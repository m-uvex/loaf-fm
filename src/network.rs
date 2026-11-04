use crate::{state, util};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::Command;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Protocol {
    Smb,
    Webdav,
}

impl Default for Protocol {
    fn default() -> Self {
        Protocol::Smb
    }
}

impl Protocol {
    pub fn as_str(&self) -> &'static str {
        match self {
            Protocol::Smb => "smb",
            Protocol::Webdav => "webdav",
        }
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            Protocol::Smb => "SMB / CIFS",
            Protocol::Webdav => "WebDAV",
        }
    }

    pub fn icon(&self) -> &'static str {
        match self {
            Protocol::Smb => "network",
            Protocol::Webdav => "globe",
        }
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct NetworkProfile {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub protocol: Protocol,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub server: String,
    #[serde(default)]
    pub share: String, // SMB share name or WebDAV path (e.g. "/remote.php/webdav")
    #[serde(default)]
    pub username: String,
    #[serde(default)]
    pub domain: String, // SMB domain
    #[serde(default)]
    pub port: Option<u16>,
    #[serde(default = "default_ssl")]
    pub ssl: bool, // WebDAV https (davs://) vs http (dav://)
    #[serde(default)]
    pub remember: bool,
}

fn default_ssl() -> bool {
    true
}

#[derive(Clone, Debug, Serialize)]
pub struct NetworkProfileState {
    pub id: String,
    pub protocol: String,
    pub name: String,
    pub server: String,
    pub share: String,
    pub username: String,
    pub domain: String,
    pub port: Option<u16>,
    pub ssl: bool,
    pub connected: bool,
    pub path: String,
    pub label: String,
    pub icon: String,
}

#[derive(Debug)]
pub struct MountError {
    pub message: String,
    pub needs_password: bool,
}

