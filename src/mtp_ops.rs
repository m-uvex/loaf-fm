//! MTP file operations: metadata, mkdir, rename, delete, transfer, and local caching.

use crate::fsops::Monitor;
use crate::mtp::Location;
use crate::native;
use serde::Deserialize;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
pub struct Metadata {
    pub name: String,
    pub is_dir: bool,
    pub size: u64,
    pub modified: i64,
}

#[derive(Deserialize, Debug)]
struct StatResponse {
    exists: Option<bool>,
    name: Option<String>,
    is_dir: Option<bool>,
    size: Option<u64>,
    modified: Option<i64>,
    error: Option<String>,
}

#[derive(Deserialize, Debug)]
struct OpResponse {
    ok: Option<bool>,
    error: Option<String>,
}

pub fn metadata(url: &str) -> Result<Option<Metadata>, String> {
    if Location::parse(url).is_none() {
        return Err("Invalid MTP URL".to_string());
    }
    let res = native::mtp_operation_json("stat", url, "");
    let reply: StatResponse = serde_json::from_str(&res)
        .map_err(|e| format!("Failed to parse MTP stat response: {}", e))?;
    if let Some(err) = reply.error {
        if !err.is_empty() {
            return Err(err);
        }
    }
    if reply.exists == Some(true) {
        let name = reply.name.unwrap_or_default();
        if Location::parse(url)
            .and_then(|loc| loc.child(&name))
            .is_none()
        {
            return Err("Invalid filename returned by phone".to_string());
        }
        Ok(Some(Metadata {
            name,
            is_dir: reply.is_dir.unwrap_or(false),
            size: reply.size.unwrap_or(0),
            modified: reply.modified.unwrap_or(0),
        }))
    } else {
        Ok(None)
    }
}

pub fn mkdir(parent_url: &str, name: &str) -> Result<String, String> {
    let parent_loc =
        Location::parse(parent_url).ok_or_else(|| "Invalid parent MTP URL".to_string())?;
    if parent_loc.is_root() {
        return Err("Cannot create directory in device root".to_string());
    }
    let child_loc = parent_loc
        .child(name)
        .ok_or_else(|| "Invalid directory name".to_string())?;
    let res = native::mtp_operation_json("mkdir", &parent_loc.url(), name);
    let reply: OpResponse = serde_json::from_str(&res)
        .map_err(|e| format!("Failed to parse MTP mkdir response: {}", e))?;
    if let Some(err) = reply.error {
        if !err.is_empty() {
            return Err(err);
        }
    }
    if reply.ok == Some(true) {
        Ok(child_loc.url())
    } else {
        Err("Failed to create directory on MTP device".to_string())
    }
}

pub fn rename(url: &str, name: &str) -> Result<String, String> {
    let loc = Location::parse(url).ok_or_else(|| "Invalid MTP URL".to_string())?;
    if loc.is_root() || loc.dirs().is_empty() && loc.storage().is_some() {
        return Err("Cannot rename device or storage root".to_string());
    }
    let parent = loc
        .parent()
        .ok_or_else(|| "Target has no parent".to_string())?;
    let new_loc = parent
        .child(name)
        .ok_or_else(|| "Invalid new name for rename".to_string())?;
    if new_loc == loc {
        return Ok(loc.url());
    }
    if metadata(&new_loc.url())?.is_some() {
        return Err("An item with that name already exists on the phone".to_string());
    }
    let res = native::mtp_operation_json("rename", &loc.url(), name);
    let reply: OpResponse = serde_json::from_str(&res)
        .map_err(|e| format!("Failed to parse MTP rename response: {}", e))?;
    if let Some(err) = reply.error {
        if !err.is_empty() {
            return Err(err);
        }
    }
    if reply.ok == Some(true) {
        Ok(new_loc.url())
    } else {
        Err("Failed to rename object on MTP device".to_string())
    }
}

