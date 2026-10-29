//! `LoafEngine`: one file view (a pane / tab). It is a QAbstractListModel
//! the grid and list views bind to directly, so QML never parses JSON per
//! item and only visible delegates are created.
//!
//! All disk access (listing, searching, archive listing) happens on worker
//! threads; results come back through `qt_thread().queue(..)`. A generation
//! counter drops results from scans that were superseded. An inotify watcher
//! keeps the shown folder up to date with minimal row updates.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!(<QtCore/QAbstractListModel>);
        type QAbstractListModel;

        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qvariant.h");
        type QVariant = cxx_qt_lib::QVariant;
        include!("cxx-qt-lib/qmodelindex.h");
        type QModelIndex = cxx_qt_lib::QModelIndex;
        include!("cxx-qt-lib/qhash.h");
        type QHash_i32_QByteArray = cxx_qt_lib::QHash<cxx_qt_lib::QHashPair_i32_QByteArray>;
        include!("cxx-qt-lib/qlist.h");
        type QList_i32 = cxx_qt_lib::QList<i32>;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[base = QAbstractListModel]
        #[qproperty(QString, current_path)]
        #[qproperty(QString, current_dir_name)]
        #[qproperty(QString, location_kind)]
        #[qproperty(QString, breadcrumbs_json)]
        #[qproperty(bool, can_go_back)]
        #[qproperty(bool, can_go_forward)]
        #[qproperty(bool, show_hidden)]
        #[qproperty(QString, sort_by)]
        #[qproperty(bool, sort_ascending)]
        #[qproperty(QString, folder_position)]
        #[qproperty(QString, view_mode)]
        #[qproperty(QString, filter_text)]
        #[qproperty(i32, item_count)]
        #[qproperty(bool, loading)]
        #[qproperty(QString, error_text)]
        #[qproperty(bool, is_searching_everywhere)]
        #[qproperty(QString, search_query)]
        #[qproperty(bool, searching)]
        #[qproperty(bool, read_only)]
        type LoafEngine = super::PaneRust;
    }
    unsafe extern "RustQt" {
        #[inherit]
        #[cxx_name = "beginResetModel"]
        fn begin_reset_model(self: Pin<&mut LoafEngine>);
        #[inherit]
        #[cxx_name = "endResetModel"]
        fn end_reset_model(self: Pin<&mut LoafEngine>);
        #[inherit]
        #[cxx_name = "beginInsertRows"]
        fn begin_insert_rows(self: Pin<&mut LoafEngine>, parent: &QModelIndex, first: i32, last: i32);
        #[inherit]
        #[cxx_name = "endInsertRows"]
        fn end_insert_rows(self: Pin<&mut LoafEngine>);
        #[inherit]
        #[cxx_name = "beginRemoveRows"]
        fn begin_remove_rows(self: Pin<&mut LoafEngine>, parent: &QModelIndex, first: i32, last: i32);
        #[inherit]
        #[cxx_name = "endRemoveRows"]
        fn end_remove_rows(self: Pin<&mut LoafEngine>);
        #[inherit]
        fn index(self: &LoafEngine, row: i32, column: i32, parent: &QModelIndex) -> QModelIndex;

        #[inherit]
        #[qsignal]
        #[cxx_name = "dataChanged"]
        fn data_changed(self: Pin<&mut LoafEngine>, top_left: &QModelIndex, bottom_right: &QModelIndex, roles: &QList_i32);

        #[qinvokable]
        #[cxx_override]
        fn data(self: &LoafEngine, index: &QModelIndex, role: i32) -> QVariant;
        #[qinvokable]
        #[cxx_override]
        #[cxx_name = "roleNames"]
        fn role_names(self: &LoafEngine) -> QHash_i32_QByteArray;
        #[qinvokable]
        #[cxx_override]
        #[cxx_name = "rowCount"]
        fn row_count(self: &LoafEngine, parent: &QModelIndex) -> i32;
    }

    unsafe extern "RustQt" {
        /// A scan finished and the rows are up to date.
        #[qsignal]
        fn loaded(self: Pin<&mut LoafEngine>);
    }

    unsafe extern "RustQt" {
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
        fn open_trash(self: Pin<&mut LoafEngine>);
        #[qinvokable]
        fn open_recent(self: Pin<&mut LoafEngine>);
        #[qinvokable]
        fn open_starred(self: Pin<&mut LoafEngine>);
        #[qinvokable]
        fn search(self: Pin<&mut LoafEngine>, query: &QString, scope: &QString, contents: bool);
        #[qinvokable]
        fn clear_search(self: Pin<&mut LoafEngine>);
        #[qinvokable]
        fn set_filter(self: Pin<&mut LoafEngine>, text: &QString);
        #[qinvokable]
        fn toggle_show_hidden(self: Pin<&mut LoafEngine>);
        #[qinvokable]
        fn set_sort(self: Pin<&mut LoafEngine>, key: &QString, ascending: bool);
        #[qinvokable]
        fn toggle_sort_order(self: Pin<&mut LoafEngine>);
        #[qinvokable]
        fn change_folder_position(self: Pin<&mut LoafEngine>, position: &QString);
        #[qinvokable]
        fn set_view(self: Pin<&mut LoafEngine>, mode: &QString);
        #[qinvokable]
        fn toggle_view_mode(self: Pin<&mut LoafEngine>);
        #[qinvokable]
        fn reload_starred(self: Pin<&mut LoafEngine>);

        /// JSON {location, back, forward} for tabs and session restore.
        #[qinvokable]
        fn get_state(self: &LoafEngine) -> QString;
        #[qinvokable]
        fn restore_state(self: Pin<&mut LoafEngine>, state: &QString);

        #[qinvokable]
        fn path_at(self: &LoafEngine, row: i32) -> QString;
        #[qinvokable]
        fn item_json(self: &LoafEngine, row: i32) -> QString;
        /// rows: JSON array of row numbers -> JSON array of paths.
        #[qinvokable]
        fn paths_for_rows(self: &LoafEngine, rows: &QString) -> QString;
        #[qinvokable]
        fn row_of(self: &LoafEngine, path: &QString) -> i32;
        /// Rows whose names match a shell-style pattern ("*.jpg").
        #[qinvokable]
        fn rows_matching(self: &LoafEngine, pattern: &QString) -> QString;
        /// Keeps only paths that are still shown (JSON array in and out).
        #[qinvokable]
        fn filter_existing(self: &LoafEngine, paths_json: &QString) -> QString;
        /// Paths of rows first..=last (for shift-selection ranges).
        #[qinvokable]
        fn paths_in_range(self: &LoafEngine, first: i32, last: i32) -> QString;
    }

    impl cxx_qt::Threading for LoafEngine {}
    impl cxx_qt::Initialize for LoafEngine {}
}

