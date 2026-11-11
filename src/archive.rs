//! Archive creation, extraction and listing through the usual command line
//! tools (7-Zip, tar, cpio, unzip/unrar/python3 as fallbacks).
//!
//! Safety rules:
//! * member names are always passed as `./name`, so a file called
//!   `--checkpoint-action=exec=...` can never be read as an option;
//! * passwords go through stdin, never argv (`/proc/*/cmdline` is world
//!   readable);
//! * every run can be cancelled (the child is killed).

use crate::util::{which, which_any};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::Duration;

#[derive(Debug, PartialEq)]
pub enum ArchiveError {
    /// The archive is encrypted and no (or a wrong) password was given.
    NeedPassword,
    /// A required program is not installed.
    MissingTool(&'static str),
    Cancelled,
    Failed(String),
}

impl std::fmt::Display for ArchiveError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ArchiveError::NeedPassword => write!(f, "This archive needs a password"),
            ArchiveError::MissingTool(t) => write!(f, "'{}' is not installed", t),
            ArchiveError::Cancelled => write!(f, "Cancelled"),
            ArchiveError::Failed(m) => write!(f, "{}", m),
        }
    }
}

/// Recognised archive kinds, by file name.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Kind {
    Zip,
    SevenZip,
    Rar,
    Tar,
    TarGz,
    TarXz,
    TarBz2,
    TarZst,
    Cpio,
    Iso,
    /// Anything else 7-Zip understands (cab, arj, lzh, ...).
    Other7z,
}

pub fn kind_of(path: &Path) -> Option<Kind> {
    let n = path.file_name()?.to_string_lossy().to_lowercase();
    let ends = |s: &str| n.ends_with(s);
    Some(if ends(".tar.gz") || ends(".tgz") {
        Kind::TarGz
    } else if ends(".tar.xz") || ends(".txz") {
        Kind::TarXz
    } else if ends(".tar.bz2") || ends(".tbz2") || ends(".tbz") {
        Kind::TarBz2
    } else if ends(".tar.zst") || ends(".tzst") {
        Kind::TarZst
    } else if ends(".tar") {
        Kind::Tar
    } else if ends(".zip") || ends(".zipx") || ends(".jar") || ends(".apk") {
        Kind::Zip
    } else if ends(".7z") {
        Kind::SevenZip
    } else if ends(".rar") {
        Kind::Rar
    } else if ends(".cpio") {
        Kind::Cpio
    } else if ends(".iso") {
        Kind::Iso
    } else if ends(".cab") || ends(".arj") || ends(".lha") || ends(".lzh") {
        Kind::Other7z
    } else {
        return None;
    })
}

pub fn is_archive(path: &Path) -> bool {
    kind_of(path).is_some()
}

/// Archive name without its (possibly double) extension.
pub fn base_name(path: &Path) -> String {
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "archive".into());
    let lower = name.to_lowercase();
    for suffix in [
        ".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2", ".tgz", ".txz", ".tbz2", ".tbz", ".tzst",
        ".zip", ".zipx", ".7z", ".rar", ".tar", ".cpio", ".iso", ".cab", ".arj", ".lha", ".lzh",
    ] {
        if lower.ends_with(suffix) && name.len() > suffix.len() {
            return name[..name.len() - suffix.len()].to_string();
        }
    }
    name
}

fn seven_zip() -> Option<PathBuf> {
    which_any(&["7z", "7zz", "7za"])
}

