//! Quick Look previews and the Properties dialog data.

use crate::{archive, listing, native, util};
use serde::Serialize;
use std::fs;
use std::io::Read;
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use std::path::Path;

/// How much of a text file the preview reads (never the whole file).
const PREVIEW_BYTES: u64 = 256 * 1024;

#[derive(Serialize, Default)]
pub struct QuickLook {
    pub name: String,
    pub path: String,
    /// image | text | media | thumbnail | archive | folder | none
    pub kind: String,
    pub language: String,
    pub text: String,
    pub truncated: bool,
    pub image_url: String,
    /// For "thumbnail" kind: id for image://thumb/ (video, pdf, font...).
    pub thumb_id: String,
    pub size_str: String,
    pub modified_str: String,
    pub mime: String,
    pub note: String,
}

pub fn preview_language(ext: &str) -> &'static str {
    match ext {
        "md" | "markdown" => "markdown",
        "rs" => "rust",
        "py" | "pyw" => "python",
        "js" | "mjs" | "cjs" | "ts" | "jsx" | "tsx" => "javascript",
        "c" | "h" => "c",
        "cpp" | "cc" | "cxx" | "hpp" | "hh" => "cpp",
        "java" | "kt" | "kts" | "scala" => "java",
        "go" => "go",
        "sh" | "bash" | "zsh" | "fish" | "nu" | "ps1" | "bat" | "cmd" => "shell",
        "nix" => "nix",
        "lua" => "lua",
        "sql" => "sql",
        "html" | "htm" | "xml" | "svg" | "qml" | "xhtml" => "markup",
        "css" | "scss" | "sass" | "less" => "css",
        "json" | "json5" | "jsonc" => "json",
        "yaml" | "yml" | "toml" | "ini" | "conf" | "cfg" | "properties" => "yaml",
        "rb" | "php" | "swift" | "hs" | "ml" | "ex" | "exs" | "erl" | "clj" | "zig" | "dart" | "r" | "jl" => "c_like",
        _ => "text",
    }
}

/// Reads the head of a file; (text, truncated, looks_binary).
/// Archive contents for Quick Look: (listing, truncated, note). Slow for
/// large compressed archives; call from a worker thread.
pub fn archive_preview(path: &Path) -> (String, bool, String) {
    match archive::list(path, "") {
        Ok(entries) => {
            let total = entries.iter().filter(|e| !e.is_dir).count();
            let mut lines: Vec<String> = entries
                .iter()
                .take(400)
                .map(|e| if e.is_dir { format!("{}/", e.path) } else { format!("{}  ({})", e.path, util::format_size(e.size)) })
                .collect();
            lines.sort();
            (lines.join("\n"), entries.len() > 400, format!("Archive · {} files", total))
        }
        Err(archive::ArchiveError::NeedPassword) => (String::new(), false, "Encrypted archive".into()),
        Err(e) => (String::new(), false, e.to_string()),
    }
}

pub fn read_head(path: &Path) -> (String, bool, bool) {
    let Ok(f) = fs::File::open(path) else { return (String::new(), false, false) };
    let len = f.metadata().map(|m| m.len()).unwrap_or(0);
    let mut buf = Vec::with_capacity(PREVIEW_BYTES.min(len) as usize);
    if f.take(PREVIEW_BYTES).read_to_end(&mut buf).is_err() {
        return (String::new(), false, false);
    }
    let binary = buf.iter().take(8192).any(|b| *b == 0);
    if binary {
        return (String::new(), len > PREVIEW_BYTES, true);
    }
    // Don't cut a multi-byte character in half at the end.
    let mut end = buf.len();
    if let Err(e) = std::str::from_utf8(&buf) {
        if e.error_len().is_none() {
            end = e.valid_up_to(); // only an incomplete character at the end
        }
    }
    (String::from_utf8_lossy(&buf[..end]).to_string(), len > PREVIEW_BYTES, false)
}

