#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, current_path)]
        #[qproperty(QString, current_dir_name)]
        #[qproperty(QString, files_json)]
        #[qproperty(QString, breadcrumbs_json)]
        #[qproperty(bool, is_dark)]
        #[qproperty(bool, has_clipboard)]
        #[qproperty(bool, show_hidden)]
        #[qproperty(bool, disambiguate_duplicates)]
        #[qproperty(QString, wallpaper_colors_json)]
        #[qproperty(bool, is_searching_everywhere)]
        #[qproperty(QString, search_everywhere_json)]
        #[qproperty(bool, can_go_back)]
        #[qproperty(bool, can_go_forward)]
        #[qproperty(QString, hostname)]
        #[qproperty(QString, drives_json)]
        #[qproperty(QString, trash_json)]
        #[qproperty(QString, frequent_dirs_json)]
        #[qproperty(QString, sort_by)]
        #[qproperty(bool, sort_ascending)]
        #[qproperty(bool, dirs_first)]
        #[qproperty(QString, folder_position)]
        #[qproperty(QString, view_mode)]
        #[qproperty(QString, clipboard_cut_paths_json)]
        #[qproperty(QString, device_type)]
        #[qproperty(bool, can_undo)]
        #[qproperty(bool, can_redo)]
        #[qproperty(QString, trash_root)]
        type LoafEngine = super::LoafEngineRust;

        #[qinvokable]
        fn set_path(self: Pin<&mut LoafEngine>, path: &QString);

        #[qinvokable]
        fn navigate_up(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn go_back(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn go_forward(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn refresh(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn toggle_show_hidden(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn toggle_disambiguate_duplicates(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn resolve_icon(self: &LoafEngine, name: &QString) -> QString;

        #[qinvokable]
        fn get_thumbnail(self: &LoafEngine, path: &QString) -> QString;

        #[qinvokable]
        fn search_everywhere(self: Pin<&mut LoafEngine>, query: &QString);

        #[qinvokable]
        fn clear_search_everywhere(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn load_drives(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn refresh_frequent_dirs(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn load_trash(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn empty_trash(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn open_item(self: &LoafEngine, path: &QString);

        #[qinvokable]
        fn open_with_apps(self: &LoafEngine, path: &QString) -> QString;

        #[qinvokable]
        fn all_open_with_apps(self: &LoafEngine) -> QString;

        #[qinvokable]
        fn open_with_app(self: &LoafEngine, path: &QString, app_id: &QString);

        #[qinvokable]
        fn default_app_for(self: &LoafEngine, path: &QString) -> QString;

        #[qinvokable]
        fn set_default_app(self: &LoafEngine, path: &QString, app_id: &QString);

        #[qinvokable]
        fn run_custom_command(self: &LoafEngine, command: &QString, path: &QString) -> bool;

        #[qinvokable]
        fn recent_open_with_apps(self: &LoafEngine) -> QString;

        #[qinvokable]
        fn open_terminal(self: &LoafEngine, dir_path: &QString);

        #[qinvokable]
        fn create_folder(self: Pin<&mut LoafEngine>, dir: &QString, name: &QString);

        #[qinvokable]
        fn create_file(self: Pin<&mut LoafEngine>, dir: &QString, name: &QString);

        #[qinvokable]
        fn rename_item(self: Pin<&mut LoafEngine>, dir: &QString, old_name: &QString, new_name: &QString);

        #[qinvokable]
        fn trash_items(self: Pin<&mut LoafEngine>, paths_json: &QString);

        #[qinvokable]
        fn copy_items(self: Pin<&mut LoafEngine>, paths_json: &QString, is_cut: bool);

        #[qinvokable]
        fn paste_items(self: Pin<&mut LoafEngine>, dest_dir: &QString);

        #[qinvokable]
        fn drop_items(self: Pin<&mut LoafEngine>, paths_json: &QString, dest_dir: &QString, as_copy: bool);

        #[qinvokable]
        fn get_item_info(self: &LoafEngine, path: &QString) -> QString;

        #[qinvokable]
        fn quick_look(self: &LoafEngine, path: &QString) -> QString;

        #[qinvokable]
        fn set_sort(self: Pin<&mut LoafEngine>, sort_by: &QString, ascending: bool);

        #[qinvokable]
        fn toggle_sort_order(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn toggle_view_mode(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn check_paste_conflicts(self: &LoafEngine, paths_json: &QString, dest_dir: &QString) -> QString;

        #[qinvokable]
        fn check_clipboard_conflicts(self: &LoafEngine, dest_dir: &QString) -> QString;

        #[qinvokable]
        fn paste_items_resolved(self: Pin<&mut LoafEngine>, dest_dir: &QString, resolution: &QString);

        #[qinvokable]
        fn drop_items_resolved(self: Pin<&mut LoafEngine>, paths_json: &QString, dest_dir: &QString, as_copy: bool, resolution: &QString);

        #[qinvokable]
        fn change_folder_position(self: Pin<&mut LoafEngine>, position: &QString);

        #[qinvokable]
        fn compress_items_with_options(self: Pin<&mut LoafEngine>, paths_json: &QString, format: &QString, password: &QString);

        #[qinvokable]
        fn create_symlinks(self: Pin<&mut LoafEngine>, paths_json: &QString, dest_dir: &QString);

        #[qinvokable]
        fn compress_items(self: Pin<&mut LoafEngine>, paths_json: &QString, format: &QString);

        #[qinvokable]
        fn extract_archive(self: Pin<&mut LoafEngine>, archive_path: &QString, into_subfolder: bool);

        #[qinvokable]
        fn is_archive_file(self: &LoafEngine, path: &QString) -> bool;

        #[qinvokable]
        fn mount_drive(self: Pin<&mut LoafEngine>, device: &QString);

        #[qinvokable]
        fn unmount_drive(self: Pin<&mut LoafEngine>, device: &QString);

        #[qinvokable]
        fn rename_drive(self: Pin<&mut LoafEngine>, device: &QString, new_name: &QString);

        #[qinvokable]
        fn undo(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn redo(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn refresh_system_theme(self: Pin<&mut LoafEngine>);

        #[qinvokable]
        fn restore_trash_item(self: Pin<&mut LoafEngine>, path: &QString);

        #[qinvokable]
        fn get_setting(&self, key: &QString) -> QString;

        #[qinvokable]
        fn set_setting(self: Pin<&mut LoafEngine>, key: &QString, value: &QString);

        #[qinvokable]
        fn reload_wallpaper_colors(self: Pin<&mut LoafEngine>) -> bool;
    }
}

use core::pin::Pin;
use cxx_qt::CxxQtType;
use cxx_qt_lib::QString;
use serde::Serialize;
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

static CLIPBOARD: Mutex<(Vec<String>, bool)> = Mutex::new((Vec::new(), false));
static ICON_CACHE: Mutex<Option<HashMap<String, String>>> = Mutex::new(None);
static VISIT_COUNTS: Mutex<Option<HashMap<String, usize>>> = Mutex::new(None);
static SETTINGS_STORE: Mutex<Option<HashMap<String, String>>> = Mutex::new(None);
static BIN_CACHE: Mutex<Option<HashMap<String, Option<String>>>> = Mutex::new(None);

pub fn resolve_system_icon(name: &str) -> String {
    let mut cache_guard = ICON_CACHE.lock().unwrap();
    let cache = cache_guard.get_or_insert_with(HashMap::new);

    if let Some(path) = cache.get(name) {
        return path.clone();
    }

    let home = std::env::var("HOME").unwrap_or_default();
    let search_roots = [
        format!("{}/.local/share/icons", home),
        format!("{}/.icons", home),
        "/run/current-system/sw/share/icons".to_string(),
    ];

    let themes = ["WhiteSur", "WhiteSur-dark", "WhiteSur-light", "Adwaita", "Papirus", "hicolor"];

    let subdirs = [
        "symbolic/places", "symbolic/actions", "symbolic/mimetypes", "symbolic/categories", "symbolic/devices", "symbolic/status", "symbolic/legacy",
        "scalable/places", "scalable/mimetypes", "scalable/actions", "scalable/devices", "scalable/status",
        "48x48/places", "48x48/mimetypes", "48x48/actions", "48x48/devices",
        "48x48@2x/places", "48x48@2x/mimetypes", "48x48@2x/actions", "48x48@2x/devices",
    ];

    let mut found_path = String::new();

    'outer: for root in &search_roots {
        for theme in &themes {
            let theme_dir = Path::new(root).join(theme);
            if !theme_dir.is_dir() {
                continue;
            }

            for sub in &subdirs {
                let candidate_dir = theme_dir.join(sub);
                for ext in &["svg", "png"] {
                    let direct = candidate_dir.join(format!("{}.{}", name, ext));
                    if direct.exists() {
                        found_path = format!("file://{}", direct.to_string_lossy());
                        break 'outer;
                    }
                    let symbolic = candidate_dir.join(format!("{}-symbolic.{}", name, ext));
                    if symbolic.exists() {
                        found_path = format!("file://{}", symbolic.to_string_lossy());
                        break 'outer;
                    }
                }
            }
        }
    }

    cache.insert(name.to_string(), found_path.clone());
    found_path
}

fn run_cmd_stdout(cmd: &str, args: &[&str]) -> Option<String> {
    let output = std::process::Command::new(cmd).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn dark_from_gsettings() -> Option<bool> {
    let out = run_cmd_stdout("gsettings", &["get", "org.gnome.desktop.interface", "color-scheme"])?;
    let s = out.to_lowercase();
    if s.contains("prefer-dark") {
        Some(true)
    } else if s.contains("prefer-light") {
        Some(false)
    } else {
        // "default"/unset means "no preference": try the next source.
        None
    }
}

fn dark_from_portal() -> Option<bool> {
    let out = run_cmd_stdout(
        "gdbus",
        &[
            "call",
            "--session",
            "--dest",
            "org.freedesktop.portal.Desktop",
            "--object-path",
            "/org/freedesktop/portal/desktop",
            "--method",
            "org.freedesktop.portal.Settings.Read",
            "org.freedesktop.appearance",
            "color-scheme",
        ],
    )?;
    // Reply shape: (<uint32 1>,) where 0 = no preference, 1 = prefer dark, 2 = prefer light.
    if out.contains("uint32 1") {
        Some(true)
    } else if out.contains("uint32 2") {
        Some(false)
    } else {
        None
    }
}

fn dark_from_gtk_settings() -> Option<bool> {
    let home = std::env::var("HOME").unwrap_or_default();
    let candidates = [
        std::env::var("XDG_CONFIG_HOME").ok().map(|c| PathBuf::from(c).join("gtk-3.0/settings.ini")),
        std::env::var("XDG_CONFIG_HOME").ok().map(|c| PathBuf::from(c).join("gtk-4.0/settings.ini")),
        Some(PathBuf::from(&home).join(".config/gtk-3.0/settings.ini")),
        Some(PathBuf::from(&home).join(".config/gtk-4.0/settings.ini")),
    ];

    for candidate in candidates.into_iter().flatten() {
        let Ok(content) = fs::read_to_string(&candidate) else { continue };
        for line in content.lines() {
            let line = line.trim();
            let Some((key, value)) = line.split_once('=') else { continue };
            if key.trim() != "gtk-application-prefer-dark-theme" {
                continue;
            }
            let v = value.trim().to_lowercase();
            if v == "1" || v == "true" || v == "yes" || v == "on" {
                return Some(true);
            }
            if v == "0" || v == "false" || v == "no" || v == "off" {
                return Some(false);
            }
        }
    }
    None
}

/// Detection order: gsettings -> XDG desktop portal -> GTK settings.ini -> dark.
fn detect_system_dark_mode() -> bool {
    if let Some(dark) = dark_from_gsettings() {
        return dark;
    }
    if let Some(dark) = dark_from_portal() {
        return dark;
    }
    if let Some(dark) = dark_from_gtk_settings() {
        return dark;
    }
    true
}

fn read_system_hostname() -> String {
    if let Ok(s) = fs::read_to_string("/proc/sys/kernel/hostname") {
        let trimmed = s.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    "PC".to_string()
}

/// Returns (source_path, content, mtime_secs) for the first readable color source.
fn read_wallpaper_colors_source() -> Option<(String, String, u64)> {
    let home = std::env::var("HOME").unwrap_or_default();
    let candidates = [
        format!("{}/.local/state/quickshell/user/generated/colors.json", home),
        format!("{}/.cache/wal/colors.json", home),
        format!("{}/.cache/matugen/colors.json", home),
    ];

    for path_str in candidates {
        let path = Path::new(&path_str);
        let Ok(content) = fs::read_to_string(path) else { continue };
        let is_object = serde_json::from_str::<serde_json::Value>(&content)
            .ok()
            .map(|v| v.is_object() && v.as_object().map(|o| !o.is_empty()).unwrap_or(false))
            .unwrap_or(false);
        if !is_object {
            continue;
        }
        let mtime = fs::metadata(path)
            .and_then(|m| m.modified())
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        return Some((path_str, content, mtime));
    }
    None
}

fn read_wallpaper_colors() -> String {
    read_wallpaper_colors_source()
        .map(|(_, content, _)| content)
        .unwrap_or_else(|| "{}".to_string())
}

#[derive(Serialize, Clone)]
pub struct FileItem {
    pub name: String,
    pub is_dir: bool,
    pub is_symlink: bool,
    pub icon: String,
    pub icon_path: String,
    pub thumbnail: String,
    pub category: String,
    pub size: u64,
    pub size_str: String,
    pub modified: u64,
    pub modified_str: String,
}

#[derive(Serialize, Clone)]
pub struct ConflictItem {
    pub name: String,
    pub src_path: String,
    pub dest_path: String,
    pub src_size: String,
    pub dest_size: String,
    pub is_dir: bool,
}

#[derive(Serialize)]
pub struct Breadcrumb {
    pub name: String,
    pub path: String,
    pub icon: String,
    pub system_icon: String,
    pub is_root_place: bool,
    pub is_forward: bool,
}

#[derive(Serialize, Clone)]
pub struct SearchResultItem {
    pub name: String,
    pub display_name: String,
    pub path: String,
    pub parent_path: String,
    pub is_dir: bool,
    pub icon: String,
    pub icon_path: String,
    pub thumbnail: String,
    pub category: String,
}

#[derive(Serialize, Clone)]
pub struct DriveItem {
    pub name: String,
    pub device: String,
    pub mount_point: String,
    pub is_mounted: bool,
    pub is_external: bool,
    pub fs_type: String,
    pub total_str: String,
    pub used_str: String,
    pub free_str: String,
    pub total_bytes: u64,
    pub used_bytes: u64,
    pub free_bytes: u64,
    pub percent: f64,
    pub model: String,
}

#[derive(Serialize, Clone)]
pub struct FrequentDirItem {
    pub name: String,
    pub path: String,
    pub icon: String,
}

#[derive(Serialize)]
pub struct ItemInfo {
    pub name: String,
    pub path: String,
    pub size: String,
    pub is_dir: bool,
    pub modified: String,
}

pub struct LoafEngineRust {
    current_path: QString,
    current_dir_name: QString,
    files_json: QString,
    breadcrumbs_json: QString,
    is_dark: bool,
    has_clipboard: bool,
    show_hidden: bool,
    disambiguate_duplicates: bool,
    wallpaper_colors_json: QString,
    is_searching_everywhere: bool,
    search_everywhere_json: QString,
    can_go_back: bool,
    can_go_forward: bool,
    hostname: QString,
    drives_json: QString,
    trash_json: QString,
    frequent_dirs_json: QString,
    sort_by: QString,
    sort_ascending: bool,
    dirs_first: bool,
    folder_position: QString,
    view_mode: QString,
    clipboard_cut_paths_json: QString,
    device_type: QString,
    can_undo: bool,
    can_redo: bool,
    trash_root: QString,
    history_stack: Vec<String>,
    forward_stack: Vec<String>,
}

fn detect_device_type() -> &'static str {
    if let Ok(chassis) = fs::read_to_string("/sys/class/dmi/id/chassis_type") {
        match chassis.trim() {
            "8" | "9" | "10" | "11" | "14" | "30" | "31" | "32" => return "laptop",
            _ => {}
        }
    }
    if Path::new("/sys/class/power_supply/BAT0").exists() || Path::new("/sys/class/power_supply/BAT1").exists() {
        return "laptop";
    }
    "desktop"
}

#[derive(Clone)]
struct TrashItem {
    /// Absolute path the file had before it was trashed.
    original: String,
    /// Absolute path inside the trash `files/` directory.
    trashed: String,
    /// Absolute path to the matching `info/<name>.trashinfo` file.
    info: String,
}

#[derive(Clone)]
enum UndoAction {
    Rename { dir: String, old_name: String, new_name: String },
    Create { path: String, is_dir: bool },
    /// Pairs are (from, to) as performed by the move.
    Move { pairs: Vec<(String, String)> },
    /// Pairs are (source, created_copy).
    Copy { pairs: Vec<(String, String)> },
    Trash { items: Vec<TrashItem> },
}

static UNDO_STACK: Mutex<Option<Vec<UndoAction>>> = Mutex::new(None);
static REDO_STACK: Mutex<Option<Vec<UndoAction>>> = Mutex::new(None);

fn stack_len(stack: &Mutex<Option<Vec<UndoAction>>>) -> usize {
    stack.lock().unwrap().as_ref().map(|s| s.len()).unwrap_or(0)
}

fn clear_stack(stack: &Mutex<Option<Vec<UndoAction>>>) {
    if let Some(s) = stack.lock().unwrap().as_mut() {
        s.clear();
    }
}

/// Pushes an undo entry and invalidates the redo stack, keeping both bounded.
fn push_undo(action: UndoAction) {
    {
        let mut guard = UNDO_STACK.lock().unwrap();
        let stack = guard.get_or_insert_with(Vec::new);
        stack.push(action);
        if stack.len() > 200 {
            stack.remove(0);
        }
    }
    clear_stack(&REDO_STACK);
}

fn percent_encode_path(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        let keep = b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~' | b'/');
        if keep {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{:02X}", b));
        }
    }
    out
}

/// Builds a Qt-friendly `file://` URL with the path percent-encoded.
fn file_url(path: &Path) -> String {
    format!("file://{}", percent_encode_path(&path.to_string_lossy()))
}

fn iso_datetime_now() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let days = (secs / 86400) as i64;
    let rem = secs % 86400;

    // days -> civil date (Howard Hinnant's algorithm)
    let z = days + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = (z - era * 146097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };

    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}",
        y,
        m,
        d,
        rem / 3600,
        (rem % 3600) / 60,
        rem % 60
    )
}

fn trash_root_dir() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_DATA_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg).join("Trash");
        }
    }
    let home = std::env::var("HOME").unwrap_or_default();
    PathBuf::from(home).join(".local/share/Trash")
}

fn trash_paths() -> (PathBuf, PathBuf) {
    let root = trash_root_dir();
    (root.join("files"), root.join("info"))
}

fn unique_trash_name(files_dir: &Path, name: &str) -> String {
    if !files_dir.join(name).exists() {
        return name.to_string();
    }
    let p = Path::new(name);
    let stem = p.file_stem().and_then(|s| s.to_str()).unwrap_or(name);
    let ext = p
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| format!(".{}", e))
        .unwrap_or_default();
    let mut i = 1;
    loop {
        let candidate = format!("{}.{}{}", stem, i, ext);
        if !files_dir.join(&candidate).exists() {
            return candidate;
        }
        i += 1;
    }
}

/// Moves `path` into the user's trash (#1.1 freedesktop spec) and returns
/// everything needed to reverse the operation.
fn trash_into_home_trash(path: &Path) -> Option<TrashItem> {
    let name = path.file_name().and_then(|n| n.to_str())?.to_string();
    if !path.exists() {
        return None;
    }

    let (files_dir, info_dir) = trash_paths();
    fs::create_dir_all(&files_dir).ok()?;
    fs::create_dir_all(&info_dir).ok()?;

    let trash_name = unique_trash_name(&files_dir, &name);
    let trashed = files_dir.join(&trash_name);
    let info_path = info_dir.join(format!("{}.trashinfo", trash_name));

    let abs = fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    let abs_str = abs.to_string_lossy().to_string();
    let info_content = format!(
        "[Trash Info]\nPath={}\nDeletionDate={}\n",
        percent_encode_path(&abs_str),
        iso_datetime_now()
    );
    fs::write(&info_path, info_content).ok()?;

    let mut moved = fs::rename(path, &trashed).is_ok();
    if !moved {
        // Cross-device fallback: copy then delete the original.
        let copied = if abs.is_dir() {
            std::process::Command::new("cp")
                .arg("-r")
                .arg(&abs)
                .arg(&trashed)
                .status()
                .map(|s| s.success())
                .unwrap_or(false)
        } else {
            fs::copy(&abs, &trashed).is_ok()
        };
        if copied {
            let _ = if abs.is_dir() { fs::remove_dir_all(&abs) } else { fs::remove_file(&abs) };
            moved = true;
        }
    }

    if !moved {
        let _ = fs::remove_file(&info_path);
        return None;
    }

    Some(TrashItem {
        original: abs_str,
        trashed: trashed.to_string_lossy().to_string(),
        info: info_path.to_string_lossy().to_string(),
    })
}

/// Reads the `Path=` line out of a `.trashinfo` file.
fn parse_trashinfo_path(info_content: &str) -> Option<String> {
    for line in info_content.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("Path=") {
            let mut decoded = Vec::with_capacity(rest.len());
            let bytes = rest.as_bytes();
            let mut i = 0;
            while i < bytes.len() {
                if bytes[i] == b'%' && i + 2 < bytes.len() {
                    if let Ok(v) = u8::from_str_radix(&rest[i + 1..i + 3], 16) {
                        decoded.push(v);
                        i += 3;
                        continue;
                    }
                }
                decoded.push(bytes[i]);
                i += 1;
            }
            let s = String::from_utf8_lossy(&decoded).to_string();
            if !s.is_empty() {
                return Some(s);
            }
        }
    }
    None
}

fn config_file_path() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg).join("loaf/config.json");
        }
    }
    let home = std::env::var("HOME").unwrap_or_default();
    PathBuf::from(home).join(".config/loaf/config.json")
}

