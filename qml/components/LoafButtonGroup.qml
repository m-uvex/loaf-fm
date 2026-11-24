import QtQuick
import app.loaf

// LoafButtonGroup -- Material 3 Expressive button group, small size.
// Buttons sit 2dp apart with fully round outer corners and tight 8dp
// inner corners (connected shape). Pressing a button morphs its inner
// corners to 4dp and widens it by 15%, squeezing its neighbours to make
// room (standard-group width interaction), on a stiff spring.
//
// buttons: [{ text, icon, variant }]  -- variant as in LoafButton
// signal clicked(int index)
Item {
    id: root

    property var buttons: []
    signal clicked(int index)

    readonly property real gap: 2
    readonly property real innerRadius: 8
    readonly property real pressedInnerRadius: 4
    readonly property real pressGrow: 0.15
    property int pressedIndex: -1

    implicitHeight: 36
    implicitWidth: {
        var w = 0;
        for (var i = 0; i < rep.count; i++)
            w += rep.itemAt(i) ? rep.itemAt(i).naturalWidth : 0;
        return w + gap * Math.max(0, rep.count - 1);
    }

    // Width of button i, adjusted while a button is pressed. The pressed one grows, adjacent ones give up the
    // space (split between them; an edge button takes it from its one neighbour).
    function slotWidth(i) {
        var n = rep.count;
        if (n === 0) return 0;
        // Each button keeps its natural width; spare room (or a shortfall)
        // is spread evenly so the row always fills its width exactly.
        var natural = 0;
        for (var k = 0; k < n; k++)
            natural += rep.itemAt(k) ? rep.itemAt(k).naturalWidth : 0;
        var own = rep.itemAt(i) ? rep.itemAt(i).naturalWidth : 0;
        var base = own + (width - gap * (n - 1) - natural) / n;
        var p = pressedIndex;
        if (p < 0) return base;
        var pressedNatural = rep.itemAt(p) ? rep.itemAt(p).naturalWidth : 0;
        var extra = pressedNatural * pressGrow;
        if (i === p) return base + extra;
        var neighbours = (p > 0 ? 1 : 0) + (p < n - 1 ? 1 : 0);
        if (Math.abs(i - p) === 1) return base - extra / neighbours;
        return base;
    }

    Row {
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            id: rep
            model: root.buttons

            Item {
                id: slot
                required property var modelData
                required property int index

                readonly property bool first: index === 0
                readonly property bool last: index === rep.count - 1
                readonly property bool pressed: mouse.pressed
                readonly property real outer: height / 2
                readonly property real inner: pressed ? root.pressedInnerRadius : root.innerRadius
                readonly property real naturalWidth: label.implicitWidth + (glyph.visible ? glyph.width + content.spacing : 0) + 28
                readonly property string variant: modelData.variant || "tonal"

                width: root.slotWidth(index)
                height: root.height

                Behavior on width {
                    enabled: theme.animate
                    SpringAnimation { spring: 9; damping: 0.9; epsilon: 0.25 }
                }

                readonly property color bgColor: variant === "filled" ? theme.primary
                    : variant === "danger" ? theme.dangerContainer : theme.secondaryContainer
                readonly property color fgColor: variant === "filled" ? theme.primaryFg
                    : variant === "danger" ? theme.danger : theme.secondaryContainerFg

                Rectangle {
                    anchors.fill: parent
                    color: mouse.containsMouse ? Qt.lighter(slot.bgColor, 1.12) : slot.bgColor
                    topLeftRadius: slot.first ? slot.outer : slot.inner
                    bottomLeftRadius: slot.first ? slot.outer : slot.inner
                    topRightRadius: slot.last ? slot.outer : slot.inner
                    bottomRightRadius: slot.last ? slot.outer : slot.inner

                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: 120 } }
                    Behavior on topLeftRadius { enabled: theme.animate; SpringAnimation { spring: 9; damping: 0.9 } }
                    Behavior on bottomLeftRadius { enabled: theme.animate; SpringAnimation { spring: 9; damping: 0.9 } }
                    Behavior on topRightRadius { enabled: theme.animate; SpringAnimation { spring: 9; damping: 0.9 } }
                    Behavior on bottomRightRadius { enabled: theme.animate; SpringAnimation { spring: 9; damping: 0.9 } }
                }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 7

                    LoafIcon {
                        id: glyph
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (slot.modelData.icon || "").length > 0
                        name: slot.modelData.icon || ""
                        size: 16
                        color: slot.fgColor
                    }

                    Text {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        // Natural width, capped to what the slot can show.
                        width: Math.max(0, Math.min(implicitWidth,
                            slot.width - 24 - (glyph.visible ? glyph.width + content.spacing : 0)))
                        text: slot.modelData.text || ""
                        elide: Text.ElideRight
                        color: slot.fgColor
                        font.pixelSize: theme.fs(13)
                        font.weight: Font.Medium
                        font.family: theme.fontFamily
                    }
                }

                Accessible.role: Accessible.Button
                Accessible.name: slot.modelData.text || ""
                activeFocusOnTab: true
                Keys.onSpacePressed: root.clicked(index)
                Keys.onReturnPressed: root.clicked(index)
                Keys.onLeftPressed: if (index > 0) rep.itemAt(index - 1).forceActiveFocus()
                Keys.onRightPressed: if (!last) rep.itemAt(index + 1).forceActiveFocus()

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    visible: slot.activeFocus
                    color: "transparent"
                    border.width: 2
                    border.color: theme.primary
                    topLeftRadius: slot.first ? slot.outer + 2 : slot.inner + 2
                    bottomLeftRadius: slot.first ? slot.outer + 2 : slot.inner + 2
                    topRightRadius: slot.last ? slot.outer + 2 : slot.inner + 2
                    bottomRightRadius: slot.last ? slot.outer + 2 : slot.inner + 2
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressedChanged: root.pressedIndex = pressed ? slot.index : (root.pressedIndex === slot.index ? -1 : root.pressedIndex)
                    onClicked: root.clicked(slot.index)
                }
            }
        }
    }
}