use crate::listing::{self, Change, Entry, SortSpec};
use crate::{archive, state, trash, util, watcher, xdg};
use core::pin::Pin;
use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::{QByteArray, QHash, QHashPair_i32_QByteArray, QList, QModelIndex, QString, QVariant};
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

#[derive(Clone, Debug, PartialEq)]
enum Loc {
    Dir(PathBuf),
    Trash,
    Recent,
    Starred,
    Search { root: PathBuf, query: String, contents: bool },
    /// Browsing inside an archive file (read-only).
    Archive { file: PathBuf, inner: String },
    Mtp(crate::mtp::Location),
}

pub const ARCHIVE_SCHEME: &str = "archive://";

/// Splits "archive://<file>#<member>" (without the scheme). Folder and file
/// names may contain `#`, so the split is at the first `#` whose left side
/// is an existing file.
pub fn split_archive_url(rest: &str) -> (PathBuf, String) {
    for (i, _) in rest.match_indices('#') {
        let file = Path::new(&rest[..i]);
        if file.is_file() {
            return (file.to_path_buf(), rest[i + 1..].to_string());
        }
    }
    if Path::new(rest).is_file() {
        return (PathBuf::from(rest), String::new());
    }
    let (file, inner) = rest.split_once('#').unwrap_or((rest, ""));
    (PathBuf::from(file), inner.to_string())
}

impl Loc {
    fn to_string(&self) -> String {
        match self {
            Loc::Dir(p) => p.to_string_lossy().to_string(),
            Loc::Mtp(location) => location.url(),
            Loc::Trash => "trash:///".into(),
            Loc::Recent => "recent:///".into(),
            Loc::Starred => "starred:///".into(),
            Loc::Search { root, .. } => root.to_string_lossy().to_string(),
            Loc::Archive { file, inner } => format!("{}{}#{}", ARCHIVE_SCHEME, file.to_string_lossy(), inner),
        }
    }

    fn parse(s: &str) -> Option<Loc> {
        let s = s.trim();
        if s.starts_with("mtp:") {
            return crate::mtp::Location::parse(s).map(Loc::Mtp);
        }
        match s {
            "trash:///" | "trash:" | "trash://" => return Some(Loc::Trash),
            "recent:///" | "recent:" => return Some(Loc::Recent),
            "starred:///" | "starred:" => return Some(Loc::Starred),
            _ => {}
        }
        if let Some(rest) = s.strip_prefix(ARCHIVE_SCHEME) {
            let (file, inner) = split_archive_url(rest);
            return Some(Loc::Archive { file, inner: inner.trim_matches('/').to_string() });
        }
        let path = if let Some(rest) = s.strip_prefix("file://") {
            trash::decode_path(rest)
        } else if s == "~" {
            util::home()
        } else if let Some(rest) = s.strip_prefix("~/") {
            util::home().join(rest)
        } else {
            PathBuf::from(s)
        };
        if !path.is_absolute() {
            return None;
        }
        if path.is_dir() {
            return Some(Loc::Dir(path));
        }
        if path.is_file() && archive::is_archive(&path) {
            return Some(Loc::Archive { file: path, inner: String::new() });
        }
        None
    }

    fn kind(&self) -> &'static str {
        match self {
            Loc::Dir(_) => "dir",
            Loc::Mtp(_) => "mtp",
            Loc::Trash => "trash",
            Loc::Recent => "recent",
            Loc::Starred => "starred",
            Loc::Search { .. } => "search",
            Loc::Archive { .. } => "archive",
        }
    }
}

pub struct PaneRust {
    current_path: QString,
    current_dir_name: QString,
    location_kind: QString,
    breadcrumbs_json: QString,
    can_go_back: bool,
    can_go_forward: bool,
    show_hidden: bool,
    sort_by: QString,
    sort_ascending: bool,
    folder_position: QString,
    view_mode: QString,
    filter_text: QString,
    item_count: i32,
    loading: bool,
    error_text: QString,
    is_searching_everywhere: bool,
    search_query: QString,
    searching: bool,
    read_only: bool,

    loc: Loc,
    /// Location to return to when a search is cleared.
    before_search: Option<Loc>,
    /// Shared entries: filtering never re-copies rows, it just makes a new
    /// list of `Arc`s pointing at the same entries.
    all: Vec<Arc<Entry>>,
    rows: Vec<Arc<Entry>>,
    starred: HashSet<String>,
    back: Vec<String>,
    forward: Vec<String>,
    generation: Arc<AtomicU64>,
    watcher: Option<watcher::DirWatcher>,
    archive_cache: Option<(PathBuf, i64, Vec<archive::Entry>)>,
}

