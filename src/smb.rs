use crate::{state, util};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::Command;

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Profile {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub server: String,
    #[serde(default)]
    pub share: String,
    #[serde(default)]
    pub username: String,
    #[serde(default)]
    pub domain: String,
    #[serde(default)]
    pub remember: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct ProfileState {
    pub id: String,
    pub name: String,
    pub server: String,
    pub share: String,
    pub username: String,
    pub domain: String,
    pub connected: bool,
    pub path: String,
    pub label: String,
}

#[derive(Debug)]
pub struct MountError {
    pub message: String,
    pub needs_password: bool,
}

impl Profile {
    pub fn label(&self) -> String {
        if !self.name.trim().is_empty() {
            return self.name.trim().to_string();
        }
        let server = self.server.trim();
        let share = self.share.trim().trim_matches('/');
        if share.is_empty() {
            server.to_string()
        } else {
            format!("{}/{}", server, share)
        }
    }
}

pub fn new_id() -> String {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("{:x}{:x}", nanos, std::process::id())
}

pub fn profiles() -> Vec<Profile> {
    state::get("smbProfiles")
        .and_then(|s| serde_json::from_str::<Vec<Profile>>(&s).ok())
        .unwrap_or_default()
        .into_iter()
        .filter(|p| !p.id.is_empty() && !p.server.trim().is_empty())
        .collect()
}

pub fn save(list: &[Profile]) {
    state::set("smbProfiles", &serde_json::to_string(list).unwrap_or_else(|_| "[]".into()));
}

pub fn set_remember(id: &str, remember: bool) {
    let mut list = profiles();
    if let Some(profile) = list.iter_mut().find(|p| p.id == id) {
        if profile.remember != remember {
            profile.remember = remember;
            save(&list);
        }
    }
}

const GVFS_SCHEMA: &str = "org.gnome.keyring.NetworkPassword";

fn secret_tool() -> Option<PathBuf> {
    util::which("secret-tool")
}

fn split_server(value: &str) -> (&str, Option<u32>) {
    let value = value.trim();
    if let Some(rest) = value.strip_prefix('[') {
        if let Some((host, tail)) = rest.split_once(']') {
            let port = tail.strip_prefix(':').and_then(|p| p.parse::<u32>().ok());
            return (host, port);
        }
    }
    if let Some((host, port)) = value.rsplit_once(':') {
        if !host.contains(':') {
            if let Ok(port) = port.parse::<u32>() {
                return (host, Some(port));
            }
        }
    }
    (value, None)
}

fn keyring_attributes(profile: &Profile) -> Vec<String> {
    let (host, port) = split_server(&profile.server);
    let mut args = vec![
        "xdg:schema".to_string(),
        GVFS_SCHEMA.to_string(),
        "server".to_string(),
        host.to_string(),
        "protocol".to_string(),
        "smb".to_string(),
    ];
    let username = profile.username.trim();
    let domain = profile.domain.trim();
    if !username.is_empty() {
        args.push("user".to_string());
        args.push(username.to_string());
    }
    if !domain.is_empty() {
        args.push("domain".to_string());
        args.push(domain.to_string());
    }
    if let Some(port) = port {
        args.push("port".to_string());
        args.push(port.to_string());
    }
    args
}

pub fn saved_password(profile: &Profile) -> String {
    if profile.username.trim().is_empty() {
        return String::new();
    }
    let Some(tool) = secret_tool() else { return String::new() };
    let mut cmd = Command::new(tool);
    cmd.arg("lookup");
    cmd.args(keyring_attributes(profile));
    let (ok, out, _) = util::run_capture(cmd, None);
    if ok {
        out.trim_end_matches('\n').to_string()
    } else {
        String::new()
    }
}

pub fn store_password(profile: &Profile, password: &str) -> bool {
    if profile.username.trim().is_empty() || password.is_empty() {
        return false;
    }
    let Some(tool) = secret_tool() else { return false };
    let mut clear = Command::new(&tool);
    clear.arg("clear");
    clear.args(keyring_attributes(profile));
    let _ = util::run_capture(clear, None);
    let label = format!("Loaf: SMB share {}", profile.label());
    let mut cmd = Command::new(tool);
    cmd.args(["store", "--label", &label, "--collection", "default"]);
    cmd.args(keyring_attributes(profile));
    let (ok, _, _) = util::run_capture(cmd, Some(password.as_bytes()));
    ok
}

pub fn clear_password(profile: &Profile) {
    let Some(tool) = secret_tool() else { return };
    let mut cmd = Command::new(tool);
    cmd.arg("clear");
    cmd.args(keyring_attributes(profile));
    let _ = util::run_capture(cmd, None);
}

fn runtime_dir() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(format!("/run/user/{}", unsafe { libc::getuid() })))
}

