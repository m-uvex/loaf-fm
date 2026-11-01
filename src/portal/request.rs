//! Validation and normalization of portal file chooser requests. The D-Bus
//! layer (C++) demarshals the option map into the JSON shape documented in
//! `filters.rs`; this module checks it against the spec's safety rules and
//! fills defaults, so the picker UI and the reply builder only ever see
//! sensible values. An error means the request is answered with response
//! code 2.

use serde_json::{json, Map, Value};

use super::filters::Filter;

/// The entry point called from the D-Bus layer. Returns
/// `{"ok":true,"spec":...}` on success, `{"ok":false,"error":...}` when the
/// request must be answered with a response code of 2.
pub fn normalize_request_json(raw: &str) -> String {
    // LOAF_VERBOSE diagnostics go to stderr directly (Qt logging may be
    // routed elsewhere); this is the one place every request passes.
    if std::env::var("LOAF_VERBOSE").is_ok() {
        eprintln!("loaf: portal request: {raw}");
    }
    match normalize(raw) {
        Ok(spec) => json!({ "ok": true, "spec": spec }).to_string(),
        Err(error) => json!({ "ok": false, "error": error }).to_string(),
    }
}

/// Validates the request JSON and returns the normalized spec, or the
/// reason the request must fail.
pub fn normalize(raw: &str) -> Result<Value, String> {
    let value: Value = serde_json::from_str(raw).map_err(|error| format!("malformed request: {error}"))?;
    let kind = string(&value, "kind").ok_or("request kind is missing")?;
    if !matches!(kind.as_str(), "open" | "save" | "save-files") {
        return Err(format!("unknown request kind '{kind}'"));
    }
    let handle = plain_string(&value, "handle")?;
    if !handle.starts_with('/') {
        return Err("request handle is not an object path".into());
    }

    let current_file = if kind == "save" { optional_path(&value, "current_file")? } else { String::new() };
    let current_folder = optional_path(&value, "current_folder")?;
    // current_folder wins; otherwise a save request starts where the
    // pre-filled file lives.
    let start_folder = if !current_folder.is_empty() {
        current_folder
    } else {
        current_file.rsplit_once('/').map(|(parent, _)| parent.to_string()).unwrap_or_default()
    };

    let current_name = if kind == "save" {
        let name = string(&value, "current_name").unwrap_or_default();
        if name.is_empty() && !current_file.is_empty() {
            current_file.rsplit('/').next().unwrap_or_default().to_string()
        } else {
            name
        }
    } else {
        String::new()
    };
    validate_file_name(&current_name, "current_name")?;

    let mut files = Vec::new();
    if kind == "save-files" {
        let Some(list) = value.get("files").and_then(Value::as_array) else {
            return Err("save-files requests need a 'files' list".into());
        };
        for entry in list {
            let Some(name) = entry.as_str() else {
                return Err("files entries must be file names".into());
            };
            validate_file_name(name, "files")?;
            files.push(name.to_string());
        }
    }

    let mut spec = Map::new();
    spec.insert("kind".into(), json!(kind));
    spec.insert("handle".into(), json!(handle));
    spec.insert("app_id".into(), json!(string(&value, "app_id").unwrap_or_default()));
    spec.insert("parent_window".into(), json!(string(&value, "parent_window").unwrap_or_default()));
    spec.insert("title".into(), json!(string(&value, "title").unwrap_or_default()));
    spec.insert("accept_label".into(), json!(string(&value, "accept_label").unwrap_or_default()));
    spec.insert("modal".into(), json!(value.get("modal").and_then(Value::as_bool).unwrap_or(true)));
    spec.insert(
        "multiple".into(),
        json!(kind == "open" && value.get("multiple").and_then(Value::as_bool).unwrap_or(false)),
    );
    spec.insert(
        "directory".into(),
        json!(kind == "open" && value.get("directory").and_then(Value::as_bool).unwrap_or(false)),
    );
    spec.insert("start_folder".into(), json!(start_folder));
    spec.insert("current_name".into(), json!(current_name));
    spec.insert("current_file".into(), json!(current_file));
    spec.insert("files".into(), json!(files));
    spec.insert("filters".into(), json!(filter_list(&value)));
    spec.insert("current_filter".into(), json!(current_filter(&value)));
    spec.insert("choices".into(), json!(choice_list(&value)));
    Ok(Value::Object(spec))
}

