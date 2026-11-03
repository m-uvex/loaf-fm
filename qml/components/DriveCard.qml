import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import app.loaf

// DriveCard -- storage drive card used by the PC dashboard.
// drive: { name, label, device, mountpoint, is_external, mounted, fs_type,
//          icon, size_bytes, used_bytes, percent }
Item {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 128
    implicitHeight: 128
    implicitWidth: 320

    property var drive: ({})

    signal contextRequested(real x, real y)
    signal activated()
    signal mountRequested()

    readonly property bool isMounted: {
        var d = root.drive || {};
        if (d.mounted !== undefined)
            return d.mounted === true;
        if (d.is_mounted !== undefined)
            return d.is_mounted === true;
        return false;
    }

    readonly property real usedBytes: {
        var d = root.drive || {};
        return Number(d.used_bytes) || 0;
    }

    readonly property real totalBytes: {
        var d = root.drive || {};
        if (d.size_bytes !== undefined)
            return Number(d.size_bytes) || 0;
        return Number(d.total_bytes) || 0;
    }

    function formatBytes(bytes) {
        var b = Number(bytes) || 0;
        var gb = 1024 * 1024 * 1024;
        var tb = 1024 * gb;
        var mb = 1024 * 1024;
        if (b >= tb)
            return (b / tb).toFixed(1) + " TB";
        if (b >= gb)
            return (b / gb).toFixed(1) + " GB";
        if (b >= mb)
            return (b / mb).toFixed(1) + " MB";
        if (b > 0)
            return (b / 1024).toFixed(0) + " KB";
        return "0 B";
    }

    function driveIcon() {
        var d = root.drive || {};
        if (d.icon && String(d.icon).length > 0)
            return d.icon;
        if (d.is_external === true)
            return "usb";
        return "hard-drive";
    }

    readonly property real usage: Math.max(0, Math.min(1, ((root.drive && root.drive.percent) || 0) / 100))
    // Nearly full drives switch to the error colors.
    readonly property bool almostFull: root.isMounted && root.usage >= 0.9

    function secondaryText() {
        var d = root.drive || {};
        var label = d.label ? String(d.label) : "";
        var fs = d.fs_type ? String(d.fs_type) : "";
        if (label.length > 0 && fs.length > 0)
            return label + " \u2022 " + fs;
        if (label.length > 0)
            return label;
        if (fs.length > 0)
            return fs;
        return d.device ? String(d.device) : "";
    }

    opacity: root.isMounted || (root.drive && root.drive.provider === "mtp") ? 1.0 : 0.85
    Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 140 } }

    scale: cardMouse.pressed ? 0.98 : 1.0
    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.32 } }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: theme.radiusXl
        color: root.isMounted ? theme.surfaceContainer : theme.surfaceContainerLow

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
    }

    Rectangle {
        id: hoverLayer
        anchors.fill: parent
        radius: theme.radiusXl
        color: cardMouse.containsMouse ? theme.hoverOverlay : "transparent"

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: 100 } }
    }

    // Dashed outline for unmounted drives.
    Shape {
        id: dashedBorder
        anchors.fill: parent
        visible: !root.isMounted && !(root.drive && root.drive.provider === "mtp")
        readonly property real r: theme.radiusXl

        ShapePath {
            strokeColor: theme.outlineVariant
            strokeWidth: 1
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]
            capStyle: ShapePath.FlatCap

            startX: dashedBorder.r
            startY: 0
            PathLine { x: dashedBorder.width - dashedBorder.r; y: 0 }
            PathArc { x: dashedBorder.width; y: dashedBorder.r; radiusX: dashedBorder.r; radiusY: dashedBorder.r }
            PathLine { x: dashedBorder.width; y: dashedBorder.height - dashedBorder.r }
            PathArc { x: dashedBorder.width - dashedBorder.r; y: dashedBorder.height; radiusX: dashedBorder.r; radiusY: dashedBorder.r }
            PathLine { x: dashedBorder.r; y: dashedBorder.height }
            PathArc { x: 0; y: dashedBorder.height - dashedBorder.r; radiusX: dashedBorder.r; radiusY: dashedBorder.r }
            PathLine { x: 0; y: dashedBorder.r }
            PathArc { x: dashedBorder.r; y: 0; radiusX: dashedBorder.r; radiusY: dashedBorder.r }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.rightMargin: root.isMounted ? 18 : 16 + mountButton.width + 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Item {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52

                LoafShape {
                    anchors.fill: parent
                    shape: root.drive && root.drive.is_external ? "clover4" : "cookie9"
                    color: !root.isMounted ? theme.surfaceContainerHighest
                           : (root.almostFull ? theme.dangerContainer : theme.primaryContainer)
                    rotation: cardMouse.containsMouse ? 30 : 0
                    Behavior on rotation { enabled: theme.animate; SpringAnimation { spring: 2.5; damping: 0.28 } }
                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }
                }

                LoafIcon {
                    anchors.centerIn: parent
                    name: root.drive && root.drive.is_locked ? "lock-simple" : root.driveIcon()
                    size: 24
                    color: !root.isMounted ? theme.textMuted
                           : (root.almostFull ? theme.danger : theme.primaryContainerFg)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2

                Text {
                    text: (root.drive && root.drive.name) ? root.drive.name : ""
                    color: theme.textMain
                    font.pixelSize: theme.fs(15)
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.isMounted ? root.secondaryText() : ((root.drive && root.drive.device) ? root.drive.device : "")
                    color: theme.textMuted
                    font.pixelSize: theme.fs(12)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Text {
                visible: root.isMounted
                text: Math.round(root.usage * 100) + "%"
                color: root.almostFull ? theme.danger : theme.primary
                font.pixelSize: theme.fs(24)
                font.bold: true
                font.letterSpacing: -0.5
            }
        }

        UsageBar {
            visible: root.isMounted
            Layout.fillWidth: true
            value: root.usage
            barColor: root.almostFull ? theme.danger : theme.primary
        }

        RowLayout {
            visible: root.isMounted
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: root.formatBytes(root.usedBytes) + " used"
                color: theme.textMuted
                font.pixelSize: theme.fs(11)
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.formatBytes(Math.max(0, root.totalBytes - root.usedBytes)) + " free of " + root.formatBytes(root.totalBytes)
                color: theme.textMuted
                font.pixelSize: theme.fs(11)
                horizontalAlignment: Text.AlignRight
            }
        }

        Item {
            visible: !root.isMounted
            Layout.fillHeight: true
        }
    }

    // Sits above the content so the whole card is clickable; the Mount button
    // below is raised above this MouseArea so it keeps its own clicks.
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root.contextRequested(mouse.x + root.x, mouse.y + root.y);
            else
                root.activated();
        }
    }

    LoafButton {
        id: mountButton
        z: 2
        visible: !root.isMounted
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.drive && root.drive.provider === "mtp" ? qsTr("Browse") : qsTr("Mount")
        variant: "tonal"
        icon: "download-simple"
        onClicked: root.mountRequested()
    }
}
