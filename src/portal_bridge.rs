//! Rust entry points for the C++ D-Bus layer (`cpp/portal.cpp`): request
//! validation and `file://` URI building. This file must live next to the
//! other cxx-qt bridges because cxx-qt-build only accepts one directory per
//! QmlModule; the logic it exposes lives in `portal::request` and
//! `portal::uri`.

#[cxx_qt::bridge]
pub mod ffi {
    #[namespace = "loaf_portal"]
    extern "Rust" {
        /// Validates and normalizes a request spec built from the D-Bus
        /// options; returns `{"ok":..,"spec"/"error":..}` JSON.
        fn normalize_picker_request(json: &str) -> String;

        /// `file://` URIs for absolute paths, in the same order as the
        /// input.
        fn picker_file_uris(paths: &Vec<String>) -> Vec<String>;
    }
}

fn normalize_picker_request(json: &str) -> String {
    crate::portal::request::normalize_request_json(json)
}

// cxx marshals string collections as Vec, so the parameter stays a Vec
// even though clippy would prefer a slice.
#[allow(clippy::ptr_arg)]
fn picker_file_uris(paths: &Vec<String>) -> Vec<String> {
    paths
        .iter()
        .map(|path| crate::portal::uri::path_to_file_uri(std::path::Path::new(path)))
        .collect()
}
