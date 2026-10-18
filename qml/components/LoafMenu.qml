import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// LoafMenu -- Material 3 Expressive menu with model-driven rows, separators
// and cascading submenus.
//
// model entry shape:
//   { text, icon, shortcut, enabled, checkable, checked, danger,
//     separatorBefore, submenu: [ ...same shape... ], action: function() {} }
LoafPopup {
    id: menu

    property var model: []
    property real menuMinWidth: 208
    property real menuMaxWidth: 320
    property bool modelVisible: true
    // Tall menus (app lists) scroll past this instead of overflowing the screen.
    // Capped at 70% of the window so the menu never grows taller than the screen.
    property real maxMenuHeight: Math.round(winHeight() * 0.7)

    property int highlightIndex: -1
    property var parentMenu: null
    property var currentSubmenu: null

    // Extra widgets appended below the model rows (View menu uses this).
    default property alias extraContent: menu.contentHost.data

    // Width is computed imperatively (on model change) so the TextMetrics
    // measurement below never takes part in a property-binding loop. Consumers
    // that assign an explicit `width` simply take precedence over autoWidth.
    property real autoWidth: menu.menuMinWidth
    width: menu.autoWidth

    onModelChanged: menu.refreshWidth()
    Component.onCompleted: menu.refreshWidth()

    // Scrolls the row area so `rowIndex` is inside the visible window (used by
    // keyboard navigation, which must not move the highlight off-screen).
    function revealRow(rowIndex) {
        var wrap = menu.rowWrapperFor(rowIndex);
        if (!wrap || !scrollFlick || !wrap.mapToItem)
            return;
        var top = wrap.mapToItem(scrollFlick, 0, 0).y;
        var bottom = top + wrap.height;
        if (top < scrollFlick.contentY)
            scrollFlick.contentY = top;
        else if (bottom > scrollFlick.contentY + scrollFlick.height)
            scrollFlick.contentY = bottom - scrollFlick.height;
    }

    function refreshWidth() {
        menu.autoWidth = menu.computeWidth();
    }

    onOpened: {
        menu.reposition();
        menu.highlightIndex = -1;
        if (scrollFlick)
            scrollFlick.contentY = 0;
        keyHandler.forceActiveFocus();
        menu.animateIn();
    }

    onAboutToHide: menu.animateOut()

    onClosed: {
        menu.hideSubmenuNow();
        menu.resetRows();
    }

    // ---- width measurement --------------------------------------------------

    TextMetrics { id: tmLabel; font.pixelSize: 13 }
    TextMetrics { id: tmShortcut; font.pixelSize: 11 }

    function computeMeasuredWidth() {
        if (typeof tmLabel === "undefined" || !tmLabel)
            return 0;
        var opts = menu.model;
        var maxW = 0;
        if (opts && opts.length) {
            for (var i = 0; i < opts.length; i++) {
                var it = opts[i];
                if (!it || !it.text)
                    continue;
                tmLabel.text = String(it.text);
                var w = 24; // left + right row margins
                if (it.icon && String(it.icon).length > 0)
                    w += 26;
                w += tmLabel.advanceWidth;
                if (it.shortcut && String(it.shortcut).length > 0) {
                    tmShortcut.text = String(it.shortcut);
                    w += tmShortcut.advanceWidth + 12;
                }
                if (it.submenu && it.submenu.length > 0)
                    w += 18;
                maxW = Math.max(maxW, w);
            }
        }
        return maxW;
    }

    function computeWidth() {
        var cw = Math.max(menu.computeMeasuredWidth(), menu.menuMinWidth - 2 * menu.contentPadding);
        return Math.min(menu.menuMaxWidth, Math.ceil(cw + 2 * menu.contentPadding));
    }

    // ---- row animation ------------------------------------------------------

    function animatableRows() {
        var out = [];
        // Rows are parented to rowsColumn inside the scrollable area.
        var kids = menu.rowsColumn ? menu.rowsColumn.children : [];
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i];
            if (c && c.visible && (typeof c.playPop === "function" || typeof c.popIn === "function"))
                out.push(c);
        }
        return out;
    }

    function animateIn() {
        var list = menu.animatableRows();
        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            var delay = i * 22;
            if (typeof item.playPop === "function")
                item.playPop(delay);
            else if (typeof item.popIn === "function")
                item.popIn(delay);
        }
    }

    function animateOut() {
        var list = menu.animatableRows();
        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            if (typeof item.playOut === "function")
                item.playOut(0);
            else if (typeof item.popOut === "function")
                item.popOut(0);
        }
    }

    function resetRows() {
        var list = menu.animatableRows();
        for (var i = 0; i < list.length; i++)
            list[i].reset();
    }

    // ---- activation ---------------------------------------------------------

    function activate(index) {
        var opts = menu.model;
        if (!opts || index < 0 || index >= opts.length)
            return;
        var it = opts[index];
        if (!it || it.enabled === false)
            return;
        if (it.submenu && it.submenu.length > 0) {
            menu.openSubmenuAt(index);
            return;
        }
        if (typeof it.action === "function")
            it.action();
        menu.close();
    }

    function rowWrapperFor(index) {
        // `rowsColumn` is an id in this component scope, so it is referenced
        // directly rather than through the root alias.
        var kids = rowsColumn.children;
        for (var i = 0; i < kids.length; i++) {
            if (kids[i] && kids[i].rowIndex === index)
                return kids[i];
        }
        return null;
    }

    // ---- cascading submenus -------------------------------------------------

    function ensureSubmenu() {
        if (menu.currentSubmenu)
            return menu.currentSubmenu;
        // NOTE: LoafMenu must not reference itself as a static type (that breaks
        // loading), so nested menus are created dynamically at runtime instead.
        var parentItem = Overlay.overlay;
        if (!parentItem)
            parentItem = menu.parent;
        var obj = null;
        try {
            obj = Qt.createQmlObject("import QtQuick\nimport app.loaf\nLoafMenu { }",
                                     parentItem ? parentItem : menu, "LoafSubmenu");
        } catch (e) {
            console.warn("LoafMenu: could not create submenu: " + e);
            return null;
        }
        if (!obj)
            return null;
        obj.menuMinWidth = menu.menuMinWidth;
        obj.menuMaxWidth = menu.menuMaxWidth;
        obj.maxMenuHeight = menu.maxMenuHeight;
        obj.parentMenu = menu;
        if (parentItem)
            obj.parent = parentItem;
        menu.currentSubmenu = obj;
        return obj;
    }

    function showSubmenu(anchorItem, submenuModel) {
        if (!submenuModel || submenuModel.length === 0) {
            menu.hideSubmenuSoon();
            return;
        }
        hideTimer.stop();
        var sm = menu.ensureSubmenu();
        if (!sm)
            return;
        // Reassigning resets scroll position; this only happens when the
        // submenu content actually changed, so the position is kept otherwise.
        var same = sm.parentMenu === menu
            && sm.model && sm.model.length === submenuModel.length
            && (submenuModel.length === 0 || sm.model[0].text === submenuModel[0].text);
        if (!same) {
            sm.model = submenuModel;
            sm.resetScroll();
        }
        sm.parentMenu = menu;
        sm.openRightOf(anchorItem);
    }

    // Called when a menu (re)opens so it always starts at the top.
    function resetScroll() {
        if (scrollFlick)
            scrollFlick.contentY = 0;
        menu.highlightIndex = -1;
    }

    function openSubmenuAt(index) {
        var opts = menu.model;
        if (!opts || !opts[index])
            return;
        var sub = opts[index].submenu;
        if (!sub || sub.length === 0)
            return;
        var wrap = menu.rowWrapperFor(index);
        menu.highlightIndex = index;
        menu.showSubmenu(wrap && wrap.rowItem ? wrap.rowItem : wrap, sub);
    }

    function hideSubmenuSoon() {
        if (menu.currentSubmenu && menu.currentSubmenu.opened)
            hideTimer.restart();
    }

    function hideSubmenuNow() {
        hideTimer.stop();
        if (menu.currentSubmenu && menu.currentSubmenu.opened)
            menu.currentSubmenu.close();
    }

    // ---- keyboard -----------------------------------------------------------

    function isNestedMenu() {
        return menu.parentMenu !== null && menu.parentMenu !== undefined;
    }

    function moveHighlight(dir) {
        var opts = menu.model || [];
        if (opts.length === 0)
            return;
        var i = menu.highlightIndex;
        for (var step = 0; step < opts.length; step++) {
            i = (i + dir + opts.length) % opts.length;
            var it = opts[i];
            if (it && it.enabled !== false) {
                menu.highlightIndex = i;
                menu.revealRow(i);
                return;
            }
        }
    }

    function activateHighlight() {
        if (menu.highlightIndex >= 0) {
            menu.activate(menu.highlightIndex);
            return;
        }
        if (menu.model && menu.model.length > 0)
            menu.activate(0);
    }

    function openHighlightSubmenu() {
        if (menu.highlightIndex >= 0)
            menu.openSubmenuAt(menu.highlightIndex);
    }

    function closeRecursive() {
        menu.hideSubmenuNow();
        var p = menu.parentMenu;
        menu.parentMenu = null;
        menu.close();
        if (p)
            p.close();
    }

    function handleEscape() {
        if (menu.isNestedMenu())
            menu.closeRecursive();
        else
            menu.close();
    }

    // ---- rows ---------------------------------------------------------------

    // Long menus (e.g. "Other Applications") scroll instead of overflowing the
    // screen: the rows live inside a Flickable that only takes the height it
    // needs, up to maxMenuHeight.
    Flickable {
        id: scrollFlick

        Layout.fillWidth: true
        Layout.maximumHeight: menu.maxMenuHeight
        implicitHeight: Math.min(rowsColumn.implicitHeight, menu.maxMenuHeight)
        contentWidth: width
        contentHeight: rowsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // A wheel event over the menu must scroll it, never close it.
        ScrollBar.vertical: ScrollBar {
            id: menuScrollBar
            policy: scrollFlick.contentHeight > scrollFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        ColumnLayout {
            id: rowsColumn
            width: scrollFlick.width
            spacing: 0

            Repeater {
                id: rowsRepeater
                model: menu.model

                delegate: ColumnLayout {
                    id: rowWrap
                    Layout.fillWidth: true
                    spacing: 0
                    visible: menu.modelVisible

                    property var entry: modelData
                    property int rowIndex: index
                    property var rowItem: row

                    function playPop(delayMs) { sep.popIn(delayMs); row.popIn(delayMs); }
                    function playOut(delayMs) { sep.popOut(delayMs); row.popOut(delayMs); }
                    function reset() { sep.reset(); row.reset(); }

                    Rectangle {
                        id: sep
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.topMargin: 5
                        Layout.bottomMargin: 5
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        color: theme.separator
                        visible: rowWrap.entry ? rowWrap.entry.separatorBefore === true : false

                        SequentialAnimation {
                            id: sepIn
                            property int delayMs: 0
                            PauseAnimation { duration: sepIn.delayMs }
                            NumberAnimation { target: sep; property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                        }

                        SequentialAnimation {
                            id: sepOut
                            property int delayMs: 0
                            PauseAnimation { duration: sepOut.delayMs }
                            NumberAnimation { target: sep; property: "opacity"; from: 1.0; to: 0.0; duration: 100; easing.type: Easing.InCubic }
                        }

                        function popIn(d) { sepOut.stop(); sepIn.stop(); sep.opacity = 0.0; sepIn.delayMs = d; sepIn.start(); }
                        function popOut(d) { sepIn.stop(); sepOut.stop(); sep.opacity = 1.0; sepOut.delayMs = d; sepOut.start(); }
                        function reset() { sepIn.stop(); sepOut.stop(); sep.opacity = 1.0; }
                    }

                    LoafMenuItem {
                        id: row
                        icon: rowWrap.entry && rowWrap.entry.icon ? rowWrap.entry.icon : ""
                        text: rowWrap.entry && rowWrap.entry.text ? rowWrap.entry.text : ""
                        shortcut: rowWrap.entry && rowWrap.entry.shortcut ? rowWrap.entry.shortcut : ""
                        danger: rowWrap.entry ? rowWrap.entry.danger === true : false
                        enabled: rowWrap.entry ? rowWrap.entry.enabled !== false : true
                        checkable: rowWrap.entry ? rowWrap.entry.checkable === true : false
                        checked: rowWrap.entry ? rowWrap.entry.checked === true : false
                        hasSubmenu: rowWrap.entry && rowWrap.entry.submenu ? rowWrap.entry.submenu.length > 0 : false
                        highlighted: menu.highlightIndex === rowWrap.rowIndex

                        onTriggered: menu.activate(rowWrap.rowIndex)
                        onSubmenuHovered: menu.openSubmenuAt(rowWrap.rowIndex)
                        onHoveredChanged: {
                            if (!row.hovered)
                                return;
                            if (row.hasSubmenu)
                                menu.openSubmenuAt(rowWrap.rowIndex);
                            else
                                menu.hideSubmenuSoon();
                        }

                        // Wheel over a row scrolls the menu instead of bubbling
                        // out to the window behind it.
                        WheelHandler {
                            target: null
                            onWheel: function(event) {
                                if (event.angleDelta.y !== 0) {
                                    scrollFlick.contentY -= event.angleDelta.y / 2;
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Focusable 0-height helper that owns menu keyboard handling.
    Item {
        id: keyHandler
        Layout.fillWidth: true
        Layout.preferredHeight: 0
        implicitHeight: 0
        focus: true

        Keys.onDownPressed: { menu.moveHighlight(1); event.accepted = true; }
        Keys.onUpPressed: { menu.moveHighlight(-1); event.accepted = true; }
        Keys.onReturnPressed: { menu.activateHighlight(); event.accepted = true; }
        Keys.onEnterPressed: { menu.activateHighlight(); event.accepted = true; }
        Keys.onRightPressed: { menu.openHighlightSubmenu(); event.accepted = true; }
        Keys.onLeftPressed: {
            if (menu.isNestedMenu())
                menu.close();
            event.accepted = true;
        }
        Keys.onEscapePressed: { menu.handleEscape(); event.accepted = true; }
    }

    Timer {
        id: hideTimer
        interval: 220
        onTriggered: {
            var sm = menu.currentSubmenu;
            if (!sm || !sm.opened)
                return;
            if (menu.contentHovered || sm.contentHovered)
                return;
            sm.close();
        }
    }
}