pub fn remove(paths: &[String], mon: &dyn Monitor) -> Result<(), String> {
    for p in paths {
        if mon.cancelled() {
            return Err("cancelled".to_string());
        }
        let loc = Location::parse(p).ok_or_else(|| format!("Invalid MTP URL: {}", p))?;
        if loc.is_root() || loc.dirs().is_empty() && loc.storage().is_some() {
            return Err("Cannot delete device or storage root".to_string());
        }
        let res = native::mtp_operation_json("delete", &loc.url(), "");
        let reply: OpResponse = serde_json::from_str(&res)
            .map_err(|e| format!("Failed to parse MTP delete response: {}", e))?;
        if let Some(err) = reply.error {
            if !err.is_empty() {
                return Err(err);
            }
        }
        if reply.ok != Some(true) {
            return Err(format!("Failed to delete {}", p));
        }
    }
    Ok(())
}

pub fn local_copy(url: &str, mon: &dyn Monitor) -> Result<PathBuf, String> {
    let loc = Location::parse(url).ok_or_else(|| "Invalid MTP URL".to_string())?;
    if loc.is_root() || loc.dirs().is_empty() && loc.storage().is_some() {
        return Err("Cannot download device or storage root as a file".to_string());
    }
    let meta = metadata(&loc.url())?.ok_or_else(|| "File not found on MTP device".to_string())?;
    if meta.is_dir {
        return Err("Cannot download directory as a single file".to_string());
    }

    let private = tempfile_staging_dir()?;
    let target = private.join(sanitize_filename(&loc.title()));

    if mon.cancelled() {
        return Err("cancelled".to_string());
    }

    let target_str = target
        .to_str()
        .ok_or_else(|| "Invalid UTF-8 in target path".to_string())?;
    let res = native::mtp_operation_json("download", &loc.url(), target_str);
    let reply: OpResponse = serde_json::from_str(&res)
        .map_err(|e| format!("Failed to parse download response: {}", e))?;
    if let Some(err) = reply.error {
        if !err.is_empty() {
            return Err(err);
        }
    }
    if reply.ok != Some(true) {
        return Err("Failed to download file from MTP device".to_string());
    }
    if fs::metadata(&target).map_err(|e| e.to_string())?.len() != meta.size {
        return Err("Downloaded phone file has an unexpected size".to_string());
    }
    mon.advance(meta.size, &target);
    Ok(target)
}

// A move must not erase new or changed source items that were not part of the copy.
fn source_snapshot(
    path: &str,
    mon: &dyn Monitor,
) -> Result<Vec<(String, bool, u64, i128)>, String> {
    let mut result = Vec::new();
    if let Some(location) = Location::parse(path) {
        let meta = metadata(&location.url())?.ok_or("Source disappeared during move")?;
        result.push((
            location.url(),
            meta.is_dir,
            meta.size,
            if meta.is_dir {
                0
            } else {
                meta.modified as i128
            },
        ));
        let mut stack = if meta.is_dir {
            vec![location]
        } else {
            Vec::new()
        };
        while let Some(folder) = stack.pop() {
            if mon.cancelled() {
                return Err("cancelled; source preserved".into());
            }
            for entry in crate::mtp::list(&folder)? {
                let child = folder.child(&entry.name).ok_or("Invalid phone filename")?;
                result.push((
                    child.url(),
                    entry.is_dir,
                    entry.size,
                    if entry.is_dir {
                        0
                    } else {
                        entry.modified as i128
                    },
                ));
                if entry.is_dir {
                    stack.push(child);
                }
            }
        }
    } else {
        use std::os::unix::fs::MetadataExt;
        let mut stack = vec![PathBuf::from(path)];
        while let Some(item) = stack.pop() {
            if mon.cancelled() {
                return Err("cancelled; source preserved".into());
            }
            let meta = fs::symlink_metadata(&item).map_err(|e| e.to_string())?;
            if !meta.is_dir() && !meta.is_file() {
                return Err("Unsupported source type for MTP move".into());
            }
            result.push((
                item.to_string_lossy().into_owned(),
                meta.is_dir(),
                if meta.is_dir() { 0 } else { meta.len() },
                if meta.is_dir() {
                    0
                } else {
                    meta.mtime() as i128 * 1_000_000_000 + meta.mtime_nsec() as i128
                },
            ));
            if meta.is_dir() {
                for child in fs::read_dir(&item).map_err(|e| e.to_string())? {
                    stack.push(child.map_err(|e| e.to_string())?.path());
                }
            }
        }
    }
    result.sort();
    Ok(result)
}

