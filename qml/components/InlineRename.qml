import QtQuick
import QtQuick.Controls
import app.loaf

// In-place name editor (F2). Selects the name without its extension,
// commits on Enter or when focus leaves, cancels on Escape.
TextField {
    id: editor

    property string originalName: ""
    property bool isDir: false
    property bool horizontal: false
    property bool done: false
    property bool ready: false

    signal commit(string text)
    signal cancel()

    text: originalName
    color: theme.textMain
    font.pixelSize: theme.fs(horizontal ? 13 : 11)
    horizontalAlignment: horizontal ? TextInput.AlignLeft : TextInput.AlignHCenter
    selectByMouse: true
    padding: 3
    leftPadding: 6
    rightPadding: 6
    Accessible.name: qsTr("New name")

    background: Rectangle {
        radius: theme.radiusS
        color: theme.surfaceContainerHighest
        border.width: 2
        border.color: theme.primary
    }

    function finish(accept) {
        if (done)
            return;
        done = true;
        if (accept)
            editor.commit(editor.text);
        else
            editor.cancel();
    }

    Component.onCompleted: {
        forceActiveFocus();
        var dot = originalName.lastIndexOf(".");
        if (!isDir && dot > 0)
            select(0, dot);
        else
            selectAll();
        Qt.callLater(function() {
            if (!editor.activeFocus)
                editor.forceActiveFocus();
            editor.ready = true;
        });
    }

    Keys.onReturnPressed: function(event) { finish(true); event.accepted = true; }
    Keys.onEnterPressed: function(event) { finish(true); event.accepted = true; }
    Keys.onEscapePressed: function(event) { finish(false); event.accepted = true; }
    onActiveFocusChanged: if (ready && !activeFocus) finish(true)
}
