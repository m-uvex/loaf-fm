import QtQuick
import QtQuick.Controls
import app.loaf
TextField {
    id: field
    color: theme.textMain
    placeholderTextColor: theme.textMuted
    selectionColor: theme.primary
    selectedTextColor: theme.primaryFg
    font.pixelSize: theme.fs(13)
    selectByMouse: true
    leftPadding: 12
    rightPadding: 12
    topPadding: 8
    bottomPadding: 8
    Accessible.name: placeholderText

    background: Rectangle {
        radius: theme.radiusS
        color: theme.surfaceContainerHighest
        border.width: field.activeFocus ? 2 : 1
        border.color: field.activeFocus ? theme.primary : theme.outlineAlpha(theme.borderSubtle)
    }
}
