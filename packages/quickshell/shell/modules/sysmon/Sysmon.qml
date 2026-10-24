import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar module: the CPU load, and on request memory, CPU temperature, GPU and
// network speed (Shell Manager › Modules › System › BAR). Each is tinted as it
// climbs. Opens the system metrics.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  // ---- bar metrics ----
  readonly property bool showMemory: ModuleSettings.get("sysmon", "barMemory", false)
  readonly property bool showTemp: ModuleSettings.get("sysmon", "barTemp", false)
  readonly property bool showGpu: ModuleSettings.get("sysmon", "barGpu", false)
  readonly property bool showNetwork: ModuleSettings.get("sysmon", "barNetwork", false)
  readonly property bool needsFull: showMemory || showTemp || showGpu || showNetwork
  readonly property int memPercent: SysmonService.mem.total > 0 ? Math.round(100 * SysmonService.memUsed / SysmonService.mem.total) : -1

  // the full snapshot while one of them is on the bar, as the task manager holds it
  property bool holding: false
  function syncHold() {
    if (needsFull === holding) return;
    holding = needsFull;
    if (holding) SysmonService.hold();
    else SysmonService.release();
  }
  onNeedsFullChanged: syncHold()
  Component.onCompleted: syncHold()
  Component.onDestruction: {
    if (holding) SysmonService.release();
  }

  // two digits wide, so the bar doesn't shift between 9% and 10%; "--" while unknown
  function percent(p) { return p < 0 ? "--" : String(p).padStart(2, " ") + "%"; }
  function heat(t) { return t >= 85 ? Theme.red : t >= 70 ? Theme.yellow : Theme.foreground0; }
  function compact(bytes) { return bytes < 1048576 ? Math.round(bytes / 1024) + "K" : (bytes / 1048576).toFixed(1) + "M"; }

  implicitWidth: strip.implicitWidth
  implicitHeight: strip.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("sysmon")
  Accessible.description: "Open system metrics"

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat) { popup.toggle(); }
    event.accepted = true;
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusControl
    color: "transparent"
    border.width: root.activeFocus ? 2 : 0
    border.color: Theme.foreground0
  }

  Row {
    id: strip
    spacing: Theme.gapMedium

    KitBarItem {
      icon: "cpu"
      text: ModuleSettings.get("sysmon", "barPercent", true) ? BarLayout.faceText("sysmon", root.percent(SysmonService.cpu), "CPU") : ""
      tint: Theme.loadColor(SysmonService.cpu)
    }

    KitBarItem {
      visible: root.showMemory
      icon: "grid"
      text: BarLayout.faceText("sysmon", root.percent(root.memPercent), "RAM")
      tint: root.memPercent < 0 ? Theme.muted : Theme.loadColor(root.memPercent)
    }

    KitBarItem {
      visible: root.showTemp
      icon: "gauge"
      text: BarLayout.faceText("sysmon", SysmonService.temps.cpu === null ? "--" : SysmonService.temps.cpu + "°", "TEMP")
      tint: SysmonService.temps.cpu === null ? Theme.muted : root.heat(SysmonService.temps.cpu)
    }

    KitBarItem {
      visible: root.showGpu && SysmonService.dgpu.state !== "none"
      icon: "monitor"
      text: BarLayout.faceText("sysmon", SysmonService.dgpu.state === "active" ? root.percent(SysmonService.dgpu.util ?? -1) : "--", "GPU")
      tint: SysmonService.dgpu.state === "active" ? Theme.loadColor(SysmonService.dgpu.util ?? 0) : Theme.muted
    }

    KitBarItem {
      visible: root.showNetwork
      icon: "download"
      text: BarLayout.faceText("sysmon", "↓" + root.compact(SysmonService.rxRate) + " ↑" + root.compact(SysmonService.txRate), "NET")
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "sysmon"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: SysmonService.popupShown()
    onHidden: SysmonService.popupHidden()

    SysmonPopup {
      id: content
      anchors.fill: parent
    }
  }
}
