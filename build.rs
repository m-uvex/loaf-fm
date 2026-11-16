use cxx_qt_build::{CxxQtBuilder, QmlModule};
use std::path::PathBuf;

fn xml_escape(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

// Compiles translations/*.ts to .qm with lrelease and embeds them under :/i18n.
// A missing translations/ directory or failure to compile is a build failure in release mode.
fn compile_translations() -> Option<PathBuf> {
    let is_release = std::env::var("PROFILE").as_deref() == Ok("release");
    let fail = |step: &str, detail: &str| -> Option<PathBuf> {
        let message = format!("translations: {step} failed: {detail}");
        if is_release {
            panic!("{message}");
        }
        println!("cargo:warning={message}");
        None
    };
    let out_dir = std::env::var("OUT_DIR").ok()?;
    let mut catalogues: Vec<PathBuf> = Vec::new();
    match std::fs::read_dir("translations") {
        Ok(entries) => {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) == Some("ts") {
                    catalogues.push(path);
                }
            }
        }
        Err(error) => return fail("read translations directory", &error.to_string()),
    }
    if catalogues.is_empty() {
        return None;
    }
    let check_candidate = |bin: &str| -> bool {
        std::process::Command::new(bin)
            .arg("--version")
            .output()
            .map(|out| {
                let text = String::from_utf8_lossy(&out.stdout);
                text.contains("lrelease") || out.status.success()
            })
            .unwrap_or(false)
    };
    let lrelease = if let Some(env_lrelease) = std::env::var("LRELEASE")
        .ok()
        .filter(|v| !v.trim().is_empty())
    {
        if !check_candidate(&env_lrelease) {
            return fail(
                "find lrelease",
                &format!("LRELEASE='{env_lrelease}' is not runnable"),
            );
        }
        env_lrelease
    } else {
        const CANDIDATES: &[&str] = &["lrelease", "lrelease-qt6", "lrelease6"];
        let mut found = None;
        for &candidate in CANDIDATES {
            if check_candidate(candidate) {
                found = Some(candidate.to_string());
                break;
            }
        }
        match found {
            Some(binary) => {
                println!("cargo:warning=translations: using lrelease candidate '{binary}'");
                binary
            }
            None => {
                return fail(
                    "find lrelease",
                    "executable not found or not runnable (tried lrelease, lrelease-qt6, lrelease6)",
                );
            }
        }
    };
    let qm_dir = PathBuf::from(&out_dir).join("i18n");
    if let Err(error) = std::fs::create_dir_all(&qm_dir) {
        return fail("create i18n output directory", &error.to_string());
    }
    let mut qrc = String::from("<RCC>\n  <qresource prefix=\"/i18n\">\n");
    for catalogue in &catalogues {
        let Some(stem) = catalogue.file_stem().and_then(|s| s.to_str()) else {
            return fail("read catalogue file stem", &catalogue.display().to_string());
        };
        let stem = stem.to_string();
        let qm = qm_dir.join(format!("{stem}.qm"));
        let status = match std::process::Command::new(&lrelease)
            .arg(catalogue)
            .arg("-qm")
            .arg(&qm)
            .status()
        {
            Ok(status) => status,
            Err(error) => return fail("run lrelease", &error.to_string()),
        };
        if !status.success() {
            return fail(
                "compile catalogue",
                &format!("lrelease failed for {}", catalogue.display()),
            );
        }
        qrc.push_str(&format!(
            "    <file alias=\"{}.qm\">{}</file>\n",
            xml_escape(&stem),
            xml_escape(&qm.to_string_lossy())
        ));
    }
    qrc.push_str("  </qresource>\n</RCC>\n");
    let qrc_path = PathBuf::from(&out_dir).join("i18n.qrc");
    if let Err(error) = std::fs::write(&qrc_path, qrc) {
        return fail("write i18n qrc", &error.to_string());
    }
    println!("cargo:rerun-if-changed=translations");
    println!("cargo:rerun-if-env-changed=LRELEASE");
    Some(qrc_path)
}

