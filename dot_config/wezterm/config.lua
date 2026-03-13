local wezterm = require 'wezterm'
local utils = require 'utils'
local keybinds = require 'keybinds'

local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.use_ime = true
config.adjust_window_size_when_changing_font_size = false

---------------------------------------------------------------
-- appearance
---------------------------------------------------------------
config.font = wezterm.font_with_fallback({
	'Cica',
	{ family = 'Symbols Nerd Font Mono', scale = 1 },
	{ family = 'Iosevka Term', weight = 'Regular' },
	'Fira Code',
})
config.font_size = 14.2
config.allow_square_glyphs_to_overflow_width = "Always"
config.color_scheme = 'iceberg-dark'
config.window_background_opacity = 0.94

config.window_padding = {
	left = 5,
	right = 5,
	top = 0,
	bottom = 0,
}

config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true

---------------------------------------------------------------
-- keybinds
---------------------------------------------------------------
config.disable_default_key_bindings = true
config.keys = keybinds.create({
	tmux = true
})

---------------------------------------------------------------
-- bells
---------------------------------------------------------------
config.visual_bell = {
	fade_in_function = "EaseIn",
	fade_in_duration_ms = 120,
	fade_out_function = "EaseOut",
	fade_out_duration_ms = 120,
	target = "CursorColor",
}

config.colors = {
	visual_bell = "#202020",
}

config.audible_bell = "Disabled"

---------------------------------------------------------------
--- local override
---------------------------------------------------------------
local ok, local_config = pcall(dofile, wezterm.config_dir .. '/local.lua')
if ok and local_config then
	utils.merge_config(config, local_config)
end

return config