/// Runs `cmd`, feeding `stdin` and polling `cancelled` so a long run can be
/// stopped. Returns (success, combined output).
fn run(
    mut cmd: Command,
    stdin: Option<String>,
    cancelled: &dyn Fn() -> bool,
) -> Result<(bool, String), ArchiveError> {
    cmd.stdin(if stdin.is_some() {
        Stdio::piped()
    } else {
        Stdio::null()
    })
    .stdout(Stdio::piped())
    .stderr(Stdio::piped());
    let mut child = cmd
        .spawn()
        .map_err(|e| ArchiveError::Failed(e.to_string()))?;
    if let Some(data) = stdin {
        if let Some(mut s) = child.stdin.take() {
            let _ = s.write_all(data.as_bytes());
        }
    }
    // Drain output on threads so a chatty tool can't block on a full pipe.
    let mut out = child.stdout.take();
    let mut err = child.stderr.take();
    let t_out = std::thread::spawn(move || {
        let mut s = String::new();
        if let Some(o) = out.as_mut() {
            let _ = std::io::Read::read_to_string(o, &mut s);
        }
        s
    });
    let t_err = std::thread::spawn(move || {
        let mut s = String::new();
        if let Some(e) = err.as_mut() {
            let _ = std::io::Read::read_to_string(e, &mut s);
        }
        s
    });
    let status = loop {
        match child.try_wait() {
            Ok(Some(st)) => break st,
            Ok(None) => {
                if cancelled() {
                    let _ = child.kill();
                    let _ = child.wait();
                    let _ = t_out.join();
                    let _ = t_err.join();
                    return Err(ArchiveError::Cancelled);
                }
                std::thread::sleep(Duration::from_millis(80));
            }
            Err(e) => return Err(ArchiveError::Failed(e.to_string())),
        }
    };
    let text = format!(
        "{}\n{}",
        t_out.join().unwrap_or_default(),
        t_err.join().unwrap_or_default()
    );
    Ok((status.success(), text))
}

fn looks_like_password_error(output: &str) -> bool {
    let o = output.to_lowercase();
    o.contains("wrong password")
        || o.contains("cannot open encrypted archive")
        || o.contains("can not open encrypted archive")
        || o.contains("enter password") && o.contains("error")
}

fn last_error_line(output: &str) -> String {
    output
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .rfind(|l| {
            l.to_lowercase().contains("error") || l.starts_with("tar:") || l.contains("cannot")
        })
        .unwrap_or("The archive tool reported an error")
        .to_string()
}

/// `./name` for each item, relative to `parent`. Items must live in `parent`.
fn member_args(items: &[PathBuf], parent: &Path) -> Vec<String> {
    items
        .iter()
        .map(|p| {
            let rel = p
                .strip_prefix(parent)
                .map(|r| r.to_path_buf())
                .unwrap_or_else(|_| PathBuf::from(p.file_name().unwrap_or_default()));
            format!("./{}", rel.to_string_lossy())
        })
        .collect()
}

fn collect_cpio(root: &Path, rel: &str, out: &mut Vec<String>) {
    out.push(rel.to_string());
    let Ok(meta) = fs::symlink_metadata(root) else {
        return;
    };
    if !meta.is_dir() {
        return;
    }
    if let Ok(rd) = fs::read_dir(root) {
        for e in rd.flatten() {
            let child = format!(
                "{}/{}",
                rel.trim_end_matches('/'),
                e.file_name().to_string_lossy()
            );
            collect_cpio(&e.path(), &child, out);
        }
    }
}