fn load_settings() -> HashMap<String, String> {
    {
        let guard = SETTINGS_STORE.lock().unwrap();
        if let Some(map) = guard.as_ref() {
            return map.clone();
        }
    }

    let mut map = HashMap::new();
    if let Ok(content) = fs::read_to_string(config_file_path()) {
        if let Ok(serde_json::Value::Object(obj)) = serde_json::from_str::<serde_json::Value>(&content) {
            for (k, v) in obj {
                if let Some(s) = v.as_str() {
                    map.insert(k, s.to_string());
                }
            }
        }
    }

    *SETTINGS_STORE.lock().unwrap() = Some(map.clone());
    map
}

/// Writes `map` to disk and refreshes the in-memory cache, so the next
/// `load_settings` sees the new values. (Saving without refreshing the cache
/// would leave `load_settings` returning stale data for the rest of the run.)
fn store_settings(map: &HashMap<String, String>) {
    save_settings(map);
    *SETTINGS_STORE.lock().unwrap() = Some(map.clone());
}

/// Persists settings atomically (temp file in the same directory + rename).
fn save_settings(map: &HashMap<String, String>) {
    let path = config_file_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let json = serde_json::to_string_pretty(map).unwrap_or_else(|_| "{}".to_string());
    let tmp = path.with_extension("json.tmp");
    if fs::write(&tmp, json.as_bytes()).is_ok() {
        if fs::rename(&tmp, &path).is_err() {
            let _ = fs::remove_file(&tmp);
        }
    } else {
        eprintln!("loaf: could not write settings to {:?}", path);
    }
}

fn find_in_store(keyword: &str, rel: &str) -> Option<String> {
    let entries = fs::read_dir("/nix/store").ok()?;
    let mut best: Option<String> = None;
    for entry in entries.flatten() {
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if !name.contains(keyword) {
            continue;
        }
        let candidate = entry.path().join(rel);
        if candidate.is_file() {
            let s = candidate.to_string_lossy().to_string();
            // Prefer the shortest match so the choice is stable across runs.
            if best.as_ref().map(|b| s.len() < b.len()).unwrap_or(true) {
                best = Some(s);
            }
        }
    }
    best
}

fn resolve_binary_uncached(name: &str, store_keyword: &str) -> Option<String> {
    // 1. PATH (covers `nix develop` and normal host installs).
    if let Ok(path) = std::env::var("PATH") {
        for dir in std::env::split_paths(&path) {
            let candidate = dir.join(name);
            if candidate.is_file() {
                return Some(candidate.to_string_lossy().to_string());
            }
        }
    }

    // 2. Common profile / system locations.
    let home = std::env::var("HOME").unwrap_or_default();
    let user = std::env::var("USER").unwrap_or_default();
    let extra = [
        format!("/run/current-system/sw/bin/{}", name),
        format!("/run/wrappers/bin/{}", name),
        format!("/etc/profiles/per-user/{}/bin/{}", user, name),
        format!("{}/.nix-profile/bin/{}", home, name),
        format!("/nix/var/nix/profiles/default/bin/{}", name),
        format!("/usr/local/bin/{}", name),
        format!("/usr/bin/{}", name),
        format!("/bin/{}", name),
    ];
    for candidate in extra {
        if Path::new(&candidate).is_file() {
            return Some(candidate);
        }
    }

    // 3. Nix store (e.g. `7z` from pkgs.p7zip, `zip` from pkgs.zip when running
    //    the built binary outside of the dev shell).
    find_in_store(store_keyword, &format!("bin/{}", name))
}

fn resolve_binary(name: &str, store_keyword: &str) -> Option<String> {
    {
        let guard = BIN_CACHE.lock().unwrap();
        if let Some(cache) = guard.as_ref() {
            if let Some(hit) = cache.get(name) {
                return hit.clone();
            }
        }
    }

    let resolved = resolve_binary_uncached(name, store_keyword);
    let mut guard = BIN_CACHE.lock().unwrap();
    guard
        .get_or_insert_with(HashMap::new)
        .insert(name.to_string(), resolved.clone());
    resolved
}

/// First available executable from a set of aliases.
fn resolve_any_binary(names: &[&str], store_keyword: &str) -> Option<String> {
    names.iter().find_map(|n| resolve_binary(n, store_keyword))
}

fn archive_base_name(path: &Path) -> String {
    let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("archive");
    let lower = name.to_lowercase();
    for suffix in [
        ".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2", ".tgz", ".txz", ".tbz2", ".zip", ".7z", ".tar",
    ] {
        if lower.ends_with(suffix) {
            return name[..name.len() - suffix.len()].to_string();
        }
    }
    path.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("archive")
        .to_string()
}

/// Name to store inside the archive: relative to the archive's directory.
fn relative_name(path: &str, parent: &Path) -> String {
    let p = Path::new(path);
    match p.strip_prefix(parent) {
        Ok(rel) if !rel.as_os_str().is_empty() => rel.to_string_lossy().to_string(),
        _ => p
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| path.to_string()),
    }
}

fn ran_ok(status: std::io::Result<std::process::ExitStatus>) -> bool {
    status.map(|s| s.success()).unwrap_or(false)
}

fn seven_zip_bin() -> Option<String> {
    resolve_any_binary(&["7z", "7zz", "7za", "7zr"], "p7zip")
}

fn compress_with_7z(archive: &Path, names: &[String], pass: &str, parent: &Path) -> bool {
    let Some(bin) = seven_zip_bin() else {
        eprintln!("loaf: 7z not found (install p7zip) - cannot create .7z archives");
        return false;
    };

    let mut cmd = std::process::Command::new(bin);
    cmd.current_dir(parent).arg("a").arg("-y");
    if !pass.is_empty() {
        cmd.arg(format!("-p{}", pass));
        // Header encryption is only valid for 7z containers.
        cmd.arg("-mhe=on");
    }
    cmd.arg(archive).args(names);
    ran_ok(cmd.status())
}

fn compress_zip_encrypted(archive: &Path, names: &[String], pass: &str, parent: &Path) -> bool {
    if pass.is_empty() {
        return compress_zip(archive, names, parent);
    }

    // Preferred: AES-256 zip via 7z. `-mhe=on` cannot be used with `-tzip`
    // (p7zip rejects it with E_INVALIDARG), so only the password is passed.
    if let Some(bin) = seven_zip_bin() {
        let ok = ran_ok(
            std::process::Command::new(&bin)
                .current_dir(parent)
                .args(["a", "-y", "-tzip", "-mem=AES256"])
                .arg(format!("-p{}", pass))
                .arg(archive)
                .args(names)
                .status(),
        );
        if ok {
            return true;
        }
    }

    // Fallback: legacy ZipCrypto via the `zip` CLI (weaker, but keeps the menu option working).
    if let Some(zip) = resolve_binary("zip", "zip") {
        eprintln!("loaf: 7z unavailable, using legacy ZipCrypto encryption for {}", archive.display());
        return ran_ok(
            std::process::Command::new(zip)
                .current_dir(parent)
                .arg("-r")
                .arg(format!("-P{}", pass))
                .arg(archive)
                .args(names)
                .status(),
        );
    }

    eprintln!("loaf: neither 7z nor zip is installed - cannot create an encrypted archive");
    false
}

fn compress_zip(archive: &Path, names: &[String], parent: &Path) -> bool {
    if let Some(zip) = resolve_binary("zip", "zip") {
        if ran_ok(
            std::process::Command::new(&zip)
                .current_dir(parent)
                .args(["-r", "-q"])
                .arg(archive)
                .args(names)
                .status(),
        ) {
            return true;
        }
    }

    if let Some(bin) = seven_zip_bin() {
        if ran_ok(
            std::process::Command::new(bin)
                .current_dir(parent)
                .args(["a", "-y", "-tzip"])
                .arg(archive)
                .args(names)
                .status(),
        ) {
            return true;
        }
    }

    if let Some(python) = resolve_binary("python3", "python3") {
        return ran_ok(
            std::process::Command::new(python)
                .current_dir(parent)
                .args(["-m", "zipfile", "-c"])
                .arg(archive)
                .args(names)
                .status(),
        );
    }

    eprintln!("loaf: no zip, 7z or python3 available - cannot create .zip archives");
    false
}

fn compress_tar(archive: &Path, names: &[String], parent: &Path, flag: &str) -> bool {
    ran_ok(
        std::process::Command::new("tar")
            .arg(format!("-c{}f", flag))
            .arg(archive)
            .args(["-C"])
            .arg(parent)
            .args(names)
            .status(),
    )
}

fn compress_tar_zstd(archive: &Path, names: &[String], parent: &Path) -> bool {
    let long = ran_ok(
        std::process::Command::new("tar")
            .args(["--zstd", "-cf"])
            .arg(archive)
            .args(["-C"])
            .arg(parent)
            .args(names)
            .status(),
    );
    if long {
        return true;
    }

    // Older tar builds: pipe through the zstd binary explicitly.
    ran_ok(
        std::process::Command::new("tar")
            .args(["-I", "zstd", "-cf"])
            .arg(archive)
            .args(["-C"])
            .arg(parent)
            .args(names)
            .status(),
    )
}

fn collect_cpio_paths(root: &Path, rel: &str, out: &mut Vec<String>) {
    out.push(rel.to_string());
    if !root.is_dir() {
        return;
    }
    if let Ok(entries) = fs::read_dir(root) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            let child_rel = format!("{}/{}", rel.trim_end_matches('/'), name);
            collect_cpio_paths(&entry.path(), &child_rel, out);
        }
    }
}

fn compress_cpio(archive: &Path, names: &[String], parent: &Path) -> bool {
    use std::io::Write as _;

    let Some(cpio) = resolve_binary("cpio", "cpio") else {
        eprintln!("loaf: cpio not found (install cpio) - cannot create .cpio archives");
        return false;
    };

    // cpio does not recurse: feed it the full, newline/NUL separated file list.
    let mut list: Vec<String> = Vec::new();
    for name in names {
        collect_cpio_paths(&parent.join(name), name, &mut list);
    }

    let Ok(file) = fs::File::create(archive) else {
        eprintln!("loaf: could not create {}", archive.display());
        return false;
    };

    let mut child = match std::process::Command::new(cpio)
        .current_dir(parent)
        .args(["--null", "-o", "-H", "newc", "--quiet"])
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::from(file))
        .spawn()
    {
        Ok(child) => child,
        Err(err) => {
            eprintln!("loaf: could not run cpio: {}", err);
            return false;
        }
    };

    if let Some(stdin) = child.stdin.as_mut() {
        for item in &list {
            if stdin.write_all(item.as_bytes()).is_err() || stdin.write_all(b"\0").is_err() {
                break;
            }
        }
    }
    drop(child.stdin.take());

    ran_ok(child.wait())
}

fn copy_recursive(src: &Path, dst: &Path) -> bool {
    if src.is_dir() {
        std::process::Command::new("cp")
            .arg("-r")
            .arg(src)
            .arg(dst)
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
    } else {
        fs::copy(src, dst).is_ok()
    }
}

fn remove_path(path: &Path) -> bool {
    if path.is_dir() {
        fs::remove_dir_all(path).is_ok()
    } else {
        fs::remove_file(path).is_ok()
    }
}

/// Falls back to the system trash CLI when the in-process trash fails, then
/// recovers the matching `.trashinfo` entry so the action stays undoable.
fn trash_via_cli(path: &Path) -> Option<TrashItem> {
    let (files_dir, info_dir) = trash_paths();
    let before: std::collections::HashSet<String> = fs::read_dir(&info_dir)
        .map(|entries| {
            entries
                .flatten()
                .filter_map(|e| e.file_name().into_string().ok())
                .collect()
        })
        .unwrap_or_default();

    let abs = fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    let ran = std::process::Command::new("trash")
        .arg(&abs)
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
        || std::process::Command::new("gio")
            .arg("trash")
            .arg("--")
            .arg(&abs)
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
    if !ran {
        return None;
    }

    let entries = fs::read_dir(&info_dir).ok()?;
    for entry in entries.flatten() {
        let name = match entry.file_name().into_string() {
            Ok(n) => n,
            Err(_) => continue,
        };
        if before.contains(&name) || !name.ends_with(".trashinfo") {
            continue;
        }
        let Ok(content) = fs::read_to_string(entry.path()) else { continue };
        let Some(original) = parse_trashinfo_path(&content) else { continue };
        if Path::new(&original) == abs {
            let trashed = files_dir.join(name.trim_end_matches(".trashinfo"));
            return Some(TrashItem {
                original,
                trashed: trashed.to_string_lossy().to_string(),
                info: entry.path().to_string_lossy().to_string(),
            });
        }
    }
    None
}