impl Default for PaneRust {
    fn default() -> Self {
        let home = util::home();
        Self {
            current_path: QString::from(&*home.to_string_lossy()),
            current_dir_name: QString::from("Home"),
            location_kind: QString::from("dir"),
            breadcrumbs_json: QString::from("[]"),
            can_go_back: false,
            can_go_forward: false,
            show_hidden: state::get_bool("show_hidden", false),
            sort_by: QString::from(&*state::get_or("sort_by", "name")),
            sort_ascending: state::get_bool("sort_ascending", true),
            folder_position: QString::from(&*state::get_or("folder_position", "first")),
            view_mode: QString::from(&*state::get_or("view_mode", "grid")),
            filter_text: QString::default(),
            item_count: 0,
            loading: false,
            error_text: QString::default(),
            is_searching_everywhere: false,
            search_query: QString::default(),
            searching: false,
            read_only: false,
            loc: Loc::Dir(home),
            before_search: None,
            all: Vec::new(),
            rows: Vec::new(),
            starred: xdg::starred().into_iter().map(|p| p.to_string_lossy().to_string()).collect(),
            back: Vec::new(),
            forward: Vec::new(),
            generation: Arc::new(AtomicU64::new(0)),
            watcher: None,
            archive_cache: None,
        }
    }
}

// Model roles (Qt::UserRole + n).
const ROLE_BASE: i32 = 0x0100;
const ROLES: [&str; 18] = [
    "name",
    "path",
    "is_dir",
    "is_symlink",
    "is_hidden",
    "size",
    "size_str",
    "modified",
    "modified_str",
    "icon",
    "system_icon",
    "category",
    "thumbable",
    "thumb_id",
    "detail",
    "display_name",
    "starred",
    "parent_path",
];

pub fn hex_path(p: &str) -> String {
    use std::fmt::Write;
    let mut s = String::with_capacity(p.len() * 2);
    for b in p.as_bytes() {
        let _ = write!(s, "{:02x}", b);
    }
    s
}

/// "Just now", "5m ago", ... or a date.
pub fn relative_time(ts: i64) -> String {
    if ts <= 0 {
        return "-".into();
    }
    let now = unsafe { libc::time(std::ptr::null_mut()) } as i64;
    let elapsed = now - ts;
    if (0..60).contains(&elapsed) {
        "Just now".into()
    } else if (0..3600).contains(&elapsed) {
        format!("{}m ago", elapsed / 60)
    } else if (0..86400).contains(&elapsed) {
        format!("{}h ago", elapsed / 3600)
    } else if (0..86400 * 7).contains(&elapsed) {
        format!("{}d ago", elapsed / 86400)
    } else {
        format_date(ts)
    }
}

pub fn format_date(ts: i64) -> String {
    let t = ts as libc::time_t;
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    unsafe {
        libc::localtime_r(&t, &mut tm);
    }
    const MONTHS: [&str; 12] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    format!("{} {}, {}", MONTHS[tm.tm_mon.clamp(0, 11) as usize], tm.tm_mday, tm.tm_year + 1900)
}

fn entry_json(e: &Entry, starred: bool) -> serde_json::Value {
    serde_json::json!({
        "name": e.name,
        "path": e.path,
        "is_dir": e.is_dir,
        "is_symlink": e.is_symlink,
        "is_hidden": e.is_hidden,
        "size": e.size,
        "size_str": if e.is_dir { "-".to_string() } else { util::format_size(e.size) },
        "modified": e.modified,
        "modified_str": relative_time(e.modified),
        "icon": e.icon,
        "system_icon": e.system_icon,
        "category": e.category,
        "detail": e.detail,
        "parent_path": e.detail,
        "display_name": e.display_name,
        "starred": starred,
    })
}

#[derive(serde::Serialize)]
struct Crumb {
    name: String,
    path: String,
    icon: String,
    system_icon: String,
    is_root_place: bool,
    is_forward: bool,
}

fn crumb(name: &str, path: &str, icon: &str, sys: &str, root: bool) -> Crumb {
    Crumb {
        name: name.into(),
        path: path.into(),
        icon: icon.into(),
        system_icon: sys.into(),
        is_root_place: root,
        is_forward: false,
    }
}

/// Breadcrumbs for a real folder: start at Home for anything inside ~$USER,
/// or at the filesystem root for system paths.
fn dir_crumbs(target: &Path) -> Vec<Crumb> {
    let home = util::home();
    let mut out = Vec::new();

    if target.starts_with(&home) {
        out.push(crumb("Home", &home.to_string_lossy(), "house", "user-home-symbolic", true));
        let mut cur = home.clone();
        if let Ok(rel) = target.strip_prefix(&home) {
            for comp in rel.components() {
                if let std::path::Component::Normal(c) = comp {
                    cur.push(c);
                    let name = c.to_string_lossy().to_string();
                    // Match XDG places for nicer icons (Pictures, Downloads, Documents, etc.)
                    let (icon, sys) = match name.as_str() {
                        "Documents" => ("file-text", "folder-documents-symbolic"),
                        "Downloads" => ("download", "folder-download-symbolic"),
                        "Pictures" => ("image", "folder-pictures-symbolic"),
                        "Music" => ("music", "folder-music-symbolic"),
                        "Videos" => ("video", "folder-videos-symbolic"),
                        "Desktop" => ("desktop", "user-desktop-symbolic"),
                        _ => ("folder", "folder"),
                    };
                    out.push(crumb(&name, &cur.to_string_lossy(), icon, sys, false));
                }
            }
        }
    } else {
        out.push(crumb("root", "/", "hard-drive", "drive-harddisk-symbolic", true));
        let mut cur = PathBuf::from("/");
        if let Ok(rel) = target.strip_prefix("/") {
            for comp in rel.components() {
                if let std::path::Component::Normal(c) = comp {
                    cur.push(c);
                    out.push(crumb(&c.to_string_lossy(), &cur.to_string_lossy(), "folder", "folder", false));
                }
            }
        }
    }

    out
}

impl qobject::LoafEngine {
    pub fn row_count(&self, _parent: &QModelIndex) -> i32 {
        self.rows.len() as i32
    }

    pub fn role_names(&self) -> QHash<QHashPair_i32_QByteArray> {
        let mut h = QHash::<QHashPair_i32_QByteArray>::default();
        for (i, name) in ROLES.iter().enumerate() {
            h.insert(ROLE_BASE + i as i32, QByteArray::from(*name));
        }
        h
    }

