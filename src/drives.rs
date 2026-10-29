//! Devices for the sidebar and This PC: block volumes via lsblk/UDisks,
//! and optional USB MTP phones via KDE's session D-Bus service.

use crate::util::{self, which};
use serde::Serialize;
use std::path::Path;
use std::process::Command;

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct Drive {
    pub name: String,
    pub device: String,
    /// The whole disk this partition belongs to (for power-off/eject).
    pub disk: String,
    pub mount_point: String,
    pub is_mounted: bool,
    pub is_external: bool,
    /// LUKS container that still needs unlocking.
    pub is_locked: bool,
    /// Lives inside an unlocked LUKS container (`crypt_device`).
    pub is_encrypted: bool,
    pub crypt_device: String,
    pub fs_type: String,
    pub total_bytes: u64,
    pub used_bytes: u64,
    pub free_bytes: u64,
    pub total_str: String,
    pub used_str: String,
    pub free_str: String,
    pub percent: f64,
    pub model: String,
    /// Provider kind: "block" (default) or "mtp".
    pub provider: String,
    /// Icon override (e.g. "device-mobile" for phones).
    pub icon: String,
}

pub fn statvfs(mount: &str) -> Option<(u64, u64)> {
    let c = std::ffi::CString::new(mount).ok()?;
    let mut st: libc::statvfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statvfs(c.as_ptr(), &mut st) } != 0 {
        return None;
    }
    let total = st.f_blocks as u64 * st.f_frsize as u64;
    let free = st.f_bavail as u64 * st.f_frsize as u64;
    Some((total, free))
}

fn sysfs_removable(name: &str) -> bool {
    let block = Path::new("/sys/class/block").join(name);
    if let Ok(real) = std::fs::canonicalize(&block) {
        if real.to_string_lossy().contains("/usb") {
            return true;
        }
    }
    std::fs::read_to_string(Path::new("/sys/block").join(name).join("removable"))
        .map(|s| s.trim() == "1")
        .unwrap_or(false)
}

fn s<'a>(v: &'a serde_json::Value, k: &str) -> &'a str {
    v.get(k).and_then(|x| x.as_str()).unwrap_or("")
}

fn b(v: &serde_json::Value, k: &str) -> bool {
    match v.get(k) {
        Some(serde_json::Value::Bool(x)) => *x,
        Some(serde_json::Value::String(x)) => x == "1",
        Some(serde_json::Value::Number(n)) => n.as_u64() == Some(1),
        _ => false,
    }
}

fn mountpoint_of(v: &serde_json::Value) -> String {
    // util-linux >= 2.37 reports "mountpoints": [...]; older "mountpoint".
    if let Some(arr) = v.get("mountpoints").and_then(|m| m.as_array()) {
        let mut valid: Vec<&str> = arr.iter().filter_map(|m| m.as_str()).filter(|m| !m.is_empty()).collect();
        // Sort candidate mountpoints stably: category priority, then shortest path, then lexical tiebreak.
        fn score(m: &str) -> u8 {
            if m == "/" {
                0
            } else if m == "/home" {
                1
            } else if m.starts_with("/home/") {
                2
            } else if m.starts_with("/media/") || m.starts_with("/run/media/") {
                3
            } else if m.starts_with("/mnt/") {
                4
            } else if !m.starts_with("/var/") && !m.starts_with("/srv") && !m.starts_with("/root") && !m.starts_with("/nix") {
                5
            } else {
                6
            }
        }
        valid.sort_by(|a, b| {
            score(a).cmp(&score(b))
                .then_with(|| a.len().cmp(&b.len()))
                .then_with(|| a.cmp(b))
        });
        if let Some(first) = valid.first() {
            return first.to_string();
        }
    }
    s(v, "mountpoint").to_string()
}