/// Reverses `action` on the filesystem; returns the action that would replay it.
fn apply_inverse(action: &UndoAction) -> Option<UndoAction> {
    match action {
        UndoAction::Rename { dir, old_name, new_name } => {
            let base = Path::new(dir);
            fs::rename(base.join(new_name), base.join(old_name))
                .ok()
                .map(|_| UndoAction::Rename {
                    dir: dir.clone(),
                    old_name: old_name.clone(),
                    new_name: new_name.clone(),
                })
        }
        UndoAction::Create { path, is_dir } => {
            let p = Path::new(path);
            let ok = if *is_dir { fs::remove_dir_all(p).is_ok() } else { fs::remove_file(p).is_ok() };
            if ok {
                Some(UndoAction::Create { path: path.clone(), is_dir: *is_dir })
            } else {
                None
            }
        }
        UndoAction::Move { pairs } => {
            let mut undone = Vec::new();
            for (from, to) in pairs {
                if fs::rename(to, from).is_ok() {
                    undone.push((from.clone(), to.clone()));
                }
            }
            if undone.is_empty() {
                None
            } else {
                Some(UndoAction::Move { pairs: undone })
            }
        }
        UndoAction::Copy { pairs } => {
            let mut removed = Vec::new();
            for (source, created) in pairs {
                if remove_path(Path::new(created)) {
                    removed.push((source.clone(), created.clone()));
                }
            }
            if removed.is_empty() {
                None
            } else {
                Some(UndoAction::Copy { pairs: removed })
            }
        }
        UndoAction::Trash { items } => {
            let mut restored = Vec::new();
            for item in items {
                let from = Path::new(&item.trashed);
                let to = Path::new(&item.original);
                if let Some(parent) = to.parent() {
                    let _ = fs::create_dir_all(parent);
                }
                let mut ok = fs::rename(from, to).is_ok();
                if !ok && from.exists() && copy_recursive(from, to) {
                    let _ = remove_path(from);
                    ok = true;
                }
                if ok {
                    let _ = fs::remove_file(&item.info);
                    restored.push(item.clone());
                }
            }
            if restored.is_empty() {
                None
            } else {
                Some(UndoAction::Trash { items: restored })
            }
        }
    }
}

/// Replays `action` on the filesystem; returns the action that would undo it.
fn apply_action(action: &UndoAction) -> Option<UndoAction> {
    match action {
        UndoAction::Rename { dir, old_name, new_name } => {
            let base = Path::new(dir);
            fs::rename(base.join(old_name), base.join(new_name))
                .ok()
                .map(|_| action.clone())
        }
        UndoAction::Create { path, is_dir } => {
            let ok = if *is_dir {
                fs::create_dir_all(path).is_ok()
            } else {
                fs::File::create(path).is_ok()
            };
            if ok {
                Some(action.clone())
            } else {
                None
            }
        }
        UndoAction::Move { pairs } => {
            let mut redone = Vec::new();
            for (from, to) in pairs {
                if fs::rename(from, to).is_ok() {
                    redone.push((from.clone(), to.clone()));
                }
            }
            if redone.is_empty() {
                None
            } else {
                Some(UndoAction::Move { pairs: redone })
            }
        }
        UndoAction::Copy { pairs } => {
            let mut redone = Vec::new();
            for (source, created) in pairs {
                if copy_recursive(Path::new(source), Path::new(created)) {
                    redone.push((source.clone(), created.clone()));
                }
            }
            if redone.is_empty() {
                None
            } else {
                Some(UndoAction::Copy { pairs: redone })
            }
        }
        UndoAction::Trash { items } => {
            let mut retrashed = Vec::new();
            for item in items {
                if let Some(new_item) = trash_into_home_trash(Path::new(&item.original)) {
                    retrashed.push(new_item);
                }
            }
            if retrashed.is_empty() {
                None
            } else {
                Some(UndoAction::Trash { items: retrashed })
            }
        }
    }
}

fn format_size(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = 1024 * KB;
    const GB: u64 = 1024 * MB;

    if bytes >= GB {
        format!("{:.1} GB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.1} MB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.1} KB", bytes as f64 / KB as f64)
    } else {
        format!("{} B", bytes)
    }
}

fn format_unix_date(ts: u64) -> String {
    let days = (ts / 86400) as i64;
    let mut y = 1970;
    let mut d = days;
    loop {
        let leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
        let days_in_year = if leap { 366 } else { 365 };
        if d < days_in_year {
            break;
        }
        d -= days_in_year;
        y += 1;
    }
    let leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
    let month_days = [
        31, if leap { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
    ];
    let month_names = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    let mut m = 0;
    for (i, &md) in month_days.iter().enumerate() {
        if d < md {
            m = i;
            break;
        }
        d -= md;
    }
    format!("{} {}, {}", month_names[m], d + 1, y)
}

fn format_modified_time(meta: &fs::Metadata) -> (u64, String) {
    if let Ok(mtime) = meta.modified() {
        let ts = mtime.duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
        let elapsed = mtime.elapsed().map(|e| e.as_secs()).unwrap_or(0);
        let s = if elapsed < 60 {
            "Just now".to_string()
        } else if elapsed < 3600 {
            format!("{}m ago", elapsed / 60)
        } else if elapsed < 86400 {
            format!("{}h ago", elapsed / 3600)
        } else if elapsed < 86400 * 7 {
            format!("{}d ago", elapsed / 86400)
        } else {
            format_unix_date(ts)
        };
        (ts, s)
    } else {
        (0, "-".to_string())
    }
}

fn get_unique_name(dest: &Path, name: &str) -> PathBuf {
    let mut target = dest.join(name);
    if !target.exists() {
        return target;
    }
    let p = Path::new(name);
    let is_tar_gz = name.ends_with(".tar.gz");
    let (stem, ext) = if is_tar_gz {
        let s = name.strip_suffix(".tar.gz").unwrap_or(name);
        (s, ".tar.gz")
    } else {
        let s = p.file_stem().and_then(|s| s.to_str()).unwrap_or(name);
        let _e = p.extension().and_then(|e| e.to_str()).map(|e| format!(".{}", e)).unwrap_or_default();
        (s, "")
    };
    let ext_str = if is_tar_gz { ext.to_string() } else { p.extension().and_then(|e| e.to_str()).map(|e| format!(".{}", e)).unwrap_or_default() };

    let mut count = 1;
    loop {
        let new_name = format!("{} ({}){}", stem, count, ext_str);
        target = dest.join(&new_name);
        if !target.exists() {
            return target;
        }
        count += 1;
    }
}

fn is_archive_path(path: &Path) -> bool {
    let s = path.to_string_lossy().to_lowercase();
    s.ends_with(".zip")
        || s.ends_with(".tar.gz")
        || s.ends_with(".tgz")
        || s.ends_with(".tar.xz")
        || s.ends_with(".txz")
        || s.ends_with(".tar.zst")
        || s.ends_with(".tar.bz2")
        || s.ends_with(".tbz2")
        || s.ends_with(".tar")
        || s.ends_with(".7z")
        || s.ends_with(".rar")
        || s.ends_with(".zipx")
        || s.ends_with(".cab")
        || s.ends_with(".arj")
        || s.ends_with(".lha")
        || s.ends_with(".lzh")
        || s.ends_with(".cpio")
}

fn is_picture_format(ext: &str) -> bool {
    matches!(
        ext,
        "png" | "jpg" | "jpeg" | "jpe" | "jfif"
        | "webp" | "gif" | "bmp" | "dib" | "ico"
        | "svg" | "svgz"
        | "kra" | "ora"
        | "tiff" | "tif"
        | "avif" | "heic" | "heif" | "jxl"
        | "xcf" | "psd"
        | "raw" | "cr2" | "nef" | "dng" | "arw"
    )
}

fn get_thumbnail_cache_dir() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_default();
    let dir = PathBuf::from(home).join(".cache/loaf/thumbs");
    let _ = fs::create_dir_all(&dir);
    dir
}

/// Cache key: absolute path + mtime + size, so a modified file regenerates.
fn compute_file_hash(path: &Path) -> String {
    use std::hash::{Hash, Hasher};
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    path.to_string_lossy().hash(&mut hasher);
    if let Ok(meta) = fs::metadata(path) {
        if let Ok(mtime) = meta.modified() {
            mtime.hash(&mut hasher);
        }
        meta.len().hash(&mut hasher);
    }
    format!("{:016x}", hasher.finish())
}

/// Formats Qt can decode on its own (qtbase + qtsvg image plugins).
/// Everything else is converted to PNG in the thumbnail cache.
fn is_natively_renderable(ext: &str) -> bool {
    matches!(
        ext,
        "png" | "jpg" | "jpeg" | "jpe" | "jfif" | "gif" | "bmp" | "dib" | "ico" | "svg" | "svgz" | "xpm"
    )
}

const KRA_EXTRACT_SCRIPT: &str = r#"import sys, zipfile
try:
    with zipfile.ZipFile(sys.argv[1], 'r') as z:
        for c in ['preview.png', 'Thumbnails/thumbnail.png', 'mergedimage.png']:
            if c in z.namelist():
                with open(sys.argv[2], 'wb') as f:
                    f.write(z.read(c))
                break
except Exception:
    pass
"#;

const PIL_THUMB_SCRIPT: &str = r#"import sys
try:
    from PIL import Image
except Exception:
    sys.exit(1)
try:
    im = Image.open(sys.argv[1])
    try:
        im.seek(0)
    except Exception:
        pass
    im.thumbnail((256, 256))
    if im.mode not in ('RGB', 'RGBA'):
        im = im.convert('RGBA')
    im.save(sys.argv[2], 'PNG')
except Exception:
    sys.exit(1)
"#;

fn resolve_thumbnail_path(path: &Path) -> String {
    resolve_thumbnail_url(path, true)
}

fn resolve_thumbnail_url(path: &Path, allow_generation: bool) -> String {
    let Some(ext) = path.extension().and_then(|e| e.to_str()).map(|e| e.to_lowercase()) else {
        return String::new();
    };

    if !is_picture_format(&ext) {
        return String::new();
    }

    // Formats Qt handles itself: hand back the original file URL.
    if is_natively_renderable(&ext) {
        return file_url(path);
    }

    let cache_dir = get_thumbnail_cache_dir();
    let cached_thumb = cache_dir.join(format!("{}.png", compute_file_hash(path)));
    if cached_thumb.exists() {
        return file_url(&cached_thumb);
    }

    // Anything we cannot convert still gets the original URL so Qt's own image
    // loader gets a chance (an empty string would render a broken thumbnail).
    if !allow_generation {
        return file_url(path);
    }

    let src = path.to_string_lossy().to_string();
    let dst = cached_thumb.to_string_lossy().to_string();

    // Krita/OpenRaster are zip containers: pull the embedded preview out with python3.
    if ext == "kra" || ext == "ora" {
        if let Some(python) = resolve_binary("python3", "python3") {
            let ok = std::process::Command::new(&python)
                .args(["-c", KRA_EXTRACT_SCRIPT, &src, &dst])
                .status()
                .map(|s| s.success())
                .unwrap_or(false);
            if ok && cached_thumb.exists() {
                return file_url(&cached_thumb);
            }
        }
    }

    // Primary converter: ImageMagick (`magick`, or legacy `convert`).
    // NB: ImageMagick 7 requires the input before operators; `magick -thumbnail
    // 256x256 in.tiff out.png` fails with "no images found for operation".
    if let Some(magick) = resolve_any_binary(&["magick", "convert"], "imagemagick") {
        let ok = std::process::Command::new(&magick)
            .args([&format!("{}[0]", src), "-thumbnail", "256x256", &dst])
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
        if ok && cached_thumb.exists() {
            return file_url(&cached_thumb);
        }
    }

    // Fallback converter: python3 + Pillow.
    if let Some(python) = resolve_binary("python3", "python3") {
        let ok = std::process::Command::new(&python)
            .args(["-c", PIL_THUMB_SCRIPT, &src, &dst])
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
        if ok && cached_thumb.exists() {
            return file_url(&cached_thumb);
        }
    }

    // No converter worked (or is installed): let Qt try the original file.
    file_url(path)
}

fn icon_for_file(path: &Path, is_dir: bool) -> (&'static str, &'static str) {
    if is_dir {
        return ("folder", "folder");
    }

    let ext = path.extension().and_then(|ext| ext.to_str()).unwrap_or("").to_lowercase();
    if is_picture_format(&ext) {
        return ("file-image", "media");
    }

    match ext.as_str() {
        "mp3" | "flac" | "wav" | "ogg" | "m4a" | "aac" | "opus" => ("file-audio", "media"),
        "mp4" | "mkv" | "webm" | "mov" | "avi" | "flv" | "wmv" => ("file-video", "media"),
        "html" | "htm" => ("file-html", "code"),
        "css" | "scss" | "sass" | "less" => ("file-css", "code"),
        "rs" | "nix" | "js" | "ts" | "jsx" | "tsx" | "py" | "c" | "cpp" | "h" | "hpp" | "lua" | "go" | "java" | "kt" => ("file-code", "code"),
        "sh" | "bash" | "zsh" | "fish" => ("code", "code"),
        "zip" => ("file-zip", "archive"),
        "tar" | "gz" | "xz" | "zst" | "bz2" | "7z" | "rar" | "tgz" | "txz" | "tbz2" | "cab" | "arj" | "lha" | "lzh" | "cpio" | "iso" => ("file-archive", "archive"),
        "pdf" => ("file-pdf", "document"),
        "md" | "txt" | "json" | "toml" | "yaml" | "yml" | "csv" | "log" | "doc" | "docx" | "odt" => ("file-text", "text"),
        _ => ("file", "file"),
    }
}

fn system_icon_for_file(path: &Path, is_dir: bool) -> &'static str {
    if is_dir {
        return "folder";
    }

    let ext = path.extension().and_then(|ext| ext.to_str()).unwrap_or("").to_lowercase();
    if is_picture_format(&ext) {
        return "image-x-generic";
    }

    match ext.as_str() {
        "mp3" | "flac" | "wav" | "ogg" | "m4a" => "audio-x-generic",
        "mp4" | "mkv" | "webm" | "mov" | "avi" => "video-x-generic",
        "rs" | "nix" | "js" | "ts" | "jsx" | "tsx" | "py" | "c" | "cpp" | "h" | "lua" | "html" | "css" => "text-x-script",
        "zip" | "tar" | "gz" | "xz" | "zst" | "bz2" | "7z" => "package-x-generic",
        _ => "text-x-generic",
    }
}

// ============================================================
// "Open With" support
// ============================================================

/// One parsed `*.desktop` entry (only the `[Desktop Entry]` group is read).
#[derive(Clone)]
struct DesktopApp {
    /// Desktop file id (filename without `.desktop`).
    id: String,
    name: String,
    exec: String,
    /// Absolute path of the `.desktop` file.
    desktop_path: PathBuf,
}

#[derive(Serialize, Clone)]
pub struct AppEntry {
    pub id: String,
    pub name: String,
}

static APPS_CACHE: Mutex<Option<Vec<DesktopApp>>> = Mutex::new(None);

fn desktop_app_dirs() -> Vec<PathBuf> {
    let home = std::env::var("HOME").unwrap_or_default();
    let candidates = [
        PathBuf::from(&home).join(".local/share/applications"),
        PathBuf::from(&home).join(".local/share/flatpak/exports/share/applications"),
        PathBuf::from("/run/current-system/sw/share/applications"),
        PathBuf::from("/var/lib/flatpak/exports/share/applications"),
        PathBuf::from("/usr/local/share/applications"),
        PathBuf::from("/usr/share/applications"),
    ];
    candidates.into_iter().filter(|d| d.is_dir()).collect()
}

/// Current locale codes, most specific first (`de_DE`, then `de`).
fn locale_chain() -> Vec<String> {
    let raw = std::env::var("LC_ALL")
        .or_else(|_| std::env::var("LC_MESSAGES"))
        .or_else(|_| std::env::var("LANG"))
        .unwrap_or_default();
    let raw = raw.split(['.', '@']).next().unwrap_or("").replace('-', "_");
    let mut chain = Vec::new();
    if !raw.is_empty() {
        chain.push(raw.clone());
        if let Some((lang, _)) = raw.split_once('_') {
            chain.push(lang.to_string());
        }
    }
    chain
}

fn parse_desktop_file(path: &Path) -> Option<DesktopApp> {
    let content = fs::read_to_string(path).ok()?;
    let mut in_group = false;
    let mut is_app = false;
    let mut hidden = false;
    let mut name = String::new();
    let mut localized: Vec<(String, String)> = Vec::new();
    let mut exec = String::new();

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if line.starts_with('[') {
            in_group = line == "[Desktop Entry]";
            continue;
        }
        if !in_group {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else { continue };
        let key = key.trim();
        let value = value.trim().to_string();
        match key {
            "Type" => is_app = value.eq_ignore_ascii_case("Application"),
            "Hidden" | "NoDisplay" => hidden = value.eq_ignore_ascii_case("true"),
            "Exec" => exec = value,
            "Name" => name = value,
            _ => {
                if let Some(loc) = key.strip_prefix("Name[") {
                    if let Some(code) = loc.strip_suffix(']') {
                        localized.push((code.to_string(), value));
                    }
                }
            }
        }
    }

    if !is_app || hidden || exec.is_empty() {
        return None;
    }

    // Prefer a translated name matching the current locale, then any localized one.
    let mut display = String::new();
    for code in locale_chain() {
        if let Some((_, v)) = localized.iter().find(|(c, _)| c.eq_ignore_ascii_case(&code)) {
            display = v.clone();
            break;
        }
    }
    if display.is_empty() {
        display = localized.first().map(|(_, v)| v.clone()).unwrap_or_default();
    }
    if display.is_empty() {
        display = name;
    }
    if display.is_empty() {
        return None;
    }

    Some(DesktopApp {
        id: path.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default(),
        name: display,
        exec,
        desktop_path: path.to_path_buf(),
    })
        .map(|mut app| {
            if app.id.ends_with(".desktop") {
                app.id.truncate(app.id.len() - ".desktop".len());
            }
            app
        })
}

