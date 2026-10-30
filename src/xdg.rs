//! Desktop integration files shared with other file managers:
//! XDG user folders (localized names), GTK bookmarks, recently used files,
//! templates, Nautilus scripts, and Loaf's own starred list.

use crate::util;
use std::fs;
use std::path::{Path, PathBuf};
/// Parses `user-dirs.dirs` content into (KEY, absolute path) pairs, e.g.
/// ("PICTURES", "/home/u/Bilder").
pub fn parse_user_dirs(content: &str, home: &Path) -> Vec<(String, PathBuf)> {
    let mut out = Vec::new();
    for line in content.lines() {
        let line = line.trim();
        if line.starts_with('#') {
            continue;
        }
        let Some((k, v)) = line.split_once('=') else { continue };
        let Some(key) = k.trim().strip_prefix("XDG_").and_then(|k| k.strip_suffix("_DIR")) else { continue };
        let v = v.trim().trim_matches('"');
        let path = if let Some(rest) = v.strip_prefix("$HOME") {
            home.join(rest.trim_start_matches('/'))
        } else if v.starts_with('/') {
            PathBuf::from(v)
        } else {
            continue;
        };
        // The spec says a dir equal to $HOME means "disabled".
        if path == home {
            continue;
        }
        out.push((key.to_string(), path));
    }
    out
}

/// The user's special folders, keyed by XDG name (DESKTOP, DOWNLOAD,
/// TEMPLATES, PUBLICSHARE, DOCUMENTS, MUSIC, PICTURES, VIDEOS).
pub fn user_dirs() -> Vec<(String, PathBuf)> {
    let home = util::home();
    let content = fs::read_to_string(util::config_home().join("user-dirs.dirs")).unwrap_or_default();
    let mut dirs = parse_user_dirs(&content, &home);
    // Fall back to the English defaults for keys the file doesn't define.
    for (key, name) in [
        ("DESKTOP", "Desktop"),
        ("DOWNLOAD", "Downloads"),
        ("TEMPLATES", "Templates"),
        ("PUBLICSHARE", "Public"),
        ("DOCUMENTS", "Documents"),
        ("MUSIC", "Music"),
        ("PICTURES", "Pictures"),
        ("VIDEOS", "Videos"),
    ] {
        if !dirs.iter().any(|(k, _)| k == key) {
            dirs.push((key.to_string(), home.join(name)));
        }
    }
    dirs
}

pub fn user_dir(key: &str) -> Option<PathBuf> {
    user_dirs().into_iter().find(|(k, _)| k == key).map(|(_, p)| p)
}

#[derive(Clone, Debug, serde::Serialize, PartialEq)]
pub struct Place {
    /// Stable id: "home", "DOCUMENTS", ..., "trash", or "bookmark:<path>".
    pub id: String,
    pub name: String,
    pub path: String,
    /// Phosphor icon name.
    pub icon: String,
    /// Freedesktop icon name for system icon themes.
    pub system_icon: String,
    pub kind: String,
}

