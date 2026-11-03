use crate::{state, util};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::{Duration, Instant};

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

/// A server found on the local network. Shares are filled in on a best-effort
/// basis (anonymous `smbclient -L`); a server with no listed shares is still
/// useful because the user can type a share name in the editor.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Discovered {
    #[serde(default)]
    pub server: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub address: String,
    #[serde(default)]
    pub shares: Vec<String>,
    #[serde(default)]
    pub source: String,
}

static DISCOVERED: Mutex<Vec<Discovered>> = Mutex::new(Vec::new());
static DISCOVERING: AtomicBool = AtomicBool::new(false);

const DISCOVERY_SETTING: &str = "smbAutoDiscovery";
const DISCOVERY_CACHE: &str = "smbDiscovered";
const DISCOVERY_IGNORED: &str = "smbDiscoveryIgnored";

pub fn discovery_enabled() -> bool {
    state::get_bool(DISCOVERY_SETTING, true)
}

pub fn set_discovery_enabled(enabled: bool) {
    state::set_bool(DISCOVERY_SETTING, enabled);
}

pub fn normalized_server(server: &str) -> String {
    let (host, _) = split_server(server);
    host.trim().trim_end_matches('.').to_ascii_lowercase()
}

fn ignored_servers() -> Vec<String> {
    state::get(DISCOVERY_IGNORED)
        .and_then(|s| serde_json::from_str::<Vec<String>>(&s).ok())
        .unwrap_or_default()
        .into_iter()
        .map(|s| normalized_server(&s))
        .filter(|s| !s.is_empty())
        .collect()
}

pub fn is_ignored(server: &str) -> bool {
    let key = normalized_server(server);
    !key.is_empty() && ignored_servers().iter().any(|s| s == &key)
}

pub fn set_ignored(server: &str, ignored: bool) {
    let key = normalized_server(server);
    if key.is_empty() {
        return;
    }
    let mut list = ignored_servers();
    let present = list.iter().any(|s| s == &key);
    if ignored && !present {
        list.push(key);
    } else if !ignored {
        list.retain(|s| s != &key);
    } else {
        return;
    }
    list.sort();
    list.dedup();
    state::set(DISCOVERY_IGNORED, &serde_json::to_string(&list).unwrap_or_else(|_| "[]".into()));
}

pub fn clear_ignored() {
    state::set(DISCOVERY_IGNORED, "[]");
}

pub fn ignored_count() -> usize {
    ignored_servers().len()
}

/// Loads the last scan from the settings file so the sidebar can show it
/// immediately at startup, before the first network scan finishes.
pub fn load_cached_discovery() {
    let mut cache = util::lock(&DISCOVERED);
    if !cache.is_empty() {
        return;
    }
    if let Some(raw) = state::get(DISCOVERY_CACHE) {
        if let Ok(mut list) = serde_json::from_str::<Vec<Discovered>>(&raw) {
            list.retain(|d| !d.server.trim().is_empty());
            *cache = list;
        }
    }
}

pub fn cached_discovered() -> Vec<Discovered> {
    util::lock(&DISCOVERED).clone()
}

fn store_discovered(list: &[Discovered]) {
    *util::lock(&DISCOVERED) = list.to_vec();
    state::set(DISCOVERY_CACHE, &serde_json::to_string(list).unwrap_or_else(|_| "[]".into()));
}