fn all_desktop_apps() -> Vec<DesktopApp> {
    let mut guard = APPS_CACHE.lock().unwrap();
    if let Some(cached) = guard.as_ref() {
        return cached.clone();
    }

    let mut apps: Vec<DesktopApp> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    for dir in desktop_app_dirs() {
        let Ok(entries) = fs::read_dir(&dir) else { continue };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("desktop") {
                continue;
            }
            let Some(app) = parse_desktop_file(&path) else { continue };
            // Desktop IDs are globally unique: the first directory in the search
            // order wins, which matches how the XDG lookup works.
            if !seen.insert(app.id.clone()) {
                continue;
            }
            apps.push(app);
        }
    }
    apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));

    *guard = Some(apps.clone());
    apps
}

/// MIME type of `path`, with a small extension table as fallback when
/// `xdg-mime` is unavailable.
fn mime_type_for_path(path: &Path) -> String {
    if path.is_dir() {
        return "inode/directory".to_string();
    }
    if let Some(mime) = run_cmd_stdout("xdg-mime", &["query", "filetype", &path.to_string_lossy()]) {
        if !mime.is_empty() && !mime.contains(' ') {
            return mime;
        }
    }

    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();
    match ext.as_str() {
        "txt" => "text/plain",
        "md" => "text/markdown",
        "pdf" => "application/pdf",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "svg" => "image/svg+xml",
        "mp3" => "audio/mpeg",
        "flac" => "audio/flac",
        "mp4" => "video/mp4",
        "mkv" => "video/x-matroska",
        "webm" => "video/webm",
        "zip" => "application/zip",
        "html" | "htm" => "text/html",
        "json" => "application/json",
        _ => "",
    }
    .to_string()
}

/// True when a `MimeType=` entry from a desktop file covers `mime` (with a
/// little tolerance for the usual alias spellings).
fn mime_covers(declared: &str, mime: &str) -> bool {
    let declared = declared.trim().to_lowercase();
    let mime = mime.trim().to_lowercase();
    if declared.is_empty() || mime.is_empty() {
        return false;
    }
    if declared == mime || declared == "*/*" {
        return true;
    }
    // Wildcard types such as "image/*" or "text/*".
    if let Some(prefix) = declared.strip_suffix("/*") {
        return mime.split('/').next() == Some(prefix);
    }
    // Common aliases seen in desktop files.
    let aliases: [(&str, &str); 6] = [
        ("image/jpg", "image/jpeg"),
        ("image/pjpeg", "image/jpeg"),
        ("application/x-zip-compressed", "application/zip"),
        ("application/x-7z-compressed", "application/x-7z"),
        ("text/xml", "application/xml"),
        ("text/markdown", "text/x-markdown"),
    ];
    aliases.iter().any(|(a, b)| {
        (declared == *a && mime == *b) || (declared == *b && mime == *a)
    })
}

/// How many recently used apps are remembered for the Open With menus.
const RECENT_APPS_LIMIT: usize = 8;
/// Settings key holding the recent app list.
const RECENT_APPS_KEY: &str = "recentOpenApps";
/// Field separator inside the stored list: a control character, so it can
/// never collide with a desktop id or a shell command.
const RECENT_APPS_SEP: &str = "\u{1}";

/// Appends `app_id` to the most-recently-used list stored in the settings,
/// de-duplicating and keeping the newest entry first.
///
/// Accepts either a desktop id (`firefox`) or a raw command line (recorded as
/// `cmd:<command>`), so custom commands are tracked too.
fn push_recent_app(app_id: &str) {
    if app_id.is_empty() {
        return;
    }

    let mut settings = load_settings();
    let existing = settings.get(RECENT_APPS_KEY).cloned().unwrap_or_default();
    let mut list: Vec<String> = existing
        .split(RECENT_APPS_SEP)
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();

    list.retain(|id| id != app_id);
    list.insert(0, app_id.to_string());
    list.truncate(RECENT_APPS_LIMIT);

    settings.insert(RECENT_APPS_KEY.to_string(), list.join(RECENT_APPS_SEP));
    store_settings(&settings);
}

/// The remembered apps, most recent first, resolved to `{id, name}` entries.
///
/// Desktop ids are matched against the installed entries, so an app that has
/// since been uninstalled drops out of the list. `cmd:` entries have no
/// desktop file to resolve against and are skipped.
fn recent_open_with_apps() -> Vec<AppEntry> {
    let settings = load_settings();
    let stored = settings.get(RECENT_APPS_KEY).cloned().unwrap_or_default();
    if stored.is_empty() {
        return Vec::new();
    }

    let installed = all_desktop_apps();
    let mut out: Vec<AppEntry> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();

    for id in stored
        .split(RECENT_APPS_SEP)
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
    {
        if !seen.insert(id.to_string()) {
            continue;
        }
        if id.starts_with("cmd:") {
            continue;
        }
        if let Some(app) = installed.iter().find(|a| a.id == id) {
            out.push(AppEntry {
                id: app.id.clone(),
                name: app.name.clone(),
            });
        }
    }
    out
}

/// Placeholders a user-typed command may use for the selected file.
const CUSTOM_COMMAND_PLACEHOLDERS: [&str; 4] = ["%f", "%F", "%u", "%U"];

/// True when the command uses shell syntax (pipes, redirection, subshells).
/// Such commands are run verbatim: appending the file would break them.
fn uses_shell_syntax(command: &str) -> bool {
    command.contains(['|', '&', ';', '>', '<', '`', '$', '(', ')', '{', '}', '*', '?', '\n'])
}

/// Substitutes `path` into a user-typed command and runs it through `sh -c`.
///
/// Accepts the same field codes desktop entries use. A plain command with no
/// field code gets the quoted path appended, so both `mpv` and `mpv %f` work.
fn substitute_command_path(command: &str, path: &Path) -> String {
    let quoted = format!("'{}'", path.to_string_lossy().replace('\'', r"'\''"));
    let mut out = command.to_string();
    let mut replaced = false;
    for placeholder in CUSTOM_COMMAND_PLACEHOLDERS {
        if out.contains(placeholder) {
            out = out.replace(placeholder, &quoted);
            replaced = true;
        }
    }
    if !replaced && !uses_shell_syntax(&out) {
        out.push(' ');
        out.push_str(&quoted);
    }
    out
}

/// Replaces the desktop `Exec` field codes (`%f`, `%U`, `%i`, ...) with `path`.
///
/// The file argument is substituted as a sentinel token rather than the raw
/// path, so a name containing spaces stays a single argument as the desktop
/// entry spec requires.
fn expand_exec(exec: &str, path: &Path) -> Vec<String> {
    const FIELD: &str = "\u{1}field\u{1}";
    const PCT: &str = "\u{2}pct\u{2}";
    let p = path.to_string_lossy().to_string();
    // Flatpak exports escape field codes as `@@u`/`@@` (it turns them back into
    // `%u` itself); unescape those so the file still gets passed through.
    let prepared = exec.replace("@@", PCT);
    let substituted: String = prepared
        .replace("%F", FIELD)
        .replace("%U", FIELD)
        .replace("%D", FIELD)
        .replace("%N", FIELD)
        .replace("%V", FIELD)
        .replace("%M", FIELD)
        .replace("%f", FIELD)
        .replace("%u", FIELD)
        .replace("%d", FIELD)
        .replace("%n", FIELD)
        .replace("%v", FIELD)
        .replace("%m", FIELD)
        .replace("%i", "--icon")
        .replace("%c", "")
        .replace("%k", "")
        .replace("%%", "%");

    // Shell-like tokenizer: honours single/double quotes and backslash escapes.
    let mut tokens: Vec<String> = Vec::new();
    let mut cur = String::new();
    let mut quote: Option<char> = None;
    let mut escaped = false;
    for ch in substituted.chars() {
        if escaped {
            cur.push(ch);
            escaped = false;
            continue;
        }
        match ch {
            '\\' if quote != Some('\'') => escaped = true,
            '"' | '\'' => match quote {
                Some(q) if q == ch => quote = None,
                None => quote = Some(ch),
                _ => cur.push(ch),
            },
            c if c.is_whitespace() && quote.is_none() => {
                if !cur.is_empty() {
                    tokens.push(std::mem::take(&mut cur));
                }
            }
            _ => cur.push(ch),
        }
    }
    if !cur.is_empty() {
        tokens.push(cur);
    }

    // Any argument carrying the field code is the file itself, quoted or not.
    tokens
        .into_iter()
        .filter_map(|token| {
            if token.contains(FIELD) {
                Some(p.clone())
            } else if token.is_empty() {
                None
            } else {
                Some(token.replace(PCT, "%"))
            }
        })
        .collect()
}

/// MIME types a desktop file declares support for (from its `MimeType=` key).
fn declared_mimes(desktop_path: &Path) -> Vec<String> {
    let Ok(content) = fs::read_to_string(desktop_path) else { return Vec::new() };
    let mut in_group = false;
    let mut mimes = Vec::new();
    for line in content.lines() {
        let line = line.trim();
        if line.starts_with('[') {
            in_group = line == "[Desktop Entry]";
            continue;
        }
        if !in_group {
            continue;
        }
        if let Some(value) = line.strip_prefix("MimeType=") {
            mimes.extend(value.split(';').map(|m| m.trim().to_string()).filter(|m| !m.is_empty()));
        }
    }
    mimes
}

/// Reads the current default for `mime` from `xdg-mime`, falling back to
/// `~/.config/mimeapps.list`. Returns the desktop file name (e.g.
/// `firefox.desktop`).
fn default_app_id(mime: &str) -> Option<String> {
    if let Some(id) = run_cmd_stdout("xdg-mime", &["query", "default", mime]) {
        if !id.is_empty() {
            return Some(id);
        }
    }
    let content = fs::read_to_string(mimeapps_list_path()).ok()?;
    let mut in_group = false;
    for line in content.lines() {
        let line = line.trim();
        if line.starts_with('[') {
            in_group = line == "[Default Applications]";
            continue;
        }
        if !in_group {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else { continue };
        if key.trim().eq_ignore_ascii_case(mime) {
            let id = value.trim();
            if !id.is_empty() {
                return Some(id.to_string());
            }
        }
    }
    None
}

/// Strips the `.desktop` suffix so a mimeapps.list value can be compared with
/// a parsed desktop file id.
fn desktop_id_of(desktop_file_name: &str) -> &str {
    desktop_file_name
        .strip_suffix(".desktop")
        .unwrap_or(desktop_file_name)
}

/// Records `app_id` as the default for `mime` in `~/.config/mimeapps.list`,
/// keeping the file's existing entries and comments intact.
fn set_default_app_id(mime: &str, app_id: &str) {
    let desktop_name = if app_id.ends_with(".desktop") {
        app_id.to_string()
    } else {
        format!("{}.desktop", app_id)
    };

    // Preferred: let xdg-mime update every relevant mimeapps.list itself.
    if ran_ok(std::process::Command::new("xdg-mime").arg("default").arg(&desktop_name).arg(mime).status()) {
        return;
    }

    let list_path = mimeapps_list_path();
    if let Some(parent) = list_path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let existing = fs::read_to_string(&list_path).unwrap_or_default();
    let mut lines: Vec<String> = existing.lines().map(|l| l.to_string()).collect();
    if lines.is_empty() {
        lines.push("[Default Applications]".to_string());
    }

    let mut in_group = false;
    let mut replaced = false;
    for line in lines.iter_mut() {
        let trimmed = line.trim();
        if trimmed.starts_with('[') {
            in_group = trimmed == "[Default Applications]";
            continue;
        }
        if !in_group || !trimmed.contains('=') {
            continue;
        }
        let key = trimmed.split_once('=').map(|(k, _)| k.trim()).unwrap_or("");
        if key.eq_ignore_ascii_case(mime) {
            if replaced {
                // Drop duplicate entries for the same MIME type.
                *line = String::new();
                continue;
            }
            *line = format!("{}={}", mime, desktop_name);
            replaced = true;
        }
    }
    if !replaced {
        // Append to the end of the [Default Applications] group, creating the
        // group at the file end when it is missing.
        let insert_at = lines
            .iter()
            .position(|l| l.trim() == "[Default Applications]")
            .map(|i| {
                let next_group = lines[i + 1..]
                    .iter()
                    .position(|l| l.trim().starts_with('['))
                    .map(|off| i + 1 + off)
                    .unwrap_or(lines.len());
                next_group
            });
        let entry = format!("{}={}", mime, desktop_name);
        match insert_at {
            Some(idx) => lines.insert(idx, entry),
            None => {
                lines.push(String::new());
                lines.push("[Default Applications]".to_string());
                lines.push(entry);
            }
        }
    }

    let _ = fs::write(&list_path, lines.join("\n"));
}

// ============================================================
// Quick Look (inline preview) support
// ============================================================

/// Upper bound on how much of a text file is handed to the preview pane.
const QUICKLOOK_MAX_BYTES: usize = 256 * 1024;

#[derive(Serialize)]
pub struct QuickLook {
    pub name: String,
    pub path: String,
    /// image | text | markdown | media | folder | none
    pub kind: String,
    /// Highlighting hint for the QML side (empty for plain text).
    pub language: String,
    pub text: String,
    pub truncated: bool,
    pub image_url: String,
    pub size_str: String,
    pub modified_str: String,
    /// Short line shown when there is nothing to preview.
    pub note: String,
}

/// Maps a file extension to a highlighting language (see the QML highlighter).
fn preview_language(ext: &str) -> &'static str {
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

fn is_media_ext(ext: &str) -> bool {
    matches!(
        ext,
        "mp4" | "mkv" | "webm" | "mov" | "avi" | "flv" | "wmv" | "m4v" | "mpg" | "mpeg"
            | "mp3" | "flac" | "wav" | "ogg" | "oga" | "m4a" | "aac" | "opus" | "wma"
    )
}

/// Reads at most `QUICKLOOK_MAX_BYTES` and reports whether the head of the file
/// looks binary (a NUL byte in the first 8 KiB is the usual heuristic).
fn read_preview_text(path: &Path) -> (String, bool, bool) {
    let Ok(bytes) = fs::read(path) else {
        return (String::new(), false, false);
    };
    let truncated = bytes.len() > QUICKLOOK_MAX_BYTES;
    let slice = if truncated { &bytes[..QUICKLOOK_MAX_BYTES] } else { &bytes[..] };
    let binary = slice.iter().take(8192).any(|b| *b == 0);
    if binary {
        return (String::new(), truncated, true);
    }
    (String::from_utf8_lossy(slice).to_string(), truncated, false)
}

fn count_dir_entries(path: &Path) -> usize {
    fs::read_dir(path)
        .map(|entries| entries.flatten().count())
        .unwrap_or(0)
}

/// Builds everything the preview pane needs for `path`.
fn quick_look_data(path: &Path) -> QuickLook {
    let name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .to_string();
    let meta = fs::metadata(path).ok();
    let size_str = meta
        .as_ref()
        .filter(|_| !path.is_dir())
        .map(|m| format_size(m.len()))
        .unwrap_or_else(|| "-".to_string());
    let modified_str = meta
        .as_ref()
        .map(|m| format_modified_time(m).1)
        .unwrap_or_else(|| "-".to_string());

    let mut out = QuickLook {
        name,
        path: path.to_string_lossy().to_string(),
        kind: "none".to_string(),
        language: String::new(),
        text: String::new(),
        truncated: false,
        image_url: String::new(),
        size_str,
        modified_str,
        note: "No preview available".to_string(),
    };

    if path.is_dir() {
        let entries = count_dir_entries(path);
        out.kind = "folder".into();
        out.note = format!(
            "Folder · {} item{}",
            entries,
            if entries == 1 { "" } else { "s" }
        );
        return out;
    }

    if meta.is_none() {
        out.kind = "none".into();
        out.note = "This item no longer exists".to_string();
        return out;
    }

    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    // Images: reuse the thumbnail pipeline (natively renderable files are shown
    // full-size, the rest through the generated cache entry).
    if is_picture_format(&ext) {
        out.kind = "image".into();
        out.image_url = resolve_thumbnail_url(path, false);
        out.note = String::new();
        return out;
    }

    if is_media_ext(&ext) {
        out.kind = "media".into();
        out.note = "Media file · press Enter to open it in your default player".to_string();
        return out;
    }

    if ext == "pdf" || ext == "epub" || ext == "mobi" {
        out.kind = "none".into();
        out.note = "No inline preview · press Enter to open it".to_string();
        return out;
    }

    let language = preview_language(&ext);
    if language != "text" {
        let (text, truncated, binary) = read_preview_text(path);
        if binary {
            out.note = "Binary file · no text preview".to_string();
            return out;
        }
        out.kind = "text".into();
        out.language = language.to_string();
        out.text = text;
        out.truncated = truncated;
        out.note = String::new();
        return out;
    }

    // Plain text (or an extension-less file such as a config or a script).
    let (text, truncated, binary) = read_preview_text(path);
    if binary {
        out.kind = "none".into();
        out.note = "Binary file · no text preview".to_string();
        return out;
    }
    out.kind = "text".into();
    out.language = "text".to_string();
    out.text = text;
    out.truncated = truncated;
    out.note = String::new();
    out
}

fn mimeapps_list_path() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg).join("mimeapps.list");
        }
    }
    let home = std::env::var("HOME").unwrap_or_default();
    PathBuf::from(home).join(".config/mimeapps.list")
}

