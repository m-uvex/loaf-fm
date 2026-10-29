// Injected into the real main.qml; all navigation and model code is production.
TestCase { id: mtpEvents; when: false }
function mtpCheck(condition, message) { if (!condition) throw new Error(message); }
function mtpWait(predicate, message) {
    for (var i = 0; i < 800 && !predicate(); ++i) mtpEvents.wait(10);
    mtpCheck(predicate(), message);
}
function mtpFind(item, predicate) {
    if (predicate(item)) return item;
    var children = item.children || [];
    for (var i = 0; i < children.length; ++i) {
        var found = mtpFind(children[i], predicate);
        if (found) return found;
    }
    return null;
}
function mtpClickPhone(uri, button) {
    var list = mtpFind(sidebar, function(item) { return item.positionViewAtIndex !== undefined; });
    var row;
    mtpWait(function() {
        var index = sidebar.entries.findIndex(function(item) { return item.id === "device:" + uri; });
        if (index < 0) return false;
        list.positionViewAtIndex(index, ListView.Contain);
        row = list.itemAtIndex(index);
        return row && row.button;
    }, "Missing phone row");
    mtpEvents.wait(30);
    mtpEvents.mouseClick(row.button, row.button.width / 2, 22, button || Qt.LeftButton);
}
function mtpLoaded(path) {
    mtpWait(function() { return engine.current_path === path && !engine.loading; }, "Location did not load: " + path + " (current " + engine.current_path + "; " + engine.error_text + ")");
    mtpCheck(engine.error_text === "", "MTP error: " + engine.error_text);
    mtpEvents.wait(40); // Let Qt polish delegate geometry after the asynchronous model change.
}
function mtpItem(name) {
    for (var i = 0; i < engine.item_count; ++i) {
        var item = JSON.parse(engine.item_json(i));
        if (item.name === name) return item;
    }
    throw new Error("Missing item: " + name);
}
function mtpOpenFolder(name) {
    var entry = mtpItem(name), target;
    for (var row = 0; row < engine.item_count; ++row) {
        if (JSON.parse(engine.item_json(row)).path === entry.path) { window.activePane.ensureVisible(row); break; }
    }
    mtpEvents.wait(80);
    mtpWait(function() {
        target = mtpFind(window.activePane, function(item) { return item.path === entry.path && item.is_dir === true && item.visible; });
        return !!target;
    }, "Missing folder delegate: " + name);
    // The delegate is destroyed during navigation; send both clicks through the stable content item.
    var point = target.mapToItem(window.contentItem, target.width / 2, target.height / 2);
    console.log("MTP_CASE_OPEN", name);
    mtpEvents.mouseDoubleClickSequence(window.contentItem, point.x, point.y, Qt.LeftButton);
    mtpLoaded(entry.path);
    return entry.path;
}
// Shared by isolated and real-phone acceptance checks. Only a newly created folder is mutated.
property var mtpTestOperation: null
Connections {
    target: core
    function onOperation_finished(kind, ok, resultJson) {
        if (kind.indexOf("mtp-") === 0) window.mtpTestOperation = {kind: kind, ok: ok, result: JSON.parse(resultJson || "null")};
    }
}
function mtpMaybeItem(name) {
    for (var i = 0; i < engine.item_count; ++i) { var item = JSON.parse(engine.item_json(i)); if (item.name === name) return item; }
    return null;
}
function mtpTypeText(text) {
    nativeBridge.setClipboardText(text);
    mtpEvents.keyClick(Qt.Key_V, Qt.ControlModifier);
}
function mtpTransferCheck(paths, dest, mode, expectedSuccess) {
    window.mtpTestOperation = null;
    core.transfer(JSON.stringify(paths), dest, mode, "rename");
    mtpWait(function() { return !core.busy && window.mtpTestOperation && window.mtpTestOperation.kind === "mtp-transfer"; }, "Transfer did not finish");
    mtpCheck(window.mtpTestOperation.ok === expectedSuccess, "Unexpected transfer result: " + toastItem.message);
    mtpWait(function() { return !engine.loading; }, "Transfer view did not refresh");
    return window.mtpTestOperation.result.created;
}
function mtpReadWrite(storage, stay) {
    var testName = core.get_setting("mtpRwTestName") || "Loaf write test";
    mtpCheck(!mtpMaybeItem(testName), "Refusing to reuse an existing phone test folder");
    window.mtpTestOperation = null;
    window.defocusInputs();
    mtpEvents.keyClick(Qt.Key_N, Qt.ControlModifier | Qt.ShiftModifier);
    mtpWait(function() { return inputModal.visible; }, "New folder UI did not open");
    mtpEvents.wait(240);
    mtpTypeText(testName); mtpEvents.keyClick(Qt.Key_Return);
    mtpWait(function() { return !core.busy && window.mtpTestOperation && window.mtpTestOperation.kind === "mtp-create"; }, "Folder creation did not finish");
    mtpCheck(window.mtpTestOperation.ok && window.mtpTestOperation.result.created.length === 1, "Folder creation failed: " + toastItem.message);
    var ownedPath = window.mtpTestOperation.result.created[0];
    mtpWait(function() { return !!mtpMaybeItem(testName); }, "Created folder is not listed");
    mtpWait(function() { return !inputModal.visible; }, "New folder dialog did not close");
    mtpEvents.wait(60);
    var testPath = mtpOpenFolder(testName);
    mtpCheck(testPath === ownedPath, "Created test folder identity mismatch");
    console.log("MTP_RW_CASE folder created");
    var local = core.get_setting("devicesTestRoot") + "/local.txt";
    var expected = JSON.parse(core.quick_look(local)).text;
    nativeBridge.setClipboardFiles([local], false);
    window.defocusInputs(); mtpEvents.keyClick(Qt.Key_V, Qt.ControlModifier);
    mtpWait(function() { return !core.busy && !!mtpMaybeItem("local.txt"); }, "Paste did not upload file: " + toastItem.message);
    mtpCheck(window.mtpTestOperation.ok, "Upload reported failure: " + toastItem.message);
    var uploaded = mtpItem("local.txt");
    console.log("MTP_RW_CASE uploaded");
    window.activePane.selectPaths([uploaded.path]); window.defocusInputs(); mtpEvents.keyClick(Qt.Key_F2);
    mtpWait(function() { return window.activePane.renamingPath === uploaded.path; }, "Rename editor missing");
    mtpEvents.wait(60);
    mtpEvents.keyClick(Qt.Key_A, Qt.ControlModifier); mtpTypeText("renamed # %.txt"); mtpEvents.keyClick(Qt.Key_Return);
    mtpWait(function() { return !core.busy && !!mtpMaybeItem("renamed # %.txt"); }, "Rename failed: " + toastItem.message);
    mtpCheck(window.mtpTestOperation.ok, "Rename reported failure: " + toastItem.message);
    var renamed = mtpItem("renamed # %.txt");
    console.log("MTP_RW_CASE renamed");
    window.previewItem(renamed.path);
    mtpWait(function() { return quickLook.visible && quickLook.info.text === expected; }, "Downloaded preview mismatch: " + toastItem.message);
    quickLook.close();
    mtpWait(function() { return !quickLook.visible; }, "Preview popup did not close");
    mtpEvents.wait(50);
    window.activePane.selectPaths([renamed.path]); window.defocusInputs(); mtpEvents.keyClick(Qt.Key_C, Qt.ControlModifier);
    mtpCheck(window.mtpClipboardPaths.length === 1, "Phone clipboard copy failed");
    mtpCheck(nativeBridge.clipboardFiles().paths[0] === renamed.path, "MTP clipboard identity did not round-trip");
    // A second Loaf window has no local JS clipboard state; exercise that fallback.
    window.mtpClipboardPaths = [];
    window.mtpClipboardCut = false;
    engine.set_path(stay); mtpLoaded(stay);
    window.defocusInputs(); mtpEvents.keyClick(Qt.Key_V, Qt.ControlModifier);
    mtpWait(function() { return !core.busy && !!mtpMaybeItem("renamed # %.txt"); }, "Download failed: " + toastItem.message);
    mtpCheck(window.mtpTestOperation.ok, "Download reported failure: " + toastItem.message);
    mtpCheck(JSON.parse(core.quick_look(mtpItem("renamed # %.txt").path)).text === expected, "Round-trip content mismatch");
    console.log("MTP_RW_CASE downloaded");
    engine.set_path(testPath); mtpLoaded(testPath);
    if (core.get_setting("mtpRealDevice") !== "true") {
        var testRoot = core.get_setting("devicesTestRoot");
        core.set_setting("mtpFixtureFailUpload", "true");
        mtpTransferCheck([testRoot + "/failed-move.txt"], testPath, "move", false);
        mtpCheck(JSON.parse(core.get_item_info(testRoot + "/failed-move.txt")).exists, "Failed move removed source");
        core.set_setting("mtpFixtureFailUpload", "false");
        var collided = mtpTransferCheck([testRoot + "/collision/renamed # %.txt"], testPath, "copy", true);
        mtpCheck(collided.length === 1 && collided[0] !== renamed.path, "Collision replaced existing file");
        var moved = mtpTransferCheck([testRoot + "/move-me.txt"], testPath, "move", true);
        mtpCheck(!JSON.parse(core.get_item_info(testRoot + "/move-me.txt")).exists, "Successful upload move retained local source");
        mtpTransferCheck(moved, stay, "move", true);
        mtpCheck(!mtpMaybeItem("move-me.txt"), "Successful download move retained phone source");
        var copiedTree = mtpTransferCheck([testRoot + "/Source tree"], testPath, "copy", true);
        mtpTransferCheck(copiedTree, stay, "copy", true);
        console.log("MTP_RW_CASE failure, collision, moves and folder round trip");
    }
    core.create_file(testPath, "empty.txt");
    mtpWait(function() { return !core.busy && !!mtpMaybeItem("empty.txt"); }, "Empty file creation failed");
    mtpCheck(mtpItem("empty.txt").size === 0, "Created file is not empty");
    engine.set_path(storage); mtpLoaded(storage);
    window.activePane.selectPaths([testPath]); window.defocusInputs(); mtpEvents.keyClick(Qt.Key_Delete);
    mtpWait(function() { return confirmDialog.visible; }, "Permanent-delete confirmation missing");
    mtpEvents.wait(250);
    var confirm = mtpFind(confirmDialog.contentItem, function(item) { return item.text === qsTr("Delete") && item.visible && item.width > 0; });
    mtpCheck(!!confirm, "Delete confirmation button missing");
    var point = confirm.mapToItem(window.contentItem, confirm.width / 2, confirm.height / 2);
    mtpEvents.mouseClick(window.contentItem, point.x, point.y, Qt.LeftButton);
    mtpWait(function() { return !core.busy && !confirmDialog.visible && !mtpMaybeItem(testName); }, "Created phone folder was not deleted");
    mtpCheck(window.mtpTestOperation.ok, "Delete reported failure: " + toastItem.message);
    console.log("MTP_UI_TEST_READ_WRITE_PASS");
}

