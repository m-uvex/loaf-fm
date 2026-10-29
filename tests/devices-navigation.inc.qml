// Injected into the real main.qml by check-devices-sidebar.py. Only test
// scenarios and event helpers live here; navigation uses production code.
TestCase { id: deviceEvents; when: false }
function deviceCheck(condition, message) {
    if (!condition) throw new Error(message);
}
function deviceWait(predicate, message) {
    for (var i = 0; i < 600 && !predicate(); ++i) deviceEvents.wait(10);
    deviceCheck(predicate(), message);
}
function testFolder(name) { return core.get_setting("devicesTestRoot") + "/" + name; }
function deviceNavigate(name) {
    window.showFiles();
    engine.set_path(testFolder(name));
    deviceEvents.wait(30);
}
function deviceFind(item, predicate) {
    if (predicate(item)) return item;
    var children = item.children || [];
    for (var i = 0; i < children.length; ++i) {
        var found = deviceFind(children[i], predicate);
        if (found) return found;
    }
    return null;
}
function deviceButton(name) {
    var list = deviceFind(sidebar, function(item) { return item.positionViewAtIndex !== undefined; });
    var entry = null;
    deviceWait(function() {
        var index = sidebar.entries.findIndex(function(item) { return item.id === "device:/dev/loaf-test-" + name; });
        if (index < 0) return false;
        list.positionViewAtIndex(index, ListView.Contain);
        entry = list.itemAtIndex(index);
        return entry && entry.button && entry.modelData.id === "device:/dev/loaf-test-" + name;
    }, "Missing device row: " + name);
    deviceEvents.wait(30);
    var point = entry.button.mapToItem(list, 20, 22);
    deviceCheck(point.y >= 0 && point.y < list.height, "Clipped row: " + name);
    return entry.button;
}
function deviceClick(name, button) {
    var row = deviceButton(name);
    deviceEvents.mouseClick(row, row.width / 2, 22, button || Qt.LeftButton);
}
function deviceSettled() {
    deviceWait(function() { return !core.busy && window.pendingMountDevice === ""; }, "Operation did not settle");
    deviceEvents.wait(50);
}
function devicePassword(text) {
    deviceWait(function() { return passwordModal.visible; }, "Missing password prompt");
    deviceEvents.wait(240);
    for (var character of text) deviceEvents.keyClick(character);
    deviceEvents.keyClick(Qt.Key_Return);
}
Timer {
    interval: 100; running: true
    onTriggered: {
        try {
            theme.reduceMotionSetting = true;
            window.width = 640; window.height = 420;
            deviceNavigate("stay");
            deviceWait(function() { return sidebar.drives.length >= 10; }, "Drives not loaded");
            sidebar.expanded = true;
            deviceEvents.wait(300);
            deviceCheck(sidebar.width === 200, "Expanded sidebar width");
            deviceClick("mounted");
            deviceCheck(engine.current_path === testFolder("mounted"), "Mounted click did not open");
            deviceCheck(sidebar.activeId === "device:/dev/loaf-test-mounted", "Mounted highlight missing");
            sidebar.expanded = false;
            deviceEvents.wait(300);
            deviceNavigate("stay");
            var row = deviceButton("mounted");
            row.forceActiveFocus();
            deviceEvents.keyClick(Qt.Key_Space);
            deviceCheck(engine.current_path === testFolder("mounted"), "Keyboard activation failed");
            deviceCheck(sidebar.width === 68, "Collapsed sidebar width");
            var mountedTabCount = window.tabs.length;
            deviceEvents.mouseClick(row, row.width / 2, 22, Qt.MiddleButton);
            deviceCheck(window.tabs.length === mountedTabCount + 1, "Mounted middle click did not create tab");
            sidebar.expanded = true;
            deviceEvents.wait(250);
            console.log("DEVICES_CASE mounted, keyboard, collapsed and short sidebar");

            deviceNavigate("stay");
            deviceClick("success");
            deviceCheck(window.pendingMountDevice === "/dev/loaf-test-success", "Mount not requested");
            deviceClick("success"); // Runner checks that only one command ran.
            deviceCheck(engine.current_path === testFolder("stay"), "Navigated before mount success");
            core.operation_finished("drive", true, JSON.stringify({action: "mount", device: "/dev/other", mount_point: testFolder("other")}));
            core.operation_finished("drive", true, JSON.stringify({action: "rename", device: "/dev/loaf-test-success"}));
            deviceCheck(window.pendingMountDevice === "/dev/loaf-test-success", "Unrelated result consumed request");
            deviceSettled();
            deviceCheck(engine.current_path === testFolder("success"), "Successful mount did not open");
            console.log("DEVICES_CASE delayed mount, duplicate clicks and result correlation");

            deviceNavigate("stay");
            deviceClick("fail");
            deviceSettled();
            deviceCheck(engine.current_path === testFolder("stay"), "Failed mount changed folder");
            deviceClick("cancel");
            deviceNavigate("other");
            deviceNavigate("stay");
            deviceSettled();
            deviceCheck(engine.current_path === testFolder("stay"), "Late result hijacked folder");
            deviceClick("view");
            window.openSettings();
            deviceSettled();
            deviceCheck(window.activeView === "settings", "Late result left Settings");
            deviceNavigate("stay");
            deviceClick("tab", Qt.MiddleButton);
            var count = window.tabs.length;
            window.newTab(testFolder("other"));
            deviceSettled();
            deviceCheck(window.tabs.length === count + 1 && engine.current_path === testFolder("other"), "Late result hijacked tab");
            console.log("DEVICES_CASE failure, folder/view/tab cancellation");

            window.openPc();
            deviceEvents.wait(100);
            var card = deviceFind(pcView, function(item) { return item.visible && item.drive !== undefined && item.drive.device === "/dev/loaf-test-pc"; });
            deviceCheck(card, "This PC drive card missing");
            var flick = card.parent;
            while (flick && flick.contentY === undefined) flick = flick.parent;
            var point = card.mapToItem(flick.contentItem, 0, 0);
            flick.contentY = Math.max(0, Math.min(point.y - 40, flick.contentHeight - flick.height));
            deviceEvents.wait(50);
            deviceEvents.mouseClick(card, 30, card.height / 2, Qt.LeftButton);
            deviceCheck(window.pendingMountDevice === "/dev/loaf-test-pc", "This PC click did not request mount");
            deviceSettled();
            deviceCheck(window.activeView === "files" && engine.current_path === testFolder("pc"), "This PC mount did not open");

            deviceNavigate("stay");
            deviceClick("gone");
            deviceEvents.wait(120);
            core.load_drives();
            deviceWait(function() { return !sidebar.drives.some(function(d) { return d.device === "/dev/loaf-test-gone"; }); }, "Unplug did not refresh");
            deviceSettled();
            deviceCheck(engine.current_path === testFolder("stay"), "Unplugged result changed folder");
            console.log("DEVICES_CASE This PC mount and simulated unplug");

            deviceClick("locked");
            deviceWait(function() { return passwordModal.visible; }, "Password prompt missing");
            deviceEvents.keyClick(Qt.Key_Escape);
            deviceWait(function() { return !passwordModal.visible && window.pendingMountDevice === ""; }, "Password cancellation left pending intent");
            deviceClick("locked");
            devicePassword("wrong");
            deviceWait(function() { return passwordModal.visible && passwordModal.request.error === true && !core.busy; }, "Password retry missing");
            deviceCheck(window.pendingMountDevice === "/dev/loaf-test-locked", "Wrong password discarded navigation intent");
            devicePassword("test-pass");
            deviceSettled();
            deviceCheck(engine.current_path === testFolder("locked"), "Authenticated drive did not open");
            deviceNavigate("stay");
            deviceClick("unlock-fail");
            devicePassword("test-pass");
            deviceSettled();
            deviceCheck(engine.current_path === testFolder("stay"), "Unlock mount failure changed folder");
            console.log("DEVICES_CASE password cancel/retry and post-unlock mount failure");
            console.log("DEVICES_UI_TEST_ALL_PASS");
        } catch (error) {
            console.error("DEVICES_UI_TEST_FAIL: " + error.message);
        }
        Qt.quit();
    }
}
