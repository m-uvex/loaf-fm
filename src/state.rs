//! Process-wide state shared by every Loaf object: persisted settings and
//! folder visit counts. Stored under `$XDG_CONFIG_HOME/loaf/`.

use crate::util::{self, lock};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;

static SETTINGS: Mutex<Option<HashMap<String, String>>> = Mutex::new(None);
static VISITS: Mutex<Option<HashMap<String, u32>>> = Mutex::new(None);

fn config_dir() -> PathBuf {
    util::config_home().join("loaf")
}

fn settings_file() -> PathBuf {
    config_dir().join("config.json")
}

fn load_settings() -> HashMap<String, String> {
    let mut map = HashMap::new();
    if let Ok(content) = std::fs::read_to_string(settings_file()) {
        if let Ok(serde_json::Value::Object(obj)) =
            serde_json::from_str::<serde_json::Value>(&content)
        {
            for (k, v) in obj {
                let s = match v {
                    serde_json::Value::String(s) => s,
                    other => other.to_string(),
                };
                map.insert(k, s);
            }
        }
    }
    map
}

pub fn get(key: &str) -> Option<String> {
    let mut guard = lock(&SETTINGS);
    guard.get_or_insert_with(load_settings).get(key).cloned()
}

pub fn get_or(key: &str, default: &str) -> String {
    get(key)
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| default.to_string())
}

pub fn get_bool(key: &str, default: bool) -> bool {
    match get(key).as_deref() {
        Some("true") | Some("1") => true,
        Some("false") | Some("0") => false,
        _ => default,
    }
}

/// Stores a setting (written atomically; unchanged values are not rewritten).
pub fn set(key: &str, value: &str) {
    let snapshot = {
        let mut guard = lock(&SETTINGS);
        let map = guard.get_or_insert_with(load_settings);
        if map.get(key).map(|v| v == value).unwrap_or(false) {
            return;
        }
        map.insert(key.to_string(), value.to_string());
        map.clone()
    };
    let mut sorted: Vec<(&String, &String)> = snapshot.iter().collect();
    sorted.sort();
    let obj: serde_json::Map<String, serde_json::Value> = sorted
        .into_iter()
        .map(|(k, v)| (k.clone(), serde_json::Value::String(v.clone())))
        .collect();
    let json = serde_json::to_string_pretty(&obj).unwrap_or_else(|_| "{}".into());
    if let Err(e) = util::write_atomic(&settings_file(), json.as_bytes()) {
        eprintln!("loaf: could not save settings: {}", e);
    }
}

pub fn set_bool(key: &str, value: bool) {
    set(key, if value { "true" } else { "false" });
}

fn visits_file() -> PathBuf {
    config_dir().join("visits.json")
}

/// Counts a folder visit (for the "Frequent folders" row).
pub fn record_visit(path: &str) {
    let home = util::home().to_string_lossy().to_string();
    if path == home || path == "/" || !path.starts_with('/') {
        return;
    }
    let snapshot = {
        let mut guard = lock(&VISITS);
        let map = guard.get_or_insert_with(|| {
            std::fs::read_to_string(visits_file())
                .ok()
                .and_then(|s| serde_json::from_str(&s).ok())
                .unwrap_or_default()
        });
        *map.entry(path.to_string()).or_insert(0) += 1;
        // Keep the file small: forget the least visited folders.
        if map.len() > 200 {
            let mut v: Vec<(String, u32)> = map.iter().map(|(k, c)| (k.clone(), *c)).collect();
            v.sort_by(|a, b| b.1.cmp(&a.1));
            v.truncate(150);
            *map = v.into_iter().collect();
        }
        map.clone()
    };
    let _ = util::write_atomic(
        &visits_file(),
        serde_json::to_string(&snapshot)
            .unwrap_or_default()
            .as_bytes(),
    );
}

/// Most visited folders that still exist, most visited first.
pub fn frequent(limit: usize) -> Vec<String> {
    let mut guard = lock(&VISITS);
    let map = guard.get_or_insert_with(|| {
        std::fs::read_to_string(visits_file())
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default()
    });
    let mut v: Vec<(&String, &u32)> = map.iter().collect();
    v.sort_by(|a, b| b.1.cmp(a.1).then_with(|| a.0.cmp(b.0)));
    v.into_iter()
        .map(|(p, _)| p.clone())
        .filter(|p| std::path::Path::new(p).is_dir())
        .take(limit)
        .collect()
}
