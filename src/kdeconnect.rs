//! KDE Connect integration: list reachable devices, mount SFTP, share files.

use crate::drives::Drive;
use crate::message::Message;
use crate::util;
use std::path::Path;
use std::process::Command;

#[derive(Clone, Debug)]
pub struct ConnectedDevice {
    pub id: String,
    pub name: String,
    pub device_type: String,
    pub mount_point: String,
    pub is_mounted: bool,
}

fn kdeconnect_cli() -> Option<std::path::PathBuf> {
    util::which("kdeconnect-cli")
}

pub fn is_available() -> bool {
    kdeconnect_cli().is_some()
}

fn run_kdeconnect(args: &[&str]) -> Result<String, String> {
    let bin = kdeconnect_cli().ok_or_else(|| "kdeconnect-cli not found".to_string())?;
    let mut cmd = Command::new(bin);
    cmd.args(args);
    let (ok, out, err) = util::run_capture(cmd, None);
    if ok {
        Ok(out)
    } else {
        let msg = err
            .lines()
            .map(str::trim)
            .rfind(|l| !l.is_empty())
            .or_else(|| out.lines().map(str::trim).rfind(|l| !l.is_empty()))
            .unwrap_or("kdeconnect-cli failed");
        Err(msg.to_string())
    }
}

fn dbus_get_string(device_id: &str, property: &str) -> Option<String> {
    let path = format!("/modules/kdeconnect/devices/{}", device_id);
    // Try gdbus first, then qdbus variants.
    let gdbus = util::which("gdbus");
    if let Some(bin) = gdbus {
        let mut cmd = Command::new(bin);
        cmd.args([
            "call",
            "--session",
            "--dest",
            "org.kde.kdeconnect",
            "--object-path",
            &path,
            "--method",
            "org.freedesktop.DBus.Properties.Get",
            "org.kde.kdeconnect.device",
            property,
        ]);
        let (ok, out, _) = util::run_capture(cmd, None);
        if ok {
            if let Some(v) = parse_gdbus_variant_string(&out) {
                return Some(v);
            }
        }
    }
    for name in ["qdbus6", "qdbus-qt6", "qdbus"] {
        let Some(bin) = util::which(name) else {
            continue;
        };
        let mut cmd = Command::new(bin);
        cmd.args([
            "org.kde.kdeconnect",
            &path,
            &format!("org.kde.kdeconnect.device.{}", property),
        ]);
        let (ok, out, _) = util::run_capture(cmd, None);
        if ok {
            let v = out.trim();
            if !v.is_empty() {
                return Some(v.to_string());
            }
        }
    }
    None
}

fn parse_gdbus_variant_string(out: &str) -> Option<String> {
    // gdbus prints: (<'phone'>,) or (<'value'>,)
    let s = out.trim();
    let start = s.find('\'')?;
    let rest = &s[start + 1..];
    let end = rest.rfind('\'')?;
    Some(rest[..end].to_string())
}

fn device_type(id: &str) -> String {
    dbus_get_string(id, "type").unwrap_or_else(|| "phone".to_string())
}

fn mount_point(id: &str) -> Option<String> {
    let out = run_kdeconnect(&["-d", id, "--get-mount-point"]).ok()?;
    let p = out.lines().map(str::trim).find(|l| !l.is_empty())?;
    let path = Path::new(p);
    if path.is_dir() {
        Some(p.to_string())
    } else {
        None
    }
}

pub fn device_uri(id: &str) -> String {
    format!("kdeconnect://{}", id)
}

pub fn parse_device_id(uri: &str) -> Option<&str> {
    uri.strip_prefix("kdeconnect://").filter(|id| !id.is_empty() && id.chars().all(|c| c.is_ascii_hexdigit()))
}

