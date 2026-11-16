//! Desktop applications: parsing `.desktop` entries, MIME associations
//! (`mimeapps.list`), and launching apps with files (Exec field codes).
//!
//! Everything is read once and cached; a right-click never re-reads the
//! applications folders.

use crate::message::{Message, MessageKey};
use crate::util::{self, lock};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;

#[derive(Clone, Debug)]
pub struct DesktopApp {
    /// Desktop file id ("org.gnome.TextEditor"), without `.desktop`.
    pub id: String,
    pub name: String,
    pub exec: String,
    pub icon: String,
    pub mimes: Vec<String>,
    pub terminal: bool,
    /// NoDisplay apps are still valid handlers, just not listed on their own.
    pub no_display: bool,
    pub path: PathBuf,
}

static APPS: Mutex<Option<Vec<DesktopApp>>> = Mutex::new(None);

/// Application folders in lookup priority order (user first).
pub fn app_dirs() -> Vec<PathBuf> {
    let mut v = vec![util::data_home().join("applications")];
    v.push(util::data_home().join("flatpak/exports/share/applications"));
    for d in util::data_dirs() {
        v.push(d.join("applications"));
    }
    let mut seen = HashSet::new();
    v.retain(|d| d.is_dir() && seen.insert(d.clone()));
    v
}

/// Current locale codes, most specific first (`de_DE`, then `de`).
fn locale_chain() -> Vec<String> {
    let raw = ["LC_ALL", "LC_MESSAGES", "LANG"]
        .iter()
        .filter_map(|k| std::env::var(k).ok())
        .find(|v| !v.is_empty())
        .unwrap_or_default();
    let raw = raw.split(['.', '@']).next().unwrap_or("").replace('-', "_");
    let mut chain = Vec::new();
    if !raw.is_empty() && raw != "C" && raw != "POSIX" {
        chain.push(raw.clone());
        if let Some((lang, _)) = raw.split_once('_') {
            chain.push(lang.to_string());
        }
    }
    chain
}

/// Parses one desktop entry. `id` is the desktop file id to record.
pub fn parse_desktop_file(path: &Path, id: &str) -> Option<DesktopApp> {
    let content = fs::read_to_string(path).ok()?;
    let mut in_group = false;
    let mut kv: HashMap<String, String> = HashMap::new();
    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if line.starts_with('[') {
            in_group = line == "[Desktop Entry]";
            continue;
        }
        if in_group && let Some((k, v)) = line.split_once('=') {
            kv.entry(k.trim().to_string())
                .or_insert_with(|| v.trim().to_string());
        }
    }
    let is_true = |k: &str| {
        kv.get(k)
            .map(|v| v.eq_ignore_ascii_case("true"))
            .unwrap_or(false)
    };
    if !kv.get("Type").map(|t| t == "Application").unwrap_or(false) || is_true("Hidden") {
        return None;
    }
    let exec = kv.get("Exec").cloned().unwrap_or_default();
    if exec.is_empty() {
        return None;
    }
    // TryExec names a binary that must exist for the entry to be usable.
    if let Some(try_exec) = kv.get("TryExec").filter(|t| !t.is_empty()) {
        let ok = if try_exec.starts_with('/') {
            Path::new(try_exec).exists()
        } else {
            util::which(try_exec).is_some()
        };
        if !ok {
            return None;
        }
    }
    let mut name = String::new();
    for code in locale_chain() {
        if let Some(v) = kv.get(&format!("Name[{}]", code)) {
            name = v.clone();
            break;
        }
    }
    if name.is_empty() {
        name = kv.get("Name").cloned().unwrap_or_default();
    }
    if name.is_empty() {
        return None;
    }
    Some(DesktopApp {
        id: id.to_string(),
        name,
        exec,
        icon: kv.get("Icon").cloned().unwrap_or_default(),
        mimes: kv
            .get("MimeType")
            .map(|m| {
                m.split(';')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty())
                    .collect()
            })
            .unwrap_or_default(),
        terminal: is_true("Terminal"),
        no_display: is_true("NoDisplay"),
        path: path.to_path_buf(),
    })
}

fn scan_dir(dir: &Path, prefix: &str, seen: &mut HashSet<String>, out: &mut Vec<DesktopApp>) {
    let Ok(rd) = fs::read_dir(dir) else { return };
    for e in rd.flatten() {
        let p = e.path();
        let fname = e.file_name().to_string_lossy().to_string();
        if p.is_dir() {
            // Subfolders form ids like "kde-foo.desktop" per the spec.
            scan_dir(&p, &format!("{}{}-", prefix, fname), seen, out);
            continue;
        }
        let Some(stem) = fname.strip_suffix(".desktop") else {
            continue;
        };
        let id = format!("{}{}", prefix, stem);
        // The first folder in priority order owns an id, even if that entry
        // is hidden (that is how users hide system entries).
        if !seen.insert(id.clone()) {
            continue;
        }
        if let Some(app) = parse_desktop_file(&p, &id) {
            out.push(app);
        }
    }
}

/// All installed applications (cached).
pub fn all() -> Vec<DesktopApp> {
    let mut guard = lock(&APPS);
    if let Some(apps) = guard.as_ref() {
        return apps.clone();
    }
    let mut seen = HashSet::new();
    let mut apps = Vec::new();
    for dir in app_dirs() {
        scan_dir(&dir, "", &mut seen, &mut apps);
    }
    apps.sort_by_key(|a| a.name.to_lowercase());
    *guard = Some(apps.clone());
    apps
}

/// Forget the cache (after installing apps or changing defaults).
pub fn invalidate() {
    *lock(&APPS) = None;
}

pub fn find(id: &str) -> Option<DesktopApp> {
    let id = id.strip_suffix(".desktop").unwrap_or(id);
    all().into_iter().find(|a| a.id == id)
}

