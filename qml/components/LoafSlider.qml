import QtQuick
import QtQuick.Layouts
import app.loaf

Item {
    id: root

    property real from: 0.0
    property real to: 1.0
    property real stepSize: 0.01
    property real value: 0.5
    property bool formatPercent: false
    property string unit: ""
    property string customValueText: ""
    property bool showValue: true
    property string accessibleName: ""

    signal moved(real value)

    Layout.fillWidth: false
    Layout.preferredHeight: 36
    Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 260
    Layout.maximumWidth: Layout.preferredWidth
    implicitHeight: 36
    implicitWidth: Layout.preferredWidth

    readonly property real range: Math.max(0.0001, root.to - root.from)
    readonly property real normalized: Math.max(0.0, Math.min(1.0, (root.value - root.from) / range))

    function setValueFromX(mouseX) {
        var clampedX = Math.max(0, Math.min(trackArea.width, mouseX));
        var norm = clampedX / Math.max(1, trackArea.width);
        var rawVal = root.from + norm * root.range;
        if (root.stepSize > 0) {
            rawVal = Math.round((rawVal - root.from) / root.stepSize) * root.stepSize + root.from;
        }
        var finalVal = Math.max(root.from, Math.min(root.to, rawVal));
        if (root.value !== finalVal) {
            root.value = finalVal;
            root.moved(finalVal);
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // Interactive Slider Track Area
        Item {
            id: trackArea
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            opacity: root.enabled ? 1.0 : 0.4

            readonly property real handleX: root.normalized * (trackArea.width - 6)

            // Inactive Track (Full background)
            Rectangle {
                id: bgTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 16
                radius: 8
                color: theme.surfaceContainerHighest
                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                // Active Track (Filled progress with M3E stop gap)
                Rectangle {
                    id: fillTrack
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, trackArea.handleX - 3)
                    radius: 8
                    color: theme.primary

                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                }
            }

            // Material 3 Expressive Thumb Handle
            Rectangle {
                id: thumb
                x: trackArea.handleX
                anchors.verticalCenter: parent.verticalCenter
                width: trackMouse.pressed ? 8 : (trackMouse.containsMouse ? 7 : 6)
                height: trackMouse.pressed ? 34 : (trackMouse.containsMouse ? 30 : 26)
                radius: 3
                color: theme.primary

                Behavior on width { enabled: theme.animate; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: theme.animate; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }

                // Subtle focus / active halo
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 12
                    height: parent.height + 6
                    radius: 6
                    color: theme.primary
                    opacity: trackMouse.pressed ? 0.22 : (trackMouse.containsMouse ? 0.12 : 0.0)

                    Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 120 } }
                }
            }

            MouseArea {
                id: trackMouse
                anchors.fill: parent
                enabled: root.enabled
                hoverEnabled: root.enabled
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                onPressed: function(mouse) {
                    root.setValueFromX(mouse.x);
                }

                onPositionChanged: function(mouse) {
                    if (pressed) {
                        root.setValueFromX(mouse.x);
                    }
                }
            }
        }

        // Live Value Pill Badge
        Rectangle {
            visible: root.showValue
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 26
            Layout.preferredWidth: Math.max(50, valText.implicitWidth + 14)
            Layout.minimumWidth: 50
            implicitWidth: Layout.preferredWidth
            radius: theme.radiusFull
            color: theme.surfaceContainerHighest

            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

            Text {
                id: valText
                anchors.centerIn: parent
                text: root.customValueText.length > 0 ? root.customValueText
                    : (root.formatPercent ? (Math.round(root.value * 100) + "%") : (root.value.toString() + root.unit))
                color: theme.textMain
                font.pixelSize: theme.fs(11)
                font.bold: true
                font.family: theme.fontFamily
            }
        }
    }

    Accessible.role: Accessible.Slider
    Accessible.name: root.accessibleName.length > 0 ? root.accessibleName : qsTr("Slider")
}
