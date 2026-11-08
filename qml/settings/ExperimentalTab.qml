import QtQuick
import QtQuick.Layouts
import app.loaf

ColumnLayout {
    id: root

    property string searchQuery: ""

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

    readonly property bool matchIcons: matches("experimental icon styles adwaita desktop system theme vector")
    readonly property bool matchArchives: matches("experimental archives compress cpio tar 7z bz2 xz zst formats compression")
    readonly property bool matchPcCustom: matches("experimental pc customization dashboard layout sections this pc")
    readonly property bool matchShareLink: matches("experimental share via link cloudflare tunnel p2p host local send")

    readonly property int matchCount: (searchQuery && searchQuery.trim().length > 0)
        ? ((matchIcons ? 1 : 0) + (matchArchives ? 1 : 0) + (matchPcCustom ? 1 : 0) + (matchShareLink ? 1 : 0))
        : 0

    Layout.fillWidth: true
    spacing: 16

    SettingCard {
        visible: root.matchIcons || root.matchArchives || root.matchPcCustom || root.matchShareLink
        title: qsTr("Experimental Features")
        subtitle: qsTr("Cutting-edge capabilities, advanced formats, and preview tools")
        icon: "sparkle"

        SettingRow {
            visible: root.matchIcons
            icon: "shapes"
            title: qsTr("Extended icon styles")
            subtitle: qsTr("Unlock system desktop themes, Adwaita vector icons, and third-party icon packs in Interface settings")

            LoafSwitch {
                id: expIconSwitch
                checked: theme.showExperimentalIcons
                onToggled: theme.showExperimentalIcons = checked
            }
        }

        SettingDivider { visible: root.matchIcons && (root.matchArchives || root.matchPcCustom || root.matchShareLink) }

        SettingRow {
            visible: root.matchArchives
            icon: "archive"
            title: qsTr("Advanced archive formats")
            subtitle: qsTr("Enable specialized compression algorithms (.7z, .tar.bz2, .tar.xz, .tar.zst, .cpio) in Compress menus")

            LoafSwitch {
                id: expArchSwitch
                checked: theme.showAdvancedArchives
                onToggled: theme.showAdvancedArchives = checked
            }
        }

        SettingDivider { visible: root.matchArchives && (root.matchPcCustom || root.matchShareLink) }

        SettingRow {
            visible: root.matchPcCustom
            icon: "desktop"
            title: qsTr("This PC dashboard customization")
            subtitle: qsTr("Allow reordering, toggling, and customizing storage drives and places sections on the This PC overview")

            LoafSwitch {
                id: pcCustomSwitch
                checked: theme.experimentalPcCustomization
                onToggled: theme.experimentalPcCustomization = checked
            }
        }

        SettingDivider { visible: root.matchPcCustom && root.matchShareLink }

        SettingRow {
            visible: root.matchShareLink
            icon: "broadcast"
            title: qsTr("P2P share via link")
            subtitle: qsTr("Serve files directly from your machine using an encrypted Cloudflare tunnel and unlock the Share settings tab")

            LoafSwitch {
                id: shareViaLinkSwitch
                checked: theme.shareViaLinkEnabled
                onToggled: {
                    theme.shareViaLinkEnabled = checked;
                    if (checked && typeof core !== "undefined" && core) {
                        if (!core.is_cloudflared_installed()) {
                            core.install_cloudflared();
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: theme
        function onShowExperimentalIconsChanged() {
            if (expIconSwitch.checked !== theme.showExperimentalIcons)
                expIconSwitch.checked = theme.showExperimentalIcons
        }
        function onShowAdvancedArchivesChanged() {
            if (expArchSwitch.checked !== theme.showAdvancedArchives)
                expArchSwitch.checked = theme.showAdvancedArchives
        }
        function onExperimentalPcCustomizationChanged() {
            if (pcCustomSwitch.checked !== theme.experimentalPcCustomization)
                pcCustomSwitch.checked = theme.experimentalPcCustomization
        }
        function onShareViaLinkEnabledChanged() {
            if (shareViaLinkSwitch.checked !== theme.shareViaLinkEnabled)
                shareViaLinkSwitch.checked = theme.shareViaLinkEnabled
        }
    }
}