fn string(value: &Value, key: &str) -> Option<String> {
    value.get(key)?.as_str().map(String::from)
}

/// A byte-string field: no interior NUL (the D-Bus layer chops trailing
/// ones), and absolute when present.
fn optional_path(value: &Value, key: &str) -> Result<String, String> {
    let path = string(value, key).unwrap_or_default();
    if path.contains('\0') {
        return Err(format!("{key} contains a NUL byte"));
    }
    if !path.is_empty() && !path.starts_with('/') {
        return Err(format!("{key} is not an absolute path"));
    }
    Ok(path)
}

fn plain_string(value: &Value, key: &str) -> Result<String, String> {
    let text = string(value, key).unwrap_or_default();
    if text.contains('\0') {
        return Err(format!("{key} contains a NUL byte"));
    }
    Ok(text)
}

/// Only plain file names are accepted: no separators, no traversal, no NUL.
fn validate_file_name(name: &str, field: &str) -> Result<(), String> {
    if name.is_empty() {
        return Ok(()); // an empty current_name is filled in by the UI
    }
    if name.contains('/') || name.contains('\0') {
        return Err(format!("{field} must be a plain file name"));
    }
    if name == "." || name == ".." {
        return Err(format!("{field} must not be '.' or '..'"));
    }
    Ok(())
}

/// Filters keep their order; malformed entries are dropped so one broken
/// filter cannot break the whole dialog.
fn filter_list(value: &Value) -> Vec<Value> {
    value
        .get("filters")
        .and_then(Value::as_array)
        .map(|entries| {
            entries
                .iter()
                .filter(|entry| Filter::from_json(entry).is_some())
                .cloned()
                .collect()
        })
        .unwrap_or_default()
}

fn current_filter(value: &Value) -> Option<Value> {
    let filter = value.get("current_filter")?;
    Filter::from_json(filter)?;
    Some(filter.clone())
}

