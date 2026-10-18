import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// LoafDialog -- centered modal Material 3 dialog.
// Note: the `closed()` signal is inherited from Popup (Popup already declares
// opened()/closed()), so it is not re-declared here.
Popup {
    id: dialog

    property string title: ""
    property real dialogWidth: 380

    default property alias content: body.data

    width: dialogWidth
    padding: 24
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay

    transformOrigin: Item.Center
    scale: 0.9
    opacity: 0.0

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "scale"; from: 1.0; to: 0.9; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 120; easing.type: Easing.InCubic }
        }
    }

    Overlay.modal: Rectangle {
        color: "#00000099"
    }

    background: Rectangle {
        radius: theme.radiusXl
        color: theme.surfaceContainerHigh
        border.color: theme.borderSubtle
        border.width: 1

        Behavior on color { ColorAnimation { duration: theme.durationNormal } }
        Behavior on border.color { ColorAnimation { duration: theme.durationNormal } }
    }

    contentItem: ColumnLayout {
        id: dialogColumn
        spacing: 14
        width: dialog.width - 2 * dialog.padding

        Text {
            id: titleText
            visible: dialog.title.length > 0
            text: dialog.title
            color: theme.textMain
            font.pixelSize: 18
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 12
        }
    }
}