/// Whether a `MimeType=` entry covers `mime` (wildcards and common aliases).
pub fn mime_covers(declared: &str, mime: &str) -> bool {
    let declared = declared.trim().to_lowercase();
    let mime = mime.trim().to_lowercase();
    if declared.is_empty() || mime.is_empty() {
        return false;
    }
    if declared == mime || declared == "*/*" || declared == "all/all" {
        return true;
    }
    if let Some(prefix) = declared.strip_suffix("/*") {
        return mime.split('/').next() == Some(prefix);
    }
    const ALIASES: [(&str, &str); 7] = [
        ("image/jpg", "image/jpeg"),
        ("image/pjpeg", "image/jpeg"),
        ("application/x-zip-compressed", "application/zip"),
        ("application/x-7z-compressed", "application/x-7z"),
        ("text/xml", "application/xml"),
        ("text/markdown", "text/x-markdown"),
        ("application/x-pdf", "application/pdf"),
    ];
    ALIASES
        .iter()
        .any(|(a, b)| (declared == *a && mime == *b) || (declared == *b && mime == *a))
}

/// `mimeapps.list` files in priority order (spec: desktop-specific first).
fn mimeapps_files() -> Vec<PathBuf> {
    let desktops: Vec<String> = std::env::var("XDG_CURRENT_DESKTOP")
        .unwrap_or_default()
        .split(':')
        .filter(|s| !s.is_empty())
        .map(|s| s.to_lowercase())
        .collect();
    let mut dirs = vec![util::config_home()];
    dirs.extend(
        std::env::var("XDG_CONFIG_DIRS")
            .unwrap_or_else(|_| "/etc/xdg".into())
            .split(':')
            .filter(|s| !s.is_empty())
            .map(PathBuf::from),
    );
    dirs.push(util::data_home().join("applications"));
    dirs.extend(
        util::data_dirs()
            .into_iter()
            .map(|d| d.join("applications")),
    );
    let mut out = Vec::new();
    for d in dirs {
        for de in &desktops {
            out.push(d.join(format!("{}-mimeapps.list", de)));
        }
        out.push(d.join("mimeapps.list"));
    }
    out
}

fn group_values(content: &str, group: &str, mime: &str) -> Vec<String> {
    let mut in_group = false;
    let mut out = Vec::new();
    for line in content.lines() {
        let line = line.trim();
        if line.starts_with('[') {
            in_group = line == group;
            continue;
        }
        if !in_group {
            continue;
        }
        if let Some((k, v)) = line.split_once('=')
            && k.trim().eq_ignore_ascii_case(mime)
        {
            out.extend(
                v.split(';')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty()),
            );
        }
    }
    out
}

/// The default application for `mime`, following the mimeapps spec:
/// `[Default Applications]`, then `[Added Associations]`, then any app that
/// declares the type. Removed associations are skipped.
pub fn default_for(mime: &str) -> Option<DesktopApp> {
    default_for_in(&all(), mime)
}

pub fn default_for_in(apps: &[DesktopApp], mime: &str) -> Option<DesktopApp> {
    if mime.is_empty() {
        return None;
    }
    let installed = |id: &str| {
        let id = id.strip_suffix(".desktop").unwrap_or(id);
        apps.iter().find(|a| a.id == id).cloned()
    };
    let mut removed: HashSet<String> = HashSet::new();
    let files: Vec<String> = mimeapps_files()
        .iter()
        .filter_map(|p| fs::read_to_string(p).ok())
        .collect();
    for content in &files {
        for r in group_values(content, "[Removed Associations]", mime) {
            removed.insert(r.trim_end_matches(".desktop").to_string());
        }
        for id in group_values(content, "[Default Applications]", mime) {
            if let Some(app) = installed(&id) {
                return Some(app);
            }
        }
    }
    for content in &files {
        for id in group_values(content, "[Added Associations]", mime) {
            if removed.contains(id.trim_end_matches(".desktop")) {
                continue;
            }
            if let Some(app) = installed(&id) {
                return Some(app);
            }
        }
    }
    apps.iter()
        .find(|a| !removed.contains(&a.id) && a.mimes.iter().any(|m| mime_covers(m, mime)))
        .cloned()
}

/// Apps that declare support for `mime`, default first.
pub fn for_mime(mime: &str) -> Vec<DesktopApp> {
    let apps = all();
    let mut list: Vec<DesktopApp> = apps
        .iter()
        .filter(|a| a.mimes.iter().any(|m| mime_covers(m, mime)))
        .cloned()
        .collect();
    if let Some(def) = default_for_in(&apps, mime)
        && let Some(pos) = list.iter().position(|a| a.id == def.id)
    {
        let d = list.remove(pos);
        list.insert(0, d);
    }
    list
}

/// Writes `id` as the default for `mime` in `~/.config/mimeapps.list`,
/// keeping everything else in the file intact.
pub fn set_default(mime: &str, id: &str) -> std::io::Result<()> {
    let desktop = if id.ends_with(".desktop") {
        id.to_string()
    } else {
        format!("{}.desktop", id)
    };
    let path = util::config_home().join("mimeapps.list");
    let existing = fs::read_to_string(&path).unwrap_or_default();
    let updated = set_default_in(&existing, mime, &desktop);
    util::write_atomic(&path, updated.as_bytes())?;
    invalidate();
    Ok(())
}

/// Pure helper behind [`set_default`] (testable).
pub fn set_default_in(existing: &str, mime: &str, desktop: &str) -> String {
    let mut lines: Vec<String> = existing.lines().map(str::to_string).collect();
    let entry = format!("{}={}", mime, desktop);
    let mut in_group = false;
    let mut replaced = false;
    let mut group_end: Option<usize> = None;
    let mut i = 0;
    while i < lines.len() {
        let t = lines[i].trim().to_string();
        if t.starts_with('[') {
            if in_group && group_end.is_none() {
                group_end = Some(i);
            }
            in_group = t == "[Default Applications]";
            i += 1;
            continue;
        }
        if in_group
            && let Some((k, _)) = t.split_once('=')
            && k.trim().eq_ignore_ascii_case(mime)
        {
            if replaced {
                lines.remove(i);
                continue;
            }
            lines[i] = entry.clone();
            replaced = true;
        }
        i += 1;
    }
    if !replaced {
        let has_group = lines.iter().any(|l| l.trim() == "[Default Applications]");
        if has_group {
            // Insert at the end of the group, before trailing blank lines.
            let mut at = group_end.unwrap_or(lines.len());
            while at > 0 && lines[at - 1].trim().is_empty() {
                at -= 1;
            }
            lines.insert(at, entry);
        } else {
            if !lines.is_empty() && !lines.last().map(|l| l.trim().is_empty()).unwrap_or(true) {
                lines.push(String::new());
            }
            lines.push("[Default Applications]".into());
            lines.push(entry);
        }
    }
    let mut out = lines.join("\n");
    out.push('\n');
    out
}