fn check_move_source(
    path: &str,
    before: &Option<Vec<(String, bool, u64, i128)>>,
    mon: &dyn Monitor,
) -> Result<(), String> {
    if let Some(before) = before {
        if &source_snapshot(path, mon)? != before {
            return Err("Source changed during transfer; it has been preserved".into());
        }
    }
    Ok(())
}

pub fn transfer(
    paths: &[String],
    dest: &str,
    mode: &str,
    mon: &dyn Monitor,
) -> Result<Vec<String>, String> {
    let is_dest_mtp = dest.starts_with("mtp://");
    let any_src_mtp = paths.iter().any(|p| p.starts_with("mtp://"));

    if !is_dest_mtp && !any_src_mtp {
        return Err(
            "Neither source nor destination is an MTP path (use fsops for local transfers)"
                .to_string(),
        );
    }

    if !matches!(mode, "copy" | "move") {
        return Err("MTP supports copy and move, not links".to_string());
    }
    let mut completed = Vec::new();

    if is_dest_mtp && !any_src_mtp {
        // Local -> MTP
        let dest_loc =
            Location::parse(dest).ok_or_else(|| "Invalid destination MTP URL".to_string())?;
        if dest_loc.is_root() {
            return Err("Cannot transfer directly to device root".to_string());
        }
        for src_str in paths {
            if mon.cancelled() {
                return Err("cancelled".to_string());
            }
            let before = if mode == "move" {
                Some(source_snapshot(src_str, mon)?)
            } else {
                None
            };
            let src_path = PathBuf::from(src_str);
            let meta = fs::symlink_metadata(&src_path)
                .map_err(|e| format!("Failed to stat source {}: {}", src_str, e))?;
            if meta.file_type().is_symlink()
                || !meta.file_type().is_dir() && !meta.file_type().is_file()
            {
                return Err(format!("Unsupported file type for MTP: {}", src_str));
            }
            let file_name = src_path
                .file_name()
                .and_then(|n| n.to_str())
                .ok_or_else(|| format!("Invalid source file name: {}", src_str))?;

            let final_name = find_unique_mtp_name(&dest_loc, file_name)?;
            let item_url = if meta.is_dir() {
                upload_dir_recursive(&src_path, &dest_loc, &final_name, mon)?
            } else {
                upload_file(&src_path, &dest_loc, &final_name, mon)?
            };
            if mode == "move" {
                if mon.cancelled() {
                    return Err("cancelled; source preserved".to_string());
                }
                check_move_source(src_str, &before, mon)?;
                if meta.is_dir() {
                    fs::remove_dir_all(&src_path).map_err(|e| {
                        format!("Failed to clean up source directory {}: {}", src_str, e)
                    })?;
                } else {
                    fs::remove_file(&src_path).map_err(|e| {
                        format!("Failed to clean up source file {}: {}", src_str, e)
                    })?;
                }
            }
            completed.push(item_url);
        }
    } else if !is_dest_mtp && any_src_mtp {
        // MTP -> Local
        let dest_path = PathBuf::from(dest);
        if !dest_path.is_dir() {
            return Err("Local destination must be an existing directory".to_string());
        }
        for src_url in paths {
            if mon.cancelled() {
                return Err("cancelled".to_string());
            }
            let src_loc = Location::parse(src_url)
                .ok_or_else(|| format!("Invalid source MTP URL: {}", src_url))?;
            if src_loc.is_root() || src_loc.dirs().is_empty() && src_loc.storage().is_some() {
                return Err("Cannot transfer device or storage root".to_string());
            }
            let before = if mode == "move" {
                Some(source_snapshot(src_url, mon)?)
            } else {
                None
            };
            let meta = metadata(src_url)?
                .ok_or_else(|| format!("Source not found on MTP device: {}", src_url))?;
            let final_name = find_unique_local_name(&dest_path, &meta.name);
            let target_item = dest_path.join(&final_name);

            if meta.is_dir {
                download_dir_recursive(&src_loc, &target_item, mon)?;
            } else {
                download_file(&src_loc, &target_item, meta.size, mon)?;
            }

            if mode == "move" {
                check_move_source(src_url, &before, mon)?;
                remove(&[src_url.clone()], mon)?;
            }
            completed.push(target_item.to_str().unwrap().to_string());
        }
    } else {
        // MTP -> MTP
        let dest_loc =
            Location::parse(dest).ok_or_else(|| "Invalid destination MTP URL".to_string())?;
        if dest_loc.is_root() {
            return Err("Cannot transfer directly to device root".to_string());
        }
        for src_url in paths {
            if mon.cancelled() {
                return Err("cancelled".to_string());
            }
            let src_loc = Location::parse(src_url)
                .ok_or_else(|| format!("Invalid source MTP URL: {}", src_url))?;
            if src_loc.is_root() || src_loc.dirs().is_empty() && src_loc.storage().is_some() {
                return Err("Cannot transfer device or storage root".to_string());
            }
            // Check self or recursive ancestor copy
            if dest_loc == src_loc || dest_loc.url().starts_with(&(src_loc.url() + "/")) {
                return Err("Cannot copy a directory into itself or its descendant".to_string());
            }

            let before = if mode == "move" {
                Some(source_snapshot(src_url, mon)?)
            } else {
                None
            };
            let meta = metadata(src_url)?
                .ok_or_else(|| format!("Source not found on MTP device: {}", src_url))?;

            // Optimization: if move within same parent, perform rename
            if mode == "move" && src_loc.parent() == Some(dest_loc.clone()) {
                completed.push(src_loc.url());
                continue;
            }

            // Transfer via private staging directory
            let staging_dir = tempfile_staging_dir()?;
            let staged_target = staging_dir.join(&meta.name);

            if meta.is_dir {
                download_dir_recursive(&src_loc, &staged_target, mon)?;
            } else {
                download_file(&src_loc, &staged_target, meta.size, mon)?;
            }

            let final_name = find_unique_mtp_name(&dest_loc, &meta.name)?;
            let item_url = if meta.is_dir {
                upload_dir_recursive(&staged_target, &dest_loc, &final_name, mon)?
            } else {
                upload_file(&staged_target, &dest_loc, &final_name, mon)?
            };

            let _ = fs::remove_dir_all(&staging_dir);

            if mode == "move" {
                check_move_source(src_url, &before, mon)?;
                remove(&[src_url.clone()], mon)?;
            }
            completed.push(item_url);
        }
    }

    Ok(completed)
}

