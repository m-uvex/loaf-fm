//! Small process helpers shared by the backend modules.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::Mutex;

static WHICH_CACHE: Mutex<Option<HashMap<String, Option<PathBuf>>>> = Mutex::new(None);

/// Locks a mutex even if a previous holder panicked: the data we keep behind
/// these locks (caches, lists) is always in a usable state.
pub fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|poison| poison.into_inner())
}

/// Finds an executable on `$PATH` (plus the usual NixOS profile locations
/// for when Loaf is started outside a login shell). Cached.
pub fn which(name: &str) -> Option<PathBuf> {
    if let Some(hit) = lock(&WHICH_CACHE).get_or_insert_with(HashMap::new).get(name) {
        return hit.clone();
    }
    let mut dirs: Vec<PathBuf> = std::env::var_os("PATH")
        .map(|p| std::env::split_paths(&p).collect())
        .unwrap_or_default();
    let home = std::env::var("HOME").unwrap_or_default();
    let user = std::env::var("USER").unwrap_or_default();
    for extra in [
        "/run/current-system/sw/bin".to_string(),
        "/run/wrappers/bin".to_string(),
        format!("/etc/profiles/per-user/{}/bin", user),
        format!("{}/.nix-profile/bin", home),
        "/usr/local/bin".to_string(),
        "/usr/bin".to_string(),
        "/bin".to_string(),
    ] {
        dirs.push(PathBuf::from(extra));
    }
    let found = dirs.into_iter().map(|d| d.join(name)).find(|c| is_executable(c));
    lock(&WHICH_CACHE).get_or_insert_with(HashMap::new).insert(name.to_string(), found.clone());
    found
}

fn is_executable(p: &Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    std::fs::metadata(p).map(|m| m.is_file() && m.permissions().mode() & 0o111 != 0).unwrap_or(false)
}

/// First available program out of a list of aliases.
pub fn which_any(names: &[&str]) -> Option<PathBuf> {
    names.iter().find_map(|n| which(n))
}

/// Starts a program without waiting for it. A helper thread reaps the child
/// so finished programs never linger as zombies.
pub fn spawn_detached(mut cmd: Command) -> std::io::Result<()> {
    cmd.stdin(Stdio::null());
    let mut child = cmd.spawn()?;
    std::thread::spawn(move || {
        let _ = child.wait();
    });
    Ok(())
}

/// Runs a command to completion and returns (success, stdout, stderr).
pub fn run_capture(mut cmd: Command, stdin_data: Option<&[u8]>) -> (bool, String, String) {
    use std::io::Write;
    cmd.stdout(Stdio::piped()).stderr(Stdio::piped());
    cmd.stdin(if stdin_data.is_some() { Stdio::piped() } else { Stdio::null() });
    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => return (false, String::new(), e.to_string()),
    };
    if let (Some(data), Some(mut stdin)) = (stdin_data, child.stdin.take()) {
        let _ = stdin.write_all(data);
    }
    match child.wait_with_output() {
        Ok(out) => (
            out.status.success(),
            String::from_utf8_lossy(&out.stdout).to_string(),
            String::from_utf8_lossy(&out.stderr).to_string(),
        ),
        Err(e) => (false, String::new(), e.to_string()),
    }
}

pub fn home() -> PathBuf {
    PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/".to_string()))
}

pub fn config_home() -> PathBuf {
    match std::env::var("XDG_CONFIG_HOME") {
        Ok(x) if !x.is_empty() => PathBuf::from(x),
        _ => home().join(".config"),
    }
}

pub fn data_home() -> PathBuf {
    match std::env::var("XDG_DATA_HOME") {
        Ok(x) if !x.is_empty() => PathBuf::from(x),
        _ => home().join(".local/share"),
    }
}

pub fn cache_home() -> PathBuf {
    match std::env::var("XDG_CACHE_HOME") {
        Ok(x) if !x.is_empty() => PathBuf::from(x),
        _ => home().join(".cache"),
    }
}

/// `$XDG_DATA_DIRS`, defaulting as the spec says.
pub fn data_dirs() -> Vec<PathBuf> {
    let raw = std::env::var("XDG_DATA_DIRS").unwrap_or_default();
    let raw = if raw.trim().is_empty() { "/usr/local/share:/usr/share".to_string() } else { raw };
    let mut v: Vec<PathBuf> = raw.split(':').filter(|s| !s.is_empty()).map(PathBuf::from).collect();
    for extra in ["/run/current-system/sw/share", "/var/lib/flatpak/exports/share"] {
        let p = PathBuf::from(extra);
        if !v.contains(&p) {
            v.push(p);
        }
    }
    v
}

