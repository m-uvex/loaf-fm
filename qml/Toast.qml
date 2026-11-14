import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// Snackbar for short messages; "undo" messages carry an Undo button.
Rectangle {
    id: toast

    property string kind: "info"
    property string message: ""

    function show(k, text) {
        kind = k;
        message = text;
        visible = true;
        opacity = 1.0;
        scale = 1.0;
        hideTimer.interval = k === "error" ? 8000 : 5000;
        hideTimer.restart();
    }

    function dismiss() {
        opacity = 0.0;
        scale = 0.85;
        closeTimer.restart();
    }

    visible: false
    opacity: 0.0
    scale: 0.85
    transformOrigin: Item.Center

    Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.8; damping: 0.35 } }

    Timer { id: closeTimer; interval: 180; onTriggered: toast.visible = false }

    width: Math.min(row.implicitWidth + 32, parent ? parent.width - 40 : 600)
    height: 46
    radius: theme.radiusFull
    color: kind === "error" ? theme.dangerContainer : theme.surfaceContainerHighest
    border.color: theme.outlineAlpha(theme.outlineVariant)
    border.width: 1
    Accessible.role: Accessible.AlertMessage
    Accessible.name: message

    Timer { id: hideTimer; onTriggered: toast.dismiss() }

    HoverHandler { onHoveredChanged: if (hovered) hideTimer.stop(); else hideTimer.restart() }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12
        LoafIcon {
            name: toast.kind === "error" ? "warning" : (toast.kind === "undo" ? "check-circle" : "info")
            size: 18
            color: toast.kind === "error" ? theme.danger : theme.primary
        }
        Text {
            text: toast.message
            color: toast.kind === "error" ? theme.danger : theme.textMain
            font.pixelSize: theme.fs(12)
            elide: Text.ElideRight
            Layout.maximumWidth: 520
        }
        LoafButton {
            visible: toast.kind === "undo" && core.can_undo
            text: qsTr("Undo")
            variant: "tonal"
            onClicked: {
                core.undo();
                toast.dismiss();
            }
        }
        LoafButton {
            icon: "x"
            variant: "text"
            Accessible.name: qsTr("Dismiss")
            onClicked: toast.dismiss()
        }
    }
}