fn upload_file(
    src_file: &Path,
    dest_loc: &Location,
    dest_name: &str,
    mon: &dyn Monitor,
) -> Result<String, String> {
    if mon.cancelled() {
        return Err("cancelled".to_string());
    }
    let target_loc = dest_loc
        .child(dest_name)
        .ok_or_else(|| "Invalid target file name".to_string())?;
    let src_str = src_file
        .to_str()
        .ok_or_else(|| "Invalid UTF-8 in source file path".to_string())?;

    let res = native::mtp_operation_json("upload", &target_loc.url(), src_str);
    let reply: OpResponse = serde_json::from_str(&res)
        .map_err(|e| format!("Failed to parse upload response: {}", e))?;
    if let Some(err) = reply.error {
        if !err.is_empty() {
            return Err(err);
        }
    }
    if reply.ok != Some(true) {
        return Err(format!("Failed to upload file to {}", target_loc.url()));
    }
    let sz = fs::metadata(src_file).map(|m| m.len()).unwrap_or(0);
    if metadata(&target_loc.url())?.map(|entry| entry.size) != Some(sz) {
        return Err("Phone upload size could not be verified; source preserved".to_string());
    }
    mon.advance(sz, src_file);
    Ok(target_loc.url())
}

fn upload_dir_recursive(
    src_dir: &Path,
    dest_parent: &Location,
    dir_name: &str,
    mon: &dyn Monitor,
) -> Result<String, String> {
    if mon.cancelled() {
        return Err("cancelled".to_string());
    }
    let created_url = mkdir(&dest_parent.url(), dir_name)?;
    let created_loc = Location::parse(&created_url)
        .ok_or_else(|| "Failed to parse created MTP directory URL".to_string())?;

    let rd = fs::read_dir(src_dir).map_err(|e| {
        format!(
            "Failed to read source directory {}: {}",
            src_dir.display(),
            e
        )
    })?;
    for entry in rd {
        if mon.cancelled() {
            return Err("cancelled".to_string());
        }
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        let meta = fs::symlink_metadata(&path).map_err(|e| e.to_string())?;
        if meta.file_type().is_symlink()
            || !meta.file_type().is_dir() && !meta.file_type().is_file()
        {
            return Err(format!("Unsupported file type for MTP: {}", path.display()));
        }
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .ok_or("Invalid filename")?;
        let unique_name = find_unique_mtp_name(&created_loc, name)?;
        if meta.is_dir() {
            upload_dir_recursive(&path, &created_loc, &unique_name, mon)?;
        } else {
            upload_file(&path, &created_loc, &unique_name, mon)?;
        }
    }
    Ok(created_url)
}

