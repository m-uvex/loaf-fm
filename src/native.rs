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

        /// Human readable description of a MIME type ("PNG image").
        fn mime_comment_for(mime: &str) -> String;

        fn set_application_identity(version: &str);

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
