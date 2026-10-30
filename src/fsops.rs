//! Native file transfer engine: copy / move / delete with progress, cancel,
//! metadata preservation and a filesystem flush once the data is written.
//!
//! Nothing in here touches Qt so it can run on worker threads and be unit
//! tested on its own.

use std::ffi::CString;
use std::fs;
use std::io::{self, Read, Write};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
use std::os::unix::io::AsRawFd;
use std::path::{Path, PathBuf};

/// Hooks a transfer reports through. `cancelled` is polled between chunks.
pub trait Monitor {
    fn cancelled(&self) -> bool;
    /// `bytes` were written while working on `current`.
    fn advance(&self, bytes: u64, current: &Path);
}

/// A monitor that never cancels and ignores progress (tests, small jobs).
pub struct Silent;
impl Monitor for Silent {
    fn cancelled(&self) -> bool {
        false
    }
    fn advance(&self, _bytes: u64, _current: &Path) {}
}

fn cancelled_err() -> io::Error {
    io::Error::new(io::ErrorKind::Interrupted, "cancelled")
}

/// Total bytes and entry count below `paths` (symlinks are not followed).
pub fn measure(paths: &[PathBuf], mon: &dyn Monitor) -> (u64, u64) {
    let mut bytes = 0u64;
    let mut count = 0u64;
    let mut stack: Vec<PathBuf> = paths.to_vec();
    while let Some(p) = stack.pop() {
        if mon.cancelled() {
            break;
        }
        let Ok(meta) = fs::symlink_metadata(&p) else { continue };
        count += 1;
        if meta.is_dir() {
            if let Ok(rd) = fs::read_dir(&p) {
                stack.extend(rd.flatten().map(|e| e.path()));
            }
        } else if meta.is_file() {
            bytes += meta.len();
        }
    }
    (bytes, count)
}

/// True when `inner` is `outer` or lives below it (lexically, after resolving
/// the parents so `a/../b` style inputs can't sneak past).
pub fn is_inside(inner: &Path, outer: &Path) -> bool {
    let canon = |p: &Path| -> PathBuf {
        match (p.parent(), p.file_name()) {
            (Some(parent), Some(name)) => fs::canonicalize(parent)
                .map(|c| c.join(name))
                .unwrap_or_else(|_| p.to_path_buf()),
            _ => p.to_path_buf(),
        }
    };
    canon(inner).starts_with(canon(outer))
}

fn set_times(fd: i32, meta: &fs::Metadata) {
    let times = [
        libc::timespec { tv_sec: meta.atime() as libc::time_t, tv_nsec: meta.atime_nsec() as _ },
        libc::timespec { tv_sec: meta.mtime() as libc::time_t, tv_nsec: meta.mtime_nsec() as _ },
    ];
    unsafe {
        libc::futimens(fd, times.as_ptr());
    }
}

fn set_path_times(path: &Path, meta: &fs::Metadata) {
    let Ok(c) = CString::new(path.as_os_str().as_bytes()) else { return };
    let times = [
        libc::timespec { tv_sec: meta.atime() as libc::time_t, tv_nsec: meta.atime_nsec() as _ },
        libc::timespec { tv_sec: meta.mtime() as libc::time_t, tv_nsec: meta.mtime_nsec() as _ },
    ];
    unsafe {
        libc::utimensat(libc::AT_FDCWD, c.as_ptr(), times.as_ptr(), libc::AT_SYMLINK_NOFOLLOW);
    }
}

const CHUNK: usize = 8 * 1024 * 1024;

