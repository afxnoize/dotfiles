local wezterm = require 'wezterm'
local utils = require 'utils'

local M = {}

local default_keybinds = {
  { key = "c", mods = "CTRL|SHIFT", action = wezterm.action({ CopyTo = "Clipboard" }) },
  { key = "v", mods = "CTRL|SHIFT", action = wezterm.action({ PasteFrom = "Clipboard" }) },
  { key = "Insert", mods = "SHIFT", action = wezterm.action({ PasteFrom = "PrimarySelection" }) },
  { key = "=", mods = "CTRL", action = "ResetFontSize" },
  { key = "+", mods = "CTRL", action = "IncreaseFontSize" },
  { key = "-", mods = "CTRL", action = "DecreaseFontSize" },
  { key = " ", mods = "CTRL|SHIFT", action = "QuickSelect" },
  { key = "x", mods = "CTRL|SHIFT", action = "ActivateCopyMode" },
  { key = "PageUp", mods = "ALT", action = wezterm.action({ ScrollByPage = -1 }) },
  { key = "PageDown", mods = "ALT", action = wezterm.action({ ScrollByPage = 1 }) },
  { key = "r", mods = "ALT", action = "ReloadConfiguration" },
  { key = "r", mods = "ALT|SHIFT", action = wezterm.action({ EmitEvent = "toggle-tmux-keybinds" }) },
  { key = "e", mods = "ALT", action = wezterm.action({ EmitEvent = "trigger-nvim-with-scrollback" }) },
  { key = "x", mods = "ALT", action = wezterm.action({ CloseCurrentPane = { confirm = false } }) },
}

local tmux_keybinds = {
  -- { key = "k", mods = "ALT", action = wezterm.action({ SpawnTab = "CurrentPaneDomain" }) },
  { key = "k", mods = "ALT", action = wezterm.action.ShowLauncher },
  { key = "j", mods = "ALT", action = wezterm.action({ CloseCurrentTab = { confirm = false } }) },
  { key = "h", mods = "ALT", action = wezterm.action({ ActivateTabRelative = -1 }) },
  { key = "l", mods = "ALT", action = wezterm.action({ ActivateTabRelative = 1 }) },
  { key = "h", mods = "ALT|CTRL", action = wezterm.action({ MoveTabRelative = -1 }) },
  { key = "l", mods = "ALT|CTRL", action = wezterm.action({ MoveTabRelative = 1 }) },
  { key = "k", mods = "ALT|CTRL", action = "ActivateCopyMode" },
  { key = "j", mods = "ALT|CTRL", action = wezterm.action({ PasteFrom = "PrimarySelection" }) },
  { key = "1", mods = "ALT", action = wezterm.action({ ActivateTab = 0 }) },
  { key = "2", mods = "ALT", action = wezterm.action({ ActivateTab = 1 }) },
  { key = "3", mods = "ALT", action = wezterm.action({ ActivateTab = 2 }) },
  { key = "4", mods = "ALT", action = wezterm.action({ ActivateTab = 3 }) },
  { key = "5", mods = "ALT", action = wezterm.action({ ActivateTab = 4 }) },
  { key = "6", mods = "ALT", action = wezterm.action({ ActivateTab = 5 }) },
  { key = "7", mods = "ALT", action = wezterm.action({ ActivateTab = 6 }) },
  { key = "8", mods = "ALT", action = wezterm.action({ ActivateTab = 7 }) },
  { key = "9", mods = "ALT", action = wezterm.action({ ActivateTab = 8 }) },
  { key = "-", mods = "ALT", action = wezterm.action({ SplitVertical = { domain = "CurrentPaneDomain" } }) },
  { key = "=", mods = "ALT", action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }) },
  { key = "h", mods = "ALT|SHIFT", action = wezterm.action({ ActivatePaneDirection = "Left" }) },
  { key = "l", mods = "ALT|SHIFT", action = wezterm.action({ ActivatePaneDirection = "Right" }) },
  { key = "k", mods = "ALT|SHIFT", action = wezterm.action({ ActivatePaneDirection = "Up" }) },
  { key = "j", mods = "ALT|SHIFT", action = wezterm.action({ ActivatePaneDirection = "Down" }) },
  { key = "h", mods = "ALT|SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Left", 1 } }) },
  { key = "l", mods = "ALT|SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Right", 1 } }) },
  { key = "k", mods = "ALT|SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Up", 1 } }) },
  { key = "j", mods = "ALT|SHIFT|CTRL", action = wezterm.action({ AdjustPaneSize = { "Down", 1 } }) },
  { key = "c", mods = "ALT", action = "QuickSelect" },
}

function M.create(opts)
	local keys = default_keybinds

	if opts.tmux then
		keys = utils.merge_lists(keys, tmux_keybinds)
	end
	return keys
end

return M
