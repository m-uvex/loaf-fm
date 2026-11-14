import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

Item {
    id: settingsView

    property int activeTab: 0
    property string searchQuery: ""
    signal searchCleared()
    signal openNetworkEditorRequested(var profile)
    signal removeNetworkDriveRequested(string id, string label)

    readonly property bool isCompact: width < 660

    // Main tabs displayed in the scrollable list
    readonly property var mainTabsModel: {
        var t = [
            { id: "interface", index: 0, name: qsTr("Interface"), iconName: "palette", subtitle: qsTr("Theme, appearance, top bar and icon styling") },
            { id: "behavior", index: 1, name: qsTr("Behavior"), iconName: "gear", subtitle: qsTr("Folder opening, drag behavior, and session restore") },
            { id: "accessibility", index: 2, name: qsTr("Accessibility"), iconName: "person-arms-spread", subtitle: qsTr("Performance, motion, scaling and background effects") }
        ];
        if (theme.shareViaLinkEnabled) {
            t.push({ id: "share", index: 5, name: qsTr("Share"), iconName: "share-network", subtitle: qsTr("Cloudflare tunnel file hosting and active streams") });
        }
        t.push({ id: "network", index: 6, name: qsTr("Network"), iconName: "network", subtitle: qsTr("Saved network drives and auto discovery") });
        t.push({ id: "experimental", index: 3, name: qsTr("Experimental"), iconName: "sparkle", subtitle: qsTr("Preview features, advanced archives and link sharing") });
        t.push({ id: "shortcuts", index: 7, name: qsTr("Shortcuts"), iconName: "keyboard", subtitle: qsTr("Customize keyboard shortcuts across Loaf") });
        return t;
    }

    readonly property var allTabsModel: {
        var all = [].concat(mainTabsModel);
        all.push({ id: "about", index: 4, name: qsTr("About Loaf"), iconName: "bread", subtitle: qsTr("Version info, credits, and links") });
        return all;
    }

    readonly property var currentTabInfo: {
        for (var i = 0; i < allTabsModel.length; ++i) {
            if (allTabsModel[i].index === activeTab) return allTabsModel[i];
        }
        return allTabsModel[0];
    }

    readonly property int totalMatches: tabInterface.matchCount
        + tabBehavior.matchCount
        + tabAccessibility.matchCount
        + tabExperimental.matchCount
        + (theme.shareViaLinkEnabled ? tabShare.matchCount : 0)
        + tabNetwork.matchCount
        + tabShortcuts.matchCount
        + tabAbout.matchCount

    function getTabMatchCount(tabId) {
        if (tabId === "interface") return tabInterface.matchCount;
        if (tabId === "behavior") return tabBehavior.matchCount;
        if (tabId === "accessibility") return tabAccessibility.matchCount;
        if (tabId === "experimental") return tabExperimental.matchCount;
        if (tabId === "share") return tabShare.matchCount;
        if (tabId === "network") return tabNetwork.matchCount;
        if (tabId === "shortcuts") return tabShortcuts.matchCount;
        if (tabId === "about") return tabAbout.matchCount;
        return 0;
    }

    function updateHighlight() {
        if (settingsView.activeTab === 4) {
            var ptAbout = aboutNavBtn.mapToItem(navRail, 0, 0);
            selectionHighlight.targetY = ptAbout.y;
            return;
        }
        var m = mainTabsModel || [];
        for (var i = 0; i < m.length; ++i) {
            if (m[i].index === settingsView.activeTab) {
                var it = tabNavList.itemAtIndex(i);
                if (it) {
                    var p = it.mapToItem(navRail, 0, 0);
                    selectionHighlight.targetY = p.y;
                    return;
                }
            }
        }
        selectionHighlight.targetY = -100;
    }

    onActiveTabChanged: Qt.callLater(updateHighlight)
    onIsCompactChanged: Qt.callLater(updateHighlight)

    RowLayout {
        anchors.fill: parent
        spacing: settingsView.isCompact ? 10 : 16

        // Left Navigation Rail (Matches main Sidebar architecture)
        Rectangle {
            id: navRail
            Layout.fillHeight: true
            Layout.preferredWidth: settingsView.isCompact ? 68 : Math.max(160, Math.min(220, parent.width * 0.28))
            radius: theme.radiusXl
            color: theme.backdropSurface(theme.surfaceContainer)
            clip: true

            Behavior on Layout.preferredWidth {
                enabled: theme.animate
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }
            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

            // Traveling selection highlight that smoothly glides with spring animation
            Rectangle {
                id: selectionHighlight
                z: 1
                x: 12
                width: settingsView.isCompact ? 44 : (navRail.width - 24)
                height: 44
                radius: 22
                color: theme.primaryContainer
                visible: opacity > 0.01
                opacity: targetY >= 0 ? 1.0 : 0.0
                property real targetY: -100
                y: targetY

                Behavior on y {
                    enabled: theme.animate
                    SpringAnimation { spring: 4.2; damping: 0.38 }
                }
                Behavior on width {
                    enabled: theme.animate
                    SpringAnimation { spring: 3.5; damping: 0.35 }
                }
                Behavior on opacity {
                    enabled: theme.animate
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 14
                anchors.bottomMargin: 14
                spacing: 8
                z: 2

                // Header block (Icon + Settings Title)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    height: 44

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: settingsView.isCompact ? 12 : 16
                        spacing: 8

                        Item {
                            width: 44
                            height: 44

                            LoafIcon {
                                anchors.centerIn: parent
                                name: "gear"
                                size: 20
                                color: theme.primary
                            }
                        }

                        Text {
                            visible: !settingsView.isCompact
                            text: qsTr("Settings")
                            color: theme.textMain
                            font.pixelSize: theme.fs(14)
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // Top Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    color: theme.separator
                }

                // Scrollable Category Tabs List (matches Sidebar.qml ListView)
                ListView {
                    id: tabNavList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: settingsView.mainTabsModel
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                    onContentYChanged: settingsView.updateHighlight()
                    onCountChanged: Qt.callLater(settingsView.updateHighlight)
                    Component.onCompleted: Qt.callLater(settingsView.updateHighlight)

                    delegate: Item {
                        id: tabItem
                        width: tabNavList.width
                        height: 44

                        readonly property bool isCurrent: modelData.index === settingsView.activeTab
                        readonly property bool isHovered: tabMouse.containsMouse
                        readonly property int tabMatches: settingsView.getTabMatchCount(modelData.id)

                        scale: tabMouse.pressed ? 0.95 : (tabMouse.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.0; damping: 0.3 } }

                        Rectangle {
                            x: 12
                            width: settingsView.isCompact ? 44 : (tabItem.width - 24)
                            height: 44
                            radius: 22
                            color: (tabItem.isHovered && !tabItem.isCurrent) ? theme.hoverOverlay : "transparent"
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                            Behavior on width { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
                        }

                        Item {
                            id: iconContainer
                            x: 12
                            width: 44
                            height: 44
                            scale: tabMouse.pressed ? 0.88 : (tabMouse.containsMouse ? 1.10 : 1.0)
                            Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.5; damping: 0.3 } }

                            LoafIcon {
                                anchors.centerIn: parent
                                name: modelData.iconName
                                size: 20
                                color: tabItem.isCurrent ? theme.primaryContainerFg : (tabItem.isHovered ? theme.textMain : theme.textMuted)
                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                            }

                            // Compact search match indicator
                            Rectangle {
                                visible: settingsView.isCompact && settingsView.searchQuery.length > 0 && tabMatches > 0
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 4
                                anchors.rightMargin: 4
                                width: 8
                                height: 8
                                radius: 4
                                color: tabItem.isCurrent ? theme.textMain : theme.primary
                            }
                        }

                        Text {
                            anchors.left: iconContainer.right
                            anchors.leftMargin: 8
                            anchors.right: badgeContainer.visible ? badgeContainer.left : parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !settingsView.isCompact
                            text: modelData.name
                            color: tabItem.isCurrent ? theme.primaryContainerFg : (tabItem.isHovered ? theme.textMain : theme.textMuted)
                            font.pixelSize: theme.fs(13)
                            font.bold: tabItem.isCurrent
                            font.family: theme.fontFamily
                            elide: Text.ElideRight
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                        }

                        Rectangle {
                            id: badgeContainer
                            visible: !settingsView.isCompact && settingsView.searchQuery.length > 0 && tabMatches > 0
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            radius: theme.radiusFull
                            color: isCurrent ? theme.surfaceContainerHighest : theme.primaryContainer
                            implicitHeight: 20
                            implicitWidth: badgeTxt.implicitWidth + 10

                            Text {
                                id: badgeTxt
                                anchors.centerIn: parent
                                text: tabMatches.toString()
                                color: isCurrent ? theme.textMain : theme.primaryContainerFg
                                font.pixelSize: theme.fs(10)
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (settingsView.isCompact) tooltip.show(tabMouse, modelData.name)
                            onExited: tooltip.hide(tabMouse)
                            onClicked: {
                                if (settingsView.searchQuery.length > 0) {
                                    settingsView.searchCleared();
                                    settingsView.searchQuery = "";
                                }
                                settingsView.activeTab = modelData.index;
                            }
                        }
                    }
                }

                // Bottom Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    color: theme.separator
                }

                // Bottom Pinned: About Loaf Button (Matches main Sidebar Settings position)
                Item {
                    id: aboutNavBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    height: 44

                    readonly property bool isCurrent: settingsView.activeTab === 4
                    readonly property bool isHovered: aboutMouse.containsMouse
                    readonly property int aboutMatches: settingsView.getTabMatchCount("about")

                    scale: aboutMouse.pressed ? 0.95 : (aboutMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.0; damping: 0.3 } }

                    Rectangle {
                        x: 12
                        width: settingsView.isCompact ? 44 : (aboutNavBtn.width - 24)
                        height: 44
                        radius: 22
                        color: (aboutNavBtn.isHovered && !aboutNavBtn.isCurrent) ? theme.hoverOverlay : "transparent"
                        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                        Behavior on width { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
                    }

                    Item {
                        id: aboutIconBox
                        x: 12
                        width: 44
                        height: 44
                        scale: aboutMouse.pressed ? 0.88 : (aboutMouse.containsMouse ? 1.10 : 1.0)
                        Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.5; damping: 0.3 } }

                        LoafIcon {
                            anchors.centerIn: parent
                            name: "bread"
                            size: 20
                            color: aboutNavBtn.isCurrent ? theme.primaryContainerFg : (aboutMouse.containsMouse ? theme.textMain : theme.textMuted)
                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                        }

                        // Compact search indicator
                        Rectangle {
                            visible: settingsView.isCompact && settingsView.searchQuery.length > 0 && aboutNavBtn.aboutMatches > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 4
                            anchors.rightMargin: 4
                            width: 8
                            height: 8
                            radius: 4
                            color: aboutNavBtn.isCurrent ? theme.textMain : theme.primary
                        }
                    }

                    Text {
                        anchors.left: aboutIconBox.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !settingsView.isCompact
                        text: qsTr("About Loaf")
                        color: aboutNavBtn.isCurrent ? theme.primaryContainerFg : (aboutMouse.containsMouse ? theme.textMain : theme.textMuted)
                        font.pixelSize: theme.fs(13)
                        font.bold: aboutNavBtn.isCurrent
                        elide: Text.ElideRight
                        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                    }

                    MouseArea {
                        id: aboutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (settingsView.isCompact) tooltip.show(aboutMouse, qsTr("About Loaf"))
                        onExited: tooltip.hide(aboutMouse)
                        onClicked: {
                            if (settingsView.searchQuery.length > 0) {
                                settingsView.searchCleared();
                                settingsView.searchQuery = "";
                            }
                            settingsView.activeTab = 4;
                        }
                    }
                }
            }
        }

        // Right Content View
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: theme.radiusL
            color: theme.backdropSurface(theme.surfaceContainerLow)
            clip: true

            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

            ScrollView {
                id: contentScroll
                anchors.fill: parent
                anchors.margins: settingsView.isCompact ? 14 : 22
                clip: true
                contentWidth: availableWidth

                ColumnLayout {
                    id: contentColumn
                    width: contentScroll.availableWidth
                    spacing: settingsView.isCompact ? 14 : 20

                    // Header Block
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: settingsView.isCompact ? 2 : 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            LoafIcon {
                                visible: settingsView.searchQuery.length === 0 && currentTabInfo.iconName.length > 0
                                name: currentTabInfo.iconName
                                size: settingsView.isCompact ? 22 : 26
                                color: theme.primary
                            }

                            Text {
                                text: settingsView.searchQuery.length > 0
                                    ? qsTr("Settings search results")
                                    : currentTabInfo.name
                                color: theme.textMain
                                font.pixelSize: settingsView.isCompact ? theme.fs(20) : theme.fs(24)
                                font.bold: true
                                font.letterSpacing: -0.5
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                visible: settingsView.searchQuery.length > 0 && settingsView.totalMatches > 0
                                height: 26
                                radius: theme.radiusFull
                                color: theme.primaryContainer
                                implicitWidth: summaryCountTxt.implicitWidth + 16

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

                        Text {
                            visible: !settingsView.isCompact && settingsView.searchQuery.length === 0 && currentTabInfo.subtitle.length > 0
                            text: currentTabInfo.subtitle
                            color: theme.textMuted
                            font.pixelSize: theme.fs(12)
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }

                    // Empty Search Result State
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 40
                        Layout.bottomMargin: 40
                        visible: settingsView.searchQuery.length > 0 && settingsView.totalMatches === 0
                        spacing: 14

                        LoafIcon {
                            Layout.alignment: Qt.AlignHCenter
                            name: "magnifying-glass"
                            size: 48
                            color: theme.textMuted
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("No settings found matching \"") + settingsView.searchQuery + "\""
                            color: theme.textMuted
                            font.pixelSize: theme.fs(14)
                            font.bold: true
                        }

                        LoafButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Clear search")
                            icon: "x"
                            variant: "tonal"
                            onClicked: {
                                settingsView.searchCleared();
                                settingsView.searchQuery = "";
                            }
                        }
                    }

                    // Tab 0: Interface
                    InterfaceTab {
                        id: tabInterface
                        searchQuery: settingsView.searchQuery
                        visible: settingsView.searchQuery.length > 0
                            ? (tabInterface.matchCount > 0)
                            : (settingsView.activeTab === 0)
                        opacity: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 0) ? 1.0 : 0.0
                        transform: Translate {
                            y: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 0) ? 0 : 8
                            Behavior on y { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    // Tab 1: Behavior
                    BehaviorTab {
                        id: tabBehavior
                        searchQuery: settingsView.searchQuery
                        visible: settingsView.searchQuery.length > 0
                            ? (tabBehavior.matchCount > 0)
                            : (settingsView.activeTab === 1)
                        opacity: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 1) ? 1.0 : 0.0
                        transform: Translate {
                            y: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 1) ? 0 : 8
                            Behavior on y { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    // Tab 2: Accessibility
                    AccessibilityTab {
                        id: tabAccessibility
                        searchQuery: settingsView.searchQuery
                        visible: settingsView.searchQuery.length > 0
                            ? (tabAccessibility.matchCount > 0)
                            : (settingsView.activeTab === 2)
                        opacity: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 2) ? 1.0 : 0.0
                        transform: Translate {
                            y: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 2) ? 0 : 8
                            Behavior on y { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    // Tab 5: Share (only when Cloudflare sharing is enabled)
                    ShareTab {
                        id: tabShare
                        searchQuery: settingsView.searchQuery
                        visible: theme.shareViaLinkEnabled
                            && (settingsView.searchQuery.length > 0
                                ? (tabShare.matchCount > 0)
                                : (settingsView.activeTab === 5))
                        opacity: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 5) ? 1.0 : 0.0
                        transform: Translate {
                            y: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 5) ? 0 : 8
                            Behavior on y { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    // Tab 6: Network
                    NetworkTab {
                        id: tabNetwork
                        searchQuery: settingsView.searchQuery
                        onOpenNetworkEditorRequested: function(p) { settingsView.openNetworkEditorRequested(p); }
                        onRemoveNetworkDriveRequested: function(id, l) { settingsView.removeNetworkDriveRequested(id, l); }
                        visible: settingsView.searchQuery.length > 0
                            ? (tabNetwork.matchCount > 0)
                            : (settingsView.activeTab === 6)
                        opacity: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 6) ? 1.0 : 0.0
                        transform: Translate {
                            y: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 6) ? 0 : 8
                            Behavior on y { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    // Tab 3: Experimental
                    ExperimentalTab {
                        id: tabExperimental
                        searchQuery: settingsView.searchQuery
                        visible: settingsView.searchQuery.length > 0
                            ? (tabExperimental.matchCount > 0)
                            : (settingsView.activeTab === 3)
                        opacity: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 3) ? 1.0 : 0.0
                        transform: Translate {
                            y: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 3) ? 0 : 8
                            Behavior on y { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    // Tab 7: Shortcuts
                    ShortcutsTab {
                        id: tabShortcuts
                        searchQuery: settingsView.searchQuery
                        visible: settingsView.searchQuery.length > 0
                            ? (tabShortcuts.matchCount > 0)
                            : (settingsView.activeTab === 7)
                        opacity: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 7) ? 1.0 : 0.0
                        transform: Translate {
                            y: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 7) ? 0 : 8
                            Behavior on y { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    // Tab 4: About
                    AboutTab {
                        id: tabAbout
                        searchQuery: settingsView.searchQuery
                        visible: settingsView.searchQuery.length > 0
                            ? (tabAbout.matchCount > 0)
                            : (settingsView.activeTab === 4)
                        opacity: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 4) ? 1.0 : 0.0
                        transform: Translate {
                            y: (settingsView.searchQuery.length > 0 || settingsView.activeTab === 4) ? 0 : 8
                            Behavior on y { enabled: theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
