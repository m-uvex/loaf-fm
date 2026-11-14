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
    if let Some(hit) = lock(&WHICH_CACHE)
        .get_or_insert_with(HashMap::new)
        .get(name)
    {
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
    let found = dirs
        .into_iter()
        .map(|d| d.join(name))
        .find(|c| is_executable(c));
    lock(&WHICH_CACHE)
        .get_or_insert_with(HashMap::new)
        .insert(name.to_string(), found.clone());
    found
}

/// True when `p` is a regular file with any execute bit set. Symlinks follow
/// their target; folders are never "executable" here.
pub fn is_executable(p: &Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    std::fs::metadata(p)
        .map(|m| m.is_file() && m.permissions().mode() & 0o111 != 0)
        .unwrap_or(false)
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
    cmd.stdin(if stdin_data.is_some() {
        Stdio::piped()
    } else {
        Stdio::null()
    });
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
    let raw = if raw.trim().is_empty() {
        "/usr/local/share:/usr/share".to_string()
    } else {
        raw
    };
    let mut v: Vec<PathBuf> = raw
        .split(':')
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .collect();
    for extra in [
        "/run/current-system/sw/share",
        "/var/lib/flatpak/exports/share",
    ] {
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
        path.file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default(),
        std::process::id(),
        SEQ.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
    ));
    std::fs::write(&tmp, data)?;
    std::fs::rename(&tmp, path).inspect_err(|_| {
        let _ = std::fs::remove_file(&tmp);
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

pub use crate::message::{Message, MessageArgument, MessageBody, MessageKey};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn atomic_write_roundtrip() {
        let tmp_dir = std::env::temp_dir().join(format!("loaf_util_atomic_{}", std::process::id()));
        let _ = std::fs::create_dir_all(&tmp_dir);
        let target = tmp_dir.join("test.txt");
        assert!(write_atomic(&target, b"content").is_ok());
        assert_eq!(std::fs::read(&target).unwrap(), b"content");
        let _ = std::fs::remove_dir_all(&tmp_dir);
    }

    #[test]
    fn is_executable_checks_mode() {
        use std::os::unix::fs::PermissionsExt;
        let tmp = std::env::temp_dir().join(format!("loaf_util_exec_{}", std::process::id()));
        std::fs::create_dir_all(&tmp).unwrap();
        let exe = tmp.join("prog");
        std::fs::write(&exe, b"#!/bin/sh\n").unwrap();
        std::fs::set_permissions(&exe, std::fs::Permissions::from_mode(0o755)).unwrap();
        assert!(is_executable(&exe));
        // Symlinks follow their target.
        let link = tmp.join("link-to-prog");
        std::os::unix::fs::symlink(&exe, &link).unwrap();
        assert!(is_executable(&link));
        std::fs::set_permissions(&exe, std::fs::Permissions::from_mode(0o644)).unwrap();
        assert!(!is_executable(&exe));
        // Folders are never runnable.
        assert!(!is_executable(&tmp));
        std::fs::remove_dir_all(&tmp).unwrap();
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
    #[test]
    fn messages_parse_as_single_json_object() {
        for (msg, key) in [
            (Message::key(MessageKey::InfoNoPreview), "info.no-preview"),
            (
                Message::key(MessageKey::InfoNoPreview)
                    .text("one")
                    .text("two"),
                "info.no-preview",
            ),
            (
                Message::list(vec![Message::key(MessageKey::InfoNoPreview)]),
                "list.join",
            ),
        ] {
            let text = msg.to_string();
            let parsed: serde_json::Value = serde_json::from_str(&text).unwrap();
            assert!(parsed.is_object());
            assert_eq!(parsed["key"], key);
            assert_eq!(parsed["v"], 1);
        }
        let parsed: serde_json::Value = serde_json::from_str(
            &Message::key(MessageKey::InfoNoPreview)
                .text("one")
                .to_string(),
        )
        .unwrap();
        assert_eq!(parsed["args"], serde_json::json!(["one"]));
    }

    #[test]
    fn raw_text_round_trips_literally() {
        let parsed: serde_json::Value =
            serde_json::from_str(&Message::raw("{\"key\":\"notify.cancelled\"}").to_string())
                .unwrap();
        assert_eq!(parsed["v"], 1);
        assert_eq!(parsed["raw"], "{\"key\":\"notify.cancelled\"}");
    }

    #[test]
    fn message_list_nests_messages_and_plain_text() {
        let items = vec![
            Message::key(MessageKey::PlaceHome),
            Message::raw("plain text"),
            Message::key(MessageKey::NotifyBookmarkAdded).text("arg"),
        ];
        let text = Message::list(items).to_string();
        let parsed: serde_json::Value = serde_json::from_str(&text).unwrap();
        assert_eq!(parsed["key"], "list.join");
        assert_eq!(parsed["args"][0]["key"], "place.home");
        assert_eq!(parsed["args"][1]["raw"], "plain text");
        assert_eq!(parsed["args"][2]["key"], "notify.bookmark-added");
        let nested = Message::key(MessageKey::OutcomeRestoreItemFailed)
            .text("100%2.txt")
            .nested(Message::key(MessageKey::InfoMissing))
            .to_string();
        let outer: serde_json::Value = serde_json::from_str(&nested).unwrap();
        assert_eq!(outer["args"][0], "100%2.txt");
        assert_eq!(outer["args"][1]["key"], "info.missing");
    }

    #[test]
    fn golden_message_serialization() {
        assert_eq!(
            Message::key(MessageKey::InfoNoPreview).to_string(),
            r#"{"key":"info.no-preview","v":1}"#
        );
        assert_eq!(
            Message::raw("{\"key\":\"notify.cancelled\"}").to_string(),
            r#"{"raw":"{\"key\":\"notify.cancelled\"}","v":1}"#
        );
        assert_eq!(
            Message::raw("{filename}.txt").to_string(),
            r#"{"raw":"{filename}.txt","v":1}"#
        );
        assert_eq!(
            Message::key(MessageKey::NotifyBookmarkAdded)
                .text("100%2.txt")
                .to_string(),
            r#"{"args":["100%2.txt"],"key":"notify.bookmark-added","v":1}"#
        );
        assert_eq!(
            Message::key(MessageKey::OutcomeRestoreItemFailed)
                .text("arg%1")
                .nested(Message::key(MessageKey::InfoMissing))
                .to_string(),
            r#"{"args":["arg%1",{"key":"info.missing","v":1}],"key":"outcome.restore-item-failed","v":1}"#
        );
        assert_eq!(
            Message::list(vec![
                Message::key(MessageKey::PlaceHome),
                Message::raw("plain text"),
                Message::key(MessageKey::NotifyBookmarkAdded).text("arg")
            ])
            .to_string(),
            r#"{"args":[{"key":"place.home","v":1},{"raw":"plain text","v":1},{"args":["arg"],"key":"notify.bookmark-added","v":1}],"key":"list.join","v":1}"#
        );
    }
}
