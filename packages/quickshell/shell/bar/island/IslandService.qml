pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.apps.auth
import qs.apps.backup
import qs.apps.capture
import qs.apps.packages
import qs.components
import qs.config
import qs.modules.audio
import qs.modules.battery
import qs.modules.bluetooth
import qs.modules.focus
import qs.modules.mpd
import qs.modules.radio
import qs.modules.timer
import qs.modules.language
import qs.modules.mihomo
import qs.modules.brightness
import qs.modules.player
import qs.modules.notifications

// What the island shows, for every bar's island (Bar › Style island): the
// track (MPD first, else an MPRIS player), passing flashes (a volume or
// brightness change, a new notification) and the power actions. The wave is
// the Equalizer module's.
// Each island keeps its own view; this only tells them what happened.
//
// IPC: `qs -c shell ipc call island hub|media|power|launcher|keybinds|collapse` (the focused
// monitor's island answers).
Singleton {
  id: root

  // ---- tuning ----
  // a notification flash: Notifications › Toasts › Toast duration (0: until dismissed)
  readonly property int toastSeconds: ModuleSettings.get("notifications", "toastSeconds", 5)
  readonly property int noticeMs: toastSeconds * 1000
  readonly property int quietStartMs: 3000     // values read at startup are not news

  // a flash: "notice"; `requested`: a view asked for over IPC
  signal flashed(string kind, int ms)
  signal requested(string view, string screen)

  property bool ready: false
  Timer { running: true; interval: root.quietStartMs; onTriggered: root.ready = true }

  // ---- media: the player the Player module shows (modules/player/PlayerService) ----
  readonly property bool hasMedia: PlayerService.hasMedia
  readonly property bool playing: PlayerService.playing
  readonly property bool radio: PlayerService.radio
  // whose popup the current player belongs to: the radio's, the music's, or another app's media
  readonly property string family: PlayerService.family || "music"
  readonly property string title: PlayerService.title
  readonly property string artist: PlayerService.artist
  readonly property string cover: PlayerService.cover
  readonly property real position: PlayerService.position
  readonly property real length: PlayerService.length

  function togglePlay() { PlayerService.togglePlay(); }
  // a live activity's own player: the music's or the other apps'
  function toggleLive(kind) { (kind === "media" ? PlayerService.media : PlayerService.music).togglePlay(); }
  function next() { PlayerService.next(); }
  function prev() { PlayerService.prev(); }
  function seek(fraction) { PlayerService.seek(fraction); }


  // ---- live activities: what is running, for the pill's live slot ----
  // Held first (recording, backup, update), then music. Selection uses stable
  // activity IDs so array reordering cannot move the user's choice.
  readonly property var activities: {
    const on = {
      battery: BatteryService.present && BatteryService.discharging && BatteryService.capacity <= ShellSettings.liveBatteryBelow
               && (ShellSettings.liveBatteryStay === "fixed" || batShown),
      bluetooth: btShown && BluetoothService.mainDevice !== null,
      recording: CaptureService.recording || CaptureService.recordOutcome !== "",
      update: PackagesService.busy || RootService.running || PackagesService.status !== "",
      backup: BackupService.jobKind === "run" && (BackupService.busy || BackupService.status !== ""),
      vpn: MihomoService.serviceOn,
      focus: FocusService.on,
      timer: TimerService.active,
      radio: ShellSettings.liveRadioAlways || RadioService.active && (MpdService.playing || ShellSettings.liveRadioPaused),
      media: PlayerService.media.hasMedia && (PlayerService.media.playing || ShellSettings.liveMediaPaused),
      music: ShellSettings.liveMusicAlways || PlayerService.music.hasMedia && (PlayerService.music.playing || ShellSettings.liveMusicPaused),
      notice: noticeItem !== null
    };
    if (flashKind !== "") on[flashKind] = true;
    const list = [];
    for (const section of ["asks", "held", "flash"])
      for (const k of ShellSettings.liveOrdered(section))
        if (on[k] && ShellSettings.liveOn(k)) list.push(k);
    return list;
  }
  // a device that connects shows for a while (it is an event, not a task)
  property bool btShown: false
  readonly property string btMac: BluetoothService.mainDevice?.mac ?? ""
  onBtMacChanged: if (ready && btMac !== "") { btShown = true; btTimer.restart(); } else if (btMac === "") btShown = false
  Timer { id: btTimer; interval: 8000; onTriggered: root.btShown = false }
  // low battery with "5 s": it shows once when the level crosses the line
  property bool batShown: false
  readonly property bool batLow: BatteryService.present && BatteryService.discharging && BatteryService.capacity <= ShellSettings.liveBatteryBelow
  onBatLowChanged: if (batLow && ready) { batShown = true; batTimer.restart(); } else if (!batLow) batShown = false
  Timer { id: batTimer; interval: 5000; onTriggered: root.batShown = false }

  // a flash: a short note about a quick change (the mic, the layout, the cable)
  property string flashKind: ""
  function flash(kind) {
    if (!ready || !ShellSettings.liveOn(kind)) return;
    flashKind = kind;
    flashTimer.interval = ShellSettings.liveFlashMs;
    flashTimer.restart();
  }
  Timer { id: flashTimer; onTriggered: root.flashKind = "" }
  readonly property bool micMuted: AudioService.source?.audio?.muted ?? false
  onMicMutedChanged: flash("mic")
  readonly property string layoutNow: LanguageService.layout
  property string layoutFrom: ""               // the layout it changed from
  property string layoutLast: ""
  onLayoutNowChanged: { layoutFrom = layoutLast; layoutLast = layoutNow; if (layoutFrom !== "") flash("layout"); }
  readonly property bool pluggedNow: BatteryService.plugged
  onPluggedNowChanged: if (pluggedNow) flash("plugged")
  // the module a click on an activity opens (BarLayout.openModule)
  readonly property var liveTarget: ({ recording: "capture", timer: "timer", radio: "tuner", media: "media", music: "music", vpn: "mihomo", battery: "battery", bluetooth: "bluetooth", update: "packages", backup: "backup", mic: "audio", layout: "language", plugged: "battery" })
  property var liveViews: ({})             // screen name -> { selected: activity ID, manual: bool }
  property string pendingFrontKind: ""
  function liveFor(screen) {
    if (flashKind !== "" && activities.includes(flashKind)) return flashKind;
    const view = liveViews[screen] ?? {};
    return activities.includes(view.selected) ? view.selected : activities[0] ?? "";
  }
  function liveDirection(screen) { return liveViews[screen]?.direction ?? 1; }
  readonly property string live: liveFor("")
  function pruneLiveViews() {
    const connected = new Set(Quickshell.screens.map(s => s.name).concat([""]));
    const kept = Object.fromEntries(Object.entries(liveViews).filter(([screen]) => connected.has(screen)));
    if (Object.keys(kept).length !== Object.keys(liveViews).length) liveViews = kept;
  }
  Connections {
    target: Quickshell
    function onScreensChanged() { root.pruneLiveViews(); }
  }
  // a new activity takes the pill (Bar › Live › New one comes forward); paging goes on from there
  property var seenKinds: []
  onActivitiesChanged: {
    const added = activities.filter(k => !seenKinds.includes(k));
    seenKinds = activities;
    const views = Object.assign({}, liveViews);
    const screens = Quickshell.screens.map(s => s.name).concat([""]);
    for (const screen of screens) {
      const view = views[screen] ?? { selected: "", manual: false };
      if (!activities.includes(view.selected)) { view.selected = ""; view.manual = false; }
      views[screen] = view;
    }
    liveViews = views;
    if (ready && ShellSettings.liveFront && added.length > 0 && !added.includes(flashKind)) {
      pendingFrontKind = added[0];
      liveFrontTimer.restart();
    }
  }

  Timer {
    id: liveFrontTimer
    interval: 220
    onTriggered: {
      const kind = root.pendingFrontKind;
      root.pendingFrontKind = "";
      if (!ShellSettings.liveFront || !root.activities.includes(kind)) return;
      const views = Object.assign({}, root.liveViews);
      const screens = Quickshell.screens.map(s => s.name).concat([""]);
      for (const screen of screens) {
        const view = views[screen] ?? { selected: "", manual: false };
        if (!view.manual) { view.selected = kind; view.direction = 1; }
        views[screen] = view;
      }
      root.liveViews = views;
    }
  }
  function liveStep(delta, screen) {
    const page = activities.filter(k => k !== flashKind);
    const n = page.length;
    if (n < 2 || !ShellSettings.liveWheel) return;
    const views = Object.assign({}, liveViews);
    const view = Object.assign({ selected: "", manual: false }, views[screen] ?? {});
    const current = page.indexOf(page.includes(view.selected) ? view.selected : page[0]);
    view.selected = page[(Math.max(0, current) + delta + n) % n];
    view.manual = true;
    view.direction = delta;
    views[screen] = view;
    liveViews = views;
  }

  // ---- osd ----
  property string osdKind: ""                  // volume | brightness
  readonly property real osdLevel: osdKind === "volume" ? AudioService.volume / 100 : BrightnessService.brightness / 100
  // past 100 %: the sink is boosted, shown red
  readonly property bool osdLoud: osdKind === "volume" && !osdMuted && osdLevel > 1.0
  readonly property bool osdMuted: osdKind === "volume" && AudioService.muted
  readonly property string osdIcon: osdKind === "brightness" ? "sun" : osdMuted || AudioService.volume === 0 ? "volume-x" : "volume"

  // a volume or brightness change is a flash of the live slot (the "volume" kind)
  function osd(kind) {
    // a volume change made in the open volume popup shows in the popup, not as a flash
    if (kind === "volume" && PopupManager.current?.ipcTarget === "audio") return;
    osdKind = kind;
    flash("volume");
  }

  Connections {
    target: AudioService
    function onVolumeChanged() { root.osd("volume"); }
    function onMutedChanged() { root.osd("volume"); }
  }
  Connections {
    target: BrightnessService
    function onBrightnessChanged() { root.osd("brightness"); }
  }

  // ---- notice ----
  readonly property int noticeMax: 3         // notices stacked at once, newest on top
  property var notices: []                     // [{key, app, summary, body, urgency, time}]
  property int noticeMore: 0                   // fresh ones past the stack: "N more notifications"
  property real noticeTime: 0                 // the newest one taken: later ones are news
  property var noticeSeen: ({})                // notification key -> last version shown
  property var noticeQueue: []                 // live notices wait in arrival order

  // Notifications › Delivery › Show as: a card (the island's toast) or a live activity (a line in the slot)
  readonly property string noticeAppear: ModuleSettings.get("notifications", "appear", "card")
  property var noticeItem: null                // the one the live slot shows (appear "live")
  property var deferredNotices: []              // ordinary notices wait until fullscreen ends
  readonly property bool fullscreenActive: Number(Hyprland.activeToplevel?.lastIpcObject?.fullscreen ?? 0) > 0
  onFullscreenActiveChanged: if (!fullscreenActive) drainDeferredNotices()
  onNoticeAppearChanged: if (noticeAppear !== "live") clearLiveNotices()
  function clearLiveNotices() { noticeItem = null; noticeQueue = []; noticeLiveTimer.stop(); }
  Connections {
    target: ShellSettings
    function onLiveEnabledChanged() {
      if (ShellSettings.liveEnabled) return;
      root.clearLiveNotices();
      root.flashKind = "";
      flashTimer.stop();
    }
  }
  Connections {
    target: ShellSettings
    function onLiveNoticeMsChanged() {
      if (!root.noticeItem || root.noticeItem.urgency === "critical") return;
      if (ShellSettings.liveNoticeMs === 0) noticeLiveTimer.stop();
      else { noticeLiveTimer.interval = ShellSettings.liveNoticeMs; noticeLiveTimer.restart(); }
    }
  }

  Connections {
    target: NotificationsService
    function onItemsChanged() {
      if (!root.ready) return;
      const now = Date.now();
      const items = NotificationsService.items;
      const keys = new Set(items.map(n => n.key));
      const seen = Object.fromEntries(Object.entries(root.noticeSeen).filter(([key]) => keys.has(key)));
      const fresh = items.filter(n => n.time > (seen[n.key] ?? 0) && now - n.time <= 10000);
      if (fresh.length === 0) return;
      for (const n of fresh) seen[n.key] = n.time;
      root.noticeSeen = seen;
      root.noticeTime = Math.max(root.noticeTime, ...fresh.map(n => n.time));
      // Focus: only the critical ones come through
      const deliver = FocusService.on ? fresh.filter(n => n.urgency === "critical") : fresh;
      root.routeNotices(deliver);
    }
  }
  function routeNotices(items) {
    if (items.length === 0) return;
    const critical = items.filter(n => n.urgency === "critical");
    if (fullscreenActive) {
      const ordinary = items.filter(n => n.urgency !== "critical");
      deferredNotices = ordinary.concat(deferredNotices.filter(n => !ordinary.some(f => f.key === n.key))).slice(-32);
    }
    const deliver = fullscreenActive ? critical : items;
    if (deliver.length === 0) return;
    if (noticeAppear === "live" && ShellSettings.liveEnabled) {
      // A live notice holds the slot until its turn ends; critical notices preempt.
      enqueueLiveNotices(deliver.slice().reverse());
      return;
    }
    // A replaced notification (same key) takes its old toast's place.
    notices = deliver.concat(notices.filter(n => !deliver.some(f => f.key === n.key))).slice(0, noticeMax);
    noticeMore = Math.max(0, deliver.length - noticeMax);
    flashed("notice", hasCritical() ? 0 : noticeMs);
  }
  function drainDeferredNotices() {
    if (fullscreenActive || deferredNotices.length === 0) return;
    const fresh = deferredNotices.filter(n => Date.now() - n.time <= 30000);
    deferredNotices = [];
    routeNotices(fresh);
  }
  function sameNotice(a, b) { return a.app === b.app && a.summary === b.summary && a.body === b.body && a.urgency === b.urgency; }
  function showNextLiveNotice(markRead) {
    if (noticeQueue.length === 0) {
      noticeItem = null;
      noticeLiveTimer.stop();
      if (markRead) NotificationsService.markSeen();
      return;
    }
    noticeItem = noticeQueue[0];
    noticeQueue = noticeQueue.slice(1);
    if (noticeItem.urgency === "critical" || ShellSettings.liveNoticeMs === 0) noticeLiveTimer.stop();
    else { noticeLiveTimer.interval = ShellSettings.liveNoticeMs; noticeLiveTimer.restart(); }
  }
  function enqueueLiveNotices(items) {
    let queue = noticeQueue.slice();
    for (const item of items) {
      if (noticeItem && noticeItem.key === item.key) {
        noticeItem = Object.assign({}, item, { repeats: noticeItem.repeats ?? 1 });
        if (noticeItem.urgency === "critical" || ShellSettings.liveNoticeMs === 0) noticeLiveTimer.stop();
        else { noticeLiveTimer.interval = ShellSettings.liveNoticeMs; noticeLiveTimer.restart(); }
        continue;
      }
      if (noticeItem && sameNotice(noticeItem, item)) {
        noticeItem = Object.assign({}, noticeItem, { repeats: (noticeItem.repeats ?? 1) + 1 });
        if (noticeItem.urgency !== "critical" && ShellSettings.liveNoticeMs > 0) noticeLiveTimer.restart();
        continue;
      }
      if (item.urgency === "critical" && noticeItem && noticeItem.urgency !== "critical") {
        noticeLiveTimer.stop();
        queue.unshift(noticeItem);
        noticeItem = Object.assign({ repeats: 1 }, item);
        continue;
      }
      const duplicate = queue.findIndex(n => sameNotice(n, item));
      if (duplicate >= 0) queue[duplicate] = Object.assign({}, queue[duplicate], { repeats: (queue[duplicate].repeats ?? 1) + 1 });
      else if (item.urgency === "critical") {
        const firstOrdinary = queue.findIndex(n => n.urgency !== "critical");
        queue.splice(firstOrdinary < 0 ? queue.length : firstOrdinary, 0, Object.assign({ repeats: 1 }, item));
      } else queue.push(Object.assign({ repeats: 1 }, item));
    }
    noticeQueue = queue.slice(0, 32);
    if (!noticeItem) showNextLiveNotice();
  }
  Timer { id: noticeLiveTimer; onTriggered: root.showNextLiveNotice(false) }
  function dismissLiveNotice() { noticeLiveTimer.stop(); showNextLiveNotice(true); }

  function hasCritical() { return root.notices.some(n => n.urgency === "critical"); }

  // the notice flash is over, or an OSD replaces it: its toasts leave the
  // island (the centre keeps them), so a later notice does not bring them back.
  // keepCritical (an OSD): the critical ones stay, to come back after it
  function clearNotices(keepCritical) {
    root.notices = keepCritical ? root.notices.filter(n => n.urgency === "critical") : [];
    root.noticeMore = 0;
    root.noticeQueue = keepCritical ? root.noticeQueue.filter(n => n.urgency === "critical") : [];
  }

  // a click on a notice: its app's window, else the notifications popup (D-02)
  function activate(item) {
    if (!NotificationsService.focusApp(item)) openNotifications();
  }

  function dismissNotice(key) {
    root.notices = root.notices.filter(n => n.key !== key);
    if (root.notices.length === 0) {
      root.noticeMore = 0;
      // closed on the island: no unseen dot left behind on the compact island
      NotificationsService.markSeen();
    }
  }

  // mako's `island` mode (themes/*/mako/config) keeps notifications off screen
  // while the island shows them; they still reach its history
  readonly property bool island: Theme.island
  onIslandChanged: makoMode()
  Component.onCompleted: { makoMode(); toastMode(); }
  function makoMode() {
    Quickshell.execDetached(["makoctl", "mode", island ? "-a" : "-r", "island"]);
  }

  // the toast duration is one of mako's toast-N modes (themes/*/mako/config),
  // so Solid toasts follow the setting too; the island reads it itself
  onToastSecondsChanged: toastMode()
  function toastMode() {
    const keep = "toast-" + toastSeconds;
    const args = ["makoctl", "mode", "-a", keep];
    for (const s of [3, 5, 10, 0]) if (("toast-" + s) !== keep) args.push("-r", "toast-" + s);
    Quickshell.execDetached(args);
  }

  // the centre opened (from anywhere): the toasts close, the centre keeps them
  Connections {
    target: NotificationsService
    function onOpened() { root.clearNotices(); root.noticeItem = null; noticeLiveTimer.stop(); }
  }

  function openNotifications() {
    ShellIpc.call("notifications", "toggle");
  }

  // ---- power ----
  readonly property var powerActions: [
    { id: "poweroff",  icon: "power",      label: "Power off", confirm: true },
    { id: "reboot",    icon: "refresh",    label: "Reboot",    confirm: true },
    { id: "lock",      icon: "lock",       label: "Lock",      confirm: false },
    { id: "hibernate", icon: "info",       label: "Hibernate", confirm: true },
    { id: "suspend",   icon: "moon",       label: "Suspend",   confirm: false }
  ]

  function power(action) {
    if (action === "lock") ShellIpc.call("lock", "lock");
    else if (action === "suspend") Quickshell.execDetached(["sh", "-c", "qs -c shell ipc call lock lock; sleep 0.5; systemctl suspend"]);
    else Quickshell.execDetached(["systemctl", action]);
  }

  IpcHandler {
    target: "island"
    enabled: Theme.island
    function hub(): void { root.requested("hub", Hyprland.focusedMonitor?.name ?? ""); }
    function media(): void { root.requested("media", Hyprland.focusedMonitor?.name ?? ""); }
    function power(): void { root.requested("power", Hyprland.focusedMonitor?.name ?? ""); }
    function launcher(): void { root.requested("launcher", Hyprland.focusedMonitor?.name ?? ""); }
    function keybinds(): void { root.requested("keybinds", Hyprland.focusedMonitor?.name ?? ""); }
    function collapse(): void { root.requested("compact", ""); }
  }
}