/// Default sidebar places: Home, then the XDG folders that exist, using
/// their real (localized) names.
pub fn default_places() -> Vec<Place> {
    let home = util::home();
    let mut v = vec![Place {
        id: "home".into(),
        name: "Home".into(),
        path: home.to_string_lossy().to_string(),
        icon: "house".into(),
        system_icon: "user-home".into(),
        kind: "place".into(),
    }];
    let dirs = user_dirs();
    for (key, icon, sys) in [
        ("DESKTOP", "desktop", "user-desktop"),
        ("DOCUMENTS", "file-text", "folder-documents"),
        ("DOWNLOAD", "download", "folder-download"),
        ("PICTURES", "image", "folder-pictures"),
        ("MUSIC", "music", "folder-music"),
        ("VIDEOS", "video", "folder-videos"),
    ] {
        let Some((_, p)) = dirs.iter().find(|(k, _)| k == key) else { continue };
        if !p.is_dir() {
            continue;
        }
        v.push(Place {
            id: key.into(),
            name: p.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| key.into()),
            path: p.to_string_lossy().to_string(),
            icon: icon.into(),
            system_icon: sys.into(),
            kind: "place".into(),
        });
    }

    // Common non-standard places: Projects and Games (with localized folder names).
    let project_names = [
        "Projects", "Projekte", "Projets", "Proyectos", "Projetos", "Проекты", "Progetti", "Projeler", "Development", "Dev", "Code",
    ];
    for name in project_names {
        let p = home.join(name);
        if p.is_dir() {
            v.push(Place {
                id: "PROJECTS".into(),
                name: p.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| "Projects".into()),
                path: p.to_string_lossy().to_string(),
                icon: "code".into(),
                system_icon: "folder-development".into(),
                kind: "place".into(),
            });
            break;
        }
    }

    let game_names = [
        "Games", "Spiele", "Jeux", "Juegos", "Jogos", "Игры", "Giochi", "Oyunlar",
    ];
    for name in game_names {
        let p = home.join(name);
        if p.is_dir() {
            v.push(Place {
                id: "GAMES".into(),
                name: p.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| "Games".into()),
                path: p.to_string_lossy().to_string(),
                icon: "game-controller".into(),
                system_icon: "applications-games".into(),
                kind: "place".into(),
            });
            break;
        }
    }

    v
}
pub fn bookmarks_file() -> PathBuf {
    util::config_home().join("gtk-3.0/bookmarks")
}

/// One line of the bookmarks file. Non-file URIs are kept so we never drop
/// the user's network bookmarks when rewriting the file.
#[derive(Clone, Debug, PartialEq)]
pub struct Bookmark {
    pub uri: String,
    pub label: String,
}

impl Bookmark {
    pub fn path(&self) -> Option<PathBuf> {
        self.uri.strip_prefix("file://").map(crate::trash::decode_path)
    }
    pub fn display_name(&self) -> String {
        if !self.label.is_empty() {
            return self.label.clone();
        }
        self.path()
            .and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string()))
            .unwrap_or_else(|| self.uri.clone())
    }
}

pub fn parse_bookmarks(content: &str) -> Vec<Bookmark> {
    content
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .map(|l| match l.split_once(' ') {
            Some((u, label)) => Bookmark { uri: u.to_string(), label: label.trim().to_string() },
            None => Bookmark { uri: l.to_string(), label: String::new() },
        })
        .collect()
}

pub fn format_bookmarks(list: &[Bookmark]) -> String {
    let mut s = String::new();
    for b in list {
        s.push_str(&b.uri);
        if !b.label.is_empty() {
            s.push(' ');
            s.push_str(&b.label);
        }
        s.push('\n');
    }
    s
}

pub fn bookmarks() -> Vec<Bookmark> {
    parse_bookmarks(&fs::read_to_string(bookmarks_file()).unwrap_or_default())
}

fn save_bookmarks(list: &[Bookmark]) -> std::io::Result<()> {
    util::write_atomic(&bookmarks_file(), format_bookmarks(list).as_bytes())
}

pub fn uri_for(path: &Path) -> String {
    format!("file://{}", crate::trash::encode_path(path))
}

pub fn add_bookmark(path: &Path) -> std::io::Result<()> {
    let mut list = bookmarks();
    let uri = uri_for(path);
    if !list.iter().any(|b| b.uri == uri) {
        list.push(Bookmark { uri, label: String::new() });
        save_bookmarks(&list)?;
    }
    Ok(())
}

pub fn remove_bookmark(path: &Path) -> std::io::Result<()> {
    let mut list = bookmarks();
    let uri = uri_for(path);
    let before = list.len();
    list.retain(|b| b.uri != uri && b.path().as_deref() != Some(path));
    if list.len() != before {
        save_bookmarks(&list)?;
    }
    Ok(())
}

pub fn rename_bookmark(path: &Path, label: &str) -> std::io::Result<()> {
    let mut list = bookmarks();
    for b in list.iter_mut() {
        if b.path().as_deref() == Some(path) {
            b.label = label.trim().to_string();
        }
    }
    save_bookmarks(&list)
}

/// Moves the bookmark for `path` to position `to` among all bookmarks.
pub fn move_bookmark(path: &Path, to: usize) -> std::io::Result<()> {
    let mut list = bookmarks();
    let Some(from) = list.iter().position(|b| b.path().as_deref() == Some(path)) else { return Ok(()) };
    let b = list.remove(from);
    list.insert(to.min(list.len()), b);
    save_bookmarks(&list)
}
pub fn recent_file() -> PathBuf {
    util::data_home().join("recently-used.xbel")
}

