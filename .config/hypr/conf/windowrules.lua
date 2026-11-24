hl.window_rule({
	name = "suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Let Kitty control background opacity so its text stays opaque on focus changes.
hl.window_rule({
	name = "kitty-glass",
	match = { class = "^(kitty|kitty-.*)$" },
	no_shadow = true,
	opacity = "1.0 override 1.0 override 1.0 override",
})

hl.window_rule({
	name = "xwayland-drag-fix",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		fullscreen = false,
	},
	no_focus = true,
})

hl.layer_rule({
	name = "wofi-effects",
	match = { namespace = "wofi" },
	blur = true,
	ignore_alpha = 0.5,
	animation = "popin 98%",
})

hl.layer_rule({
	name = "waybar-blur",
	match = { namespace = "waybar" },
	blur = true,
	ignore_alpha = 0.5,
})

hl.layer_rule({
	name = "waybar-menu-blur",
	match = { namespace = "^(wifi-panel|bluetooth-panel|power-panel|swaync-control-center|swaync-notification-window)$" },
	blur = true,
	ignore_alpha = 0.5,
})

hl.window_rule({
	name = "utility-floating",
	match = { title = "^(Bluetooth Devices|Waypaper|Volume Control)$" },
	float = true,
	center = true,
})

-- SwayNC handles its own short entrance animation.
hl.layer_rule({
    name = "notification-animation",
    match = { namespace = "swaync-.*|wifi-panel|wifi-panel-backdrop|bluetooth-panel|bluetooth-panel-backdrop|power-panel|power-panel-backdrop" },
    no_anim = true,
})
