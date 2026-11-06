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

/// A typed argument to `msg_args`: plain user text or a nested message.
pub enum MessageArg {
    Text(String),
    Message(String),
}

impl From<&str> for MessageArg {
    fn from(text: &str) -> Self {
        MessageArg::Text(text.to_string())
    }
}

impl From<String> for MessageArg {
    fn from(text: String) -> Self {
        MessageArg::Text(text)
    }
}

impl From<&String> for MessageArg {
    fn from(text: &String) -> Self {
        MessageArg::Text(text.clone())
    }
}

/// Serializes a translation key for resolution in QML (`theme.resolveRustMessage`).
pub fn msg(key: &str) -> String {
    serde_json::json!({ "v": 1, "key": key }).to_string()
}

/// Wraps user-controlled text so QML shows it literally, never as a key.
pub fn raw(text: &str) -> String {
    serde_json::json!({ "v": 1, "raw": text }).to_string()
}

/// Serializes a translation key with typed arguments for resolution in QML.
pub fn msg_args(key: &str, args: &[MessageArg]) -> String {
    let values: Vec<serde_json::Value> = args
        .iter()
        .map(|arg| match arg {
            MessageArg::Text(text) => serde_json::Value::String(text.clone()),
            MessageArg::Message(message) => serde_json::from_str(message).unwrap_or_else(|_| serde_json::Value::String(message.clone())),
        })
        .collect();
    serde_json::json!({ "v": 1, "key": key, "args": values }).to_string()
}

