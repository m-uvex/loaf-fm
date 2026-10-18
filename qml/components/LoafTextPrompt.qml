import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// LoafTextPrompt -- single-line text input dialog.
LoafDialog {
    id: prompt

    property string label: ""
    property string initialText: ""
    property string placeholder: ""
    property string confirmText: "Save"
    property bool selectBasename: false

    signal accepted(string text)
    signal cancelled()

    function accept() {
        prompt.accepted(field.text);
        prompt.close();
    }

    function cancel() {
        prompt.cancelled();
        prompt.close();
    }

    onOpened: {
        field.text = prompt.initialText;
        field.forceActiveFocus();
        if (prompt.selectBasename) {
            var slash = prompt.initialText.lastIndexOf("/");
            if (slash >= 0)
                field.select(slash + 1, field.text.length);
            else
                field.selectAll();
        } else {
            field.selectAll();
        }
    }

    Text {
        visible: prompt.label.length > 0
        text: prompt.label
        color: theme.textMuted
        font.pixelSize: 12
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    TextField {
        id: field
        Layout.fillWidth: true
        placeholderText: prompt.placeholder
        color: theme.textMain
        placeholderTextColor: theme.textMuted
        font.pixelSize: 14
        selectByMouse: true
        leftPadding: 12
        rightPadding: 12
        topPadding: 9
        bottomPadding: 9

        background: Rectangle {
            radius: theme.radiusS
            color: theme.surfaceContainerHighest
            border.width: field.activeFocus ? 2 : 1
            border.color: field.activeFocus ? theme.primary : theme.borderSubtle

            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        onAccepted: prompt.accept()

        Keys.onEscapePressed: {
            prompt.cancel();
            event.accepted = true;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        LoafButton {
            text: "Cancel"
            variant: "text"
            onClicked: prompt.cancel()
        }

        LoafButton {
            text: prompt.confirmText
            variant: "filled"
            onClicked: prompt.accept()
        }
    }
}