/// Expands an `Exec` line for `files`. Field codes follow the Desktop Entry
/// spec; a file argument stays one argv entry even if it contains spaces.
pub fn expand_exec(app: &DesktopApp, files: &[PathBuf]) -> Vec<String> {
    let tokens = tokenize(&app.exec.replace("@@u", "").replace("@@", ""));
    let mut out = Vec::new();
    let to_uri = |p: &PathBuf| format!("file://{}", crate::trash::encode_path(p));
    let mut used_files = false;
    for tok in tokens {
        match tok.as_str() {
            "%f" => {
                if let Some(f) = files.first() {
                    out.push(f.to_string_lossy().to_string());
                }
                used_files = true;
            }
            "%F" => {
                out.extend(files.iter().map(|f| f.to_string_lossy().to_string()));
                used_files = true;
            }
            "%u" => {
                if let Some(f) = files.first() {
                    out.push(to_uri(f));
                }
                used_files = true;
            }
            "%U" => {
                out.extend(files.iter().map(to_uri));
                used_files = true;
            }
            "%i" => {
                if !app.icon.is_empty() {
                    out.push("--icon".into());
                    out.push(app.icon.clone());
                }
            }
            "%c" => out.push(app.name.clone()),
            "%k" => out.push(app.path.to_string_lossy().to_string()),
            "%d" | "%D" | "%n" | "%N" | "%v" | "%m" => {}
            _ => {
                // Codes embedded in a longer argument ("--file=%f").
                let mut t = tok.clone();
                for (code, val) in [
                    ("%f", files.first().map(|f| f.to_string_lossy().to_string())),
                    ("%u", files.first().map(to_uri)),
                ] {
                    if t.contains(code) {
                        t = t.replace(code, &val.unwrap_or_default());
                        used_files = true;
                    }
                }
                t = t.replace("%%", "%");
                if !t.is_empty() {
                    out.push(t);
                }
            }
        }
    }
    let _ = used_files;
    out
}

fn tokenize_core(s: &str) -> (Vec<String>, bool) {
    let mut tokens = Vec::new();
    let mut cur = String::new();
    let mut quote: Option<char> = None;
    let mut escaped = false;
    let mut has_token = false;
    let mut is_valid = true;
    for ch in s.chars() {
        if escaped {
            cur.push(ch);
            escaped = false;
            continue;
        }
        match ch {
            '\\' if quote != Some('\'') => escaped = true,
            '"' | '\'' if quote.is_none() => {
                quote = Some(ch);
                has_token = true;
            }
            c if Some(c) == quote => quote = None,
            c if c.is_whitespace() && quote.is_none() => {
                if has_token || !cur.is_empty() {
                    tokens.push(std::mem::take(&mut cur));
                    has_token = false;
                }
            }
            c => cur.push(c),
        }
    }
    if escaped || quote.is_some() {
        is_valid = false;
    }
    if has_token || !cur.is_empty() {
        tokens.push(cur);
    }
    (tokens, is_valid)
}

/// Shell-like tokenizer for Exec lines (quotes and backslash escapes).
pub fn tokenize(s: &str) -> Vec<String> {
    tokenize_core(s).0
}

