use cxx_qt_build::{CxxQtBuilder, QmlModule};

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
            .qml_file("qml/components/MtpCard.qml")
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
    .cpp_file("cpp/loaf/native.h")
    .cpp_file("cpp/loaf/thumbnails.h")
    .cpp_file("cpp/native.cpp")
    .cpp_file("cpp/thumbnails.cpp");
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
