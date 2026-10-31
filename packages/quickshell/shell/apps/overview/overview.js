// Geometry is in monitor-local logical pixels. No compositor calls while hovering.
function rows(windows, activeWorkspace) {
    const ids = windows.map(window => window.workspace).concat([activeWorkspace]).filter(id => id > 0 && id <= 10);
    const first = Math.min.apply(null, ids), last = Math.max.apply(null, ids);
    const result = [];
    const firstHasWindows = windows.some(window => window.workspace === first);
    const lastHasWindows = windows.some(window => window.workspace === last);
    for (let id = Math.max(1, first - (firstHasWindows ? 1 : 0));
         id <= Math.min(10, last + (lastHasWindows ? 1 : 0)); id++) result.push(id);
    return result;
}

function members(windows, workspace, excludedAddress) {
    return windows.filter(window => window.workspace === workspace && window.address !== excludedAddress);
}

function bounds(windows, mw, mh) {
    if (!windows.length) return { x: 0, y: 0, width: mw, height: mh };
    const x = Math.min.apply(null, windows.map(w => w.x));
    const y = Math.min.apply(null, windows.map(w => w.y));
    return { x: x, y: y,
        width: Math.max.apply(null, windows.map(w => w.x + w.width)) - x,
        height: Math.max.apply(null, windows.map(w => w.y + w.height)) - y };
}

function appendSlot(windows, workspace, carried, mw, mh, gap) {
    const tiled = members(windows, workspace, carried.address).filter(w => !w.floating);
    if (!tiled.length || workspace === carried.workspace || carried.floating) return null;
    const b = bounds(tiled, mw, mh);
    const anchor = tiled.reduce((a, w) => w.x + w.width > a.x + a.width ? w : a);
    return { kind: "append", workspace: workspace, anchor: anchor.address,
        x: b.x + b.width + gap, y: b.y, width: carried.width, height: carried.height };
}

function contains(rect, x, y) {
    return rect && x >= rect.x && x <= rect.x + rect.width && y >= rect.y && y <= rect.y + rect.height;
}

function intent(windows, ids, carried, point, mw, mh, pitch, gap, scrolling, masterRatio, newMaster) {
    if (!carried) return null;
    const index = Math.floor(point.y / pitch), workspace = ids[index];
    const y = point.y - index * pitch;
    if (!workspace || workspace === carried.workspace || y < 0 || y > mh) return null;
    const slot = scrolling ? appendSlot(windows, workspace, carried, mw, mh, gap) : null;
    if (contains(slot, point.x, y)) return slot;
    const existing = members(windows, workspace, carried.address);
    const tiled = existing.filter(w => !w.floating);
    const b = bounds(existing, mw, mh);
    if (point.x < Math.min(0, b.x) || point.x > Math.max(mw, b.x + b.width)) return null;
    const anchor = tiled.length ? tiled.reduce((a, w) => w.x + w.width > a.x + a.width ? w : a) : null;
    const result = { kind: "join", workspace: workspace, anchor: anchor ? anchor.address : "",
        x: carried.x, y: carried.y, width: carried.width, height: carried.height };
    // Predict only a simple pair; more complex layouts use their actual result.
    if (tiled.length === 1 && !carried.floating) {
        const w = tiled[0], ratio = scrolling ? 0.5 : masterRatio;
        const left = Math.max(1, (w.width - gap) * ratio);
        const right = Math.max(1, w.width - gap - left);
        result.existing = { address: w.address, x: w.x, y: w.y,
            width: newMaster && !scrolling ? right : left, height: w.height };
        if (newMaster && !scrolling) {
            result.x = w.x; result.width = left;
            result.existing.x = w.x + left + gap;
        } else {
            result.x = w.x + left + gap; result.width = right;
        }
        result.y = w.y; result.height = w.height;
    }
    return result;
}

function rectMap(windows) {
    const map = {};
    for (const w of windows) map[w.address] = w;
    return map;
}

function geometryKey(windows) {
    return windows.map(w => [w.address, w.workspace, w.x, w.y, w.width, w.height].join(":")).sort().join("|");
}

function luaString(value) {
    return '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n").replace(/\r/g, "\\r") + '"';
}

function windowSelector(address) {
    return luaString("address:" + (address.startsWith("0x") ? address : "0x" + address));
}

function uniqueColumns(windows) {
    const columns = [];
    for (const window of windows) {
        if (!columns.some(column => Math.abs(column.x - window.x) < 2)) columns.push(window);
    }
    return columns;
}

function appendColumnResizes(commands, windows) {
    for (const window of uniqueColumns(windows)) {
        commands.push("resize(" + windowSelector(window.address) + ", " + Math.round(window.width) + ")");
    }
}

