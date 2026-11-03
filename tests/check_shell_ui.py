#!/usr/bin/env python3
"""Run the kit's keyboard/layout tests without opening desktop windows.

Requires qt6-declarative (qmltestrunner). Quickshell embeds its plugins, so
this harness supplies a plain clipped rectangle for ClippingRectangle and
replaces the Motion singleton's container. It tests interaction and tokens;
live Quickshell is still needed to verify GPU clipping and window behaviour.
Layout functions use a memory-only store. No real settings or desktop state
are accessed.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "packages/quickshell/shell"


def qml_block(source, marker):
    """Extract a production block for a host without system side effects."""
    start = source.index(marker)
    brace = source.index("{", start)
    depth, end = 1, brace + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


def qml_function(source, name):
    return qml_block(source, "  function " + name + "(")


def main():
    runner = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"
    with tempfile.TemporaryDirectory(prefix="shell-ui-") as tmp:
        work = Path(tmp)
        config = work / "qs/config"
        config.mkdir(parents=True)
        shutil.copytree(SHELL / "kit", work / "qs/kit")
        for name in ("EntryBrowser.qml", "EntryCard.qml"):
            shutil.copy(SHELL / "apps/shellmanager" / name, work / "qs/kit" / name)
        shutil.copy(SHELL / "apps/shellmanager/BarArrangement.qml", work / "qs/kit/BarArrangement.qml")
        for name in ("Theme.qml", "Motion.qml"):
            text = (SHELL / "config" / name).read_text()
            text = text.replace("import Quickshell\n", "").replace("Singleton {", "QtObject {")
            (config / name).write_text(text)
        shutil.copy(ROOT / "themes/gruvbox/quickshell/shell/config/Colors.qml", config / "Colors.qml")
        settings = (SHELL / "config/ShellState.qml").read_text()
        settings = settings.replace("import Quickshell.Io", "").replace("JsonAdapter {", "QtObject {")
        # Exercise the production named-shape accessors against isolated settings.
        source = (SHELL / "config/ShellSettings.qml").read_text()
        start = source.index("  readonly property var lookDefaults:")
        end = source.index("\n  // animations", start)
        look_defaults = source[start:end]
        look_properties = "\n".join(line for line in source.splitlines()
                                    if line.startswith("  readonly property ") and ": look(" in line)
        look_defaults += "\n" + look_properties
        settings = settings.replace("QtObject {", "QtObject {\n  id: state\n" + look_defaults + "\n" + qml_function(source, "look") + "\n" + qml_function(source, "setLook"), 1)
        (config / "ShellSettings.qml").write_text("pragma Singleton\n" + settings)
        # The real selection model has no portal, filesystem or process dependencies.
        shutil.copy(SHELL / "apps/files/FilesSelection.qml", work / "qs/kit/FilesSelection.qml")
        shutil.copy(SHELL / "apps/files/FilesHistory.qml", work / "qs/kit/FilesHistory.qml")
        shutil.copy(SHELL / "apps/capture/CaptureSavePanel.qml", work / "qs/kit/CaptureSavePanel.qml")
        shutil.copy(SHELL / "components/PopupContentHost.qml", work / "qs/kit/PopupContentHost.qml")
        shutil.copy(SHELL / "apps/lock/LockAuthentication.qml", work / "qs/kit/LockAuthentication.qml")
        shutil.copy(SHELL / "apps/lock/LockLifecycle.qml", work / "qs/kit/LockLifecycle.qml")
        device_row = (SHELL / "modules/bluetooth/DeviceRow.qml").read_text()
        (work / "qs/kit/TestBluetoothRow.qml").write_text(
            device_row.replace("BluetoothService", "TestBluetoothService"))
        (work / "qs/kit/TestBluetoothService.qml").write_text(
            'pragma Singleton\nimport QtQuick\nQtObject {\n'
            'property bool powered: true\nproperty string busyMac: ""\nproperty var calls: []\n'
            'function toggleDevice(device) { calls = calls.concat([device.mac]); }\n}\n')
        shutil.copy(SHELL / "modules/wifi/SignalBars.qml", work / "qs/kit/SignalBars.qml")
        network_row = (SHELL / "modules/wifi/NetworkRow.qml").read_text()
        (work / "qs/kit/TestNetworkRow.qml").write_text(
            network_row.replace("WifiService", "TestWifiService"))
        (work / "qs/kit/TestWifiService.qml").write_text(
            'pragma Singleton\nimport QtQuick\nQtObject {\n'
            'property bool connected: false\nproperty bool radioOn: true\n'
            'property string ssid: ""\nproperty string connectingSsid: ""\n'
            'property bool hiddenBusy: false\n'
            'readonly property bool connectionBusy: connectingSsid !== "" || hiddenBusy\n'
            'property var calls: []\n'
            'function connectTo(network) { calls = calls.concat([network.ssid]); }\n}\n')
        lock = (SHELL / "apps/lock/Lock.qml").read_text()
        (work / "qs/kit/TestLockRouting.qml").write_text(
            'import QtQuick\nimport TestQuickshell\nimport qs.config\nQtObject {\n'
            '  id: root\n  property string snapshotDir: "/unused-test-snapshots"\n'
            '  property string focusedScreen: "HDMI-A-1"\n'
            '  readonly property string screenOption: ModuleSettings.get("lock", "screen", "all")\n'
            '  property QtObject session: QtObject { id: sessionLock; property bool locked: false }\n'
            '  property QtObject lifecycleState: QtObject { id: lifecycle; function requestLock() { return true; } }\n'
            '  property QtObject snapshots: QtObject {\n'
            '    id: preparation\n    property bool busy: false\n    property var calls: []\n'
            '    function prepare(directory, screens) { calls = calls.concat([{directory: directory, screens: screens}]); busy = true; }\n'
            '  }\n'
            + qml_function(lock, "lock") + '\n' + qml_function(lock, "shows") + '\n}\n')
        brightness = (SHELL / "modules/brightness/BrightnessService.qml").read_text()
        (work / "qs/kit/TestBrightnessSchedule.qml").write_text(
            'import QtQuick\nQtObject {\nproperty bool ready: true\nproperty var inSchedule: null\n'
            'property var schedule: ({enabled: true, start: "21:00", end: "07:00"})\n'
            'property bool night: false\nfunction setNight(on) { night = on; }\n'
            + qml_function(brightness, "minutes") + '\n'
            + qml_function(brightness, "checkSchedule") + '\n}\n')
        timer = (SHELL / "modules/timer/TimerService.qml").read_text()
        timer_state = timer.split("  // ---- the tick ----")[0]
        timer_state = timer_state.replace("pragma Singleton\n", "").replace("import Quickshell\n", "").replace("import Quickshell.Io\n", "").replace("Singleton {", "QtObject {")
        (work / "qs/kit/TestTimerState.qml").write_text(
            timer_state + qml_function(timer, "finish")
            + '\n  property QtObject notifications: QtObject { id: ring; property var command: []; '
            'property int calls: 0; property bool running: false; '
            'onRunningChanged: if (running) { calls++; running = false; } }\n}\n')
        island_service = (SHELL / "bar/island/IslandService.qml").read_text()
        (work / "qs/kit/TestIslandLiveSelection.qml").write_text(
            'import QtQuick\nimport qs.config\nItem {\n'
            '  property var activities: []\n  property string flashKind: ""\n'
            '  property var liveViews: ({})\n  property var liveWheelTimes: ({})\n'
            + qml_function(island_service, "liveFor") + '\n'
            + qml_function(island_service, "liveDirection") + '\n'
            + qml_function(island_service, "liveStep") + '\n}\n')
        (work / "qs/kit/TestIslandNoticeQueue.qml").write_text(
            'import QtQuick\nimport qs.config\nItem {\n'
            '  id: root\n  property var noticeQueue: []\n  property var noticeItem: null\n'
            '  property int markedSeen: 0\n  readonly property bool timerRunning: noticeLiveTimer.running\n'
            '  function markNoticesSeen() { markedSeen++; }\n'
            '  Timer { id: noticeLiveTimer }\n'
            + qml_function(island_service, "sameNotice") + '\n'
            + qml_function(island_service, "showNextLiveNotice").replace("NotificationsService.markSeen()", "root.markNoticesSeen()") + '\n'
            + qml_function(island_service, "enqueueLiveNotices") + '\n}\n')
        settings_index = (SHELL / "apps/shellmanager/SettingsIndex.qml").read_text()
        (work / "qs/kit/TestSettingsIndex.qml").write_text(
            'import QtQuick\nQtObject {\n  property var indexed: []\n'
            + qml_function(settings_index, "norm") + '\n'
            + qml_function(settings_index, "words") + '\n'
            + qml_function(settings_index, "search") + '\n}\n')
        files = (SHELL / "apps/files/FilesState.qml").read_text()
        (work / "qs/kit/TestFileCreation.qml").write_text(
            'import QtQuick\nQtObject {\nproperty var calls: []\nproperty var history: []\n'
            'function act(request, args) { calls = calls.concat([{request: request, args: args}]); }\n'
            'function record(entry) { history = history.concat([entry]); }\n'
            + qml_function(files, "createNew") + '\n}\n')
        # Layout logic uses its production functions with a memory-only store.
        bar = work / "qs/bar"
        bar.mkdir()
        layout = (SHELL / "bar/BarLayout.qml").read_text().split("  // written by `./install.py link`;")[0]
        layout = layout.replace("import Quickshell\n", "import TestQuickshell\n").replace("import Quickshell.Io\n", "").replace("Singleton {", "QtObject {")
        # Popup IPC is outside these memory-only layout tests.
        layout = layout.replace("import qs.components\n", "")
        layout += """  property QtObject store: QtObject {
          id: state
          property var zones: null
          property var hidden: []
          property var screens: ({})
          property bool shared: false
          property string main: ""
        }
        }
