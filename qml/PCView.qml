import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// PC Dashboard: hostname header with device type icon, plus reorderable /
// customizable sections (places, frequent, internal storage summary + drives,
// external drives). Drive rows are rendered with the shared DriveCard; all
// controls come from the shared component library (SectionHeader, LoafButton,
// LoafShape, UsageBar, LoafMenu, LoafTextPrompt).
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
        core.set_setting("pcSectionOrder", JSON.stringify(pcView.sectionOrder));
        core.set_setting("pcSectionConfig", JSON.stringify(pcView.sectionConfig));
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
            return JSON.parse(core.drives_json || "[]");
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
            return JSON.parse(core.frequent_dirs_json || "[]");
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
    // Places cycle through expressive shapes and the three tonal containers.
    readonly property var placeShapes: ["cookie9", "clover4", "sunny", "cookie6", "flower", "burst", "clover8", "cookie4", "cookie12"]
    function placeShape(i) {
        return pcView.placeShapes[i % pcView.placeShapes.length];
    }
    function placeContainer(i) {
        return [theme.primaryContainer, theme.secondaryContainer, theme.tertiaryContainer][i % 3];
    }
    function placeOnContainer(i) {
        return [theme.primaryContainerFg, theme.secondaryContainerFg, theme.textMain][i % 3];
    }

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
        window.openDrive(d, false);
    }

    function mountDrive(d) {
        window.mountDrive(d);
    }

    function unmountDrive(d) {
        window.unmountDrive(d);
    }

    // Folder shortcuts: the user's real (localized) folders, issue #21/#22.
    readonly property var quickPlaces: {
        try {
            return JSON.parse(core.places_json || "[]").filter(function(p) { return p.kind === "place"; });
        } catch (e) {
            return [];
        }
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
        var isMtp = d && d.provider === "mtp";
        var items = [];

        items.push({
            "text": qsTr("Open"),
            "icon": "folder-open",
            "enabled": mounted || isMtp,
            "action": function () { pcView.openDrive(d); }
        });
        if (!mounted) {
            items.push({
                "text": isMtp ? qsTr("Browse") : qsTr("Mount"),
                "icon": isMtp ? "plugs-connected" : "download",
                "separatorBefore": true,
                "action": function () { pcView.mountDrive(d); }
            });
        }
        if (mounted && !isMtp) {
            items.push({
                "text": qsTr("Unmount"),
                "icon": "eject",
                "separatorBefore": true,
                "action": function () { pcView.unmountDrive(d); }
            });
        }
        if (external && d.disk && !isMtp) {
            items.push({
                "text": qsTr("Eject (Safely Remove)"),
                "icon": "eject",
                "separatorBefore": !mounted,
                "action": function () { core.eject_drive(d.disk); }
            });
        }
        if (d.is_encrypted && d.crypt_device && !isMtp) {
            items.push({
                "text": qsTr("Lock Encrypted Drive"),
                "icon": "lock",
                "enabled": !mounted,
                "action": function () { core.lock_drive(d.crypt_device); }
            });
        }
        if (!isMtp) {
            items.push({
                "text": qsTr("Rename"),
                "icon": "pencil-simple",
                "separatorBefore": true,
                "action": function () { pcView.requestRename(d); }
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
            var order = core.get_setting("pcSectionOrder");
            if (order && order.length > 0)
                pcView.sectionOrder = pcView.normalizeOrder(JSON.parse(order));
        } catch (e) {}
        try {
            var cfg = core.get_setting("pcSectionConfig");
            if (cfg && cfg.length > 0)
                pcView.sectionConfig = pcView.normalizeConfig(JSON.parse(cfg));
        } catch (e) {}
    }
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
            // Hero: the device in a large expressive shape, a short storage
            // summary and a few decorative shapes.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 20

                Item {
                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 104

                    LoafShape {
                        anchors.fill: parent
                        shape: "cookie12"
                        color: theme.primaryContainer
                        rotation: heroMouse.containsMouse ? 30 : 0
                        Behavior on rotation { enabled: theme.animate; SpringAnimation { spring: 2.0; damping: 0.25 } }
                    }
                    LoafShape {
                        width: 30; height: 30
                        x: parent.width - 22; y: -4
                        shape: "sunny"
                        color: theme.tertiaryContainer
                        rotation: heroMouse.containsMouse ? -45 : 0
                        Behavior on rotation { enabled: theme.animate; SpringAnimation { spring: 2.0; damping: 0.25 } }
                    }
                    Rectangle {
                        width: 14; height: 14; radius: 7
                        x: 2; y: parent.height - 16
                        color: theme.secondaryContainer
                    }
                    LoafIcon {
                        anchors.centerIn: parent
                        name: core.device_type === "laptop" ? "laptop" : "desktop"
                        size: 44
                        color: theme.primaryContainerFg
                    }
                    MouseArea {
                        id: heroMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: core.hostname || qsTr("This PC")
                        color: theme.textMain
                        font.pixelSize: theme.fs(32)
                        font.bold: true
                        font.letterSpacing: -0.8
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: {
                            var kind = core.device_type === "laptop" ? qsTr("Laptop") : qsTr("Desktop");
                            if (pcView.totalInternalBytes <= 0)
                                return kind;
                            return kind + "  ·  " + qsTr("%1 free of %2")
                                .arg(pcView.formatBytes(pcView.freeInternalBytes))
                                .arg(pcView.formatBytes(pcView.totalInternalBytes));
                        }
                        color: theme.textMuted
                        font.pixelSize: theme.fs(14)
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // Decorative cluster; hidden on narrow windows.
                Item {
                    visible: pcFlick.width > 720
                    Layout.preferredWidth: 132
                    Layout.preferredHeight: 96

                    LoafShape {
                        width: 72; height: 72
                        x: 0; y: 14
                        shape: "flower"
                        color: theme.tertiaryContainer
                        rotation: 12
                    }
                    LoafShape {
                        width: 48; height: 48
                        x: 64; y: 0
                        shape: "clover4"
                        color: theme.primaryContainer
                        rotation: 45
                    }
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        x: 100; y: 66
                        color: theme.primary
                    }
                }

                LoafButton {
                    id: customizeBtn
                    visible: pcView.customizationEnabled
                    Layout.alignment: Qt.AlignTop
                    text: pcView.customizing ? qsTr("Done") : qsTr("Customize")
                    icon: pcView.customizing ? "check" : "sliders-horizontal"
                    variant: pcView.customizing ? "tonal" : "outlined"
                    onClicked: pcView.isCustomizing = !pcView.isCustomizing
                }
            }
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
                    SectionHeader {
                        Layout.fillWidth: true
                        icon: sectionDelegate.secKey === "places" ? "folder"
                              : (sectionDelegate.secKey === "frequent" ? "clock"
                              : (sectionDelegate.secKey === "internal" ? "hard-drives" : "usb"))
                        title: sectionDelegate.secKey === "places" ? qsTr("Places")
                               : (sectionDelegate.secKey === "frequent" ? qsTr("Frequent")
                               : (sectionDelegate.secKey === "internal" ? qsTr("Internal Storage") : qsTr("External Storage")))
                        subtitle: sectionDelegate.secKey === "external"
                                  ? theme.plural(pcView.externalDrives.length, qsTr("1 drive connected"), qsTr("%1 drives connected"))
                                  : ""
                        LoafButton {
                            visible: pcView.customizing
                                     && (sectionDelegate.secKey === "places" || sectionDelegate.secKey === "frequent")
                            text: sectionDelegate.secView === "carousel" ? qsTr("Carousel") : qsTr("Grid")
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
                            variant: sectionDelegate.secVisible ? "text" : qsTr("tonal")
                            onClicked: pcView.toggleSectionVisibility(sectionDelegate.secKey)
                        }
                    }
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
                                text: qsTr("Section hidden")
                                color: theme.textMuted
                                font.pixelSize: theme.fs(12)
                            }
                            LoafButton {
                                text: qsTr("Restore")
                                icon: "plus"
                                variant: "tonal"
                                onClicked: pcView.toggleSectionVisibility(sectionDelegate.secKey)
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: sectionDelegate.secView === "carousel" ? 60 : placesGrid.implicitHeight
                        visible: sectionDelegate.secVisible && sectionDelegate.secKey === "places"

                        GridLayout {
                            id: placesGrid
                            visible: sectionDelegate.secView !== "carousel"
                            anchors.fill: parent
                            columns: pcView.columnCount(150)
                            columnSpacing: 12
                            rowSpacing: 12

                            Repeater {
                                model: pcView.quickPlaces

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 116
                                    radius: theme.radiusXl
                                    color: placeMouse.containsMouse ? theme.surfaceContainerHigh : theme.surfaceContainer
                                    scale: placeMouse.pressed ? 0.95 : (placeMouse.containsMouse ? 1.02 : 1.0)
                                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.32 } }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        width: parent.width - 24
                                        spacing: 10

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 56
                                            Layout.preferredHeight: 56

                                            LoafShape {
                                                anchors.fill: parent
                                                shape: pcView.placeShape(index)
                                                color: pcView.placeContainer(index)
                                                rotation: placeMouse.containsMouse ? 45 : 0
                                                Behavior on rotation { enabled: theme.animate; SpringAnimation { spring: 2.5; damping: 0.26 } }
                                            }
                                            LoafIcon {
                                                anchors.centerIn: parent
                                                name: modelData.icon
                                                size: 24
                                                color: pcView.placeOnContainer(index)
                                            }
                                        }
                                        Text {
                                            text: modelData.name
                                            color: theme.textMain
                                            font.pixelSize: theme.fs(13)
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
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
                                            window.showFiles();
                                            engine.set_path(modelData.path);
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

                            model: pcView.quickPlaces

                            delegate: Rectangle {
                                width: 156
                                height: 60
                                radius: theme.radiusFull
                                color: cPlaceMouse.containsMouse ? theme.surfaceContainerHigh : theme.surfaceContainer
                                scale: cPlaceMouse.pressed ? 0.95 : 1.0
                                Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                                Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 16
                                    spacing: 10

                                    Item {
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40

                                        LoafShape {
                                            anchors.fill: parent
                                            shape: pcView.placeShape(index)
                                            color: pcView.placeContainer(index)
                                            rotation: cPlaceMouse.containsMouse ? 45 : 0
                                            Behavior on rotation { enabled: theme.animate; SpringAnimation { spring: 2.5; damping: 0.26 } }
                                        }
                                        LoafIcon {
                                            anchors.centerIn: parent
                                            name: modelData.icon
                                            size: 18
                                            color: pcView.placeOnContainer(index)
                                        }
                                    }
                                    Text {
                                        text: modelData.name
                                        color: theme.textMain
                                        font.pixelSize: theme.fs(12)
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: cPlaceMouse
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
                                Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

                                RowLayout {
                                    id: freqCardRow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    LoafIcon { name: modelData.icon || "folder"; size: 16; color: theme.primary }
                                    Text { text: modelData.name; color: theme.textMain; font.pixelSize: theme.fs(12); font.bold: true }
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
                                    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        LoafIcon { name: modelData.icon || "folder"; size: 16; color: theme.primary }
                                        Text { text: modelData.name; color: theme.textMain; font.pixelSize: theme.fs(12); font.bold: true; elide: Text.ElideRight }
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
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: sectionDelegate.secVisible
                                 && sectionDelegate.secKey === "internal"
                                 && pcView.internalDrives.length > 0
                        // Pool summary; with a single drive it would only repeat its card.
                        Rectangle {
                            visible: pcView.internalDrives.length > 1
                            Layout.fillWidth: true
                            Layout.preferredHeight: poolCol.implicitHeight + 40
                            radius: theme.radiusXl
                            color: theme.surfaceContainerHigh

                            ColumnLayout {
                                id: poolCol
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 14

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 16

                                    Item {
                                        Layout.preferredWidth: 56
                                        Layout.preferredHeight: 56

                                        LoafShape {
                                            anchors.fill: parent
                                            shape: "burst"
                                            color: theme.primaryContainer
                                        }
                                        LoafIcon {
                                            anchors.centerIn: parent
                                            name: "hard-drives"
                                            size: 26
                                            color: theme.primaryContainerFg
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: qsTr("System Drive Pool")
                                            color: theme.textMain
                                            font.pixelSize: theme.fs(16)
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: pcView.formatBytes(pcView.usedInternalBytes) + " used of "
                                                  + pcView.formatBytes(pcView.totalInternalBytes) + "  ·  "
                                                  + pcView.formatBytes(pcView.freeInternalBytes) + " free"
                                            color: theme.textMuted
                                            font.pixelSize: theme.fs(12)
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: Math.round(pcView.overallUsage * 100) + "%"
                                        color: theme.primary
                                        font.pixelSize: theme.fs(34)
                                        font.bold: true
                                        font.letterSpacing: -1
                                    }
                                }

                                UsageBar {
                                    Layout.fillWidth: true
                                    value: pcView.overallUsage
                                    thickness: 6
                                    amplitude: 4
                                    wavelength: 48
                                }
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
    LoafMenu {
        id: driveMenu
        parent: Overlay.overlay
        model: []
        menuMinWidth: 208
    }
    LoafTextPrompt {
        id: renamePrompt
        title: qsTr("Rename Drive")
        confirmText: qsTr("Rename")
        placeholder: qsTr("Drive name")
        onAccepted: function (text) {
            var name = String(text).trim();
            if (name.length > 0 && pcView.renameDevice.length > 0) {
                core.rename_drive(pcView.renameDevice, name);
            }
        }
    }
}