/// JSON for QML: adds whether a profile already exists and whether the user
/// hid this server. Ignored entries are kept so Settings can offer "Unhide".
pub fn discovered_json() -> String {
    let saved: std::collections::HashSet<String> =
        profiles().iter().map(|p| normalized_server(&p.server)).collect();
    let ignored = ignored_servers();
    let mut list = cached_discovered();
    list.sort_by(|a, b| {
        let an = if a.name.trim().is_empty() { &a.server } else { &a.name };
        let bn = if b.name.trim().is_empty() { &b.server } else { &b.name };
        an.to_ascii_lowercase().cmp(&bn.to_ascii_lowercase()).then_with(|| a.server.cmp(&b.server))
    });
    let items: Vec<serde_json::Value> = list
        .iter()
        .map(|d| {
            let key = normalized_server(&d.server);
            let name = if d.name.trim().is_empty() { d.server.clone() } else { d.name.clone() };
            serde_json::json!({
                "server": d.server,
                "name": name,
                "address": d.address,
                "shares": d.shares,
                "source": d.source,
                "saved": saved.contains(&key),
                "ignored": ignored.iter().any(|s| s == &key),
            })
        })
        .collect();
    serde_json::to_string(&items).unwrap_or_else(|_| "[]".into())
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

/// Runs a command with a hard time limit. `timeout` comes from coreutils and
/// is present on effectively every Linux desktop; without it, commands that
/// implement their own timeout (Avahi's `-t`) still run.
fn run_timed(program: &str, args: &[&str], timeout_secs: u64) -> Option<String> {
    let bin = util::which(program)?;
    let mut cmd = if timeout_secs > 0 {
        let timeout = util::which("timeout")?;
        let mut c = Command::new(timeout);
        c.arg(timeout_secs.to_string()).arg(&bin).args(args);
        c
    } else {
        let mut c = Command::new(&bin);
        c.args(args);
        c
    };
    cmd.env("LC_ALL", "C").env("LC_MESSAGES", "C");
    let (ok, out, _) = util::run_capture(cmd, None);
    if ok {
        Some(out)
    } else {
        None
    }
}

fn add_found(
    found: &mut BTreeMap<String, Discovered>,
    server: String,
    name: String,
    address: String,
    source: &str,
) {
    let key = normalized_server(&server);
    if key.is_empty() {
        return;
    }
    // mDNS reports the same host once per address (IPv4/IPv6); NetBIOS and
    // GVfs report the same host under another name. Merge them by address as
    // well so the sidebar does not show duplicates.
    let existing = found.iter().find_map(|(k, d)| {
        let same_server = k == &key;
        let same_address =
            !address.is_empty() && !d.address.is_empty() && d.address.eq_ignore_ascii_case(&address);
        if same_server || same_address {
            Some(k.clone())
        } else {
            None
        }
    });
    let key = existing.unwrap_or(key);
    let entry = found.entry(key).or_insert_with(|| Discovered {
        server: server.clone(),
        name: name.clone(),
        address: address.clone(),
        shares: Vec::new(),
        source: source.to_string(),
    });
    if entry.name.trim().is_empty() || (entry.name == entry.server && !name.is_empty()) {
        entry.name = name;
    }
    if entry.address.is_empty() && !address.is_empty() {
        entry.address = address;
    }
    // Prefer a DNS/mDNS hostname over a bare NetBIOS name, since it resolves
    // the same way but also works with `smb://host.local/` style URIs.
    if server.contains('.') && !entry.server.contains('.') && !entry.server.contains(':') && !server.contains(':') {
        entry.server = server;
    }
    if source == "mdns" || entry.source.is_empty() {
        entry.source = source.to_string();
    }
}

fn parse_avahi_line(line: &str, found: &mut BTreeMap<String, Discovered>) {
    let mut parts = line.split(';');
    if parts.next() != Some("=") {
        return;
    }
    let _interface = parts.next();
    let _protocol = parts.next();
    let name = parts.next().unwrap_or("").trim();
    let service = parts.next().unwrap_or("").trim();
    let _domain = parts.next();
    let host = parts.next().unwrap_or("").trim();
    let address = parts.next().unwrap_or("").trim();
    if !matches!(service, "_smb._tcp" | "_nmb._tcp" | "_workstation._tcp") {
        return;
    }
    let server = if host.is_empty() {
        address.trim_end_matches('.').to_string()
    } else {
        host.trim_end_matches('.').to_string()
    };
    if server.is_empty() {
        return;
    }
    add_found(found, server, name.to_string(), address.to_string(), "mdns");
}

fn parse_nmblookup(out: &str, found: &mut BTreeMap<String, Discovered>) {
    for line in out.lines() {
        let line = line.trim();
        let mut fields = line.split_whitespace();
        let Some(address) = fields.next() else { continue };
        if !address.chars().next().map(|c| c.is_ascii_digit()).unwrap_or(false) {
            continue;
        }
        let Some(record) = fields.next() else { continue };
        let Some((name, suffix)) = record.rsplit_once('<') else { continue };
        let suffix = suffix.trim_end_matches('>');
        if suffix != "00" && suffix != "20" {
            continue;
        }
        let name = name.trim();
        if name.is_empty() || name.eq_ignore_ascii_case("__MSBROWSE__") {
            continue;
        }
        add_found(found, name.to_string(), name.to_string(), address.to_string(), "netbios");
    }
}

/// Text between `<tag ...>` and `</tag>`, tolerating attributes on the
/// opening tag. Used for the small set of WS-Discovery elements we need; a
/// full XML parser would be overkill for one short UDP datagram.
fn tag_text<'a>(xml: &'a str, tag: &str) -> Option<&'a str> {
    let open = format!("<{tag}");
    let close = format!("</{tag}>");
    let mut from = 0;
    loop {
        let start = from + xml.get(from..)?.find(&open)?;
        let after = &xml[start + open.len()..];
        // `<d:XAddrs` must not match `<d:XAddrsFoo`.
        match after.as_bytes().first().copied() {
            Some(b'>') | Some(b' ') | Some(b'\t') | Some(b'\n') | Some(b'\r') => {}
            _ => {
                from = start + open.len();
                continue;
            }
        }
        let gt = after.find('>')?;
        let content = start + open.len() + gt + 1;
        let end = content + xml.get(content..)?.find(&close)?;
        return Some(&xml[content..end]);
    }
}

