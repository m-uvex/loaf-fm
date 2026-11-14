import QtQuick
import QtQuick.Layouts
import app.loaf

// SettingDivider -- hairline between option rows, inset to the label column.
Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: 0
    Layout.bottomMargin: 0
    Layout.leftMargin: 36
    implicitHeight: 1
    color: theme.outlineAlpha(theme.outlineVariant)
    opacity: 0.18
}
