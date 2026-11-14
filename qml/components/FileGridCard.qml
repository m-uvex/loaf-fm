import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

Item {
    id: card

    property var viewPane: null
    property var hostWindow: null
    property var engineModel: null
    property var fileDragManager: null

    property int itemIndex: 0
    property string itemName: ""
    property string itemPath: ""
    property bool itemIsDir: false
    property bool itemIsSymlink: false
    property string itemIcon: ""
    property string itemSystemIcon: ""
    property bool itemThumbable: false
    property string itemThumbId: ""
    property string itemDisplayName: ""
    property bool itemStarred: false

    GridView.onPooled: cardMouse.dragging = false
    ListView.onPooled: cardMouse.dragging = false
    width: viewPane ? viewPane.cellW : 100
    height: viewPane ? viewPane.cellH : 100

    readonly property bool isSelected: !!(viewPane && viewPane.selection && viewPane.selection[itemPath])
    readonly property bool isCut: !!(hostWindow && hostWindow.cutSet && hostWindow.cutSet[itemPath])
    readonly property int cols: viewPane ? viewPane.cols() : 1
    readonly property int col: itemIndex % Math.max(1, cols)
    readonly property int rowIdx: Math.floor(itemIndex / Math.max(1, cols))

    readonly property bool isDropTarget: itemIsDir && folderDrop.containsDrag
    readonly property bool hasThumb: theme.showThumbnails && itemThumbable && thumbImg.status === Image.Ready
    readonly property bool isCursor: !!(hostWindow && hostWindow.keyboardNavActive && viewPane && viewPane.isActive && viewPane.cursorPath === itemPath)

    Accessible.role: Accessible.ListItem
    Accessible.name: itemName
    Accessible.selected: isSelected

    DropArea {
        id: folderDrop
        anchors.fill: parent
        enabled: card.itemIsDir && engineModel && !engineModel.read_only
        keys: ["text/uri-list"]
        onEntered: if (fileDragManager) fileDragManager.hover(card.itemPath, engineModel)
        onExited: if (fileDragManager && fileDragManager.hoverTarget === card.itemPath) fileDragManager.hoverTarget = ""
        onDropped: function(drop) { if (viewPane) viewPane.handleDropOn(drop, card.itemPath, card); }
    }

    Rectangle {
        id: hoverOverlay
        anchors.fill: parent
        anchors.margins: 4
        radius: theme.radiusM
        color: card.isDropTarget ? theme.primaryContainer : theme.hoverOverlay
        border.width: card.isDropTarget ? 2 : 0
        border.color: theme.primary
        visible: !card.isSelected && (cardMouse.containsMouse || card.isDropTarget)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: theme.radiusM
        color: "transparent"
        border.width: card.isCursor ? 2 : 0
        border.color: theme.primary
        visible: card.isCursor
    }

    scale: cardMouse.pressed ? 0.94 : ((cardMouse.containsMouse && !card.isSelected) ? 1.03 : 1.0)
    Behavior on scale { enabled: theme.animate; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    ColumnLayout {
        id: cardContentCol
        opacity: card.isCut ? 0.52 : 1.0
        Behavior on opacity { enabled: theme.animate; NumberAnimation { duration: theme.durationFast } }
        anchors.fill: parent
        anchors.margins: 12 * (viewPane ? viewPane.chromeScale : 1)
        spacing: 6

        Item { Layout.fillHeight: true }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: viewPane ? viewPane.iconBox : 48
            Layout.preferredHeight: viewPane ? viewPane.iconBox : 48

            LoafIcon {
                visible: !card.hasThumb && theme.iconSource === "phosphor"
                anchors.centerIn: parent
                name: card.isCut ? (card.itemIsDir ? "folder-dashed" : "file-dashed") : (card.itemIcon || "file")
                size: viewPane ? viewPane.iconSize : 24
                color: card.isSelected ? theme.secondaryContainerFg
                    : (theme.tintIcon(card.itemIsDir) ? theme.iconColorValue : theme.textMain)
            }

            Image {
                visible: !card.hasThumb && theme.iconSource !== "phosphor"
                anchors.centerIn: parent
                source: (theme.iconSource !== "phosphor" && hostWindow) ? hostWindow.systemIcon(card.itemSystemIcon) : ""
                width: (viewPane ? viewPane.iconSize : 24) + 2
                height: (viewPane ? viewPane.iconSize : 24) + 2
                sourceSize.width: 64 * (viewPane ? viewPane.zoom : 1)
                sourceSize.height: 64 * (viewPane ? viewPane.zoom : 1)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Item {
                id: thumbFrame
                anchors.centerIn: parent
                visible: card.hasThumb
                readonly property bool square: theme.thumbnailShape !== "original"
                readonly property real fit: (square || thumbImg.implicitWidth <= 0 || thumbImg.implicitHeight <= 0)
                    ? 0 : Math.min(parent.width / thumbImg.implicitWidth, parent.height / thumbImg.implicitHeight)
                width: fit > 0 ? Math.round(thumbImg.implicitWidth * fit) : parent.width
                height: fit > 0 ? Math.round(thumbImg.implicitHeight * fit) : parent.height

                Image {
                    id: thumbImg
                    anchors.fill: parent
                    source: theme.showThumbnails && card.itemThumbable && card.itemThumbId.length > 0
                        ? ("image://thumb/" + card.itemThumbId + (thumbFrame.square ? "/cover" : "") + "/round") : ""
                    fillMode: thumbFrame.square ? Image.PreserveAspectCrop : Image.Stretch
                    sourceSize.width: viewPane ? viewPane.thumbBox : 64
                    sourceSize.height: viewPane ? viewPane.thumbBox : 64
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(width, height) / 6
                    color: "transparent"
                    border.color: card.isSelected ? theme.primary : theme.outlineAlpha(theme.outlineVariant)
                    border.width: 1
                    opacity: card.isSelected ? 0.75 : 0.35
                }
            }
            Rectangle {
                visible: card.itemIsSymlink
                width: 14; height: 14; radius: 7
                color: theme.surfaceContainer
                border.color: theme.outlineAlpha(theme.outlineVariant)
                border.width: 1
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                LoafIcon { anchors.centerIn: parent; name: "arrow-square-out"; size: 9; color: theme.primary }
            }
            LoafIcon {
                visible: card.itemStarred
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: -4
                name: "star"
                size: 13
                color: theme.primary
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            active: true
            sourceComponent: (viewPane && viewPane.renamingPath === card.itemPath) ? renameEditor : nameLabel

            Component {
                id: nameLabel
                Text {
                    text: (engineModel && engineModel.is_searching_everywhere) ? (card.itemDisplayName || card.itemName) : card.itemName
                    color: card.isSelected ? theme.secondaryContainerFg : theme.textMain
                    font.pixelSize: theme.fs(11)
                    font.bold: card.itemIsDir || card.isSelected
                    font.weight: theme.fw(card.itemIsDir || card.isSelected)
                    font.family: theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignTop
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideMiddle
                }
            }
            Component {
                id: renameEditor
                InlineRename {
                    originalName: card.itemName
                    isDir: card.itemIsDir
                    onCommit: function(text) { if (viewPane) viewPane.commitRename(card.itemPath, text); }
                    onCancel: if (viewPane) viewPane.cancelRename()
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        anchors.margins: 4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        preventStealing: true
        onWheel: function(wheel) { wheel.accepted = false; }

        property point pressPt
        property bool dragging: false

        onPressed: function(mouse) {
            if (viewPane) viewPane.activated();
            if (hostWindow) hostWindow.defocusInputs();
            pressPt = Qt.point(mouse.x, mouse.y);
            dragging = false;
            if (mouse.button === Qt.LeftButton && !card.isSelected
                    && !(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
                if (viewPane) viewPane.selectRow(card.itemIndex, false, false);
            }
        }
        onPositionChanged: function(mouse) {
            if (dragging || !(mouse.buttons & (Qt.LeftButton | Qt.RightButton)) || (viewPane && viewPane.renamingPath === card.itemPath))
                return;
            if (engineModel && (engineModel.location_kind === "archive" || engineModel.location_kind === "trash" || (engineModel.location_kind === "mtp" && engineModel.read_only)))
                return;
            var dx = mouse.x - pressPt.x, dy = mouse.y - pressPt.y;
            if (dx * dx + dy * dy >= 36) {
                dragging = true;
                if (!card.isSelected && viewPane)
                    viewPane.selectRow(card.itemIndex, false, false);
                if (fileDragManager) {
                    fileDragManager.isRmb = !!(mouse.buttons & Qt.RightButton);
                    fileDragManager.cursorPos = hostWindow ? mapToItem(hostWindow.contentItem, mouse.x, mouse.y) : Qt.point(mouse.x, mouse.y);
                    fileDragManager.begin(viewPane ? viewPane.selectedPaths() : [], mouse);
                }
            }
        }
        onReleased: if (dragging) { if (fileDragManager) fileDragManager.end(); dragging = false; }
        onCanceled: if (dragging) { if (fileDragManager) fileDragManager.end(); dragging = false; }
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                if (hostWindow) hostWindow.newTab(card.itemPath);
                return;
            }
            if (mouse.button === Qt.RightButton) {
                if (!card.isSelected && viewPane)
                    viewPane.selectRow(card.itemIndex, false, false);
                if (hostWindow) {
                    var pt = mapToItem(hostWindow.contentItem, mouse.x, mouse.y);
                    hostWindow.openItemMenu(viewPane, card.itemIndex, pt.x, pt.y);
                }
            } else {
                if (typeof contextMenu !== "undefined" && contextMenu) contextMenu.close();
                if (!(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) && theme.clickToOpen === "single") {
                    if (viewPane) viewPane.openRow(card.itemIndex);
                    return;
                }
                var wasOnlySelected = card.isSelected && viewPane && viewPane.selectedCount === 1;
                if (viewPane)
                    viewPane.selectRow(card.itemIndex, !!(mouse.modifiers & Qt.ControlModifier), !!(mouse.modifiers & Qt.ShiftModifier));
                if (wasOnlySelected && !(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))
                        && theme.clickToRename && mouse.y > card.height * 0.6)
                    renameDelay.restart();
            }
        }
        onDoubleClicked: function(mouse) {
            renameDelay.stop();
            if (mouse.button === Qt.LeftButton && viewPane)
                viewPane.openRow(card.itemIndex);
        }
        Timer { id: renameDelay; interval: 500; onTriggered: if (viewPane) viewPane.startRename() }
    }
}