/// Copies the contents of `src` into `dst`, using `copy_file_range` (which
/// lets the kernel/filesystem do server-side or reflink copies) and falling
/// back to a plain read/write loop when the kernel refuses.
fn copy_data(src: &mut fs::File, dst: &mut fs::File, path: &Path, mon: &dyn Monitor) -> io::Result<()> {
    let mut use_range = true;
    let mut buf: Vec<u8> = Vec::new();
    loop {
        if mon.cancelled() {
            return Err(cancelled_err());
        }
        if use_range {
            let n = unsafe {
                libc::copy_file_range(
                    src.as_raw_fd(),
                    std::ptr::null_mut(),
                    dst.as_raw_fd(),
                    std::ptr::null_mut(),
                    CHUNK,
                    0,
                )
            };
            if n > 0 {
                mon.advance(n as u64, path);
                continue;
            }
            if n == 0 {
                return Ok(());
            }
            let err = io::Error::last_os_error();
            match err.raw_os_error() {
                Some(libc::EXDEV) | Some(libc::ENOSYS) | Some(libc::EINVAL) | Some(libc::EOPNOTSUPP)
                | Some(libc::EPERM) => {
                    use_range = false;
                    buf.resize(1024 * 1024, 0);
                }
                Some(libc::EINTR) => continue,
                _ => return Err(err),
            }
        } else {
            let n = match src.read(&mut buf) {
                Ok(0) => return Ok(()),
                Ok(n) => n,
                Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
                Err(e) => return Err(e),
            };
            dst.write_all(&buf[..n])?;
            mon.advance(n as u64, path);
        }
    }
}

fn copy_file(src: &Path, dst: &Path, meta: &fs::Metadata, mon: &dyn Monitor) -> io::Result<()> {
    let mut input = fs::File::open(src)?;
    // create_new: never clobber something that appeared in the meantime.
    let mut output = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(dst)?;
    let result = copy_data(&mut input, &mut output, src, mon).and_then(|_| {
        output.set_permissions(fs::Permissions::from_mode(meta.mode() & 0o7777))?;
        set_times(output.as_raw_fd(), meta);
        Ok(())
    });
    if result.is_err() {
        drop(output);
        let _ = fs::remove_file(dst);
    }
    result
}

/// Recursively copies `src` to `dst` (which must not exist). Symlinks are
/// copied as links, permissions and timestamps are kept. Special files
/// (sockets, fifos, devices) are skipped.
pub fn copy_tree(src: &Path, dst: &Path, mon: &dyn Monitor) -> io::Result<()> {
    if is_inside(dst, src) {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "cannot copy a folder into itself"));
    }
    let result = copy_tree_inner(src, dst, mon);
    if result.is_err() {
        // Leave no half-copied item behind; the source is untouched.
        let _ = remove_tree(dst);
    }
    result
}

fn copy_tree_inner(src: &Path, dst: &Path, mon: &dyn Monitor) -> io::Result<()> {
    if mon.cancelled() {
        return Err(cancelled_err());
    }
    let meta = fs::symlink_metadata(src)?;
    let ft = meta.file_type();
    if ft.is_symlink() {
        let target = fs::read_link(src)?;
        std::os::unix::fs::symlink(&target, dst)?;
        set_path_times(dst, &meta);
        mon.advance(0, src);
    } else if ft.is_dir() {
        fs::create_dir(dst)?;
        // Keep the folder writable while filling it, apply the real mode after.
        let _ = fs::set_permissions(dst, fs::Permissions::from_mode(0o700));
        for entry in fs::read_dir(src)? {
            let entry = entry?;
            copy_tree_inner(&entry.path(), &dst.join(entry.file_name()), mon)?;
        }
        fs::set_permissions(dst, fs::Permissions::from_mode(meta.mode() & 0o7777))?;
        set_path_times(dst, &meta);
        mon.advance(0, src);
    } else if ft.is_file() {
        copy_file(src, dst, &meta, mon)?;
    }
    Ok(())
}

/// Deletes `path` without following symlinks (a link to a folder removes the
/// link, never the folder it points at). Missing paths are not an error.
pub fn remove_tree(path: &Path) -> io::Result<()> {
    match fs::symlink_metadata(path) {
        Ok(meta) if meta.is_dir() => fs::remove_dir_all(path),
        Ok(_) => fs::remove_file(path),
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e),
    }
}

/// Flushes the filesystem that holds `path` so the data is really on the
/// device (important before a USB stick is pulled out).
pub fn sync_filesystem(path: &Path) {
    let dir = if path.is_dir() { path } else { path.parent().unwrap_or(path) };
    if let Ok(f) = fs::File::open(dir) {
        unsafe {
            libc::syncfs(f.as_raw_fd());
        }
    }
}

