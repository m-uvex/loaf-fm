//! File chooser filters: parsing and matching glob and MIME type patterns.

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

impl FilterPattern {
    pub fn new(kind: FilterKind, pattern: &str) -> Self {
        let pattern = match kind {
            FilterKind::Glob => normalize_glob(pattern).to_lowercase(),
            FilterKind::MimeType => pattern.to_string(),
        };
        Self { kind, pattern }
    }
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
            patterns.push(FilterPattern::new(kind, pattern));
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

    /// True when `file_name` passes the filter. `mime_matches` evaluates the
    /// filter's MIME patterns with the supplied file name.
    pub fn matches(&self, file_name: &str, mime_matches: &impl Fn(&str, &Filter) -> bool) -> bool {
        if self.patterns.is_empty() {
            return true;
        }
        let lowered = file_name.to_lowercase();
        if self.patterns.iter().any(|pattern| {
            pattern.kind == FilterKind::Glob && glob_match(&pattern.pattern, &lowered)
        }) {
            return true;
        }
        self.patterns
            .iter()
            .any(|pattern| pattern.kind == FilterKind::MimeType)
            && mime_matches(file_name, self)
    }

    /// True when the filter has no patterns or all its patterns are catch-all globs.
    pub fn is_catch_all(&self) -> bool {
        self.patterns.is_empty()
            || self
                .patterns
                .iter()
                .all(|pattern| pattern.kind == FilterKind::Glob && pattern.pattern == "*")
    }
}

/// Apps occasionally send regex-flavored patterns instead of shell globs
/// (e.g. `.*pdf` or `.*\.pdf` from an accept attribute), and catch-all
/// filters arrive as `.*`, `*` or `*.*`. Normalize the common cases so
/// they behave like the globs the spec asks for: a leading `.*` becomes
/// `*`, escaped dots become literal dots, and `*.*` widens to `*` (an
/// extensionless file is still a file).
fn normalize_glob(pattern: &str) -> String {
    let mut normalized = pattern.replace("\\.", ".");
    if let Some(rest) = normalized.strip_prefix(".*") {
        normalized = format!("*{rest}");
    }
    if normalized == "*.*" {
        normalized = "*".to_string();
    }
    normalized
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    /// Fake shared-mime-info: known extensions plus text/markdown inheriting
    /// text/plain.
    fn fake_mime(file_name: &str, filter: &Filter) -> bool {
        let actual = if file_name.ends_with(".png") {
            "image/png"
        } else if file_name.ends_with(".jpg") {
            "image/jpeg"
        } else if file_name.ends_with(".md") {
            "text/markdown"
        } else {
            "application/octet-stream"
        };
        filter.patterns.iter().any(|pattern| {
            pattern.kind == FilterKind::MimeType
                && (actual == pattern.pattern
                    || (actual == "text/markdown" && pattern.pattern == "text/plain"))
        })
    }

    fn filter(name: &str, patterns: &[(&str, &str)]) -> Filter {
        Filter {
            name: name.into(),
            patterns: patterns
                .iter()
                .map(|(kind, pattern)| {
                    FilterPattern::new(
                        if *kind == "glob" {
                            FilterKind::Glob
                        } else {
                            FilterKind::MimeType
                        },
                        pattern,
                    )
                })
                .collect(),
        }
    }

    #[test]
    fn glob_patterns_match_case_insensitively() {
        let f = filter("Images", &[("glob", "*.JPG"), ("glob", "*.png")]);
        assert!(f.matches("photo.jpg", &fake_mime));
        assert!(f.matches("photo.PNG", &fake_mime));
        assert!(!f.matches("photo.jpeg", &fake_mime));
        assert!(f.matches("shot.png", &fake_mime));
    }

    #[test]
    fn mime_patterns_use_the_injected_matcher() {
        let f = filter("Images", &[("mime", "image/png")]);
        assert!(f.matches("shot.png", &fake_mime));
        assert!(!f.matches("shot.jpg", &fake_mime));
    }

    #[test]
    fn mime_inheritance_is_delegated_to_the_matcher() {
        let f = filter("Text", &[("mime", "text/plain")]);
        assert!(f.matches("notes.md", &fake_mime));
    }

    #[test]
    fn patterns_are_alternatives() {
        let f = filter("Images", &[("glob", "*.png"), ("mime", "image/jpeg")]);
        assert!(f.matches("shot.png", &fake_mime));
        assert!(f.matches("shot.jpg", &fake_mime));
        assert!(!f.matches("notes.md", &fake_mime));
    }

    #[test]
    fn empty_patterns_match_everything() {
        let f = filter("All files", &[]);
        assert!(f.matches("anything.bin", &fake_mime));
    }

    #[test]
    fn regex_flavored_globs_are_normalized() {
        let f = filter("Binaries", &[("glob", ".*bin")]);
        assert!(f.matches("100MB.bin", &fake_mime));
        assert!(f.matches("bin", &fake_mime));
        let f = filter("Pdf", &[("glob", ".*\\.pdf")]);
        assert!(f.matches("doc.pdf", &fake_mime));
        let f = filter("Everything", &[("glob", ".*")]);
        assert!(f.matches("whatever.txt", &fake_mime));
        let f = filter("All Files", &[("glob", "*.*")]);
        assert!(f.matches("100MB.bin", &fake_mime));
        assert!(f.matches("makefile", &fake_mime));
        let f = filter("Images", &[("glob", "*.png")]);
        assert!(f.matches("shot.png", &fake_mime));
        assert!(!f.matches("shot.jpg", &fake_mime));
        let f = filter("Dotfiles", &[("glob", ".hidden")]);
        assert!(f.matches(".hidden", &fake_mime));
        assert!(!f.matches("notes.md", &fake_mime));
    }

    #[test]
    fn chromium_filters_match_case_insensitive_bracket_globs() {
        let bin = filter("*.bin", &[("glob", "*.[bB][iI][nN]")]);
        assert!(bin.matches("100MB.bin", &fake_mime));
        assert!(bin.matches("100MB.BIN", &fake_mime));
        assert!(!bin.matches("notes.txt", &fake_mime));
        let all = filter("All Files", &[("glob", "*.*")]);
        assert!(all.matches("100MB.bin", &fake_mime));
        assert!(all.matches("archive.tar.gz", &fake_mime));
    }

    #[test]
    fn chromiums_filter_json_round_trips_through_the_spec() {
        let spec = json!({"name": "*.bin", "patterns": [["glob", "*.[bB][iI][nN]"]]});
        let f = Filter::from_json(&spec).expect("Chromium's filter shape parses");
        assert!(f.matches("100MB.bin", &fake_mime));
        assert!(!f.matches("photo.png", &fake_mime));
    }

    #[test]
    fn parse_accepts_valid_and_rejects_malformed() {
        let valid =
            json!({"name": "Images", "patterns": [["glob", "*.png"], ["mime", "image/png"]]});
        assert_eq!(
            Filter::from_json(&valid),
            Some(filter(
                "Images",
                &[("glob", "*.png"), ("mime", "image/png")]
            ))
        );
        assert!(Filter::parse("").is_none());
        assert!(Filter::parse("not json").is_none());
        assert!(Filter::from_json(&json!({"patterns": []})).is_none());
        assert!(Filter::from_json(&json!({"name": "X", "patterns": [["regex", "a"]]})).is_none());
        assert!(Filter::from_json(&json!({"name": "X", "patterns": [["glob"]]})).is_none());
        assert!(Filter::from_json(&json!("a string")).is_none());
    }
}
