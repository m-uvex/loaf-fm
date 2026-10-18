import QtQuick
import QtQuick.Layouts
import app.loaf

// LoafCard -- Material 3 surface card with an optional outline and hover state.
Rectangle {
    id: root

    property color cardColor: theme.surfaceContainerLow
    property bool outline: true
    property bool interactive: false
    property real padding: 14

    default property alias content: inner.data

    radius: theme.radiusL
    color: cardColor
    border.width: outline ? 1 : 0
    border.color: theme.borderSubtle

    implicitHeight: inner.implicitHeight + 2 * padding
    implicitWidth: inner.implicitWidth + 2 * padding

    Behavior on color { ColorAnimation { duration: theme.durationNormal } }

    Rectangle {
        id: hoverLayer
        anchors.fill: parent
        radius: root.radius
        color: cardMouse.containsMouse ? theme.menuItemHover : "transparent"
        visible: root.interactive

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 8
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        visible: root.interactive
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: Qt.PointingHandCursor
    }
}
