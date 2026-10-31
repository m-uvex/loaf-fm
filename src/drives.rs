//! Block devices for the "This PC" page: discovery through `lsblk`, usage
//! through `statvfs`, and actions through UDisks (`udisksctl` / D-Bus), so
//! nothing needs root and polkit asks when it must.

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
        let valid: Vec<&str> = arr.iter().filter_map(|m| m.as_str()).filter(|m| !m.is_empty()).collect();
        // If root "/" is in the mountpoints list, always prefer "/" over overlay/bind mounts
        if valid.contains(&"/") {
            return "/".to_string();
        }
        // Skip inaccessible system/container mountpoints if another path is available
        if let Some(user_mount) = valid.iter().find(|m| !m.starts_with("/var/lib") && !m.starts_with("/nix")) {
            return user_mount.to_string();
        }
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
    out
}

/// All drives (runs `lsblk`; call from a worker thread).
pub fn list() -> Vec<Drive> {
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
    let out = udisks(&["mount", "-b", device], None)?;
    // "Mounted /dev/sdb1 at /run/media/u/LABEL"
    Ok(out.trim().rsplit(" at ").next().unwrap_or("").trim_end_matches('.').to_string())
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
        assert_eq!(root.mount_point, "/", "prefers / over a submount like /home");
        assert_eq!(root.percent, 75.0);
        assert!(!root.is_external);
        let usb = &d[1];
        assert!(usb.is_external && !usb.is_mounted);
        assert_eq!(usb.disk, "/dev/sdb");
        assert!(d[2].is_locked, "LUKS container needs unlocking");
    }

    #[test]
    fn object_paths() {
        assert_eq!(udisks_object("/dev/sdb1"), "/org/freedesktop/UDisks2/block_devices/sdb1");
        assert_eq!(udisks_object("/dev/dm-0"), "/org/freedesktop/UDisks2/block_devices/dm_2d0");
    }

    #[test]
    fn lists_this_machine() {
        // Smoke test: must not panic; most machines have at least one drive.
        let _ = list();
    }
}
