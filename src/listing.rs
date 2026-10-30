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
        "png" | "jpg" | "jpeg" | "jpe" | "jfif" | "webp" | "gif" | "bmp" | "dib" | "ico" | "svg" | "svgz" | "kra"
            | "ora" | "tiff" | "tif" | "avif" | "heic" | "heif" | "jxl" | "xcf" | "psd" | "raw" | "cr2" | "nef"
            | "dng" | "arw" | "tga" | "xpm" | "pbm" | "pgm" | "ppm" | "qoi"
    )
}

pub fn is_video_ext(ext: &str) -> bool {
    // Not "ts": far more often TypeScript than an MPEG-TS stream (those
    // usually come as .m2ts/.mts from cameras).
    matches!(ext, "mp4" | "mkv" | "webm" | "mov" | "avi" | "flv" | "wmv" | "m4v" | "mpg" | "mpeg" | "ogv" | "3gp" | "m2ts" | "mts")
}

pub fn is_audio_ext(ext: &str) -> bool {
    matches!(ext, "mp3" | "flac" | "wav" | "ogg" | "oga" | "m4a" | "aac" | "opus" | "wma" | "aiff" | "ape")
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
        "rs" | "nix" | "js" | "mjs" | "ts" | "jsx" | "tsx" | "py" | "c" | "cc" | "cpp" | "h" | "hpp" | "lua"
        | "go" | "java" | "kt" | "rb" | "php" | "swift" | "zig" | "qml" | "cs" | "dart" | "hs" => {
            ("file-code", "text-x-script", "code", false)
        }
        "sh" | "bash" | "zsh" | "fish" => ("code", "text-x-script", "code", false),
        "zip" | "jar" | "apk" => ("file-zip", "package-x-generic", "archive", false),
        "tar" | "gz" | "xz" | "zst" | "bz2" | "7z" | "rar" | "tgz" | "txz" | "tbz2" | "cab" | "arj" | "lha"
        | "lzh" | "cpio" | "iso" | "deb" | "rpm" => ("file-archive", "package-x-generic", "archive", false),
        "pdf" => ("file-pdf", "application-pdf", "document", true),
        "epub" | "djvu" => ("file-text", "x-office-document", "document", true),
        "doc" | "docx" | "odt" | "rtf" => ("file-text", "x-office-document", "document", true),
        "xls" | "xlsx" | "ods" | "csv" => ("file-text", "x-office-spreadsheet", "document", true),
        "ppt" | "pptx" | "odp" => ("file-text", "x-office-presentation", "document", true),
        "md" | "txt" | "json" | "toml" | "yaml" | "yml" | "log" | "ini" | "conf" | "cfg" | "xml" => {
            ("file-text", "text-x-generic", "text", false)
        }
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
        .map(|s| s.lines().map(|l| l.trim().to_string()).filter(|l| !l.is_empty()).collect())
        .unwrap_or_default()
}

/// Builds an entry for `path` (symlinks are described as links but sized
/// and typed by their target when it exists).
pub fn entry_for(path: &Path, name: &str, hidden_names: &HashSet<String>) -> Option<Entry> {
    let lmeta = fs::symlink_metadata(path).ok()?;
    let is_symlink = lmeta.file_type().is_symlink();
    let meta = if is_symlink { fs::metadata(path).unwrap_or(lmeta) } else { lmeta };
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
            return Err(std::io::Error::new(std::io::ErrorKind::Interrupted, "cancelled"));
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
    /// "name" | "modified" | "size" | "type"
    pub key: String,
    pub ascending: bool,
    /// "first" | "last" | "mixed"
    pub folders: String,
}

impl Default for SortSpec {
    fn default() -> Self {
        SortSpec { key: "name".into(), ascending: true, folders: "first".into() }
    }
}

