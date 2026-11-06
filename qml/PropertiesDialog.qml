import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// Properties: General (sizes, dates, location), Permissions (owner, group,
// rwx bits) and Open With (default application for the file type).
LoafDialog {
    id: dlg
    dialogWidth: Math.min(window.width - 80, 480)

    property var paths: []
    property var info: ({})
    property string sizeText: ""
    property int tab: 0
    property var apps: []
    property string defaultApp: ""
    // Editable permission bits (owner, group, others) x (r, w, x).
    property int mode: 0
    property bool recursive: false
    readonly property bool multiple: paths.length > 1
    readonly property string sizeKey: "props:" + paths.join("\n")

    title: multiple ? qsTr("%n item(s)", "", paths.length) : (info.name || qsTr("Properties"))

    function showFor(list) {
        paths = list;
        tab = 0;
        recursive = false;
        sizeText = "";
        info = multiple ? ({}) : JSON.parse(core.get_item_info(list[0]) || "{}");
        mode = (info.mode_bits || 0) & 0o777;
        apps = [];
        defaultApp = "";
        if (!multiple && !info.is_dir) {
            apps = JSON.parse(core.open_with_apps(list[0]) || "[]");
            defaultApp = core.default_app_for(list[0]);
        }
        var needsMeasure = multiple || info.is_dir;
        if (needsMeasure) {
            sizeText = qsTr("Calculating…");
            core.start_dir_size(sizeKey, JSON.stringify(list));
        }
        open();
    }

    Connections {
        target: core
        function onDir_size_ready(key, json) {
            if (key === dlg.sizeKey)
                dlg.sizeText = JSON.parse(json).text;
        }
    }

    LoafSegmented {
        visible: !dlg.multiple
        options: dlg.info.is_dir
            ? [{ value: 0, label: qsTr("General") }, { value: 1, label: qsTr("Permissions") }]
            : [{ value: 0, label: qsTr("General") }, { value: 1, label: qsTr("Permissions") }, { value: 2, label: qsTr("Open With") }]
        value: dlg.tab
        onSelected: function(v) { dlg.tab = v; }
    }

    // ---- General ----------------------------------------------------------
    GridLayout {
        visible: dlg.tab === 0
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 14
        rowSpacing: 8

        component Key: Text {
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
        }
        component Val: Text {
            color: theme.textMain
            font.pixelSize: theme.fs(12)
            Layout.fillWidth: true
            wrapMode: Text.WrapAnywhere
            textFormat: Text.PlainText
        }

        Key { text: qsTr("Type"); visible: !dlg.multiple }
        Val { text: ((dlg.info.is_dir ? theme.categoryName("folder") : (dlg.info.type || "-")) + (dlg.info.mime && !dlg.info.is_dir ? "  (" + dlg.info.mime + ")" : "")); visible: !dlg.multiple }

        Key { text: qsTr("Size") }
        Val { text: dlg.sizeText.length > 0 ? dlg.sizeText : (dlg.info.size_str || "-") }

        Key { text: qsTr("Contents"); visible: !dlg.multiple && dlg.info.is_dir === true }
        Val { text: qsTr("%n item(s)", "", dlg.info.items || 0); visible: !dlg.multiple && dlg.info.is_dir === true }

        Key { text: qsTr("Location"); visible: !dlg.multiple }
        Val { text: dlg.info.parent || "-"; visible: !dlg.multiple }

        Key { text: qsTr("Link to"); visible: dlg.info.is_symlink === true }
        Val { text: dlg.info.link_target || ""; visible: dlg.info.is_symlink === true }

        Key { text: qsTr("Modified"); visible: !dlg.multiple }
        Val { text: theme.relativeTime(dlg.info.modified_ts || 0); visible: !dlg.multiple }

        Key { text: qsTr("Accessed"); visible: !dlg.multiple }
        Val { text: theme.relativeTime(dlg.info.accessed_ts || 0); visible: !dlg.multiple }

        Key { text: qsTr("Created"); visible: !dlg.multiple }
        Val { text: theme.relativeTime(dlg.info.created_ts || 0); visible: !dlg.multiple }

        Key { text: qsTr("Free space"); visible: !dlg.multiple }
        Val { text: dlg.info.free_space || "-"; visible: !dlg.multiple }
    }

    // ---- Permissions --------------------------------------------------------
    ColumnLayout {
        visible: dlg.tab === 1 && !dlg.multiple
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: qsTr("Owner: %1    Group: %2").arg(dlg.info.owner || "-").arg(dlg.info.group || "-")
            color: theme.textMain
            font.pixelSize: theme.fs(12)
        }
        Text {
            visible: dlg.info.is_owner !== true
            text: qsTr("Only the owner can change these permissions.")
            color: theme.danger
            font.pixelSize: theme.fs(11)
        }

        ColumnLayout {
            spacing: 2
            enabled: dlg.info.is_owner === true

            RowLayout {
                spacing: 0
                Item { Layout.preferredWidth: 70; height: 1 }
                Repeater {
                    model: [qsTr("Read"), qsTr("Write"), dlg.info.is_dir ? qsTr("Open") : qsTr("Run")]
                    delegate: Text {
                        required property string modelData
                        Layout.preferredWidth: 64
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: theme.textMuted
                        font.pixelSize: theme.fs(11)
                    }
                }
            }

            Repeater {
                model: [
                    { label: qsTr("Owner"), shift: 6 },
                    { label: qsTr("Group"), shift: 3 },
                    { label: qsTr("Others"), shift: 0 }
                ]
                delegate: RowLayout {
                    id: permRow
                    required property var modelData
                    spacing: 0
                    Text {
                        text: permRow.modelData.label
                        color: theme.textMain
                        font.pixelSize: theme.fs(12)
                        Layout.preferredWidth: 70
                    }
                    Repeater {
                        model: [4, 2, 1]
                        delegate: Item {
                            required property int modelData
                            readonly property int bit: modelData << permRow.modelData.shift
                            Layout.preferredWidth: 64
                            implicitHeight: 30
                            LoafCheckBox {
                                anchors.centerIn: parent
                                checked: (dlg.mode & parent.bit) !== 0
                                onToggled: dlg.mode = checked ? (dlg.mode | parent.bit) : (dlg.mode & ~parent.bit)
                                Accessible.name: permRow.modelData.label
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: qsTr("Mode: %1").arg(("000" + dlg.mode.toString(8)).slice(-3))
            color: theme.textMuted
            font.pixelSize: theme.fs(11)
            font.family: "monospace"
        }

        LoafCheckBox {
            visible: dlg.info.is_dir === true
            enabled: dlg.info.is_owner === true
            text: qsTr("Apply to everything inside")
            checked: dlg.recursive
            onToggled: dlg.recursive = checked
        }

        LoafButton {
            text: qsTr("Apply Permissions")
            variant: "tonal"
            enabled: dlg.info.is_owner === true && (dlg.mode !== (dlg.info.mode_bits & 0o777) || dlg.recursive)
            onClicked: {
                var err = core.set_permissions(dlg.paths[0], dlg.mode | (dlg.info.mode_bits & 0o7000), dlg.recursive);
                if (err.length > 0) {
                    window.toast("error", err);
                } else {
                    window.toast("info", qsTr("Permissions updated"));
                    dlg.info = JSON.parse(core.get_item_info(dlg.paths[0]) || "{}");
                    dlg.mode = (dlg.info.mode_bits || 0) & 0o777;
                }
            }
        }
    }

    // ---- Open With -----------------------------------------------------------
    ColumnLayout {
        visible: dlg.tab === 2 && !dlg.multiple
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: qsTr("Default application for %1").arg(dlg.info.type || qsTr("this type"))
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
        }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(260, contentHeight)
            clip: true
            model: dlg.apps
            ScrollBar.vertical: ScrollBar {}
            delegate: LoafRadio {
                required property var modelData
                width: ListView.view.width
                text: modelData.name
                checked: modelData.id === dlg.defaultApp
                onClicked: {
                    core.set_default_app(dlg.paths[0], modelData.id);
                    dlg.defaultApp = modelData.id;
                }
            }
        }
        Text {
            visible: dlg.apps.length === 0
            text: qsTr("No installed application declares support for this file type.")
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        LoafButton {
            text: qsTr("Close")
            variant: "filled"
            onClicked: dlg.close()
        }
    }
}