/// Writes a file atomically (temp file in the same folder + rename).
pub fn write_atomic(path: &Path, data: &[u8]) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    // Unique per call: concurrent writers must never share a temp file.
    static SEQ: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let tmp = path.with_file_name(format!(
        ".{}.loaf-tmp-{}-{}",
        path.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default(),
        std::process::id(),
        SEQ.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
    ));
    std::fs::write(&tmp, data)?;
    std::fs::rename(&tmp, path).map_err(|e| {
        let _ = std::fs::remove_file(&tmp);
        e
    })
}

/// Human readable byte count ("1.4 MB").
pub fn format_size(bytes: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];
    if bytes < 1024 {
        return format!("{} B", bytes);
    }
    let mut v = bytes as f64;
    let mut i = 0;
    while v >= 1024.0 && i < UNITS.len() - 1 {
        v /= 1024.0;
        i += 1;
    }
    format!("{:.1} {}", v, UNITS[i])
}

/// Filesystem type of the mount that holds `path`, from /proc/self/mounts text.
fn fstype_in(path: &std::path::Path, mounts: &str) -> Option<String> {
    let mut best: Option<(usize, String)> = None;
    for line in mounts.lines() {
        let mut parts = line.split_whitespace();
        let (Some(_), Some(mnt), Some(fstype)) = (parts.next(), parts.next(), parts.next()) else { continue };
        let mnt = crate::trash::unescape_mount(mnt);
        if path.starts_with(&mnt) && best.as_ref().map_or(true, |(len, _)| mnt.len() > *len) {
            best = Some((mnt.len(), fstype.to_string()));
        }
    }
    best.map(|(_, t)| t)
}

/// True for network and remote filesystems. A stat() there can hang for
/// minutes when the server is gone, so callers on the UI thread skip it.
pub fn on_network_fs(path: &std::path::Path) -> bool {
    on_network_fs_in(path, &mount_table())
}

/// /proc/self/mounts, for checking many paths with on_network_fs_in().
pub fn mount_table() -> String {
    std::fs::read_to_string("/proc/self/mounts").unwrap_or_default()
}

pub fn on_network_fs_in(path: &std::path::Path, mounts: &str) -> bool {
    fstype_in(path, mounts).is_some_and(|t| {
        matches!(t.as_str(), "nfs" | "nfs4" | "cifs" | "smb3" | "smbfs" | "9p" | "davfs" | "ceph" | "glusterfs" | "afs" | "sshfs")
            || (t.starts_with("fuse.") && !matches!(t.as_str(), "fuse.portal" | "fuse.gvfsd-fuse-local"))
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_the_mount_holding_a_path() {
        let mounts = "/dev/nvme0n1p6 / ext4 rw 0 0\nsrv:/share /mnt/nas nfs4 rw 0 0\n//pc/x /mnt/smb\\040disk cifs rw 0 0\n";
        assert_eq!(fstype_in(std::path::Path::new("/home/u"), mounts).as_deref(), Some("ext4"));
        assert_eq!(fstype_in(std::path::Path::new("/mnt/nas/a/b"), mounts).as_deref(), Some("nfs4"));
        assert_eq!(fstype_in(std::path::Path::new("/mnt/smb disk/f"), mounts).as_deref(), Some("cifs"));
    }

    #[test]
    fn finds_sh() {
        assert!(which("sh").is_some());
        assert!(which("definitely-not-a-real-binary-xyz").is_none());
    }

    #[test]
    fn sizes() {
        assert_eq!(format_size(0), "0 B");
        assert_eq!(format_size(1536), "1.5 KB");
        assert_eq!(format_size(5 * 1024 * 1024 * 1024), "5.0 GB");
    }

    #[test]
    fn atomic_write() {
        let p = std::env::temp_dir().join(format!("loaf-util-{}.txt", std::process::id()));
        write_atomic(&p, b"one").unwrap();
        write_atomic(&p, b"two").unwrap();
        assert_eq!(std::fs::read(&p).unwrap(), b"two");
        std::fs::remove_file(&p).unwrap();
    }
}
