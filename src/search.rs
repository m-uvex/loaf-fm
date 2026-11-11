//! Recursive file search for worker threads: matches names (and optionally
//! text contents), streams results in batches, stops when cancelled, and
//! stays on local filesystems.

use crate::listing::{self, Entry};
use std::collections::HashSet;
use std::fs;
use std::io::Read;
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

pub struct Query {
    pub text: String,
    pub root: PathBuf,
    pub show_hidden: bool,
    /// Also look inside text files.
    pub contents: bool,
    pub max_results: usize,
}

/// Folders that are almost never what a person is searching for.
const NOISE: [&str; 9] = [
    ".git",
    "node_modules",
    "target",
    ".cache",
    ".direnv",
    "__pycache__",
    ".npm",
    ".cargo",
    ".rustup",
];

/// Device ids of mounts we must not descend into (network shares, FUSE
/// remotes, pseudo filesystems): a hung NFS server would freeze the search.
fn excluded_devices() -> HashSet<u64> {
    let mut out = HashSet::new();
    let Ok(m) = fs::read_to_string("/proc/self/mounts") else {
        return out;
    };
    for line in m.lines() {
        let mut p = line.split_whitespace();
        let (Some(_), Some(mnt), Some(fs)) = (p.next(), p.next(), p.next()) else {
            continue;
        };
        let remote = matches!(
            fs,
            "nfs"
                | "nfs4"
                | "cifs"
                | "smb3"
                | "smbfs"
                | "sshfs"
                | "9p"
                | "afs"
                | "ceph"
                | "glusterfs"
        ) || fs.starts_with("fuse.")
            && !matches!(fs, "fuse.ntfs-3g" | "fuse.ntfs" | "fuse.exfat");
        if remote || crate::trash::is_virtual_fs(fs) && fs != "tmpfs" {
            // Only stat the mount point itself; never anything below it.
            let mnt = crate::trash::unescape_mount(mnt);
            if let Ok(meta) = fs::symlink_metadata(&mnt) {
                out.insert(meta.dev());
            }
        }
    }
    out
}

fn file_contains(path: &Path, needle_lower: &str, size: u64) -> bool {
    if size == 0 || size > 4 * 1024 * 1024 || needle_lower.is_empty() {
        return false;
    }
    let Ok(mut f) = fs::File::open(path) else {
        return false;
    };
    let mut buf = Vec::with_capacity(size as usize);
    if f.read_to_end(&mut buf).is_err() {
        return false;
    }
    if buf.iter().take(8192).any(|b| *b == 0) {
        return false; // binary
    }
    String::from_utf8_lossy(&buf)
        .to_lowercase()
        .contains(needle_lower)
}

/// Runs the search, calling `emit` with batches of matches (roughly every
/// 150 ms) until done, cancelled, or `max_results` is reached. Returns the
/// number of matches.
pub fn run(q: &Query, cancelled: &dyn Fn() -> bool, emit: &mut dyn FnMut(Vec<Entry>)) -> usize {
    let needle = q.text.trim().to_lowercase();
    if needle.is_empty() {
        return 0;
    }
    let excluded = excluded_devices();
    let mut batch: Vec<Entry> = Vec::new();
    let mut total = 0usize;
    let mut last_emit = Instant::now();
    // Breadth-first so shallow (likely more relevant) hits come first.
    let mut queue = std::collections::VecDeque::from([(q.root.clone(), 0usize)]);
    let mut visited_dirs = HashSet::new();
    let empty = HashSet::new();
    while let Some((dir, depth)) = queue.pop_front() {
        if cancelled() || total >= q.max_results {
            break;
        }
        let Ok(rd) = fs::read_dir(&dir) else { continue };
        for e in rd.flatten() {
            if total >= q.max_results || cancelled() {
                break;
            }
            let name = e.file_name().to_string_lossy().to_string();
            if !q.show_hidden && name.starts_with('.') && !needle.starts_with('.') {
                continue;
            }
            let Ok(ft) = e.file_type() else { continue };
            let path = e.path();
            let name_hit = name.to_lowercase().contains(&needle);
            if ft.is_dir() && !ft.is_symlink() {
                if NOISE.contains(&name.as_str()) || depth >= 24 {
                    // still allow a direct name hit on the folder itself
                } else if let Ok(meta) = e.metadata() {
                    let dev = meta.dev();
                    if !excluded.contains(&dev) && visited_dirs.insert((dev, meta.ino())) {
                        queue.push_back((path.clone(), depth + 1));
                    }
                }
            }
            let content_hit = !name_hit
                && q.contents
                && ft.is_file()
                && e.metadata()
                    .map(|m| file_contains(&path, &needle, m.len()))
                    .unwrap_or(false);
            if name_hit || content_hit {
                if let Some(mut entry) = listing::entry_for(&path, &name, &empty) {
                    entry.detail = dir.to_string_lossy().to_string();
                    batch.push(entry);
                    total += 1;
                }
            }
            if !batch.is_empty() && last_emit.elapsed() >= Duration::from_millis(150) {
                emit(std::mem::take(&mut batch));
                last_emit = Instant::now();
            }
        }
    }
    if !batch.is_empty() && !cancelled() {
        emit(batch);
    }
    total
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_names_contents_and_respects_hidden() {
        let d = std::env::temp_dir().join(format!("loaf-search-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(d.join("a/b/c")).unwrap();
        fs::create_dir_all(d.join(".secret")).unwrap();
        fs::create_dir_all(d.join("node_modules/report")).unwrap();
        fs::write(d.join("a/b/c/Report-2024.pdf"), b"x").unwrap();
        fs::write(d.join("a/notes.txt"), b"the quarterly REPORT is due").unwrap();
        fs::write(d.join(".secret/report.md"), b"x").unwrap();
        fs::write(d.join("node_modules/report/x"), b"x").unwrap();
        let mut found = Vec::new();
        let q = Query {
            text: "report".into(),
            root: d.clone(),
            show_hidden: false,
            contents: false,
            max_results: 100,
        };
        run(&q, &|| false, &mut |b| {
            found.extend(b.into_iter().map(|e| e.name))
        });
        found.sort();
        assert_eq!(
            found,
            vec!["Report-2024.pdf"],
            "hidden folders and node_modules are skipped"
        );

        let mut found = Vec::new();
        let q = Query {
            contents: true,
            show_hidden: true,
            ..q
        };
        run(&q, &|| false, &mut |b| {
            found.extend(b.into_iter().map(|e| e.name))
        });
        assert!(found.contains(&"notes.txt".to_string()));
        assert!(found.contains(&"report.md".to_string()));

        let mut n = 0;
        let q = Query {
            max_results: 1,
            ..q
        };
        run(&q, &|| false, &mut |b| n += b.len());
        assert_eq!(n, 1);
        let mut n = 0;
        run(&q, &|| true, &mut |b| n += b.len());
        assert_eq!(n, 0, "cancelled search emits nothing");
        fs::remove_dir_all(&d).unwrap();
    }
}
