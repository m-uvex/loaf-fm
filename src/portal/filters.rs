//! File chooser filters: parsing and matching. A filter has a display name
//! and a list of patterns; a pattern is either a `glob` (shell-style, matched
//! case-insensitively against the file name) or a `mime` type (matched with
//! shared-mime-info inheritance and aliases, which needs QMimeDatabase and
//! is therefore injected as a callback). A filter with no patterns matches
//! everything — the "All files" entry.
//!
//! JSON form shared between the D-Bus layer and the engine:
//! `{ "name": "Images", "patterns": [["glob", "*.png"], ["mime", "image/png"]] }`

use crate::pane::glob_match;
use serde_json::Value;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FilterKind {
    Glob,
    MimeType,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FilterPattern {
    pub kind: FilterKind,
    pub pattern: String,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Filter {
    pub name: String,
    pub patterns: Vec<FilterPattern>,
}

impl Filter {
    /// Parses one filter object; `None` for anything malformed. Callers
    /// treat that as "no filter", which always shows every file.
    pub fn from_json(value: &Value) -> Option<Filter> {
        let name = value.get("name")?.as_str()?.to_string();
        let mut patterns = Vec::new();
        for entry in value.get("patterns")?.as_array()? {
            let entry = entry.as_array()?;
            let kind = match entry.first()?.as_str()? {
                "glob" => FilterKind::Glob,
                "mime" => FilterKind::MimeType,
                _ => return None,
            };
            let pattern = entry.get(1)?.as_str()?;
            patterns.push(FilterPattern { kind, pattern: pattern.to_string() });
        }
        Some(Filter { name, patterns })
    }

    /// Parses the engine's current-filter JSON. An empty string means no
    /// filter is set.
    pub fn parse(json: &str) -> Option<Filter> {
        if json.is_empty() {
            return None;
        }
        Self::from_json(&serde_json::from_str(json).ok()?)
    }

    /// True when `file_name` passes the filter. `mime_matches` receives
    /// (file name, filter MIME, is directory) and decides whether the file
    /// has that MIME type.
    pub fn matches(&self, file_name: &str, is_dir: bool, mime_matches: &impl Fn(&str, &str, bool) -> bool) -> bool {
        if self.patterns.is_empty() {
            return true;
        }
        let lowered = file_name.to_lowercase();
        self.patterns.iter().any(|pattern| match pattern.kind {
            FilterKind::Glob => glob_match(&normalize_glob(&pattern.pattern).to_lowercase(), &lowered),
            FilterKind::MimeType => mime_matches(file_name, &pattern.pattern, is_dir),
        })
    }
}

/// Apps occasionally send regex-flavored patterns instead of shell globs
/// (e.g. `.*pdf` or `.*\.pdf` from an accept attribute). Normalize the
/// common cases so they behave like the globs the spec asks for:
/// a leading `.*` becomes `*` and escaped dots become literal dots.
fn normalize_glob(pattern: &str) -> String {
    let unescaped = pattern.replace("\\.", ".");
    if let Some(rest) = unescaped.strip_prefix(".*") {
        format!("*{rest}")
    } else {
        unescaped
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    /// Fake shared-mime-info: known extensions plus text/markdown inheriting
    /// text/plain.
    fn fake_mime(file_name: &str, filter_mime: &str, is_dir: bool) -> bool {
        if is_dir {
            return filter_mime == "inode/directory";
        }
        let actual = if file_name.ends_with(".png") {
            "image/png"
        } else if file_name.ends_with(".jpg") {
            "image/jpeg"
        } else if file_name.ends_with(".md") {
            "text/markdown"
        } else {
            "application/octet-stream"
        };
        actual == filter_mime || (actual == "text/markdown" && filter_mime == "text/plain")
    }

    fn filter(name: &str, patterns: &[(&str, &str)]) -> Filter {
        Filter {
            name: name.into(),
            patterns: patterns
                .iter()
                .map(|(kind, pattern)| FilterPattern {
                    kind: if *kind == "glob" { FilterKind::Glob } else { FilterKind::MimeType },
                    pattern: pattern.to_string(),
                })
                .collect(),
        }
    }

    #[test]
    fn glob_patterns_match_case_insensitively() {
        let f = filter("Images", &[("glob", "*.JPG"), ("glob", "*.png")]);
        assert!(f.matches("photo.jpg", false, &fake_mime));
        assert!(f.matches("photo.PNG", false, &fake_mime));
        assert!(!f.matches("photo.jpeg", false, &fake_mime));
        assert!(f.matches("shot.png", false, &fake_mime));
    }

    #[test]
    fn mime_patterns_use_the_injected_matcher() {
        let f = filter("Images", &[("mime", "image/png")]);
        assert!(f.matches("shot.png", false, &fake_mime));
        assert!(!f.matches("shot.jpg", false, &fake_mime));
    }

    #[test]
    fn directories_match_directory_mime_filters() {
        let f = filter("Folders", &[("mime", "inode/directory")]);
        assert!(f.matches("Documents", true, &fake_mime));
        assert!(!f.matches("Documents", false, &fake_mime));
    }

    #[test]
    fn mime_inheritance_is_delegated_to_the_matcher() {
        let f = filter("Text", &[("mime", "text/plain")]);
        assert!(f.matches("notes.md", false, &fake_mime));
    }

    #[test]
    fn patterns_are_alternatives() {
        let f = filter("Images", &[("glob", "*.png"), ("mime", "image/jpeg")]);
        assert!(f.matches("shot.png", false, &fake_mime));
        assert!(f.matches("shot.jpg", false, &fake_mime));
        assert!(!f.matches("notes.md", false, &fake_mime));
    }

    #[test]
    fn empty_patterns_match_everything() {
        let f = filter("All files", &[]);
        assert!(f.matches("anything.bin", false, &fake_mime));
    }

    #[test]
    fn regex_flavored_globs_are_normalized() {
        // Apps sometimes send regex-style patterns; they must behave like
        // the globs the spec asks for.
        let f = filter("Binaries", &[("glob", ".*bin")]);
        assert!(f.matches("100MB.bin", false, &fake_mime));
        assert!(f.matches("bin", false, &fake_mime));
        let f = filter("Pdf", &[("glob", ".*\\.pdf")]);
        assert!(f.matches("doc.pdf", false, &fake_mime));
        let f = filter("Everything", &[("glob", ".*")]);
        assert!(f.matches("whatever.txt", false, &fake_mime));
        // Ordinary globs are untouched.
        let f = filter("Images", &[("glob", "*.png")]);
        assert!(f.matches("shot.png", false, &fake_mime));
        assert!(!f.matches("shot.jpg", false, &fake_mime));
        let f = filter("Dotfiles", &[("glob", ".hidden")]);
        assert!(f.matches(".hidden", false, &fake_mime));
        assert!(!f.matches("notes.md", false, &fake_mime));
    }

    #[test]
    fn parse_accepts_valid_and_rejects_malformed() {
        let valid = json!({"name": "Images", "patterns": [["glob", "*.png"], ["mime", "image/png"]]});
        assert_eq!(Filter::from_json(&valid), Some(filter("Images", &[("glob", "*.png"), ("mime", "image/png")])));
        assert!(Filter::parse("").is_none());
        assert!(Filter::parse("not json").is_none());
        assert!(Filter::from_json(&json!({"patterns": []})).is_none());
        assert!(Filter::from_json(&json!({"name": "X", "patterns": [["regex", "a"]]})).is_none());
        assert!(Filter::from_json(&json!({"name": "X", "patterns": [["glob"]]})).is_none());
        assert!(Filter::from_json(&json!("a string")).is_none());
    }
}
