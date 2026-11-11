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
                return fail("find lrelease", "executable not found or not runnable (tried lrelease, lrelease-qt6, lrelease6)");
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
    let builder = CxxQtBuilder::new_qml_module(
        QmlModule::new("app.loaf")
            .qml_file("qml/main.qml")
            .qml_file("qml/Theme.qml")
            .qml_file("qml/Messages.qml")
            .qml_file("qml/LoafIcon.qml")
            .qml_file("qml/SettingsView.qml")
            .qml_file("qml/PCView.qml")
            .qml_file("qml/FilePane.qml")
            .qml_file("qml/Sidebar.qml")
            .qml_file("qml/PickerWindow.qml")
            .qml_file("qml/QuickLook.qml")
            .qml_file("qml/PropertiesDialog.qml")
            .qml_file("qml/BatchRenameDialog.qml")
            .qml_file("qml/ConflictDialog.qml")
            .qml_file("qml/OperationsPanel.qml")
            .qml_file("qml/Toast.qml")
            .qml_file("qml/components/FileGridCard.qml")
            .qml_file("qml/components/InlineRename.qml")
            .qml_file("qml/components/LoafCheckBox.qml")
            .qml_file("qml/components/LoafRadio.qml")
            .qml_file("qml/components/LoafTextField.qml")
            .qml_file("qml/components/LoafPopup.qml")
            .qml_file("qml/components/LoafMenuItem.qml")
            .qml_file("qml/components/LoafMenu.qml")
            .qml_file("qml/components/LoafSelect.qml")
            .qml_file("qml/components/LoafSegmented.qml")
            .qml_file("qml/components/LoafSwitch.qml")
            .qml_file("qml/components/LoafSlider.qml")
            .qml_file("qml/components/LoafButton.qml")
            .qml_file("qml/components/LoafCard.qml")
            .qml_file("qml/components/SectionHeader.qml")
            .qml_file("qml/components/LoafDialog.qml")
            .qml_file("qml/components/LoafTextPrompt.qml")
            .qml_file("qml/components/UsageBar.qml")
            .qml_file("qml/components/LoafShape.qml")
            .qml_file("qml/components/DriveCard.qml")
            .qml_file("qml/components/TopIconButton.qml")
            .qml_file("qml/settings/SettingDivider.qml")
            .qml_file("qml/settings/SettingRow.qml")
            .qml_file("qml/settings/SettingCard.qml")
            .qml_file("qml/settings/InterfaceTab.qml")
            .qml_file("qml/settings/BehaviorTab.qml")
            .qml_file("qml/settings/AccessibilityTab.qml")
            .qml_file("qml/settings/ExperimentalTab.qml")
            .qml_file("qml/settings/ShareTab.qml")
            .qml_file("qml/settings/NetworkTab.qml")
            .qml_file("qml/settings/AboutTab.qml"),
    )
    .qt_module("DBus")
    .qt_module("Quick")
    .qrc("assets/resources.qrc")
    .file("src/native.rs")
    .file("src/pane.rs")
    .file("src/core.rs")
    .file("src/portal_bridge.rs")
    .cpp_file("cpp/loaf/native.h")
    .cpp_file("cpp/loaf/portal.h")
    .cpp_file("cpp/loaf/thumbnails.h")
    .cpp_file("cpp/native.cpp")
    .cpp_file("cpp/portal.cpp")
    .cpp_file("cpp/thumbnails.cpp");
    let builder = match compile_translations() {
        Some(qrc) => builder.qrc(qrc),
        None => builder,
    };
    // Our own headers live in cpp/ ("loaf/native.h").
    let builder = unsafe {
        builder.cc_builder(|cc| {
            cc.include("cpp");
        })
    };
    builder.build();
    // Our C++ code in the cxx-qt static library uses these modules; with
    // --as-needed the early -l flags are dropped, so repeat them last.
    for lib in ["Qt6Quick", "Qt6Qml", "Qt6DBus", "Qt6Gui", "Qt6Core"] {
        println!("cargo:rustc-link-arg=-l{lib}");
    }
}
