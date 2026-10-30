import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// Shown when pasting / dropping onto names that already exist.
LoafDialog {
    id: dlg
    title: conflicts.length === 1 ? qsTr("Replace “%1”?").arg(conflicts[0].name) : theme.plural(conflicts.length, qsTr("1 item already exists"), qsTr("%1 items already exist"))
    dialogWidth: Math.min(window.width - 80, 480)

    property var conflicts: []
    property var paths: []
    property string dest: ""
    property string mode: "copy"
    property bool fromCut: false

    function showFor(list, srcPaths, destDir, opMode, cut) {
        conflicts = list;
        paths = srcPaths;
        dest = destDir;
        mode = opMode;
        fromCut = !!cut;
        open();
    }

    function apply(resolution) {
        core.transfer(JSON.stringify(paths), dest, mode, resolution);
        if (fromCut)
            window.afterCutPaste();
        close();
    }

    Text {
        Layout.fillWidth: true
        text: dlg.conflicts.length === 1
            ? (dlg.conflicts[0].is_dir && dlg.conflicts[0].src_is_dir
                ? qsTr("A folder with this name already exists. Merge combines both folders; Replace moves the existing one to the trash.")
                : qsTr("An item with this name already exists in the destination."))
            : qsTr("Choose what to do with all of them. Items without a conflict are transferred normally.")
        color: theme.textMuted
        font.pixelSize: theme.fs(12)
        wrapMode: Text.Wrap
    }

    // Side by side comparison of the first conflict.
    RowLayout {
        visible: dlg.conflicts.length > 0
        Layout.fillWidth: true
        spacing: 10
        Repeater {
            model: dlg.conflicts.length > 0 ? [
                { title: qsTr("Existing"), size: dlg.conflicts[0].dest_size, date: dlg.conflicts[0].dest_modified, dir: dlg.conflicts[0].is_dir },
                { title: qsTr("Incoming"), size: dlg.conflicts[0].src_size, date: dlg.conflicts[0].src_modified, dir: dlg.conflicts[0].src_is_dir }
            ] : []
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 70
                radius: theme.radiusM
                color: theme.surfaceContainer
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    LoafIcon { name: modelData.dir ? "folder" : "file"; size: 22; color: theme.primary }
                    ColumnLayout {
                        spacing: 2
                        Text { text: modelData.title; color: theme.textMain; font.pixelSize: theme.fs(12); font.bold: true }
                        Text { text: modelData.size; color: theme.textMuted; font.pixelSize: theme.fs(11) }
                        Text { text: modelData.date; color: theme.textMuted; font.pixelSize: theme.fs(11) }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        LoafButton { text: qsTr("Cancel"); variant: "text"; onClicked: dlg.close() }
        Item { Layout.fillWidth: true }
        LoafButton { text: qsTr("Skip"); variant: "tonal"; onClicked: dlg.apply("skip") }
        LoafButton { text: qsTr("Keep Both"); variant: "tonal"; onClicked: dlg.apply("rename") }
        // Folder onto folder: combine them; nothing in the destination is overwritten.
        LoafButton {
            visible: dlg.conflicts.some(function(c) { return c.is_dir && c.src_is_dir; })
            text: qsTr("Merge")
            variant: "tonal"
            onClicked: dlg.apply("merge")
        }
        LoafButton { text: qsTr("Replace"); variant: "filled"; onClicked: dlg.apply("overwrite") }
    }
}
