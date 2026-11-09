#!/usr/bin/env python3
"""Run real UI acceptance for Date-Modified grouping in Grid and List views.

Exercises genuine QtTest mouse and keyboard events against isolated scratch fixtures.
Never touches real user data or system state.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time

QML_TEST_INC = r"""
TestCase { id: uiTest; when: false }

function check(condition, message) {
    if (!condition) {
        console.error("TEST_FAILURE: " + message);
        console.log("TEST_ABORTED_ON_FAILURE");
        Qt.quit();
        throw new Error(message);
    }
}

function waitMs(ms) {
    uiTest.wait(ms);
}

function waitUntil(predicate, message, maxMs) {
    var limit = (maxMs || 4000) / 25;
    for (var i = 0; i < limit && !predicate(); ++i) uiTest.wait(25);
    check(predicate(), message);
}

Timer {
    interval: 100
    running: true
    onTriggered: {
        try {
            runAllTests();
        } catch (e) {
            console.error("QML_TEST_EXCEPTION: " + e + "\n" + (e.stack || ""));
            console.log("TEST_ABORTED_ON_EXCEPTION");
            Qt.quit();
        }
    }
}

function findCard(item, path) {
    if (item.itemPath !== undefined && item.itemPath === path) return item;
    var children = item.children || [];
    for (var i = 0; i < children.length; ++i) {
        var found = findCard(children[i], path);
        if (found) return found;
    }
    return null;
}