/// Choices keep their order; malformed entries are dropped.
fn choice_list(value: &Value) -> Vec<Value> {
    value
        .get("choices")
        .and_then(Value::as_array)
        .map(|entries| {
            entries
                .iter()
                .filter(|entry| {
                    let values_ok = entry.get("values").and_then(Value::as_array).is_some_and(|values| {
                        values
                            .iter()
                            .all(|value| value.get("id").and_then(Value::as_str).is_some() && value.get("label").and_then(Value::as_str).is_some())
                    });
                    entry.get("label").and_then(Value::as_str).is_some()
                        && entry.get("id").and_then(Value::as_str).is_some()
                        && entry.get("selected").and_then(Value::as_str).is_some()
                        && values_ok
                })
                .cloned()
                .collect()
        })
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn spec(raw: Value) -> Value {
        normalize(&raw.to_string()).unwrap()
    }

    fn error(raw: Value) -> String {
        normalize(&raw.to_string()).unwrap_err()
    }

    #[test]
    fn open_request_gets_defaults() {
        let s = spec(json!({"kind": "open", "handle": "/org/x/request/1"}));
        assert_eq!(s["kind"], "open");
        assert_eq!(s["modal"], true);
        assert_eq!(s["multiple"], false);
        assert_eq!(s["directory"], false);
        assert_eq!(s["start_folder"], "");
        assert_eq!(s["current_name"], "");
        assert_eq!(s["files"], json!([]));
        assert_eq!(s["filters"], json!([]));
        assert_eq!(s["current_filter"], Value::Null);
        assert_eq!(s["choices"], json!([]));
    }

    #[test]
    fn save_request_prefers_current_folder_and_current_name() {
        let s = spec(json!({
            "kind": "save",
            "handle": "/org/x/request/1",
            "current_folder": "/home/u/Downloads",
            "current_name": "a.txt",
            "current_file": "/home/u/Documents/ignored.txt"
        }));
        assert_eq!(s["start_folder"], "/home/u/Downloads");
        assert_eq!(s["current_name"], "a.txt");
        assert_eq!(s["current_file"], "/home/u/Documents/ignored.txt");
    }

    #[test]
    fn save_request_falls_back_to_current_file() {
        let s = spec(json!({"kind": "save", "handle": "/org/x/request/1", "current_file": "/home/u/report.pdf"}));
        assert_eq!(s["start_folder"], "/home/u");
        assert_eq!(s["current_name"], "report.pdf");
    }

    #[test]
    fn multiple_and_directory_only_apply_to_open() {
        let s = spec(json!({"kind": "save", "handle": "/h", "multiple": true, "directory": true}));
        assert_eq!(s["multiple"], false);
        assert_eq!(s["directory"], false);
    }

    #[test]
    fn rejects_unknown_kinds_and_bad_paths() {
        assert!(error(json!({"kind": "print", "handle": "/h"})).contains("unknown request kind"));
        assert!(error(json!({"handle": "/h"})).contains("kind is missing"));
        assert!(error(json!({"kind": "open"})).contains("object path"));
        assert!(error(json!({"kind": "open", "handle": "/h", "current_folder": "relative/path"})).contains("absolute"));
        assert!(error(json!({"kind": "save", "handle": "/h", "current_folder": "/a\u{0}b"})).contains("NUL"));
    }

    #[test]
    fn rejects_path_traversal_in_names() {
        assert!(error(json!({"kind": "save", "handle": "/h", "current_name": "a/b.txt"})).contains("plain file name"));
        assert!(error(json!({"kind": "save", "handle": "/h", "current_name": ".."})).contains("'.' or '..'"));
        assert!(error(json!({"kind": "save-files", "handle": "/h", "files": ["ok.txt", "../escape"]})).contains("plain file name"));
        assert!(error(json!({"kind": "save-files", "handle": "/h", "files": ["ok.txt", 3]})).contains("file names"));
        assert!(error(json!({"kind": "save-files", "handle": "/h"})).contains("files"));
    }

    #[test]
    fn save_files_keeps_plain_names() {
        let s = spec(json!({"kind": "save-files", "handle": "/h", "files": ["a.png", "b.png"]}));
        assert_eq!(s["files"], json!(["a.png", "b.png"]));
        let s = spec(json!({"kind": "save-files", "handle": "/h", "files": []}));
        assert_eq!(s["files"], json!([]));
    }

    #[test]
    fn malformed_filters_are_dropped_but_good_ones_kept() {
        let s = spec(json!({
            "kind": "open",
            "handle": "/h",
            "filters": [
                {"name": "Images", "patterns": [["glob", "*.png"], ["mime", "image/png"]]},
                {"name": "Broken", "patterns": [["regex", "a"]]},
                "not an object"
            ]
        }));
        assert_eq!(s["filters"].as_array().unwrap().len(), 1);
        assert_eq!(s["filters"][0]["name"], "Images");
        assert_eq!(spec(json!({"kind": "open", "handle": "/h", "current_filter": {"name": "B", "patterns": []}}))["current_filter"]["name"], "B");
        assert_eq!(spec(json!({"kind": "open", "handle": "/h", "current_filter": "junk"}))["current_filter"], Value::Null);
    }

    #[test]
    fn malformed_choices_are_dropped_but_good_ones_kept() {
        let s = spec(json!({
            "kind": "open",
            "handle": "/h",
            "choices": [
                {"label": "Size", "id": "size", "values": [{"id": "s", "label": "Small"}], "selected": "s"},
                {"label": "Missing id", "values": [], "selected": ""},
                {"label": "Bad values", "id": "x", "values": [{"id": "s"}], "selected": ""}
            ]
        }));
        assert_eq!(s["choices"].as_array().unwrap().len(), 1);
        assert_eq!(s["choices"][0]["id"], "size");
    }

    #[test]
    fn envelope_reports_ok_and_errors() {
        let ok: Value = serde_json::from_str(&normalize_request_json(&json!({"kind": "open", "handle": "/h"}).to_string())).unwrap();
        assert_eq!(ok["ok"], true);
        assert_eq!(ok["spec"]["kind"], "open");
        let bad: Value = serde_json::from_str(&normalize_request_json(&json!({"kind": "bogus", "handle": "/h"}).to_string())).unwrap();
        assert_eq!(bad["ok"], false);
        assert!(bad["error"].as_str().unwrap().contains("unknown request kind"));
        let malformed: Value = serde_json::from_str(&normalize_request_json("not json")).unwrap();
        assert_eq!(malformed["ok"], false);
    }
}
