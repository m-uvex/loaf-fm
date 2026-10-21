use super::entry::FileEntry;
use super::sort::{sort_entries, SortOptions};
use std::fs;
use std::io;
use std::path::Path;

/// Options configuring directory scanning.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ScanOptions {
    pub show_hidden: bool,
    pub sort: SortOptions,
}

impl Default for ScanOptions {
    fn default() -> Self {
        Self {
            show_hidden: false,
            sort: SortOptions::default(),
        }
    }
}

/// Safely scans a directory on the local filesystem and returns a sorted list of entries.
/// Returns an `io::Error` if the directory does not exist or permissions are denied.
pub fn scan_directory(dir_path: &Path, options: &ScanOptions) -> io::Result<Vec<FileEntry>> {
    let read_dir = fs::read_dir(dir_path)?;
    let mut items = Vec::new();

    for entry_res in read_dir {
        let entry = match entry_res {
            Ok(e) => e,
            Err(_) => continue, // Skip unreadable entries gracefully
        };

        if let Some(file_entry) = FileEntry::from_dir_entry(&entry) {
            if !options.show_hidden && file_entry.is_hidden {
                continue;
            }
            items.push(file_entry);
        }
    }

    sort_entries(&mut items, &options.sort);

    Ok(items)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fs::sort::{FolderPosition, SortDirection, SortField};
    use std::fs::File;
    use std::io::Write;

    #[test]
    fn test_scan_and_sort() {
        let temp_dir = std::env::temp_dir().join("loaf_test_scan_and_sort");
        let _ = fs::remove_dir_all(&temp_dir);
        fs::create_dir_all(&temp_dir).unwrap();

        // Create sample files and folders
        fs::create_dir(temp_dir.join("b_folder")).unwrap();
        fs::create_dir(temp_dir.join(".hidden_folder")).unwrap();

        let mut f1 = File::create(temp_dir.join("a_file.txt")).unwrap();
        f1.write_all(b"hello").unwrap(); // 5 bytes

        let mut f2 = File::create(temp_dir.join("c_file.bin")).unwrap();
        f2.write_all(b"longer data content").unwrap(); // 19 bytes

        let mut f3 = File::create(temp_dir.join(".hidden_file")).unwrap();
        f3.write_all(b"secret").unwrap();

        // 1. Scan without hidden files
        let options = ScanOptions {
            show_hidden: false,
            sort: SortOptions {
                field: SortField::Name,
                direction: SortDirection::Ascending,
                folder_position: FolderPosition::First,
            },
        };

        let entries = scan_directory(&temp_dir, &options).unwrap();
        assert_eq!(entries.len(), 3);
        // Folders first: b_folder should be index 0
        assert_eq!(entries[0].name, "b_folder");
        assert!(entries[0].is_dir);
        assert_eq!(entries[1].name, "a_file.txt");
        assert_eq!(entries[2].name, "c_file.bin");

        // 2. Scan with hidden files
        let mut options_hidden = options;
        options_hidden.show_hidden = true;
        let entries_with_hidden = scan_directory(&temp_dir, &options_hidden).unwrap();
        assert_eq!(entries_with_hidden.len(), 5);

        // Clean up
        let _ = fs::remove_dir_all(&temp_dir);
    }
}