    pub fn data(&self, index: &QModelIndex, role: i32) -> QVariant {
        let row = index.row();
        let Some(e) = (row >= 0).then(|| self.rows.get(row as usize)).flatten() else { return QVariant::default() };
        let s = |v: &str| QVariant::from(&QString::from(v));
        match ROLES.get((role - ROLE_BASE) as usize).copied().unwrap_or("") {
            "name" => s(&e.name),
            "path" => s(&e.path),
            "is_dir" => QVariant::from(&e.is_dir),
            "is_symlink" => QVariant::from(&e.is_symlink),
            "is_hidden" => QVariant::from(&e.is_hidden),
            "size" => QVariant::from(&(e.size as i64)),
            "size_str" => s(&if e.is_dir { "-".to_string() } else { util::format_size(e.size) }),
            "modified" => QVariant::from(&e.modified),
            "modified_str" => s(&relative_time(e.modified)),
            "icon" => s(e.icon),
            "system_icon" => s(e.system_icon),
            "category" => s(e.category),
            "thumbable" => QVariant::from(&e.thumbable),
            "thumb_id" => s(&if e.thumbable { format!("{}-{}", hex_path(&e.path), e.modified) } else { String::new() }),
            "detail" | "parent_path" => s(&e.detail),
            "display_name" => s(&e.display_name),
            "starred" => QVariant::from(&self.starred.contains(&e.path)),
            _ => QVariant::default(),
        }
    }

    fn apply_rows(mut self: Pin<&mut Self>, new_rows: Vec<Arc<Entry>>, reset: bool) {
        // A full reset is cheaper for the view than thousands of row ops.
        let big_change = !reset && {
            let old = &self.rows;
            old.len().abs_diff(new_rows.len()) > 2000
        };
        if reset || big_change {
            self.as_mut().begin_reset_model();
            self.as_mut().rust_mut().rows = new_rows;
            self.as_mut().end_reset_model();
        } else {
            let changes = listing::diff(&self.rows, &new_rows);
            let root = QModelIndex::default();
            for c in changes {
                match c {
                    Change::Remove { at, count } => {
                        self.as_mut().begin_remove_rows(&root, at as i32, (at + count - 1) as i32);
                        self.as_mut().rust_mut().rows.drain(at..at + count);
                        self.as_mut().end_remove_rows();
                    }
                    Change::Insert { at, items } => {
                        let n = items.len();
                        self.as_mut().begin_insert_rows(&root, at as i32, (at + n - 1) as i32);
                        let rows = &mut self.as_mut().rust_mut().rows;
                        rows.splice(at..at, items);
                        self.as_mut().end_insert_rows();
                    }
                    Change::Update { at, item } => {
                        self.as_mut().rust_mut().rows[at] = item;
                        let idx = self.index(at as i32, 0, &root);
                        self.as_mut().data_changed(&idx, &idx, &QList::<i32>::default());
                    }
                }
            }
        }
        let n = self.rows.len() as i32;
        if *self.item_count() != n {
            self.as_mut().set_item_count(n);
        }
    }

    fn sort_spec(&self) -> SortSpec {
        SortSpec {
            key: self.sort_by().to_string(),
            ascending: *self.sort_ascending(),
            folders: self.folder_position().to_string(),
        }
    }

    fn visible_rows(&self) -> Vec<Arc<Entry>> {
        // Lowercased once here; `visible` compares against name_lower.
        let filter = listing::lower_filter(&self.filter_text().to_string());
        let show_hidden = *self.show_hidden();
        // Trash, recent and search lists show everything they found.
        let honour_hidden = matches!(self.loc, Loc::Dir(_) | Loc::Archive { .. } | Loc::Mtp(_));
        self.all
            .iter()
            .filter(|e| listing::visible(e, show_hidden || !honour_hidden, &filter))
            .cloned()
            .collect()
    }