/// Creates `archive` from `items` (all inside the same folder). `format` is
/// one of zip, zip_encrypted, 7z, tar.gz, tar.xz, tar.bz2, tar.zst, cpio.
pub fn compress(
    archive: &Path,
    items: &[PathBuf],
    format: &str,
    password: &str,
    cancelled: &dyn Fn() -> bool,
) -> Result<(), ArchiveError> {
    let parent = items
        .first()
        .and_then(|p| p.parent())
        .ok_or_else(|| ArchiveError::Failed("nothing to compress".into()))?
        .to_path_buf();
    let members = member_args(items, &parent);
    let pw = if password.is_empty() {
        None
    } else {
        Some(format!("{}\n{}\n", password, password))
    };
    let format = if format == "zip_encrypted" && pw.is_none() {
        "zip"
    } else {
        format
    };

    let result = match format {
        "7z" | "zip_encrypted" | "zip"
            if format == "7z" || pw.is_some() || which("zip").is_none() =>
        {
            let bin = seven_zip().ok_or(ArchiveError::MissingTool("7z (p7zip / 7zip)"))?;
            let mut cmd = Command::new(bin);
            cmd.current_dir(&parent).args(["a", "-y", "-bd"]);
            if format != "7z" {
                cmd.args(["-tzip"]);
                if pw.is_some() {
                    cmd.arg("-mem=AES256");
                }
            }
            if pw.is_some() {
                // `-p` without a value makes 7-Zip read the password from stdin.
                cmd.arg("-p");
                if format == "7z" {
                    cmd.arg("-mhe=on");
                }
            }
            cmd.arg("--").arg(archive).args(&members);
            run(cmd, pw.clone(), cancelled)?
        }
        "zip" => {
            let mut cmd = Command::new(which("zip").unwrap());
            // zip wants `--` after the archive name (the archive path is absolute).
            cmd.current_dir(&parent)
                .args(["-r", "-q", "-y"])
                .arg(archive)
                .arg("--")
                .args(&members);
            run(cmd, None, cancelled)?
        }
        "zip_encrypted" => return Err(ArchiveError::MissingTool("7z (p7zip / 7zip)")),
        "tar.gz" | "tar.xz" | "tar.bz2" | "tar" => {
            let flag = match format {
                "tar.gz" => "-czf",
                "tar.xz" => "-cJf",
                "tar.bz2" => "-cjf",
                _ => "-cf",
            };
            let mut cmd = Command::new(which("tar").ok_or(ArchiveError::MissingTool("tar"))?);
            cmd.arg(flag)
                .arg(archive)
                .arg("-C")
                .arg(&parent)
                .arg("--")
                .args(&members);
            run(cmd, None, cancelled)?
        }
        "tar.zst" => {
            let tar = which("tar").ok_or(ArchiveError::MissingTool("tar"))?;
            let mut cmd = Command::new(&tar);
            cmd.args(["--zstd", "-cf"])
                .arg(archive)
                .arg("-C")
                .arg(&parent)
                .arg("--")
                .args(&members);
            let first = run(cmd, None, cancelled)?;
            if first.0 {
                first
            } else {
                let mut cmd = Command::new(&tar);
                cmd.args(["-I", "zstd", "-cf"])
                    .arg(archive)
                    .arg("-C")
                    .arg(&parent)
                    .arg("--")
                    .args(&members);
                run(cmd, None, cancelled)?
            }
        }
        "cpio" => {
            let cpio = which("cpio").ok_or(ArchiveError::MissingTool("cpio"))?;
            let mut list = Vec::new();
            for (item, member) in items.iter().zip(&members) {
                collect_cpio(item, member, &mut list);
            }
            let out = fs::File::create(archive).map_err(|e| ArchiveError::Failed(e.to_string()))?;
            let mut child = Command::new(cpio)
                .current_dir(&parent)
                .args(["--null", "-o", "-H", "newc", "--quiet"])
                .stdin(Stdio::piped())
                .stdout(Stdio::from(out))
                .stderr(Stdio::piped())
                .spawn()
                .map_err(|e| ArchiveError::Failed(e.to_string()))?;
            if let Some(mut stdin) = child.stdin.take() {
                for item in &list {
                    let _ = stdin.write_all(item.as_bytes());
                    let _ = stdin.write_all(b"\0");
                }
            }
            let out = child
                .wait_with_output()
                .map_err(|e| ArchiveError::Failed(e.to_string()))?;
            (
                out.status.success(),
                String::from_utf8_lossy(&out.stderr).to_string(),
            )
        }
        other => {
            return Err(ArchiveError::Failed(format!(
                "unsupported format '{}'",
                other
            )))
        }
    };

    if result.0 {
        Ok(())
    } else {
        let _ = fs::remove_file(archive);
        Err(ArchiveError::Failed(last_error_line(&result.1)))
    }
}

