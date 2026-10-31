//! MTP / Android phone storage through GVfs.
//!
//! GVfs exposes MTP devices as a FUSE directory under
//! `$XDG_RUNTIME_DIR/gvfs/mtp:host=...`, so once a phone is mounted the rest
//! of Loaf can browse and copy files with the normal filesystem code. Mount
//! and unmount go through `gio`, matching the SMB integration.

use crate::util::{self, which};
use serde::Serialize;
use std::path::PathBuf;
use std::process::Command;

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct Device {
    pub name: String,
    /// GVfs URI, e.g. `mtp://SAMSUNG_SAMSUNG_Android_/`.
    pub uri: String,
    /// USB device node when GVfs reports one, e.g. `/dev/bus/usb/001/004`.
    pub device: String,
    /// Mounted FUSE directory, empty while the phone is not mounted.
    pub path: String,
    pub is_mounted: bool,
}

struct RawVolume {
    name: String,
    uri: String,
    device: String,
}

fn push_volume(current: Option<RawVolume>, out: &mut Vec<RawVolume>) {
    let Some(mut v) = current else { return };
    if !(v.uri.starts_with("mtp://") || v.uri.starts_with("gphoto2://")) {
        return;
    }
    v.name = v.name.trim().to_string();
    v.device = v.device.trim().trim_matches('\'').to_string();
    out.push(v);
}

/// Parses the volumes GVfs reports. Only MTP / PTP volumes are kept, so
/// ordinary UDisks drives and network mounts are ignored.
fn parse_mount_list(text: &str) -> Vec<RawVolume> {
    let mut out = Vec::new();
    let mut current: Option<RawVolume> = None;
    for raw in text.lines() {
        let line = raw.trim();
        if line.starts_with("Volume(") {
            push_volume(current.take(), &mut out);
            let name = line.split_once("):").map(|(_, n)| n.trim()).unwrap_or("");
            current = Some(RawVolume { name: name.to_string(), uri: String::new(), device: String::new() });
            continue;
        }
        // A volume block ends at the next drive, mount, or volume.
        if line.starts_with("Drive(") || line.starts_with("Mount(") {
            push_volume(current.take(), &mut out);
            continue;
        }
        let Some(v) = current.as_mut() else { continue };
        if let Some(uri) = line.strip_prefix("activation_root=") {
            v.uri = uri.trim().trim_end_matches('/').to_string();
        } else if let Some(device) = line.strip_prefix("unix-device:") {
            v.device = device.trim().trim_matches('\'').to_string();
        }
    }
    push_volume(current, &mut out);
    out
}

fn runtime_dir() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(format!("/run/user/{}", unsafe { libc::getuid() })))
}

fn gvfs_dir() -> PathBuf {
    runtime_dir().join("gvfs")
}

fn percent_decode(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let hi = (bytes[i + 1] as char).to_digit(16);
            let lo = (bytes[i + 2] as char).to_digit(16);
            if let (Some(hi), Some(lo)) = (hi, lo) {
                out.push((hi * 16 + lo) as u8);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).to_string()
}

/// GVfs names its FUSE directories after the mount host, URL-encoding the
/// brackets of `[usb:001,004]` style hosts.
fn expected_mount_name(uri: &str) -> Option<String> {
    let (scheme, rest) = uri.split_once("://")?;
    let host = rest.trim_matches('/');
    if host.is_empty() {
        return None;
    }
    Some(format!("{}:host={}", scheme, host))
}

fn matches_mount_name(uri: &str, name: &str) -> bool {
    let Some(want) = expected_mount_name(uri) else { return false };
    let decoded = percent_decode(name);
    decoded.trim_end_matches('/') == want
}

fn mounted_path(uri: &str) -> Option<PathBuf> {
    let entries = std::fs::read_dir(gvfs_dir()).ok()?;
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().to_string();
        if matches_mount_name(uri, &name) {
            let path = entry.path();
            if path.is_dir() {
                return Some(path);
            }
        }
    }
    None
}

fn friendly_name(volume: &str, uri: &str) -> String {
    let name = volume.trim();
    if !name.is_empty() {
        return name.to_string();
    }
    let host = uri.split_once("://").map(|(_, rest)| rest).unwrap_or("").trim_matches('/');
    let host = percent_decode(host).replace(['_', '+'], " ");
    let host = host.trim();
    if host.is_empty() {
        "Android device".to_string()
    } else {
        host.to_string()
    }
}

fn gio_error(out: &str, err: &str) -> String {
    err.lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .last()
        .or_else(|| out.lines().map(str::trim).filter(|line| !line.is_empty()).last())
        .unwrap_or("the phone could not be mounted")
        .to_string()
}

/// GVfs expects a trailing slash on MTP locations.
fn gio_location(uri: &str) -> String {
    if uri.ends_with('/') {
        uri.to_string()
    } else {
        format!("{}/", uri.trim_end_matches('/'))
    }
}

/// Connected MTP / PTP devices, mounted or not. Runs `gio`; call from a
/// worker thread.
pub fn list() -> Vec<Device> {
    let Some(gio) = which("gio") else { return Vec::new() };
    let mut cmd = Command::new(gio);
    cmd.args(["mount", "-li"]).env("LC_ALL", "C").env("LANGUAGE", "C");
    let (ok, out, _) = util::run_capture(cmd, None);
    if !ok {
        return Vec::new();
    }
    parse_mount_list(&out)
        .into_iter()
        .map(|v| {
            let path = mounted_path(&v.uri);
            Device {
                name: friendly_name(&v.name, &v.uri),
                is_mounted: path.is_some(),
                path: path.map(|p| p.to_string_lossy().to_string()).unwrap_or_default(),
                uri: v.uri,
                device: v.device,
            }
        })
        .collect()
}

