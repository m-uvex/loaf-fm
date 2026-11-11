//! `file://` URI helpers for portal results. Encoding is strict RFC 8089:
//! everything outside the unreserved set and `/` is percent-escaped, so
//! `?`, `#`, spaces and non-UTF-8 bytes are never ambiguous. Decoding is
//! the exact inverse (lossy for non-UTF-8, which Linux paths can contain).

use std::os::unix::ffi::OsStrExt;
use std::path::{Path, PathBuf};

/// Builds a `file://` URI for an absolute path.
pub fn path_to_file_uri(path: &Path) -> String {
    let bytes = path.as_os_str().as_encoded_bytes();
    let mut uri = String::with_capacity(bytes.len() + 7);
    uri.push_str("file://");
    for byte in bytes {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' | b'/' => {
                uri.push(*byte as char);
            }
            _ => uri.push_str(&format!("%{byte:02X}")),
        }
    }
    uri
}

/// Parses a `file://` URI back into a path. `None` for anything that is not
/// a `file://` URI of an absolute path.
pub fn file_uri_to_path(uri: &str) -> Option<PathBuf> {
    let rest = uri.strip_prefix("file://")?;
    let rest = rest.strip_prefix("localhost").unwrap_or(rest);
    let bytes = rest.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let hex = |c: u8| (c as char).to_digit(16);
            if let (Some(high), Some(low)) = (hex(bytes[i + 1]), hex(bytes[i + 2])) {
                out.push((high * 16 + low) as u8);
                i += 3;
                continue;
            }
            // A stray '%' that is not an escape: keep it literal.
        }
        out.push(bytes[i]);
        i += 1;
    }
    let path = PathBuf::from(std::ffi::OsStr::from_bytes(&out));
    path.is_absolute().then_some(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encodes_reserved_and_non_ascii_bytes() {
        assert_eq!(
            path_to_file_uri(Path::new("/home/u/file.txt")),
            "file:///home/u/file.txt"
        );
        assert_eq!(
            path_to_file_uri(Path::new("/home/u/My File.txt")),
            "file:///home/u/My%20File.txt"
        );
        assert_eq!(
            path_to_file_uri(Path::new("/tmp/a#b?c.txt")),
            "file:///tmp/a%23b%3Fc.txt"
        );
        assert_eq!(
            path_to_file_uri(Path::new("/tmp/50%.txt")),
            "file:///tmp/50%25.txt"
        );
        assert_eq!(
            path_to_file_uri(Path::new("/tmp/日本.txt")),
            "file:///tmp/%E6%97%A5%E6%9C%AC.txt"
        );
    }

    #[test]
    fn decodes_what_it_encodes() {
        for raw in [
            "/home/u/file.txt",
            "/home/u/My File.txt",
            "/tmp/a#b?c.txt",
            "/tmp/日本.txt",
        ] {
            assert_eq!(
                file_uri_to_path(&path_to_file_uri(Path::new(raw))).unwrap(),
                PathBuf::from(raw)
            );
        }
    }

    #[test]
    fn decode_rejects_non_file_uris() {
        assert!(file_uri_to_path("http://example.com/x").is_none());
        assert!(file_uri_to_path("/plain/path").is_none());
        assert!(file_uri_to_path("file://relative").is_none());
        assert!(file_uri_to_path("file:///tmp/x").is_some());
        assert_eq!(
            file_uri_to_path("file:///tmp/x").unwrap(),
            PathBuf::from("/tmp/x")
        );
    }

    #[test]
    fn decode_tolerates_stray_percent_signs() {
        assert_eq!(
            file_uri_to_path("file:///tmp/50%.txt").unwrap(),
            PathBuf::from("/tmp/50%.txt")
        );
    }
}
