import QtQuick
import QtQuick.Controls
import app.loaf

// Checkbox drawn with the theme colors (the stock style ignores them).
CheckBox {
    id: control
    spacing: 8
    Accessible.name: text

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: (control.height - height) / 2
        // Expressive: corners soften while pressed, on the fast spring.
        radius: control.pressed ? 9 : 5
        Behavior on radius { enabled: theme.animate; SpringAnimation { spring: theme.springFast; damping: theme.springFastDamping } }
        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
        color: control.checked ? theme.primary : "transparent"
        border.color: control.checked ? theme.primary : theme.outlineAlpha(theme.outline)
        border.width: 2
        opacity: control.enabled ? 1.0 : 0.45
        // State layer
        Rectangle {
            anchors.centerIn: parent
            width: 34; height: 34; radius: 17
            z: -1
            color: theme.primary
            opacity: control.pressed ? 0.18 : (control.hovered ? 0.1 : 0)
            Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
        }
        LoafIcon {
            anchors.centerIn: parent
            visible: control.checked
            name: "check"
            size: 12
            color: theme.primaryFg
        }
    }

    contentItem: Text {
        text: control.text
        color: theme.textMain
        opacity: control.enabled ? 1.0 : 0.45
        font.pixelSize: theme.fs(12)
        leftPadding: control.indicator.width + control.spacing
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
