import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// One portal file chooser request: a dedicated window that reuses the
// normal browsing views (sidebar + file pane) plus a filter dropdown, the
// choice widgets and an accept/cancel row. main.qml creates one per
// pickerRequested and answers through nativeBridge.respondPicker exactly
// once per request.
Window {
    id: picker

    // The normalized request spec from the portal backend.
    required property var request

    readonly property bool isSave: request.kind === "save"
    readonly property bool isSaveFiles: request.kind === "save-files"
    readonly property bool directoryMode: request.directory === true
    readonly property bool multiple: request.multiple === true
    readonly property bool modal: request.modal !== false

    readonly property var filters: request.filters || []
    // True when the app already offers a catch-all (a filter with no
    // patterns, or one whose patterns all mean "everything" — Firefox
    // sends `.*` or `*.*`), so we do not add a second "All files" entry.
    readonly property bool appHasCatchAll: {
        for (var i = 0; i < filters.length; ++i) {
            var patterns = filters[i].patterns || [];
            if (patterns.length === 0)
                return true;
            var allStar = true;
            for (var j = 0; j < patterns.length; ++j) {
                var p = String((patterns[j] || [])[1] || "");
                if (p !== "*" && p !== ".*" && p !== "*.*") {
                    allStar = false;
                    break;
                }
            }
            if (allStar)
                return true;
        }
        return false;
    }
    readonly property var filterOptions: {
        var options = [];
        if (!appHasCatchAll)
            options.push({ "value": "-1", "label": qsTr("All files") });
        for (var i = 0; i < filters.length; ++i)
            options.push({ "value": String(i), "label": filters[i].name });
        return options;
    }
    // Index into `filters`, -1 = all files. Starts plain and is set
    // imperatively in onCompleted so the current_filter match cannot fight
    // with user selections.
    property int activeFilter: -1

    // Look the filter up straight from `activeFilter` instead of through a
    // dependent binding: bindings still hold the previous value while a
    // change handler runs, so a binding read here applied the previous
    // filter (every selection lagged one step behind).
    function filterAt(index) {
        return index >= 0 && index < filters.length ? filters[index] : null;
    }

    // Chosen value per choice id; booleans are stored as JS booleans and
    // serialized as "true"/"false" in the reply.
    property var choiceValues: ({})
    property bool answered: false
    property bool pathEditing: false

    readonly property string acceptLabel: {
        if ((request.accept_label || "").length > 0)
            return request.accept_label;
        if (isSave)
            return qsTr("Save");
        if (directoryMode || isSaveFiles)
            return qsTr("Select Folder");
        return qsTr("Open");
    }

    signal finished(string handle)

    width: 900
    height: 640
    minimumWidth: 660
    minimumHeight: 460
    title: (request.title || "").length > 0
        ? request.title
        : (isSave ? qsTr("Save File") : qsTr("Open File"))
    color: theme.windowBackground
    modality: modal ? Qt.WindowModal : Qt.NonModal
    visible: true

    Shortcut { sequences: ["Ctrl+L", "Alt+D"]; onActivated: startEditingPath() }

    onActiveFilterChanged: applyPickerRules()

    onClosing: function(close) {
        close.accepted = false;
        respond(1, []);
    }

    Component.onCompleted: {
        for (var i = 0; i < (request.choices || []).length; ++i) {
            var choice = request.choices[i];
            var values = choice.values || [];
            if (values.length === 0)
                choiceValues[choice.id] = choice.selected === "true";
            else if ((choice.selected || "").length > 0)
                choiceValues[choice.id] = choice.selected;
            else
                choiceValues[choice.id] = values[0].id;
        }
        var start = request.start_folder || "";
        if (!start && (isSave || isSaveFiles)) {
            var documents = pane.engine.current_path + "/Documents";
            if (nativeBridge.fileExists(documents))
                start = documents;
        }
        if (start)
            pane.engine.set_path(start);
        if ((request.current_file || "").length > 0)
            pane.pendingSelect = [request.current_file];
        // Preselect the app's current_filter, if it matches one by name.
        var current = request.current_filter;
        if (current) {
            for (var j = 0; j < filters.length; ++j) {
                if (filters[j].name === current.name) {
                    activeFilter = j;
                    break;
                }
            }
        }
        nativeBridge.setPickerTransient(picker, request.parent_window || "", modal);
        applyPickerRules();
    }

    // Directory-only and the selected filter are engine rules, so the
    // normal listing machinery does the filtering. A catch-all (the
    // synthetic "All files" or an app filter without patterns) maps to no
    // engine filter at all, so toggling filters can never leave a
    // restrictive rule behind.
    function applyPickerRules() {
        var f = filterAt(activeFilter);
        pane.engine.set_picker_rules(f && f.patterns && f.patterns.length > 0 ? JSON.stringify(f) : "", directoryMode);
    }
    function systemIcon(name) {
        var source = theme.iconSource === "adwaita" ? "adwaita"
                   : theme.iconSource === "custom" ? theme.customIconTheme
                   : "system";
        return core.resolve_icon(source, name);
    }


    // True while a text field owns the keyboard, so the window-level key
    // handler must not steal keys for view navigation.
    readonly property bool fieldHasFocus: searchField.activeFocus || pathInput.activeFocus || nameField.activeFocus

    function startEditingPath() {
        pathInput.text = pane.engine.location_kind === "dir" ? pane.engine.current_path : "";
        pathEditing = true;
        pathInput.forceActiveFocus();
        pathInput.selectAll();
    }

    function commitPathEdit() {
        var raw = pathInput.text.trim();
        pathEditing = false;
        rootLayout.forceActiveFocus();
        if (raw.length === 0)
            return;
        pane.engine.set_path(raw);
        clearSearch();
    }
    function defocusInputs() {
        if (searchField.activeFocus)
            searchField.focus = false;
        if (pathEditing)
            pathEditing = false;
        rootLayout.forceActiveFocus();
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
            source: visible ? systemIcon(tib.systemIcon) : ""
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


    function clearSearch() {
        searchField.text = "";
        if (pane.engine.location_kind === "search")
            pane.engine.clear_search();
    }

    Timer {
        id: searchDebounce
        interval: 250
        onTriggered: {
            if (searchField.text.trim().length > 0)
                pane.engine.search(searchField.text, "folder", theme.searchContents);
        }
    }

    // Answers the request on the D-Bus side and closes the window. `uris`
    // are absolute paths; the backend percent-encodes them.
    function respond(code, uris) {
        if (answered)
            return;
        answered = true;
        var results = {};
        if (code === 0) {
            results.uris = uris;
            var choices = [];
            for (var i = 0; i < (request.choices || []).length; ++i) {
                var choice = request.choices[i];
                var value = choiceValues[choice.id];
                if (typeof value === "boolean")
                    value = value ? "true" : "false";
                choices.push([choice.id, value || ""]);
            }
            if (choices.length > 0)
                results.choices = choices;
            var currentFilter = filterAt(activeFilter);
            if (currentFilter)
                results.current_filter = currentFilter;
        }
        nativeBridge.respondPicker(request.handle, code, JSON.stringify(results));
        finished(request.handle);
        destroy();
    }

    // The request was closed from the D-Bus side (Request.Close()); the
    // backend already replied with code 2, so just go away.
    function dismiss() {
        if (answered)
            return;
        answered = true;
        finished(request.handle);
        destroy();
    }

    function acceptRequest() {
        if (answered)
            return;
        if (request.kind === "save") {
            var name = nameField.text.trim();
            if (name.length === 0 || name === "." || name === ".." || name.indexOf("/") >= 0) {
                nameField.forceActiveFocus();
                return;
            }
            if (pane.engine.location_kind !== "dir")
                return;
            var target = pane.engine.current_path + "/" + name;
            if (nativeBridge.fileExists(target)) {
                overwriteDialog.targets = [target];
                overwriteDialog.open();
                return;
            }
            respond(0, [target]);
            return;
        }
        if (request.kind === "save-files") {
            if (pane.engine.location_kind !== "dir")
                return;
            var folder = pane.engine.current_path;
            var uris = [];
            var files = request.files || [];
            for (var i = 0; i < files.length; ++i)
                uris.push(folder + "/" + files[i]);
            var existing = [];
            for (var j = 0; j < uris.length; ++j) {
                if (nativeBridge.fileExists(uris[j]))
                    existing.push(uris[j]);
            }
            if (existing.length > 0) {
                overwriteDialog.targets = uris;
                overwriteDialog.open();
                return;
            }
            respond(0, uris);
            return;
        }
        // OpenFile: only real paths can be returned (not archive members or
        // special locations).
        var selected = pane.selectedPaths().filter(function(path) { return path.indexOf("/") === 0; });
        if (directoryMode) {
            if (selected.length > 0)
                respond(0, multiple ? selected : [selected[0]]);
            else if (pane.engine.location_kind === "dir")
                respond(0, [pane.engine.current_path]);
            return;
        }
        if (selected.length === 0)
            return;
        if (!multiple) {
            // A single selected folder is entered instead of returned.
            if (selected.length === 1) {
                var row = pane.engine.row_of(selected[0]);
                var item = row >= 0 ? JSON.parse(pane.engine.item_json(row)) : null;
                if (item && item.is_dir) {
                    pane.engine.set_path(item.path);
                    return;
                }
            }
            selected = [selected[0]];
        }
        respond(0, selected);
    }

    ColumnLayout {
        id: rootLayout
        anchors.fill: parent
        spacing: 0
        focus: true

        // Navigating leaves search/filter mode; keep the field in sync.
        Connections {
            target: pane.engine
            function onCurrent_pathChanged() {
                if (searchField.text.length > 0)
                    searchField.text = "";
            }
        }

        Keys.onPressed: function(event) {
            // Text fields own the keyboard first.
            if (fieldHasFocus)
                return;
            if (event.key === Qt.Key_Escape) {
                respond(1, []);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                acceptRequest();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                pane.moveSelection(-1, 0, event.modifiers & Qt.ShiftModifier);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                pane.moveSelection(1, 0, event.modifiers & Qt.ShiftModifier);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                pane.moveSelection(0, -1, event.modifiers & Qt.ShiftModifier);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                pane.moveSelection(0, 1, event.modifiers & Qt.ShiftModifier);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backspace) {
                pane.engine.navigate_up();
                event.accepted = true;
            } else if (event.key === Qt.Key_Home) {
                pane.selectRow(0, false, event.modifiers & Qt.ShiftModifier);
                pane.ensureVisible(0);
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                var last = pane.engine.item_count - 1;
                pane.selectRow(last, false, event.modifiers & Qt.ShiftModifier);
                pane.ensureVisible(last);
                event.accepted = true;
            } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                pane.selectAll();
                event.accepted = true;
            }
        }

        // ---- header: title and filter ------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: (request.title || "").length > 0 ? request.title : (isSave ? qsTr("Save File") : qsTr("Open File"))
                color: theme.textMain
                font.pixelSize: theme.fs(17)
                font.bold: true
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - (filterRow.visible ? filterRow.width + 32 : 20))
            }

            RowLayout {
                id: filterRow
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                visible: filters.length > 0
                spacing: 10

                Text {
                    text: qsTr("Filter")
                    color: theme.textMuted
                    font.pixelSize: theme.fs(13)
                }
                LoafSelect {
                    id: filterSelect
                    width: 220
                    implicitWidth: 220
                    Layout.preferredWidth: 220
                    options: filterOptions
                    value: String(activeFilter)
                    accessibleName: qsTr("File type filter")
                    onSelected: function(value) { activeFilter = parseInt(value); }
                }
            }
        }

        // ---- header: path bar and search -----------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 10
            spacing: 10

            // Path bar: breadcrumbs, or a text field (Ctrl+L) with Tab completion.
            Rectangle {
                id: pathBar
                Layout.fillWidth: true
                Layout.minimumWidth: 140
                Layout.preferredHeight: 40
                radius: theme.radiusFull
                color: pathEditing ? theme.surfaceContainerHighest : theme.surfaceContainer
                clip: true

                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: startEditingPath()
                    onClicked: defocusInputs()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 6
                    spacing: 8
                    visible: pathEditing || theme.pathBarMode === "text"

                    LoafIcon {
                        name: pane.engine.location_kind === "search" ? "magnifying-glass" : "folder"
                        size: 16
                        color: theme.primary
                    }

                    TextInput {
                        id: pathInput
                        Layout.fillWidth: true
                        visible: pathEditing
                        color: theme.textMain
                        font.pixelSize: theme.fs(13)
                        font.family: "monospace"
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        Accessible.role: Accessible.EditableText
                        Accessible.name: qsTr("Location")
                        Keys.onReturnPressed: commitPathEdit()
                        Keys.onEnterPressed: commitPathEdit()
                        Keys.onEscapePressed: { pathEditing = false; rootLayout.forceActiveFocus(); }
                        Keys.onTabPressed: function(event) {
                            var done = core.complete_path(text, pane.engine.show_hidden);
                            if (done !== text) {
                                text = done;
                                cursorPosition = text.length;
                            }
                            event.accepted = true;
                        }
                        onActiveFocusChanged: if (!activeFocus && pathEditing) pathEditing = false
                    }

                    // Read-only path mirror for "text only" mode.
                    Text {
                        visible: !pathEditing
                        Layout.fillWidth: true
                        text: pane.engine.location_kind === "dir" || pane.engine.location_kind === "archive"
                            ? pane.engine.current_path : pane.engine.location_kind + "://"
                        color: theme.textMain
                        font.pixelSize: theme.fs(13)
                        font.family: "monospace"
                        elide: Text.ElideMiddle
                        verticalAlignment: Text.AlignVCenter
                        Accessible.role: Accessible.StaticText
                        Accessible.name: qsTr("Current location")
                    }

                    TopIconButton {
                        visible: pathEditing
                        iconName: "check"
                        accessibleName: qsTr("Go")
                        onClicked: commitPathEdit()
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
                    visible: !pathEditing && theme.pathBarMode !== "text"
                    model: JSON.parse(pane.engine.breadcrumbs_json || "[]")
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
                            Accessible.role: Accessible.Button
                            Accessible.name: crumbDelegate.modelData.name

                            Rectangle {
                                anchors.fill: parent
                                radius: theme.radiusFull
                                color: crumbDelegate.modelData.is_forward ? "transparent" : (chip.isCurrent ? theme.secondaryContainer : theme.hoverOverlay)
                                border.color: crumbDelegate.modelData.is_forward ? theme.outline : "transparent"
                                border.width: crumbDelegate.modelData.is_forward ? 1 : 0
                                opacity: (chip.isCurrent || crumbDelegate.modelData.is_forward || chipMouse.containsMouse) ? 1.0 : 0.0
                                Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
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
                                    source: visible ? systemIcon(crumbDelegate.modelData.system_icon || "folder") : ""
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
                                enabled: !crumbDelegate.modelData.is_forward
                                opacity: crumbDelegate.modelData.is_forward ? 0.4 : 1.0
                                onClicked: pane.engine.set_path(crumbDelegate.modelData.path)
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
            }

            // Search: typing filters the current view, Enter searches the
            // folder subtree.
            Rectangle {
                id: searchBox
                Layout.preferredWidth: 230
                Layout.preferredHeight: 40
                radius: theme.radiusFull
                color: theme.surfaceContainer
                border.width: searchField.activeFocus ? 2 : 1
                border.color: searchField.activeFocus ? theme.primary : theme.outlineVariant

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    LoafIcon {
                        name: "magnifying-glass"
                        size: 16
                        color: theme.textMuted
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: theme.textMain
                        font.pixelSize: theme.fs(13)
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        Accessible.role: Accessible.EditableText
                        Accessible.name: qsTr("Search")

                        Text {
                            text: pane.engine.location_kind === "search" ? qsTr("Search…") : qsTr("Filter this folder…")
                            color: theme.outline
                            font.pixelSize: theme.fs(13)
                            visible: !searchField.text && !searchField.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: {
                            if (pane.engine.location_kind === "search")
                                searchDebounce.restart();
                            else
                                pane.engine.set_filter(text);
                        }
                        Keys.onReturnPressed: function(event) {
                            if (text.trim().length > 0)
                                pane.engine.search(text, "folder", theme.searchContents);
                            event.accepted = true;
                        }
                        Keys.onEnterPressed: function(event) {
                            if (text.trim().length > 0)
                                pane.engine.search(text, "folder", theme.searchContents);
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: function(event) {
                            clearSearch();
                            event.accepted = true;
                        }
                    }

                    LoafIcon {
                        name: "x"
                        size: 14
                        color: theme.textMuted
                        visible: searchField.text.length > 0
                        opacity: searchClearMouse.containsMouse ? 1.0 : 0.6

                        MouseArea {
                            id: searchClearMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: clearSearch()
                        }
                    }
                }
            }
        }

        // ---- body: sidebar and the normal file view -----------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            spacing: 10

            Sidebar {
                id: sidebar
                Layout.fillHeight: true
                Layout.preferredWidth: implicitWidth
                expanded: true
                pickerMode: true
                activeId: {
                    var places = sidebar.places;
                    for (var i = 0; i < places.length; ++i) {
                        if (places[i].path && places[i].path === pane.engine.current_path)
                            return places[i].id;
                    }
                    return "";
                }
                // The picker only offers real folders; Recent/Starred/Trash
                // and This PC are hidden entirely.
                onPlaceClicked: function(place) {
                    if (place.path && place.path.indexOf("/") === 0 && !place.missing)
                        pane.engine.set_path(place.path);
                }
                onSettingsClicked: {}
            }

            FilePane {
                id: pane
                Layout.fillWidth: true
                Layout.fillHeight: true
                showHeader: false
                pickerMode: true
                pickerMultiple: multiple
                onFilePicked: function(path) { respond(0, [path]); }
            }
        }

        // ---- footer: choices, file name, buttons ---------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: theme.outlineVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                visible: (request.choices || []).length > 0
                spacing: 18

                Repeater {
                    model: request.choices || []

                    delegate: RowLayout {
                        required property var modelData
                        spacing: 8

                        // No options: a boolean choice.
                        LoafSwitch {
                            visible: (modelData.values || []).length === 0
                            label: modelData.label
                            checked: picker.choiceValues[modelData.id] === true
                            onToggled: function(checked) { picker.choiceValues[modelData.id] = checked; }
                        }

                        RowLayout {
                            visible: (modelData.values || []).length > 0
                            spacing: 8
                            Text {
                                text: modelData.label
                                color: theme.textMuted
                                font.pixelSize: theme.fs(13)
                            }
                            LoafSelect {
                                width: 180
                                implicitWidth: 180
                                Layout.preferredWidth: 180
                                options: (modelData.values || []).map(function(value) {
                                    return { "value": value.id, "label": value.label };
                                })
                                value: typeof picker.choiceValues[modelData.id] === "string" ? picker.choiceValues[modelData.id] : ""
                                accessibleName: modelData.label
                                onSelected: function(value) { picker.choiceValues[modelData.id] = value; }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: isSave
                spacing: 10

                Text {
                    text: qsTr("Name")
                    color: theme.textMuted
                    font.pixelSize: theme.fs(13)
                }
                LoafTextField {
                    id: nameField
                    Layout.fillWidth: true
                    text: request.current_name || ""
                    placeholderText: qsTr("File name")
                    Accessible.name: qsTr("File name")
                    onAccepted: acceptRequest()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }
                LoafButton {
                    text: qsTr("Cancel")
                    variant: "text"
                    onClicked: respond(1, [])
                }
                LoafButton {
                    text: acceptLabel
                    variant: "filled"
                    onClicked: acceptRequest()
                }
            }
        }
    }

    LoafDialog {
        id: overwriteDialog
        property var targets: []
        readonly property bool many: targets.length > 1
        width: 420
        title: many ? qsTr("Replace files?") : qsTr("Replace file?")

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: theme.textMain
            font.pixelSize: theme.fs(13)
            text: overwriteDialog.many
                ? qsTr("%1 of the files already exist in this folder. Replace them?").arg(overwriteDialog.targets.length)
                : qsTr("“%1” already exists. Replace it?").arg(overwriteDialog.targets.length > 0 ? overwriteDialog.targets[0].split("/").pop() : "")
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 10
            LoafButton {
                text: qsTr("Cancel")
                variant: "text"
                onClicked: overwriteDialog.close()
            }
            LoafButton {
                text: qsTr("Replace")
                variant: "danger"
                onClicked: {
                    overwriteDialog.close();
                    respond(0, overwriteDialog.targets);
                }
            }
        }
    }
}
