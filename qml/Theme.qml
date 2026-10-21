import QtQuick

Item {
    id: theme
    visible: false

    property string themeMode: "auto" // "auto", "light", "dark"
    property string accentName: "wallpaper" // "wallpaper", "lavender", "amber", "catppuccin", "nord", "tokyonight", "gruvbox", "rosepine"
    property string iconSource: "phosphor" // "phosphor" or "system"
    property string phosphorWeight: "regular" // "regular", "bold", "fill", "duotone", "light", "thin"
    property string dragAction: "select" // "select" (selection box) or "scroll" (pan view)
    property bool showThumbnails: true
    property bool showBrandBadge: true
    property bool showExperimentalIcons: false
    property bool showAdvancedArchives: false
    property bool experimentalPcCustomization: false
    property int gridZoomLevel: 2 // 0: Tiny (70%) .. 2: Normal (100%) .. 12: Huge (800%)
    property int listZoomLevel: 2

    FontLoader { id: fontReg; source: "qrc:/loaf/fonts/Phosphor.ttf" }
    FontLoader { id: fontBold; source: "qrc:/loaf/fonts/Phosphor-Bold.ttf" }
    FontLoader { id: fontFill; source: "qrc:/loaf/fonts/Phosphor-Fill.ttf" }
    FontLoader { id: fontDuotone; source: "qrc:/loaf/fonts/Phosphor-Duotone.ttf" }
    FontLoader { id: fontLight; source: "qrc:/loaf/fonts/Phosphor-Light.ttf" }
    FontLoader { id: fontThin; source: "qrc:/loaf/fonts/Phosphor-Thin.ttf" }

    function getFontFamily() {
        switch (phosphorWeight) {
            case "bold": return (fontBold && fontBold.name) ? fontBold.name : "Phosphor-Bold";
            case "fill": return (fontFill && fontFill.name) ? fontFill.name : "Phosphor-Fill";
            case "duotone": return (fontDuotone && fontDuotone.name) ? fontDuotone.name : "Phosphor-Duotone";
            case "light": return (fontLight && fontLight.name) ? fontLight.name : "Phosphor-Light";
            case "thin": return (fontThin && fontThin.name) ? fontThin.name : "Phosphor-Thin";
            default: return (fontReg && fontReg.name) ? fontReg.name : "Phosphor";
        }
    }

    property bool isDark: {
        if (themeMode === "dark") return true;
        if (themeMode === "light") return false;
        if (typeof engine !== "undefined" && engine && typeof engine.is_dark === "boolean") {
            return engine.is_dark;
        }
        if (Application.styleHints && Application.styleHints.colorScheme === Qt.Light) return false;
        return true;
    }

    readonly property var wallpaperData: {
        try {
            return JSON.parse(engine ? engine.wallpaper_colors_json : "{}")
        } catch (e) {
            return {}
        }
    }

    readonly property var palettes: ({
        "wallpaper": {
            darkBg: (wallpaperData && wallpaperData.background) ? wallpaperData.background : "#121214",
            darkSurfaceLowest: (wallpaperData && wallpaperData.surface_container_lowest) ? wallpaperData.surface_container_lowest : "#0d0e0f",
            darkSurfaceLow: (wallpaperData && wallpaperData.surface_container_low) ? wallpaperData.surface_container_low : "#18191a",
            darkSurface: (wallpaperData && wallpaperData.surface_container) ? wallpaperData.surface_container : "#1e2021",
            darkSurfaceHigh: (wallpaperData && wallpaperData.surface_container_high) ? wallpaperData.surface_container_high : "#282a2b",
            darkSurfaceHighest: (wallpaperData && wallpaperData.surface_container_highest) ? wallpaperData.surface_container_highest : "#333537",
            darkPrimary: (wallpaperData && wallpaperData.primary) ? wallpaperData.primary : "#cfc6ab",
            darkFg: (wallpaperData && wallpaperData.on_primary) ? wallpaperData.on_primary : "#201b0a",
            darkContainer: (wallpaperData && wallpaperData.primary_container) ? wallpaperData.primary_container : "#4c4732",
            darkContainerFg: (wallpaperData && wallpaperData.on_primary_container) ? wallpaperData.on_primary_container : "#ece2c6",
            darkSecondaryContainer: (wallpaperData && wallpaperData.secondary_container) ? wallpaperData.secondary_container : "#454336",
            darkSecondaryContainerFg: (wallpaperData && wallpaperData.on_secondary_container) ? wallpaperData.on_secondary_container : "#ece2c6",
            darkTertiaryContainer: (wallpaperData && wallpaperData.tertiary_container) ? wallpaperData.tertiary_container : "#524332",
            darkTextMain: (wallpaperData && wallpaperData.on_surface) ? wallpaperData.on_surface : "#e4e2de",
            darkTextMuted: (wallpaperData && wallpaperData.on_surface_variant) ? wallpaperData.on_surface_variant : "#c8c6c0",
            darkOutline: (wallpaperData && wallpaperData.outline) ? wallpaperData.outline : "#92908a",
            darkOutlineVariant: (wallpaperData && wallpaperData.outline_variant) ? wallpaperData.outline_variant : "#484742",

            lightBg: "#fef8f4",
            lightSurfaceLowest: "#ffffff",
            lightSurfaceLow: "#f9f2ec",
            lightSurface: "#f3ece4",
            lightSurfaceHigh: "#ede5dc",
            lightSurfaceHighest: "#e7ded4",
            lightPrimary: (wallpaperData && wallpaperData.primary) ? wallpaperData.primary : "#655e48",
            lightFg: "#ffffff",
            lightContainer: (wallpaperData && wallpaperData.primary_container) ? wallpaperData.primary_container : "#ece2c6",
            lightContainerFg: (wallpaperData && wallpaperData.on_primary_container) ? wallpaperData.on_primary_container : "#201b0a",
            lightSecondaryContainer: (wallpaperData && wallpaperData.secondary_container) ? wallpaperData.secondary_container : "#ece2c6",
            lightSecondaryContainerFg: (wallpaperData && wallpaperData.on_secondary_container) ? wallpaperData.on_secondary_container : "#201b0a",
            lightTertiaryContainer: (wallpaperData && wallpaperData.tertiary_container) ? wallpaperData.tertiary_container : "#f0ddd0",
            lightTextMain: "#1d1c16",
            lightTextMuted: "#494740",
            lightOutline: "#7a7770",
            lightOutlineVariant: "#cbc7be"
        },
        "lavender": {
            darkBg: "#121214",
            darkSurfaceLowest: "#0d0e0f",
            darkSurfaceLow: "#18181b",
            darkSurface: "#1f1f23",
            darkSurfaceHigh: "#29292f",
            darkSurfaceHighest: "#35343c",
            darkPrimary: "#d0bcff",
            darkFg: "#381e72",
            darkContainer: "#4f378b",
            darkContainerFg: "#eaddff",
            darkSecondaryContainer: "#4a4458",
            darkSecondaryContainerFg: "#eaddff",
            darkTertiaryContainer: "#633b48",
            darkTextMain: "#e6e6e8",
            darkTextMuted: "#cac4d0",
            darkOutline: "#938f99",
            darkOutlineVariant: "#49454f",

            lightBg: "#faf8fc",
            lightSurfaceLowest: "#ffffff",
            lightSurfaceLow: "#f4eef7",
            lightSurface: "#eee8f1",
            lightSurfaceHigh: "#e8e2eb",
            lightSurfaceHighest: "#e2dce5",
            lightPrimary: "#65558f",
            lightFg: "#ffffff",
            lightContainer: "#eaddff",
            lightContainerFg: "#210f47",
            lightSecondaryContainer: "#e8def8",
            lightSecondaryContainerFg: "#210f47",
            lightTertiaryContainer: "#ffd8e4",
            lightTextMain: "#1d1b20",
            lightTextMuted: "#79747e",
            lightOutline: "#79747e",
            lightOutlineVariant: "#cac4d0"
        },
        "amber": {
            darkBg: "#131315",
            darkSurfaceLowest: "#0d0e0f",
            darkSurfaceLow: "#19181a",
            darkSurface: "#212023",
            darkSurfaceHigh: "#2c2a2f",
            darkSurfaceHighest: "#38363c",
            darkPrimary: "#f5bd6d",
            darkFg: "#432c00",
            darkContainer: "#5e4100",
            darkContainerFg: "#ffdea7",
            darkSecondaryContainer: "#423420",
            darkSecondaryContainerFg: "#ffdea7",
            darkTertiaryContainer: "#593a20",
            darkTextMain: "#f2ede8",
            darkTextMuted: "#c8beaf",
            darkOutline: "#8f8576",
            darkOutlineVariant: "#443f38",

            lightBg: "#fdf8f4",
            lightSurfaceLowest: "#ffffff",
            lightSurfaceLow: "#f7efe7",
            lightSurface: "#ede4db",
            lightSurfaceHigh: "#e2d8cd",
            lightSurfaceHighest: "#d6cbc0",
            lightPrimary: "#825500",
            lightFg: "#ffffff",
            lightContainer: "#ffdea7",
            lightContainerFg: "#2a1800",
            lightSecondaryContainer: "#fae7cb",
            lightSecondaryContainerFg: "#432c00",
            lightTertiaryContainer: "#ffdcc1",
            lightTextMain: "#221b14",
            lightTextMuted: "#6b6256",
            lightOutline: "#867b6e",
            lightOutlineVariant: "#d4c8ba"
        },
        "catppuccin": {
            darkBg: "#1e1e2e",
            darkSurfaceLowest: "#11111b",
            darkSurfaceLow: "#181825",
            darkSurface: "#24273a",
            darkSurfaceHigh: "#313244",
            darkSurfaceHighest: "#45475a",
            darkPrimary: "#cba6f7",
            darkFg: "#11111b",
            darkContainer: "#45475a",
            darkContainerFg: "#cdd6f4",
            darkSecondaryContainer: "#36384d",
            darkSecondaryContainerFg: "#89b4fa",
            darkTertiaryContainer: "#5e3f53",
            darkTextMain: "#cdd6f4",
            darkTextMuted: "#a6adc8",
            darkOutline: "#7f849c",
            darkOutlineVariant: "#313244",

            lightBg: "#eff1f5",
            lightSurfaceLowest: "#ffffff",
            lightSurfaceLow: "#e6e9ef",
            lightSurface: "#dce0e8",
            lightSurfaceHigh: "#ccd0da",
            lightSurfaceHighest: "#bcc0cc",
            lightPrimary: "#8839ef",
            lightFg: "#ffffff",
            lightContainer: "#dce0e8",
            lightContainerFg: "#8839ef",
            lightSecondaryContainer: "#d2d7e6",
            lightSecondaryContainerFg: "#1e66f5",
            lightTertiaryContainer: "#f4ccd4",
            lightTextMain: "#4c4f69",
            lightTextMuted: "#6c6f85",
            lightOutline: "#9ca0b0",
            lightOutlineVariant: "#ccd0da"
        },
        "nord": {
            darkBg: "#2e3440",
            darkSurfaceLowest: "#1e222a",
            darkSurfaceLow: "#242933",
            darkSurface: "#353c4a",
            darkSurfaceHigh: "#3b4252",
            darkSurfaceHighest: "#434c5e",
            darkPrimary: "#88c0d0",
            darkFg: "#2e3440",
            darkContainer: "#434c5e",
            darkContainerFg: "#eceff4",
            darkSecondaryContainer: "#3d4757",
            darkSecondaryContainerFg: "#88c0d0",
            darkTertiaryContainer: "#533a41",
            darkTextMain: "#eceff4",
            darkTextMuted: "#d8dee9",
            darkOutline: "#4c566a",
            darkOutlineVariant: "#3b4252",

            lightBg: "#eceff4",
            lightSurfaceLowest: "#ffffff",
            lightSurfaceLow: "#e5e9f0",
            lightSurface: "#d8dee9",
            lightSurfaceHigh: "#cbd3df",
            lightSurfaceHighest: "#bcc6d5",
            lightPrimary: "#5e81ac",
            lightFg: "#ffffff",
            lightContainer: "#d8dee9",
            lightContainerFg: "#2e3440",
            lightSecondaryContainer: "#d8e1eb",
            lightSecondaryContainerFg: "#3b5b84",
            lightTertiaryContainer: "#edd1ce",
            lightTextMain: "#2e3440",
            lightTextMuted: "#4c566a",
            lightOutline: "#7d899e",
            lightOutlineVariant: "#d8dee9"
        },
        "tokyonight": {
            darkBg: "#1a1b26",
            darkSurfaceLowest: "#13141c",
            darkSurfaceLow: "#16161e",
            darkSurface: "#1f2335",
            darkSurfaceHigh: "#24283b",
            darkSurfaceHighest: "#292e42",
            darkPrimary: "#7aa2f7",
            darkFg: "#15161e",
            darkContainer: "#292e42",
            darkContainerFg: "#c0caf5",
            darkSecondaryContainer: "#28334d",
            darkSecondaryContainerFg: "#7dcfff",
            darkTertiaryContainer: "#522e3e",
            darkTextMain: "#c0caf5",
            darkTextMuted: "#9aa5ce",
            darkOutline: "#565f89",
            darkOutlineVariant: "#24283b",

            lightBg: "#d5d6db",
            lightSurfaceLowest: "#ffffff",
            lightSurfaceLow: "#cbccd1",
            lightSurface: "#c4c8da",
            lightSurfaceHigh: "#b4b8cb",
            lightSurfaceHighest: "#a4a8bc",
            lightPrimary: "#3d59a1",
            lightFg: "#ffffff",
            lightContainer: "#c4c8da",
            lightContainerFg: "#1a1b26",
            lightSecondaryContainer: "#c5cce4",
            lightSecondaryContainerFg: "#2e4580",
            lightTertiaryContainer: "#e1bec6",
            lightTextMain: "#343b58",
            lightTextMuted: "#565a6e",
            lightOutline: "#79809f",
            lightOutlineVariant: "#c4c8da"
        },
        "gruvbox": {
            darkBg: "#282828",
            darkSurfaceLowest: "#141617",
            darkSurfaceLow: "#1d2021",
            darkSurface: "#32302f",
            darkSurfaceHigh: "#3c3836",
            darkSurfaceHighest: "#504945",
            darkPrimary: "#fabd2f",
            darkFg: "#1d2021",
            darkContainer: "#504945",
            darkContainerFg: "#fabd2f",
            darkSecondaryContainer: "#453b30",
            darkSecondaryContainerFg: "#fe8019",
            darkTertiaryContainer: "#552825",
            darkTextMain: "#ebdbb2",
            darkTextMuted: "#a89984",
            darkOutline: "#7c6f64",
            darkOutlineVariant: "#3c3836",

            lightBg: "#fbf1c7",
            lightSurfaceLowest: "#ffffff",
            lightSurfaceLow: "#f2e5bc",
            lightSurface: "#ebdbb2",
            lightSurfaceHigh: "#d5c4a1",
            lightSurfaceHighest: "#bdae93",
            lightPrimary: "#b57614",
            lightFg: "#ffffff",
            lightContainer: "#ebdbb2",
            lightContainerFg: "#282828",
            lightSecondaryContainer: "#e5d4a8",
            lightSecondaryContainerFg: "#8f3f05",
            lightTertiaryContainer: "#ecc8b8",
            lightTextMain: "#282828",
            lightTextMuted: "#7c6f64",
            lightOutline: "#8a7b6b",
            lightOutlineVariant: "#d5c4a1"
        },
        "rosepine": {
            darkBg: "#191724",
            darkSurfaceLowest: "#0f0e17",
            darkSurfaceLow: "#14121e",
            darkSurface: "#1f1d2e",
            darkSurfaceHigh: "#26233a",
            darkSurfaceHighest: "#393552",
            darkPrimary: "#ebbcba",
            darkFg: "#191724",
            darkContainer: "#31748f",
            darkContainerFg: "#e0def4",
            darkSecondaryContainer: "#2d283e",
            darkSecondaryContainerFg: "#9ccfd8",
            darkTertiaryContainer: "#492b3a",
            darkTextMain: "#e0def4",
            darkTextMuted: "#908caa",
            darkOutline: "#6e6a86",
            darkOutlineVariant: "#26233a",

            lightBg: "#faf4ed",
            lightSurfaceLowest: "#ffffff",
            lightSurfaceLow: "#f2e9de",
            lightSurface: "#fffaf3",
            lightSurfaceHigh: "#f2e9e1",
            lightSurfaceHighest: "#dfdad9",
            lightPrimary: "#d7827e",
            lightFg: "#ffffff",
            lightContainer: "#f2e9de",
            lightContainerFg: "#575279",
            lightSecondaryContainer: "#e9e3d9",
            lightSecondaryContainerFg: "#286983",
            lightTertiaryContainer: "#ecd1d7",
            lightTextMain: "#575279",
            lightTextMuted: "#797593",
            lightOutline: "#8a8597",
            lightOutlineVariant: "#dfdad9"
        }
    })

    readonly property var activePalette: palettes[accentName] || palettes["lavender"]

    // Background & Surfaces
    readonly property color background: isDark ? activePalette.darkBg : activePalette.lightBg
    readonly property color surfaceDim: isDark ? activePalette.darkBg : activePalette.lightSurfaceLow
    readonly property color surface: isDark ? activePalette.darkBg : activePalette.lightBg
    readonly property color surfaceBright: isDark ? activePalette.darkSurfaceHighest : activePalette.lightSurfaceLowest
    readonly property color surfaceContainerLowest: isDark ? activePalette.darkSurfaceLowest : activePalette.lightSurfaceLowest
    readonly property color surfaceContainerLow: isDark ? activePalette.darkSurfaceLow : activePalette.lightSurfaceLow
    readonly property color surfaceContainer: isDark ? activePalette.darkSurface : activePalette.lightSurface
    readonly property color surfaceContainerHigh: isDark ? activePalette.darkSurfaceHigh : activePalette.lightSurfaceHigh
    readonly property color surfaceContainerHighest: isDark ? activePalette.darkSurfaceHighest : activePalette.lightSurfaceHighest

    // Primary Accents
    readonly property color primary: isDark ? activePalette.darkPrimary : activePalette.lightPrimary
    readonly property color primaryFg: isDark ? activePalette.darkFg : activePalette.lightFg
    readonly property color primaryContainer: isDark ? activePalette.darkContainer : activePalette.lightContainer
    readonly property color primaryContainerFg: isDark ? activePalette.darkContainerFg : activePalette.lightContainerFg

    // Secondary Accents
    readonly property color secondaryContainer: isDark ? activePalette.darkSecondaryContainer : activePalette.lightSecondaryContainer
    readonly property color secondaryContainerFg: isDark ? activePalette.darkSecondaryContainerFg : activePalette.lightSecondaryContainerFg
    readonly property color tertiaryContainer: isDark ? activePalette.darkTertiaryContainer : activePalette.lightTertiaryContainer

    // Text & Outlines
    readonly property color textMain: isDark ? activePalette.darkTextMain : activePalette.lightTextMain
    readonly property color textMuted: isDark ? activePalette.darkTextMuted : activePalette.lightTextMuted
    readonly property color outline: isDark ? activePalette.darkOutline : activePalette.lightOutline
    readonly property color outlineVariant: isDark ? activePalette.darkOutlineVariant : activePalette.lightOutlineVariant

    // Semantic component tokens (derived so components never pick raw surface tokens)
    readonly property color menuSurface: isDark ? activePalette.darkSurfaceHigh : activePalette.lightSurfaceLowest
    readonly property color hoverOverlay: isDark ? Qt.rgba(1.0, 1.0, 1.0, 0.08) : Qt.rgba(0.0, 0.0, 0.0, 0.06)
    readonly property color activeOverlay: isDark ? Qt.rgba(1.0, 1.0, 1.0, 0.14) : Qt.rgba(0.0, 0.0, 0.0, 0.10)
    readonly property color menuItemHover: isDark ? Qt.rgba(1.0, 1.0, 1.0, 0.09) : Qt.rgba(0.0, 0.0, 0.0, 0.05)
    readonly property color danger: isDark ? "#f2b8b5" : "#ba1a1a"
    readonly property color dangerContainer: isDark ? "#381e1e" : "#ffdad6"
    readonly property color dangerFg: danger
    readonly property color track: isDark ? activePalette.darkSurfaceHighest : activePalette.lightSurfaceHigh
    readonly property color borderSubtle: outlineVariant
    readonly property color separator: outlineVariant

    // Radii & Motion
    readonly property real radiusFull: 9999.0
    readonly property real radiusXl: 28.0
    readonly property real radiusL: 18.0
    readonly property real radiusM: 12.0
    readonly property real radiusS: 8.0

    readonly property int durationFast: 150
    readonly property int durationNormal: 250

    function readSetting(key) {
        if (typeof engine === "undefined" || !engine || typeof engine.get_setting !== "function")
            return "";
        var value = engine.get_setting(key);
        return (value === undefined || value === null) ? "" : String(value);
    }

    function writeSetting(key, value) {
        if (typeof engine === "undefined" || !engine || typeof engine.set_setting !== "function")
            return;
        engine.set_setting(key, String(value));
    }

    function loadSettings() {
        var value = "";

        value = readSetting("themeMode");
        if (value.length > 0) themeMode = value;
        value = readSetting("accentName");
        if (value.length > 0) accentName = value;
        value = readSetting("iconSource");
        if (value.length > 0) iconSource = value;
        value = readSetting("phosphorWeight");
        if (value.length > 0) phosphorWeight = value;
        value = readSetting("dragAction");
        if (value.length > 0) dragAction = value;

        value = readSetting("showThumbnails");
        if (value.length > 0) showThumbnails = (value === "true");
        value = readSetting("showBrandBadge");
        if (value.length > 0) showBrandBadge = (value === "true");
        value = readSetting("showExperimentalIcons");
        if (value.length > 0) showExperimentalIcons = (value === "true");
        value = readSetting("showAdvancedArchives");
        if (value.length > 0) showAdvancedArchives = (value === "true");
        value = readSetting("experimentalPcCustomization");
        if (value.length > 0) experimentalPcCustomization = (value === "true");
        value = readSetting("gridZoomLevel");
        if (value.length > 0) gridZoomLevel = Math.max(0, Math.min(9, parseInt(value, 10) || 2));
        value = readSetting("listZoomLevel");
        if (value.length > 0) listZoomLevel = Math.max(0, Math.min(9, parseInt(value, 10) || 2));
    }

    Component.onCompleted: loadSettings()

    onThemeModeChanged: writeSetting("themeMode", themeMode)
    onAccentNameChanged: writeSetting("accentName", accentName)
    onIconSourceChanged: writeSetting("iconSource", iconSource)
    onPhosphorWeightChanged: writeSetting("phosphorWeight", phosphorWeight)
    onDragActionChanged: writeSetting("dragAction", dragAction)
    onShowThumbnailsChanged: writeSetting("showThumbnails", showThumbnails)
    onShowBrandBadgeChanged: writeSetting("showBrandBadge", showBrandBadge)
    onShowExperimentalIconsChanged: writeSetting("showExperimentalIcons", showExperimentalIcons)
    onShowAdvancedArchivesChanged: writeSetting("showAdvancedArchives", showAdvancedArchives)
    onExperimentalPcCustomizationChanged: writeSetting("experimentalPcCustomization", experimentalPcCustomization)
    onGridZoomLevelChanged: writeSetting("gridZoomLevel", gridZoomLevel)
    onListZoomLevelChanged: writeSetting("listZoomLevel", listZoomLevel)
}
