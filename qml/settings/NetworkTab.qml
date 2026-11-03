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

    readonly property bool matchSmb: matches("network smb samba nas share server mount connect remote windows keyring")
    readonly property bool matchDiscovery: matches("discover automatic scan lan avahi mdns bonjour netbios ws-discovery smb samba nas network")
    readonly property int matchCount: (matchSmb ? 1 : 0) + (matchDiscovery ? 1 : 0)

    readonly property var profiles: {
        if (typeof core !== "undefined" && core && core.smb_profiles_json) {
            try {
                return JSON.parse(core.smb_profiles_json || "[]");
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
        if (entry.address)
            parts.push(entry.address);
        return parts.join("  ·  ");
    }

    function addShare(server, share) {
        if (typeof core !== "undefined" && core && share)
            core.add_smb_discovered(server, share);
    }

    Layout.fillWidth: true
    spacing: 16

    SettingCard {
        visible: root.matchSmb
        title: qsTr("Network Storage (SMB / CIFS)")
        subtitle: qsTr("Connect to remote Windows file shares, home NAS, and Samba servers")
        icon: "network"

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: qsTr("Configured Shares")
                color: theme.textMain
                font.pixelSize: theme.fs(13)
                font.bold: true
                Layout.fillWidth: true
            }

            LoafButton {
                text: qsTr("Add Share")
                icon: "plus"
                variant: "filled"
                onClicked: if (typeof window !== "undefined") window.openSmbEditor({})
            }
        }

        SettingDivider {}

        Text {
            visible: root.profiles.length === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            text: qsTr("No shares saved yet. Add a server host and share name to connect. Mounted shares appear directly in the sidebar navigation and browse identically to local folders.")
        }

        Repeater {
            model: root.profiles

            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: shareRow.implicitHeight + 20
                radius: theme.radiusM
                color: theme.surfaceContainerHigh
                border.width: 1
                border.color: theme.borderSubtle

                RowLayout {
                    id: shareRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    LoafIcon {
                        name: modelData.connected ? "network" : "plug"
                        size: 20
                        color: modelData.connected ? theme.primary : theme.textMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            text: modelData.label || ""
                            color: theme.textMain
                            font.pixelSize: theme.fs(13)
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (modelData.username ? modelData.username + "@" : "") + (modelData.server || "") + (modelData.share ? "/" + modelData.share : "")
                            color: theme.textMuted
                            font.pixelSize: theme.fs(11)
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }

                    LoafButton {
                        text: modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
                        icon: modelData.connected ? "plug-slash" : "plug"
                        variant: modelData.connected ? "tonal" : "filled"
                        onClicked: {
                            if (typeof core !== "undefined" && core) {
                                if (modelData.connected)
                                    core.disconnect_smb(modelData.id);
                                else
                                    core.connect_smb(modelData.id, "", false);
                            }
                        }
                    }

                    LoafButton {
                        icon: "pencil-simple"
                        variant: "ghost"
                        Accessible.name: qsTr("Edit share")
                        onClicked: if (typeof window !== "undefined") window.openSmbEditor(modelData)
                    }

                    LoafButton {
                        icon: "trash"
                        variant: "ghost"
                        Accessible.name: qsTr("Remove share")
                        onClicked: if (typeof window !== "undefined") window.removeSmbShare(modelData.id, modelData.label)
                    }
                }
            }
        }
    }

    SettingCard {
        visible: root.matchDiscovery
        title: qsTr("Automatic Discovery")
        subtitle: qsTr("Find Windows, Samba, and NAS shares on this local network")
        icon: "broadcast"

        SettingRow {
            icon: "broadcast"
            title: qsTr("Discover network shares")
            subtitle: qsTr("Scan in the background with mDNS/Avahi, NetBIOS, and GVfs, and show new servers in the sidebar")

            LoafSwitch {
                id: discoverySwitch
                checked: theme.smbAutoDiscovery
                onToggled: theme.smbAutoDiscovery = checked
            }
        }

        SettingDivider {}

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.scanning ? qsTr("Scanning the local network…") : qsTr("Discovered on this network")
                color: theme.textMain
                font.pixelSize: theme.fs(13)
                font.bold: true
                Layout.fillWidth: true
            }

            LoafButton {
                text: qsTr("Scan Now")
                icon: "arrows-clockwise"
                variant: "tonal"
                enabled: root.discoveryEnabled && !root.scanning
                onClicked: if (typeof core !== "undefined" && core) core.refresh_smb_discovery()
            }
        }

        Text {
            visible: !root.discoveryEnabled
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            text: qsTr("Automatic discovery is off. Saved shares still appear in the sidebar; turn discovery on to scan again.")
        }

        Text {
            visible: root.discoveryEnabled && !root.scanning && root.discovered.length === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            text: qsTr("No shared disks found yet. Make sure the NAS or Windows PC is on the same network, then scan again.")
        }

        Repeater {
            model: root.discovered

            delegate: Rectangle {
                required property var modelData
                readonly property var entry: modelData

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: discoveryRow.implicitHeight + 20
                radius: theme.radiusM
                color: theme.surfaceContainerHigh
                border.width: 1
                border.color: theme.borderSubtle
                opacity: entry.ignored ? 0.55 : 1.0

                RowLayout {
                    id: discoveryRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    LoafIcon {
                        name: entry.ignored ? "eye-slash" : "network"
                        size: 20
                        color: entry.ignored ? theme.textMuted : theme.primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 6

                        Text {
                            text: entry.name || entry.server || ""
                            color: theme.textMain
                            font.pixelSize: theme.fs(13)
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: root.serverSubtitle(entry).length > 0
                            text: root.serverSubtitle(entry)
                            color: theme.textMuted
                            font.pixelSize: theme.fs(11)
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: !entry.ignored

                            Repeater {
                                model: entry.shares || []

                                delegate: LoafButton {
                                    required property string modelData
                                    text: modelData
                                    icon: "plus"
                                    variant: "tonal"
                                    onClicked: root.addShare(entry.server, modelData)
                                }
                            }
                        }
                    }

                    LoafButton {
                        visible: !entry.ignored
                        text: qsTr("Add Share…")
                        icon: "plus"
                        variant: "outlined"
                        onClicked: if (typeof window !== "undefined") window.openSmbEditor({ server: entry.server, name: entry.name, share: "" })
                    }

                    LoafButton {
                        visible: !entry.ignored
                        icon: "eye-slash"
                        variant: "ghost"
                        Accessible.name: qsTr("Hide this server")
                        onClicked: if (typeof core !== "undefined" && core) core.ignore_smb_server(entry.server)
                    }

                    LoafButton {
                        visible: entry.ignored
                        text: qsTr("Unhide")
                        icon: "eye"
                        variant: "tonal"
                        onClicked: if (typeof core !== "undefined" && core) core.unignore_smb_server(entry.server)
                    }
                }
            }
        }

        RowLayout {
            visible: root.discovered.some(function(d) { return d.ignored; })
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: qsTr("Hidden servers are still remembered above.")
                color: theme.textMuted
                font.pixelSize: theme.fs(11)
                Layout.fillWidth: true
            }

            LoafButton {
                text: qsTr("Unhide All")
                icon: "eye"
                variant: "text"
                onClicked: if (typeof core !== "undefined" && core) core.clear_ignored_smb_servers()
            }
        }
    }

    SettingCard {
        visible: root.matchSmb
        title: qsTr("Authentication & Mounting")
        subtitle: qsTr("Shares are mounted securely via GVfs. Credentials are saved in the system FreeDesktop secret keyring.")
        icon: "lock-key"
    }

    Connections {
        target: theme
        function onSmbAutoDiscoveryChanged() {
            if (discoverySwitch.checked !== theme.smbAutoDiscovery)
                discoverySwitch.checked = theme.smbAutoDiscovery;
        }
    }
}
