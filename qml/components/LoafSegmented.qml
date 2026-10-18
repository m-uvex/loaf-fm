import QtQuick
import QtQuick.Layouts
import app.loaf

// LoafSegmented -- Material 3 segmented control.
// options: [{ value, label, icon }]
Item {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 36
    implicitHeight: 36
    implicitWidth: 160

    property var options: []
    property var value
    property string label: ""

    signal selected(var value)

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
            font.pixelSize: 12
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

                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: theme.durationFast } }
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

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            LoafIcon {
                                visible: !!(modelData && modelData.icon && String(modelData.icon).length > 0)
                                name: (modelData && modelData.icon) ? modelData.icon : ""
                                size: 14
                                color: segItem.isCurrent ? theme.secondaryContainerFg : theme.textMuted
                            }

                            Text {
                                text: (modelData && modelData.label) ? modelData.label : ""
                                color: segItem.isCurrent ? theme.secondaryContainerFg : theme.textMuted
                                font.pixelSize: 12
                                font.bold: segItem.isCurrent
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
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