    fn refilter(mut self: Pin<&mut Self>, reset: bool) {
        let rows = self.visible_rows();
        self.as_mut().apply_rows(rows, reset);
    }
    fn update_location_props(mut self: Pin<&mut Self>) {
        let loc = self.loc.clone();
        let (title, crumbs): (String, Vec<Crumb>) = match &loc {
            Loc::Dir(p) => {
                let name = if *p == util::home() {
                    "Home".to_string()
                } else {
                    p.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| "/".into())
                };
                let mut c = dir_crumbs(p);
                // Show where "forward" would go as faded crumbs.
                if let Some(fwd) = self.forward.last().and_then(|f| Loc::parse(f)) {
                    if let Loc::Dir(f) = fwd {
                        if f != *p && f.starts_with(p) {
                            let mut cur = p.clone();
                            for comp in f.strip_prefix(p).unwrap_or(Path::new("")).components() {
                                if let std::path::Component::Normal(x) = comp {
                                    cur.push(x);
                                    let mut cb = crumb(&x.to_string_lossy(), &cur.to_string_lossy(), "folder", "folder", false);
                                    cb.is_forward = true;
                                    c.push(cb);
                                }
                            }
                        }
                    }
                }
                (name, c)
            }
            Loc::Mtp(location) => (location.title(), location.breadcrumbs().into_iter()
                .enumerate().map(|(index, (name, path))| crumb(&name, &path,
                    if index == 0 { "device-mobile" } else { "folder" },
                    if index == 0 { "phone-symbolic" } else { "folder" }, index == 0)).collect()),
            Loc::Trash => ("Trash".into(), vec![crumb("Trash", "trash:///", "trash", "user-trash-symbolic", true)]),
            Loc::Recent => ("Recent".into(), vec![crumb("Recent", "recent:///", "clock", "document-open-recent-symbolic", true)]),
            Loc::Starred => ("Starred".into(), vec![crumb("Starred", "starred:///", "star", "starred-symbolic", true)]),
            Loc::Search { root, .. } => ("Search".into(), dir_crumbs(root)),
            Loc::Archive { file, inner } => {
                let parent = file.parent().unwrap_or(Path::new("/"));
                let mut c = dir_crumbs(parent);
                let fname = file.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
                c.push(crumb(&fname, &Loc::Archive { file: file.clone(), inner: String::new() }.to_string(), "file-zip", "package-x-generic", false));
                let mut acc = String::new();
                for part in inner.split('/').filter(|s| !s.is_empty()) {
                    if !acc.is_empty() {
                        acc.push('/');
                    }
                    acc.push_str(part);
                    c.push(crumb(part, &Loc::Archive { file: file.clone(), inner: acc.clone() }.to_string(), "folder", "folder", false));
                }
                let title = if inner.is_empty() {
                    fname
                } else {
                    inner.rsplit('/').next().unwrap_or(inner).to_string()
                };
                (title, c)
            }
        };
        let path = loc.to_string();
        self.as_mut().set_current_path(QString::from(&*path));
        self.as_mut().set_current_dir_name(QString::from(&*title));
        self.as_mut().set_location_kind(QString::from(loc.kind()));
        self.as_mut().set_breadcrumbs_json(QString::from(&*serde_json::to_string(&crumbs).unwrap_or_default()));
        let searching = matches!(loc, Loc::Search { .. });
        self.as_mut().set_is_searching_everywhere(searching);
        self.as_mut().set_read_only(matches!(loc, Loc::Archive { .. } | Loc::Recent | Loc::Search { .. } | Loc::Starred)
            || matches!(&loc, Loc::Mtp(location) if location.storage().is_none()));
        let (b, f) = (!self.back.is_empty(), !self.forward.is_empty());
        self.as_mut().set_can_go_back(b);
        self.as_mut().set_can_go_forward(f);
        // Watch what we show.
        let watch: Option<PathBuf> = match &loc {
            Loc::Dir(p) => Some(p.clone()),
            Loc::Trash => Some(trash::home_trash().join("files")),
            _ => None,
        };
        if let Some(w) = self.watcher.as_ref() {
            match watch {
                Some(p) => w.watch(&p),
                None => w.unwatch(),
            }
        }
    }

    fn go_to(mut self: Pin<&mut Self>, loc: Loc, push_history: bool) {
        if push_history && loc != self.loc {
            let current = match (&self.loc, &self.before_search) {
                (Loc::Search { .. }, Some(prev)) => prev.to_string(),
                _ => self.loc.to_string(),
            };
            let back = &mut self.as_mut().rust_mut().back;
            if back.last() != Some(&current) {
                back.push(current);
            }
            if back.len() > 100 {
                back.remove(0);
            }
            self.as_mut().rust_mut().forward.clear();
        }
        if !matches!(loc, Loc::Search { .. }) {
            self.as_mut().rust_mut().before_search = None;
            if self.searching().to_owned() {
                self.as_mut().set_searching(false);
            }
            if !self.search_query().is_empty() {
                self.as_mut().set_search_query(QString::default());
            }
        }
        if let Loc::Dir(p) = &loc {
            state::record_visit(&p.to_string_lossy());
        }
        self.as_mut().rust_mut().loc = loc;
        if !self.filter_text().is_empty() {
            self.as_mut().set_filter_text(QString::default());
        }
        self.as_mut().update_location_props();
        self.start_scan(true);
    }

    /// Lists the current location on a worker thread.
    fn start_scan(mut self: Pin<&mut Self>, reset: bool) {
        let gen = self.generation.fetch_add(1, Ordering::SeqCst) + 1;
        let gen_ref = self.generation.clone();
        let loc = self.loc.clone();
        let spec = self.sort_spec();
        let archive_cache = self.archive_cache.clone();
        let thread = self.qt_thread();
        if reset {
            // Show the new location right away instead of the old rows.
            self.as_mut().rust_mut().all.clear();
            self.as_mut().apply_rows(Vec::new(), true);
        }
        self.as_mut().set_loading(true);
        let started = std::time::Instant::now();
        std::thread::spawn(move || {
            let cancelled = || gen_ref.load(Ordering::SeqCst) != gen;
            let mut new_cache = None;
            let result: Result<Vec<Entry>, String> = match &loc {
                Loc::Dir(p) => listing::scan(p, &cancelled).map_err(|e| match e.kind() {
                    std::io::ErrorKind::PermissionDenied => "You don't have permission to view this folder".to_string(),
                    std::io::ErrorKind::NotFound => "This folder no longer exists".to_string(),
                    _ => e.to_string(),
                }),
                Loc::Trash => Ok(trash::list()
                    .into_iter()
                    .filter_map(|it| {
                        let name = it.original.file_name()?.to_string_lossy().to_string();
                        let mut e = listing::entry_for(&it.trashed, &name, &HashSet::new())?;
                        e.is_hidden = false;
                        e.detail = it.original.parent().map(|p| p.to_string_lossy().to_string()).unwrap_or_default();
                        Some(e)
                    })
                    .collect()),
                Loc::Mtp(location) => crate::mtp::list(location),
                Loc::Recent => Ok(listing::entries_for_paths(&xdg::recent_files(300))),
                Loc::Starred => Ok(listing::entries_for_paths(&xdg::starred())),
                Loc::Search { .. } => Ok(Vec::new()),
                Loc::Archive { file, inner } => {
                    let mtime = std::fs::metadata(file).map(|m| std::os::unix::fs::MetadataExt::mtime(&m)).unwrap_or(0);
                    let entries = match archive_cache {
                        Some((f, m, e)) if f == *file && m == mtime => Ok(e),
                        _ => archive::list(file, "").map_err(|e| e.to_string()),
                    };
                    entries.map(|entries| {
                        new_cache = Some((file.clone(), mtime, entries.clone()));
                        archive_children(file, inner, &entries)
                    })
                }
            };
            if cancelled() {
                return;
            }
            let result = result.map(|mut v| {
                if !matches!(loc, Loc::Recent | Loc::Search { .. }) {
                    listing::sort(&mut v, &spec);
                }
                v.into_iter().map(Arc::new).collect::<Vec<_>>()
            });
            let _ = thread.queue(move |mut pane| {
                if pane.generation.load(Ordering::SeqCst) != gen {
                    return;
                }
                if new_cache.is_some() {
                    pane.as_mut().rust_mut().archive_cache = new_cache;
                }
                // Space watcher refreshes to twice the scan time, so a big
                // folder that keeps changing (a long copy into it) still
                // finishes its scans instead of restarting them forever.
                if let Some(w) = pane.watcher.as_ref() {
                    let ms = (started.elapsed().as_millis() as u64 * 2).clamp(250, 10_000);
                    w.min_interval_ms.store(ms, Ordering::Relaxed);
                }
                match result {
                    Ok(entries) => {
                        if !pane.error_text().is_empty() {
                            pane.as_mut().set_error_text(QString::default());
                        }
                        pane.as_mut().rust_mut().all = entries;
                        pane.as_mut().refilter(reset);
                    }
                    Err(msg) => {
                        pane.as_mut().rust_mut().all.clear();
                        pane.as_mut().refilter(true);
                        pane.as_mut().set_error_text(QString::from(&*msg));
                    }
                }
                pane.as_mut().set_loading(false);
                pane.as_mut().loaded();
            });
        });
    }

    pub fn set_path(self: Pin<&mut Self>, path: &QString) {
        if let Some(loc) = Loc::parse(&path.to_string()) {
            if loc == self.loc && !matches!(loc, Loc::Search { .. }) {
                return self.refresh();
            }
            self.go_to(loc, true);
        }
    }

    pub fn navigate_up(self: Pin<&mut Self>) {
        let up = match &self.loc {
            Loc::Dir(p) => p.parent().map(|x| Loc::Dir(x.to_path_buf())),
            Loc::Mtp(location) => location.parent().map(Loc::Mtp),
            Loc::Archive { file, inner } if inner.is_empty() => file.parent().map(|x| Loc::Dir(x.to_path_buf())),
            Loc::Archive { file, inner } => Some(Loc::Archive {
                file: file.clone(),
                inner: inner.rsplit_once('/').map(|(a, _)| a.to_string()).unwrap_or_default(),
            }),
            Loc::Search { .. } => self.before_search.clone(),
            _ => Some(Loc::Dir(util::home())),
        };
        if let Some(l) = up {
            self.go_to(l, true);
        }
    }

    fn jump(mut self: Pin<&mut Self>, forward: bool) {
        loop {
            let next = if forward {
                self.as_mut().rust_mut().forward.pop()
            } else {
                self.as_mut().rust_mut().back.pop()
            };
            let Some(next) = next else { break };
            // Skip entries that no longer exist (deleted folders).
            let Some(loc) = Loc::parse(&next) else { continue };
            let current = match (&self.loc, &self.before_search) {
                (Loc::Search { .. }, Some(prev)) => prev.to_string(),
                _ => self.loc.to_string(),
            };
            if forward {
                self.as_mut().rust_mut().back.push(current);
            } else {
                self.as_mut().rust_mut().forward.push(current);
            }
            self.go_to(loc, false);
            return;
        }
        self.update_location_props();
    }

    pub fn go_back(self: Pin<&mut Self>) {
        self.jump(false);
    }

    pub fn go_forward(self: Pin<&mut Self>) {
        self.jump(true);
    }

    pub fn refresh(self: Pin<&mut Self>) {
        match self.loc.clone() {
            Loc::Search { root, query, contents } => {
                self.run_search(root, query, contents);
            }
            Loc::Dir(p) if !p.is_dir() => {
                // The folder vanished: go to the nearest existing parent.
                let mut up = p.clone();
                while !up.is_dir() {
                    if !up.pop() {
                        up = util::home();
                        break;
                    }
                }
                self.go_to(Loc::Dir(up), false);
            }
            _ => self.start_scan(false),
        }
    }

    pub fn open_trash(self: Pin<&mut Self>) {
        self.go_to(Loc::Trash, true);
    }

    pub fn open_recent(self: Pin<&mut Self>) {
        self.go_to(Loc::Recent, true);
    }

    pub fn open_starred(self: Pin<&mut Self>) {
        self.go_to(Loc::Starred, true);
    }
    pub fn search(mut self: Pin<&mut Self>, query: &QString, scope: &QString, contents: bool) {
        if matches!(self.loc, Loc::Mtp(_)) && scope.to_string() != "home" {
            self.as_mut().set_filter_text(query.clone());
            self.refilter(true);
            return;
        }
        let q = query.to_string();
        if q.trim().is_empty() {
            return self.clear_search();
        }
        let root = match (scope.to_string().as_str(), &self.loc, &self.before_search) {
            ("home", _, _) => util::home(),
            (_, Loc::Search { root, .. }, _) => root.clone(),
            (_, Loc::Dir(p), _) => p.clone(),
            _ => util::home(),
        };
        if !matches!(self.loc, Loc::Search { .. }) {
            let prev = self.loc.clone();
            self.as_mut().rust_mut().before_search = Some(prev);
        }
        self.as_mut().rust_mut().loc = Loc::Search { root: root.clone(), query: q.clone(), contents };
        self.as_mut().set_search_query(QString::from(&*q));
        self.as_mut().update_location_props();
        self.run_search(root, q, contents);
    }

    fn run_search(mut self: Pin<&mut Self>, root: PathBuf, query: String, contents: bool) {
        let gen = self.generation.fetch_add(1, Ordering::SeqCst) + 1;
        let gen_ref = self.generation.clone();
        let show_hidden = *self.show_hidden();
        let thread = self.qt_thread();
        self.as_mut().rust_mut().all.clear();
        self.as_mut().apply_rows(Vec::new(), true);
        self.as_mut().set_searching(true);
        self.as_mut().set_loading(true);
        std::thread::spawn(move || {
            let cancelled = || gen_ref.load(Ordering::SeqCst) != gen;
            let q = crate::search::Query { text: query, root, show_hidden, contents, max_results: 2000 };
            let t = thread.clone();
            crate::search::run(&q, &cancelled, &mut |mut batch: Vec<Entry>| {
                let _ = t.queue(move |mut pane| {
                    if pane.generation.load(Ordering::SeqCst) != gen {
                        return;
                    }
                    let mut all = std::mem::take(&mut pane.as_mut().rust_mut().all);
                    all.extend(batch.drain(..).map(Arc::new));
                    if state::get_bool("disambiguate_duplicates", true) {
                        listing::disambiguate_shared(&mut all);
                    }
                    pane.as_mut().rust_mut().all = all;
                    pane.as_mut().refilter(false);
                });
            });
            let _ = thread.queue(move |mut pane| {
                if pane.generation.load(Ordering::SeqCst) != gen {
                    return;
                }
                pane.as_mut().set_searching(false);
                pane.as_mut().set_loading(false);
                pane.as_mut().loaded();
            });
        });
    }

    pub fn clear_search(mut self: Pin<&mut Self>) {
        if let Some(prev) = self.as_mut().rust_mut().before_search.take() {
            self.go_to(prev, false);
        } else if !self.search_query().is_empty() {
            self.as_mut().set_search_query(QString::default());
        }
    }

    pub fn set_filter(mut self: Pin<&mut Self>, text: &QString) {
        if *self.filter_text() == *text {
            return;
        }
        self.as_mut().set_filter_text(text.clone());
        self.refilter(false);
    }

    pub fn toggle_show_hidden(mut self: Pin<&mut Self>) {
        let v = !*self.show_hidden();
        self.as_mut().set_show_hidden(v);
        state::set_bool("show_hidden", v);
        self.refilter(false);
    }

    fn resort(mut self: Pin<&mut Self>) {
        let spec = self.sort_spec();
        let mut all = std::mem::take(&mut self.as_mut().rust_mut().all);
        listing::sort(&mut all, &spec);
        self.as_mut().rust_mut().all = all;
        self.refilter(true);
    }

    pub fn set_sort(mut self: Pin<&mut Self>, key: &QString, ascending: bool) {
        self.as_mut().set_sort_by(key.clone());
        self.as_mut().set_sort_ascending(ascending);
        state::set("sort_by", &key.to_string());
        state::set_bool("sort_ascending", ascending);
        self.resort();
    }

    pub fn toggle_sort_order(mut self: Pin<&mut Self>) {
        let v = !*self.sort_ascending();
        self.as_mut().set_sort_ascending(v);
        state::set_bool("sort_ascending", v);
        self.resort();
    }

    pub fn change_folder_position(mut self: Pin<&mut Self>, position: &QString) {
        self.as_mut().set_folder_position(position.clone());
        state::set("folder_position", &position.to_string());
        self.resort();
    }

    pub fn set_view(mut self: Pin<&mut Self>, mode: &QString) {
        self.as_mut().set_view_mode(mode.clone());
        state::set("view_mode", &mode.to_string());
    }

    pub fn toggle_view_mode(self: Pin<&mut Self>) {
        let next = if self.view_mode().to_string() == "list" { "grid" } else { "list" };
        self.set_view(&QString::from(next));
    }

    pub fn reload_starred(mut self: Pin<&mut Self>) {
        let set: HashSet<String> = xdg::starred().into_iter().map(|p| p.to_string_lossy().to_string()).collect();
        self.as_mut().rust_mut().starred = set;
        if matches!(self.loc, Loc::Starred) {
            return self.start_scan(false);
        }
        let n = self.rows.len() as i32;
        if n > 0 {
            let root = QModelIndex::default();
            let a = self.index(0, 0, &root);
            let b = self.index(n - 1, 0, &root);
            let mut roles = QList::<i32>::default();
            roles.append(ROLE_BASE + 16);
            self.as_mut().data_changed(&a, &b, &roles);
        }
    }
    pub fn get_state(&self) -> QString {
        let loc = match (&self.loc, &self.before_search) {
            (Loc::Search { .. }, Some(prev)) => prev.to_string(),
            _ => self.loc.to_string(),
        };
        let v = serde_json::json!({ "location": loc, "back": self.back, "forward": self.forward });
        QString::from(&*v.to_string())
    }

    pub fn restore_state(mut self: Pin<&mut Self>, state_json: &QString) {
        let Ok(v) = serde_json::from_str::<serde_json::Value>(&state_json.to_string()) else { return };
        let list = |k: &str| -> Vec<String> {
            v.get(k)
                .and_then(|x| x.as_array())
                .map(|a| a.iter().filter_map(|s| s.as_str().map(String::from)).collect())
                .unwrap_or_default()
        };
        self.as_mut().rust_mut().back = list("back");
        self.as_mut().rust_mut().forward = list("forward");
        let loc = v
            .get("location")
            .and_then(|l| l.as_str())
            .and_then(Loc::parse)
            .unwrap_or_else(|| Loc::Dir(util::home()));
        self.go_to(loc, false);
    }
    pub fn path_at(&self, row: i32) -> QString {
        self.rows.get(row.max(0) as usize).map(|e| QString::from(&*e.path)).unwrap_or_default()
    }

    pub fn item_json(&self, row: i32) -> QString {
        match self.rows.get(row.max(0) as usize).filter(|_| row >= 0) {
            Some(e) => QString::from(&*entry_json(e, self.starred.contains(&e.path)).to_string()),
            None => QString::from("{}"),
        }
    }

    pub fn paths_for_rows(&self, rows: &QString) -> QString {
        let idx: Vec<i64> = serde_json::from_str(&rows.to_string()).unwrap_or_default();
        let paths: Vec<&str> = idx
            .into_iter()
            .filter(|i| *i >= 0)
            .filter_map(|i| self.rows.get(i as usize))
            .map(|e| e.path.as_str())
            .collect();
        QString::from(&*serde_json::to_string(&paths).unwrap_or_else(|_| "[]".into()))
    }

    pub fn row_of(&self, path: &QString) -> i32 {
        let p = path.to_string();
        self.rows.iter().position(|e| e.path == p).map(|i| i as i32).unwrap_or(-1)
    }

    pub fn rows_matching(&self, pattern: &QString) -> QString {
        let pat = pattern.to_string().to_lowercase();
        let rows: Vec<usize> = self
            .rows
            .iter()
            .enumerate()
            // Names are stored pre-lowercased; no per-row copies here.
            .filter(|(_, e)| glob_match(&pat, &e.name_lower))
            .map(|(i, _)| i)
            .collect();
        QString::from(&*serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into()))
    }
}

