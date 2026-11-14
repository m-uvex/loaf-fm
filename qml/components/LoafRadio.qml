import QtQuick
import QtQuick.Controls
import app.loaf

RadioButton {
    id: control
    spacing: 8
    hoverEnabled: true
    Accessible.name: text

    indicator: Item {
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: (control.height - height) / 2

        // Hover halo, mirroring the switch and palette cards.
        Rectangle {
            anchors.centerIn: parent
            width: 32
            height: 32
            radius: width / 2
            color: theme.primary
            opacity: control.hovered ? 0.12 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            id: ring
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: 9
            color: "transparent"
            border.color: control.checked ? theme.primary
                : (control.hovered ? theme.primary : theme.outlineAlpha(theme.outline))
            border.width: 2
            scale: control.hovered ? 1.08 : 1.0

            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: 150 } }
            Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4; damping: 0.4 } }

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: theme.primary
                visible: control.checked

            }
        }
    }

    contentItem: Text {
        text: control.text
        color: control.hovered ? theme.primary : theme.textMain
        font.pixelSize: theme.fs(12)
        leftPadding: control.indicator.width + control.spacing
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: 150 } }
    }
}