pub fn quick_look(path: &Path) -> QuickLook {
    let name = path.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
    let meta = fs::metadata(path).ok();
    let mut q = QuickLook {
        name: name.clone(),
        path: path.to_string_lossy().to_string(),
        kind: "none".into(),
        note: "No preview available".into(),
        ..Default::default()
    };
    let Some(meta) = meta else {
        q.note = "This item no longer exists".into();
        return q;
    };
    q.modified_str = crate::pane::relative_time(meta.mtime());
    if meta.is_dir() {
        let n = fs::read_dir(path).map(|r| r.count()).unwrap_or(0);
        q.kind = "folder".into();
        q.note = format!("Folder · {} item{}", n, if n == 1 { "" } else { "s" });
        return q;
    }
    q.size_str = util::format_size(meta.len());
    q.mime = native::mime_type(path, true);
    let ext = listing::extension(&name);
    if listing::is_image_ext(&ext) || q.mime.starts_with("image/") {
        q.kind = "image".into();
        q.image_url = format!("file://{}", crate::trash::encode_path(path));
        // Formats Qt can't decode fall back to a large generated thumbnail.
        q.thumb_id = format!("{}-{}", crate::pane::hex_path(&q.path), meta.mtime());
        q.note.clear();
        return q;
    }
    if archive::is_archive(path) {
        // Listing may decompress the whole file (big .tar.gz): done later on a
        // worker thread through archive_preview(), never here on the UI thread.
        q.kind = "archive".into();
        q.note = "Reading archive…".into();
        return q;
    }
    let (_, _, _, thumbable) = listing::classify(&name, false);
    if listing::is_video_ext(&ext) || listing::is_audio_ext(&ext) || thumbable {
        q.kind = if thumbable { "thumbnail" } else { "media" }.into();
        q.thumb_id = format!("{}-{}", crate::pane::hex_path(&q.path), meta.mtime());
        q.note = "Press Enter to open it".into();
        return q;
    }
    let (text, truncated, binary) = read_head(path);
    if binary {
        q.note = "Binary file · no text preview".into();
        return q;
    }
    q.kind = "text".into();
    q.language = preview_language(&ext).into();
    q.text = text;
    q.truncated = truncated;
    q.note.clear();
    q
}

fn user_name(uid: u32) -> String {
    let mut buf = vec![0i8; 4096];
    let mut pw: libc::passwd = unsafe { std::mem::zeroed() };
    let mut out: *mut libc::passwd = std::ptr::null_mut();
    let rc = unsafe { libc::getpwuid_r(uid, &mut pw, buf.as_mut_ptr(), buf.len(), &mut out) };
    if rc == 0 && !out.is_null() {
        return unsafe { std::ffi::CStr::from_ptr(pw.pw_name) }.to_string_lossy().to_string();
    }
    uid.to_string()
}

fn group_name(gid: u32) -> String {
    let mut buf = vec![0i8; 4096];
    let mut gr: libc::group = unsafe { std::mem::zeroed() };
    let mut out: *mut libc::group = std::ptr::null_mut();
    let rc = unsafe { libc::getgrgid_r(gid, &mut gr, buf.as_mut_ptr(), buf.len(), &mut out) };
    if rc == 0 && !out.is_null() {
        return unsafe { std::ffi::CStr::from_ptr(gr.gr_name) }.to_string_lossy().to_string();
    }
    gid.to_string()
}

pub fn mode_string(mode: u32, is_dir: bool, is_link: bool) -> String {
    let mut s = String::with_capacity(10);
    s.push(if is_link { 'l' } else if is_dir { 'd' } else { '-' });
    for shift in [6, 3, 0] {
        let bits = (mode >> shift) & 7;
        s.push(if bits & 4 != 0 { 'r' } else { '-' });
        s.push(if bits & 2 != 0 { 'w' } else { '-' });
        s.push(if bits & 1 != 0 { 'x' } else { '-' });
    }
    s
}

