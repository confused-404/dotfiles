local wezterm = require("wezterm")

local config = wezterm.config_builder()

local is_windows = os.getenv("OS") and os.getenv("OS"):lower():find("windows") ~= nil
local is_macos = wezterm.target_triple:lower():find("darwin") ~= nil

-- ui
config.color_scheme = "rose-pine-moon"
config.max_fps = 120
config.font = wezterm.font("Hack Nerd Font", { weight = "Regular" })

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.window_frame = {
    font = wezterm.font("Hack Nerd Font", { weight = "Bold" }),
}

config.inactive_pane_hsb = {
    saturation = 0.0,
    brightness = 0.5,
}

if is_windows then
    config.win32_system_backdrop = "Acrylic"
    config.window_background_opacity = 0.7
    config.window_frame.font_size = 10.0
end

if is_macos then
    config.window_background_opacity = 0.8
    config.macos_window_background_blur = 50
    config.font_size = 15.0
    config.window_frame.font_size = 13.0
end

-- shell
if is_windows then
    config.default_domain = "WSL:Ubuntu"
end

-- keys
local act = wezterm.action

local maximize_window = wezterm.action_callback(function(window, _pane)
    window:maximize()
end)

config.disable_default_key_bindings = true
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
    -- config reload / utility
    { key = "r", mods = "LEADER", action = act.ReloadConfiguration },
    { key = "m", mods = "LEADER", action = maximize_window },

    -- tabs
    { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
    { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
    { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },

    -- panes
    { key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

    -- vim-style pane movement
    { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
    { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
    { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

    -- copy/paste
    { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
    { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
}

return config
