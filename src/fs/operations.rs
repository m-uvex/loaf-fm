use std::fs;
use std::io::{self, Error, ErrorKind};
use std::path::{Path, PathBuf};

/// Strategy when an item with the same name already exists in the destination.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConflictResolution {
    /// Overwrites existing files or merges/replaces folders.
    Overwrite,
    /// Preserves existing files by generating a unique name (e.g. `file (1).txt`).
    RenameUnique,
    /// Aborts operation for this item without modifying destination.
    Skip,
}

impl ConflictResolution {
    pub fn parse(s: &str) -> Self {
        match s.to_ascii_lowercase().as_str() {
            "overwrite" | "replace" => ConflictResolution::Overwrite,
            "skip" | "cancel" => ConflictResolution::Skip,
            _ => ConflictResolution::RenameUnique,
        }
    }
}

/// Checks whether a filename is valid on standard POSIX and Linux filesystems.
pub fn is_valid_filename(name: &str) -> bool {
    let trimmed = name.trim();
    if trimmed.is_empty() || trimmed == "." || trimmed == ".." {
        return false;
    }
    // Disallow null bytes and forward slashes in filenames
    if trimmed.contains('\0') || trimmed.contains('/') {
        return false;
    }
    true
}

/// Splits a filename into (stem, extension) correctly recognizing compound extensions like `.tar.gz`.
pub fn split_stem_and_ext(name: &str) -> (&str, &str) {
    let compound_exts = [
        ".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tar.lz4", ".tar.sz",
    ];

    for ext in &compound_exts {
        if name.to_ascii_lowercase().ends_with(ext) {
            let stem = &name[..name.len() - ext.len()];
            return (stem, ext);
        }
    }

    if let Some(pos) = name.rfind('.') {
        if pos > 0 {
            return (&name[..pos], &name[pos..]);
        }
    }

    (name, "")
}

/// Generates a non-conflicting path in `dest_dir` by appending ` (1)`, ` (2)`, etc.
pub fn generate_unique_path(dest_dir: &Path, name: &str) -> PathBuf {
    let mut candidate = dest_dir.join(name);
    if !candidate.exists() && !candidate.is_symlink() {
        return candidate;
    }

    let (stem, ext) = split_stem_and_ext(name);
    let mut counter: usize = 1;

    loop {
        let unique_name = format!("{} ({}){}", stem, counter, ext);
        candidate = dest_dir.join(&unique_name);
        if !candidate.exists() && !candidate.is_symlink() {
            return candidate;
        }
        counter += 1;
    }
}

/// Creates a new empty file in `parent_dir` with the given `name`.
pub fn create_file(parent_dir: &Path, name: &str) -> io::Result<PathBuf> {
    if !is_valid_filename(name) {
        return Err(Error::new(
            ErrorKind::InvalidInput,
            format!("Invalid filename: '{}'", name),
        ));
    }

    let target = parent_dir.join(name);
    if target.exists() {
        return Err(Error::new(
            ErrorKind::AlreadyExists,
            format!("File already exists: {:?}", target),
        ));
    }

    fs::File::create(&target)?;
    Ok(target)
}

/// Creates a new directory in `parent_dir` with the given `name`.
pub fn create_dir(parent_dir: &Path, name: &str) -> io::Result<PathBuf> {
    if !is_valid_filename(name) {
        return Err(Error::new(
            ErrorKind::InvalidInput,
            format!("Invalid folder name: '{}'", name),
        ));
    }

    let target = parent_dir.join(name);
    if target.exists() {
        return Err(Error::new(
            ErrorKind::AlreadyExists,
            format!("Folder already exists: {:?}", target),
        ));
    }

    fs::create_dir(&target)?;
    Ok(target)
}

