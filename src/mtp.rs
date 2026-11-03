//! MTP location parsing, formatting, directory listing, and metadata decoding.

use crate::listing;
use crate::native;
use serde::Deserialize;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Location {
    udi: String,
    storage: Option<String>,
    dirs: Vec<String>,
}

fn hex_encode(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        out.push(char::from_digit((b >> 4) as u32, 16).unwrap());
        out.push(char::from_digit((b & 0x0f) as u32, 16).unwrap());
    }
    out
}

fn hex_decode(s: &str) -> Option<Vec<u8>> {
    if s.is_empty() || s.len() % 2 != 0 {
        return None;
    }
    let mut out = Vec::with_capacity(s.len() / 2);
    let bytes = s.as_bytes();
    for i in (0..bytes.len()).step_by(2) {
        let hi = (bytes[i] as char).to_digit(16)?;
        let lo = (bytes[i + 1] as char).to_digit(16)?;
        out.push(((hi << 4) | lo) as u8);
    }
    Some(out)
}

fn percent_encode(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for &b in s.as_bytes() {
        if b.is_ascii_alphanumeric() || b == b'-' || b == b'.' || b == b'_' || b == b'~' {
            out.push(b as char);
        } else {
            out.push('%');
            out.push(
                char::from_digit((b >> 4) as u32, 16)
                    .unwrap()
                    .to_ascii_uppercase(),
            );
            out.push(
                char::from_digit((b & 0x0f) as u32, 16)
                    .unwrap()
                    .to_ascii_uppercase(),
            );
        }
    }
    out
}

fn percent_decode(s: &str) -> Option<String> {
    let mut bytes = Vec::with_capacity(s.len());
    let b = s.as_bytes();
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' {
            if i + 2 >= b.len() {
                return None;
            }
            let hi = (b[i + 1] as char).to_digit(16)?;
            let lo = (b[i + 2] as char).to_digit(16)?;
            bytes.push(((hi << 4) | lo) as u8);
            i += 3;
        } else {
            bytes.push(b[i]);
            i += 1;
        }
    }
    String::from_utf8(bytes).ok()
}

fn is_valid_component(name: &str) -> bool {
    !name.is_empty() && name != "." && name != ".." && !name.contains('/') && !name.contains('\0')
}

impl Location {
    pub fn parse(s: &str) -> Option<Self> {
        let rest = s.strip_prefix("mtp://")?;
        // Keep long physical identifiers in the path; Qt applies DNS label limits to hosts.
        // Accept old addresses when restoring sessions, but always emit the canonical form.
        let rest = rest.strip_prefix("loaf/").unwrap_or(rest);
        // Canonical device roots end in '/', separating their identity from descendants.
        let rest = if rest.ends_with('/') && rest.matches('/').count() == 1 {
            &rest[..rest.len() - 1]
        } else {
            rest
        };
        if rest.is_empty() || rest.contains('?') || rest.contains('#') {
            return None;
        }

        let parts: Vec<&str> = rest.split('/').collect();
        if parts.is_empty() {
            return None;
        }

        let udi_hex = parts[0];
        if udi_hex.is_empty() || udi_hex.to_lowercase() != udi_hex {
            return None;
        }
        let udi_bytes = hex_decode(udi_hex)?;
        let udi = String::from_utf8(udi_bytes).ok()?;
        if !udi.starts_with('/') || udi.contains('\0') {
            return None;
        }

        if parts.len() == 1 {
            return Some(Location {
                udi,
                storage: None,
                dirs: Vec::new(),
            });
        }

        let raw_storage = parts[1];
        let storage = percent_decode(raw_storage)?;
        if !is_valid_component(&storage) {
            return None;
        }

        let mut dirs = Vec::new();
        for &seg in &parts[2..] {
            let dir = percent_decode(seg)?;
            if !is_valid_component(&dir) {
                return None;
            }
            dirs.push(dir);
        }

        Some(Location {
            udi,
            storage: Some(storage),
            dirs,
        })
    }