/// First host from an `http://host:port/path` address, handling bracketed
/// IPv6 literals.
fn host_from_url(url: &str) -> Option<String> {
    let rest = url.split_once("://").map(|(_, r)| r).unwrap_or(url);
    let authority = rest.split(['/', '?', '#']).next()?.trim();
    if authority.is_empty() {
        return None;
    }
    if let Some(stripped) = authority.strip_prefix('[') {
        let end = stripped.find(']')?;
        return Some(stripped[..end].to_string());
    }
    let host = authority.split(':').next().unwrap_or("").trim();
    if host.is_empty() {
        None
    } else {
        Some(host.to_string())
    }
}

fn parse_ws_discovery_response(xml: &str, found: &mut BTreeMap<String, Discovered>) {
    let computer = tag_text(xml, "wsdp:Computer")
        .map(|s| s.trim())
        .filter(|s| !s.is_empty());
    let Some(addrs) = tag_text(xml, "d:XAddrs") else { return };
    for url in addrs.split_whitespace() {
        let Some(address) = host_from_url(url) else { continue };
        // The computer name (NetBIOS/DNS) is more useful for SMB than the
        // WS-Discovery HTTP address; keep the address for merging/deduping.
        let name = computer.unwrap_or(&address).to_string();
        add_found(found, name.clone(), name, address, "ws-discovery");
    }
}

fn ws_probe_message() -> String {
    // MessageID only needs to be unique per probe; time + pid is enough and
    // avoids pulling in a UUID crate.
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let pid = std::process::id() as u128;
    let raw = nanos ^ (pid << 64);
    let hex = format!("{raw:032x}");
    let uuid = format!("{}-{}-{}-{}-{}", &hex[0..8], &hex[8..12], &hex[12..16], &hex[16..20], &hex[20..32]);
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
 xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
 xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
 xmlns:wsdp="http://schemas.xmlsoap.org/ws/2006/02/devprof">
 <e:Header>
  <w:MessageID>uuid:{uuid}</w:MessageID>
  <w:To e:mustUnderstand="true">urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
  <w:Action e:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>
 </e:Header>
 <e:Body>
  <d:Probe><d:Types>wsdp:Device</d:Types></d:Probe>
 </e:Body>
</e:Envelope>"#
    )
}

/// Sends a WS-Discovery multicast probe and collects ProbeMatch replies. This
/// finds devices that do not advertise over mDNS or NetBIOS; it is best
/// effort, because many networks filter multicast.
fn ws_discovery(found: &mut BTreeMap<String, Discovered>) {
    use std::net::{SocketAddr, UdpSocket};
    let Ok(socket) = UdpSocket::bind(("0.0.0.0", 0)) else { return };
    let _ = socket.set_multicast_ttl_v4(2);
    let Ok(target) = "239.255.255.250:3702".parse::<SocketAddr>() else { return };
    let probe = ws_probe_message();
    let deadline = Instant::now() + Duration::from_millis(1800);
    for _ in 0..2 {
        if socket.send_to(probe.as_bytes(), target).is_err() {
            return;
        }
        std::thread::sleep(Duration::from_millis(120));
    }
    let mut buf = [0u8; 8192];
    while let Some(remaining) = deadline.checked_duration_since(Instant::now()) {
        if remaining.is_zero() || socket.set_read_timeout(Some(remaining)).is_err() {
            break;
        }
        match socket.recv_from(&mut buf) {
            Ok((n, _)) => {
                if let Ok(text) = std::str::from_utf8(&buf[..n]) {
                    parse_ws_discovery_response(text, found);
                }
            }
            Err(_) => break,
        }
    }
}