fn record_dir_visit(path: &str) {
    let mut guard = VISIT_COUNTS.lock().unwrap();
    let map = guard.get_or_insert_with(HashMap::new);
    *map.entry(path.to_string()).or_insert(0) += 1;
}

fn get_frequent_dirs() -> Vec<FrequentDirItem> {
    let home = std::env::var("HOME").unwrap_or_default();
    // Seed defaults so the row is never empty on first run.
    let defaults = [
        ("loaf", format!("{}/Projects/loaf", home), "code"),
        ("Projects", format!("{}/Projects", home), "code"),
        ("Wallpapers", format!("{}/Pictures/Wallpapers", home), "image"),
        ("Downloads", format!("{}/Downloads", home), "download"),
        (".config", format!("{}/.config", home), "gear"),
        ("Documents", format!("{}/Documents", home), "file-text"),
    ];

    let counts = VISIT_COUNTS.lock().unwrap();
    let counts_ref = counts.as_ref();

    let mut res: Vec<(u32, FrequentDirItem)> = Vec::new();

    // Real visited dirs (ranked by visit count), skipping HOME itself.
    if let Some(map) = counts_ref {
        let mut entries: Vec<(&String, &usize)> = map.iter().collect();
        entries.sort_by(|a, b| b.1.cmp(a.1));
        for (path, count) in entries {
            if *path == home {
                continue;
            }
            let p = Path::new(path);
            if !p.is_dir() {
                continue;
            }
            let name = p
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or(path.as_str())
                .to_string();
            let (_, icon) = icon_for_file(p, true);
            res.push((
                *count as u32,
                FrequentDirItem {
                    name,
                    path: path.clone(),
                    icon: icon.to_string(),
                },
            ));
        }
    }

    // Merge in defaults (with their seed counts) if not already present.
    for (name, path, icon) in &defaults {
        if res.iter().any(|(_, it)| it.path == *path) && Path::new(path).is_dir() {
            continue;
        }
        if Path::new(path).is_dir() {
            let seed = match *name {
                "loaf" => 5,
                "Projects" => 4,
                "Downloads" => 3,
                "Wallpapers" => 2,
                "Documents" => 1,
                _ => 0,
            };
            res.push((
                seed,
                FrequentDirItem {
                    name: name.to_string(),
                    path: path.clone(),
                    icon: icon.to_string(),
                },
            ));
        }
    }

    res.sort_by(|a, b| b.0.cmp(&a.0));
    res.into_iter().map(|(_, it)| it).take(6).collect()
}

fn is_external_device(block_name: &str, rm: bool, hotplug: bool, tran: &str) -> bool {
    // Removable/hotpluggable is authoritative.
    if rm || hotplug {
        return true;
    }

    // Removable buses.
    match tran.to_lowercase().as_str() {
        "usb" | "mmc" | "sdio" | "firewire" | "1394" | "memstick" => return true,
        _ => {}
    }

    // Fall back to sysfs for devices lsblk reports no transport for.
    let base = block_name.trim_start_matches("/dev/").trim();
    if base.is_empty() {
        return false;
    }

    // Partition names ("sdb1", "mmcblk0p2", "nvme0n1p3") resolve to the parent disk.
    let stripped_digits = base.trim_end_matches(|c: char| c.is_ascii_digit());
    let stripped_p = stripped_digits.strip_suffix('p');
    let parent = match stripped_p {
        Some(s) if s.chars().last().map(|c| c.is_ascii_digit()).unwrap_or(false) => s,
        _ => stripped_digits,
    };

    let mut candidates = vec![base.to_string()];
    if parent != base && !parent.is_empty() {
        candidates.push(parent.to_string());
    }

    for candidate in candidates {
        let sys_block = Path::new("/sys/block").join(&candidate);
        if let Ok(removable) = fs::read_to_string(sys_block.join("removable")) {
            if removable.trim() == "1" {
                return true;
            }
        }
        let real = fs::canonicalize(&sys_block)
            .or_else(|_| fs::canonicalize(Path::new("/sys/class/block").join(&candidate)));
        if let Ok(real) = real {
            let s = real.to_string_lossy().to_lowercase();
            if s.contains("/usb") {
                return true;
            }
        }
    }
    false
}

fn read_system_drives() -> Vec<DriveItem> {
    let mut drives = Vec::new();
    let mut seen_devices = std::collections::HashSet::new();

    if let Ok(output) = std::process::Command::new("lsblk")
        .args(["-b", "--json", "-o", "NAME,LABEL,MOUNTPOINT,FSTYPE,SIZE,RM,HOTPLUG,TRAN,MODEL,UUID"])
        .output()
    {
        if let Ok(val) = serde_json::from_slice::<serde_json::Value>(&output.stdout) {
            if let Some(blocks) = val.get("blockdevices").and_then(|b| b.as_array()) {
                fn process_device(
                    dev: &serde_json::Value,
                    parent_model: &str,
                    parent_tran: &str,
                    parent_rm: bool,
                    parent_name: &str,
                    drives: &mut Vec<DriveItem>,
                    seen: &mut std::collections::HashSet<String>,
                ) {
                    let name = dev.get("name").and_then(|n| n.as_str()).unwrap_or("");
                    let model = dev.get("model").and_then(|m| m.as_str()).unwrap_or(parent_model);
                    let tran = dev.get("tran").and_then(|t| t.as_str()).unwrap_or(parent_tran);
                    let rm = dev.get("rm").and_then(|r| r.as_bool()).unwrap_or(parent_rm);
                    let hotplug = dev.get("hotplug").and_then(|h| h.as_bool()).unwrap_or(false);
                    let fstype = dev.get("fstype").and_then(|f| f.as_str()).unwrap_or("");
                    let mountpoint = dev.get("mountpoint").and_then(|m| m.as_str()).unwrap_or("");
                    let label = dev.get("label").and_then(|l| l.as_str()).unwrap_or("");
                    let size = dev.get("size").and_then(|s| s.as_u64()).unwrap_or(0);
                    // Partitions inherit the physical disk name so sysfs lookups work.
                    let block_name = if parent_name.is_empty() { name } else { parent_name };

                    if let Some(children) = dev.get("children").and_then(|c| c.as_array()) {
                        for child in children {
                            process_device(child, model, tran, rm, block_name, drives, seen);
                        }
                    } else if !name.is_empty() && !fstype.is_empty() && fstype != "swap" && mountpoint != "[SWAP]" {
                        let device_path = format!("/dev/{}", name);
                        if seen.contains(&device_path) {
                            return;
                        }
                        seen.insert(device_path.clone());

                        let is_mounted = !mountpoint.is_empty();
                        let is_external = is_external_device(block_name, rm, hotplug, tran);

                        let display_name = if !label.is_empty() {
                            label.to_string()
                        } else if mountpoint == "/" {
                            "Root (/)".to_string()
                        } else if is_mounted {
                            Path::new(mountpoint)
                                .file_name()
                                .and_then(|n| n.to_str())
                                .unwrap_or(name)
                                .to_string()
                        } else {
                            name.to_string()
                        };

                        let (total_bytes, free_bytes, used_bytes, percent) = if is_mounted {
                            let c_mount = std::ffi::CString::new(mountpoint).unwrap_or_default();
                            let mut st: libc::statvfs = unsafe { std::mem::zeroed() };
                            if unsafe { libc::statvfs(c_mount.as_ptr(), &mut st) } == 0 {
                                let total = st.f_blocks as u64 * st.f_frsize as u64;
                                let free = st.f_bavail as u64 * st.f_frsize as u64;
                                let used = total.saturating_sub(free);
                                let p = if total > 0 { ((used as f64 / total as f64) * 100.0).round() } else { 0.0 };
                                (total, free, used, (p * 10.0).round() / 10.0)
                            } else {
                                (size, size, 0, 0.0)
                            }
                        } else {
                            (size, size, 0, 0.0)
                        };

                        drives.push(DriveItem {
                            name: display_name,
                            device: device_path,
                            mount_point: mountpoint.to_string(),
                            is_mounted,
                            is_external,
                            fs_type: fstype.to_string(),
                            total_str: format_size(total_bytes),
                            used_str: format_size(used_bytes),
                            free_str: format_size(free_bytes),
                            total_bytes,
                            used_bytes,
                            free_bytes,
                            percent,
                            model: model.to_string(),
                        });
                    }
                }

                for b in blocks {
                    process_device(b, "", "", false, "", &mut drives, &mut seen_devices);
                }
            }
        }
    }

    if drives.is_empty() {
        let mounts_content = fs::read_to_string("/proc/mounts").unwrap_or_default();
        for line in mounts_content.lines() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() < 3 {
                continue;
            }

            let dev = parts[0];
            let mount = parts[1];
            let fstype = parts[2];

            if (!dev.starts_with("/dev/") && !mount.starts_with("/run/media/"))
                || mount.starts_with("/boot")
                || mount == "/nix/store"
            {
                continue;
            }

            let c_mount = std::ffi::CString::new(mount).unwrap_or_default();
            let mut st: libc::statvfs = unsafe { std::mem::zeroed() };

            if unsafe { libc::statvfs(c_mount.as_ptr(), &mut st) } == 0 {
                let total = st.f_blocks as u64 * st.f_frsize as u64;
                let free = st.f_bavail as u64 * st.f_frsize as u64;
                let used = total.saturating_sub(free);
                let percent = if total > 0 {
                    ((used as f64 / total as f64) * 100.0).round()
                } else {
                    0.0
                };

                let name = if mount == "/" {
                    "Root (/)".to_string()
                } else {
                    Path::new(mount)
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or(mount)
                        .to_string()
                };

                drives.push(DriveItem {
                    name,
                    device: dev.to_string(),
                    mount_point: mount.to_string(),
                    is_mounted: true,
                    is_external: is_external_device(dev, false, false, ""),
                    fs_type: fstype.to_string(),
                    total_str: format_size(total),
                    used_str: format_size(used),
                    free_str: format_size(free),
                    total_bytes: total,
                    used_bytes: used,
                    free_bytes: free,
                    percent: (percent * 10.0).round() / 10.0,
                    model: String::new(),
                });
            }
        }
    }

    drives
}

fn scan_trash_files() -> Vec<FileItem> {
    let (files_dir, _) = trash_paths();
    scan_directory(&files_dir, true, "name", true, "first")
}

fn build_breadcrumbs(target_path: &Path, forward_target: Option<&str>) -> Vec<Breadcrumb> {
    let home = std::env::var("HOME").unwrap_or_default();
    let home_path = Path::new(&home);

    let mut crumbs = Vec::new();

    let known_places = [
        ("Projects", "code", "utilities-terminal-symbolic"),
        ("Downloads", "download", "folder-download-symbolic"),
        ("Documents", "file-text", "x-office-document-symbolic"),
        ("Pictures", "image", "image-x-generic-symbolic"),
        ("Music", "music", "audio-x-generic-symbolic"),
        ("Videos", "video", "video-x-generic-symbolic"),
    ];

    let mut base_matched: Option<(PathBuf, String, &'static str, &'static str)> = None;

    for (dir_name, icon, sys_icon) in &known_places {
        let p = home_path.join(dir_name);
        if target_path.starts_with(&p) {
            base_matched = Some((p, dir_name.to_string(), icon, sys_icon));
            break;
        }
    }

    if let Some((base_path, place_name, icon, sys_icon)) = base_matched {
        crumbs.push(Breadcrumb {
            name: place_name,
            path: base_path.to_string_lossy().to_string(),
            icon: icon.to_string(),
            system_icon: sys_icon.to_string(),
            is_root_place: true,
            is_forward: false,
        });

        if let Ok(rel) = target_path.strip_prefix(&base_path) {
            let mut cur = base_path;
            for comp in rel.components() {
                if let std::path::Component::Normal(c) = comp {
                    let s = c.to_string_lossy().to_string();
                    cur.push(&s);
                    crumbs.push(Breadcrumb {
                        name: s,
                        path: cur.to_string_lossy().to_string(),
                        icon: "folder".to_string(),
                        system_icon: "folder".to_string(),
                        is_root_place: false,
                        is_forward: false,
                    });
                }
            }
        }
    } else if target_path.starts_with(home_path) {
        crumbs.push(Breadcrumb {
            name: "Home".to_string(),
            path: home_path.to_string_lossy().to_string(),
            icon: "house".to_string(),
            system_icon: "user-home-symbolic".to_string(),
            is_root_place: true,
            is_forward: false,
        });

        if let Ok(rel) = target_path.strip_prefix(home_path) {
            let mut cur = home_path.to_path_buf();
            for comp in rel.components() {
                if let std::path::Component::Normal(c) = comp {
                    let s = c.to_string_lossy().to_string();
                    cur.push(&s);
                    crumbs.push(Breadcrumb {
                        name: s,
                        path: cur.to_string_lossy().to_string(),
                        icon: "folder".to_string(),
                        system_icon: "folder".to_string(),
                        is_root_place: false,
                        is_forward: false,
                    });
                }
            }
        }
    } else {
        let mut cur = PathBuf::new();
        for comp in target_path.components() {
            match comp {
                std::path::Component::RootDir => {
                    cur.push("/");
                    crumbs.push(Breadcrumb {
                        name: "root".to_string(),
                        path: "/".to_string(),
                        icon: "hard-drive".to_string(),
                        system_icon: "drive-harddisk-symbolic".to_string(),
                        is_root_place: true,
                        is_forward: false,
                    });
                }
                std::path::Component::Normal(c) => {
                    let s = c.to_string_lossy().to_string();
                    cur.push(&s);
                    crumbs.push(Breadcrumb {
                        name: s,
                        path: cur.to_string_lossy().to_string(),
                        icon: "folder".to_string(),
                        system_icon: "folder".to_string(),
                        is_root_place: false,
                        is_forward: false,
                    });
                }
                _ => {}
            }
        }
    }

    if let Some(fwd_str) = forward_target {
        let fwd_p = Path::new(fwd_str);
        if fwd_p != target_path && fwd_p.starts_with(target_path) {
            if let Ok(rel) = fwd_p.strip_prefix(target_path) {
                let mut cur = target_path.to_path_buf();
                for comp in rel.components() {
                    if let std::path::Component::Normal(c) = comp {
                        let fwd_name = c.to_string_lossy().to_string();
                        cur.push(&fwd_name);
                        crumbs.push(Breadcrumb {
                            name: fwd_name,
                            path: cur.to_string_lossy().to_string(),
                            icon: "folder".to_string(),
                            system_icon: "folder".to_string(),
                            is_root_place: false,
                            is_forward: true,
                        });
                    }
                }
            }
        }
    }

    crumbs
}

fn scan_directory(
    dir_path: &Path,
    show_hidden: bool,
    sort_by: &str,
    sort_ascending: bool,
    folder_position: &str,
) -> Vec<FileItem> {
    let mut items = Vec::new();

    if let Ok(entries) = fs::read_dir(dir_path) {
        for entry in entries.flatten() {
            let path = entry.path();
            let name = match entry.file_name().into_string() {
                Ok(n) => n,
                Err(_) => continue,
            };

            if !show_hidden && name.starts_with('.') {
                continue;
            }

            let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);
            let is_symlink = path.is_symlink();
            let (icon, category) = icon_for_file(&path, is_dir);
            let sys_icon_name = system_icon_for_file(&path, is_dir);
            let icon_path = resolve_system_icon(sys_icon_name);
            let thumbnail = if is_dir {
                String::new()
            } else {
                resolve_thumbnail_url(&path, false)
            };

            let (size, size_str, modified, modified_str) = if let Ok(meta) = entry.metadata() {
                let sz = if is_dir { 0 } else { meta.len() };
                let sz_str = if is_dir {
                    "-".to_string()
                } else {
                    format_size(sz)
                };
                let (ts, m_str) = format_modified_time(&meta);
                (sz, sz_str, ts, m_str)
            } else {
                (0, "-".to_string(), 0, "-".to_string())
            };

            items.push(FileItem {
                name,
                is_dir,
                is_symlink,
                icon: icon.to_string(),
                icon_path,
                thumbnail,
                category: category.to_string(),
                size,
                size_str,
                modified,
                modified_str,
            });
        }
    }

    items.sort_by(|a, b| {
        match folder_position {
            "last" => {
                if a.is_dir != b.is_dir {
                    return a.is_dir.cmp(&b.is_dir);
                }
            }
            "mixed" => {}
            _ => {
                // "first" is default
                if a.is_dir != b.is_dir {
                    return b.is_dir.cmp(&a.is_dir);
                }
            }
        }
        let ord = match sort_by {
            "size" => a.size.cmp(&b.size).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
            "modified" => a.modified.cmp(&b.modified).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
            "type" => a.category.cmp(&b.category).then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
            _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
        };
        if sort_ascending {
            ord
        } else {
            ord.reverse()
        }
    });

    items
}

