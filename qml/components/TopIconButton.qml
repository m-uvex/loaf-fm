import QtQuick
import QtQuick.Controls
import app.loaf

Item {
    id: button

    property string iconName: ""
    property string systemIcon: ""
    property string accessibleName: ""
    property bool small: false

    signal clicked()

    implicitWidth: small ? 24 : 36
    implicitHeight: small ? 24 : 36
    opacity: enabled ? 1.0 : 0.4
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: button.clicked()

    function resolveSystemIcon(name) {
        var source = theme.iconSource === "adwaita" ? "adwaita"
                   : theme.iconSource === "custom" ? theme.customIconTheme
                   : "system";
        return core.resolve_icon(source, name);
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouseArea.containsMouse ? theme.hoverOverlay : "transparent"
        border.width: button.activeFocus ? 2 : 0
        border.color: theme.primary
    }

    LoafIcon {
        visible: theme.iconSource === "phosphor" || button.systemIcon.length === 0
        anchors.centerIn: parent
        name: button.iconName
        size: button.small ? 12 : 18
        color: theme.textMain
    }

    Image {
        visible: theme.iconSource !== "phosphor" && button.systemIcon.length > 0
        anchors.centerIn: parent
        source: visible ? button.resolveSystemIcon(button.systemIcon) : ""
        width: 18
        height: 18
        sourceSize.width: 36
        sourceSize.height: 36
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: if (button.accessibleName.length > 0 && typeof tooltip !== "undefined")
            tooltip.show(button, button.accessibleName)
        onExited: if (typeof tooltip !== "undefined") tooltip.hide(button)
        onClicked: button.clicked()
    }
}