pub fn list_reachable() -> Vec<ConnectedDevice> {
    let Some(_) = kdeconnect_cli() else {
        return vec![];
    };
    let out = match run_kdeconnect(&["-a", "--id-name-only"]) {
        Ok(o) => o,
        Err(_) => return vec![],
    };
    let mut devices = Vec::new();
    for line in out.lines() {
        let line = line.trim();
        if line.is_empty() || line.ends_with("devices found") {
            continue;
        }
        // Format: "<id> <name>" (id-name-only) or "0 devices found"
        let Some((id, name)) = line.split_once(char::is_whitespace) else {
            continue;
        };
        let id = id.trim();
        let name = name.trim();
        if id.is_empty() || name.is_empty() {
            continue;
        }
        if !id.chars().all(|c| c.is_ascii_hexdigit()) {
            continue;
        }
        let dtype = device_type(id);
        let mp = mount_point(id).unwrap_or_default();
        let is_mounted = !mp.is_empty() && Path::new(&mp).is_dir();
        devices.push(ConnectedDevice {
            id: id.to_string(),
            name: name.to_string(),
            device_type: dtype,
            mount_point: mp,
            is_mounted,
        });
    }
    devices
}

pub fn icon_for(device_type: &str) -> &'static str {
    match device_type {
        "tablet" => "device-tablet",
        "desktop" | "laptop" => "laptop",
        "tv" => "television",
        _ => "device-mobile",
    }
}

pub fn to_drives() -> Vec<Drive> {
    list_reachable()
        .into_iter()
        .map(|d| Drive {
            name: Message::raw(d.name).to_string(),
            device: device_uri(&d.id),
            disk: String::new(),
            mount_point: d.mount_point.clone(),
            is_mounted: d.is_mounted,
            is_external: true,
            is_locked: false,
            is_encrypted: false,
            crypt_device: String::new(),
            fs_type: "kdeconnect".to_string(),
            total_bytes: 0,
            used_bytes: 0,
            free_bytes: 0,
            total_str: String::new(),
            used_str: String::new(),
            free_str: String::new(),
            percent: 0.0,
            model: d.device_type.clone(),
            provider: "kdeconnect".to_string(),
            icon: icon_for(&d.device_type).to_string(),
        })
        .collect()
}

pub fn mount(id: &str) -> Result<String, String> {
    run_kdeconnect(&["-d", id, "--mount"])?;
    // kdeconnect-cli --mount may return before mount is ready; poll briefly.
    for _ in 0..20 {
        if let Some(p) = mount_point(id) {
            return Ok(p);
        }
        std::thread::sleep(std::time::Duration::from_millis(100));
    }
    Err("Mounted, but mount point was not found".to_string())
}

pub fn unmount(id: &str) -> Result<(), String> {
    let mp = mount_point(id).ok_or_else(|| "Device is not mounted".to_string())?;
    // Try fusermount3, fusermount, then umount.
    for (bin_name, args) in [
        ("fusermount3", vec!["-u", mp.as_str()]),
        ("fusermount", vec!["-u", mp.as_str()]),
        ("umount", vec![mp.as_str()]),
    ] {
        let Some(bin) = util::which(bin_name) else {
            continue;
        };
        let mut cmd = Command::new(bin);
        cmd.args(&args);
        let (ok, _, err) = util::run_capture(cmd, None);
        if ok {
            return Ok(());
        }
        // If busy, report that error
        let lower = err.to_lowercase();
        if lower.contains("busy") {
            return Err(err.lines().rfind(|l| !l.trim().is_empty()).unwrap_or("Device is busy").trim().to_string());
        }
    }
    Err("Could not unmount KDE Connect device (fusermount/umount not found or failed)".to_string())
}

pub fn share_files(id: &str, paths: &[String]) -> Result<(), String> {
    for path in paths {
        let p = Path::new(path);
        if !p.exists() {
            return Err(format!("File not found: {}", path));
        }
        run_kdeconnect(&["-d", id, "--share", path])?;
    }
    Ok(())
}