fn execute_search_everywhere(query_str: &str, show_hidden: bool, disambiguate_duplicates: bool) -> Vec<SearchResultItem> {
    let q = query_str.to_lowercase();
    let home = std::env::var("HOME").unwrap_or_default();
    let mut results: Vec<(i32, SearchResultItem)> = Vec::new();

    let mut stack = vec![(PathBuf::from(&home), 0)];
    let skip_dirs = [
        ".git", "node_modules", "target", ".cache", ".local/share/Trash",
        ".direnv", "venv", ".npm", ".cargo", ".rustup"
    ];

    while let Some((dir, depth)) = stack.pop() {
        if depth > 5 || results.len() > 300 {
            continue;
        }

        if let Ok(entries) = fs::read_dir(&dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                let file_name = match entry.file_name().into_string() {
                    Ok(n) => n,
                    Err(_) => continue,
                };

                let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);

                if is_dir {
                    if skip_dirs.iter().any(|s| file_name == *s) {
                        continue;
                    }
                    if !show_hidden && file_name.starts_with('.') {
                        continue;
                    }
                    stack.push((path.clone(), depth + 1));
                } else if !show_hidden && file_name.starts_with('.') {
                    continue;
                }

                let name_lower = file_name.to_lowercase();
                let score = if name_lower == q {
                    120
                } else if name_lower.starts_with(&q) {
                    100
                } else if name_lower.contains(&q) {
                    60
                } else {
                    continue;
                };

                let parent_path = path.parent().map(|p| p.to_string_lossy().to_string()).unwrap_or_default();
                let (icon, category) = icon_for_file(&path, is_dir);
                let sys_icon = system_icon_for_file(&path, is_dir);
                let icon_path = resolve_system_icon(sys_icon);
                let thumbnail = if is_dir {
                    String::new()
                } else {
                    // Recursive search can hit hundreds of images: reuse the cache
                    // instead of spawning an image converter for each hit.
                    resolve_thumbnail_url(&path, false)
                };

                results.push((
                    score,
                    SearchResultItem {
                        name: file_name.clone(),
                        display_name: file_name,
                        path: path.to_string_lossy().to_string(),
                        parent_path,
                        is_dir,
                        icon: icon.to_string(),
                        icon_path,
                        thumbnail,
                        category: category.to_string(),
                    },
                ));
            }
        }
    }

    results.sort_by(|(s1, i1), (s2, i2)| {
        s2.cmp(s1).then_with(|| i2.is_dir.cmp(&i1.is_dir))
    });

    let mut items: Vec<SearchResultItem> = results.into_iter().take(150).map(|(_, it)| it).collect();

    if disambiguate_duplicates {
        let mut name_counts: HashMap<String, usize> = HashMap::new();
        for it in &items {
            *name_counts.entry(it.name.clone()).or_insert(0) += 1;
        }

        for it in &mut items {
            if let Some(&count) = name_counts.get(&it.name) {
                if count > 1 {
                    let p = Path::new(&it.path);
                    if let Some(parent) = p.parent() {
                        let parent_name = parent.file_name().and_then(|n| n.to_str()).unwrap_or("..");
                        it.display_name = format!("{}/{}", parent_name, it.name);
                    }
                }
            }
        }
    }

    items
}

impl Default for LoafEngineRust {
    fn default() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/home".to_string());
        let home_path = Path::new(&home);
        let dir_name = home_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("Home")
            .to_string();

        let items = scan_directory(home_path, false, "name", true, "first");
        let files_json = serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string());

        let crumbs = build_breadcrumbs(home_path, None);
        let crumbs_json = serde_json::to_string(&crumbs).unwrap_or_else(|_| "[]".to_string());

        let wp_colors = read_wallpaper_colors();
        let drives = read_system_drives();
        let drives_json = serde_json::to_string(&drives).unwrap_or_else(|_| "[]".to_string());

        let trash = scan_trash_files();
        let trash_json = serde_json::to_string(&trash).unwrap_or_else(|_| "[]".to_string());

        let freq = get_frequent_dirs();
        let frequent_dirs_json = serde_json::to_string(&freq).unwrap_or_else(|_| "[]".to_string());

        Self {
            current_path: QString::from(&home),
            current_dir_name: QString::from(&dir_name),
            files_json: QString::from(&files_json),
            breadcrumbs_json: QString::from(&crumbs_json),
            is_dark: detect_system_dark_mode(),
            has_clipboard: false,
            show_hidden: false,
            disambiguate_duplicates: true,
            wallpaper_colors_json: QString::from(&wp_colors),
            is_searching_everywhere: false,
            search_everywhere_json: QString::from("[]"),
            can_go_back: false,
            can_go_forward: false,
            hostname: QString::from(&read_system_hostname()),
            drives_json: QString::from(&drives_json),
            trash_json: QString::from(&trash_json),
            frequent_dirs_json: QString::from(&frequent_dirs_json),
            sort_by: QString::from("name"),
            sort_ascending: true,
            dirs_first: true,
            folder_position: QString::from("first"),
            view_mode: QString::from("grid"),
            clipboard_cut_paths_json: QString::from("[]"),
            device_type: QString::from(detect_device_type()),
            can_undo: false,
            can_redo: false,
            trash_root: QString::from(&trash_paths().0.to_string_lossy().to_string()),
            history_stack: Vec::new(),
            forward_stack: Vec::new(),
        }
    }
}

impl qobject::LoafEngine {
    /// Keeps can_undo / can_redo in sync with the stacks.
    fn sync_undo_flags(mut self: Pin<&mut Self>) {
        let undo = stack_len(&UNDO_STACK) > 0;
        let redo = stack_len(&REDO_STACK) > 0;
        if *self.as_ref().can_undo() != undo {
            self.as_mut().set_can_undo(undo);
        }
        if *self.as_ref().can_redo() != redo {
            self.as_mut().set_can_redo(redo);
        }
    }

    /// Records an undo entry and refreshes the can_undo/can_redo properties.
    fn record_undo(mut self: Pin<&mut Self>, action: UndoAction) {
        push_undo(action);
        self.as_mut().sync_undo_flags();
    }

    /// Drops clipboard paths that no longer exist and republishes the state.
    fn refresh_clipboard_state(mut self: Pin<&mut Self>) {
        let (has, json) = {
            let mut clip = CLIPBOARD.lock().unwrap();
            clip.0.retain(|p| Path::new(p).exists());
            let has = !clip.0.is_empty();
            if !has {
                clip.1 = false;
            }
            let json = if clip.1 && has {
                serde_json::to_string(&clip.0).unwrap_or_else(|_| "[]".to_string())
            } else {
                "[]".to_string()
            };
            (has, json)
        };
        self.as_mut().set_has_clipboard(has);
        self.as_mut().set_clipboard_cut_paths_json(QString::from(&json));
    }

    pub fn set_path(mut self: Pin<&mut Self>, path: &QString) {
        let p = path.to_string();
        let path_buf = PathBuf::from(&p);

        if !path_buf.is_dir() {
            return;
        }

        record_dir_visit(&p);

        let old_path = self.as_ref().current_path().to_string();

        if old_path != p {
            self.as_mut().rust_mut().history_stack.push(old_path.clone());
            self.as_mut().rust_mut().forward_stack.clear();
        }

        let fwd_target = self.as_ref().forward_stack.last().cloned();

        let name = path_buf
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or(&p)
            .to_string();

        let show_hidden = *self.as_ref().show_hidden();
        let sort_by = self.as_ref().sort_by().to_string();
        let sort_ascending = *self.as_ref().sort_ascending();
        let folder_pos = self.as_ref().folder_position().to_string();
        let items = scan_directory(&path_buf, show_hidden, &sort_by, sort_ascending, &folder_pos);
        let files_json = serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string());

        let crumbs = build_breadcrumbs(&path_buf, fwd_target.as_deref());
        let crumbs_json = serde_json::to_string(&crumbs).unwrap_or_else(|_| "[]".to_string());

        let can_back = !self.as_ref().history_stack.is_empty();
        let can_fwd = !self.as_ref().forward_stack.is_empty();

        self.as_mut().set_can_go_back(can_back);
        self.as_mut().set_can_go_forward(can_fwd);
        self.as_mut().set_is_searching_everywhere(false);
        self.as_mut().set_current_path(path.clone());
        self.as_mut().set_current_dir_name(QString::from(&name));
        self.as_mut().set_files_json(QString::from(&files_json));
        self.as_mut().set_breadcrumbs_json(QString::from(&crumbs_json));

