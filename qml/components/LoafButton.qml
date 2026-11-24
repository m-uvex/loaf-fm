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
    property string accessibleName: ""
    // Hover label shown after the shared tooltip delay; empty keeps it silent.
    property string tooltipText: ""
    Accessible.name: accessibleName.length > 0 ? accessibleName : (text.length > 0 ? text : icon)

    // Hover signals for callers that want their own hover handling (e.g.
    // tooltip wiring from outside this file).
    signal hoverEntered()
    signal hoverExited()

    signal clicked()

    readonly property bool iconOnly: text.length === 0
    readonly property alias containsMouse: mouse.containsMouse
    readonly property alias hovered: mouse.containsMouse

    implicitHeight: 34
    implicitWidth: iconOnly ? 34 : (contentRow.implicitWidth + 28)
    Layout.preferredHeight: 34
    Layout.preferredWidth: implicitWidth

    opacity: enabled ? 1.0 : 0.45

    // M3 Expressive shape morph: round at rest, square when toggled on,
    // and corners tighten while pressed (small button: 8dp pressed, 12dp
    // selected), on the fast spatial spring.
    readonly property real cornerRadius: mouse.pressed ? 8 : (checked ? 12 : height / 2)

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
        radius: root.cornerRadius
        Behavior on radius { enabled: theme.animate; SpringAnimation { spring: theme.springFast; damping: theme.springFastDamping } }
        color: theme.outlineVariant
        opacity: 0.55
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.cornerRadius
        color: mouse.containsMouse ? root.hoverBg : root.bgColor
        border.width: root.variant === "outlined" ? 1 : 0
        border.color: theme.outlineAlpha(theme.outline)

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: 120 } }
        Behavior on radius { enabled: theme.animate; SpringAnimation { spring: theme.springFast; damping: theme.springFastDamping } }
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
            font.pixelSize: theme.fs(13)
            font.bold: root.variant === "filled" || root.variant === "tonal"
            font.weight: theme.fw(root.variant === "filled" || root.variant === "tonal")
            font.family: theme.fontFamily
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            root.hoverEntered();
            if (root.tooltipText.length > 0 && typeof tooltip !== "undefined")
                tooltip.show(root, root.tooltipText)
        }
        onExited: {
            root.hoverExited();
            if (typeof tooltip !== "undefined")
                tooltip.hide(root)
        }
        onClicked: root.clicked()
    }
}