fn attr<'a>(tag: &'a str, name: &str) -> Option<&'a str> {
    let key = format!(" {}=\"", name);
    let start = tag.find(&key)? + key.len();
    let end = tag[start..].find('"')? + start;
    Some(&tag[start..end])
}

fn xml_unescape(s: &str) -> String {
    s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'").replace("&amp;", "&")
}

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;")
}

/// (path, modified ISO timestamp) of every local file entry, newest first.
pub fn parse_recent(content: &str) -> Vec<(PathBuf, String)> {
    let mut out = Vec::new();
    let mut rest = content;
    while let Some(i) = rest.find("<bookmark ") {
        let tail = &rest[i..];
        let end = tail.find('>').unwrap_or(tail.len());
        let tag = &tail[..end];
        if let Some(href) = attr(tag, "href") {
            let href = xml_unescape(href);
            if let Some(p) = href.strip_prefix("file://") {
                let stamp = attr(tag, "modified").or_else(|| attr(tag, "visited")).or_else(|| attr(tag, "added"));
                out.push((crate::trash::decode_path(p), stamp.unwrap_or("").to_string()));
            }
        }
        rest = &tail[end.min(tail.len())..];
    }
    out.sort_by(|a, b| b.1.cmp(&a.1));
    out
}

/// Recently used files that still exist (newest first, deduplicated).
pub fn recent_files(limit: usize) -> Vec<PathBuf> {
    let content = fs::read_to_string(recent_file()).unwrap_or_default();
    let mut seen = std::collections::HashSet::new();
    parse_recent(&content)
        .into_iter()
        .map(|(p, _)| p)
        .filter(|p| seen.insert(p.clone()) && fs::symlink_metadata(p).is_ok())
        .take(limit)
        .collect()
}

fn iso_utc_now() -> String {
    let now = unsafe { libc::time(std::ptr::null_mut()) };
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    unsafe {
        libc::gmtime_r(&now, &mut tm);
    }
    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z",
        tm.tm_year + 1900,
        tm.tm_mon + 1,
        tm.tm_mday,
        tm.tm_hour,
        tm.tm_min,
        tm.tm_sec
    )
}

/// Returns `content` with `path` recorded as just used (pure, testable).
pub fn add_recent_in(content: &str, path: &Path, mime: &str, now: &str) -> String {
    let href = xml_escape(&uri_for(path));
    let needle = format!("href=\"{}\"", href);
    if let Some(pos) = content.find(&needle) {
        // Update the existing entry's timestamps.
        let tag_start = content[..pos].rfind("<bookmark").unwrap_or(pos);
        let tag_end = content[pos..].find('>').map(|e| pos + e).unwrap_or(content.len());
        let mut tag = content[tag_start..tag_end].to_string();
        for key in ["modified", "visited"] {
            let k = format!(" {}=\"", key);
            if let Some(s) = tag.find(&k) {
                let vs = s + k.len();
                if let Some(ve) = tag[vs..].find('"') {
                    tag.replace_range(vs..vs + ve, now);
                }
            }
        }
        return format!("{}{}{}", &content[..tag_start], tag, &content[tag_end..]);
    }
    let entry = format!(
        "  <bookmark href=\"{href}\" added=\"{now}\" modified=\"{now}\" visited=\"{now}\">\n    <info>\n      <metadata owner=\"http://freedesktop.org\">\n        <mime:mime-type type=\"{mime}\"/>\n        <bookmark:applications>\n          <bookmark:application name=\"Loaf\" exec=\"&apos;loaf %u&apos;\" modified=\"{now}\" count=\"1\"/>\n        </bookmark:applications>\n      </metadata>\n    </info>\n  </bookmark>\n",
        href = href,
        now = now,
        mime = xml_escape(if mime.is_empty() { "application/octet-stream" } else { mime })
    );
    if let Some(close) = content.rfind("</xbel>") {
        format!("{}{}{}", &content[..close], entry, &content[close..])
    } else {
        format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<xbel version=\"1.0\"\n      xmlns:bookmark=\"http://www.freedesktop.org/standards/desktop-bookmarks\"\n      xmlns:mime=\"http://www.freedesktop.org/standards/shared-mime-info\"\n>\n{}</xbel>\n",
            entry
        )
    }
}

