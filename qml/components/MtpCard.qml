import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import app.loaf

// MtpCard -- Android phone / MTP device card used by the PC dashboard.
// device: { name, uri, device, path, is_mounted }
Item {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 76
    implicitHeight: 76
    implicitWidth: 320

    property var device: ({})

    signal activated()
    signal contextRequested(real x, real y)
    signal connectRequested()
    signal disconnectRequested()

    readonly property bool isMounted: root.device && root.device.is_mounted === true
    readonly property bool busy: root.device && root.device.is_busy === true

    function secondaryText() {
        var d = root.device || {};
        if (root.isMounted) {
            var dev = d.device ? String(d.device) : "";
            return dev.length > 0 ? qsTr("Connected") + " \u2022 " + dev : qsTr("Connected");
        }
        return qsTr("Not connected");
    }

    opacity: root.isMounted ? 1.0 : 0.8
    Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 140 } }

    Rectangle {
        anchors.fill: parent
        radius: theme.radiusL
        color: theme.surfaceContainerLow
    }

    Rectangle {
        anchors.fill: parent
        radius: theme.radiusL
        color: cardMouse.containsMouse ? theme.hoverOverlay : "transparent"
        Behavior on color { enabled: theme.animate; ColorAnimation { duration: 100 } }
    }

    // Dashed outline while the phone is not mounted.
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

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        anchors.rightMargin: 14 + actionButton.width + 12
        spacing: 12

        LoafIcon {
            name: "device-mobile"
            size: 28
            color: root.isMounted ? theme.primary : theme.textMuted
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            spacing: 2

            Text {
                text: (root.device && root.device.name) ? root.device.name : ""
                color: theme.textMain
                font.pixelSize: theme.fs(14)
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.secondaryText()
                color: theme.textMuted
                font.pixelSize: theme.fs(12)
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    // Sits above the content so the whole card is clickable; the action button
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
        id: actionButton
        z: 2
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.isMounted ? qsTr("Disconnect") : qsTr("Connect")
        variant: root.isMounted ? "outlined" : "tonal"
        icon: root.isMounted ? "plug-slash" : "plug"
        enabled: !root.busy
        onClicked: {
            if (root.isMounted)
                root.disconnectRequested();
            else
                root.connectRequested();
        }
    }
}