/// Parses `lsblk -J -b -o NAME,PATH,LABEL,MOUNTPOINT(S),FSTYPE,SIZE,RM,HOTPLUG,TRAN,MODEL,TYPE`.
/// `usage` returns (total, free) for a mount point.
pub fn parse_lsblk(json: &str, usage: &dyn Fn(&str) -> Option<(u64, u64)>, removable: &dyn Fn(&str) -> bool) -> Vec<Drive> {
    let Ok(val) = serde_json::from_str::<serde_json::Value>(json) else { return vec![] };
    let mut out = Vec::new();
    let Some(devs) = val.get("blockdevices").and_then(|d| d.as_array()) else { return out };
    struct Ctx<'a> {
        disk: String,
        model: String,
        external: bool,
        usage: &'a dyn Fn(&str) -> Option<(u64, u64)>,
    }
    fn walk(v: &serde_json::Value, ctx: &Ctx, crypt: &str, out: &mut Vec<Drive>) {
        let name = s(v, "name");
        let fstype = s(v, "fstype");
        let children = v.get("children").and_then(|c| c.as_array());
        let is_luks = fstype == "crypto_LUKS";
        if let Some(ch) = children {
            if !is_luks {
                for c in ch {
                    walk(c, ctx, crypt, out);
                }
                return;
            }
            // Unlocked LUKS: show the cleartext filesystem inside instead.
            let me = if s(v, "path").is_empty() { format!("/dev/{}", name) } else { s(v, "path").to_string() };
            for c in ch {
                walk(c, ctx, &me, out);
            }
            return;
        }
        if name.is_empty() || (fstype.is_empty() && !is_luks) || fstype == "swap" {
            return;
        }
        let mount = mountpoint_of(v);
        if mount == "[SWAP]" || mount.starts_with("/boot") || mount == "/nix/store" {
            return;
        }
        let path = if s(v, "path").is_empty() { format!("/dev/{}", name) } else { s(v, "path").to_string() };
        let size = v.get("size").and_then(|x| x.as_u64()).unwrap_or(0);
        let mounted = !mount.is_empty();
        let (total, free) = if mounted { (ctx.usage)(&mount).unwrap_or((size, 0)) } else { (size, size) };
        let used = total.saturating_sub(free);
        let label = s(v, "label");
        let display = if !label.is_empty() {
            label.to_string()
        } else if mount == "/" {
            "Root (/)".to_string()
        } else if mounted {
            Path::new(&mount).file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| name.to_string())
        } else if !ctx.model.is_empty() {
            format!("{} ({})", ctx.model.trim(), util::format_size(size))
        } else {
            format!("{} Volume", util::format_size(size))
        };
        let pct = if total > 0 && mounted { ((used as f64 / total as f64) * 1000.0).round() / 10.0 } else { 0.0 };
        out.push(Drive {
            name: display,
            device: path,
            disk: ctx.disk.clone(),
            mount_point: mount,
            is_mounted: mounted,
            is_external: ctx.external,
            is_locked: is_luks,
            is_encrypted: !crypt.is_empty(),
            crypt_device: crypt.to_string(),
            fs_type: fstype.to_string(),
            total_bytes: total,
            used_bytes: used,
            free_bytes: free,
            total_str: util::format_size(total),
            used_str: util::format_size(used),
            free_str: util::format_size(free),
            percent: pct,
            model: ctx.model.clone(),
            provider: "block".to_string(),
            icon: String::new(),
        });
    }
    for d in devs {
        let ty = s(d, "type");
        if ty == "loop" || ty == "rom" && d.get("children").is_none() && s(d, "fstype").is_empty() {
            continue;
        }
        let name = s(d, "name");
        let tran = s(d, "tran").to_lowercase();
        let external = b(d, "rm")
            || b(d, "hotplug")
            || matches!(tran.as_str(), "usb" | "mmc" | "sdio" | "firewire" | "1394" | "memstick")
            || removable(name);
        let ctx = Ctx {
            disk: if s(d, "path").is_empty() { format!("/dev/{}", name) } else { s(d, "path").to_string() },
            model: s(d, "model").trim().to_string(),
            external,
            usage,
        };
        walk(d, &ctx, "", &mut out);
    }

    // Disambiguate duplicate display names across drives (e.g. btrfs multi-volumes sharing label)
    disambiguate_drive_names(&mut out);

    out
}

