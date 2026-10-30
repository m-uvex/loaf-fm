//! freedesktop.org Trash specification (1.0) implementation.
//!
//! * Home trash: `$XDG_DATA_HOME/Trash`.
//! * Other filesystems: `$topdir/.Trash/$uid` (only when `.Trash` is a real,
//!   sticky directory) or `$topdir/.Trash-$uid`, so trashing a file on a USB
//!   stick never copies it into the home folder.
//! * `.trashinfo` files are reserved with `O_EXCL` before the move, carry a
//!   local-time `DeletionDate`, and use a topdir-relative `Path` outside home.
//! * Symlinks are trashed as links; their targets are never touched.

use std::fs;
use std::io::{self, Write};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, PartialEq)]
pub struct TrashedItem {
    /// Absolute path the item had before it was trashed.
    pub original: PathBuf,
    /// Where it lives now (inside `<trash>/files`).
    pub trashed: PathBuf,
    /// Its `<trash>/info/<name>.trashinfo` file.
    pub info: PathBuf,
    /// `DeletionDate` as written in the info file.
    pub deleted: String,
}

fn uid() -> u32 {
    unsafe { libc::getuid() }
}

pub fn home_trash() -> PathBuf {
    // Tests run in parallel; a per-process private trash means no test can
    // ever reach the user's real trash, whatever the environment says.
    if cfg!(test) {
        return std::env::temp_dir().join(format!("loaf-test-trash-{}", std::process::id()));
    }
    match std::env::var("XDG_DATA_HOME") {
        Ok(x) if !x.is_empty() => PathBuf::from(x).join("Trash"),
        _ => PathBuf::from(std::env::var("HOME").unwrap_or_default()).join(".local/share/Trash"),
    }
}

/// Percent-encodes a path as the spec requires (RFC 2396 escaping, `/` kept).
pub fn encode_path(p: &Path) -> String {
    let mut out = String::new();
    for &b in p.as_os_str().as_bytes() {
        if b.is_ascii_alphanumeric() || b"-_.~/!*'()".contains(&b) {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{:02X}", b));
        }
    }
    out
}

/// Reverses [`encode_path`]; works on raw bytes so malformed input can never
/// panic on a char boundary.
pub fn decode_path(s: &str) -> PathBuf {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let hex = |c: u8| (c as char).to_digit(16);
            if let (Some(h), Some(l)) = (hex(bytes[i + 1]), hex(bytes[i + 2])) {
                out.push((h * 16 + l) as u8);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    PathBuf::from(std::ffi::OsStr::from_bytes(&out))
}

/// Local time as `YYYY-MM-DDThh:mm:ss` (the spec asks for local time).
pub fn local_timestamp() -> String {
    let now = unsafe { libc::time(std::ptr::null_mut()) };
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    unsafe {
        libc::localtime_r(&now, &mut tm);
    }
    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}",
        tm.tm_year + 1900,
        tm.tm_mon + 1,
        tm.tm_mday,
        tm.tm_hour,
        tm.tm_min,
        tm.tm_sec
    )
}

/// The absolute path of `p` with its parent resolved but the last component
/// left alone (so a symlink stays a symlink).
pub fn absolute_no_follow(p: &Path) -> io::Result<PathBuf> {
    let name = p.file_name().ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "no file name"))?;
    let parent = match p.parent() {
        Some(x) if !x.as_os_str().is_empty() => x.to_path_buf(),
        _ => std::env::current_dir()?,
    };
    Ok(fs::canonicalize(parent)?.join(name))
}

/// Mount point that contains `p` (walks up while the device stays the same).
pub fn topdir_of(p: &Path) -> Option<PathBuf> {
    let dev = fs::symlink_metadata(p).ok()?.dev();
    let mut cur = p.to_path_buf();
    loop {
        let parent = match cur.parent() {
            Some(x) => x.to_path_buf(),
            None => return Some(cur),
        };
        match fs::metadata(&parent) {
            Ok(m) if m.dev() == dev => cur = parent,
            _ => return Some(cur),
        }
    }
}

fn is_sticky_real_dir(p: &Path) -> bool {
    match fs::symlink_metadata(p) {
        Ok(m) => m.is_dir() && (m.mode() & libc::S_ISVTX as u32) != 0,
        Err(_) => false,
    }
}

/// A real directory (not a symlink) owned by us. Trash folders on removable
/// drives are untrusted: a planted `files -> ~/Documents` link must never be
/// followed by Empty Trash.
fn owned_real_dir(p: &Path) -> bool {
    fs::symlink_metadata(p).map(|m| m.is_dir() && m.uid() == uid()).unwrap_or(false)
}