    pub fn url(&self) -> String {
        let udi_hex = hex_encode(self.udi.as_bytes());
        let mut out = format!("mtp://loaf/{}", udi_hex);
        if let Some(ref st) = self.storage {
            out.push('/');
            out.push_str(&percent_encode(st));
            for dir in &self.dirs {
                out.push('/');
                out.push_str(&percent_encode(dir));
            }
        } else {
            out.push('/');
        }
        out
    }

    pub fn is_root(&self) -> bool {
        self.storage.is_none() && self.dirs.is_empty()
    }

    pub fn parent(&self) -> Option<Self> {
        if !self.dirs.is_empty() {
            let mut new_dirs = self.dirs.clone();
            new_dirs.pop();
            Some(Location {
                udi: self.udi.clone(),
                storage: self.storage.clone(),
                dirs: new_dirs,
            })
        } else if self.storage.is_some() {
            Some(Location {
                udi: self.udi.clone(),
                storage: None,
                dirs: Vec::new(),
            })
        } else {
            None
        }
    }

    pub fn title(&self) -> String {
        if let Some(last_dir) = self.dirs.last() {
            last_dir.clone()
        } else if let Some(ref st) = self.storage {
            st.clone()
        } else {
            "Phone".to_string()
        }
    }

    pub fn root_url(&self) -> String {
        format!("mtp://loaf/{}/", hex_encode(self.udi.as_bytes()))
    }

    pub fn breadcrumbs(&self) -> Vec<(String, String)> {
        let mut crumbs = Vec::new();
        let root_u = self.root_url();
        crumbs.push(("Phone".to_string(), root_u.clone()));

        if let Some(ref st) = self.storage {
            let mut curr = format!("{}{}", root_u, percent_encode(st));
            crumbs.push((st.clone(), curr.clone()));
            for d in &self.dirs {
                curr = format!("{}/{}", curr, percent_encode(d));
                crumbs.push((d.clone(), curr.clone()));
            }
        }
        crumbs
    }

    pub fn child(&self, name: &str) -> Option<Self> {
        if !is_valid_component(name) {
            return None;
        }
        if self.storage.is_none() {
            Some(Location {
                udi: self.udi.clone(),
                storage: Some(name.to_string()),
                dirs: Vec::new(),
            })
        } else {
            let mut new_dirs = self.dirs.clone();
            new_dirs.push(name.to_string());
            Some(Location {
                udi: self.udi.clone(),
                storage: self.storage.clone(),
                dirs: new_dirs,
            })
        }
    }

    pub fn udi(&self) -> &str {
        &self.udi
    }

    pub fn storage(&self) -> Option<&str> {
        self.storage.as_deref()
    }

    pub fn dirs(&self) -> &[String] {
        &self.dirs
    }
}

#[derive(Deserialize, Debug)]
pub struct RawMtpResponse {
    pub entries: Option<Vec<RawMtpEntry>>,
    pub error: Option<String>,
}

#[derive(Deserialize, Debug)]
pub struct RawMtpEntry {
    pub name: String,
    pub is_dir: bool,
    pub size: u64,
    pub modified: i64,
}

pub fn decode_entries(location: &Location, json: &str) -> Result<Vec<listing::Entry>, String> {
    let resp: RawMtpResponse =
        serde_json::from_str(json).map_err(|e| format!("Failed to parse MTP response: {}", e))?;

    if let Some(err) = resp.error {
        if !err.is_empty() {
            return Err(err);
        }
    }

    let raw_entries = resp
        .entries
        .ok_or_else(|| "Missing entries in MTP response".to_string())?;
    let mut entries = Vec::with_capacity(raw_entries.len());

    let mut names = std::collections::HashSet::new();
    for item in raw_entries {
        if !is_valid_component(&item.name) || !names.insert(item.name.clone()) {
            return Err("Phone returned an invalid or duplicate filename".to_string());
        }
        let child_loc = match location.child(&item.name) {
            Some(loc) => loc,
            None => continue,
        };
        let (icon, sys_icon, category, _) = listing::classify(&item.name, item.is_dir);
        let is_hidden = item.name.starts_with('.');
        entries.push(listing::Entry {
            name: item.name.clone(),
            name_lower: item.name.to_lowercase(),
            path: child_loc.url(),
            is_dir: item.is_dir,
            is_symlink: false,
            is_hidden,
            size: item.size,
            modified: item.modified,
            icon,
            system_icon: sys_icon,
            category,
            thumbable: false,
            detail: "MTP".to_string(),
            display_name: item.name,
        });
    }

    Ok(entries)
}