fn disambiguate_drive_names(drives: &mut [Drive]) {
    use std::collections::HashMap;
    let mut counts: HashMap<String, usize> = HashMap::new();
    for d in drives.iter() {
        *counts.entry(d.name.clone()).or_insert(0) += 1;
    }

    for d in drives.iter_mut() {
        if counts.get(&d.name).copied().unwrap_or(0) > 1 {
            let suffix = if !d.mount_point.is_empty() {
                d.mount_point.clone()
            } else {
                Path::new(&d.device)
                    .file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_else(|| d.device.clone())
            };
            d.name = format!("{} ({})", d.name, suffix);
        }
    }
}

/// All drives (runs `lsblk` and checks for MTP devices; call from a worker thread).
pub fn list() -> Vec<Drive> {
    let mut drives = list_block();
    let mtp_json = crate::native::list_kmtp_devices_json();
    drives.extend(parse_mtp_devices(&mtp_json));
    drives
}

pub fn parse_mtp_devices(json: &str) -> Vec<Drive> {
    let Ok(val) = serde_json::from_str::<serde_json::Value>(json) else { return vec![] };
    let Some(arr) = val.as_array() else { return vec![] };
    let mut out = Vec::new();
    for item in arr {
        let name = s(item, "name").trim().to_string();
        let url = s(item, "url").to_string();
        let udi = s(item, "udi").to_string();
        let model = s(item, "model").trim().to_string();
        let total = item.get("total_bytes").and_then(|v| v.as_u64().or_else(|| v.as_f64().map(|f| f as u64))).unwrap_or(0);
        let free = item.get("free_bytes").and_then(|v| v.as_u64().or_else(|| v.as_f64().map(|f| f as u64))).unwrap_or(0);
        let used = total.saturating_sub(free);
        let pct = if total > 0 { ((used as f64 / total as f64) * 1000.0).round() / 10.0 } else { 0.0 };

        // A phone is a virtual location, never a guessed local mount path.
        let Some(location) = crate::mtp::Location::parse(&url).filter(|loc| loc.is_root() && loc.udi() == udi) else {
            continue;
        };
        out.push(Drive {
            name: if !name.is_empty() { name } else { "MTP Device".to_string() },
            device: location.url(),
            disk: String::new(),
            mount_point: String::new(),
            is_mounted: false,
            is_external: true,
            is_locked: false,
            is_encrypted: false,
            crypt_device: String::new(),
            fs_type: "mtp".to_string(),
            total_bytes: total,
            used_bytes: used,
            free_bytes: free,
            total_str: util::format_size(total),
            used_str: util::format_size(used),
            free_str: util::format_size(free),
            percent: pct,
            model,
            provider: "mtp".to_string(),
            icon: "device-mobile".to_string(),
        });
    }
    out
}

pub fn list_block() -> Vec<Drive> {
    let Some(lsblk) = which("lsblk") else { return vec![] };
    let out = Command::new(lsblk)
        .args(["-J", "-b", "-o", "NAME,PATH,LABEL,MOUNTPOINTS,FSTYPE,SIZE,RM,HOTPLUG,TRAN,MODEL,TYPE"])
        .output();
    let json = match out {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout).to_string(),
        _ => {
            // Older util-linux without MOUNTPOINTS.
            Command::new("lsblk")
                .args(["-J", "-b", "-o", "NAME,PATH,LABEL,MOUNTPOINT,FSTYPE,SIZE,RM,HOTPLUG,TRAN,MODEL,TYPE"])
                .output()
                .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
                .unwrap_or_default()
        }
    };
    parse_lsblk(&json, &|m| statvfs(m), &sysfs_removable)
}

