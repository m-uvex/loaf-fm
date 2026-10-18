import QtQuick
import QtQuick.Layouts
import app.loaf

// SectionHeader -- title / subtitle block with an optional icon and a
// right-aligned controls slot (declared children are laid out there).
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""

    default property alias controls: rightRow.data

    Layout.fillWidth: true
    Layout.preferredHeight: 42
    implicitHeight: 42
    implicitWidth: 200

    RowLayout {
        anchors.fill: parent
        spacing: 10

        LoafIcon {
            visible: root.icon.length > 0
            name: root.icon
            size: 18
            color: theme.primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: root.title
                color: theme.textMain
                font.pixelSize: 20
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: theme.textMuted
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        RowLayout {
            id: rightRow
            spacing: 8
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
