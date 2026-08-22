hl.window_rule({
	name = "suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
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
	name = "waybar-effects",
	match = { namespace = "waybar" },
	blur = true,
	ignore_alpha = 0.5,
})

hl.layer_rule({
	name = "wofi-effects",
	match = { namespace = "wofi" },
	blur = true,
	ignore_alpha = 0.5,
	animation = "fade",
})

hl.window_rule({
	name = "utility-floating",
	match = { title = "^(Bluetooth Devices|Waypaper|Volume Control)$" },
	float = true,
	center = true,
})
