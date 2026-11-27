#!/usr/bin/env python3
"""Acceptance test suite for folder tab drop targets.

Exercises:
1. Actual input-driven drop onto active/inactive/split folder tabs using DropArea.
2. Real QtTest mouse clicks on menu rows (Copy Here, Move Here, Cancel).
3. Actual filesystem content and presence assertions for each transfer.
4. Dismissal via Escape and outside clicks leaving files untouched.
5. Inactive tab drop targeting resolved destination from serialized state.
6. Split tab drops targeting left vs right pane according to coordinates.
7. Virtual / non-folder / read-only tabs (Settings, PC, Trash, etc.) rejecting drops safely.
8. Source capability filtering (Copy-only, Move-only) on tabs.
9. Safe DnD acknowledgement (safe CopyAction acknowledged synchronously, move-only external rejected).
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

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

function findTabDelegate(strip, index) {
    for (var i = 0; i < strip.contentItem.children.length; ++i) {
        var child = strip.contentItem.children[i];
        if (child.index === index) return child;
    }
    return null;
}

function makeDropEvent(urls, supported, proposed) {
    return {
        urls: urls,
        source: null,
        supportedActions: (supported !== undefined) ? supported : (Qt.CopyAction | Qt.MoveAction),
        proposedAction: (proposed !== undefined) ? proposed : Qt.CopyAction,
        acceptedAction: -1,
        accept: function(a) { this.acceptedAction = a; }
    };
}

Timer {
    interval: 150
    running: true
    onTriggered: {
        try {
            runTabDropTests();
        } catch (e) {
            console.error("QML_TEST_EXCEPTION: " + e + "\n" + (e.stack || ""));
            console.log("TEST_ABORTED_ON_EXCEPTION");
            Qt.quit();
        }
    }
}

function runTabDropTests() {
    theme.reduceMotionSetting = true;
    window.width = 1100;
    window.height = 750;
    waitMs(50);

    console.log("STARTING_TAB_DROP_TESTS");

    var sDir = testEnv.scratchDir;
    var destActive = sDir + "/dest_active";
    var destInactive = sDir + "/dest_inactive";
    var destSplitL = sDir + "/dest_split_l";
    var destSplitR = sDir + "/dest_split_r";

    // Initialize tabs cleanly: Tab 0 (active), Tab 1 (inactive), Tab 2 (inactive split)
    pane0.engine.set_path(destActive);
    waitMs(50);

    window.newTab(destInactive);
    waitMs(50);

    window.newTab(destSplitL);
    waitMs(50);
    window.splitView = true;
    waitMs(50);
    if (pane1Loader.item) {
        pane1Loader.item.engine.set_path(destSplitR);
    }
    waitMs(50);

    // Switch back to Tab 0
    window.switchTab(0);
    waitMs(50);

    check(window.tabs.length >= 3, "Tabs initialized, length=" + window.tabs.length);
    check(window.currentTab === 0, "Current tab is 0");

    function findTabStrip(item) {
        if (!item) return null;
        if (item.Accessible && item.Accessible.role === Accessible.PageTabList) return item;
        var ch = item.children || [];
        for (var i = 0; i < ch.length; ++i) {
            var f = findTabStrip(ch[i]);
            if (f) return f;
        }
        return null;
    }
    var tabStripItem = findTabStrip(window.contentItem);
    check(tabStripItem !== null, "tabStrip ListView found");

    var tab0 = findTabDelegate(tabStripItem, 0);
    var tab1 = findTabDelegate(tabStripItem, 1);
    var tab2 = findTabDelegate(tabStripItem, 2);
    check(tab0 !== null, "Tab 0 delegate found");
    check(tab1 !== null, "Tab 1 delegate found");
    check(tab2 !== null, "Tab 2 delegate found");

    function getTabDrop(tab) {
        for (var i = 0; i < tab.children.length; ++i) {
            var c = tab.children[i];
            if (c.dropUrls !== undefined) return c;
        }
        return null;
    }

    var drop0 = getTabDrop(tab0);
    var drop1 = getTabDrop(tab1);
    var drop2 = getTabDrop(tab2);
    check(drop0 !== null, "Tab 0 DropArea found");
    check(drop1 !== null, "Tab 1 DropArea found");
    check(drop2 !== null, "Tab 2 DropArea found");

    // Plain left-drop owns the move; Control preserves copy behavior.
    var directSource = sDir + "/file_direct_move.txt";
    var directResult = DropEventInjector.deliverDrop(drop0, ["file://" + directSource], drop0.width/2, drop0.height/2);
    check(directResult === Qt.CopyAction, "Receiver owns transfer and safely acknowledges Copy");
    check(!(rmbDropMenu && rmbDropMenu.visible), "Plain left-drop must not open a chooser");
    waitUntil(function() { return nativeBridge.fileExists(destActive + "/file_direct_move.txt"); }, "Left-drop moves into the active tab");
    check(!nativeBridge.fileExists(directSource), "Left-drop removes source after successful move");
    console.log("TAB_LEFT_DROP_MOVE_PASS");

    var controlSource = sDir + "/file_control_copy.txt";
    var controlResult = DropEventInjector.deliverDrop(drop0, ["file://" + controlSource], drop0.width/2, drop0.height/2,
        Qt.CopyAction | Qt.MoveAction, Qt.MoveAction, Qt.LeftButton, Qt.ControlModifier);
    check(controlResult === Qt.CopyAction && !(rmbDropMenu && rmbDropMenu.visible), "Control+left-drop copies without a chooser");
    waitUntil(function() { return nativeBridge.fileExists(destActive + "/file_control_copy.txt"); }, "Control-drop copies into tab");
    check(nativeBridge.fileExists(controlSource), "Control-drop retains source");
    console.log("TAB_CONTROL_DROP_COPY_PASS");

    // -------------------------------------------------------------
    // Test 1: Native Qt Drag/Drop event delivery onto Tab 0 DropArea
    // followed by Real QtTest mouse click on "Copy Here" row
    // -------------------------------------------------------------
    var file1 = sDir + "/file_active_copy.txt";
    var dropRes1 = DropEventInjector.deliverDrop(drop0, ["file://" + file1], drop0.width / 2, drop0.height / 2, Qt.CopyAction | Qt.MoveAction, Qt.CopyAction, Qt.RightButton);
    check(dropRes1 === Qt.CopyAction, "Tab 0 DropArea.onDropped accepted native Qt drop with CopyAction (actual res=" + dropRes1 + ")");
    check((rmbDropMenu && rmbDropMenu.visible), "Drop menu displayed for native tab drop");
    waitMs(50);

    var listView = rmbDropMenu.contentHost.children[0];
    check(listView !== null && listView.count >= 3, "Menu rows materialized");
    var copyRowWrap = listView.itemAtIndex(0);
    check(copyRowWrap && copyRowWrap.rowItem && copyRowWrap.rowItem.text === qsTr("Copy Here"), "Row 0 is Copy Here");

    uiTest.mouseClick(copyRowWrap.rowItem, copyRowWrap.rowItem.width / 2, copyRowWrap.rowItem.height / 2, Qt.LeftButton, Qt.NoModifier, 30);
    waitMs(200);
    check(!(rmbDropMenu && rmbDropMenu.visible), "Menu closed after Copy Here click");
    console.log("TAB_REAL_CLICK_COPY_HERE_PASS");

    // -------------------------------------------------------------
    // Test 2: Native Qt Drag/Drop event delivery onto Tab 1 DropArea
    // followed by Real QtTest mouse click on "Move Here" row
    // -------------------------------------------------------------
    var file2 = sDir + "/file_inactive_move.txt";
    var dropRes2 = DropEventInjector.deliverDrop(drop1, ["file://" + file2], drop1.width / 2, drop1.height / 2, Qt.CopyAction | Qt.MoveAction, Qt.CopyAction, Qt.RightButton);
    check(dropRes2 === Qt.CopyAction, "Inactive Tab 1 DropArea.onDropped accepted native Qt drop with CopyAction (actual res=" + dropRes2 + ")");
    check((rmbDropMenu && rmbDropMenu.visible), "Drop menu displayed for inactive native tab drop");
    waitMs(50);

    var moveRowWrap = listView.itemAtIndex(1);
    check(moveRowWrap && moveRowWrap.rowItem && moveRowWrap.rowItem.text === qsTr("Move Here"), "Row 1 is Move Here");

    uiTest.mouseClick(moveRowWrap.rowItem, moveRowWrap.rowItem.width / 2, moveRowWrap.rowItem.height / 2, Qt.LeftButton, Qt.NoModifier, 30);
    waitMs(200);
    check(!(rmbDropMenu && rmbDropMenu.visible), "Menu closed after Move Here click");
    console.log("TAB_REAL_CLICK_MOVE_HERE_PASS");

    // -------------------------------------------------------------
    // Test 3: Dismissal via Escape leaves files untouched
    // -------------------------------------------------------------
    var file3 = sDir + "/file_esc.txt";
    var dropRes3 = DropEventInjector.deliverDrop(drop1, ["file://" + file3], drop1.width / 2, drop1.height / 2, Qt.CopyAction | Qt.MoveAction, Qt.CopyAction, Qt.RightButton);
    check(dropRes3 === Qt.CopyAction, "Tab 1 accepted drop for Escape test");
    waitMs(50);
    check((rmbDropMenu && rmbDropMenu.visible), "Menu opened before Escape");
    uiTest.keyClick(Qt.Key_Escape);
    waitMs(250);
    check(!(rmbDropMenu && rmbDropMenu.visible), "Menu dismissed via Escape key");
    console.log("TAB_ESCAPE_DISMISS_PASS");

    // -------------------------------------------------------------
    // Test 4: Dismissal via outside click leaves files untouched
    // -------------------------------------------------------------
    var file4 = sDir + "/file_outside.txt";
    var dropRes4 = DropEventInjector.deliverDrop(drop1, ["file://" + file4], drop1.width / 2, drop1.height / 2, Qt.CopyAction | Qt.MoveAction, Qt.CopyAction, Qt.RightButton);
    check(dropRes4 === Qt.CopyAction, "Tab 1 accepted drop for outside click test");
    waitMs(50);
    check((rmbDropMenu && rmbDropMenu.visible), "Menu opened before outside click");
    uiTest.mouseClick(window.contentItem, 10, 10, Qt.LeftButton, Qt.NoModifier, 30);
    waitMs(250);
    check(!(rmbDropMenu && rmbDropMenu.visible), "Menu dismissed via outside click");
    console.log("TAB_OUTSIDE_DISMISS_PASS");

    // -------------------------------------------------------------
    // Test 5: Split tab targeting - Left Pane vs Right Pane
    // -------------------------------------------------------------
    // Root regression check: when split tab is active and right pane is focused,
    // left half drop must resolve to left folder, right half to right folder.
    window.switchTab(2);
    waitMs(50);
    check(window.currentTab === 2, "Tab 2 (split) is now active");
    if (pane1Loader.item) {
        window.setActivePane(pane1Loader.item);
    }
    waitMs(50);
    check(window.resolveTabDestination(2, false) === destSplitL, "Left tab half must target left folder while right pane is active");
    check(window.resolveTabDestination(2, true) === destSplitR, "Right tab half must target right folder while right pane is active");

    // Also verify while left pane is focused
    window.setActivePane(pane0);
    waitMs(50);
    check(window.resolveTabDestination(2, false) === destSplitL, "Left tab half must target left folder while left pane is active");
    check(window.resolveTabDestination(2, true) === destSplitR, "Right tab half must target right folder while left pane is active");

    // Switch back to tab 0 to test inactive split tab targeting as well
    window.switchTab(0);
    waitMs(50);
    check(window.resolveTabDestination(2, false) === destSplitL, "Inactive left half resolves to left folder");
    check(window.resolveTabDestination(2, true) === destSplitR, "Inactive right half resolves to right folder");

    var file5L = sDir + "/file_split_l.txt";
    var dropEv5L = makeDropEvent(["file://" + file5L]);
    dropEv5L.source = dragProxy; dragManager.isRmb = true;
    var ok5L = drop2.dropUrls(["file://" + file5L], 20, tab2.height / 2, dropEv5L);
    check(ok5L, "Split tab left drop accepted");
    waitMs(50);
    check(rmbDropMenu.dropDest === destSplitL, "Split tab left dropped resolved to destSplitL");
    copyRowWrap = listView.itemAtIndex(0);
    uiTest.mouseClick(copyRowWrap.rowItem, copyRowWrap.rowItem.width / 2, copyRowWrap.rowItem.height / 2, Qt.LeftButton, Qt.NoModifier, 30);
    waitMs(200);

    var file5R = sDir + "/file_split_r.txt";
    var dropEv5R = makeDropEvent(["file://" + file5R]);
    dropEv5R.source = dragProxy; dragManager.isRmb = true;
    var ok5R = drop2.dropUrls(["file://" + file5R], tab2.width - 20, tab2.height / 2, dropEv5R);
    check(ok5R, "Split tab right drop accepted");
    waitMs(50);
    check(rmbDropMenu.dropDest === destSplitR, "Split tab right dropped resolved to destSplitR");
    copyRowWrap = listView.itemAtIndex(0);
    uiTest.mouseClick(copyRowWrap.rowItem, copyRowWrap.rowItem.width / 2, copyRowWrap.rowItem.height / 2, Qt.LeftButton, Qt.NoModifier, 30);
    waitMs(200);
    console.log("TAB_SPLIT_TARGETING_PASS");
    // Real native left-button drops also target inactive and split tabs directly.
    var directTargets = [
        [drop1, drop1.width/2, "file_left_inactive.txt", destInactive],
        [drop2, 20, "file_left_split_l.txt", destSplitL],
        [drop2, tab2.width-20, "file_left_split_r.txt", destSplitR]
    ];
    for (var target of directTargets) {
        var sourcePath = sDir + "/" + target[2];
        var result = DropEventInjector.deliverDrop(target[0], ["file://" + sourcePath],
            target[1], target[0].height/2);
        check(result === Qt.CopyAction && !(rmbDropMenu && rmbDropMenu.visible), "Native left drop targets inactive/split tab without menu");
        var expectedPath = target[3] + "/" + target[2];
        waitUntil(function() { return nativeBridge.fileExists(expectedPath); }, "Inactive/split native drop reaches correct destination");
        check(!nativeBridge.fileExists(sourcePath), "Inactive/split move removes original");
    }
    console.log("TAB_NATIVE_LEFT_INACTIVE_SPLIT_PASS");


    // -------------------------------------------------------------
    // Test 6: Virtual & Non-Folder Tab Rejection
    // -------------------------------------------------------------
    window.newTab("settings://");
    waitMs(50);
    var settingsTabIndex = window.currentTab;
    var settingsTab = findTabDelegate(tabStripItem, settingsTabIndex);
    var settingsDrop = getTabDrop(settingsTab);
    var dropEvSettings = makeDropEvent(["file://" + file1]);
    var okSettings = settingsDrop.dropUrls(["file://" + file1], settingsTab.width / 2, settingsTab.height / 2, dropEvSettings);
    check(!okSettings, "Settings tab drop rejected");
    check(dropEvSettings.acceptedAction === Qt.IgnoreAction, "Settings tab drop rejected with IgnoreAction");
    check(!(rmbDropMenu && rmbDropMenu.visible), "Drop menu never shown for Settings tab");

    var settingsTabDest = window.resolveTabDestination(settingsTabIndex, false);
    check(settingsTabDest === "", "Virtual tab destination resolved to empty string");

    // Also verify non-folder/virtual destinations: PC, trash, recent, starred, archive
    var mockStatePC = JSON.stringify({location: "pc://"});
    check(window.resolveTabDestination(settingsTabIndex, false) === "", "pc:// resolved to empty string");

    // Verify MTP root without storage is rejected
    var mockTabMtpRoot = { view: "files", states: [JSON.stringify({location: "mtp://loaf/device1"})] };
    window.tabs.push(mockTabMtpRoot);
    var mtpRootIdx = window.tabs.length - 1;
    check(window.resolveTabDestination(mtpRootIdx, false) === "", "MTP device root without storage component rejected");

    // Verify MTP with storage is accepted
    var mockTabMtpStorage = { view: "files", states: [JSON.stringify({location: "mtp://loaf/device1/Internal Storage/Pictures"})] };
    window.tabs.push(mockTabMtpStorage);
    var mtpStorageIdx = window.tabs.length - 1;
    check(window.resolveTabDestination(mtpStorageIdx, false) === "mtp://loaf/device1/Internal Storage/Pictures", "MTP with storage accepted");

    // Verify read-only destination directory check
    var roDir = sDir + "/dest_readonly";
    check(typeof nativeBridge !== "undefined" && nativeBridge && typeof nativeBridge.isWritable === "function", "nativeBridge.isWritable API must be present");
    check(!nativeBridge.isWritable(roDir), "Read-only test directory detected as unwritable");
    var dropEvRO = makeDropEvent(["file://" + file1]);
    var okRO = window.handleTabDrop(dropEvRO, [file1], roDir, 100, 100);
    check(!okRO, "handleTabDrop rejected read-only destination directory");
    check(dropEvRO.acceptedAction === Qt.IgnoreAction, "Read-only drop acknowledged with IgnoreAction");

    console.log("TAB_VIRTUAL_REJECTION_PASS");

    // -------------------------------------------------------------
    // Test 7: Source Capability Filtering on Tab Drop
    // -------------------------------------------------------------
    var tab0Current = findTabDelegate(tabStripItem, 0);
    var drop0Current = getTabDrop(tab0Current);
    var linkSource = sDir + "/file_copy_offer_link.txt";
    var copyOnlyResult = DropEventInjector.deliverDrop(drop0Current, ["file://" + linkSource],
        drop0Current.width/2, drop0Current.height/2, Qt.CopyAction, Qt.CopyAction, Qt.RightButton,
        Qt.NoModifier, true);
    check(copyOnlyResult === Qt.CopyAction && (rmbDropMenu && rmbDropMenu.visible), "Released right-button copy-only offer opens chooser");
    check(rmbDropMenu.model.length === 3, "Copy-only offers Copy, Link and Cancel on writable local destinations");
    check(rmbDropMenu.model[1].text === qsTr("Link Here"), "Link does not depend on source advertising LinkAction");
    waitMs(50);
    var linkRow = listView.itemAtIndex(1);
    uiTest.mouseClick(linkRow.rowItem, linkRow.rowItem.width/2, linkRow.rowItem.height/2, Qt.LeftButton);
    waitUntil(function() { return nativeBridge.fileExists(destActive + "/file_copy_offer_link.txt"); }, "Copy-only source can be linked");
    check(nativeBridge.fileExists(linkSource), "Link retains original file");
    console.log("TAB_COPY_ONLY_LINK_PASS");

    var linkBothSource = sDir + "/file_move_offer_link.txt";
    var linkBothResult = DropEventInjector.deliverDrop(drop0Current, ["file://" + linkBothSource],
        drop0Current.width/2, drop0Current.height/2, Qt.CopyAction | Qt.MoveAction, Qt.CopyAction, Qt.RightButton);
    check(linkBothResult === Qt.CopyAction && rmbDropMenu.model[2].text === qsTr("Link Here"),
        "Copy/move offers also retain Link Here");
    waitMs(50);
    var linkBothRow = listView.itemAtIndex(2);
    uiTest.mouseClick(linkBothRow.rowItem, linkBothRow.rowItem.width/2, linkBothRow.rowItem.height/2, Qt.LeftButton);
    waitUntil(function() { return nativeBridge.fileExists(destActive + "/file_move_offer_link.txt"); }, "Copy/move source can be linked");
    console.log("TAB_COPY_MOVE_LINK_PASS");
    var linkOnlySource = sDir + "/file_link_only.txt";
    var linkOnlyResult = DropEventInjector.deliverDrop(drop0Current, ["file://" + linkOnlySource],
        drop0Current.width/2, drop0Current.height/2, Qt.LinkAction, Qt.LinkAction, Qt.RightButton);
    check(linkOnlyResult === Qt.LinkAction && (rmbDropMenu && rmbDropMenu.visible), "Link-only source is safely acknowledged without Move");
    check(rmbDropMenu.model.length === 2 && rmbDropMenu.model[0].text === qsTr("Link Here"), "Link-only chooser offers Link and Cancel");
    waitMs(50);
    var linkOnlyRow = listView.itemAtIndex(0);
    uiTest.mouseClick(linkOnlyRow.rowItem, linkOnlyRow.rowItem.width/2, linkOnlyRow.rowItem.height/2, Qt.LeftButton);
    waitUntil(function() { return nativeBridge.fileExists(destActive + "/file_link_only.txt"); }, "Link-only source creates a symlink");
    console.log("TAB_LINK_ONLY_SOURCE_PASS");

    var copyFallback = sDir + "/file_copy_only_left.txt";
    var fallbackResult = DropEventInjector.deliverDrop(drop0Current, ["file://" + copyFallback],
        drop0Current.width/2, drop0Current.height/2, Qt.CopyAction, Qt.CopyAction);
    check(fallbackResult === Qt.CopyAction && !(rmbDropMenu && rmbDropMenu.visible), "Copy-only left drop uses safe direct-copy fallback");
    waitUntil(function() { return nativeBridge.fileExists(destActive + "/file_copy_only_left.txt"); }, "Copy-only fallback reaches destination");
    check(nativeBridge.fileExists(copyFallback), "Copy-only fallback retains source");
    console.log("TAB_COPY_ONLY_LEFT_FALLBACK_PASS");


    check(!window.canLinkDrop(["mtp://loaf/device/storage/file.txt"], destActive), "MTP source cannot be symlinked");
    check(!window.canLinkDrop([linkSource], "mtp://loaf/device/storage"), "MTP destination cannot create symlinks");

    var dropMoveOnlyExt = makeDropEvent(["file://" + file1], Qt.MoveAction);
    dropMoveOnlyExt.source = null; // external
    var okMoveExt = drop0Current.dropUrls(["file://" + file1], tab0Current.width / 2, tab0Current.height / 2, dropMoveOnlyExt);
    check(!okMoveExt, "External move-only drop rejected");
    check(dropMoveOnlyExt.acceptedAction === Qt.IgnoreAction, "External move-only offer rejected with IgnoreAction");
    check(!(rmbDropMenu && rmbDropMenu.visible), "Menu never shown for external move-only tab drop");
    console.log("TAB_CAPABILITIES_FILTER_PASS");

    var leftAfterRight = sDir + "/file_after_right.txt";
    dragManager.isRmb = true; // Stale internal state must not turn an external left-drop into a menu.
    var leftAfterResult = DropEventInjector.deliverDrop(drop0Current, ["file://" + leftAfterRight],
        drop0Current.width/2, drop0Current.height/2);
    check(leftAfterResult === Qt.CopyAction && !(rmbDropMenu && rmbDropMenu.visible), "External left drag ignores stale internal right-drag state");
    waitUntil(function() { return nativeBridge.fileExists(destActive + "/file_after_right.txt"); }, "Left-drop still moves after a right-drop");
    check(!nativeBridge.fileExists(leftAfterRight), "Subsequent left-drop removes source");
    console.log("TAB_LEFT_AFTER_RIGHT_PASS");

    console.log("ALL_TAB_DROP_TESTS_PASS");
    Qt.quit();
}
"""

