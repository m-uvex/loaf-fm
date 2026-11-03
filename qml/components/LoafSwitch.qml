import QtQuick
import QtQuick.Layouts
import app.loaf

// LoafSwitch -- Material 3 switch row (label left, springy thumb right).
Item {
    id: root

    Layout.fillWidth: label.length > 0
    Layout.preferredHeight: 32
    implicitHeight: 32
    implicitWidth: label.length > 0 ? 180 : 46

    property bool checked: false
    property string label: ""

    signal toggled(bool checked)

    transform: Translate { id: switchTranslate; y: 0 }

    ParallelAnimation {
        id: switchPopAnim
        property int delayMs: 0
        SequentialAnimation {
            PauseAnimation { duration: switchPopAnim.delayMs }
            ParallelAnimation {
                NumberAnimation { target: switchTranslate; property: "y"; from: -10; to: 0; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: root; property: "scale"; from: 0.90; to: 1.0; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                NumberAnimation { target: root; property: "opacity"; from: 0.0; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }

    function popIn(delayMs) {
        switchPopAnim.stop();
        switchTranslate.y = -10;
        root.scale = 0.90;
        root.opacity = 0.0;
        switchPopAnim.delayMs = delayMs || 0;
        switchPopAnim.start();
    }
    function playPop(delayMs) { popIn(delayMs); }
    function reset() {
        switchPopAnim.stop();
        switchTranslate.y = 0;
        root.scale = 1.0;
        root.opacity = 1.0;
    }


    RowLayout {
        anchors.fill: parent
        spacing: root.label.length > 0 ? 10 : 0

        Text {
            text: root.label
            visible: root.label.length > 0
            color: theme.textMain
            font.pixelSize: theme.fs(13)
            Layout.fillWidth: root.label.length > 0
            elide: Text.ElideRight
        }

        Rectangle {
            id: track
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 46
            Layout.preferredHeight: 26
            // Soft hover halo, revealed when the pointer is over the switch
            // (a child drawn behind the track: anchors can't reach across the layout).
            Rectangle {
                z: -1
                anchors.fill: parent
                anchors.margins: -5
                radius: theme.radiusFull
                color: theme.primary
                opacity: switchMouse.containsMouse ? (root.checked ? 0.16 : 0.09) : 0.0
                visible: opacity > 0.01

                Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            radius: theme.radiusFull
            color: root.checked ? theme.primary : theme.surfaceContainerHighest
            border.width: root.checked ? 0 : 1
            border.color: switchMouse.containsMouse && !root.checked ? theme.primary : theme.outline

            Behavior on color { enabled: theme.animate; ColorAnimation { duration: 140 } }
            Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: 140 } }
            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: 140 } }

            Rectangle {
                id: thumb
                height: width
                radius: width / 2
                y: (track.height - height) / 2
                width: switchMouse.pressed ? 24 : (switchMouse.containsMouse ? 20 : 18)
                x: root.checked ? (track.width - width - 4) : 4
                color: root.checked ? theme.primaryFg : theme.outline

                Behavior on x { enabled: theme.animate; SpringAnimation { spring: 4; damping: 0.7 } }
                Behavior on width { enabled: theme.animate; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { enabled: theme.animate; ColorAnimation { duration: 140 } }
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
