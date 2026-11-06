import QtQuick
import QtQuick.Controls
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

    readonly property bool matchProvider: matches("hosting provider own machine cloud p2p")
    readonly property bool matchActive: matches("active shares running hosted links tunnels streams")
    readonly property bool matchCompression: matches("compression archive format zip 7z tar gz password folders files")
    readonly property bool matchAdvanced: matches("advanced cloudflare tunnel agent daemon expiration throttle bandwidth rate limit")

    readonly property int matchCount: (matchProvider ? 1 : 0) + (matchActive ? 1 : 0)
        + (matchCompression ? 1 : 0) + (matchAdvanced ? 1 : 0)

    readonly property bool passwordSupported: {
        var fmt = theme.shareCompressFormat;
        var isZipOr7z = (fmt === "zip" || fmt === "7z");
        return (theme.shareCompressFolders && isZipOr7z) || (theme.shareCompressFiles && isZipOr7z);
    }

    Layout.fillWidth: true
    spacing: 16

    // 1. Hosting Provider Card
    SettingCard {
        visible: root.matchProvider
        title: qsTr("Hosting Provider")
        subtitle: qsTr("Choose how files are exposed when generating public links")
        icon: "hard-drives"

        SettingRow {
            icon: "hard-drives"
            title: qsTr("Provider")
            subtitle: qsTr("Host directly from your machine or use hosted cloud relay")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 110 : 280
                options: [
                    { value: "local", label: qsTr("Own Machine"), icon: "desktop" },
                    { value: "cloud", label: qsTr("Loaf Cloud (Soon)"), icon: "cloud", disabled: true }
                ]
                value: theme.shareProvider
                onSelected: function(v) {
                    if (v === "local") theme.shareProvider = "local";
                }
            }
        }
    }

    // 2. Active Shares Card (Moved to the top)
    SettingCard {
        id: activeSharesCard
        visible: root.matchActive
        title: qsTr("Active Shares")
        subtitle: qsTr("Files and directories currently being streamed from your machine")
        icon: "broadcast"

        property var sharesList: []

        function refreshShares() {
            if (typeof core !== "undefined" && core) {
                try {
                    sharesList = JSON.parse(core.list_shares_json() || "[]");
                } catch (e) {
                    sharesList = [];
                }
            }
        }

        Timer {
            interval: 2000
            running: root.visible
            repeat: true
            triggeredOnStart: true
            onTriggered: activeSharesCard.refreshShares()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                visible: activeSharesCard.sharesList.length === 0
                text: qsTr("No active shares right now.")
                color: theme.textMuted
                font.pixelSize: theme.fs(12)
                font.italic: true
                Layout.fillWidth: true
            }

            LoafButton {
                text: qsTr("Refresh")
                icon: "arrow-clockwise"
                variant: "tonal"
                onClicked: activeSharesCard.refreshShares()
            }
        }

        Repeater {
            model: activeSharesCard.sharesList

            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: shareItemRow.implicitHeight + 20
                radius: theme.radiusM
                color: theme.surfaceContainerHigh
                border.width: 1
                border.color: theme.borderSubtle

                RowLayout {
                    id: shareItemRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    LoafIcon {
                        name: modelData.is_archive ? "file-archive" : "file"
                        size: 24
                        color: theme.primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            spacing: 8
                            Text {
                                text: modelData.name
                                color: theme.textMain
                                font.pixelSize: theme.fs(13)
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                radius: 4
                                implicitWidth: stText.implicitWidth + 8
                                implicitHeight: stText.implicitHeight + 4
                                color: modelData.status === "ready" ? theme.primaryContainer : theme.surfaceContainerHighest
                                Text {
                                    id: stText
                                    anchors.centerIn: parent
                                    text: modelData.status ? modelData.status.toUpperCase() : ""
                                    color: modelData.status === "ready" ? theme.primaryContainerFg : theme.textMuted
                                    font.pixelSize: theme.fs(9)
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            visible: modelData.url && modelData.url.length > 0
                            text: modelData.url || ""
                            color: theme.primary
                            font.pixelSize: theme.fs(11)
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }

                    LoafButton {
                        visible: modelData.url && modelData.url.length > 0
                        icon: "copy"
                        variant: "ghost"
                        Accessible.name: qsTr("Copy URL")
                        onClicked: if (typeof core !== "undefined" && core) core.copy_text(modelData.url)
                    }

                    LoafButton {
                        text: qsTr("Stop")
                        icon: "x"
                        variant: "tonal"
                        onClicked: {
                            if (typeof core !== "undefined" && core) {
                                core.cancel_share(modelData.id);
                                activeSharesCard.refreshShares();
                            }
                        }
                    }
                }
            }
        }
    }

    // Settings below only apply to "local" provider
    // 3. Compression & Archives Card
    SettingCard {
        visible: theme.shareProvider === "local" && root.matchCompression
        title: qsTr("Compression & Archives")
        subtitle: qsTr("Per-type compression options and optional archive password protection")
        icon: "archive"

        SettingRow {
            icon: "folder-notch"
            title: qsTr("Folder compression")
            subtitle: qsTr("Select archive format for shared folders or stream raw files")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 280
                options: [
                    { value: "off", label: qsTr("Off"), shortLabel: qsTr("Off") },
                    { value: "zip", label: ".zip", shortLabel: ".zip" },
                    { value: "7z", label: ".7z", shortLabel: ".7z" },
                    { value: "tar.gz", label: ".tar.gz", shortLabel: ".tar" }
                ]
                value: !theme.shareCompressFolders ? "off" : theme.shareCompressFormat
                onSelected: function(v) {
                    if (v === "off") {
                        theme.shareCompressFolders = false;
                    } else {
                        theme.shareCompressFolders = true;
                        theme.shareCompressFormat = v;
                    }
                }
            }
        }

        SettingDivider {}

        SettingRow {
            icon: "file-archive"
            title: qsTr("Single file compression")
            subtitle: qsTr("Compress standalone files into an archive before uploading")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 280
                options: [
                    { value: "off", label: qsTr("Off"), shortLabel: qsTr("Off") },
                    { value: "zip", label: ".zip", shortLabel: ".zip" },
                    { value: "7z", label: ".7z", shortLabel: ".7z" },
                    { value: "tar.gz", label: ".tar.gz", shortLabel: ".tar" }
                ]
                value: !theme.shareCompressFiles ? "off" : theme.shareCompressFormat
                onSelected: function(v) {
                    if (v === "off") {
                        theme.shareCompressFiles = false;
                    } else {
                        theme.shareCompressFiles = true;
                        theme.shareCompressFormat = v;
                    }
                }
            }
        }

        SettingDivider { visible: root.passwordSupported }

        // Dynamic password setting: only shows when .zip or .7z is selected on folders or files
        SettingRow {
            visible: root.passwordSupported
            icon: "lock-key"
            title: qsTr("Archive password")
            subtitle: qsTr("Password protection for generated .zip and .7z packages")

            LoafTextField {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 140 : 220
                echoMode: TextInput.Password
                placeholderText: qsTr("No password")
                text: theme.sharePassword
                onTextChanged: theme.sharePassword = text
            }
        }
    }

    // 4. Advanced Category Card (Collapsed by default)
    SettingCard {
        visible: theme.shareProvider === "local" && root.matchAdvanced
        title: qsTr("Advanced")
        subtitle: qsTr("Cloudflare tunnel daemon status, link expiration, and bandwidth throttle")
        icon: "sliders"
        collapsed: true

        SettingRow {
            icon: "cloud"
            title: qsTr("Cloudflare tunnel agent")
            subtitle: (typeof core !== "undefined" && core && core.cloudflared_ready)
                ? qsTr("The tunnel daemon (cloudflared) is installed and active")
                : qsTr("Securely exposes shared files without router port forwarding")

            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                Rectangle {
                    implicitHeight: 28
                    radius: theme.radiusFull
                    color: (typeof core !== "undefined" && core && core.cloudflared_ready)
                        ? theme.primaryContainer : theme.surfaceContainerHighest
                    implicitWidth: tunnelStatusRow.implicitWidth + 18

                    RowLayout {
                        id: tunnelStatusRow
                        anchors.centerIn: parent
                        spacing: 6

                        LoafIcon {
                            name: (typeof core !== "undefined" && core && core.cloudflared_ready) ? "check-circle" : "arrow-circle-down"
                            size: 14
                            color: (typeof core !== "undefined" && core && core.cloudflared_ready) ? theme.primaryContainerFg : theme.textMuted
                        }
                        Text {
                            text: (typeof core !== "undefined" && core && core.cloudflared_ready) ? qsTr("Ready") : qsTr("Not installed")
                            color: (typeof core !== "undefined" && core && core.cloudflared_ready) ? theme.primaryContainerFg : theme.textMuted
                            font.pixelSize: theme.fs(11)
                            font.bold: true
                        }
                    }
                }

                LoafButton {
                    text: (typeof core !== "undefined" && core && core.cloudflared_ready) ? qsTr("Reinstall") : qsTr("Install Now")
                    variant: "tonal"
                    icon: "download-simple"
                    onClicked: if (typeof core !== "undefined" && core) core.install_cloudflared()
                }
            }
        }

        SettingDivider {}

        SettingRow {
            icon: "timer"
            title: qsTr("Link expiration period")
            subtitle: qsTr("Automatically terminate the stream and revoke the link after this period")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 160 : 320
                options: [
                    //: Short label for 1 Hour expiration. Must stay short.
                    { value: 1, label: qsTr("1 Hour"), shortLabel: qsTr("1h") },
                    //: Short label for 6 Hours expiration. Must stay short.
                    { value: 6, label: qsTr("6 Hours"), shortLabel: qsTr("6h") },
                    //: Short label for 24 Hours expiration. Must stay short.
                    { value: 24, label: qsTr("24 Hours"), shortLabel: qsTr("24h") },
                    //: Short label for Never expiring (infinity symbol). Must stay short.
                    { value: 0, label: qsTr("Never"), shortLabel: qsTr("∞") }
                ]
                value: theme.shareExpirationHours
                onSelected: function(v) { theme.shareExpirationHours = v; }
            }
        }

        SettingDivider {}

        SettingRow {
            icon: "gauge"
            title: qsTr("Bandwidth upload throttle")
            subtitle: qsTr("Limit upload rate to prevent saturating your local internet connection")

            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                LoafTextField {
                    Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 90 : 120
                    placeholderText: qsTr("Unlimited")
                    text: theme.shareThrottleKbps > 0 ? theme.shareThrottleKbps.toString() : ""
                    onTextChanged: {
                        var val = parseInt(text) || 0;
                        theme.shareThrottleKbps = val;
                    }
                }
                //: Unit label for kilobytes per second. Must stay short.
                Text {
                    text: qsTr("KB/s")
                    color: theme.textMuted
                    font.pixelSize: theme.fs(12)
                }
            }
        }
    }
}
