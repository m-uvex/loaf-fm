import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.loaf

// Rename several items at once: find & replace, numbered pattern, or case.
LoafDialog {
    id: dlg
    title: qsTr("Rename %1 Items").arg(items.length)
    dialogWidth: Math.min(window.width - 80, 620)

    // [{ path, name, is_dir }]
    property var items: []
    property int mode: 0
    property string findText: ""
    property string replaceText: ""
    property bool useRegex: false
    property bool matchCase: false
    property string pattern: qsTr("[name] ###")
    property int startNumber: 1
    property string caseMode: "lower"

    function showFor(list) {
        items = list;
        open();
    }

    function splitName(name, isDir) {
        var dot = name.lastIndexOf(".");
        if (isDir || dot <= 0)
            return { base: name, ext: "" };
        return { base: name.substring(0, dot), ext: name.substring(dot) };
    }

    function newName(item, i) {
        var parts = splitName(item.name, item.is_dir);
        if (mode === 0) {
            if (findText.length === 0)
                return item.name;
            try {
                var flags = matchCase ? "g" : "gi";
                var re = useRegex ? new RegExp(findText, flags)
                    : new RegExp(findText.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), flags);
                return parts.base.replace(re, replaceText) + parts.ext;
            } catch (e) {
                return item.name;
            }
        }
        if (mode === 1) {
            var n = startNumber + i;
            var out = pattern.replace(/#+/g, function(m) {
                var s = String(n);
                while (s.length < m.length)
                    s = "0" + s;
                return s;
            });
            out = out.split("[name]").join(parts.base).split("[ext]").join(parts.ext.replace(/^\./, ""));
            return out + (pattern.indexOf("[ext]") >= 0 ? "" : parts.ext);
        }
        var b = parts.base;
        if (caseMode === "lower")
            b = b.toLowerCase();
        else if (caseMode === "upper")
            b = b.toUpperCase();
        else
            b = b.toLowerCase().replace(/(^|[\s_\-])(\S)/g, function(m, sep, c) { return sep + c.toUpperCase(); });
        return b + parts.ext;
    }

    readonly property var preview: {
        var seen = {};
        var out = [];
        for (var i = 0; i < items.length; ++i) {
            var nn = newName(items[i], i).trim();
            var bad = nn.length === 0 || nn.indexOf("/") >= 0 || seen[nn] === true;
            seen[nn] = true;
            out.push({ old: items[i].name, name: nn, path: items[i].path, bad: bad, changed: nn !== items[i].name });
        }
        return out;
    }
    readonly property bool valid: preview.length > 0 && !preview.some(function(p) { return p.bad; })
        && preview.some(function(p) { return p.changed; })

    LoafSegmented {
        options: [
            { value: 0, label: qsTr("Find & Replace") },
            { value: 1, label: qsTr("Pattern") },
            { value: 2, label: qsTr("Case") }
        ]
        value: dlg.mode
        onSelected: function(v) { dlg.mode = v; }
    }

    GridLayout {
        visible: dlg.mode === 0
        Layout.fillWidth: true
        columns: 2
        Text { text: qsTr("Find"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
        LoafTextField { Layout.fillWidth: true; text: dlg.findText; onTextChanged: dlg.findText = text; selectByMouse: true }
        Text { text: qsTr("Replace with"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
        LoafTextField { Layout.fillWidth: true; text: dlg.replaceText; onTextChanged: dlg.replaceText = text; selectByMouse: true }
        Item { width: 1; height: 1 }
        RowLayout {
            LoafCheckBox { text: qsTr("Regular expression"); checked: dlg.useRegex; onToggled: dlg.useRegex = checked }
            LoafCheckBox { text: qsTr("Match case"); checked: dlg.matchCase; onToggled: dlg.matchCase = checked }
        }
    }

    GridLayout {
        visible: dlg.mode === 1
        Layout.fillWidth: true
        columns: 2
        Text { text: qsTr("Pattern"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
        LoafTextField { Layout.fillWidth: true; text: dlg.pattern; onTextChanged: dlg.pattern = text; selectByMouse: true }
        Text { text: qsTr("Start at"); color: theme.textMuted; font.pixelSize: theme.fs(12) }
        LoafTextField {
            Layout.preferredWidth: 120
            text: String(dlg.startNumber)
            validator: IntValidator { bottom: 0; top: 999999 }
            onTextChanged: if (acceptableInput) dlg.startNumber = parseInt(text)
        }
        Item { width: 1; height: 1 }
        Text {
            text: qsTr("### = number, [name] = original name, [ext] = extension")
            color: theme.textMuted
            font.pixelSize: theme.fs(11)
        }
    }

    LoafSegmented {
        visible: dlg.mode === 2
        options: [
            { value: "lower", label: qsTr("lowercase") },
            { value: "upper", label: qsTr("UPPERCASE") },
            { value: "title", label: qsTr("Title Case") }
        ]
        value: dlg.caseMode
        onSelected: function(v) { dlg.caseMode = v; }
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(240, Math.max(60, contentHeight))
        clip: true
        model: dlg.preview
        ScrollBar.vertical: ScrollBar {}
        delegate: RowLayout {
            required property var modelData
            width: ListView.view.width
            spacing: 8
            Text {
                Layout.preferredWidth: parent.width * 0.45
                text: modelData.old
                color: theme.textMuted
                font.pixelSize: theme.fs(12)
                elide: Text.ElideMiddle
            }
            LoafIcon { name: "arrow-right"; size: 12; color: theme.outlineAlpha(theme.outline) }
            Text {
                Layout.fillWidth: true
                text: modelData.name
                color: modelData.bad ? theme.danger : (modelData.changed ? theme.primary : theme.textMain)
                font.pixelSize: theme.fs(12)
                font.bold: modelData.changed
                elide: Text.ElideMiddle
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            visible: !dlg.valid && dlg.preview.some(function(p) { return p.bad; })
            text: qsTr("Some new names are empty, invalid or duplicated")
            color: theme.danger
            font.pixelSize: theme.fs(11)
        }
        Item { Layout.fillWidth: true }
        LoafButton { text: qsTr("Cancel"); variant: "text"; onClicked: dlg.close() }
        LoafButton {
            text: qsTr("Rename")
            variant: "filled"
            enabled: dlg.valid
            onClicked: {
                var list = dlg.preview.filter(function(p) { return p.changed; })
                    .map(function(p) { return { path: p.path, name: p.name }; });
                var err = core.batch_rename(JSON.stringify(list));
                if (err.length > 0) {
                    window.toast("error", err);
                } else {
                    dlg.close();
                }
            }
        }
    }
}