Timer {
    interval: 100; running: true
    onTriggered: {
        try {
            theme.reduceMotionSetting = true;
            window.width = 1000; window.height = 760;
            var startup = core.get_setting("mtpStartupPath");
            if (startup) {
                mtpLoaded(startup);
                mtpCheck(!engine.read_only && engine.location_kind === "mtp", "MTP startup state lost");
                console.log("MTP_UI_TEST_STARTUP_PASS"); Qt.quit(); return;
            }
            var stay = core.get_setting("devicesTestRoot") + "/stay";
            window.showFiles(); engine.set_path(stay); sidebar.expanded = true;
            if (core.get_setting("mtpMissingService") === "true") {
                mtpEvents.wait(1800);
                mtpCheck(sidebar.drives.length === 0 && !engine.loading, "Missing optional service did not degrade gracefully");
                console.log("MTP_UI_TEST_MISSING_SERVICE_PASS"); Qt.quit(); return;
            }
            var root = core.get_setting("mtpPrimaryUri");
            var second = "mtp://loaf/2f746573742f7365636f6e64/";
            mtpWait(function() { return sidebar.drives.length === 3; }, "Phone discovery failed");
            mtpClickPhone(root); mtpLoaded(root);
            mtpCheck(engine.read_only && engine.location_kind === "mtp", "MTP is not a read-only virtual location");
            mtpCheck(sidebar.activeId === "device:" + root, "Phone highlight missing");
            var storage = mtpOpenFolder("Internal storage");
            mtpCheck(engine.item_count === 5, "Folder listing or hidden-file filtering failed");
            var file = mtpItem("notes.txt");
            mtpCheck(file.size > 0 && !file.is_dir, "File metadata lost");
            var camera = mtpOpenFolder("Camera");
            mtpCheck(engine.item_count === 0, "Empty folder not empty");
            engine.navigate_up(); mtpLoaded(storage);
            engine.go_back(); mtpLoaded(camera);
            engine.go_forward(); mtpLoaded(storage);
            engine.view_mode = "list"; mtpEvents.wait(200);
            var unicode = mtpOpenFolder("a # % π");
            mtpCheck(unicode.indexOf("%23") >= 0 && unicode.indexOf("%25") >= 0, "URI escaping lost");
            engine.navigate_up(); mtpLoaded(storage);
            mtpCheck(!engine.read_only, "Phone storage is still read-only");
            mtpReadWrite(storage, stay);
            var slow = mtpItem("Slow");
            engine.set_path(slow.path); engine.set_path(stay); mtpLoaded(stay);
            mtpEvents.wait(700); mtpCheck(engine.current_path === stay, "Stale listing changed current location");
            var count = window.tabs.length;
            mtpClickPhone(second, Qt.MiddleButton); mtpLoaded(second);
            mtpCheck(window.tabs.length === count + 1, "Phone middle-click did not open a new tab");
            mtpOpenFolder("Internal storage");
            mtpItem("Second phone only.txt");
            mtpCheck(sidebar.activeId === "device:" + second, "Second phone highlight wrong");
            console.log("MTP_CASE locked");
            mtpClickPhone("mtp://loaf/2f746573742f6c6f636b6564/");
            mtpWait(function() { return !engine.loading && engine.error_text.length > 0; }, "Locked phone error missing");
            mtpCheck(engine.item_count === 0, "Locked phone retained old rows");
            mtpClickPhone(root); mtpLoaded(root);
            console.log("MTP_CASE unplug");
            core.set_setting("mtpTestPresence", "absent");
            mtpWait(function() { return sidebar.drives.length === 0 && !engine.loading && engine.error_text.length > 0; }, "Unplug did not refresh sidebar and view");
            core.set_setting("mtpTestPresence", "present");
            mtpWait(function() { return sidebar.drives.length === 3; }, "Reconnect not discovered");
            mtpClickPhone(root); mtpLoaded(root);
            console.log("MTP_UI_TEST_ALL_PASS");
        } catch (error) { console.error("MTP_UI_TEST_FAIL", error.message); }
        Qt.quit();
    }
}