/// Extracts `archive` into `target` (created if needed). Returns
/// `NeedPassword` when the archive is encrypted and `password` is empty or
/// wrong, so the caller can ask and try again.
pub fn extract(
    archive: &Path,
    target: &Path,
    password: &str,
    cancelled: &dyn Fn() -> bool,
) -> Result<(), ArchiveError> {
    let kind = kind_of(archive).ok_or_else(|| ArchiveError::Failed("not an archive".into()))?;
    fs::create_dir_all(target).map_err(|e| ArchiveError::Failed(e.to_string()))?;
    let (ok, output) = match kind {
        Kind::Tar | Kind::TarGz | Kind::TarXz | Kind::TarBz2 | Kind::TarZst => {
            let tar = which("tar").ok_or(ArchiveError::MissingTool("tar"))?;
            let mut cmd = Command::new(tar);
            match kind {
                Kind::TarGz => cmd.arg("-xzf"),
                Kind::TarXz => cmd.arg("-xJf"),
                Kind::TarBz2 => cmd.arg("-xjf"),
                Kind::TarZst => cmd.args(["--zstd", "-xf"]),
                _ => cmd.arg("-xf"),
            };
            cmd.arg(archive)
                .arg("-C")
                .arg(target)
                .arg("--no-same-owner");
            run(cmd, None, cancelled)?
        }
        _ => {
            if let Some(bin) = seven_zip() {
                let mut cmd = Command::new(bin);
                cmd.args(["x", "-y", "-bd"])
                    .arg(format!("-o{}", target.display()));
                // Without -p, 7-Zip asks for a password on stdin only when the
                // archive needs one (`-p` alone would mean "empty password").
                let stdin = if password.is_empty() {
                    None
                } else {
                    Some(format!("{}\n", password))
                };
                cmd.arg("--").arg(archive);
                run(cmd, stdin, cancelled)?
            } else {
                match kind {
                    Kind::Zip => {
                        if let Some(unzip) = which("unzip") {
                            let mut cmd = Command::new(unzip);
                            // -P would put the password in argv; without 7z we
                            // can only handle unencrypted zips safely.
                            cmd.args(["-q", "-o"]).arg(archive).arg("-d").arg(target);
                            run(cmd, None, cancelled)?
                        } else if let Some(py) = which("python3") {
                            let mut cmd = Command::new(py);
                            cmd.args(["-m", "zipfile", "-e"]).arg(archive).arg(target);
                            run(cmd, None, cancelled)?
                        } else {
                            return Err(ArchiveError::MissingTool("7z or unzip"));
                        }
                    }
                    Kind::Rar => {
                        let unrar =
                            which("unrar").ok_or(ArchiveError::MissingTool("7z or unrar"))?;
                        let mut cmd = Command::new(unrar);
                        cmd.args(["x", "-o+", "-p-"])
                            .arg(archive)
                            .arg(format!("{}/", target.display()));
                        run(cmd, None, cancelled)?
                    }
                    Kind::Cpio => {
                        let cpio = which("cpio").ok_or(ArchiveError::MissingTool("cpio"))?;
                        let input = fs::File::open(archive)
                            .map_err(|e| ArchiveError::Failed(e.to_string()))?;
                        let out = Command::new(cpio)
                            .current_dir(target)
                            .args(["-idm", "--no-absolute-filenames", "--quiet"])
                            .stdin(Stdio::from(input))
                            .output()
                            .map_err(|e| ArchiveError::Failed(e.to_string()))?;
                        (
                            out.status.success(),
                            String::from_utf8_lossy(&out.stderr).to_string(),
                        )
                    }
                    _ => return Err(ArchiveError::MissingTool("7z (p7zip / 7zip)")),
                }
            }
        }
    };
    if ok {
        return Ok(());
    }
    if looks_like_password_error(&output)
        || (!ok && password.is_empty() && output.to_lowercase().contains("password"))
    {
        return Err(ArchiveError::NeedPassword);
    }
    Err(ArchiveError::Failed(last_error_line(&output)))
}

#[derive(Clone, Debug, PartialEq)]
pub struct Entry {
    /// Path inside the archive, without leading `./` or `/`, no trailing `/`.
    pub path: String,
    pub is_dir: bool,
    pub size: u64,
    /// "YYYY-MM-DD hh:mm:ss" when the tool reports it.
    pub modified: String,
}

fn clean_member(p: &str) -> String {
    let mut s = p.trim();
    while let Some(rest) = s.strip_prefix("./") {
        s = rest;
    }
    s.trim_start_matches('/').trim_end_matches('/').to_string()
}

