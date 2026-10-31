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

    readonly property bool matchTheme: matches("theme appearance light dark auto mode color scheme")
    readonly property bool matchOpacity: matches("background opacity panel backing transparency translucent translucency frosted blur appearance")
    readonly property bool matchPalette: matches("theme palette accent colors wallpaper catppuccin nord tokyonight gruvbox rosepine amber lavender violet ricing")
    readonly property bool matchIconStyle: matches("icon style vector phosphor system adwaita desktop theme custom installed papirus breeze")
    readonly property bool matchIconWeight: matches("phosphor weight variant thin light regular bold fill duotone stroke thickness")
    readonly property bool matchTopBar: matches("top bar toolbar operations undo redo new tab new window path bar chips text breadcrumb")
    readonly property bool matchMenus: matches("menus context menu right click sidebar customize places navigation layout minimal")
    readonly property bool matchThisPc: matches("this pc computer name label hostname rename dashboard drive overview")

    readonly property int matchCount: (matchTheme ? 1 : 0) + (matchOpacity ? 1 : 0) + (matchPalette ? 1 : 0)
        + (matchIconStyle ? 1 : 0) + (matchIconWeight ? 1 : 0) + (matchTopBar ? 1 : 0) + (matchMenus ? 1 : 0)
        + (matchThisPc ? 1 : 0)

    Layout.fillWidth: true
    spacing: 16

    // Category 1: Appearance
    SettingCard {
        visible: root.matchTheme || root.matchOpacity
        title: qsTr("Appearance")
        subtitle: qsTr("Window colors and translucency")
        icon: "palette"

        SettingRow {
            visible: root.matchTheme
            icon: "circle-half"
            title: qsTr("Color scheme")
            subtitle: qsTr("Follow system preferences, or force dark or light theme")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 120 : 280
                options: [
                    { value: "auto", label: qsTr("Auto"), icon: "circle-half" },
                    { value: "light", label: qsTr("Light"), icon: "sun" },
                    { value: "dark", label: qsTr("Dark"), icon: "moon" }
                ]
                value: theme.themeMode
                onSelected: function(v) { theme.themeMode = v; }
            }
        }

        SettingDivider { visible: root.matchTheme && root.matchOpacity }

        SettingRow {
            visible: root.matchOpacity
            icon: "drop"
            title: qsTr("Background opacity")
            subtitle: theme.lowPower
                ? qsTr("Disabled in low-power mode")
                : qsTr("Fades the window itself so the desktop shows through margins and gaps")

            LoafSlider {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 260
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: theme.backgroundOpacity
                enabled: !theme.lowPower
                formatPercent: true
                accessibleName: qsTr("Background opacity")
                onMoved: function(v) { theme.backgroundOpacity = v; }
            }
        }

        SettingDivider { visible: root.matchOpacity }

        SettingRow {
            visible: root.matchOpacity
            icon: "square-half"
            title: qsTr("Panel backing opacity")
            subtitle: theme.lowPower
                ? qsTr("Disabled in low-power mode")
                : qsTr("Fades file panes, sidebar and cards while keeping text and icons solid")

            LoafSlider {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 260
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: theme.panelOpacity
                enabled: !theme.lowPower
                formatPercent: true
                accessibleName: qsTr("Panel backing opacity")
                onMoved: function(v) { theme.panelOpacity = v; }
            }
        }
    }

    // Category 2: Color Palette
    SettingCard {
        visible: root.matchPalette
        title: qsTr("Color palette")
        subtitle: qsTr("Wallpaper color extraction or curated Material 3 palettes")
        icon: "paint-brush"

        Flow {
            id: palFlow
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: [
                    { id: "wallpaper", label: qsTr("Wallpaper") },
                    { id: "lavender", label: qsTr("Loaf Violet") },
                    { id: "amber", label: qsTr("Loaf Amber") },
                    { id: "catppuccin", label: qsTr("Catppuccin") },
                    { id: "nord", label: qsTr("Nord") },
                    { id: "tokyonight", label: qsTr("Tokyo Night") },
                    { id: "gruvbox", label: qsTr("Gruvbox") },
                    { id: "rosepine", label: qsTr("Rosé Pine") }
                ]

                delegate: Item {
                    width: (typeof settingsView !== "undefined" && settingsView.isCompact)
                        ? Math.max(120, Math.floor((palFlow.width - 10) / 2))
                        : 142
                    height: 42

                    readonly property var swatch: theme.palettes[modelData.id] ? theme.palettes[modelData.id] : theme.palettes["lavender"]
                    readonly property bool isSelected: theme.accentName === modelData.id

                    Rectangle {
                        anchors.fill: parent
                        radius: theme.radiusM
                        color: isSelected ? theme.primaryContainer : theme.surfaceContainerHigh
                        border.width: isSelected ? 2 : 1
                        border.color: isSelected ? theme.primary : theme.outlineVariant

                        scale: palMouse.pressed ? 0.95 : (palMouse.containsMouse ? 1.02 : 1.0)

                        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                        Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                        Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Rectangle {
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 7
                                color: swatch ? swatch.darkPrimary : theme.primary
                                border.width: 1
                                border.color: theme.outlineVariant
                            }

                            Text {
                                text: modelData.label
                                color: isSelected ? theme.primaryContainerFg : theme.textMain
                                font.pixelSize: theme.fs(11)
                                font.bold: isSelected
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                            }

                            LoafIcon {
                                visible: isSelected
                                name: "check"
                                size: 14
                                color: theme.primaryContainerFg
                            }
                        }
                    }

                    MouseArea {
                        id: palMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: theme.accentName = modelData.id
                    }
                }
            }
        }
    }

    // Category 3: Icons
    SettingCard {
        visible: (theme.showExperimentalIcons && root.matchIconStyle) || (theme.iconSource === "phosphor" && root.matchIconWeight)
        title: qsTr("Icons")
        subtitle: qsTr("Choose icon style and stroke weight")
        icon: "shapes"

        SettingRow {
            visible: theme.showExperimentalIcons && root.matchIconStyle
            icon: "app-window"
            title: qsTr("Icon set")
            subtitle: qsTr("Phosphor, system desktop theme, GNOME Adwaita, or installed icon theme")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 160 : 340
                options: [
                    { value: "phosphor", label: qsTr("Phosphor"), icon: "sparkle" },
                    { value: "system", label: qsTr("System"), icon: "desktop" },
                    { value: "adwaita", label: qsTr("Adwaita"), icon: "app-window" },
                    { value: "custom", label: qsTr("Custom"), icon: "palette" }
                ]
                value: theme.iconSource
                onSelected: function(v) {
                    if (v === "custom" && theme.customIconTheme.length === 0 && typeof core !== "undefined" && core) {
                        theme.customIconTheme = core.icon_theme;
                    }
                    theme.iconSource = v;
                }
            }
        }

        SettingRow {
            visible: theme.showExperimentalIcons && theme.iconSource === "custom" && root.matchIconStyle
            icon: "folder-simple"
            title: qsTr("Icon theme")
            subtitle: qsTr("Any icon theme installed on this system")

            LoafSelect {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 180 : 260
                accessibleName: qsTr("Icon theme")
                options: (theme.iconSource === "custom" && typeof core !== "undefined" && core)
                    ? JSON.parse(core.icon_themes_json() || "[]").map(function (t) {
                        return { value: t.id, label: t.name, iconUrl: core.resolve_icon(t.id, "folder") };
                    })
                    : []
                value: theme.customIconTheme
                onSelected: function (v) { theme.customIconTheme = v; }
            }
        }

        SettingDivider { visible: theme.showExperimentalIcons && root.matchIconStyle && theme.iconSource === "phosphor" && root.matchIconWeight }

        // Icon weight only shows when Phosphor is active (system icons do not have variable weight)
        SettingRow {
            visible: theme.iconSource === "phosphor" && root.matchIconWeight
            icon: "text-b"
            title: qsTr("Icon weight")
            subtitle: qsTr("Stroke thickness and styling variant for Phosphor icons")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
                options: [
                    { value: "thin", label: qsTr("Thin"), shortLabel: "Th" },
                    { value: "light", label: qsTr("Light"), shortLabel: "Lt" },
                    { value: "regular", label: qsTr("Regular"), shortLabel: "Reg" },
                    { value: "bold", label: qsTr("Bold"), shortLabel: "Bd" },
                    { value: "fill", label: qsTr("Fill"), shortLabel: "Fil" },
                    { value: "duotone", label: qsTr("Duotone"), shortLabel: "Duo" }
                ]
                value: theme.phosphorWeight
                onSelected: function(v) { theme.phosphorWeight = v; }
            }
        }
    }

    // Category 4: Top Bar & Navigation
    SettingCard {
        visible: root.matchTopBar
        title: qsTr("Top Bar & Navigation")
        subtitle: qsTr("Toolbar actions, path display, and tab controls")
        icon: "browser"

        SettingRow {
            icon: "arrow-u-up-left"
            title: qsTr("Back and forward buttons")
            subtitle: qsTr("Show both navigation arrows, only Forward when available, or hide them")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 140 : 280
                options: [
                    { value: "auto", label: qsTr("Automatic"), icon: "arrows-clockwise", shortLabel: "Auto" },
                    { value: "always", label: qsTr("Always"), icon: "arrow-left", shortLabel: "Show" },
                    { value: "hidden", label: qsTr("Hidden"), icon: "eye-slash", shortLabel: "Hide" }
                ]
                value: theme.toolbarOperations
                onSelected: function(v) { theme.toolbarOperations = v; }
            }
        }

        SettingDivider {}

        SettingRow {
            icon: "tabs"
            title: qsTr("New tab button")
            subtitle: qsTr("Show the quick New Tab action on the top bar (Ctrl+T)")

            LoafSwitch {
                checked: theme.showNewTabButton
                onToggled: function(c) { theme.showNewTabButton = c; }
            }
        }

        SettingDivider {}

        SettingRow {
            icon: "app-window"
            title: qsTr("New window button")
            subtitle: qsTr("Show the quick New Window action on the top bar (Ctrl+N)")

            LoafSwitch {
                checked: theme.showNewWindowButton
                onToggled: function(c) { theme.showNewWindowButton = c; }
            }
        }

        SettingDivider {}

        SettingRow {
            icon: "bread"
            title: qsTr("Path bar display")
            subtitle: qsTr("Choose between clickable breadcrumb chips or raw editable path text")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 140 : 260
                options: [
                    { value: "chips", label: qsTr("Breadcrumbs"), icon: "bread", shortLabel: "Chips" },
                    { value: "text", label: qsTr("Text Only"), icon: "text-t", shortLabel: "Text" }
                ]
                value: theme.pathBarMode
                onSelected: function(v) { theme.pathBarMode = v; }
            }
        }
    }

    // Category 5: Menus & Sidebar
    SettingCard {
        visible: root.matchMenus || root.matchThisPc
        title: qsTr("Menus & Sidebar")
        subtitle: qsTr("Context menus and left sidebar rail pins")
        icon: "sliders"

        SettingRow {
            icon: "list-bullets"
            title: qsTr("Context menu layout")
            subtitle: qsTr("Minimal hides common shortcuts like cut, copy, and delete to keep menus compact")

            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                LoafSegmented {
                    Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 140 : 260
                    options: [
                        { value: "full", label: qsTr("Full"), shortLabel: "Full" },
                        { value: "minimal", label: qsTr("Minimal"), shortLabel: "Min" },
                        { value: "custom", label: qsTr("Custom"), shortLabel: "Edit" }
                    ]
                    value: theme.contextMenuMode
                    onSelected: function(v) {
                        theme.contextMenuMode = v;
                        if (v === "custom" && typeof customizeContextMenuDialog !== "undefined") {
                            customizeContextMenuDialog.open();
                        }
                    }
                }

                LoafButton {
                    visible: theme.contextMenuMode === "custom"
                    text: qsTr("Edit…")
                    icon: "sliders"
                    variant: "tonal"
                    onClicked: if (typeof customizeContextMenuDialog !== "undefined") customizeContextMenuDialog.open()
                }
            }
        }

        SettingDivider {}

        SettingRow {
            icon: "sidebar-simple"
            title: qsTr("Navigation sidebar")
            subtitle: qsTr("Reorder, pin, or hide drives, standard locations, and custom bookmarks")

            LoafButton {
                text: qsTr("Customize Sidebar…")
                icon: "sliders-horizontal"
                variant: "tonal"
                onClicked: if (typeof customizePlaces !== "undefined") customizePlaces.open()
            }
        }

        SettingDivider { visible: root.matchThisPc }

        SettingRow {
            visible: root.matchThisPc
            icon: "desktop"
            title: qsTr("This PC name")
            subtitle: qsTr("Shown in the sidebar, tabs, and window title; leave empty to use the hostname")

            LoafTextField {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 140 : 220
                placeholderText: typeof core !== "undefined" && core && core.hostname ? core.hostname : qsTr("Hostname")
                text: typeof core !== "undefined" && core ? core.pc_label : ""
                selectByMouse: true
                onEditingFinished: core.set_pc_name(text)
            }
        }
    }
}
