import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Basic
import app.loaf

// Bottom-right progress pill for running file operations; click to expand
// the list, each entry can be cancelled.
Item {
    id: panel

    readonly property var ops: {
        try {
            return JSON.parse(core.operations_json || "[]");
        } catch (e) {
            return [];
        }
    }
    property bool expanded: false
    // Don't flash the pill for operations that finish in a blink.
    property bool shown: false
    onOpsChanged: {
        if (ops.length > 0)
            showDelay.start();
        else {
            showDelay.stop();
            shown = false;
            expanded = false;
        }
    }
    Timer { id: showDelay; interval: 350; onTriggered: panel.shown = panel.ops.length > 0 }

    visible: shown
    width: expanded ? 340 : pill.implicitWidth + 32
    height: expanded ? list.implicitHeight + 24 : 44
    Accessible.role: Accessible.ProgressBar
    Accessible.name: ops.length > 0 ? theme.resolveRustMessage(ops[0].title) : ""

    Rectangle {
        anchors.fill: parent
        radius: panel.expanded ? theme.radiusL : theme.radiusFull
        color: theme.surfaceContainerHighest
        border.color: theme.outlineAlpha(theme.outlineVariant)
        border.width: 1
    }

    // Collapsed pill.
    RowLayout {
        id: pill
        visible: !panel.expanded
        anchors.centerIn: parent
        spacing: 12

        Item {
            Layout.preferredWidth: 26; Layout.preferredHeight: 26
            Canvas {
                id: ring
                anchors.fill: parent
                property real progress: panel.ops.length > 0 ? panel.ops[0].progress : 0
                property color trackColor: theme.outlineAlpha(theme.outlineVariant)
                property color progressColor: theme.primary
                onProgressChanged: requestPaint()
                onTrackColorChanged: requestPaint()
                onProgressColorChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.lineWidth = 3;
                    ctx.strokeStyle = trackColor;
                    ctx.beginPath();
                    ctx.arc(12, 12, 9, 0, Math.PI * 2);
                    ctx.stroke();
                    ctx.strokeStyle = progressColor;
                    ctx.beginPath();
                    var p = progress < 0 ? 0.25 : progress;
                    ctx.arc(12, 12, 9, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p);
                    ctx.stroke();
                }
                RotationAnimator on rotation {
                    running: panel.visible && ring.progress < 0 && theme.animate
                    from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                }
            }
        }
        Text {
            text: panel.ops.length === 1 ? theme.resolveRustMessage(panel.ops[0].title) : qsTr("%n operation(s)", "", panel.ops.length)
            color: theme.textMain
            font.family: theme.fontFamily
            font.pixelSize: theme.fs(12)
            elide: Text.ElideRight
            Layout.maximumWidth: 240
        }
        Text {
            text: panel.ops.length === 1 ? panel.ops[0].speed || "" : ""
            visible: text.length > 0
            color: theme.textMuted
            font.family: theme.fontFamily
            font.pixelSize: theme.fs(11)
        }
        LoafIcon {
            name: "caret-up"
            size: 14
            color: theme.textMuted
        }
        Item { Layout.preferredWidth: 4; Layout.preferredHeight: 1 }
    }

    MouseArea {
        anchors.fill: parent
        visible: !panel.expanded
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.expanded = true
    }

    ColumnLayout {
        id: list
        visible: panel.expanded
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text { text: qsTr("Operations"); color: theme.textMain; font.pixelSize: theme.fs(13); font.bold: true; Layout.fillWidth: true }
            LoafButton { icon: "caret-down"; variant: "text"; onClicked: panel.expanded = false; Accessible.name: qsTr("Collapse") }
        }

        Repeater {
            model: panel.ops
            delegate: ColumnLayout {
                id: opItem
                required property var modelData
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: theme.resolveRustMessage(opItem.modelData.title)
                        color: theme.textMain
                        font.pixelSize: theme.fs(12)
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    LoafButton {
                        icon: "x"
                        variant: "text"
                        Accessible.name: qsTr("Cancel")
                        onClicked: core.cancel_operation(opItem.modelData.id)
                    }
                }
                Basic.ProgressBar {
                    Layout.fillWidth: true
                    palette.dark: theme.primary
                    palette.midlight: theme.outlineVariant
                    from: 0
                    to: 1
                    value: opItem.modelData.progress < 0 ? 0 : opItem.modelData.progress
                    indeterminate: opItem.modelData.progress < 0
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        text: theme.resolveRustMessage(modelData.detail)
                        visible: text.length > 0
                        color: theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: theme.fs(10)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: [modelData.speed, modelData.eta].filter(function(s) { return s && s.length > 0; }).join("  ·  ")
                        visible: text.length > 0
                        color: theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: theme.fs(10)
                        Layout.alignment: Qt.AlignRight
                    }
                }
                Text {
                    text: theme.resolveRustMessage(modelData.current)
                    visible: text.length > 0
                    color: theme.textMuted
                    font.family: theme.fontFamily
                    font.pixelSize: theme.fs(10)
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }
    }
}