pub fn item_info(path: &Path) -> serde_json::Value {
    let lmeta = fs::symlink_metadata(path);
    let Ok(lmeta) = lmeta else {
        return serde_json::json!({ "name": path.file_name().map(|n| n.to_string_lossy().to_string()), "path": path, "exists": false });
    };
    let is_link = lmeta.file_type().is_symlink();
    let meta = if is_link { fs::metadata(path).unwrap_or(lmeta.clone()) } else { lmeta.clone() };
    let is_dir = meta.is_dir();
    let mime = if is_dir { "inode/directory".to_string() } else { native::mime_type(path, true) };
    let created = meta
        .created()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| crate::pane::format_date(d.as_secs() as i64))
        .unwrap_or_else(|| "-".into());
    let fmt_full = |ts: i64| {
        let t = ts as libc::time_t;
        let mut tm: libc::tm = unsafe { std::mem::zeroed() };
        unsafe {
            libc::localtime_r(&t, &mut tm);
        }
        format!(
            "{} {:02}:{:02}",
            crate::pane::format_date(ts),
            tm.tm_hour,
            tm.tm_min
        )
    };
    let free = path
        .parent()
        .and_then(|p| crate::drives::statvfs(&p.to_string_lossy()))
        .map(|(_, f)| util::format_size(f))
        .unwrap_or_else(|| "-".into());
    let mode = meta.permissions().mode() & 0o7777;
    serde_json::json!({
        "exists": true,
        "name": path.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| "/".into()),
        "path": path.to_string_lossy(),
        "parent": path.parent().map(|p| p.to_string_lossy().to_string()).unwrap_or_default(),
        "is_dir": is_dir,
        "is_symlink": is_link,
        "link_target": if is_link { fs::read_link(path).map(|t| t.to_string_lossy().to_string()).unwrap_or_default() } else { String::new() },
        "size": if is_dir { 0 } else { meta.len() },
        "size_str": if is_dir { "-".to_string() } else { format!("{} ({} bytes)", util::format_size(meta.len()), meta.len()) },
        "items": if is_dir { fs::read_dir(path).map(|r| r.count()).unwrap_or(0) } else { 0 },
        "mime": mime,
        "type": if is_dir { "Folder".to_string() } else { native::mime_comment(&mime) },
        "modified": fmt_full(meta.mtime()),
        "accessed": fmt_full(meta.atime()),
        "created": created,
        "mode": format!("{:o}", mode),
        "mode_bits": mode,
        "mode_str": mode_string(mode, is_dir, is_link),
        "owner": user_name(meta.uid()),
        "group": group_name(meta.gid()),
        "is_owner": meta.uid() == unsafe { libc::getuid() },
        "free_space": free,
    })
}

/// Applies `mode` to `path` (and below, if `recursive`). Files never gain
/// execute bits they didn't have; folders get the mode as given.
pub fn set_permissions(path: &Path, mode: u32, recursive: bool) -> std::io::Result<()> {
    let apply = |p: &Path, is_dir: bool| -> std::io::Result<()> {
        let cur = fs::symlink_metadata(p)?.permissions().mode();
        let new = if is_dir || !recursive {
            mode
        } else {
            (mode & !0o111) | (cur & 0o111 & mode)
        };
        fs::set_permissions(p, fs::Permissions::from_mode(new & 0o7777))
    };
    let meta = fs::symlink_metadata(path)?;
    if meta.file_type().is_symlink() {
        return Ok(()); // permissions of links are meaningless on Linux
    }
    apply(path, meta.is_dir())?;
    if recursive && meta.is_dir() {
        let mut stack = vec![path.to_path_buf()];
        while let Some(d) = stack.pop() {
            for e in fs::read_dir(&d)?.flatten() {
                let Ok(ft) = e.file_type() else { continue };
                if ft.is_symlink() {
                    continue;
                }
                apply(&e.path(), ft.is_dir())?;
                if ft.is_dir() {
                    stack.push(e.path());
                }
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn modes() {
        assert_eq!(mode_string(0o755, true, false), "drwxr-xr-x");
        assert_eq!(mode_string(0o640, false, false), "-rw-r-----");
    }

    #[test]
    fn head_is_bounded() {
        let p = std::env::temp_dir().join(format!("loaf-info-{}.txt", std::process::id()));
        fs::write(&p, "é".repeat(200_000)).unwrap();
        let (text, truncated, binary) = read_head(&p);
        assert!(truncated && !binary);
        assert!(text.len() <= PREVIEW_BYTES as usize);
        assert!(!text.contains('\u{fffd}'), "no broken character at the cut");
        fs::remove_file(&p).unwrap();
    }

    #[test]
    fn recursive_permissions_keep_file_exec_bits() {
        let d = std::env::temp_dir().join(format!("loaf-perm-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(d.join("sub")).unwrap();
        fs::write(d.join("sub/a.txt"), b"").unwrap();
        fs::write(d.join("sub/run.sh"), b"").unwrap();
        fs::set_permissions(d.join("sub/run.sh"), fs::Permissions::from_mode(0o755)).unwrap();
        set_permissions(&d, 0o750, true).unwrap();
        let m = |p: &str| fs::metadata(d.join(p)).unwrap().permissions().mode() & 0o777;
        assert_eq!(m("sub"), 0o750);
        assert_eq!(m("sub/a.txt"), 0o640);
        assert_eq!(m("sub/run.sh"), 0o750);
        fs::remove_dir_all(&d).unwrap();
    }
}