impl qobject::LoafEngine {
    pub fn filter_existing(&self, paths_json: &QString) -> QString {
        let wanted: Vec<String> = serde_json::from_str(&paths_json.to_string()).unwrap_or_default();
        let shown: HashSet<&str> = self.rows.iter().map(|e| e.path.as_str()).collect();
        let kept: Vec<&String> = wanted.iter().filter(|p| shown.contains(p.as_str())).collect();
        QString::from(&*serde_json::to_string(&kept).unwrap_or_else(|_| "[]".into()))
    }

    pub fn paths_in_range(&self, first: i32, last: i32) -> QString {
        let (a, b) = (first.min(last).max(0) as usize, first.max(last).max(0) as usize);
        let paths: Vec<&str> = self.rows.iter().skip(a).take(b.saturating_sub(a) + 1).map(|e| e.path.as_str()).collect();
        QString::from(&*serde_json::to_string(&paths).unwrap_or_else(|_| "[]".into()))
    }
}

/// Minimal `*` / `?` wildcard matching (case handled by the caller).
pub fn glob_match(pat: &str, s: &str) -> bool {
    let p: Vec<char> = pat.chars().collect();
    let t: Vec<char> = s.chars().collect();
    let (mut pi, mut ti, mut star, mut mark) = (0usize, 0usize, None::<usize>, 0usize);
    while ti < t.len() {
        if pi < p.len() && (p[pi] == '?' || p[pi] == t[ti]) {
            pi += 1;
            ti += 1;
        } else if pi < p.len() && p[pi] == '*' {
            star = Some(pi);
            mark = ti;
            pi += 1;
        } else if let Some(sp) = star {
            pi = sp + 1;
            mark += 1;
            ti = mark;
        } else {
            return false;
        }
    }
    while pi < p.len() && p[pi] == '*' {
        pi += 1;
    }
    pi == p.len()
}

