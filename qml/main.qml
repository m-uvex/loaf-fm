import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import app.loaf

ApplicationWindow {
    id: window
    width: 1080
    height: 720
    minimumWidth: 760
    minimumHeight: 500
    visible: true
    title: "Loaf - " + (activeView === "settings"
        ? ("Settings - " + (settingsView ? (settingsView.activeTab === 0 ? "Interface" : (settingsView.activeTab === 1 ? "Behavior" : (settingsView.activeTab === 2 ? "Experimental" : "About Loaf"))) : "Settings"))
        : activeView === "pc" ? (engine.hostname || "This PC")
        : (engine.is_searching_everywhere ? "Searching Everywhere" : engine.current_dir_name))
    color: theme.background

    property bool sidebarExpanded: false
    property string activeView: "files" // "files", "settings", or "pc"
    property int currentNavIndex: 1      // nav rows: 0 = PC, 1 = Home, ...
    property int currentPlaceIndex: 1    // last clicked place row (pill position when in files view)
    property bool isEditingPath: false

    // Views that show the back button and aren't the file grid (back returns to files)
    readonly property bool isAuxView: activeView === "settings" || activeView === "pc"

    // Return to the file grid, restoring the nav pill to the last place row.
    // placeIdx >= 0 also updates which place is considered active (e.g. PCView jumps).
    function showFiles(placeIdx) {
        activeView = "files";
        if (placeIdx !== undefined && placeIdx >= 0) {
            currentPlaceIndex = placeIdx;
        }
        currentNavIndex = currentPlaceIndex;
    }

    function startEditingPath() {
        if (activeView !== "files") return;
        pathInput.text = engine.current_path;
        isEditingPath = true;
        pathInput.forceActiveFocus();
        pathInput.selectAll();
    }

    function commitPathEdit() {
        var raw = pathInput.text.trim();
        if (raw.length > 0) {
            engine.set_path(raw);
        }
        isEditingPath = false;
    }

    function copySelected(isCut) {
        if (activeView !== "files") return;
        var items = gridContainer.getSelectedItems();
        if (items.length === 0) return;
        var paths = items.map(function(it) {
            return engine.is_searching_everywhere ? it.path : (engine.current_path + "/" + it.name);
        });
        engine.copy_items(JSON.stringify(paths), isCut);
    }

    function triggerPaste() {
        if (activeView !== "files") return;
        var conflictsJson = engine.check_clipboard_conflicts(engine.current_path);
        var conflicts = JSON.parse(conflictsJson || "[]");
        if (conflicts.length > 0) {
            conflictModal.showForClipboard(conflicts, engine.current_path);
        } else {
            engine.paste_items(engine.current_path);
        }
    }

    function handleDrop(paths, destDir, asCopy) {
        var conflictsJson = engine.check_paste_conflicts(JSON.stringify(paths), destDir);
        var conflicts = JSON.parse(conflictsJson || "[]");
        if (conflicts.length > 0) {
            conflictModal.showForDrop(conflicts, paths, destDir, asCopy);
        } else {
            engine.drop_items(JSON.stringify(paths), destDir, asCopy);
        }
    }

    function renameSelected() {
        if (activeView !== "files") return;
        var items = gridContainer.getSelectedItems();
        if (items.length === 1) {
            inputModal.showRename(items[0].name);
        }
    }

    function trashSelected() {
        if (activeView !== "files") return;
        var items = gridContainer.getSelectedItems();
        if (items.length === 0) return;
        var paths = items.map(function(it) {
            return engine.is_searching_everywhere ? it.path : (engine.current_path + "/" + it.name);
        });
        engine.trash_items(JSON.stringify(paths));
        gridContainer.clearSelection();
    }

    // True while the user is navigating the file grid/list from the keyboard,
    // used to draw a visible focus ring.
    property bool keyboardNavActive: false

    // Responsive list-column visibility: fixed columns drop out as the window
    // narrows so nothing overlaps at 760px.
    readonly property bool listShowDate: width >= 820
    readonly property bool listShowSize: width >= 900
    readonly property bool listShowType: width >= 980

    // True while any modal dialog is open (arrow keys / shortcuts must not fire).
    readonly property bool anyModalOpen: inputModal.visible || propsModal.visible
        || conflictModal.visible || passwordModal.visible || quickLook.visible
        || commandModal.visible || window.isEditingPath

    // Opens (or closes) the Quick Look preview for the current selection.
    function toggleQuickLook() {
        if (quickLook.visible) {
            quickLook.close();
            return;
        }
        if (activeView !== "files") return;
        var items = gridContainer.getSelectedItems();
        if (items.length === 0) return;
        var it = items[items.length - 1];
        var path = engine.is_searching_everywhere ? it.path : (engine.current_path + "/" + it.name);
        quickLook.showFor(path);
    }

    // True when a plain keystroke should be routed to the grid/list (no input
    // field focused, files view visible, no modal open).
    readonly property bool gridKeyboardReady: window.activeView === "files"
        && !searchInput.activeFocus && !pathInput.activeFocus && !window.anyModalOpen

    // Global Keyboard Shortcuts. Each is *enabled* only when it should apply so
    // that a disabled shortcut never swallows the key from a focused text field.
    Shortcut { sequence: "Ctrl+Z"; enabled: engine.can_undo && !window.anyModalOpen; onActivated: engine.undo() }
    Shortcut { sequence: "Ctrl+Y"; enabled: engine.can_redo && !window.anyModalOpen; onActivated: engine.redo() }
    Shortcut { sequence: "Ctrl+Shift+Z"; enabled: engine.can_redo && !window.anyModalOpen; onActivated: engine.redo() }
    Shortcut { sequence: "Ctrl+C"; enabled: window.gridKeyboardReady; onActivated: window.copySelected(false) }
    Shortcut { sequence: "Ctrl+X"; enabled: window.gridKeyboardReady; onActivated: window.copySelected(true) }
    Shortcut { sequence: "Ctrl+V"; enabled: window.activeView === "files" && !window.anyModalOpen && !searchInput.activeFocus && !pathInput.activeFocus; onActivated: window.triggerPaste() }
    Shortcut { sequence: "Ctrl+A"; enabled: window.gridKeyboardReady; onActivated: gridContainer.selectAll() }
    Shortcut { sequence: "Ctrl+H"; onActivated: engine.toggle_show_hidden() }
    Shortcut { sequence: "Ctrl+L"; onActivated: window.startEditingPath() }
    Shortcut { sequence: "F2"; enabled: window.gridKeyboardReady; onActivated: window.renameSelected() }
    // Stays enabled while the preview is open so Space toggles it shut again.
Shortcut { sequence: "Space"; enabled: quickLook.visible || window.gridKeyboardReady; onActivated: window.toggleQuickLook() }
    Shortcut { sequence: "Delete"; enabled: window.gridKeyboardReady; onActivated: window.trashSelected() }
    Shortcut { sequence: "Alt+Left"; enabled: engine.can_go_back; onActivated: engine.go_back() }
    Shortcut { sequence: "Alt+Right"; enabled: engine.can_go_forward; onActivated: engine.go_forward() }
    Shortcut { sequence: "Alt+Up"; onActivated: engine.navigate_up() }
    Shortcut { sequence: "Backspace"; enabled: window.gridKeyboardReady && engine.can_go_back; onActivated: engine.go_back() }
    // NOTE: Return / Enter are handled in globalKeyHandler below (not as a
    // Shortcut) so they are never swallowed from a focused text field.

    // Full-window catcher for mouse back / forward side buttons. It sits below
    // the shell (z: 0) and only accepts the two extra buttons, so ordinary
    // clicks are untouched while the side buttons always navigate history.
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onPressed: function(mouse) {
            if (mouse.button === Qt.BackButton) {
                if (engine.can_go_back) engine.go_back();
            } else if (mouse.button === Qt.ForwardButton) {
                if (engine.can_go_forward) engine.go_forward();
            }
        }
    }

    Item {
        id: globalKeyHandler
        anchors.fill: parent
        focus: true
        z: -100

        Keys.onPressed: function(event) {
            if (window.anyModalOpen) {
                return;
            }

            // Always-on arrow navigation + open, for both grid and list views.
            if (window.gridKeyboardReady) {
                switch (event.key) {
                case Qt.Key_Up:
                    window.keyboardNavActive = true;
                    gridContainer.moveSelection(0, -1, !!(event.modifiers & Qt.ShiftModifier));
                    event.accepted = true;
                    return;
                case Qt.Key_Down:
                    window.keyboardNavActive = true;
                    gridContainer.moveSelection(0, 1, !!(event.modifiers & Qt.ShiftModifier));
                    event.accepted = true;
                    return;
                case Qt.Key_Left:
                    if (engine.view_mode !== "list") {
                        window.keyboardNavActive = true;
                        gridContainer.moveSelection(-1, 0, !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                        return;
                    }
                    break;
                case Qt.Key_Right:
                    if (engine.view_mode !== "list") {
                        window.keyboardNavActive = true;
                        gridContainer.moveSelection(1, 0, !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                        return;
                    }
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    gridContainer.openSelected();
                    event.accepted = true;
                    return;
                }
            }

            // Type-to-search: any printable key pulls focus into the search bar.
            if (!searchInput.activeFocus && window.activeView === "files") {
                if (!(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    if (event.text.length > 0 && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backspace && event.key !== Qt.Key_Delete) {
                        searchInput.forceActiveFocus();
                        searchInput.text = event.text;
                        searchInput.cursorPosition = 1;
                        event.accepted = true;
                    }
                }
            }
        }
    }

    LoafEngine {
        id: engine
        onCurrent_pathChanged: {
            gridContainer.clearSelection();
            window.keyboardNavActive = false;
            // dirTransitionAnim is restarted here only: one transition per
            // navigation, even if both the path and the active view change.
            dirTransitionAnim.restart();
        }
    }

    ParallelAnimation {
        id: dirTransitionAnim

        NumberAnimation {
            target: mainStageContent
            property: "opacity"
            from: 0.2
            to: 1.0
            duration: 170
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: stageTranslate
            property: "y"
            from: 10
            to: 0
            duration: 190
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: stageScale
            property: "xScale"
            from: 0.985
            to: 1.0
            duration: 190
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: stageScale
            property: "yScale"
            from: 0.985
            to: 1.0
            duration: 190
            easing.type: Easing.OutCubic
        }
    }

    Theme {
        id: theme
    }

    FontLoader {
        id: phosphorFontRegular
        source: "qrc:/loaf/fonts/Phosphor.ttf"
    }

    FontLoader {
        id: phosphorFontBold
        source: "qrc:/loaf/fonts/Phosphor-Bold.ttf"
    }

    // ==========================================
    // ORGANIC BACKGROUND SHAPES
    // ==========================================
    Item {
        anchors.fill: parent
        z: 0

        Rectangle {
            width: 420
            height: 220
            radius: 200
            x: -40
            y: -50
            color: theme.primaryContainer
            opacity: theme.isDark ? 0.22 : 0.35
        }

        Rectangle {
            width: 380
            height: 380
            radius: 190
            x: parent.width - 280
            y: parent.height - 300
            color: theme.secondaryContainer
            opacity: theme.isDark ? 0.18 : 0.28
        }
    }

    // ==========================================
    // APP SHELL
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        z: 1

        // Top Navigation Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: 10

            // Brand Pill (width + opacity animate on show/hide)
            Rectangle {
                id: brandBadge
                property real badgeWidth: theme.showBrandBadge ? (brandRow.implicitWidth + 24) : 0
                Layout.preferredWidth: badgeWidth
                Layout.minimumWidth: 0
                height: 42
                opacity: theme.showBrandBadge ? 1.0 : 0.0
                visible: opacity > 0.001
                radius: theme.radiusFull
                color: theme.surfaceContainer

                Behavior on badgeWidth { SpringAnimation { spring: 3.8; damping: 0.35 } }
                Behavior on opacity { NumberAnimation { duration: theme.durationFast; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: brandRow
                    anchors.centerIn: parent
                    spacing: 8
                    clip: true

                    LoafIcon {
                        name: "bread"
                        size: 18
                        color: theme.primary
                    }
                    Text {
                        text: "Loaf"
                        color: theme.textMain
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
            }

            // Navigation History Chip (Back & Forward)
            Rectangle {
                id: navHistoryChip
                height: 42
                radius: theme.radiusFull
                color: theme.surfaceContainer
                clip: true

                readonly property bool canBack: engine.can_go_back || window.isAuxView || engine.is_searching_everywhere
                readonly property bool canForward: engine.can_go_forward && !window.isAuxView && !engine.is_searching_everywhere

                opacity: (canBack || canForward) ? 1.0 : 0.0
                property real chipWidth: (canBack || canForward)
                    ? ((canBack && canForward) ? 82 : 44)
                    : 0
                Layout.preferredWidth: chipWidth

                Behavior on chipWidth { SpringAnimation { spring: 3.8; damping: 0.32 } }
                Behavior on opacity { NumberAnimation { duration: theme.durationFast } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    // Back Button
                    Item {
                        visible: navHistoryChip.canBack
                        width: 36
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: backBtnMouse.containsMouse ? theme.hoverOverlay : "transparent"

                            LoafIcon {
                                visible: theme.iconSource === "phosphor"
                                anchors.centerIn: parent
                                name: "caret-left"
                                size: 18
                                color: theme.textMain
                            }

                            Image {
                                visible: theme.iconSource === "system"
                                anchors.centerIn: parent
                                source: engine.resolve_icon("go-previous-symbolic")
                                width: 18
                                height: 18
                                sourceSize.width: 36
                                sourceSize.height: 36
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                id: backBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (engine.is_searching_everywhere) {
                                        engine.clear_search_everywhere();
                                        searchInput.text = "";
                                    } else if (window.activeView === "settings") {
                                        if (searchInput.text.length > 0) {
                                            searchInput.text = "";
                                        } else if (settingsView && settingsView.activeTab > 0) {
                                            settingsView.activeTab = 0;
                                        } else {
                                            window.showFiles();
                                        }
                                    } else if (window.activeView === "pc") {
                                        window.showFiles();
                                    } else {
                                        engine.go_back();
                                    }
                                }
                            }
                        }
                    }

                    // Divider if both can be pressed
                    Rectangle {
                        visible: navHistoryChip.canBack && navHistoryChip.canForward
                        width: 1
                        height: 18
                        color: theme.outlineVariant
                    }

                    // Forward Button
                    Item {
                        visible: navHistoryChip.canForward
                        width: 36
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: fwdBtnMouse.containsMouse ? theme.hoverOverlay : "transparent"

                            LoafIcon {
                                visible: theme.iconSource === "phosphor"
                                anchors.centerIn: parent
                                name: "caret-right"
                                size: 18
                                color: theme.textMain
                            }

                            Image {
                                visible: theme.iconSource === "system"
                                anchors.centerIn: parent
                                source: engine.resolve_icon("go-next-symbolic")
                                width: 18
                                height: 18
                                sourceSize.width: 36
                                sourceSize.height: 36
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                id: fwdBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: engine.go_forward()
                            }
                        }
                    }
                }
            }

            // Path Bar in Center
            Rectangle {
                id: pathBarContainer
                visible: window.activeView !== "pc"
                Layout.fillWidth: true
                Layout.minimumWidth: 140
                Layout.preferredHeight: 42
                radius: theme.radiusFull
                color: window.isEditingPath ? theme.surfaceContainerHighest : theme.surfaceContainer
                clip: true

                Behavior on color { ColorAnimation { duration: theme.durationFast } }

                // Direct Path Input (Active when isEditingPath is true)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 8
                    visible: window.isEditingPath && window.activeView === "files"

                    LoafIcon {
                        name: "folder"
                        size: 16
                        color: theme.primary
                    }

                    TextInput {
                        id: pathInput
                        Layout.fillWidth: true
                        color: theme.textMain
                        font.pixelSize: 13
                        font.family: "monospace"
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        Keys.onReturnPressed: function(event) {
                            window.commitPathEdit();
                            event.accepted = true;
                        }
                        Keys.onEnterPressed: function(event) {
                            window.commitPathEdit();
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: function(event) {
                            window.isEditingPath = false;
                            event.accepted = true;
                        }
                    }

                    // Checkmark commit button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: pathCommitMouse.containsMouse ? theme.primaryContainer : "transparent"
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }

                        LoafIcon {
                            anchors.centerIn: parent
                            name: "check"
                            size: 14
                            color: theme.primary
                        }

                        MouseArea {
                            id: pathCommitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.commitPathEdit()
                        }
                    }
                }

                // Background click on path bar opens direct edit
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onPressed: {
                        if (searchInput.activeFocus)
                            searchInput.focus = false;
                    }
                    onDoubleClicked: window.startEditingPath()
                }

                // Files Breadcrumbs
                ListView {
                    id: breadcrumbs
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    orientation: ListView.Horizontal
                    spacing: 4
                    clip: true
                    visible: !window.isEditingPath && window.activeView === "files" && !engine.is_searching_everywhere

                    model: JSON.parse(engine.breadcrumbs_json || "[]")

                    populate: Transition {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: 170; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                    }
                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: 170; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                    }

                    delegate: RowLayout {
                        height: breadcrumbs.height
                        spacing: 4

                        Item {
                            id: chipContainer
                            height: 32
                            width: chipRow.implicitWidth + 22

                            readonly property bool isHoverDropTarget: dragManager.active && dragManager.hoverTarget === modelData.path

                            Rectangle {
                                anchors.fill: parent
                                radius: theme.radiusFull
                                color: chipContainer.isHoverDropTarget
                                    ? theme.primaryContainer
                                    : (modelData.is_forward
                                        ? "transparent"
                                        : ((index === breadcrumbs.count - 1 && !modelData.is_forward) ? theme.secondaryContainer : theme.hoverOverlay))
                                border.color: chipContainer.isHoverDropTarget ? theme.primary : (modelData.is_forward ? theme.outline : "transparent")
                                border.width: (chipContainer.isHoverDropTarget || modelData.is_forward) ? 1 : 0
                                opacity: (chipContainer.isHoverDropTarget || index === breadcrumbs.count - 1 || modelData.is_forward || cMouse.containsMouse) ? 1.0 : 0.0

                                Behavior on opacity {
                                    NumberAnimation { duration: theme.durationFast }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: theme.durationFast }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                keys: ["text/uri-list"]
                                onEntered: {
                                    dragManager.hoverTarget = modelData.path;
                                }
                                onExited: {
                                    if (dragManager.hoverTarget === modelData.path) {
                                        dragManager.hoverTarget = "";
                                    }
                                }
                                onDropped: function(drop) {
                                    if (!drop.hasUrls) return;
                                    var dest = modelData.path;
                                    dragManager.hoverTarget = "";
                                    var paths = [];
                                    for (var i = 0; i < drop.urls.length; ++i) {
                                        var u = drop.urls[i].toString();
                                        if (u.startsWith("file://")) u = u.slice(7);
                                        if (u === dest) continue;
                                        paths.push(u);
                                    }
                                    if (paths.length === 0) return;
                                    var asCopy = (drop.source === dragProxy) ? dragManager.asCopy : (drop.proposedAction === Qt.CopyAction);
                                    drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                                    if (dragManager.isRmb) {
                                        var pt = mapToItem(window.contentItem, cMouse.mouseX, cMouse.mouseY);
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

                                // Iconic root place icon
                                Item {
                                    width: 16
                                    height: 16
                                    visible: modelData.is_root_place

                                    LoafIcon {
                                        visible: theme.iconSource === "phosphor"
                                        anchors.centerIn: parent
                                        name: modelData.icon || "folder"
                                        size: 15
                                        color: (index === breadcrumbs.count - 1) ? theme.secondaryContainerFg : theme.textMain
                                    }

                                    Image {
                                        visible: theme.iconSource === "system"
                                        anchors.centerIn: parent
                                        source: engine.resolve_icon(modelData.system_icon || "folder")
                                        width: 15
                                        height: 15
                                        sourceSize.width: 32
                                        sourceSize.height: 32
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                                Text {
                                    id: chipTxt
                                    text: modelData.name
                                    color: modelData.is_forward
                                        ? theme.textMuted
                                        : ((index === breadcrumbs.count - 1) ? theme.secondaryContainerFg : (cMouse.containsMouse ? theme.textMain : theme.textMuted))
                                    font.pixelSize: 12
                                    font.bold: index === breadcrumbs.count - 1 && !modelData.is_forward

                                    Behavior on color {
                                        ColorAnimation { duration: theme.durationFast }
                                    }
                                }
                            }

                            scale: cMouse.pressed ? 0.94 : (cMouse.containsMouse ? 1.04 : 1.0)
                            Behavior on scale { SpringAnimation { spring: 3.8; damping: 0.3 } }

                            MouseArea {
                                id: cMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: engine.set_path(modelData.path)
                            }
                        }

                        LoafIcon {
                            visible: index < breadcrumbs.count - 1
                            name: "caret-right"
                            size: 11
                            color: theme.outline
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // PC Breadcrumb Chip
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6
                    visible: window.activeView === "pc"

                    Item {
                        height: 32
                        width: pcChipRow.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: theme.secondaryContainer
                        }

                        RowLayout {
                            id: pcChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            LoafIcon {
                                visible: theme.iconSource === "phosphor"
                                name: "desktop"
                                size: 15
                                color: theme.secondaryContainerFg
                            }
                            Image {
                                visible: theme.iconSource === "system"
                                source: engine.resolve_icon("computer-symbolic")
                                width: 15
                                height: 15
                                sourceSize.width: 32
                                sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                text: engine.hostname || "This PC"
                                color: theme.secondaryContainerFg
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                }

                // Settings Path Bar Header: <Settings icon> Settings > Behavior
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6
                    visible: window.activeView === "settings"

                    // Chip 1: <Settings icon> Settings
                    Item {
                        id: settingsRootChip
                        height: 32
                        width: settingsChipRow.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: (settingsView.searchQuery.length === 0 && settingsView.activeTab === 0)
                                ? theme.secondaryContainer
                                : (settingsChipMouse.containsMouse ? theme.surfaceContainerHigh : "transparent")

                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        }

                        RowLayout {
                            id: settingsChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            LoafIcon {
                                visible: theme.iconSource === "phosphor"
                                name: "gear"
                                size: 15
                                color: (settingsView.searchQuery.length === 0 && settingsView.activeTab === 0)
                                    ? theme.secondaryContainerFg
                                    : (settingsChipMouse.containsMouse ? theme.textMain : theme.textMuted)
                            }

                            Image {
                                visible: theme.iconSource === "system"
                                source: engine.resolve_icon("preferences-system-symbolic")
                                width: 14
                                height: 14
                                sourceSize.width: 28
                                sourceSize.height: 28
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: "Settings"
                                color: (settingsView.searchQuery.length === 0 && settingsView.activeTab === 0)
                                    ? theme.secondaryContainerFg
                                    : (settingsChipMouse.containsMouse ? theme.textMain : theme.textMuted)
                                font.pixelSize: 12
                                font.bold: (settingsView.searchQuery.length === 0 && settingsView.activeTab === 0)
                            }
                        }

                        scale: settingsChipMouse.pressed ? 0.94 : (settingsChipMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 3.8; damping: 0.3 } }

                        MouseArea {
                            id: settingsChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                settingsView.activeTab = 0;
                            }
                        }
                    }

                    // Separator Caret
                    LoafIcon {
                        name: "caret-right"
                        size: 11
                        color: theme.outline
                        Layout.alignment: Qt.AlignVCenter
                        visible: settingsView.searchQuery.length > 0 || settingsView.activeTab > 0
                    }

                    // Chip 2: Active Tab or Search Query
                    Item {
                        visible: settingsView.searchQuery.length > 0 || settingsView.activeTab > 0
                        height: 32
                        width: subTabTxt.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: theme.secondaryContainer
                        }

                        Text {
                            id: subTabTxt
                            anchors.centerIn: parent
                            text: settingsView.searchQuery.length > 0
                                ? ("Search: \"" + searchInput.text + "\"")
                                : (settingsView.activeTab === 0 ? "Interface" : (settingsView.activeTab === 1 ? "Behavior" : (settingsView.activeTab === 2 ? "Experimental" : "About Loaf")))
                            color: theme.secondaryContainerFg
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Search Everywhere Breadcrumb: <Globe icon> Search Everywhere > [Query]
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6
                    visible: engine.is_searching_everywhere

                    // Centring spacers fill the bar so the chips sit mid-bar
                    // instead of leaving a large empty gap on one side.
                    Item { Layout.fillWidth: true }

                    // Chip 1: <Globe icon> Search Everywhere (Click to exit)
                    Item {
                        height: 32
                        width: seChipRow.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: (searchInput.text.trim().length === 0)
                                ? theme.secondaryContainer
                                : (seChipMouse.containsMouse ? theme.surfaceContainerHigh : "transparent")

                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                        }

                        RowLayout {
                            id: seChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            LoafIcon {
                                name: "globe"
                                size: 14
                                color: (searchInput.text.trim().length === 0)
                                    ? theme.secondaryContainerFg
                                    : (seChipMouse.containsMouse ? theme.textMain : theme.textMuted)
                            }

                            Text {
                                text: "Search Everywhere"
                                color: (searchInput.text.trim().length === 0)
                                    ? theme.secondaryContainerFg
                                    : (seChipMouse.containsMouse ? theme.textMain : theme.textMuted)
                                font.pixelSize: 12
                                font.bold: searchInput.text.trim().length === 0
                            }
                        }

                        scale: seChipMouse.pressed ? 0.94 : (seChipMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { SpringAnimation { spring: 3.8; damping: 0.3 } }

                        MouseArea {
                            id: seChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engine.clear_search_everywhere();
                                searchInput.text = "";
                            }
                        }
                    }

                    // Separator Caret
                    LoafIcon {
                        visible: searchInput.text.trim().length > 0
                        name: "caret-right"
                        size: 11
                        color: theme.outline
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Chip 2: Query Chip
                    Item {
                        visible: searchInput.text.trim().length > 0
                        height: 32
                        width: seQueryTxt.implicitWidth + 22

                        Rectangle {
                            anchors.fill: parent
                            radius: theme.radiusFull
                            color: theme.secondaryContainer
                        }

                        Text {
                            id: seQueryTxt
                            anchors.centerIn: parent
                            text: "\"" + searchInput.text.trim() + "\""
                            color: theme.secondaryContainerFg
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            // Expanding Search Bar (Smoothly expands to the left when focused)
            Rectangle {
                id: searchBarRect
                visible: window.activeView !== "pc"
                Layout.preferredHeight: 42
                radius: theme.radiusFull
                color: searchInput.activeFocus ? theme.surfaceContainerHighest : theme.surfaceContainer
                border.width: searchInput.activeFocus ? 1.5 : 0
                border.color: theme.primary

                Behavior on border.width { NumberAnimation { duration: theme.durationFast } }

                property real barWidth: engine.is_searching_everywhere
                    ? (window.width < 900 ? 240 : 320)
                    : (searchInput.activeFocus ? (window.width < 900 ? 260 : 460) : 260)
                Layout.preferredWidth: barWidth
                Layout.minimumWidth: 120

                Behavior on barWidth {
                    SpringAnimation { spring: 3.8; damping: 0.32 }
                }

                Behavior on color { ColorAnimation { duration: theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    spacing: 10

                    Item {
                        width: 16
                        height: 16
                        LoafIcon {
                            visible: theme.iconSource === "phosphor"
                            anchors.centerIn: parent
                            name: "magnifying-glass"
                            size: 16
                            color: searchInput.activeFocus ? theme.primary : theme.outline
                        }
                        Image {
                            visible: theme.iconSource === "system"
                            anchors.centerIn: parent
                            source: engine.resolve_icon("system-search")
                            width: 16
                            height: 16
                            sourceSize.width: 32
                            sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: theme.textMain
                        font.pixelSize: 13
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter

                        Text {
                            text: window.activeView === "settings"
                                ? "Search settings..."
                                : (engine.is_searching_everywhere ? "Search across entire filesystem..." : "Search files...")
                            color: theme.outline
                            font.pixelSize: 13
                            visible: !searchInput.text && !searchInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: {
                            if (window.activeView === "pc") {
                                // Typing search from PC pulls back to the file grid
                                window.showFiles();
                            }
                            if (window.activeView === "files") {
                                if (engine.is_searching_everywhere) {
                                    engine.search_everywhere(searchInput.text);
                                }
                                if (searchInput.text.trim().length > 0) {
                                    filesGridView.selectItem(0, false, false);
                                }
                            }
                        }

                        Keys.onEscapePressed: function(event) {
                            if (searchInput.text.length > 0) {
                                searchInput.text = "";
                                event.accepted = true;
                            } else if (window.isAuxView) {
                                window.showFiles();
                                event.accepted = true;
                            }
                        }

                        Keys.onDownPressed: function(event) {
                            if (window.activeView === "files") {
                                gridContainer.moveSelection(0, 1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                        }

                        Keys.onUpPressed: function(event) {
                            if (window.activeView === "files") {
                                gridContainer.moveSelection(0, -1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                        }

                        Keys.onLeftPressed: function(event) {
                            if (window.activeView === "files" && engine.view_mode === "grid") {
                                gridContainer.moveSelection(-1, 0, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                        }

                        Keys.onRightPressed: function(event) {
                            if (window.activeView === "files" && engine.view_mode === "grid") {
                                gridContainer.moveSelection(1, 0, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                        }

                        Keys.onReturnPressed: function(event) {
                            if (window.activeView === "files") {
                                gridContainer.openSelected();
                                event.accepted = true;
                            }
                        }

                        Keys.onEnterPressed: function(event) {
                            if (window.activeView === "files") {
                                gridContainer.openSelected();
                                event.accepted = true;
                            }
                        }
                    }

                    // "Search everywhere" Pop-up Pill Button (Visible when focused)
                    Rectangle {
                        id: everywhereBtn
                        visible: (window.activeView === "files") && (searchInput.activeFocus || engine.is_searching_everywhere) && !engine.is_searching_everywhere
                        height: 30
                        width: everywhereRow.implicitWidth + 18
                        radius: theme.radiusFull
                        color: everywhereMouse.containsMouse ? theme.primary : theme.surfaceContainerLow

                        Behavior on color { ColorAnimation { duration: theme.durationFast } }

                        RowLayout {
                            id: everywhereRow
                            anchors.centerIn: parent
                            spacing: 6

                            LoafIcon {
                                name: "globe"
                                size: 13
                                color: everywhereMouse.containsMouse ? theme.primaryFg : theme.textMain
                            }

                            Text {
                                text: "Search everywhere"
                                color: everywhereMouse.containsMouse ? theme.primaryFg : theme.textMain
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: everywhereMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engine.search_everywhere(searchInput.text || "a");
                            }
                        }
                    }

                    // Exit Search Everywhere Button (When search everywhere is active)
                    Rectangle {
                        visible: engine.is_searching_everywhere
                        height: 30
                        width: closeSearchTxt.implicitWidth + 18
                        radius: theme.radiusFull
                        color: closeSearchMouse.containsMouse ? theme.surfaceContainerHighest : theme.surfaceContainerLow

                        Text {
                            id: closeSearchTxt
                            anchors.centerIn: parent
                            text: "Back to Files"
                            color: theme.textMain
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: closeSearchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engine.clear_search_everywhere();
                                searchInput.text = "";
                            }
                        }
                    }
                }
            }

            // Unified View & Sort Options Button
            Rectangle {
                id: viewDropdownBtn
                visible: window.activeView === "files" && !engine.is_searching_everywhere
                Layout.preferredHeight: 42
                Layout.preferredWidth: viewDropdownRow.implicitWidth + (window.width < 900 ? 16 : 24)
                radius: theme.radiusFull
                color: viewDropdownMouse.containsMouse ? theme.surfaceContainerHighest : theme.surfaceContainer
                Behavior on color { ColorAnimation { duration: theme.durationFast } }
                scale: viewDropdownMouse.pressed ? 0.95 : 1.0
                Behavior on scale { SpringAnimation { spring: 4.0; damping: 0.3 } }

                RowLayout {
                    id: viewDropdownRow
                    anchors.centerIn: parent
                    spacing: 7

                    LoafIcon {
                        name: engine.view_mode === "list" ? "list" : "squares-four"
                        size: 16
                        color: theme.primary
                    }

                    Text {
                        visible: window.width >= 900
                        text: "View"
                        color: theme.textMain
                        font.pixelSize: 12
                        font.bold: true
                    }

                    LoafIcon {
                        name: "caret-down"
                        size: 11
                        color: theme.outline
                    }
                }

                MouseArea {
                    id: viewDropdownMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pt = mapToItem(window.contentItem, 0, height + 6);
                        viewMenuPopup.openAt(pt.x, pt.y);
                    }
                }
            }

            // Empty Trash: shown only while browsing the trash root.
            LoafButton {
                id: emptyTrashBtn
                visible: window.activeView === "files"
                    && engine.trash_root.length > 0
                    && engine.current_path === engine.trash_root
                text: window.width < 900 ? "" : "Empty Trash"
                icon: "trash"
                variant: "danger"
                onClicked: engine.empty_trash()
            }
        }

        // ==========================================
        // MAIN BODY (Expandable Rail + Stage)
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: 20
            spacing: 16

            // Expandable Navigation Rail
            Rectangle {
                id: navRailRect
                Layout.fillHeight: true
                property real railWidth: window.sidebarExpanded ? 190 : 68
                Layout.preferredWidth: railWidth
                radius: theme.radiusXl
                color: theme.surfaceContainer
                clip: true

                Behavior on railWidth {
                    NumberAnimation {
                        duration: 230
                        easing.type: Easing.OutCubic
                    }
                }

                // Sliding Active Pill Indicator (glides between Places and Settings)
                Rectangle {
                    id: navIndicator
                    height: 44
                    radius: 22
                    x: 12
                    width: window.sidebarExpanded ? (navRailRect.width - 24) : 44
                    color: theme.primaryContainer
                    opacity: engine.is_searching_everywhere ? 0.35 : 1.0
                    Behavior on opacity { NumberAnimation { duration: theme.durationFast } }
                    z: 0

                    y: {
                        if (window.activeView === "settings") {
                            return navRailCol.y + settingsBtnItem.y;
                        } else {
                            return navRailCol.y + navRailArea.y + window.currentNavIndex * 52;
                        }
                    }

                    Behavior on y {
                        SpringAnimation {
                            spring: 3.5
                            damping: 0.35
                            epsilon: 0.25
                        }
                    }
                    Behavior on width {
                        SpringAnimation {
                            spring: 3.5
                            damping: 0.35
                        }
                    }
                    Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                    ParallelAnimation {
                        id: indicatorExpandAnim
                        SequentialAnimation {
                            PauseAnimation { duration: 60 + window.currentNavIndex * 40 }
                            NumberAnimation {
                                target: navIndicator
                                property: "width"
                                from: 44
                                to: navRailRect.width - 24
                                duration: 210
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.25
                            }
                        }
                    }

                    ParallelAnimation {
                        id: indicatorCollapseAnim
                        SequentialAnimation {
                            PauseAnimation { duration: Math.max(0, (navRepeater.count - 1 - window.currentNavIndex)) * 22 }
                            NumberAnimation {
                                target: navIndicator
                                property: "width"
                                from: navIndicator.width
                                to: 44
                                duration: 130
                                easing.type: Easing.InCubic
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: navRailCol
                    anchors.fill: parent
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    spacing: 8
                    z: 1

                    // Sidebar Expand Toggle Button
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44

                        Rectangle {
                            width: 44
                            height: 44
                            radius: 22
                            x: 12
                            color: toggleMouse.containsMouse ? theme.surfaceContainerHigh : "transparent"

                            Behavior on color { ColorAnimation { duration: theme.durationFast } }

                            LoafIcon {
                                anchors.centerIn: parent
                                name: window.sidebarExpanded ? "sidebar" : "sidebar-simple"
                                size: 20
                                color: theme.textMain
                            }

                            MouseArea {
                                id: toggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    window.sidebarExpanded = !window.sidebarExpanded;
                                    if (window.sidebarExpanded) {
                                        indicatorCollapseAnim.stop();
                                        indicatorExpandAnim.restart();
                                        for (var i = 0; i < navRepeater.count; i++) {
                                            var it = navRepeater.itemAt(i);
                                            if (it && typeof it.playExpand === "function") {
                                                it.playExpand(i);
                                            }
                                        }
                                        if (settingsBtnItem && typeof settingsBtnItem.playExpand === "function") {
                                            settingsBtnItem.playExpand(navRepeater.count);
                                        }
                                    } else {
                                        indicatorExpandAnim.stop();
                                        indicatorCollapseAnim.restart();
                                        if (settingsBtnItem && typeof settingsBtnItem.playCollapse === "function") {
                                            settingsBtnItem.playCollapse(0);
                                        }
                                        for (var j = 0; j < navRepeater.count; j++) {
                                            var btn = navRepeater.itemAt(j);
                                            if (btn && typeof btn.playCollapse === "function") {
                                                var revIdx = (navRepeater.count - j);
                                                btn.playCollapse(revIdx);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Places Navigation List
                    Item {
                        id: navRailArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Column {
                            id: navColumn
                            anchors.fill: parent
                            spacing: 8

                            Repeater {
                                id: navRepeater
                                model: [
                                    { name: engine.hostname || "PC", iconName: engine.device_type === "laptop" ? "laptop" : "desktop", systemIcon: "computer-symbolic", view: "pc" },
                                    { name: "Home", iconName: "house", systemIcon: "user-home-symbolic", pathSuffix: "", view: "files" },
                                    { name: "Documents", iconName: "file-text", systemIcon: "x-office-document-symbolic", pathSuffix: "Documents", view: "files" },
                                    { name: "Downloads", iconName: "download", systemIcon: "folder-download-symbolic", pathSuffix: "Downloads", view: "files" },
                                    { name: "Pictures", iconName: "image", systemIcon: "image-x-generic-symbolic", pathSuffix: "Pictures", view: "files" },
                                    { name: "Music", iconName: "music", systemIcon: "audio-x-generic-symbolic", pathSuffix: "Music", view: "files" },
                                    { name: "Videos", iconName: "video", systemIcon: "video-x-generic-symbolic", pathSuffix: "Videos", view: "files" },
                                    { name: "Projects", iconName: "code", systemIcon: "utilities-terminal-symbolic", pathSuffix: "Projects", view: "files" },
                                    { name: "Trash", iconName: "trash", systemIcon: "user-trash-symbolic", view: "files", trashRoot: true }
                                ]

                                delegate: Item {
                                    id: navBtn
                                    width: navRailArea.width
                                    height: 44

                                    readonly property bool isSelected: window.activeView === modelData.view && window.currentNavIndex === index
                                    readonly property bool isHovered: btnMouse.containsMouse

                                    Rectangle {
                                        width: window.sidebarExpanded ? (parent.width - 24) : 44
                                        height: 44
                                        radius: 22
                                        x: 12
                                        color: theme.hoverOverlay
                                        opacity: (!navBtn.isSelected && navBtn.isHovered) ? 1.0 : 0.0

                                        Behavior on opacity { NumberAnimation { duration: theme.durationFast } }
                                        Behavior on width { SpringAnimation { spring: 3.5; damping: 0.35 } }
                                    }

                                    Item {
                                        id: iconBox
                                        width: 44
                                        height: 44
                                        x: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        transformOrigin: Item.Center

                                        NumberAnimation {
                                            id: iconBounceAnim
                                            target: iconBox
                                            property: "scale"
                                            from: 1.0
                                            to: 1.25
                                            duration: 120
                                            easing.type: Easing.OutBack
                                            onFinished: iconSettleAnim.start()
                                        }
                                        NumberAnimation {
                                            id: iconSettleAnim
                                            target: iconBox
                                            property: "scale"
                                            from: 1.25
                                            to: 1.0
                                            duration: 120
                                            easing.type: Easing.OutCubic
                                        }

                                        LoafIcon {
                                            visible: theme.iconSource === "phosphor"
                                            anchors.centerIn: parent
                                            name: modelData.iconName
                                            size: 20
                                            color: navBtn.isSelected ? theme.primaryContainerFg : (navBtn.isHovered ? theme.textMain : theme.textMuted)

                                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                        }

                                        Image {
                                            visible: theme.iconSource === "system"
                                            anchors.centerIn: parent
                                            source: engine.resolve_icon(modelData.systemIcon)
                                            width: 20
                                            height: 20
                                            sourceSize.width: 40
                                            sourceSize.height: 40
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    Item {
                                        id: labelContainer
                                        anchors.left: iconBox.right
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24

                                        clip: true
                                        opacity: window.sidebarExpanded ? 1.0 : 0.0
                                        scale: window.sidebarExpanded ? 1.0 : 0.3
                                        transformOrigin: Item.Left

                                        transform: Translate {
                                            id: labelTranslate
                                            x: window.sidebarExpanded ? 0 : -16
                                        }

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.name
                                            color: navBtn.isSelected ? theme.primaryContainerFg : (navBtn.isHovered ? theme.textMain : theme.textMuted)
                                            font.pixelSize: 13
                                            font.bold: navBtn.isSelected
                                            elide: Text.ElideRight

                                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                        }
                                    }

                                    ParallelAnimation {
                                        id: labelExpandAnim
                                        property int delayMs: 0

                                        SequentialAnimation {
                                            PauseAnimation { duration: labelExpandAnim.delayMs }
                                            ParallelAnimation {
                                                ScriptAction { script: iconBounceAnim.restart() }
                                                NumberAnimation {
                                                    target: labelContainer
                                                    property: "opacity"
                                                    from: 0.0
                                                    to: 1.0
                                                    duration: 180
                                                    easing.type: Easing.OutCubic
                                                }
                                                NumberAnimation {
                                                    target: labelContainer
                                                    property: "scale"
                                                    from: 0.3
                                                    to: 1.0
                                                    duration: 230
                                                    easing.type: Easing.OutBack
                                                    easing.overshoot: 1.5
                                                }
                                                NumberAnimation {
                                                    target: labelTranslate
                                                    property: "x"
                                                    from: -16
                                                    to: 0
                                                    duration: 210
                                                    easing.type: Easing.OutBack
                                                    easing.overshoot: 1.2
                                                }
                                            }
                                        }
                                    }

                                    ParallelAnimation {
                                        id: labelCollapseAnim
                                        property int delayMs: 0

                                        SequentialAnimation {
                                            PauseAnimation { duration: labelCollapseAnim.delayMs }
                                            ParallelAnimation {
                                                NumberAnimation {
                                                    target: labelContainer
                                                    property: "opacity"
                                                    from: labelContainer.opacity
                                                    to: 0.0
                                                    duration: 110
                                                    easing.type: Easing.InCubic
                                                }
                                                NumberAnimation {
                                                    target: labelContainer
                                                    property: "scale"
                                                    from: labelContainer.scale
                                                    to: 0.3
                                                    duration: 130
                                                    easing.type: Easing.InBack
                                                    easing.overshoot: 1.2
                                                }
                                                NumberAnimation {
                                                    target: labelTranslate
                                                    property: "x"
                                                    from: labelTranslate.x
                                                    to: -16
                                                    duration: 130
                                                    easing.type: Easing.InCubic
                                                }
                                            }
                                        }
                                    }

                                    function playExpand(idx) {
                                        labelCollapseAnim.stop();
                                        labelExpandAnim.stop();
                                        labelContainer.opacity = 0.0;
                                        labelContainer.scale = 0.3;
                                        labelTranslate.x = -16;
                                        labelExpandAnim.delayMs = 60 + idx * 35;
                                        labelExpandAnim.start();
                                    }

                                    function playCollapse(reverseIdx) {
                                        labelExpandAnim.stop();
                                        labelCollapseAnim.stop();
                                        labelCollapseAnim.delayMs = reverseIdx * 20;
                                        labelCollapseAnim.start();
                                    }

                                    MouseArea {
                                        id: btnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            engine.clear_search_everywhere();
                                            window.currentNavIndex = index;
                                            if (modelData.view === "pc") {
                                                window.activeView = "pc";
                                                engine.load_drives();
                                                engine.refresh_frequent_dirs();
                                            } else if (modelData.trashRoot) {
                                                window.currentPlaceIndex = index;
                                                window.activeView = "files";
                                                engine.set_path(engine.trash_root);
                                            } else {
                                                window.currentPlaceIndex = index;
                                                window.activeView = "files";
                                                var homeBase = "/home/" + (engine.current_path.split("/")[2] || "m_uvex");
                                                if (modelData.pathSuffix === "") {
                                                    engine.set_path(homeBase);
                                                } else {
                                                    engine.set_path(homeBase + "/" + modelData.pathSuffix);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Settings Button
                    Item {
                        id: settingsBtnItem
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44

                        readonly property bool isSettingsActive: window.activeView === "settings"

                        Rectangle {
                            width: window.sidebarExpanded ? (parent.width - 24) : 44
                            height: 44
                            radius: 22
                            x: 12
                            color: theme.hoverOverlay
                            opacity: settingsMouse.containsMouse ? 1.0 : 0.0

                            Behavior on opacity { NumberAnimation { duration: theme.durationFast } }
                            Behavior on width { SpringAnimation { spring: 3.5; damping: 0.35 } }
                        }

                        Item {
                            id: settingsIconBox
                            width: 44
                            height: 44
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            transformOrigin: Item.Center

                            NumberAnimation {
                                id: settingsBounceAnim
                                target: settingsIconBox
                                property: "scale"
                                from: 1.0
                                to: 1.25
                                duration: 120
                                easing.type: Easing.OutBack
                                onFinished: settingsSettleAnim.start()
                            }
                            NumberAnimation {
                                id: settingsSettleAnim
                                target: settingsIconBox
                                property: "scale"
                                from: 1.25
                                to: 1.0
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                            LoafIcon {
                                visible: theme.iconSource === "phosphor"
                                anchors.centerIn: parent
                                name: "gear"
                                size: 20
                                color: settingsBtnItem.isSettingsActive ? theme.primaryContainerFg : (settingsMouse.containsMouse ? theme.textMain : theme.textMuted)

                                Behavior on color { ColorAnimation { duration: theme.durationFast } }
                            }

                            Image {
                                visible: theme.iconSource === "system"
                                anchors.centerIn: parent
                                source: engine.resolve_icon("preferences-system-symbolic")
                                width: 20
                                height: 20
                                sourceSize.width: 40
                                sourceSize.height: 40
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Item {
                            id: settingsLabelContainer
                            anchors.left: settingsIconBox.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24

                            clip: true
                            opacity: window.sidebarExpanded ? 1.0 : 0.0
                            scale: window.sidebarExpanded ? 1.0 : 0.3
                            transformOrigin: Item.Left

                            transform: Translate {
                                id: settingsLabelTranslate
                                x: window.sidebarExpanded ? 0 : -16
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Settings"
                                color: settingsBtnItem.isSettingsActive ? theme.primaryContainerFg : (settingsMouse.containsMouse ? theme.textMain : theme.textMuted)
                                font.pixelSize: 13
                                font.bold: settingsBtnItem.isSettingsActive
                                elide: Text.ElideRight

                                Behavior on color { ColorAnimation { duration: theme.durationFast } }
                            }
                        }

                        ParallelAnimation {
                            id: settingsExpandAnim
                            property int delayMs: 0

                            SequentialAnimation {
                                PauseAnimation { duration: settingsExpandAnim.delayMs }
                                ParallelAnimation {
                                    ScriptAction { script: settingsBounceAnim.restart() }
                                    NumberAnimation {
                                        target: settingsLabelContainer
                                        property: "opacity"
                                        from: 0.0
                                        to: 1.0
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: settingsLabelContainer
                                        property: "scale"
                                        from: 0.3
                                        to: 1.0
                                        duration: 230
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.5
                                    }
                                    NumberAnimation {
                                        target: settingsLabelTranslate
                                        property: "x"
                                        from: -16
                                        to: 0
                                        duration: 210
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.2
                                    }
                                }
                            }
                        }

                        ParallelAnimation {
                            id: settingsCollapseAnim
                            property int delayMs: 0

                            SequentialAnimation {
                                PauseAnimation { duration: settingsCollapseAnim.delayMs }
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: settingsLabelContainer
                                        property: "opacity"
                                        from: settingsLabelContainer.opacity
                                        to: 0.0
                                        duration: 110
                                        easing.type: Easing.InCubic
                                    }
                                    NumberAnimation {
                                        target: settingsLabelContainer
                                        property: "scale"
                                        from: settingsLabelContainer.scale
                                        to: 0.3
                                        duration: 130
                                        easing.type: Easing.InBack
                                        easing.overshoot: 1.2
                                    }
                                    NumberAnimation {
                                        target: settingsLabelTranslate
                                        property: "x"
                                        from: settingsLabelTranslate.x
                                        to: -16
                                        duration: 130
                                        easing.type: Easing.InCubic
                                    }
                                }
                            }
                        }

                        function playExpand(idx) {
                            settingsCollapseAnim.stop();
                            settingsExpandAnim.stop();
                            settingsLabelContainer.opacity = 0.0;
                            settingsLabelContainer.scale = 0.3;
                            settingsLabelTranslate.x = -16;
                            settingsExpandAnim.delayMs = 60 + idx * 35;
                            settingsExpandAnim.start();
                        }

                        function playCollapse(reverseIdx) {
                            settingsExpandAnim.stop();
                            settingsCollapseAnim.stop();
                            settingsCollapseAnim.delayMs = reverseIdx * 20;
                            settingsCollapseAnim.start();
                        }

                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                engine.clear_search_everywhere();
                                if (window.activeView === "settings") {
                                    window.showFiles();
                                } else {
                                    window.activeView = "settings";
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // MAIN CONTENT STAGE
            // ==========================================
            Rectangle {
                id: mainStage
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.radiusXl
                color: theme.surfaceContainerLow
                clip: true
                // Visible focus ring while the grid/list is driven by the keyboard.
                border.width: window.keyboardNavActive ? 2 : 0
                border.color: theme.primary
                Behavior on border.width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                // Shared content wrapper for dir/settings transition animation
                Item {
                    id: mainStageContent
                    anchors.fill: parent

                    transform: [
                        Translate {
                            id: stageTranslate
                            y: 0
                        },
                        Scale {
                            id: stageScale
                            origin.x: mainStageContent.width / 2
                            origin.y: 0
                            xScale: 1.0
                            yScale: 1.0
                        }
                    ]

                // VIEW 1: FILES BROWSER
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 14
                    visible: window.activeView === "files"

                    // Directory Hero Header & Item/Selection Count
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            id: dirHeroTitle
                            text: engine.is_searching_everywhere ? "Searching Everywhere" : engine.current_dir_name
                            color: theme.textMain
                            font.pixelSize: 26
                            font.bold: true
                            font.letterSpacing: -0.5
                            elide: Text.ElideRight
                            Layout.maximumWidth: Math.max(120, mainStage.width - 220)

                            transform: Translate { id: dirHeroTrans; x: 0 }

                            onTextChanged: dirHeroAnim.restart()

                            SequentialAnimation {
                                id: dirHeroAnim
                                ParallelAnimation {
                                    NumberAnimation { target: dirHeroTitle; property: "opacity"; from: 0.2; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: dirHeroTrans; property: "x"; from: -8; to: 0; duration: 180; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Selection Count Badge
                        Rectangle {
                            visible: filesGridView.selectedCount > 0
                            height: 28
                            width: selLabel.implicitWidth + 20
                            radius: theme.radiusFull
                            color: theme.primaryContainer

                            Text {
                                id: selLabel
                                anchors.centerIn: parent
                                text: filesGridView.selectedCount + " selected"
                                color: theme.primaryContainerFg
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        // Total Items Badge
                        Rectangle {
                            height: 28
                            width: countLabel.implicitWidth + 18
                            radius: theme.radiusFull
                            color: theme.surfaceContainerHigh

                            Text {
                                id: countLabel
                                anchors.centerIn: parent
                                text: {
                                    var count = gridContainer.allTargetItems ? gridContainer.allTargetItems.length : 0;
                                    if (engine.is_searching_everywhere) {
                                        return count + " results";
                                    }
                                    return count + " items";
                                }
                                color: theme.textMuted
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    // File Grid Stage
                    Item {
                        id: gridContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        property var selectedIndices: ({})
                        property int selectedCount: Object.keys(selectedIndices).length
                        property int lastSelectedIndex: -1
                        property int anchorIndex: -1

                        property var allTargetItems: []
                        property var displayedItems: []
                        property int loadedCount: 0

                        function reloadItems() {
                            loadTimer.stop();
                            var full;
                            if (engine.is_searching_everywhere) {
                                full = JSON.parse(engine.search_everywhere_json || "[]");
                            } else {
                                var raw = JSON.parse(engine.files_json || "[]");
                                var q = searchInput.text.toLowerCase().trim();
                                if (q.length === 0) {
                                    full = raw;
                                } else {
                                    full = raw.filter(function(item) {
                                        return item.name.toLowerCase().indexOf(q) !== -1;
                                    });
                                }
                            }
                            allTargetItems = full;
                            if (full.length <= 40) {
                                displayedItems = full;
                                loadedCount = full.length;
                            } else {
                                displayedItems = full.slice(0, 40);
                                loadedCount = 40;
                                loadTimer.start();
                            }
                        }

                        Timer {
                            id: loadTimer
                            interval: 16
                            repeat: true
                            onTriggered: {
                                if (gridContainer.loadedCount >= gridContainer.allTargetItems.length) {
                                    stop();
                                    return;
                                }
                                var nextSize = Math.min(30, gridContainer.allTargetItems.length - gridContainer.loadedCount);
                                gridContainer.displayedItems = gridContainer.displayedItems.concat(
                                    gridContainer.allTargetItems.slice(gridContainer.loadedCount, gridContainer.loadedCount + nextSize)
                                );
                                gridContainer.loadedCount += nextSize;
                            }
                        }

                        Connections {
                            target: engine
                            function onFiles_jsonChanged() { gridContainer.reloadItems(); }
                            function onSearch_everywhere_jsonChanged() { gridContainer.reloadItems(); }
                            function onIs_searching_everywhereChanged() { gridContainer.reloadItems(); }
                        }

                        Connections {
                            target: searchInput
                            function onTextChanged() { gridContainer.reloadItems(); }
                        }

                        Component.onCompleted: gridContainer.reloadItems()

                        function getFilteredItems() {
                            return allTargetItems;
                        }

                        function getSelectedItems() {
                            var raw = allTargetItems;
                            var res = [];
                            for (var k in selectedIndices) {
                                var idx = parseInt(k);
                                if (raw[idx]) res.push(raw[idx]);
                            }
                            return res;
                        }

                        function selectItem(idx, isCtrl, isShift) {
                            var copy = {};
                            if (isShift) {
                                var anchor = anchorIndex !== -1 ? anchorIndex : (lastSelectedIndex !== -1 ? lastSelectedIndex : 0);
                                var start = Math.min(anchor, idx);
                                var end = Math.max(anchor, idx);
                                for (var i = start; i <= end; ++i) {
                                    copy[i] = true;
                                }
                                lastSelectedIndex = idx;
                            } else if (isCtrl) {
                                copy = Object.assign({}, selectedIndices);
                                if (copy[idx]) {
                                    delete copy[idx];
                                } else {
                                    copy[idx] = true;
                                }
                                lastSelectedIndex = idx;
                                anchorIndex = idx;
                            } else {
                                copy[idx] = true;
                                lastSelectedIndex = idx;
                                anchorIndex = idx;
                            }
                            selectedIndices = copy;
                        }

                        function selectAll() {
                            var raw = engine.is_searching_everywhere
                                ? JSON.parse(engine.search_everywhere_json || "[]")
                                : getFilteredItems();
                            var copy = {};
                            for (var i = 0; i < raw.length; ++i) {
                                copy[i] = true;
                            }
                            selectedIndices = copy;
                        }

                        function clearSelection() {
                            selectedIndices = {};
                            lastSelectedIndex = -1;
                            anchorIndex = -1;
                        }

                        function moveSelection(dx, dy, isShift) {
                            var raw = engine.is_searching_everywhere
                                ? JSON.parse(engine.search_everywhere_json || "[]")
                                : getFilteredItems();
                            if (raw.length === 0) return;

                            var isList = engine.view_mode === "list";
                            var effectiveCols = isList ? 1 : (filesGridView.cols || 1);

                            var cur = lastSelectedIndex !== -1 ? lastSelectedIndex : 0;
                            var target;
                            if (isList) {
                                var delta = (dy !== 0) ? dy : dx;
                                target = cur + delta;
                            } else {
                                target = cur + dx + dy * effectiveCols;
                            }

                            if (target < 0) target = 0;
                            if (target >= raw.length) target = raw.length - 1;

                            selectItem(target, false, isShift);
                            if (isList) {
                                filesListView.positionViewAtIndex(target, ListView.Visible);
                            } else {
                                filesGridView.positionViewAtIndex(target, GridView.Visible);
                            }
                        }

                        function openSelected() {
                            var items = getSelectedItems();
                            if (items.length > 0) {
                                var it = items[0];
                                var targetPath = engine.is_searching_everywhere
                                    ? it.path
                                    : (engine.current_path + "/" + it.name);

                                if (it.is_dir) {
                                    clearSelection();
                                    engine.set_path(targetPath);
                                    if (engine.is_searching_everywhere) {
                                        engine.clear_search_everywhere();
                                        searchInput.text = "";
                                    }
                                } else {
                                    engine.open_item(targetPath);
                                }
                            }
                        }

                        // Drop target: current directory (for external drops onto empty space)
                        DropArea {
                            id: gridDropArea
                            anchors.fill: parent
                            keys: ["text/uri-list"]

                            // Only handle drops that didn't land on a folder card.
                            // Folder cards have their own DropArea which takes priority.
                            property bool gridIsTarget: containsDrag && dragManager.hoverTarget.length === 0

                            onDropped: function(drop) {
                                if (!drop.hasUrls) return;
                                // If hovering a folder, that folder's DropArea owns the drop.
                                if (dragManager.hoverTarget.length > 0) return;

                                var destPath = engine.current_path;
                                var paths = [];
                                for (var i = 0; i < drop.urls.length; ++i) {
                                    var u = drop.urls[i].toString();
                                    if (u.startsWith("file://")) u = u.slice(7);
                                    if (u === destPath) continue;
                                    paths.push(u);
                                }
                                if (paths.length === 0) return;

                                var asCopy;
                                if (drop.source === dragProxy) {
                                    asCopy = dragManager.asCopy;
                                } else {
                                    asCopy = (drop.proposedAction === Qt.CopyAction) || !(drop.supportedActions & Qt.MoveAction);
                                }

                                drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                                window.handleDrop(paths, destPath, asCopy);
                            }
                        }

                        // Right-click on empty background or left-click deselect
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            z: 0

                            onPressed: {
                                if (searchInput.activeFocus)
                                    searchInput.focus = false;
                            }

                            onClicked: function(mouse) {
                                if (selectionManager.justFinishedDrag) return;
                                if (mouse.button === Qt.RightButton && !engine.is_searching_everywhere) {
                                    contextMenu.showEmptyMenu(mouse.x + gridContainer.x, mouse.y + gridContainer.y);
                                } else {
                                    filesGridView.clearSelection();
                                    contextMenu.close();
                                }
                            }
                        }

                        GridView {
                            id: filesGridView
                            anchors.fill: parent
                            cellWidth: 124
                            cellHeight: 114
                            clip: true
                            z: engine.view_mode === "grid" ? 2 : 1
                            // Cross-fade grid <-> list instead of an instant swap.
                            opacity: engine.view_mode === "grid" ? 1.0 : 0.0
                            visible: opacity > 0.001
                            enabled: engine.view_mode === "grid"
                            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                            interactive: true
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                id: gridScrollBar
                                policy: ScrollBar.AsNeeded
                                width: 12
                                padding: 2
                                contentItem: Rectangle {
                                    implicitWidth: 6
                                    radius: 3
                                    color: gridScrollBar.pressed ? theme.primary : (gridScrollBar.hovered ? theme.outline : theme.outlineVariant)
                                    opacity: gridScrollBar.active ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }

                            readonly property int rows: Math.ceil(count / cols)
                            contentWidth: Math.max(width, cols * cellWidth)
                            contentHeight: Math.max(height, rows * cellHeight)

                            property alias selectedIndices: gridContainer.selectedIndices
                            property alias selectedCount: gridContainer.selectedCount
                            property alias lastSelectedIndex: gridContainer.lastSelectedIndex

                            function selectItem(idx, isCtrl, isShift) { gridContainer.selectItem(idx, isCtrl, isShift); }
                            function selectAll() { gridContainer.selectAll(); }
                            function clearSelection() { gridContainer.clearSelection(); }
                            function getFilteredItems() { return gridContainer.getFilteredItems(); }
                            function getSelectedItems() { return gridContainer.getSelectedItems(); }
                            function openSelected() { gridContainer.openSelected(); }

                            readonly property int cols: Math.max(1, Math.floor(width / cellWidth))

                            // Per-card staggered enter is implemented on the delegate
                            // itself (capped) instead of populate/add transitions, so
                            // large folders and search results never hitch.

                            // Wheel handler ensures smooth wheel scrolling in both select and scroll modes
                            WheelHandler {
                                id: gridWheelHandler
                                target: null
                                onWheel: function(event) {
                                    var delta = event.angleDelta.y;
                                    var step = 80;
                                    var newY = filesGridView.contentY - (delta > 0 ? step : -step);
                                    var maxY = Math.max(0, filesGridView.contentHeight - filesGridView.height);
                                    filesGridView.contentY = Math.max(0, Math.min(maxY, newY));
                                }
                            }

                            // ==========================================
                            // RUBBERBAND SELECTION BOX & CONTROLLER
                            // ==========================================
                            Rectangle {
                                id: selectionBox
                                parent: filesGridView.contentItem
                                z: 100
                                visible: false
                                color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, theme.isDark ? 0.22 : 0.16)
                                border.color: theme.primary
                                border.width: 1.5
                                radius: theme.radiusM

                                Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                Behavior on border.color { ColorAnimation { duration: theme.durationFast } }
                            }

                            ParallelAnimation {
                                id: contractAnim
                                NumberAnimation { target: selectionBox; property: "x"; to: selectionManager.startX; duration: 160; easing.type: Easing.OutCubic }
                                NumberAnimation { target: selectionBox; property: "y"; to: selectionManager.startY; duration: 160; easing.type: Easing.OutCubic }
                                NumberAnimation { target: selectionBox; property: "width"; to: 0; duration: 160; easing.type: Easing.OutCubic }
                                NumberAnimation { target: selectionBox; property: "height"; to: 0; duration: 160; easing.type: Easing.OutCubic }
                                NumberAnimation { target: selectionBox; property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.OutQuad }

                                onFinished: {
                                    selectionBox.visible = false;
                                    selectionBox.opacity = 1.0;
                                }
                            }

                            Item {
                                id: selectionManager

                                property real startX: 0
                                property real startY: 0
                                property real curX: 0
                                property real curY: 0
                                property bool active: false
                                property bool justFinishedDrag: false
                                property var baseSelection: ({})
                                property bool isCtrl: false

                                function start(x, y, ctrl) {
                                    contractAnim.stop();
                                    selectionBox.opacity = 1.0;
                                    selectionBox.visible = false;
                                    resetJustFinishedDragTimer.stop();
                                    justFinishedDrag = false;

                                    startX = x;
                                    startY = y;
                                    curX = x;
                                    curY = y;
                                    isCtrl = ctrl;
                                    baseSelection = ctrl ? Object.assign({}, filesGridView.selectedIndices) : {};
                                    active = false;
                                }

                                function update(x, y) {
                                    if (theme.dragAction !== "select") return;

                                    curX = x;
                                    curY = y;
                                    var dx = curX - startX;
                                    var dy = curY - startY;

                                    if (!active && (dx * dx + dy * dy >= 25)) {
                                        active = true;
                                        contractAnim.stop();
                                        selectionBox.opacity = 1.0;
                                        selectionBox.visible = true;
                                    }

                                    if (active) {
                                        var boxX = Math.min(startX, curX);
                                        var boxY = Math.min(startY, curY);
                                        var boxW = Math.abs(curX - startX);
                                        var boxH = Math.abs(curY - startY);

                                        selectionBox.x = boxX;
                                        selectionBox.y = boxY;
                                        selectionBox.width = boxW;
                                        selectionBox.height = boxH;

                                        var totalCount = filesGridView.count;
                                        var cols = filesGridView.cols;
                                        var cellW = filesGridView.cellWidth;
                                        var cellH = filesGridView.cellHeight;

                                        var newSelection = Object.assign({}, baseSelection);

                                        for (var i = 0; i < totalCount; ++i) {
                                            var col = i % cols;
                                            var row = Math.floor(i / cols);
                                            var itemL = col * cellW + 4;
                                            var itemT = row * cellH + 4;
                                            var itemR = itemL + cellW - 8;
                                            var itemB = itemT + cellH - 8;

                                            var intersects = (boxX < itemR && (boxX + boxW) > itemL &&
                                                              boxY < itemB && (boxY + boxH) > itemT);

                                            if (intersects) {
                                                newSelection[i] = true;
                                            } else if (!isCtrl) {
                                                delete newSelection[i];
                                            }
                                        }

                                        filesGridView.selectedIndices = newSelection;
                                    }
                                }

                                function end() {
                                    if (active) {
                                        active = false;
                                        justFinishedDrag = true;
                                        contractAnim.start();
                                        resetJustFinishedDragTimer.restart();
                                    }
                                }
                            }

                            Timer {
                                id: resetJustFinishedDragTimer
                                interval: 60
                                repeat: false
                                onTriggered: selectionManager.justFinishedDrag = false
                            }

                            Timer {
                                id: autoScrollTimer
                                interval: 20
                                repeat: true
                                running: selectionManager.active

                                onTriggered: {
                                    var viewTop = filesGridView.contentY;
                                    var viewBottom = viewTop + filesGridView.height;
                                    var scrollMargin = 32;
                                    var step = 10;

                                    if (selectionManager.curY < viewTop + scrollMargin && filesGridView.contentY > 0) {
                                        filesGridView.contentY = Math.max(0, filesGridView.contentY - step);
                                        selectionManager.update(selectionManager.curX, selectionManager.curY);
                                    } else if (selectionManager.curY > viewBottom - scrollMargin && filesGridView.contentY < filesGridView.contentHeight - filesGridView.height) {
                                        filesGridView.contentY = Math.min(filesGridView.contentHeight - filesGridView.height, filesGridView.contentY + step);
                                        selectionManager.update(selectionManager.curX, selectionManager.curY);
                                    }
                                }
                            }

                            // Background click & rubberband selection area
                            MouseArea {
                                id: bgMouseArea
                                parent: filesGridView.contentItem
                                x: 0
                                y: 0
                                width: Math.max(filesGridView.width, filesGridView.contentWidth)
                                height: Math.max(filesGridView.height + filesGridView.contentY, filesGridView.contentHeight)
                                z: -1
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                preventStealing: theme.dragAction === "select"

                                property point pressPt: Qt.point(0, 0)

                                onPressed: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        pressPt = Qt.point(mouse.x, mouse.y);
                                        if (theme.dragAction === "select") {
                                            selectionManager.start(mouse.x, mouse.y, !!(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)));
                                        }
                                    }
                                }

                                onPositionChanged: function(mouse) {
                                    if (theme.dragAction !== "select") return;
                                    if (mouse.buttons & Qt.LeftButton) {
                                        selectionManager.update(mouse.x, mouse.y);
                                    }
                                }

                                onReleased: function(mouse) {
                                    if (selectionManager.active) {
                                        selectionManager.end();
                                    }
                                }

                                onCanceled: {
                                    if (selectionManager.active) {
                                        selectionManager.end();
                                    }
                                }

                                onClicked: function(mouse) {
                                    if (selectionManager.justFinishedDrag) return;
                                    if (mouse.button === Qt.RightButton && !engine.is_searching_everywhere) {
                                        var pt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                        contextMenu.showEmptyMenu(pt.x, pt.y);
                                    } else {
                                        filesGridView.clearSelection();
                                        contextMenu.close();
                                    }
                                }
                            }

                            function moveSelection(dx, dy, isShift) {
                                gridContainer.moveSelection(dx, dy, isShift);
                            }

                            focus: true
                            Keys.onLeftPressed: function(event) {
                                moveSelection(-1, 0, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onRightPressed: function(event) {
                                moveSelection(1, 0, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onUpPressed: function(event) {
                                moveSelection(0, -1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onDownPressed: function(event) {
                                moveSelection(0, 1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function(event) {
                                openSelected();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function(event) {
                                openSelected();
                                event.accepted = true;
                            }

                            model: gridContainer.displayedItems

                            delegate: Item {
                                id: fileCardDelegate
                                width: filesGridView.cellWidth
                                height: filesGridView.cellHeight

                                readonly property var item: modelData
                                readonly property bool isSelected: !!filesGridView.selectedIndices[index]

                                readonly property bool isCutItem: {
                                    if (!engine.has_clipboard) return false;
                                    try {
                                        var cutList = JSON.parse(engine.clipboard_cut_paths_json || "[]");
                                        var myPath = engine.is_searching_everywhere ? item.path : (engine.current_path + "/" + item.name);
                                        return cutList.indexOf(myPath) !== -1;
                                    } catch (e) {
                                        return false;
                                    }
                                }

                                opacity: isCutItem ? 0.52 : 1.0

                                readonly property int col: index % filesGridView.cols
                                readonly property bool hasLeft: isSelected && (col > 0) && !!filesGridView.selectedIndices[index - 1]
                                readonly property bool hasRight: isSelected && (col < filesGridView.cols - 1) && !!filesGridView.selectedIndices[index + 1]

                                readonly property string thumbSource: {
                                    if (!theme.showThumbnails || fileCardDelegate.item.is_dir) return "";
                                    var fullPath = engine.is_searching_everywhere
                                        ? fileCardDelegate.item.path
                                        : (engine.current_path + "/" + fileCardDelegate.item.name);
                                    var t = engine.get_thumbnail(fullPath);
                                    if (t && t.length > 0) return t;
                                    return fileCardDelegate.item.thumbnail || "";
                                }
                                readonly property bool hasThumbnail: theme.showThumbnails && thumbSource.length > 0
                                    && (thumbImg.status === Image.Ready)

                                readonly property bool isDropTarget: fileCardDelegate.item.is_dir && folderDropArea.containsDrag

                                // Drop target for folders: accept drops + hover-to-open
                                DropArea {
                                    id: folderDropArea
                                    anchors.fill: parent
                                    enabled: fileCardDelegate.item.is_dir
                                    keys: ["text/uri-list"]

                                    property string folderPath: engine.is_searching_everywhere
                                        ? fileCardDelegate.item.path
                                        : (engine.current_path + "/" + fileCardDelegate.item.name)

                                    onEntered: function(drag) {
                                        dragManager.hoverTarget = folderPath;
                                    }
                                    onExited: {
                                        if (dragManager.hoverTarget === folderPath) {
                                            dragManager.hoverTarget = "";
                                        }
                                    }
                                    onPositionChanged: function(drag) {
                                        dragManager.hoverTarget = folderPath;
                                    }
                                    onDropped: function(drop) {
                                        dragManager.hoverTarget = "";
                                        if (!drop.hasUrls) return;

                                        var destPath = folderPath;
                                        var paths = [];
                                        for (var i = 0; i < drop.urls.length; ++i) {
                                            var u = drop.urls[i].toString();
                                            if (u.startsWith("file://")) u = u.slice(7);
                                            // Ignore dropping a folder into itself
                                            if (u === destPath) continue;
                                            paths.push(u);
                                        }
                                        if (paths.length === 0) return;

                                        // Internal drag: honor Ctrl (copy) vs default (move).
                                        // External drag from another app: copy is the safe default.
                                        var asCopy;
                                        if (drop.source === dragProxy) {
                                            asCopy = dragManager.asCopy;
                                        } else {
                                            asCopy = (drop.proposedAction === Qt.CopyAction) || !(drop.supportedActions & Qt.MoveAction);
                                        }

                                        drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                                        if (dragManager.isRmb) {
                                            var pt = mapToItem(window.contentItem, cardMouseArea.mouseX, cardMouseArea.mouseY);
                                            rmbDropMenu.showAt(pt.x, pt.y, paths, destPath);
                                        } else {
                                            window.handleDrop(paths, destPath, asCopy);
                                        }
                                    }
                                }

                                // Connected Selection Background with FULL Matching Outer Curvature
                                Rectangle {
                                    id: cardHighlight
                                    anchors.fill: parent
                                    anchors.topMargin: 4
                                    anchors.bottomMargin: 4
                                    anchors.leftMargin: fileCardDelegate.hasLeft ? -4 : 4
                                    anchors.rightMargin: fileCardDelegate.hasRight ? -4 : 4

                                    radius: theme.radiusL
                                    color: fileCardDelegate.isDropTarget
                                        ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, theme.isDark ? 0.20 : 0.14)
                                        : (fileCardDelegate.isSelected
                                            ? theme.secondaryContainer
                                            : (cardMouseArea.pressed ? theme.activeOverlay : theme.hoverOverlay))
                                    opacity: (fileCardDelegate.isSelected || cardMouseArea.containsMouse || fileCardDelegate.isDropTarget) ? 1.0 : 0.0
                                    border.color: fileCardDelegate.isDropTarget ? theme.primary : Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0)
                                    border.width: fileCardDelegate.isDropTarget ? 2 : 0

                                    Behavior on opacity { NumberAnimation { duration: theme.durationFast } }
                                    scale: fileCardDelegate.isDropTarget ? 1.06 : 1.0
                                    Behavior on scale { SpringAnimation { spring: 4.0; damping: 0.3 } }

                                    // Square off right half if connected right (leaves left outer corners curved)
                                    Rectangle {
                                        visible: fileCardDelegate.hasRight
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width / 2
                                        color: parent.color
                                        radius: 0
                                    }

                                    // Square off left half if connected left (leaves right outer corners curved)
                                    Rectangle {
                                        visible: fileCardDelegate.hasLeft
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width / 2
                                        color: parent.color
                                        radius: 0
                                    }
                                }

                                // Hover/press scale. (An earlier version of this line
                                // branched on a non-existent `entered` flag, which made
                                // the whole binding throw and left cards unscalable.)
                                scale: cardMouseArea.pressed ? 0.94
                                    : ((cardMouseArea.containsMouse && !fileCardDelegate.hasLeft && !fileCardDelegate.hasRight) ? 1.03 : 1.0)
                                Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6
                                    z: 1

                                    Item { Layout.fillHeight: true }

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 46
                                        Layout.preferredHeight: 46

                                        LoafIcon {
                                            visible: !fileCardDelegate.hasThumbnail && (theme.iconSource === "phosphor")
                                            anchors.centerIn: parent
                                            name: fileCardDelegate.isCutItem
                                                ? (fileCardDelegate.item.is_dir ? "folder-dashed" : "file-dashed")
                                                : (fileCardDelegate.item.icon || (fileCardDelegate.item.is_dir ? "folder" : "file"))
                                            size: 42
                                            color: fileCardDelegate.isSelected
                                                ? theme.secondaryContainerFg
                                                : (fileCardDelegate.item.is_dir ? theme.primary : theme.textMain)
                                        }

                                        // Symlink badge indicator
                                        Rectangle {
                                            visible: fileCardDelegate.item.is_symlink
                                            width: 14
                                            height: 14
                                            radius: 7
                                            color: theme.surfaceContainer
                                            border.color: theme.outlineVariant
                                            border.width: 1
                                            anchors.bottom: parent.bottom
                                            anchors.right: parent.right
                                            z: 2

                                            LoafIcon {
                                                anchors.centerIn: parent
                                                name: "arrow-square-out"
                                                size: 9
                                                color: theme.primary
                                            }
                                        }

                                        Image {
                                            visible: !fileCardDelegate.hasThumbnail && (theme.iconSource === "system")
                                            anchors.centerIn: parent
                                            source: fileCardDelegate.item.icon_path
                                            width: 44
                                            height: 44
                                            sourceSize.width: 64
                                            sourceSize.height: 64
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            mipmap: true
                                        }

                                        Item {
                                            id: thumbSlot
                                            anchors.fill: parent
                                            visible: fileCardDelegate.hasThumbnail

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: theme.radiusM
                                                color: fileCardDelegate.isSelected ? theme.secondaryContainer : theme.surfaceContainerHigh
                                                opacity: 0.6
                                            }

                                            // Rounded mask. layer.enabled gives it a texture
                                            // so it can be used as a MultiEffect maskSource
                                            // while staying invisible.
                                            Rectangle {
                                                id: thumbMask
                                                anchors.fill: parent
                                                radius: theme.radiusM
                                                color: "white"
                                                visible: false
                                                layer.enabled: true
                                            }

                                            // Thumbnail. MultiEffect cannot sample an invisible
                                            // item, so the *visible* image is masked via
                                            // layer.effect instead of feeding a hidden source
                                            // into a separate MultiEffect.
                                            Image {
                                                id: thumbImg
                                                anchors.fill: parent
                                                source: fileCardDelegate.thumbSource
                                                fillMode: Image.PreserveAspectCrop
                                                sourceSize.width: 96
                                                sourceSize.height: 96
                                                asynchronous: false
                                                cache: true
                                                smooth: true
                                                mipmap: true
                                                visible: fileCardDelegate.hasThumbnail
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    maskEnabled: true
                                                    maskSource: thumbMask
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: theme.radiusM
                                                color: "transparent"
                                                border.color: fileCardDelegate.isSelected ? theme.primary : theme.outlineVariant
                                                border.width: 1
                                                opacity: fileCardDelegate.isSelected ? 0.75 : 0.35
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        // If search everywhere, show disambiguated display_name (e.g. Projects/Pictures)
                                        text: engine.is_searching_everywhere
                                            ? (fileCardDelegate.item.display_name || fileCardDelegate.item.name)
                                            : fileCardDelegate.item.name
                                        color: fileCardDelegate.isSelected ? theme.secondaryContainerFg : theme.textMain
                                        font.pixelSize: 11
                                        font.bold: fileCardDelegate.item.is_dir || fileCardDelegate.isSelected
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignTop
                                        wrapMode: Text.WrapAnywhere
                                        maximumLineCount: 2
                                        elide: Text.ElideMiddle
                                    }

                                    Item { Layout.fillHeight: true }
                                }

                                MouseArea {
                                    id: cardMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    preventStealing: true

                                    onWheel: function(wheel) {
                                        wheel.accepted = false;
                                    }

                                    property point pressPt: Qt.point(0, 0)
                                    property bool dragStarted: false

                                    onPressed: function(mouse) {
                                        if (mouse.button === Qt.LeftButton) {
                                            pressPt = Qt.point(mouse.x, mouse.y);
                                            dragStarted = false;
                                            if (!fileCardDelegate.isSelected && !(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
                                                filesGridView.selectItem(index, false, false);
                                            }
                                        }
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (!(mouse.buttons & (Qt.LeftButton | Qt.RightButton))) return;
                                        if (engine.is_searching_everywhere) return;
                                        if (dragStarted) return;

                                        var dx = mouse.x - pressPt.x;
                                        var dy = mouse.y - pressPt.y;
                                        if (dx * dx + dy * dy >= 36) {
                                            dragStarted = true;
                                            dragManager.isRmb = !!(mouse.buttons & Qt.RightButton);
                                            var gpt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                            dragManager.cursorPos = gpt;
                                            dragManager.begin(fileCardDelegate.item, index, mouse);
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        if (dragStarted) {
                                            dragManager.end();
                                            dragStarted = false;
                                        }
                                    }

                                    onCanceled: {
                                        if (dragStarted) {
                                            dragManager.end();
                                            dragStarted = false;
                                        }
                                    }

                                    onClicked: function(mouse) {
                                        if (searchInput.activeFocus)
                                            searchInput.focus = false;
                                        if (mouse.button === Qt.RightButton) {
                                            if (!fileCardDelegate.isSelected) {
                                                filesGridView.selectItem(index, false, false);
                                            }
                                            var pt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                            contextMenu.showItemMenu(fileCardDelegate.item, pt.x, pt.y);
                                        } else {
                                            contextMenu.close();
                                            var isCtrl = !!(mouse.modifiers & Qt.ControlModifier);
                                            var isShift = !!(mouse.modifiers & Qt.ShiftModifier);
                                            filesGridView.selectItem(index, isCtrl, isShift);
                                        }
                                    }

                                    onDoubleClicked: function(mouse) {
                                        if (mouse.button === Qt.LeftButton) {
                                            var targetPath = engine.is_searching_everywhere
                                                ? fileCardDelegate.item.path
                                                : (engine.current_path + "/" + fileCardDelegate.item.name);

                                            if (fileCardDelegate.item.is_dir) {
                                                gridContainer.clearSelection();
                                                engine.set_path(targetPath);
                                                if (engine.is_searching_everywhere) {
                                                    engine.clear_search_everywhere();
                                                    searchInput.text = "";
                                                }
                                            } else {
                                                engine.open_item(targetPath);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // List View Column Headers
                        Rectangle {
                            id: listHeaderRow
                            readonly property bool shown: engine.view_mode === "list" && !engine.is_searching_everywhere
                            visible: opacity > 0.001
                            opacity: shown ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 32
                            radius: theme.radiusM
                            color: theme.surfaceContainer
                            z: 2

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                // Name Column
                                Item {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 100
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            text: "Name"
                                            color: engine.sort_by === "name" ? theme.primary : theme.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        LoafIcon {
                                            visible: engine.sort_by === "name"
                                            name: engine.sort_ascending ? "sort-ascending" : "sort-descending"
                                            size: 13
                                            color: theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (engine.sort_by === "name") {
                                                engine.toggle_sort_order();
                                            } else {
                                                engine.set_sort("name", true);
                                            }
                                        }
                                    }
                                }

                                // Date Modified Column
                                Item {
                                    visible: window.listShowDate
                                    Layout.preferredWidth: 150
                                    Layout.minimumWidth: 96
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            text: "Date Modified"
                                            color: engine.sort_by === "modified" ? theme.primary : theme.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        LoafIcon {
                                            visible: engine.sort_by === "modified"
                                            name: engine.sort_ascending ? "sort-ascending" : "sort-descending"
                                            size: 13
                                            color: theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (engine.sort_by === "modified") {
                                                engine.toggle_sort_order();
                                            } else {
                                                engine.set_sort("modified", false);
                                            }
                                        }
                                    }
                                }

                                // Type Column
                                Item {
                                    visible: window.listShowType
                                    Layout.preferredWidth: 100
                                    Layout.minimumWidth: 70
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            text: "Type"
                                            color: engine.sort_by === "type" ? theme.primary : theme.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        LoafIcon {
                                            visible: engine.sort_by === "type"
                                            name: engine.sort_ascending ? "sort-ascending" : "sort-descending"
                                            size: 13
                                            color: theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (engine.sort_by === "type") {
                                                engine.toggle_sort_order();
                                            } else {
                                                engine.set_sort("type", true);
                                            }
                                        }
                                    }
                                }

                                // Size Column
                                Item {
                                    visible: window.listShowSize
                                    Layout.preferredWidth: 80
                                    Layout.minimumWidth: 60
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Text {
                                            text: "Size"
                                            color: engine.sort_by === "size" ? theme.primary : theme.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        LoafIcon {
                                            visible: engine.sort_by === "size"
                                            name: engine.sort_ascending ? "sort-ascending" : "sort-descending"
                                            size: 13
                                            color: theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (engine.sort_by === "size") {
                                                engine.toggle_sort_order();
                                            } else {
                                                engine.set_sort("size", false);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Detailed List View
                        ListView {
                            id: filesListView
                            anchors.top: listHeaderRow.shown ? listHeaderRow.bottom : parent.top
                            anchors.topMargin: listHeaderRow.shown ? 6 : 0
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            spacing: 3
                            clip: true
                            z: engine.view_mode === "list" ? 2 : 1
                            // Cross-fade grid <-> list instead of an instant swap.
                            opacity: engine.view_mode === "list" ? 1.0 : 0.0
                            visible: opacity > 0.001
                            enabled: engine.view_mode === "list"
                            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                            interactive: true
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                id: listScrollBar
                                policy: ScrollBar.AsNeeded
                                width: 12
                                padding: 2
                                contentItem: Rectangle {
                                    implicitWidth: 6
                                    radius: 3
                                    color: listScrollBar.pressed ? theme.primary : (listScrollBar.hovered ? theme.outline : theme.outlineVariant)
                                    opacity: listScrollBar.active ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }

                            WheelHandler {
                                id: listWheelHandler
                                target: null
                                onWheel: function(event) {
                                    var delta = event.angleDelta.y;
                                    var step = 80;
                                    var newY = filesListView.contentY - (delta > 0 ? step : -step);
                                    var maxY = Math.max(0, filesListView.contentHeight - filesListView.height);
                                    filesListView.contentY = Math.max(0, Math.min(maxY, newY));
                                }
                            }

                            // Keyboard navigation (arrow keys + open), mirroring the grid.
                            focus: false
                            Keys.onUpPressed: function(event) {
                                gridContainer.moveSelection(0, -1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onDownPressed: function(event) {
                                gridContainer.moveSelection(0, 1, !!(event.modifiers & Qt.ShiftModifier));
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function(event) {
                                gridContainer.openSelected();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: function(event) {
                                gridContainer.openSelected();
                                event.accepted = true;
                            }

                            model: filesGridView.model

                            delegate: Item {
                                id: listRowDelegate
                                width: filesListView.width
                                height: 38

                                readonly property var item: modelData
                                readonly property bool isSelected: !engine.is_searching_everywhere && !!gridContainer.selectedIndices[index]
                                readonly property bool isHovered: listRowMouse.containsMouse
                                readonly property bool isDropTarget: listFolderDropArea.containsDrag

                                readonly property bool isCutItem: {
                                    if (!engine.has_clipboard) return false;
                                    try {
                                        var cutList = JSON.parse(engine.clipboard_cut_paths_json || "[]");
                                        var myPath = engine.is_searching_everywhere ? item.path : (engine.current_path + "/" + item.name);
                                        return cutList.indexOf(myPath) !== -1;
                                    } catch (e) {
                                        return false;
                                    }
                                }

                                readonly property string fullPath: engine.is_searching_everywhere
                                    ? item.path : (engine.current_path + "/" + item.name)
                                readonly property string thumbSource: {
                                    if (!theme.showThumbnails || item.is_dir) return "";
                                    var t = engine.get_thumbnail(fullPath);
                                    if (t && t.length > 0) return t;
                                    return item.thumbnail || "";
                                }
                                readonly property bool hasThumbnail: theme.showThumbnails && thumbSource.length > 0
                                    && (listThumbImg.status === Image.Ready)

                                opacity: isCutItem ? 0.52 : 1.0
                                Behavior on opacity { NumberAnimation { duration: theme.durationFast } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: theme.radiusM
                                    color: listRowDelegate.isSelected
                                        ? theme.secondaryContainer
                                        : (listRowDelegate.isDropTarget ? theme.primaryContainer : theme.hoverOverlay)
                                    opacity: (listRowDelegate.isSelected || listRowDelegate.isHovered || listRowDelegate.isDropTarget) ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: theme.durationFast } }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Name Column
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Item {
                                            width: 22
                                            height: 22
                                            Layout.alignment: Qt.AlignVCenter

                                            LoafIcon {
                                                visible: !listRowDelegate.hasThumbnail && theme.iconSource === "phosphor"
                                                anchors.centerIn: parent
                                                name: listRowDelegate.isCutItem
                                                    ? (listRowDelegate.item.is_dir ? "folder-dashed" : "file-dashed")
                                                    : (listRowDelegate.item.icon || (listRowDelegate.item.is_dir ? "folder" : "file"))
                                                size: 18
                                                color: listRowDelegate.isSelected ? theme.secondaryContainerFg : (listRowDelegate.item.is_dir ? theme.primary : theme.textMain)
                                            }

                                            // Small symlink badge indicator
                                            Rectangle {
                                                visible: listRowDelegate.item.is_symlink
                                                width: 10
                                                height: 10
                                                radius: 5
                                                color: theme.surfaceContainer
                                                border.color: theme.outlineVariant
                                                border.width: 1
                                                anchors.bottom: parent.bottom
                                                anchors.right: parent.right

                                                LoafIcon {
                                                    anchors.centerIn: parent
                                                    name: "arrow-square-out"
                                                    size: 7
                                                    color: theme.primary
                                                }
                                            }

                                            Image {
                                                visible: !listRowDelegate.hasThumbnail && theme.iconSource === "system"
                                                anchors.centerIn: parent
                                                source: listRowDelegate.item.icon_path ? (listRowDelegate.item.icon_path.indexOf("file://") === 0 ? listRowDelegate.item.icon_path : ("file://" + listRowDelegate.item.icon_path)) : ""
                                                width: 18
                                                height: 18
                                                sourceSize.width: 36
                                                sourceSize.height: 36
                                                fillMode: Image.PreserveAspectFit
                                            }

                                            // Inline image thumbnail (replaces the icon).
                                            Rectangle {
                                                anchors.fill: parent
                                                visible: listRowDelegate.hasThumbnail
                                                radius: 6
                                                color: theme.surfaceContainerHigh
                                                clip: true

                                                Image {
                                                    id: listThumbImg
                                                    anchors.fill: parent
                                                    source: listRowDelegate.thumbSource
                                                    fillMode: Image.PreserveAspectCrop
                                                    sourceSize.width: 44
                                                    sourceSize.height: 44
                                                    asynchronous: true
                                                    cache: true
                                                    smooth: true
                                                    mipmap: true
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 6
                                                    color: "transparent"
                                                    border.color: theme.outlineVariant
                                                    border.width: 1
                                                    opacity: 0.4
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: listRowDelegate.item.name
                                            color: listRowDelegate.isSelected ? theme.secondaryContainerFg : theme.textMain
                                            font.pixelSize: 13
                                            font.bold: listRowDelegate.item.is_dir || listRowDelegate.isSelected
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    // Date Column
                                    Text {
                                        visible: window.listShowDate
                                        Layout.preferredWidth: 150
                                        Layout.minimumWidth: 96
                                        text: listRowDelegate.item.modified_str || "-"
                                        color: listRowDelegate.isSelected ? theme.secondaryContainerFg : theme.textMuted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    // Type Column
                                    Text {
                                        visible: window.listShowType
                                        Layout.preferredWidth: 100
                                        Layout.minimumWidth: 70
                                        text: listRowDelegate.item.category || "-"
                                        color: listRowDelegate.isSelected ? theme.secondaryContainerFg : theme.outline
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    // Size Column
                                    Text {
                                        visible: window.listShowSize
                                        Layout.preferredWidth: 80
                                        Layout.minimumWidth: 60
                                        text: listRowDelegate.item.size_str || "-"
                                        color: listRowDelegate.isSelected ? theme.secondaryContainerFg : theme.textMuted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }

                                DropArea {
                                    id: listFolderDropArea
                                    anchors.fill: parent
                                    enabled: listRowDelegate.item.is_dir
                                    keys: ["text/uri-list"]

                                    onEntered: function(drag) {
                                        dragManager.hoverTarget = engine.current_path + "/" + listRowDelegate.item.name;
                                    }
                                    onExited: {
                                        if (dragManager.hoverTarget === (engine.current_path + "/" + listRowDelegate.item.name)) {
                                            dragManager.hoverTarget = "";
                                        }
                                    }
                                    onDropped: function(drop) {
                                        if (!drop.hasUrls) return;
                                        var folderPath = engine.current_path + "/" + listRowDelegate.item.name;
                                        dragManager.hoverTarget = "";
                                        var paths = [];
                                        for (var i = 0; i < drop.urls.length; ++i) {
                                            var u = drop.urls[i].toString();
                                            if (u.startsWith("file://")) u = u.slice(7);
                                            if (u === folderPath) continue;
                                            paths.push(u);
                                        }
                                        if (paths.length === 0) return;

                                        var asCopy;
                                        if (drop.source === dragProxy) {
                                            asCopy = dragManager.asCopy;
                                        } else {
                                            asCopy = (drop.proposedAction === Qt.CopyAction) || !(drop.supportedActions & Qt.MoveAction);
                                        }
                                        drop.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                                        if (dragManager.isRmb) {
                                            var pt = mapToItem(window.contentItem, listRowMouse.mouseX, listRowMouse.mouseY);
                                            rmbDropMenu.showAt(pt.x, pt.y, paths, folderPath);
                                        } else {
                                            window.handleDrop(paths, folderPath, asCopy);
                                        }
                                    }
                                }

                                MouseArea {
                                    id: listRowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true

                                    onWheel: function(wheel) {
                                        wheel.accepted = false;
                                    }

                                    property point pressPos: Qt.point(0, 0)
                                    property bool isDragging: false

                                    onPressed: function(mouse) {
                                        pressPos = Qt.point(mouse.x, mouse.y);
                                        isDragging = false;
                                        var isCtrl = !!(mouse.modifiers & Qt.ControlModifier);
                                        var isShift = !!(mouse.modifiers & Qt.ShiftModifier);
                                        if (mouse.button === Qt.LeftButton) {
                                            if (!gridContainer.selectedIndices[index] && !isCtrl && !isShift) {
                                                gridContainer.selectItem(index, false, false);
                                            }
                                        }
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (mouse.buttons & (Qt.LeftButton | Qt.RightButton)) {
                                            var dx = mouse.x - pressPos.x;
                                            var dy = mouse.y - pressPos.y;
                                            if (!isDragging && (dx*dx + dy*dy >= 36)) {
                                                isDragging = true;
                                                dragManager.isRmb = !!(mouse.buttons & Qt.RightButton);
                                                var gpt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                                dragManager.cursorPos = gpt;
                                                dragManager.begin(listRowDelegate.item, index, mouse);
                                            }
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        if (isDragging) {
                                            isDragging = false;
                                            dragManager.end();
                                        }
                                    }

                                    onClicked: function(mouse) {
                                        if (isDragging) return;
                                        if (searchInput.activeFocus)
                                            searchInput.focus = false;
                                        var isCtrl = !!(mouse.modifiers & Qt.ControlModifier);
                                        var isShift = !!(mouse.modifiers & Qt.ShiftModifier);
                                        if (mouse.button === Qt.LeftButton) {
                                            gridContainer.selectItem(index, isCtrl, isShift);
                                        } else if (mouse.button === Qt.RightButton) {
                                            if (!gridContainer.selectedIndices[index]) {
                                                gridContainer.selectItem(index, false, false);
                                            }
                                            var pt = mapToItem(window.contentItem, mouse.x, mouse.y);
                                            contextMenu.showItemMenu(listRowDelegate.item, pt.x, pt.y);
                                        }
                                    }

                                    onDoubleClicked: function(mouse) {
                                        if (mouse.button === Qt.LeftButton) {
                                            var fullPath = engine.is_searching_everywhere
                                                ? listRowDelegate.item.path
                                                : (engine.current_path + "/" + listRowDelegate.item.name);
                                            if (listRowDelegate.item.is_dir) {
                                                gridContainer.clearSelection();
                                                engine.set_path(fullPath);
                                                if (engine.is_searching_everywhere) {
                                                    engine.clear_search_everywhere();
                                                    searchInput.text = "";
                                                }
                                            } else {
                                                engine.open_item(fullPath);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // VIEW 2: INTEGRATED SETTINGS VIEW
                SettingsView {
                    id: settingsView
                    anchors.fill: parent
                    anchors.margins: 22
                    searchQuery: window.activeView === "settings" ? searchInput.text : ""
                    visible: opacity > 0.001
                    opacity: window.activeView === "settings" ? 1.0 : 0.0
                    enabled: window.activeView === "settings"

                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: Translate {
                        y: window.activeView === "settings" ? 0 : 8
                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }

                // VIEW 3: PC DASHBOARD
                PCView {
                    id: pcView
                    anchors.fill: parent
                    anchors.margins: 22
                    visible: opacity > 0.001
                    opacity: window.activeView === "pc" ? 1.0 : 0.0
                    enabled: window.activeView === "pc"

                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: Translate {
                        y: window.activeView === "pc" ? 0 : 8
                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }

                // VIEW 4: TRASH is now a normal directory (navigated via the nav
                // rail -> engine.trash_root); no dedicated view exists anymore.
                } // end mainStageContent
            }
        }
    }

    // ==========================================
    // FILE DRAG & DROP SYSTEM
    // ==========================================
    QtObject {
        id: dragManager
        property bool active: false
        property bool asCopy: false
        property bool isRmb: false
        property var paths: []          // absolute paths being dragged
        property string hoverTarget: "" // dir path currently hovered (for auto-open)
        property point cursorPos: Qt.point(0, 0)

        function begin(item, index, mouse) {
            // Drag the whole selection if the pressed card is part of it,
            // otherwise just the pressed card.
            var idxs = [];
            if (filesGridView.selectedIndices[index]) {
                for (var k in filesGridView.selectedIndices) idxs.push(parseInt(k));
            } else {
                filesGridView.selectItem(index, false, false);
                idxs = [index];
            }

            var items = JSON.parse(engine.files_json || "[]");
            var list = [];
            for (var i = 0; i < idxs.length; ++i) {
                var it = items[idxs[i]];
                if (!it) continue;
                list.push(engine.is_searching_everywhere ? it.path
                    : (engine.current_path + "/" + it.name));
            }
            if (list.length === 0) return;

            paths = list;
            isRmb = (mouse.button === Qt.RightButton || !!(mouse.buttons & Qt.RightButton));
            asCopy = !!(mouse.modifiers & Qt.ControlModifier);
            active = true;
            hoverTarget = "";
            dragProxy.x = cursorPos.x;
            dragProxy.y = cursorPos.y;

            // Grab the ghost for the drag pixmap, then start once it's ready.
            dragGhost.visible = true;
            dragGhost.grabToImage(function(result) {
                dragProxy.ghostImageSource = result.url;
                dragGhost.visible = false;
                if (dragManager.active) {
                    dragProxy.Drag.active = true;
                }
            });
        }

        function end() {
            active = false;
            hoverTarget = "";
            hoverOpenTimer.stop();
            dragProxy.Drag.active = false;
        }
    }

    // Invisible proxy that carries the platform drag (external apps read its mimeData)
    Item {
        id: dragProxy
        visible: false
        width: 1
        height: 1

        Drag.active: false
        Drag.dragType: Drag.Automatic
        Drag.keys: ["text/uri-list"]
        Drag.source: dragProxy
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: dragManager.asCopy ? Qt.CopyAction : Qt.MoveAction
        Drag.hotSpot.x: dragGhost.width / 2
        Drag.hotSpot.y: dragGhost.height / 2
        Drag.imageSource: ghostImageSource

        // Build a file:// uri list from the dragged paths.
        // Qt splits text/uri-list on CRLF per RFC 2483, so join with \r\n.
        property string uriList: {
            var uris = [];
            for (var i = 0; i < dragManager.paths.length; ++i) {
                uris.push("file://" + dragManager.paths[i]);
            }
            return uris.join("\r\n");
        }
        property url ghostImageSource: ""

        Drag.mimeData: ({
            "text/uri-list": uriList,
            "text/plain": dragManager.paths.join("\n")
        })

        // dragFinished is a signal of the Drag attached type, not the Item
        Drag.onDragFinished: function(dropAction) {
            // Internal drops handle their own fs work via DropArea.onDropped.
            // Only clean up state here; the DropArea path already refreshed.
            dragManager.end();
        }
    }

    // Visible ghost shown while dragging inside the app (also source of the drag image)
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
        opacity: 0.96

        Row {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 10

            LoafIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "file"
                size: 22
                color: theme.primary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dragManager.paths.length > 1
                    ? (dragManager.paths.length + " files")
                    : (dragManager.paths.length === 1
                        ? dragManager.paths[0].split("/").pop()
                        : "")
                color: theme.textMain
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, 180)
            }
        }

        // "copy" badge when Ctrl is held
        Rectangle {
            visible: dragManager.asCopy
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: -4
            width: 20
            height: 20
            radius: 10
            color: theme.primary

            LoafIcon {
                anchors.centerIn: parent
                name: "copy"
                size: 12
                color: theme.primaryFg
            }
        }
    }

    // Hover-to-open timer: if a drag stays over a folder, navigate into it
    Timer {
        id: hoverOpenTimer
        interval: 750
        repeat: false
        running: dragManager.active && dragManager.hoverTarget.length > 0
        onTriggered: {
            if (dragManager.active && dragManager.hoverTarget.length > 0) {
                var target = dragManager.hoverTarget;
                dragManager.hoverTarget = "";
                filesGridView.clearSelection();
                engine.set_path(target);
            }
        }
    }

    // ==========================================
    // CONTEXT MENUS -- built on the shared LoafMenu library
    // ==========================================
    LoafMenu {
        id: contextMenu

        property var currentTargetItem: null
        property bool isItemMenu: false

        menuMinWidth: 230
        menuMaxWidth: 340

        readonly property bool insideTrash: engine.trash_root.length > 0
            && engine.current_path === engine.trash_root

        function targetPath() {
            if (!currentTargetItem)
                return "";
            if (engine.is_searching_everywhere)
                return currentTargetItem.path || "";
            return engine.current_path + "/" + currentTargetItem.name;
        }

        function selectedPaths() {
            var items = gridContainer.getSelectedItems();
            var out = [];
            for (var i = 0; i < items.length; ++i) {
                var it = items[i];
                out.push(engine.is_searching_everywhere
                    ? it.path
                    : (engine.current_path + "/" + it.name));
            }
            return out;
        }

        function compressSubmenu(paths) {
            function doCompress(fmt) {
                contextMenu.close();
                engine.compress_items_with_options(JSON.stringify(paths), fmt, "");
            }
            var sub = [
                { text: ".zip Archive", icon: "file-zip", action: function() { doCompress("zip"); } },
                { text: "Encrypted .zip…", icon: "lock", action: function() {
                    contextMenu.close();
                    passwordModal.openFor(paths, "zip_encrypted");
                } },
                { text: ".tar.gz Archive", icon: "archive", separatorBefore: true, action: function() { doCompress("tar.gz"); } },
                { text: ".7z Archive", icon: "file-archive", action: function() { doCompress("7z"); } }
            ];
            if (theme.showAdvancedArchives) {
                sub.push({ text: ".tar.xz Archive", icon: "archive", separatorBefore: true, action: function() { doCompress("tar.xz"); } });
                sub.push({ text: ".tar.zst Archive", icon: "archive", action: function() { doCompress("tar.zst"); } });
                sub.push({ text: ".tar.bz2 Archive", icon: "archive", action: function() { doCompress("tar.bz2"); } });
                sub.push({ text: ".cpio Archive", icon: "package", action: function() { doCompress("cpio"); } });
            }
            return sub;
        }

        // Resolved once per menu opening: the desktop-entry scan is cached in
        // Rust, but the xdg-mime lookups are not free.
        function appsForPath(itemPath) {
            var recommended = [];
            var recent = [];
            var defaultId = "";
            try {
                recommended = JSON.parse(engine.open_with_apps(itemPath) || "[]");
                recent = JSON.parse(engine.recent_open_with_apps() || "[]");
                defaultId = engine.default_app_for(itemPath) || "";
            } catch (e) {
                recommended = [];
                recent = [];
            }
            return { recommended: recommended, recent: recent, defaultId: defaultId };
        }

        // A non-clickable section header, omitted when its section is empty.
        function sectionHeader(text, icon, hasFollowing) {
            if (!hasFollowing)
                return null;
            return { text: text, icon: icon, separatorBefore: true, enabled: false };
        }

        // "Open With" submenu: recommended apps for the item's MIME type, plus
        // the full application list for anything else.
        function openWithSubmenu(itemPath, recommended, defaultId, recent) {
            var used = {};
            var sub = [];
            var suggested = [];

            // Entries already in Recent are shown there, not repeated below.
            for (var i = 0; i < recommended.length; ++i) {
                if (!recent || !recent.some(function(r) { return r.id === recommended[i].id; }))
                    suggested.push(recommended[i]);
            }

            // Recent apps first: they are what the user opened before.
            if (recent && recent.length > 0) {
                for (var r = 0; r < recent.length; ++r) {
                    var rec = recent[r];
                    used[rec.id] = true;
                    sub.push(appRow(rec, itemPath, rec.id === defaultId, "history"));
                }
                var header = sectionHeader("Suggested for this file", "sparkle", suggested.length > 0);
                if (header)
                    sub.push(header);
            }

            for (var j = 0; j < suggested.length; ++j) {
                used[suggested[j].id] = true;
                sub.push(appRow(suggested[j], itemPath, suggested[j].id === defaultId));
            }

            // Every other installed application, so an app that does not declare
            // the MIME type can still be used.
            var others = [];
            try {
                others = JSON.parse(engine.all_open_with_apps() || "[]");
            } catch (e) {
                others = [];
            }
            var extra = [];
            for (var j = 0; j < others.length; ++j) {
                if (!used[others[j].id])
                    extra.push(appRow(others[j], itemPath, others[j].id === defaultId));
            }
            if (extra.length > 0) {
                sub.push({ text: "Other Applications…", icon: "list", separatorBefore: true, submenu: extra });
            }
            sub.push({ text: "Run Custom Command…", icon: "terminal", separatorBefore: true, action: function() {
                contextMenu.close();
                commandModal.showFor(itemPath);
            } });
            return sub;
        }

        function appRow(app, itemPath, isDefault, extraIcon) {
            return {
                text: app.name,
                icon: extraIcon || "package",
                // A check mark marks the app xdg-open would use by default.
                checkable: isDefault,
                checked: isDefault,
                action: function() {
                    contextMenu.close();
                    engine.open_with_app(itemPath, app.id);
                }
            };
        }

        // Picks the application `xdg-open` will use for this item from now on.
        function setDefaultSubmenu(itemPath, recommended, defaultId, recent) {
            var supported = [];

            // Recent entries are shown separately, so drop duplicates below.
            for (var i = 0; i < recommended.length; ++i) {
                if (!recent || !recent.some(function(r) { return r.id === recommended[i].id; }))
                    supported.push(recommended[i]);
            }

            var sub = [];
            // One-click "make default what I used lately" lives at the top.
            if (recent && recent.length > 0) {
                for (var r = 0; r < recent.length; ++r)
                    sub.push(defaultAppRow(recent[r], itemPath, defaultId, "history"));
                var header = sectionHeader("Supported apps", "package", supported.length > 0);
                if (header)
                    sub.push(header);
            }

            for (var j = 0; j < supported.length; ++j)
                sub.push(defaultAppRow(supported[j], itemPath, defaultId));
            return sub;
        }

        // Own scope so each row's closure captures its own app entry.
        function defaultAppRow(app, itemPath, defaultId, extraIcon) {
            return {
                text: app.name,
                icon: extraIcon || "package",
                checkable: true,
                checked: app.id === defaultId,
                action: function() {
                    contextMenu.close();
                    engine.set_default_app(itemPath, app.id);
                }
            };
        }

        function buildItemModel() {
            var it = currentTargetItem;
            if (!it)
                return [];
            var isSearching = engine.is_searching_everywhere;
            var itemPath = targetPath();
            var paths = selectedPaths();
            if (paths.length === 0)
                paths = [itemPath];
            var parentPath = it.parent_path || "";
            var inTrash = contextMenu.insideTrash;
            var m = [];

            m.push({ text: "Open", icon: "arrow-square-out", action: function() {
                if (it.is_dir) {
                    engine.set_path(itemPath);
                    if (engine.is_searching_everywhere) {
                        engine.clear_search_everywhere();
                        searchInput.text = "";
                    }
                } else {
                    engine.open_item(itemPath);
                }
            } });

            // Hide "Open Containing Folder" when the item already lives in the
            // folder we are browsing.
            var showContaining = isSearching
                || (parentPath.length > 0 && parentPath !== engine.current_path);
            if (showContaining) {
                m.push({ text: "Open Containing Folder", icon: "folder-open", action: function() {
                    if (parentPath.length > 0) {
                        engine.clear_search_everywhere();
                        searchInput.text = "";
                        engine.set_path(parentPath);
                    }
                } });
            }

            m.push({ text: "Open in Terminal", icon: "terminal", action: function() {
                var dir = it.is_dir ? itemPath : (parentPath.length > 0 ? parentPath : engine.current_path);
                engine.open_terminal(dir);
            } });

            m.push({ text: "Quick Look", icon: "eye", shortcut: "Space", action: function() {
                contextMenu.close();
                window.toggleQuickLook();
            } });

            // Folders can be handed to archive tools, browsers, editors, etc. too.
            var appInfo = appsForPath(itemPath);
            var withApps = openWithSubmenu(itemPath, appInfo.recommended, appInfo.defaultId, appInfo.recent);
            if (withApps.length > 0) {
                m.push({ text: "Open With", icon: "package", submenu: withApps });
            }
            var defaultApps = setDefaultSubmenu(itemPath, appInfo.recommended, appInfo.defaultId, appInfo.recent);
            if (defaultApps.length > 0) {
                m.push({ text: "Set Default Application", icon: "check-square", submenu: defaultApps });
            }

            m.push({ text: "Cut", icon: "scissors", shortcut: "Ctrl+X", separatorBefore: true, action: function() {
                engine.copy_items(JSON.stringify(paths), true);
            } });
            m.push({ text: "Copy", icon: "copy", shortcut: "Ctrl+C", action: function() {
                engine.copy_items(JSON.stringify(paths), false);
            } });
            m.push({ text: "Rename", icon: "pencil-simple", shortcut: "F2", enabled: !inTrash, action: function() {
                inputModal.showRename(it.name);
            } });

            var isArchive = !isSearching && it.is_dir === false
                && engine.is_archive_file(itemPath);
            if (isArchive) {
                m.push({ text: "Extract Here", icon: "archive", action: function() {
                    engine.extract_archive(itemPath, false);
                } });
                m.push({ text: "Extract to Folder", icon: "folder-open", action: function() {
                    engine.extract_archive(itemPath, true);
                } });
            }

            m.push({ text: "Compress", icon: "file-archive", submenu: compressSubmenu(paths) });

            if (inTrash) {
                m.push({ text: "Restore", icon: "arrow-counter-clockwise", separatorBefore: true, action: function() {
                    engine.restore_trash_item(itemPath);
                } });
            } else {
                m.push({ text: "Move to Trash", icon: "trash", shortcut: "Del", danger: true, separatorBefore: true, action: function() {
                    engine.trash_items(JSON.stringify(paths));
                    gridContainer.clearSelection();
                } });
            }

            m.push({ text: "Properties", icon: "info", action: function() {
                propsModal.showInfo(itemPath);
            } });

            return m;
        }

        function buildEmptyModel() {
            var m = [];
            m.push({ text: "New Folder", icon: "folder-plus", action: function() {
                inputModal.showNewFolder();
            } });
            m.push({ text: "New Text File", icon: "file-plus", action: function() {
                inputModal.showNewFile();
            } });
            m.push({ text: "Open Terminal Here", icon: "terminal", action: function() {
                engine.open_terminal(engine.current_path);
            } });
            if (engine.has_clipboard) {
                m.push({ text: "Paste", icon: "clipboard", shortcut: "Ctrl+V", action: function() {
                    window.triggerPaste();
                } });
            }
            m.push({ text: "Select All", icon: "check-square", shortcut: "Ctrl+A", separatorBefore: true, action: function() {
                gridContainer.selectAll();
            } });
            return m;
        }

        function showItemMenu(item, mx, my) {
            currentTargetItem = item;
            isItemMenu = true;
            model = buildItemModel();
            openAt(mx, my);
        }

        function showEmptyMenu(mx, my) {
            currentTargetItem = null;
            isItemMenu = false;
            model = buildEmptyModel();
            openAt(mx, my);
        }
    }

    // ==========================================
    // QUICK LOOK PREVIEW (Spacebar)
    // ==========================================
    LoafPopup {
        id: quickLook
        parent: Overlay.overlay

        property var info: ({})
        // Rendered once per open so scrolling never re-runs the highlighter.
        property string previewHtml: ""

        readonly property bool isCode: info.language !== undefined
            && info.language !== "" && info.language !== "text"
        readonly property bool isMarkdown: info.language === "markdown"

        readonly property bool isAudio: info.kind === "media"
            && /\.(mp3|flac|wav|ogg|oga|m4a|aac|opus|wma)$/i.test(String(info.name || ""))

        function mediaIcon() {
            return info.kind === "folder" ? "folder"
                : (info.kind === "image" ? "image"
                : (info.kind === "media" ? (isAudio ? "music" : "video") : "file-text"));
        }

        function fallbackIcon() {
            return info.kind === "folder" ? "folder"
                : (info.kind === "media" ? (isAudio ? "music" : "video") : "file");
        }

        width: Math.min(window.width - 160, 900)
        height: Math.min(window.height - 160, 640)

        function showFor(path) {
            var raw = "{}";
            try {
                raw = engine.quick_look(path) || "{}";
            } catch (e) {
                raw = "{}";
            }
            info = JSON.parse(raw);
            previewHtml = buildPreviewHtml();
            openAt((window.width - width) / 2, (window.height - height) / 2);
        }

        // ---- markup helpers ---------------------------------------------------

        function escapeHtml(s) {
            return String(s)
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;");
        }

        function span(color, text, bold) {
            return "<font color=\"" + color + "\"" + (bold ? " weight=\"bold\"" : "") + ">"
                + escapeHtml(text) + "</font>";
        }

        function keywordSet(language) {
            var common = "if else for while return function class const let var new this null true false import from export default switch case break continue do try catch finally throw async await typeof instanceof extends super static public private protected interface enum implements package void int float double char bool string bool";
            switch (language) {
            case "rust":
                return "fn let mut const static struct enum impl trait pub use mod match if else for while loop return where ref self Self crate as in break continue unsafe move dyn box async await match Some None Ok Err";
            case "python":
                return "def class return if elif else for while import from as with try except finally raise lambda None True False and or not in is pass yield async await global nonlocal assert del";
            case "javascript":
                return common;
            case "c":
            case "cpp":
                return common + " size_t typedef struct union enum namespace template typename operator using virtual override delete nullptr printf malloc free sizeof";
            case "java":
                return common + " public private protected abstract extends implements throws void int long double float boolean char byte short synchronized native final transient";
            case "go":
                return "package import func var const type struct interface map chan go defer if else for range return switch case break continue select fallthrough nil true false";
            case "shell":
            case "nix":
                return "if then else elif fi for while do done case esac function return export local readonly source echo cd exit set unset local in with let rec inherit";
            case "lua":
                return "function local end if then elseif else for while do return break repeat until nil true false and or not in";
            case "sql":
                return "select from where insert into values update set delete create table drop alter index join inner left right outer on group by order having limit offset union distinct as and or not null primary key foreign references default";
            case "css":
                return "important media supports keyframes import charset font-face root inherit initial unset";
            default:
                return common;
            }
        }

        function keywordsFor(language) {
            var set = {};
            var list = keywordSet(language).split(" ");
            for (var i = 0; i < list.length; ++i) {
                if (list[i].length > 0)
                    set[list[i]] = true;
            }
            return set;
        }

        function highlightCode(code, language) {
            var keywords = keywordsFor(language);
            var commentColor = theme.outline;
            var stringColor = theme.isDark ? "#8bd5a4" : "#0b7a3f";
            var numberColor = theme.isDark ? "#f0b072" : "#a35b00";
            var keywordColor = theme.primary;

            // One pass over the source: the first alternative that matches at a
            // position wins, so comments/strings are consumed whole.
            var re = language === "python" || language === "shell" || language === "nix" || language === "yaml"
                ? /(^#!.*|\/\/[^\n]*|#[^\n]*)|("(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')|(\b\d+(?:\.\d+)?\b)|([A-Za-z_][A-Za-z0-9_]*)/gm
                : /(\/\*[\s\S]*?\*\/|\/\/[^\n]*|<!--[\s\S]*?-->|#[^\n]*)|("(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`)|(\b\d+(?:\.\d+)?\b)|([A-Za-z_][A-Za-z0-9_]*)/gm;

            var out = "";
            var last = 0;
            var m;
            while ((m = re.exec(code)) !== null) {
                if (m.index > last)
                    out += escapeHtml(code.substring(last, m.index));
                if (m[1])
                    out += span(commentColor, m[1]);
                else if (m[2])
                    out += span(stringColor, m[2]);
                else if (m[3])
                    out += span(numberColor, m[3]);
                else if (m[4])
                    out += keywords[m[4]] ? span(keywordColor, m[4], true) : escapeHtml(m[4]);
                last = re.lastIndex;
                if (m[0].length === 0)
                    re.lastIndex++;
            }
            out += escapeHtml(code.substring(last));
            return out;
        }

        function renderMarkdownInline(escaped) {
            var out = escaped;
            out = out.replace(/`([^`]+)`/g, "<font color=\"" + theme.primary + "\"><i>$1</i></font>");
            out = out.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
            out = out.replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<i>$2</i>");
            out = out.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g,
                "<font color=\"" + theme.primary + "\" underline=\"single\">$1</font>");
            return out;
        }

        function renderMarkdown(src) {
            var lines = src.split("\n");
            var html = "";
            var inCode = false;
            var headingColor = theme.primary;
            for (var i = 0; i < lines.length; ++i) {
                var line = lines[i];
                var trimmed = line.trim();

                if (/^```/.test(trimmed)) {
                    inCode = !inCode;
                    html += span(theme.outline, trimmed) + "<br>";
                    continue;
                }
                if (inCode) {
                    html += span(theme.secondaryContainerFg, line) + "<br>";
                    continue;
                }
                if (trimmed.length === 0) {
                    html += "<br>";
                    continue;
                }
                var heading = /^(#{1,6})\s+(.*)$/.exec(trimmed);
                if (heading) {
                    var level = heading[1].length;
                    html += "<font color=\"" + headingColor + "\" weight=\"bold\" size=\""
                        + (20 - level * 2) + "\">" + renderMarkdownInline(escapeHtml(heading[2])) + "</font><br>";
                    continue;
                }
                if (/^(-{3,}|\*{3,}|_{3,})$/.test(trimmed)) {
                    html += span(theme.outline, "──────────") + "<br>";
                    continue;
                }
                if (/^>\s?/.test(trimmed)) {
                    html += span(theme.textMuted, "│ " + renderMarkdownInline(escapeHtml(trimmed.replace(/^>\s?/, "")))) + "<br>";
                    continue;
                }
                var bullet = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/.exec(line);
                if (bullet) {
                    var pad = bullet[1].length > 0 ? "&nbsp;".repeat(Math.min(bullet[1].length, 8)) : "";
                    var marker = /^\d/.test(bullet[2]) ? bullet[2] + " " : "• ";
                    html += pad + span(theme.primary, marker) + renderMarkdownInline(escapeHtml(bullet[3])) + "<br>";
                    continue;
                }
                html += renderMarkdownInline(escapeHtml(line)) + "<br>";
            }
            return html;
        }

        function buildPreviewHtml() {
            if (!info || info.kind !== "text")
                return "";
            if (info.language === "markdown")
                return renderMarkdown(String(info.text || ""));
            if (!isCode)
                return escapeHtml(String(info.text || ""));
            return "<pre style=\"margin:0px\">" + highlightCode(String(info.text || ""), info.language) + "</pre>";
        }

        // ---- content ----------------------------------------------------------

        ColumnLayout {
            width: quickLook.width - 2 * quickLook.contentPadding
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                LoafIcon {
                    name: quickLook.mediaIcon()
                    size: 22
                    color: theme.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: quickLook.info.name || ""
                        color: theme.textMain
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideMiddle
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (quickLook.info.size_str || "-") + "  ·  "
                            + (quickLook.info.modified_str || "-") + "  ·  "
                            + (quickLook.info.path || "")
                        color: theme.textMuted
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: theme.separator
            }

            // Image preview
            Item {
                visible: quickLook.info.kind === "image"
                Layout.fillWidth: true
                Layout.fillHeight: true

                Image {
                    id: quickLookImage
                    anchors.fill: parent
                    anchors.margins: 4
                    source: quickLook.info.image_url || ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    cache: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: quickLookImage.status === Image.Error
                    text: "Could not render this image"
                    color: theme.textMuted
                    font.pixelSize: 13
                }
            }

            // Text / code / markdown preview
            Flickable {
                id: previewFlick
                visible: quickLook.info.kind === "text"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: Math.max(width, previewText.implicitWidth + 24)
                contentHeight: Math.max(height, previewText.implicitHeight + 24)
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                Text {
                    id: previewText
                    x: 12
                    y: 12
                    text: quickLook.previewHtml
                    textFormat: Text.RichText
                    color: theme.textMain
                    font.pixelSize: 13
                    // Code keeps its own line breaks and scrolls sideways;
                    // prose wraps to the pane width.
                    wrapMode: quickLook.isCode && !quickLook.isMarkdown ? Text.NoWrap : Text.Wrap
                    width: quickLook.isCode && !quickLook.isMarkdown
                        ? implicitWidth
                        : previewFlick.width - 24
                }
            }

            // Folder / media / unsupported
            ColumnLayout {
                visible: quickLook.info.kind !== "image" && quickLook.info.kind !== "text"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Item { Layout.fillHeight: true }

                LoafIcon {
                    Layout.alignment: Qt.AlignHCenter
                    name: quickLook.fallbackIcon()
                    size: 46
                    color: theme.textMuted
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    text: quickLook.info.note || ""
                    color: theme.textMuted
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Item { Layout.fillHeight: true }
            }

            Text {
                visible: quickLook.info.truncated === true
                text: "Preview truncated — showing the first part of the file"
                color: theme.textMuted
                font.pixelSize: 11
            }
        }
    }

    // ==========================================
    // INPUT MODAL (New Folder, New File, Rename)
    // ==========================================
    LoafTextPrompt {
        id: inputModal

        property string mode: "new_folder"
        property string targetItemName: ""

        function showNewFolder() {
            mode = "new_folder";
            title = "New Folder";
            label = "Enter a name for the new folder";
            placeholder = "Folder name";
            initialText = "New Folder";
            confirmText = "Save";
            selectBasename = false;
            open();
        }

        function showNewFile() {
            mode = "new_file";
            title = "New File";
            label = "Enter a name for the new file";
            placeholder = "File name";
            initialText = "Untitled.txt";
            confirmText = "Save";
            selectBasename = false;
            open();
        }

        function showRename(oldName) {
            mode = "rename";
            targetItemName = oldName;
            title = "Rename";
            label = "Enter a new name";
            initialText = oldName;
            confirmText = "Rename";
            selectBasename = true;
            open();
        }

        onAccepted: function(text) {
            var val = (text || "").trim();
            if (val.length === 0)
                return;
            if (mode === "new_folder") {
                engine.create_folder(engine.current_path, val);
            } else if (mode === "new_file") {
                engine.create_file(engine.current_path, val);
            } else if (mode === "rename") {
                engine.rename_item(engine.current_path, targetItemName, val);
            }
        }
    }

    // ==========================================
    // CUSTOM COMMAND MODAL (Open With → Run Command)
    // ==========================================
    LoafTextPrompt {
        id: commandModal

        property string targetPath: ""
        property bool rememberCommand: false

        function showFor(path) {
            targetPath = path;
            title = "Run Custom Command";
            label = "Command to open “" + (path.split("/").pop() || path) + "”. "
                + "Use %f where the file should go (it is appended if omitted).";
            placeholder = "mpv %f";
            initialText = rememberCommand ? (engine.get_setting("openWithCustomCommand") || "") : "";
            confirmText = "Run";
            selectBasename = false;
            open();
        }

        onAccepted: function(text) {
            var cmd = (text || "").trim();
            if (cmd.length === 0)
                return;
            engine.set_setting("openWithCustomCommand", cmd);
            rememberCommand = true;
            engine.run_custom_command(cmd, targetPath);
        }
    }

    // ==========================================
    // PROPERTIES MODAL
    // ==========================================
    LoafDialog {
        id: propsModal
        title: "Properties"
        dialogWidth: 380

        property var info: ({})

        function showInfo(path) {
            info = JSON.parse(engine.get_item_info(path) || "{}");
            open();
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            LoafIcon {
                name: propsModal.info.is_dir ? "folder" : "file-text"
                size: 32
                color: theme.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: propsModal.info.name || "-"
                    color: theme.textMain
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Text {
                    text: propsModal.info.is_dir ? "Folder" : "File"
                    color: theme.textMuted
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: theme.separator
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Path: " + (propsModal.info.path || "-")
                color: theme.textMuted
                font.pixelSize: 11
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
            }
            Text {
                text: "Size: " + (propsModal.info.size || "-")
                color: theme.textMuted
                font.pixelSize: 11
            }
            Text {
                text: "Modified: " + (propsModal.info.modified || "-")
                color: theme.textMuted
                font.pixelSize: 11
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LoafButton {
                text: "OK"
                variant: "filled"
                onClicked: propsModal.close()
            }
        }
    }

    // ==========================================
    // UNIFIED VIEW DROPDOWN
    // ==========================================
    LoafMenu {
        id: viewMenuPopup
        menuMinWidth: 288
        menuMaxWidth: 360
        model: []

        Text {
            Layout.leftMargin: 6
            text: "VIEW"
            color: theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.8
        }

        LoafSegmented {
            Layout.leftMargin: 2
            options: [
                { value: "grid", label: "Grid", icon: "squares-four" },
                { value: "list", label: "List", icon: "list" }
            ]
            value: engine.view_mode
            onSelected: function(v) { engine.view_mode = v; viewMenuPopup.close(); }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            color: theme.separator
        }

        Text {
            Layout.leftMargin: 6
            text: "SORT BY"
            color: theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.8
        }

        LoafMenuItem {
            text: "Name"
            checkable: true
            checked: engine.sort_by === "name"
            onTriggered: { engine.set_sort("name", engine.sort_ascending); viewMenuPopup.close(); }
        }
        LoafMenuItem {
            text: "Date Modified"
            checkable: true
            checked: engine.sort_by === "modified"
            onTriggered: { engine.set_sort("modified", engine.sort_ascending); viewMenuPopup.close(); }
        }
        LoafMenuItem {
            text: "Size"
            checkable: true
            checked: engine.sort_by === "size"
            onTriggered: { engine.set_sort("size", engine.sort_ascending); viewMenuPopup.close(); }
        }
        LoafMenuItem {
            text: "Type"
            checkable: true
            checked: engine.sort_by === "type"
            onTriggered: { engine.set_sort("type", engine.sort_ascending); viewMenuPopup.close(); }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            color: theme.separator
        }

        Text {
            Layout.leftMargin: 6
            text: "ORDER"
            color: theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.8
        }

        LoafSegmented {
            Layout.leftMargin: 2
            options: [
                { value: "asc", label: "Ascending", icon: "sort-ascending" },
                { value: "desc", label: "Descending", icon: "sort-descending" }
            ]
            value: engine.sort_ascending ? "asc" : "desc"
            onSelected: function(v) { engine.set_sort(engine.sort_by, v === "asc"); }
        }

        Text {
            Layout.leftMargin: 6
            Layout.topMargin: 4
            text: "FOLDERS"
            color: theme.textMuted
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.8
        }

        LoafSegmented {
            Layout.leftMargin: 2
            options: [
                { value: "first", label: "First" },
                { value: "last", label: "Last" },
                { value: "mixed", label: "Mixed" }
            ]
            value: engine.folder_position
            onSelected: function(v) { engine.change_folder_position(v); }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            color: theme.separator
        }

        LoafSwitch {
            Layout.topMargin: 2
            label: "Show Hidden Files"
            checked: engine.show_hidden
            onToggled: engine.toggle_show_hidden()
        }
    }

    // ==========================================
    // PASSWORD PROMPT FOR ENCRYPTED ARCHIVES
    // ==========================================
    LoafTextPrompt {
        id: passwordModal

        property var paths: []
        property string format: "zip_encrypted"

        title: "Encrypted Archive"
        label: "Set a password to protect the archive"
        placeholder: "Password"
        confirmText: "Create"

        function openFor(targetPaths, fmt) {
            paths = targetPaths;
            format = fmt;
            initialText = "";
            open();
        }

        onAccepted: function(text) {
            if (!text || text.length === 0)
                return;
            engine.compress_items_with_options(JSON.stringify(paths), format, text);
        }
    }

    // ==========================================
    // RIGHT-MOUSE DRAG DROP MENU
    // ==========================================
    LoafMenu {
        id: rmbDropMenu
        menuMinWidth: 200
        menuMaxWidth: 280

        property var dropPaths: []
        property string dropDest: ""

        function showAt(px, py, paths, dest) {
            // A same-directory drop is a silent no-op.
            var sameDir = paths.length > 0;
            for (var i = 0; i < paths.length; ++i) {
                var p = paths[i];
                var slash = p.lastIndexOf("/");
                var parent = slash > 0 ? p.substring(0, slash) : "/";
                if (parent !== dest) {
                    sameDir = false;
                    break;
                }
            }
            if (sameDir) {
                dragManager.end();
                return;
            }
            dropPaths = paths;
            dropDest = dest;
            model = [
                { text: "Copy Here", icon: "copy", action: function() {
                    window.handleDrop(rmbDropMenu.dropPaths, rmbDropMenu.dropDest, true);
                } },
                { text: "Move Here", icon: "arrows-out-cardinal", action: function() {
                    window.handleDrop(rmbDropMenu.dropPaths, rmbDropMenu.dropDest, false);
                } },
                { text: "Link Here", icon: "link", action: function() {
                    engine.create_symlinks(JSON.stringify(rmbDropMenu.dropPaths), rmbDropMenu.dropDest);
                } },
                { text: "Cancel", icon: "x", danger: true, separatorBefore: true, action: function() {
                    dragManager.end();
                } }
            ];
            openAt(px, py);
        }
    }

    // ==========================================
    // CONFLICT RESOLUTION MODAL
    // ==========================================
    LoafDialog {
        id: conflictModal
        title: "File Conflict"
        dialogWidth: 420

        property var conflicts: []
        property var droppedPaths: []
        property string destDir: ""
        property bool isDrop: false
        property bool asCopy: false

        function showForClipboard(confList, dest) {
            conflicts = confList;
            destDir = dest;
            isDrop = false;
            open();
        }

        function showForDrop(confList, paths, dest, copy) {
            conflicts = confList;
            droppedPaths = paths;
            destDir = dest;
            isDrop = true;
            asCopy = copy;
            open();
        }

        function applyResolution(res) {
            if (isDrop) {
                engine.drop_items_resolved(JSON.stringify(droppedPaths), destDir, asCopy, res);
            } else {
                engine.paste_items_resolved(destDir, res);
            }
            close();
        }

        Text {
            Layout.fillWidth: true
            text: conflictModal.conflicts.length === 1
                ? ("\u201c" + conflictModal.conflicts[0].name + "\u201d already exists.")
                : (conflictModal.conflicts.length + " items already exist in this destination.")
            color: theme.textMuted
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Rectangle {
            visible: conflictModal.conflicts.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: theme.radiusM
            color: theme.surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                LoafIcon {
                    name: (conflictModal.conflicts[0] && conflictModal.conflicts[0].is_dir) ? "folder" : "file"
                    size: 20
                    color: theme.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: conflictModal.conflicts[0] ? conflictModal.conflicts[0].name : ""
                        color: theme.textMain
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    Text {
                        text: conflictModal.conflicts[0] ? ("Destination size: " + conflictModal.conflicts[0].dest_size) : ""
                        color: theme.outline
                        font.pixelSize: 11
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            LoafButton {
                text: "Cancel"
                variant: "text"
                onClicked: conflictModal.close()
            }
            Item { Layout.fillWidth: true }
            LoafButton {
                text: "Skip"
                variant: "tonal"
                onClicked: conflictModal.applyResolution("skip")
            }
            LoafButton {
                text: "Keep Both"
                variant: "tonal"
                onClicked: conflictModal.applyResolution("rename")
            }
            LoafButton {
                text: "Replace"
                variant: "filled"
                onClicked: conflictModal.applyResolution("overwrite")
            }
        }
    }
}