/// Parses `7z l -slt` output.
pub fn parse_7z_listing(text: &str) -> Vec<Entry> {
    let mut out = Vec::new();
    // The technical listing starts after the "----------" separator line.
    let body = match text.find("\n----------\n") {
        Some(i) => &text[i + 12..],
        None => text,
    };
    for block in body.split("\n\n") {
        let mut path = None;
        let mut is_dir = false;
        let mut size = 0;
        let mut modified = String::new();
        for line in block.lines() {
            let Some((k, v)) = line.split_once(" = ") else {
                continue;
            };
            match k {
                "Path" => path = Some(clean_member(v)),
                "Folder" => is_dir = v.trim() == "+",
                "Attributes" => is_dir = is_dir || v.starts_with('D'),
                "Size" => size = v.trim().parse().unwrap_or(0),
                "Modified" => modified = v.trim().chars().take(19).collect(),
                _ => {}
            }
        }
        if let Some(p) = path.filter(|p| !p.is_empty()) {
            out.push(Entry {
                path: p,
                is_dir,
                size,
                modified,
            });
        }
    }
    out
}

/// Parses `tar -tv --full-time` output ("perm owner size date time name").
pub fn parse_tar_listing(text: &str) -> Vec<Entry> {
    let mut out = Vec::new();
    for line in text.lines() {
        let mut rest = line.trim_start();
        let mut fields = Vec::new();
        for _ in 0..5 {
            let Some((f, r)) = rest.split_once(char::is_whitespace) else {
                break;
            };
            fields.push(f);
            rest = r.trim_start();
        }
        if fields.len() < 5 || rest.is_empty() {
            continue;
        }
        let is_dir = fields[0].starts_with('d');
        let name = match fields[0].chars().next() {
            Some('l') => rest.split(" -> ").next().unwrap_or(rest),
            Some('h') => rest.split(" link to ").next().unwrap_or(rest),
            _ => rest,
        };
        let path = clean_member(name);
        if path.is_empty() {
            continue;
        }
        out.push(Entry {
            path,
            is_dir,
            size: fields[2].parse().unwrap_or(0),
            modified: format!("{} {}", fields[3], fields[4])
                .chars()
                .take(19)
                .collect(),
        });
    }
    out
}

/// Adds folder entries that are only implied by member paths (zip files
/// often omit them).
pub fn with_implied_dirs(mut entries: Vec<Entry>) -> Vec<Entry> {
    let mut known: std::collections::HashSet<String> = entries
        .iter()
        .filter(|e| e.is_dir)
        .map(|e| e.path.clone())
        .collect();
    let mut extra = Vec::new();
    for e in &entries {
        let mut p = Path::new(&e.path).parent();
        while let Some(dir) = p {
            let s = dir.to_string_lossy().to_string();
            if s.is_empty() {
                break;
            }
            if known.insert(s.clone()) {
                extra.push(Entry {
                    path: s,
                    is_dir: true,
                    size: 0,
                    modified: String::new(),
                });
            }
            p = dir.parent();
        }
    }
    entries.extend(extra);
    entries
}

/// Lists everything inside an archive.
pub fn list(archive: &Path, password: &str) -> Result<Vec<Entry>, ArchiveError> {
    let never = || false;
    let kind = kind_of(archive).ok_or_else(|| ArchiveError::Failed("not an archive".into()))?;
    let entries = match kind {
        Kind::Tar | Kind::TarGz | Kind::TarXz | Kind::TarBz2 | Kind::TarZst => {
            let tar = which("tar").ok_or(ArchiveError::MissingTool("tar"))?;
            let mut cmd = Command::new(tar);
            if kind == Kind::TarZst {
                cmd.arg("--zstd");
            }
            cmd.args(["-tv", "--full-time", "-f"]).arg(archive);
            let (ok, text) = run(cmd, None, &never)?;
            if !ok {
                return Err(ArchiveError::Failed(last_error_line(&text)));
            }
            parse_tar_listing(&text)
        }
        _ => {
            let bin = seven_zip().ok_or(ArchiveError::MissingTool("7z (p7zip / 7zip)"))?;
            let mut cmd = Command::new(bin);
            cmd.args(["l", "-slt"]);
            let stdin = if password.is_empty() {
                None
            } else {
                Some(format!("{}\n", password))
            };
            cmd.arg("--").arg(archive);
            let (ok, text) = run(cmd, stdin, &never)?;
            if !ok {
                if looks_like_password_error(&text) {
                    return Err(ArchiveError::NeedPassword);
                }
                return Err(ArchiveError::Failed(last_error_line(&text)));
            }
            parse_7z_listing(&text)
        }
    };
    Ok(with_implied_dirs(entries))
}

