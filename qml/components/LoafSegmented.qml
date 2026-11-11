import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// LoafSegmented -- Material 3 segmented control.
// options: [{ value, label, icon, shortLabel }]
Item {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 36
    implicitHeight: 36
    implicitWidth: 160

    property var options: []
    property var value
    property string label: ""
    property bool iconOnly: false

    signal selected(var value)

    readonly property bool hasIcons: {
        var opts = root.options || [];
        if (opts.length === 0) return false;
        for (var i = 0; i < opts.length; i++) {
            if (!opts[i] || !opts[i].icon || String(opts[i].icon).length === 0) return false;
        }
        return true;
    }

    readonly property bool isCompact: (typeof settingsView !== "undefined" && settingsView.isCompact) || root.width < (root.options ? root.options.length * 68 : 150)
    readonly property bool effectiveIconOnly: iconOnly || (hasIcons && isCompact)

    transform: Translate { id: segTranslate; y: 0 }

    ParallelAnimation {
        id: segPopAnim
        property int delayMs: 0
        SequentialAnimation {
            PauseAnimation { duration: segPopAnim.delayMs }
            ParallelAnimation {
                NumberAnimation { target: segTranslate; property: "y"; from: -10; to: 0; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: root; property: "scale"; from: 0.90; to: 1.0; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                NumberAnimation { target: root; property: "opacity"; from: 0.0; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }

    function popIn(delayMs) {
        segPopAnim.stop();
        segTranslate.y = -10;
        root.scale = 0.90;
        root.opacity = 0.0;
        segPopAnim.delayMs = delayMs || 0;
        segPopAnim.start();
    }
    function playPop(delayMs) { popIn(delayMs); }
    function reset() {
        segPopAnim.stop();
        segTranslate.y = 0;
        root.scale = 1.0;
        root.opacity = 1.0;
    }

    readonly property int currentIndex: {
        var opts = root.options || [];
        for (var i = 0; i < opts.length; i++) {
            if (opts[i] && opts[i].value === root.value)
                return i;
        }
        return 0;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Text {
            text: root.label
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            visible: root.label.length > 0
        }

        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: root.height
            radius: theme.radiusFull
            color: theme.surfaceContainerHighest

            readonly property real segW: track.width / Math.max(1, (root.options ? root.options.length : 1))

            Rectangle {
                id: highlight
                height: track.height - 6
                y: 3
                radius: theme.radiusFull
                color: theme.secondaryContainer
                width: Math.max(0, track.segW - 6)
                x: 3 + root.currentIndex * track.segW

                Behavior on x { enabled: theme.animate; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on width { enabled: theme.animate; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: root.options

                    delegate: Item {
                        id: segItem
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property bool isCurrent: index === root.currentIndex
                        readonly property bool hasIcon: !!(modelData && modelData.icon && String(modelData.icon).length > 0)
                        readonly property bool isDisabled: !!(modelData && modelData.disabled)

                        opacity: isDisabled ? 0.4 : 1.0

                        // Animate the entire pill content wrapper with a spring on hover and press
                        Item {
                            id: contentWrapper
                            anchors.fill: parent
                            scale: segMouse.pressed ? 0.93 : (segMouse.containsMouse ? 1.05 : 1.0)

                            Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.5; damping: 0.3 } }

                            // Hover pill highlight
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: theme.radiusFull
                                color: theme.secondaryContainer
                                opacity: segItem.isCurrent ? 0.0 : (segMouse.pressed ? 0.35 : (segMouse.containsMouse ? 0.18 : 0.0))

                                Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 150 } }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: root.effectiveIconOnly ? 0 : 6

                                LoafIcon {
                                    visible: segItem.hasIcon
                                    name: segItem.hasIcon ? modelData.icon : ""
                                    size: root.effectiveIconOnly ? 16 : 14
                                    color: segItem.isCurrent ? theme.secondaryContainerFg : (segMouse.containsMouse ? theme.textMain : theme.textMuted)

                                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: 140 } }
                                }

                                Text {
                                    visible: !root.effectiveIconOnly && (modelData && modelData.label)
                                    text: {
                                        if (!modelData) return "";
                                        if (root.isCompact && modelData.shortLabel) return modelData.shortLabel;
                                        return modelData.label || "";
                                    }
                                    color: segItem.isCurrent ? theme.secondaryContainerFg : (segMouse.containsMouse ? theme.textMain : theme.textMuted)
                                    font.pixelSize: theme.fs(12)
                                    font.bold: segItem.isCurrent
                                    font.family: theme.fontFamily

                                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: 140 } }
                                }
                            }
                        }

                        MouseArea {
                            id: segMouse
                            anchors.fill: parent
                            enabled: !segItem.isDisabled
                            hoverEnabled: !segItem.isDisabled
                            cursorShape: segItem.isDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                            ToolTip.visible: segMouse.containsMouse && root.effectiveIconOnly && !!(modelData && modelData.label)
                            ToolTip.text: (modelData && modelData.label) ? modelData.label : ""
                            ToolTip.delay: 350

                            onClicked: {
                                if (!segItem.isDisabled) {
                                    root.value = modelData.value;
                                    root.selected(modelData.value);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
