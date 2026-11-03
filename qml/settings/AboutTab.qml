import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

ColumnLayout {
    id: root

    property string searchQuery: ""

    property string repoDescription: qsTr("A beautiful and fast Rust-based Material 3 Expressive file manager for Linux.")
    property var contributors: []
    property bool contributorsLoading: false
    property string contributorsError: ""

    // Refresh the live data at most once every five minutes.
    property double lastRefreshMs: 0
    // login -> { name, ts }: display names change rarely, so cache them longer.
    property var profileCache: ({})
    property var pendingList: []

    readonly property bool isCompact: (typeof settingsView !== "undefined" && settingsView.isCompact) || root.width < 560
    readonly property string repoUrl: "https://github.com/m-uvex/loaf-fm"

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

    readonly property bool matchAbout: matches("about loaf version credits github contributors license repo description")
    readonly property bool matchContributors: matches("contributors people team authors credits github")
    readonly property int matchCount: (matchAbout ? 1 : 0) + (matchContributors ? 1 : 0)

    Timer {
        id: requestTimeout
        interval: 9000
        repeat: false
        onTriggered: {
            if (!root.contributorsLoading)
                return;
            root.contributorsLoading = false;
            if (root.contributors.length === 0 && root.pendingList.length > 0)
                root.contributors = root.pendingList;
            root.contributorsError = qsTr("Could not reach GitHub. Check your connection.");
        }
    }

    // Called whenever the tab becomes visible; the data is only re-fetched
    // when it is missing or older than five minutes.
    function maybeRefresh() {
        if (root.contributorsLoading)
            return;
        if (root.contributors.length > 0 && Date.now() - root.lastRefreshMs < 5 * 60 * 1000)
            return;
        refreshRepository();
    }

    // Pulls the live repository description, the contributor list and each
    // contributor's GitHub display name.
    function refreshRepository() {
        if (root.contributorsLoading)
            return;
        root.contributorsLoading = true;
        root.contributorsError = "";
        root.lastRefreshMs = Date.now();
        requestTimeout.restart();

        var repo = new XMLHttpRequest();
        repo.onreadystatechange = function() {
            if (repo.readyState !== XMLHttpRequest.DONE)
                return;
            if (repo.status !== 200)
                return;
            try {
                var info = JSON.parse(repo.responseText);
                if (info && typeof info.description === "string" && info.description.length > 0)
                    root.repoDescription = info.description;
            } catch (e) { /* keep the bundled description */ }
        };
        repo.open("GET", "https://api.github.com/repos/m-uvex/loaf-fm");
        repo.setRequestHeader("Accept", "application/vnd.github+json");
        repo.send();

        var people = new XMLHttpRequest();
        people.onreadystatechange = function() {
            if (people.readyState !== XMLHttpRequest.DONE)
                return;
            if (people.status !== 200) {
                requestTimeout.stop();
                root.contributorsLoading = false;
                root.contributorsError = qsTr("Contributors need an internet connection.");
                return;
            }
            var list = [];
            try {
                var raw = JSON.parse(people.responseText);
                if (Array.isArray(raw)) {
                    for (var i = 0; i < raw.length; ++i) {
                        var c = raw[i];
                        if (!c || !c.login || /\[bot\]$/.test(c.login))
                            continue;
                        list.push({
                            login: c.login,
                            name: c.login,
                            avatar: c.avatar_url || "",
                            contributions: c.contributions || 0
                        });
                    }
                }
            } catch (e) {
                requestTimeout.stop();
                root.contributorsLoading = false;
                root.contributorsError = qsTr("Could not read the contributor list.");
                return;
            }
            root.resolveNames(list);
        };
        people.open("GET", "https://api.github.com/repos/m-uvex/loaf-fm/contributors?per_page=100");
        people.setRequestHeader("Accept", "application/vnd.github+json");
        people.send();
    }

    // Looks up each contributor's profile to get their display name. Falls
    // back to the login when the profile has no name or the request fails.
    function resolveNames(list) {
        if (list.length === 0) {
            requestTimeout.stop();
            root.contributors = [];
            root.contributorsLoading = false;
            return;
        }
        root.pendingList = list;
        var remaining = list.length;
        var now = Date.now();

        function complete() {
            if (--remaining > 0)
                return;
            requestTimeout.stop();
            root.contributorsLoading = false;
            root.contributors = list;
            root.pendingList = [];
            root.lastRefreshMs = Date.now();
        }

        for (var i = 0; i < list.length; ++i) {
            (function(entry) {
                var cached = root.profileCache[entry.login];
                if (cached && now - cached.ts < 60 * 60 * 1000) {
                    entry.name = cached.name;
                    complete();
                    return;
                }
                var req = new XMLHttpRequest();
                req.onreadystatechange = function() {
                    if (req.readyState !== XMLHttpRequest.DONE)
                        return;
                    var display = entry.login;
                    if (req.status === 200) {
                        try {
                            var user = JSON.parse(req.responseText);
                            if (user && typeof user.name === "string" && user.name.trim().length > 0)
                                display = user.name.trim();
                        } catch (e) { /* keep the login */ }
                    }
                    entry.name = display;
                    root.profileCache[entry.login] = { name: display, ts: Date.now() };
                    complete();
                };
                req.open("GET", "https://api.github.com/users/" + encodeURIComponent(entry.login));
                req.setRequestHeader("Accept", "application/vnd.github+json");
                req.send();
            })(list[i]);
        }
    }

    // Only when the About tab is shown: no network requests just for opening Settings.
    Component.onCompleted: if (visible) maybeRefresh()
    onVisibleChanged: if (visible) maybeRefresh()

    Layout.fillWidth: true
    spacing: 16

    // ---- Hero identity card -------------------------------------------
    Rectangle {
        visible: root.matchAbout
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        radius: theme.radiusXl
        color: theme.surfaceContainer
        border.width: 1
        border.color: theme.borderSubtle
        implicitHeight: heroCol.implicitHeight + (root.isCompact ? 36 : 56)

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }

        ColumnLayout {
            id: heroCol
            anchors.fill: parent
            anchors.margins: root.isCompact ? 18 : 28
            spacing: root.isCompact ? 14 : 18

            // Icon + wordmark + version, all sharing one vertical band.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.isCompact ? 14 : 18

                Rectangle {
                    id: logoBadge
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: heroText.implicitHeight + 4
                    Layout.preferredHeight: heroText.implicitHeight + 4
                    radius: width * 0.28
                    color: theme.primaryContainer
                    border.width: 2
                    border.color: theme.primary

                    LoafIcon {
                        anchors.centerIn: parent
                        name: "bread"
                        size: Math.round(parent.width * 0.52)
                        color: theme.primaryContainerFg
                    }
                }

                ColumnLayout {
                    id: heroText
                    Layout.alignment: Qt.AlignVCenter
                    spacing: root.isCompact ? 5 : 8

                    Text {
                        Layout.alignment: Qt.AlignLeft
                        text: "Loaf"
                        color: theme.textMain
                        font.pixelSize: root.isCompact ? theme.fs(28) : theme.fs(34)
                        font.bold: true
                        font.letterSpacing: -0.8
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignLeft
                        radius: theme.radiusFull
                        color: theme.secondaryContainer
                        implicitHeight: 25
                        implicitWidth: verTxt.implicitWidth + 18

                        Text {
                            id: verTxt
                            anchors.centerIn: parent
                            text: qsTr("Version ") + Qt.application.version
                            color: theme.secondaryContainerFg
                            font.pixelSize: theme.fs(11)
                            font.bold: true
                        }
                    }
                }
            }

            // Repository description (mirrors the GitHub repo blurb).
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.repoDescription
                color: theme.textMuted
                font.pixelSize: theme.fs(13)
                lineHeight: 1.2
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            // Actions, one column on narrow layouts.
            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: root.isCompact ? 1 : 2
                columnSpacing: 10
                rowSpacing: 10

                LoafButton {
                    text: qsTr("Repository")
                    icon: "github-logo"
                    variant: "filled"
                    Layout.fillWidth: root.isCompact
                    onClicked: Qt.openUrlExternally(root.repoUrl)
                }

                LoafButton {
                    text: qsTr("Report an issue")
                    icon: "bug"
                    variant: "tonal"
                    Layout.fillWidth: root.isCompact
                    onClicked: Qt.openUrlExternally(root.repoUrl + "/issues")
                }
            }
        }
    }

    // ---- Contributors --------------------------------------------------
    SettingCard {
        visible: root.matchContributors
        title: qsTr("Contributors")
        subtitle: qsTr("Everyone who has landed code in the repository, pulled live from GitHub")
        icon: "users"

        Text {
            Layout.fillWidth: true
            text: root.contributorsLoading
                ? qsTr("Loading contributors…")
                : (root.contributors.length > 0
                    ? theme.plural(root.contributors.length, qsTr("1 contributor"), qsTr("%1 contributors"))
                    : (root.contributorsError.length > 0 ? root.contributorsError : qsTr("No contributors listed yet.")))
            color: theme.textMuted
            font.pixelSize: theme.fs(12)
            wrapMode: Text.Wrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: root.contributors

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool hovered: chipMouse.containsMouse
                    readonly property string displayName: (modelData.name && modelData.name.length > 0)
                        ? modelData.name : modelData.login

                    width: chipRow.implicitWidth + 24
                    height: 46
                    radius: theme.radiusM
                    color: hovered ? theme.primaryContainer : theme.surfaceContainerHigh
                    border.width: 1
                    border.color: hovered ? theme.primary : theme.outlineVariant
                    scale: chipMouse.pressed ? 0.97 : (hovered ? 1.03 : 1.0)

                    Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                    Behavior on border.color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                    Behavior on scale { enabled: theme.animate; SpringAnimation { spring: 3.5; damping: 0.3 } }

                    Accessible.role: Accessible.Link
                    Accessible.name: displayName

                    Row {
                        id: chipRow
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9

                        Item {
                            width: 28
                            height: 28

                            // Letter avatar: always available, even offline.
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: theme.surfaceContainerHighest

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.login ? modelData.login.charAt(0).toUpperCase() : "?"
                                    color: theme.textMuted
                                    font.pixelSize: theme.fs(11)
                                    font.bold: true
                                }
                            }

                            // Circular GitHub avatar, clipped by the canvas.
                            Canvas {
                                anchors.fill: parent
                                property string src: modelData.avatar || ""

                                onSrcChanged: requestPaint()
                                onImageLoaded: requestPaint()
                                onWidthChanged: requestPaint()
                                Component.onCompleted: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.save();
                                    ctx.clearRect(0, 0, width, height);
                                    if (src.length > 0) {
                                        ctx.beginPath();
                                        ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2);
                                        ctx.closePath();
                                        ctx.clip();
                                        ctx.drawImage(src, 0, 0, width, height);
                                    }
                                    ctx.restore();
                                }
                            }
                        }

                        Text {
                            text: displayName
                            anchors.verticalCenter: parent.verticalCenter
                            color: hovered ? theme.primaryContainerFg : theme.textMain
                            font.pixelSize: theme.fs(12)
                            font.bold: hovered

                            Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationFast } }
                        }
                    }

                    ToolTip.visible: hovered
                    ToolTip.text: "@" + modelData.login
                    ToolTip.delay: 700

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(root.repoUrl + "/graphs/contributors")
                    }
                }
            }
        }
    }
}
