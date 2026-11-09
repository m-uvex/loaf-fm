//! Directory scanning, sorting, filtering and incremental diffing for the
//! file view model. Pure Rust; runs on worker threads.

use std::cmp::Ordering;
use std::collections::HashSet;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::sync::Arc;

#[derive(Clone, Debug, PartialEq)]
pub struct Entry {
    pub name: String,
    /// Lowercase copy of `name`. The as-you-type filter compares against
    /// this, so retyping in the filter box never re-lowercases every name.
    pub name_lower: String,
    /// Absolute path (for search results the item may live anywhere).
    pub path: String,
    /// Folder, or a symlink pointing at one (it opens like a folder).
    pub is_dir: bool,
    pub is_symlink: bool,
    pub is_hidden: bool,
    pub size: u64,
    pub modified: i64,
    /// Phosphor icon name.
    pub icon: &'static str,
    /// Freedesktop icon name (system icon themes).
    pub system_icon: &'static str,
    /// Coarse type used for the Type column / sorting ("folder", "media", ...).
    pub category: &'static str,
    /// Whether a thumbnail may exist (images, videos, documents...).
    pub thumbable: bool,
    /// Extra text: parent folder for search results, original location in
    /// the trash, ...
    pub detail: String,
    /// Disambiguated name for search results ("Projects/notes.md").
    pub display_name: String,
}

pub fn extension(name: &str) -> String {
    match name.rfind('.') {
        Some(i) if i > 0 && i + 1 < name.len() => name[i + 1..].to_lowercase(),
        _ => String::new(),
    }
}

pub fn is_image_ext(ext: &str) -> bool {
    matches!(
        ext,
        "png"
            | "jpg"
            | "jpeg"
            | "jpe"
            | "jfif"
            | "webp"
            | "gif"
            | "bmp"
            | "dib"
            | "ico"
            | "svg"
            | "svgz"
            | "kra"
            | "ora"
            | "tiff"
            | "tif"
            | "avif"
            | "heic"
            | "heif"
            | "jxl"
            | "xcf"
            | "psd"
            | "raw"
            | "cr2"
            | "nef"
            | "dng"
            | "arw"
            | "tga"
            | "xpm"
            | "pbm"
            | "pgm"
            | "ppm"
            | "qoi"
    )
}

pub fn is_video_ext(ext: &str) -> bool {
    matches!(
        ext,
        "mp4"
            | "mkv"
            | "webm"
            | "mov"
            | "avi"
            | "flv"
            | "wmv"
            | "m4v"
            | "mpg"
            | "mpeg"
            | "ogv"
            | "3gp"
            | "ts"
    )
}

pub fn is_audio_ext(ext: &str) -> bool {
    matches!(
        ext,
        "mp3" | "flac" | "wav" | "ogg" | "oga" | "m4a" | "aac" | "opus" | "wma" | "aiff" | "ape"
    )
}

/// (phosphor icon, freedesktop icon, category, thumbnail candidate)
pub fn classify(name: &str, is_dir: bool) -> (&'static str, &'static str, &'static str, bool) {
    if is_dir {
        return ("folder", "folder", "folder", false);
    }
    let ext = extension(name);
    if is_image_ext(&ext) {
        return ("file-image", "image-x-generic", "image", true);
    }
    if is_video_ext(&ext) {
        return ("file-video", "video-x-generic", "video", true);
    }
    if is_audio_ext(&ext) {
        return ("file-audio", "audio-x-generic", "audio", false);
    }
    match ext.as_str() {
        "html" | "htm" | "xhtml" => ("file-html", "text-html", "code", false),
        "css" | "scss" | "sass" | "less" => ("file-css", "text-css", "code", false),
        "rs" | "nix" | "js" | "mjs" | "ts" | "jsx" | "tsx" | "py" | "c" | "cc" | "cpp" | "h"
        | "hpp" | "lua" | "go" | "java" | "kt" | "rb" | "php" | "swift" | "zig" | "qml" | "cs"
        | "dart" | "hs" => ("file-code", "text-x-script", "code", false),
        "sh" | "bash" | "zsh" | "fish" => ("code", "text-x-script", "code", false),
        "zip" | "jar" | "apk" => ("file-zip", "package-x-generic", "archive", false),
        "tar" | "gz" | "xz" | "zst" | "bz2" | "7z" | "rar" | "tgz" | "txz" | "tbz2" | "cab"
        | "arj" | "lha" | "lzh" | "cpio" | "iso" | "deb" | "rpm" => {
            ("file-archive", "package-x-generic", "archive", false)
        }
        "pdf" => ("file-pdf", "application-pdf", "document", true),
        "epub" | "djvu" => ("file-text", "x-office-document", "document", true),
        "doc" | "docx" | "odt" | "rtf" => ("file-text", "x-office-document", "document", true),
        "xls" | "xlsx" | "ods" | "csv" => ("file-text", "x-office-spreadsheet", "document", true),
        "ppt" | "pptx" | "odp" => ("file-text", "x-office-presentation", "document", true),
        "md" | "txt" | "json" | "toml" | "yaml" | "yml" | "log" | "ini" | "conf" | "cfg"
        | "xml" => ("file-text", "text-x-generic", "text", false),
        "ttf" | "otf" | "woff" | "woff2" => ("file", "font-x-generic", "font", true),
        "desktop" => ("file", "application-x-desktop", "application", false),
        "appimage" | "exe" | "msi" => ("file", "application-x-executable", "application", false),
        _ => ("file", "text-x-generic", "file", false),
    }
}

/// Names listed in a folder's `.hidden` file (one per line) are hidden too,
/// like in Nautilus and Dolphin.
fn dot_hidden(dir: &Path) -> HashSet<String> {
    fs::read_to_string(dir.join(".hidden"))
        .map(|s| {
            s.lines()
                .map(|l| l.trim().to_string())
                .filter(|l| !l.is_empty())
                .collect()
        })
        .unwrap_or_default()
}

/// Builds an entry for `path` (symlinks are described as links but sized
/// and typed by their target when it exists).
pub fn entry_for(path: &Path, name: &str, hidden_names: &HashSet<String>) -> Option<Entry> {
    let lmeta = fs::symlink_metadata(path).ok()?;
    let is_symlink = lmeta.file_type().is_symlink();
    let meta = if is_symlink {
        fs::metadata(path).unwrap_or(lmeta)
    } else {
        lmeta
    };
    let is_dir = meta.is_dir();
    let (icon, system_icon, category, thumbable) = classify(name, is_dir);
    Some(Entry {
        name: name.to_string(),
        name_lower: name.to_lowercase(),
        path: path.to_string_lossy().to_string(),
        is_dir,
        is_symlink,
        is_hidden: name.starts_with('.') || hidden_names.contains(name),
        size: if is_dir { 0 } else { meta.len() },
        modified: meta.mtime(),
        icon,
        system_icon,
        category,
        thumbable,
        detail: String::new(),
        display_name: name.to_string(),
    })
}

