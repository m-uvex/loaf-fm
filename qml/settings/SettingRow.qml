import QtQuick
import QtQuick.Layouts
import app.loaf

// SettingRow -- one labelled option inside a SettingCard.
// Label block on the left, control on the right, with a consistent
// control column so switches, radios, sliders and segmented controls
// all line up on the same right edge.
RowLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""

    readonly property bool isCompact: (typeof settingsView !== "undefined" && settingsView.isCompact) || root.width < 460

    default property alias control: controlSlot.data

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.topMargin: root.isCompact ? 9 : 12
    Layout.bottomMargin: root.isCompact ? 9 : 12
    spacing: 18

    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 12
        Layout.alignment: Qt.AlignVCenter

        Item {
            visible: root.icon.length > 0
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter

            Item {
                id: iconWrapper
                anchors.centerIn: parent
                width: parent.width
                height: parent.height

                LoafIcon {
                    id: rowIcon
                    anchors.centerIn: parent
                    name: root.icon
                    size: root.isCompact ? 18 : 20
                    color: theme.primary
                    scale: rowMouse.containsMouse ? 1.15 : 1.0

                    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 5; damping: 0.35 } }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 3
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.title
                color: theme.textMain
                font.pixelSize: theme.fs(13)
                font.bold: true
                font.weight: theme.fw(true)
                font.family: theme.fontFamily
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            // Subtitles are dropped on narrow layouts to keep rows calm.
            Text {
                visible: !root.isCompact && root.subtitle.length > 0
                text: root.subtitle
                color: theme.textMuted
                font.pixelSize: theme.fs(11)
                font.weight: theme.fontWeight
                font.family: theme.fontFamily
                lineHeight: 1.15
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }
    }

    // No maximumWidth: controls hug the card's trailing edge.
    RowLayout {
        id: controlSlot
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        spacing: 10
    }
}
