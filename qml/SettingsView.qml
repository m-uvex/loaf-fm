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
    readonly property bool card13Match: matchesQuery("performance low power mode battery old slow computer animations effects gpu")
    readonly property bool card14Match: matchesQuery("reduce motion animations accessibility")
    readonly property bool card15Match: matchesQuery("text size font scale accessibility larger")
    readonly property bool card16Match: matchesQuery("restore session tabs remember last folder window startup")
    readonly property bool card17Match: matchesQuery("click rename inline single click")
    readonly property bool card18Match: matchesQuery("search file contents text inside")

    readonly property int interfaceMatches: (card1Match ? 1 : 0) + (card2Match ? 1 : 0) + (card3Match ? 1 : 0) + (card4Match ? 1 : 0) + (card5Match ? 1 : 0)
    readonly property int behaviorMatches: (card6Match ? 1 : 0) + (card7Match ? 1 : 0) + (card8Match ? 1 : 0) + (card9Match ? 1 : 0)
        + (card16Match ? 1 : 0) + (card17Match ? 1 : 0) + (card18Match ? 1 : 0)
    readonly property int accessibilityMatches: (card13Match ? 1 : 0) + (card14Match ? 1 : 0) + (card15Match ? 1 : 0)
    readonly property int experimentalMatches: (card10Match ? 1 : 0) + (card12Match ? 1 : 0)
    readonly property int aboutMatches: (card11Match ? 1 : 0)
    readonly property int totalMatches: interfaceMatches + behaviorMatches + accessibilityMatches + experimentalMatches + aboutMatches

    // Space still claimed above `panel` by panels that are painted while fading
    // out. Overlapping the incoming tab with the outgoing one lets the switch
    // cross-fade instead of dropping the outgoing panel in one frame.
    function fadeOverlapAbove(panel) {
        var panels = [tabInterface, tabBehavior, tabAccessibility, tabExperimental, tabAbout];
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
            Layout.preferredWidth: 200
            radius: theme.radiusL
            color: theme.surfaceContainer

            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                // Section Label
                Text {
                    text: qsTr("SETTINGS")
                    color: theme.textMuted
                    font.pixelSize: theme.fs(10)
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

                        Behavior on y { enabled: theme.animate; NumberAnimation { duration: theme.durationNormal; easing.type: Easing.OutCubic } }
                        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                    }

                    Repeater {
                        id: tabNavRepeater
                        model: [
                            { name: "Interface", iconName: "palette" },
                            { name: "Behavior", iconName: "gear" },
                            { name: "Accessibility", iconName: "person-arms-spread" },
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

                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 10

                                    LoafIcon {
                                        name: modelData.iconName
                                        size: 18
                                        color: isCurrent ? theme.primaryContainerFg : (isHovered ? theme.textMain : theme.textMuted)
                                        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                    }

                                    Text {
                                        text: modelData.name
                                        color: isCurrent ? theme.primaryContainerFg : (isHovered ? theme.textMain : theme.textMuted)
                                        font.pixelSize: theme.fs(13)
                                        font.bold: isCurrent
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
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

            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

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
                            : (settingsView.activeTab === 0 ? "Interface" : (settingsView.activeTab === 1 ? "Behavior" : (settingsView.activeTab === 2 ? "Accessibility" : (settingsView.activeTab === 3 ? "Experimental" : "About Loaf"))))
                        color: theme.textMain
                        font.pixelSize: theme.fs(26)
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
                            text: qsTr("Settings search results")
                            color: theme.textMain
                            font.pixelSize: theme.fs(16)
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
                                font.pixelSize: theme.fs(11)
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
                            font.pixelSize: theme.fs(14)
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

                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on slideOffset { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        transform: Translate { y: tabInterface.slideOffset }

                        // 1. Theme (Auto, Light, Dark)
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card1Match
                            Layout.fillWidth: true
                            implicitHeight: schemeRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: schemeRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("Theme"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Light, dark, or system appearance"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
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

                                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
                                            Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Auto")
                                                color: theme.themeMode === "auto" ? theme.primaryContainerFg : theme.textMain
                                                font.pixelSize: theme.fs(12)
                                                font.bold: true
                                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
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

                                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
                                            Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Light")
                                                color: theme.themeMode === "light" ? theme.primaryContainerFg : theme.textMain
                                                font.pixelSize: theme.fs(12)
                                                font.bold: true
                                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
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

                                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
                                            Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Dark")
                                                color: theme.themeMode === "dark" ? theme.primaryContainerFg : theme.textMain
                                                font.pixelSize: theme.fs(12)
                                                font.bold: true
                                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
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
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            ColumnLayout {
                                id: palContentCol
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: qsTr("Color palette"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Wallpaper extraction & community color schemes"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
                                }

                                Flow {
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
                                            { id: "rosepine", label: qsTr("Rosé Pine") },
                                            { id: "everforest", label: qsTr("Everforest") },
                                            { id: "breeze", label: qsTr("Breeze") }
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

                                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                                Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                                Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
                                                Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

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
                                                        font.pixelSize: theme.fs(11)
                                                        font.bold: theme.accentName === modelData.id
                                                        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
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
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: brandRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("Top-Left Loaf Badge"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Show the bread icon brand badge in the top bar"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
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
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: iconSrcRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("Icon style"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Phosphor, system theme, or GNOME Adwaita"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
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
                                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
                                            Text { anchors.centerIn: parent; text: qsTr("Phosphor"); color: theme.iconSource === "phosphor" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: theme.fs(11); font.bold: true; Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } } }
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
                                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
                                            Text { anchors.centerIn: parent; text: qsTr("System"); color: theme.iconSource === "system" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: theme.fs(11); font.bold: true; Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } } }
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
                                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                            Behavior on border.width { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
                                            Text { anchors.centerIn: parent; text: qsTr("Adwaita"); color: theme.iconSource === "adwaita" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: theme.fs(11); font.bold: true; Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } } }
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
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            ColumnLayout {
                                id: weightCol
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("Phosphor icon weight"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Thin, light, regular, bold, fill, or duotone"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            { id: "thin", label: qsTr("Thin") },
                                            { id: "light", label: qsTr("Light") },
                                            { id: "regular", label: qsTr("Regular") },
                                            { id: "bold", label: qsTr("Bold") },
                                            { id: "fill", label: qsTr("Fill") },
                                            { id: "duotone", label: qsTr("Duotone") }
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
                                                Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: theme.phosphorWeight === modelData.id ? theme.primaryContainerFg : theme.textMain
                                                    font.pixelSize: theme.fs(11)
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

                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on slideOffset { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        transform: Translate { y: tabBehavior.slideOffset }

                        // Left-Click Drag Action
                        Rectangle {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card6Match
                            Layout.fillWidth: true
                            implicitHeight: dragActionRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: dragActionRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("Left-click drag action"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Choose whether dragging selects items or pans the view"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
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
                                            Text { anchors.centerIn: parent; text: qsTr("Selection Box"); color: theme.dragAction === "select" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: theme.fs(11); font.bold: true }
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
                                            Text { anchors.centerIn: parent; text: qsTr("Pan View"); color: theme.dragAction === "scroll" ? theme.primaryContainerFg : theme.textMain; font.pixelSize: theme.fs(11); font.bold: true }
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
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: thumbRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("Picture Thumbnails"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Show preview thumbnails for pictures, SVGs, and creative files"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
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
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: hiddenRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("Show Hidden Files"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Display files and folders starting with a dot"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
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
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: disambigRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("Disambiguate duplicate names"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Show parent folder prefix for duplicate search results"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
                                }

                                LoafSwitch {
                                    id: disambigSwitch
                                    checked: core.get_setting("disambiguate_duplicates") !== "false"
                                    onToggled: core.set_setting("disambiguate_duplicates", checked ? "true" : "false")
                                }
                            }


                        }
                        SettingCard {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card16Match
                            title: qsTr("Restore last session")
                            subtitle: qsTr("Reopen your tabs, folders and window size on start")
                            LoafSwitch {
                                checked: core.get_setting("restoreSession") !== "false"
                                onToggled: function(c) { core.set_setting("restoreSession", c ? "true" : "false"); }
                            }
                        }

                        SettingCard {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card17Match
                            title: qsTr("Click selected name to rename")
                            subtitle: qsTr("A second single click on a selected item's name starts renaming (F2 always works)")
                            LoafSwitch {
                                checked: theme.clickToRename
                                onToggled: function(c) { theme.clickToRename = c; }
                            }
                        }

                        SettingCard {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card18Match
                            title: qsTr("Search inside files")
                            subtitle: qsTr("Subfolder / everywhere searches also match text inside files (slower)")
                            LoafSwitch {
                                checked: theme.searchContents
                                onToggled: function(c) { theme.searchContents = c; }
                            }
                        }

                        SettingCard {
                            title: qsTr("Navigation sidebar")
                            subtitle: qsTr("Show, hide and reorder places, drives and bookmarks in the left rail")
                            LoafButton {
                                text: qsTr("Customize Sidebar…")
                                icon: "sliders-horizontal"
                                variant: "tonal"
                                onClicked: customizePlaces.open()
                            }
                        }

                        SettingCard {
                            title: qsTr("Context menu layout")
                            subtitle: qsTr("Minimal hides items with common shortcuts (Open, Cut, Copy, Delete, etc.)")
                            RowLayout {
                                spacing: 8
                                LoafSegmented {
                                    Layout.preferredWidth: 260
                                    options: [
                                        { value: "full", label: qsTr("Full") },
                                        { value: "minimal", label: qsTr("Minimal") },
                                        { value: "custom", label: qsTr("Custom") }
                                    ]
                                    value: theme.contextMenuMode
                                    onSelected: function(v) {
                                        theme.contextMenuMode = v;
                                        if (v === "custom")
                                            customizeContextMenuDialog.open();
                                    }
                                }
                                LoafButton {
                                    visible: theme.contextMenuMode === "custom"
                                    text: qsTr("Edit…")
                                    icon: "sliders"
                                    variant: "tonal"
                                    onClicked: customizeContextMenuDialog.open()
                                }
                            }
                        }
                    }


                    // ==========================================
                    // TAB 2: ACCESSIBILITY
                    // ==========================================
                    ColumnLayout {
                        id: tabAccessibility
                        Layout.fillWidth: true
                        spacing: 14

                        readonly property bool shown: settingsView.searchQuery.length > 0 ? (settingsView.accessibilityMatches > 0) : (settingsView.activeTab === 2)
                        readonly property real fadeOverlap: settingsView.fadeOverlapAbove(tabAccessibility)
                        property real slideOffset: shown ? 0 : 6

                        Layout.topMargin: -fadeOverlap
                        Layout.bottomMargin: fadeOverlap

                        visible: shown || opacity > 0.001
                        opacity: shown ? 1.0 : 0.0
                        enabled: shown

                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on slideOffset { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        transform: Translate { y: tabAccessibility.slideOffset }

                        // Performance: low-power mode
                        SettingCard {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card13Match
                            title: qsTr("Low-power mode")
                            subtitle: (theme.softwareRendering || core.low_end_hardware)
                                ? qsTr("This computer looks low-end (no GPU acceleration, little memory or few cores), so Auto keeps it on. Disables animations, thumbnail masks and background effects.")
                                : qsTr("Disables animations, thumbnail masks and background effects for older or battery-powered machines")
                            LoafSegmented {
                                Layout.preferredWidth: 220
                                options: [{ value: "auto", label: qsTr("Auto") }, { value: "on", label: qsTr("On") }, { value: "off", label: qsTr("Off") }]
                                value: theme.lowPowerSetting
                                onSelected: function(v) { theme.lowPowerSetting = v; }
                            }
                        }

                        SettingCard {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card14Match
                            title: qsTr("Reduce motion")
                            subtitle: qsTr("Turn off springs, fades and slide transitions")
                            LoafSwitch {
                                checked: theme.reduceMotionSetting
                                onToggled: function(c) { theme.reduceMotionSetting = c; }
                            }
                        }

                        SettingCard {
                            visible: settingsView.searchQuery.length === 0 || settingsView.card15Match
                            title: qsTr("Text size")
                            subtitle: qsTr("Scales all text; also follows the desktop font size")
                            LoafSegmented {
                                Layout.preferredWidth: 260
                                options: [{ value: 0.9, label: "90%" }, { value: 1.0, label: "100%" }, { value: 1.15, label: "115%" }, { value: 1.3, label: "130%" }]
                                value: theme.fontScaleSetting
                                onSelected: function(v) { theme.fontScaleSetting = v; }
                            }
                        }
                    }


                    // ==========================================
                    // TAB 3: EXPERIMENTAL
                    // ==========================================
                    ColumnLayout {
                        id: tabExperimental
                        Layout.fillWidth: true
                        spacing: 14

                        readonly property bool shown: settingsView.searchQuery.length > 0 ? (settingsView.experimentalMatches > 0) : (settingsView.activeTab === 3)
                        readonly property real fadeOverlap: settingsView.fadeOverlapAbove(tabExperimental)
                        property real slideOffset: shown ? 0 : 6

                        Layout.topMargin: -fadeOverlap
                        Layout.bottomMargin: fadeOverlap

                        visible: shown || opacity > 0.001
                        opacity: shown ? 1.0 : 0.0
                        enabled: shown

                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on slideOffset { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        transform: Translate { y: tabExperimental.slideOffset }

                        // More Icon Styles (System & Adwaita)
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: expIconRow.implicitHeight + 32
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: expIconRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("More icon styles"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Enable System desktop theme and GNOME Adwaita vector icons"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
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
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: expArchRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("Advanced Archive Formats"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Enable obscure archive formats (.7z, .tar.bz2, .tar.xz, .tar.zst, .cpio) in Compress menu"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
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
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

                            RowLayout {
                                id: pcCustomRow
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                ColumnLayout {
                                    spacing: 3
                                    Text { text: qsTr("PC customization"); color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                                    Text { text: qsTr("Allow reordering and hiding sections on the This PC dashboard"); color: theme.textMuted; font.pixelSize: theme.fs(11) }
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

                        readonly property bool shown: settingsView.searchQuery.length > 0 ? (settingsView.aboutMatches > 0) : (settingsView.activeTab === 4)
                        readonly property real fadeOverlap: settingsView.fadeOverlapAbove(tabAbout)
                        property real slideOffset: shown ? 0 : 6

                        Layout.topMargin: -fadeOverlap
                        Layout.bottomMargin: fadeOverlap

                        visible: shown || opacity > 0.001
                        opacity: shown ? 1.0 : 0.0
                        enabled: shown

                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on slideOffset { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        transform: Translate { y: tabAbout.slideOffset }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: aboutRow.implicitHeight + 36
                            radius: theme.radiusL
                            color: theme.surfaceContainer
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

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
                                    Text { text: qsTr("Loaf v") + Qt.application.version; color: theme.textMain; font.pixelSize: theme.fs(16); font.bold: true }
                                    Text { text: qsTr("A beautiful and fast Rust-based Material 3 Expressive file manager for Linux."); color: theme.textMuted; font.pixelSize: theme.fs(12) }
                                    RowLayout {
                                        spacing: 6
                                        LoafIcon { name: "github-logo"; size: 14; color: theme.primary }
                                        Text {
                                            id: ghLink
                                            text: qsTr("github.com/m-uvex/loaf-fm  ·  by @m_uvex")
                                            color: ghMouse.containsMouse ? theme.primary : theme.outline
                                            font.pixelSize: theme.fs(11)
                                            font.underline: ghMouse.containsMouse

                                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: 120 } }

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

    // Settings row: title + subtitle on the left, a control on the right.
    component SettingCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        default property alias control: controlSlot.data
        Layout.fillWidth: true
        implicitHeight: cardRow.implicitHeight + 32
        radius: theme.radiusL
        color: theme.surfaceContainer

        RowLayout {
            id: cardRow
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14
            ColumnLayout {
                spacing: 3
                Layout.fillWidth: true
                Text { text: card.title; color: theme.textMain; font.pixelSize: theme.fs(14); font.bold: true }
                Text {
                    text: card.subtitle
                    color: theme.textMuted
                    font.pixelSize: theme.fs(11)
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
            RowLayout { id: controlSlot }
        }
    }
}
