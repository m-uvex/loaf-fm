use cxx_qt_build::{CxxQtBuilder, QmlModule};
use std::path::PathBuf;

// Compiles translations/*.ts to .qm with lrelease and embeds them under :/i18n.
// Returns None when there is nothing to compile or lrelease is unavailable.
fn compile_translations() -> Option<PathBuf> {
    let out_dir = std::env::var("OUT_DIR").ok()?;
    let mut catalogues: Vec<PathBuf> = Vec::new();
    let entries = std::fs::read_dir("translations").ok()?;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) == Some("ts") {
            println!("cargo:rerun-if-changed={}", path.display());
            catalogues.push(path);
        }
    }
    if catalogues.is_empty() {
        return None;
    }
    let lrelease_available = std::process::Command::new("lrelease")
        .arg("--version")
        .output()
        .map(|out| {
            let text = String::from_utf8_lossy(&out.stdout);
            text.contains("lrelease") || out.status.success()
        })
        .unwrap_or(false);
    if !lrelease_available {
        println!("cargo:warning=lrelease not found; translations disabled");
        return None;
    }
    let qm_dir = PathBuf::from(&out_dir).join("i18n");
    std::fs::create_dir_all(&qm_dir).ok()?;
    let mut qrc = String::from("<RCC>\n  <qresource prefix=\"/i18n\">\n");
    for catalogue in &catalogues {
        let stem = catalogue.file_stem()?.to_string_lossy().to_string();
        let qm = qm_dir.join(format!("{stem}.qm"));
        let status = std::process::Command::new("lrelease")
            .arg(catalogue)
            .arg("-qm")
            .arg(&qm)
            .status()
            .ok()?;
        if !status.success() {
            println!(
                "cargo:warning=lrelease failed for {}; translations disabled",
                catalogue.display()
            );
            return None;
        }
        qrc.push_str(&format!(
            "    <file alias=\"{stem}.qm\">{}</file>\n",
            qm.display()
        ));
    }
    qrc.push_str("  </qresource>\n</RCC>\n");
    let qrc_path = PathBuf::from(&out_dir).join("i18n.qrc");
    std::fs::write(&qrc_path, qrc).ok()?;
    println!("cargo:rerun-if-changed={}", qrc_path.display());
    Some(qrc_path)
}

fn main() {
    let builder = CxxQtBuilder::new_qml_module(
        QmlModule::new("app.loaf")
            .qml_file("qml/main.qml")
            .qml_file("qml/Theme.qml")
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
