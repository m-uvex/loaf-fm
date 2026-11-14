import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    width: expanded ? 340 : pill.implicitWidth
    height: expanded ? list.implicitHeight + 24 : 44
    Accessible.role: Accessible.ProgressBar
    Accessible.name: ops.length > 0 ? ops[0].title : ""

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
        spacing: 10

        Item {
            width: 26; height: 26
            Canvas {
                id: ring
                anchors.fill: parent
                property real progress: panel.ops.length > 0 ? panel.ops[0].progress : 0
                onProgressChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.lineWidth = 3;
                    ctx.strokeStyle = theme.outlineAlpha(theme.outlineVariant);
                    ctx.beginPath();
                    ctx.arc(13, 13, 10, 0, Math.PI * 2);
                    ctx.stroke();
                    ctx.strokeStyle = theme.primary;
                    ctx.beginPath();
                    var p = progress < 0 ? 0.25 : progress;
                    ctx.arc(13, 13, 10, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p);
                    ctx.stroke();
                }
                RotationAnimator on rotation {
                    running: panel.visible && ring.progress < 0 && theme.animate
                    from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                }
            }
        }
        Text {
            text: panel.ops.length === 1 ? panel.ops[0].title : qsTr("%1 operations").arg(panel.ops.length)
            color: theme.textMain
            font.pixelSize: theme.fs(12)
            font.bold: true
            elide: Text.ElideRight
            Layout.maximumWidth: 240
        }
        Item { width: 4; height: 1 }
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
                required property var modelData
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: modelData.title
                        color: theme.textMain
                        font.pixelSize: theme.fs(12)
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    LoafButton {
                        icon: "x"
                        variant: "text"
                        Accessible.name: qsTr("Cancel")
                        onClicked: core.cancel_operation(modelData.id)
                    }
                }
                ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: modelData.progress < 0 ? 0 : modelData.progress
                    indeterminate: modelData.progress < 0
                }
                Text {
                    text: [modelData.detail, modelData.current].filter(function(s) { return s && s.length > 0; }).join("  ·  ")
                    color: theme.textMuted
                    font.pixelSize: theme.fs(10)
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }
    }
}