fn tokenize_strict(s: &str) -> Option<Vec<String>> {
    let (tokens, valid) = tokenize_core(s);
    if valid && !tokens.is_empty() {
        Some(tokens)
    } else {
        None
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum WorkdirStrategy {
    FlagSep(&'static str),
    FlagJoin(&'static str),
    WeztermStart,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct ResolvedTerminal {
    bin: PathBuf,
    args: Vec<String>,
    exec_flag: Vec<String>,
    workdir_strategy: Option<WorkdirStrategy>,
}

impl ResolvedTerminal {
    fn for_command(&self) -> (PathBuf, Vec<String>) {
        let mut full_args = self.args.clone();
        for flag in &self.exec_flag {
            if flag == "start" && full_args.iter().any(|a| a == "start") {
                continue;
            }
            full_args.push(flag.clone());
        }
        (self.bin.clone(), full_args)
    }

    fn for_open_in(&self, dir: &Path) -> (PathBuf, Vec<String>) {
        let mut full_args = self.args.clone();
        let dir_str = dir.to_string_lossy().to_string();
        match &self.workdir_strategy {
            Some(WorkdirStrategy::FlagSep(flag)) => {
                full_args.push((*flag).to_string());
                full_args.push(dir_str);
            }
            Some(WorkdirStrategy::FlagJoin(flag)) => {
                full_args.push(format!("{}{}", flag, dir_str));
            }
            Some(WorkdirStrategy::WeztermStart) => {
                let has_start = full_args.iter().any(|a| a == "start");
                if !has_start {
                    full_args.push("start".to_string());
                }
                full_args.push("--cwd".to_string());
                full_args.push(dir_str);
            }
            None => {}
        }
        (self.bin.clone(), full_args)
    }
}

fn builtin_terminal_specs() -> &'static [(
    &'static str,
    &'static [&'static str],
    Option<WorkdirStrategy>,
)] {
    &[
        (
            "xdg-terminal-exec",
            &[],
            Some(WorkdirStrategy::FlagJoin("--dir=")),
        ),
        (
            "kgx",
            &["--"],
            Some(WorkdirStrategy::FlagJoin("--working-directory=")),
        ),
        (
            "gnome-terminal",
            &["--"],
            Some(WorkdirStrategy::FlagJoin("--working-directory=")),
        ),
        (
            "konsole",
            &["-e"],
            Some(WorkdirStrategy::FlagSep("--workdir")),
        ),
        ("kitty", &[], Some(WorkdirStrategy::FlagSep("-d"))),
        (
            "alacritty",
            &["-e"],
            Some(WorkdirStrategy::FlagSep("--working-directory")),
        ),
        ("foot", &[], Some(WorkdirStrategy::FlagSep("-D"))),
        (
            "wezterm",
            &["start", "--"],
            Some(WorkdirStrategy::WeztermStart),
        ),
        (
            "ghostty",
            &["-e"],
            Some(WorkdirStrategy::FlagJoin("--working-directory=")),
        ),
        (
            "xfce4-terminal",
            &["-x"],
            Some(WorkdirStrategy::FlagJoin("--working-directory=")),
        ),
        ("tilix", &["-e"], Some(WorkdirStrategy::FlagSep("-w"))),
        ("xterm", &["-e"], None),
    ]
}

fn parse_terminal_candidate(
    cmd_str: &str,
    which_fn: impl Fn(&str) -> Option<PathBuf>,
) -> Option<ResolvedTerminal> {
    let tokens = tokenize_strict(cmd_str)?;
    let p = which_fn(&tokens[0])?;
    let base_name = p.file_name()?.to_string_lossy();
    let spec = builtin_terminal_specs()
        .iter()
        .find(|(name, _, _)| *name == base_name);
    let (exec_flag, workdir_strategy) = if let Some((_, ef, ws)) = spec {
        (ef.iter().map(|s| s.to_string()).collect(), ws.clone())
    } else {
        (vec!["-e".to_string()], None)
    };
    Some(ResolvedTerminal {
        bin: p,
        args: tokens[1..].to_vec(),
        exec_flag,
        workdir_strategy,
    })
}

fn read_ini_raw_value(path: &Path, group: &str, key: &str) -> Option<String> {
    let content = fs::read_to_string(path).ok()?;
    let mut in_group = group.is_empty();
    for line in content.lines() {
        let line = line.trim();
        if line.starts_with('[') && line.ends_with(']') {
            let current_section = &line[1..line.len() - 1];
            in_group = current_section == group;
            continue;
        }
        if in_group {
            if let Some((k, v)) = line.split_once('=') {
                if k.trim() == key {
                    let val = v.trim();
                    if !val.is_empty() {
                        return Some(val.to_string());
                    }
                }
            }
        }
    }
    None
}

fn resolve_desktop_terminal_with(
    desktop: &str,
    which_fn: &impl Fn(&str) -> Option<PathBuf>,
    cfg_dir: &Path,
) -> Option<ResolvedTerminal> {
    let kde = || {
        read_ini_raw_value(
            &cfg_dir.join("kdeglobals"),
            "General",
            "TerminalApplication",
        )
        .and_then(|cmd| parse_terminal_candidate(&cmd, which_fn))
    };
    let gsettings = || {
        let gsettings_bin = which_fn("gsettings")?;
        let (ok, out, _) = util::run_capture(
            {
                let mut cmd = Command::new(gsettings_bin);
                cmd.args([
                    "get",
                    "org.gnome.desktop.default-applications.terminal",
                    "exec",
                ]);
                cmd
            },
            None,
        );
        if !ok {
            return None;
        }
        let exec = out.trim().trim_matches('\'').trim().to_string();
        if exec.is_empty() {
            return None;
        }
        parse_terminal_candidate(&exec, which_fn)
    };
    let xfce = || {
        read_ini_raw_value(&cfg_dir.join("xfce4/helpers.rc"), "", "TerminalEmulator")
            .and_then(|cmd| parse_terminal_candidate(&cmd, which_fn))
    };

    let desk = desktop.to_uppercase();
    if desk.contains("KDE") {
        kde().or_else(gsettings).or_else(xfce)
    } else if desk.contains("GNOME") {
        gsettings().or_else(kde).or_else(xfce)
    } else if desk.contains("XFCE") {
        xfce().or_else(kde).or_else(gsettings)
    } else {
        kde().or_else(gsettings).or_else(xfce)
    }
}

fn resolve_terminal_with(
    env_term: Option<&str>,
    desktop: &str,
    which_fn: impl Fn(&str) -> Option<PathBuf>,
    cfg_dir: &Path,
) -> Option<ResolvedTerminal> {
    if let Some(t) = env_term {
        if let Some(res) = parse_terminal_candidate(t, &which_fn) {
            return Some(res);
        }
    }
    if let Some(p) = which_fn("xdg-terminal-exec") {
        return Some(ResolvedTerminal {
            bin: p,
            args: vec![],
            exec_flag: vec![],
            workdir_strategy: Some(WorkdirStrategy::FlagJoin("--dir=")),
        });
    }
    if let Some(res) = resolve_desktop_terminal_with(desktop, &which_fn, cfg_dir) {
        return Some(res);
    }
    for (bin, ef, ws) in builtin_terminal_specs() {
        if let Some(p) = which_fn(bin) {
            return Some(ResolvedTerminal {
                bin: p,
                args: vec![],
                exec_flag: ef.iter().map(|s| s.to_string()).collect(),
                workdir_strategy: ws.clone(),
            });
        }
    }
    None
}

/// A terminal emulator command prefix ("kitty", "-e") for Terminal=true apps
/// and "Open in Terminal".
pub fn terminal_command() -> Option<(PathBuf, Vec<String>)> {
    let env_term = std::env::var("TERMINAL").ok();
    let desktop = std::env::var("XDG_CURRENT_DESKTOP").unwrap_or_default();
    let cfg = util::config_home();
    let res = resolve_terminal_with(env_term.as_deref(), &desktop, util::which, &cfg)?;
    Some(res.for_command())
}

/// Opens a terminal in `dir`.
pub fn open_terminal_in(dir: &Path) -> std::io::Result<()> {
    if !dir.is_dir() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            Message::key(MessageKey::NotifyNoTerminal).to_string(),
        ));
    }
    let env_term = std::env::var("TERMINAL").ok();
    let desktop = std::env::var("XDG_CURRENT_DESKTOP").unwrap_or_default();
    let cfg = util::config_home();
    let Some(res) = resolve_terminal_with(env_term.as_deref(), &desktop, util::which, &cfg) else {
        return Err(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            Message::key(MessageKey::NotifyNoTerminal).to_string(),
        ));
    };

    let (bin, args) = res.for_open_in(dir);
    let mut cmd = Command::new(bin);
    cmd.args(args).current_dir(dir);
    util::spawn_detached(cmd)
}