/// Whether `root/files` and `root/info` are safe to read and delete from.
fn usable_trash(root: &Path) -> bool {
    owned_real_dir(&root.join("files")) && owned_real_dir(&root.join("info"))
}

fn ensure_trash_dirs(root: &Path) -> io::Result<()> {
    for sub in ["files", "info"] {
        let d = root.join(sub);
        if fs::symlink_metadata(&d).is_err() {
            fs::create_dir_all(&d)?;
            let _ = fs::set_permissions(&d, fs::Permissions::from_mode(0o700));
        }
    }
    if usable_trash(root) {
        Ok(())
    } else {
        Err(io::Error::new(io::ErrorKind::PermissionDenied, "unsafe trash directory"))
    }
}

/// Picks (and creates if needed) the trash directory for a path on another
/// filesystem. Returns `None` when no usable trash can exist there.
fn topdir_trash(topdir: &Path, create: bool) -> Option<PathBuf> {
    let shared = topdir.join(".Trash");
    if is_sticky_real_dir(&shared) {
        let mine = shared.join(uid().to_string());
        if owned_real_dir(&mine) || (create && fs::create_dir(&mine).is_ok()) {
            if !create || ensure_trash_dirs(&mine).is_ok() {
                return Some(mine);
            }
        }
    }
    let personal = topdir.join(format!(".Trash-{}", uid()));
    match fs::symlink_metadata(&personal) {
        Ok(m) if m.is_dir() && m.uid() == uid() => {
            if !create || ensure_trash_dirs(&personal).is_ok() {
                return Some(personal);
            }
            None
        }
        Ok(_) => None, // something else squats on the name: don't use it
        Err(_) if create => {
            fs::create_dir(&personal).ok()?;
            let _ = fs::set_permissions(&personal, fs::Permissions::from_mode(0o700));
            ensure_trash_dirs(&personal).ok()?;
            Some(personal)
        }
        Err(_) => None,
    }
}

/// The trash directory an item at `abs` should go to, plus the topdir to make
/// `Path=` relative to (None for the home trash).
fn trash_for(abs: &Path) -> io::Result<(PathBuf, Option<PathBuf>)> {
    let home = home_trash();
    let _ = fs::create_dir_all(&home);
    let item_dev = fs::symlink_metadata(abs)?.dev();
    let home_dev = fs::metadata(&home).map(|m| m.dev()).ok();
    if home_dev == Some(item_dev) {
        ensure_trash_dirs(&home)?;
        return Ok((home, None));
    }
    let top = topdir_of(abs).ok_or_else(|| io::Error::new(io::ErrorKind::Other, "no mount point"))?;
    match topdir_trash(&top, true) {
        Some(t) => Ok((t, Some(top))),
        None => Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "this drive has no usable trash folder",
        )),
    }
}

/// Reserves `<info>/<name>.trashinfo` atomically, picking a free name, and
/// returns the chosen file name.
fn reserve_info(root: &Path, name: &str, contents: &str) -> io::Result<String> {
    let info_dir = root.join("info");
    let files_dir = root.join("files");
    let path = Path::new(name);
    let stem = path.file_stem().map(|s| s.to_string_lossy().to_string()).unwrap_or_else(|| name.to_string());
    let ext = path.extension().map(|e| format!(".{}", e.to_string_lossy())).unwrap_or_default();
    for i in 0u32.. {
        let cand = if i == 0 { name.to_string() } else { format!("{}.{}{}", stem, i, ext) };
        if fs::symlink_metadata(files_dir.join(&cand)).is_ok() {
            continue;
        }
        match fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(info_dir.join(format!("{}.trashinfo", cand)))
        {
            Ok(mut f) => {
                f.write_all(contents.as_bytes())?;
                return Ok(cand);
            }
            Err(e) if e.kind() == io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(e),
        }
    }
    unreachable!()
}

/// Moves `path` into the matching trash. Never copies across filesystems.
pub fn trash(path: &Path) -> io::Result<TrashedItem> {
    let abs = absolute_no_follow(path)?;
    let name = abs
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "no file name"))?;
    let (root, topdir) = trash_for(&abs)?;
    if abs.starts_with(&root) {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, "item is already in the trash"));
    }
    let shown_path = match &topdir {
        Some(top) => abs.strip_prefix(top).map(|p| p.to_path_buf()).unwrap_or_else(|_| abs.clone()),
        None => abs.clone(),
    };
    let deleted = local_timestamp();
    let contents = format!("[Trash Info]\nPath={}\nDeletionDate={}\n", encode_path(&shown_path), deleted);
    let chosen = reserve_info(&root, &name, &contents)?;
    let info = root.join("info").join(format!("{}.trashinfo", chosen));
    let trashed = root.join("files").join(&chosen);
    if let Err(e) = fs::rename(&abs, &trashed) {
        let _ = fs::remove_file(&info);
        return Err(e);
    }
    Ok(TrashedItem { original: abs, trashed, info, deleted })
}

