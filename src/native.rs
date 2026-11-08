//! Rust declarations for the C++ helpers in `cpp/native.cpp`.

#[cxx_qt::bridge]
pub mod ffi {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qqmlapplicationengine.h");
        type QQmlApplicationEngine = cxx_qt_lib::QQmlApplicationEngine;
    }

    #[namespace = "loaf"]
    unsafe extern "C++" {
        include!("loaf/native.h");

        /// Hands `paths` to an already running Loaf. True when it accepted.
        fn forward_to_running_instance(paths: &Vec<String>, mode: &str) -> bool;

        /// Registers D-Bus services, the `native` QML context property, the
        /// thumbnail image provider and translations.
        fn setup_engine(engine: Pin<&mut QQmlApplicationEngine>, paths: &Vec<String>, mode: &str);

        /// MIME type via shared-mime-info (QMimeDatabase).
        fn mime_type_for(path: &str, sniff: bool) -> String;

        type MimeFilterMatcher;
        fn new_mime_filter_matcher(filter_mimes: &Vec<String>) -> UniquePtr<MimeFilterMatcher>;
        fn matches(self: &MimeFilterMatcher, file_name: &str) -> bool;

        /// Human readable description of a MIME type ("PNG image").
        fn mime_comment_for(mime: &str) -> String;

        fn image_palette_json(path: &str) -> String;

        /// Sets the application name / desktop file id (Wayland app id, X11
        /// WM_CLASS) to `window_class`.
        fn set_application_identity(version: &str, window_class: &str);

        fn list_kmtp_devices_json() -> String;
        fn list_mtp_directory(url: &str) -> String;
        fn mtp_operation_json(action: &str, url: &str, argument: &str) -> String;
    }
}

pub fn list_kmtp_devices_json() -> String {
    ffi::list_kmtp_devices_json()
}

pub fn list_mtp_directory(url: &str) -> String {
    ffi::list_mtp_directory(url)
}

pub fn mtp_operation_json(action: &str, url: &str, argument: &str) -> String {
    ffi::mtp_operation_json(action, url, argument)
}

pub fn mime_type(path: &std::path::Path, sniff: bool) -> String {
    ffi::mime_type_for(&path.to_string_lossy(), sniff)
}

pub fn mime_comment(mime: &str) -> String {
    ffi::mime_comment_for(mime)
}

pub fn image_palette_json(path: &std::path::Path) -> String {
    ffi::image_palette_json(&path.to_string_lossy())
}

#[cfg(test)]
mod tests {
    use super::{ffi, mime_type};
    use std::path::Path;

    #[test]
    fn mime_matcher_distinguishes_compound_extensions() {
        let filter_mimes = vec!["application/x-compressed-tar".to_string()];
        let matcher = ffi::new_mime_filter_matcher(&filter_mimes);
        let matcher = matcher.as_ref().expect("matcher is constructed");
        assert!(matcher.matches("a.tar.gz"));
        assert!(!matcher.matches("b.gz"));
    }

    #[test]
    fn mime_matcher_uses_mime_inheritance() {
        let filter_mimes = vec!["text/plain".to_string()];
        let matcher = ffi::new_mime_filter_matcher(&filter_mimes);
        assert!(matcher
            .as_ref()
            .expect("matcher is constructed")
            .matches("notes.md"));
    }

    #[test]
    fn mime_matcher_handles_extensionless_names() {
        let filter_mimes = vec![mime_type(Path::new("Makefile"), false)];
        let matcher = ffi::new_mime_filter_matcher(&filter_mimes);
        assert!(matcher
            .as_ref()
            .expect("matcher is constructed")
            .matches("Makefile"));
    }

    #[test]
    fn mime_matcher_rejects_unknown_filter_types() {
        let filter_mimes = vec!["application/x-loaf-unknown-filter".to_string()];
        let matcher = ffi::new_mime_filter_matcher(&filter_mimes);
        assert!(!matcher
            .as_ref()
            .expect("matcher is constructed")
            .matches("file.png"));
    }
}