function luaFocusResizeHelpers() {
    return "local function focus(s)\n"
        + "  local wanted = hl.get_window(s); if not wanted then error('Overview: target window closed') end\n"
        + "  hl.dispatch(hl.dsp.focus({ window = s }))\n"
        + "  local active = hl.get_active_window()\n"
        + "  if not active or active.address ~= wanted.address then error('Overview: compositor refused window focus') end\n"
        + "end\n"
        + "local function resize(s, width)\n"
        + "  local w = hl.get_window(s); if not w then return end; focus(s)\n"
        + "  local m = w.monitor; local r = m.reserved or {}; local out = hl.get_config('general.gaps_out')\n"
        + "  local left = type(out) == 'table' and (out.left or 0) or tonumber(out) or 0\n"
        + "  local right = type(out) == 'table' and (out.right or 0) or tonumber(out) or 0\n"
        + "  local inner = hl.get_config('general.gaps_in'); local border = tonumber(hl.get_config('general.border_size')) or 0\n"
        + "  local il = type(inner) == 'table' and (inner.left or 0) or tonumber(inner) or 0\n"
        + "  local ir = type(inner) == 'table' and (inner.right or 0) or tonumber(inner) or 0\n"
        + "  local usable = m.width / (m.scale or 1) - (r[1] or r.left or 0) - (r[3] or r.right or 0) - left - right\n"
        + "  hl.dispatch(hl.dsp.layout('colresize ' .. math.max(0.05, math.min(1, (width + il + ir + 2 * border) / usable))))\n"
        + "end\n";
}

function luaRestoreFocusAndCursor() {
    return "local restored, restoreErr = pcall(function()\n"
        + "  if ws then hl.dispatch(hl.dsp.focus({ workspace = ws.id })) end\n"
        + "  if old and old.workspace and ws and old.workspace.id == ws.id and hl.get_window('address:' .. old.address) then focus('address:' .. old.address) end\n"
        + "end)\n"
        + "hl.config({ cursor = { no_warps = noWarps == true } })\n"
        + "if not ok then error(err) end\n"
        + "if not restored then error(restoreErr) end";
}

// One compositor transaction: insert after the intended column, apply the width
// policy, and restore the workspace, focus and cursor policy even on failure.
function moveCommand(carried, drop, windows, scrolling) {
    const target = windowSelector(carried.address);
    const commands = [];
    const tiled = members(windows, drop.workspace, carried.address).filter(w => !w.floating);
    if (scrolling && !carried.floating && drop.kind === "append") {
        // Pin a lone column's displayed width BEFORE a second column is
        // inserted: fullscreen_on_one_column can hide its latent half-width.
        appendColumnResizes(commands, tiled);
    }
    if (scrolling && !carried.floating && drop.anchor) commands.push("focus(" + windowSelector(drop.anchor) + ")");
    commands.push("hl.dispatch(hl.dsp.window.move({ workspace = " + drop.workspace + ", window = target, follow = false }))");
    if (scrolling && !carried.floating) {
        if (drop.kind === "append") {
            // A lone column may have a latent half-width despite being displayed
            // full-width. Pin the displayed widths after adding the new column.
            appendColumnResizes(commands, tiled);
            commands.push("resize(target, " + Math.round(carried.width) + ")");
        } else if (tiled.length === 1) {
            commands.push("focus(" + windowSelector(tiled[0].address) + "); hl.dispatch(hl.dsp.layout('colresize 0.5'))");
            commands.push("focus(target); hl.dispatch(hl.dsp.layout('colresize 0.5'))");
        }
        if (drop.anchor) {
            commands.push("focus(" + windowSelector(drop.anchor) + ")");
            commands.push("local a = hl.get_window(" + windowSelector(drop.anchor) + ")");
            const anchor = tiled.find(w => w.address === drop.anchor);
            if (anchor) commands.push("if a then local at = a.at; local by = " + Math.round(anchor.x)
                + " + a.monitor.x - (at.x or at[1]); if math.abs(by) > 1 then hl.dispatch(hl.dsp.layout('move ' .. (by >= 0 and '+' or '') .. math.floor(by))) end end");
        }
    }
    return "local target = " + target + "\n"
        + "local moving = hl.get_window(target); if not moving then error('Overview: window closed') end\n"
        + "local old = hl.get_active_window(); local mon = hl.get_active_monitor(); local ws = mon and mon.active_workspace\n"
        + "local noWarps = hl.get_config('cursor.no_warps')\n"
        + luaFocusResizeHelpers()
        + "hl.config({ cursor = { no_warps = true } })\n"
        + "local ok, err = xpcall(function()\n" + commands.join("\n") + "\nend, debug.traceback)\n"
        + luaRestoreFocusAndCursor();
}