"""
        (bar / "BarLayout.qml").write_text(layout)
        components = work / "qs/components"
        components.mkdir()
        manager = (SHELL / "components/PopupManager.qml").read_text()
        (components / "PopupManager.qml").write_text(manager.replace("import Quickshell.Hyprland", "import TestQuickshell"))
        popup = (SHELL / "bar/BarPopup.qml").read_text()
        (components / "TestPopupLifetime.qml").write_text(
            'import QtQuick\nQtObject {\n  id: root\n'
            '  property bool visible: false\n  property var bar: ({screen: {name: "one"}})\n'
            '  property var probe: null\n'
            '  onVisibleChanged: if (!visible && probe) probe.closed++\n'
            + qml_block(popup, "  Component.onDestruction:") + '\n}\n')
        fake = work / "TestQuickshell"
        fake.mkdir()
        (fake / "qmldir").write_text("module TestQuickshell\nsingleton Quickshell 1.0 Quickshell.qml\nsingleton Hyprland 1.0 Hyprland.qml\n")
        (fake / "Quickshell.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { property var screens: [{name: "HDMI-A-1"}, {name: "eDP-1"}] }\n')
        (fake / "Hyprland.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { property var focusedMonitor: null }\n')
        (config / "ModuleSettings.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { property var values: ({}); function get(module, key, fallback) { return values[module + "/" + key] ?? fallback; } }\n')
        state_file = config / "ShellSettings.qml"
        state_file.write_text(state_file.read_text().replace("id: state", "id: state\n  function set(key, value) { state[key] = value; }", 1))
        for folder in (config, work / "qs/kit", bar, components):
            entries = ["module qs." + folder.name]
            for file in sorted(folder.glob("*.qml")):
                prefix = "singleton " if "pragma Singleton" in file.read_text() else ""
                entries.append(f"{prefix}{file.stem} 1.0 {file.name}")
            (folder / "qmldir").write_text("\n".join(entries) + "\n")
        widgets = work / "Quickshell/Widgets"
        widgets.mkdir(parents=True)
        (widgets / "qmldir").write_text("module Quickshell.Widgets\nClippingRectangle 1.0 ClippingRectangle.qml\n")
        (widgets / "ClippingRectangle.qml").write_text("import QtQuick\nRectangle { clip: true }\n")
        for test in (ROOT / "tests/qml").glob("tst_*.qml"):
            shutil.copy(test, work)
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
        return subprocess.run([runner, "-input", tmp, "-import", tmp], env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
