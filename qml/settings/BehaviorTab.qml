import QtQuick
import QtQuick.Layouts
import app.loaf

ColumnLayout {
    id: root

    property string searchQuery: ""

    function matches(keywords) {
        if (!searchQuery || searchQuery.length === 0) return true;
        var q = searchQuery.toLowerCase().trim();
        var parts = q.split(/\s+/);
        var kw = keywords.toLowerCase();
        for (var i = 0; i < parts.length; ++i) {
            if (parts[i].length > 0 && kw.indexOf(parts[i]) === -1) {
                return false;
            }
        }
        return true;
    }

    readonly property bool matchOpenDirs: matches("open folders directories navigation split view new tab current view")
    readonly property bool matchDrag: matches("left click drag action selection box pan scroll view rubberband marquee mouse")
    readonly property bool matchHidden: matches("show hidden files dot dotfiles folders")
    readonly property bool matchDisambig: matches("disambiguate duplicate names parent folder prefix search")
    readonly property bool matchRename: matches("click rename inline single click")
    readonly property bool matchSearch: matches("search file contents text inside")
    readonly property bool matchSession: matches("session restore tabs remember last folder window startup launch")

    readonly property int matchCount: (matchOpenDirs ? 1 : 0) + (matchDrag ? 1 : 0) + (matchHidden ? 1 : 0)
        + (matchDisambig ? 1 : 0) + (matchRename ? 1 : 0) + (matchSearch ? 1 : 0) + (matchSession ? 1 : 0)

    Layout.fillWidth: true
    spacing: 16

    // Category 1: Browsing & Navigation
    SettingCard {
        visible: root.matchOpenDirs || root.matchDrag || root.matchHidden || root.matchDisambig
        title: qsTr("Browsing & Navigation")
        subtitle: qsTr("Folder opening mode, drag actions, and file visibility")
        icon: "folder-notch-open"

        SettingRow {
            visible: root.matchOpenDirs
            icon: "folder-open"
            title: qsTr("Open folders in")
            subtitle: qsTr("Where newly clicked directories should navigate")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 140 : 280
                options: [
                    { value: "current", label: qsTr("Current"), icon: "folder", shortLabel: qsTr("Current") },
                    { value: "split", label: qsTr("Split"), icon: "columns", shortLabel: qsTr("Split") },
                    //: Short label for New Tab in folder opening segment control. Must stay short.
                    { value: "tab", label: qsTr("New Tab"), icon: "plus-square", shortLabel: qsTr("Tab") }
                ]
                value: theme.openFolderMode
                onSelected: function(v) { theme.openFolderMode = v; }
            }
        }

        SettingDivider { visible: root.matchOpenDirs && (root.matchDrag || root.matchHidden || root.matchDisambig) }

        SettingRow {
            visible: root.matchDrag
            icon: "cursor-click"
            title: qsTr("Left-click drag action")
            subtitle: qsTr("Choose whether dragging on empty space creates a selection box or pans the view")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 90 : 260
                options: [
                    { value: "select", label: qsTr("Selection Box"), icon: "bounding-box" },
                    { value: "scroll", label: qsTr("Pan View"), icon: "hand-grabbing" }
                ]
                value: theme.dragAction
                onSelected: function(v) { theme.dragAction = v; }
            }
        }

        SettingDivider { visible: root.matchDrag && (root.matchHidden || root.matchDisambig) }

        SettingRow {
            visible: root.matchHidden
            icon: "eye"
            title: qsTr("Show hidden files")
            subtitle: qsTr("Display files and folders prefixed with a dot (Ctrl+H)")

            LoafSwitch {
                id: hiddenSwitch
                checked: typeof window !== "undefined" ? window.showHidden : false
                onToggled: if (typeof window !== "undefined") window.toggleShowHidden()
            }
        }

        SettingDivider { visible: root.matchHidden && root.matchDisambig }

        SettingRow {
            visible: root.matchDisambig
            icon: "text-t"
            title: qsTr("Disambiguate duplicate names")
            subtitle: qsTr("Display parent directory prefixes for search results with identical names")

            LoafSwitch {
                id: disambigSwitch
                checked: typeof core !== "undefined" && core ? core.get_setting("disambiguate_duplicates") !== "false" : true
                onToggled: if (typeof core !== "undefined" && core) core.set_setting("disambiguate_duplicates", checked ? "true" : "false")
            }
        }
    }

    // Category 2: File Operations
    SettingCard {
        visible: root.matchRename || root.matchSearch
        title: qsTr("File Operations")
        subtitle: qsTr("Inline rename triggers and content search")
        icon: "gear-six"

        SettingRow {
            visible: root.matchRename
            icon: "pencil-simple-line"
            title: qsTr("Click selected item to rename")
            subtitle: qsTr("Clicking an already selected item triggers inline renaming (F2 always renames)")

            LoafSwitch {
                checked: theme.clickToRename
                onToggled: function(c) { theme.clickToRename = c; }
            }
        }

        SettingDivider { visible: root.matchRename && root.matchSearch }

        SettingRow {
            visible: root.matchSearch
            icon: "file-text"
            title: qsTr("Search inside file contents")
            subtitle: qsTr("Match text inside text and code files in subfolder searches (indexed, slightly slower)")

            LoafSwitch {
                checked: theme.searchContents
                onToggled: function(c) { theme.searchContents = c; }
            }
        }
    }

    // Category 3: Session
    SettingCard {
        visible: root.matchSession
        title: qsTr("Session")
        subtitle: qsTr("Window state and startup restoration")
        icon: "clock-counter-clockwise"

        SettingRow {
            icon: "clock-counter-clockwise"
            title: qsTr("Restore session on launch")
            subtitle: qsTr("Automatically reopen tabs, visited folders, and split panes on startup")

            LoafSwitch {
                checked: typeof core !== "undefined" && core ? core.get_setting("restoreSession") !== "false" : true
                onToggled: if (typeof core !== "undefined" && core) core.set_setting("restoreSession", checked ? "true" : "false")
            }
        }
    }

    Connections {
        target: typeof engine !== "undefined" ? engine : null
        function onShow_hiddenChanged() {
            if (typeof window !== "undefined" && hiddenSwitch.checked !== window.showHidden)
                hiddenSwitch.checked = window.showHidden
        }
    }
}