/// Records that Loaf opened `path` so other apps' "Recent" lists see it.
pub fn add_recent(path: &Path, mime: &str) {
    // Read-modify-write: one writer at a time or updates get lost.
    static LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());
    let _guard = util::lock(&LOCK);
    let file = recent_file();
    let content = fs::read_to_string(&file).unwrap_or_default();
    // Never rewrite a file we can't understand.
    if !content.is_empty() && !content.contains("<xbel") {
        return;
    }
    let updated = add_recent_in(&content, path, mime, &iso_utc_now());
    let _ = util::write_atomic(&file, updated.as_bytes());
}
#[derive(Clone, Debug, serde::Serialize)]
pub struct MenuFile {
    pub name: String,
    pub path: String,
    /// Folders become submenus.
    pub children: Vec<MenuFile>,
}

fn menu_tree(dir: &Path, want: &dyn Fn(&Path) -> bool, depth: usize) -> Vec<MenuFile> {
    let mut out = Vec::new();
    let Ok(rd) = fs::read_dir(dir) else { return out };
    for e in rd.flatten() {
        let name = e.file_name().to_string_lossy().to_string();
        if name.starts_with('.') {
            continue;
        }
        let p = e.path();
        if p.is_dir() {
            if depth < 3 {
                let children = menu_tree(&p, want, depth + 1);
                if !children.is_empty() {
                    out.push(MenuFile { name, path: p.to_string_lossy().to_string(), children });
                }
            }
        } else if want(&p) {
            out.push(MenuFile { name, path: p.to_string_lossy().to_string(), children: vec![] });
        }
    }
    out.sort_by_key(|m| m.name.to_lowercase());
    out
}

pub fn templates() -> Vec<MenuFile> {
    match user_dir("TEMPLATES") {
        Some(d) => menu_tree(&d, &|p| p.is_file(), 0),
        None => vec![],
    }
}

/// Folders Nautilus-style scripts are read from.
pub fn script_dirs() -> Vec<PathBuf> {
    vec![util::data_home().join("nautilus/scripts"), util::data_home().join("loaf/scripts")]
}

pub fn scripts() -> Vec<MenuFile> {
    let is_exec = |p: &Path| {
        use std::os::unix::fs::PermissionsExt;
        fs::metadata(p).map(|m| m.is_file() && m.permissions().mode() & 0o111 != 0).unwrap_or(false)
    };
    let mut out = Vec::new();
    for d in script_dirs() {
        out.extend(menu_tree(&d, &is_exec, 0));
    }
    out
}

/// Runs a Nautilus script with the environment Nautilus provides.
pub fn run_script(script: &Path, current_dir: &Path, selected: &[PathBuf]) -> std::io::Result<()> {
    let paths: String = selected.iter().map(|p| format!("{}\n", p.to_string_lossy())).collect();
    let uris: String = selected.iter().map(|p| format!("{}\n", uri_for(p))).collect();
    let mut cmd = std::process::Command::new(script);
    cmd.current_dir(current_dir)
        .args(selected.iter().map(|p| p.file_name().map(|n| n.to_os_string()).unwrap_or_default()))
        .env("NAUTILUS_SCRIPT_SELECTED_FILE_PATHS", paths)
        .env("NAUTILUS_SCRIPT_SELECTED_URIS", uris)
        .env("NAUTILUS_SCRIPT_CURRENT_URI", uri_for(current_dir));
    util::spawn_detached(cmd)
}
fn starred_file() -> PathBuf {
    util::config_home().join("loaf/starred.json")
}

pub fn starred() -> Vec<PathBuf> {
    fs::read_to_string(starred_file())
        .ok()
        .and_then(|s| serde_json::from_str::<Vec<String>>(&s).ok())
        .unwrap_or_default()
        .into_iter()
        .map(PathBuf::from)
        .collect()
}

