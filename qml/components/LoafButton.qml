import QtQuick
import QtQuick.Layouts
import app.loaf

// LoafButton -- Material 3 Expressive button.
// variant: "text" | "filled" | "tonal" | "outlined" | "elevated" | "danger"
Item {
    id: root

    property string text: ""
    property string icon: ""
    property string variant: "text"
    property bool checked: false

    signal clicked()

    readonly property bool iconOnly: text.length === 0

    implicitHeight: 34
    implicitWidth: iconOnly ? 34 : (contentRow.implicitWidth + 28)
    Layout.preferredHeight: 34
    Layout.preferredWidth: implicitWidth

    opacity: enabled ? 1.0 : 0.45
    transformOrigin: Item.Center
    scale: mouse.pressed ? 0.95 : 1.0

    Behavior on scale { SpringAnimation { spring: 4.0; damping: 0.3 } }

    readonly property color bgColor: {
        switch (variant) {
        case "filled": return theme.primary;
        case "tonal": return theme.secondaryContainer;
        case "elevated": return theme.surfaceContainerLow;
        case "danger": return theme.dangerContainer;
        case "outlined": return "transparent";
        default: return "transparent";
        }
    }

    readonly property color fgColor: {
        switch (variant) {
        case "filled": return theme.primaryFg;
        case "tonal": return theme.secondaryContainerFg;
        case "danger": return theme.danger;
        default: return theme.textMain;
        }
    }

    readonly property color hoverBg: {
        switch (variant) {
        case "filled": return Qt.lighter(theme.primary, 1.12);
        case "tonal": return Qt.lighter(theme.secondaryContainer, 1.12);
        case "danger": return Qt.lighter(theme.dangerContainer, 1.12);
        case "elevated": return theme.hoverOverlay;
        default: return theme.hoverOverlay;
        }
    }

    // Soft layered elevation underlay (elevated variant).
    Rectangle {
        visible: root.variant === "elevated"
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        radius: theme.radiusFull
        color: theme.outlineVariant
        opacity: 0.55
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: theme.radiusFull
        color: mouse.containsMouse ? root.hoverBg : root.bgColor
        border.width: root.variant === "outlined" ? 1 : 0
        border.color: theme.outline

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        LoafIcon {
            visible: root.icon.length > 0
            name: root.icon
            size: 16
            color: root.fgColor
        }

        Text {
            visible: root.text.length > 0
            text: root.text
            color: root.fgColor
            font.pixelSize: 13
            font.bold: root.variant === "filled" || root.variant === "tonal"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
