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

        /// MIME type via shared-mime-info (QMimeDatabase). Thread safe.
        fn mime_type_for(path: &str, sniff: bool) -> String;

        /// Whether a file matches a MIME filter, shared-mime-info
        /// inheritance and aliases included. `is_dir` matches only
        /// directory types. Thread safe.
        fn mime_filter_matches(file_name: &str, filter_mime: &str, is_dir: bool) -> bool;

        /// Human readable description of a MIME type ("PNG image").
        fn mime_comment_for(mime: &str) -> String;

        fn set_application_identity(version: &str);
    }
}

pub fn mime_type(path: &std::path::Path, sniff: bool) -> String {
    ffi::mime_type_for(&path.to_string_lossy(), sniff)
}

pub fn mime_filter_matches(file_name: &str, filter_mime: &str, is_dir: bool) -> bool {
    ffi::mime_filter_matches(file_name, filter_mime, is_dir)
}

pub fn mime_comment(mime: &str) -> String {
    ffi::mime_comment_for(mime)
}