fn download_file(
    src_loc: &Location,
    dest_file: &Path,
    size: u64,
    mon: &dyn Monitor,
) -> Result<(), String> {
    if mon.cancelled() {
        return Err("cancelled".to_string());
    }
    let dest_str = dest_file
        .to_str()
        .ok_or_else(|| "Invalid UTF-8 in destination file path".to_string())?;
    let res = native::mtp_operation_json("download", &src_loc.url(), dest_str);
    let reply: OpResponse = serde_json::from_str(&res)
        .map_err(|e| format!("Failed to parse download response: {}", e))?;
    if let Some(err) = reply.error {
        if !err.is_empty() {
            return Err(err);
        }
    }
    if reply.ok != Some(true) {
        return Err(format!("Failed to download file from {}", src_loc.url()));
    }
    if fs::metadata(dest_file).map_err(|e| e.to_string())?.len() != size {
        return Err("Phone download was incomplete; source preserved".to_string());
    }
    mon.advance(size, dest_file);
    Ok(())
}

fn download_dir_recursive(
    src_loc: &Location,
    dest_dir: &Path,
    mon: &dyn Monitor,
) -> Result<(), String> {
    if mon.cancelled() {
        return Err("cancelled".to_string());
    }
    fs::create_dir(dest_dir).map_err(|e| {
        format!(
            "Failed to create local directory {}: {}",
            dest_dir.display(),
            e
        )
    })?;

    let entries = crate::mtp::list(src_loc)?;
    for entry in entries {
        if mon.cancelled() {
            return Err("cancelled".to_string());
        }
        let child_loc = src_loc
            .child(&entry.name)
            .ok_or_else(|| format!("Invalid child name: {}", entry.name))?;
        let unique_name = find_unique_local_name(dest_dir, &entry.name);
        let child_dest = dest_dir.join(&unique_name);
        if entry.is_dir {
            download_dir_recursive(&child_loc, &child_dest, mon)?;
        } else {
            download_file(&child_loc, &child_dest, entry.size, mon)?;
        }
    }
    Ok(())
}

pub fn find_unique_local_name(dir: &Path, original_name: &str) -> String {
    if fs::symlink_metadata(dir.join(original_name)).is_err() {
        return original_name.to_string();
    }
    let (stem, ext) = split_name(original_name);
    let mut counter = 1;
    loop {
        let candidate = if ext.is_empty() {
            format!("{} ({})", stem, counter)
        } else {
            format!("{} ({}).{}", stem, counter, ext)
        };
        if fs::symlink_metadata(dir.join(&candidate)).is_err() {
            return candidate;
        }
        counter += 1;
    }
}

pub fn find_unique_mtp_name(parent_loc: &Location, original_name: &str) -> Result<String, String> {
    let check_url = parent_loc
        .child(original_name)
        .ok_or_else(|| "Invalid child name".to_string())?
        .url();
    if metadata(&check_url)?.is_none() {
        return Ok(original_name.to_string());
    }
    let (stem, ext) = split_name(original_name);
    let mut counter = 1;
    loop {
        let candidate = if ext.is_empty() {
            format!("{} ({})", stem, counter)
        } else {
            format!("{} ({}).{}", stem, counter, ext)
        };
        let check_url = parent_loc
            .child(&candidate)
            .ok_or_else(|| "Invalid candidate name".to_string())?
            .url();
        if metadata(&check_url)?.is_none() {
            return Ok(candidate);
        }
        counter += 1;
    }
}