fn parse_gio_network(out: &str, found: &mut BTreeMap<String, Discovered>) {
    for line in out.lines() {
        let uri = line.trim();
        let Some(rest) = uri.strip_prefix("smb://") else { continue };
        let server = rest.split('/').next().unwrap_or("").trim();
        if server.is_empty() {
            continue;
        }
        add_found(found, server.to_string(), server.to_string(), String::new(), "gvfs");
    }
}

fn parse_smbclient_shares(out: &str) -> Vec<String> {
    let mut shares = Vec::new();
    for line in out.lines() {
        let mut fields = line.trim().split('|');
        let Some(kind) = fields.next() else { continue };
        let Some(name) = fields.next() else { continue };
        if !kind.eq_ignore_ascii_case("Disk") {
            continue;
        }
        let name = name.trim();
        if name.is_empty() || name.ends_with('$') {
            continue;
        }
        if !shares.iter().any(|s: &String| s.eq_ignore_ascii_case(name)) {
            shares.push(name.to_string());
        }
    }
    shares.sort_by(|a, b| a.to_ascii_lowercase().cmp(&b.to_ascii_lowercase()));
    shares
}

fn list_shares(server: &str) -> Vec<String> {
    let target = format!("//{}", server);
    run_timed("smbclient", &["-L", &target, "-N", "-g"], 4)
        .map(|out| parse_smbclient_shares(&out))
        .unwrap_or_default()
}

fn discover_inner() -> Vec<Discovered> {
    let mut found: BTreeMap<String, Discovered> = BTreeMap::new();

    // Avahi/mDNS: Samba and most NAS boxes advertise `_smb._tcp`.
    for service in ["_smb._tcp", "_nmb._tcp", "_workstation._tcp"] {
        if let Some(out) = run_timed("avahi-browse", &["-rtp", service], 0) {
            for line in out.lines() {
                parse_avahi_line(line, &mut found);
            }
        }
    }

    // NetBIOS broadcast: finds Windows machines that do not speak mDNS.
    if let Some(out) = run_timed("nmblookup", &["*"], 0) {
        parse_nmblookup(&out, &mut found);
    }

    // WS-Discovery: Windows and many NAS boxes answer this even when mDNS is
    // unavailable. Pure std so no extra dependency is needed.
    ws_discovery(&mut found);

    // GVfs' network neighbourhood is a useful fallback on desktops without
    // Avahi or Samba's command-line tools installed.
    if let Some(out) = run_timed("gio", &["list", "network:///"], 4) {
        parse_gio_network(&out, &mut found);
    }

    let mut list: Vec<Discovered> = found.into_values().collect();
    // Shotgunning `smbclient` at an entire large subnet is pointless; keep the
    // scan bounded even on unusual networks.
    list.truncate(64);
    if !list.is_empty() && util::which("smbclient").is_some() && util::which("timeout").is_some() {
        let enumerated: Vec<(usize, Vec<String>)> = std::thread::scope(|scope| {
            let handles: Vec<_> = list
                .iter()
                .enumerate()
                .map(|(i, d)| {
                    let server = d.server.clone();
                    scope.spawn(move || (i, list_shares(&server)))
                })
                .collect();
            handles.into_iter().filter_map(|h| h.join().ok()).collect()
        });
        for (i, shares) in enumerated {
            if let Some(entry) = list.get_mut(i) {
                entry.shares = shares;
            }
        }
    }
    list.retain(|d| !d.server.trim().is_empty());
    list.sort_by(|a, b| a.server.to_ascii_lowercase().cmp(&b.server.to_ascii_lowercase()));
    list
}

