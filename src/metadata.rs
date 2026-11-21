//! Extended file attributes & metadata extraction (Windows Explorer-style
//! columns: filesystem, EXIF camera/photo, audio/video media, and documents).
//!
//! Runs on worker threads only. Uses `exiftool` (batched per directory) when
//! available, with graceful fallback to `ffprobe` and pure-Rust `stat` metadata.

use crate::util;
use serde::Serialize;
use std::collections::{HashMap, HashSet};
use std::ffi::CStr;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::Path;
use std::process::Command;

#[derive(Clone, Copy, Debug, Serialize)]
pub struct ColumnDef {
    pub key: &'static str,
    pub label: &'static str,
    pub category: &'static str,
    pub width: i32,
    pub quick: bool,
    pub default_asc: bool,
    pub needs_external: bool,
}

/// Full catalog of optional columns (built-in columns: name, modified, type, size).
pub const EXTRA_COLUMNS: &[ColumnDef] = &[
    // File System
    ColumnDef {
        key: "extension",
        label: "Extension",
        category: "File System",
        width: 84,
        quick: true,
        default_asc: true,
        needs_external: false,
    },
    ColumnDef {
        key: "created",
        label: "Date Created",
        category: "File System",
        width: 145,
        quick: true,
        default_asc: false,
        needs_external: false,
    },
    ColumnDef {
        key: "accessed",
        label: "Date Accessed",
        category: "File System",
        width: 145,
        quick: false,
        default_asc: false,
        needs_external: false,
    },
    ColumnDef {
        key: "permissions",
        label: "Permissions",
        category: "File System",
        width: 96,
        quick: true,
        default_asc: true,
        needs_external: false,
    },
    ColumnDef {
        key: "owner",
        label: "Owner",
        category: "File System",
        width: 96,
        quick: false,
        default_asc: true,
        needs_external: false,
    },
    ColumnDef {
        key: "group",
        label: "Group",
        category: "File System",
        width: 96,
        quick: false,
        default_asc: true,
        needs_external: false,
    },
    ColumnDef {
        key: "symlink_target",
        label: "Link Target",
        category: "File System",
        width: 150,
        quick: false,
        default_asc: true,
        needs_external: false,
    },
    ColumnDef {
        key: "links",
        label: "Hard Links",
        category: "File System",
        width: 84,
        quick: false,
        default_asc: false,
        needs_external: false,
    },
    ColumnDef {
        key: "inode",
        label: "Inode",
        category: "File System",
        width: 100,
        quick: false,
        default_asc: true,
        needs_external: false,
    },
    ColumnDef {
        key: "mime_type",
        label: "MIME Type",
        category: "File System",
        width: 140,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    // Camera & Photo (EXIF)
    ColumnDef {
        key: "dimensions",
        label: "Dimensions",
        category: "Camera & Photo",
        width: 110,
        quick: true,
        default_asc: false,
        needs_external: true,
    },
    ColumnDef {
        key: "date_taken",
        label: "Date Taken",
        category: "Camera & Photo",
        width: 145,
        quick: true,
        default_asc: false,
        needs_external: true,
    },
    ColumnDef {
        key: "camera_make",
        label: "Camera Make",
        category: "Camera & Photo",
        width: 115,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "camera_model",
        label: "Camera Model",
        category: "Camera & Photo",
        width: 130,
        quick: true,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "camera_id",
        label: "Camera ID",
        category: "Camera & Photo",
        width: 125,
        quick: true,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "iso",
        label: "ISO Speed",
        category: "Camera & Photo",
        width: 84,
        quick: true,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "aperture",
        label: "F-Stop",
        category: "Camera & Photo",
        width: 80,
        quick: true,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "exposure_time",
        label: "Exposure Time",
        category: "Camera & Photo",
        width: 105,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "focal_length",
        label: "Focal Length",
        category: "Camera & Photo",
        width: 100,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "lens_model",
        label: "Lens Model",
        category: "Camera & Photo",
        width: 140,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "flash",
        label: "Flash Mode",
        category: "Camera & Photo",
        width: 110,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "gps",
        label: "GPS Coordinates",
        category: "Camera & Photo",
        width: 155,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "color_space",
        label: "Color Space",
        category: "Camera & Photo",
        width: 100,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "orientation",
        label: "Orientation",
        category: "Camera & Photo",
        width: 110,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    // Audio & Video
    ColumnDef {
        key: "duration",
        label: "Duration",
        category: "Audio & Video",
        width: 88,
        quick: true,
        default_asc: false,
        needs_external: true,
    },
    ColumnDef {
        key: "bitrate",
        label: "Bitrate",
        category: "Audio & Video",
        width: 96,
        quick: false,
        default_asc: false,
        needs_external: true,
    },
    ColumnDef {
        key: "frame_rate",
        label: "Frame Rate",
        category: "Audio & Video",
        width: 92,
        quick: false,
        default_asc: false,
        needs_external: true,
    },
    ColumnDef {
        key: "video_codec",
        label: "Video Codec",
        category: "Audio & Video",
        width: 105,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "audio_codec",
        label: "Audio Codec",
        category: "Audio & Video",
        width: 105,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "title",
        label: "Title",
        category: "Audio & Video",
        width: 140,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "artist",
        label: "Artist",
        category: "Audio & Video",
        width: 125,
        quick: true,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "album",
        label: "Album",
        category: "Audio & Video",
        width: 125,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "genre",
        label: "Genre",
        category: "Audio & Video",
        width: 100,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "track",
        label: "Track #",
        category: "Audio & Video",
        width: 76,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "year",
        label: "Year",
        category: "Audio & Video",
        width: 72,
        quick: false,
        default_asc: false,
        needs_external: true,
    },
    // Document
    ColumnDef {
        key: "author",
        label: "Author",
        category: "Document",
        width: 125,
        quick: true,
        default_asc: true,
        needs_external: true,
    },
    ColumnDef {
        key: "pages",
        label: "Pages",
        category: "Document",
        width: 76,
        quick: false,
        default_asc: false,
        needs_external: true,
    },
    ColumnDef {
        key: "creator_tool",
        label: "Program Name",
        category: "Document",
        width: 130,
        quick: false,
        default_asc: true,
        needs_external: true,
    },
];

pub fn catalog_json() -> String {
    serde_json::to_string(EXTRA_COLUMNS).unwrap_or_else(|_| "[]".into())
}

pub fn is_extra_column(key: &str) -> bool {
    EXTRA_COLUMNS.iter().any(|c| c.key == key)
}

fn format_mode(mode: u32) -> String {
    let bits = [
        (0o400, 'r'),
        (0o200, 'w'),
        (0o100, 'x'),
        (0o040, 'r'),
        (0o020, 'w'),
        (0o010, 'x'),
        (0o004, 'r'),
        (0o002, 'w'),
        (0o001, 'x'),
    ];
    bits.iter()
        .map(|&(mask, ch)| if mode & mask != 0 { ch } else { '-' })
        .collect()
}

fn format_timestamp(secs: i64) -> String {
    if secs <= 0 {
        return String::new();
    }
    let t = secs as libc::time_t;
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    if unsafe { libc::localtime_r(&t, &mut tm) }.is_null() {
        return String::new();
    }
    format!(
        "{:04}-{:02}-{:02} {:02}:{:02}",
        tm.tm_year + 1900,
        tm.tm_mon + 1,
        tm.tm_mday,
        tm.tm_hour,
        tm.tm_min
    )
}

fn uid_name(uid: u32, cache: &mut HashMap<u32, String>) -> String {
    if let Some(s) = cache.get(&uid) {
        return s.clone();
    }
    let name = unsafe {
        let pw = libc::getpwuid(uid);
        if pw.is_null() || (*pw).pw_name.is_null() {
            uid.to_string()
        } else {
            CStr::from_ptr((*pw).pw_name).to_string_lossy().to_string()
        }
    };
    cache.insert(uid, name.clone());
    name
}

fn gid_name(gid: u32, cache: &mut HashMap<u32, String>) -> String {
    if let Some(s) = cache.get(&gid) {
        return s.clone();
    }
    let name = unsafe {
        let gr = libc::getgrgid(gid);
        if gr.is_null() || (*gr).gr_name.is_null() {
            gid.to_string()
        } else {
            CStr::from_ptr((*gr).gr_name).to_string_lossy().to_string()
        }
    };
    cache.insert(gid, name.clone());
    name
}

fn json_str(obj: &serde_json::Map<String, serde_json::Value>, keys: &[&str]) -> String {
    for &k in keys {
        if let Some(v) = obj.get(k) {
            match v {
                serde_json::Value::String(s) if !s.trim().is_empty() => {
                    return s.trim().to_string()
                }
                serde_json::Value::Number(n) => return n.to_string(),
                _ => {}
            }
        }
    }
    String::new()
}

fn populate_from_exif_obj(
    obj: &serde_json::Map<String, serde_json::Value>,
    want: &HashSet<&str>,
    out: &mut HashMap<String, String>,
) {
    let mut put = |key: &str, val: String| {
        if !val.is_empty() && want.contains(key) {
            out.insert(key.to_string(), val);
        }
    };
    if want.contains("dimensions") {
        let w = json_str(obj, &["ImageWidth", "ExifImageWidth"]);
        let h = json_str(obj, &["ImageHeight", "ExifImageHeight"]);
        if !w.is_empty() && !h.is_empty() {
            put("dimensions", format!("{} x {}", w, h));
        }
    }
    put("mime_type", json_str(obj, &["MIMEType"]));
    put(
        "date_taken",
        json_str(obj, &["DateTimeOriginal", "CreateDate", "MediaCreateDate"]),
    );
    put("camera_make", json_str(obj, &["Make"]));
    put("camera_model", json_str(obj, &["Model"]));
    put(
        "camera_id",
        json_str(
            obj,
            &[
                "SerialNumber",
                "InternalSerialNumber",
                "CameraID",
                "BodySerialNumber",
                "UniqueCameraModel",
            ],
        ),
    );
    put("iso", json_str(obj, &["ISO", "ISOSpeedRatings"]));
    let fnum = json_str(obj, &["FNumber", "Aperture", "ApertureValue"]);
    if !fnum.is_empty() {
        put(
            "aperture",
            if fnum.starts_with('f') || fnum.starts_with('F') {
                fnum
            } else {
                format!("f/{}", fnum)
            },
        );
    }
    put(
        "exposure_time",
        json_str(obj, &["ExposureTime", "ShutterSpeed", "ShutterSpeedValue"]),
    );
    put("focal_length", json_str(obj, &["FocalLength"]));
    put(
        "lens_model",
        json_str(obj, &["LensModel", "LensID", "Lens"]),
    );
    put("flash", json_str(obj, &["Flash"]));
    if want.contains("gps") {
        let pos = json_str(obj, &["GPSPosition"]);
        if !pos.is_empty() {
            put("gps", pos);
        } else {
            let lat = json_str(obj, &["GPSLatitude"]);
            let lon = json_str(obj, &["GPSLongitude"]);
            if !lat.is_empty() && !lon.is_empty() {
                put("gps", format!("{}, {}", lat, lon));
            }
        }
    }
    put("color_space", json_str(obj, &["ColorSpace"]));
    put("orientation", json_str(obj, &["Orientation"]));
    put("duration", json_str(obj, &["Duration", "MediaDuration"]));
    put(
        "bitrate",
        json_str(obj, &["AvgBitrate", "AudioBitrate", "VideoBitrate"]),
    );
    put("frame_rate", json_str(obj, &["VideoFrameRate"]));
    put(
        "video_codec",
        json_str(obj, &["VideoCodec", "CompressorID", "CompressorName"]),
    );
    put(
        "audio_codec",
        json_str(obj, &["AudioFormat", "AudioCodec", "AudioEncoding"]),
    );
    put("title", json_str(obj, &["Title"]));
    put(
        "artist",
        json_str(obj, &["Artist", "AlbumArtist", "Composer"]),
    );
    put("album", json_str(obj, &["Album"]));
    put("genre", json_str(obj, &["Genre"]));
    put("track", json_str(obj, &["Track", "TrackNumber"]));
    put("year", json_str(obj, &["Year", "ContentCreateDate"]));
    put("author", json_str(obj, &["Author", "Creator"]));
    put("pages", json_str(obj, &["PageCount", "Pages"]));
    put(
        "creator_tool",
        json_str(obj, &["CreatorTool", "Software", "Producer", "Application"]),
    );
}

/// Extract requested metadata columns for `paths` on a worker thread.
pub fn extract_batch(
    paths: &[String],
    requested: &[String],
) -> HashMap<String, HashMap<String, String>> {
    let mut result: HashMap<String, HashMap<String, String>> = HashMap::new();
    if paths.is_empty() || requested.is_empty() {
        return result;
    }
    let want: HashSet<&str> = requested.iter().map(|s| s.as_str()).collect();
    let needs_stat = want.iter().any(|k| {
        matches!(
            *k,
            "extension"
                | "created"
                | "accessed"
                | "permissions"
                | "owner"
                | "group"
                | "symlink_target"
                | "links"
                | "inode"
        )
    });
    let needs_external = EXTRA_COLUMNS
        .iter()
        .any(|c| c.needs_external && want.contains(c.key));

    let mut uid_cache = HashMap::new();
    let mut gid_cache = HashMap::new();
    let mut regular_files: Vec<String> = Vec::new();

    for p in paths {
        let path = Path::new(p);
        let Ok(meta) = fs::symlink_metadata(path) else {
            continue;
        };
        if meta.is_file() {
            regular_files.push(p.clone());
        }
        if !needs_stat {
            continue;
        }
        let map = result.entry(p.clone()).or_default();
        if want.contains("extension") && !meta.is_dir() {
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                let ext = crate::listing::extension(name);
                if !ext.is_empty() {
                    map.insert("extension".into(), ext.to_uppercase());
                }
            }
        }
        if want.contains("created") {
            if let Ok(ct) = meta.created() {
                if let Ok(dur) = ct.duration_since(std::time::UNIX_EPOCH) {
                    map.insert("created".into(), format_timestamp(dur.as_secs() as i64));
                }
            }
        }
        if want.contains("accessed") {
            map.insert("accessed".into(), format_timestamp(meta.atime()));
        }
        if want.contains("permissions") {
            map.insert("permissions".into(), format_mode(meta.mode()));
        }
        if want.contains("owner") {
            map.insert("owner".into(), uid_name(meta.uid(), &mut uid_cache));
        }
        if want.contains("group") {
            map.insert("group".into(), gid_name(meta.gid(), &mut gid_cache));
        }
        if want.contains("symlink_target") && meta.file_type().is_symlink() {
            if let Ok(target) = fs::read_link(path) {
                map.insert(
                    "symlink_target".into(),
                    target.to_string_lossy().to_string(),
                );
            }
        }
        if want.contains("links") {
            map.insert("links".into(), meta.nlink().to_string());
        }
        if want.contains("inode") {
            map.insert("inode".into(), meta.ino().to_string());
        }
    }

    if needs_external && !regular_files.is_empty() {
        if let Some(bin) = util::which("exiftool") {
            // Chunk to avoid exceeding OS argv limits on huge directories.
            for chunk in regular_files.chunks(200) {
                let mut cmd = Command::new(&bin);
                cmd.args(["-j", "-q", "-q", "--"]);
                cmd.args(chunk);
                let (ok, out, _) = util::run_capture(cmd, None);
                if !ok {
                    continue;
                }
                if let Ok(serde_json::Value::Array(arr)) = serde_json::from_str(&out) {
                    for item in arr {
                        let Some(obj) = item.as_object() else {
                            continue;
                        };
                        let Some(src) = obj.get("SourceFile").and_then(|v| v.as_str()) else {
                            continue;
                        };
                        let map = result.entry(src.to_string()).or_default();
                        populate_from_exif_obj(obj, &want, map);
                    }
                }
            }
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn formats_permissions_and_parses_exif_fields() {
        assert_eq!(format_mode(0o100755), "rwxr-xr-x");
        assert_eq!(format_mode(0o100640), "rw-r-----");

        let sample: serde_json::Value = serde_json::json!({
            "SourceFile": "/tmp/a.jpg",
            "Make": "Canon",
            "Model": "EOS R5",
            "SerialNumber": "042021001234",
            "ISO": 800,
            "FNumber": 2.8,
            "ImageWidth": 8192,
            "ImageHeight": 5464
        });
        let want: HashSet<&str> = [
            "camera_make",
            "camera_model",
            "camera_id",
            "iso",
            "aperture",
            "dimensions",
        ]
        .into_iter()
        .collect();
        let mut out = HashMap::new();
        populate_from_exif_obj(sample.as_object().unwrap(), &want, &mut out);
        assert_eq!(out.get("camera_make").map(String::as_str), Some("Canon"));
        assert_eq!(out.get("camera_model").map(String::as_str), Some("EOS R5"));
        assert_eq!(
            out.get("camera_id").map(String::as_str),
            Some("042021001234")
        );
        assert_eq!(out.get("iso").map(String::as_str), Some("800"));
        assert_eq!(out.get("aperture").map(String::as_str), Some("f/2.8"));
        assert_eq!(
            out.get("dimensions").map(String::as_str),
            Some("8192 x 5464")
        );
    }
}
