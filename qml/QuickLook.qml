import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// Quick Look (Space): preview images, text/code/markdown, archives, and
// large thumbnails of videos, PDFs and fonts without opening an app.
LoafPopup {
    id: quickLook
    parent: Overlay.overlay
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Window shortcuts are blocked while a modal popup is open, so Space
    // (which opened Quick Look) needs its own shortcut to close it again.
    Shortcut { sequence: "Space"; enabled: quickLook.visible; onActivated: quickLook.close() }
    // "Press Enter to open it": the window's own Enter handling is blocked
    // while this modal popup is open.
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: quickLook.visible && (quickLook.info.path || "").length > 0
        // Same as Enter in the file view: folders and archives open inside
        // Loaf, and the Trash keeps its own rules.
        onActivated: { quickLook.close(); window.activePane.openSelected(); }
    }

    // No resting scale/opacity of 0: with animations off (reduce motion,
    // low-power) the enter transition is skipped, and the popup would stay
    // invisible while still blocking the window.
    transformOrigin: Item.Center

    enter: Transition {
        enabled: theme.animate
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.15; to: 1.0; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }
    }

    exit: Transition {
        enabled: theme.animate
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 160; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.20; duration: 160; easing.type: Easing.InCubic }
        }
    }

    property var info: ({})
    property bool imageFailed: false
    // Rendered once per open so scrolling never re-runs the highlighter.
    property string previewHtml: ""

    readonly property bool isCode: info.language !== undefined
        && info.language !== "" && info.language !== "text"
    readonly property bool isMarkdown: info.language === "markdown"
    // Played with AnimatedImage (the thumbnail provider only gives a still frame).
    readonly property bool isGif: info.kind === "image" && /\.gif$/i.test(String(info.name || ""))

    readonly property bool isAudio: info.kind === "media"
        && /\.(mp3|flac|wav|ogg|oga|m4a|aac|opus|wma)$/i.test(String(info.name || ""))

    function mediaIcon() {
        return info.kind === "archive" ? "file-zip" : info.kind === "folder" ? "folder"
            : (info.kind === "image" ? "image"
            : (info.kind === "media" ? (isAudio ? "music" : "video") : "file-text"));
    }

    // The archive listing arrives later from a worker thread.
    Connections {
        target: core
        function onArchive_preview_ready(json) {
            var r = JSON.parse(json);
            if (r.path !== quickLook.info.path)
                return;
            var next = Object.assign({}, quickLook.info);
            next.text = r.text;
            next.truncated = r.truncated;
            next.note = r.note;
            quickLook.info = next;
            quickLook.previewHtml = quickLook.buildPreviewHtml();
        }
    }

    function fallbackIcon() {
        return info.kind === "folder" ? "folder"
            : (info.kind === "media" ? (isAudio ? "music" : "video") : "file");
    }

    width: Math.min(window.width - 160, 900)
    height: Math.min(window.height - 160, 640)

    function showFor(path) {
        var raw = "{}";
        try {
            raw = core.quick_look(path) || "{}";
        } catch (e) {
            raw = "{}";
        }
        info = JSON.parse(raw);
        imageFailed = false;
        if (info.kind === "archive")
            core.start_archive_preview(path);
        previewHtml = buildPreviewHtml();
        // The exit transition leaves opacity/scale low; with animations off the
        // enter transition won't restore them.
        opacity = 1;
        scale = 1;
        openAt((window.width - width) / 2, (window.height - height) / 2);
    }

    // ---- markup helpers ---------------------------------------------------

    function escapeHtml(s) {
        return String(s)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
    }

    function span(color, text, bold) {
        return "<font color=\"" + color + "\"" + (bold ? " weight=\"bold\"" : "") + ">"
            + escapeHtml(text) + "</font>";
    }

    function keywordSet(language) {
        var common = "if else for while return function class const let var new this null true false import from export default switch case break continue do try catch finally throw async await typeof instanceof extends super static public private protected interface enum implements package void int float double char bool string bool";
        switch (language) {
        case "rust":
            return "fn let mut const static struct enum impl trait pub use mod match if else for while loop return where ref self Self crate as in break continue unsafe move dyn box async await match Some None Ok Err";
        case "python":
            return "def class return if elif else for while import from as with try except finally raise lambda None True False and or not in is pass yield async await global nonlocal assert del";
        case "javascript":
            return common;
        case "c":
        case "cpp":
            return common + " size_t typedef struct union enum namespace template typename operator using virtual override delete nullptr printf malloc free sizeof";
        case "java":
            return common + " public private protected abstract extends implements throws void int long double float boolean char byte short synchronized native final transient";
        case "go":
            return "package import func var const type struct interface map chan go defer if else for range return switch case break continue select fallthrough nil true false";
        case "shell":
        case "nix":
            return "if then else elif fi for while do done case esac function return export local readonly source echo cd exit set unset local in with let rec inherit";
        case "lua":
            return "function local end if then elseif else for while do return break repeat until nil true false and or not in";
        case "sql":
            return "select from where insert into values update set delete create table drop alter index join inner left right outer on group by order having limit offset union distinct as and or not null primary key foreign references default";
        case "css":
            return "important media supports keyframes import charset font-face root inherit initial unset";
        default:
            return common;
        }
    }

    function keywordsFor(language) {
        var set = {};
        var list = keywordSet(language).split(" ");
        for (var i = 0; i < list.length; ++i) {
            if (list[i].length > 0)
                set[list[i]] = true;
        }
        return set;
    }

    function highlightCode(code, language) {
        var keywords = keywordsFor(language);
        var commentColor = theme.outline;
        var stringColor = theme.syntaxString;
        var numberColor = theme.syntaxNumber;
        var keywordColor = theme.syntaxKeyword;

        // One pass over the source: the first alternative that matches at a
        // position wins, so comments/strings are consumed whole.
        var re = language === "python" || language === "shell" || language === "nix" || language === "yaml"
            ? /(^#!.*|\/\/[^\n]*|#[^\n]*)|("(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')|(\b\d+(?:\.\d+)?\b)|([A-Za-z_][A-Za-z0-9_]*)/gm
            : /(\/\*[\s\S]*?\*\/|\/\/[^\n]*|<!--[\s\S]*?-->|#[^\n]*)|("(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`)|(\b\d+(?:\.\d+)?\b)|([A-Za-z_][A-Za-z0-9_]*)/gm;

        var out = "";
        var last = 0;
        var m;
        while ((m = re.exec(code)) !== null) {
            if (m.index > last)
                out += escapeHtml(code.substring(last, m.index));
            if (m[1])
                out += span(commentColor, m[1]);
            else if (m[2])
                out += span(stringColor, m[2]);
            else if (m[3])
                out += span(numberColor, m[3]);
            else if (m[4])
                out += keywords[m[4]] ? span(keywordColor, m[4], true) : escapeHtml(m[4]);
            last = re.lastIndex;
            if (m[0].length === 0)
                re.lastIndex++;
        }
        out += escapeHtml(code.substring(last));
        return out;
    }

    function renderMarkdownInline(escaped) {
        var out = escaped;
        out = out.replace(/`([^`]+)`/g, "<font color=\"" + theme.primary + "\"><i>$1</i></font>");
        out = out.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
        out = out.replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<i>$2</i>");
        out = out.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g,
            "<font color=\"" + theme.primary + "\" underline=\"single\">$1</font>");
        return out;
    }

    function renderMarkdown(src) {
        var lines = src.split("\n");
        var html = "";
        var inCode = false;
        var headingColor = theme.primary;
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i];
            var trimmed = line.trim();

            if (/^```/.test(trimmed)) {
                inCode = !inCode;
                html += span(theme.outline, trimmed) + "<br>";
                continue;
            }
            if (inCode) {
                html += span(theme.secondaryContainerFg, line) + "<br>";
                continue;
            }
            if (trimmed.length === 0) {
                html += "<br>";
                continue;
            }
            var heading = /^(#{1,6})\s+(.*)$/.exec(trimmed);
            if (heading) {
                var level = heading[1].length;
                html += "<font color=\"" + headingColor + "\" weight=\"bold\" size=\""
                    + (20 - level * 2) + "\">" + renderMarkdownInline(escapeHtml(heading[2])) + "</font><br>";
                continue;
            }
            if (/^(-{3,}|\*{3,}|_{3,})$/.test(trimmed)) {
                html += span(theme.outline, "──────────") + "<br>";
                continue;
            }
            if (/^>\s?/.test(trimmed)) {
                html += span(theme.textMuted, "│ " + renderMarkdownInline(escapeHtml(trimmed.replace(/^>\s?/, "")))) + "<br>";
                continue;
            }
            var bullet = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/.exec(line);
            if (bullet) {
                var pad = bullet[1].length > 0 ? "&nbsp;".repeat(Math.min(bullet[1].length, 8)) : "";
                var marker = /^\d/.test(bullet[2]) ? bullet[2] + " " : "• ";
                html += pad + span(theme.primary, marker) + renderMarkdownInline(escapeHtml(bullet[3])) + "<br>";
                continue;
            }
            html += renderMarkdownInline(escapeHtml(line)) + "<br>";
        }
        return html;
    }

    function buildPreviewHtml() {
        if (!info || (info.kind !== "text" && info.kind !== "archive"))
            return "";
        if (info.language === "markdown")
            return renderMarkdown(String(info.text || ""));
        var text = String(info.text || "");
        if (info.kind === "archive")
            return "<pre style=\"margin:0px\">" + escapeHtml(text) + "</pre>";
        if (!isCode)
            return escapeHtml(text);
        // Highlighting runs in JS on the UI thread: keep it bounded.
        if (text.length > 65536 || theme.lowPower)
            return "<pre style=\"margin:0px\">" + escapeHtml(text) + "</pre>";
        return "<pre style=\"margin:0px\">" + highlightCode(text, info.language) + "</pre>";
    }

    // ---- content ----------------------------------------------------------

    ColumnLayout {
        width: quickLook.width - 2 * quickLook.contentPadding
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            LoafIcon {
                name: quickLook.mediaIcon()
                size: 22
                color: theme.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: quickLook.info.name || ""
                    color: theme.textMain
                    font.pixelSize: theme.fs(14)
                    font.bold: true
                    elide: Text.ElideMiddle
                }
                Text {
                    Layout.fillWidth: true
                    text: (quickLook.info.size_str || "-") + "  ·  "
                        + (quickLook.info.modified_str || "-") + "  ·  "
                        + (quickLook.info.path || "")
                    color: theme.textMuted
                    font.pixelSize: theme.fs(11)
                    elide: Text.ElideMiddle
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: theme.separator
        }

        // Image preview
        Item {
            visible: quickLook.info.kind === "image" || ((quickLook.info.kind === "thumbnail" || quickLook.info.kind === "media") && quickLookImage.status === Image.Ready)
            Layout.fillWidth: true
            Layout.fillHeight: true

            AnimatedImage {
                anchors.fill: parent
                anchors.margins: 4
                visible: quickLook.isGif
                source: visible ? (quickLook.info.image_url || "") : ""
                playing: visible && quickLook.visible
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Image {
                id: quickLookImage
                anchors.fill: parent
                anchors.margins: 4
                visible: !quickLook.isGif
                source: quickLook.isGif ? "" : quickLook.info.kind === "image"
                    ? ((quickLook.imageFailed && quickLook.info.thumb_id) ? ("image://thumb/" + quickLook.info.thumb_id) : (quickLook.info.image_url || ""))
                    : ((quickLook.info.kind === "thumbnail" || quickLook.info.kind === "media") && quickLook.info.thumb_id ? ("image://thumb/" + quickLook.info.thumb_id) : "")
                sourceSize.width: 1024
                sourceSize.height: 1024
                onStatusChanged: if (status === Image.Error && quickLook.info.kind === "image") quickLook.imageFailed = true
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                cache: true
            }

            Text {
                anchors.centerIn: parent
                visible: quickLookImage.status === Image.Error
                text: qsTr("Could not render this image")
                color: theme.textMuted
                font.pixelSize: theme.fs(13)
            }
        }

        // Text / code / markdown preview
        Flickable {
            id: previewFlick
            visible: quickLook.info.kind === "text" || quickLook.info.kind === "archive"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: Math.max(width, previewText.implicitWidth + 24)
            contentHeight: Math.max(height, previewText.implicitHeight + 24)
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

            Text {
                id: previewText
                x: 12
                y: 12
                text: quickLook.previewHtml
                textFormat: Text.RichText
                color: theme.textMain
                font.pixelSize: theme.fs(13)
                // Code keeps its own line breaks and scrolls sideways;
                // prose wraps to the pane width.
                wrapMode: quickLook.isCode && !quickLook.isMarkdown ? Text.NoWrap : Text.Wrap
                width: quickLook.isCode && !quickLook.isMarkdown
                    ? implicitWidth
                    : previewFlick.width - 24
            }
        }

        // Folder / media / unsupported
        ColumnLayout {
            visible: quickLook.info.kind !== "image" && quickLook.info.kind !== "text" && quickLook.info.kind !== "archive"
                && !((quickLook.info.kind === "thumbnail" || quickLook.info.kind === "media") && quickLookImage.status === Image.Ready)
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Item { Layout.fillHeight: true }

            LoafIcon {
                Layout.alignment: Qt.AlignHCenter
                name: quickLook.fallbackIcon()
                size: 46
                color: theme.textMuted
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                text: quickLook.info.note || ""
                color: theme.textMuted
                font.pixelSize: theme.fs(13)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }
        }

        Text {
            visible: quickLook.info.truncated === true
            text: qsTr("Preview truncated — showing the first part of the file")
            color: theme.textMuted
            font.pixelSize: theme.fs(11)
        }
    }
}