pub fn split_name(name: &str) -> (&str, &str) {
    match name.rfind('.') {
        Some(i) if i > 0 && i + 1 < name.len() => (&name[..i], &name[i + 1..]),
        _ => (name, ""),
    }
}

fn sanitize_filename(name: &str) -> String {
    let mut out = String::new();
    for c in name.chars() {
        if c.is_alphanumeric() || c == '.' || c == '-' || c == '_' {
            out.push(c);
        } else {
            out.push('_');
        }
    }
    if out.is_empty() {
        "file".to_string()
    } else {
        out
    }
}

fn dirs_next_cache_dir() -> PathBuf {
    if let Ok(p) = std::env::var("XDG_CACHE_HOME") {
        if !p.is_empty() {
            return PathBuf::from(p);
        }
    }
    if let Ok(home) = std::env::var("HOME") {
        return PathBuf::from(home).join(".cache");
    }
    PathBuf::from("/tmp")
}

fn tempfile_staging_dir() -> Result<PathBuf, String> {
    let base = dirs_next_cache_dir().join("loaf/mtp_staging");
    let unique = base.join(format!("{}_{}", std::process::id(), rand_nonce()));
    fs::create_dir_all(&base).map_err(|e| e.to_string())?;
    use std::os::unix::fs::DirBuilderExt;
    fs::DirBuilder::new()
        .mode(0o700)
        .create(&unique)
        .map_err(|e| e.to_string())?;
    Ok(unique)
}

fn rand_nonce() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos() as u64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_split_name() {
        assert_eq!(split_name("foo.tar.gz"), ("foo.tar", "gz"));
        assert_eq!(split_name("notes.txt"), ("notes", "txt"));
        assert_eq!(split_name("README"), ("README", ""));
        assert_eq!(split_name(".hidden"), (".hidden", ""));
    }

    #[test]
    fn test_sanitize_filename() {
        assert_eq!(sanitize_filename("hello world/1.jpg"), "hello_world_1.jpg");
        assert_eq!(sanitize_filename("a#%π"), "a__π");
        assert_eq!(sanitize_filename(""), "file");
    }

    #[test]
    fn test_find_unique_local_name() {
        let temp_dir = tempfile_staging_dir().unwrap();
        let f1 = temp_dir.join("photo.jpg");
        fs::write(&f1, b"1").unwrap();

        let unique1 = find_unique_local_name(&temp_dir, "photo.jpg");
        assert_eq!(unique1, "photo (1).jpg");

        let f2 = temp_dir.join("photo (1).jpg");
        fs::write(&f2, b"2").unwrap();

        let unique2 = find_unique_local_name(&temp_dir, "photo.jpg");
        assert_eq!(unique2, "photo (2).jpg");

        let unique_new = find_unique_local_name(&temp_dir, "other.txt");
        assert_eq!(unique_new, "other.txt");

        let _ = fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_stat_response_decode() {
        let json_exists = r#"{"exists": true, "name": "notes.txt", "is_dir": false, "size": 123, "modified": 1700000000}"#;
        let stat: StatResponse = serde_json::from_str(json_exists).unwrap();
        assert_eq!(stat.exists, Some(true));
        assert_eq!(stat.name.as_deref(), Some("notes.txt"));
        assert_eq!(stat.size, Some(123));

        let json_missing = r#"{"exists": false}"#;
        let stat_m: StatResponse = serde_json::from_str(json_missing).unwrap();
        assert_eq!(stat_m.exists, Some(false));

        let json_err = r#"{"error": "Device is disconnected"}"#;
        let stat_e: StatResponse = serde_json::from_str(json_err).unwrap();
        assert_eq!(stat_e.error.as_deref(), Some("Device is disconnected"));
    }
}