fn same_device(a: &Path, b_parent: &Path) -> bool {
    match (fs::symlink_metadata(a), fs::metadata(b_parent)) {
        (Ok(x), Ok(y)) => x.dev() == y.dev(),
        _ => false,
    }
}

/// Moves `src` to `dst` (which must not exist). Uses rename on the same
/// filesystem; otherwise copies, flushes the destination, and only then
/// deletes the source, so an interrupted move never loses data.
pub fn move_path(src: &Path, dst: &Path, mon: &dyn Monitor) -> io::Result<()> {
    if is_inside(dst, src) {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "cannot move a folder into itself"));
    }
    if fs::symlink_metadata(dst).is_ok() {
        return Err(io::Error::new(io::ErrorKind::AlreadyExists, "destination exists"));
    }
    match fs::rename(src, dst) {
        Ok(()) => {
            let (bytes, _) = measure(&[dst.to_path_buf()], &Silent);
            mon.advance(bytes, src);
            return Ok(());
        }
        Err(e) if e.raw_os_error() == Some(libc::EXDEV) => {}
        Err(e) => {
            // Some filesystems report a cross-device rename differently; only
            // fall back to copying when we really are on two devices.
            if same_device(src, dst.parent().unwrap_or(Path::new("/"))) {
                return Err(e);
            }
        }
    }
    copy_tree(src, dst, mon)?;
    sync_filesystem(dst);
    remove_tree(src)
}

/// A sibling name of `dst` that does not exist yet, for staging.
fn staging_name(dst: &Path, tag: &str) -> PathBuf {
    let parent = dst.parent().unwrap_or(Path::new("."));
    let base = dst.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
    let pid = std::process::id();
    for i in 0u32.. {
        let cand = parent.join(format!(".loaf-{}-{}-{}-{}", tag, pid, i, base));
        if fs::symlink_metadata(&cand).is_err() {
            return cand;
        }
    }
    unreachable!()
}

/// Replaces `dst` with `src` (copied or moved). The new data is staged next
/// to `dst` first; the old item then goes to the **trash** (never deleted
/// outright, so a replaced folder's other files can be recovered) and the
/// new one is renamed in. Any failure puts the old item back.
pub fn replace(src: &Path, dst: &Path, is_move: bool, mon: &dyn Monitor) -> io::Result<()> {
    if src == dst {
        return Ok(());
    }
    if is_inside(dst, src) || is_inside(src, dst) {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "source and destination overlap"));
    }
    let staged = staging_name(dst, "new");
    if is_move {
        move_path(src, &staged, mon)?;
    } else {
        copy_tree(src, &staged, mon)?;
    }
    let undo_stage = |staged: &Path| {
        if is_move {
            let _ = move_path(staged, src, &Silent);
        } else {
            let _ = remove_tree(staged);
        }
    };
    let old = match crate::trash::trash(dst) {
        Ok(item) => item,
        // No usable trash on this filesystem (root-owned mount, NFS, MTP…):
        // replace the way it always worked (set aside, swap, delete).
        Err(_) => {
            let r = swap_and_delete(&staged, dst);
            if r.is_err() {
                undo_stage(&staged);
            }
            return r;
        }
    };
    if let Err(e) = fs::rename(&staged, dst) {
        let _ = crate::trash::restore(&old);
        undo_stage(&staged);
        return Err(e);
    }
    Ok(())
}

/// Puts `staged` at `dst`, deleting what was there. Restores `dst` if the swap fails.
fn swap_and_delete(staged: &Path, dst: &Path) -> io::Result<()> {
    let old = staging_name(dst, "old");
    fs::rename(dst, &old)?;
    if let Err(e) = fs::rename(staged, dst) {
        let _ = fs::rename(&old, dst);
        return Err(e);
    }
    remove_tree(&old)
}

