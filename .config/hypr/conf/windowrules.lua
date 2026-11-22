hl.window_rule({
	name = "suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Keep Kitty's transparency without blur and text fully opaque on focus changes.
hl.window_rule({
	name = "kitty-glass",
	match = { class = "^(kitty|kitty-.*)$" },
	no_blur = true,
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
	-- The solid panel needs no blur; leave the shadow's transparent canvas clear.
	blur = false,
	animation = "popin 96%",
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