/// Lists `dir`. `cancelled` is polled so a superseded scan stops early.
pub fn scan(dir: &Path, cancelled: &dyn Fn() -> bool) -> std::io::Result<Vec<Entry>> {
    let hidden = dot_hidden(dir);
    let mut out = Vec::new();
    for e in fs::read_dir(dir)? {
        if cancelled() {
            return Err(std::io::Error::new(
                std::io::ErrorKind::Interrupted,
                "cancelled",
            ));
        }
        let Ok(e) = e else { continue };
        // Non-UTF-8 names are shown lossily rather than silently dropped.
        let name = e.file_name().to_string_lossy().to_string();
        if let Some(entry) = entry_for(&e.path(), &name, &hidden) {
            out.push(entry);
        }
    }
    Ok(out)
}

/// Natural, case-insensitive comparison: "file2" < "file10", "a" == "A".
///
/// No allocations: digit runs are compared as byte slices with the leading
/// zeros stripped, which is exactly what the old `String` copies produced.
pub fn natural_cmp(a: &str, b: &str) -> Ordering {
    // Peek carries the byte index, so digit runs can be sliced for free.
    let mut ai = a.char_indices().peekable();
    let mut bi = b.char_indices().peekable();
    loop {
        match (ai.peek().copied(), bi.peek().copied()) {
            (None, None) => return a.cmp(b),
            (None, Some(_)) => return Ordering::Less,
            (Some(_), None) => return Ordering::Greater,
            (Some((_, x)), Some((_, y))) if x.is_ascii_digit() && y.is_ascii_digit() => {
                let (sa, _) = ai.next().unwrap();
                let (sb, _) = bi.next().unwrap();
                // Consume both runs; ASCII digits are one byte each, so the
                // next byte index is exactly where the run ends.
                let (mut ea, mut eb) = (a.len(), b.len());
                while let Some(&(idx, c)) = ai.peek() {
                    if !c.is_ascii_digit() {
                        ea = idx;
                        break;
                    }
                    ai.next();
                }
                while let Some(&(idx, c)) = bi.peek() {
                    if !c.is_ascii_digit() {
                        eb = idx;
                        break;
                    }
                    bi.next();
                }
                let ta = a[sa..ea].trim_start_matches('0');
                let tb = b[sb..eb].trim_start_matches('0');
                let ord = ta.len().cmp(&tb.len()).then_with(|| ta.cmp(tb));
                if ord != Ordering::Equal {
                    return ord;
                }
            }
            (_, _) => {
                // Digits absent or equal runs: compare one character each.
                let ((_, x), (_, y)) = (ai.next().unwrap(), bi.next().unwrap());
                let lx = x.to_lowercase().next().unwrap_or(x);
                let ly = y.to_lowercase().next().unwrap_or(y);
                if lx != ly {
                    return lx.cmp(&ly);
                }
            }
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct SortSpec {
    /// "none" | "name" | "modified" | "size" | "type"
    pub group_by: String,
    pub group_ascending: bool,
    /// "name" | "modified" | "size" | "type"
    pub key: String,
    pub ascending: bool,
    /// "first" | "last" | "mixed"
    pub folders: String,
}

impl Default for SortSpec {
    fn default() -> Self {
        SortSpec {
            group_by: "none".into(),
            group_ascending: true,
            key: "name".into(),
            ascending: true,
            folders: "first".into(),
        }
    }
}

pub fn name_group_label(name: &str) -> String {
    let trimmed = name.trim_start_matches('.');
    if trimmed.is_empty() {
        return "Other".into();
    }
    let first = trimmed.chars().next().unwrap();
    if first.is_ascii_digit() {
        "0\u{2013}9".into()
    } else if first.is_alphabetic() {
        first.to_uppercase().collect()
    } else {
        "Other".into()
    }
}

fn compare_name_group(la: &str, lb: &str, ascending: bool) -> Ordering {
    let rank = |l: &str| -> u8 {
        if l == "0\u{2013}9" || l == "0-9" {
            1
        } else if l == "Other" {
            2
        } else {
            0
        }
    };
    let ord = rank(la).cmp(&rank(lb)).then_with(|| natural_cmp(la, lb));
    if ascending {
        ord
    } else {
        ord.reverse()
    }
}

pub fn size_group_label(entry: &Entry) -> String {
    if entry.is_dir {
        "Folders".into()
    } else if entry.size == 0 {
        "Empty (0 B)".into()
    } else if entry.size < 1024 * 1024 {
        "Small (< 1 MiB)".into()
    } else if entry.size < 100 * 1024 * 1024 {
        "Medium (1 MiB \u{2013} <100 MiB)".into()
    } else if entry.size < 1024 * 1024 * 1024 {
        "Large (100 MiB \u{2013} <1 GiB)".into()
    } else {
        "Huge (\u{2265} 1 GiB)".into()
    }
}

fn size_bucket_rank(entry: &Entry) -> u8 {
    if entry.is_dir {
        0
    } else if entry.size == 0 {
        1
    } else if entry.size < 1024 * 1024 {
        2
    } else if entry.size < 100 * 1024 * 1024 {
        3
    } else if entry.size < 1024 * 1024 * 1024 {
        4
    } else {
        5
    }
}

fn compare_size_group(a: &Entry, b: &Entry, spec: &SortSpec) -> Ordering {
    if a.is_dir && b.is_dir {
        return Ordering::Equal;
    }
    if a.is_dir != b.is_dir {
        return match spec.folders.as_str() {
            "last" => {
                if a.is_dir {
                    Ordering::Greater
                } else {
                    Ordering::Less
                }
            }
            "mixed" => {
                let ord = if a.is_dir {
                    Ordering::Less
                } else {
                    Ordering::Greater
                };
                if spec.group_ascending {
                    ord
                } else {
                    ord.reverse()
                }
            }
            _ => {
                if a.is_dir {
                    Ordering::Less
                } else {
                    Ordering::Greater
                }
            }
        };
    }
    let ra = size_bucket_rank(a);
    let rb = size_bucket_rank(b);
    let ord = ra.cmp(&rb);
    if spec.group_ascending {
        ord
    } else {
        ord.reverse()
    }
}

pub fn type_group_label(category: &str, is_dir: bool) -> String {
    if is_dir || category == "folder" {
        "Folders".into()
    } else {
        match category {
            "document" => "Documents".into(),
            "image" => "Images".into(),
            "video" => "Videos".into(),
            "audio" => "Audio".into(),
            "code" => "Code & Scripts".into(),
            "archive" => "Archives".into(),
            "text" => "Plain Text".into(),
            "font" => "Fonts".into(),
            "application" => "Applications".into(),
            _ => "Other Files".into(),
        }
    }
}

fn compare_type_group(la: &str, lb: &str, ascending: bool) -> Ordering {
    let ord = natural_cmp(la, lb);
    if ascending {
        ord
    } else {
        ord.reverse()
    }
}

pub fn group_label(entry: &Entry, group_by: &str, ctx: &DateGroupContext) -> String {
    match group_by {
        "name" => name_group_label(&entry.name),
        "modified" => date_group_label(entry.modified, ctx),
        "size" => size_group_label(entry),
        "type" => type_group_label(entry.category, entry.is_dir),
        _ => String::new(),
    }
}

fn compare_group_buckets(
    a: &Entry,
    b: &Entry,
    spec: &SortSpec,
    ctx: &DateGroupContext,
) -> Ordering {
    match spec.group_by.as_str() {
        "name" => {
            let la = name_group_label(&a.name);
            let lb = name_group_label(&b.name);
            compare_name_group(&la, &lb, spec.group_ascending)
        }
        "modified" => {
            let ka = date_bucket_key(a.modified, ctx);
            let kb = date_bucket_key(b.modified, ctx);
            compare_date_group_keys(ka, kb, spec.group_ascending)
        }
        "size" => compare_size_group(a, b, spec),
        "type" => {
            let la = type_group_label(a.category, a.is_dir);
            let lb = type_group_label(b.category, b.is_dir);
            compare_type_group(&la, &lb, spec.group_ascending)
        }
        _ => Ordering::Equal,
    }
}

fn compare_intra_bucket(a: &Entry, b: &Entry, spec: &SortSpec) -> Ordering {
    let folder_cmp = || match spec.folders.as_str() {
        "mixed" => Ordering::Equal,
        "last" if a.is_dir != b.is_dir => a.is_dir.cmp(&b.is_dir),
        _ if a.is_dir != b.is_dir => b.is_dir.cmp(&a.is_dir),
        _ => Ordering::Equal,
    };

    let f = folder_cmp();
    if f != Ordering::Equal {
        return f;
    }

    let by_name = || natural_cmp(&a.name, &b.name);

    let ord = match spec.key.as_str() {
        "name" => by_name(),
        "modified" => {
            let a_unknown = checked_localtime(a.modified).is_none();
            let b_unknown = checked_localtime(b.modified).is_none();
            match (a_unknown, b_unknown) {
                (true, true) => Ordering::Equal,
                (true, false) => Ordering::Greater,
                (false, true) => Ordering::Less,
                (false, false) => {
                    let m = b.modified.cmp(&a.modified);
                    if spec.ascending {
                        m
                    } else {
                        m.reverse()
                    }
                }
            }
        }
        "size" => {
            let s = a.size.cmp(&b.size).then_with(by_name);
            if spec.ascending {
                s
            } else {
                s.reverse()
            }
        }
        "type" => {
            let t = a
                .category
                .cmp(b.category)
                .then_with(|| extension(&a.name).cmp(&extension(&b.name)))
                .then_with(by_name);
            if spec.ascending {
                t
            } else {
                t.reverse()
            }
        }
        _ => by_name(),
    };

    let ord = if spec.key == "name" {
        if spec.ascending {
            ord
        } else {
            ord.reverse()
        }
    } else {
        ord
    };

    ord.then_with(by_name).then_with(|| a.path.cmp(&b.path))
}

pub fn compare(a: &Entry, b: &Entry, spec: &SortSpec) -> Ordering {
    compare_with_ctx(a, b, spec, &DateGroupContext::new(0))
}

pub fn compare_with_ctx(a: &Entry, b: &Entry, spec: &SortSpec, ctx: &DateGroupContext) -> Ordering {
    if spec.group_by != "none" && !spec.group_by.is_empty() {
        let group_ord = compare_group_buckets(a, b, spec, ctx);
        if group_ord != Ordering::Equal {
            return group_ord;
        }
    }
    compare_intra_bucket(a, b, spec)
}

/// Constant-time civil calendar calculation (Howard Hinnant's algorithm).
/// Converts (year, month 1..=12, day 1..=31) to day count from civil epoch (1970-01-01 = 0).
#[inline]
pub fn days_from_civil(mut y: i32, m: u32, d: u32) -> i64 {
    y -= if m <= 2 { 1 } else { 0 };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = (y - era * 400) as u32;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era as i64 * 146097 + doe as i64 - 719468
}

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub struct DateGroupContext {
    pub now_ts: i64,
    pub year: i32,
    pub mon: i32,
    pub mday: i32,
    pub iso_wday: i32,
    pub civil_days: i64,
}

impl DateGroupContext {
    pub fn new(now_ts: i64) -> Self {
        let now = if now_ts != 0 {
            now_ts
        } else {
            (unsafe { libc::time(std::ptr::null_mut()) }) as i64
        };
        let t_now = now as libc::time_t;
        let mut tm_now: libc::tm = unsafe { std::mem::zeroed() };
        let ret = unsafe { libc::localtime_r(&t_now, &mut tm_now) };
        if ret.is_null() {
            return Self::from_civil(1970, 1, 1, 4, now);
        }
        let year = tm_now.tm_year + 1900;
        let mon = tm_now.tm_mon + 1;
        let mday = tm_now.tm_mday;
        let iso_wday = if tm_now.tm_wday == 0 {
            7
        } else {
            tm_now.tm_wday
        };
        let civil_days = days_from_civil(year, mon as u32, mday as u32);
        Self {
            now_ts: now,
            year,
            mon,
            mday,
            iso_wday,
            civil_days,
        }
    }

    pub fn from_civil(year: i32, mon: i32, mday: i32, iso_wday: i32, now_ts: i64) -> Self {
        let civil_days = days_from_civil(year, mon as u32, mday as u32);
        Self {
            now_ts,
            year,
            mon,
            mday,
            iso_wday,
            civil_days,
        }
    }
}

impl Default for DateGroupContext {
    fn default() -> Self {
        Self::new(0)
    }
}

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub struct DateBucketKey {
    pub order: i64,
    pub is_unknown: bool,
}

impl DateBucketKey {
    pub const UNKNOWN: Self = Self {
        order: i64::MAX,
        is_unknown: true,
    };
}

fn checked_localtime(ts: i64) -> Option<libc::tm> {
    if ts == 0 {
        return None;
    }
    let t = ts as libc::time_t;
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    let ret = unsafe { libc::localtime_r(&t, &mut tm) };
    if ret.is_null() {
        None
    } else {
        Some(tm)
    }
}

pub fn date_bucket_key(ts: i64, ctx: &DateGroupContext) -> DateBucketKey {
    let Some(tm) = checked_localtime(ts) else {
        return DateBucketKey::UNKNOWN;
    };
    let year = tm.tm_year + 1900;
    let mon = tm.tm_mon + 1;
    let mday = tm.tm_mday;
    let civil_days = days_from_civil(year, mon as u32, mday as u32);
    let days_diff = ctx.civil_days - civil_days;

    if days_diff < 0 {
        DateBucketKey {
            order: -1,
            is_unknown: false,
        }
    } else if days_diff == 0 {
        DateBucketKey {
            order: 0,
            is_unknown: false,
        }
    } else if days_diff == 1 {
        DateBucketKey {
            order: 1,
            is_unknown: false,
        }
    } else if days_diff < ctx.iso_wday as i64 {
        DateBucketKey {
            order: 2,
            is_unknown: false,
        }
    } else if days_diff < (ctx.iso_wday + 7) as i64 {
        DateBucketKey {
            order: 3,
            is_unknown: false,
        }
    } else if year == ctx.year && mon == ctx.mon {
        DateBucketKey {
            order: 4,
            is_unknown: false,
        }
    } else {
        let months_ago = ((ctx.year * 12 + ctx.mon) - (year * 12 + mon)) as i64;
        DateBucketKey {
            order: 10 + months_ago.max(0),
            is_unknown: false,
        }
    }
}

// Compile-time verified NUL-terminated CStr for strftime, compatible with Rust 1.75+.
// ASCII for "%B %Y\0"
const MONTH_YEAR_FMT_BYTES: &[u8; 6] = &[b'%', b'B', b' ', b'%', b'Y', 0];
const MONTH_YEAR_FMT_CSTR: &std::ffi::CStr =
    match std::ffi::CStr::from_bytes_with_nul(MONTH_YEAR_FMT_BYTES) {
        Ok(c) => c,
        Err(_) => panic!("static date format must be NUL-terminated"),
    };

fn format_month_year(tm: &libc::tm) -> String {
    let mut buf = [0u8; 64];
    let len = unsafe {
        libc::strftime(
            buf.as_mut_ptr() as *mut libc::c_char,
            buf.len(),
            MONTH_YEAR_FMT_CSTR.as_ptr(),
            tm,
        )
    };
    if len > 0 {
        if let Ok(s) = std::str::from_utf8(&buf[..len]) {
            return s.to_string();
        }
    }
    const MONTHS: [&str; 12] = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
    ];
    let month_name = MONTHS[tm.tm_mon.clamp(0, 11) as usize];
    let year = tm.tm_year + 1900;
    format!("{} {}", month_name, year)
}

pub fn date_group_label(ts: i64, ctx: &DateGroupContext) -> String {
    let Some(tm) = checked_localtime(ts) else {
        return "Unknown date".into();
    };
    let year = tm.tm_year + 1900;
    let mon = tm.tm_mon + 1;
    let mday = tm.tm_mday;
    let civil_days = days_from_civil(year, mon as u32, mday as u32);
    let days_diff = ctx.civil_days - civil_days;

    if days_diff < 0 {
        "Future".into()
    } else if days_diff == 0 {
        "Today".into()
    } else if days_diff == 1 {
        "Yesterday".into()
    } else if days_diff < ctx.iso_wday as i64 {
        "Earlier this week".into()
    } else if days_diff < (ctx.iso_wday + 7) as i64 {
        "Last week".into()
    } else if year == ctx.year && mon == ctx.mon {
        "Earlier this month".into()
    } else {
        format_month_year(&tm)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DateGroupInfo {
    pub label: String,
    pub order: i64,
}

pub fn date_group_info(ts: i64, now_ts: i64) -> DateGroupInfo {
    let ctx = DateGroupContext::new(now_ts);
    let key = date_bucket_key(ts, &ctx);
    let label = date_group_label(ts, &ctx);
    DateGroupInfo {
        label,
        order: key.order,
    }
}

#[inline]
pub fn compare_date_group_keys(ka: DateBucketKey, kb: DateBucketKey, ascending: bool) -> Ordering {
    match (ka.is_unknown, kb.is_unknown) {
        (true, true) => Ordering::Equal,
        (true, false) => Ordering::Greater, // Unknown LAST in both directions
        (false, true) => Ordering::Less,    // Unknown LAST in both directions
        (false, false) => {
            let cmp = ka.order.cmp(&kb.order);
            if ascending {
                cmp
            } else {
                cmp.reverse()
            }
        }
    }
}

pub fn sort<T: EntryLike>(entries: &mut [T], spec: &SortSpec) {
    sort_with_ctx(entries, spec, &DateGroupContext::new(0));
}

pub fn sort_with_ctx<T: EntryLike>(entries: &mut [T], spec: &SortSpec, ctx: &DateGroupContext) {
    entries.sort_by(|a, b| compare_with_ctx(a.as_entry(), b.as_entry(), spec, ctx));
}

/// Compared as an [Entry] regardless of how it is stored (owned or shared
/// behind an `Arc`, which keeps model refilters from re-cloning every row).
pub trait EntryLike {
    fn as_entry(&self) -> &Entry;
}

impl EntryLike for Entry {
    fn as_entry(&self) -> &Entry {
        self
    }
}

impl EntryLike for std::sync::Arc<Entry> {
    fn as_entry(&self) -> &Entry {
        self.as_ref()
    }
}

/// Filter text as compared against names: trimmed and lowercased once, so
/// listing thousands of entries does not re-lowercase per entry.
pub fn lower_filter(filter: &str) -> String {
    filter.trim().to_lowercase()
}

/// Which entries are shown: hidden files only when asked, unless the
/// filter starts with a dot (so ".bashrc" can be found, issue #12).
/// `filter_lower` comes from `lower_filter`.
pub fn visible(e: &Entry, show_hidden: bool, filter_lower: &str) -> bool {
    if e.is_hidden && !show_hidden && !filter_lower.starts_with('.') {
        return false;
    }
    filter_lower.is_empty() || e.name_lower.contains(filter_lower)
}

/// One step that turns the old list into the new one.
#[derive(Debug, PartialEq)]
pub enum Change<T> {
    Remove { at: usize, count: usize },
    Insert { at: usize, items: Vec<T> },
    Update { at: usize, item: T },
}

/// Edit script from `old` to `new` (both sorted the same way, keyed by
/// path). Applying the changes in order to `old` yields `new`.
pub fn diff<T: EntryLike + Clone + PartialEq>(old: &[T], new: &[T]) -> Vec<Change<T>> {
    let new_keys: HashSet<&str> = new.iter().map(|e| e.as_entry().path.as_str()).collect();
    let mut pending_old: HashSet<&str> = old.iter().map(|e| e.as_entry().path.as_str()).collect();
    let mut changes: Vec<Change<T>> = Vec::new();
    let (mut i, mut j, mut k) = (0usize, 0usize, 0usize);
    let push_remove = |changes: &mut Vec<Change<T>>, at: usize| {
        if let Some(Change::Remove { at: a, count }) = changes.last_mut() {
            if *a == at {
                *count += 1;
                return;
            }
        }
        changes.push(Change::Remove { at, count: 1 });
    };
    while i < old.len() || j < new.len() {
        if i < old.len() && j < new.len() && old[i].as_entry().path == new[j].as_entry().path {
            if old[i].as_entry() != new[j].as_entry() {
                changes.push(Change::Update {
                    at: k,
                    item: new[j].clone(),
                });
            }
            pending_old.remove(old[i].as_entry().path.as_str());
            i += 1;
            j += 1;
            k += 1;
        } else if i < old.len()
            && (j >= new.len()
                || !new_keys.contains(old[i].as_entry().path.as_str())
                // Both lists hold new[j] and old[i], just in another order:
                // drop old[i] here; it is inserted again at its new spot.
                || pending_old.contains(new[j].as_entry().path.as_str()))
        {
            pending_old.remove(old[i].as_entry().path.as_str());
            push_remove(&mut changes, k);
            i += 1;
        } else {
            let at = k;
            let item = new[j].clone();
            if let Some(Change::Insert { at: a, items }) = changes.last_mut() {
                if *a + items.len() == at {
                    items.push(item);
                    j += 1;
                    k += 1;
                    continue;
                }
            }
            changes.push(Change::Insert {
                at,
                items: vec![item],
            });
            j += 1;
            k += 1;
        }
    }
    changes
}

/// Applies `changes` to `list` (used by tests and by the model mirror).
pub fn apply<T: EntryLike + Clone>(list: &mut Vec<T>, changes: &[Change<T>]) {
    for c in changes {
        match c {
            Change::Remove { at, count } => {
                list.drain(*at..*at + *count);
            }
            Change::Insert { at, items } => {
                for (n, it) in items.iter().enumerate() {
                    list.insert(at + n, it.clone());
                }
            }
            Change::Update { at, item } => list[*at] = item.clone(),
        }
    }
}

/// For search results with the same name, show "parent/name" instead.
pub fn disambiguate(entries: &mut [Entry]) {
    let mut counts = std::collections::HashMap::new();
    for e in entries.iter() {
        *counts.entry(e.name.clone()).or_insert(0usize) += 1;
    }
    for e in entries.iter_mut() {
        if counts.get(&e.name).copied().unwrap_or(0) > 1 {
            let parent = Path::new(&e.path)
                .parent()
                .and_then(|p| p.file_name())
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_default();
            e.display_name = format!("{}/{}", parent, e.name);
        }
    }
}

/// [`disambiguate`] for shared entries. Search results arrive in batches, so
/// only names that just became ambiguous are rebuilt; the rest keep their
/// `Arc` (previously every batch re-copying every entry).
pub fn disambiguate_shared(entries: &mut [Arc<Entry>]) {
    // Owned keys: the map must not borrow into `entries` — later batches
    // replace shared entries in place.
    let mut counts = std::collections::HashMap::<String, usize>::new();
    for e in entries.iter() {
        *counts.entry(e.name.clone()).or_insert(0usize) += 1;
    }
    for e in entries.iter_mut() {
        if counts.get(&e.name).copied().unwrap_or(0) <= 1 {
            continue;
        }
        // Already rewritten ("parent/name" always has a slash; plain names
        // cannot contain one), so this batch adds nothing to do.
        if e.display_name != e.name {
            continue;
        }
        let parent = Path::new(&e.path)
            .parent()
            .and_then(|p| p.file_name())
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        *e = Arc::new(Entry {
            display_name: format!("{}/{}", parent, e.name),
            ..(**e).clone()
        });
    }
}

/// Helper for building entries for arbitrary paths (search, recent, starred).
pub fn entries_for_paths(paths: &[PathBuf]) -> Vec<Entry> {
    let empty = HashSet::new();
    paths
        .iter()
        .filter_map(|p| {
            let name = p.file_name()?.to_string_lossy().to_string();
            let mut e = entry_for(p, &name, &empty)?;
            e.detail = p
                .parent()
                .map(|x| x.to_string_lossy().to_string())
                .unwrap_or_default();
            Some(e)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn e(name: &str, is_dir: bool, size: u64) -> Entry {
        let (icon, system_icon, category, thumbable) = classify(name, is_dir);
        Entry {
            name: name.into(),
            name_lower: name.to_lowercase(),
            path: format!("/d/{}", name),
            is_dir,
            is_symlink: false,
            is_hidden: name.starts_with('.'),
            size,
            modified: 0,
            icon,
            system_icon,
            category,
            thumbable,
            detail: String::new(),
            display_name: name.into(),
        }
    }

    #[test]
    fn natural_order() {
        let mut v = vec!["file10", "File2", "file1", "a", "B", "file02b"];
        v.sort_by(|a, b| natural_cmp(a, b));
        assert_eq!(v, vec!["a", "B", "file1", "File2", "file02b", "file10"]);
    }

    #[test]
    fn folders_first_and_sorting() {
        let mut v = vec![
            e("b.txt", false, 5),
            e("Zdir", true, 0),
            e("a.txt", false, 9),
            e("adir", true, 0),
        ];
        sort(&mut v, &SortSpec::default());
        let names: Vec<_> = v.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(names, vec!["adir", "Zdir", "a.txt", "b.txt"]);
        sort(
            &mut v,
            &SortSpec {
                key: "size".into(),
                ascending: false,
                folders: "last".into(),
                ..SortSpec::default()
            },
        );
        let names: Vec<_> = v.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(names, vec!["a.txt", "b.txt", "Zdir", "adir"]);
    }

    #[test]
    fn date_group_buckets_deterministic() {
        // Thursday 2026-11-12 12:00:00 UTC = 1794484800
        let now_utc = 1794484800i64;
        let ctx = DateGroupContext::new(now_utc);

        let today = date_bucket_key(now_utc, &ctx);
        assert_eq!(today.order, 0);
        assert_eq!(date_group_label(now_utc, &ctx), "Today");

        let yesterday = date_bucket_key(now_utc - 86400, &ctx);
        assert_eq!(yesterday.order, 1);
        assert_eq!(date_group_label(now_utc - 86400, &ctx), "Yesterday");

        let earlier_this_week = date_bucket_key(now_utc - 86400 * 2, &ctx);
        assert_eq!(earlier_this_week.order, 2);
        assert_eq!(
            date_group_label(now_utc - 86400 * 2, &ctx),
            "Earlier this week"
        );

        let last_week = date_bucket_key(now_utc - 86400 * 5, &ctx);
        assert_eq!(last_week.order, 3);
        assert_eq!(date_group_label(now_utc - 86400 * 5, &ctx), "Last week");

        let future = date_bucket_key(now_utc + 86400 * 2, &ctx);
        assert_eq!(future.order, -1);
        assert_eq!(date_group_label(now_utc + 86400 * 2, &ctx), "Future");

        // Valid historical negative timestamp (1960-01-01 12:00:00 UTC = -315604800)
        let hist_ts = -315604800i64;
        let hist_key = date_bucket_key(hist_ts, &ctx);
        assert!(!hist_key.is_unknown);
        assert!(hist_key.order >= 10);
        let hist_lbl = date_group_label(hist_ts, &ctx);
        assert!(hist_lbl.contains("1960"), "historical label: {}", hist_lbl);

        // Unknown / sentinel 0
        let unknown0 = date_bucket_key(0, &ctx);
        assert!(unknown0.is_unknown);
        assert_eq!(date_group_label(0, &ctx), "Unknown date");

        // Extreme invalid timestamps must fail cleanly without crashing or hanging
        let extreme_max = date_bucket_key(i64::MAX, &ctx);
        assert!(extreme_max.is_unknown);
        assert_eq!(date_group_label(i64::MAX, &ctx), "Unknown date");

        let extreme_min = date_bucket_key(i64::MIN, &ctx);
        assert!(extreme_min.is_unknown);
        assert_eq!(date_group_label(i64::MIN, &ctx), "Unknown date");

        // Month boundary: Nov 1st 12:00 UTC (Yesterday is Oct 31st)
        // 2026-11-01 12:00:00 UTC = 1793534400
        let nov1_ts = 1793534400i64;
        let nov1_ctx = DateGroupContext::new(nov1_ts);
        let oct31_ts = nov1_ts - 86400; // Oct 31
        let oct31_key = date_bucket_key(oct31_ts, &nov1_ctx);
        assert_eq!(oct31_key.order, 1);
        assert_eq!(date_group_label(oct31_ts, &nov1_ctx), "Yesterday");

        // Leap year: 2024-03-01 12:00 UTC (Yesterday is Feb 29)
        // 2024-03-01 12:00:00 UTC = 1709294400
        let mar1_2024 = 1709294400i64;
        let leap_ctx = DateGroupContext::new(mar1_2024);
        let feb29_ts = mar1_2024 - 86400; // Feb 29 2024
        let feb29_key = date_bucket_key(feb29_ts, &leap_ctx);
        assert_eq!(feb29_key.order, 1);
        assert_eq!(date_group_label(feb29_ts, &leap_ctx), "Yesterday");
    }

    #[test]
    fn date_group_unknown_last_in_both_sort_directions() {
        let t_today = 1794484800i64; // Thursday 2026-11-12
        let t_yesterday = t_today - 86400;
        let t_future = t_today + 86400;

        let f_future = Entry {
            modified: t_future,
            ..e("future.txt", false, 1)
        };
        let f_today = Entry {
            modified: t_today,
            ..e("today.txt", false, 1)
        };
        let f_yesterday = Entry {
            modified: t_yesterday,
            ..e("yesterday.txt", false, 1)
        };
        let f_unknown1 = Entry {
            modified: 0,
            ..e("unknown1.txt", false, 1)
        };
        let f_unknown2 = Entry {
            modified: i64::MAX,
            ..e("unknown2.txt", false, 1)
        };

        let ctx = DateGroupContext::new(t_today);
        let items = vec![
            f_unknown1.clone(),
            f_yesterday.clone(),
            f_future.clone(),
            f_unknown2.clone(),
            f_today.clone(),
        ];

        // 1. Ascending sort (newest first: Future, Today, Yesterday)
        let mut asc = items.clone();
        sort_with_ctx(
            &mut asc,
            &SortSpec {
                group_by: "modified".into(),
                group_ascending: true,
                key: "modified".into(),
                ascending: true,
                folders: "first".into(),
            },
            &ctx,
        );
        let asc_names: Vec<_> = asc.iter().map(|x| x.name.as_str()).collect();
        // Future, Today, Yesterday, then unknown1, unknown2 at the very end
        assert_eq!(asc_names[0], "future.txt");
        assert_eq!(asc_names[1], "today.txt");
        assert_eq!(asc_names[2], "yesterday.txt");
        assert_eq!(&asc_names[3..], &["unknown1.txt", "unknown2.txt"]);

        // 2. Descending sort (oldest first: Yesterday, Today, Future): Unknown MUST STILL BE LAST!
        let mut desc = items.clone();
        sort_with_ctx(
            &mut desc,
            &SortSpec {
                group_by: "modified".into(),
                group_ascending: false,
                key: "modified".into(),
                ascending: false,
                folders: "first".into(),
            },
            &ctx,
        );
        let desc_names: Vec<_> = desc.iter().map(|x| x.name.as_str()).collect();
        // Yesterday, Today, Future, then unknown1, unknown2 at the very end
        assert_eq!(desc_names[0], "yesterday.txt");
        assert_eq!(desc_names[1], "today.txt");
        assert_eq!(desc_names[2], "future.txt");
        assert_eq!(&desc_names[3..], &["unknown1.txt", "unknown2.txt"]);
    }

    #[test]
    fn date_group_intra_bucket_timestamp_ordering() {
        let t_today = 1794484800i64; // Thursday 2026-11-12
        let ctx = DateGroupContext::new(t_today);

        let f_earlier = Entry {
            modified: t_today - 3600,
            ..e("earlier.txt", false, 1)
        };
        let f_later = Entry {
            modified: t_today - 60,
            ..e("later.txt", false, 1)
        };
        let items = vec![f_earlier.clone(), f_later.clone()];

        // Ascending = newest first within same bucket
        let mut asc = items.clone();
        sort_with_ctx(
            &mut asc,
            &SortSpec {
                group_by: "modified".into(),
                group_ascending: true,
                key: "modified".into(),
                ascending: true,
                folders: "first".into(),
            },
            &ctx,
        );
        let asc_names: Vec<_> = asc.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(asc_names, vec!["later.txt", "earlier.txt"]);

        // Descending = oldest first within same bucket
        let mut desc = items.clone();
        sort_with_ctx(
            &mut desc,
            &SortSpec {
                group_by: "modified".into(),
                group_ascending: true,
                key: "modified".into(),
                ascending: false,
                folders: "first".into(),
            },
            &ctx,
        );
        let desc_names: Vec<_> = desc.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(desc_names, vec!["earlier.txt", "later.txt"]);
    }

    #[test]
    fn date_group_folders_policy_within_each_group() {
        let t_today = 1794484800i64;
        let t_yesterday = t_today - 86400;
        let ctx = DateGroupContext::new(t_today);

        let d_today = Entry {
            modified: t_today,
            ..e("dir_today", true, 0)
        };
        let f_today = Entry {
            modified: t_today,
            ..e("file_today.txt", false, 1)
        };
        let d_yest = Entry {
            modified: t_yesterday,
            ..e("dir_yest", true, 0)
        };
        let f_yest = Entry {
            modified: t_yesterday,
            ..e("file_yest.txt", false, 1)
        };

        let items = vec![
            f_yest.clone(),
            d_today.clone(),
            f_today.clone(),
            d_yest.clone(),
        ];

        // Folders FIRST (ascending = newest groups first):
        let mut list_first = items.clone();
        sort_with_ctx(
            &mut list_first,
            &SortSpec {
                group_by: "modified".into(),
                group_ascending: true,
                key: "modified".into(),
                ascending: true,
                folders: "first".into(),
            },
            &ctx,
        );
        let names: Vec<_> = list_first.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(
            names,
            vec!["dir_today", "file_today.txt", "dir_yest", "file_yest.txt"]
        );

        // Folders LAST (ascending = newest groups first):
        let mut list_last = items.clone();
        sort_with_ctx(
            &mut list_last,
            &SortSpec {
                group_by: "modified".into(),
                group_ascending: true,
                key: "modified".into(),
                ascending: true,
                folders: "last".into(),
            },
            &ctx,
        );
        let names_last: Vec<_> = list_last.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(
            names_last,
            vec!["file_today.txt", "dir_today", "file_yest.txt", "dir_yest"]
        );
    }

    #[test]
    fn name_group_unicode_and_dots_and_digits() {
        assert_eq!(name_group_label("apple"), "A");
        assert_eq!(name_group_label(".bashrc"), "B");
        assert_eq!(name_group_label(".config"), "C");
        assert_eq!(name_group_label("..hidden"), "H");
        assert_eq!(name_group_label("."), "Other");
        assert_eq!(name_group_label(".."), "Other");
        assert_eq!(name_group_label("123"), "0\u{2013}9");
        assert_eq!(name_group_label("#tag"), "Other");
        assert_eq!(name_group_label("Zebra"), "Z");
    }

    #[test]
    fn size_group_boundaries() {
        let folder = e("mydir", true, 0);
        assert_eq!(size_group_label(&folder), "Folders");

        let empty = e("zero.txt", false, 0);
        assert_eq!(size_group_label(&empty), "Empty (0 B)");

        let small = e("small.txt", false, 512);
        assert_eq!(size_group_label(&small), "Small (< 1 MiB)");

        let medium = e("med.bin", false, 10 * 1024 * 1024);
        assert_eq!(
            size_group_label(&medium),
            "Medium (1 MiB \u{2013} <100 MiB)"
        );

        let large = e("big.iso", false, 500 * 1024 * 1024);
        assert_eq!(size_group_label(&large), "Large (100 MiB \u{2013} <1 GiB)");

        let huge = e("huge.tar", false, 2 * 1024 * 1024 * 1024);
        assert_eq!(size_group_label(&huge), "Huge (\u{2265} 1 GiB)");
    }

    #[test]
    fn independent_grouping_and_sorting_matrix() {
        let ctx = DateGroupContext::new(1794484800i64);
        let base_items = vec![
            Entry {
                name: "folder_a".into(),
                is_dir: true,
                size: 4096,
                modified: 1794484800, // Today
                category: "folder",
                path: "/tmp/folder_a".into(),
                ..e("folder_a", true, 4096)
            },
            Entry {
                name: "alpha.txt".into(),
                is_dir: false,
                size: 500,
                modified: 1794484800 - 86400, // Yesterday
                category: "document",
                path: "/tmp/alpha.txt".into(),
                ..e("alpha.txt", false, 500)
            },
            Entry {
                name: "bravo.txt".into(),
                is_dir: false,
                size: 2000,
                modified: 1794484800, // Today
                category: "document",
                path: "/tmp/bravo.txt".into(),
                ..e("bravo.txt", false, 2000)
            },
            Entry {
                name: "charlie.png".into(),
                is_dir: false,
                size: 100,
                modified: 1794484800, // Today
                category: "image",
                path: "/tmp/charlie.png".into(),
                ..e("charlie.png", false, 100)
            },
            Entry {
                name: "delta.unknown".into(),
                is_dir: false,
                size: 5000000,
                modified: 0, // Unknown date
                category: "other",
                path: "/tmp/delta.unknown".into(),
                ..e("delta.unknown", false, 5000000)
            },
        ];

        let group_options = ["none", "name", "modified", "size", "type"];
        let sort_options = ["name", "modified", "size", "type"];
        let folder_options = ["first", "last", "mixed"];

        for group_by in group_options {
            for sort_by in sort_options {
                for group_asc in [true, false] {
                    for sort_asc in [true, false] {
                        for folders in folder_options {
                            let spec = SortSpec {
                                group_by: group_by.into(),
                                group_ascending: group_asc,
                                key: sort_by.into(),
                                ascending: sort_asc,
                                folders: folders.into(),
                            };

                            let mut items = base_items.clone();
                            sort_with_ctx(&mut items, &spec, &ctx);

                            // 1. Total count preserved
                            assert_eq!(items.len(), base_items.len());

                            // 2. Strict pairwise total order agreement with compare_with_ctx
                            for i in 0..items.len() {
                                for j in (i + 1)..items.len() {
                                    let cmp = compare_with_ctx(&items[i], &items[j], &spec, &ctx);
                                    assert!(
                                        cmp != Ordering::Greater,
                                        "Order violation between index {} ({}) and {} ({}) under {:?}",
                                        i, items[i].name, j, items[j].name, spec
                                    );
                                }
                            }

                            // 3. Contiguous grouping verification when group_by != "none"
                            if group_by != "none" {
                                let mut seen_labels: Vec<String> = Vec::new();
                                let mut current_label = String::new();
                                for item in &items {
                                    let lbl = group_label(item, group_by, &ctx);
                                    if lbl != current_label {
                                        assert!(
                                            !seen_labels.contains(&lbl),
                                            "Group bucket '{}' is fragmented (not contiguous) under {:?}",
                                            lbl, spec
                                        );
                                        seen_labels.push(lbl.clone());
                                        current_label = lbl;
                                    }
                                }
                            }

                            // 4. Folder policy verification
                            if folders == "first" {
                                let mut seen_file = false;
                                for item in &items {
                                    if group_by == "none" {
                                        if !item.is_dir {
                                            seen_file = true;
                                        } else {
                                            assert!(!seen_file, "Folder appeared after file with folders=first: {:?}", spec);
                                        }
                                    }
                                }
                            } else if folders == "last" {
                                let mut seen_dir = false;
                                for item in &items {
                                    if group_by == "none" {
                                        if item.is_dir {
                                            seen_dir = true;
                                        } else {
                                            assert!(!seen_dir, "File appeared after folder with folders=last: {:?}", spec);
                                        }
                                    }
                                }
                            }

                            // 5. Unknown date is placed last in modified grouping
                            if group_by == "modified" {
                                let last_item = items.last().unwrap();
                                assert_eq!(
                                    group_label(last_item, "modified", &ctx),
                                    "Unknown date",
                                    "Unknown date must always be the last bucket regardless of direction: {:?}",
                                    spec
                                );
                            }
                        }
                    }
                }
            }
        }
    }

    #[test]
    fn hidden_filter_rules() {
        let dot = e(".bashrc", false, 1);
        assert!(!visible(&dot, false, ""));
        assert!(
            visible(&dot, false, ".bash"),
            "typing a dot finds dotfiles (issue #12)"
        );
        assert!(!visible(&dot, false, "bash"));
        assert!(visible(&dot, true, "bash"));
    }

    fn check_diff(old: Vec<Entry>, new: Vec<Entry>) {
        let changes = diff(&old, &new);
        let mut cur = old.clone();
        apply(&mut cur, &changes);
        assert_eq!(cur, new, "changes: {:?}", changes);
    }

    #[test]
    fn diff_cases() {
        let a = e("a", false, 1);
        let b = e("b", false, 1);
        let c = e("c", false, 1);
        let d = e("d", false, 1);
        check_diff(
            vec![a.clone(), b.clone(), c.clone()],
            vec![a.clone(), c.clone()],
        );
        check_diff(
            vec![a.clone(), c.clone()],
            vec![a.clone(), b.clone(), c.clone(), d.clone()],
        );
        check_diff(vec![], vec![a.clone(), b.clone()]);
        check_diff(vec![a.clone(), b.clone()], vec![]);
        let mut b2 = b.clone();
        b2.size = 99;
        check_diff(
            vec![a.clone(), b.clone(), c.clone()],
            vec![a.clone(), b2.clone(), c.clone()],
        );
        // Reordering (e.g. sorted by size and a file grew).
        check_diff(
            vec![a.clone(), b.clone(), c.clone(), d.clone()],
            vec![b.clone(), c.clone(), a.clone(), d.clone()],
        );
        check_diff(
            vec![a.clone(), b.clone(), c.clone(), d.clone()],
            vec![d.clone(), a.clone(), b.clone(), c.clone()],
        );
        check_diff(
            vec![a.clone(), b.clone(), c.clone(), d.clone()],
            vec![d.clone(), c.clone(), b.clone(), a.clone()],
        );
        // Removal + insertion are merged into ranges.
        let changes = diff(&[a.clone(), b.clone(), c.clone()], &[d.clone()]);
        assert!(changes.len() <= 2, "{:?}", changes);
    }

    #[test]
    fn diff_random_permutations() {
        // Deterministic pseudo-random lists; every diff must reproduce `new`.
        let mut seed = 12345u64;
        let mut rnd = || {
            seed ^= seed << 13;
            seed ^= seed >> 7;
            seed ^= seed << 17;
            seed
        };
        let pool: Vec<Entry> = (0..12).map(|i| e(&format!("f{}", i), false, i)).collect();
        for _ in 0..500 {
            let pick = |r: &mut dyn FnMut() -> u64| -> Vec<Entry> {
                let mut v: Vec<Entry> = pool.iter().filter(|_| r() % 2 == 0).cloned().collect();
                for x in v.iter_mut() {
                    if r() % 4 == 0 {
                        x.size += 100;
                    }
                }
                // Random order, like an arbitrary sort key change.
                for i in (1..v.len()).rev() {
                    let j = (r() % (i as u64 + 1)) as usize;
                    v.swap(i, j);
                }
                v
            };
            let old = pick(&mut rnd);
            let new = pick(&mut rnd);
            check_diff(old, new);
        }
    }

    #[test]
    fn diff_shared_rows_match_owned() {
        // The model stores shared entries; the diff script over `Arc`s must
        // behave exactly like the plain-Entry one.
        let old: Vec<Entry> = vec![e("a", false, 1), e("b", false, 2), e("c", false, 3)];
        let new: Vec<Entry> = vec![
            e("a", false, 1),
            e("b", false, 9),
            e("d", false, 4),
            e("c", false, 3),
        ];
        let shared = |v: &[Entry]| -> Vec<Arc<Entry>> { v.iter().cloned().map(Arc::new).collect() };
        assert_eq!(
            format!("{:?}", diff(&shared(&old), &shared(&new))),
            format!("{:?}", diff(&old, &new))
        );
        let mut cur = shared(&old);
        apply(&mut cur, &diff(&shared(&old), &shared(&new)));
        let plain: Vec<Entry> = cur.iter().map(|a| a.as_ref().clone()).collect();
        assert_eq!(plain, new);
    }

    #[test]
    fn disambiguate_shared_streams() {
        // First batch: two different files. Second batch: a duplicate name
        // arrives; both must end up as "parent/name", and batch 1's entry
        // (already prefixed) must keep its detail path intact.
        let mut a = e("report", false, 1);
        a.path = "/home/x/report".into();
        let mut b = e("notes", false, 2);
        b.path = "/home/y/notes".into();
        let mut all = vec![Arc::new(a), Arc::new(b)];
        disambiguate_shared(&mut all);
        assert_eq!(all[0].display_name, "report");
        assert_eq!(all[1].display_name, "notes");

        let mut c = e("report", false, 3);
        c.path = "/home/z/report".into();
        all.push(Arc::new(c));
        disambiguate_shared(&mut all);
        assert_eq!(all[0].display_name, "x/report");
        assert_eq!(all[2].display_name, "z/report");
        assert_eq!(all[0].name_lower, "report");
        // Names stayed unambiguous untouched.
        assert_eq!(all[1].display_name, "notes");
    }

    #[test]
    fn scans_real_folder() {
        let d = std::env::temp_dir().join(format!("loaf-list-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(d.join("sub")).unwrap();
        fs::write(d.join("x.png"), b"").unwrap();
        fs::write(d.join("secret"), b"").unwrap();
        fs::write(d.join(".hidden"), b"secret\n").unwrap();
        std::os::unix::fs::symlink(d.join("sub"), d.join("link")).unwrap();
        let v = scan(&d, &|| false).unwrap();
        let get = |n: &str| v.iter().find(|x| x.name == n).unwrap().clone();
        assert!(
            get("link").is_dir && get("link").is_symlink,
            "links to folders open as folders"
        );
        assert!(get("secret").is_hidden, ".hidden file is honoured");
        assert!(get("x.png").thumbable);
        fs::remove_dir_all(&d).unwrap();
    }
}