        let freq = get_frequent_dirs();
        let freq_json = serde_json::to_string(&freq).unwrap_or_else(|_| "[]".to_string());
        self.as_mut().set_frequent_dirs_json(QString::from(&freq_json));
    }

    pub fn navigate_up(self: Pin<&mut Self>) {
        let cur = self.as_ref().current_path().to_string();
        let path = Path::new(&cur);
        if let Some(parent) = path.parent() {
            let parent_str = parent.to_string_lossy().to_string();
            self.set_path(&QString::from(&parent_str));
        }
    }

    pub fn go_back(mut self: Pin<&mut Self>) {
        if let Some(prev) = self.as_mut().rust_mut().history_stack.pop() {
            let cur = self.as_ref().current_path().to_string();
            self.as_mut().rust_mut().forward_stack.push(cur);

            let path_buf = PathBuf::from(&prev);
            let name = path_buf.file_name().and_then(|n| n.to_str()).unwrap_or(&prev).to_string();
            let show_hidden = *self.as_ref().show_hidden();
            let sort_by = self.as_ref().sort_by().to_string();
            let sort_ascending = *self.as_ref().sort_ascending();
            let folder_pos = self.as_ref().folder_position().to_string();
            let items = scan_directory(&path_buf, show_hidden, &sort_by, sort_ascending, &folder_pos);
            let files_json = serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string());

            let fwd_target = self.as_ref().forward_stack.last().cloned();
            let crumbs = build_breadcrumbs(&path_buf, fwd_target.as_deref());
            let crumbs_json = serde_json::to_string(&crumbs).unwrap_or_else(|_| "[]".to_string());

            let can_back = !self.as_ref().history_stack.is_empty();
            let can_fwd = !self.as_ref().forward_stack.is_empty();

            self.as_mut().set_can_go_back(can_back);
            self.as_mut().set_can_go_forward(can_fwd);
            self.as_mut().set_is_searching_everywhere(false);
            self.as_mut().set_current_path(QString::from(&prev));
            self.as_mut().set_current_dir_name(QString::from(&name));
            self.as_mut().set_files_json(QString::from(&files_json));
            self.as_mut().set_breadcrumbs_json(QString::from(&crumbs_json));
        }
    }

    pub fn go_forward(mut self: Pin<&mut Self>) {
        if let Some(next) = self.as_mut().rust_mut().forward_stack.pop() {
            let cur = self.as_ref().current_path().to_string();
            self.as_mut().rust_mut().history_stack.push(cur);

            let path_buf = PathBuf::from(&next);
            let name = path_buf.file_name().and_then(|n| n.to_str()).unwrap_or(&next).to_string();
            let show_hidden = *self.as_ref().show_hidden();
            let sort_by = self.as_ref().sort_by().to_string();
            let sort_ascending = *self.as_ref().sort_ascending();
            let folder_pos = self.as_ref().folder_position().to_string();
            let items = scan_directory(&path_buf, show_hidden, &sort_by, sort_ascending, &folder_pos);
            let files_json = serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string());

            let fwd_target = self.as_ref().forward_stack.last().cloned();
            let crumbs = build_breadcrumbs(&path_buf, fwd_target.as_deref());
            let crumbs_json = serde_json::to_string(&crumbs).unwrap_or_else(|_| "[]".to_string());

            let can_back = !self.as_ref().history_stack.is_empty();
            let can_fwd = !self.as_ref().forward_stack.is_empty();

            self.as_mut().set_can_go_back(can_back);
            self.as_mut().set_can_go_forward(can_fwd);
            self.as_mut().set_is_searching_everywhere(false);
            self.as_mut().set_current_path(QString::from(&next));
            self.as_mut().set_current_dir_name(QString::from(&name));
            self.as_mut().set_files_json(QString::from(&files_json));
            self.as_mut().set_breadcrumbs_json(QString::from(&crumbs_json));
        }
    }

    pub fn refresh(self: Pin<&mut Self>) {
        let cur = self.as_ref().current_path().clone();
        self.set_path(&cur);
    }

    pub fn toggle_show_hidden(mut self: Pin<&mut Self>) {
        let cur_val = *self.as_ref().show_hidden();
        self.as_mut().set_show_hidden(!cur_val);
        self.refresh();
    }

    pub fn toggle_disambiguate_duplicates(mut self: Pin<&mut Self>) {
        let cur_val = *self.as_ref().disambiguate_duplicates();
        self.as_mut().set_disambiguate_duplicates(!cur_val);
    }

    pub fn load_drives(mut self: Pin<&mut Self>) {
        let drives = read_system_drives();
        let json = serde_json::to_string(&drives).unwrap_or_else(|_| "[]".to_string());
        self.as_mut().set_drives_json(QString::from(&json));
    }

    pub fn refresh_frequent_dirs(mut self: Pin<&mut Self>) {
        let freq = get_frequent_dirs();
        let json = serde_json::to_string(&freq).unwrap_or_else(|_| "[]".to_string());
        self.as_mut().set_frequent_dirs_json(QString::from(&json));
    }

    pub fn load_trash(mut self: Pin<&mut Self>) {
        let trash = scan_trash_files();
        let json = serde_json::to_string(&trash).unwrap_or_else(|_| "[]".to_string());
        self.as_mut().set_trash_json(QString::from(&json));
    }

    pub fn empty_trash(mut self: Pin<&mut Self>) {
        let _ = std::process::Command::new("gio").args(["trash", "--empty"]).status();

        let (trash_files, trash_info) = trash_paths();

        if let Ok(entries) = fs::read_dir(&trash_files) {
            for entry in entries.flatten() {
                let _ = fs::remove_dir_all(entry.path()).or_else(|_| fs::remove_file(entry.path()));
            }
        }
        if let Ok(entries) = fs::read_dir(&trash_info) {
            for entry in entries.flatten() {
                let _ = fs::remove_file(entry.path());
            }
        }
        // Trash entries can no longer be restored, so the stack is stale.
        clear_stack(&UNDO_STACK);
        clear_stack(&REDO_STACK);

        self.as_mut().sync_undo_flags();
        self.load_trash();
    }

    /// Restores a single item from the trash by following its `.trashinfo` entry.
    pub fn restore_trash_item(mut self: Pin<&mut Self>, path: &QString) {
        let item_path = PathBuf::from(path.to_string());
        let Some(name) = item_path.file_name().and_then(|n| n.to_str()).map(|n| n.to_string()) else {
            return;
        };

        let (files_dir, info_dir) = trash_paths();
        let trashed = if item_path.is_absolute() { item_path.clone() } else { files_dir.join(&name) };
        let info_path = info_dir.join(format!("{}.trashinfo", name));

        let Ok(content) = fs::read_to_string(&info_path) else {
            eprintln!("loaf: no trash metadata for {}", name);
            return;
        };
        let Some(original) = parse_trashinfo_path(&content) else {
            eprintln!("loaf: malformed trash metadata for {}", name);
            return;
        };

        let target = PathBuf::from(&original);
        if let Some(parent) = target.parent() {
            let _ = fs::create_dir_all(parent);
        }

        let restored = fs::rename(&trashed, &target).is_ok();
        if restored || copy_recursive(&trashed, &target) {
            if !restored {
                let _ = remove_path(&trashed);
            }
            let _ = fs::remove_file(&info_path);
        } else {
            eprintln!("loaf: could not restore {} to {}", name, original);
        }

        self.as_mut().load_trash();
        self.refresh();
    }

    pub fn search_everywhere(mut self: Pin<&mut Self>, query: &QString) {
        let q = query.to_string();
        if q.trim().is_empty() {
            self.as_mut().set_is_searching_everywhere(false);
            self.as_mut().set_search_everywhere_json(QString::from("[]"));
            return;
        }

        let show_hidden = *self.as_ref().show_hidden();
        let disambiguate = *self.as_ref().disambiguate_duplicates();
        let items = execute_search_everywhere(&q, show_hidden, disambiguate);
        let json = serde_json::to_string(&items).unwrap_or_else(|_| "[]".to_string());

        self.as_mut().set_is_searching_everywhere(true);
        self.as_mut().set_search_everywhere_json(QString::from(&json));
    }

    pub fn clear_search_everywhere(mut self: Pin<&mut Self>) {
        self.as_mut().set_is_searching_everywhere(false);
        self.as_mut().set_search_everywhere_json(QString::from("[]"));
    }

    pub fn resolve_icon(&self, name: &QString) -> QString {
        let n = name.to_string();
        let path = resolve_system_icon(&n);
        QString::from(&path)
    }

    pub fn get_thumbnail(&self, path: &QString) -> QString {
        let path_str = path.to_string();
        QString::from(&resolve_thumbnail_path(Path::new(&path_str)))
    }

    pub fn open_item(&self, path: &QString) {
        let p = path.to_string();
        let _ = std::process::Command::new("xdg-open").arg(&p).spawn();
    }

    /// Apps that declare support for the file's MIME type, best match first,
    /// followed by every other installed application.
    pub fn open_with_apps(&self, path: &QString) -> QString {
        let target = PathBuf::from(path.to_string());
        let mime = mime_type_for_path(&target);

        let mut recommended: Vec<DesktopApp> = Vec::new();
        let mut seen: HashSet<String> = HashSet::new();
        let apps = all_desktop_apps();
        if !mime.is_empty() {
            let default = default_app_id(&mime).map(|d| desktop_id_of(&d).to_string());
            for app in apps.iter() {
                if declared_mimes(&app.desktop_path)
                    .iter()
                    .any(|m| mime_covers(m, &mime))
                {
                    seen.insert(app.id.clone());
                    recommended.push(app.clone());
                }
            }
            // Always surface the current default, even if its desktop file does
            // not list the MIME type explicitly, and list it first.
            if let Some(default_id) = default {
                if let Some(pos) = recommended.iter().position(|a| a.id == default_id) {
                    let app = recommended.remove(pos);
                    recommended.insert(0, app);
                }
            }
        }

        let json = serde_json::to_string(
            &recommended
                .iter()
                .map(|a| AppEntry { id: a.id.clone(), name: a.name.clone() })
                .collect::<Vec<AppEntry>>(),
        )
        .unwrap_or_else(|_| "[]".to_string());
        QString::from(&json)
    }

    /// Every installed application, for the "Other Applications" list.
    pub fn all_open_with_apps(&self) -> QString {
        let json = serde_json::to_string(
            &all_desktop_apps()
                .iter()
                .map(|a| AppEntry { id: a.id.clone(), name: a.name.clone() })
                .collect::<Vec<AppEntry>>(),
        )
        .unwrap_or_else(|_| "[]".to_string());
        QString::from(&json)
    }

    /// The most recently used apps, newest first (for the "Recent" group).
    pub fn recent_open_with_apps(&self) -> QString {
        let json = serde_json::to_string(&recent_open_with_apps())
            .unwrap_or_else(|_| "[]".to_string());
        QString::from(&json)
    }

    pub fn open_with_app(&self, path: &QString, app_id: &QString) {
        let target = PathBuf::from(path.to_string());
        let id = app_id.to_string();
        let Some(app) = all_desktop_apps().into_iter().find(|a| a.id == id) else {
            eprintln!("loaf: no desktop entry found for app id '{}'", id);
            return;
        };
        push_recent_app(&id);
        let args = expand_exec(&app.exec, &target);
        if args.is_empty() {
            return;
        }
        let mut cmd = std::process::Command::new(&args[0]);
        cmd.args(&args[1..]);
        // Some apps expect to be started with the file as their working context.
        if let Some(parent) = target.parent() {
            if parent.is_dir() && !target.is_dir() {
                cmd.current_dir(parent);
            }
        }
        if let Err(err) = cmd.spawn() {
            eprintln!("loaf: could not launch '{}': {}", app.name, err);
        }
    }

    /// Desktop id (without the `.desktop` suffix) of the current default
    /// application for the file's MIME type.
    pub fn default_app_for(&self, path: &QString) -> QString {
        let mime = mime_type_for_path(&PathBuf::from(path.to_string()));
        let id = if mime.is_empty() {
            String::new()
        } else {
            default_app_id(&mime)
                .map(|name| desktop_id_of(&name).to_string())
                .unwrap_or_default()
        };
        QString::from(&id)
    }

    /// Runs a user-typed command with the selected item, e.g. `mpv %f`.
    ///
    /// Returns false when the command is empty or the shell cannot be started.
    pub fn run_custom_command(&self, command: &QString, path: &QString) -> bool {
        let command = command.to_string();
        let trimmed = command.trim();
        if trimmed.is_empty() {
            return false;
        }

        push_recent_app(&format!("cmd:{}", trimmed));
        let expanded = substitute_command_path(trimmed, &PathBuf::from(path.to_string()));
        match std::process::Command::new("sh")
            .arg("-c")
            .arg(&expanded)
            .spawn()
        {
            Ok(_) => true,
            Err(err) => {
                eprintln!("loaf: could not run custom command: {}", err);
                false
            }
        }
    }

    pub fn set_default_app(&self, path: &QString, app_id: &QString) {
        let mime = mime_type_for_path(&PathBuf::from(path.to_string()));
        let app_id = app_id.to_string();
        if mime.is_empty() {
            return;
        }
        set_default_app_id(&mime, &app_id);
        // The recommendation list may change with the new default.
        *APPS_CACHE.lock().unwrap() = None;
    }

    pub fn open_terminal(&self, dir_path: &QString) {
        let dir = dir_path.to_string();
        if Path::new("/etc/profiles/per-user/m_uvex/bin/kitty").exists() {
            let _ = std::process::Command::new("kitty").arg("--directory").arg(&dir).spawn();
        } else if Path::new("/etc/profiles/per-user/m_uvex/bin/foot").exists() {
            let _ = std::process::Command::new("foot").arg("-D").arg(&dir).spawn();
        } else {
            let _ = std::process::Command::new("xdg-terminal-exec").current_dir(&dir).spawn();
        }
    }

    pub fn create_folder(mut self: Pin<&mut Self>, dir: &QString, name: &QString) {
        let target = Path::new(&dir.to_string()).join(name.to_string());
        if fs::create_dir_all(&target).is_ok() {
            self.as_mut().record_undo(UndoAction::Create {
                path: target.to_string_lossy().to_string(),
                is_dir: true,
            });
        }
        self.refresh();
    }

    pub fn create_file(mut self: Pin<&mut Self>, dir: &QString, name: &QString) {
        let target = Path::new(&dir.to_string()).join(name.to_string());
        if fs::File::create(&target).is_ok() {
            self.as_mut().record_undo(UndoAction::Create {
                path: target.to_string_lossy().to_string(),
                is_dir: false,
            });
        }
        self.refresh();
    }

    pub fn rename_item(mut self: Pin<&mut Self>, dir: &QString, old_name: &QString, new_name: &QString) {
        let dir_str = dir.to_string();
        let base = Path::new(&dir_str);
        let src = base.join(old_name.to_string());
        let dst = base.join(new_name.to_string());
        if fs::rename(&src, &dst).is_ok() {
            self.as_mut().record_undo(UndoAction::Rename {
                dir: dir_str,
                old_name: old_name.to_string(),
                new_name: new_name.to_string(),
            });
        }
        self.refresh();
    }

    pub fn trash_items(mut self: Pin<&mut Self>, paths_json: &QString) {
        if let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) {
            let mut items = Vec::new();
            for p in paths {
                let path = Path::new(&p);
                if let Some(item) = trash_into_home_trash(path) {
                    items.push(item);
                } else if let Some(item) = trash_via_cli(path) {
                    items.push(item);
                } else {
                    eprintln!("loaf: could not move {} to trash", p);
                }
            }
            if !items.is_empty() {
                self.as_mut().record_undo(UndoAction::Trash { items });
            }
        }
        self.as_mut().load_trash();
        self.refresh();
    }

    pub fn copy_items(mut self: Pin<&mut Self>, paths_json: &QString, is_cut: bool) {
        if let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) {
            let mut clip = CLIPBOARD.lock().unwrap();
            *clip = (paths.clone(), is_cut);
            let has = !clip.0.is_empty();
            self.as_mut().set_has_clipboard(has);
            if is_cut {
                self.as_mut().set_clipboard_cut_paths_json(paths_json.clone());
            } else {
                self.as_mut().set_clipboard_cut_paths_json(QString::from("[]"));
            }
        }
    }

    pub fn paste_items(self: Pin<&mut Self>, dest_dir: &QString) {
        self.paste_items_resolved(dest_dir, &QString::from("overwrite"));
    }

    pub fn drop_items(self: Pin<&mut Self>, paths_json: &QString, dest_dir: &QString, as_copy: bool) {
        self.drop_items_resolved(paths_json, dest_dir, as_copy, &QString::from("overwrite"));
    }

    pub fn change_folder_position(mut self: Pin<&mut Self>, position: &QString) {
        self.as_mut().set_folder_position(position.clone());
        let pos_str = position.to_string();
        self.as_mut().set_dirs_first(pos_str != "mixed");
        self.refresh();
    }

    pub fn set_sort(mut self: Pin<&mut Self>, sort_by: &QString, ascending: bool) {
        self.as_mut().set_sort_by(sort_by.clone());
        self.as_mut().set_sort_ascending(ascending);
        self.refresh();
    }

    pub fn toggle_sort_order(mut self: Pin<&mut Self>) {
        let cur = *self.as_ref().sort_ascending();
        self.as_mut().set_sort_ascending(!cur);
        self.refresh();
    }

    pub fn toggle_view_mode(mut self: Pin<&mut Self>) {
        let cur = self.as_ref().view_mode().to_string();
        let next = if cur == "list" { "grid" } else { "list" };
        self.as_mut().set_view_mode(QString::from(next));
    }

    pub fn check_paste_conflicts(&self, paths_json: &QString, dest_dir: &QString) -> QString {
        let dest = PathBuf::from(dest_dir.to_string());
        let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) else {
            return QString::from("[]");
        };

        let mut conflicts = Vec::new();
        for p_str in paths {
            let src = PathBuf::from(&p_str);
            // Self-drop guard: if destination is the same directory as source parent, ignore it!
            if let Some(src_parent) = src.parent() {
                if src_parent == dest {
                    continue;
                }
            }
            let Some(file_name) = src.file_name() else { continue };
            let target = dest.join(file_name);
            if target.exists() {
                let name = file_name.to_string_lossy().to_string();
                let is_dir = target.is_dir();
                let src_size = src.metadata().map(|m| format_size(m.len())).unwrap_or_else(|_| "-".to_string());
                let dest_size = target.metadata().map(|m| format_size(m.len())).unwrap_or_else(|_| "-".to_string());
                conflicts.push(ConflictItem {
                    name,
                    src_path: p_str,
                    dest_path: target.to_string_lossy().to_string(),
                    src_size,
                    dest_size,
                    is_dir,
                });
            }
        }

        QString::from(&serde_json::to_string(&conflicts).unwrap_or_else(|_| "[]".to_string()))
    }

    pub fn check_clipboard_conflicts(&self, dest_dir: &QString) -> QString {
        let clip = CLIPBOARD.lock().unwrap();
        let paths_json = serde_json::to_string(&clip.0).unwrap_or_else(|_| "[]".to_string());
        drop(clip);
        self.check_paste_conflicts(&QString::from(&paths_json), dest_dir)
    }

    pub fn paste_items_resolved(mut self: Pin<&mut Self>, dest_dir: &QString, resolution: &QString) {
        let dest = PathBuf::from(dest_dir.to_string());
        let (files, is_cut) = {
            let clip = CLIPBOARD.lock().unwrap();
            (clip.0.clone(), clip.1)
        };
        let res = resolution.to_string();

        let mut move_pairs: Vec<(String, String)> = Vec::new();
        let mut copy_pairs: Vec<(String, String)> = Vec::new();

        for src_str in &files {
            let src = PathBuf::from(src_str);
            let Some(file_name) = src.file_name().and_then(|n| n.to_str()) else { continue };
            let target = if res == "rename" {
                get_unique_name(&dest, file_name)
            } else {
                dest.join(file_name)
            };

            if res == "skip" && dest.join(file_name).exists() {
                continue;
            }
            if target == src {
                continue;
            }
            // Overwriting an existing entry cannot be reversed, so skip undo for it.
            let undoable = res == "rename" || !target.exists();

            let ok = if is_cut {
                let mut moved_ok = fs::rename(&src, &target).is_ok();
                if !moved_ok && copy_recursive(&src, &target) {
                    let _ = remove_path(&src);
                    moved_ok = true;
                }
                moved_ok
            } else {
                copy_recursive(&src, &target)
            };

            if !ok {
                continue;
            }
            let target_str = target.to_string_lossy().to_string();
            if is_cut {
                if undoable {
                    move_pairs.push((src_str.clone(), target_str));
                }
            } else if undoable {
                copy_pairs.push((src_str.clone(), target_str));
            }
        }

        if is_cut {
            if let Ok(mut clip) = CLIPBOARD.lock() {
                clip.0.clear();
                clip.1 = false;
            }
            self.as_mut().set_clipboard_cut_paths_json(QString::from("[]"));
            self.as_mut().set_has_clipboard(false);
        }

        if !move_pairs.is_empty() {
            self.as_mut().record_undo(UndoAction::Move { pairs: move_pairs });
        } else if !copy_pairs.is_empty() {
            self.as_mut().record_undo(UndoAction::Copy { pairs: copy_pairs });
        }

        self.refresh();
    }

    pub fn drop_items_resolved(mut self: Pin<&mut Self>, paths_json: &QString, dest_dir: &QString, as_copy: bool, resolution: &QString) {
        let dest = PathBuf::from(dest_dir.to_string());
        if !dest.is_dir() { return; }
        let res = resolution.to_string();

        let mut move_pairs: Vec<(String, String)> = Vec::new();
        let mut copy_pairs: Vec<(String, String)> = Vec::new();

        if let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) {
            for src_str in paths {
                let src = PathBuf::from(&src_str);
                if src.is_dir() && dest.starts_with(&src) { continue; }
                if src == dest { continue; }
                if !as_copy {
                    if let Some(src_parent) = src.parent() {
                        if src_parent == dest {
                            continue; // Self-drop canceled
                        }
                    }
                }

                let Some(file_name) = src.file_name().and_then(|n| n.to_str()) else { continue };
                let target = if res == "rename" {
                    get_unique_name(&dest, file_name)
                } else {
                    dest.join(file_name)
                };

                if res == "skip" && dest.join(file_name).exists() {
                    continue;
                }
                let undoable = res == "rename" || !target.exists();

                let ok = if as_copy {
                    copy_recursive(&src, &target)
                } else {
                    let mut moved_ok = fs::rename(&src, &target).is_ok();
                    if !moved_ok && copy_recursive(&src, &target) {
                        let _ = remove_path(&src);
                        moved_ok = true;
                    }
                    moved_ok
                };

                if !ok {
                    continue;
                }
                let target_str = target.to_string_lossy().to_string();
                if as_copy {
                    if undoable {
                        copy_pairs.push((src_str.clone(), target_str));
                    }
                } else if undoable {
                    move_pairs.push((src_str.clone(), target_str));
                }
            }
        }

        if !move_pairs.is_empty() {
            self.as_mut().record_undo(UndoAction::Move { pairs: move_pairs });
        } else if !copy_pairs.is_empty() {
            self.as_mut().record_undo(UndoAction::Copy { pairs: copy_pairs });
        }

        self.refresh();
    }

    pub fn create_symlinks(self: Pin<&mut Self>, paths_json: &QString, dest_dir: &QString) {
        let dest = PathBuf::from(dest_dir.to_string());
        if !dest.is_dir() { return; }
        if let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) {
            for p_str in paths {
                let src = PathBuf::from(&p_str);
                let Some(name) = src.file_name().and_then(|n| n.to_str()) else { continue };
                let target = get_unique_name(&dest, name);
                #[cfg(unix)]
                let _ = std::os::unix::fs::symlink(&src, &target);
            }
        }
        self.refresh();
    }

    pub fn compress_items_with_options(self: Pin<&mut Self>, paths_json: &QString, format: &QString, password: &QString) {
        let Ok(paths) = serde_json::from_str::<Vec<String>>(&paths_json.to_string()) else {
            eprintln!("loaf: compress: invalid paths payload");
            return;
        };
        if paths.is_empty() {
            return;
        }

        let fmt = format.to_string();
        let pass = password.to_string();
        let first_p = PathBuf::from(&paths[0]);
        let parent_dir = first_p.parent().unwrap_or(Path::new(".")).to_path_buf();

        let base_name = if paths.len() == 1 {
            archive_base_name(&first_p)
        } else {
            "Archive".to_string()
        };

        let archive_ext = match fmt.as_str() {
            "zip" | "zip_encrypted" => "zip",
            "7z" => "7z",
            "tar.gz" => "tar.gz",
            "tar.xz" => "tar.xz",
            "tar.zst" => "tar.zst",
            "tar.bz2" => "tar.bz2",
            "cpio" => "cpio",
            _ => "zip",
        };
        let archive_filename = format!("{}.{}", base_name, archive_ext);
        let archive_target = get_unique_name(&parent_dir, &archive_filename);

        // Names stored inside the archive are relative to the archive's directory.
        let relative_names: Vec<String> = paths.iter().map(|p| relative_name(p, &parent_dir)).collect();

        let created = match fmt.as_str() {
            "7z" => compress_with_7z(&archive_target, &relative_names, &pass, &parent_dir),
            "zip_encrypted" => compress_zip_encrypted(&archive_target, &relative_names, &pass, &parent_dir),
            "zip" if !pass.is_empty() => compress_zip_encrypted(&archive_target, &relative_names, &pass, &parent_dir),
            "zip" => compress_zip(&archive_target, &relative_names, &parent_dir),
            "tar.gz" => compress_tar(&archive_target, &relative_names, &parent_dir, "z"),
            "tar.xz" => compress_tar(&archive_target, &relative_names, &parent_dir, "J"),
            "tar.bz2" => compress_tar(&archive_target, &relative_names, &parent_dir, "j"),
            "tar.zst" => compress_tar_zstd(&archive_target, &relative_names, &parent_dir),
            "cpio" => compress_cpio(&archive_target, &relative_names, &parent_dir),
            other => {
                eprintln!("loaf: unsupported archive format '{}'", other);
                false
            }
        };

        if !created {
            // Leave no half-written archive behind.
            if archive_target.exists() && archive_target.metadata().map(|m| m.len() == 0).unwrap_or(false) {
                let _ = fs::remove_file(&archive_target);
            }
            eprintln!("loaf: failed to create {}", archive_target.display());
        }

        self.refresh();
    }

    pub fn compress_items(self: Pin<&mut Self>, paths_json: &QString, format: &QString) {
        self.compress_items_with_options(paths_json, format, &QString::from(""));
    }

    pub fn extract_archive(self: Pin<&mut Self>, archive_path: &QString, into_subfolder: bool) {
        let arch = PathBuf::from(archive_path.to_string());
        if !arch.exists() { return; }

        let parent_dir = arch.parent().unwrap_or(Path::new(".")).to_path_buf();
        let target_dir = if into_subfolder {
            let name_str = arch.file_name().and_then(|n| n.to_str()).unwrap_or("extracted");
            let stem = if name_str.ends_with(".tar.gz") {
                name_str.strip_suffix(".tar.gz").unwrap_or(name_str)
            } else if name_str.ends_with(".tar.xz") {
                name_str.strip_suffix(".tar.xz").unwrap_or(name_str)
            } else if name_str.ends_with(".tar.zst") {
                name_str.strip_suffix(".tar.zst").unwrap_or(name_str)
            } else {
                arch.file_stem().and_then(|s| s.to_str()).unwrap_or("extracted")
            };
            let dir = get_unique_name(&parent_dir, stem);
            let _ = fs::create_dir_all(&dir);
            dir
        } else {
            parent_dir.clone()
        };

        let name_lower = arch.file_name().and_then(|n| n.to_str()).unwrap_or("").to_lowercase();
        if name_lower.ends_with(".zip") {
            let _ = std::process::Command::new("python3")
                .arg("-m").arg("zipfile")
                .arg("-e").arg(&arch).arg(&target_dir)
                .status();
        } else if name_lower.ends_with(".tar.gz") || name_lower.ends_with(".tgz") {
            let _ = std::process::Command::new("tar")
                .arg("-xzf").arg(&arch).arg("-C").arg(&target_dir)
                .status();
        } else if name_lower.ends_with(".tar.xz") || name_lower.ends_with(".txz") {
            let _ = std::process::Command::new("tar")
                .arg("-xJf").arg(&arch).arg("-C").arg(&target_dir)
                .status();
        } else if name_lower.ends_with(".tar.zst") {
            let _ = std::process::Command::new("tar")
                .arg("--zstd").arg("-xf").arg(&arch).arg("-C").arg(&target_dir)
                .status();
        } else if name_lower.ends_with(".tar") {
            let _ = std::process::Command::new("tar")
                .arg("-xf").arg(&arch).arg("-C").arg(&target_dir)
                .status();
        } else if name_lower.ends_with(".7z") {
            let _ = std::process::Command::new("7z")
                .arg("x").arg("-y").arg(&arch)
                .arg(format!("-o{}", target_dir.display()))
                .status();
        }

        self.refresh();
    }

    pub fn is_archive_file(&self, path: &QString) -> bool {
        let p = PathBuf::from(path.to_string());
        is_archive_path(&p)
    }

    /// Inline preview payload for the Quick Look pane.
    pub fn quick_look(&self, path: &QString) -> QString {
        let data = quick_look_data(&PathBuf::from(path.to_string()));
        let json = serde_json::to_string(&data).unwrap_or_else(|_| "{}".to_string());
        QString::from(&json)
    }

    pub fn get_item_info(&self, path: &QString) -> QString {
        let p = PathBuf::from(path.to_string());
        let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("").to_string();
        let is_dir = p.is_dir();

        let (size_str, mod_str) = if let Ok(meta) = p.metadata() {
            let s = if is_dir { "Folder".to_string() } else { format_size(meta.len()) };
            let m = meta.modified().ok()
                .and_then(|t| t.elapsed().ok())
                .map(|e| {
                    let secs = e.as_secs();
                    if secs < 60 { "Just now".to_string() }
                    else if secs < 3600 { format!("{} min ago", secs / 60) }
                    else if secs < 86400 { format!("{} hrs ago", secs / 3600) }
                    else { format!("{} days ago", secs / 86400) }
                })
                .unwrap_or_else(|| "-".to_string());
            (s, m)
        } else {
            ("-".to_string(), "-".to_string())
        };

        let info = ItemInfo {
            name,
            path: p.to_string_lossy().to_string(),
            size: size_str,
            is_dir,
            modified: mod_str,
        };

        serde_json::to_string(&info).unwrap_or_else(|_| "{}".to_string()).into()
    }

    pub fn undo(mut self: Pin<&mut Self>) {
        let action = {
            let mut guard = UNDO_STACK.lock().unwrap();
            let stack = guard.get_or_insert_with(Vec::new);
            stack.pop()
        };

        let Some(act) = action else { return };
        let redo_entry = apply_inverse(&act);

        if let Some(entry) = redo_entry {
            let mut guard = REDO_STACK.lock().unwrap();
            guard.get_or_insert_with(Vec::new).push(entry);
        }

        // The view may need to be reloaded either way: a partially applied action
        // still changed the filesystem.
        self.as_mut().sync_undo_flags();
        self.as_mut().refresh_clipboard_state();
        self.as_mut().load_trash();
        self.refresh();
    }

    pub fn redo(mut self: Pin<&mut Self>) {
        let action = {
            let mut guard = REDO_STACK.lock().unwrap();
            let stack = guard.get_or_insert_with(Vec::new);
            stack.pop()
        };

        let Some(act) = action else { return };
        let undo_entry = apply_action(&act);

        if let Some(entry) = undo_entry {
            let mut guard = UNDO_STACK.lock().unwrap();
            guard.get_or_insert_with(Vec::new).push(entry);
        }

        self.as_mut().sync_undo_flags();
        self.as_mut().refresh_clipboard_state();
        self.as_mut().load_trash();
        self.refresh();
    }

    /// Re-detects the system color scheme and republishes `is_dark`.
    pub fn refresh_system_theme(mut self: Pin<&mut Self>) {
        let dark = detect_system_dark_mode();
        self.as_mut().set_is_dark(dark);
    }

    pub fn get_setting(&self, key: &QString) -> QString {
        let k = key.to_string();
        let value = load_settings().get(&k).cloned().unwrap_or_default();
        QString::from(&value)
    }

    pub fn set_setting(self: Pin<&mut Self>, key: &QString, value: &QString) {
        let k = key.to_string();
        let v = value.to_string();
        let mut map = load_settings();
        if map.get(&k).map(|existing| existing == &v).unwrap_or(false) {
            return;
        }
        map.insert(k, v);
        store_settings(&map);
    }

    pub fn mount_drive(mut self: Pin<&mut Self>, device: &QString) {
        let dev = device.to_string();
        let _ = std::process::Command::new("udisksctl")
            .args(["mount", "-b", &dev])
            .status();
        self.as_mut().load_drives();
    }

    pub fn unmount_drive(mut self: Pin<&mut Self>, device: &QString) {
        let dev = device.to_string();
        let _ = std::process::Command::new("udisksctl")
            .args(["unmount", "-b", &dev])
            .status();
        self.as_mut().load_drives();
    }

    pub fn rename_drive(mut self: Pin<&mut Self>, device: &QString, new_name: &QString) {
        let dev = device.to_string();
        let name = new_name.to_string();
        let _ = std::process::Command::new("e2label").args([&dev, &name]).status()
            .or_else(|_| std::process::Command::new("fatlabel").args([&dev, &name]).status())
            .or_else(|_| std::process::Command::new("exfatlabel").args([&dev, &name]).status());
        self.as_mut().load_drives();
    }

    pub fn reload_wallpaper_colors(mut self: Pin<&mut Self>) -> bool {
        // Always re-read the wallpaper color source from disk: matugen/pywal may
        // have rewritten it since the last check.
        let Some((_source, content, _mtime)) = read_wallpaper_colors_source() else {
            // Nothing readable yet: keep the colors we already have.
            return false;
        };

        if content == self.as_ref().wallpaper_colors_json().to_string() {
            return false;
        }

        self.as_mut().set_wallpaper_colors_json(QString::from(&content));
        true
    }
}