pub fn set_starred(path: &Path, on: bool) -> std::io::Result<()> {
    let mut list = starred();
    list.retain(|p| p != path);
    if on {
        list.push(path.to_path_buf());
    }
    let json: Vec<String> = list.iter().map(|p| p.to_string_lossy().to_string()).collect();
    util::write_atomic(&starred_file(), serde_json::to_string_pretty(&json).unwrap_or_default().as_bytes())
}

/// Starred paths after moving each `from` to `to` (items inside a moved
/// folder follow it too).
fn follow_moves(list: Vec<PathBuf>, pairs: &[(PathBuf, PathBuf)]) -> Vec<PathBuf> {
    list.into_iter()
        .map(|p| {
            for (from, to) in pairs {
                if let Ok(rest) = p.strip_prefix(from) {
                    return if rest.as_os_str().is_empty() { to.clone() } else { to.join(rest) };
                }
            }
            p
        })
        .collect()
}

/// Keeps stars on items that were moved or renamed.
pub fn move_starred(pairs: &[(PathBuf, PathBuf)]) {
    let list = starred();
    let moved = follow_moves(list.clone(), pairs);
    if moved != list {
        let json: Vec<String> = moved.iter().map(|p| p.to_string_lossy().to_string()).collect();
        let _ = util::write_atomic(&starred_file(), serde_json::to_string_pretty(&json).unwrap_or_default().as_bytes());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stars_follow_moved_items_and_folders() {
        let list = vec![PathBuf::from("/a/x.txt"), PathBuf::from("/a/dir/in.txt"), PathBuf::from("/a/other")];
        let pairs = vec![(PathBuf::from("/a/x.txt"), PathBuf::from("/b/x.txt")), (PathBuf::from("/a/dir"), PathBuf::from("/b/dir"))];
        assert_eq!(
            follow_moves(list, &pairs),
            vec![PathBuf::from("/b/x.txt"), PathBuf::from("/b/dir/in.txt"), PathBuf::from("/a/other")]
        );
    }

    #[test]
    fn localized_user_dirs() {
        let home = Path::new("/home/anna");
        let content = "# comment\nXDG_PICTURES_DIR=\"$HOME/Bilder\"\nXDG_MUSIC_DIR=\"/data/Musik\"\nXDG_PUBLICSHARE_DIR=\"$HOME/\"\nXDG_VIDEOS_DIR=\"$HOME/Videos\"\nbogus\n";
        let d = parse_user_dirs(content, home);
        assert!(d.contains(&("PICTURES".into(), PathBuf::from("/home/anna/Bilder"))));
        assert!(d.contains(&("MUSIC".into(), PathBuf::from("/data/Musik"))));
        assert!(!d.iter().any(|(k, _)| k == "PUBLICSHARE"), "$HOME means disabled");
        assert_eq!(d.len(), 3);
    }

    #[test]
    fn bookmarks_roundtrip_keeps_unknown_lines() {
        let src = "file:///home/a/My%20Stuff Stuff\nsftp://host/x\nfile:///tmp\n";
        let list = parse_bookmarks(src);
        assert_eq!(list.len(), 3);
        assert_eq!(list[0].path(), Some(PathBuf::from("/home/a/My Stuff")));
        assert_eq!(list[0].display_name(), "Stuff");
        assert_eq!(list[2].display_name(), "tmp");
        assert_eq!(list[1].path(), None);
        assert_eq!(format_bookmarks(&list), src);
    }

    #[test]
    fn recent_parse_and_update() {
        let base = add_recent_in("", Path::new("/a/one.txt"), "text/plain", "2026-01-01T00:00:00Z");
        let two = add_recent_in(&base, Path::new("/a/t&o.txt"), "text/plain", "2026-01-02T00:00:00Z");
        let again = add_recent_in(&two, Path::new("/a/one.txt"), "text/plain", "2026-01-03T00:00:00Z");
        let parsed = parse_recent(&again);
        assert_eq!(parsed.len(), 2, "no duplicate entry");
        assert_eq!(parsed[0], (PathBuf::from("/a/one.txt"), "2026-01-03T00:00:00Z".to_string()));
        assert_eq!(parsed[1].0, PathBuf::from("/a/t&o.txt"));
        assert!(again.trim_end().ends_with("</xbel>"));
    }
}
