//! Optional rclone integration: detects active `fuse.rclone` mounts (including
//! custom `--config` and `--rc-addr` flags), lists configured remotes, and runs
//! common cloud actions (public link, remote info/quota, size, VFS refresh,
//! copy/move to remote). Degrades gracefully when `rclone` is not installed.

use crate::util;
use serde::Serialize;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct RcloneMount {
    pub mount_point: String,
    pub remote: String,
    pub config_path: String,
    pub rc_addr: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct RcloneContext {
    pub available: bool,
    pub in_mount: bool,
    pub remote: String,
    pub remote_path: String,
    pub mount_point: String,
    pub has_rc: bool,
    pub remotes: Vec<String>,
}

fn unescape_mount_field(s: &str) -> String {
    s.replace("\\040", " ")
        .replace("\\011", "\t")
        .replace("\\012", "\n")
        .replace("\\134", "\\")
}

/// Parse a `/proc/self/mounts` line and return `(source, mount_point)` if it is
/// a `fuse.rclone` mount.
fn parse_rclone_mount_line(line: &str) -> Option<(String, String)> {
    let mut parts = line.split_whitespace();
    let src = unescape_mount_field(parts.next()?);
    let target = unescape_mount_field(parts.next()?);
    let fstype = parts.next()?;
    if fstype == "fuse.rclone" {
        Some((src, target))
    } else {
        None
    }
}

/// Extract `(remote, config_path, rc_addr)` from an `rclone mount ...` cmdline
/// matching `mount_point`.
fn parse_rclone_cmdline(args: &[String], mount_point: &str) -> Option<(String, String, String)> {
    let is_rclone = args
        .first()
        .and_then(|a| Path::new(a).file_name())
        .map(|n| n == "rclone")
        .unwrap_or(false);
    if !is_rclone || !args.iter().any(|a| a == mount_point) {
        return None;
    }
    let mount_idx = args.iter().position(|a| a == "mount")?;
    let mut config_path = String::new();
    let mut rc_addr = String::new();
    let mut remote = String::new();

    let mut i = 1;
    while i < args.len() {
        let a = &args[i];
        if a == "--config" && i + 1 < args.len() {
            config_path = args[i + 1].clone();
            i += 2;
            continue;
        }
        if let Some(v) = a.strip_prefix("--config=") {
            config_path = v.to_string();
        } else if a == "--rc-addr" && i + 1 < args.len() {
            rc_addr = args[i + 1].clone();
            i += 2;
            continue;
        } else if let Some(v) = a.strip_prefix("--rc-addr=") {
            rc_addr = v.to_string();
        } else if i > mount_idx && remote.is_empty() && !a.starts_with('-') && a != mount_point {
            remote = a.clone();
        }
        i += 1;
    }
    Some((remote, config_path, rc_addr))
}

fn find_mount_process_meta(mount_point: &str) -> Option<(String, String, String)> {
    let entries = std::fs::read_dir("/proc").ok()?;
    for entry in entries.flatten() {
        let name = entry.file_name();
        let pid_str = name.to_string_lossy();
        if !pid_str.bytes().all(|b| b.is_ascii_digit()) {
            continue;
        }
        let Ok(raw) = std::fs::read(entry.path().join("cmdline")) else {
            continue;
        };
        if raw.is_empty() {
            continue;
        }
        let args: Vec<String> = raw
            .split(|&b| b == 0)
            .filter(|s| !s.is_empty())
            .map(|s| String::from_utf8_lossy(s).to_string())
            .collect();
        if let Some(meta) = parse_rclone_cmdline(&args, mount_point) {
            return Some(meta);
        }
    }
    None
}

pub fn detect_mount(path: &Path) -> Option<RcloneMount> {
    let mounts = std::fs::read_to_string("/proc/self/mounts").ok()?;
    let mut best: Option<(String, String)> = None;
    for line in mounts.lines() {
        let Some((src, target)) = parse_rclone_mount_line(line) else {
            continue;
        };
        if path.starts_with(&target)
            && best
                .as_ref()
                .map(|(_, prev)| target.len() > prev.len())
                .unwrap_or(true)
        {
            best = Some((src, target));
        }
    }
    let (src, mount_point) = best?;
    let (proc_remote, config_path, rc_addr) =
        find_mount_process_meta(&mount_point).unwrap_or_default();
    let remote = if !proc_remote.is_empty() {
        proc_remote
    } else if src.contains(':') {
        src
    } else {
        format!("{}:", src)
    };
    Some(RcloneMount {
        mount_point,
        remote,
        config_path,
        rc_addr,
    })
}

pub fn remote_path_for(mount: &RcloneMount, path: &Path) -> String {
    let rel = path
        .strip_prefix(&mount.mount_point)
        .ok()
        .map(|p| p.to_string_lossy().trim_start_matches('/').to_string())
        .unwrap_or_default();
    if rel.is_empty() {
        mount.remote.clone()
    } else if mount.remote.ends_with(':') || mount.remote.ends_with('/') {
        format!("{}{}", mount.remote, rel)
    } else {
        format!("{}/{}", mount.remote, rel)
    }
}

pub fn list_remotes() -> Vec<String> {
    let Some(bin) = util::which("rclone") else {
        return Vec::new();
    };
    let mut cmd = Command::new(bin);
    cmd.arg("listremotes");
    let (ok, out, _) = util::run_capture(cmd, None);
    if !ok {
        return Vec::new();
    }
    out.lines()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .collect()
}

pub fn context_for(path: &Path) -> RcloneContext {
    if util::which("rclone").is_none() {
        return RcloneContext {
            available: false,
            in_mount: false,
            remote: String::new(),
            remote_path: String::new(),
            mount_point: String::new(),
            has_rc: false,
            remotes: Vec::new(),
        };
    }
    let mount = detect_mount(path);
    let remotes = list_remotes();
    match mount {
        Some(m) => {
            let remote_path = remote_path_for(&m, path);
            RcloneContext {
                available: true,
                in_mount: true,
                remote: m.remote,
                remote_path,
                mount_point: m.mount_point,
                has_rc: !m.rc_addr.is_empty(),
                remotes,
            }
        }
        None => RcloneContext {
            available: !remotes.is_empty(),
            in_mount: false,
            remote: String::new(),
            remote_path: String::new(),
            mount_point: String::new(),
            has_rc: false,
            remotes,
        },
    }
}

fn rclone_cmd(bin: &PathBuf, config_path: &str) -> Command {
    let mut cmd = Command::new(bin);
    if !config_path.is_empty() {
        cmd.args(["--config", config_path]);
    }
    cmd
}

pub fn public_link(path: &Path) -> Result<String, String> {
    let bin = util::which("rclone").ok_or_else(|| "rclone is not installed".to_string())?;
    let mount =
        detect_mount(path).ok_or_else(|| "Selected item is not in an rclone mount".to_string())?;
    let target = remote_path_for(&mount, path);
    let mut cmd = rclone_cmd(&bin, &mount.config_path);
    cmd.args(["link", &target]);
    let (ok, out, err) = util::run_capture(cmd, None);
    if ok {
        let url = out.lines().next().unwrap_or("").trim().to_string();
        if url.is_empty() {
            Err("rclone returned an empty link".to_string())
        } else {
            Ok(url)
        }
    } else {
        Err(err.trim().to_string())
    }
}

pub fn refresh_vfs(path: &Path) -> Result<String, String> {
    let bin = util::which("rclone").ok_or_else(|| "rclone is not installed".to_string())?;
    let mount =
        detect_mount(path).ok_or_else(|| "Selected item is not in an rclone mount".to_string())?;
    if mount.rc_addr.is_empty() {
        return Err("rclone mount was not started with --rc".to_string());
    }
    let dir_path = if path.is_dir() {
        path
    } else {
        path.parent().unwrap_or(path)
    };
    let rel = dir_path
        .strip_prefix(&mount.mount_point)
        .ok()
        .map(|p| p.to_string_lossy().trim_start_matches('/').to_string())
        .unwrap_or_default();
    let mut cmd = Command::new(&bin);
    cmd.args(["rc", "--url", &mount.rc_addr, "vfs/refresh"]);
    if !rel.is_empty() {
        cmd.arg(format!("dir={}", rel));
    }
    let (ok, _, err) = util::run_capture(cmd, None);
    if ok {
        Ok("VFS directory cache refreshed".to_string())
    } else {
        Err(err.trim().to_string())
    }
}

pub fn remote_about(path: &Path) -> Result<String, String> {
    let bin = util::which("rclone").ok_or_else(|| "rclone is not installed".to_string())?;
    let mount =
        detect_mount(path).ok_or_else(|| "Selected item is not in an rclone mount".to_string())?;
    let mut cmd = rclone_cmd(&bin, &mount.config_path);
    cmd.args(["about", &mount.remote]);
    let (ok, out, err) = util::run_capture(cmd, None);
    if ok {
        let summary = out
            .lines()
            .map(str::trim)
            .filter(|l| !l.is_empty())
            .collect::<Vec<_>>()
            .join("  ·  ");
        Ok(if summary.is_empty() {
            "No quota information available".to_string()
        } else {
            summary
        })
    } else {
        Err(err.trim().to_string())
    }
}

pub fn remote_size(path: &Path) -> Result<String, String> {
    let bin = util::which("rclone").ok_or_else(|| "rclone is not installed".to_string())?;
    let mount =
        detect_mount(path).ok_or_else(|| "Selected item is not in an rclone mount".to_string())?;
    let target = remote_path_for(&mount, path);
    let mut cmd = rclone_cmd(&bin, &mount.config_path);
    cmd.args(["size", &target]);
    let (ok, out, err) = util::run_capture(cmd, None);
    if ok {
        let summary = out
            .lines()
            .map(str::trim)
            .filter(|l| !l.is_empty())
            .collect::<Vec<_>>()
            .join("  ·  ");
        Ok(summary)
    } else {
        Err(err.trim().to_string())
    }
}

pub fn transfer_to_remote(path: &Path, remote: &str, is_move: bool) -> Result<String, String> {
    let bin = util::which("rclone").ok_or_else(|| "rclone is not installed".to_string())?;
    let subcmd = if is_move { "move" } else { "copy" };
    let dest = if path.is_dir() {
        let name = path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        if remote.ends_with(':') || remote.ends_with('/') {
            format!("{}{}", remote, name)
        } else {
            format!("{}/{}", remote, name)
        }
    } else {
        remote.to_string()
    };
    let mut cmd = Command::new(&bin);
    cmd.args([subcmd, &path.to_string_lossy(), &dest]);
    let (ok, _, err) = util::run_capture(cmd, None);
    if ok {
        Ok(format!(
            "{} to {}",
            if is_move { "Moved" } else { "Uploaded" },
            dest
        ))
    } else {
        Err(err.trim().to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_rclone_mount_and_cmdline() {
        let line = "Personal\\040Drive /home/alice/Personal\\040Drive fuse.rclone rw,relatime 0 0";
        let (src, target) = parse_rclone_mount_line(line).unwrap();
        assert_eq!(src, "Personal Drive");
        assert_eq!(target, "/home/alice/Personal Drive");

        let args: Vec<String> = [
            "/usr/bin/rclone",
            "--config",
            "/tmp/rclone.conf",
            "mount",
            "gdrive:",
            "/home/alice/Personal Drive",
            "--rc",
            "--rc-addr",
            "unix:///tmp/rc.sock",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect();
        let (remote, cfg, rc) = parse_rclone_cmdline(&args, "/home/alice/Personal Drive").unwrap();
        assert_eq!(remote, "gdrive:");
        assert_eq!(cfg, "/tmp/rclone.conf");
        assert_eq!(rc, "unix:///tmp/rc.sock");
    }

    #[test]
    fn builds_remote_path() {
        let mount = RcloneMount {
            mount_point: "/mnt/gdrive".into(),
            remote: "gdrive:".into(),
            config_path: String::new(),
            rc_addr: String::new(),
        };
        assert_eq!(
            remote_path_for(&mount, Path::new("/mnt/gdrive/Docs/report.pdf")),
            "gdrive:Docs/report.pdf"
        );
        assert_eq!(remote_path_for(&mount, Path::new("/mnt/gdrive")), "gdrive:");
    }
}
