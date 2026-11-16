import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

ColumnLayout {
    id: root

    property string searchQuery: ""
    signal openNetworkEditorRequested(var profile)
    signal removeNetworkDriveRequested(string id, string label)

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

    readonly property bool matchSaved: matches("saved drives network shares storage connect mount remote host server edit rename remove")
    readonly property bool matchDiscovery: matches("auto discovery scan network servers find detect lan avahi mdns bonjour netbios ws-discovery")
    readonly property int matchCount: (searchQuery && searchQuery.trim().length > 0)
        ? ((matchSaved ? 1 : 0) + (matchDiscovery ? 1 : 0))
        : 0

    readonly property var profiles: {
        if (typeof core !== "undefined" && core && (core.network_profiles_json || core.smb_profiles_json)) {
            try {
                return JSON.parse(core.network_profiles_json || core.smb_profiles_json || "[]");
            } catch (e) {
                return [];
            }
        }
        return [];
    }

    readonly property var discovered: {
        if (typeof core !== "undefined" && core && core.smb_discovered_json) {
            try {
                return JSON.parse(core.smb_discovered_json || "[]");
            } catch (e) {
                return [];
            }
        }
        return [];
    }

    readonly property bool scanning: typeof core !== "undefined" && core && core.smb_discovery_scanning === true
    readonly property bool discoveryEnabled: theme.smbAutoDiscovery

    function serverSubtitle(entry) {
        var parts = [];
        if (entry.server && entry.server !== entry.name)
            parts.push(entry.server);
        if (entry.address && entry.address !== entry.server)
            parts.push(entry.address);
        return parts.join("  ·  ");
    }

    function addShare(server, share) {
        if (typeof core !== "undefined" && core && share)
            core.add_smb_discovered(server, share);
    }

    function connectDiscovered(entry) {
        if (!entry) return;
        if (entry.shares && entry.shares.length > 0) {
            addShare(entry.server, entry.shares[0]);
        } else {
            root.openNetworkEditorRequested({
                server: entry.server || "",
                name: entry.name || entry.server || ""
            });
        }
    }

    function openRename(drive) {
        renamePrompt.targetDrive = drive;
        renamePrompt.initialText = drive.label || drive.name || "";
        renamePrompt.open();
    }

    Layout.fillWidth: true
    spacing: 16

    SettingCard {
        visible: root.matchSaved
        title: qsTr("Saved Drives")
        subtitle: qsTr("Network storage locations and mounted remote drives")
        icon: "hard-drives"

        headerActions: [
            LoafButton {
                text: qsTr("Add Drive")
                icon: "plus"
                variant: "filled"
                onClicked: root.openNetworkEditorRequested({})
            }
        ]

        Text {
            visible: root.profiles.length === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            text: qsTr("No network drives configured yet. Add a remote drive or cloud storage to connect. Mounted drives appear directly in the sidebar navigation.")
        }

        Repeater {
            model: root.profiles

            delegate: Rectangle {
                id: savedDriveCard
                required property var modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: driveRow.implicitHeight + 20
                radius: theme.radiusM
                color: theme.surfaceContainerHigh
                border.width: 1
                border.color: theme.outlineAlpha(theme.borderSubtle)

                RowLayout {
                    id: driveRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    LoafIcon {
                        name: savedDriveCard.modelData.icon || "hard-drives"
                        size: 20
                        color: savedDriveCard.modelData.connected ? theme.primary : theme.textMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 3

                        RowLayout {
                            spacing: 8
                            Text {
                                text: savedDriveCard.modelData.label || qsTr("Network Drive")
                                color: theme.textMain
                                font.pixelSize: theme.fs(13)
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                radius: theme.radiusFull
                                color: savedDriveCard.modelData.connected ? theme.primaryContainer : theme.surfaceContainerHighest
                                implicitWidth: statusTxt.implicitWidth + 10
                                implicitHeight: 18

                                Text {
                                    id: statusTxt
                                    anchors.centerIn: parent
                                    text: savedDriveCard.modelData.connected ? qsTr("Connected") : qsTr("Offline")
                                    color: savedDriveCard.modelData.connected ? theme.primaryContainerFg : theme.textMuted
                                    font.pixelSize: theme.fs(9)
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            text: {
                                var srv = savedDriveCard.modelData.server || "";
                                if (savedDriveCard.modelData.port && savedDriveCard.modelData.port > 0)
                                    srv += ":" + savedDriveCard.modelData.port;
                                var sh = savedDriveCard.modelData.share || "";
                                if (sh && sh.indexOf("/") !== 0)
                                    sh = "/" + sh;
                                var user = savedDriveCard.modelData.username ? (savedDriveCard.modelData.username + "@") : "";
                                return "//" + user + srv + sh;
                            }
                            color: theme.textMuted
                            font.pixelSize: theme.fs(11)
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }

                    LoafButton {
                        text: savedDriveCard.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
                        icon: savedDriveCard.modelData.connected ? "plug-slash" : "plug"
                        variant: savedDriveCard.modelData.connected ? "tonal" : "filled"
                        onClicked: {
                            if (typeof core !== "undefined" && core) {
                                if (savedDriveCard.modelData.connected)
                                    core.disconnect_network(savedDriveCard.modelData.id);
                                else
                                    core.connect_network(savedDriveCard.modelData.id, "", false);
                            }
                        }
                    }

                    LoafButton {
                        id: renameBtn
                        icon: "tag"
                        variant: "ghost"
                        Accessible.name: qsTr("Rename drive")
                        tooltipText: qsTr("Rename")
                        onClicked: root.openRename(savedDriveCard.modelData)
                    }

                    LoafButton {
                        id: editBtn
                        icon: "pencil-simple"
                        variant: "ghost"
                        Accessible.name: qsTr("Edit drive")
                        tooltipText: qsTr("Edit")
                        onClicked: root.openNetworkEditorRequested(savedDriveCard.modelData)
                    }

                    LoafButton {
                        id: removeBtn
                        icon: "trash"
                        variant: "ghost"
                        Accessible.name: qsTr("Remove drive")
                        tooltipText: qsTr("Remove")
                        onClicked: root.removeNetworkDriveRequested(savedDriveCard.modelData.id, savedDriveCard.modelData.label)
                    }
                }
            }
        }
    }

    SettingCard {
        visible: root.matchDiscovery
        title: qsTr("Auto Discovery")
        subtitle: qsTr("Scan and detect shared network drives across the local network")
        icon: "broadcast"

        headerActions: [
            LoafSwitch {
                id: autoDiscoverySwitch
                checked: theme.smbAutoDiscovery
                onToggled: function(c) { theme.smbAutoDiscovery = c; }
            },
            LoafButton {
                id: refreshDiscoveryBtn
                icon: "arrows-clockwise"
                variant: "tonal"
                enabled: root.discoveryEnabled && !root.scanning
                Accessible.name: qsTr("Scan network now")
                tooltipText: qsTr("Re-discover drives")
                onClicked: if (typeof core !== "undefined" && core) core.refresh_smb_discovery()

                RotationAnimation {
                    target: refreshDiscoveryBtn
                    property: "rotation"
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: root.scanning
                }
            }
        ]

        Text {
            visible: !root.discoveryEnabled
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            text: qsTr("Auto discovery is off. Turn the toggle on to scan for network storage shared on your LAN.")
        }

        Text {
            visible: root.discoveryEnabled && root.scanning && root.discovered.length === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            text: qsTr("Looking for network storage and shared drives on this network…")
        }

        Text {
            visible: root.discoveryEnabled && !root.scanning && root.discovered.length === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            text: qsTr("No network drives discovered yet. Make sure file sharing is active on your NAS or server, then click the retry icon above to scan again.")
        }

        Repeater {
            model: root.discovered

            delegate: Rectangle {
                id: discCard
                required property var modelData
                readonly property var entry: discCard.modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: discRow.implicitHeight + 20
                radius: theme.radiusM
                color: theme.surfaceContainerHigh
                border.width: 1
                border.color: theme.outlineAlpha(theme.borderSubtle)
                opacity: entry.ignored ? 0.55 : 1.0

                RowLayout {
                    id: discRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    LoafIcon {
                        name: discCard.entry.ignored ? "eye-slash" : "network"
                        size: 20
                        color: discCard.entry.ignored ? theme.textMuted : theme.primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 4

                        Text {
                            text: discCard.entry.name || discCard.entry.server || qsTr("Network Device")
                            color: theme.textMain
                            font.pixelSize: theme.fs(13)
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: root.serverSubtitle(discCard.entry).length > 0
                            text: root.serverSubtitle(discCard.entry)
                            color: theme.textMuted
                            font.pixelSize: theme.fs(11)
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: !discCard.entry.ignored && discCard.entry.shares && discCard.entry.shares.length > 0

                            Repeater {
                                model: discCard.entry.shares || []

                                delegate: LoafButton {
                                    id: discShareBtn
                                    required property string modelData
                                    text: discShareBtn.modelData
                                    icon: "plus"
                                    variant: "tonal"
                                    onClicked: root.addShare(discCard.entry.server, discShareBtn.modelData)
                                }
                            }
                        }
                    }

                    LoafButton {
                        text: qsTr("Connect")
                        icon: "plug"
                        variant: "filled"
                        visible: !discCard.entry.ignored && (!discCard.entry.shares || discCard.entry.shares.length === 0)
                        onClicked: root.connectDiscovered(discCard.entry)
                    }

                    LoafButton {
                        id: ignoreBtn
                        icon: discCard.entry.ignored ? "eye" : "eye-slash"
                        variant: "ghost"
                        Accessible.name: discCard.entry.ignored ? qsTr("Show drive") : qsTr("Ignore drive")
                        tooltipText: discCard.entry.ignored ? qsTr("Restore") : qsTr("Ignore")
                        onClicked: {
                            if (typeof core !== "undefined" && core) {
                                if (discCard.entry.ignored)
                                    core.unignore_smb_server(discCard.entry.server);
                                else
                                    core.ignore_smb_server(discCard.entry.server);
                            }
                        }
                    }
                }
            }
        }
    }

    // Single dialog for quick rename
    LoafTextPrompt {
        id: renamePrompt
        title: qsTr("Rename Drive")
        label: qsTr("Display name:")
        confirmText: qsTr("Save")
        property var targetDrive: null

        onAccepted: function(newName) {
            if (!targetDrive || !newName.trim()) return;
            var d = targetDrive;
            if (typeof core !== "undefined" && core) {
                core.save_network_profile(
                    d.id,
                    d.protocol || "smb",
                    newName.trim(),
                    d.server || "",
                    d.share || "",
                    d.username || "",
                    d.domain || "",
                    d.port || 0,
                    d.ssl !== undefined ? d.ssl : true
                );
            }
            if (typeof window !== "undefined" && window.toast)
                window.toast("info", qsTr("Drive renamed"));
        }
    }
}
