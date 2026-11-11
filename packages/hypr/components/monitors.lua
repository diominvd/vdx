-- Hyprland — monitors and workspaces
-- https://wiki.hypr.land/Configuring/Basics/Monitors/
-- https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- this machine's outputs and workspace rules: machine/monitors.lua, from
-- .machine.toml; without it every output takes its preferred mode
if not require("components.machine").load("monitors") then
	hl.monitor({
		output = "",
		mode = "preferred",
		position = "auto",
		scale = "auto",
	})
end

-- Saved display choices override the profile on every config reload.
local saved = os.getenv("HOME") .. "/.local/state/dotfiles/display.lua"
local file = io.open(saved, "r")
if file then
	file:close()
	dofile(saved)
end
