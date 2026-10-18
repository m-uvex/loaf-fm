use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("app.loaf")
            .qml_file("qml/main.qml")
            .qml_file("qml/Theme.qml")
            .qml_file("qml/LoafIcon.qml")
            .qml_file("qml/SettingsView.qml")
            .qml_file("qml/PCView.qml")
            .qml_file("qml/components/LoafPopup.qml")
            .qml_file("qml/components/LoafMenuItem.qml")
            .qml_file("qml/components/LoafMenu.qml")
            .qml_file("qml/components/LoafSegmented.qml")
            .qml_file("qml/components/LoafSwitch.qml")
            .qml_file("qml/components/LoafButton.qml")
            .qml_file("qml/components/LoafCard.qml")
            .qml_file("qml/components/SectionHeader.qml")
            .qml_file("qml/components/LoafDialog.qml")
            .qml_file("qml/components/LoafTextPrompt.qml")
            .qml_file("qml/components/UsageBar.qml")
            .qml_file("qml/components/DriveCard.qml")
    )
    .qrc("assets/resources.qrc")
    .file("src/bridge.rs")
    .build();
}
