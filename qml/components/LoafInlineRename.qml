import QtQuick
import app.loaf

Rectangle {
    id: root

    property string originalText: ""
    property int editorFontSize: 13
    property bool editorBold: false
    property color editorColor: theme.textMain

    signal accepted(string text)
    signal cancelled()

    visible: false
    z: 20
    width: 120
    height: 26
    radius: theme.radiusS
    color: theme.surfaceContainerHighest
    border.width: field.activeFocus ? 2 : 1
    border.color: field.activeFocus ? theme.primary : theme.borderSubtle

    function begin() {
        if (!root.visible)
            return
        field.text = root.originalText
        field.forceActiveFocus()
        var dot = root.originalText.lastIndexOf(".")
        if (dot > 0)
            field.select(0, dot)
        else
            field.selectAll()
    }

    function accept() {
        if (!root.visible)
            return
        root.accepted(field.text)
    }

    function cancel() {
        if (!root.visible)
            return
        root.cancelled()
    }

    onVisibleChanged: if (visible) Qt.callLater(begin)

    TextInput {
        id: field
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        verticalAlignment: TextInput.AlignVCenter
        color: root.editorColor
        font.pixelSize: root.editorFontSize
        font.bold: root.editorBold
        selectByMouse: true
        clip: true

        onAccepted: root.accept()
        onActiveFocusChanged: if (!activeFocus && root.visible) root.accept()

        Keys.onEscapePressed: {
            root.cancel()
            event.accepted = true
        }

        Keys.onTabPressed: {
            root.accept()
            event.accepted = true
        }
    }
}
