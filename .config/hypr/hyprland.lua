local confDir = os.getenv("HOME") .. "/.config/hypr/conf"

------------------
-- MONITORS
------------------
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1.2,
})

------------------
-- AUTOSTART
------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("waybar")
	hl.exec_cmd("waypaper --restore")
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("systemctl --user start hyprland-session.target")
	hl.exec_cmd("swaync")
end)

------------------
-- ENVIRONMENT
------------------
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots/")
hl.env("QT_STYLE_OVERRIDE", "Adwaita-Dark")

------------------
-- SUB-CONFIGS
------------------
dofile(confDir .. "/input.lua")
dofile(confDir .. "/lookfeel.lua")
dofile(confDir .. "/keybinds.lua")
dofile(confDir .. "/windowrules.lua")