/// Serializes several messages or plain texts joined with "; " in QML.
pub fn msg_list(items: &[String]) -> String {
    let values: Vec<serde_json::Value> = items
        .iter()
        .map(|item| {
            let parsed: serde_json::Value = serde_json::from_str(item).unwrap_or_else(|_| serde_json::Value::String(item.clone()));
            if parsed.is_object() && parsed.get("v") == Some(&serde_json::json!(1)) {
                parsed
            } else {
                serde_json::Value::String(item.clone())
            }
        })
        .collect();
    serde_json::json!({ "v": 1, "key": "list.join", "args": values }).to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

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
        for (text, key) in [
            (msg("example.key"), "example.key"),
            (msg_args("example.key", &[MessageArg::Text("one".to_string()), MessageArg::Text("two".to_string())]), "example.key"),
            (msg_list(&[msg("example.key")]), "list.join"),
        ] {
            let parsed: serde_json::Value = serde_json::from_str(&text).unwrap();
            assert!(parsed.is_object());
            assert_eq!(parsed["key"], key);
            assert_eq!(parsed["v"], 1);
        }
        let parsed: serde_json::Value = serde_json::from_str(&msg_args("example.key", &[MessageArg::Text("one".to_string())])).unwrap();
        assert_eq!(parsed["args"], serde_json::json!(["one"]));
    }

    #[test]
    fn raw_text_round_trips_literally() {
        let parsed: serde_json::Value = serde_json::from_str(&raw("{\"key\":\"notify.cancelled\"}")).unwrap();
        assert_eq!(parsed["v"], 1);
        assert_eq!(parsed["raw"], "{\"key\":\"notify.cancelled\"}");
    }

    #[test]
    fn message_list_nests_messages_and_plain_text() {
        let items = [msg("first.key"), "plain text".to_string(), msg_args("second.key", &[MessageArg::Text("arg".to_string())])];
        let parsed: serde_json::Value = serde_json::from_str(&msg_list(&items)).unwrap();
        assert_eq!(parsed["key"], "list.join");
        assert_eq!(parsed["args"][0]["key"], "first.key");
        assert_eq!(parsed["args"][1], "plain text");
        assert_eq!(parsed["args"][2]["key"], "second.key");
        let nested = msg_args("outer.key", &[MessageArg::Message(msg("inner.key")), MessageArg::Text("100%2.txt".to_string())]);
        let outer: serde_json::Value = serde_json::from_str(&nested).unwrap();
        assert_eq!(outer["args"][0]["key"], "inner.key");
        assert_eq!(outer["args"][1], "100%2.txt");
    }

    fn looks_like_key(key: &str) -> bool {
        const PREFIXES: &[&str] = &["archive", "drive", "info", "list", "name", "notify", "op", "outcome", "pane", "place", "share", "trash"];
        let mut parts = key.split('.');
        if !parts.next().map(|value| PREFIXES.contains(&value)).unwrap_or(false) {
            return false;
        }
        let rest: Vec<&str> = parts.collect();
        !rest.is_empty() && rest.iter().all(|part| !part.is_empty() && part.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-' || c == '_'))
    }

    fn string_literals(source: &str) -> Vec<String> {
        let mut literals = Vec::new();
        let bytes: Vec<char> = source.chars().collect();
        let mut index = 0usize;
        while index < bytes.len() {
            if bytes[index] != '"' {
                index += 1;
                continue;
            }
            index += 1;
            let mut literal = String::new();
            while index < bytes.len() {
                let current = bytes[index];
                index += 1;
                if current == '\\' {
                    if index < bytes.len() {
                        let escaped = bytes[index];
                        index += 1;
                        match escaped {
                            'n' => literal.push('\n'),
                            't' => literal.push('\t'),
                            '"' => literal.push('"'),
                            '\\' => literal.push('\\'),
                            other => {
                                literal.push('\\');
                                literal.push(other);
                            }
                        }
                    }
                } else if current == '"' {
                    break;
                } else {
                    literal.push(current);
                }
            }
            literals.push(literal);
        }
        literals
    }

    #[test]
    fn rust_and_qml_message_keys_match() {
        use std::collections::{BTreeMap, BTreeSet};
        use std::path::{Path, PathBuf};
        fn visit(directory: &Path, keys: &mut BTreeMap<String, Vec<String>>) {
            let Ok(entries) = std::fs::read_dir(directory) else {
                return;
            };
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    visit(&path, keys);
                } else if path.extension().and_then(|extension| extension.to_str()) == Some("rs") {
                    if let Ok(source) = std::fs::read_to_string(&path) {
                        let code = &source[..source.find("#[cfg(test)]").unwrap_or(source.len())];
                        let code = code.replace(r#".trim_matches('"')"#, "").replace("'/'", "\"/\"").replace("'\\n'", "\"\\n\"");
                        for literal in string_literals(&code) {
                            if looks_like_key(&literal) {
                                keys.entry(literal).or_default().push(path.display().to_string());
                            }
                        }
                    }
                }
            }
        }
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let mut rust_keys: BTreeMap<String, Vec<String>> = BTreeMap::new();
        visit(&root.join("src"), &mut rust_keys);
        let mut qml_keys: BTreeMap<String, Vec<String>> = BTreeMap::new();
        let theme = std::fs::read_to_string(root.join("qml/Theme.qml")).expect("qml/Theme.qml");
        for literal in string_literals(&theme) {
            if looks_like_key(&literal) {
                qml_keys.entry(literal).or_default().push("qml/Theme.qml".to_string());
            }
        }
        let rust_set: BTreeSet<&String> = rust_keys.keys().collect();
        let qml_set: BTreeSet<&String> = qml_keys.keys().collect();
        let only_rust: Vec<&String> = rust_set.difference(&qml_set).copied().collect();
        let only_qml: Vec<&String> = qml_set.difference(&rust_set).copied().collect();
        assert!(only_rust.is_empty() && only_qml.is_empty(), "message key mismatch\nRust-only keys:\n{}\nQML-only keys:\n{}", only_rust.iter().map(|key| format!("  {key}  <- {:?}", rust_keys.get(*key).unwrap())).collect::<Vec<_>>().join("\n"), only_qml.iter().map(|key| format!("  {key}  <- {:?}", qml_keys.get(*key).unwrap())).collect::<Vec<_>>().join("\n"));
    }
}
