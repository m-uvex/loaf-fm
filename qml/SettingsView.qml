import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

Item {
    id: settingsView
    property int activeTab: 0
    property string searchQuery: ""
    signal searchCleared()

    function matchesQuery(keywords) {
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

    readonly property bool card1Match: matchesQuery("theme appearance light dark auto mode color scheme")
    readonly property bool card2Match: matchesQuery("theme palette accent colors wallpaper catppuccin nord tokyonight gruvbox rosepine amber lavender violet ricing")
    readonly property bool card3Match: matchesQuery("top left brand loaf logo badge show hide")
    readonly property bool card4Match: matchesQuery("icon style vector phosphor system adwaita desktop theme")
    readonly property bool card5Match: matchesQuery("phosphor weight variant thin light regular bold fill duotone stroke thickness")

    readonly property bool card6Match: matchesQuery("left click drag action selection box pan scroll view rubberband marquee mouse")
    readonly property bool card7Match: matchesQuery("picture thumbnails preview image photo svg gallery")
    readonly property bool card8Match: matchesQuery("show hidden files dot dotfiles folders")
    readonly property bool card9Match: matchesQuery("disambiguate duplicate names parent folder prefix search")

    readonly property bool card10Match: matchesQuery("experimental icon styles adwaita advanced archives compress cpio tar formats")
    readonly property bool card11Match: matchesQuery("about loaf version musa orbitos author credits")
    readonly property bool card12Match: matchesQuery("experimental pc customization dashboard layout sections this pc")

    readonly property int interfaceMatches: (card1Match ? 1 : 0) + (card2Match ? 1 : 0) + (card3Match ? 1 : 0) + (card4Match ? 1 : 0) + (card5Match ? 1 : 0)
    readonly property int behaviorMatches: (card6Match ? 1 : 0) + (card7Match ? 1 : 0) + (card8Match ? 1 : 0) + (card9Match ? 1 : 0)
    readonly property int experimentalMatches: (card10Match ? 1 : 0) + (card12Match ? 1 : 0)
    readonly property int aboutMatches: (card11Match ? 1 : 0)
    readonly property int totalMatches: interfaceMatches + behaviorMatches + experimentalMatches + aboutMatches

    // Space still claimed above `panel` by panels that are painted while fading
    // out. Overlapping the incoming tab with the outgoing one lets the switch
    // cross-fade instead of dropping the outgoing panel in one frame.
    function fadeOverlapAbove(panel) {
        var panels = [tabInterface, tabBehavior, tabExperimental, tabAbout];
        var overlap = 0;
        for (var i = 0; i < panels.length; i++) {
            var p = panels[i];
            if (!p || p === panel)
                break;
            if (p.visible && !p.shown)
                overlap += p.implicitHeight + contentColumn.spacing;
        }
        return overlap;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 16

        // Left Navigation Tabs
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 180
            radius: theme.radiusL
            color: theme.surfaceContainer

            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                // Section Label
                Text {
                    text: "SETTINGS"
                    color: theme.textMuted
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                    Layout.margins: 6
                    Layout.bottomMargin: 6
                }

                Item {
                    id: tabNavList
                    readonly property int rowHeight: 42
                    readonly property int rowGap: 6

                    Layout.fillWidth: true
                    Layout.preferredHeight: tabNavRepeater.count * rowHeight + Math.max(0, tabNavRepeater.count - 1) * rowGap

                    // Selection fill travels between rows instead of popping in place.
                    Rectangle {
                        id: tabHighlight
                        width: tabNavList.width
                        height: tabNavList.rowHeight
                        radius: theme.radiusFull
                        color: theme.primaryContainer
                        y: Math.max(0, Math.min(settingsView.activeTab, tabNavRepeater.count - 1)) * (tabNavList.rowHeight + tabNavList.rowGap)

                        Behavior on y { NumberAnimation { duration: theme.durationNormal; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                    }

                    Repeater {
                        id: tabNavRepeater
                        model: [
                            { name: "Interface", iconName: "palette" },
                            { name: "Behavior", iconName: "gear" },
                            { name: "Experimental", iconName: "sparkle" },
                            { name: "About Loaf", iconName: "bread" }
                        ]

                        delegate: Item {
                            width: tabNavList.width
                            height: tabNavList.rowHeight
                            y: index * (tabNavList.rowHeight + tabNavList.rowGap)

                            readonly property bool isCurrent: settingsView.activeTab === index
                            readonly property bool isHovered: tabMouse.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                radius: theme.radiusFull
                                color: (isHovered && !isCurrent) ? theme.surfaceContainerHigh : "transparent"

                                Behavior on color { ColorAnimation { duration: theme.durationFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 10

                                    LoafIcon {
                                        name: modelData.iconName
                                        size: 18
                                        color: isCurrent ? theme.primaryContainerFg : (isHovered ? theme.textMain : theme.textMuted)
                                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                    }

                                    Text {
                                        text: modelData.name
                                        color: isCurrent ? theme.primaryContainerFg : (isHovered ? theme.textMain : theme.textMuted)
                                        font.pixelSize: 13
                                        font.bold: isCurrent
                                        Layout.fillWidth: true
                                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                    }
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    settingsView.searchCleared();
                                    settingsView.activeTab = index;
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // Right Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: theme.radiusL
            color: theme.surfaceContainerLow
            clip: true

            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

            ScrollView {
                id: contentScroll
                anchors.fill: parent
                anchors.margins: 22
                clip: true
                contentWidth: availableWidth

                ColumnLayout {
                    id: contentColumn
                    width: contentScroll.availableWidth
                    spacing: 16

                    // Single Unified Top Header (No dot, no repeated pill)
                    Text {
                        text: settingsView.searchQuery.length > 0
                            ? "Settings"
                            : (settingsView.activeTab === 0 ? "Interface" : (settingsView.activeTab === 1 ? "Behavior" : (settingsView.activeTab === 2 ? "Experimental" : "About Loaf")))
                        color: theme.textMain
                        font.pixelSize: 26
                        font.bold: true
                        font.letterSpacing: -0.5
                    }

                    // Search Results Header (when searching)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: settingsView.searchQuery.length > 0 && settingsView.totalMatches > 0
                        spacing: 8

                        LoafIcon { name: "magnifying-glass"; size: 16; color: theme.primary }
                        Text {
                            text: "Settings search results"
                            color: theme.textMain
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Rectangle {
                            height: 22
                            width: summaryCountTxt.implicitWidth + 14
                            radius: theme.radiusFull
                            color: theme.primaryContainer

                            Text {
                                id: summaryCountTxt
                                anchors.centerIn: parent
                                text: settingsView.totalMatches + " found"
                                color: theme.primaryContainerFg
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    // Empty Search Results State
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 40
                        Layout.bottomMargin: 40
                        visible: settingsView.searchQuery.length > 0 && settingsView.totalMatches === 0
                        spacing: 12

                        LoafIcon {
                            Layout.alignment: Qt.AlignHCenter
                            name: "magnifying-glass"
                            size: 44
                            color: theme.textMuted
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No settings found matching \"" + settingsView.searchQuery + "\""
                            color: theme.textMuted
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    // ==========================================
                    // TAB 0: INTERFACE
                    // ==========================================
                    ColumnLayout {
                        id: tabInterface
                        Layout.fillWidth: true
                        spacing: 14

                        readonly property bool shown: settingsView.searchQuery.length > 0 ? (settingsView.interfaceMatches > 0) : (settingsView.activeTab === 0)
                        readonly property real fadeOverlap: settingsView.fadeOverlapAbove(tabInterface)
                        property real slideOffset: shown ? 0 : 6

                        Layout.topMargin: -fadeOverlap
                        Layout.bottomMargin: fadeOverlap

                        visible: shown || opacity > 0.001
                        opacity: shown ? 1.0 : 0.0
                        enabled: shown

                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on slideOffset { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        transform: Translate { y: tabInterface.slideOffset }

                        // 1. Theme (Auto, Light, Dark)
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card1Match
                            Layout.fillWidth: true
                            implicitHeight: schemeRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: schemeRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "Theme"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Light, dark, or system appearance"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    spacing: 8

                                    // AUTO PILL
                                    Item {
                                        width: 88; height: 38
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: theme.radiusFull
                                            color: theme.themeMode === "auto" ? theme.primaryContainer : theme.surfaceContainerHigh
                                            border.width: theme.themeMode === "auto" ? 2 : 1
                                            border.color: theme.themeMode === "auto" ? theme.primary : theme.outlineVariant
                                            scale: autoMouse.pressed ? 0.94 : (autoMouse.containsMouse ? 1.04 : 1.0)

                                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { NumberAnimation { duration: theme.durationFast } }
                                            Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Auto"
                                                color: theme.themeMode === "auto" ? theme.primaryContainerFg : theme.textMain
                                                font.pixelSize: 12
                                                font.bold: true
                                                Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                            }
                                        }
                                        MouseArea {
                                            id: autoMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: theme.themeMode = "auto"
                                        }
                                    }

                                    // LIGHT PILL
                                    Item {
                                        width: 88; height: 38
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: theme.radiusFull
                                            color: theme.themeMode === "light" ? theme.primaryContainer : theme.surfaceContainerHigh
                                            border.width: theme.themeMode === "light" ? 2 : 1
                                            border.color: theme.themeMode === "light" ? theme.primary : theme.outlineVariant
                                            scale: lightMouse.pressed ? 0.94 : (lightMouse.containsMouse ? 1.04 : 1.0)

                                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { NumberAnimation { duration: theme.durationFast } }
                                            Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Light"
                                                color: theme.themeMode === "light" ? theme.primaryContainerFg : theme.textMain
                                                font.pixelSize: 12
                                                font.bold: true
                                                Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                            }
                                        }
                                        MouseArea {
                                            id: lightMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: theme.themeMode = "light"
                                        }
                                    }

                                    // DARK PILL
                                    Item {
                                        width: 88; height: 38
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: theme.radiusFull
                                            color: theme.themeMode === "dark" ? theme.primaryContainer : theme.surfaceContainerHigh
                                            border.width: theme.themeMode === "dark" ? 2 : 1
                                            border.color: theme.themeMode === "dark" ? theme.primary : theme.outlineVariant
                                            scale: darkMouse.pressed ? 0.94 : (darkMouse.containsMouse ? 1.04 : 1.0)

                                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { NumberAnimation { duration: theme.durationFast } }
                                            Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Dark"
                                                color: theme.themeMode === "dark" ? theme.primaryContainerFg : theme.textMain
                                                font.pixelSize: 12
                                                font.bold: true
                                                Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                            }
                                        }
                                        MouseArea {
                                            id: darkMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: theme.themeMode = "dark"
                                        }
                                    }
                                }
                            }
                        }

                        // 2. Palette Picker (Pill Swatches)
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card2Match
                            Layout.fillWidth: true
                            implicitHeight: palContentCol.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            ColumnLayout {
                                id: palContentCol
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: "Color palette"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Wallpaper extraction & community color schemes"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Repeater {
                                        model: [
                                            { id: "wallpaper", label: "Wallpaper" },
                                            { id: "lavender", label: "Loaf Violet" },
                                            { id: "amber", label: "Loaf Amber" },
                                            { id: "catppuccin", label: "Catppuccin" },
                                            { id: "nord", label: "Nord" },
                                            { id: "tokyonight", label: "Tokyo Night" },
                                            { id: "gruvbox", label: "Gruvbox" },
                                            { id: "rosepine", label: "Rosé Pine" }
                                        ]

                                        delegate: Item {
                                            width: 126; height: 38

                                            readonly property var swatch: theme.palettes[modelData.id] ? theme.palettes[modelData.id] : theme.palettes["lavender"]

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: theme.radiusFull
                                                color: theme.accentName === modelData.id ? theme.primaryContainer : theme.surfaceContainerHigh
                                                border.width: theme.accentName === modelData.id ? 2 : 1
                                                border.color: theme.accentName === modelData.id ? theme.primary : theme.outlineVariant

                                                scale: palMouse.pressed ? 0.94 : (palMouse.containsMouse ? 1.04 : 1.0)

                                                Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                                Behavior on border.color { ColorAnimation { duration: theme.durationFast } }
                                                Behavior on border.width { NumberAnimation { duration: theme.durationFast } }
                                                Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 8

                                                    Rectangle {
                                                        width: 12; height: 12; radius: 6
                                                        color: swatch.darkPrimary
                                                    }
                                                    Text {
                                                        text: modelData.label
                                                        color: theme.accentName === modelData.id ? theme.primaryContainerFg : theme.textMain
                                                        font.pixelSize: 11
                                                        font.bold: theme.accentName === modelData.id
                                                        Behavior on color { ColorAnimation { duration: theme.durationFast } }
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
                        }

                        // 3. Top-Left Loaf Logo Badge Toggle
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card3Match
                            Layout.fillWidth: true
                            implicitHeight: brandRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: brandRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "Top-Left Loaf Badge"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Show the bread icon brand badge in the top bar"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                LoafSwitch {
                                    id: brandBadgeSwitch
                                    checked: theme.showBrandBadge
                                    onToggled: theme.showBrandBadge = checked
                                }
                            }

                            Connections {
                                target: theme
                                function onShowBrandBadgeChanged() {
                                    if (brandBadgeSwitch.checked !== theme.showBrandBadge)
                                        brandBadgeSwitch.checked = theme.showBrandBadge
                                }
                            }
                        }

                        // 4. Icon Style (Reveals Adwaita & System when experimental enabled)
                        Rectangle {
                            visible: theme.showExperimentalIcons && (settingsView.searchQuery.length === 0 || settingsView.card4Match)
                            Layout.fillWidth: true
                            implicitHeight: iconSrcRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: iconSrcRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "Icon style"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Phosphor, system theme, or GNOME Adwaita"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    spacing: 8

                                    Item {
                                        width: 90; height: 38
                                        Rectangle {
                                            anchors.fill: parent; radius: theme.radiusFull
                                            color: theme.iconSource === "phosphor" ? theme.primaryContainer : theme.surfaceContainerHigh
                                            border.width: theme.iconSource === "phosphor" ? 2 : 1
                                            border.color: theme.iconSource === "phosphor" ? theme.primary : theme.outlineVariant
                                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { NumberAnimation { duration: theme.durationFast } }
                                            Text { anchors.centerIn: parent; text: "Phosphor"; color: theme.iconSource === "phosphor" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: 11; font.bold: true; Behavior on color { ColorAnimation { duration: theme.durationFast } } }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: theme.iconSource = "phosphor" }
                                    }

                                    Item {
                                        width: 90; height: 38
                                        Rectangle {
                                            anchors.fill: parent; radius: theme.radiusFull
                                            color: theme.iconSource === "system" ? theme.primaryContainer : theme.surfaceContainerHigh
                                            border.width: theme.iconSource === "system" ? 2 : 1
                                            border.color: theme.iconSource === "system" ? theme.primary : theme.outlineVariant
                                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { NumberAnimation { duration: theme.durationFast } }
                                            Text { anchors.centerIn: parent; text: "System"; color: theme.iconSource === "system" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: 11; font.bold: true; Behavior on color { ColorAnimation { duration: theme.durationFast } } }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: theme.iconSource = "system" }
                                    }

                                    Item {
                                        width: 90; height: 38
                                        Rectangle {
                                            anchors.fill: parent; radius: theme.radiusFull
                                            color: theme.iconSource === "adwaita" ? theme.primaryContainer : theme.surfaceContainerHigh
                                            border.width: theme.iconSource === "adwaita" ? 2 : 1
                                            border.color: theme.iconSource === "adwaita" ? theme.primary : theme.outlineVariant
                                            Behavior on color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { NumberAnimation { duration: theme.durationFast } }
                                            Text { anchors.centerIn: parent; text: "Adwaita"; color: theme.iconSource === "adwaita" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: 11; font.bold: true; Behavior on color { ColorAnimation { duration: theme.durationFast } } }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: theme.iconSource = "adwaita" }
                                    }
                                }
                            }
                        }

                        // 5. Phosphor Weight Variant
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card5Match
                            Layout.fillWidth: true
                            implicitHeight: weightCol.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            ColumnLayout {
                                id: weightCol
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "Phosphor icon weight"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Thin, light, regular, bold, fill, or duotone"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            { id: "thin", label: "Thin" },
                                            { id: "light", label: "Light" },
                                            { id: "regular", label: "Regular" },
                                            { id: "bold", label: "Bold" },
                                            { id: "fill", label: "Fill" },
                                            { id: "duotone", label: "Duotone" }
                                        ]

                                        delegate: Item {
                                            width: 86; height: 36
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: theme.radiusFull
                                                color: theme.phosphorWeight === modelData.id ? theme.primaryContainer : theme.surfaceContainerHigh
                                                border.color: theme.primary
                                                border.width: theme.phosphorWeight === modelData.id ? 2 : 0

                                                scale: wMouse.pressed ? 0.94 : (wMouse.containsMouse ? 1.04 : 1.0)
                                                Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: theme.phosphorWeight === modelData.id ? theme.primaryContainerFg : theme.textMain
                                                    font.pixelSize: 11
                                                    font.bold: theme.phosphorWeight === modelData.id
                                                }
                                            }
                                            MouseArea {
                                                id: wMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: theme.phosphorWeight = modelData.id
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // TAB 1: BEHAVIOR
                    // ==========================================
                    ColumnLayout {
                        id: tabBehavior
                        Layout.fillWidth: true
                        spacing: 14

                        readonly property bool shown: settingsView.searchQuery.length > 0 ? (settingsView.behaviorMatches > 0) : (settingsView.activeTab === 1)
                        readonly property real fadeOverlap: settingsView.fadeOverlapAbove(tabBehavior)
                        property real slideOffset: shown ? 0 : 6

                        Layout.topMargin: -fadeOverlap
                        Layout.bottomMargin: fadeOverlap

                        visible: shown || opacity > 0.001
                        opacity: shown ? 1.0 : 0.0
                        enabled: shown

                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on slideOffset { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        transform: Translate { y: tabBehavior.slideOffset }

                        // Left-Click Drag Action
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card6Match
                            Layout.fillWidth: true
                            implicitHeight: dragActionRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: dragActionRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "Left-click drag action"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Choose whether dragging selects items or pans the view"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    spacing: 8

                                    Item {
                                        width: 130; height: 38
                                        Rectangle {
                                            anchors.fill: parent; radius: theme.radiusFull
                                            color: theme.dragAction === "select" ? theme.primaryContainer : theme.surfaceContainerHigh
                                            border.color: theme.primary
                                            border.width: theme.dragAction === "select" ? 2 : 0
                                            Text { anchors.centerIn: parent; text: "Selection Box"; color: theme.dragAction === "select" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: 11; font.bold: true }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: theme.dragAction = "select" }
                                    }

                                    Item {
                                        width: 100; height: 38
                                        Rectangle {
                                            anchors.fill: parent; radius: theme.radiusFull
                                            color: theme.dragAction === "scroll" ? theme.primaryContainer : theme.surfaceContainerHigh
                                            border.color: theme.primary
                                            border.width: theme.dragAction === "scroll" ? 2 : 0
                                            Text { anchors.centerIn: parent; text: "Pan View"; color: theme.dragAction === "scroll" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: 11; font.bold: true }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: theme.dragAction = "scroll" }
                                    }
                                }
                            }
                        }

                        // Picture Thumbnails
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card7Match
                            Layout.fillWidth: true
                            implicitHeight: thumbRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: thumbRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "Picture Thumbnails"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Show preview thumbnails for pictures, SVGs, and creative files"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                LoafSwitch {
                                    id: thumbSwitch
                                    checked: theme.showThumbnails
                                    onToggled: theme.showThumbnails = checked
                                }
                            }

                            Connections {
                                target: theme
                                function onShowThumbnailsChanged() {
                                    if (thumbSwitch.checked !== theme.showThumbnails)
                                        thumbSwitch.checked = theme.showThumbnails
                                }
                            }
                        }

                        // Show Hidden Files
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card8Match
                            Layout.fillWidth: true
                            implicitHeight: hiddenRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: hiddenRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "Show Hidden Files"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Display files and folders starting with a dot"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                LoafSwitch {
                                    id: hiddenSwitch
                                    checked: engine.show_hidden
                                    onToggled: if (engine.show_hidden !== checked) engine.toggle_show_hidden()
                                }
                            }

                            Connections {
                                target: engine
                                function onShow_hiddenChanged() {
                                    if (hiddenSwitch.checked !== engine.show_hidden)
                                        hiddenSwitch.checked = engine.show_hidden
                                }
                            }
                        }

                        // Disambiguate duplicate names in search
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card9Match
                            Layout.fillWidth: true
                            implicitHeight: disambigRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: disambigRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "Disambiguate duplicate names"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Show parent folder prefix for duplicate search results"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                LoafSwitch {
                                    id: disambigSwitch
                                    checked: engine.disambiguate_duplicates
                                    onToggled: if (engine.disambiguate_duplicates !== checked) engine.toggle_disambiguate_duplicates()
                                }
                            }

                            Connections {
                                target: engine
                                function onDisambiguate_duplicatesChanged() {
                                    if (disambigSwitch.checked !== engine.disambiguate_duplicates)
                                        disambigSwitch.checked = engine.disambiguate_duplicates
                                }
                            }
                        }
                    }

                    // ==========================================
                    // TAB 2: EXPERIMENTAL
                    // ==========================================
                    ColumnLayout {
                        id: tabExperimental
                        Layout.fillWidth: true
                        spacing: 14

                        readonly property bool shown: settingsView.searchQuery.length > 0 ? (settingsView.experimentalMatches > 0) : (settingsView.activeTab === 2)
                        readonly property real fadeOverlap: settingsView.fadeOverlapAbove(tabExperimental)
                        property real slideOffset: shown ? 0 : 6

                        Layout.topMargin: -fadeOverlap
                        Layout.bottomMargin: fadeOverlap

                        visible: shown || opacity > 0.001
                        opacity: shown ? 1.0 : 0.0
                        enabled: shown

                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on slideOffset { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        transform: Translate { y: tabExperimental.slideOffset }

                        // More Icon Styles (System & Adwaita)
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: expIconRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: expIconRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "More icon styles"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Enable System desktop theme and GNOME Adwaita vector icons"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                LoafSwitch {
                                    id: expIconSwitch
                                    checked: theme.showExperimentalIcons
                                    onToggled: theme.showExperimentalIcons = checked
                                }
                            }

                            Connections {
                                target: theme
                                function onShowExperimentalIconsChanged() {
                                    if (expIconSwitch.checked !== theme.showExperimentalIcons)
                                        expIconSwitch.checked = theme.showExperimentalIcons
                                }
                            }
                        }

                        // Advanced Archive Formats
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: expArchRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: expArchRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "Advanced Archive Formats"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Enable obscure archive formats (.7z, .tar.bz2, .tar.xz, .tar.zst, .cpio) in Compress menu"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                LoafSwitch {
                                    id: expArchSwitch
                                    checked: theme.showAdvancedArchives
                                    onToggled: theme.showAdvancedArchives = checked
                                }
                            }

                            Connections {
                                target: theme
                                function onShowAdvancedArchivesChanged() {
                                    if (expArchSwitch.checked !== theme.showAdvancedArchives)
                                        expArchSwitch.checked = theme.showAdvancedArchives
                                }
                            }
                        }

                        // PC Customization
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card12Match
                            Layout.fillWidth: true
                            implicitHeight: pcCustomRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: pcCustomRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: "PC customization"; color: theme.textMain; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Allow reordering and hiding sections on the This PC dashboard"; color: theme.textMuted; font.pixelSize: 11 }
                                }

                                LoafSwitch {
                                    id: pcCustomSwitch
                                    checked: theme.experimentalPcCustomization
                                    onToggled: theme.experimentalPcCustomization = checked
                                }
                            }

                            // LoafSwitch assigns to its own `checked` when clicked,
                            // which drops the binding above. Re-sync so the switch
                            // still follows external changes (e.g. settings loaded
                            // from the store, or another view toggling the option).
                            Connections {
                                target: theme
                                function onExperimentalPcCustomizationChanged() {
                                    if (pcCustomSwitch.checked !== theme.experimentalPcCustomization)
                                        pcCustomSwitch.checked = theme.experimentalPcCustomization
                                }
                            }
                        }
                    }

                    // ==========================================
                    // TAB 3: ABOUT LOAF
                    // ==========================================
                    ColumnLayout {
                        id: tabAbout
                        Layout.fillWidth: true
                        spacing: 14

                        readonly property bool shown: settingsView.searchQuery.length > 0 ? (settingsView.aboutMatches > 0) : (settingsView.activeTab === 3)
                        readonly property real fadeOverlap: settingsView.fadeOverlapAbove(tabAbout)
                        property real slideOffset: shown ? 0 : 6

                        Layout.topMargin: -fadeOverlap
                        Layout.bottomMargin: fadeOverlap

                        visible: shown || opacity > 0.001
                        opacity: shown ? 1.0 : 0.0
                        enabled: shown

                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on slideOffset { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        transform: Translate { y: tabAbout.slideOffset }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: aboutRow.implicitHeight + 36
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: aboutRow
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16

                                Rectangle {
                                    width: 52; height: 52; radius: theme.radiusM
                                    color: theme.primaryContainer
                                    LoafIcon { anchors.centerIn: parent; name: "bread"; size: 28; color: theme.primaryContainerFg }
                                }

                                ColumnLayout {
                                    spacing: 4
                                    Text { text: "Loaf v0.1.0"; color: theme.textMain; font.pixelSize: 16; font.bold: true }
                                    Text { text: "A beatiful and fast rust-based materal 3e file manager for linux."; color: theme.textMuted; font.pixelSize: 12 }
                                    RowLayout {
                                        spacing: 6
                                        LoafIcon { name: "github-logo"; size: 14; color: theme.primary }
                                        Text {
                                            id: ghLink
                                            text: "github.com/m-uvex/loaf-fm  ·  by @m_uvex"
                                            color: ghMouse.containsMouse ? theme.primary : theme.outline
                                            font.pixelSize: 11
                                            font.underline: ghMouse.containsMouse

                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            MouseArea {
                                                id: ghMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Qt.openUrlExternally("https://github.com/m-uvex/loaf-fm")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