fn udisks(args: &[&str], stdin: Option<&[u8]>) -> Result<String, String> {
    let device = args.windows(2).find(|pair| pair[0] == "-b").map(|pair| pair[1]).unwrap_or("");
    if !device.starts_with("/dev/") {
        return Err("This action is only supported for block devices".to_string());
    }
    let bin = which("udisksctl").ok_or("udisks2 (udisksctl) is not installed")?;
    let mut cmd = Command::new(bin);
    cmd.args(args);
    let (ok, out, err) = util::run_capture(cmd, stdin);
    if ok {
        Ok(out)
    } else {
        Err(err.lines().last().unwrap_or("UDisks reported an error").trim().to_string())
    }
}

pub fn mount(device: &str) -> Result<String, String> {
    udisks(&["mount", "-b", device], None)?;
    // Resolve from the filesystem model: udisksctl's human-readable output
    // can be localized and is not a reliable navigation target.
    list_block().into_iter()
        .find(|d| d.device == device && d.is_mounted)
        .map(|d| d.mount_point)
        .ok_or_else(|| "mounted device has no discoverable mount point".to_string())
}

pub fn unmount(device: &str) -> Result<(), String> {
    udisks(&["unmount", "-b", device], None).map(|_| ())
}

/// Unmounts every mounted partition of `disk` and powers it off so it can
/// be unplugged safely.
pub fn eject(disk: &str, drives: &[Drive]) -> Result<(), String> {
    for d in drives.iter().filter(|d| d.disk == disk && d.is_mounted) {
        unmount(&d.device)?;
    }
    for d in drives.iter().filter(|d| d.disk == disk && d.is_encrypted) {
        lock(&d.crypt_device)?;
    }
    crate::fsops::sync_filesystem(Path::new("/"));
    udisks(&["power-off", "-b", disk], None).map(|_| ())
}

/// Unlocks a LUKS device with `passphrase` (sent on stdin) and returns the
/// cleartext device path.
pub fn unlock(device: &str, passphrase: &str) -> Result<String, String> {
    let out = udisks(&["unlock", "-b", device, "--key-file", "/dev/stdin"], Some(passphrase.as_bytes()))?;
    // "Unlocked /dev/sdb1 as /dev/dm-3."
    Ok(out.trim().rsplit(" as ").next().unwrap_or("").trim_end_matches('.').to_string())
}

pub fn lock(device: &str) -> Result<(), String> {
    udisks(&["lock", "-b", device], None).map(|_| ())
}

/// UDisks object path for a block device ("/dev/dm-0" -> ".../dm_2d0").
pub fn udisks_object(device: &str) -> String {
    let base = Path::new(device).file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
    let mut esc = String::new();
    for c in base.bytes() {
        if c.is_ascii_alphanumeric() {
            esc.push(c as char);
        } else {
            esc.push_str(&format!("_{:02x}", c));
        }
    }
    format!("/org/freedesktop/UDisks2/block_devices/{}", esc)
}

