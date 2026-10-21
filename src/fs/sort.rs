use super::entry::FileEntry;

/// Supported fields for sorting items.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SortField {
    Name,
    Size,
    Modified,
    Kind,
}

impl SortField {
    pub fn parse(s: &str) -> Self {
        match s.to_ascii_lowercase().as_str() {
            "size" => SortField::Size,
            "modified" | "date" => SortField::Modified,
            "type" | "kind" | "category" => SortField::Kind,
            _ => SortField::Name,
        }
    }
}

/// Ordering direction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SortDirection {
    Ascending,
    Descending,
}

/// Where directories appear relative to regular files.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FolderPosition {
    First,
    Last,
    Mixed,
}

impl FolderPosition {
    pub fn parse(s: &str) -> Self {
        match s.to_ascii_lowercase().as_str() {
            "last" => FolderPosition::Last,
            "mixed" => FolderPosition::Mixed,
            _ => FolderPosition::First,
        }
    }
}

/// Comprehensive sorting options.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SortOptions {
    pub field: SortField,
    pub direction: SortDirection,
    pub folder_position: FolderPosition,
}

impl Default for SortOptions {
    fn default() -> Self {
        Self {
            field: SortField::Name,
            direction: SortDirection::Ascending,
            folder_position: FolderPosition::First,
        }
    }
}

/// Sorts a slice of `FileEntry` in-place according to the given `SortOptions`.
pub fn sort_entries(entries: &mut [FileEntry], options: &SortOptions) {
    entries.sort_by(|a, b| {
        // 1. Evaluate directory grouping first if not 'Mixed'
        match options.folder_position {
            FolderPosition::First => {
                if a.is_dir != b.is_dir {
                    // Directories come first (b.is_dir cmp a.is_dir: true > false)
                    return b.is_dir.cmp(&a.is_dir);
                }
            }
            FolderPosition::Last => {
                if a.is_dir != b.is_dir {
                    // Directories come last
                    return a.is_dir.cmp(&b.is_dir);
                }
            }
            FolderPosition::Mixed => {}
        }

        // 2. Compare based on the chosen sort field
        let ord = match options.field {
            SortField::Size => a
                .size_bytes
                .cmp(&b.size_bytes)
                .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
            SortField::Modified => a
                .modified_timestamp
                .cmp(&b.modified_timestamp)
                .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
            SortField::Kind => a
                .kind
                .label()
                .cmp(b.kind.label())
                .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase())),
            SortField::Name => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
        };

        // 3. Apply direction
        match options.direction {
            SortDirection::Ascending => ord,
            SortDirection::Descending => ord.reverse(),
        }
    });
}