/// Extracts a single member (file or folder) into `target_dir`, returning
/// the extracted path. Used to open files from inside an archive.
pub fn extract_member(
    archive: &Path,
    member: &str,
    target_dir: &Path,
    password: &str,
) -> Result<PathBuf, ArchiveError> {
    let never = || false;
    let kind = kind_of(archive).ok_or_else(|| ArchiveError::Failed("not an archive".into()))?;
    fs::create_dir_all(target_dir).map_err(|e| ArchiveError::Failed(e.to_string()))?;
    let (ok, text) = match kind {
        Kind::Tar | Kind::TarGz | Kind::TarXz | Kind::TarBz2 | Kind::TarZst => {
            let tar = which("tar").ok_or(ArchiveError::MissingTool("tar"))?;
            // Members may have been stored with or without a leading "./".
            let try_names = [member.to_string(), format!("./{}", member)];
            let mut last = (false, String::new());
            for name in try_names {
                let mut cmd = Command::new(&tar);
                if kind == Kind::TarZst {
                    cmd.arg("--zstd");
                }
                cmd.arg("-xf")
                    .arg(archive)
                    .arg("-C")
                    .arg(target_dir)
                    .arg("--no-same-owner")
                    .arg("--")
                    .arg(&name);
                last = run(cmd, None, &never)?;
                if last.0 {
                    break;
                }
            }
            last
        }
        _ => {
            let bin = seven_zip().ok_or(ArchiveError::MissingTool("7z (p7zip / 7zip)"))?;
            let mut cmd = Command::new(bin);
            cmd.args(["x", "-y", "-bd", "-spd"])
                .arg(format!("-o{}", target_dir.display()));
            let stdin = if password.is_empty() {
                None
            } else {
                Some(format!("{}\n", password))
            };
            cmd.arg("--").arg(archive).arg(member);
            run(cmd, stdin, &never)?
        }
    };
    if !ok {
        if looks_like_password_error(&text) {
            return Err(ArchiveError::NeedPassword);
        }
        return Err(ArchiveError::Failed(last_error_line(&text)));
    }
    let out = target_dir.join(member);
    if fs::symlink_metadata(&out).is_ok() {
        Ok(out)
    } else {
        Err(ArchiveError::Failed(
            "the file was not found in the archive".into(),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sandbox(tag: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("loaf-arch-{}-{}", tag, std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn kinds_and_base_names() {
        assert_eq!(kind_of(Path::new("a.TAR.GZ")), Some(Kind::TarGz));
        assert_eq!(kind_of(Path::new("a.tbz2")), Some(Kind::TarBz2));
        assert_eq!(kind_of(Path::new("a.txt")), None);
        assert_eq!(base_name(Path::new("/x/My Files.tar.zst")), "My Files");
        assert_eq!(base_name(Path::new("/x/.zip")), ".zip");
    }

    #[test]
    fn option_like_names_are_not_options() {
        let d = sandbox("inject");
        let evil = "--checkpoint=1 --checkpoint-action=exec=touch PWNED";
        fs::write(d.join(evil), b"x").unwrap();
        fs::write(d.join("-rf"), b"y").unwrap();
        for fmt in ["tar.gz", "tar.xz", "tar.bz2", "zip"] {
            let arch = d.join(format!("out.{}", fmt));
            compress(&arch, &[d.join(evil), d.join("-rf")], fmt, "", &|| false).unwrap();
            assert!(arch.exists(), "{} archive created", fmt);
            assert!(
                !d.join("PWNED").exists(),
                "{} must not execute file names",
                fmt
            );
            let names: Vec<String> = list(&arch, "")
                .unwrap()
                .into_iter()
                .map(|e| e.path)
                .collect();
            assert!(
                names.contains(&evil.to_string()),
                "{} keeps the name: {:?}",
                fmt,
                names
            );
            let out = d.join(format!("x-{}", fmt));
            extract(&arch, &out, "", &|| false).unwrap();
            assert_eq!(fs::read(out.join(evil)).unwrap(), b"x");
        }
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn encrypted_round_trip_without_argv_password() {
        if seven_zip().is_none() {
            return;
        }
        let d = sandbox("pw");
        fs::create_dir_all(d.join("docs")).unwrap();
        fs::write(d.join("docs/secret.txt"), b"top secret").unwrap();
        for fmt in ["7z", "zip_encrypted"] {
            let arch = d.join(if fmt == "7z" { "s.7z" } else { "s.zip" });
            compress(&arch, &[d.join("docs")], fmt, "hunter2", &|| false).unwrap();
            let out = d.join(format!("out-{}", fmt));
            assert_eq!(
                extract(&arch, &out, "", &|| false),
                Err(ArchiveError::NeedPassword)
            );
            assert_eq!(
                extract(&arch, &d.join("bad"), "wrong", &|| false),
                Err(ArchiveError::NeedPassword)
            );
            extract(&arch, &out, "hunter2", &|| false).unwrap();
            assert_eq!(
                fs::read(out.join("docs/secret.txt")).unwrap(),
                b"top secret"
            );
        }
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn lists_and_extracts_one_member() {
        let d = sandbox("member");
        fs::create_dir_all(d.join("proj/src")).unwrap();
        fs::write(d.join("proj/src/main.rs"), b"fn main(){}").unwrap();
        fs::write(d.join("proj/readme"), b"hi").unwrap();
        for fmt in ["tar.gz", "zip"] {
            let arch = d.join(format!("p.{}", fmt));
            compress(&arch, &[d.join("proj")], fmt, "", &|| false).unwrap();
            let entries = list(&arch, "").unwrap();
            assert!(
                entries.iter().any(|e| e.path == "proj/src" && e.is_dir),
                "{:?}",
                entries
            );
            assert!(entries
                .iter()
                .any(|e| e.path == "proj/src/main.rs" && !e.is_dir && e.size == 11));
            if fmt == "zip" && seven_zip().is_none() {
                continue;
            }
            let got = extract_member(
                &arch,
                "proj/src/main.rs",
                &d.join(format!("one-{}", fmt)),
                "",
            )
            .unwrap();
            assert_eq!(fs::read(got).unwrap(), b"fn main(){}");
        }
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn parses_tar_lines_with_spaces_and_links() {
        let t = "drwxr-xr-x u/g 0 2024-01-02 03:04:05 ./a dir/\n-rw-r--r-- u/g 12 2024-01-02 03:04:05 ./a dir/f g.txt\nlrwxrwxrwx u/g 0 2024-01-02 03:04:05 ./ln -> f g.txt\n";
        let e = parse_tar_listing(t);
        assert_eq!(e.len(), 3);
        assert_eq!(
            e[0],
            Entry {
                path: "a dir".into(),
                is_dir: true,
                size: 0,
                modified: "2024-01-02 03:04:05".into()
            }
        );
        assert_eq!(e[1].path, "a dir/f g.txt");
        assert_eq!(e[1].size, 12);
        assert_eq!(e[2].path, "ln");
    }

    #[test]
    fn cancel_kills_the_tool() {
        let d = sandbox("cancel");
        let r = run(
            {
                let mut c = Command::new("sleep");
                c.arg("5");
                c
            },
            None,
            &|| true,
        );
        assert_eq!(r.unwrap_err(), ArchiveError::Cancelled);
        fs::remove_dir_all(&d).unwrap();
    }
}