/// Merges folder `src` into existing folder `dst`: sub-folders that exist
/// on both sides are merged too; any other name clash gets a free
/// "name (2)" so nothing in `dst` is overwritten. A move removes `src`
/// when it ends up empty.
pub fn merge_into(src: &Path, dst: &Path, is_move: bool, mon: &dyn Monitor) -> io::Result<()> {
    if is_inside(dst, src) || is_inside(src, dst) {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "source and destination overlap"));
    }
    for entry in fs::read_dir(src)? {
        if mon.cancelled() {
            return Err(io::Error::from(io::ErrorKind::Interrupted));
        }
        let entry = entry?;
        let from = entry.path();
        let name = entry.file_name();
        let to = dst.join(&name);
        let from_is_dir = entry.file_type()?.is_dir();
        match fs::symlink_metadata(&to) {
            Ok(m) if m.is_dir() && from_is_dir => merge_into(&from, &to, is_move, mon)?,
            other => {
                let target = if other.is_ok() { unique_name(dst, &name.to_string_lossy()) } else { to };
                if is_move {
                    move_path(&from, &target, mon)?;
                } else {
                    copy_tree(&from, &target, mon)?;
                }
            }
        }
    }
    if is_move {
        let _ = fs::remove_dir(src); // only succeeds when empty
    }
    Ok(())
}

/// Replaces `dst` with a symlink to `src`. Refuses when `dst` already is
/// `src` (e.g. reached through a linked folder), which would otherwise
/// delete the source and leave a link pointing at itself.
pub fn replace_with_link(src: &Path, dst: &Path) -> io::Result<()> {
    if let (Ok(a), Ok(b)) = (fs::canonicalize(src), fs::canonicalize(dst)) {
        if a == b {
            return Err(io::Error::new(io::ErrorKind::InvalidInput, "source and destination are the same item"));
        }
    }
    let staged = staging_name(dst, "new");
    std::os::unix::fs::symlink(src, &staged)?;
    let old = match crate::trash::trash(dst) {
        Ok(item) => item,
        Err(_) => {
            let r = swap_and_delete(&staged, dst);
            if r.is_err() {
                let _ = fs::remove_file(&staged);
            }
            return r;
        }
    };
    if let Err(e) = fs::rename(&staged, dst) {
        let _ = crate::trash::restore(&old);
        let _ = fs::remove_file(&staged);
        return Err(e);
    }
    Ok(())
}

/// Renames without ever replacing an existing `to` (fails with
/// `AlreadyExists` instead). A plain rename would silently replace an empty
/// folder or file that appeared at `to` meanwhile.
pub fn rename_noreplace(from: &Path, to: &Path) -> io::Result<()> {
    use std::os::unix::ffi::OsStrExt;
    let a = std::ffi::CString::new(from.as_os_str().as_bytes())?;
    let b = std::ffi::CString::new(to.as_os_str().as_bytes())?;
    let r = unsafe { libc::renameat2(libc::AT_FDCWD, a.as_ptr(), libc::AT_FDCWD, b.as_ptr(), libc::RENAME_NOREPLACE) };
    if r == 0 {
        return Ok(());
    }
    let e = io::Error::last_os_error();
    match e.raw_os_error() {
        // Filesystem without RENAME_NOREPLACE support: best effort.
        Some(libc::EINVAL) | Some(libc::ENOSYS) => {
            if fs::symlink_metadata(to).is_ok() {
                return Err(io::Error::from(io::ErrorKind::AlreadyExists));
            }
            fs::rename(from, to)
        }
        _ => Err(e),
    }
}

/// Moves `from` into `dir` under `name`, or the first free "name (N)".
pub fn place_unique(from: &Path, dir: &Path, name: &str) -> io::Result<PathBuf> {
    loop {
        let to = unique_name(dir, name);
        match rename_noreplace(from, &to) {
            Ok(()) => return Ok(to),
            Err(e) if e.kind() == io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(e),
        }
    }
}

