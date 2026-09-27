local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.font = wezterm.font("Hack Nerd Font Mono")
config.font_size = 11.0

config.color_scheme = "Catppuccin Mocha"

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "TITLE | RESIZE"

config.keys = {
  {
    key = "l",
    mods = "CTRL|SHIFT",
    action = act.ShowLauncherArgs({
      flags = "FUZZY|DOMAINS",
      title = "Choose Ubuntu version",
    }),
  },
}

return config