/// Renames a file or folder inside `parent_dir` from `old_name` to `new_name`.
pub fn rename_entry(parent_dir: &Path, old_name: &str, new_name: &str) -> io::Result<PathBuf> {
    if !is_valid_filename(new_name) {
        return Err(Error::new(
            ErrorKind::InvalidInput,
            format!("Invalid new name: '{}'", new_name),
        ));
    }

    let src = parent_dir.join(old_name);
    let dst = parent_dir.join(new_name);

    if !src.exists() && !src.is_symlink() {
        return Err(Error::new(
            ErrorKind::NotFound,
            format!("Source does not exist: {:?}", src),
        ));
    }

    if src == dst {
        return Ok(dst);
    }

    if dst.exists() {
        return Err(Error::new(
            ErrorKind::AlreadyExists,
            format!("Destination already exists: {:?}", dst),
        ));
    }

    fs::rename(&src, &dst)?;
    Ok(dst)
}

/// Removes a file, directory, or symlink recursively from disk.
pub fn remove_entry(path: &Path) -> io::Result<()> {
    let meta = match path.symlink_metadata() {
        Ok(m) => m,
        Err(e) if e.kind() == ErrorKind::NotFound => return Ok(()),
        Err(e) => return Err(e),
    };

    if meta.is_dir() {
        fs::remove_dir_all(path)
    } else {
        fs::remove_file(path)
    }
}

/// Pure Rust recursive directory copy.
pub fn copy_dir_recursive(src: &Path, dst: &Path) -> io::Result<()> {
    if !dst.exists() {
        fs::create_dir_all(dst)?;
    }

    for entry_res in fs::read_dir(src)? {
        let entry = entry_res?;
        let entry_path = entry.path();
        let file_name = entry.file_name();
        let target_path = dst.join(file_name);

        let file_type = entry.file_type()?;
        if file_type.is_dir() {
            copy_dir_recursive(&entry_path, &target_path)?;
        } else if file_type.is_symlink() {
            if let Ok(link_target) = fs::read_link(&entry_path) {
                #[cfg(unix)]
                let _ = std::os::unix::fs::symlink(&link_target, &target_path);
            }
        } else {
            fs::copy(&entry_path, &target_path)?;
        }
    }

    Ok(())
}

/// Copies `src` (file or directory) into `dest_dir`, handling name conflicts according to `resolution`.
/// Returns `Ok(Some(final_path))` on success, or `Ok(None)` if skipped.
pub fn copy_entry(
    src: &Path,
    dest_dir: &Path,
    resolution: ConflictResolution,
) -> io::Result<Option<PathBuf>> {
    let name = match src.file_name().and_then(|n| n.to_str()) {
        Some(n) => n,
        None => {
            return Err(Error::new(
                ErrorKind::InvalidInput,
                format!("Invalid source path filename: {:?}", src),
            ))
        }
    };

    let target = dest_dir.join(name);
    let final_dest = if target.exists() || target.is_symlink() {
        match resolution {
            ConflictResolution::Skip => return Ok(None),
            ConflictResolution::RenameUnique => generate_unique_path(dest_dir, name),
            ConflictResolution::Overwrite => {
                if target.is_dir() && src.is_file() {
                    return Err(Error::new(
                        ErrorKind::AlreadyExists,
                        format!("Cannot overwrite existing folder with a file: {:?}", target),
                    ));
                }
                if target.is_file() && src.is_dir() {
                    return Err(Error::new(
                        ErrorKind::AlreadyExists,
                        format!("Cannot overwrite existing file with a folder: {:?}", target),
                    ));
                }
                target
            }
        }
    } else {
        target
    };

    let is_dir = src.metadata().map(|m| m.is_dir()).unwrap_or(false);
    if is_dir {
        copy_dir_recursive(src, &final_dest)?;
    } else {
        fs::copy(src, &final_dest)?;
    }

    Ok(Some(final_dest))
}