/// Sets a filesystem label through UDisks (polkit asks for permission when
/// needed); works for ext*, FAT, exFAT, NTFS, btrfs, xfs...
pub fn set_label(device: &str, label: &str) -> Result<(), String> {
    if !device.starts_with("/dev/") {
        return Err("Renaming is only supported for block devices".to_string());
    }
    let gdbus = which("gdbus").ok_or("gdbus (glib2) is not installed")?;
    let mut cmd = Command::new(gdbus);
    cmd.args([
        "call",
        "--system",
        "--dest",
        "org.freedesktop.UDisks2",
        "--object-path",
        &udisks_object(device),
        "--method",
        "org.freedesktop.UDisks2.Filesystem.SetLabel",
    ])
    .arg(format!("'{}'", label.replace('\\', "\\\\").replace('\'', "\\'")))
    .arg("{}");
    let (ok, _, err) = util::run_capture(cmd, None);
    if ok {
        Ok(())
    } else {
        Err(err.trim().lines().last().unwrap_or("could not rename the drive").to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"{"blockdevices":[
      {"name":"nvme0n1","path":"/dev/nvme0n1","label":null,"mountpoints":[null],"fstype":null,"size":512110190592,"rm":false,"hotplug":false,"tran":"nvme","model":"Samsung SSD","type":"disk","children":[
        {"name":"nvme0n1p1","path":"/dev/nvme0n1p1","label":null,"mountpoints":["/boot/efi"],"fstype":"vfat","size":629145600,"rm":false,"hotplug":false,"tran":null,"model":null,"type":"part"},
        {"name":"nvme0n1p2","path":"/dev/nvme0n1p2","label":"fedora","mountpoints":["/home","/"],"fstype":"btrfs","size":500000000000,"rm":false,"hotplug":false,"tran":null,"model":null,"type":"part"},
        {"name":"nvme0n1p3","path":"/dev/nvme0n1p3","label":null,"mountpoints":["[SWAP]"],"fstype":"swap","size":8000000000,"rm":false,"hotplug":false,"tran":null,"model":null,"type":"part"}
      ]},
      {"name":"sdb","path":"/dev/sdb","label":null,"mountpoints":[null],"fstype":null,"size":32000000000,"rm":true,"hotplug":true,"tran":"usb","model":"SanDisk ","type":"disk","children":[
        {"name":"sdb1","path":"/dev/sdb1","label":"STICK","mountpoints":[null],"fstype":"exfat","size":32000000000,"rm":true,"hotplug":true,"tran":null,"model":null,"type":"part"}
      ]},
      {"name":"sdc","path":"/dev/sdc","label":null,"mountpoints":[null],"fstype":null,"size":64000000000,"rm":true,"hotplug":true,"tran":"usb","model":"Vault","type":"disk","children":[
        {"name":"sdc1","path":"/dev/sdc1","label":null,"mountpoints":[null],"fstype":"crypto_LUKS","size":64000000000,"rm":true,"hotplug":true,"tran":null,"model":null,"type":"part"}
      ]},
      {"name":"loop0","path":"/dev/loop0","fstype":"squashfs","mountpoints":["/snap/x"],"size":1,"type":"loop"}
    ]}"#;

    #[test]
    fn parses_drives() {
        let d = parse_lsblk(SAMPLE, &|m| if m == "/" { Some((1000, 250)) } else { None }, &|_| false);
        let names: Vec<_> = d.iter().map(|x| x.device.as_str()).collect();
        assert_eq!(names, vec!["/dev/nvme0n1p2", "/dev/sdb1", "/dev/sdc1"], "efi, swap and loop are hidden");
        let root = &d[0];
        assert_eq!(root.name, "fedora");
        assert_eq!(root.mount_point, "/", "prefers / when multiple mountpoints are present");
        assert_eq!(root.percent, 75.0);
        assert!(!root.is_external);
        let usb = &d[1];
        assert!(usb.is_external && !usb.is_mounted);
        assert_eq!(usb.disk, "/dev/sdb");
        assert!(d[2].is_locked, "LUKS container needs unlocking");
    }

    #[test]
    fn disambiguates_duplicate_labels() {
        let json = r#"{"blockdevices":[
          {"name":"nvme0n1","path":"/dev/nvme0n1","label":null,"mountpoints":[],"fstype":null,"size":500000000000,"rm":false,"hotplug":false,"tran":"nvme","model":"FastNVMe","type":"disk","children":[
            {"name":"nvme0n1p6","path":"/dev/nvme0n1p6","label":"linux-root","mountpoints":["/var/log","/"],"fstype":"btrfs","size":80000000000,"rm":false,"hotplug":false,"tran":null,"model":null,"type":"part"},
            {"name":"nvme0n1p8","path":"/dev/nvme0n1p8","label":"linux-root","mountpoints":["/home"],"fstype":"btrfs","size":200000000000,"rm":false,"hotplug":false,"tran":null,"model":null,"type":"part"},
            {"name":"nvme0n1p9","path":"/dev/nvme0n1p9","label":"data","mountpoints":[],"fstype":"ext4","size":50000000000,"rm":false,"hotplug":false,"tran":null,"model":null,"type":"part"},
            {"name":"nvme0n1p10","path":"/dev/nvme0n1p10","label":"data","mountpoints":[],"fstype":"ext4","size":50000000000,"rm":false,"hotplug":false,"tran":null,"model":null,"type":"part"}
          ]}
        ]}"#;
        let d = parse_lsblk(json, &|_| Some((100, 50)), &|_| false);
        assert_eq!(d.len(), 4);
        assert_eq!(d[0].device, "/dev/nvme0n1p6");
        assert_eq!(d[0].mount_point, "/");
        assert_eq!(d[0].name, "linux-root (/)");

        assert_eq!(d[1].device, "/dev/nvme0n1p8");
        assert_eq!(d[1].mount_point, "/home");
        assert_eq!(d[1].name, "linux-root (/home)");

        assert_eq!(d[2].device, "/dev/nvme0n1p9");
        assert_eq!(d[2].name, "data (nvme0n1p9)");

        assert_eq!(d[3].device, "/dev/nvme0n1p10");
        assert_eq!(d[3].name, "data (nvme0n1p10)");
    }

    #[test]
    fn mountpoint_choice_is_independent_of_listing_order() {
        for mounts in [
            vec!["/var/log", "/home", "/"],
            vec!["/", "/home", "/var/log"],
        ] {
            assert_eq!(mountpoint_of(&serde_json::json!({"mountpoints": mounts})), "/");
        }
        for mounts in [
            vec!["/var/log", "/mnt/z", "/mnt/a"],
            vec!["/mnt/a", "/mnt/z", "/var/log"],
        ] {
            assert_eq!(mountpoint_of(&serde_json::json!({"mountpoints": mounts})), "/mnt/a");
        }
        assert_eq!(mountpoint_of(&serde_json::json!({"mountpoint": "/home"})), "/home");
    }

    #[test]
    fn object_paths() {
        assert_eq!(udisks_object("/dev/sdb1"), "/org/freedesktop/UDisks2/block_devices/sdb1");
        assert_eq!(udisks_object("/dev/dm-0"), "/org/freedesktop/UDisks2/block_devices/dm_2d0");
    }

    #[test]
    fn parses_mtp_devices_metadata() {
        let json = r#"[
          {
            "name": "Redmi K20 Pro",
            "udi": "/test/phone",
            "url": "mtp://loaf/2f746573742f70686f6e65",
            "model": "Redmi K20 Pro",
            "icon": "device-mobile",
            "total_bytes": 116933570560,
            "free_bytes": 85724872704
          }
        ]"#;
        let d = parse_mtp_devices(json);
        assert_eq!(d.len(), 1);
        let phone = &d[0];
        assert_eq!(phone.name, "Redmi K20 Pro");
        assert_eq!(phone.device, "mtp://loaf/2f746573742f70686f6e65/");
        assert!(!phone.is_mounted);
        assert!(phone.mount_point.is_empty());
        assert_eq!(phone.provider, "mtp");
        assert_eq!(phone.icon, "device-mobile");
        assert!(phone.is_external);
        assert!(!phone.is_locked);
        assert_eq!(phone.fs_type, "mtp");
        assert_eq!(phone.total_bytes, 116933570560);
        assert_eq!(phone.free_bytes, 85724872704);
        assert_eq!(phone.used_bytes, 116933570560 - 85724872704);
        assert!(phone.percent > 0.0);
    }

    #[test]
    fn parses_empty_mtp_list() {
        let d = parse_mtp_devices("[]");
        assert!(d.is_empty());
        let d_invalid = parse_mtp_devices("not-json");
        assert!(d_invalid.is_empty());
    }

    #[test]
    fn rejects_ambiguous_mtp_identity_and_block_actions() {
        assert!(parse_mtp_devices(r#"[{"name":"Phone","url":"mtp:/"}]"#).is_empty());
        let uri = "mtp://loaf/2f746573742f70686f6e65";
        assert!(mount(uri).is_err());
        assert!(unmount(uri).is_err());
        assert!(lock(uri).is_err());
        assert!(unlock(uri, "unused").is_err());
        assert!(eject(uri, &[]).is_err());
        assert!(set_label(uri, "Phone").is_err());
    }

    #[test]
    fn lists_this_machine() {
        // Smoke test: must not panic; most machines have at least one drive.
        let _ = list();
    }
}