/// Entries directly inside `inner` of an archive listing.
fn archive_children(file: &Path, inner: &str, entries: &[archive::Entry]) -> Vec<Entry> {
    let prefix = if inner.is_empty() { String::new() } else { format!("{}/", inner) };
    let mut out = Vec::new();
    for e in entries {
        let Some(rest) = e.path.strip_prefix(&prefix) else { continue };
        if rest.is_empty() || rest.contains('/') {
            continue;
        }
        let (icon, system_icon, category, _) = listing::classify(rest, e.is_dir);
        let modified = parse_stamp(&e.modified);
        out.push(Entry {
            name: rest.to_string(),
            name_lower: rest.to_lowercase(),
            path: Loc::Archive {
                file: file.to_path_buf(),
                inner: e.path.clone(),
            }
            .to_string(),
            is_dir: e.is_dir,
            is_symlink: false,
            is_hidden: rest.starts_with('.'),
            size: e.size,
            modified,
            icon,
            system_icon,
            category,
            thumbable: false,
            detail: String::new(),
            display_name: rest.to_string(),
        });
    }
    out
}

/// "YYYY-MM-DD hh:mm:ss" (local time) -> unix seconds.
fn parse_stamp(s: &str) -> i64 {
    let nums: Vec<i32> = s.split(|c: char| !c.is_ascii_digit()).filter(|x| !x.is_empty()).filter_map(|x| x.parse().ok()).collect();
    if nums.len() < 6 {
        return 0;
    }
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    tm.tm_year = nums[0] - 1900;
    tm.tm_mon = nums[1] - 1;
    tm.tm_mday = nums[2];
    tm.tm_hour = nums[3];
    tm.tm_min = nums[4];
    tm.tm_sec = nums[5];
    tm.tm_isdst = -1;
    unsafe { libc::mktime(&mut tm) as i64 }
}

