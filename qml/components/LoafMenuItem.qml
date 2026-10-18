import QtQuick
import QtQuick.Layouts
import app.loaf

// LoafMenuItem -- a single Material 3 Expressive menu row.
// Self-contained: never references an external menu id.
Item {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 36
    implicitHeight: 36
    implicitWidth: 120

    transformOrigin: Item.Center

    property string icon: ""
    property string text: ""
    property string shortcut: ""
    property bool danger: false
    property bool checkable: false
    property bool checked: false
    property bool hasSubmenu: false
    property bool highlighted: false

    signal triggered()
    signal submenuHovered()

    // Default visible even if popIn() is never called.
    scale: 1.0
    opacity: 1.0

    transform: Translate { id: itemTranslate; y: 0 }

    readonly property bool hovered: itemMouse.containsMouse
    readonly property bool showTrailingShortcut: !root.hasSubmenu
                                                && !(root.checkable && root.checked)
                                                && root.shortcut.length > 0

    ParallelAnimation {
        id: popAnim
        property int delayMs: 0

        SequentialAnimation {
            PauseAnimation { duration: popAnim.delayMs }
            ParallelAnimation {
                NumberAnimation {
                    target: itemTranslate
                    property: "y"
                    from: -8
                    to: 0
                    duration: 160
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: root
                    property: "scale"
                    from: 0.96
                    to: 1.0
                    duration: 160
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: root
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    ParallelAnimation {
        id: popOutAnim
        property int delayMs: 0

        SequentialAnimation {
            PauseAnimation { duration: popOutAnim.delayMs }
            ParallelAnimation {
                NumberAnimation {
                    target: itemTranslate
                    property: "y"
                    from: 0
                    to: -4
                    duration: 90
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: root
                    property: "opacity"
                    from: 1.0
                    to: 0.0
                    duration: 90
                    easing.type: Easing.InCubic
                }
            }
        }
    }

    function popIn(delayMs) {
        popOutAnim.stop();
        popAnim.stop();
        itemTranslate.y = -8;
        root.scale = 0.96;
        root.opacity = 0.0;
        popAnim.delayMs = delayMs || 0;
        popAnim.start();
    }

    function popOut(delayMs) {
        popAnim.stop();
        popOutAnim.stop();
        itemTranslate.y = 0;
        root.scale = 1.0;
        root.opacity = 1.0;
        popOutAnim.delayMs = delayMs || 0;
        popOutAnim.start();
    }

    function playPop(delayMs) { popIn(delayMs); }
    function playOut(delayMs) { popOut(delayMs); }

    function reset() {
        popAnim.stop();
        popOutAnim.stop();
        itemTranslate.y = 0;
        root.scale = 1.0;
        root.opacity = 1.0;
    }

    Rectangle {
        id: itemBg
        anchors.fill: parent
        radius: theme.radiusFull
        color: (itemMouse.containsMouse || root.highlighted)
            ? (root.danger ? theme.dangerContainer : theme.menuItemHover)
            : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10
        opacity: root.enabled ? 1.0 : 0.45

        LoafIcon {
            visible: root.icon.length > 0
            name: root.icon
            size: 16
            color: root.danger ? theme.danger : theme.textMain
        }

        Text {
            text: root.text
            color: root.danger ? theme.danger : theme.textMain
            font.pixelSize: 13
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        LoafIcon {
            visible: root.hasSubmenu
            name: "caret-right"
            size: 12
            color: theme.outline
        }

        LoafIcon {
            visible: !root.hasSubmenu && root.checkable && root.checked
            name: "check"
            size: 14
            color: theme.primary
        }

        Text {
            visible: root.showTrailingShortcut
            text: root.shortcut
            color: theme.outline
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: itemMouse
        anchors.fill: parent
        hoverEnabled: root.enabled
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            if (root.enabled && root.hasSubmenu)
                root.submenuHovered();
        }

        onClicked: {
            if (!root.enabled)
                return;
            if (root.hasSubmenu)
                root.submenuHovered();
            else
                root.triggered();
        }
    }
}
