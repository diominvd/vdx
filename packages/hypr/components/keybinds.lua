-- Hyprland — keybinds
-- https://wiki.hypr.land/Configuring/Basics/Binds/
-- https://wiki.hypr.land/Configuring/Basics/Dispatchers/
--
-- Every bind carries a description "Group · What it does": hyprctl binds
-- shows it, and the Keybinds app (Super+B) lists them by tab.

local mainMod = "SUPER"

local function bind(group, keys, action, what, opts)
	opts = opts or {}
	opts.description = group .. " · " .. what
	return hl.bind(keys, action, opts)
end

-- apps
bind("Apps", mainMod .. " + Q", hl.dsp.exec_cmd("kitty"), "Terminal")
bind("Apps", mainMod .. " + E", hl.dsp.exec_cmd("qs -c shell ipc call files toggle"), "Files")
bind("Apps", "ALT + space", hl.dsp.exec_cmd("qs -c shell ipc call launcher toggle"), "Launcher")
bind("Apps", mainMod .. " + Z", hl.dsp.exec_cmd("qs -c shell ipc call lock lock"), "Lock the screen")
-- the shell's lock screen: if the shell dies while locked, started again it locks anew
hl.config({ misc = { allow_session_lock_restore = true } })
-- the lid: the shell does what Lock screen › Lid closed says (logind is held back by the shell)
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("qs -c shell ipc call lock lid"), { locked = true })

-- shell
bind("Shell", mainMod .. " + S", hl.dsp.exec_cmd("qs -c shell ipc call shell toggle"), "Shell Manager")
bind("Shell", mainMod .. " + B", hl.dsp.exec_cmd("qs -c shell ipc call keybinds toggle"), "Keybinds")
bind("Shell", "CTRL + SHIFT + Escape", hl.dsp.exec_cmd("qs -c shell ipc call taskmanager toggle"), "Task manager")
bind("Shell", mainMod .. " + X", hl.dsp.exec_cmd("qs -c shell ipc call cleaner toggle"), "Cleaner")
bind("Shell", mainMod .. " + T", hl.dsp.exec_cmd("qs -c shell ipc call themepicker toggle"), "Theme picker")
-- the overview (apps/overview): every workspace and its windows, laid out by the window mode;
-- Alt + Tab (the window switcher) is the floating mode's: modes/floating.lua
bind("Shell", mainMod .. " + TAB", hl.dsp.exec_cmd("qs -c shell ipc call overview toggle"), "Overview")

-- screenshots (both copy to the clipboard)
-- capture tool: freezes the screens, the toolbar picks region / window / screen,
-- shot or recording (again: cancel, or stop the recording)
bind("Capture", mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("qs -c shell ipc call capture open"), "Capture tool")

-- windows
bind("Windows", mainMod .. " + C", hl.dsp.window.close(), "Close")
bind("Windows", mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), "Float / tile")
bind("Windows", mainMod .. " + F", hl.dsp.window.fullscreen(), "Fullscreen")
bind("Windows", mainMod .. " + N", function() MinimizeWindow() end, "Minimize")

-- mouse
local mouseBinds = {
	bind("Windows", mainMod .. " + mouse:272", hl.dsp.window.drag(), "Drag", { mouse = true }),
	bind("Windows", mainMod .. " + mouse:273", hl.dsp.window.resize(), "Resize", { mouse = true }),
}

-- The overview (apps/overview) drags windows with the left button itself. The
-- binds above are the compositor's and would act on the windows under it, so they are off
-- while it is open (it switches them: MouseBinds(false), back on closing and at start).
function MouseBinds(on)
	for _, b in ipairs(mouseBinds) do b:set_enabled(on) end
end

-- Super + H / J / K / L and the wheel are the window mode's:
-- components/modes/<mode>.lua (focus, or placing a floating window)

-- move window
bind("Move", mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }), "Left")
bind("Move", mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }), "Right")
bind("Move", mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }), "Up")
bind("Move", mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }), "Down")

-- resize (repeating while held)
bind("Resize", mainMod .. " + comma", hl.dsp.window.resize({ x = -40, y = 0 }), "Narrower", { repeating = true })
bind("Resize", mainMod .. " + period", hl.dsp.window.resize({ x = 40, y = 0 }), "Wider", { repeating = true })
bind("Resize", mainMod .. " + SHIFT + comma", hl.dsp.window.resize({ x = 0, y = -40 }), "Shorter", { repeating = true })
bind("Resize", mainMod .. " + SHIFT + period", hl.dsp.window.resize({ x = 0, y = 40 }), "Taller", { repeating = true })

-- music / volume
bind("Media", mainMod .. " + ALT + P", hl.dsp.exec_cmd("mpc toggle"), "Play / pause")
bind("Media", mainMod .. " + ALT + left", hl.dsp.exec_cmd("mpc prev"), "Previous track")
bind("Media", mainMod .. " + ALT + right", hl.dsp.exec_cmd("mpc next"), "Next track")
bind("Media", mainMod .. " + ALT + up", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume up")
bind("Media", mainMod .. " + ALT + down", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Volume down")
-- the keyboard's own volume keys (XF86Audio*): work on the lock screen too
bind("Media", "XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume up", { repeating = true, locked = true })
bind("Media", "XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Volume down", { repeating = true, locked = true })
bind("Media", "XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Mute", { locked = true })

-- workspaces 1-10 (SUPER+0 = workspace 10)
for i = 1, 10 do
	local key = (i == 10) and "0" or tostring(i)
	bind("Workspaces", mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), "Go to " .. i)
	bind("Workspaces", mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), "Send window to " .. i)
end