fn main() {
    let builder = CxxQtBuilder::new_qml_module(QmlModule::new("app.loaf").qml_files([
        "qml/main.qml",
        "qml/Theme.qml",
        "qml/Messages.qml",
        "qml/LoafIcon.qml",
        "qml/SettingsView.qml",
        "qml/PCView.qml",
        "qml/FilePane.qml",
        "qml/Sidebar.qml",
        "qml/PickerWindow.qml",
        "qml/QuickLook.qml",
        "qml/PropertiesDialog.qml",
        "qml/BatchRenameDialog.qml",
        "qml/ConflictDialog.qml",
        "qml/OperationsPanel.qml",
        "qml/Toast.qml",
        "qml/components/FileGridCard.qml",
        "qml/components/InlineRename.qml",
        "qml/components/LoafCheckBox.qml",
        "qml/components/LoafRadio.qml",
        "qml/components/LoafTextField.qml",
        "qml/components/LoafPopup.qml",
        "qml/components/LoafMenuItem.qml",
        "qml/components/LoafMenu.qml",
        "qml/components/LoafSelect.qml",
        "qml/components/LoafSegmented.qml",
        "qml/components/LoafSwitch.qml",
        "qml/components/LoafSlider.qml",
        "qml/components/LoafButton.qml",
        "qml/components/LoafCard.qml",
        "qml/components/SectionHeader.qml",
        "qml/components/LoafDialog.qml",
        "qml/components/LoafTextPrompt.qml",
        "qml/components/UsageBar.qml",
        "qml/components/LoafShape.qml",
        "qml/components/DriveCard.qml",
        "qml/components/TopIconButton.qml",
        "qml/settings/SettingDivider.qml",
        "qml/settings/SettingRow.qml",
        "qml/settings/SettingCard.qml",
        "qml/settings/InterfaceTab.qml",
        "qml/settings/BehaviorTab.qml",
        "qml/settings/AccessibilityTab.qml",
        "qml/settings/ExperimentalTab.qml",
        "qml/settings/ShareTab.qml",
        "qml/settings/NetworkTab.qml",
        "qml/settings/AboutTab.qml",
    ]))
    .qt_module("DBus")
    .qt_module("Quick")
    .qrc("assets/resources.qrc")
    .files([
        "src/native.rs",
        "src/pane.rs",
        "src/core.rs",
        "src/portal_bridge.rs",
    ])
    .cpp_files([
        "cpp/loaf/native.h",
        "cpp/loaf/portal.h",
        "cpp/loaf/thumbnails.h",
        "cpp/native.cpp",
        "cpp/portal.cpp",
        "cpp/thumbnails.cpp",
    ]);
    let builder = match compile_translations() {
        Some(qrc) => builder.qrc(qrc),
        None => builder,
    };
    // Our own headers live in cpp/ ("loaf/native.h").
    let builder = unsafe {
        builder.cc_builder(|cc| {
            cc.include("cpp");
            // cxx-qt-build applies std=c++17 after this callback; a plain flag is emitted later and wins.
            cc.flag("-std=c++23");
            for (key, value) in [
                ("QT_NO_KEYWORDS", None),
                ("QT_NO_FOREACH", None),
                ("QT_NO_CAST_FROM_ASCII", None),
                ("QT_NO_CAST_TO_ASCII", None),
                ("QT_NO_URL_CAST_FROM_STRING", None),
                ("QT_DISABLE_DEPRECATED_UP_TO", Some("0x060C00")),
            ] {
                cc.define(key, value);
            }
        })
    };
    builder.build();
    // Our C++ code in the cxx-qt static library uses these modules; with
    // --as-needed the early -l flags are dropped, so repeat them last.
    for lib in ["Qt6Quick", "Qt6Qml", "Qt6DBus", "Qt6Gui", "Qt6Core"] {
        println!("cargo:rustc-link-arg=-l{lib}");
    }
}