fn gvfs_dir() -> PathBuf {
    runtime_dir().join("gvfs")
}

fn encode(value: &str) -> String {
    let mut out = String::new();
    for b in value.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => out.push(b as char),
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}

fn encode_path(value: &str) -> String {
    value
        .split('/')
        .filter(|part| !part.is_empty())
        .map(encode)
        .collect::<Vec<_>>()
        .join("/")
}

pub fn uri(profile: &Profile) -> String {
    let mut userinfo = String::new();
    let domain = profile.domain.trim();
    let username = profile.username.trim();
    if !username.is_empty() {
        if !domain.is_empty() {
            userinfo.push_str(&encode(domain));
            userinfo.push(';');
        }
        userinfo.push_str(&encode(username));
        userinfo.push('@');
    }
    let server = profile.server.trim();
    let share = encode_path(profile.share.trim());
    if share.is_empty() {
        format!("smb://{}{}/", userinfo, server)
    } else {
        format!("smb://{}{}/{}", userinfo, server, share)
    }
}

struct MountEntry {
    server: String,
    share: String,
    user: String,
    domain: String,
    port: Option<u32>,
}

fn parse_mount_entry(name: &str) -> Option<MountEntry> {
    let rest = name.strip_prefix("smb-share:")?;
    let mut server = String::new();
    let mut share = String::new();
    let mut user = String::new();
    let mut domain = String::new();
    let mut port = None;
    for part in rest.split(',') {
        let Some((key, value)) = part.split_once('=') else { continue };
        match key {
            "server" => server = value.to_string(),
            "share" => share = value.to_string(),
            "user" => user = value.to_string(),
            "domain" => domain = value.to_string(),
            "port" => port = value.parse::<u32>().ok(),
            _ => {}
        }
    }
    if server.is_empty() {
        return None;
    }
    Some(MountEntry { server, share, user, domain, port })
}

fn same(a: &str, b: &str) -> bool {
    a.eq_ignore_ascii_case(b)
}

pub fn connected_path(profile: &Profile) -> Option<PathBuf> {
    let dir = gvfs_dir();
    let entries = std::fs::read_dir(&dir).ok()?;
    let (want_server, want_port) = split_server(&profile.server);
    let want_share = profile.share.trim().trim_matches('/');
    let want_user = profile.username.trim();
    let want_domain = profile.domain.trim();
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().to_string();
        let Some(found) = parse_mount_entry(&name) else { continue };
        if !same(&found.server, want_server) {
            continue;
        }
        if found.port != want_port {
            continue;
        }
        if !same(found.share.trim_matches('/'), want_share) {
            continue;
        }
        if !want_user.is_empty() && !found.user.is_empty() && !same(&found.user, want_user) {
            continue;
        }
        if !want_domain.is_empty() && !found.domain.is_empty() && !same(&found.domain, want_domain) {
            continue;
        }
        let path = entry.path();
        if path.is_dir() {
            return Some(path);
        }
    }
    None
}

fn run_gio(args: &[String]) -> Result<String, String> {
    let bin = util::which("gio").ok_or("GVfs (gio) is not installed")?;
    let mut cmd = Command::new(bin);
    cmd.env("LC_MESSAGES", "C");
    cmd.args(args);
    let (ok, out, err) = util::run_capture(cmd, None);
    if ok {
        Ok(out)
    } else {
        let stderr_line = err.lines().map(str::trim).filter(|line| !line.is_empty()).last();
        let stdout_line = out.lines().map(str::trim).filter(|line| !line.is_empty()).last();
        let message = stderr_line
            .or(stdout_line)
            .unwrap_or("the share could not be mounted")
            .to_string();
        Err(message)
    }
}

fn needs_password(message: &str) -> bool {
    let lower = message.to_lowercase();
    lower.contains("password")
        || lower.contains("authentication")
        || lower.contains("credential")
        || lower.contains("login")
        || lower.contains("permission denied")
        || lower.contains("access denied")
}

