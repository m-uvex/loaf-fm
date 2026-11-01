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
    readonly property var filterOptions: {
        var options = [{ "value": "-1", "label": qsTr("All files") }];
        for (var i = 0; i < filters.length; ++i)
            options.push({ "value": String(i), "label": filters[i].name });
        return options;
    }
    // Index into `filters`, -1 = all files.
    property int activeFilter: {
        var current = request.current_filter;
        if (current) {
            for (var i = 0; i < filters.length; ++i) {
                if (filters[i].name === current.name)
                    return i;
            }
        }
        return -1;
    }
    readonly property var activeFilterObject: activeFilter >= 0 && activeFilter < filters.length ? filters[activeFilter] : null

    // Chosen value per choice id; booleans are stored as JS booleans and
    // serialized as "true"/"false" in the reply.
    property var choiceValues: ({})
    property bool answered: false

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
        nativeBridge.setPickerTransient(picker, request.parent_window || "", modal);
        applyPickerRules();
    }

    // Directory-only and the selected filter are engine rules, so the
    // normal listing machinery does the filtering.
    function applyPickerRules() {
        pane.engine.set_picker_rules(activeFilterObject ? JSON.stringify(activeFilterObject) : "", directoryMode);
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
            if (activeFilterObject)
                results.current_filter = activeFilterObject;
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

        Keys.onPressed: function(event) {
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
            Layout.preferredHeight: 60

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
                activeId: {
                    var kind = pane.engine.location_kind;
                    if (kind === "trash" || kind === "recent" || kind === "starred")
                        return kind;
                    var places = sidebar.places;
                    for (var i = 0; i < places.length; ++i) {
                        if (places[i].path && places[i].path === pane.engine.current_path)
                            return places[i].id;
                    }
                    return "";
                }
                // Recent/Starred/Trash list real files, so they are
                // browsable in a picker; This PC and settings have no
                // meaning here.
                onPlaceClicked: function(place) {
                    if (place.kind === "trash")
                        pane.engine.open_trash();
                    else if (place.kind === "recent")
                        pane.engine.open_recent();
                    else if (place.kind === "starred")
                        pane.engine.open_starred();
                    else if (place.path && place.path.indexOf("/") === 0 && !place.missing)
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
