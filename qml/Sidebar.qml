import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// Navigation rail: This PC, Recent, Starred, the user's (localized) folders,
// GTK bookmarks and Trash, from core.places_json. Scrolls when the window is
// short, accepts drops, and every entry has a context menu.
Rectangle {
    id: rail

    property bool expanded: false
    // Id of the highlighted entry ("pc", "settings", "home", "bookmark:/x", ...).
    property string activeId: ""
    property var focusedButton: null
    readonly property bool keyboardHasFocus: focusedButton !== null && focusedButton.activeFocus

    signal placeClicked(var place, bool newTab)
    signal driveClicked(var drive, bool newTab)
    signal settingsClicked()
    signal placeMenuRequested(var place, real x, real y)
    signal driveMenuRequested(var drive, real x, real y)
    signal sidebarMenuRequested(real x, real y)

    readonly property var places: {
        try {
            return JSON.parse(core.places_json || "[]");
        } catch (e) {
            return [];
        }
    }

    readonly property var drives: {
        try {
            return JSON.parse(core.drives_json || "[]");
        } catch (e) {
            return [];
        }
    }

    readonly property var entries: places.filter(function(p) { return p.id !== "trash"; }).concat(
        drives.map(function(d) {
            var iconName = d.icon || (d.provider === "mtp" ? "device-mobile" : (d.is_external ? "usb" : "hard-drive"));
            var sysIcon = d.provider === "mtp" ? "phone-symbolic" : (d.is_external ? "drive-removable-media" : "drive-harddisk");
            return { id: "device:" + d.device, kind: "device", name: d.name,
                icon: iconName,
                system_icon: sysIcon,
                path: d.mount_point, drive: d };
        }))

    readonly property var trashPlace: {
        for (var i = 0; i < places.length; ++i) {
            if (places[i].id === "trash") return places[i];
        }
        return { id: "trash", kind: "trash", name: qsTr("Trash"), path: "trash:///", icon: "trash", system_icon: "user-trash-symbolic" };
    }

    readonly property bool showTrash: !theme.hideTrashWhenEmpty || (typeof core !== "undefined" && core && !core.trash_empty) || (typeof dragManager !== "undefined" && dragManager && dragManager.active)

    radius: theme.radiusXl
    color: theme.backdropSurface(theme.surfaceContainer)
    border.width: 1
    border.color: theme.outlineVariant
    clip: true
    implicitWidth: expanded ? 200 : 68
    Behavior on implicitWidth { enabled: theme.animate; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Sidebar")

    // Right-click empty area of the sidebar to expand/collapse or customize
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.RightButton
        onClicked: function(mouse) {
            var p = mapToItem(window.contentItem, mouse.x, mouse.y);
            rail.sidebarMenuRequested(p.x, p.y);
        }
    }

    // Traveling selection highlight that smoothly glides between places, trash, and settings
    Rectangle {
        id: selectionHighlight
        z: 1
        x: 12
        width: rail.expanded ? (rail.width - 24) : 44
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

    function updateHighlight() {
        if (!rail.activeId || rail.activeId.length === 0) {
            selectionHighlight.targetY = -100;
            return;
        }
        if (rail.activeId === "settings") {
            var pt = settingsBtn.mapToItem(rail, 0, 0);
            selectionHighlight.targetY = pt.y;
            return;
        }
        if (rail.activeId === "trash" && rail.showTrash) {
            var ptTrash = trashContainer.mapToItem(rail, 0, 0);
            selectionHighlight.targetY = ptTrash.y;
            return;
        }
        var filtered = placeList.model || [];
        for (var i = 0; i < filtered.length; ++i) {
            if (filtered[i].id === rail.activeId) {
                var it = placeList.itemAtIndex(i);
                if (it && it.y >= placeList.contentY && it.y + it.height <= placeList.contentY + placeList.height) {
                    var p = it.button.mapToItem(rail, 0, 0);
                    selectionHighlight.targetY = p.y;
                    return;
                }
            }
        }
        selectionHighlight.targetY = -100;
    }

    onActiveIdChanged: Qt.callLater(updateHighlight)
    onShowTrashChanged: Qt.callLater(updateHighlight)
    onExpandedChanged: Qt.callLater(updateHighlight)
    onDrivesChanged: Qt.callLater(updateHighlight)

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 8
        z: 2

        // Expand / collapse header button with animated icon + text
        Item {
            id: headerToggleItem
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            height: 44

            readonly property bool isHovered: toggleMouse.containsMouse

            Rectangle {
                x: 12
                width: rail.expanded ? (parent.width - 24) : 44
                height: 44
                radius: 22
                color: headerToggleItem.isHovered ? theme.hoverOverlay : "transparent"
                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                Behavior on width { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: rail.expanded ? 16 : 12
                spacing: 8

                Item {
                    width: 44
                    height: 44

                    // Two marks that hand over to each other: no spinning, the
                    // sidebar glyph fades out while the Loaf mark fades in.
                    LoafIcon {
                        anchors.centerIn: parent
                        name: "sidebar-simple"
                        size: 20
                        color: theme.textMain
                        opacity: rail.expanded ? 0.0 : 1.0
                        scale: rail.expanded ? 0.65 : 1.0
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                        Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.8; damping: 0.45 } }
                    }

                    LoafIcon {
                        anchors.centerIn: parent
                        name: headerToggleItem.isHovered ? "sidebar" : "bread"
                        size: 20
                        color: theme.primary
                        opacity: rail.expanded ? 1.0 : 0.0
                        scale: rail.expanded ? (headerToggleItem.isHovered ? 1.10 : 1.0) : 0.65
                        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                        Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.0; damping: 0.3 } }
                    }
                }

                Text {
                    visible: opacity > 0.01
                    opacity: rail.expanded ? 1.0 : 0.0
                    scale: rail.expanded ? 1.0 : 0.7
                    transformOrigin: Item.Left
                    transform: Translate {
                        x: rail.expanded ? 0 : -10
                        Behavior on x { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
                    }
                    text: headerToggleItem.isHovered ? qsTr("Collapse") : "Loaf"
                    color: headerToggleItem.isHovered ? theme.primary : theme.textMain
                    font.pixelSize: theme.fs(14)
                    font.bold: !headerToggleItem.isHovered
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180 } }
                    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                }
            }

            MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        var p = mapToItem(window.contentItem, mouse.x, mouse.y);
                        rail.sidebarMenuRequested(p.x, p.y);
                    } else {
                        rail.expanded = !rail.expanded;
                    }
                }
            }
        }

        // Divider between header and places
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            color: theme.separator
            opacity: 0.45
        }

        ListView {
            id: placeList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: rail.entries
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 6 }

            onContentYChanged: Qt.callLater(rail.updateHighlight)
            onCountChanged: Qt.callLater(rail.updateHighlight)
            Component.onCompleted: Qt.callLater(rail.updateHighlight)

            delegate: Item {
                id: entry
                width: placeList.width
                required property var modelData
                required property int index
                readonly property bool isDevice: modelData.kind === "device"
                readonly property real headerHeight: isDevice && (index === 0 || placeList.model[index - 1].kind !== "device")
                    ? 12 : 0
                property alias button: entryButton
                height: 44 + headerHeight
                Rectangle {
                    visible: entry.headerHeight > 0
                    x: 12; width: parent.width - 24; height: 1
                    color: theme.separator; opacity: 0.35
                }
                RailButton {
                    id: entryButton
                    anchors.bottom: parent.bottom
                    width: parent.width
                    iconName: entry.modelData.icon
                    systemIcon: entry.modelData.system_icon
                    label: entry.modelData.name
                    showLabel: rail.expanded
                    selected: rail.activeId === entry.modelData.id
                    dimmed: entry.isDevice ? (entry.modelData.drive.provider !== "mtp" && !entry.modelData.drive.is_mounted)
                        : entry.modelData.missing === true || (entry.modelData.kind === "smb" && entry.modelData.connected !== true)
                    dropPath: entry.isDevice ? (entry.modelData.drive.is_mounted ? entry.modelData.path : "")
                        : ((entry.modelData.kind === "place" || entry.modelData.kind === "bookmark" || (entry.modelData.kind === "smb" && entry.modelData.connected === true)) ? entry.modelData.path : "")
                    accessibleName: label + (entry.isDevice && entry.modelData.drive.provider !== "mtp" && !entry.modelData.drive.is_mounted ? " (" + qsTr("unmounted") + ")" : "")
                    onActiveFocusChanged: if (activeFocus) placeList.positionViewAtIndex(entry.index, ListView.Contain)
                    onClicked: entry.isDevice ? rail.driveClicked(entry.modelData.drive, false) : rail.placeClicked(entry.modelData, false)
                    onMiddleClicked: entry.isDevice ? rail.driveClicked(entry.modelData.drive, true) : rail.placeClicked(entry.modelData, true)
                    onMenuRequested: function(x, y) {
                        if (entry.isDevice) rail.driveMenuRequested(entry.modelData.drive, x, y);
                        else rail.placeMenuRequested(entry.modelData, x, y);
                    }
                    onFilesDropped: function(paths, asCopy, d) {
                        if (dropPath.length > 0) {
                            if (dragManager.isRmb) {
                                var pt = mapToItem(window.contentItem, d.x, d.y);
                                rmbDropMenu.showAt(pt.x, pt.y, paths, dropPath);
                            } else {
                                window.handleDrop(paths, dropPath, asCopy);
                            }
                        }
                    }
                }
            }

            // Drop a folder on the empty part of the rail to bookmark it.
            footer: Item {
                width: placeList.width
                height: 48
                DropArea {
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onDropped: function(drop) {
                        var paths = window.urlsToPaths(drop.urls);
                        for (var i = 0; i < paths.length; ++i)
                            core.add_bookmark(paths[i]);
                        drop.accept(Qt.LinkAction);
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: theme.radiusL
                        color: "transparent"
                        border.width: parent.containsDrag ? 2 : 0
                        border.color: theme.primary
                        Text {
                            visible: parent.parent.containsDrag && rail.expanded
                            anchors.centerIn: parent
                            text: qsTr("Add to sidebar")
                            color: theme.primary
                            font.pixelSize: theme.fs(11)
                        }
                    }
                }
            }
        }

        // Animated Pinned Trash right above Settings
        Item {
            id: trashContainer
            Layout.fillWidth: true
            Layout.preferredHeight: rail.showTrash ? 44 : 0
            visible: Layout.preferredHeight > 0.01
            clip: true
            opacity: rail.showTrash ? 1.0 : 0.0

            Behavior on Layout.preferredHeight { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
            Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            RailButton {
                id: trashButton
                anchors.fill: parent
                iconName: "trash"
                systemIcon: "user-trash-symbolic"
                label: qsTr("Trash")
                showLabel: rail.expanded
                selected: rail.activeId === "trash"
                accessibleName: qsTr("Trash")
                acceptsTrashDrop: true
                onClicked: rail.placeClicked(rail.trashPlace, false)
                onMiddleClicked: rail.placeClicked(rail.trashPlace, true)
                onMenuRequested: function(x, y) { rail.placeMenuRequested(rail.trashPlace, x, y); }
                onFilesDropped: function(paths, asCopy, d) {
                    if (dragManager.isRmb) {
                        var pt = mapToItem(window.contentItem, d.x, d.y);
                        rmbDropMenu.showAt(pt.x, pt.y, paths, "trash");
                    } else {
                        core.trash_items(JSON.stringify(paths));
                    }
                }
            }
        }

        RailButton {
            id: settingsBtn
            Layout.fillWidth: true
            iconName: "gear"
            systemIcon: "preferences-system-symbolic"
            label: qsTr("Settings")
            showLabel: rail.expanded
            selected: rail.activeId === "settings"
            accessibleName: qsTr("Settings")
            onClicked: rail.settingsClicked()
        }
    }

    // One row of the rail (icon + optional label).
    component RailButton: Item {
        id: btn
        property string iconName: "folder"
        property string systemIcon: ""
        property string label: ""
        property bool showLabel: false
        property bool selected: false
        property bool dimmed: false
        property string dropPath: ""
        property bool acceptsTrashDrop: false
        property string accessibleName: label

        signal clicked()
        signal middleClicked()
        signal menuRequested(real x, real y)
        signal filesDropped(var paths, bool asCopy, var dropEvent)

        implicitHeight: 44
        height: 44
        scale: mouse.pressed ? 0.95 : (mouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.0; damping: 0.3 } }
        activeFocusOnTab: true
        onActiveFocusChanged: {
            if (activeFocus)
                rail.focusedButton = btn;
            else if (rail.focusedButton === btn)
                rail.focusedButton = null;
        }
        Keys.onReturnPressed: btn.clicked()
        Keys.onEnterPressed: btn.clicked()
        Keys.onSpacePressed: btn.clicked()
        Accessible.role: Accessible.Button
        Accessible.name: accessibleName
        Accessible.onPressAction: btn.clicked()

        readonly property bool dropHover: drop.containsDrag

        Rectangle {
            x: 12
            width: btn.showLabel ? btn.width - 24 : 44
            height: 44
            radius: 22
            color: btn.dropHover ? theme.primaryContainer
                : (mouse.containsMouse && !btn.selected ? theme.hoverOverlay : "transparent")
            border.width: btn.dropHover || btn.activeFocus ? 2 : 0
            border.color: theme.primary
            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
            Behavior on width { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
        }

        Item {
            id: iconBox
            x: 12
            width: 44
            height: 44
            opacity: btn.dimmed ? 0.45 : 1.0
            scale: mouse.pressed ? 0.88 : (mouse.containsMouse ? 1.10 : 1.0)
            Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 4.5; damping: 0.3 } }

            LoafIcon {
                visible: theme.iconSource === "phosphor" || btn.systemIcon.length === 0
                anchors.centerIn: parent
                name: btn.iconName
                size: 20
                color: btn.selected ? theme.primaryContainerFg : (mouse.containsMouse ? theme.textMain : theme.textMuted)
            }
            Image {
                visible: theme.iconSource !== "phosphor" && btn.systemIcon.length > 0
                anchors.centerIn: parent
                source: visible ? window.systemIcon(btn.systemIcon) : ""
                width: 20
                height: 20
                sourceSize.width: 40
                sourceSize.height: 40
                fillMode: Image.PreserveAspectFit
            }
        }

        Text {
            anchors.left: iconBox.right
            anchors.leftMargin: 6
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: opacity > 0.01
            opacity: btn.showLabel ? (btn.dimmed ? 0.5 : 1.0) : 0.0
            scale: btn.showLabel ? 1.0 : 0.4
            transformOrigin: Item.Left
            transform: Translate {
                x: btn.showLabel ? 0 : -14
                Behavior on x { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
            }
            Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: 160 } }
            Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.35 } }
            text: btn.label
            color: btn.selected ? theme.primaryContainerFg : (mouse.containsMouse ? theme.textMain : theme.textMuted)
            font.pixelSize: theme.fs(13)
            font.bold: btn.selected
            elide: Text.ElideRight
        }

        ToolTip.visible: !btn.showLabel && mouse.containsMouse && btn.label.length > 0
        ToolTip.text: btn.label
        ToolTip.delay: 500

        DropArea {
            id: drop
            anchors.fill: parent
            enabled: btn.dropPath.length > 0 || btn.acceptsTrashDrop
            keys: ["text/uri-list"]
            onDropped: function(d) {
                var paths = window.urlsToPaths(d.urls);
                if (paths.length === 0)
                    return;
                var asCopy = (d.source === dragProxy) ? dragManager.asCopy : (d.proposedAction === Qt.CopyAction);
                d.accept(asCopy ? Qt.CopyAction : Qt.MoveAction);
                btn.filesDropped(paths, asCopy, d);
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: function(m) {
                if (m.button === Qt.RightButton) {
                    var p = mapToItem(window.contentItem, m.x, m.y);
                    btn.menuRequested(p.x, p.y);
                } else if (m.button === Qt.MiddleButton) {
                    btn.middleClicked();
                } else {
                    btn.clicked();
                }
            }
        }
    }
}
