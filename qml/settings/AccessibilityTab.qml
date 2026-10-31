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

    readonly property bool matchLowPower: matches("performance low power mode battery old slow computer gpu")
    readonly property bool matchMotion: matches("reduce motion animations transitions springs accessibility")
    readonly property bool matchThumbnails: matches("picture thumbnails preview image photo svg gallery")
    readonly property bool matchThumbShape: matches("thumbnail shape square crop original aspect ratio preview image photo")
    readonly property bool matchShapes: matches("decorative background shapes blobs ambient bubbles")
    readonly property bool matchFontSize: matches("text size font scale accessibility larger zoom")
    readonly property bool matchIconSize: matches("icon size zoom view grid thumbnails scale")

    readonly property int matchCount: (matchLowPower ? 1 : 0) + (matchMotion ? 1 : 0) + (matchThumbnails ? 1 : 0)
        + (matchShapes ? 1 : 0) + (matchFontSize ? 1 : 0) + (matchIconSize ? 1 : 0) + (matchThumbShape ? 1 : 0)

    Layout.fillWidth: true
    spacing: 16

    // Category 1: Performance
    SettingCard {
        visible: root.matchLowPower || root.matchMotion || root.matchThumbnails || root.matchShapes
        title: qsTr("Performance & Effects")
        subtitle: qsTr("Power savings, thumbnail rendering, and motion effects")
        icon: "lightning"

        SettingRow {
            visible: root.matchLowPower
            icon: "battery-charging"
            title: qsTr("Low-power mode")
            subtitle: (theme.softwareRendering || (typeof core !== "undefined" && core && core.low_end_hardware))
                ? qsTr("Low-end hardware detected (software rendering or constrained resources). Auto keeps performance mode active.")
                : qsTr("Disables background effects, blur masks, and complex transitions for older machines and battery savings")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 140 : 260
                options: [
                    { value: "auto", label: qsTr("Auto"), shortLabel: "A" },
                    { value: "on", label: qsTr("On"), shortLabel: "On" },
                    { value: "off", label: qsTr("Off"), shortLabel: "Off" }
                ]
                value: theme.lowPowerSetting
                onSelected: function(v) { theme.lowPowerSetting = v; }
            }
        }

        SettingDivider { visible: root.matchLowPower && (root.matchMotion || root.matchThumbnails || root.matchShapes) }

        SettingRow {
            visible: root.matchMotion
            icon: "sparkle"
            title: qsTr("Reduce motion")
            subtitle: qsTr("Disable spring animations, slide transitions, and layout micro-effects")

            LoafSwitch {
                checked: theme.reduceMotionSetting
                onToggled: function(c) { theme.reduceMotionSetting = c; }
            }
        }

        SettingDivider { visible: root.matchMotion && (root.matchThumbnails || root.matchShapes) }

        SettingRow {
            visible: root.matchThumbnails
            icon: "image"
            title: qsTr("Picture thumbnails")
            subtitle: qsTr("Render background thumbnail previews for images, video posters, and SVGs")

            LoafSwitch {
                id: thumbSwitch
                checked: theme.showThumbnails
                onToggled: theme.showThumbnails = checked
            }
        }

        SettingDivider { visible: root.matchThumbnails && root.matchShapes }

        SettingRow {
            visible: root.matchShapes
            icon: "shapes"
            title: qsTr("Background decorative shapes")
            subtitle: qsTr("Display floating ambient gradient shapes in the window background")

            LoafSwitch {
                checked: theme.showBackgroundShapes
                onToggled: function(c) { theme.showBackgroundShapes = c; }
            }
        }
    }

    // Category 2: View & Scaling
    SettingCard {
        visible: root.matchFontSize || root.matchIconSize || root.matchThumbShape
        title: qsTr("View & Scaling")
        subtitle: qsTr("Text scaling and folder item icon sizes")
        icon: "magnifying-glass-plus"

        SettingRow {
            visible: root.matchFontSize
            icon: "text-aa"
            title: qsTr("Text scaling")
            subtitle: qsTr("Adjust font sizing proportionally across panes, sidebars, and dialogs")

            LoafSlider {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 260
                from: 0.85
                to: 1.30
                stepSize: 0.05
                value: theme.fontScaleSetting
                formatPercent: true
                accessibleName: qsTr("Text scaling")
                onMoved: function(v) { theme.fontScaleSetting = v; }
            }
        }

        SettingDivider { visible: root.matchFontSize && root.matchIconSize }

        SettingRow {
            visible: root.matchIconSize
            icon: "squares-four"
            title: qsTr("Icon zoom size")
            subtitle: qsTr("Default icon and thumbnail sizing for directory views (Ctrl + Scroll)")

            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                LoafSlider {
                    Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 260
                    from: 0
                    to: theme.zoomLevels.length - 1
                    stepSize: 1
                    value: theme.zoomIndex
                    showValue: false
                    accessibleName: qsTr("Icon zoom size")
                    onMoved: function(v) { theme.zoomIndex = Math.round(v); }
                }

                Rectangle {
                    implicitHeight: 26
                    radius: theme.radiusFull
                    color: theme.surfaceContainerHighest
                    implicitWidth: zoomValTxt.implicitWidth + 16

                    Text {
                        id: zoomValTxt
                        anchors.centerIn: parent
                        text: Math.round(theme.zoom * 100) + "%"
                        color: theme.textMain
                        font.pixelSize: theme.fs(11)
                        font.bold: true
                    }
                }
            }
        }

        SettingDivider { visible: (root.matchFontSize || root.matchIconSize) && root.matchThumbShape }

        SettingRow {
            visible: root.matchThumbShape
            icon: "crop"
            title: qsTr("Thumbnail shape")
            subtitle: qsTr("Crop picture thumbnails to a square, or keep their original aspect ratio")

            LoafSegmented {
                Layout.preferredWidth: (typeof settingsView !== "undefined" && settingsView.isCompact) ? 170 : 260
                enabled: theme.showThumbnails
                options: [
                    { value: "square", label: qsTr("Square"), shortLabel: qsTr("Square") },
                    { value: "original", label: qsTr("Original"), shortLabel: qsTr("Orig.") }
                ]
                value: theme.thumbnailShape
                onSelected: function(v) { theme.thumbnailShape = v; }
            }
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