/// `dest/name`, or `dest/name (N).ext` when that is taken. Multi-part
/// extensions like `.tar.gz` stay together.
pub fn unique_name(dest: &Path, name: &str) -> PathBuf {
    let first = dest.join(name);
    if fs::symlink_metadata(&first).is_err() {
        return first;
    }
    let lower = name.to_lowercase();
    let multi = [".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2"];
    let split_at = multi
        .iter()
        .find(|s| lower.ends_with(*s) && name.len() > s.len())
        .map(|s| name.len() - s.len())
        .or_else(|| {
            // A leading dot is part of the name (".bashrc"), not an extension.
            name.rfind('.').filter(|&i| i > 0)
        })
        .unwrap_or(name.len());
    let (stem, ext) = name.split_at(split_at);
    for n in 2u32.. {
        let cand = dest.join(format!("{} ({}){}", stem, n, ext));
        if fs::symlink_metadata(&cand).is_err() {
            return cand;
        }
    }
    unreachable!()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn place_unique_never_replaces() {
        let d = std::env::temp_dir().join(format!("loaf-place-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(d.join("taken")).unwrap(); // empty dir: plain rename would replace it
        fs::create_dir_all(d.join("src")).unwrap();
        fs::write(d.join("src/f"), b"x").unwrap();
        assert!(rename_noreplace(&d.join("src"), &d.join("taken")).is_err());
        let to = place_unique(&d.join("src"), &d, "taken").unwrap();
        assert_eq!(to, d.join("taken (2)"));
        assert!(d.join("taken").is_dir() && d.join("taken (2)/f").is_file());
        let _ = fs::remove_dir_all(&d);
    }
    use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};

    fn tmpdir(tag: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("loaf-fsops-{}-{}", tag, std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn copies_tree_with_links_and_modes() {
        let d = tmpdir("copy");
        let src = d.join("src");
        fs::create_dir_all(src.join("sub")).unwrap();
        fs::write(src.join("a.txt"), b"hello").unwrap();
        fs::write(src.join("sub/b.bin"), vec![7u8; 3 * 1024 * 1024]).unwrap();
        fs::set_permissions(src.join("a.txt"), fs::Permissions::from_mode(0o640)).unwrap();
        std::os::unix::fs::symlink("a.txt", src.join("link")).unwrap();

        copy_tree(&src, &d.join("dst"), &Silent).unwrap();
        let dst = d.join("dst");
        assert_eq!(fs::read(dst.join("a.txt")).unwrap(), b"hello");
        assert_eq!(fs::read(dst.join("sub/b.bin")).unwrap().len(), 3 * 1024 * 1024);
        assert_eq!(fs::read_link(dst.join("link")).unwrap(), PathBuf::from("a.txt"));
        let mode = fs::metadata(dst.join("a.txt")).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o640);
        let src_m = fs::metadata(src.join("a.txt")).unwrap().mtime();
        assert_eq!(fs::metadata(dst.join("a.txt")).unwrap().mtime(), src_m);
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn refuses_copy_into_itself() {
        let d = tmpdir("self");
        fs::create_dir_all(d.join("a")).unwrap();
        assert!(copy_tree(&d.join("a"), &d.join("a/inner"), &Silent).is_err());
        assert!(move_path(&d.join("a"), &d.join("a/inner"), &Silent).is_err());
        assert!(d.join("a").is_dir());
        fs::remove_dir_all(&d).unwrap();
    }

    struct CancelAfter {
        limit: u64,
        seen: AtomicU64,
        flag: AtomicBool,
    }
    impl Monitor for CancelAfter {
        fn cancelled(&self) -> bool {
            self.flag.load(Ordering::SeqCst)
        }
        fn advance(&self, bytes: u64, _c: &Path) {
            if self.seen.fetch_add(bytes, Ordering::SeqCst) + bytes >= self.limit {
                self.flag.store(true, Ordering::SeqCst);
            }
        }
    }

    #[test]
    fn cancelled_copy_leaves_nothing_behind() {
        let d = tmpdir("cancel");
        fs::create_dir_all(d.join("src")).unwrap();
        for i in 0..4 {
            fs::write(d.join(format!("src/f{}", i)), vec![1u8; 9 * 1024 * 1024]).unwrap();
        }
        let mon = CancelAfter { limit: 10 * 1024 * 1024, seen: AtomicU64::new(0), flag: AtomicBool::new(false) };
        let err = copy_tree(&d.join("src"), &d.join("dst"), &mon).unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::Interrupted);
        assert!(!d.join("dst").exists());
        assert_eq!(fs::read_dir(d.join("src")).unwrap().count(), 4);
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn replace_folder_swaps_instead_of_nesting() {
        let d = tmpdir("replace");
        fs::create_dir_all(d.join("a/photos")).unwrap();
        fs::write(d.join("a/photos/new.jpg"), b"new").unwrap();
        fs::create_dir_all(d.join("b/photos")).unwrap();
        fs::write(d.join("b/photos/old.jpg"), b"old").unwrap();

        replace(&d.join("a/photos"), &d.join("b/photos"), false, &Silent).unwrap();
        assert!(d.join("b/photos/new.jpg").exists());
        assert!(!d.join("b/photos/old.jpg").exists());
        // The replaced folder went to the trash, not into the void.
        let trashed = crate::trash::home_trash().join("files");
        assert!(fs::read_dir(&trashed).unwrap().flatten().any(|e| e.path().join("old.jpg").exists()));
        assert!(!d.join("b/photos/photos").exists(), "must not nest");
        assert!(d.join("a/photos/new.jpg").exists(), "copy keeps source");
        // No staging leftovers.
        assert_eq!(fs::read_dir(d.join("b")).unwrap().count(), 1);

        replace(&d.join("a/photos"), &d.join("b/photos"), true, &Silent).unwrap();
        assert!(!d.join("a/photos").exists(), "move removes source");
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn merge_keeps_files_only_in_destination() {
        let d = tmpdir("merge");
        fs::create_dir_all(d.join("a/pics/sub")).unwrap();
        fs::write(d.join("a/pics/new.jpg"), b"new").unwrap();
        fs::write(d.join("a/pics/same.jpg"), b"from a").unwrap();
        fs::write(d.join("a/pics/sub/deep.txt"), b"deep").unwrap();
        fs::create_dir_all(d.join("b/pics/sub")).unwrap();
        fs::write(d.join("b/pics/only_b.jpg"), b"keep me").unwrap();
        fs::write(d.join("b/pics/same.jpg"), b"from b").unwrap();

        merge_into(&d.join("a/pics"), &d.join("b/pics"), true, &Silent).unwrap();
        assert_eq!(fs::read(d.join("b/pics/only_b.jpg")).unwrap(), b"keep me");
        assert_eq!(fs::read(d.join("b/pics/same.jpg")).unwrap(), b"from b", "never overwritten");
        assert_eq!(fs::read(d.join("b/pics/same (2).jpg")).unwrap(), b"from a");
        assert!(d.join("b/pics/new.jpg").exists() && d.join("b/pics/sub/deep.txt").exists());
        assert!(!d.join("a/pics").exists(), "an emptied source folder is removed on move");
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn remove_tree_does_not_follow_links() {
        let d = tmpdir("rm");
        fs::create_dir_all(d.join("real")).unwrap();
        fs::write(d.join("real/keep"), b"x").unwrap();
        std::os::unix::fs::symlink(d.join("real"), d.join("link")).unwrap();
        remove_tree(&d.join("link")).unwrap();
        assert!(d.join("real/keep").exists());
        assert!(fs::symlink_metadata(d.join("link")).is_err());
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn unique_names() {
        let d = tmpdir("uniq");
        fs::write(d.join("a.txt"), b"").unwrap();
        fs::write(d.join("x.tar.gz"), b"").unwrap();
        fs::write(d.join(".bashrc"), b"").unwrap();
        assert_eq!(unique_name(&d, "a.txt"), d.join("a (2).txt"));
        assert_eq!(unique_name(&d, "x.tar.gz"), d.join("x (2).tar.gz"));
        assert_eq!(unique_name(&d, ".bashrc"), d.join(".bashrc (2)"));
        assert_eq!(unique_name(&d, "free"), d.join("free"));
        fs::remove_dir_all(&d).unwrap();
    }
}