/// Parses a `.trashinfo` body into (Path, DeletionDate).
pub fn parse_info(content: &str) -> Option<(PathBuf, String)> {
    let mut in_group = false;
    let mut path = None;
    let mut date = String::new();
    for line in content.lines() {
        let line = line.trim();
        if line.starts_with('[') {
            in_group = line == "[Trash Info]";
            continue;
        }
        if !in_group {
            continue;
        }
        if let Some(v) = line.strip_prefix("Path=") {
            path = Some(decode_path(v));
        } else if let Some(v) = line.strip_prefix("DeletionDate=") {
            date = v.to_string();
        }
    }
    path.filter(|p| !p.as_os_str().is_empty()).map(|p| (p, date))
}

/// Every trash directory currently reachable: home plus one per mounted
/// filesystem that already has a trash for this user.
pub fn all_trash_dirs() -> Vec<PathBuf> {
    let mut out = vec![home_trash()];
    let mounts = fs::read_to_string("/proc/self/mounts").unwrap_or_default();
    for line in mounts.lines() {
        let mut parts = line.split_whitespace();
        let (Some(_dev), Some(mnt), Some(fstype)) = (parts.next(), parts.next(), parts.next()) else { continue };
        if is_virtual_fs(fstype) {
            continue;
        }
        let mnt = PathBuf::from(unescape_mount(mnt));
        if let Some(t) = topdir_trash(&mnt, false) {
            if !out.contains(&t) {
                out.push(t);
            }
        }
    }
    out
}

pub fn is_virtual_fs(fstype: &str) -> bool {
    matches!(
        fstype,
        "proc" | "sysfs" | "devtmpfs" | "devpts" | "tmpfs" | "cgroup" | "cgroup2" | "securityfs" | "pstore"
            | "debugfs" | "tracefs" | "configfs" | "fusectl" | "mqueue" | "hugetlbfs" | "bpf" | "autofs"
            | "binfmt_misc" | "efivarfs" | "ramfs" | "rpc_pipefs" | "nsfs" | "overlay" | "squashfs"
            | "fuse.portal" | "fuse.gvfsd-fuse" | "selinuxfs"
    )
}