pub fn compare(a: &Entry, b: &Entry, spec: &SortSpec) -> Ordering {
    match spec.folders.as_str() {
        "mixed" => {}
        "last" if a.is_dir != b.is_dir => return a.is_dir.cmp(&b.is_dir),
        _ if a.is_dir != b.is_dir => return b.is_dir.cmp(&a.is_dir),
        _ => {}
    }
    // By name, dot-names go after the others in their group (folders, then
    // .folders, then files, then .files), as in Nautilus, in either direction.
    if spec.key == "name" {
        let (ha, hb) = (a.name.starts_with('.'), b.name.starts_with('.'));
        if ha != hb {
            return ha.cmp(&hb);
        }
    }
    let by_name = || natural_cmp(&a.name, &b.name);
    let ord = match spec.key.as_str() {
        "size" => a.size.cmp(&b.size).then_with(by_name),
        "modified" => a.modified.cmp(&b.modified).then_with(by_name),
        "type" => a
            .category
            .cmp(b.category)
            .then_with(|| extension(&a.name).cmp(&extension(&b.name)))
            .then_with(by_name),
        _ => by_name(),
    };
    let ord = if spec.ascending { ord } else { ord.reverse() };
    // Names are unique within a folder, but search results may repeat them.
    ord.then_with(|| a.path.cmp(&b.path))
}

pub fn sort<T: EntryLike>(entries: &mut [T], spec: &SortSpec) {
    entries.sort_by(|a, b| compare(a.as_entry(), b.as_entry(), spec));
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
            changes.push(Change::Insert { at, items: vec![item] });
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
            e.detail = p.parent().map(|x| x.to_string_lossy().to_string()).unwrap_or_default();
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
        let mut v = vec![e("b.txt", false, 5), e("Zdir", true, 0), e("a.txt", false, 9), e("adir", true, 0)];
        sort(&mut v, &SortSpec::default());
        let names: Vec<_> = v.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(names, vec!["adir", "Zdir", "a.txt", "b.txt"]);
        sort(&mut v, &SortSpec { key: "size".into(), ascending: false, folders: "last".into() });
        let names: Vec<_> = v.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(names, vec!["a.txt", "b.txt", "Zdir", "adir"]);
    }

    #[test]
    fn dot_names_sort_after_the_others_in_their_group() {
        let mut v = vec![e(".git", true, 0), e("zeta", true, 0), e(".dotfile", false, 1), e("alpha.txt", false, 1), e("Alpha", true, 0)];
        sort(&mut v, &SortSpec::default());
        let names: Vec<_> = v.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(names, vec!["Alpha", "zeta", ".git", "alpha.txt", ".dotfile"]);
        sort(&mut v, &SortSpec { key: "name".into(), ascending: false, folders: "first".into() });
        let names: Vec<_> = v.iter().map(|x| x.name.as_str()).collect();
        assert_eq!(names, vec!["zeta", "Alpha", ".git", "alpha.txt", ".dotfile"], "still last when reversed");
    }

    #[test]
    fn typescript_is_code_not_video() {
        assert_eq!(classify("app.ts", false).2, "code");
        assert_eq!(classify("clip.m2ts", false).2, "video");
    }

    #[test]
    fn hidden_filter_rules() {
        let dot = e(".bashrc", false, 1);
        assert!(!visible(&dot, false, ""));
        assert!(visible(&dot, false, ".bash"), "typing a dot finds dotfiles (issue #12)");
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
        check_diff(vec![a.clone(), b.clone(), c.clone()], vec![a.clone(), c.clone()]);
        check_diff(vec![a.clone(), c.clone()], vec![a.clone(), b.clone(), c.clone(), d.clone()]);
        check_diff(vec![], vec![a.clone(), b.clone()]);
        check_diff(vec![a.clone(), b.clone()], vec![]);
        let mut b2 = b.clone();
        b2.size = 99;
        check_diff(vec![a.clone(), b.clone(), c.clone()], vec![a.clone(), b2.clone(), c.clone()]);
        // Reordering (e.g. sorted by size and a file grew).
        check_diff(vec![a.clone(), b.clone(), c.clone(), d.clone()], vec![b.clone(), c.clone(), a.clone(), d.clone()]);
        check_diff(vec![a.clone(), b.clone(), c.clone(), d.clone()], vec![d.clone(), a.clone(), b.clone(), c.clone()]);
        check_diff(vec![a.clone(), b.clone(), c.clone(), d.clone()], vec![d.clone(), c.clone(), b.clone(), a.clone()]);
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
        assert!(get("link").is_dir && get("link").is_symlink, "links to folders open as folders");
        assert!(get("secret").is_hidden, ".hidden file is honoured");
        assert!(get("x.png").thumbable);
        fs::remove_dir_all(&d).unwrap();
    }
}
