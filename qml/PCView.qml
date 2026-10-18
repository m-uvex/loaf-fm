import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// PC Dashboard: hostname header with device type icon, plus reorderable /
// customizable sections (places, frequent, internal storage summary + drives,
// external drives). Drive rows are rendered with the shared DriveCard; all
// controls come from the shared component library (SectionHeader, LoafButton,
// LoafCard, UsageBar, LoafMenu, LoafTextPrompt).
Item {
    id: pcView

    // ---- customization model -----------------------------------------------

    readonly property var knownSections: ["places", "frequent", "internal", "external"]

    property var sectionOrder: ["places", "frequent", "internal", "external"]
    property var sectionConfig: pcView.defaultConfig()
    property bool isCustomizing: false

    readonly property bool customizationEnabled: theme.experimentalPcCustomization === true
    readonly property bool customizing: pcView.customizationEnabled && pcView.isCustomizing

    onCustomizationEnabledChanged: {
        if (!pcView.customizationEnabled)
            pcView.isCustomizing = false;
    }

    function defaultConfig() {
        return {
            "places": { visible: true, view: "grid" },
            "frequent": { visible: true, view: "carousel" },
            "internal": { visible: true, view: "cards" },
            "external": { visible: true, view: "cards" }
        };
    }

    function normalizeOrder(saved) {
        var out = [];
        if (saved && saved.length) {
            for (var i = 0; i < saved.length; i++) {
                if (pcView.knownSections.indexOf(saved[i]) !== -1 && out.indexOf(saved[i]) === -1)
                    out.push(saved[i]);
            }
        }
        for (var j = 0; j < pcView.knownSections.length; j++) {
            if (out.indexOf(pcView.knownSections[j]) === -1)
                out.push(pcView.knownSections[j]);
        }
        return out;
    }

    function normalizeConfig(saved) {
        var base = pcView.defaultConfig();
        if (saved && typeof saved === "object") {
            for (var k in base) {
                if (saved[k] && typeof saved[k] === "object") {
                    if (saved[k].visible !== undefined)
                        base[k].visible = saved[k].visible !== false;
                    if (saved[k].view === "carousel" || saved[k].view === "grid")
                        base[k].view = saved[k].view;
                }
            }
        }
        return base;
    }

    function sectionVisible(secKey) {
        var cfg = pcView.sectionConfig[secKey];
        return cfg ? cfg.visible !== false : true;
    }

    function sectionView(secKey) {
        var cfg = pcView.sectionConfig[secKey];
        return (cfg && cfg.view === "carousel") ? "carousel" : "grid";
    }

    // A section only exists when it has something to show. External Storage in
    // particular must never appear (not even while customizing) with no drives.
    function sectionExists(secKey) {
        if (secKey === "external")
            return pcView.externalDrives.length > 0;
        if (secKey === "internal")
            return pcView.internalDrives.length > 0;
        return true;
    }

    function saveCustomization() {
        engine.set_setting("pcSectionOrder", JSON.stringify(pcView.sectionOrder));
        engine.set_setting("pcSectionConfig", JSON.stringify(pcView.sectionConfig));
    }

    function moveSection(secId, direction) {
        var idx = pcView.sectionOrder.indexOf(secId);
        if (idx === -1)
            return;
        var newIdx = idx + direction;
        if (newIdx < 0 || newIdx >= pcView.sectionOrder.length)
            return;
        var copy = pcView.sectionOrder.slice();
        var temp = copy[idx];
        copy[idx] = copy[newIdx];
        copy[newIdx] = temp;
        pcView.sectionOrder = copy;
        pcView.saveCustomization();
    }

    function toggleSectionVisibility(secId) {
        var copy = Object.assign({}, pcView.sectionConfig);
        var entry = Object.assign({}, copy[secId]);
        entry.visible = !(entry.visible !== false);
        copy[secId] = entry;
        pcView.sectionConfig = copy;
        pcView.saveCustomization();
    }

    function toggleSectionView(secId) {
        var copy = Object.assign({}, pcView.sectionConfig);
        var entry = Object.assign({}, copy[secId]);
        entry.view = (entry.view === "carousel") ? "grid" : "carousel";
        copy[secId] = entry;
        pcView.sectionConfig = copy;
        pcView.saveCustomization();
    }

    // ---- drive data --------------------------------------------------------

    readonly property var allDrives: {
        try {
            return JSON.parse(engine.drives_json || "[]");
        } catch (e) {
            return [];
        }
    }
    readonly property var internalDrives: pcView.allDrives.filter(function (d) {
        return !d.is_external;
    })
    readonly property var externalDrives: pcView.allDrives.filter(function (d) {
        return d.is_external;
    })
    readonly property var frequentDirs: {
        try {
            return JSON.parse(engine.frequent_dirs_json || "[]");
        } catch (e) {
            return [];
        }
    }

    readonly property real totalInternalBytes: pcView.internalDrives.reduce(function (acc, d) {
        return acc + (d.total_bytes || 0);
    }, 0)
    readonly property real usedInternalBytes: pcView.internalDrives.reduce(function (acc, d) {
        return acc + (d.used_bytes || 0);
    }, 0)
    readonly property real freeInternalBytes: Math.max(0, pcView.totalInternalBytes - pcView.usedInternalBytes)
    readonly property real overallUsage: pcView.totalInternalBytes > 0 ? (pcView.usedInternalBytes / pcView.totalInternalBytes) : 0

    function formatBytes(bytes) {
        var b = Number(bytes) || 0;
        var gb = 1024 * 1024 * 1024;
        var tb = 1024 * gb;
        var mb = 1024 * 1024;
        if (b >= tb)
            return (b / tb).toFixed(1) + " TB";
        if (b >= gb)
            return (b / gb).toFixed(1) + " GB";
        if (b >= mb)
            return (b / mb).toFixed(1) + " MB";
        if (b > 0)
            return (b / 1024).toFixed(0) + " KB";
        return "0 B";
    }

    // Responsive column count: reflows to the available width.
    function columnCount(minCellWidth) {
        return Math.max(1, Math.floor(pcFlick.width / minCellWidth));
    }

    function isMounted(d) {
        if (!d)
            return false;
        if (d.mounted !== undefined)
            return d.mounted === true;
        return d.is_mounted === true;
    }

    // ---- drive actions -----------------------------------------------------

    function openDrive(d) {
        if (pcView.isMounted(d)) {
            window.showFiles();
            engine.set_path(d.mount_point);
        } else {
            pcView.mountDrive(d);
        }
    }

    function mountDrive(d) {
        if (!d)
            return;
        engine.mount_drive(d.device);
        engine.load_drives();
    }

    function unmountDrive(d) {
        if (!d)
            return;
        engine.unmount_drive(d.device);
        engine.load_drives();
    }

    property string renameDevice: ""
    property var menuDrive: ({})

    function requestRename(d) {
        if (!d)
            return;
        pcView.renameDevice = d.device;
        renamePrompt.initialText = d.name;
        renamePrompt.label = d.name;
        renamePrompt.open();
    }

    function driveMenuModel(d) {
        var mounted = pcView.isMounted(d);
        var external = d && d.is_external === true;
        var items = [];

        items.push({
            "text": "Open",
            "icon": "folder-open",
            "enabled": mounted,
            "action": function () { pcView.openDrive(d); }
        });
        if (!mounted) {
            items.push({
                "text": "Mount",
                "icon": "download",
                "separatorBefore": true,
                "action": function () { pcView.mountDrive(d); }
            });
        }
        if (mounted) {
            items.push({
                "text": "Unmount",
                "icon": "eject",
                "separatorBefore": true,
                "action": function () { pcView.unmountDrive(d); }
            });
        }
        items.push({
            "text": "Rename",
            "icon": "pencil-simple",
            "separatorBefore": true,
            "action": function () { pcView.requestRename(d); }
        });
        if (external) {
            items.push({
                "text": "Eject",
                "icon": "eject",
                "danger": true,
                "enabled": mounted,
                "separatorBefore": true,
                "action": function () { pcView.unmountDrive(d); }
            });
        }
        return items;
    }

    function openDriveMenu(d, sceneX, sceneY) {
        pcView.menuDrive = d;
        driveMenu.model = pcView.driveMenuModel(d);
        driveMenu.openAt(sceneX, sceneY);
    }

    Component.onCompleted: {
        try {
            var order = engine.get_setting("pcSectionOrder");
            if (order && order.length > 0)
                pcView.sectionOrder = pcView.normalizeOrder(JSON.parse(order));
        } catch (e) {}
        try {
            var cfg = engine.get_setting("pcSectionConfig");
            if (cfg && cfg.length > 0)
                pcView.sectionConfig = pcView.normalizeConfig(JSON.parse(cfg));
        } catch (e) {}
    }

    // =========================================================================
    // LAYOUT
    // =========================================================================

    Flickable {
        id: pcFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: pcCol.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: pcCol
            width: pcFlick.width
            spacing: 24

            // ===== Unified Header: hostname & device type icon =====
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 22
                    color: theme.primaryContainer
                    LoafIcon {
                        anchors.centerIn: parent
                        name: engine.device_type === "laptop" ? "laptop" : "desktop"
                        size: 22
                        color: theme.primaryContainerFg
                    }
                }

                Text {
                    text: engine.hostname || "This PC"
                    color: theme.textMain
                    font.pixelSize: 26
                    font.bold: true
                    font.letterSpacing: -0.5
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Customize / Done (only when the experimental flag is enabled).
                LoafButton {
                    id: customizeBtn
                    visible: pcView.customizationEnabled
                    text: pcView.customizing ? "Done" : "Customize"
                    icon: pcView.customizing ? "check" : "sliders-horizontal"
                    variant: pcView.customizing ? "tonal" : "outlined"
                    onClicked: pcView.isCustomizing = !pcView.isCustomizing
                }
            }

            // ===== SECTIONS (Reorderable) =====
            Repeater {
                model: pcView.sectionOrder

                delegate: ColumnLayout {
                    id: sectionDelegate

                    Layout.fillWidth: true
                    spacing: 12
                    visible: pcView.sectionExists(modelData)
                             && (pcView.sectionVisible(modelData) || pcView.customizing)

                    property string secKey: modelData
                    property bool secVisible: pcView.sectionVisible(modelData)
                    property string secView: pcView.sectionView(modelData)

                    // ----- Section header + customization controls -----
                    SectionHeader {
                        Layout.fillWidth: true
                        icon: sectionDelegate.secKey === "places" ? "folder"
                              : (sectionDelegate.secKey === "frequent" ? "clock"
                              : (sectionDelegate.secKey === "internal" ? "hard-drives" : "usb"))
                        title: sectionDelegate.secKey === "places" ? "Places"
                               : (sectionDelegate.secKey === "frequent" ? "Frequent"
                               : (sectionDelegate.secKey === "internal" ? "Internal Storage" : "External Storage"))
                        subtitle: sectionDelegate.secKey === "external"
                                  ? (pcView.externalDrives.length + (pcView.externalDrives.length === 1 ? " drive connected" : " drives connected"))
                                  : ""

                        // View mode toggle (places / frequent only)
                        LoafButton {
                            visible: pcView.customizing
                                     && (sectionDelegate.secKey === "places" || sectionDelegate.secKey === "frequent")
                            text: sectionDelegate.secView === "carousel" ? "Carousel" : "Grid"
                            icon: sectionDelegate.secView === "carousel" ? "list" : "squares-four"
                            variant: "tonal"
                            onClicked: pcView.toggleSectionView(sectionDelegate.secKey)
                        }

                        LoafButton {
                            visible: pcView.customizing
                            icon: "caret-up"
                            variant: "text"
                            onClicked: pcView.moveSection(sectionDelegate.secKey, -1)
                        }

                        LoafButton {
                            visible: pcView.customizing
                            icon: "caret-down"
                            variant: "text"
                            onClicked: pcView.moveSection(sectionDelegate.secKey, 1)
                        }

                        LoafButton {
                            visible: pcView.customizing
                            icon: sectionDelegate.secVisible ? "x" : "plus"
                            variant: sectionDelegate.secVisible ? "text" : "tonal"
                            onClicked: pcView.toggleSectionVisibility(sectionDelegate.secKey)
                        }
                    }

                    // ----- Dashed restore strip when a section is hidden -----
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        visible: pcView.customizing && !sectionDelegate.secVisible
                        radius: theme.radiusM
                        color: "transparent"
                        border.color: theme.outline
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 12
                            Text {
                                text: "Section hidden"
                                color: theme.textMuted
                                font.pixelSize: 12
                            }
                            LoafButton {
                                text: "Restore"
                                icon: "plus"
                                variant: "tonal"
                                onClicked: pcView.toggleSectionVisibility(sectionDelegate.secKey)
                            }
                        }
                    }

                    // ==========================================
                    // SECTION: PLACES
                    // ==========================================
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: sectionDelegate.secView === "carousel" ? 54 : placesGrid.implicitHeight
                        visible: sectionDelegate.secVisible && sectionDelegate.secKey === "places"

                        GridLayout {
                            id: placesGrid
                            visible: sectionDelegate.secView !== "carousel"
                            anchors.fill: parent
                            columns: pcView.columnCount(170)
                            columnSpacing: 10
                            rowSpacing: 10

                            Repeater {
                                model: [
                                    { name: "Home", iconName: "house", pathSuffix: "" },
                                    { name: "Documents", iconName: "file-text", pathSuffix: "Documents" },
                                    { name: "Downloads", iconName: "download", pathSuffix: "Downloads" },
                                    { name: "Pictures", iconName: "image", pathSuffix: "Pictures" },
                                    { name: "Music", iconName: "music", pathSuffix: "Music" },
                                    { name: "Videos", iconName: "video", pathSuffix: "Videos" },
                                    { name: "Projects", iconName: "code", pathSuffix: "Projects" }
                                ]

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 52
                                    radius: theme.radiusL
                                    color: theme.surfaceContainer
                                    opacity: placeMouse.containsMouse ? 1.0 : 0.85
                                    scale: placeMouse.pressed ? 0.96 : (placeMouse.containsMouse ? 1.02 : 1.0)
                                    Behavior on opacity { NumberAnimation { duration: theme.durationFast } }
                                    Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.32 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 10

                                        LoafIcon {
                                            name: modelData.iconName
                                            size: 20
                                            color: theme.primary
                                        }
                                        Text {
                                            text: modelData.name
                                            color: theme.textMain
                                            font.pixelSize: 13
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: placeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var homeBase = "/home/" + (engine.current_path.split("/")[2] || "m_uvex");
                                            var target = modelData.pathSuffix === "" ? homeBase : (homeBase + "/" + modelData.pathSuffix);
                                            window.showFiles(index + 1);
                                            engine.set_path(target);
                                        }
                                    }
                                }
                            }
                        }

                        ListView {
                            visible: sectionDelegate.secView === "carousel"
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: 10
                            clip: true

                            model: [
                                { name: "Home", iconName: "house", pathSuffix: "" },
                                { name: "Documents", iconName: "file-text", pathSuffix: "Documents" },
                                { name: "Downloads", iconName: "download", pathSuffix: "Downloads" },
                                { name: "Pictures", iconName: "image", pathSuffix: "Pictures" },
                                { name: "Music", iconName: "music", pathSuffix: "Music" },
                                { name: "Videos", iconName: "video", pathSuffix: "Videos" },
                                { name: "Projects", iconName: "code", pathSuffix: "Projects" }
                            ]

                            delegate: Rectangle {
                                width: 140
                                height: 50
                                radius: theme.radiusL
                                color: theme.surfaceContainer
                                opacity: cPlaceMouse.containsMouse ? 1.0 : 0.85
                                scale: cPlaceMouse.pressed ? 0.95 : 1.0
                                Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    LoafIcon { name: modelData.iconName; size: 18; color: theme.primary }
                                    Text { text: modelData.name; color: theme.textMain; font.pixelSize: 12; font.bold: true }
                                }

                                MouseArea {
                                    id: cPlaceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var homeBase = "/home/" + (engine.current_path.split("/")[2] || "m_uvex");
                                        var target = modelData.pathSuffix === "" ? homeBase : (homeBase + "/" + modelData.pathSuffix);
                                        window.showFiles(index + 1);
                                        engine.set_path(target);
                                    }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // SECTION: FREQUENT
                    // ==========================================
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: sectionDelegate.secView === "grid" ? freqGrid.implicitHeight : 48
                        visible: sectionDelegate.secVisible && sectionDelegate.secKey === "frequent"

                        ListView {
                            visible: sectionDelegate.secView !== "grid"
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: 10
                            clip: true

                            model: pcView.frequentDirs

                            delegate: Rectangle {
                                width: freqCardRow.implicitWidth + 24
                                height: 46
                                radius: theme.radiusFull
                                color: theme.surfaceContainer
                                opacity: freqCMouse.containsMouse ? 1.0 : 0.85
                                scale: freqCMouse.pressed ? 0.95 : 1.0
                                Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

                                RowLayout {
                                    id: freqCardRow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    LoafIcon { name: modelData.icon || "folder"; size: 16; color: theme.primary }
                                    Text { text: modelData.name; color: theme.textMain; font.pixelSize: 12; font.bold: true }
                                }

                                MouseArea {
                                    id: freqCMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.showFiles();
                                        engine.set_path(modelData.path);
                                    }
                                }
                            }
                        }

                        GridLayout {
                            id: freqGrid
                            visible: sectionDelegate.secView === "grid"
                            anchors.fill: parent
                            columns: pcView.columnCount(200)
                            columnSpacing: 10
                            rowSpacing: 10

                            Repeater {
                                model: pcView.frequentDirs

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: theme.radiusFull
                                    color: theme.surfaceContainer
                                    opacity: freqGMouse.containsMouse ? 1.0 : 0.85
                                    scale: freqGMouse.pressed ? 0.95 : 1.0
                                    Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        LoafIcon { name: modelData.icon || "folder"; size: 16; color: theme.primary }
                                        Text { text: modelData.name; color: theme.textMain; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight }
                                    }

                                    MouseArea {
                                        id: freqGMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            window.showFiles();
                                            engine.set_path(modelData.path);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // SECTION: INTERNAL STORAGE
                    // ==========================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: sectionDelegate.secVisible
                                 && sectionDelegate.secKey === "internal"
                                 && pcView.internalDrives.length > 0

                        // Aggregate summary card (total / free). No percentage pill.
                        LoafCard {
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                LoafIcon { name: "hard-drives"; size: 24; color: theme.primary }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "System Drive Pool"
                                        color: theme.textMain
                                        font.pixelSize: 15
                                        font.bold: true
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: pcView.formatBytes(pcView.usedInternalBytes) + " used of "
                                              + pcView.formatBytes(pcView.totalInternalBytes) + "  ·  "
                                              + pcView.formatBytes(pcView.freeInternalBytes) + " free"
                                        color: theme.textMuted
                                        font.pixelSize: 12
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            UsageBar {
                                Layout.fillWidth: true
                                value: pcView.overallUsage
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: pcView.columnCount(340)
                            columnSpacing: 12
                            rowSpacing: 12

                            Repeater {
                                model: pcView.internalDrives
                                delegate: driveDelegate
                            }
                        }
                    }

                    // ==========================================
                    // SECTION: EXTERNAL STORAGE
                    // ==========================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: sectionDelegate.secVisible
                                 && sectionDelegate.secKey === "external"
                                 && pcView.externalDrives.length > 0

                        GridLayout {
                            Layout.fillWidth: true
                            columns: pcView.columnCount(340)
                            columnSpacing: 12
                            rowSpacing: 12

                            Repeater {
                                model: pcView.externalDrives
                                delegate: driveDelegate
                            }
                        }
                    }
                }
            }
        }
    }

    // Shared delegate for every drive row (internal + external).
    Component {
        id: driveDelegate

        DriveCard {
            id: driveCard
            drive: modelData

            onActivated: pcView.openDrive(driveCard.drive)
            onMountRequested: pcView.mountDrive(driveCard.drive)
            onContextRequested: function (mx, my) {
                var p = driveCard.mapToItem(null, mx - driveCard.x, my - driveCard.y);
                pcView.openDriveMenu(driveCard.drive, p.x, p.y);
            }
        }
    }

    // Right-click drive actions.
    LoafMenu {
        id: driveMenu
        parent: Overlay.overlay
        model: []
        menuMinWidth: 208
    }

    // Rename drive prompt.
    LoafTextPrompt {
        id: renamePrompt
        title: "Rename Drive"
        confirmText: "Rename"
        placeholder: "Drive name"
        onAccepted: function (text) {
            var name = String(text).trim();
            if (name.length > 0 && pcView.renameDevice.length > 0) {
                engine.rename_drive(pcView.renameDevice, name);
                engine.load_drives();
            }
        }
    }
}
