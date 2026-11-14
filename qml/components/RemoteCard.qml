import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import app.loaf

Item {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 128
    implicitHeight: 128
    implicitWidth: 320

    property var remote: ({})

    signal contextRequested(real x, real y)
    signal activated()
    signal actionRequested()

    readonly property bool connected: root.remote && root.remote.connected === true
    readonly property bool bookmark: root.remote && root.remote.kind === "bookmark"
    readonly property bool active: root.connected || root.bookmark

    function remoteIcon() {
        var r = root.remote || {};
        if (r.icon && String(r.icon).length > 0)
            return r.icon;
        if (r.protocol === "webdav" || r.kind === "bookmark")
            return "globe";
        return "network";
    }

    function protocolLabel() {
        var r = root.remote || {};
        if (r.kind === "bookmark")
            return qsTr("Remote URL");
        if (r.protocol === "webdav")
            return "WebDAV";
        return "SMB";
    }

    function secondaryText() {
        var r = root.remote || {};
        if (r.kind === "bookmark")
            return r.path ? String(r.path) : "";
        var server = r.server ? String(r.server) : "";
        if (r.port && r.port > 0)
            server += ":" + r.port;
        var share = r.share ? String(r.share) : "";
        if (share.length > 0 && share.charAt(0) !== "/")
            share = "/" + share;
        if (server.length > 0 && share.length > 0)
            return server + share;
        return server.length > 0 ? server : share;
    }

    function statusText() {
        if (root.bookmark)
            return qsTr("Link");
        return root.connected ? qsTr("Connected") : qsTr("Saved");
    }

    opacity: root.active ? 1.0 : 0.85
    Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 140 } }

    scale: cardMouse.pressed ? 0.98 : 1.0
    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.32 } }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: theme.radiusXl
        color: root.active ? theme.surfaceContainer : theme.surfaceContainerLow

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
    }

    Rectangle {
        id: hoverLayer
        anchors.fill: parent
        radius: theme.radiusXl
        color: cardMouse.containsMouse ? theme.hoverOverlay : "transparent"

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: 100 } }
    }

    Shape {
        id: dashedBorder
        anchors.fill: parent
        visible: !root.active
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
        anchors.rightMargin: 16 + actionButton.width + 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Item {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52

                LoafShape {
                    anchors.fill: parent
                    shape: root.bookmark ? "flower" : "cookie9"
                    color: root.active ? theme.primaryContainer : theme.surfaceContainerHighest
                    rotation: cardMouse.containsMouse ? 30 : 0
                    Behavior on rotation { enabled: theme.animate; SpringAnimation { spring: 2.5; damping: 0.28 } }
                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }
                }

                LoafIcon {
                    anchors.centerIn: parent
                    name: root.remoteIcon()
                    size: 24
                    color: root.active ? theme.primaryContainerFg : theme.textMuted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: (root.remote && root.remote.name) ? root.remote.name
                              : ((root.remote && root.remote.server) ? root.remote.server : qsTr("Remote"))
                        color: theme.textMain
                        font.pixelSize: theme.fs(15)
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        radius: theme.radiusFull
                        color: root.connected ? theme.primaryContainer
                               : (root.bookmark ? theme.secondaryContainer : theme.surfaceContainerHighest)
                        implicitWidth: statusLabel.implicitWidth + 12
                        implicitHeight: 18

                        Text {
                            id: statusLabel
                            anchors.centerIn: parent
                            text: root.statusText()
                            color: root.connected ? theme.primaryContainerFg
                                   : (root.bookmark ? theme.secondaryContainerFg : theme.textMuted)
                            font.pixelSize: theme.fs(9)
                            font.bold: true
                        }
                    }
                }

                Text {
                    text: root.secondaryText()
                    visible: text.length > 0
                    color: theme.textMuted
                    font.pixelSize: theme.fs(12)
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }

        Text {
            text: root.protocolLabel()
            color: theme.textMuted
            font.pixelSize: theme.fs(11)
            font.bold: true
        }
    }

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
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.active ? qsTr("Open") : qsTr("Connect")
        variant: root.active ? "tonal" : "filled"
        icon: root.active ? "folder-open" : "plug"
        onClicked: root.actionRequested()
    }
}