impl NetworkProfile {
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

pub fn profiles() -> Vec<NetworkProfile> {
    // 1. Try reading unified networkProfiles
    if let Some(s) = state::get("networkProfiles") {
        if let Ok(list) = serde_json::from_str::<Vec<NetworkProfile>>(&s) {
            return list
                .into_iter()
                .filter(|p| !p.id.is_empty() && !p.server.trim().is_empty())
                .collect();
        }
    }

    // 2. Migration: Check legacy smbProfiles
    if let Some(s) = state::get("smbProfiles") {
        #[derive(Deserialize)]
        struct LegacySmbProfile {
            #[serde(default)]
            id: String,
            #[serde(default)]
            name: String,
            #[serde(default)]
            server: String,
            #[serde(default)]
            share: String,
            #[serde(default)]
            username: String,
            #[serde(default)]
            domain: String,
            #[serde(default)]
            remember: bool,
        }

        if let Ok(legacy_list) = serde_json::from_str::<Vec<LegacySmbProfile>>(&s) {
            let migrated: Vec<NetworkProfile> = legacy_list
                .into_iter()
                .filter(|p| !p.id.is_empty() && !p.server.trim().is_empty())
                .map(|p| NetworkProfile {
                    id: p.id,
                    protocol: Protocol::Smb,
                    name: p.name,
                    server: p.server,
                    share: p.share,
                    username: p.username,
                    domain: p.domain,
                    port: None,
                    ssl: false,
                    remember: p.remember,
                })
                .collect();
            if !migrated.is_empty() {
                save(&migrated);
                return migrated;
            }
        }
    }

    Vec::new()
}

pub fn save(list: &[NetworkProfile]) {
    let json = serde_json::to_string(list).unwrap_or_else(|_| "[]".into());
    state::set("networkProfiles", &json);
    // Maintain backwards compatibility for any legacy readers
    state::set("smbProfiles", &json);
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

pub fn split_server(value: &str) -> (&str, Option<u16>) {
    let value = value.trim();
    if let Some(rest) = value.strip_prefix('[') {
        if let Some((host, tail)) = rest.split_once(']') {
            let port = tail.strip_prefix(':').and_then(|p| p.parse::<u16>().ok());
            return (host, port);
        }
    }
    if let Some((host, port)) = value.rsplit_once(':') {
        if !host.contains(':') {
            if let Ok(port) = port.parse::<u16>() {
                return (host, Some(port));
            }
        }
    }
    (value, None)
}

fn keyring_attributes(profile: &NetworkProfile) -> Vec<String> {
    let (host, host_port) = split_server(&profile.server);
    let port = profile.port.or(host_port);

    match profile.protocol {
        Protocol::Smb => {
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
        Protocol::Webdav => {
            // GVfs gvfsbackenddav uses protocol "http" for both http and https NetworkPassword lookup
            let mut args = vec![
                "xdg:schema".to_string(),
                GVFS_SCHEMA.to_string(),
                "server".to_string(),
                host.to_string(),
                "protocol".to_string(),
                "http".to_string(),
            ];
            let username = profile.username.trim();
            if !username.is_empty() {
                args.push("user".to_string());
                args.push(username.to_string());
            }
            if let Some(port) = port {
                args.push("port".to_string());
                args.push(port.to_string());
            }
            args
        }
    }
}

pub fn saved_password(profile: &NetworkProfile) -> String {
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

pub fn store_password(profile: &NetworkProfile, password: &str) -> bool {
    if profile.username.trim().is_empty() || password.is_empty() {
        return false;
    }
    let Some(tool) = secret_tool() else { return false };
    let mut clear = Command::new(&tool);
    clear.arg("clear");
    clear.args(keyring_attributes(profile));
    let _ = util::run_capture(clear, None);
    let label = format!("Loaf: {} share {}", profile.protocol.display_name(), profile.label());
    let mut cmd = Command::new(tool);
    cmd.args(["store", "--label", &label, "--collection", "default"]);
    cmd.args(keyring_attributes(profile));
    let (ok, _, _) = util::run_capture(cmd, Some(password.as_bytes()));
    ok
}

pub fn clear_password(profile: &NetworkProfile) {
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

pub fn uri(profile: &NetworkProfile) -> String {
    let (host, host_port) = split_server(&profile.server);
    let port = profile.port.or(host_port);

    match profile.protocol {
        Protocol::Smb => {
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
            let host_port_str = if let Some(p) = port {
                if host.starts_with('[') && host.ends_with(']') {
                    format!("{}:{}", host, p)
                } else if host.contains(':') {
                    format!("[{}]:{}", host, p)
                } else {
                    format!("{}:{}", host, p)
                }
            } else {
                host.to_string()
            };
            let share = encode_path(profile.share.trim());
            if share.is_empty() {
                format!("smb://{}{}/", userinfo, host_port_str)
            } else {
                format!("smb://{}{}/{}", userinfo, host_port_str, share)
            }
        }
        Protocol::Webdav => {
            let scheme = if profile.ssl { "davs" } else { "dav" };
            let mut userinfo = String::new();
            let username = profile.username.trim();
            if !username.is_empty() {
                userinfo.push_str(&encode(username));
                userinfo.push('@');
            }
            let host_port_str = if let Some(p) = port {
                if host.starts_with('[') && host.ends_with(']') {
                    format!("{}:{}", host, p)
                } else if host.contains(':') {
                    format!("[{}]:{}", host, p)
                } else {
                    format!("{}:{}", host, p)
                }
            } else {
                host.to_string()
            };
            let mut path = profile.share.trim().to_string();
            if !path.is_empty() && !path.starts_with('/') {
                path = format!("/{}", path);
            }
            let encoded_path = encode_path(&path);
            if encoded_path.is_empty() {
                format!("{}://{}{}/", scheme, userinfo, host_port_str)
            } else {
                format!("{}://{}{}/{}", scheme, userinfo, host_port_str, encoded_path)
            }
        }
    }
}

struct SmbMountEntry {
    server: String,
    share: String,
    user: String,
    domain: String,
    port: Option<u16>,
}

fn parse_smb_mount_entry(name: &str) -> Option<SmbMountEntry> {
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
            "port" => port = value.parse::<u16>().ok(),
            _ => {}
        }
    }
    if server.is_empty() {
        return None;
    }
    Some(SmbMountEntry { server, share, user, domain, port })
}

struct DavMountEntry {
    host: String,
    ssl: bool,
    prefix: String,
    user: String,
    port: Option<u16>,
}

fn parse_dav_mount_entry(name: &str) -> Option<DavMountEntry> {
    let rest = name.strip_prefix("dav:")?;
    let mut host = String::new();
    let mut ssl = false;
    let mut prefix = String::new();
    let mut user = String::new();
    let mut port = None;
    for part in rest.split(',') {
        let Some((key, value)) = part.split_once('=') else { continue };
        match key {
            "host" => host = value.to_string(),
            "ssl" => ssl = value.eq_ignore_ascii_case("true"),
            "prefix" => prefix = value.to_string(),
            "user" => user = value.to_string(),
            "port" => port = value.parse::<u16>().ok(),
            _ => {}
        }
    }
    if host.is_empty() {
        return None;
    }
    Some(DavMountEntry { host, ssl, prefix, user, port })
}

fn same(a: &str, b: &str) -> bool {
    a.eq_ignore_ascii_case(b)
}

fn normalize_path_prefix(p: &str) -> String {
    let trimmed = p.trim().trim_matches('/');
    if trimmed.is_empty() {
        String::new()
    } else {
        format!("/{}", trimmed)
    }
}

pub fn connected_path(profile: &NetworkProfile) -> Option<PathBuf> {
    let dir = gvfs_dir();
    let entries = std::fs::read_dir(&dir).ok()?;
    let (want_host, host_port) = split_server(&profile.server);
    let want_port = profile.port.or(host_port);
    let want_user = profile.username.trim();

    match profile.protocol {
        Protocol::Smb => {
            let want_share = profile.share.trim().trim_matches('/');
            let want_domain = profile.domain.trim();
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                let Some(found) = parse_smb_mount_entry(&name) else { continue };
                if !same(&found.server, want_host) {
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
        }
        Protocol::Webdav => {
            let want_prefix = normalize_path_prefix(&profile.share);
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                let Some(found) = parse_dav_mount_entry(&name) else { continue };
                let found_host = found.host.trim_matches('[').trim_matches(']');
                let target_host = want_host.trim_matches('[').trim_matches(']');
                if !same(found_host, target_host) {
                    continue;
                }
                if found.ssl != profile.ssl {
                    continue;
                }
                if found.port != want_port {
                    continue;
                }
                let found_prefix = normalize_path_prefix(&found.prefix);
                if !same(&found_prefix, &want_prefix) {
                    continue;
                }
                if !want_user.is_empty() && !found.user.is_empty() && !same(&found.user, want_user) {
                    continue;
                }
                let path = entry.path();
                if path.is_dir() {
                    return Some(path);
                }
            }
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
        || lower.contains("not authorized")
}

pub fn mount(profile: &NetworkProfile) -> Result<String, MountError> {
    let target = uri(profile);
    if let Err(message) = run_gio(&["mount".to_string(), target.clone()]) {
        if !message.to_lowercase().contains("already mounted") {
            return Err(MountError {
                needs_password: needs_password(&message),
                message,
            });
        }
    }
    for _ in 0..25 {
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

pub fn unmount(profile: &NetworkProfile) -> Result<(), String> {
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

pub fn state_for(profile: &NetworkProfile) -> NetworkProfileState {
    let path = connected_path(profile);
    NetworkProfileState {
        id: profile.id.clone(),
        protocol: profile.protocol.as_str().to_string(),
        name: profile.name.clone(),
        server: profile.server.clone(),
        share: profile.share.clone(),
        username: profile.username.clone(),
        domain: profile.domain.clone(),
        port: profile.port,
        ssl: profile.ssl,
        connected: path.is_some(),
        path: path.map(|p| p.to_string_lossy().to_string()).unwrap_or_default(),
        label: profile.label(),
        icon: profile.protocol.icon().to_string(),
    }
}

pub fn list_json() -> String {
    let list: Vec<NetworkProfileState> = profiles().iter().map(state_for).collect();
    serde_json::to_string(&list).unwrap_or_else(|_| "[]".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn smb_uri_building() {
        let p = NetworkProfile {
            id: "smb1".into(),
            protocol: Protocol::Smb,
            name: "Media".into(),
            server: "nas.local".into(),
            share: "media/movies".into(),
            username: "alice".into(),
            domain: "WORKGROUP".into(),
            port: None,
            ssl: false,
            remember: false,
        };
        assert_eq!(uri(&p), "smb://WORKGROUP;alice@nas.local/media/movies");

        let p_port = NetworkProfile {
            port: Some(445),
            ..p.clone()
        };
        assert_eq!(uri(&p_port), "smb://WORKGROUP;alice@nas.local:445/media/movies");
    }

    #[test]
    fn webdav_uri_building() {
        let p = NetworkProfile {
            id: "dav1".into(),
            protocol: Protocol::Webdav,
            name: "Nextcloud".into(),
            server: "cloud.example.com".into(),
            share: "/remote.php/dav/files/alice/".into(),
            username: "alice".into(),
            domain: String::new(),
            port: None,
            ssl: true,
            remember: false,
        };
        assert_eq!(uri(&p), "davs://alice@cloud.example.com/remote.php/dav/files/alice");

        let p_insecure = NetworkProfile {
            ssl: false,
            port: Some(8080),
            share: "webdav".into(),
            username: String::new(),
            ..p.clone()
        };
        assert_eq!(uri(&p_insecure), "dav://cloud.example.com:8080/webdav");
    }

    #[test]
    fn parse_mount_entries() {
        let smb_entry = parse_smb_mount_entry("smb-share:server=nas.local,share=media,user=alice").unwrap();
        assert_eq!(smb_entry.server, "nas.local");
        assert_eq!(smb_entry.share, "media");
        assert_eq!(smb_entry.user, "alice");

        let dav_entry = parse_dav_mount_entry("dav:host=cloud.example.com,ssl=true,prefix=/remote.php/webdav,user=alice").unwrap();
        assert_eq!(dav_entry.host, "cloud.example.com");
        assert!(dav_entry.ssl);
        assert_eq!(dav_entry.prefix, "/remote.php/webdav");
        assert_eq!(dav_entry.user, "alice");
    }
}
