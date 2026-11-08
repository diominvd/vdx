import QtQuick
import QtTest
import qs.kit

TestCase {
  name: "WifiRow"
  when: windowShown
  width: 360
  height: 100
  visible: true

  TestNetworkRow {
    id: row
    width: 300
    modelData: ({ssid: "fixture-network", secure: true, signal: 80, saved: false})
  }

  function init() {
    row.modelData = ({ssid: "fixture-network", secure: true, signal: 80, saved: false});
    TestWifiService.connected = false;
    TestWifiService.radioOn = true;
    TestWifiService.ssid = "";
    TestWifiService.connectingSsid = "";
    TestWifiService.hiddenBusy = false;
    TestWifiService.calls = [];
    row.forceActiveFocus();
  }

  function test_signal_name_and_single_trailing_state() {
    const signal = findChild(row, "networkSignal");
    const name = findChild(row, "networkName");
    const mark = findChild(row, "networkState");
    verify(signal.x + signal.width < name.x);
    verify(name.x + name.width < mark.x);
    compare(mark.x + mark.width, row.width - 10);
    compare(mark.name, "lock");
    verify(mark.visible);
    TestWifiService.connected = true;
    TestWifiService.ssid = "fixture-network";
    compare(mark.name, "check");
    verify(mark.visible);
    TestWifiService.connected = false;
    row.modelData = ({ssid: "open-network", secure: false, signal: 20});
    verify(!mark.visible);
    row.width = 180;
    row.modelData = ({ssid: "a very long network name which must be elided", secure: true, signal: 20});
    verify(name.width > 0);
    verify(name.x + name.width < mark.x);
    row.width = 300;
  }

  function test_keyboard_and_mouse_activate_network() {
    verify(row.activeFocus);
    verify(row.Accessible.name.indexOf("secured network") >= 0);
    keyClick(Qt.Key_Space);
    keyClick(Qt.Key_Return);
    mouseClick(row, 20, 15);
    compare(TestWifiService.calls.length, 3);
    compare(TestWifiService.calls[0], "fixture-network");
  }

  function test_current_connecting_or_off_network_cannot_activate() {
    TestWifiService.connected = true;
    TestWifiService.ssid = "fixture-network";
    compare(row.enabled, false);
    row.activate();
    TestWifiService.connected = false;
    TestWifiService.connectingSsid = "another-network";
    compare(row.enabled, false);
    row.activate();
    TestWifiService.connectingSsid = "";
    TestWifiService.hiddenBusy = true;
    compare(row.enabled, false);
    row.activate();
    TestWifiService.hiddenBusy = false;
    TestWifiService.radioOn = false;
    row.activate();
    compare(TestWifiService.calls.length, 0);
  }
}