function runAllTests() {
    theme.reduceMotionSetting = true;
    window.width = 1080;
    window.height = 720;
    var p = pane0;
    p.engine.set_path(testEnv.scratchDir);
    waitUntil(function() { return !p.engine.loading && p.engine.item_count === 9; }, "Fixture loaded");

    // Capture initial 1080x720 grouped grid screenshot
    p.grabToImage(function(result) {
        result.saveToFile(testEnv.artifactDir + "/grouped_grid_1080x720.png");
    });
    waitMs(80);

    // 0. Default Verification (group_by: "none")
    check(!p.isGroupedGrid(), "Default grid is not grouped");
    check(p.engine.group_by === "none", "Default group_by is none");

    // 1. Grouped Grid Verification (ascending = true means newest-first)
    p.engine.set_group("modified", true);
    p.engine.set_sort("modified", true);
    waitMs(150);
    check(p.isGroupedGrid(), "Grouped grid active");
    check(p.engine.group_by === "modified", "Group by modified");
    check(p.engine.sort_by === "modified", "Sort by modified");
    check(p.engine.sort_ascending === true, "Sort ascending is true (newest first)");
    var groups = JSON.parse(p.engine.groups_json());
    check(groups.length >= 3, "At least 3 date groups present");
    check(groups[0].title === "Today", "First group is Today when ascending=true; got " + groups[0].title);

    var dayTimer = null;
    for (var timerIndex = 0; timerIndex < p.data.length; ++timerIndex) {
        if (p.data[timerIndex].lastDateKey !== undefined)
            dayTimer = p.data[timerIndex];
    }
    check(dayTimer !== null, "Calendar refresh timer found");
    check(dayTimer.lastDateKey === Qt.formatDate(new Date(), "yyyy-MM-dd"), "Calendar key is initialized before the first tick");
    dayTimer.lastDateKey = "1900-01-01";
    dayTimer.triggered();
    check(dayTimer.lastDateKey === Qt.formatDate(new Date(), "yyyy-MM-dd"), "Calendar rollover refresh updates the key");

    function clickPath(path, modifiers) {
        var card = findCard(p.groupedListView.contentItem, path);
        check(card !== null, "Visible card " + path);
        var point = card.mapToItem(p, card.width / 2, card.height / 2);
        uiTest.mouseClick(p, point.x, point.y, Qt.LeftButton, modifiers || Qt.NoModifier, 30);
        waitMs(40);
    }

    // 2. Real Click Selection
    var first = p.engine.path_at(1);
    clickPath(first, Qt.NoModifier);
    check(p.selectedCount === 1 && p.selection[first], "Real click selects exact source path");
    console.log("DATE_GROUPS_FIRST_CLICK_PASS");

    // 3. Real Keyboard Navigation Across Headers
    p.forceActiveFocus();
    uiTest.keyClick(Qt.Key_Down, Qt.NoModifier, 30);
    waitMs(60);
    var expectedDown = groups[1].start + Math.min(1, groups[1].count - 1);
    check(p.cursorPath === p.engine.path_at(expectedDown), "Real Down key crosses section with column preserved; got " + p.cursorPath);
    console.log("DATE_GROUPS_KEY_DOWN_PASS");

    // 4. Real Shift-Click Across Headers
    clickPath(first, Qt.NoModifier);
    var lastIndex = groups[1].start + 1;
    clickPath(p.engine.path_at(lastIndex), Qt.ShiftModifier);
    check(p.selectedCount === lastIndex, "Real Shift-click range across header; got " + p.selectedCount);
    console.log("DATE_GROUPS_SHIFT_CLICK_PASS");

    // 5. Real Ctrl-Click Toggle
    var folder = p.engine.path_at(0);
    clickPath(folder, Qt.ControlModifier);
    check(p.selection[folder] === true, "Real Ctrl-click selects");
    clickPath(folder, Qt.ControlModifier);
    check(!p.selection[folder], "Real Ctrl-click deselects");
    console.log("DATE_GROUPS_CTRL_CLICK_PASS");

    // 6. Real Gap-to-Gap Drag Selection Across Headers
    p.clearSelection();
    p.groupedListView.contentY = 0;
    waitMs(60);
    var firstVisual = p.groupedRows[p.groupedFileToVisual[0].visualRow];
    var nextVisual = p.groupedRows[p.groupedFileToVisual[groups[1].start].visualRow];
    var from = p.groupedListView.contentItem.mapToItem(p, p.cellW, firstVisual.y + p.cellH / 2);
    var to = p.groupedListView.contentItem.mapToItem(p, p.cellW * 2.8, nextVisual.y + p.cellH / 2);
    uiTest.mousePress(p, from.x, from.y, Qt.LeftButton, Qt.NoModifier, 30);
    uiTest.mouseMove(p, to.x, to.y, 80);
    waitMs(60);
    uiTest.mouseRelease(p, to.x, to.y, Qt.LeftButton, Qt.NoModifier, 30);
    waitMs(60);
    check(p.selectedCount >= 2, "Real gap-to-gap drag across header selects files; got " + p.selectedCount);
    var selected = Object.keys(p.selection);
    for (var i = 0; i < selected.length; ++i) {
        check(p.engine.row_of(selected[i]) >= 0, "Only valid source files selected");
    }
    check(!p.selection[folder], "Gap marquee excludes first column");
    console.log("ROOT_REAL_GRID_INPUT_PASS count=" + p.selectedCount);

    // 7. View Toggle Path Retention
    var keep = selected[0];
    p.engine.toggle_view_mode();
    waitMs(120);
    check(p.isList() && p.selection[keep], "View toggle retains path selection");

    // 8. Real List Drag Across Headers
    p.clearSelection();
    var view = p.listView;
    view.contentY = view.originY;
    waitMs(60);
    var lastRow = view.itemAtIndex(groups[1].start + 1);
    check(lastRow !== null, "List row materialized");
    var a = view.contentItem.mapToItem(p, 8, view.originY + 5);
    var b = lastRow.mapToItem(p, 300, lastRow.height / 2);
    uiTest.mousePress(p, a.x, a.y, Qt.LeftButton, Qt.NoModifier, 30);
    uiTest.mouseMove(p, b.x, b.y, 90);
    waitMs(60);
    uiTest.mouseRelease(p, b.x, b.y, Qt.LeftButton, Qt.NoModifier, 30);
    waitMs(60);
    check(p.selectedCount >= 2, "Real list drag across native section headers selects rows");
    selected = Object.keys(p.selection);
    for (var j = 0; j < selected.length; ++j) {
        check(p.engine.row_of(selected[j]) >= 0, "List only valid source paths");
    }
    console.log("ROOT_REAL_LIST_INPUT_PASS count=" + p.selectedCount);

    // 9. Normal Grid Selection Regression (Group None, Name sort)
    p.engine.toggle_view_mode();
    waitMs(60);
    p.engine.set_group("none", true);
    p.engine.set_sort("name", true);
    waitMs(80);
    check(!p.isGroupedGrid(), "Normal GridView active for group none");
    p.clearSelection();
    var normCard0 = findCard(p.gridView.contentItem, first);
    check(normCard0 !== null, "Normal grid card materialized");
    var pt0 = normCard0.mapToItem(p, normCard0.width / 2, normCard0.height / 2);
    uiTest.mouseClick(p, pt0.x, pt0.y, Qt.LeftButton, Qt.NoModifier, 30);
    waitMs(40);
    check(p.selectedCount === 1 && p.selection[first], "Normal grid real click selects");
    var normCard1 = findCard(p.gridView.contentItem, folder);
    check(normCard1 !== null, "Normal grid second card materialized");
    var pt1 = normCard1.mapToItem(p, normCard1.width / 2, normCard1.height / 2);
    uiTest.mouseClick(p, pt1.x, pt1.y, Qt.LeftButton, Qt.ControlModifier, 30);
    waitMs(40);
    check(p.selectedCount === 2 && p.selection[first] && p.selection[folder], "Normal grid real Ctrl-click multi-selects");
    console.log("NORMAL_GRID_INPUT_PASS count=" + p.selectedCount);

    // 10. Modified sort direction toggle and header interaction check in both views
    // Switch to list view and re-enable modified grouping
    p.engine.toggle_view_mode();
    waitMs(60);
    check(p.isList(), "List view active for header checks");
    p.engine.set_group("modified", true);
    p.engine.set_sort("modified", true);
    waitMs(80);
    var listGroupsAsc = JSON.parse(p.engine.groups_json());
    check(listGroupsAsc[0].title === "Today", "List view ascending=true first group is Today");
    // Toggle group order (group_ascending=false -> oldest first)
    p.engine.toggle_group_order();
    waitMs(80);
    check(p.engine.group_ascending === false, "Group ascending is false after toggle");
    var listGroupsDesc = JSON.parse(p.engine.groups_json());
    check(listGroupsDesc[0].title !== "Today", "List view descending first group is oldest (not Today)");
    check(listGroupsDesc[listGroupsDesc.length - 1].title === "Today", "List view descending last known group is Today");

    // Toggle view mode to grouped grid and verify same direction contract
    p.engine.toggle_view_mode();
    waitMs(60);
    check(p.isGroupedGrid(), "Grouped grid active after toggle");
    check(p.engine.group_ascending === false, "Group ascending still false in grid");
    var gridGroupsDesc = JSON.parse(p.engine.groups_json());
    check(gridGroupsDesc[gridGroupsDesc.length - 1].title === "Today", "Grid view descending last known group is Today");
    // Toggle back to ascending in grid
    p.engine.toggle_group_order();
    waitMs(80);
    check(p.engine.group_ascending === true, "Group ascending back to true");
    var gridGroupsAsc = JSON.parse(p.engine.groups_json());
    check(gridGroupsAsc[0].title === "Today", "Grid view ascending first group is Today");
    console.log("DATE_GROUPS_DIRECTION_TOGGLE_PASS");

    // 11. View menu popup reachability and real wheel scroll at 640x420
    window.width = 640;
    window.height = 420;
    waitMs(60);
    p.engine.set_group("name", true);
    viewMenuPopup.open();
    waitMs(100);
    check(viewMenuPopup.opened || viewMenuPopup.visible, "View menu opened at 640x420");
    var startY = viewMenuFlickable.contentY;
    uiTest.mouseWheel(viewMenuFlickable, viewMenuFlickable.width / 2, viewMenuFlickable.height / 2, 0, -720, Qt.NoButton, Qt.NoModifier, 30);
    waitMs(100);
    check(viewMenuFlickable.contentY > startY, "Real wheel reaches lower View controls");
    viewMenuPopup.close();
    waitMs(60);
    console.log("ROOT_VIEW_MENU_REAL_SCROLL_PASS");

    // 12. Full matrix of independent grouping & sorting across Grid and List
    window.width = 1080;
    window.height = 720;
    p.engine.set_path(testEnv.artifactDir + "/matrix_files");
    waitUntil(function() { return !p.engine.loading && p.engine.item_count === 6; }, "Combination fixture loaded");
    p.engine.change_folder_position("mixed");

    function names() {
        var result = [];
        for (var row = 0; row < p.engine.item_count; ++row) {
            result.push(JSON.parse(p.engine.item_json(row)).name);
        }
        return result;
    }

    function realSelect(index) {
        p.clearSelection();
        waitMs(50);
        var path = p.engine.path_at(index);
        var item = p.isList() ? p.listView.itemAtIndex(index) : findCard(p.groupedListView.contentItem, path);
        check(item !== null, "Combination visible delegate exists");
        if (!p.isList()) check(item.itemIndex === index && item.itemPath === path, "Fresh card row/path identity");
        var at = item.mapToItem(p, item.width / 2, item.height / 2);
        uiTest.mouseClick(p, at.x, at.y, Qt.LeftButton, Qt.NoModifier, 30);
        waitMs(40);
        check(p.selectedCount === 1 && p.selection[path], "Combination real click selects exact file");
    }

    for (var modeIndex = 0; modeIndex < 2; ++modeIndex) {
        p.engine.set_view(modeIndex === 0 ? "grid" : "list");
        waitMs(60);
        p.engine.set_group("name", true);
        p.engine.set_sort("size", false);
        waitMs(80);
        check(names().slice(0, 4).join(",") === "alpha.png,Alpha.txt,beta.zip,beta.txt", "Name groups with largest-first files");
        realSelect(0);

        p.engine.set_sort("size", true);
        waitMs(80);
        check(names().slice(0, 4).join(",") === "Alpha.txt,alpha.png,beta.txt,beta.zip", "Sort direction changes files without changing group order");
        realSelect(0);

        p.engine.set_group("name", false);
        waitMs(80);
        check(JSON.parse(p.engine.groups_json())[0].title === "G", "Independent group reverse order");
        realSelect(0);

        p.engine.set_group("size", true);
        p.engine.set_sort("name", true);
        waitMs(80);
        check(names().join(",") === "Gamma,delta.mp3,alpha.png,Alpha.txt,beta.txt,beta.zip", "Size ranges with independent alphabetical sort");
        realSelect(0);

        p.engine.set_group("type", true);
        p.engine.set_sort("modified", true);
        waitMs(80);
        var typeGroups = JSON.parse(p.engine.groups_json());
        var textGroup = null;
        for (var gi = 0; gi < typeGroups.length; ++gi) {
            if (typeGroups[gi].title === "Plain Text" || typeGroups[gi].title === "Documents") textGroup = typeGroups[gi];
        }
        check(textGroup !== null && textGroup.count === 2, "Type group contains both text files");
        check(names()[textGroup.start] === "Alpha.txt", "Type group sorted by newest modified date");
        realSelect(0);

        p.engine.set_group("none", true);
        p.engine.set_sort("size", false);
        waitMs(80);
        check(JSON.parse(p.engine.groups_json()).length === 0, "None disables grouping");
        check(names()[0] === "Gamma" || names()[0] === "beta.zip", "Flat size sort remains functional");
        console.log("ROOT_INDEPENDENT_REAL_INPUT_PASS " + (modeIndex === 0 ? "grid" : "list"));
    }

    // Only one grid may render, independently of the selected sort key.
    p.engine.set_view("grid");
    var groupModes = ["none", "name", "modified", "size", "type"];
    var sortModes = ["name", "modified", "size", "type"];
    for (var groupIndex = 0; groupIndex < groupModes.length; ++groupIndex) {
        for (var sortIndex = 0; sortIndex < sortModes.length; ++sortIndex) {
            var grouping = groupModes[groupIndex];
            var sorting = sortModes[sortIndex];
            p.engine.set_group(grouping, true);
            p.engine.set_sort(sorting, true);
            waitMs(60);
            var grouped = grouping !== "none";
            var combination = "group=" + grouping + ", sort=" + sorting;
            check(p.gridView.visible === !grouped, "Flat grid visibility: " + combination);
            check(p.groupedListView.visible === grouped, "Grouped grid visibility: " + combination);
            check(!p.listView.visible, "List remains hidden in grid mode: " + combination);
            var activeGrid = grouped ? p.groupedListView : p.gridView;
            check(activeGrid.count > 0, "Active grid has rows: " + combination);
            p.ensureVisible(0);
            waitMs(40);
            var firstPath = p.engine.path_at(0);
            var firstCard = grouped ? findCard(activeGrid.contentItem, firstPath) : activeGrid.itemAtIndex(0);
            check(firstCard !== null && firstCard.itemPath === firstPath, "First grid card is rendered: " + combination);
            p.clearSelection();
            var firstPoint = firstCard.mapToItem(p, firstCard.width / 2, firstCard.height / 2);
            uiTest.mouseClick(p, firstPoint.x, firstPoint.y, Qt.LeftButton, Qt.NoModifier, 30);
            waitMs(30);
            check(p.selectedCount === 1 && p.selection[firstPath], "Active grid receives clicks: " + combination);
        }
    }
    console.log("GRID_VISIBILITY_ALL_GROUP_SORT_MODES_PASS");

    console.log("ALL_DATE_GROUPS_UI_TESTS_PASS");
    Qt.quit();
}
"""

def create_scratch_fixtures(tmpdir):
    scratch = Path(tmpdir) / "scratch_files"
    scratch.mkdir()
    large = Path(tmpdir) / "large_files"
    large.mkdir()
    matrix = Path(tmpdir) / "matrix_files"
    matrix.mkdir()

    for name, size, age in [
        ("Alpha.txt", 500, 100),
        ("alpha.png", 1000, 200),
        ("beta.txt", 50, 90000),
        ("beta.zip", 1500, 500),
        ("delta.mp3", 0, 300),
    ]:
        target = matrix / name
        target.write_bytes(b"x" * size)
        os.utime(target, (1794220000 - age, 1794220000 - age))
    (matrix / "Gamma").mkdir()

    now = time.time()
    (scratch / "today_file_1.txt").write_text("today 1")
    os.utime(scratch / "today_file_1.txt", (now - 300, now - 300))
    (scratch / "today_file_2.txt").write_text("today 2")
    os.utime(scratch / "today_file_2.txt", (now - 200, now - 200))
    (scratch / "today_dir_1").mkdir()
    os.utime(scratch / "today_dir_1", (now - 100, now - 100))

    (scratch / "yesterday_file_1.txt").write_text("yesterday 1")
    os.utime(scratch / "yesterday_file_1.txt", (now - 86400, now - 86400))
    (scratch / "yesterday_file_2.txt").write_text("yesterday 2")
    os.utime(scratch / "yesterday_file_2.txt", (now - 86400, now - 86400))
    (scratch / "yesterday_dir_1").mkdir()
    os.utime(scratch / "yesterday_dir_1", (now - 86400, now - 86400))

    (scratch / "last_week_1.txt").write_text("last week 1")
    os.utime(scratch / "last_week_1.txt", (now - 86400 * 7, now - 86400 * 7))
    (scratch / "last_week_2.txt").write_text("last week 2")
    os.utime(scratch / "last_week_2.txt", (now - 86400 * 7, now - 86400 * 7))

    (scratch / "october_2026_file.txt").write_text("oct 2026")
    os.utime(scratch / "october_2026_file.txt", (1792065600, 1792065600))

    return scratch, large

def main():
    root = Path(__file__).resolve().parents[1]
    binary = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "target/debug/loaf"

    with tempfile.TemporaryDirectory(prefix="loaf-check-date-groups-") as td:
        sandbox = Path(td)
        scratch_dir, large_dir = create_scratch_fixtures(sandbox)
        probe = sandbox / "main.qml"

        source = (root / "qml/main.qml").read_text().replace("import app.loaf", "import app.loaf\nimport QtTest", 1)
        test_env_qml = f"""
        Item {{
            id: testEnv
            property string scratchDir: "{scratch_dir}"
            property string artifactDir: "{sandbox}"
            property string largeDir: "{large_dir}"
        }}
        """
        injected = source.rsplit("}", 1)[0] + test_env_qml + QML_TEST_INC + "}\n"
        probe.write_text(injected)

        for item in (root / "qml").iterdir():
            if item.name != "main.qml":
                dst = sandbox / item.name
                if not dst.exists():
                    os.symlink(item, dst)

        xdg_config = sandbox / "xdg_config"
        xdg_data = sandbox / "xdg_data"
        xdg_cache = sandbox / "xdg_cache"
        xdg_runtime = sandbox / "xdg_runtime"
        for d in [xdg_config, xdg_data, xdg_cache, xdg_runtime]:
            d.mkdir(parents=True, exist_ok=True)

        env = os.environ.copy()
        env.update(
            QT_QPA_PLATFORM="offscreen",
            QT_QUICK_CONTROLS_STYLE="Basic",
            QT_FORCE_STDERR_LOGGING="1",
            LOAF_QML=str(probe),
            XDG_CONFIG_HOME=str(xdg_config),
            XDG_DATA_HOME=str(xdg_data),
            XDG_CACHE_HOME=str(xdg_cache),
            XDG_RUNTIME_DIR=str(xdg_runtime),
        )

        result = subprocess.run([str(binary), "--new-window"], env=env, capture_output=True, text=True, timeout=45)
        output = result.stdout + result.stderr
        rc = result.returncode

        if rc != 0 or "ALL_DATE_GROUPS_UI_TESTS_PASS" not in output or "TEST_ABORTED" in output:
            print("STDERR/STDOUT TAIL:")
            print(output)
            sys.exit(1)

        print("\n".join(line for line in output.splitlines() if "_PASS" in line or "count=" in line))
        print("ALL_DATE_GROUPS_UI_TESTS_PASS")

if __name__ == "__main__":
    main()
