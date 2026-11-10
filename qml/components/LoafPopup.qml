import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// LoafPopup -- Material 3 Expressive surface popup.
// Rounded elevated surface with spring-ish enter/exit motion and fully
// declarative child content (children are laid out in a ColumnLayout).
Popup {
    id: popup

    property real contentPadding: 10
    property color surfaceColor: theme.menuSurface
    property color borderColor: theme.borderSubtle
    property real surfaceRadius: theme.radiusL

    // Children land in the host ColumnLayout.
    default property alias content: hostColumn.data

    // The host item, exposed so derived popups (e.g. LoafMenu) can alias/extend it.
    property alias contentHost: hostColumn

    padding: contentPadding
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    transformOrigin: Item.Center
    scale: 0.85
    opacity: 0.0

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.8; to: 1.0; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
    }

    exit: Transition {
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
        popup.x = px;
        popup.y = py;
        popup.open();
        popup.reposition();
    }

    function reposition() {
        var margin = 10;
        var w = popup.width > 0 ? popup.width : (popup.implicitWidth > 0 ? popup.implicitWidth : 200);
        var h = popup.height > 0 ? popup.height : (popup.implicitHeight > 0 ? popup.implicitHeight : 120);
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
}