/// Scans the LAN. Returns `None` when discovery is disabled or another scan
/// is already running. Results are cached in memory and under
/// `$XDG_CONFIG_HOME/loaf/config.json`.
pub fn discover_now() -> Option<Vec<Discovered>> {
    if !discovery_enabled() {
        return None;
    }
    if DISCOVERING.swap(true, Ordering::SeqCst) {
        return None;
    }
    struct Reset;
    impl Drop for Reset {
        fn drop(&mut self) {
            DISCOVERING.store(false, Ordering::SeqCst);
        }
    }
    let _reset = Reset;
    let list = discover_inner();
    store_discovered(&list);
    Some(list)
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

    #[test]
    fn reads_avahi_records() {
        let mut found = BTreeMap::new();
        parse_avahi_line("=;eth0;IPv4;NAS;_smb._tcp;local;nas.local;192.168.1.5;445;", &mut found);
        parse_avahi_line("=;eth0;IPv4;NAS;_smb._tcp;local;nas.local;fe80::1;445;", &mut found);
        parse_avahi_line("=;eth0;IPv4;Printer;_ipp._tcp;local;printer.local;192.168.1.9;631;", &mut found);
        let list: Vec<&Discovered> = found.values().collect();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].server, "nas.local");
        assert_eq!(list[0].name, "NAS");
        assert_eq!(list[0].address, "192.168.1.5");
    }

    #[test]
    fn reads_nmblookup_hosts_and_merges_by_address() {
        let mut found = BTreeMap::new();
        parse_nmblookup(
            "querying * on 192.168.1.255\n192.168.1.5 NAS<00>\n192.168.1.5 NAS<20>\n192.168.1.7 DESKTOP<00>\n",
            &mut found,
        );
        assert_eq!(found.len(), 2);
        assert!(found.values().any(|d| d.server == "NAS" && d.address == "192.168.1.5"));
        assert!(found.values().any(|d| d.server == "DESKTOP"));
    }

    #[test]
    fn merges_mdns_names_with_netbios_addresses() {
        let mut found = BTreeMap::new();
        parse_nmblookup("192.168.1.5 NAS<00>\n", &mut found);
        parse_avahi_line("=;eth0;IPv4;NAS;_smb._tcp;local;nas.local;192.168.1.5;445;", &mut found);
        let list: Vec<&Discovered> = found.values().collect();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].server, "nas.local");
        assert_eq!(list[0].name, "NAS");
    }

    #[test]
    fn reads_gio_network_servers() {
        let mut found = BTreeMap::new();
        parse_gio_network("smb://nas.local/\ndns-sd://printer/\nsmb://\n", &mut found);
        let list: Vec<&Discovered> = found.values().collect();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].server, "nas.local");
    }

    #[test]
    fn reads_smbclient_share_list() {
        let out = "\
Disk|media|Media library
Disk|backup|Snapshots
IPC|IPC$|IPC Service
Disk|print$|Printer drivers
Disk|MEDIA|Duplicate
";
        assert_eq!(parse_smbclient_shares(out), vec!["backup", "media"]);
    }

    #[test]
    fn reads_ws_discovery_responses() {
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
 xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
 xmlns:wsdp="http://schemas.xmlsoap.org/ws/2006/02/devprof">
 <soap:Body>
  <d:ProbeMatches><d:ProbeMatch>
   <d:XAddrs>http://192.168.1.5:5357/abc/</d:XAddrs>
   <wsdp:Computer>STUDIO</wsdp:Computer>
  </d:ProbeMatch></d:ProbeMatches>
 </soap:Body>
</soap:Envelope>"#;
        let mut found = BTreeMap::new();
        parse_ws_discovery_response(xml, &mut found);
        let list: Vec<&Discovered> = found.values().collect();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].server, "STUDIO");
        assert_eq!(list[0].name, "STUDIO");
        assert_eq!(list[0].address, "192.168.1.5");
        assert_eq!(list[0].source, "ws-discovery");
    }

    #[test]
    fn extracts_hosts_from_urls() {
        assert_eq!(host_from_url("http://192.168.1.5:5357/abc/"), Some("192.168.1.5".into()));
        assert_eq!(host_from_url("http://[fe80::1]:5357/x"), Some("fe80::1".into()));
        assert_eq!(host_from_url("http://nas.local/"), Some("nas.local".into()));
        assert_eq!(host_from_url(""), None);
    }

    #[test]
    fn ignores_unrelated_tags_with_the_same_prefix() {
        let xml = "<d:XAddrsFoo>nope</d:XAddrsFoo><d:XAddrs>http://10.0.0.2:1/x</d:XAddrs>";
        assert_eq!(tag_text(xml, "d:XAddrs"), Some("http://10.0.0.2:1/x"));
    }
}