/// Launches `app` with `files`.
pub fn launch(app: &DesktopApp, files: &[PathBuf]) -> std::io::Result<()> {
    let mut argv = expand_exec(app, files);
    if argv.is_empty() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            Message::key(MessageKey::NotifyEmptyExec).to_string(),
        ));
    }
    if app.terminal
        && let Some((term, prefix)) = terminal_command()
    {
        let mut full = vec![term.to_string_lossy().to_string()];
        full.extend(prefix.iter().map(|s| s.to_string()));
        full.append(&mut argv);
        argv = full;
    }
    let mut cmd = Command::new(&argv[0]);
    cmd.args(&argv[1..]);
    if let Some(parent) = files.first().and_then(|f| f.parent())
        && parent.is_dir()
    {
        cmd.current_dir(parent);
    }
    util::spawn_detached(cmd)
}

/// Placeholders a user-typed command may use for the selected file.
const PLACEHOLDERS: [&str; 4] = ["%f", "%F", "%u", "%U"];

/// True when a typed command uses shell syntax and must run verbatim.
pub fn uses_shell_syntax(command: &str) -> bool {
    command.contains([
        '|', '&', ';', '>', '<', '`', '$', '(', ')', '{', '}', '*', '?', '\n',
    ])
}

/// Turns a user-typed command into a `sh -c` script that reads the file
/// path from `$1`. The path is never pasted into the script text, so names
/// containing quotes, `$(...)` or backticks can't run anything. Quotes the
/// user put around a placeholder (`"%f"`, `'%f'`) are dropped.
/// Commands without a placeholder and without shell syntax get `"$1"` appended.
pub fn command_script(command: &str) -> String {
    let mut out = command.to_string();
    let mut replaced = false;
    for ph in PLACEHOLDERS {
        if out.contains(ph) {
            for wrapped in [format!("\"{}\"", ph), format!("'{}'", ph), ph.to_string()] {
                out = out.replace(&wrapped, "\"$1\"");
            }
            replaced = true;
        }
    }
    if !replaced && !uses_shell_syntax(&out) {
        out.push_str(" \"$1\"");
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write_desktop(dir: &Path, name: &str, body: &str) -> PathBuf {
        fs::create_dir_all(dir).unwrap();
        let p = dir.join(name);
        fs::write(&p, body).unwrap();
        p
    }

    fn sandbox(tag: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("loaf-apps-{}-{}", tag, std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn parses_entries_and_respects_tryexec() {
        let d = sandbox("parse");
        let p = write_desktop(
            &d,
            "viewer.desktop",
            "[Desktop Entry]\nType=Application\nName=Viewer\nExec=viewer %U\nMimeType=image/png;image/*;\nNoDisplay=true\nIcon=viewer\n[Desktop Action x]\nName=Other\n",
        );
        let app = parse_desktop_file(&p, "viewer").unwrap();
        assert_eq!(app.name, "Viewer");
        assert!(app.no_display, "NoDisplay entries stay usable as handlers");
        assert_eq!(app.mimes, vec!["image/png", "image/*"]);
        let gone = write_desktop(
            &d,
            "gone.desktop",
            "[Desktop Entry]\nType=Application\nName=Gone\nExec=gone\nTryExec=/definitely/not/here\n",
        );
        assert!(parse_desktop_file(&gone, "gone").is_none());
        let hidden = write_desktop(
            &d,
            "h.desktop",
            "[Desktop Entry]\nType=Application\nName=H\nExec=h\nHidden=true\n",
        );
        assert!(parse_desktop_file(&hidden, "h").is_none());
        let link = write_desktop(
            &d,
            "l.desktop",
            "[Desktop Entry]\nType=Link\nName=L\nURL=x\n",
        );
        assert!(parse_desktop_file(&link, "l").is_none());
        fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn exec_field_codes() {
        let app = DesktopApp {
            id: "x".into(),
            name: "X App".into(),
            exec: "x --title=\"%c\" %F --icon-flag %i --opt=%f".into(),
            icon: "x-icon".into(),
            mimes: vec![],
            terminal: false,
            no_display: false,
            path: PathBuf::from("/usr/share/applications/x.desktop"),
        };
        let files = vec![PathBuf::from("/a b/c.txt"), PathBuf::from("/d.txt")];
        let argv = expand_exec(&app, &files);
        assert_eq!(argv[0], "x");
        assert_eq!(
            argv[1], "--title=%c",
            "quoted codes inside args stay literal"
        );
        assert_eq!(
            &argv[2..4],
            &["/a b/c.txt".to_string(), "/d.txt".to_string()]
        );
        assert!(argv.contains(&"--icon".to_string()) && argv.contains(&"x-icon".to_string()));
        assert_eq!(argv.last().unwrap(), "--opt=/a b/c.txt");

        let uri_app = DesktopApp {
            exec: "open %u".into(),
            ..app.clone()
        };
        assert_eq!(expand_exec(&uri_app, &files)[1], "file:///a%20b/c.txt");
        let flatpak = DesktopApp {
            exec: "/usr/bin/flatpak run --file-forwarding org.x @@u %U @@".into(),
            ..app
        };
        let argv = expand_exec(&flatpak, &files[..1]);
        assert_eq!(argv.last().unwrap(), "file:///a%20b/c.txt");
    }

    #[test]
    fn mime_matching() {
        assert!(mime_covers("image/*", "image/png"));
        assert!(mime_covers("image/jpg", "image/jpeg"));
        assert!(!mime_covers("image/*", "video/mp4"));
        assert!(!mime_covers("", "text/plain"));
    }

    #[test]
    fn mimeapps_edit_keeps_other_content() {
        let src = "# keep me\n[Added Associations]\ntext/plain=a.desktop;\n\n[Default Applications]\ntext/plain=old.desktop\nimage/png=v.desktop\ntext/plain=dup.desktop\n";
        let out = set_default_in(src, "text/plain", "new.desktop");
        assert!(out.contains("# keep me"));
        assert!(out.contains("text/plain=a.desktop;"));
        assert!(out.contains("text/plain=new.desktop"));
        assert!(!out.contains("old.desktop") && !out.contains("dup.desktop"));
        assert!(out.contains("image/png=v.desktop"));
        let added = set_default_in(src, "video/mp4", "mpv.desktop");
        let idx_group = added.find("[Default Applications]").unwrap();
        assert!(added.find("video/mp4=mpv.desktop").unwrap() > idx_group);
        let fresh = set_default_in("", "a/b", "c.desktop");
        assert_eq!(fresh, "[Default Applications]\na/b=c.desktop\n");
    }

    #[test]
    fn custom_commands() {
        assert_eq!(command_script("mpv"), "mpv \"$1\"");
        assert_eq!(command_script("mpv %f --fs"), "mpv \"$1\" --fs");
        assert_eq!(
            command_script("ffmpeg -i \"%f\" o.mp4"),
            "ffmpeg -i \"$1\" o.mp4"
        );
        assert_eq!(command_script("cat '%f'"), "cat \"$1\"");
        assert_eq!(command_script("echo hi | wc"), "echo hi | wc");
        // The path only ever arrives as an argument.
        let d = std::env::temp_dir().join(format!("loaf-cmd-{}", std::process::id()));
        fs::create_dir_all(&d).unwrap();
        let evil = d.join("x\"$(touch pwned)\"'`touch pwned2`'");
        let out = Command::new("sh")
            .arg("-c")
            .arg(command_script("printf %s \"%f\""))
            .arg("sh")
            .arg(&evil)
            .current_dir(&d)
            .output()
            .unwrap();
        assert_eq!(String::from_utf8_lossy(&out.stdout), evil.to_string_lossy());
        assert!(!d.join("pwned").exists() && !d.join("pwned2").exists());
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn tokenizer() {
        assert_eq!(
            tokenize(r#"a "b c" d\ e '' f"#),
            vec!["a", "b c", "d e", "", "f"]
        );
        // Legacy tolerant behavior for unclosed quote / trailing escape in desktop Exec lines
        assert_eq!(tokenize(r#"a "unclosed"#), vec!["a", "unclosed"]);
        assert_eq!(tokenize(r#"a trailing\"#), vec!["a", "trailing"]);

        // Strict behavior required for terminal preference validation
        assert_eq!(
            tokenize_strict(r#"a "b c" d\ e '' f"#),
            Some(vec![
                "a".into(),
                "b c".into(),
                "d e".into(),
                "".into(),
                "f".into()
            ])
        );
        assert_eq!(tokenize_strict(r#"a "unclosed"#), None);
        assert_eq!(tokenize_strict(r#"a trailing\"#), None);
        assert_eq!(tokenize_strict("   "), None);
    }

    #[test]
    fn terminal_selection_precedence_and_args() {
        let temp_dir = std::env::temp_dir().join(format!("loaf-term-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&temp_dir);
        fs::create_dir_all(&temp_dir).unwrap();

        let fake_which = |name: &str| match name {
            "konsole" => Some(PathBuf::from("/bin/konsole")),
            "kitty" => Some(PathBuf::from("/bin/kitty")),
            "alacritty" => Some(PathBuf::from("/bin/alacritty")),
            "xdg-terminal-exec" => Some(PathBuf::from("/bin/xdg-terminal-exec")),
            "wezterm" => Some(PathBuf::from("/bin/wezterm")),
            "gnome-terminal" => Some(PathBuf::from("/bin/gnome-terminal")),
            "kgx" => Some(PathBuf::from("/bin/kgx")),
            "ghostty" => Some(PathBuf::from("/bin/ghostty")),
            "xfce4-terminal" => Some(PathBuf::from("/bin/xfce4-terminal")),
            "tilix" => Some(PathBuf::from("/bin/tilix")),
            "custom-term" => Some(PathBuf::from("/usr/local/bin/custom-term")),
            "/opt/My Term/kitty" => Some(PathBuf::from("/opt/My Term/kitty")),
            _ => None,
        };

        // 1. Host regression case: Konsole and Kitty both installed, kdeglobals has kitty -1.
        // Konsole must not win over configured Kitty.
        let kde_cfg = temp_dir.join("kdeglobals");
        fs::write(&kde_cfg, "[General]\nTerminalApplication=kitty -1\n").unwrap();

        let fake_no_xdg = |name: &str| match name {
            "konsole" => Some(PathBuf::from("/bin/konsole")),
            "kitty" => Some(PathBuf::from("/bin/kitty")),
            "/opt/My Term/kitty" => Some(PathBuf::from("/opt/My Term/kitty")),
            _ => None,
        };
        let res = resolve_terminal_with(None, "KDE", fake_no_xdg, &temp_dir).unwrap();
        assert_eq!(res.bin, PathBuf::from("/bin/kitty"));
        assert_eq!(res.args, vec!["-1"]);
        let (open_bin, open_args) = res.for_open_in(Path::new("/home/user/my dir"));
        assert_eq!(open_bin, PathBuf::from("/bin/kitty"));
        assert_eq!(open_args, vec!["-1", "-d", "/home/user/my dir"]);

        // 2. Precedence: TERMINAL override beats xdg-terminal-exec and desktop config.
        let res = resolve_terminal_with(
            Some("custom-term --flag 'with space'"),
            "KDE",
            fake_which,
            &temp_dir,
        )
        .unwrap();
        assert_eq!(res.bin, PathBuf::from("/usr/local/bin/custom-term"));
        assert_eq!(res.args, vec!["--flag", "with space"]);
        assert_eq!(res.exec_flag, vec!["-e"]);
        let (cmd_bin, cmd_args) = res.for_command();
        assert_eq!(cmd_bin, PathBuf::from("/usr/local/bin/custom-term"));
        assert_eq!(cmd_args, vec!["--flag", "with space", "-e"]);

        // 3. Precedence: xdg-terminal-exec beats desktop config when no TERMINAL override.
        // xdg-terminal-exec syntax requires monolithic --dir=/path option per upstream spec.
        let res = resolve_terminal_with(None, "KDE", fake_which, &temp_dir).unwrap();
        assert_eq!(res.bin, PathBuf::from("/bin/xdg-terminal-exec"));
        let (open_bin, open_args) = res.for_open_in(Path::new("/tmp/test dir"));
        assert_eq!(open_bin, PathBuf::from("/bin/xdg-terminal-exec"));
        assert_eq!(open_args, vec!["--dir=/tmp/test dir"]);

        // Also if user explicitly sets TERMINAL="xdg-terminal-exec", same spec applies.
        let res_explicit =
            resolve_terminal_with(Some("xdg-terminal-exec"), "KDE", fake_which, &temp_dir).unwrap();
        assert_eq!(res_explicit.bin, PathBuf::from("/bin/xdg-terminal-exec"));
        assert_eq!(
            res_explicit.for_open_in(Path::new("/tmp")).1,
            vec!["--dir=/tmp"]
        );

        // 4. Stale/unavailable executable in desktop preference falls back gracefully.
        fs::write(
            &kde_cfg,
            "[General]\nTerminalApplication=nonexistent-term --opt\n",
        )
        .unwrap();
        let res = resolve_terminal_with(None, "KDE", fake_no_xdg, &temp_dir).unwrap();
        // Fallback kicks in and picks konsole from installed candidates
        assert_eq!(res.bin, PathBuf::from("/bin/konsole"));
        let (open_bin, open_args) = res.for_open_in(Path::new("/tmp"));
        assert_eq!(open_bin, PathBuf::from("/bin/konsole"));
        assert_eq!(open_args, vec!["--workdir", "/tmp"]);

        // 5. Malformed preference strings (unclosed quote, trailing escape) fall back safely.
        fs::write(
            &kde_cfg,
            "[General]\nTerminalApplication=kitty \"unclosed\n",
        )
        .unwrap();
        let res = resolve_terminal_with(None, "KDE", fake_no_xdg, &temp_dir).unwrap();
        assert_eq!(res.bin, PathBuf::from("/bin/konsole"));

        fs::write(
            &kde_cfg,
            "[General]\nTerminalApplication=kitty trailing\\\n",
        )
        .unwrap();
        let res = resolve_terminal_with(None, "KDE", fake_no_xdg, &temp_dir).unwrap();
        assert_eq!(res.bin, PathBuf::from("/bin/konsole"));

        fs::write(&kde_cfg, "[General]\nTerminalApplication=\"   \"\n").unwrap();
        let res = resolve_terminal_with(None, "KDE", fake_no_xdg, &temp_dir).unwrap();
        assert_eq!(res.bin, PathBuf::from("/bin/konsole"));

        // 6. Shell metacharacters are treated as data, never executed via shell.
        fs::write(
            &kde_cfg,
            "[General]\nTerminalApplication=kitty -T \"`touch pwned`\" $(uname)\n",
        )
        .unwrap();
        let res = resolve_terminal_with(None, "KDE", fake_no_xdg, &temp_dir).unwrap();
        assert_eq!(res.bin, PathBuf::from("/bin/kitty"));
        assert_eq!(res.args, vec!["-T", "`touch pwned`", "$(uname)"]);
        assert!(!temp_dir.join("pwned").exists());

        // 7. No terminal installed returns None and open_terminal_in returns NotFound.
        let fake_none = |_name: &str| None;
        assert!(resolve_terminal_with(None, "KDE", fake_none, &temp_dir).is_none());

        // 8. Non-directory / invalid path rejected by open_terminal_in.
        let non_dir = temp_dir.join("file.txt");
        fs::write(&non_dir, "content").unwrap();
        let err = open_terminal_in(&non_dir).unwrap_err();
        assert_eq!(err.kind(), std::io::ErrorKind::NotFound);

        // 9. Existing Terminal=true desktop app wrapping with terminal_command.
        let app = DesktopApp {
            id: "term-cli".to_string(),
            name: "CLI App".to_string(),
            exec: "cli-tool --opt %f".to_string(),
            icon: "utilities-terminal".to_string(),
            mimes: vec![],
            terminal: true,
            no_display: false,
            path: PathBuf::from("/usr/share/applications/term-cli.desktop"),
        };
        let (term_bin, prefix) = res.for_command();
        let mut full = vec![term_bin.to_string_lossy().to_string()];
        full.extend(prefix);
        let mut argv = expand_exec(&app, &[PathBuf::from("/tmp/doc.txt")]);
        full.append(&mut argv);
        assert_eq!(
            full,
            vec![
                "/bin/kitty",
                "-T",
                "`touch pwned`",
                "$(uname)",
                "cli-tool",
                "--opt",
                "/tmp/doc.txt"
            ]
        );

        // 10. Quoted executable path with spaces in desktop config.
        fs::write(
            &kde_cfg,
            "[General]\nTerminalApplication=\"/opt/My Term/kitty\" -1\n",
        )
        .unwrap();
        let res = resolve_terminal_with(None, "KDE", fake_no_xdg, &temp_dir).unwrap();
        assert_eq!(res.bin, PathBuf::from("/opt/My Term/kitty"));
        assert_eq!(res.args, vec!["-1"]);

        // 11. Unsectioned XFCE helpers.rc support.
        let xfce_dir = temp_dir.join("xfce4");
        fs::create_dir_all(&xfce_dir).unwrap();
        fs::write(xfce_dir.join("helpers.rc"), "TerminalEmulator=kitty -1\n").unwrap();
        let res = resolve_terminal_with(None, "XFCE", fake_no_xdg, &temp_dir).unwrap();
        assert_eq!(res.bin, PathBuf::from("/bin/kitty"));
        assert_eq!(res.args, vec!["-1"]);

        // 12. WezTerm open-in-folder requires 'start --cwd <dir>' without duplicating 'start'.
        let fake_wezterm_only = |name: &str| match name {
            "wezterm" => Some(PathBuf::from("/bin/wezterm")),
            _ => None,
        };
        let res = resolve_terminal_with(None, "", fake_wezterm_only, &temp_dir).unwrap();
        assert_eq!(res.bin, PathBuf::from("/bin/wezterm"));
        let (w_bin, w_open) = res.for_open_in(Path::new("/tmp/my folder"));
        assert_eq!(w_bin, PathBuf::from("/bin/wezterm"));
        assert_eq!(w_open, vec!["start", "--cwd", "/tmp/my folder"]);

        // If user configured "wezterm start --flag", 'start' must not be duplicated.
        let res_configured =
            resolve_terminal_with(Some("wezterm start --some-flag"), "", fake_which, &temp_dir)
                .unwrap();
        let (_, w_open_configured) = res_configured.for_open_in(Path::new("/tmp/my folder"));
        assert_eq!(
            w_open_configured,
            vec!["start", "--some-flag", "--cwd", "/tmp/my folder"]
        );

        // Also for Terminal=true command execution: 'start' must not be duplicated in for_command()!
        let (_, w_cmd_configured) = res_configured.for_command();
        assert_eq!(w_cmd_configured, vec!["start", "--some-flag", "--"]);

        // 13. kgx, gnome-terminal, ghostty, xfce4-terminal, tilix verified working-directory arguments.
        let fake_gnome = |name: &str| match name {
            "gnome-terminal" => Some(PathBuf::from("/bin/gnome-terminal")),
            _ => None,
        };
        let res = resolve_terminal_with(None, "", fake_gnome, &temp_dir).unwrap();
        assert_eq!(
            res.for_open_in(Path::new("/tmp")).1,
            vec!["--working-directory=/tmp"]
        );

        let fake_kgx = |name: &str| match name {
            "kgx" => Some(PathBuf::from("/bin/kgx")),
            _ => None,
        };
        let res = resolve_terminal_with(None, "", fake_kgx, &temp_dir).unwrap();
        assert_eq!(
            res.for_open_in(Path::new("/tmp")).1,
            vec!["--working-directory=/tmp"]
        );

        let fake_ghostty = |name: &str| match name {
            "ghostty" => Some(PathBuf::from("/bin/ghostty")),
            _ => None,
        };
        let res = resolve_terminal_with(None, "", fake_ghostty, &temp_dir).unwrap();
        assert_eq!(
            res.for_open_in(Path::new("/tmp")).1,
            vec!["--working-directory=/tmp"]
        );

        let fake_xfce_term = |name: &str| match name {
            "xfce4-terminal" => Some(PathBuf::from("/bin/xfce4-terminal")),
            _ => None,
        };
        let res = resolve_terminal_with(None, "", fake_xfce_term, &temp_dir).unwrap();
        assert_eq!(
            res.for_open_in(Path::new("/tmp")).1,
            vec!["--working-directory=/tmp"]
        );

        let fake_tilix = |name: &str| match name {
            "tilix" => Some(PathBuf::from("/bin/tilix")),
            _ => None,
        };
        let res = resolve_terminal_with(None, "", fake_tilix, &temp_dir).unwrap();
        assert_eq!(res.for_open_in(Path::new("/tmp")).1, vec!["-w", "/tmp"]);

        let _ = fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn terminal_spawn_captures_argv_and_cwd() {
        use std::os::unix::fs::PermissionsExt;

        let temp_dir = std::env::temp_dir().join(format!("loaf-spawn-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&temp_dir);
        fs::create_dir_all(&temp_dir).unwrap();

        let bin_dir = temp_dir.join("bin");
        fs::create_dir_all(&bin_dir).unwrap();

        let capture_log = temp_dir.join("capture.log");
        let fake_term = bin_dir.join("my-fake-term");

        // Pass capture file path safely as first argument; no shell code interpolation.
        // Script writes atomically via temp file + rename and outputs DONE marker.
        let script = r#"#!/bin/sh
out="$1"
shift
tmp="${out}.tmp.$$"
echo "CWD: $(pwd)" > "$tmp"
for a in "$@"; do
  echo "ARG: $a" >> "$tmp"
done
echo "DONE" >> "$tmp"
mv "$tmp" "$out"
"#;
        fs::write(&fake_term, script).unwrap();
        let mut perms = fs::metadata(&fake_term).unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&fake_term, perms).unwrap();

        // Target directory with special characters, quotes, and spaces
        let target_dir = temp_dir.join("folder with spaces & $symbols; 'quotes'");
        fs::create_dir_all(&target_dir).unwrap();

        // Configure fake terminal in test kdeglobals, passing capture_log as first arg
        let kde_cfg = temp_dir.join("kdeglobals");
        fs::write(
            &kde_cfg,
            format!(
                "[General]\nTerminalApplication=\"{}\" \"{}\" --custom-arg \"val with space\"\n",
                fake_term.to_string_lossy(),
                capture_log.to_string_lossy()
            ),
        )
        .unwrap();

        let which_fn = |name: &str| {
            if name == fake_term.to_str().unwrap() || name == "my-fake-term" {
                Some(fake_term.clone())
            } else {
                None
            }
        };

        let resolved = resolve_terminal_with(None, "KDE", which_fn, &temp_dir)
            .expect("must resolve configured fake terminal");

        let (bin, args) = resolved.for_open_in(&target_dir);
        let mut cmd = Command::new(&bin);
        cmd.args(&args).current_dir(&target_dir);

        let spawn_res = util::spawn_detached(cmd);
        assert!(spawn_res.is_ok(), "spawn_detached failed: {:?}", spawn_res);

        // Wait bounded time for DONE marker in atomically published capture log
        let mut captured = String::new();
        for _ in 0..50 {
            if let Ok(c) = fs::read_to_string(&capture_log) {
                if c.contains("DONE\n") {
                    captured = c;
                    break;
                }
            }
            std::thread::sleep(std::time::Duration::from_millis(50));
        }

        assert!(
            !captured.is_empty(),
            "fake terminal was not executed or did not complete within timeout"
        );
        let lines: Vec<&str> = captured.lines().collect();

        // 1. Child process working directory matches requested target_dir exactly
        assert_eq!(lines[0], format!("CWD: {}", target_dir.to_string_lossy()));

        // 2. Arguments preserved literally without shell interpretation or loss of spaces
        assert_eq!(lines[1], "ARG: --custom-arg");
        assert_eq!(lines[2], "ARG: val with space");
        assert_eq!(lines[3], "DONE");

        // 3. Unknown terminal does not receive guessed working-directory flag; default exec flag is -e
        assert_eq!(lines.len(), 4);

        let _ = fs::remove_dir_all(&temp_dir);
    }
}
