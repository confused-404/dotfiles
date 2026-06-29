local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.default_domain = "WSL:Ubuntu"

config.font = wezterm.font("Hack Nerd Font Mono")
config.font_size = 11.0

config.color_scheme = "Catppuccin Mocha"

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "TITLE | RESIZE"

return config