pub fn list(location: &Location) -> Result<Vec<listing::Entry>, String> {
    let json = native::list_mtp_directory(&location.url());
    decode_entries(location, &json)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_location_roundtrip_and_edge_cases() {
        let udi = "/org/kde/kmtpd/device_0";
        let hex_u = hex_encode(udi.as_bytes());
        let root_url = format!("mtp://loaf/{}/", hex_u);

        let loc = Location::parse(&root_url).expect("parse root");
        assert_eq!(loc.url(), root_url);
        assert_eq!(loc.title(), "Phone");
        assert_eq!(loc.is_root(), true);
        assert_eq!(loc.parent(), None);
        assert_eq!(
            loc.breadcrumbs(),
            vec![("Phone".to_string(), root_url.clone())]
        );

        // Storage with spaces, unicode, special chars
        let st_name = "Internal Storage #1 (SD card & 100%)";
        let loc_storage = loc.child(st_name).expect("child storage");
        assert_eq!(loc_storage.title(), st_name);
        assert_eq!(loc_storage.is_root(), false);
        assert_eq!(loc_storage.parent(), Some(loc.clone()));
        let st_url = loc_storage.url();

        let parsed_st = Location::parse(&st_url).expect("parse storage url");
        assert_eq!(parsed_st, loc_storage);
        assert_eq!(parsed_st.title(), st_name);

        // Child directories with unicode
        let dir1 = "DCIM 📁";
        let loc_dir1 = loc_storage.child(dir1).expect("child dir1");
        assert_eq!(loc_dir1.title(), dir1);
        assert_eq!(loc_dir1.parent(), Some(loc_storage.clone()));
        let dir1_url = loc_dir1.url();

        let parsed_dir1 = Location::parse(&dir1_url).expect("parse dir1");
        assert_eq!(parsed_dir1, loc_dir1);

        let dir2 = "Camera";
        let loc_dir2 = loc_dir1.child(dir2).expect("child dir2");
        assert_eq!(loc_dir2.title(), dir2);
        assert_eq!(loc_dir2.parent(), Some(loc_dir1.clone()));
        let dir2_url = loc_dir2.url();

        let parsed_dir2 = Location::parse(&dir2_url).expect("parse dir2");
        assert_eq!(parsed_dir2, loc_dir2);

        // Check breadcrumbs
        let crumbs = loc_dir2.breadcrumbs();
        assert_eq!(crumbs.len(), 4);
        assert_eq!(crumbs[0], ("Phone".to_string(), root_url));
        assert_eq!(crumbs[1], (st_name.to_string(), st_url));
        assert_eq!(crumbs[2], (dir1.to_string(), dir1_url));
        assert_eq!(crumbs[3], (dir2.to_string(), dir2_url));
    }

    #[test]
    fn test_location_rejects_invalid_urls() {
        // Not mtp://
        assert_eq!(Location::parse("file:///home"), None);
        assert_eq!(Location::parse("mtp:udi=/test/phone/"), None);
        assert_eq!(Location::parse("mtp://"), None);

        // Query / fragment reject
        let hex_u = hex_encode(b"/test");
        assert_eq!(Location::parse(&format!("mtp://{}?query=1", hex_u)), None);
        assert_eq!(Location::parse(&format!("mtp://{}#frag", hex_u)), None);

        // Uppercase hex UDI reject
        let upper_hex = hex_u.to_uppercase();
        if upper_hex != hex_u {
            assert_eq!(Location::parse(&format!("mtp://{}", upper_hex)), None);
        }

        // Invalid hex
        assert_eq!(Location::parse("mtp://not_hex_zz"), None);
        assert_eq!(Location::parse("mtp://123"), None); // odd length

        // Path traversal and slashes inside components
        let slash_encoded = percent_encode("a/b");
        assert_eq!(
            Location::parse(&format!("mtp://{}/{}", hex_u, slash_encoded)),
            None
        );

        let dot = percent_encode(".");
        assert_eq!(Location::parse(&format!("mtp://{}/{}", hex_u, dot)), None);

        let dotdot = percent_encode("..");
        assert_eq!(
            Location::parse(&format!("mtp://{}/{}", hex_u, dotdot)),
            None
        );

        let null_enc = percent_encode("a\0b");
        assert_eq!(
            Location::parse(&format!("mtp://{}/{}", hex_u, null_enc)),
            None
        );

        let empty_seg = format!("mtp://{}/st//dir", hex_u);
        assert_eq!(Location::parse(&empty_seg), None);
    }

    #[test]
    fn test_decode_entries_fixture() {
        let udi = "/test/phone";
        let hex_u = hex_encode(udi.as_bytes());
        let root_loc = Location::parse(&format!("mtp://{}", hex_u)).unwrap();
        let loc = root_loc.child("Internal Storage").unwrap();

        let json = r#"{
            "entries": [
                {
                    "name": "DCIM",
                    "is_dir": true,
                    "size": 0,
                    "modified": 1700000000
                },
                {
                    "name": "photo.jpg",
                    "is_dir": false,
                    "size": 2048576,
                    "modified": 1700000100
                },
                {
                    "name": ".hidden_folder",
                    "is_dir": true,
                    "size": 0,
                    "modified": 1700000200
                }
            ]
        }"#;

        let entries = decode_entries(&loc, json).expect("decode entries");
        assert_eq!(entries.len(), 3);

        let dcim = &entries[0];
        assert_eq!(dcim.name, "DCIM");
        assert_eq!(dcim.display_name, "DCIM");
        assert_eq!(dcim.is_dir, true);
        assert_eq!(dcim.is_symlink, false);
        assert_eq!(dcim.is_hidden, false);
        assert_eq!(dcim.thumbable, false);
        assert_eq!(dcim.category, "folder");
        assert_eq!(dcim.icon, "folder");
        assert_eq!(dcim.detail, "MTP");
        assert_eq!(dcim.path, loc.child("DCIM").unwrap().url());

        let photo = &entries[1];
        assert_eq!(photo.name, "photo.jpg");
        assert_eq!(photo.display_name, "photo.jpg");
        assert_eq!(photo.is_dir, false);
        assert_eq!(photo.is_symlink, false);
        assert_eq!(photo.is_hidden, false);
        assert_eq!(photo.thumbable, false); // thumbable must be false for MTP
        assert_eq!(photo.category, "image");
        assert_eq!(photo.icon, "file-image");
        assert_eq!(photo.detail, "MTP");
        assert_eq!(photo.size, 2048576);
        assert_eq!(photo.modified, 1700000100);

        let hidden = &entries[2];
        assert_eq!(hidden.name, ".hidden_folder");
        assert_eq!(hidden.is_hidden, true);
        assert_eq!(hidden.is_dir, true);
    }

    #[test]
    fn test_decode_entries_error_handling() {
        let udi = "/test/phone";
        let hex_u = hex_encode(udi.as_bytes());
        let root_loc = Location::parse(&format!("mtp://{}", hex_u)).unwrap();

        let json_err = r#"{"entries": [], "error": "Device is locked"}"#;
        let res = decode_entries(&root_loc, json_err);
        assert_eq!(res.unwrap_err(), "Device is locked");

        let invalid_name =
            r#"{"entries":[{"name":"../escape","is_dir":false,"size":0,"modified":0}]}"#;
        assert!(decode_entries(&root_loc, invalid_name).is_err());
        let json_invalid = "not-json";
        assert!(decode_entries(&root_loc, json_invalid).is_err());
    }
}
