import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf
import ".."

// LoafSelect -- Material 3 Expressive dropdown field built on LoafMenu.
// options: [{ value, label, iconUrl? }]
Item {
    id: root

    property var options: []
    property string value: ""
    property string placeholder: qsTr("Choose…")
    property string accessibleName: ""

    signal selected(string value)

    readonly property var optionList: Array.isArray(root.options) ? root.options : []
    readonly property var current: {
        var list = optionList;
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].value === root.value)
                return list[i];
        }
        return null;
    }
    readonly property bool open: menu.visible

    implicitWidth: 240
    implicitHeight: 40
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    Accessible.role: Accessible.ComboBox
    Accessible.name: accessibleName.length > 0 ? accessibleName : (current ? current.label : placeholder)

    opacity: enabled ? 1.0 : 0.45
    scale: mouse.pressed ? 0.97 : 1.0
    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.0; damping: 0.3 } }

    function openMenu() {
        var p = root.mapToItem(null, 0, root.height + 6);
        menu.menuMinWidth = root.width;
        menu.model = optionList.map(function (o) {
            return {
                "text": o.label || "",
                "iconUrl": o.iconUrl || "",
                "checkable": true,
                "checked": o.value === root.value,
                "action": function () { root.selected(o.value); }
            };
        });
        menu.openAt(p.x, p.y);
    }

    Rectangle {
        anchors.fill: parent
        radius: theme.radiusFull
        color: mouse.containsMouse || root.open ? Qt.lighter(theme.surfaceContainerHigh, 1.08) : theme.surfaceContainerHigh
        border.width: root.open ? 2 : 1
        border.color: root.open ? theme.primary : theme.outlineAlpha(theme.outlineVariant)

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
        Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        spacing: 10

        Image {
            visible: root.current !== null && (root.current.iconUrl || "").length > 0
            source: root.current ? (root.current.iconUrl || "") : ""
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            sourceSize.width: 36
            sourceSize.height: 36
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            text: root.current ? root.current.label : root.placeholder
            color: root.current ? theme.textMain : theme.textMuted
            font.pixelSize: theme.fs(13)
            font.bold: root.current !== null
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        LoafIcon {
            name: "caret-down"
            size: 14
            color: root.open ? theme.primary : theme.textMuted
            rotation: root.open ? 180 : 0
            Behavior on rotation { enabled: theme.animate; SpringAnimation { spring: 4.0; damping: 0.35 } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // A press outside closes the menu first; don't reopen it at once.
            if (root.open)
                menu.close();
            else if (Date.now() - menu.lastClosedTime > 250)
                root.openMenu();
        }
    }

    LoafMenu {
        id: menu
        parent: Overlay.overlay
        model: []
    }
}
