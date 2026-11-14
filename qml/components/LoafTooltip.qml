import QtQuick
import QtQuick.Controls
import app.loaf

// LoafTooltip -- the one hover tooltip used across the app.
//
// Call sites go through show()/hide() instead of the attached ToolTip so the
// 1s delay, the surface styling and the "show tooltips" accessibility toggle
// all live in a single place rather than being re-tuned on every button.
//
//   onEntered: tooltip.show(mouse, qsTr("Empty Trash"))
//   onExited:  tooltip.hide(mouse)
//
// Passing the hover source to hide() makes the hand-off between two adjacent
// controls order-independent: an exit that arrives after the next enter is
// ignored instead of killing the fresh tooltip.
Item {
    id: tip

    // Lives at the window level so it can float above every pane and dialog.
    // Never eats the pointer itself: it overlays whatever is underneath.
    z: 10000
    visible: opacity > 0.01

    opacity: shown ? 1.0 : 0.0
    scale: shown ? 1.0 : 0.94
    property bool shown: false

    property Item target: null
    property string tipText: ""

    readonly property bool tipsOn: typeof theme === "undefined" || !theme || theme.showTooltips

    // The pill drives the size, so it is known synchronously -- no popup
    // open/measure/reposition round trip, which keeps the first frame exact.
    readonly property real padX: theme.fs(11)
    readonly property real padY: theme.fs(6)
    implicitWidth: label.implicitWidth + 2 * padX
    implicitHeight: label.implicitHeight + 2 * padY
    width: implicitWidth
    height: implicitHeight

    function show(item, text) {
        if (!item || !text || String(text).length === 0)
            return;
        if (!tip.tipsOn)
            return;
        delay.stop();
        tip.target = item;
        tip.tipText = String(text);
        tip.place();
        // Already on screen: follow the new target straight away instead of
        // re-charging the delay while the pointer walks a row of buttons.
        if (tip.shown)
            return;
        delay.start();
    }

    function hide(item) {
        // A newer target took over while this control was letting go.
        if (item && tip.target !== item)
            return;
        delay.stop();
        tip.shown = false;
    }

    function place() {
        var t = tip.target;
        if (!t || !t.mapToItem)
            return;
        var p = t.mapToItem(null, 0, 0);
        var gap = 8;
        var margin = 8;
        var winW = (typeof window !== "undefined" && window && window.width > 0) ? window.width : 1920;
        var winH = (typeof window !== "undefined" && window && window.height > 0) ? window.height : 1080;

        var tx = p.x + t.width / 2 - tip.width / 2;
        var ty = p.y + t.height + gap;
        if (ty + tip.height > winH - margin)
            ty = p.y - tip.height - gap;
        ty = Math.max(margin, ty);
        tx = Math.max(margin, Math.min(tx, winW - tip.width - margin));

        tip.x = tx;
        tip.y = ty;
    }

    Timer {
        id: delay
        interval: 1000
        onTriggered: {
            if (!tip.target || !tip.tipsOn)
                return;
            tip.place();
            tip.shown = true;
        }
    }

    Behavior on opacity {
        enabled: theme.animate
        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        enabled: theme.animate
        NumberAnimation { duration: 190; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

    // Soft drop shadow, offset like every other elevated surface.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: theme.radiusM
        color: theme.shadow
        z: -1
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: theme.radiusM
        color: theme.backdropSurface(theme.surfaceContainerHighest)
        border.width: 1
        border.color: theme.outlineAlpha(theme.outlineVariant)

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }
        Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: tip.tipText
        color: theme.textMain
        font.family: theme.fontFamily
        font.weight: theme.fw(false)
        font.pixelSize: theme.fs(12)
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}
