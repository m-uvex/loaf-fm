use std::fs;
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

/// Broad classification of a file for filtering, sorting, and UI categorization.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum FileKind {
    Directory,
    Image,
    Video,
    Audio,
    Document,
    Archive,
    Code,
    Executable,
    Other,
}

impl FileKind {
    /// Categorizes a file based on whether it is a directory or its extension.
    pub fn from_path(path: &Path, is_dir: bool) -> Self {
        if is_dir {
            return FileKind::Directory;
        }

        let ext = match path.extension().and_then(|e| e.to_str()) {
            Some(e) => e.to_ascii_lowercase(),
            None => return FileKind::Other,
        };

        match ext.as_str() {
            // Images
            "png" | "jpg" | "jpeg" | "webp" | "gif" | "bmp" | "svg" | "ico" | "avif" | "heic"
            | "heif" | "tiff" | "tif" => FileKind::Image,

            // Video
            "mp4" | "mkv" | "avi" | "mov" | "webm" | "flv" | "wmv" | "m4v" | "m2ts" | "mts" => {
                FileKind::Video
            }

            // Audio
            "mp3" | "flac" | "wav" | "ogg" | "m4a" | "aac" | "opus" | "wma" => FileKind::Audio,

            // Documents
            "pdf" | "doc" | "docx" | "odt" | "rtf" | "txt" | "md" | "xls" | "xlsx" | "ods"
            | "ppt" | "pptx" | "odp" | "epub" => FileKind::Document,

            // Archives
            "zip" | "tar" | "gz" | "bz2" | "xz" | "7z" | "rar" | "zst" | "cpio" | "iso" => {
                FileKind::Archive
            }

            // Code
            "rs" | "js" | "ts" | "jsx" | "tsx" | "py" | "go" | "c" | "cpp" | "h" | "hpp"
            | "html" | "css" | "json" | "toml" | "yaml" | "yml" | "sh" | "bash" | "qml" => {
                FileKind::Code
            }

            // Executables
            "exe" | "bin" | "appimage" | "deb" | "rpm" | "flatpakref" => FileKind::Executable,

            _ => FileKind::Other,
        }
    }

    /// User-friendly category label.
    pub fn label(&self) -> &'static str {
        match self {
            FileKind::Directory => "Folder",
            FileKind::Image => "Image",
            FileKind::Video => "Video",
            FileKind::Audio => "Audio",
            FileKind::Document => "Document",
            FileKind::Archive => "Archive",
            FileKind::Code => "Code",
            FileKind::Executable => "Executable",
            FileKind::Other => "Other",
        }
    }
}

/// A pure domain representation of a filesystem item.
/// Completely decoupled from Qt/QML strings, formatting, and presentation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileEntry {
    pub path: PathBuf,
    pub name: String,
    pub is_dir: bool,
    pub is_symlink: bool,
    pub size_bytes: u64,
    pub modified_timestamp: u64,
    pub is_hidden: bool,
    pub kind: FileKind,
}

impl FileEntry {
    /// Constructs a `FileEntry` from a standard `std::fs::DirEntry`.
    /// Returns None if the entry's filename cannot be parsed as valid Unicode.
    pub fn from_dir_entry(entry: &fs::DirEntry) -> Option<Self> {
        let path = entry.path();
        let name = entry.file_name().into_string().ok()?;
        let is_hidden = name.starts_with('.');

        // Check symlink first using file_type (does not follow symlinks)
        let file_type = entry.file_type().ok();
        let is_symlink = file_type.as_ref().map(|ft| ft.is_symlink()).unwrap_or(false);

        // Fetch metadata to check if target is a dir or file and get size/mtime
        // If symlink target is broken, entry.metadata() will fail, so fall back to symlink_metadata
        let (is_dir, size_bytes, modified_timestamp) = if let Ok(meta) = entry.metadata() {
            let is_d = meta.is_dir();
            let sz = if is_d { 0 } else { meta.len() };
            let mtime = meta
                .modified()
                .ok()
                .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
                .map(|d| d.as_secs())
                .unwrap_or(0);
            (is_d, sz, mtime)
        } else if let Ok(sym_meta) = entry.path().symlink_metadata() {
            let is_d = sym_meta.is_dir();
            let sz = sym_meta.len();
            let mtime = sym_meta
                .modified()
                .ok()
                .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
                .map(|d| d.as_secs())
                .unwrap_or(0);
            (is_d, sz, mtime)
        } else {
            (false, 0, 0)
        };

        let kind = FileKind::from_path(&path, is_dir);

        Some(Self {
            path,
            name,
            is_dir,
            is_symlink,
            size_bytes,
            modified_timestamp,
            is_hidden,
            kind,
        })
    }

    /// Helper returning file extension as lowercase string slice if present.
    pub fn extension(&self) -> Option<&str> {
        self.path.extension().and_then(|ext| ext.to_str())
    }
}
