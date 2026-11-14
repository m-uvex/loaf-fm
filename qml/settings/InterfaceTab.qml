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

    readonly property bool matchTheme: matches("theme appearance light dark auto mode color scheme")
    readonly property bool matchOpacity: matches("background opacity panel backing transparency translucent translucency frosted blur appearance")
    readonly property bool matchPalette: matches("theme palette accent colors wallpaper catppuccin nord tokyonight gruvbox rosepine amber lavender violet ricing")
    readonly property bool matchIconStyle: matches("icon style vector phosphor system adwaita desktop theme custom installed papirus breeze")
    readonly property bool matchIconWeight: matches("phosphor weight variant thin light regular bold fill duotone stroke thickness")
    readonly property bool matchIconColor: matches("icon color colour tint colorize colorise accent monochrome folders files all none hue saturation")
    readonly property bool matchOutlines: matches("outline outlines border borders edge edges chrome intensity thickness stroke strength")
    readonly property bool matchTopBar: matches("top bar toolbar operations undo redo new tab new window path bar chips text breadcrumb")
    readonly property bool matchThisPc: matches("this pc computer hostname name label device system")
    readonly property bool matchMenus: matches("menus context menu right click sidebar customize places navigation layout minimal")

    readonly property int matchCount: (searchQuery && searchQuery.trim().length > 0)
        ? ((matchTheme ? 1 : 0) + (matchOpacity ? 1 : 0) + (matchOutlines ? 1 : 0) + (matchPalette ? 1 : 0)
            + (matchIconStyle ? 1 : 0) + (matchIconWeight ? 1 : 0) + (matchIconColor ? 1 : 0) + (matchTopBar ? 1 : 0)
            + (matchThisPc ? 1 : 0) + (matchMenus ? 1 : 0))
        : 0

    Layout.fillWidth: true
    spacing: 16

    // Category 1: Appearance
    SettingCard {
        visible: root.matchTheme || root.matchOpacity || root.matchOutlines
        title: qsTr("Appearance")
        subtitle: qsTr("Window colors, translucency and chrome outlines")
        icon: "palette"

        SettingRow {
            visible: root.matchTheme
            icon: "circle-half"
            title: qsTr("Color scheme")
            subtitle: qsTr("Follow system preferences, or force dark or light theme")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
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
                : (theme.backgroundOpacity < 0.999 && !nativeBridge.alphaBuffer
                    ? qsTr("Restart Loaf to apply transparency")
                    : qsTr("Fades the window itself so the desktop shows through margins and gaps"))

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

        SettingDivider { visible: root.matchOutlines }

        SettingRow {
            visible: root.matchOutlines
            icon: "frame-corners"
            title: qsTr("Outlines")
            subtitle: qsTr("Draw borders around floating pills, cards and inputs. Intensity controls how strong they read")

            LoafSwitch {
                checked: theme.showOutlines
                onToggled: function(c) { theme.showOutlines = c; }
            }
        }

        SettingDivider { visible: root.matchOutlines && theme.showOutlines }

        SettingRow {
            visible: root.matchOutlines && theme.showOutlines
            icon: "squares-four"
            title: qsTr("Outline intensity")
            subtitle: qsTr("How visible the outline borders are, from faint to strong")

            LoafSlider {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 260
                from: 10.0
                to: 100.0
                stepSize: 5
                value: theme.outlineIntensity
                enabled: theme.showOutlines
                accessibleName: qsTr("Outline intensity")
                onMoved: function(v) { theme.outlineIntensity = v; }
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
                        border.color: isSelected ? theme.primary : theme.outlineAlpha(theme.outlineVariant)

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
                                border.color: theme.outlineAlpha(theme.outlineVariant)
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

        SettingRow {
            visible: theme.accentName === "wallpaper"
                && theme.availableWallpaperPaletteSources.length > 0
            icon: "image"
            title: qsTr("Wallpaper palette source")
            subtitle: qsTr("Read generated palette JSON or KDE accent colors on startup")

            LoafSelect {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact)
                    ? 180
                    : 260
                accessibleName: qsTr("Wallpaper palette source")
                options: [
                    { value: "auto", label: qsTr("Automatic") }
                ].concat(theme.availableWallpaperPaletteSources.map(function (s) {
                    return { value: s.id, label: s.label };
                }))
                value: theme.wallpaperPaletteSource
                onSelected: function (v) { theme.wallpaperPaletteSource = v; }
            }
        }
    }

    // Category 3: Icons
    SettingCard {
        visible: (theme.showExperimentalIcons && root.matchIconStyle) || (theme.iconSource === "phosphor" && root.matchIconWeight) || root.matchIconColor
        title: qsTr("Icons")
        subtitle: qsTr("Choose icon style, stroke weight, colorize scope and tint color")
        icon: "shapes"

        SettingRow {
            visible: theme.showExperimentalIcons && root.matchIconStyle
            icon: "app-window"
            title: qsTr("Icon set")
            subtitle: qsTr("Phosphor, system desktop theme, GNOME Adwaita, or installed icon theme")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
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

        SettingRow {
            visible: root.matchIconColor
            icon: "drop-half"
            title: qsTr("Colorize icons")
            subtitle: qsTr("Tint all icons, files, folders or none with the icon color")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
                options: [
                    { value: "all", label: qsTr("All"), shortLabel: "All", icon: "shapes" },
                    { value: "none", label: qsTr("None"), shortLabel: "Non", icon: "minus" },
                    { value: "files", label: qsTr("Files"), shortLabel: "Fil", icon: "file" },
                    { value: "folders", label: qsTr("Folders"), shortLabel: "Fld", icon: "folder" }
                ]
                value: theme.iconColorMode
                onSelected: function(v) { theme.iconColorMode = v; }
            }
        }

        SettingDivider { visible: root.matchIconColor && theme.iconColorMode !== "none" }

        // Pick the actual tint swatch; only meaningful when colorizing is on.
        SettingRow {
            visible: root.matchIconColor && theme.iconColorMode !== "none"
            icon: "drop"
            title: qsTr("Icon color")
            subtitle: qsTr("Foreground Material color used for the colorized file-view icons")

            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                Repeater {
                    model: [
                        { value: "primary", label: qsTr("Primary"), color: theme.primary },
                        { value: "secondary", label: qsTr("Secondary"), color: theme.secondaryContainerFg },
                        { value: "tertiary", label: qsTr("Tertiary"), color: theme.tertiaryContainer },
                        { value: "danger", label: qsTr("Error"), color: theme.danger },
                        { value: "textMain", label: qsTr("On Surface"), color: theme.textMain },
                        { value: "textMuted", label: qsTr("On Surface Variant"), color: theme.textMuted }
                    ]

                    delegate: Rectangle {
                        id: swatchDot
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: modelData.color
                        border.width: theme.iconColor === modelData.value ? 2 : 1
                        border.color: theme.iconColor === modelData.value ? theme.primary : theme.outlineAlpha(theme.outlineVariant)
                        scale: swatchDotMouse.pressed ? 0.9 : (swatchDotMouse.containsMouse ? 1.12 : 1.0)

                        Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.5; damping: 0.3 } }
                        Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }

                        LoafIcon {
                            anchors.centerIn: parent
                            name: "check"
                            size: 14
                            color: theme.onColor(modelData.color)
                            visible: theme.iconColor === modelData.value
                        }

                        MouseArea {
                            id: swatchDotMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (typeof tooltip !== "undefined") tooltip.show(swatchDotMouse, modelData.label)
                            onExited: if (typeof tooltip !== "undefined") tooltip.hide(swatchDotMouse)
                            onClicked: theme.iconColor = modelData.value
                        }
                    }
                }
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
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
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
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
                options: [
                    { value: "chips", label: qsTr("Breadcrumbs"), icon: "bread", shortLabel: "Chips" },
                    { value: "text", label: qsTr("Text Only"), icon: "text-t", shortLabel: "Text" }
                ]
                value: theme.pathBarMode
                onSelected: function(v) { theme.pathBarMode = v; }
            }
        }
    }

    // Category 5: This PC
    SettingCard {
        visible: root.matchThisPc
        title: qsTr("This PC")
        subtitle: qsTr("Name and identity of the system location")
        icon: "desktop"

        SettingRow {
            icon: "desktop"
            title: qsTr("Display name")
            subtitle: qsTr("Custom label for the This PC page, tab, and sidebar entry. Leave empty to use the hostname (%1)")
                .arg((typeof core !== "undefined" && core && core.hostname.length > 0) ? core.hostname : qsTr("This PC"))

            LoafTextField {
                id: pcNameField
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 180 : 260
                text: (typeof core !== "undefined" && core) ? core.pc_name : ""
                placeholderText: (typeof core !== "undefined" && core && core.hostname.length > 0) ? core.hostname : qsTr("This PC")
                onEditingFinished: if (typeof core !== "undefined" && core && text.trim() !== core.pc_name)
                    core.set_pc_custom_name(text.trim())
                onAccepted: if (typeof core !== "undefined" && core)
                    core.set_pc_custom_name(text.trim())
            }
        }
    }

    // Category 6: Menus & Sidebar
    SettingCard {
        visible: root.matchMenus
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
                    Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 220 : 380
                    options: [
                        { value: "full", label: qsTr("Full"), shortLabel: "Full", icon: "list-bullets" },
                        { value: "minimal", label: qsTr("Minimal"), shortLabel: "Min", icon: "minus" },
                        { value: "custom", label: qsTr("Custom"), shortLabel: "Edit", icon: "pencil-simple" }
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
    }
}
