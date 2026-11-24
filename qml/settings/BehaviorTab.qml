import QtQuick
import QtQuick.Layouts
import app.loaf

ColumnLayout {
    id: root

    property string searchQuery: ""

    function matches(keywords) {
        if (!searchQuery || searchQuery.trim().length === 0) return true;
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
    readonly property bool matchArchives: matches("open archives zip tar 7z enter extract browse default app")
    readonly property bool matchClickToOpen: matches("click to open single click double click behavior folder file")
    readonly property bool matchDrag: matches("left click drag action selection box pan scroll view rubberband marquee mouse")
    readonly property bool matchScrollStrength: matches("scroll scrolling speed strength wheel touchpad mouse sensitivity")
    readonly property bool matchHidden: matches("show hidden files dot dotfiles folders")
    readonly property bool matchDisambig: matches("disambiguate duplicate names parent folder prefix search")
    readonly property bool matchRename: matches("click rename inline single click")
    readonly property bool matchSearch: matches("search file contents text inside")
    readonly property bool matchSession: matches("session restore tabs remember last folder window startup launch")
    readonly property bool matchDefaultApps: matches("default apps applications folders directories text txt plain text png images image file type mime formats terminal emulator kitty ghostty foot alacritty wezterm konsole")

    readonly property int matchCount: (searchQuery && searchQuery.trim().length > 0)
        ? ((matchOpenDirs ? 1 : 0) + (matchArchives ? 1 : 0) + (matchClickToOpen ? 1 : 0) + (matchDrag ? 1 : 0) + (matchScrollStrength ? 1 : 0) + (matchHidden ? 1 : 0)
            + (matchDisambig ? 1 : 0) + (matchRename ? 1 : 0) + (matchSearch ? 1 : 0) + (matchSession ? 1 : 0)
            + (matchDefaultApps ? 1 : 0))
        : 0

    property var mimeTypeOptions: []
    property var terminalEmulatorOptions: []
    property string selectedTerminalEmulator: ""

    function loadAppOptions(mime) {
        var apps = [];
        try {
            apps = JSON.parse(core.apps_for_mime(mime) || "[]");
        } catch (e) {
            console.warn("Could not load default applications for " + mime + ": " + e);
        }
        var options = [{ value: "", label: qsTr("System default") }];
        var loaf = apps.filter(function(app) { return app.id === "loaf" || app.id.indexOf("loaf.") === 0; });
        var others = apps.filter(function(app) { return loaf.indexOf(app) < 0; });
        return options.concat(loaf.concat(others).map(function(app) {
            return { value: app.id, label: app.name, iconUrl: app.icon };
        }));
    }

    function loadDefaultAppSettings() {
        if (typeof core === "undefined" || !core)
            return;
        loadTerminalEmulatorSettings();
        try {
            var types = JSON.parse(core.used_mime_types() || "[]");
            mimeTypeOptions = types.map(function(type) {
                return { mime: type.mime, label: type.label, icon: type.icon || "file", archive: !!type.archive };
            });
        } catch (e) {
            console.warn("Could not load supported file types: " + e);
            mimeTypeOptions = [];
        }
    }

    function loadTerminalEmulatorSettings() {
        var options = [{ value: "", label: qsTr("System default") }];
        try {
            var installed = JSON.parse(core.available_terminal_options_json() || "[]");
            options = options.concat(installed);
        } catch (e) {
            console.warn("Could not load installed terminal emulators: " + e);
        }
        selectedTerminalEmulator = core.get_setting("preferredTerminal");
        if (selectedTerminalEmulator.length > 0
                && !options.some(function(option) { return option.value === selectedTerminalEmulator; })) {
            options.push({
                value: selectedTerminalEmulator,
                label: qsTr("%1 (not installed)").arg(selectedTerminalEmulator)
            });
        }
        terminalEmulatorOptions = options;
    }

    function saveTerminalEmulator(name) {
        core.set_setting("preferredTerminal", name);
        selectedTerminalEmulator = name;
    }

    onVisibleChanged: if (visible) loadDefaultAppSettings()
    Component.onCompleted: loadDefaultAppSettings()

    Layout.fillWidth: true
    spacing: 16

    // Category 1: Browsing & Navigation
    SettingCard {
        visible: root.matchOpenDirs || root.matchArchives || root.matchClickToOpen || root.matchDrag || root.matchScrollStrength || root.matchHidden || root.matchDisambig
        title: qsTr("Browsing & Navigation")
        subtitle: qsTr("Folder opening mode, drag actions, and file visibility")
        icon: "folder-notch-open"

        SettingRow {
            visible: root.matchOpenDirs
            icon: "folder-open"
            title: qsTr("Open folders in")
            subtitle: qsTr("Where newly clicked directories should navigate")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
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

        SettingDivider { visible: root.matchOpenDirs && (root.matchArchives || root.matchClickToOpen || root.matchDrag || root.matchHidden || root.matchDisambig) }

        SettingRow {
            visible: root.matchClickToOpen
            icon: "cursor-click"
            title: qsTr("Click to open")
            subtitle: qsTr("Choose whether a single click or a double click opens files and folders")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
                options: [
                    { value: "double", label: qsTr("Double-click"), shortLabel: qsTr("Double"), icon: "cursor-click" },
                    { value: "single", label: qsTr("Single-click"), shortLabel: qsTr("Single"), icon: "cursor" }
                ]
                value: theme.clickToOpen
                onSelected: function(v) { theme.clickToOpen = v; }
            }
        }

        SettingDivider { visible: (root.matchOpenDirs || root.matchClickToOpen) && (root.matchArchives || root.matchDrag || root.matchHidden || root.matchDisambig) }

        SettingRow {
            visible: root.matchArchives
            icon: "archive"
            title: qsTr("Open archives on Enter")
            subtitle: qsTr("Choose whether pressing Enter or double-clicking an archive browses, extracts, or opens it")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 140 : 280
                options: [
                    { value: "browse", label: qsTr("Browse"), icon: "folder-open", shortLabel: "Browse" },
                    { value: "extract", label: qsTr("Extract"), icon: "archive", shortLabel: "Extract" },
                    { value: "open", label: qsTr("Default App"), icon: "arrow-square-out", shortLabel: "App" }
                ]
                value: theme.archiveOpenAction
                onSelected: function(v) { theme.archiveOpenAction = v; }
            }
        }

        SettingDivider { visible: (root.matchOpenDirs || root.matchClickToOpen || root.matchArchives) && (root.matchDrag || root.matchScrollStrength || root.matchHidden || root.matchDisambig) }

        SettingRow {
            visible: root.matchDrag
            icon: "cursor-click"
            title: qsTr("Left-click drag action")
            subtitle: qsTr("Choose whether dragging on empty space creates a selection box or pans the view")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
                options: [
                    { value: "select", label: qsTr("Selection Box"), icon: "bounding-box" },
                    { value: "scroll", label: qsTr("Pan View"), icon: "hand-grabbing" }
                ]
                value: theme.dragAction
                onSelected: function(v) { theme.dragAction = v; }
            }
        }

        SettingDivider { visible: root.matchDrag && (root.matchScrollStrength || root.matchHidden || root.matchDisambig) }

        SettingRow {
            visible: root.matchScrollStrength
            icon: "sliders-horizontal"
            title: qsTr("Scroll strength")
            subtitle: qsTr("Adjust wheel and touchpad scrolling sensitivity (33% is original speed)")

            LoafSlider {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 260
                from: 1
                to: 100
                stepSize: 1
                value: theme.scrollStrength
                formatPercent: false
                unit: "%"
                accessibleName: qsTr("Scroll strength")
                onMoved: function(v) { theme.scrollStrength = Math.round(v); }
            }
        }

        SettingDivider { visible: (root.matchDrag || root.matchScrollStrength) && (root.matchHidden || root.matchDisambig) }

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

    SettingCard {
        visible: root.matchDefaultApps
        title: qsTr("Default Applications")
        subtitle: qsTr("Choose a terminal emulator and file type applications")
        icon: "app-window"

        SettingRow {
            icon: "terminal"
            title: qsTr("Terminal emulator")
            subtitle: qsTr("Used by Open in Terminal; System default follows your desktop settings")

            LoafSelect {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 180 : 320
                options: root.terminalEmulatorOptions
                value: root.selectedTerminalEmulator
                placeholder: qsTr("System default")
                onSelected: function(name) { root.saveTerminalEmulator(name); }
            }
        }

        Repeater {
            model: root.mimeTypeOptions

            SettingRow {
                id: mimeRow
                required property var modelData
                property var appOptions: root.loadAppOptions(modelData.mime)
                property string userApp: core.user_default_app_for_mime(modelData.mime)
                readonly property string currentApp: userApp

                // Archive rows only matter when "Opening archives" hands
                // them to an app; Browse and Extract stay inside Loaf.
                visible: !modelData.archive || theme.archiveOpenAction === "open"

                function choose(id) {
                    var mime = modelData.mime;
                    if (id === "") {
                        if (core.clear_default_mime_app(mime))
                            userApp = "";
                    } else if (core.set_default_mime_app(mime, id)) {
                        userApp = core.user_default_app_for_mime(mime);
                    }
                }

                icon: modelData.icon
                title: modelData.label
                subtitle: modelData.mime

                LoafSelect {
                    Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 180 : 320
                    options: mimeRow.appOptions
                    value: mimeRow.currentApp
                    placeholder: qsTr("System default")
                    onSelected: function(id) { mimeRow.choose(id); }
                }
            }
        }

        SettingRow {
            icon: "info"
            title: qsTr("Other file types")
            subtitle: qsTr("Less common types show up here once you open one in Loaf")
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
