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
    Layout.preferredHeight: 76
    implicitHeight: 76
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

    opacity: root.isMounted ? 1.0 : 0.8
    Behavior on opacity { NumberAnimation { duration: 140 } }

    // ---- surfaces -----------------------------------------------------------

    Rectangle {
        id: card
        anchors.fill: parent
        radius: theme.radiusL
        color: theme.surfaceContainerLow

        Behavior on color { ColorAnimation { duration: theme.durationFast } }
    }

    Rectangle {
        id: hoverLayer
        anchors.fill: parent
        radius: theme.radiusL
        color: cardMouse.containsMouse ? theme.hoverOverlay : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }
    }

    // Dashed outline for unmounted drives.
    Shape {
        id: dashedBorder
        anchors.fill: parent
        visible: !root.isMounted

        ShapePath {
            strokeColor: theme.outlineVariant
            strokeWidth: 1
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]
            capStyle: ShapePath.FlatCap

            startX: 12
            startY: 0
            PathLine { x: dashedBorder.width - 12; y: 0 }
            PathArc { x: dashedBorder.width; y: 12; radiusX: 12; radiusY: 12 }
            PathLine { x: dashedBorder.width; y: dashedBorder.height - 12 }
            PathArc { x: dashedBorder.width - 12; y: dashedBorder.height; radiusX: 12; radiusY: 12 }
            PathLine { x: 12; y: dashedBorder.height }
            PathArc { x: 0; y: dashedBorder.height - 12; radiusX: 12; radiusY: 12 }
            PathLine { x: 0; y: 12 }
            PathArc { x: 12; y: 0; radiusX: 12; radiusY: 12 }
        }
    }

    // ---- mounted content ----------------------------------------------------

    RowLayout {
        visible: root.isMounted
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        LoafIcon {
            name: root.driveIcon()
            size: 28
            color: theme.primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            spacing: 2

            Text {
                text: (root.drive && root.drive.name) ? root.drive.name : ""
                color: theme.textMain
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.secondaryText()
                color: theme.textMuted
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 170
            Layout.maximumWidth: 210
            spacing: 5

            UsageBar {
                Layout.fillWidth: true
                value: (root.drive && root.drive.percent ? root.drive.percent : 0) / 100
            }

            Text {
                text: root.formatBytes(root.usedBytes) + " used of " + root.formatBytes(root.totalBytes)
                color: theme.textMuted
                font.pixelSize: 11
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }
    }

    // ---- unmounted content --------------------------------------------------

    RowLayout {
        visible: !root.isMounted
        anchors.fill: parent
        anchors.margins: 14
        anchors.rightMargin: 14 + mountButton.width + 12
        spacing: 12

        LoafIcon {
            name: root.driveIcon()
            size: 28
            color: theme.textMuted
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            spacing: 2

            Text {
                text: (root.drive && root.drive.name) ? root.drive.name : ""
                color: theme.textMain
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: (root.drive && root.drive.device) ? root.drive.device : ""
                color: theme.textMuted
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    // ---- interaction --------------------------------------------------------

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
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "Mount"
        variant: "tonal"
        icon: "download-simple"
        onClicked: root.mountRequested()
    }
}
