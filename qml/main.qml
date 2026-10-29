import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

ApplicationWindow {
    id: window
    width: 1080
    height: 720
    minimumWidth: 640
    minimumHeight: 420
    visible: true
    background: null
    title: (nativeBridge.isAdmin ? qsTr("[Administrator] ") : "") + "Loaf - " + (activeView === "settings"
        ? qsTr("Settings")
        : activeView === "pc" ? (core.hostname || qsTr("This PC"))
        : (engine.is_searching_everywhere ? qsTr("Search") : engine.current_dir_name))
    color: theme.windowBackground

    // Mirror the whole layout for right-to-left languages.
    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    property string activeView: "files" // "files", "settings", "pc"
    property bool isEditingPath: false
    property bool keyboardNavActive: false
    property bool splitView: false
    readonly property bool showHidden: activePane ? activePane.engine.show_hidden : false

    function toggleShowHidden() {
        var v = !pane0.engine.show_hidden;
        if (pane0.engine.show_hidden !== v)
            pane0.engine.toggle_show_hidden();
        if (pane1Loader.item && pane1Loader.item.engine.show_hidden !== v)
            pane1Loader.item.engine.toggle_show_hidden();
    }
    property var activePane: pane0
    // The engine (model) of the pane the user is working in.
    readonly property var engine: activePane ? activePane.engine : pane0.engine
    property string searchScope: "folder"

    // Tabs: [{ states: [json, json], split: bool, active: 0|1, title }]
    property var tabs: [{ states: ["", ""], split: false, active: 0, title: "" }]
    property int currentTab: 0

    // Async drive mount auto-open tracking
    property var mtpClipboardPaths: []
    property bool mtpClipboardCut: false
    property string pendingMountDevice: ""
    property bool pendingMountInNewTab: false
    property string pendingMountView: ""

    function cancelDriveOpen() {
        pendingMountDevice = "";
        pendingMountInNewTab = false;
        pendingMountView = "";
    }

    onActiveViewChanged: {
        if (pendingMountDevice.length > 0 && activeView !== pendingMountView)
            cancelDriveOpen();
    }

    onCurrentTabChanged: cancelDriveOpen()
    onActivePaneChanged: cancelDriveOpen()

    Connections {
        target: window.engine
        function onCurrent_pathChanged() { window.cancelDriveOpen(); }
        function onLocation_kindChanged() { window.cancelDriveOpen(); }
    }

    function openDrive(d, inNewTab) {
        if (!d || !d.device)
            return;
        if (d.provider === "mtp") {
            window.cancelDriveOpen();
            if (inNewTab) window.newTab(d.device);
            else {
                window.showFiles();
                searchInput.text = "";
                engine.set_path(d.device);
            }
            return;
        }
        if (d.is_mounted && d.mount_point) {
            window.cancelDriveOpen();
            if (inNewTab) {
                window.newTab(d.mount_point);
                return;
            }
            window.showFiles();
            searchInput.text = "";
            engine.set_path(d.mount_point);
            return;
        }
        if (core.busy)
            return;
        if (window.pendingMountDevice.length > 0)
            return;

        window.pendingMountDevice = d.device || "";
        window.pendingMountInNewTab = !!inNewTab;
        window.pendingMountView = window.activeView;
        window.mountDrive(d);
    }

    function mountDrive(d) {
        if (!d)
            return;
        if (d.provider === "mtp") {
            window.openDrive(d, false);
            return;
        }
        if (core.busy)
            return;
        if (d.is_locked)
            core.unlock_drive(d.device, "", false);
        else
            core.mount_drive(d.device);
    }

    function unmountDrive(d) {
        if (!d)
            return;
        if (core.busy)
            return;
        core.unmount_drive(d.device);
    }

    // Paths currently cut to the clipboard (dimmed in the views).
    property var cutSet: ({})

    readonly property bool isAuxView: activeView === "settings" || activeView === "pc"
    readonly property bool anyModalOpen: inputModal.visible || propsDialog.visible || conflictDialog.visible
        || passwordModal.visible || quickLook.visible || commandModal.visible || batchRename.visible
        || confirmDialog.visible || patternModal.visible || placeEdit.visible || customizePlaces.visible
        || smbDialog.visible
        || window.isEditingPath
    readonly property bool gridKeyboardReady: activeView === "files" && !searchInput.activeFocus
        && !sidebar.keyboardHasFocus
        && !newTabToolbarButton.activeFocus && !newWindowToolbarButton.activeFocus
        && !pathInput.activeFocus && !anyModalOpen && !!activePane && activePane.renamingPath === ""
    // helpers used by the panes and dialogs

    function toast(kind, text) {
        toastItem.show(kind, text);
    }

    function openSmbEditor(profile) {
        var p = profile || {};
        smbDialog.editingId = p.profile_id || p.id || "";
        smbNameField.text = p.name || p.label || "";
        smbServerField.text = p.server || "";
        smbShareField.text = p.share || "";
        smbUserField.text = p.username || "";
        smbDomainField.text = p.domain || "";
        smbDialog.open();
    }

    function removeSmbShare(id, label) {
        confirmDialog.ask(qsTr("Remove “%1”?").arg(label || qsTr("this share")),
            qsTr("Any password Loaf saved will also be removed from the keyring."),
            qsTr("Remove"), function() { core.remove_smb_profile(id); });
    }

    function systemIcon(name) {
        var source = theme.iconSource === "adwaita" ? "adwaita"
                   : theme.iconSource === "custom" ? theme.customIconTheme
                   : "system";
        return core.resolve_icon(source, name);
    }

    function urlsToPaths(urls) {
        return pane0.urlsToPaths(urls);
    }

    function defocusInputs() {
        if (searchInput.activeFocus)
            searchInput.focus = false;
        if (isEditingPath)
            isEditingPath = false;
        globalKeyHandler.forceActiveFocus();
    }

    function showFiles() {
        if (activeView === "files")
            return;
        activeView = "files";
        // The tab has to forget it was a PC / Settings tab, otherwise the
        // sidebar keeps finding "the tab that shows This PC" and switching to
        // it does nothing once you have navigated away from it.
        var t = tabs[currentTab];
        if (t && t.view !== "files") {
            t.view = "files";
            tabsChanged();
        }
    }

    function setActivePane(p) {
        if (activePane !== p) {
            activePane = p;
            tabs[currentTab].active = (p === pane0) ? 0 : 1;
        }
    }

    function refreshCutSet() {
        var c = nativeBridge.clipboardFiles();
        var s = {};
        if (c.cut) {
            for (var i = 0; i < c.paths.length; ++i)
                s[c.paths[i]] = true;
        }
        cutSet = s;
    }

    Connections {
        target: nativeBridge
        function onClipboardChanged() {
            window.mtpClipboardPaths = [];
            window.mtpClipboardCut = false;
            window.refreshCutSet();
        }
        function onMtpDevicesChanged() {
            core.load_drives();
            if (pane0.engine.location_kind === "mtp") pane0.engine.refresh();
            if (pane1Loader.item && pane1Loader.item.engine.location_kind === "mtp") pane1Loader.item.engine.refresh();
        }
        function onOpenRequested(paths, mode) { window.handleOpenRequest(paths, mode); }
    }

    // Opens an item from a view: folders navigate, archives open as
    // folders when browsing is enabled, files launch their app.
    function openItem(pane, item) {
        if (!item || !item.path)
            return;
        if (item.is_dir) {
            var openMode = theme.openFolderMode || "current";
            if (openMode === "tab") {
                window.newTab(item.path);
            } else if (openMode === "split") {
                if (!window.splitView) {
                    // Keep the folder the user is browsing on the left and show
                    // the new directory in the freshly created right pane.
                    window.toggleSplit(item.path);
                } else {
                    pane.engine.set_path(item.path);
                }
            } else {
                pane.engine.set_path(item.path);
            }
            showFiles();
        } else if (pane.engine.location_kind === "mtp") {
            core.open_item(item.path);
        } else if (pane.engine.location_kind === "trash") {
            quickLook.showFor(item.path);
        } else if (theme.browseArchives && core.is_archive_file(item.path)) {
            pane.engine.set_path("archive://" + item.path + "#");
        } else {
            core.open_item(item.path);
        }
    }

    function selectedPaths() {
        return activePane.selectedPaths();
    }

    function copySelection(cut) {
        var paths = selectedPaths();
        if (paths.length === 0 || engine.location_kind === "archive" || engine.location_kind === "trash")
            return;
        if (engine.location_kind === "mtp") {
            if (cut && engine.read_only) return;
            nativeBridge.setClipboardFiles(paths, cut);
            mtpClipboardPaths = paths.slice();
            mtpClipboardCut = cut;
            var selected = {};
            if (cut) paths.forEach(function(path) { selected[path] = true; });
            cutSet = selected;
            toast("info", qsTr("%1 phone items copied to Loaf's clipboard").arg(paths.length));
            return;
        }
        nativeBridge.setClipboardFiles(paths, cut);
        toast("info", cut ? theme.plural(paths.length, qsTr("1 item cut"), qsTr("%1 items cut")) : theme.plural(paths.length, qsTr("1 item copied"), qsTr("%1 items copied")));
    }

    function copyPathOfSelection() {
        var paths = selectedPaths();
        if (paths.length === 0)
            paths = [engine.current_path];
        nativeBridge.setClipboardText(paths.join("\n"));
        toast("info", qsTr("Path copied"));
    }

    function pasteInto(dest) {
        if (mtpClipboardPaths.length > 0) {
            transfer(mtpClipboardPaths.slice(), dest, mtpClipboardCut ? "move" : "copy", mtpClipboardCut);
            return;
        }
        var c = nativeBridge.clipboardFiles();
        if (!c.paths || c.paths.length === 0 || !dest)
            return;
        transfer(c.paths, dest, c.cut ? "move" : "copy", c.cut);
    }

    function afterCutPaste() {
        nativeBridge.clearClipboardIfOurs();
    }

    // Starts a copy/move, asking first when names clash. `fromCut` is set
    // only when pasting a cut, which is when the clipboard gets used up.
    function transfer(paths, dest, mode, fromCut) {
        if (dest.indexOf("mtp:") === 0 || paths.some(function(path) { return path.indexOf("mtp:") === 0; })) {
            core.transfer(JSON.stringify(paths), dest, mode, "rename");
            return;
        }
        var conflicts = JSON.parse(core.check_conflicts(JSON.stringify(paths), dest) || "[]");
        if (conflicts.length > 0) {
            conflictDialog.showFor(conflicts, paths, dest, mode, !!fromCut);
            return;
        }
        core.transfer(JSON.stringify(paths), dest, mode, "rename");
        if (fromCut)
            afterCutPaste();
    }

    function handleDrop(paths, destDir, asCopy) {
        if (!destDir || paths.length === 0)
            return;
        transfer(paths, destDir, asCopy ? "copy" : "move");
    }

    function trashSelection() {
        var paths = selectedPaths();
        if (paths.length === 0)
            return;
        if (engine.location_kind === "trash") {
            deleteSelection();
            return;
        }
        if (engine.location_kind === "mtp") {
            window.deleteSelection();
            return;
        }
        if (engine.location_kind === "archive")
            return;
        core.trash_items(JSON.stringify(paths));
        activePane.clearSelection();
    }

    function deleteSelection() {
        var paths = selectedPaths();
        if (paths.length === 0 || engine.location_kind === "archive" || (engine.location_kind === "mtp" && engine.read_only))
            return;
        var pane = activePane;
        confirmDialog.ask(
            paths.length === 1 ? qsTr("Permanently delete “%1”?").arg(paths[0].split("/").pop())
                               : qsTr("Permanently delete %1 items?").arg(paths.length),
            qsTr("Deleted items can't be restored."),
            qsTr("Delete"),
            function() { core.delete_items(JSON.stringify(paths)); pane.clearSelection(); });
    }

    function showProperties(paths) {
        if (paths.some(function(path) { return path.indexOf("mtp:") === 0; }))
            return;
        if (paths.length > 0)
            propsDialog.showFor(paths);
    }

    function startNewFolder() {
        if (engine.location_kind !== "dir" && !(engine.location_kind === "mtp" && !engine.read_only))
            return;
        inputModal.showNewFolder();
    }

    function previewItem(path) {
        if (path.indexOf("mtp:") === 0) core.preview_mtp(path);
        else quickLook.showFor(path);
    }

    function toggleQuickLook() {
        if (quickLook.visible) {
            quickLook.close();
            return;
        }
        var paths = selectedPaths();
        if (paths.length > 0)
            window.previewItem(activePane.cursorPath || paths[paths.length - 1]);
    }
    function saveCurrentTab() {
        var t = tabs[currentTab];
        if (!t) return;
        t.view = window.activeView;
        t.states = [pane0.engine.get_state(), splitView && pane1Loader.item ? pane1Loader.item.engine.get_state() : (t.states[1] || "")];
        t.split = splitView;
        t.active = activePane === pane0 ? 0 : 1;
        if (window.activeView === "settings")
            t.title = qsTr("Settings");
        else if (window.activeView === "pc")
            t.title = core.hostname || qsTr("This PC");
        else
            t.title = engine.current_dir_name;
    }

    function restoreTab(i) {
        window.cancelDriveOpen();
        var t = tabs[i];
        if (!t) return;
        currentTab = i;
        activePane = pane0;
        pane0.clearSelection();
        pane0.renamingPath = "";
        if (pane1Loader.item) {
            pane1Loader.item.clearSelection();
            pane1Loader.item.renamingPath = "";
        }
        splitView = !!t.split;
        if (t.states && t.states[0])
            pane0.engine.restore_state(t.states[0]);
        if (t.split && t.states && t.states[1]) {
            if (pane1Loader.item)
                pane1Loader.item.engine.restore_state(t.states[1]);
            else
                splitSeedState = t.states[1];
        }
        activePane = (t.split && t.active === 1 && pane1Loader.item) ? pane1Loader.item : pane0;
        if (t.view === "settings")
            window.activeView = "settings";
        else if (t.view === "pc")
            window.activeView = "pc";
        else
            showFiles();
    }

    function switchTab(i) {
        if (i === currentTab || i < 0 || i >= tabs.length)
            return;
        saveCurrentTab();
        restoreTab(i);
        tabsChanged();
    }

    // "Downloads" from a saved pane state (for tabs not shown yet).
    function titleFromState(stateJson) {
        try {
            var loc = JSON.parse(stateJson).location || "";
            if (loc.indexOf("trash:") === 0)
                return qsTr("Trash");
            if (loc.indexOf("recent:") === 0)
                return qsTr("Recent");
            if (loc.indexOf("starred:") === 0)
                return qsTr("Starred");
            if (loc === core.user_dir("HOME"))
                return qsTr("Home");
            if (loc.indexOf("archive://") === 0)
                loc = loc.substring(10).split("#")[0];
            var parts = loc.split("/").filter(function(p) { return p.length > 0; });
            return parts.length > 0 ? parts[parts.length - 1] : "/";
        } catch (e) {
            return "";
        }
    }

    function newTab(path) {
        saveCurrentTab();
        var isSettings = path === "settings://";
        var isPc = path === "pc://";
        var target = (isSettings || isPc) ? "" : (path || core.user_dir("HOME"));
        var list = tabs.slice();
        var state = JSON.stringify({ location: target, back: [], forward: [] });
        var title = isSettings ? qsTr("Settings") : (isPc ? (core.hostname || qsTr("This PC")) : titleFromState(state));
        list.splice(currentTab + 1, 0, {
            states: [state, ""],
            split: false,
            active: 0,
            title: title,
            view: isSettings ? "settings" : (isPc ? "pc" : "files")
        });
        tabs = list;
        restoreTab(currentTab + 1);
    }

    // Records what the tab on screen is showing. Without this the strip (and a
    // later switch back) thinks a tab still shows whatever it showed first.
    function markCurrentTab(view, title) {
        var t = tabs[currentTab];
        if (!t)
            return;
        if (t.view === view && t.title === title)
            return;
        t.view = view;
        t.title = title;
        tabsChanged();
    }

    // This PC and Settings take over the current tab instead of stacking a new
    // one on every click. If one of them is already open in another tab, jump
    // there instead.
    function openPc() {
        if (activeView === "pc")
            return;
        for (var p = 0; p < tabs.length; ++p) {
            if (p !== currentTab && tabs[p] && tabs[p].view === "pc") {
                switchTab(p);
                return;
            }
        }
        activeView = "pc";
        markCurrentTab("pc", core.hostname || qsTr("This PC"));
    }

    function openSettings() {
        if (activeView === "settings") {
            showFiles();
            return;
        }
        for (var p = 0; p < tabs.length; ++p) {
            if (p !== currentTab && tabs[p] && tabs[p].view === "settings") {
                switchTab(p);
                return;
            }
        }
        activeView = "settings";
        markCurrentTab("settings", qsTr("Settings"));
    }

    function openInNewTab(path) {
        newTab(path);
    }

    function closeTab(i) {
        if (tabs.length <= 1) {
            window.close();
            return;
        }
        if (i === currentTab) {
            var list = tabs.slice();
            list.splice(i, 1);
            tabs = list;
            restoreTab(Math.min(i, tabs.length - 1));
        } else {
            saveCurrentTab();
            var l2 = tabs.slice();
            l2.splice(i, 1);
            tabs = l2;
            if (i < currentTab)
                currentTab -= 1;
        }
    }

    property string splitSeedPath: ""
    // Saved state for the right pane, applied when its Loader creates the item.
    property string splitSeedState: ""

    function seedSplit() {
        if (!pane1Loader.item)
            return;
        if (splitSeedState !== "") {
            var st = splitSeedState;
            splitSeedState = "";
            pane1Loader.item.engine.restore_state(st);
            return;
        }
        if (splitSeedPath === "")
            return;
        var p = splitSeedPath;
        splitSeedPath = "";
        pane1Loader.item.engine.set_path(p);
        activePane = pane1Loader.item;
    }

    function toggleSplit(seedPath) {
        if (window.activeView !== "files")
            return;
        if (splitView) {
            activePane = pane0;
            splitView = false;
            splitSeedPath = "";
            return;
        }
        splitSeedPath = (typeof seedPath === "string" && seedPath.length > 0)
            ? seedPath
            : (engine.location_kind === "dir" ? engine.current_path : core.user_dir("HOME"));
        splitView = true;
        seedSplit();
    }

    function saveSession() {
        saveCurrentTab();
        var session = {
            tabs: tabs.map(function(t) { return { states: t.states, split: t.split, active: t.active }; }),
            current: currentTab,
            width: window.width,
            height: window.height,
            maximized: window.visibility === Window.Maximized,
            sidebar: sidebar.expanded
        };
        core.set_setting("session", JSON.stringify(session));
    }

    // geometryOnly: started with explicit paths, so open just those.
    function restoreSession(geometryOnly) {
        if (core.get_setting("restoreSession") === "false" || nativeBridge.isAdmin)
            return false;
        var raw = core.get_setting("session");
        if (!raw)
            return false;
        try {
            var s = JSON.parse(raw);
            if (s.width > 300 && s.height > 200) {
                window.width = s.width;
                window.height = s.height;
            }
            if (s.maximized)
                window.showMaximized();
            sidebar.expanded = s.sidebar === true;
            if (!geometryOnly && s.tabs && s.tabs.length > 0) {
                tabs = s.tabs.map(function(t) { return { states: t.states || ["", ""], split: !!t.split, active: t.active || 0, title: window.titleFromState(t.states ? t.states[0] : "") }; });
                restoreTab(Math.max(0, Math.min(s.current || 0, tabs.length - 1)));
                return true;
            }
        } catch (e) {
            console.warn("loaf: could not restore session: " + e);
        }
        return false;
    }

    // Paths from the command line or D-Bus (another `loaf`, a browser's
    // "Show in folder", ...).
    function handleOpenRequest(paths, mode) {
        if (mode === "window" || paths.length === 0) {
            window.raise();
            window.requestActivate();
            if (mode === "window")
                newTab(core.user_dir("HOME"));
            return;
        }
        // Group by folder so several files in one folder end up selected
        // together in a single view.
        var dirs = [];
        var picks = {};
        var props = [];
        for (var i = 0; i < paths.length; ++i) {
            var p = paths[i];
            if (p.indexOf("mtp://") === 0) {
                if (mode !== "properties" && mode !== "select") newTab(p);
                continue;
            }
            var info = JSON.parse(core.get_item_info(p) || "{}");
            if (!info.exists)
                continue;
            if (mode === "properties") {
                props.push(p);
                continue;
            }
            var dir = (info.is_dir && mode !== "select") ? p : (info.parent || "/");
            if (!picks[dir]) {
                picks[dir] = [];
                dirs.push(dir);
            }
            if (dir !== p)
                picks[dir].push(p);
        }
        if (props.length > 0)
            showProperties(props);
        for (var j = 0; j < dirs.length; ++j) {
            var d = dirs[j];
            if (activeView === "files" && engine.current_path === d) {
                // Already showing that folder: just select the items.
                if (picks[d].length > 0)
                    activePane.selectPaths(picks[d]);
            } else {
                newTab(d);
                if (picks[d].length > 0)
                    activePane.pendingSelect = picks[d];
            }
        }
        window.raise();
        window.requestActivate();
    }

    onClosing: saveSession()

    Component.onCompleted: {
        refreshCutSet();
        var pending = nativeBridge.takePendingOpen();
        var restored = restoreSession(pending.length > 0);
        if (nativeBridge.startupMode === "mini") {
            sidebar.expanded = false;
            theme.zoomIndex = 1;
        }
        var first = !restored;
        for (var i = 0; i < pending.length; ++i) {
            var p = pending[i];
            if (p.indexOf("mtp://") === 0) {
                if (first) { pane0.engine.set_path(p); first = false; }
                else newTab(p);
                continue;
            }
            var info = JSON.parse(core.get_item_info(p) || "{}");
            if (!info.exists)
                continue;
            var dir = info.is_dir ? p : info.parent;
            if (first) {
                pane0.engine.set_path(dir);
                first = false;
            } else {
                newTab(dir);
            }
            if (!info.is_dir)
                activePane.pendingSelect = [p];
        }
        globalKeyHandler.forceActiveFocus();
    }
    Shortcut { sequences: [StandardKey.Undo]; enabled: core.can_undo && !window.anyModalOpen && !searchInput.activeFocus; onActivated: core.undo() }
    Shortcut { sequences: ["Ctrl+Y", "Ctrl+Shift+Z"]; enabled: core.can_redo && !window.anyModalOpen && !searchInput.activeFocus; onActivated: core.redo() }
    Shortcut { sequence: "Ctrl+C"; enabled: window.gridKeyboardReady; onActivated: window.copySelection(false) }
    Shortcut { sequence: "Ctrl+X"; enabled: window.gridKeyboardReady; onActivated: window.copySelection(true) }
    Shortcut { sequence: "Ctrl+V"; enabled: window.gridKeyboardReady && (engine.location_kind === "dir" || (engine.location_kind === "mtp" && !engine.read_only)); onActivated: window.pasteInto(engine.current_path) }
    Shortcut { sequence: "Ctrl+A"; enabled: window.gridKeyboardReady; onActivated: window.activePane.selectAll() }
    Shortcut { sequence: "Ctrl+Shift+I"; enabled: window.gridKeyboardReady; onActivated: window.activePane.invertSelection() }
    Shortcut { sequence: "Ctrl+S"; enabled: window.gridKeyboardReady; onActivated: patternModal.openFor() }
    Shortcut { sequence: "Ctrl+H"; onActivated: engine.toggle_show_hidden() }
    Shortcut { sequences: ["Ctrl+L", "Alt+D"]; onActivated: window.startEditingPath() }
    Shortcut { sequence: "Ctrl+F"; onActivated: { window.showFiles(); searchInput.forceActiveFocus(); searchInput.selectAll(); } }
    Shortcut {
        sequence: "F2"
        enabled: window.gridKeyboardReady && (engine.location_kind !== "mtp" || (!engine.read_only && window.selectedPaths().length === 1))
        onActivated: {
            if (window.selectedPaths().length > 1)
                batchRename.showFor(window.activePane.selectedItems());
            else
                window.activePane.startRename();
        }
    }
    Shortcut { sequence: "Space"; enabled: quickLook.visible || window.gridKeyboardReady; onActivated: window.toggleQuickLook() }
    Shortcut { sequence: "Delete"; enabled: window.gridKeyboardReady; onActivated: window.trashSelection() }
    Shortcut { sequence: "Shift+Delete"; enabled: window.gridKeyboardReady; onActivated: window.deleteSelection() }
    Shortcut {
        sequences: ["Alt+Left", StandardKey.Back]
        enabled: !window.anyModalOpen && (engine.can_go_back || window.isAuxView || engine.is_searching_everywhere)
        onActivated: {
            if (engine.is_searching_everywhere) {
                engine.clear_search();
                searchInput.text = "";
            } else if (window.isAuxView) {
                window.showFiles();
            } else {
                engine.go_back();
            }
        }
    }
    Shortcut {
        sequences: ["Alt+Right", StandardKey.Forward]
        enabled: !window.anyModalOpen && engine.can_go_forward && !window.isAuxView && !engine.is_searching_everywhere
        onActivated: engine.go_forward()
    }
    Shortcut { sequence: "Alt+Up"; onActivated: engine.navigate_up() }
    Shortcut { sequence: "Alt+Home"; onActivated: { window.showFiles(); engine.set_path(core.user_dir("HOME")); } }
    Shortcut { sequence: "Backspace"; enabled: window.gridKeyboardReady && engine.can_go_back; onActivated: engine.go_back() }
    Shortcut { sequences: ["F5", "Ctrl+R"]; onActivated: engine.refresh() }
    Shortcut { sequence: "Ctrl+T"; onActivated: window.newTab((engine.location_kind === "dir" || engine.location_kind === "mtp") ? engine.current_path : "") }
    Shortcut { sequence: "Ctrl+W"; onActivated: window.closeTab(window.currentTab) }
    Shortcut { sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; onActivated: window.switchTab((window.currentTab + 1) % window.tabs.length) }
    Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]; onActivated: window.switchTab((window.currentTab + window.tabs.length - 1) % window.tabs.length) }
    Shortcut { sequence: "Ctrl+N"; onActivated: core.open_new_window((engine.location_kind === "dir" || engine.location_kind === "mtp") ? engine.current_path : "") }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: !window.anyModalOpen; onActivated: window.startNewFolder() }
    Shortcut { sequence: "F3"; onActivated: window.toggleSplit() }
    Shortcut { sequence: "F9"; onActivated: sidebar.expanded = !sidebar.expanded }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++", StandardKey.ZoomIn]; onActivated: theme.stepZoom(1) }
    Shortcut { sequences: ["Ctrl+-", StandardKey.ZoomOut]; onActivated: theme.stepZoom(-1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: theme.zoomIndex = 2 }
    Shortcut { sequence: "Ctrl+1"; onActivated: engine.set_view("grid") }
    Shortcut { sequence: "Ctrl+2"; onActivated: engine.set_view("list") }
    Shortcut { sequence: "Ctrl+D"; enabled: engine.location_kind === "dir"; onActivated: core.add_bookmark(engine.current_path) }
    Shortcut { sequence: "Ctrl+Shift+C"; enabled: window.gridKeyboardReady; onActivated: window.copyPathOfSelection() }
    Shortcut {
        sequences: ["Alt+Return", "Alt+Enter"]
        enabled: window.gridKeyboardReady
        onActivated: {
            var p = window.selectedPaths();
            window.showProperties(p.length > 0 ? p : [engine.current_path]);
        }
    }
    Shortcut { sequence: "Ctrl+Q"; onActivated: window.close() }

    // Mouse back / forward buttons.
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onPressed: function(mouse) {
            if (mouse.button === Qt.BackButton && engine.can_go_back)
                engine.go_back();
            else if (mouse.button === Qt.ForwardButton && engine.can_go_forward)
                engine.go_forward();
        }
    }

    Item {
        id: globalKeyHandler
        anchors.fill: parent
        focus: true
        z: -100

        Keys.onPressed: function(event) {
            if (window.anyModalOpen)
                return;
            if (event.key === Qt.Key_Escape) {
                if (window.activePane.selectedCount > 0) {
                    window.activePane.clearSelection();
                } else if (engine.is_searching_everywhere) {
                    engine.clear_search();
                    searchInput.text = "";
                } else if (window.isAuxView) {
                    window.showFiles();
                }
                window.keyboardNavActive = false;
                event.accepted = true;
                return;
            }
            if (window.gridKeyboardReady) {
                var shift = !!(event.modifiers & Qt.ShiftModifier);
                var pane = window.activePane;
                switch (event.key) {
                case Qt.Key_Up:
                    window.keyboardNavActive = true; pane.moveSelection(0, -1, shift); event.accepted = true; return;
                case Qt.Key_Down:
                    window.keyboardNavActive = true; pane.moveSelection(0, 1, shift); event.accepted = true; return;
                case Qt.Key_Left:
                    if (!pane.isList()) { window.keyboardNavActive = true; pane.moveSelection(-1, 0, shift); event.accepted = true; return; }
                    break;
                case Qt.Key_Right:
                    if (!pane.isList()) { window.keyboardNavActive = true; pane.moveSelection(1, 0, shift); event.accepted = true; return; }
                    break;
                case Qt.Key_Home:
                    window.keyboardNavActive = true; pane.selectRow(0, false, shift); pane.ensureVisible(0); event.accepted = true; return;
                case Qt.Key_End:
                    window.keyboardNavActive = true;
                    pane.selectRow(engine.item_count - 1, false, shift);
                    pane.ensureVisible(engine.item_count - 1);
                    event.accepted = true;
                    return;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    pane.openSelected(); event.accepted = true; return;
                }
            }
            // Type to filter: printable keys go to the search box.
            if (!searchInput.activeFocus && window.activeView === "files"
                    && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                    && event.text.length > 0 && event.text.charCodeAt(0) > 32 && event.key !== Qt.Key_Delete) {
                searchInput.forceActiveFocus();
                searchInput.text = event.text;
                searchInput.cursorPosition = searchInput.text.length;
                event.accepted = true;
            }
        }
    }

    LoafCore {
        id: core
        onDrives_jsonChanged: {
            if (window.pendingMountDevice.length > 0) {
                var drives = JSON.parse(core.drives_json || "[]");
                var present = drives.some(function(d) {
                    return d.device === window.pendingMountDevice || d.crypt_device === window.pendingMountDevice;
                });
                if (!present)
                    window.cancelDriveOpen();
            }
        }
        onNotify: function(kind, text) { window.toast(kind, text); }
        onMtp_preview_ready: function(path) { quickLook.showFor(path); }
        onOperation_finished: function(kind, ok, resultJson) {
            var r = null;
            try { r = JSON.parse(resultJson); } catch (e) { r = null; }
            if (kind === "trash" && r && r.failed && r.failed.length > 0) {
                var failed = r.failed;
                confirmDialog.ask(qsTr("Can't move to the trash"),
                    theme.plural(failed.length, qsTr("1 item can't be put in the trash on this drive. Delete it permanently instead?"), qsTr("%1 items can't be put in the trash on this drive. Delete them permanently instead?")),
                    qsTr("Delete Permanently"),
                    function() { core.delete_items(JSON.stringify(failed)); });
            }
            if (r && r.reload_drives)
                core.load_drives();
            if (r && r.mtp) {
                pane0.engine.refresh();
                if (pane1Loader.item) pane1Loader.item.engine.refresh();
                if (ok && r.mode === "move") {
                    var clip = nativeBridge.clipboardFiles();
                    if (clip.cut && JSON.stringify(clip.paths) === JSON.stringify(r.sources)) nativeBridge.clearClipboardIfOurs();
                }
                if (ok && r.mode === "move" && JSON.stringify(r.sources) === JSON.stringify(window.mtpClipboardPaths)) {
                    window.mtpClipboardPaths = [];
                    window.mtpClipboardCut = false;
                    window.cutSet = {};
                }
            }
            if (kind === "drive") {
                if (r && (r.action === "mount" || r.action === "unlock")
                        && window.pendingMountDevice.length > 0 && r.device === window.pendingMountDevice) {
                    // A wrong password reopens the existing prompt; retain the
                    // user's navigation request for the authenticated retry.
                    var retrying = !ok && r.action === "unlock" && passwordModal.visible
                        && passwordModal.request.device === r.device;
                    if (!retrying) {
                        var inNewTab = window.pendingMountInNewTab;
                        window.cancelDriveOpen();
                        if (ok && r.mount_point) {
                            if (inNewTab)
                                window.newTab(r.mount_point);
                            else {
                                window.showFiles();
                                searchInput.text = "";
                                engine.set_path(r.mount_point);
                            }
                        }
                    }
                }
            }
            if (r && r.created && r.created.length > 0) {
                // Select what was just created in the pane showing its folder.
                var parent = r.created[0].substring(0, r.created[0].lastIndexOf("/"));
                if (window.activePane.engine.current_path === parent)
                    window.activePane.pendingSelect = r.created;
            }
            // Views that aren't watched directly (trash on other drives,
            // recent, starred) refresh after operations.
            var kinds = pane1Loader.item ? [pane0, pane1Loader.item] : [pane0];
            for (var i = 0; i < kinds.length; ++i) {
                var lk = kinds[i].engine.location_kind;
                if (lk !== "dir" && lk !== "search")
                    kinds[i].engine.refresh();
            }
        }
        onPassword_required: function(json) { passwordModal.openFor(JSON.parse(json)); }
        onSmb_mounted: function(profileId, path) {
            window.showFiles();
            searchInput.text = "";
            engine.set_path(path);
        }
        onShare_link_ready: function(shareId, url) {
            nativeBridge.setClipboardText(url);
            window.toast("info", qsTr("Share link copied to clipboard!"));
        }
        onShare_link_error: function(message) {
            window.toast("error", qsTr("Could not share via link: ") + message);
        }
        onStarred_changed: {
            pane0.engine.reload_starred();
            if (pane1Loader.item)
                pane1Loader.item.engine.reload_starred();
        }
    }

    Theme {
        id: theme
        // Archives open like folders on double click.
        property bool browseArchives: true
    }

    FontLoader { source: "qrc:/loaf/fonts/Phosphor.ttf" }
    FontLoader { source: "qrc:/loaf/fonts/Phosphor-Bold.ttf" }

    // Decorative background blobs (skipped in low-power mode, when background is translucent, or when disabled).
    Item {
        anchors.fill: parent
        visible: !theme.lowPower && theme.showBackgroundShapes && theme.effectiveBackgroundOpacity >= 0.98
        Rectangle {
            width: 420; height: 220; radius: 200; x: -40; y: -50
            color: theme.primaryContainer
            opacity: theme.isDark ? 0.22 : 0.35
        }
        Rectangle {
            width: 380; height: 380; radius: 190
            x: parent.width - 280; y: parent.height - 300
            color: theme.secondaryContainer
            opacity: theme.isDark ? 0.18 : 0.28
        }
    }

    // The settings tab is part of the URL: settings://behavior and friends.
    function settingsUrl() {
        var slugs = ["interface", "behavior", "accessibility", "experimental", "about", "share", "network"];
        return "settings://" + (slugs[settingsView.activeTab] || slugs[0]);
    }

    function settingsTabName() {
        var names = [qsTr("Interface"), qsTr("Behavior"), qsTr("Accessibility"),
                     qsTr("Experimental"), qsTr("About Loaf"), qsTr("Share"), qsTr("Network")];
        return names[settingsView.activeTab] || names[0];
    }

    function startEditingPath() {
        pathInput.text = window.activeView === "pc" ? "pc://"
            : (window.activeView === "settings" ? window.settingsUrl()
            : ((engine.location_kind === "dir" || engine.location_kind === "mtp") ? engine.current_path : ""));
        isEditingPath = true;
        pathInput.forceActiveFocus();
        pathInput.selectAll();
    }

    function commitPathEdit() {
        var raw = pathInput.text.trim();
        isEditingPath = false;
        if (raw.length === 0) {
            globalKeyHandler.forceActiveFocus();
            return;
        }
        if (raw === "pc" || raw === "pc://" || raw === "pc:///" || raw === "thispc://" || raw === "computer:///") {
            window.activeView = "pc";
            window.markCurrentTab("pc", core.hostname || qsTr("This PC"));
        } else if (raw === "settings" || raw.indexOf("settings://") === 0) {
            window.activeView = "settings";
            window.markCurrentTab("settings", qsTr("Settings"));
            if (raw === "settings://behavior") settingsView.activeTab = 1;
            else if (raw === "settings://accessibility") settingsView.activeTab = 2;
            else if (raw === "settings://experimental") settingsView.activeTab = 3;
            else if (raw === "settings://about") settingsView.activeTab = 4;
            else if (raw === "settings://share") settingsView.activeTab = 5;
            else if (raw === "settings://network") settingsView.activeTab = 6;
            else settingsView.activeTab = 0;
        } else {
            showFiles();
            engine.set_path(raw);
        }
        globalKeyHandler.forceActiveFocus();
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        z: 1
        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.topMargin: 14
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: window.width < 760 ? 8 : 10

            Rectangle {
                id: adminBadge
                visible: nativeBridge.isAdmin
                Layout.preferredWidth: adminRow.implicitWidth + 24
                Layout.preferredHeight: 42
                radius: theme.radiusFull
                color: theme.dangerContainer
                RowLayout {
                    id: adminRow
                    anchors.centerIn: parent
                    spacing: 8
                    LoafIcon { name: "shield-check"; size: 18; color: theme.danger }
                    Text { text: qsTr("Admin"); color: theme.danger; font.pixelSize: theme.fs(14); font.bold: true }
                }
            }
            Rectangle {
                id: navChip
                Layout.preferredHeight: 42
                radius: theme.radiusFull
                color: theme.surfaceContainer
                readonly property bool canBack: engine.can_go_back || window.isAuxView || engine.is_searching_everywhere
                readonly property bool canForward: engine.can_go_forward && !window.isAuxView && !engine.is_searching_everywhere
                readonly property bool showBack: theme.toolbarOperations !== "hidden"
                readonly property bool showForward: theme.toolbarOperations === "always"
                    || (theme.toolbarOperations === "auto" && canForward)
                visible: showBack || showForward
                Layout.preferredWidth: (showBack && showForward) ? 82 : 44
                Layout.minimumWidth: (showBack && showForward) ? 82 : 44
                opacity: (canBack || canForward) ? 1.0 : 0.45

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    TopIconButton {
                        visible: navChip.showBack
                        iconName: "caret-left"
                        systemIcon: "go-previous-symbolic"
                        enabled: navChip.canBack
                        accessibleName: qsTr("Back")
                        onClicked: {
                            if (engine.is_searching_everywhere) {
                                engine.clear_search();
                                searchInput.text = "";
                            } else if (window.isAuxView) {
                                window.showFiles();
                            } else {
                                engine.go_back();
                            }
                        }
                    }
                    TopIconButton {
                        visible: navChip.showForward
                        enabled: navChip.canForward
                        iconName: "caret-right"
                        systemIcon: "go-next-symbolic"
                        accessibleName: qsTr("Forward")
                        onClicked: engine.go_forward()
                    }
                }
            }

            Rectangle {
                id: windowTabsChip
                visible: theme.showNewTabButton || theme.showNewWindowButton
                Layout.preferredHeight: 42
                Layout.preferredWidth: (theme.showNewTabButton && theme.showNewWindowButton) ? 82 : 44
                Layout.minimumWidth: Layout.preferredWidth
                radius: theme.radiusFull
                color: theme.surfaceContainer

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    TopIconButton {
                        id: newTabToolbarButton
                        visible: theme.showNewTabButton
                        iconName: "tabs"
                        systemIcon: "tab-new-symbolic"
                        accessibleName: qsTr("New tab (Ctrl+T)")
                        activeFocusOnTab: true
                        Keys.onSpacePressed: clicked()
                        Keys.onReturnPressed: clicked()
                        Keys.onEnterPressed: clicked()
                        onClicked: window.newTab((engine.location_kind === "dir" || engine.location_kind === "mtp") ? engine.current_path : "")
                    }
                    TopIconButton {
                        id: newWindowToolbarButton
                        visible: theme.showNewWindowButton
                        iconName: "app-window"
                        systemIcon: "window-new-symbolic"
                        accessibleName: qsTr("New window (Ctrl+N)")
                        activeFocusOnTab: true
                        Keys.onSpacePressed: clicked()
                        Keys.onReturnPressed: clicked()
                        Keys.onEnterPressed: clicked()
                        onClicked: core.open_new_window((engine.location_kind === "dir" || engine.location_kind === "mtp") ? engine.current_path : "")
                    }
                }
            }

            // Path bar: breadcrumbs, or a text field (Ctrl+L) with Tab completion.
            Rectangle {
                id: pathBar
                Layout.fillWidth: true
                Layout.minimumWidth: 140
                Layout.preferredHeight: 42
                radius: theme.radiusFull
                color: window.isEditingPath ? theme.surfaceContainerHighest : theme.surfaceContainer
                clip: true

                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: window.startEditingPath()
                    onClicked: window.defocusInputs()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 6
                    spacing: 8
                    visible: window.isEditingPath || (window.activeView === "files" && theme.pathBarMode === "text")

                    LoafIcon { name: "folder"; size: 16; color: theme.primary }
                    TextInput {
                        id: pathInput
                        Layout.fillWidth: true
                        visible: window.isEditingPath
                        color: theme.textMain
                        font.pixelSize: theme.fs(13)
                        font.family: "monospace"
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        Accessible.role: Accessible.EditableText
                        Accessible.name: qsTr("Location")
                        Keys.onReturnPressed: window.commitPathEdit()
                        Keys.onEnterPressed: window.commitPathEdit()
                        Keys.onEscapePressed: { window.isEditingPath = false; globalKeyHandler.forceActiveFocus(); }
                        Keys.onTabPressed: function(event) {
                            var done = core.complete_path(text, engine.show_hidden);
                            if (done !== text) {
                                text = done;
                                cursorPosition = text.length;
                            }
                            event.accepted = true;
                        }
                        onActiveFocusChanged: if (!activeFocus && window.isEditingPath) window.isEditingPath = false
                    }
                    // Read-only path mirror for "text only" mode.
                    Text {
                        visible: !window.isEditingPath
                        Layout.fillWidth: true
                        text: window.activeView === "pc"
                            ? "pc://"
                            : (engine.location_kind === "dir" || engine.location_kind === "archive" || engine.location_kind === "mtp"
                                ? engine.current_path : engine.location_kind + "://")
                        color: theme.textMain
                        font.pixelSize: theme.fs(13)
                        font.family: "monospace"
                        elide: Text.ElideMiddle
                        verticalAlignment: Text.AlignVCenter
                        Accessible.role: Accessible.StaticText
                        Accessible.name: qsTr("Current location")
                    }
                    TopIconButton {
                        visible: window.isEditingPath
                        iconName: "check"
                        accessibleName: qsTr("Go")
                        onClicked: window.commitPathEdit()
                    }
                }

                ListView {
                    id: breadcrumbs
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    orientation: ListView.Horizontal
                    spacing: 4
                    clip: true
                    visible: !window.isEditingPath && window.activeView === "files" && theme.pathBarMode !== "text"
                    model: JSON.parse(engine.breadcrumbs_json || "[]")
                    onCountChanged: Qt.callLater(positionViewAtEnd)
                    interactive: contentWidth > width
                    boundsBehavior: Flickable.StopAtBounds

                    add: Transition {
                        enabled: theme.animate
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "scale"; from: 0.8; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                        }
                    }
                    displaced: Transition {
                        enabled: theme.animate
                        NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
                    }

                    delegate: RowLayout {
                        id: crumbDelegate
                        required property var modelData
                        required property int index
                        height: breadcrumbs.height
                        spacing: 4

                        Item {
                            id: chip
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: chipRow.implicitWidth + 22
                            readonly property var nextCrumb: breadcrumbs.model[crumbDelegate.index + 1]
                            readonly property bool isCurrent: !crumbDelegate.modelData.is_forward && (!nextCrumb || nextCrumb.is_forward)
                            readonly property bool dropHover: chipDrop.containsDrag
                            Accessible.role: Accessible.Button
                            Accessible.name: crumbDelegate.modelData.name

                            Rectangle {
                                anchors.fill: parent
                                radius: theme.radiusFull
                                color: chip.dropHover ? theme.primaryContainer
                                    : (crumbDelegate.modelData.is_forward ? "transparent" : (chip.isCurrent ? theme.secondaryContainer : theme.hoverOverlay))
                                border.color: chip.dropHover ? theme.primary : (crumbDelegate.modelData.is_forward ? theme.outline : "transparent")
                                border.width: (chip.dropHover || crumbDelegate.modelData.is_forward) ? 1 : 0
                                opacity: (chip.dropHover || chip.isCurrent || crumbDelegate.modelData.is_forward || chipMouse.containsMouse) ? 1.0 : 0.0
                                Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
                            }

                            DropArea {
                                id: chipDrop
                                anchors.fill: parent
                                enabled: crumbDelegate.modelData.path.indexOf("/") === 0
                                keys: ["text/uri-list"]
                                onDropped: function(drop) {
                                    var dest = crumbDelegate.modelData.path;
                                    var paths = window.urlsToPaths(drop.urls).filter(function(p) { return p !== dest; });
                                    if (paths.length === 0)
                                        return;
                                    var asCopy = (drop.source === dragProxy) ? dragManager.asCopy : (drop.proposedAction === Qt.CopyAction);
                                    drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                                    if (dragManager.isRmb) {
                                        var pt = chipDrop.mapToItem(window.contentItem, drop.x, drop.y);
                                        rmbDropMenu.showAt(pt.x, pt.y, paths, dest);
                                    } else {
                                        window.handleDrop(paths, dest, asCopy);
                                    }
                                }
                            }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                LoafIcon {
                                    visible: crumbDelegate.modelData.is_root_place && theme.iconSource === "phosphor"
                                    name: crumbDelegate.modelData.icon || "folder"
                                    size: 15
                                    color: chip.isCurrent ? theme.secondaryContainerFg : theme.textMain
                                }
                                Image {
                                    visible: crumbDelegate.modelData.is_root_place && theme.iconSource !== "phosphor"
                                    source: visible ? window.systemIcon(crumbDelegate.modelData.system_icon || "folder") : ""
                                    Layout.preferredWidth: 15
                                    Layout.preferredHeight: 15
                                    sourceSize.width: 32
                                    sourceSize.height: 32
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text {
                                    text: crumbDelegate.modelData.name
                                    color: crumbDelegate.modelData.is_forward ? theme.textMuted
                                        : (chip.isCurrent ? theme.secondaryContainerFg : (chipMouse.containsMouse ? theme.textMain : theme.textMuted))
                                    font.pixelSize: theme.fs(12)
                                    font.bold: chip.isCurrent
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                onClicked: function(m) {
                                    var path = crumbDelegate.modelData.path;
                                    if (m.button === Qt.MiddleButton) {
                                        window.newTab(path);
                                    } else if (m.button === Qt.RightButton) {
                                        var pt = mapToItem(window.contentItem, m.x, m.y);
                                        crumbMenu.showFor(path, pt.x, pt.y);
                                    } else {
                                        engine.set_path(path);
                                    }
                                }
                            }
                        }
                        LoafIcon {
                            visible: crumbDelegate.index < breadcrumbs.count - 1
                            name: "caret-right"
                            size: 11
                            color: theme.outline
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // PC / Settings breadcrumbs: the place, then the settings tab.
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    spacing: 6
                    visible: window.activeView !== "files" && !window.isEditingPath

                    RowLayout {
                        visible: window.activeView === "settings"
                        spacing: 6
                        LoafIcon { name: "gear"; size: 15; color: theme.textMuted }
                        Text {
                            text: qsTr("Settings")
                            color: theme.textMuted
                            font.pixelSize: theme.fs(12)
                        }
                    }
                    LoafIcon {
                        visible: window.activeView === "settings"
                        name: "caret-right"
                        size: 11
                        color: theme.outline
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Rectangle {
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: curCrumb.implicitWidth + 20
                        radius: theme.radiusFull
                        color: theme.secondaryContainer
                        RowLayout {
                            id: curCrumb
                            anchors.centerIn: parent
                            spacing: 6
                            LoafIcon {
                                visible: window.activeView === "pc"
                                name: core.device_type === "laptop" ? "laptop" : "desktop"
                                size: 15
                                color: theme.secondaryContainerFg
                            }
                            Text {
                                text: window.activeView === "pc"
                                    ? (core.hostname || qsTr("This PC"))
                                    : window.settingsTabName()
                                color: theme.secondaryContainerFg
                                font.pixelSize: theme.fs(12)
                                font.bold: true
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            // Search: typing filters this folder; the pills search below
            // this folder or the whole home folder in the background.
            Rectangle {
                id: searchBar
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                Layout.preferredWidth: (searchInput.activeFocus || engine.is_searching_everywhere)
                    ? (window.width < 900 ? 280 : 380) : (window.width < 900 ? 180 : 220)
                Layout.minimumWidth: window.width < 760 ? 80 : 120
                Layout.maximumWidth: searchBar.Layout.preferredWidth
                radius: theme.radiusFull
                color: searchInput.activeFocus ? theme.surfaceContainerHighest : theme.surfaceContainer
                border.width: searchInput.activeFocus ? 1.5 : 0
                border.color: theme.primary

                Behavior on Layout.preferredWidth { enabled: theme.animate; SpringAnimation { spring: 3.8; damping: 0.38 } }
                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }

                RowLayout {
                    id: searchRow
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 6
                    spacing: 6

                    LoafIcon {
                        name: engine.searching ? "hourglass" : "magnifying-glass"
                        size: 16
                        color: searchInput.activeFocus ? theme.primary : theme.outline
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: theme.textMain
                        font.pixelSize: theme.fs(13)
                        selectByMouse: true
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        Accessible.role: Accessible.EditableText
                        Accessible.name: qsTr("Search")

                        Text {
                            text: window.activeView === "settings" ? qsTr("Search settings…")
                                : (engine.is_searching_everywhere ? qsTr("Search…") : qsTr("Filter this folder…"))
                            color: theme.outline
                            font.pixelSize: theme.fs(13)
                            visible: !searchInput.text && !searchInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: {
                            if (window.activeView === "pc")
                                window.showFiles();
                            if (window.activeView !== "files")
                                return;
                            if (engine.is_searching_everywhere)
                                searchDebounce.restart();
                            else
                                engine.set_filter(text);
                        }
                        Keys.onEscapePressed: function(event) {
                            if (text.length > 0) {
                                text = "";
                            } else {
                                if (engine.is_searching_everywhere)
                                    engine.clear_search();
                                globalKeyHandler.forceActiveFocus();
                            }
                            event.accepted = true;
                        }
                        Keys.onDownPressed: function(event) {
                            window.keyboardNavActive = true;
                            window.activePane.moveSelection(0, 1, false);
                            globalKeyHandler.forceActiveFocus();
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: function(event) {
                            if (window.activePane.selectedCount === 0 && engine.item_count > 0)
                                window.activePane.selectRow(0, false, false);
                            window.activePane.openSelected();
                            event.accepted = true;
                        }
                    }

                    // Keep the box in step with the pane: navigating clears the
                    // filter in the backend, and each pane/tab has its own.
                    function syncSearchBox() {
                        if (window.activeView !== "files")
                            return;
                        var want = engine.is_searching_everywhere ? engine.search_query : engine.filter_text;
                        if (searchInput.text !== want)
                            searchInput.text = want;
                    }
                    Connections {
                        target: window.engine
                        function onFilter_textChanged() { if (!window.engine.is_searching_everywhere) searchRow.syncSearchBox(); }
                        function onCurrent_pathChanged() { if (!window.engine.is_searching_everywhere) searchRow.syncSearchBox(); }
                    }
                    Connections {
                        target: window
                        function onActivePaneChanged() { searchRow.syncSearchBox(); }
                    }

                    Timer {
                        id: searchDebounce
                        interval: 250
                        onTriggered: {
                            if (searchInput.text.trim().length > 0)
                                engine.search(searchInput.text, window.searchScope, theme.searchContents);
                        }
                    }
                    TopIconButton {
                        id: searchSettingsBtn
                        visible: window.activeView === "files"
                        iconName: "sliders-horizontal"
                        small: true
                        accessibleName: qsTr("Search settings")
                        onClicked: {
                            var p = mapToItem(window.contentItem, 0, height + 4);
                            searchSettingsMenu.openAt(p.x, p.y);
                        }
                    }

                    TopIconButton {
                        visible: engine.is_searching_everywhere || searchInput.text.length > 0
                        iconName: "x"
                        small: true
                        accessibleName: qsTr("Clear search")
                        onClicked: {
                            searchInput.text = "";
                            if (engine.is_searching_everywhere)
                                engine.clear_search();
                        }
                    }
                }
            }
            Rectangle {
                id: viewDropdownButton
                visible: window.activeView === "files"
                Layout.preferredHeight: 42
                Layout.preferredWidth: viewRow.implicitWidth + 20
                Layout.minimumWidth: viewRow.implicitWidth + 20
                radius: theme.radiusFull
                color: theme.surfaceContainer
                clip: true

                RowLayout {
                    id: viewRow
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: cycleMouse.containsMouse ? theme.hoverOverlay : "transparent"
                        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                        LoafIcon {
                            anchors.centerIn: parent
                            name: engine.view_mode === "list" ? "list" : "squares-four"
                            size: 16
                            color: theme.primary
                        }
                        MouseArea {
                            id: cycleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: engine.set_view(engine.view_mode === "grid" ? "list" : "grid")
                        }
                    }
                    Item {
                        implicitWidth: dropRow.implicitWidth + 10
                        implicitHeight: 32

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: dropMouse.containsMouse ? theme.hoverOverlay : "transparent"
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                        }

                        RowLayout {
                            id: dropRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text { visible: window.width >= 900; text: qsTr("View"); color: theme.textMain; font.pixelSize: theme.fs(12); font.bold: true }
                            LoafIcon { name: viewMenuPopup.visible ? "caret-up" : "caret-down"; size: 11; color: theme.outline }
                        }

                        MouseArea {
                            id: dropMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (viewMenuPopup.visible) {
                                    viewMenuPopup.close();
                                } else {
                                    var pt = mapToItem(window.contentItem, viewDropdownButton.width - viewMenuPopup.width, viewDropdownButton.height + 6);
                                    viewMenuPopup.openAt(pt.x, pt.y);
                                }
                            }
                        }
                    }
                }
            }

            LoafButton {
                visible: window.activeView === "files" && engine.location_kind === "trash" && engine.item_count > 0
                text: window.width < 900 ? "" : qsTr("Empty Trash")
                icon: "trash"
                variant: "danger"
                onClicked: window.confirmEmptyTrash()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: 20
            spacing: 16

            Sidebar {
                id: sidebar
                Layout.fillHeight: true
                Layout.preferredWidth: implicitWidth
                Behavior on Layout.preferredWidth { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
                activeId: {
                    if (window.activeView === "settings")
                        return "settings";
                    if (window.activeView === "pc")
                        return "pc";
                    var kind = engine.location_kind;
                    if (kind === "trash" || kind === "recent" || kind === "starred")
                        return kind;
                    for (var i = 0; i < places.length; ++i) {
                        if (places[i].path && places[i].path === engine.current_path)
                            return places[i].id;
                    }
                    var drives = sidebar.drives || [];
                    for (var d = 0; d < drives.length; ++d) {
                        if (kind === "mtp" && drives[d].provider === "mtp" && engine.current_path.indexOf(drives[d].device) === 0)
                            return "device:" + drives[d].device;
                        if (drives[d].is_mounted && drives[d].mount_point && drives[d].mount_point === engine.current_path)
                            return "device:" + drives[d].device;
                    }
                    return "";
                }
                onPlaceClicked: function(place, inNewTab) {
                    window.cancelDriveOpen();
                    if (place.kind === "pc") {
                        if (inNewTab) {
                            window.newTab("pc://");
                            return;
                        }
                        window.openPc();
                        return;
                    }
                    if (place.kind === "smb") {
                        if (inNewTab && place.connected && place.path) {
                            window.newTab(place.path);
                            return;
                        }
                        window.showFiles();
                        searchInput.text = "";
                        if (place.connected && place.path)
                            engine.set_path(place.path);
                        else
                            core.connect_smb(place.profile_id, "", false);
                        return;
                    }
                    // Network bookmarks (remote URIs): Loaf can't
                    // browse them internally, so hand them to the system handler.
                    if (place.kind === "network") {
                        if (place.path)
                            core.open_uri(place.path);
                        return;
                    }
                    if (inNewTab && place.path) {
                        window.newTab(place.path);
                        return;
                    }
                    window.showFiles();
                    searchInput.text = "";
                    if (place.kind === "trash")
                        engine.open_trash();
                    else if (place.kind === "recent")
                        engine.open_recent();
                    else if (place.kind === "starred")
                        engine.open_starred();
                    else if (place.missing)
                        window.toast("error", qsTr("“%1” no longer exists").arg(place.path));
                    else
                        engine.set_path(place.path);
                }
                onDriveClicked: function(drive, inNewTab) {
                    window.openDrive(drive, inNewTab);
                }
                onDriveMenuRequested: function(drive, x, y) {
                    window.openDriveContextMenu(drive, x, y);
                }
                onSettingsClicked: {
                    window.openSettings();
                }
                onPlaceMenuRequested: function(place, x, y) { placeMenu.showFor(place, x, y); }
                onSidebarMenuRequested: function(x, y) { sidebarMenu.showAt(x, y); }
                Component.onCompleted: Qt.callLater(sidebar.updateHighlight)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Tab strip sits to the right of the sidebar, moving only mainStage down!
                ListView {
                    id: tabStrip
                    visible: window.tabs.length > 1
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 36 : 0
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    model: window.tabs.length
                    Accessible.role: Accessible.PageTabList

                    add: Transition {
                        enabled: theme.animate
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
                            NumberAnimation { property: "scale"; from: 0.7; to: 1.0; duration: 220; easing.type: Easing.OutBack }
                        }
                    }
                    displaced: Transition {
                        enabled: theme.animate
                        NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
                    }

                    delegate: Rectangle {
                        id: tabDelegate
                        required property int index
                        readonly property bool current: index === window.currentTab
                        readonly property bool isSplit: current ? window.splitView
                            : !!(window.tabs[index] && window.tabs[index].split)

                        readonly property string leftName: current
                            ? (window.activeView === "settings" ? qsTr("Settings") : (window.activeView === "pc" ? (core.hostname || qsTr("This PC")) : pane0.engine.current_dir_name))
                            : (window.tabs[index] ? (window.tabs[index].title || qsTr("Tab")) : "")
                        readonly property string rightName: current ? (pane1Loader.item ? pane1Loader.item.engine.current_dir_name : (window.tabs[index] ? window.tabs[index].rightTitle || qsTr("Split") : qsTr("Split")))
                            : (window.tabs[index] ? (window.tabs[index].rightTitle || qsTr("Split")) : qsTr("Split"))

                        width: isSplit
                            ? Math.min(380, Math.max(220, tabLeftLabel.implicitWidth + tabRightLabel.implicitWidth + 88))
                            : Math.min(240, Math.max(120, tabLeftLabel.implicitWidth + 84))
                        height: 34
                        radius: theme.radiusFull
                        color: current ? theme.secondaryContainer : (tabMouse.containsMouse ? theme.hoverOverlay : theme.surfaceContainer)
                        Behavior on width { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
                        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: function(m) {
                                if (m.button === Qt.MiddleButton) {
                                    window.closeTab(tabDelegate.index);
                                    return;
                                }
                                var right = tabDelegate.isSplit
                                    && mapToItem(tabDelegate, m.x, m.y).x > tabRightLabel.mapToItem(tabDelegate, 0, 0).x;
                                window.switchTab(tabDelegate.index);
                                if (right && pane1Loader.item)
                                    window.setActivePane(pane1Loader.item);
                                else
                                    window.setActivePane(pane0);
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 6
                            spacing: 6

                            LoafIcon {
                                name: tabDelegate.current
                                    ? (window.activeView === "settings" ? "gear" : (window.activeView === "pc" ? "desktop" : (tabDelegate.isSplit ? "columns" : "folder")))
                                    : (window.tabs[tabDelegate.index] && window.tabs[tabDelegate.index].view === "settings" ? "gear"
                                        : (window.tabs[tabDelegate.index] && window.tabs[tabDelegate.index].view === "pc" ? "desktop"
                                            : (tabDelegate.isSplit ? "columns" : "folder")))
                                size: 14
                                color: tabDelegate.current ? theme.secondaryContainerFg : theme.textMuted
                            }
                            Item {
                                Layout.fillWidth: true
                                height: parent.height
                                Text {
                                    id: tabLeftLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    text: tabDelegate.leftName
                                    color: tabDelegate.current ? theme.secondaryContainerFg : theme.textMain
                                    font.pixelSize: theme.fs(12)
                                    font.bold: tabDelegate.current && (!tabDelegate.isSplit || window.activePane === pane0)
                                    elide: Text.ElideRight
                                }
                            }
                            Rectangle {
                                visible: tabDelegate.isSplit
                                width: 1
                                height: 16
                                color: tabDelegate.current ? theme.secondaryContainerFg : theme.outlineVariant
                                opacity: 0.35
                            }
                            Item {
                                visible: tabDelegate.isSplit
                                Layout.fillWidth: true
                                height: parent.height
                                Text {
                                    id: tabRightLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    text: tabDelegate.rightName
                                    color: tabDelegate.current ? theme.secondaryContainerFg : theme.textMain
                                    font.pixelSize: theme.fs(12)
                                    font.bold: tabDelegate.current && tabDelegate.isSplit && pane1Loader.item && window.activePane === pane1Loader.item
                                    elide: Text.ElideRight
                                }
                            }

                            TopIconButton {
                                iconName: "x"
                                small: true
                                accessibleName: qsTr("Close tab")
                                onClicked: window.closeTab(tabDelegate.index)
                            }
                        }
                    }

                    footer: Item {
                        width: 40
                        height: 34
                        TopIconButton {
                            anchors.centerIn: parent
                            iconName: "plus"
                            accessibleName: qsTr("New tab")
                            onClicked: window.newTab((engine.location_kind === "dir" || engine.location_kind === "mtp") ? engine.current_path : "")
                        }
                    }
                }

                Item {
                    id: mainStage
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Item {
                        id: paneRow
                        anchors.fill: parent
                        visible: window.activeView === "files"
                        readonly property real gap: 14
                        // 0 = single pane, 1 = two equal panes
                        property real split: window.splitView ? 1 : 0
                        Behavior on split { enabled: theme.animate; SpringAnimation { spring: 3.6; damping: 0.4; epsilon: 0.002 } }
                        readonly property real rightWidth: Math.max(0, Math.round((width - gap) / 2 * split))
                        readonly property real leftWidth: width - (rightWidth > 0 ? rightWidth + gap * Math.min(1, split) : 0)

                        Rectangle {
                            id: pane0Container
                            x: 0
                            width: paneRow.leftWidth
                            height: parent.height
                            radius: theme.radiusXl
                            color: theme.backdropSurface(theme.surfaceContainerLow)
                            clip: true
                            border.width: (window.splitView && window.activePane === pane0) ? 2 : (window.keyboardNavActive ? 2 : 1)
                            border.color: (window.splitView && window.activePane === pane0) ? theme.primary : (window.keyboardNavActive ? theme.primary : theme.outlineVariant)
                            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                            Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }

                            FilePane {
                                id: pane0
                                anchors.fill: parent
                                anchors.margins: 14
                                isActive: window.activePane === pane0
                                onActivated: window.setActivePane(pane0)
                                opacity: window.splitView && !isActive ? 0.90 : 1.0
                            }
                        }

                        Rectangle {
                            id: pane1Container
                            x: paneRow.width - width
                            width: paneRow.rightWidth
                            height: parent.height
                            visible: width > 2
                            opacity: Math.min(1, paneRow.split * 1.6)
                            radius: theme.radiusXl
                            color: theme.backdropSurface(theme.surfaceContainerLow)
                            clip: true
                            border.width: (window.splitView && pane1Loader.item && window.activePane === pane1Loader.item) ? 2 : 1
                            border.color: (window.splitView && pane1Loader.item && window.activePane === pane1Loader.item) ? theme.primary : theme.outlineVariant
                            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                            Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }

                            Loader {
                                id: pane1Loader
                                // Keep the pane at its full width while the container animates, so
                                // the contents slide in rather than reflow.
                                x: 14
                                y: 14
                                width: Math.max(0, Math.round((paneRow.width - paneRow.gap) / 2) - 28)
                                height: parent.height - 28
                                active: window.splitView || pane1Container.visible
                                onLoaded: window.seedSplit()
                                sourceComponent: FilePane {
                                    id: pane1
                                    isActive: window.activePane === pane1
                                    onActivated: window.setActivePane(pane1)
                                    opacity: !isActive ? 0.90 : 1.0
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: settingsContainer
                        anchors.fill: parent
                        radius: theme.radiusXl
                        color: theme.backdropSurface(theme.surfaceContainerLow)
                        clip: true
                        visible: opacity > 0.01
                        opacity: window.activeView === "settings" ? 1.0 : 0.0
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        SettingsView {
                            id: settingsView
                            anchors.fill: parent
                            anchors.margins: 22
                            searchQuery: window.activeView === "settings" ? searchInput.text : ""
                        }
                    }

                    Rectangle {
                        id: pcContainer
                        anchors.fill: parent
                        radius: theme.radiusXl
                        color: theme.backdropSurface(theme.surfaceContainerLow)
                        clip: true
                        visible: opacity > 0.01
                        opacity: window.activeView === "pc" ? 1.0 : 0.0
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        PCView {
                            id: pcView
                            anchors.fill: parent
                            anchors.margins: 22
                        }
                    }
                }
            }
        }
    }

    OperationsPanel {
        id: opsPanel
        z: 50
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 34
        anchors.bottomMargin: 34
    }

    Toast {
        id: toastItem
        z: 60
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
    }
    component TopIconButton: Item {
        id: tib
        property string iconName: ""
        property string systemIcon: ""
        property string accessibleName: ""
        property bool small: false
        signal clicked()
        implicitWidth: small ? 24 : 36
        implicitHeight: small ? 24 : 36
        opacity: enabled ? 1.0 : 0.4
        Accessible.role: Accessible.Button
        Accessible.name: accessibleName
        Accessible.onPressAction: tib.clicked()
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: tibMouse.containsMouse ? theme.hoverOverlay : "transparent"
            border.width: tib.activeFocus ? 2 : 0
            border.color: theme.primary
        }
        LoafIcon {
            visible: theme.iconSource === "phosphor" || tib.systemIcon.length === 0
            anchors.centerIn: parent
            name: tib.iconName
            size: tib.small ? 12 : 18
            color: theme.textMain
        }
        Image {
            visible: theme.iconSource !== "phosphor" && tib.systemIcon.length > 0
            anchors.centerIn: parent
            source: visible ? window.systemIcon(tib.systemIcon) : ""
            width: 18
            height: 18
            sourceSize.width: 36
            sourceSize.height: 36
        }
        MouseArea {
            id: tibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tib.clicked()
        }
        ToolTip.visible: tibMouse.containsMouse && tib.accessibleName.length > 0
        ToolTip.text: tib.accessibleName
        ToolTip.delay: 600
    }
    QtObject {
        id: dragManager
        property bool active: false
        property bool asCopy: false
        property bool isRmb: false
        property var paths: []
        property string hoverTarget: ""
        // Engine of the pane the hovered folder is in (split view).
        property var hoverEngine: null
        property point cursorPos: Qt.point(0, 0)

        // Never spring-open a folder that is itself being dragged.
        function hover(path, eng) {
            if (paths.indexOf(path) >= 0)
                return;
            hoverTarget = path;
            hoverEngine = eng;
        }

        function begin(list, mouse) {
            if (!list || list.length === 0)
                return;
            paths = list;
            isRmb = (mouse.button === Qt.RightButton || !!(mouse.buttons & Qt.RightButton));
            asCopy = !!(mouse.modifiers & Qt.ControlModifier);
            active = true;
            hoverTarget = "";
            dragProxy.x = cursorPos.x;
            dragProxy.y = cursorPos.y;
            dragGhost.visible = true;
            dragGhost.grabToImage(function(result) {
                dragProxy.ghostImageSource = result.url;
                dragGhost.visible = false;
                if (dragManager.active)
                    dragProxy.Drag.active = true;
            });
        }

        function end() {
            active = false;
            hoverTarget = "";
            dragProxy.Drag.active = false;
        }
    }

    // Percent-encodes each path segment so names with spaces, '#' or '%'
    // survive as URIs in other applications.
    function fileUri(path) {
        if (path.indexOf("mtp://") === 0) return path;
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    Item {
        id: dragProxy
        visible: false
        width: 1
        height: 1
        Drag.active: false
        Drag.dragType: Drag.Automatic
        Drag.keys: ["text/uri-list"]
        Drag.source: dragProxy
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.proposedAction: dragManager.asCopy ? Qt.CopyAction : Qt.MoveAction
        Drag.hotSpot.x: dragGhost.width / 2
        Drag.hotSpot.y: dragGhost.height / 2
        Drag.imageSource: ghostImageSource
        property url ghostImageSource: ""
        Drag.mimeData: ({
            "text/uri-list": dragManager.paths.map(window.fileUri).join("\r\n"),
            "text/plain": dragManager.paths.join("\n")
        })
        Drag.onDragFinished: dragManager.end()
    }

    Rectangle {
        id: dragGhost
        visible: false
        z: 9999
        width: Math.max(120, ghostRow.implicitWidth + 28)
        height: 52
        radius: theme.radiusL
        color: theme.surfaceContainerHighest
        border.color: theme.primary
        border.width: 1.5
        Row {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 10
            LoafIcon { anchors.verticalCenter: parent.verticalCenter; name: dragManager.paths.length > 1 ? "files" : "file"; size: 22; color: theme.primary }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dragManager.paths.length > 1 ? qsTr("%1 files").arg(dragManager.paths.length)
                    : (dragManager.paths.length === 1 ? dragManager.paths[0].split("/").pop() : "")
                color: theme.textMain
                font.pixelSize: theme.fs(12)
                font.bold: true
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 180)
            }
        }
    }

    // Hovering a folder during a drag opens it.
    Timer {
        interval: 750
        running: dragManager.active && dragManager.hoverTarget.length > 0
        onTriggered: {
            if (dragManager.active && dragManager.hoverTarget.length > 0) {
                var t = dragManager.hoverTarget;
                var eng = dragManager.hoverEngine || window.activePane.engine;
                dragManager.hoverTarget = "";
                eng.set_path(t);
            }
        }
    }
    function confirmEmptyTrash() {
        confirmDialog.ask(qsTr("Empty the trash?"), qsTr("All items in the trash will be permanently deleted."),
            qsTr("Empty Trash"), function() { core.empty_trash(); });
    }

    function menuFromTree(tree, onPick) {
        var out = [];
        for (var i = 0; i < tree.length; ++i) {
            (function(node) {
                if (node.children && node.children.length > 0)
                    out.push({ text: node.name, icon: "folder", submenu: window.menuFromTree(node.children, onPick) });
                else
                    out.push({ text: node.name, icon: "file", action: function() { onPick(node.path); } });
            })(tree[i]);
        }
        return out;
    }

    function openWithData(paths) {
        try {
            return JSON.parse(core.open_with_data(paths[0]) || "{}");
        } catch (e) {
            return {};
        }
    }

    function appRow(app, paths, defaultId, icon) {
        return {
            text: app.name,
            icon: icon || "",
            iconUrl: icon ? "" : (app.icon || ""),
            checkable: app.id === defaultId,
            checked: app.id === defaultId,
            action: function() { core.open_with_app(JSON.stringify(paths), app.id); }
        };
    }

    function openWithMenu(paths, data) {
        var recommended = data.recommended || [];
        var recent = data.recent || [];
        var defaultId = data.defaultId || "";
        var used = {};
        var sub = [];
        for (var r = 0; r < recent.length; ++r) {
            used[recent[r].id] = true;
            sub.push(appRow(recent[r], paths, defaultId, "clock-counter-clockwise"));
        }
        var suggested = [];
        for (var i = 0; i < recommended.length; ++i) {
            if (used[recommended[i].id])
                continue;
            used[recommended[i].id] = true;
            suggested.push(recommended[i]);
        }
        if (suggested.length > 0) {
            if (sub.length > 0)
                sub.push({ text: qsTr("Suggested for this file"), icon: "sparkle", separatorBefore: true, enabled: false });
            for (var s = 0; s < suggested.length; ++s)
                sub.push(appRow(suggested[s], paths, defaultId));
        }
        var others = data.others || [];
        if (others.length > 0) {
            sub.push({ text: qsTr("Other Applications…"), icon: "list", separatorBefore: sub.length > 0, submenu: function() {
                var out = [];
                for (var o = 0; o < others.length; ++o)
                    out.push(appRow(others[o], paths, defaultId));
                return out;
            } });
        }
        sub.push({ text: qsTr("Run Custom Command…"), icon: "terminal", separatorBefore: sub.length > 0, action: function() { commandModal.showFor(paths[0]); } });
        return sub;
    }

    function defaultAppRow(app, paths, defaultId, icon) {
        return {
            text: app.name,
            icon: icon || "",
            iconUrl: icon ? "" : (app.icon || ""),
            checkable: true,
            checked: app.id === defaultId,
            action: function() { core.set_default_app(paths[0], app.id); }
        };
    }

    function setDefaultMenu(paths, data) {
        var recommended = data.recommended || [];
        var recent = data.recent || [];
        var defaultId = data.defaultId || "";
        var used = {};
        var sub = [];
        for (var r = 0; r < recent.length; ++r) {
            used[recent[r].id] = true;
            sub.push(defaultAppRow(recent[r], paths, defaultId, "clock-counter-clockwise"));
        }
        for (var i = 0; i < recommended.length; ++i) {
            if (used[recommended[i].id])
                continue;
            used[recommended[i].id] = true;
            sub.push(defaultAppRow(recommended[i], paths, defaultId));
        }
        return sub;
    }

    function compressSubmenu(paths) {
        function go(fmt) { core.compress(JSON.stringify(paths), fmt, ""); }
        var sub = [
            { text: qsTr(".zip Archive"), icon: "file-zip", action: function() { go("zip"); } },
            { text: qsTr("Encrypted .zip…"), icon: "lock", action: function() { passwordModal.openFor({ kind: "compress", paths: paths, format: "zip_encrypted" }); } },
            { text: qsTr(".tar.gz Archive"), icon: "archive", separatorBefore: true, action: function() { go("tar.gz"); } },
            { text: qsTr(".7z Archive"), icon: "file-archive", action: function() { go("7z"); } },
            { text: qsTr("Encrypted .7z…"), icon: "lock", action: function() { passwordModal.openFor({ kind: "compress", paths: paths, format: "7z" }); } }
        ];
        if (theme.showAdvancedArchives) {
            sub.push({ text: ".tar.xz", icon: "archive", separatorBefore: true, action: function() { go("tar.xz"); } });
            sub.push({ text: ".tar.zst", icon: "archive", action: function() { go("tar.zst"); } });
            sub.push({ text: ".tar.bz2", icon: "archive", action: function() { go("tar.bz2"); } });
            sub.push({ text: ".cpio", icon: "package", action: function() { go("cpio"); } });
        }
        return sub;
    }

    function sortMenuItems(items) {
        var savedOrder = [];
        try {
            var raw = core.get_setting("contextMenuOrder");
            if (raw && raw.length > 0) savedOrder = JSON.parse(raw);
        } catch (e) {}
        if (savedOrder.length === 0)
            return items;
        var copy = items.slice();
        copy.sort(function(a, b) {
            var ia = a.itemKey ? savedOrder.indexOf(a.itemKey) : -1;
            var ib = b.itemKey ? savedOrder.indexOf(b.itemKey) : -1;
            if (ia === -1 && ib === -1) return 0;
            if (ia === -1) return 1;
            if (ib === -1) return -1;
            return ia - ib;
        });
        return copy;
    }

    function openItemMenu(pane, row, mx, my) {
        setActivePane(pane);
        var paths = pane.selectedPaths();
        var item = JSON.parse(pane.engine.item_json(row));
        if (paths.length === 0)
            paths = [item.path];
        var kind = pane.engine.location_kind;
        var single = paths.length === 1;
        var m = [];

        if (kind === "mtp") {
            m.push({ text: qsTr("Open"), icon: "folder-open", action: function() { pane.openSelected(); } });
            if (item.is_dir) m.push({ text: qsTr("Open in New Tab"), icon: "tabs", action: function() {
                pane.selectedItems().filter(function(entry) { return entry.is_dir; }).forEach(function(entry) { window.newTab(entry.path); });
            } });
            if (!item.is_dir) m.push({ text: qsTr("Quick Look"), icon: "eye", action: function() { window.previewItem(item.path); } });
            m.push({ text: qsTr("Copy"), icon: "copy", shortcut: "Ctrl+C", action: function() { window.copySelection(false); } });
            if (!pane.engine.read_only) {
                m.push({ text: qsTr("Cut"), icon: "scissors", shortcut: "Ctrl+X", action: function() { window.copySelection(true); } });
                if (single) m.push({ text: qsTr("Rename…"), icon: "pencil-simple", shortcut: "F2", action: function() { pane.startRename(); } });
                m.push({ text: qsTr("Delete Permanently"), icon: "trash", danger: true, action: function() { window.deleteSelection(); } });
            }
            m.push({ text: qsTr("Copy Location"), icon: "link", action: function() { nativeBridge.setClipboardText(paths.join("\n")); } });
            contextMenu.model = m;
            contextMenu.openAt(mx, my);
            return;
        }
        if (kind === "trash") {
            m.push({ text: qsTr("Restore"), icon: "arrow-counter-clockwise", action: function() { core.restore_items(JSON.stringify(paths)); pane.clearSelection(); } });
            m.push({ text: qsTr("Preview"), icon: "eye", shortcut: "Space", action: function() { quickLook.showFor(item.path); } });
            m.push({ text: qsTr("Delete Permanently"), icon: "trash", danger: true, separatorBefore: true, shortcut: "Del", action: function() { window.deleteSelection(); } });
            m.push({ text: qsTr("Properties"), icon: "info", separatorBefore: true, action: function() { window.showProperties(paths); } });
            if (m.length === 0)
                return;
            contextMenu.model = m;
            contextMenu.openAt(mx, my);
            return;
        }

        var inArchive = kind === "archive";
        m.push({ text: qsTr("Open"), icon: "arrow-square-out", itemKey: "open", action: function() { pane.openSelected(); } });
        if (item.is_dir && !inArchive)
            m.push({ text: qsTr("Open in New Tab"), icon: "tabs", itemKey: "new_tab", action: function() { for (var i = 0; i < paths.length; ++i) window.newTab(paths[i]); } });
        if ((kind === "search" || kind === "recent" || kind === "starred") && item.parent_path)
            m.push({ text: qsTr("Open Containing Folder"), icon: "folder-open", itemKey: "open_containing", action: function() {
                var target = item.path;
                searchInput.text = "";
                pane.engine.set_path(item.parent_path);
                pane.pendingSelect = [target];
            } });
        if (!item.is_dir && !inArchive) {
            var openData = openWithData(paths);
            var openSub = openWithMenu(paths, openData);
            if (openSub.length > 0)
                m.push({ text: qsTr("Open With"), icon: "app-window", itemKey: "open_with", submenu: openSub });
            var defSub = setDefaultMenu(paths, openData);
            if (defSub.length > 0)
                m.push({ text: qsTr("Set Default Application"), icon: "check-square", itemKey: "set_default", submenu: defSub });
            if (core.is_archive_file(item.path)) {
                m.push({ text: qsTr("Browse Archive"), icon: "folder-open", itemKey: "browse_archive", action: function() { pane.engine.set_path("archive://" + item.path + "#"); } });
                m.push({ text: qsTr("Extract Here"), icon: "archive", itemKey: "extract", action: function() { core.extract(item.path, false, ""); } });
                m.push({ text: qsTr("Extract to Folder"), icon: "folder-plus", itemKey: "extract", action: function() { core.extract(item.path, true, ""); } });
            }
        }
        m.push({ text: qsTr("Quick Look"), icon: "eye", shortcut: "Space", itemKey: "quick_look", action: function() { quickLook.showFor(item.path); } });
        if (!inArchive) {
            var termDir = item.is_dir ? item.path : (item.parent_path || pane.engine.current_path);
            m.push({ text: qsTr("Open in Terminal"), icon: "terminal", itemKey: "terminal", action: function() { core.open_terminal(termDir); } });

            m.push({ text: qsTr("Cut"), icon: "scissors", shortcut: "Ctrl+X", itemKey: "cut", separatorBefore: true, action: function() { window.copySelection(true); } });
            m.push({ text: qsTr("Copy"), icon: "copy", shortcut: "Ctrl+C", itemKey: "copy", action: function() { window.copySelection(false); } });
            if (item.is_dir && single && nativeBridge.clipboardHasFiles())
                m.push({ text: qsTr("Paste Into Folder"), icon: "clipboard", itemKey: "paste", action: function() { window.pasteInto(item.path); } });
            m.push({ text: qsTr("Copy Path"), icon: "copy-simple", shortcut: "Ctrl+Shift+C", itemKey: "copy_path", action: function() { window.copyPathOfSelection(); } });
            if (single)
                m.push({ text: qsTr("Rename…"), icon: "pencil-simple", shortcut: "F2", itemKey: "rename", action: function() { pane.startRename(); } });
            else
                m.push({ text: qsTr("Rename %1 Items…").arg(paths.length), icon: "pencil-simple", shortcut: "F2", itemKey: "rename", action: function() { batchRename.showFor(pane.selectedItems()); } });
            if (kind === "dir") {
                m.push({ text: qsTr("Duplicate"), icon: "copy-simple", itemKey: "duplicate", action: function() { core.transfer(JSON.stringify(paths), pane.engine.current_path, "copy", "rename"); } });
                m.push({ text: qsTr("Make Link"), icon: "link", itemKey: "make_link", action: function() { core.transfer(JSON.stringify(paths), pane.engine.current_path, "link", "rename"); } });
            }
            if (theme.shareViaLinkEnabled) {
                var shareSub = [
                    {
                        text: qsTr("Share via Link"),
                        icon: "link",
                        action: function() {
                            if (!core.is_cloudflared_installed()) {
                                window.toast("info", qsTr("Installing Cloudflare Tunnel agent..."));
                                core.install_cloudflared();
                            }
                            window.toast("info", qsTr("Preparing link share..."));
                            core.start_share(JSON.stringify(paths));
                        }
                    }
                ];
                m.push({ text: qsTr("Share…"), icon: "share-network", itemKey: "share", submenu: shareSub });
            }
            m.push({ text: qsTr("Compress"), icon: "file-archive", itemKey: "compress", submenu: compressSubmenu(paths) });

            var starred = item.starred === true;
            m.push({ text: starred ? qsTr("Unstar") : qsTr("Star"), icon: "star", itemKey: "star", separatorBefore: true, action: function() { core.set_starred(JSON.stringify(paths), !starred); } });
            if (item.is_dir && single) {
                var marked = core.is_bookmarked(item.path);
                m.push({ text: marked ? qsTr("Remove from Sidebar") : qsTr("Add to Sidebar"), icon: "push-pin", itemKey: "pin", action: function() {
                    if (marked)
                        core.remove_bookmark(item.path);
                    else
                        core.add_bookmark(item.path);
                } });
            }
            var scripts = JSON.parse(core.scripts_json() || "[]");
            if (scripts.length > 0)
                m.push({ text: qsTr("Scripts"), icon: "scroll", itemKey: "scripts", submenu: menuFromTree(scripts, function(script) {
                    core.run_script(script, kind === "dir" ? pane.engine.current_path : item.parent_path, JSON.stringify(paths));
                }) });
            if (!nativeBridge.isAdmin && item.is_dir && single)
                m.push({ text: qsTr("Open as Administrator"), icon: "shield-check", itemKey: "admin", action: function() { core.open_as_admin(item.path); } });

            m.push({ text: qsTr("Move to Trash"), icon: "trash", shortcut: "Del", danger: true, itemKey: "delete", separatorBefore: true, action: function() { window.trashSelection(); } });
            m.push({ text: qsTr("Delete Permanently"), icon: "x-circle", shortcut: "Shift+Del", itemKey: "permanent_delete", danger: true, action: function() { window.deleteSelection(); } });
        }
        m.push({ text: qsTr("Properties"), icon: "info", shortcut: "Alt+Enter", itemKey: "properties", separatorBefore: true, enabled: !inArchive, action: function() { window.showProperties(paths); } });

        function shouldIncludeItem(row) {
            if (!row || !row.itemKey) return true;
            if (theme.contextMenuMode === "minimal") {
                if (["open", "cut", "copy", "paste", "delete", "permanent_delete", "select_all"].indexOf(row.itemKey) !== -1)
                    return false;
            } else if (theme.contextMenuMode === "custom") {
                if (theme.disabledMenuItems && theme.disabledMenuItems[row.itemKey])
                    return false;
            }
            return true;
        }
        contextMenu.model = sortMenuItems(m.filter(shouldIncludeItem));
        contextMenu.openAt(mx, my);
    }

    function openEmptyMenu(pane, mx, my) {
        setActivePane(pane);
        var e = pane.engine;
        var kind = e.location_kind;
        var m = [];
        if (kind === "trash") {
            if (e.item_count > 0) {
                m.push({ text: qsTr("Empty Trash"), icon: "trash", danger: true, itemKey: "empty_trash", action: function() { window.confirmEmptyTrash(); } });
                m.push({ text: qsTr("Select All"), icon: "selection-all", shortcut: "Ctrl+A", itemKey: "select_all", separatorBefore: true, action: function() { pane.selectAll(); } });
            }
            if (m.length === 0)
                return;
            contextMenu.model = m;
            contextMenu.openAt(mx, my);
            return;
        }
        if (kind === "dir" || (kind === "mtp" && !e.read_only)) {
            var newSub = [
                { text: qsTr("Folder"), icon: "folder-plus", shortcut: "Ctrl+Shift+N", action: function() { inputModal.showNewFolder(); } },
                { text: qsTr("Empty File"), icon: "file-plus", action: function() { inputModal.showNewFile(); } },
                { text: qsTr("Symlink…"), icon: "link", action: function() { symlinkModal.openFor(e.current_path); } }
            ];
            if (kind === "mtp") newSub = newSub.filter(function(row) { return row.icon !== "link"; });
            var templates = kind === "dir" ? JSON.parse(core.templates_json() || "[]") : [];
            if (templates.length > 0) {
                newSub.push({ text: qsTr("From Template"), icon: "file-doc", submenu: menuFromTree(templates, function(tpl) {
                    var created = core.create_from_template(tpl, e.current_path);
                    if (created.length > 0) {
                        pane.pendingSelect = [created];
                        pane.pendingRename = true;
                    }
                }) });
            }
            m.push({ text: qsTr("New…"), icon: "plus-circle", itemKey: "new", submenu: newSub });
            if (nativeBridge.clipboardHasFiles() || window.mtpClipboardPaths.length > 0)
                m.push({ text: qsTr("Paste"), icon: "clipboard", shortcut: "Ctrl+V", itemKey: "paste", separatorBefore: true, action: function() { window.pasteInto(e.current_path); } });
        }
        if (e.item_count > 0) {
            m.push({ text: qsTr("Select All"), icon: "selection-all", shortcut: "Ctrl+A", itemKey: "select_all", separatorBefore: kind !== "dir", action: function() { pane.selectAll(); } });
            m.push({ text: qsTr("Select by Pattern…"), icon: "selection", shortcut: "Ctrl+S", itemKey: "select_pattern", action: function() { patternModal.openFor(); } });
        }
        if (kind === "dir") {
            m.push({ text: qsTr("Open Terminal Here"), icon: "terminal", itemKey: "terminal", separatorBefore: true, action: function() { core.open_terminal(e.current_path); } });
            var marked = core.is_bookmarked(e.current_path);
            m.push({ text: marked ? qsTr("Remove from Sidebar") : qsTr("Add to Sidebar"), icon: "push-pin", shortcut: "Ctrl+D", itemKey: "pin", action: function() {
                if (marked)
                    core.remove_bookmark(e.current_path);
                else
                    core.add_bookmark(e.current_path);
            } });
            var scripts = JSON.parse(core.scripts_json() || "[]");
            if (scripts.length > 0)
                m.push({ text: qsTr("Scripts"), icon: "scroll", itemKey: "scripts", submenu: menuFromTree(scripts, function(script) { core.run_script(script, e.current_path, "[]"); }) });
            if (!nativeBridge.isAdmin)
                m.push({ text: qsTr("Open as Administrator"), icon: "shield-check", itemKey: "admin", action: function() { core.open_as_admin(e.current_path); } });
            m.push({ text: qsTr("Properties"), icon: "info", itemKey: "properties", separatorBefore: true, action: function() { window.showProperties([e.current_path]); } });
        }

        function shouldIncludeEmpty(row) {
            if (!row || !row.itemKey) return true;
            if (theme.contextMenuMode === "minimal") {
                if (["open", "cut", "copy", "paste", "delete", "permanent_delete", "select_all"].indexOf(row.itemKey) !== -1)
                    return false;
            } else if (theme.contextMenuMode === "custom") {
                if (theme.disabledMenuItems && theme.disabledMenuItems[row.itemKey])
                    return false;
            }
            return true;
        }
        contextMenu.model = sortMenuItems(m.filter(shouldIncludeEmpty));
        contextMenu.openAt(mx, my);
    }

    LoafMenu {
        id: contextMenu
        menuMinWidth: 230
        menuMaxWidth: 340
    }
    LoafMenu {
        id: crumbMenu
        menuMinWidth: 200
        function showFor(path, x, y) {
            if (path.indexOf("/") !== 0)
                return;
            model = [
                { text: qsTr("Open in New Tab"), icon: "tabs", action: function() { window.newTab(path); } },
                { text: qsTr("Paste Into Folder"), icon: "clipboard", enabled: nativeBridge.clipboardHasFiles(), action: function() { window.pasteInto(path); } },
                { text: qsTr("Copy Path"), icon: "copy-simple", action: function() { nativeBridge.setClipboardText(path); window.toast("info", qsTr("Path copied")); } },
                { text: qsTr("Add to Sidebar"), icon: "push-pin", action: function() { core.add_bookmark(path); } },
                { text: qsTr("Properties"), icon: "info", separatorBefore: true, action: function() { window.showProperties([path]); } }
            ];
            openAt(x, y);
        }
    }

    LoafMenu {
        id: sidebarMenu
        menuMinWidth: 210
        function showAt(px, py) {
            model = [
                {
                    text: sidebar.expanded ? qsTr("Collapse Sidebar") : qsTr("Expand Sidebar"),
                    icon: sidebar.expanded ? "sidebar-simple" : "sidebar",
                    action: function() { sidebar.expanded = !sidebar.expanded; }
                },
                {
                    text: qsTr("Customize Sidebar…"),
                    icon: "sliders-horizontal",
                    separatorBefore: true,
                    action: function() { customizePlaces.open(); }
                },
                {
                    text: qsTr("Add SMB Share…"),
                    icon: "network",
                    action: function() { window.openSmbEditor({}); }
                }
            ];
            openAt(px, py);
        }
    }

    LoafMenu {
        id: searchSettingsMenu
        menuMinWidth: 260
        menuMaxWidth: 320
        model: []

        Text {
            Layout.leftMargin: 8
            Layout.topMargin: 4
            text: qsTr("SEARCH SCOPE")
            color: theme.textMuted
            font.pixelSize: theme.fs(10)
            font.bold: true
            font.letterSpacing: 0.8
        }

        LoafMenuItem {
            text: qsTr("Filter This Folder")
            icon: "folder"
            checkable: true
            checked: !engine.is_searching_everywhere
            onTriggered: {
                if (engine.is_searching_everywhere) {
                    engine.clear_search();
                    if (searchInput.text.trim().length > 0)
                        engine.set_filter(searchInput.text.trim());
                }
            }
        }

        LoafMenuItem {
            text: qsTr("Search Subfolders")
            icon: "tree-structure"
            checkable: true
            checked: engine.is_searching_everywhere && window.searchScope === "folder"
            onTriggered: {
                if (engine.is_searching_everywhere && window.searchScope === "folder") {
                    engine.clear_search();
                    if (searchInput.text.trim().length > 0)
                        engine.set_filter(searchInput.text.trim());
                    return;
                }
                window.searchScope = "folder";
                var q = searchInput.text.trim();
                if (q.length > 0) {
                    engine.set_filter("");
                    engine.search(q, "folder", theme.searchContents);
                } else {
                    searchInput.forceActiveFocus();
                }
            }
        }

        LoafMenuItem {
            text: qsTr("Search Everywhere")
            icon: "globe"
            checkable: true
            checked: engine.is_searching_everywhere && window.searchScope === "home"
            onTriggered: {
                if (engine.is_searching_everywhere && window.searchScope === "home") {
                    engine.clear_search();
                    if (searchInput.text.trim().length > 0)
                        engine.set_filter(searchInput.text.trim());
                    return;
                }
                window.searchScope = "home";
                var q = searchInput.text.trim();
                if (q.length > 0) {
                    engine.set_filter("");
                    engine.search(q, "home", theme.searchContents);
                } else {
                    searchInput.forceActiveFocus();
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 4; Layout.bottomMargin: 4; color: theme.separator }

        Text {
            Layout.leftMargin: 8
            text: qsTr("SEARCH OPTIONS")
            color: theme.textMuted
            font.pixelSize: theme.fs(10)
            font.bold: true
            font.letterSpacing: 0.8
        }

        LoafSwitch {
            label: qsTr("Search File Contents")
            checked: theme.searchContents
            onToggled: function(c) {
                theme.searchContents = c;
                if (engine.is_searching_everywhere && searchInput.text.trim().length > 0)
                    engine.search(searchInput.text.trim(), window.searchScope, theme.searchContents);
            }
        }
    }

    LoafDialog {
        id: symlinkModal
        title: qsTr("Create Symlink")
        dialogWidth: 420
        property string inDir: ""

        function openFor(dirPath) {
            inDir = dirPath;
            targetField.text = "";
            linkNameField.text = "";
            linkNameField.autoNamed = false;
            open();
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: qsTr("Target file or folder path:")
                color: theme.textMain
                font.pixelSize: theme.fs(12)
            }
            LoafTextField {
                id: targetField
                Layout.fillWidth: true
                placeholderText: "/path/to/target/file"
                onTextChanged: {
                    if (linkNameField.text.length === 0 || linkNameField.autoNamed) {
                        var p = text.trim();
                        var parts = p.split("/").filter(function(x) { return x.length > 0; });
                        if (parts.length > 0) {
                            linkNameField.text = parts[parts.length - 1];
                            linkNameField.autoNamed = true;
                        }
                    }
                }
            }

            Text {
                text: qsTr("Symlink name in %1:").arg(symlinkModal.inDir)
                color: theme.textMain
                font.pixelSize: theme.fs(12)
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
            LoafTextField {
                id: linkNameField
                property bool autoNamed: false
                Layout.fillWidth: true
                placeholderText: qsTr("Link name")
                onTextEdited: autoNamed = false
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                LoafButton {
                    text: qsTr("Cancel")
                    variant: "text"
                    onClicked: symlinkModal.close()
                }
                LoafButton {
                    text: qsTr("Create Link")
                    variant: "filled"
                    enabled: targetField.text.trim().length > 0 && linkNameField.text.trim().length > 0
                    onClicked: {
                        var target = targetField.text.trim();
                        var linkName = linkNameField.text.trim();
                        var fullLink = symlinkModal.inDir + "/" + linkName;
                        symlinkModal.close();
                        if (core.create_symlink(target, fullLink)) {
                            window.activePane.pendingSelect = [fullLink];
                            window.activePane.engine.refresh();
                            window.toast("info", qsTr("Symlink created"));
                        } else {
                            window.toast("error", qsTr("Could not create symlink"));
                        }
                    }
                }
            }
        }
    }
    LoafMenu {
        id: placeMenu
        menuMinWidth: 220
        function showFor(place, x, y) {
            var all = JSON.parse(core.all_places_json() || "[]");
            var idx = all.findIndex(function(p) { return p.id === place.id; });
            var m = [];
            if (place.kind === "smb") {
                if (place.path && place.connected)
                    m.push({ text: qsTr("Open in New Tab"), icon: "tabs", action: function() { window.newTab(place.path); } });
                if (!place.connected)
                    m.push({ text: qsTr("Connect"), icon: "plug", action: function() { core.connect_smb(place.profile_id, "", false); } });
                if (place.connected)
                    m.push({ text: qsTr("Disconnect"), icon: "plug-slash", action: function() { core.disconnect_smb(place.profile_id); } });
                m.push({ text: qsTr("Edit Share…"), icon: "pencil-simple", separatorBefore: true, action: function() { window.openSmbEditor(place); } });
                m.push({ text: qsTr("Remove Share"), icon: "x", danger: true, action: function() { window.removeSmbShare(place.profile_id, place.name); } });
                m.push({ text: qsTr("Move Up"), icon: "arrow-up", separatorBefore: true, enabled: idx > 0, action: function() { core.move_place(place.id, idx - 1); } });
                m.push({ text: qsTr("Move Down"), icon: "arrow-down", enabled: idx >= 0 && idx < all.length - 1, action: function() { core.move_place(place.id, idx + 1); } });
                m.push({ text: qsTr("Add SMB Share…"), icon: "plus", separatorBefore: true, action: function() { window.openSmbEditor({}); } });
                model = m;
                openAt(x, y);
                return;
            }
            if (place.path && place.path.indexOf("/") === 0)
                m.push({ text: qsTr("Open in New Tab"), icon: "tabs", action: function() { window.newTab(place.path); } });
            if (place.kind === "trash")
                m.push({ text: qsTr("Empty Trash"), icon: "trash", danger: true, enabled: !core.trash_empty, action: function() { window.confirmEmptyTrash(); } });
            if (place.kind === "place" || place.kind === "bookmark")
                m.push({ text: qsTr("Rename / Change Folder…"), icon: "pencil-simple", action: function() { placeEdit.openFor(place); } });
            m.push({ text: qsTr("Move Up"), icon: "arrow-up", separatorBefore: true, enabled: idx > 0, action: function() { core.move_place(place.id, idx - 1); } });
            m.push({ text: qsTr("Move Down"), icon: "arrow-down", enabled: idx >= 0 && idx < all.length - 1, action: function() { core.move_place(place.id, idx + 1); } });
            if (place.kind === "bookmark")
                m.push({ text: qsTr("Remove from Sidebar"), icon: "x", danger: true, separatorBefore: true, action: function() { core.remove_bookmark(place.path); } });
            else
                m.push({ text: qsTr("Hide from Sidebar"), icon: "eye-slash", separatorBefore: true, action: function() { core.set_place_hidden(place.id, true); } });
            m.push({ text: qsTr("Customize Sidebar…"), icon: "sliders-horizontal", action: function() { customizePlaces.open(); } });
            model = m;
            openAt(x, y);
        }
    }
    function openDriveContextMenu(d, x, y) {
        if (!d)
            return;
        pcView.openDriveMenu(d, x, y);
    }
    LoafMenu {
        id: rmbDropMenu
        menuMinWidth: 200
        property var dropPaths: []
        property string dropDest: ""
        function showAt(px, py, paths, dest) {
            dropPaths = paths;
            dropDest = dest;
            if (dest === "trash") {
                model = [
                    { text: qsTr("Move to Trash"), icon: "trash", danger: true, action: function() { core.trash_items(JSON.stringify(rmbDropMenu.dropPaths)); } },
                    { text: qsTr("Cancel"), icon: "x", separatorBefore: true, action: function() {} }
                ];
            } else {
                model = [
                    { text: qsTr("Copy Here"), icon: "copy", action: function() { window.transfer(rmbDropMenu.dropPaths, rmbDropMenu.dropDest, "copy"); } },
                    { text: qsTr("Move Here"), icon: "arrows-out-cardinal", action: function() { window.transfer(rmbDropMenu.dropPaths, rmbDropMenu.dropDest, "move"); } },
                    { text: qsTr("Link Here"), icon: "link", action: function() { core.transfer(JSON.stringify(rmbDropMenu.dropPaths), rmbDropMenu.dropDest, "link", "rename"); } },
                    { text: qsTr("Cancel"), icon: "x", danger: true, separatorBefore: true, action: function() {} }
                ];
            }
            openAt(px, py);
        }
    }
    LoafMenu {
        id: viewMenuPopup
        menuMinWidth: 290
        menuMaxWidth: 340
        model: []

        Text { Layout.leftMargin: 8; Layout.topMargin: 4; text: qsTr("VIEW MODE"); color: theme.textMuted; font.pixelSize: theme.fs(10); font.bold: true; font.letterSpacing: 0.8 }
        LoafSegmented {
            Layout.fillWidth: true
            Layout.leftMargin: 4; Layout.rightMargin: 4
            options: [{ value: "grid", label: qsTr("Grid"), icon: "squares-four" }, { value: "list", label: qsTr("List"), icon: "list" }]
            value: engine.view_mode
            onSelected: function(v) { engine.set_view(v); }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 8
            Text { text: qsTr("Icon size"); color: theme.textMain; font.pixelSize: theme.fs(12); Layout.fillWidth: true }
            LoafButton { icon: "magnifying-glass-minus"; variant: "tonal"; enabled: theme.zoomIndex > 0; onClicked: theme.stepZoom(-1) }
            Text { text: Math.round(theme.zoom * 100) + "%"; color: theme.textMuted; font.pixelSize: theme.fs(11) }
            LoafButton { icon: "magnifying-glass-plus"; variant: "tonal"; enabled: theme.zoomIndex < theme.zoomLevels.length - 1; onClicked: theme.stepZoom(1) }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 4; Layout.bottomMargin: 4; color: theme.separator }
        Text { Layout.leftMargin: 8; text: qsTr("SORT BY"); color: theme.textMuted; font.pixelSize: theme.fs(10); font.bold: true; font.letterSpacing: 0.8 }
        LoafMenuItem { text: qsTr("Name"); checkable: true; checked: engine.sort_by === "name"; onTriggered: engine.set_sort("name", engine.sort_ascending) }
        LoafMenuItem { text: qsTr("Date Modified"); checkable: true; checked: engine.sort_by === "modified"; onTriggered: engine.set_sort("modified", engine.sort_ascending) }
        LoafMenuItem { text: qsTr("Size"); checkable: true; checked: engine.sort_by === "size"; onTriggered: engine.set_sort("size", engine.sort_ascending) }
        LoafMenuItem { text: qsTr("Type"); checkable: true; checked: engine.sort_by === "type"; onTriggered: engine.set_sort("type", engine.sort_ascending) }
        LoafSegmented {
            Layout.fillWidth: true
            Layout.leftMargin: 4; Layout.rightMargin: 4
            options: [{ value: "asc", label: qsTr("Ascending"), icon: "sort-ascending" }, { value: "desc", label: qsTr("Descending"), icon: "sort-descending" }]
            value: engine.sort_ascending ? "asc" : "desc"
            onSelected: function(v) { engine.set_sort(engine.sort_by, v === "asc"); }
        }
        Text { Layout.leftMargin: 8; Layout.topMargin: 4; text: qsTr("FOLDERS"); color: theme.textMuted; font.pixelSize: theme.fs(10); font.bold: true; font.letterSpacing: 0.8 }
        LoafSegmented {
            Layout.fillWidth: true
            Layout.leftMargin: 4; Layout.rightMargin: 4
            options: [{ value: "first", label: qsTr("First") }, { value: "last", label: qsTr("Last") }, { value: "mixed", label: qsTr("Mixed") }]
            value: engine.folder_position
            onSelected: function(v) { engine.change_folder_position(v); }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 4; Layout.bottomMargin: 4; color: theme.separator }
        LoafSwitch { label: qsTr("Show Hidden Files"); checked: window.showHidden; onToggled: window.toggleShowHidden() }
        LoafSwitch { label: qsTr("Split View (F3)"); checked: window.splitView && window.activeView === "files"; onToggled: window.toggleSplit() }
    }
    QuickLook { id: quickLook }
    PropertiesDialog { id: propsDialog }
    BatchRenameDialog { id: batchRename }
    ConflictDialog { id: conflictDialog }

    LoafTextPrompt {
        id: inputModal
        property string mode: "new_folder"

        function showNewFolder() {
            mode = "new_folder";
            title = qsTr("New Folder");
            label = qsTr("Enter a name for the new folder");
            placeholder = qsTr("Folder name");
            initialText = qsTr("New Folder");
            confirmText = qsTr("Create");
            selectBasename = false;
            open();
        }

        function showNewFile() {
            mode = "new_file";
            title = qsTr("New File");
            label = qsTr("Enter a name for the new file");
            placeholder = qsTr("File name");
            initialText = qsTr("Untitled.txt");
            confirmText = qsTr("Create");
            selectBasename = false;
            open();
        }

        onAccepted: function(text) {
            var val = (text || "").trim();
            if (val.length === 0)
                return;
            var created = mode === "new_folder"
                ? core.create_folder(engine.current_path, val)
                : core.create_file(engine.current_path, val);
            if (created.length > 0)
                window.activePane.pendingSelect = [created];
        }
    }

    LoafTextPrompt {
        id: commandModal
        property string targetPath: ""
        function showFor(path) {
            targetPath = path;
            title = qsTr("Run Custom Command");
            label = qsTr("Command to open “%1”. Use %f where the file should go (it is appended if omitted).").arg(path.split("/").pop());
            placeholder = "mpv %f";
            initialText = core.get_setting("openWithCustomCommand") || "";
            confirmText = qsTr("Run");
            selectBasename = false;
            open();
        }
        onAccepted: function(text) {
            var cmd = (text || "").trim();
            if (cmd.length === 0)
                return;
            core.set_setting("openWithCustomCommand", cmd);
            core.run_custom_command(cmd, targetPath);
        }
    }

    LoafTextPrompt {
        id: patternModal
        title: qsTr("Select by Pattern")
        label: qsTr("Wildcards: * matches anything, ? one character (e.g. *.jpg)")
        placeholder: "*.jpg"
        confirmText: qsTr("Select")
        function openFor() { initialText = "*"; open(); }
        onAccepted: function(text) {
            if (text.trim().length > 0)
                window.activePane.selectPattern(text.trim());
        }
    }
    LoafDialog {
        id: passwordModal
        dialogWidth: 400
        property var request: ({})
        property bool submitting: false
        title: request.kind === "luks" ? qsTr("Unlock Drive") : (request.kind === "compress" ? qsTr("Encrypted Archive") : (request.kind === "smb" ? qsTr("Connect to SMB Share") : qsTr("Password Required")))

        function openFor(req) {
            submitting = false;
            request = req;
            pwField.text = "";
            pwRepeat.text = "";
            rememberBox.checked = false;
            open();
        }
        // Focus only works once the popup is really shown.
        onOpened: pwField.forceActiveFocus()
        onClosed: {
            if (!visible && !submitting && request.kind === "luks" && request.device === window.pendingMountDevice)
                window.cancelDriveOpen();
        }
        // A new archive's password is typed twice: a typo would lock the
        // files away for good.
        readonly property bool needsRepeat: request.kind === "compress"
        readonly property bool mismatch: needsRepeat && pwRepeat.text.length > 0 && pwRepeat.text !== pwField.text
        readonly property bool canAccept: pwField.text.length > 0 && (!needsRepeat || pwRepeat.text === pwField.text)
        function accept() {
            var pw = pwField.text;
            if (!canAccept)
                return;
            var r = request;
            submitting = true;
            close();
            if (r.kind === "compress")
                core.compress(JSON.stringify(r.paths), r.format, pw);
            else if (r.kind === "archive")
                core.extract(r.archive, r.into_subfolder, pw);
            else if (r.kind === "luks")
                core.unlock_drive(r.device, pw, rememberBox.checked);
            else if (r.kind === "smb")
                core.connect_smb(r.id, pw, rememberBox.checked);
        }

        function promptText() {
            var r = request;
            if (r.error)
                return qsTr("Wrong password, try again.");
            if (r.kind === "luks")
                return qsTr("Enter the passphrase for %1").arg(r.device || "");
            if (r.kind === "smb") {
                var user = r.username ? r.username + "@" : "";
                return qsTr("Enter the password for %1").arg(user + (r.server || ""));
            }
            if (r.kind === "compress")
                return qsTr("Set a password to protect the archive");
            return qsTr("“%1” is encrypted").arg((r.archive || "").split("/").pop());
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: passwordModal.request.error ? theme.danger : theme.textMuted
            font.pixelSize: theme.fs(12)
            text: passwordModal.promptText()
        }
        LoafTextField {
            id: pwField
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: qsTr("Password")
            color: theme.textMain
            onAccepted: passwordModal.needsRepeat ? pwRepeat.forceActiveFocus() : passwordModal.accept()
        }
        LoafTextField {
            id: pwRepeat
            visible: passwordModal.needsRepeat
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: qsTr("Repeat password")
            color: theme.textMain
            onAccepted: passwordModal.accept()
        }
        Text {
            visible: passwordModal.mismatch
            text: qsTr("The passwords don't match")
            color: theme.danger
            font.pixelSize: theme.fs(11)
        }
        LoafCheckBox {
            id: rememberBox
            visible: passwordModal.request.kind === "luks" || passwordModal.request.kind === "smb"
            text: qsTr("Remember in the keyring")
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LoafButton { text: qsTr("Cancel"); variant: "text"; onClicked: passwordModal.close() }
            LoafButton { text: passwordModal.request.kind === "compress" ? qsTr("Create") : (passwordModal.request.kind === "smb" ? qsTr("Connect") : qsTr("Unlock")); variant: "filled"; enabled: passwordModal.canAccept; onClicked: passwordModal.accept() }
        }
    }
    LoafDialog {
        id: smbDialog
        dialogWidth: 460
        property string editingId: ""
        title: editingId.length > 0 ? qsTr("Edit SMB Share") : qsTr("Add SMB Share")

        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            text: qsTr("Connect to a Windows, Samba or NAS share with your username and password.")
        }
        Text { text: qsTr("Display name"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
        LoafTextField { id: smbNameField; Layout.fillWidth: true; color: theme.textMain; placeholderText: qsTr("Studio NAS") }
        Text { text: qsTr("Server"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
        LoafTextField { id: smbServerField; Layout.fillWidth: true; color: theme.textMain; placeholderText: "192.168.1.20" }
        Text { text: qsTr("Share name"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
        LoafTextField { id: smbShareField; Layout.fillWidth: true; color: theme.textMain; placeholderText: "media" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: qsTr("Username (optional)"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
                LoafTextField { id: smbUserField; Layout.fillWidth: true; color: theme.textMain; placeholderText: "alice" }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: qsTr("Domain (optional)"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
                LoafTextField { id: smbDomainField; Layout.fillWidth: true; color: theme.textMain; placeholderText: "WORKGROUP" }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LoafButton { text: qsTr("Cancel"); variant: "text"; onClicked: smbDialog.close() }
            LoafButton {
                text: smbDialog.editingId.length > 0 ? qsTr("Save") : qsTr("Add")
                variant: "filled"
                enabled: smbServerField.text.trim().length > 0 && smbShareField.text.trim().length > 0
                onClicked: {
                    var id = core.save_smb_profile(smbDialog.editingId, smbNameField.text, smbServerField.text, smbShareField.text, smbUserField.text, smbDomainField.text);
                    if (id.length === 0) {
                        window.toast("error", qsTr("A server and share are required"));
                        return;
                    }
                    smbDialog.editingId = id;
                    smbDialog.close();
                    window.toast("info", qsTr("SMB share saved"));
                }
            }
        }
    }
    LoafDialog {
        id: confirmDialog
        dialogWidth: 420
        property string message: ""
        property string actionText: qsTr("OK")
        property var onConfirm: null
        // Requests that arrive while one is open wait their turn instead of
        // silently replacing it (its button would then do something else).
        property var queue: []
        function ask(t, msg, action, fn) {
            if (visible) {
                queue = queue.concat([[t, msg, action, fn]]);
                return;
            }
            title = t;
            message = msg;
            actionText = action;
            onConfirm = fn;
            open();
        }
        onClosed: {
            if (queue.length > 0) {
                var next = queue[0];
                queue = queue.slice(1);
                Qt.callLater(function() { confirmDialog.ask(next[0], next[1], next[2], next[3]); });
            }
        }
        Text {
            Layout.fillWidth: true
            text: confirmDialog.message
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LoafButton { text: qsTr("Cancel"); variant: "text"; onClicked: confirmDialog.close() }
            LoafButton {
                text: confirmDialog.actionText
                variant: "danger"
                onClicked: {
                    var fn = confirmDialog.onConfirm;
                    confirmDialog.close();
                    if (fn)
                        fn();
                }
            }
        }
    }
    LoafDialog {
        id: placeEdit
        title: qsTr("Edit Sidebar Entry")
        dialogWidth: 440
        property var place: ({})
        function openFor(p) {
            place = p;
            nameField.text = p.name;
            pathField.text = p.path;
            open();
        }
        onOpened: { nameField.forceActiveFocus(); nameField.selectAll(); }
        Text { text: qsTr("Name"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
        LoafTextField { id: nameField; Layout.fillWidth: true; color: theme.textMain }
        Text { text: qsTr("Folder"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
        LoafTextField {
            id: pathField
            Layout.fillWidth: true
            color: theme.textMain
            font.family: "monospace"
            Keys.onTabPressed: function(e) { text = core.complete_path(text, true); e.accepted = true; }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LoafButton { text: qsTr("Cancel"); variant: "text"; onClicked: placeEdit.close() }
            LoafButton {
                text: qsTr("Save")
                variant: "filled"
                onClicked: {
                    core.edit_place(placeEdit.place.id, nameField.text.trim() || placeEdit.place.name, pathField.text.trim());
                    placeEdit.close();
                }
            }
        }
    }
    LoafDialog {
        id: customizePlaces
        title: qsTr("Customize Sidebar")
        dialogWidth: 440
        property var all: []
        onOpened: all = JSON.parse(core.all_places_json() || "[]")
        Connections {
            target: core
            function onPlaces_jsonChanged() {
                if (customizePlaces.visible)
                    customizePlaces.all = JSON.parse(core.all_places_json() || "[]");
            }
        }
        ListView {
            id: customizePlacesList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(380, contentHeight)
            clip: true
            model: customizePlaces.all
            ScrollBar.vertical: ScrollBar {}
            spacing: 4

            delegate: Rectangle {
                id: placeRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 40
                radius: theme.radiusM
                color: dragHandleArea.containsMouse ? theme.hoverOverlay : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10
                    Item {
                        width: 20; height: 32
                        LoafIcon {
                            anchors.centerIn: parent
                            name: "dots-six-vertical"
                            size: 16
                            color: dragHandleArea.containsMouse ? theme.primary : theme.outline
                        }
                        MouseArea {
                            id: dragHandleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.SizeVerCursor
                            property int startY: 0
                            property int startIdx: -1
                            onPressed: function(mouse) {
                                startY = mouse.y;
                                startIdx = placeRow.index;
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var pt = mapToItem(customizePlacesList.contentItem, mouse.x, mouse.y);
                                    var targetIdx = Math.max(0, Math.min(customizePlaces.all.length - 1, Math.floor(pt.y / 44)));
                                    if (targetIdx !== placeRow.index) {
                                        core.move_place(placeRow.modelData.id, targetIdx);
                                    }
                                }
                            }
                        }
                    }

                    LoafIcon {
                        name: placeRow.modelData.icon || "folder"
                        size: 16
                        color: placeRow.modelData.hidden ? theme.outline : theme.primary
                    }

                    Text {
                        text: placeRow.modelData.name || ""
                        color: placeRow.modelData.hidden ? theme.textMuted : theme.textMain
                        font.pixelSize: theme.fs(13)
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        opacity: placeRow.modelData.hidden ? 0.55 : 1.0
                    }
                    LoafButton {
                        icon: placeRow.modelData.hidden ? "eye-slash" : "eye"
                        variant: "text"
                        Accessible.name: placeRow.modelData.hidden ? qsTr("Show in sidebar") : qsTr("Hide from sidebar")
                        onClicked: core.set_place_hidden(placeRow.modelData.id, !placeRow.modelData.hidden)
                    }
                    LoafButton {
                        icon: "trash"
                        variant: "text"
                        enabled: placeRow.modelData.kind === "bookmark" || (placeRow.modelData.id && placeRow.modelData.id.indexOf("bookmark:") === 0)
                        Accessible.name: qsTr("Remove bookmark")
                        onClicked: {
                            if (placeRow.modelData.path)
                                core.remove_bookmark(placeRow.modelData.path);
                            else
                                core.set_place_hidden(placeRow.modelData.id, true);
                        }
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: theme.separator }
        LoafSwitch {
            label: qsTr("Hide Trash when empty (shows when dragging)")
            checked: theme.hideTrashWhenEmpty
            onToggled: function(c) { theme.hideTrashWhenEmpty = c; }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            LoafButton {
                text: qsTr("Add Place…")
                icon: "plus"
                variant: "tonal"
                onClicked: addPlacePrompt.open()
            }
            LoafButton {
                text: qsTr("Reset")
                variant: "text"
                onClicked: core.reset_places()
            }
            Item { Layout.fillWidth: true }
            LoafButton {
                text: qsTr("Done")
                variant: "filled"
                onClicked: customizePlaces.close()
            }
        }
    }

    LoafTextPrompt {
        id: addPlacePrompt
        title: qsTr("Add Place to Sidebar")
        label: qsTr("Enter the full path of the folder to add:")
        placeholder: "/home/user/my-folder"
        confirmText: qsTr("Add")
        selectBasename: false
        onAccepted: function(pathText) {
            var p = (pathText || "").trim();
            if (p.length > 0) {
                core.add_bookmark(p);
            }
        }
    }
    LoafDialog {
        id: customizeContextMenuDialog
        title: qsTr("Customize Context Menu Actions")
        dialogWidth: 440

        readonly property var baseActions: [
            { id: "open", name: qsTr("Open"), icon: "arrow-square-out", shortcut: "Enter" },
            { id: "new_tab", name: qsTr("Open in New Tab"), icon: "tabs", shortcut: "" },
            { id: "open_with", name: qsTr("Open With"), icon: "app-window", shortcut: "" },
            { id: "open_containing", name: qsTr("Open Containing Folder"), icon: "folder-open", shortcut: "" },
            { id: "quick_look", name: qsTr("Quick Look"), icon: "eye", shortcut: "Space" },
            { id: "terminal", name: qsTr("Open in Terminal"), icon: "terminal", shortcut: "" },
            { id: "cut", name: qsTr("Cut"), icon: "scissors", shortcut: "Ctrl+X" },
            { id: "copy", name: qsTr("Copy"), icon: "copy", shortcut: "Ctrl+C" },
            { id: "copy_path", name: qsTr("Copy Path"), icon: "copy-simple", shortcut: "Ctrl+Shift+C" },
            { id: "paste", name: qsTr("Paste"), icon: "clipboard", shortcut: "Ctrl+V" },
            { id: "rename", name: qsTr("Rename"), icon: "pencil-simple", shortcut: "F2" },
            { id: "duplicate", name: qsTr("Duplicate"), icon: "copy-simple", shortcut: "" },
            { id: "make_link", name: qsTr("Make Link"), icon: "link", shortcut: "" },
            { id: "share", name: qsTr("Share…"), icon: "share-network", shortcut: "" },
            { id: "compress", name: qsTr("Compress"), icon: "file-archive", shortcut: "" },
            { id: "extract", name: qsTr("Extract"), icon: "archive", shortcut: "" },
            { id: "browse_archive", name: qsTr("Browse Archive"), icon: "folder-open", shortcut: "" },
            { id: "star", name: qsTr("Star / Unstar"), icon: "star", shortcut: "" },
            { id: "pin", name: qsTr("Add / Remove from Sidebar"), icon: "push-pin", shortcut: "Ctrl+D" },
            { id: "scripts", name: qsTr("Scripts"), icon: "scroll", shortcut: "" },
            { id: "admin", name: qsTr("Open as Administrator"), icon: "shield-check", shortcut: "" },
            { id: "delete", name: qsTr("Move to Trash"), icon: "trash", shortcut: "Del" },
            { id: "permanent_delete", name: qsTr("Delete Permanently"), icon: "x-circle", shortcut: "Shift+Del" },
            { id: "properties", name: qsTr("Properties"), icon: "info", shortcut: "Alt+Enter" },
            { id: "new", name: qsTr("New…"), icon: "plus-circle", shortcut: "" },
            { id: "select_all", name: qsTr("Select All"), icon: "selection-all", shortcut: "Ctrl+A" },
            { id: "select_pattern", name: qsTr("Select by Pattern…"), icon: "selection", shortcut: "Ctrl+S" }
        ]

        property var orderedActions: []

        function refreshActions() {
            var savedOrder = [];
            try {
                var raw = core.get_setting("contextMenuOrder");
                if (raw && raw.length > 0) savedOrder = JSON.parse(raw);
            } catch (e) {}

            var list = baseActions.slice();
            if (savedOrder.length > 0) {
                list.sort(function(a, b) {
                    var ia = savedOrder.indexOf(a.id);
                    var ib = savedOrder.indexOf(b.id);
                    if (ia === -1 && ib === -1) return 0;
                    if (ia === -1) return 1;
                    if (ib === -1) return -1;
                    return ia - ib;
                });
            }
            orderedActions = list;
        }

        onOpened: refreshActions()

        function moveAction(fromIdx, toIdx) {
            if (fromIdx === toIdx || fromIdx < 0 || toIdx < 0 || fromIdx >= orderedActions.length || toIdx >= orderedActions.length)
                return;
            var list = orderedActions.slice();
            var item = list.splice(fromIdx, 1)[0];
            list.splice(toIdx, 0, item);
            orderedActions = list;
            var orderIds = list.map(function(x) { return x.id; });
            core.set_setting("contextMenuOrder", JSON.stringify(orderIds));
        }

        ListView {
            id: customizeContextMenuList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(380, contentHeight)
            clip: true
            model: customizeContextMenuDialog.orderedActions
            ScrollBar.vertical: ScrollBar {}
            spacing: 4

            delegate: Rectangle {
                id: actionRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 40
                radius: theme.radiusM
                color: actionDragHandle.containsMouse ? theme.hoverOverlay : "transparent"

                readonly property bool isHidden: !!(theme.disabledMenuItems && theme.disabledMenuItems[modelData.id])

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10
                    Item {
                        width: 20; height: 32
                        LoafIcon {
                            anchors.centerIn: parent
                            name: "dots-six-vertical"
                            size: 16
                            color: actionDragHandle.containsMouse ? theme.primary : theme.outline
                        }
                        MouseArea {
                            id: actionDragHandle
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.SizeVerCursor
                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    var pt = mapToItem(customizeContextMenuList.contentItem, mouse.x, mouse.y);
                                    var targetIdx = Math.max(0, Math.min(customizeContextMenuDialog.orderedActions.length - 1, Math.floor(pt.y / 44)));
                                    if (targetIdx !== actionRow.index) {
                                        customizeContextMenuDialog.moveAction(actionRow.index, targetIdx);
                                    }
                                }
                            }
                        }
                    }

                    LoafIcon {
                        name: actionRow.modelData.icon || "circle"
                        size: 16
                        color: actionRow.isHidden ? theme.outline : theme.primary
                    }

                    Text {
                        text: actionRow.modelData.name || ""
                        color: actionRow.isHidden ? theme.textMuted : theme.textMain
                        font.pixelSize: theme.fs(13)
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        opacity: actionRow.isHidden ? 0.55 : 1.0
                    }

                    Text {
                        visible: actionRow.modelData.shortcut && actionRow.modelData.shortcut.length > 0
                        text: actionRow.modelData.shortcut || ""
                        color: theme.textMuted
                        font.pixelSize: theme.fs(11)
                    }
                    LoafButton {
                        icon: actionRow.isHidden ? "eye-slash" : "eye"
                        variant: "text"
                        Accessible.name: actionRow.isHidden ? qsTr("Show in context menu") : qsTr("Hide from context menu")
                        onClicked: {
                            var map = Object.assign({}, theme.disabledMenuItems || {});
                            if (actionRow.isHidden) {
                                delete map[actionRow.modelData.id];
                            } else {
                                map[actionRow.modelData.id] = true;
                            }
                            theme.disabledMenuItems = map;
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            LoafButton {
                text: qsTr("Reset to Default")
                variant: "text"
                onClicked: {
                    theme.disabledMenuItems = {};
                    theme.contextMenuMode = "full";
                    core.set_setting("contextMenuOrder", "[]");
                    customizeContextMenuDialog.refreshActions();
                }
            }
            Item { Layout.fillWidth: true }
            LoafButton {
                text: qsTr("Done")
                variant: "filled"
                onClicked: customizeContextMenuDialog.close()
            }
        }
    }
}