impl cxx_qt::Initialize for qobject::LoafEngine {
    fn initialize(mut self: Pin<&mut Self>) {
        let thread = self.qt_thread();
        let w = watcher::DirWatcher::new(move || {
            let _ = thread.queue(|pane| pane.refresh());
        });
        self.as_mut().rust_mut().watcher = w;
        // Start at home; QML restores a session or applies CLI paths later.
        self.as_mut().update_location_props();
        self.start_scan(true);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn locations_round_trip() {
        assert_eq!(Loc::parse("trash:///"), Some(Loc::Trash));
        let a = Loc::Archive { file: PathBuf::from("/tmp/x y.zip"), inner: "a/b".into() };
        assert_eq!(Loc::parse(&a.to_string()), Some(a));
        assert_eq!(Loc::parse("relative/path"), None);
        assert_eq!(Loc::parse("/"), Some(Loc::Dir(PathBuf::from("/"))));
    }

    #[test]
    fn globbing() {
        assert!(glob_match("*.jpg", "photo.jpg"));
        assert!(glob_match("img_??.png", "img_01.png"));
        assert!(!glob_match("*.jpg", "photo.jpeg"));
        assert!(glob_match("*", ""));
    }

    #[test]
    fn archive_children_lists_one_level() {
        let entries = archive::with_implied_dirs(vec![
            archive::Entry { path: "a/b/c.txt".into(), is_dir: false, size: 3, modified: "2024-01-01 00:00:00".into() },
            archive::Entry { path: "top.txt".into(), is_dir: false, size: 1, modified: String::new() },
        ]);
        let root = archive_children(Path::new("/x.zip"), "", &entries);
        let mut names: Vec<_> = root.iter().map(|e| e.name.clone()).collect();
        names.sort();
        assert_eq!(names, vec!["a", "top.txt"]);
        let inner = archive_children(Path::new("/x.zip"), "a/b", &entries);
        assert_eq!(inner.len(), 1);
        assert_eq!(inner[0].path, "archive:///x.zip#a/b/c.txt");
    }
}
