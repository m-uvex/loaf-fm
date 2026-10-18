import QtQuick
import QtQuick.Layouts
import app.loaf

// LoafSwitch -- Material 3 switch row (label left, springy thumb right).
Item {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 32
    implicitHeight: 32
    implicitWidth: 180

    property bool checked: false
    property string label: ""

    signal toggled(bool checked)

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Text {
            text: root.label
            color: theme.textMain
            font.pixelSize: 13
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Rectangle {
            id: track
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 46
            Layout.preferredHeight: 26
            radius: theme.radiusFull
            color: root.checked ? theme.primary : theme.surfaceContainerHighest
            border.width: root.checked ? 0 : 1
            border.color: theme.outline

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.width { NumberAnimation { duration: 140 } }

            Rectangle {
                id: thumb
                height: width
                radius: width / 2
                y: (track.height - height) / 2
                width: switchMouse.pressed ? 24 : 18
                x: root.checked ? (track.width - width - 4) : 4
                color: root.checked ? theme.primaryFg : theme.outline

                Behavior on x { SpringAnimation { spring: 4; damping: 0.7 } }
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            MouseArea {
                id: switchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.checked = !root.checked;
                    root.toggled(root.checked);
                }
            }
        }
    }
}