/// Mounts a device and returns the GVfs FUSE path. The phone may ask the user
/// to allow file access, so this waits a few seconds for the mount to appear.
pub fn mount(uri: &str) -> Result<String, String> {
    if let Some(path) = mounted_path(uri) {
        return Ok(path.to_string_lossy().to_string());
    }
    let gio = which("gio").ok_or("GVfs (gio) is not installed")?;
    let mut cmd = Command::new(gio);
    cmd.args(["mount", &gio_location(uri)]).env("LC_ALL", "C").env("LANGUAGE", "C");
    let (ok, out, err) = util::run_capture(cmd, None);
    if !ok {
        return Err(gio_error(&out, &err));
    }
    for _ in 0..200 {
        if let Some(path) = mounted_path(uri) {
            return Ok(path.to_string_lossy().to_string());
        }
        std::thread::sleep(std::time::Duration::from_millis(50));
    }
    Err("The phone mounted, but its local folder was not found".to_string())
}

pub fn unmount(uri: &str) -> Result<(), String> {
    let gio = which("gio").ok_or("GVfs (gio) is not installed")?;
    let target = mounted_path(uri).map(|p| p.to_string_lossy().to_string()).unwrap_or_else(|| uri.to_string());
    let mut cmd = Command::new(&gio);
    cmd.args(["mount", "-u", &target]).env("LC_ALL", "C").env("LANGUAGE", "C");
    let (ok, out, err) = util::run_capture(cmd, None);
    if ok || gio_error(&out, &err).to_lowercase().contains("not mounted") {
        return Ok(());
    }
    // Some GVfs versions only accept the original URI for MTP mounts.
    let mut cmd = Command::new(gio);
    cmd.args(["mount", "-u", &gio_location(uri)]).env("LC_ALL", "C").env("LANGUAGE", "C");
    let (ok, out, err) = util::run_capture(cmd, None);
    if ok || gio_error(&out, &err).to_lowercase().contains("not mounted") {
        Ok(())
    } else {
        Err(gio_error(&out, &err))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"
Drive(0): SPCC M.2 PCIe SSD
  Type: GProxyDrive (GProxyVolumeMonitorUDisks2)
  Volume(0): 255 GB Volume
    Type: GProxyVolume (GProxyVolumeMonitorUDisks2)
    ids:
     unix-device: '/dev/nvme1n1p3'
    activation_root=file:///run/media/u/255%20GB%20Volume/
Drive(1): SAMSUNG Android
  Type: GProxyDrive (GProxyVolumeMonitorMTP)
  Volume(0): SAMSUNG Android
    Type: GProxyVolume (GProxyVolumeMonitorMTP)
    ids:
     unix-device: '/dev/bus/usb/001/004'
    activation_root=mtp://SAMSUNG_SAMSUNG_Android_/
Mount(0): SAMSUNG Android -> mtp://SAMSUNG_SAMSUNG_Android_/
  Type: GProxyMount (GProxyVolumeMonitorMTP)
  Volume(1): Pixel Camera
    Type: GProxyVolume (GProxyVolumeMonitorGPhoto2)
    ids:
     unix-device: '/dev/bus/usb/001/005'
    activation_root=gphoto2://usb%3A001%2C005/
"#;

    #[test]
    fn finds_only_mtp_and_ptp_volumes() {
        let volumes = parse_mount_list(SAMPLE);
        assert_eq!(volumes.len(), 2);
        assert_eq!(volumes[0].name, "SAMSUNG Android");
        assert_eq!(volumes[0].uri, "mtp://SAMSUNG_SAMSUNG_Android_");
        assert_eq!(volumes[0].device, "/dev/bus/usb/001/004");
        assert_eq!(volumes[1].uri, "gphoto2://usb%3A001%2C005");
    }

    #[test]
    fn matches_gvfs_mount_directory_names() {
        assert_eq!(
            expected_mount_name("mtp://SAMSUNG_SAMSUNG_Android_/").as_deref(),
            Some("mtp:host=SAMSUNG_SAMSUNG_Android_")
        );
        assert!(matches_mount_name("mtp://SAMSUNG_SAMSUNG_Android_/", "mtp:host=SAMSUNG_SAMSUNG_Android_"));
        assert!(matches_mount_name("mtp://[usb:001,004]/", "mtp:host=%5Busb%3A001%2C004%5D"));
        assert!(!matches_mount_name("mtp://[usb:001,004]/", "mtp:host=%5Busb%3A001%2C005%5D"));
    }

    #[test]
    fn decodes_host_names() {
        assert_eq!(percent_decode("SAMSUNG%5FAndroid"), "SAMSUNG_Android");
        assert_eq!(friendly_name("", "mtp://SAMSUNG_SAMSUNG_Android_/"), "SAMSUNG SAMSUNG Android");
        assert_eq!(friendly_name("Pixel 8", "mtp://x/"), "Pixel 8");
        assert_eq!(friendly_name("", "mtp:///"), "Android device");
    }

    #[test]
    fn gio_locations_have_a_trailing_slash() {
        assert_eq!(gio_location("mtp://[usb:001,004]"), "mtp://[usb:001,004]/");
        assert_eq!(gio_location("mtp://SAMSUNG/"), "mtp://SAMSUNG/");
    }
}
