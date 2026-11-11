import QtQuick
import QtQuick.Layouts
import app.loaf

// SettingCard -- grouped, collapsible category card.
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool collapsible: root.title.length > 0
    property bool collapsed: false
    property alias headerActions: headerActionsSlot.data

    readonly property bool isCompact: (typeof settingsView !== "undefined" && settingsView.isCompact) || root.width < 460
    property real padding: isCompact ? 16 : 22

    default property alias content: innerCol.data

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    radius: theme.radiusL
    color: theme.surfaceContainer
    border.width: 1
    border.color: theme.borderSubtle
    implicitHeight: cardLayout.implicitHeight + 2 * padding
    implicitWidth: 200

    Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

    ColumnLayout {
        id: cardLayout
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 0

        Item {
            id: headerItem
            visible: root.title.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: headerRow.implicitHeight + (root.collapsible ? 8 : 0)
            Layout.bottomMargin: root.collapsed ? 0 : (root.isCompact ? 10 : 16)

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -8
                anchors.rightMargin: -8
                radius: theme.radiusM
                color: headerMouse.containsMouse && root.collapsible ? theme.hoverOverlay : "transparent"
                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                enabled: root.collapsible
                hoverEnabled: root.collapsible
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.collapsible)
                        root.collapsed = !root.collapsed;
                }
            }

            RowLayout {
                id: headerRow
                z: 1
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 0
                anchors.rightMargin: root.collapsible ? 8 : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                LoafIcon {
                    visible: root.icon.length > 0
                    name: root.icon
                    size: root.isCompact ? 18 : 20
                    color: theme.primary
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 3
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: root.title
                        color: theme.textMain
                        font.pixelSize: root.isCompact ? theme.fs(14) : theme.fs(15)
                        font.bold: true
                        font.letterSpacing: -0.2
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: !root.isCompact && root.subtitle.length > 0
                        text: root.subtitle
                        color: theme.textMuted
                        font.pixelSize: theme.fs(12)
                        lineHeight: 1.15
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    id: headerActionsSlot
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter
                }

                LoafIcon {
                    visible: root.collapsible
                    name: "caret-down"
                    size: 14
                    color: theme.textMuted
                    rotation: root.collapsed ? -90 : 0
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on rotation { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                }
            }
        }

        ColumnLayout {
            id: innerCol
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 0
            visible: !root.collapsed

            Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
    }
}