pub fn mount(profile: &Profile) -> Result<String, MountError> {
    let target = uri(profile);
    if let Err(message) = run_gio(&["mount".to_string(), target]) {
        if !message.to_lowercase().contains("already mounted") {
            return Err(MountError { needs_password: needs_password(&message), message });
        }
    }
    for _ in 0..20 {
        if let Some(path) = connected_path(profile) {
            return Ok(path.to_string_lossy().to_string());
        }
        std::thread::sleep(std::time::Duration::from_millis(50));
    }
    Err(MountError {
        needs_password: false,
        message: format!("{} mounted, but its local folder was not found", profile.label()),
    })
}

pub fn unmount(profile: &Profile) -> Result<(), String> {
    if let Some(path) = connected_path(profile) {
        run_gio(&["mount".to_string(), "-u".to_string(), path.to_string_lossy().to_string()])?;
        return Ok(());
    }
    let target = uri(profile);
    match run_gio(&["mount".to_string(), "-u".to_string(), target]) {
        Ok(_) => Ok(()),
        Err(message) if message.to_lowercase().contains("not mounted") => Ok(()),
        Err(message) => Err(message),
    }
}

pub fn state_for(profile: &Profile) -> ProfileState {
    let path = connected_path(profile);
    ProfileState {
        id: profile.id.clone(),
        name: profile.name.clone(),
        server: profile.server.clone(),
        share: profile.share.clone(),
        username: profile.username.clone(),
        domain: profile.domain.clone(),
        connected: path.is_some(),
        path: path.map(|p| p.to_string_lossy().to_string()).unwrap_or_default(),
        label: profile.label(),
    }
}

pub fn list_json() -> String {
    let list: Vec<ProfileState> = profiles().iter().map(state_for).collect();
    serde_json::to_string(&list).unwrap_or_else(|_| "[]".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn profile() -> Profile {
        Profile {
            id: "one".into(),
            name: "Media".into(),
            server: "nas.local".into(),
            share: "media/movies".into(),
            username: "alice".into(),
            domain: "WORKGROUP".into(),
            remember: false,
        }
    }

    #[test]
    fn builds_uris() {
        assert_eq!(uri(&profile()), "smb://WORKGROUP;alice@nas.local/media/movies");
        let guest = Profile { username: String::new(), domain: String::new(), share: String::new(), ..profile() };
        assert_eq!(uri(&guest), "smb://nas.local/");
        let plain = Profile { domain: String::new(), ..profile() };
        assert_eq!(uri(&plain), "smb://alice@nas.local/media/movies");
        let spaced = Profile { share: "my media".into(), ..profile() };
        assert_eq!(uri(&spaced), "smb://WORKGROUP;alice@nas.local/my%20media");
    }

    #[test]
    fn builds_keyring_attributes() {
        assert_eq!(
            keyring_attributes(&profile()),
            vec![
                "xdg:schema",
                GVFS_SCHEMA,
                "server",
                "nas.local",
                "protocol",
                "smb",
                "user",
                "alice",
                "domain",
                "WORKGROUP",
            ]
        );
    }

    #[test]
    fn reads_mount_entries() {
        let entry = parse_mount_entry("smb-share:server=nas.local,share=media,user=alice").unwrap();
        assert_eq!(entry.server, "nas.local");
        assert_eq!(entry.share, "media");
        assert_eq!(entry.user, "alice");
        assert_eq!(entry.domain, "");
        assert_eq!(entry.port, None);
        assert!(parse_mount_entry("smb-share:share=media").is_none());
        let entry = parse_mount_entry("smb-share:domain=WORKGROUP,port=4455,server=127.0.0.1,share=media,user=archy").unwrap();
        assert_eq!(entry.port, Some(4455));
    }

    #[test]
    fn splits_server_ports() {
        assert_eq!(split_server("nas.local"), ("nas.local", None));
        assert_eq!(split_server("127.0.0.1:4455"), ("127.0.0.1", Some(4455)));
        assert_eq!(split_server("[fe80::1]:4455"), ("fe80::1", Some(4455)));
        assert_eq!(split_server("fe80::1"), ("fe80::1", None));
    }

    #[test]
    fn labels_fall_back_to_server_and_share() {
        let mut p = profile();
        p.name.clear();
        assert_eq!(p.label(), "nas.local/media/movies");
        p.share.clear();
        assert_eq!(p.label(), "nas.local");
    }
}