/// Moves `src` (file or directory) into `dest_dir`, handling conflicts.
/// Uses fast atomic rename where possible; falls back to copy + remove across file system boundaries.
pub fn move_entry(
    src: &Path,
    dest_dir: &Path,
    resolution: ConflictResolution,
) -> io::Result<Option<PathBuf>> {
    let name = match src.file_name().and_then(|n| n.to_str()) {
        Some(n) => n,
        None => {
            return Err(Error::new(
                ErrorKind::InvalidInput,
                format!("Invalid source path filename: {:?}", src),
            ))
        }
    };

    let target = dest_dir.join(name);
    let final_dest = if target.exists() || target.is_symlink() {
        match resolution {
            ConflictResolution::Skip => return Ok(None),
            ConflictResolution::RenameUnique => generate_unique_path(dest_dir, name),
            ConflictResolution::Overwrite => {
                // Remove existing destination before replacing
                remove_entry(&target)?;
                target
            }
        }
    } else {
        target
    };

    // Attempt fast atomic rename first
    if fs::rename(src, &final_dest).is_ok() {
        return Ok(Some(final_dest));
    }

    // Cross-filesystem fallback: copy then delete source
    copy_entry(src, dest_dir, resolution)?;
    remove_entry(src)?;

    Ok(Some(final_dest))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_filename_validation() {
        assert!(is_valid_filename("hello.txt"));
        assert!(is_valid_filename("my folder"));
        assert!(is_valid_filename(".hidden"));
        assert!(!is_valid_filename(""));
        assert!(!is_valid_filename("   "));
        assert!(!is_valid_filename("."));
        assert!(!is_valid_filename(".."));
        assert!(!is_valid_filename("folder/file"));
        assert!(!is_valid_filename("foo\0bar"));
    }

    #[test]
    fn test_split_stem_and_ext() {
        assert_eq!(split_stem_and_ext("archive.tar.gz"), ("archive", ".tar.gz"));
        assert_eq!(split_stem_and_ext("data.tar.xz"), ("data", ".tar.xz"));
        assert_eq!(split_stem_and_ext("document.pdf"), ("document", ".pdf"));
        assert_eq!(split_stem_and_ext("folder_name"), ("folder_name", ""));
        assert_eq!(split_stem_and_ext(".gitignore"), (".gitignore", ""));
    }

    #[test]
    fn test_file_operations_lifecycle() {
        let temp = std::env::temp_dir().join("loaf_test_file_ops");
        let _ = fs::remove_dir_all(&temp);
        fs::create_dir_all(&temp).unwrap();

        // 1. Create file & directory
        let file_path = create_file(&temp, "notes.txt").unwrap();
        assert!(file_path.exists());
        fs::write(&file_path, b"test content").unwrap();

        let dir_path = create_dir(&temp, "docs").unwrap();
        assert!(dir_path.is_dir());

        // Duplicate creation should fail
        assert!(create_file(&temp, "notes.txt").is_err());
        assert!(create_dir(&temp, "docs").is_err());

        // 2. Rename
        let renamed = rename_entry(&temp, "notes.txt", "notes_renamed.txt").unwrap();
        assert!(renamed.exists());
        assert!(!file_path.exists());

        // 3. Unique name generation
        let unique1 = generate_unique_path(&temp, "notes_renamed.txt");
        assert_eq!(
            unique1.file_name().unwrap().to_str().unwrap(),
            "notes_renamed (1).txt"
        );

        // 4. Copy with RenameUnique
        let copied = copy_entry(&renamed, &temp, ConflictResolution::RenameUnique)
            .unwrap()
            .unwrap();
        assert_eq!(
            copied.file_name().unwrap().to_str().unwrap(),
            "notes_renamed (1).txt"
        );
        assert!(copied.exists());

        // 5. Move
        let moved = move_entry(&copied, &dir_path, ConflictResolution::Overwrite)
            .unwrap()
            .unwrap();
        assert!(moved.exists());
        assert!(!copied.exists());

        // 6. Remove
        remove_entry(&moved).unwrap();
        assert!(!moved.exists());

        // Cleanup
        let _ = fs::remove_dir_all(&temp);
    }
}
