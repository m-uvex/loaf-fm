import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// LoafSegmented -- Material 3 Expressive connected button group
// (replaces the segmented button). Segments sit 2dp apart with fully round
// outer corners and 8dp inner corners; pressing tightens the inner corners
// to 4dp, and the selected segment morphs fully round in the accent colour.
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
    // Icon-only is opt-in now; segments shed icons and switch to short
    // labels on their own when narrow.
    readonly property bool effectiveIconOnly: iconOnly

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

        Item {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: root.height

            readonly property int count: Math.max(1, (root.options ? root.options.length : 1))
            readonly property real gap: 2
            // Pressing a segment widens it 15% and its neighbours give up
            // the room (M3 Expressive button group width interaction).
            property int pressedIndex: -1
            function segWidth(i) {
                var base = (width - gap * (count - 1)) / count;
                var p = pressedIndex;
                if (p < 0) return base;
                var extra = base * 0.15;
                if (i === p) return base + extra;
                var neighbours = (p > 0 ? 1 : 0) + (p < count - 1 ? 1 : 0);
                return Math.abs(i - p) === 1 ? base - extra / neighbours : base;
            }

            Row {
                anchors.fill: parent
                spacing: track.gap

                Repeater {
                    model: root.options

                    delegate: Item {
                        id: segItem
                        width: track.segWidth(index)
                        height: track.height
                        Behavior on width { enabled: theme.animate; SpringAnimation { spring: theme.springFast; damping: theme.springFastDamping } }

                        readonly property bool isCurrent: index === root.currentIndex
                        readonly property bool hasIcon: !!(modelData && modelData.icon && String(modelData.icon).length > 0)
                        readonly property bool isDisabled: !!(modelData && modelData.disabled)
                        readonly property bool first: index === 0
                        readonly property bool last: index === track.count - 1
                        readonly property real outer: height / 2
                        readonly property real inner: isCurrent ? height / 2 : (segMouse.pressed ? 4 : 8)
                        readonly property color fg: isCurrent ? theme.primaryFg : theme.textMain

                        // Fit order when space runs out: full label with icon,
                        // full label alone, short label, then elide.
                        readonly property string fullText: modelData && modelData.label ? modelData.label : ""
                        readonly property string shortText: modelData && modelData.shortLabel ? modelData.shortLabel : fullText
                        readonly property real avail: (track.width - track.gap * (track.count - 1)) / track.count - 16
                        readonly property bool fullFits: fullMetrics.advanceWidth <= avail
                        readonly property string shownText: fullFits ? fullText : shortText
                        readonly property bool showIcon: hasIcon && (root.effectiveIconOnly
                            || (fullFits ? fullMetrics.advanceWidth : shortMetrics.advanceWidth) + 20 <= avail)

                        TextMetrics { id: fullMetrics; text: segItem.fullText; font.pixelSize: theme.fs(12); font.weight: Font.DemiBold; font.family: theme.fontFamily }
                        TextMetrics { id: shortMetrics; text: segItem.shortText; font.pixelSize: theme.fs(12); font.weight: Font.DemiBold; font.family: theme.fontFamily }

                        opacity: isDisabled ? 0.4 : 1.0

                        SideRoundedRect {
                            anchors.fill: parent
                            color: segItem.isCurrent ? theme.primary
                                : (segMouse.containsMouse ? Qt.lighter(theme.surfaceContainerHighest, 1.12) : theme.surfaceContainerHighest)
                            leftRadius: segItem.first ? segItem.outer : segItem.inner
                            rightRadius: segItem.last ? segItem.outer : segItem.inner

                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                            Behavior on leftRadius { enabled: theme.animate; SpringAnimation { spring: theme.springFast; damping: theme.springFastDamping } }
                            Behavior on rightRadius { enabled: theme.animate; SpringAnimation { spring: theme.springFast; damping: theme.springFastDamping } }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: root.effectiveIconOnly ? 0 : 6

                            LoafIcon {
                                id: segIcon
                                anchors.verticalCenter: parent.verticalCenter
                                visible: segItem.showIcon
                                name: segItem.hasIcon ? modelData.icon : ""
                                size: root.effectiveIconOnly ? 16 : 14
                                color: segItem.fg
                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: 140 } }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !root.effectiveIconOnly && !!(modelData && modelData.label)
                                width: Math.max(0, Math.min(implicitWidth, segItem.width - 16 - (segIcon.visible ? segIcon.width + 6 : 0)))
                                elide: Text.ElideRight
                                text: segItem.shownText
                                color: segItem.fg
                                font.pixelSize: theme.fs(12)
                                font.weight: segItem.isCurrent ? Font.DemiBold : Font.Medium
                                font.family: theme.fontFamily
                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: 140 } }
                            }
                        }

                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData && modelData.label ? modelData.label : ""
                        Accessible.checked: isCurrent

                        MouseArea {
                            id: segMouse
                            anchors.fill: parent
                            enabled: !segItem.isDisabled
                            hoverEnabled: !segItem.isDisabled
                            cursorShape: segItem.isDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onPressedChanged: track.pressedIndex = pressed ? index : (track.pressedIndex === index ? -1 : track.pressedIndex)
                            onEntered: if ((root.effectiveIconOnly || segItem.shownText !== segItem.fullText) && !!(modelData && modelData.label) && typeof tooltip !== "undefined")
                                tooltip.show(segMouse, modelData.label)
                            onExited: if (typeof tooltip !== "undefined") tooltip.hide(segMouse)

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
