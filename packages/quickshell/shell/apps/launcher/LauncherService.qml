pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.bar
import qs.apps.keybinds
import qs.apps.shellmanager
import qs.config
import qs.modules.windows

// The launcher's lists (Launcher.qml shows them): installed apps, files
// in ~ (fd), the shell's own actions, power. Every item is
// { icon | image, title, hint, keys, run() }.
Singleton {
  id: root

  // ---- state ----
  property bool open: false
  property var files: []                    // [path] of the last search
  property bool searching: false
  property string fileQuery: ""

  // ---- tabs: every tab, the order the Shell Manager's Launcher page sets, the hidden ones ----
  readonly property var allTabs: [
    { label: "Apps", value: "apps", icon: "grid" },
    { label: "Files", value: "files", icon: "folder" },
    { label: "Commands", value: "shell", icon: "search" },
    { label: "Power", value: "power", icon: "power" }
  ]
  readonly property var defaultOrder: allTabs.map(t => t.value)
  // the stored order, a tab added since missing at the end
  readonly property var orderAll: {
    const o = ModuleSettings.get("launcher", "order", defaultOrder);
    return o.concat(defaultOrder.filter(v => !o.includes(v)));
  }
  readonly property var hiddenTabs: ModuleSettings.get("launcher", "hidden", [])
  // the tabs shown, in order (at least one: the first)
  readonly property var tabs: {
    const shown = orderAll.filter(v => !hiddenTabs.includes(v)).map(v => allTabs.find(t => t.value === v)).filter(t => t);
    return shown.length > 0 ? shown : [allTabs[0]];
  }

  readonly property string home: Quickshell.env("HOME")

  function ipc(target, fn, arg) { return ShellIpc.command(target, fn, arg ? [arg] : []); }
  function exec(command) { Quickshell.execDetached(command); }


  // ---- apps ----
  // a Terminal=true entry (nvim, elio…) runs in kitty, the terminal Super + Q opens
  function runApp(e) {
    if (!e.runInTerminal) return e.execute();
    exec(["kitty", "-e"].concat(e.command.filter(a => !/^%[fFuUdDnNickvm]$/.test(a))));
  }

  // desktop files the shell already lists as its own apps (apps.json `desktop`): shown once
  readonly property var ownDesktopIds: ShellAppsService.entries.map(e => e.desktop).filter(d => d)

  function apps(q) {
    return filter(shellApps, q).concat(DesktopEntries.applications.values
      .filter(e => !e.noDisplay && !ownDesktopIds.includes(e.id)
                   && (q === "" || (e.name + " " + e.genericName + " " + (e.keywords ?? []).join(" ")).toLowerCase().includes(q)))
      .map(e => ({ image: Quickshell.iconPath(e.icon, true), icon: "app-window", title: e.name,
                   hint: e.comment || e.genericName, run: () => root.runApp(e) })))
      .sort((a, b) => a.title.localeCompare(b.title));
  }

  // ---- files ----
  function searchFiles(q) {
    fileQuery = q;
    filesProc.running = false;
    files = [];
    searching = false;
    if (q.length < 2) return;
    filesProc.command = ["fd", "--max-results", "60", "--ignore-case", "--hidden", "--fixed-strings", "--print0", "--exclude", ".git", "--exclude", ".cache", "--", q, home];
    searching = true;
    filesProc.running = true;
  }
  function fileItems() {
    return files.map(p => ({ icon: p.endsWith("/") ? "folder" : "file", title: p.replace(/\/$/, "").split("/").pop(),
                             hint: p.replace(home, "~"), run: () => root.exec(["xdg-open", p]) }));
  }

  Process {
    id: filesProc
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.fileQuery.length < 2) return;
        root.files = text.split("\u0000").filter(l => l !== "");
        root.searching = false;
      }
    }
  }

  // ---- the shell's own apps (apps/apps.json); keys from the live binds ----
  function keysOf(bind) { return KeybindsService.keysFor(bind).join(" + "); }
  readonly property var shellApps: ShellAppsService.entries.filter(e => ShellAppsService.installed(e) && e.listed !== false)
    .map(e => ({ icon: e.icon, title: e.label, hint: e.about, keys: keysOf(e.bind), run: () => ShellAppsService.run(e) }))

  // ---- the shell's own actions ----
  // the window modes come from WindowsService, as in its popup and page
  readonly property var shellItems: modeItems.concat([
    { icon: "sun", title: "Appearance", hint: "Theme, accent, wallpaper, font, cursor", run: () => exec(ipc("shell", "open", "appearance")) },
    { icon: "layout", title: "Bar", hint: "Monitors, layout, modules", run: () => exec(ipc("shell", "open", "bar")) },
    { icon: "app-window", title: "Windows", hint: "Window mode, gaps, taskbar", run: () => exec(ipc("shell", "open", "windows")) },
    { icon: "keyboard", title: "Keybinds", hint: "Every keybind, by tab", run: () => exec(ipc("keybinds", "open")) },
    { icon: "refresh", title: "Restart shell", hint: "Quickshell starts again", run: () => FontService.restartShell() }
  ])

  // a typed text also finds the shell's settings (SettingsIndex, as the Shell Manager's search):
  // a pick opens the Shell Manager at that place
  function shellSettings(q) {
    if (q === "") return [];
    SettingsIndex.load();
    const own = shellItems.map(i => i.title);
    return SettingsIndex.search(q).filter(e => !own.includes(e.label)).map(e => ({ icon: "sliders", title: e.label,
      hint: e.where !== "" ? e.where : "Settings", run: () => exec(ipc("shell", "open", e.target)) }));
  }

  // One searchable palette for shell actions, applications, bar modules,
  // settings and power. Dedicated tabs remain available for focused browsing.
  function commands(q) {
    const term = (q ?? "").trim().toLowerCase();
    const ownModules = ShellAppsService.entries.filter(e => e.module).map(e => e.module);
    const quickPower = root.powerItems.filter(i => i.title === "Lock" || i.title === "Suspend");
    const modules = BarLayout.modules.filter(m => BarLayout.installed(m.id) && !ownModules.includes(m.id)
      && (term === "" || (m.label + " " + m.about).toLowerCase().includes(term)))
      .map(m => ({ icon: m.icon, title: m.label, hint: m.about || "Bar module", run: () => BarLayout.openModule(m.id) }));
    const items = root.filter(root.shellItems, term)
      .concat(term === "" ? root.shellApps : root.apps(term), modules, root.shellSettings(term), root.filter(quickPower, term))
      .sort((a, b) => a.title.localeCompare(b.title));
    const seen = new Set();
    return items.filter(item => {
      const key = (item.title + "|" + (item.hint ?? "")).toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

  readonly property var modeItems: WindowsService.modes.map(m => ({ icon: m.icon, title: m.label, hint: "Window mode",
                                                                   run: () => WindowsService.setMode(m.value) }))

  // ---- power ----
  readonly property var powerItems: [
    { icon: "lock", title: "Lock", hint: "The lock screen", keys: keysOf("Lock the screen"), run: () => exec(ipc("lock", "lock")) },
    { icon: "moon", title: "Suspend", hint: "Sleep, locked", run: () => { ShellIpc.call("lock", "lock"); exec(["bash", "-c", "sleep 0.5; systemctl suspend"]); } },
    { icon: "log-out", title: "Log out", hint: "End the Hyprland session", run: () => Hypr.call("hl.dispatch(hl.dsp.exit())") },
    { icon: "refresh", title: "Reboot", hint: "Restart the computer", run: () => exec(["systemctl", "reboot"]) },
    { icon: "cpu", title: "Reboot to firmware", hint: "UEFI setup", run: () => exec(["systemctl", "reboot", "--firmware-setup"]) },
    { icon: "power", title: "Shut down", hint: "Power off", run: () => exec(["systemctl", "poweroff"]) }
  ]

  function filter(list, q) {
    return q === "" ? list : list.filter(i => (i.title + " " + i.hint).toLowerCase().includes(q));
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { root.open = !root.open; if (root.open) KeybindsService.refresh(); }
  }
}