#[cfg(test)]
mod open_with_tests {
    use super::*;

    fn write_desktop(dir: &Path, name: &str, body: &str) -> PathBuf {
        fs::create_dir_all(dir).unwrap();
        let path = dir.join(name);
        fs::write(&path, body).unwrap();
        path
    }

    #[test]
    fn parses_a_desktop_entry() {
        let dir = std::env::temp_dir().join("loaf-test-desktop");
        let _ = fs::remove_dir_all(&dir);
        let path = write_desktop(
            &dir,
            "firefox.desktop",
            "[Desktop Entry]\nType=Application\nName=Firefox\nName[de]=Feuerfuchs\nExec=firefox --new-window %u\nIcon=firefox\nMimeType=text/html;text/plain;\n",
        );

        let app = parse_desktop_file(&path).expect("entry should parse");
        assert_eq!(app.id, "firefox");
        assert_eq!(app.exec, "firefox --new-window %u");
        assert_eq!(declared_mimes(&path), vec!["text/html", "text/plain"]);
    }

    #[test]
    fn skips_hidden_and_non_application_entries() {
        let dir = std::env::temp_dir().join("loaf-test-desktop-skip");
        let _ = fs::remove_dir_all(&dir);
        let hidden = write_desktop(
            &dir,
            "hidden.desktop",
            "[Desktop Entry]\nType=Application\nHidden=true\nName=Hidden\nExec=hidden %f\n",
        );
        let link = write_desktop(
            &dir,
            "link.desktop",
            "[Desktop Entry]\nType=Link\nName=Link\nURL=https://example.com\n",
        );
        assert!(parse_desktop_file(&hidden).is_none());
        assert!(parse_desktop_file(&link).is_none());
    }

    #[test]
    fn expands_exec_field_codes() {
        let args = expand_exec("gimp %U", Path::new("/tmp/my photo.png"));
        assert_eq!(args, vec!["gimp", "/tmp/my photo.png"]);

        let quoted = expand_exec("env FOO=1 app \"%f\"", Path::new("/tmp/a b.txt"));
        assert_eq!(quoted, vec!["env", "FOO=1", "app", "/tmp/a b.txt"]);

        // %F and %U both mean "the file(s)".
        assert_eq!(expand_exec("viewer %F", Path::new("/tmp/x.txt")), vec!["viewer", "/tmp/x.txt"]);

        // Flatpak exports escape the field codes as `@@u`/`@@`; `flatpak run` expands
        // them itself, so the escape has to be undone before launching.
        let flatpak = expand_exec(
            "/usr/bin/flatpak run --command=gedit com.example.App @@u %U @@",
            Path::new("/tmp/x.txt"),
        );
        assert_eq!(
            flatpak,
            vec!["/usr/bin/flatpak", "run", "--command=gedit", "com.example.App", "%u", "/tmp/x.txt", "%"]
        );
    }

    #[test]
    fn mime_matching_handles_wildcards_and_aliases() {
        assert!(mime_covers("text/html", "text/html"));
        assert!(mime_covers("image/*", "image/png"));
        assert!(mime_covers("image/jpg", "image/jpeg"));
        assert!(!mime_covers("video/mp4", "image/png"));
        assert!(!mime_covers("", "image/png"));
    }
}


#[cfg(test)]
mod quick_look_tests {
    use super::*;

    fn temp_file(name: &str, content: &[u8]) -> PathBuf {
        let path = std::env::temp_dir().join(format!("loaf-quicklook-{}", name));
        fs::write(&path, content).unwrap();
        path
    }

    #[test]
    fn previews_source_code_with_a_language() {
        let path = temp_file("sample.rs", b"fn main() {}\n");
        let data = quick_look_data(&path);
        assert_eq!(data.kind, "text");
        assert_eq!(data.language, "rust");
        assert!(data.text.contains("fn main"));
        assert!(!data.truncated);
    }

    #[test]
    fn previews_plain_text_and_markdown() {
        let txt = temp_file("sample.txt", b"hello\n");
        assert_eq!(quick_look_data(&txt).language, "text");

        let md = temp_file("sample.md", b"# Title\n");
        assert_eq!(quick_look_data(&md).language, "markdown");
    }

    #[test]
    fn refuses_binary_content() {
        let path = temp_file("sample.bin", &[0x00, 0x01, 0x02, b'h', b'i']);
        let data = quick_look_data(&path);
        assert_eq!(data.kind, "none");
        assert!(data.text.is_empty());
    }

    #[test]
    fn describes_folders_and_missing_files() {
        let dir = std::env::temp_dir();
        let data = quick_look_data(&dir);
        assert_eq!(data.kind, "folder");
        assert!(data.note.contains("items") || data.note.contains("item"));

        let missing = quick_look_data(&dir.join("definitely-not-here.bin"));
        assert_eq!(missing.kind, "none");
        assert_eq!(missing.size_str, "-");
    }

    #[test]
    fn truncates_huge_text_files() {
        let big = vec![b'a'; QUICKLOOK_MAX_BYTES + 1024];
        let path = temp_file("big.log", &big);
        let data = quick_look_data(&path);
        assert_eq!(data.kind, "text");
        assert!(data.truncated);
        assert_eq!(data.text.len(), QUICKLOOK_MAX_BYTES);
    }
}

#[cfg(test)]
mod custom_command_tests {
    use super::*;

    #[test]
    fn substitutes_placeholders() {
        let path = Path::new("/tmp/my file.txt");
        assert_eq!(substitute_command_path("mpv %f", path), "mpv '/tmp/my file.txt'");
        assert_eq!(substitute_command_path("app %U", path), "app '/tmp/my file.txt'");
        assert_eq!(
            substitute_command_path("app %f --flag", path),
            "app '/tmp/my file.txt' --flag"
        );
    }

    #[test]
    fn appends_path_when_no_placeholder() {
        let path = Path::new("/tmp/a.txt");
        assert_eq!(substitute_command_path("mpv", path), "mpv '/tmp/a.txt'");
    }

    #[test]
    fn leaves_shell_syntax_untouched() {
        let cmd = "echo hi > /tmp/out.txt";
        assert_eq!(substitute_command_path(cmd, Path::new("/tmp/a.txt")), cmd);
        let piped = "cat %f | wc -l";
        assert_eq!(substitute_command_path(piped, Path::new("/tmp/a.txt")), "cat '/tmp/a.txt' | wc -l");
    }

    #[test]
    fn escapes_single_quotes_in_paths() {
        let path = Path::new("/tmp/it's.txt");
        assert_eq!(substitute_command_path("app %f", path), "app '/tmp/it'\\''s.txt'");
    }
}

#[cfg(test)]
mod recent_apps_tests {
    use super::*;

    // These tests share the process-wide settings cache, so they run in one
    // test to keep the ordering deterministic.
    #[test]
    fn recent_list_is_mru_capped_and_resolved() {
        let mut settings = load_settings();
        let original = settings.get(RECENT_APPS_KEY).cloned();
        let mut ids: Vec<String> = Vec::new();

        // Open 12 apps: only the newest 8 survive, newest first.
        for i in 0..12 {
            let id = format!("test-app-{}", i);
            ids.push(id.clone());
            push_recent_app(&id);
        }
        let stored = load_settings().get(RECENT_APPS_KEY).cloned().unwrap_or_default();
        let list: Vec<String> = stored.split(RECENT_APPS_SEP).map(|s| s.to_string()).collect();
        assert_eq!(list.len(), RECENT_APPS_LIMIT);
        assert_eq!(list[0], "test-app-11", "newest entry must come first");
        assert_eq!(list[1], "test-app-10");

        // Re-using an entry moves it to the front instead of duplicating it.
        push_recent_app("test-app-5");
        let stored = load_settings().get(RECENT_APPS_KEY).cloned().unwrap_or_default();
        let list: Vec<String> = stored.split(RECENT_APPS_SEP).map(|s| s.to_string()).collect();
        assert_eq!(list[0], "test-app-5");
        assert_eq!(list.iter().filter(|id| *id == "test-app-5").count(), 1);
        assert_eq!(list.len(), RECENT_APPS_LIMIT);

        // Ids with no matching .desktop file resolve to nothing, so an
        // uninstalled app never shows up in the menu.
        assert!(recent_open_with_apps().is_empty());

        // A real installed app resolves to its display name, and `cmd:` entries
        // are not resolved as desktop ids.
        let installed = all_desktop_apps();
        if !installed.is_empty() {
            let real = installed[0].id.clone();
            settings = load_settings();
            settings.insert(RECENT_APPS_KEY.to_string(), format!("cmd:mpv %f{}", RECENT_APPS_SEP).to_string() + &real);
            store_settings(&settings);

            let resolved = recent_open_with_apps();
            assert_eq!(resolved.len(), 1);
            assert_eq!(resolved[0].id, real);
            assert_eq!(resolved[0].name, installed[0].name);
        }

        // Restore whatever the user had before the test.
        settings = load_settings();
        match original {
            Some(v) => {
                settings.insert(RECENT_APPS_KEY.to_string(), v);
            }
            None => {
                settings.remove(RECENT_APPS_KEY);
            }
        }
        store_settings(&settings);
    }
}
