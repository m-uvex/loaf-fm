import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import app.loaf

// LoafPopup -- Material 3 Expressive surface popup.
// Rounded elevated surface with spring-ish enter/exit motion and fully
// declarative child content (children are laid out in a ColumnLayout).
Popup {
    id: popup

    property real contentPadding: 10
    property color surfaceColor: theme.submenuEffects ? theme.backdropSurface(theme.menuSurface) : theme.menuSurface
    property color borderColor: theme.outlineAlpha(theme.borderSubtle)
    property real surfaceRadius: theme.radiusL
    readonly property var captureTarget: (typeof window !== "undefined" && window && window.workspaceArea) ? window.workspaceArea : null
    readonly property bool enableBackdropBlur: theme.submenuEffects && !theme.lowPower && theme.effectivePanelOpacity < 1.0 && captureTarget !== null
        && captureTarget.GraphicsInfo.api !== GraphicsInfo.Software && captureTarget.GraphicsInfo.api !== GraphicsInfo.Unknown

    // Children land in the host ColumnLayout.
    default property alias content: hostColumn.data

    // The host item, exposed so derived popups (e.g. LoafMenu) can alias/extend it.
    property alias contentHost: hostColumn

    padding: contentPadding
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    transformOrigin: Item.Center
    scale: 0.8
    opacity: 0.0

    enter: Transition {
        enabled: theme.animate
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.8; to: 1.0; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
    }

    exit: Transition {
        enabled: theme.animate
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 160; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.85; duration: 160; easing.type: Easing.InCubic }
        }
    }

    background: Item {
        id: bgItem
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: -3
            radius: popup.surfaceRadius
            color: theme.shadow
        }
        // Opaque theme base prevents underlying sharp text leakage
        Rectangle {
            visible: theme.submenuEffects
            anchors.fill: parent
            radius: popup.surfaceRadius
            color: theme.menuSurface
        }
        Loader {
            anchors.fill: parent
            active: popup.visible && popup.enableBackdropBlur
            sourceComponent: Item {
                anchors.fill: parent
                clip: true
                ShaderEffectSource {
                    id: backdropCapture
                    sourceItem: popup.captureTarget
                    sourceRect: {
                        var _x = popup.x, _y = popup.y, _w = popup.width, _h = popup.height, _s = popup.scale;
                        if (!popup.enableBackdropBlur || !popup.captureTarget || !bgItem || !bgItem.mapToItem)
                            return Qt.rect(0, 0, 0, 0);
                        var p0 = bgItem.mapToItem(popup.captureTarget, 0, 0);
                        var p1 = bgItem.mapToItem(popup.captureTarget, bgItem.width, bgItem.height);
                        var tw = popup.captureTarget.width;
                        var th = popup.captureTarget.height;
                        var sx = Math.max(0, Math.min(tw, Math.min(p0.x, p1.x)));
                        var sy = Math.max(0, Math.min(th, Math.min(p0.y, p1.y)));
                        var ex = Math.max(0, Math.min(tw, Math.max(p0.x, p1.x)));
                        var ey = Math.max(0, Math.min(th, Math.max(p0.y, p1.y)));
                        var sw = Math.max(0, ex - sx);
                        var sh = Math.max(0, ey - sy);
                        return Qt.rect(sx, sy, sw, sh);
                    }
                    width: parent.width
                    height: parent.height
                    recursive: false
                    live: popup.visible && popup.enableBackdropBlur
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: backdropCapture
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 0.9
                    blurMax: 32
                    opacity: 0.88
                    maskEnabled: true
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: popup.width
                            height: popup.height
                            radius: popup.surfaceRadius
                            color: "black"
                        }
                    }
                }
            }
        }
        Rectangle {
            id: surfaceRect
            anchors.fill: parent
            radius: popup.surfaceRadius
            color: popup.surfaceColor
            border.color: popup.borderColor
            border.width: 1

            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }
            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }
        }
    }

    contentItem: ColumnLayout {
        id: hostColumn
        spacing: 4
        width: popup.width - 2 * popup.contentPadding

        HoverHandler { id: contentHoverHandler }
    }

    // True while the pointer is over the popup content (used for submenu lifetime).
    property alias contentHovered: contentHoverHandler.hovered

    function winWidth() {
        if (typeof window !== "undefined" && window && window.width > 0) return window.width;
        return 1920;
    }

    function winHeight() {
        if (typeof window !== "undefined" && window && window.height > 0) return window.height;
        return 1080;
    }

    // Open at a scene coordinate (top-left), flipping left/up when it would overflow.
    // The popup must be opened before its size is known (a Popup only creates its
    // contentItem -- and therefore knows its implicit size -- once it is opened),
    // so the clamping is applied right after open().
    property real requestedX: 0
    property real requestedY: 0

    function openAt(px, py) {
        popup.requestedX = px;
        popup.requestedY = py;
        popup.reposition();
        popup.open();
        popup.reposition();
    }

    function reposition() {
        var margin = 10;
        var w = popup.width > 0 ? popup.width : (popup.implicitWidth > 0 ? popup.implicitWidth : 200);
        var h = (typeof popup.computeHeight === "function") ? popup.computeHeight()
            : (popup.height > 0 ? popup.height : (popup.implicitHeight > 0 ? popup.implicitHeight : 120));
        var winW = popup.winWidth();
        var winH = popup.winHeight();

        var tx = popup.requestedX;
        var ty = popup.requestedY;

        if (tx + w > winW - margin)
            tx = popup.requestedX - w;
        if (ty + h > winH - margin)
            ty = popup.requestedY - h;

        tx = Math.max(margin, Math.min(tx, Math.max(margin, winW - w - margin)));
        ty = Math.max(margin, Math.min(ty, Math.max(margin, winH - h - margin)));

        popup.x = tx;
        popup.y = ty;
    }

    onOpened: popup.reposition()
    onHeightChanged: if (popup.opened) popup.reposition()

    function openBelow(anchorItem) {
        if (!anchorItem || !anchorItem.mapToItem) return;
        var p = anchorItem.mapToItem(null, 0, anchorItem.height);
        popup.openAt(p.x, p.y);
    }

    function openRightOf(anchorItem) {
        if (!anchorItem || !anchorItem.mapToItem) return;
        var p = anchorItem.mapToItem(null, anchorItem.width, 0);
        popup.openAt(p.x, p.y);
    }

    function openAdjacentTo(anchorItem, parentMenu) {
        if (!anchorItem || !anchorItem.mapToItem) return;
        var p = anchorItem.mapToItem(null, 0, 0);
        var winW = popup.winWidth();
        var winH = popup.winHeight();
        var margin = 10;
        var w = popup.width > 0 ? popup.width : (popup.implicitWidth > 0 ? popup.implicitWidth : 200);
        var h = (typeof popup.computeHeight === "function") ? popup.computeHeight()
            : (popup.height > 0 ? popup.height : 120);

        var parentX = parentMenu ? parentMenu.x : p.x;
        var parentW = parentMenu ? parentMenu.width : anchorItem.width;

        var tx = parentX + parentW - 4;
        if (tx + w > winW - margin) {
            tx = Math.max(margin, parentX - w + 4);
        }

        var ty = p.y - popup.contentPadding;
        if (ty + h > winH - margin) {
            ty = Math.max(margin, winH - h - margin);
        }
        ty = Math.max(margin, ty);

        popup.requestedX = tx;
        popup.requestedY = ty;
        popup.x = tx;
        popup.y = ty;
        popup.open();
        popup.reposition();
    }
}