/// `/proc/mounts` escapes spaces etc. as octal (`\040`).
pub fn unescape_mount(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'\\' && i + 3 < b.len() && b[i + 1..i + 4].iter().all(|c| (b'0'..=b'7').contains(c)) {
            let v = b[i + 1..i + 4].iter().fold(0u16, |acc, c| acc * 8 + (c - b'0') as u16);
            if v <= 255 {
                out.push(v as u8);
                i += 4;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).to_string()
}

/// Everything currently in any trash.
pub fn list() -> Vec<TrashedItem> {
    list_in(&all_trash_dirs())
}

fn list_in(roots: &[PathBuf]) -> Vec<TrashedItem> {
    let mut out = Vec::new();
    for root in roots {
        let root = root.as_path();
        let top = root_topdir(root);
        if !usable_trash(root) {
            continue;
        }
        let Ok(rd) = fs::read_dir(root.join("info")) else { continue };
        for entry in rd.flatten() {
            let fname = entry.file_name().to_string_lossy().to_string();
            let Some(stem) = fname.strip_suffix(".trashinfo") else { continue };
            let trashed = root.join("files").join(stem);
            if fs::symlink_metadata(&trashed).is_err() {
                continue; // orphaned info file
            }
            let Ok(content) = fs::read_to_string(entry.path()) else { continue };
            let Some((p, deleted)) = parse_info(&content) else { continue };
            // Never let a record restore outside its own drive (or, for
            // the home trash, use a relative path with `..` tricks).
            if p.components().any(|c| c == std::path::Component::ParentDir) {
                continue;
            }
            let original = match (&top, p.is_absolute()) {
                (None, true) => p,
                (None, false) => continue,
                (Some(t), false) => t.join(&p),
                (Some(t), true) if p.starts_with(t) => p,
                (Some(_), true) => continue,
            };
            out.push(TrashedItem { original, trashed, info: entry.path(), deleted });
        }
    }
    out
}

/// The topdir a trash directory belongs to (None for the home trash).
fn root_topdir(root: &Path) -> Option<PathBuf> {
    if root == home_trash() {
        return None;
    }
    let name = root.file_name()?.to_string_lossy().to_string();
    if name.starts_with(".Trash-") {
        root.parent().map(|p| p.to_path_buf())
    } else {
        // .Trash/$uid
        root.parent().and_then(|p| p.parent()).map(|p| p.to_path_buf())
    }
}

/// Finds the trash record for a path inside some `files/` directory.
pub fn lookup(trashed: &Path) -> Option<TrashedItem> {
    list().into_iter().find(|it| it.trashed == trashed)
}

/// Puts an item back. If something now occupies the original location the
/// restored item gets a free name instead of overwriting it. Returns where
/// it ended up.
pub fn restore(item: &TrashedItem) -> io::Result<PathBuf> {
    let parent = item.original.parent().unwrap_or(Path::new("/"));
    fs::create_dir_all(parent)?;
    let name = item.original.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
    let target = crate::fsops::unique_name(parent, &name);
    crate::fsops::move_path(&item.trashed, &target, &crate::fsops::Silent)?;
    let _ = fs::remove_file(&item.info);
    Ok(target)
}

/// Deletes one trashed item for good.
pub fn erase(item: &TrashedItem) -> io::Result<()> {
    crate::fsops::remove_tree(&item.trashed)?;
    let _ = fs::remove_file(&item.info);
    Ok(())
}

/// Empties every trash this user owns (and nothing else).
pub fn empty_all() -> io::Result<()> {
    empty_in(&all_trash_dirs())
}

fn empty_in(roots: &[PathBuf]) -> io::Result<()> {
    let mut first_err = None;
    for root in roots {
        if !usable_trash(root) {
            continue;
        }
        // Delete each item first and its .trashinfo only afterwards: if the
        // item can't be removed it stays listed instead of turning invisible.
        if let Ok(rd) = fs::read_dir(root.join("files")) {
            for e in rd.flatten() {
                match crate::fsops::remove_tree(&e.path()) {
                    Ok(()) => {
                        let mut info = e.file_name();
                        info.push(".trashinfo");
                        let _ = fs::remove_file(root.join("info").join(info));
                    }
                    Err(err) => {
                        first_err.get_or_insert(err);
                    }
                }
            }
        }
        // Records whose item is gone (orphans) can go.
        if let Ok(rd) = fs::read_dir(root.join("info")) {
            for e in rd.flatten() {
                use std::os::unix::ffi::OsStrExt;
                let name = e.file_name();
                // Raw bytes: names need not be UTF-8.
                let Some(item) = name.as_bytes().strip_suffix(b".trashinfo") else { continue };
                if fs::symlink_metadata(root.join("files").join(std::ffi::OsStr::from_bytes(item))).is_err() {
                    let _ = fs::remove_file(e.path());
                }
            }
        }
        let _ = fs::remove_file(root.join("directorysizes"));
    }
    match first_err {
        Some(e) => Err(e),
        None => Ok(()),
    }
}

/// Whether `p` lies inside any trash `files/` directory.
pub fn is_in_trash(p: &Path) -> bool {
    all_trash_dirs().iter().any(|t| p.starts_with(t.join("files")))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sandbox(tag: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("loaf-trash-{}-{}", tag, std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn encodes_and_decodes_paths() {
        let p = Path::new("/home/a b/ünï%.txt");
        assert_eq!(decode_path(&encode_path(p)), p);
        // Malformed escapes and a % before a multibyte char must not panic.
        assert_eq!(decode_path("/x/%zz"), PathBuf::from("/x/%zz"));
        assert_eq!(decode_path("/x/%é"), PathBuf::from("/x/%é"));
        assert_eq!(decode_path("/x/%4"), PathBuf::from("/x/%4"));
    }

    #[test]
    fn parses_info() {
        let (p, d) = parse_info("[Trash Info]\nPath=/a/b%20c\nDeletionDate=2026-01-02T03:04:05\n").unwrap();
        assert_eq!(p, PathBuf::from("/a/b c"));
        assert_eq!(d, "2026-01-02T03:04:05");
        assert!(parse_info("[Other]\nPath=/x\n").is_none());
    }

    #[test]
    fn unescapes_mount_points() {
        assert_eq!(unescape_mount("/run/media/u/Extra\\040Volume"), "/run/media/u/Extra Volume");
        assert_eq!(unescape_mount("/a\\04"), "/a\\04");
        assert_eq!(unescape_mount("/a\\777b"), "/a\\777b");
    }

    // A drive with `.Trash-$uid/files -> victim` must not let Empty Trash
    // (or Restore via `..` paths) reach outside the trash.
    #[test]
    fn planted_trash_symlinks_are_ignored() {
        let d = sandbox("planted");
        let victim = d.join("victim");
        fs::create_dir_all(victim.join("docs")).unwrap();
        fs::write(victim.join("docs/keep.txt"), b"x").unwrap();
        let root = d.join(format!(".Trash-{}", uid()));
        fs::create_dir_all(root.join("info")).unwrap();
        std::os::unix::fs::symlink(&victim, root.join("files")).unwrap();
        fs::write(root.join("info/docs.trashinfo"), "[Trash Info]\nPath=docs\n").unwrap();
        assert!(list_in(&[root.clone()]).is_empty());
        empty_in(&[root.clone()]).unwrap();
        assert!(victim.join("docs/keep.txt").exists());

        let root2 = d.join("t2");
        fs::create_dir_all(root2.join("files/x")).unwrap();
        fs::create_dir_all(root2.join("info")).unwrap();
        fs::write(root2.join("info/x.trashinfo"), "[Trash Info]\nPath=../../etc/x\n").unwrap();
        assert!(list_in(&[root2]).is_empty());
        let _ = fs::remove_dir_all(&d);
    }

    // A failed delete must keep the item listed (and restorable), not leave
    // an invisible file behind with its .trashinfo removed.
    #[test]
    fn empty_keeps_records_of_items_it_could_not_delete() {
        use std::os::unix::fs::PermissionsExt;
        let d = sandbox("emptyfail");
        let root = d.join("t");
        fs::create_dir_all(root.join("files/locked/inner")).unwrap();
        fs::write(root.join("files/locked/inner/f"), b"x").unwrap();
        fs::write(root.join("files/gone.txt"), b"y").unwrap();
        fs::create_dir_all(root.join("info")).unwrap();
        fs::write(root.join("info/locked.trashinfo"), "[Trash Info]\nPath=/x/locked\n").unwrap();
        fs::write(root.join("info/gone.txt.trashinfo"), "[Trash Info]\nPath=/x/gone.txt\n").unwrap();
        fs::write(root.join("info/orphan.trashinfo"), "[Trash Info]\nPath=/x/orphan\n").unwrap();
        fs::set_permissions(root.join("files/locked/inner"), fs::Permissions::from_mode(0o555)).unwrap();
        let res = empty_in(&[root.clone()]);
        fs::set_permissions(root.join("files/locked/inner"), fs::Permissions::from_mode(0o755)).unwrap();
        assert!(res.is_err());
        assert!(root.join("info/locked.trashinfo").exists(), "record kept for what is still there");
        assert!(!root.join("files/gone.txt").exists() && !root.join("info/gone.txt.trashinfo").exists());
        assert!(!root.join("info/orphan.trashinfo").exists(), "orphan records are cleaned");
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn local_timestamp_shape() {
        let t = local_timestamp();
        assert_eq!(t.len(), 19);
        assert_eq!(&t[10..11], "T");
    }

    // home_trash() is a private temp dir in tests, on the same filesystem.
    #[test]
    fn trash_restore_cycle_keeps_symlink_targets() {
        let d = sandbox("cycle");
        fs::write(d.join("target.txt"), b"precious").unwrap();
        std::os::unix::fs::symlink(d.join("target.txt"), d.join("link")).unwrap();

        let item = trash(&d.join("link")).unwrap();
        assert!(d.join("target.txt").exists(), "symlink target must survive");
        assert!(fs::symlink_metadata(&item.trashed).unwrap().file_type().is_symlink());
        assert_eq!(item.original, fs::canonicalize(&d).unwrap().join("link"));

        // Something new now lives at the original spot: restore must not clobber it.
        fs::write(d.join("link"), b"new file").unwrap();
        let back = restore(&item).unwrap();
        assert_ne!(back, d.join("link"));
        assert_eq!(fs::read(d.join("link")).unwrap(), b"new file");
        assert!(!item.info.exists());

        // Name collisions inside the trash get unique names.
        fs::write(d.join("dup"), b"1").unwrap();
        let a = trash(&d.join("dup")).unwrap();
        fs::write(d.join("dup"), b"2").unwrap();
        let b = trash(&d.join("dup")).unwrap();
        assert_ne!(a.trashed, b.trashed);
        let only_home = [home_trash()];
        assert!(list_in(&only_home).iter().any(|i| i.trashed == b.trashed));
        let _ = restore(&a);
        let _ = restore(&b);
        fs::remove_dir_all(&d).unwrap();
    }
}