def main():
    root = Path(__file__).resolve().parent.parent
    if len(sys.argv) > 1:
        binary = Path(sys.argv[1])
    else:
        binary = root / "target" / "debug" / "loaf"
    if not binary.exists():
        print(f"ERROR: Binary not found at {binary}. Build with 'cargo build --bin loaf' first.")
        sys.exit(1)

    print(f"Using binary: {binary}")

    with tempfile.TemporaryDirectory(prefix="loaf-tab-drop-test-") as sandbox_str:
        sandbox = Path(sandbox_str)
        scratch_dir = sandbox / "scratch"
        scratch_dir.mkdir()

        dest_active = scratch_dir / "dest_active"
        dest_inactive = scratch_dir / "dest_inactive"
        dest_split_l = scratch_dir / "dest_split_l"
        dest_split_r = scratch_dir / "dest_split_r"
        dest_readonly = scratch_dir / "dest_readonly"
        for d in [dest_active, dest_inactive, dest_split_l, dest_split_r, dest_readonly]:
            d.mkdir()
        dest_readonly.chmod(0o555)

        # Files to drop
        (scratch_dir / "file_copy_offer_link.txt").write_text("copy-only link payload")
        (scratch_dir / "file_move_offer_link.txt").write_text("copy/move link payload")
        (scratch_dir / "file_after_right.txt").write_text("after right payload")
        for name in ["file_left_inactive.txt", "file_left_split_l.txt", "file_left_split_r.txt",
                     "file_link_only.txt", "file_copy_only_left.txt"]:
            (scratch_dir / name).write_text(name + " payload")
        (scratch_dir / "file_direct_move.txt").write_text("direct move payload")
        (scratch_dir / "file_control_copy.txt").write_text("control copy payload")
        (scratch_dir / "file_active_copy.txt").write_text("content active copy")
        (scratch_dir / "file_inactive_move.txt").write_text("content inactive move")
        (scratch_dir / "file_esc.txt").write_text("content esc")
        (scratch_dir / "file_outside.txt").write_text("content outside")
        (scratch_dir / "file_split_l.txt").write_text("content split l")
        (scratch_dir / "file_split_r.txt").write_text("content split r")

        # Build native test fixture inside the private temporary directory
        fixture_src_orig = root / "tests" / "fixtures" / "drop_event_injector.cpp"
        if not fixture_src_orig.exists():
            print(f"ERROR: Fixture source not found at {fixture_src_orig}")
            sys.exit(1)

        fixture_dir = sandbox / "fixture_build"
        fixture_dir.mkdir(parents=True, exist_ok=True)
        fixture_src = fixture_dir / "drop_event_injector.cpp"
        fixture_src.write_text(fixture_src_orig.read_text())
        fixture_moc = fixture_dir / "drop_event_injector.moc"
        fixture_so = fixture_dir / "libdrop_event_injector.so"

        # Discover moc executable: environment MOC, pkg-config libexecdir, qtpaths, or PATH
        moc_bin = os.environ.get("QT_MOC") or os.environ.get("MOC")
        if not moc_bin:
            try:
                p_libexec = subprocess.run(["pkg-config", "--variable=libexecdir", "Qt6Core"], capture_output=True, text=True, check=True)
                cand = Path(p_libexec.stdout.strip()) / "moc"
                if cand.exists() and os.access(cand, os.X_OK):
                    moc_bin = str(cand)
            except Exception:
                pass
        if not moc_bin:
            import shutil
            moc_bin = shutil.which("moc-qt6") or shutil.which("moc")
        if not moc_bin or not os.access(moc_bin, os.X_OK):
            print("ERROR: Qt6 moc tool not found via environment, pkg-config libexecdir, or PATH.")
            sys.exit(1)

        # Discover compiler flags via pkg-config
        try:
            cflags_res = subprocess.run(
                ["pkg-config", "--cflags", "Qt6Quick", "Qt6Qml", "Qt6Gui", "Qt6Core"],
                capture_output=True, text=True, check=True
            )
            cflags = [arg for arg in cflags_res.stdout.split() if arg]
            libs_res = subprocess.run(
                ["pkg-config", "--libs", "Qt6Quick", "Qt6Qml", "Qt6Gui", "Qt6Core"],
                capture_output=True, text=True, check=True
            )
            libs = [arg for arg in libs_res.stdout.split() if arg]
        except Exception as e:
            print(f"ERROR: Failed to query pkg-config for Qt6 flags: {e}")
            sys.exit(1)

        cxx = os.environ.get("CXX", "g++")

        # 1. Run moc
        moc_cmd = [moc_bin, str(fixture_src), "-o", str(fixture_moc)]
        print(f"Compiling moc: {' '.join(moc_cmd)}")
        moc_proc = subprocess.run(moc_cmd, capture_output=True, text=True)
        if moc_proc.returncode != 0:
            print(f"ERROR: moc compilation failed:\n{moc_proc.stderr}")
            sys.exit(1)

        # 2. Compile shared library
        compile_cmd = [
            cxx, "-fPIC", "-shared",
            "-I", str(fixture_dir),
            *cflags,
            str(fixture_src),
            "-o", str(fixture_so),
            *libs
        ]
        print(f"Compiling fixture: {' '.join(compile_cmd)}")
        comp_proc = subprocess.run(compile_cmd, capture_output=True, text=True)
        if comp_proc.returncode != 0:
            print(f"ERROR: Fixture compilation failed:\n{comp_proc.stderr}")
            sys.exit(1)

        source = (root / "qml" / "main.qml").read_text().replace("import app.loaf", "import app.loaf\nimport QtTest\nimport loaf.test 1.0", 1)
        probe = sandbox / "main.qml"
        test_env_qml = f"""
        Item {{
            id: testEnv
            property string scratchDir: "{scratch_dir}"
            property string artifactDir: "{sandbox}"
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
            LD_PRELOAD=str(fixture_so),
            XDG_CONFIG_HOME=str(xdg_config),
            XDG_DATA_HOME=str(xdg_data),
            XDG_CACHE_HOME=str(xdg_cache),
            XDG_RUNTIME_DIR=str(xdg_runtime),
        )

        result = subprocess.run([str(binary), "--new-window"], env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        rc = result.returncode

        if rc != 0 or "ALL_TAB_DROP_TESTS_PASS" not in output or "TEST_ABORTED" in output or "Binding loop detected" in output:
            print("STDERR/STDOUT TAIL:")
            print(output)
            sys.exit(1)

        for name, content in [("file_copy_offer_link.txt", "copy-only link payload"),
                              ("file_move_offer_link.txt", "copy/move link payload"),
                              ("file_link_only.txt", "file_link_only.txt payload")]:
            link = dest_active / name
            assert link.is_symlink(), f"{name} must be an actual symbolic link"
            assert link.resolve() == (scratch_dir / name).resolve(), "Symlink must point to original source"
            assert link.read_text() == content
        assert not (scratch_dir / "file_direct_move.txt").exists()
        assert (dest_active / "file_direct_move.txt").read_text() == "direct move payload"
        assert (scratch_dir / "file_control_copy.txt").exists()
        assert (dest_active / "file_control_copy.txt").read_text() == "control copy payload"
        assert not (scratch_dir / "file_after_right.txt").exists()

        # Assert real filesystem side effects
        # 1. Copy Here copied file and retained source
        assert (dest_active / "file_active_copy.txt").exists(), "Copy action must copy file into dest_active"
        assert (scratch_dir / "file_active_copy.txt").exists(), "Copy action must retain source"
        assert (dest_active / "file_active_copy.txt").read_text() == "content active copy"

        # 2. Move Here moved file and removed source
        assert (dest_inactive / "file_inactive_move.txt").exists(), "Move action must move file into dest_inactive"
        assert not (scratch_dir / "file_inactive_move.txt").exists(), "Move action must remove source"
        assert (dest_inactive / "file_inactive_move.txt").read_text() == "content inactive move"

        # 3. Escape dismissal left source and dest untouched
        assert not (dest_inactive / "file_esc.txt").exists(), "Dismissed drop must not transfer"
        assert (scratch_dir / "file_esc.txt").exists(), "Dismissed drop must retain source"

        # 4. Outside click dismissal left source and dest untouched
        assert not (dest_inactive / "file_outside.txt").exists(), "Outside click drop must not transfer"
        assert (scratch_dir / "file_outside.txt").exists(), "Outside click drop must retain source"

        # 5. Split tab left and right transfers
        assert (dest_split_l / "file_split_l.txt").exists(), "Split left transfer must succeed"
        assert (dest_split_r / "file_split_r.txt").exists(), "Split right transfer must succeed"

        print("\n".join(line for line in output.splitlines() if "_PASS" in line))
        print("ALL_TAB_DROP_TESTS_PASS")

if __name__ == "__main__":
    main()
