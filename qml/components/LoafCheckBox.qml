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
        radius: 5
        color: control.checked ? theme.primary : "transparent"
        border.color: control.checked ? theme.primary : theme.outlineAlpha(theme.outline)
        border.width: 2
        opacity: control.enabled ? 1.0 : 0.45
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
