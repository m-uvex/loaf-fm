#!/usr/bin/env python3
"""Exercise submenu effects and saved preferences using QtTest-owned windows.

Build first with cargo build. Requires QtTest QML. Use --platform wayland for
hardware blur checks; the default offscreen/software run checks safe fallback.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


QML = r'''
TestCase { id: effectsTest; when: false }
Timer { interval: 150; running: true; onTriggered: {
    try {
        function demand(ok, message) { if (!ok) throw new Error(message); }
        function find(item, predicate) {
            if (predicate(item)) return item;
            for (var child of item.children || []) {
                var result = find(child, predicate);
                if (result) return result;
            }
            return null;
        }
        function checkMenu(menu) {
            demand(menu.visible, "Menu did not open");
            var expectedOpacity = theme.submenuEffects && !theme.lowPower ? theme.panelOpacity : 1.0;
            var backing = menu.background.children.filter(function(child) {
                return child.visible;
            });
            if (expectedOpacity < 1.0)
                demand(backing.length === 1, "Translucent menu backing has an extra layer");
            var surface = backing[backing.length - 1];
            demand(surface && Math.abs(surface.color.a - expectedOpacity) < 0.01,
                "Menu backing does not follow panel opacity " + expectedOpacity);
            if (!theme.submenuEffects)
                demand(surface.color === theme.menuSurface, "Disabled option changed original menu color");
        }
        function dismiss(menu) {
            // Escape closes the innermost hovered submenu first.
            for (var i = 0; menu.visible && i < 3; ++i) {
                effectsTest.keyClick(Qt.Key_Escape); effectsTest.wait(150);
            }
            demand(!menu.visible, "Escape did not close menu");
        }
        window.width = 1000; window.height = 900;
        theme.lowPowerSetting = "off"; theme.panelOpacity = 0.45;
        theme.reduceMotionSetting = true;
        effectsTest.wait(250);
        demand(theme.submenuEffects === EXPECTED, "Saved/default submenu preference is wrong");
        if (PHASE === 2) { console.log("SUBMENU_EFFECTS_PASS"); Qt.quit(); return; }

        window.openSettings(); effectsTest.wait(250);
        settingsLoader.item.searchQuery = "submenu";
        effectsTest.wait(250);
        var row = find(settingsLoader.item, function(item) { return item.title === qsTr("Submenu translucency"); });
        demand(row && row.visible, "Search did not expose submenu setting");
        var toggle = find(row, function(item) { return item.checked !== undefined && item.toggled !== undefined; });
        demand(toggle, "Submenu switch missing");
        var flick = row.parent;
        while (flick && flick.contentY === undefined) flick = flick.parent;
        demand(flick, "Settings scroll container missing");
        flick.contentY += toggle.mapToItem(flick, 0, 0).y - 80;
        effectsTest.wait(100);
        effectsTest.mouseClick(toggle, toggle.width - 20, toggle.height / 2, Qt.LeftButton);
        effectsTest.wait(200);
        demand(theme.submenuEffects === !EXPECTED, "Click did not change submenu preference");
        window.width = 640; window.height = 480;
        effectsTest.wait(200);
        demand(row.width > 0 && row.width <= settingsLoader.item.width, "Compact settings overflow horizontally");
        demand(toggle.width > 0 && toggle.width <= row.width, "Compact toggle overflow");
        if (ARTIFACTS && PHASE === 0) effectsTest.grabImage(window.contentItem).save(ARTIFACTS + "/settings-submenu-option.png");

        window.width = 1000; window.height = 900;
        window.showFiles(); pane0.engine.set_path(FILES); pane0.engine.set_view("list");
        effectsTest.wait(300);
        for (var attempt = 0; attempt < 2; ++attempt) {
            effectsTest.mouseClick(pane0, 180, 160, Qt.RightButton);
            effectsTest.wait(100);
            checkMenu(contextMenu);
            if (attempt === 0) {
                for (var opacity of [0.0, 0.80, 1.0, 0.45]) {
                    theme.panelOpacity = opacity;
                    effectsTest.wait(100);
                    checkMenu(contextMenu);
                }
            }
            if (ARTIFACTS && attempt === 0) effectsTest.grabImage(window.contentItem).save(ARTIFACTS + "/menu-" + (theme.submenuEffects ? "on" : "off") + ".png");
            dismiss(contextMenu);
        }
        effectsTest.mouseClick(viewDropdownButton, viewDropdownButton.width / 2, viewDropdownButton.height / 2, Qt.LeftButton);
        effectsTest.wait(100);
        checkMenu(viewMenuPopup);
        dismiss(viewMenuPopup);

        // Populate a harmless menu, then use pointer input to open its child.
        contextMenu.model = [{text: "Test submenu", submenu: [{text: "No operation", action: function() {}}]}];
        contextMenu.openAt(250, 150); effectsTest.wait(100);
        effectsTest.mouseMove(contextMenu.contentItem, 40, 18);
        effectsTest.wait(500);
        demand(contextMenu.currentSubmenu, "Hover did not open nested submenu");
        checkMenu(contextMenu.currentSubmenu);
        if (ARTIFACTS && PHASE === 0) effectsTest.grabImage(window.contentItem).save(ARTIFACTS + "/nested-menu-on.png");
        dismiss(contextMenu);

        // This menu is shared with file-drop actions; never execute a transfer.
        rmbDropMenu.showAt(250, 150, [FILES + "/sample.txt"], FILES);
        effectsTest.wait(100); checkMenu(rmbDropMenu);
        dismiss(rmbDropMenu);

        if (PHASE === 0) {
            theme.lowPowerSetting = "on"; effectsTest.wait(100);
            contextMenu.openAt(250, 150); effectsTest.wait(100); checkMenu(contextMenu);
            demand(contextMenu.surfaceColor.a === 1, "Low-power menu must be opaque");
            contextMenu.close(); effectsTest.wait(100);
            theme.lowPowerSetting = "off"; theme.panelOpacity = 1;
            contextMenu.openAt(250, 150); effectsTest.wait(100); checkMenu(contextMenu);
            demand(contextMenu.surfaceColor.a === 1, "Solid menu must be opaque");
            contextMenu.close(); theme.panelOpacity = 0.45;
        }
        console.log("SUBMENU_EFFECTS_PASS"); Qt.quit();
    } catch (error) { console.error("SUBMENU_EFFECTS_FAILURE", error); Qt.quit(); }
} }
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--platform", choices=("offscreen", "wayland"), default="offscreen")
    parser.add_argument("--artifacts", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    binary = (args.binary or root / "target/debug/loaf").resolve()
    if args.artifacts:
        args.artifacts.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="loaf-submenu-test-") as directory:
        sandbox = Path(directory)
        files = sandbox / "files"
        files.mkdir()
        (files / "sample.txt").write_text("test-owned file; no transfers executed")
        for index in range(20):
            (files / f"Example document {index + 1:02d}.txt").write_text("Temporary test document")
        env = os.environ.copy()
        env.pop("QT_LOGGING_RULES", None)
        env.update(QT_QPA_PLATFORM=args.platform, QT_QUICK_CONTROLS_STYLE="Basic", QT_FORCE_STDERR_LOGGING="1")
        if args.platform == "offscreen":
            env["QT_QUICK_BACKEND"] = "software"
        for key in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
            path = sandbox / key
            path.mkdir()
            env[key] = str(path)
        for entry in (root / "qml").iterdir():
            if entry.name != "main.qml":
                (sandbox / entry.name).symlink_to(entry)
        source = (root / "qml/main.qml").read_text().replace("import app.loaf", "import app.loaf\nimport QtTest", 1)
        for phase in range(3):
            script = QML.replace("EXPECTED", "true" if phase == 1 else "false").replace("PHASE", str(phase))
            script = script.replace("FILES", json.dumps(str(files)))
            script = script.replace("ARTIFACTS", json.dumps(str(args.artifacts.resolve()) if args.artifacts else ""))
            main_qml = sandbox / "main.qml"
            main_qml.write_text(source.rsplit("}", 1)[0] + script + "}\n")
            env["LOAF_QML"] = str(main_qml)
            result = subprocess.run([str(binary), "--new-window"], env=env, capture_output=True, text=True, timeout=25)
            output = result.stdout + result.stderr
            if args.artifacts:
                (args.artifacts / f"phase-{phase}.log").write_text(output)
            assert result.returncode == 0 and "SUBMENU_EFFECTS_PASS" in output, output
            assert not any(message in output for message in ("SUBMENU_EFFECTS_FAILURE", "Binding loop detected", "ReferenceError:", "TypeError:")), output
            config = json.loads((sandbox / "XDG_CONFIG_HOME/loaf/config.json").read_text())
            assert config["submenuEffects"] == ("true" if phase == 0 else "false"), config.get("submenuEffects")
            print(f"SUBMENU_PHASE_{phase}_PASS")
    print("ALL_SUBMENU_EFFECTS_TESTS_PASS")


if __name__ == "__main__":
    main()
