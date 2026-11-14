import QtQuick
import QtQuick.Layouts
import app.loaf

ColumnLayout {
    id: root

    property string searchQuery: ""
    property string capturingId: ""

    readonly property var groups: [
        {
            title: qsTr("Selection & Editing"),
            subtitle: qsTr("Clipboard, selection, rename and delete actions"),
            icon: "selection-all",
            items: [
                { id: "copy", label: qsTr("Copy"), desc: qsTr("Copy selected items to clipboard") },
                { id: "cut", label: qsTr("Cut"), desc: qsTr("Move selected items to clipboard") },
                { id: "paste", label: qsTr("Paste"), desc: qsTr("Paste items into the current folder") },
                { id: "undo", label: qsTr("Undo"), desc: qsTr("Undo the last file operation") },
                { id: "redo", label: qsTr("Redo"), desc: qsTr("Redo the last undone operation") },
                { id: "selectAll", label: qsTr("Select all"), desc: qsTr("Select every item in the current view") },
                { id: "invertSelection", label: qsTr("Invert selection"), desc: qsTr("Swap selected and unselected items") },
                { id: "selectPattern", label: qsTr("Select by pattern"), desc: qsTr("Select items matching a wildcard pattern") },
                { id: "rename", label: qsTr("Rename"), desc: qsTr("Rename selected item or batch-rename multiple") },
                { id: "trash", label: qsTr("Move to Trash"), desc: qsTr("Move selected items to Trash") },
                { id: "deletePermanent", label: qsTr("Delete permanently"), desc: qsTr("Bypass Trash and delete permanently") },
                { id: "copyPath", label: qsTr("Copy path"), desc: qsTr("Copy full path of selected items") },
                { id: "properties", label: qsTr("Properties"), desc: qsTr("Inspect file or folder properties") }
            ]
        },
        {
            title: qsTr("Navigation & Search"),
            subtitle: qsTr("Directory traversal, path bar and filtering"),
            icon: "compass",
            items: [
                { id: "back", label: qsTr("Back"), desc: qsTr("Go back in folder history") },
                { id: "backAlt", label: qsTr("Back (alternate)"), desc: qsTr("Secondary shortcut for going back") },
                { id: "forward", label: qsTr("Forward"), desc: qsTr("Go forward in folder history") },
                { id: "up", label: qsTr("Parent folder"), desc: qsTr("Navigate up one directory") },
                { id: "home", label: qsTr("Home folder"), desc: qsTr("Jump to your Home directory") },
                { id: "editPath", label: qsTr("Edit path bar"), desc: qsTr("Focus and edit the location bar") },
                { id: "search", label: qsTr("Search"), desc: qsTr("Filter or search files") },
                { id: "refresh", label: qsTr("Reload"), desc: qsTr("Refresh the current directory") },
                { id: "bookmark", label: qsTr("Bookmark folder"), desc: qsTr("Add current folder to sidebar") }
            ]
        },
        {
            title: qsTr("Tabs, View & Window"),
            subtitle: qsTr("Tabs, split view, zoom and layout modes"),
            icon: "browsers",
            items: [
                { id: "newFolder", label: qsTr("New folder"), desc: qsTr("Create a new folder here") },
                { id: "quickLook", label: qsTr("Quick Look"), desc: qsTr("Preview the selected file") },
                { id: "toggleHidden", label: qsTr("Show hidden files"), desc: qsTr("Toggle dotfile visibility") },
                { id: "newTab", label: qsTr("New tab"), desc: qsTr("Open a new tab") },
                { id: "closeTab", label: qsTr("Close tab"), desc: qsTr("Close the active tab") },
                { id: "nextTab", label: qsTr("Next tab"), desc: qsTr("Switch to the next tab") },
                { id: "prevTab", label: qsTr("Previous tab"), desc: qsTr("Switch to the previous tab") },
                { id: "newWindow", label: qsTr("New window"), desc: qsTr("Open a new Loaf window") },
                { id: "toggleSplit", label: qsTr("Toggle split view"), desc: qsTr("Show or hide the second pane") },
                { id: "toggleSidebar", label: qsTr("Toggle sidebar"), desc: qsTr("Expand or collapse the navigation rail") },
                { id: "viewGrid", label: qsTr("Grid view"), desc: qsTr("Switch to icon grid layout") },
                { id: "viewList", label: qsTr("List view"), desc: qsTr("Switch to details list layout") },
                { id: "zoomIn", label: qsTr("Zoom in"), desc: qsTr("Increase icon size") },
                { id: "zoomOut", label: qsTr("Zoom out"), desc: qsTr("Decrease icon size") },
                { id: "zoomReset", label: qsTr("Reset zoom"), desc: qsTr("Restore default icon size") },
                { id: "quit", label: qsTr("Quit Loaf"), desc: qsTr("Close the application") }
            ]
        }
    ]

    function matchesItem(it) {
        if (!searchQuery || searchQuery.trim().length === 0) return true;
        var q = searchQuery.toLowerCase().trim();
        var seq = theme.shortcutFor(it.id).toLowerCase();
        var hay = (it.label + " " + it.desc + " " + seq + " shortcut keybinding").toLowerCase();
        var parts = q.split(/\s+/);
        for (var i = 0; i < parts.length; ++i) {
            if (parts[i].length > 0 && hay.indexOf(parts[i]) === -1)
                return false;
        }
        return true;
    }

    function groupHasMatches(grp) {
        for (var i = 0; i < grp.items.length; ++i) {
            if (matchesItem(grp.items[i])) return true;
        }
        return false;
    }

    readonly property int matchCount: {
        if (!searchQuery || searchQuery.trim().length === 0) return 0;
        var c = 0;
        for (var g = 0; g < groups.length; ++g) {
            for (var i = 0; i < groups[g].items.length; ++i) {
                if (matchesItem(groups[g].items[i])) c++;
            }
        }
        return c;
    }

    Layout.fillWidth: true
    spacing: 16

    Item {
        id: keyCapture
        focus: root.capturingId.length > 0
        Keys.onPressed: function(event) {
            if (root.capturingId.length === 0) return;
            event.accepted = true;
            if (event.key === Qt.Key_Escape) {
                root.capturingId = "";
                return;
            }
            if (event.key === Qt.Key_Backspace && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier | Qt.ShiftModifier))) {
                theme.resetShortcut(root.capturingId);
                root.capturingId = "";
                return;
            }
            var seq = theme.keyEventToSequence(event);
            if (seq.length > 0) {
                theme.setShortcut(root.capturingId, seq);
                root.capturingId = "";
            }
        }
    }

    SettingCard {
        visible: !searchQuery || searchQuery.trim().length === 0 || root.matchCount > 0
        title: qsTr("Keyboard Shortcuts")
        subtitle: qsTr("Click any shortcut to record a new key combination (Esc to cancel, Backspace to reset)")
        icon: "keyboard"

        SettingRow {
            icon: "arrow-counter-clockwise"
            title: qsTr("Reset all shortcuts")
            subtitle: qsTr("Restore every keyboard shortcut back to Loaf defaults")

            LoafButton {
                text: qsTr("Reset Defaults")
                icon: "arrow-counter-clockwise"
                variant: "tonal"
                onClicked: {
                    root.capturingId = "";
                    theme.resetAllKeybindings();
                }
            }
        }
    }

    Repeater {
        model: root.groups
        delegate: SettingCard {
            required property var modelData
            visible: root.groupHasMatches(modelData)
            title: modelData.title
            subtitle: modelData.subtitle
            icon: modelData.icon

            Repeater {
                model: modelData.items
                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0
                    visible: root.matchesItem(modelData)

                    SettingDivider { visible: index > 0 }

                    SettingRow {
                        title: modelData.label
                        subtitle: modelData.desc

                        RowLayout {
                            spacing: 6

                            LoafButton {
                                readonly property bool isCapturing: root.capturingId === modelData.id
                                readonly property string seq: theme.shortcutFor(modelData.id)
                                text: isCapturing ? qsTr("Press keys…") : seq
                                variant: isCapturing ? "filled" : "tonal"
                                onClicked: {
                                    root.capturingId = isCapturing ? "" : modelData.id;
                                    if (root.capturingId.length > 0)
                                        keyCapture.forceActiveFocus();
                                }
                            }

                            LoafButton {
                                visible: theme.keybindings && theme.keybindings[modelData.id] !== undefined
                                icon: "arrow-counter-clockwise"
                                variant: "text"
                                onClicked: theme.resetShortcut(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
