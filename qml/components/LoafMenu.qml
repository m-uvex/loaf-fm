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
    // Long menus (app lists) scroll instead of running off the screen.
    property real maxMenuHeight: Math.round(winHeight() * 0.7)

    property int highlightIndex: -1
    property var parentMenu: null
    property var currentSubmenu: null
    property var pendingAction: null

    function rootMenu() {
        var m = menu;
        while (m && m.parentMenu)
            m = m.parentMenu;
        return m;
    }

    // Extra widgets appended below the model rows (View menu uses this) land in
    // contentHost via LoafPopup's inherited default property.

    // Width is computed imperatively (on model change) so the TextMetrics
    // measurement below never takes part in a property-binding loop. Consumers
    // that assign an explicit `width` simply take precedence over autoWidth.
    property real autoWidth: menu.menuMinWidth
    width: menu.autoWidth

    onModelChanged: menu.refreshWidth()
    Component.onCompleted: menu.refreshWidth()

    function refreshWidth() {
        menu.autoWidth = menu.computeWidth();
    }

    property real lastClosedTime: 0

    onAboutToShow: menu.animateIn()

    onOpened: {
        menu.reposition();
        menu.highlightIndex = -1;
        rowsView.positionViewAtBeginning();
        keyHandler.forceActiveFocus();
    }

    onAboutToHide: menu.animateOut()

    onClosed: {
        menu.lastClosedTime = Date.now();
        menu.hideSubmenuNow();
        menu.resetRows();
        if (typeof menu.pendingAction === "function") {
            var act = menu.pendingAction;
            menu.pendingAction = null;
            try {
                act();
            } catch (e) {
                console.warn("LoafMenu: action failed: " + e);
            }
        }
    }

    TextMetrics { id: tmLabel; font.pixelSize: theme.fs(13) }
    TextMetrics { id: tmShortcut; font.pixelSize: theme.fs(11) }

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

    function computeHeight() {
        var opts = menu.model;
        if (!opts || opts.length === 0)
            return 2 * menu.contentPadding;
        var total = 2 * menu.contentPadding;
        for (var i = 0; i < opts.length; ++i) {
            total += 36;
            if (opts[i] && opts[i].separatorBefore)
                total += 11;
        }
        return Math.min(total, menu.maxMenuHeight);
    }

    function animatableRows() {
        var out = [];
        var kids = rowsView.contentItem ? rowsView.contentItem.children : [];
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i];
            if (c && c.visible && (typeof c.playPop === "function" || typeof c.popIn === "function"))
                out.push(c);
        }
        if (contentHost && contentHost.children) {
            for (var j = 0; j < contentHost.children.length; j++) {
                var ch = contentHost.children[j];
                if (ch && ch.visible && ch !== rowsView && (typeof ch.playPop === "function" || typeof ch.popIn === "function"))
                    out.push(ch);
            }
        }
        return out;
    }

    function animateIn() {
        if (!theme.animate)
            return;
        var list = menu.animatableRows();
        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            if (typeof item.playPop === "function")
                item.playPop(0);
            else if (typeof item.popIn === "function")
                item.popIn(0);
        }
    }

    function animateOut() {
        if (!theme.animate)
            return;
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

    function resolveSubmenu(entry) {
        if (!entry)
            return null;
        if (typeof entry.submenu === "function")
            entry.submenu = entry.submenu();
        return entry.submenu;
    }

    function activate(index) {
        var opts = menu.model;
        if (!opts || index < 0 || index >= opts.length)
            return;
        var it = opts[index];
        if (!it || it.enabled === false)
            return;
        var sub = menu.resolveSubmenu(it);
        if (sub && sub.length > 0) {
            menu.openSubmenuAt(index);
            return;
        }
        // Close this menu and every parent first, then act: a dialog or an
        // inline editor opened by the action must not lose focus to a menu.
        // Actions run once the menu finishes closing so Qt Quick's popup focus
        // restoration cannot steal active focus from newly opened editors.
        var action = it.action;
        var root = menu.rootMenu();
        if (typeof action === "function") {
            if (root && (root.opened || root.visible))
                root.pendingAction = action;
            else
                action();
        }
        menu.closeChain();
    }

    function closeChain() {
        var m = menu;
        while (m) {
            var p = m.parentMenu;
            m.hideSubmenuNow();
            m.close();
            m = p;
        }
    }

    function rowWrapperFor(index) {
        rowsView.positionViewAtIndex(index, ListView.Contain);
        return rowsView.itemAtIndex(index);
    }

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
        obj.closed.connect(function() {
            if (!menu.contentHovered)
                menu.highlightIndex = -1;
        });
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
        sm.model = submenuModel;
        sm.parentMenu = menu;
        sm.openAdjacentTo(anchorItem, menu);
    }

    function openSubmenuAt(index) {
        var opts = menu.model;
        if (!opts || !opts[index])
            return;
        var sub = menu.resolveSubmenu(opts[index]);
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
        if (!menu.contentHovered)
            menu.highlightIndex = -1;
    }

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
                rowsView.positionViewAtIndex(i, ListView.Contain);
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

    // Rows live in a ListView: only visible rows are created (an app list
    // can hold hundreds of entries) and it scrolls past maxMenuHeight.
    ListView {
        id: rowsView
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, menu.maxMenuHeight)
        visible: menu.modelVisible && count > 0
        implicitHeight: Math.min(contentHeight, menu.maxMenuHeight)
        clip: contentHeight > height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: menu.model
        ScrollBar.vertical: ScrollBar { policy: rowsView.contentHeight > rowsView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
        onContentHeightChanged: if (menu.opened) menu.reposition()

        delegate: ColumnLayout {
            id: rowWrap
            width: rowsView.width
            spacing: 0

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
                iconUrl: rowWrap.entry && rowWrap.entry.iconUrl ? rowWrap.entry.iconUrl : ""
                text: rowWrap.entry && rowWrap.entry.text ? rowWrap.entry.text : ""
                shortcut: rowWrap.entry && rowWrap.entry.shortcut ? rowWrap.entry.shortcut : ""
                danger: rowWrap.entry ? rowWrap.entry.danger === true : false
                enabled: rowWrap.entry ? rowWrap.entry.enabled !== false : true
                checkable: rowWrap.entry ? rowWrap.entry.checkable === true : false
                checked: rowWrap.entry ? rowWrap.entry.checked === true : false
                hasSubmenu: {
                    if (!rowWrap.entry || !rowWrap.entry.submenu)
                        return false;
                    return typeof rowWrap.entry.submenu === "function"
                        || rowWrap.entry.submenu.length > 0;
                }
                highlighted: menu.highlightIndex === rowWrap.rowIndex

                onTriggered: menu.activate(rowWrap.rowIndex)
                onSubmenuHovered: menu.openSubmenuAt(rowWrap.rowIndex)
                onHoveredChanged: {
                    if (row.hovered) {
                        menu.highlightIndex = rowWrap.rowIndex;
                        if (row.hasSubmenu)
                            menu.openSubmenuAt(rowWrap.rowIndex);
                        else
                            menu.hideSubmenuSoon();
                    } else {
                        if (!row.hasSubmenu || !menu.currentSubmenu || !menu.currentSubmenu.opened) {
                            if (menu.highlightIndex === rowWrap.rowIndex)
                                menu.highlightIndex = -1;
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

        Keys.onDownPressed: function(event) { menu.moveHighlight(1); event.accepted = true; }
        Keys.onUpPressed: function(event) { menu.moveHighlight(-1); event.accepted = true; }
        Keys.onReturnPressed: function(event) { menu.activateHighlight(); event.accepted = true; }
        Keys.onEnterPressed: function(event) { menu.activateHighlight(); event.accepted = true; }
        Keys.onRightPressed: function(event) { menu.openHighlightSubmenu(); event.accepted = true; }
        Keys.onLeftPressed: function(event) {
            if (menu.isNestedMenu())
                menu.close();
            event.accepted = true;
        }
        Keys.onEscapePressed: function(event) { menu.handleEscape(); event.accepted = true; }
    }

    Timer {
        id: hideTimer
        interval: 180
        onTriggered: {
            var sm = menu.currentSubmenu;
            if (!sm || !sm.opened)
                return;
            // Only keep the submenu open if the mouse has moved into the submenu itself.
            if (sm.contentHovered)
                return;
            sm.close();
        }
    }
}
