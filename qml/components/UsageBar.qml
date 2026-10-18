import QtQuick
import QtQuick.Layouts
import app.loaf

// UsageBar -- rounded storage usage bar (value clamped to 0..1).
Item {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 6
    implicitHeight: 6
    implicitWidth: 120

    property real value: 0
    property color barColor: theme.primary
    property color trackColor: theme.track

    readonly property real clampedValue: Math.max(0, Math.min(1, isNaN(root.value) ? 0 : root.value))

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor

        Behavior on color { ColorAnimation { duration: theme.durationNormal } }
    }

    Rectangle {
        height: parent.height
        radius: height / 2
        color: root.barColor
        width: parent.width * root.clampedValue

        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme.durationNormal } }
    }
}
