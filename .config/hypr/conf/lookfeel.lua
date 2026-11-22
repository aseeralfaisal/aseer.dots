hl.config({
	general = {
		gaps_in = 3,
		gaps_out = 3,

		border_size = 1,

		col = {
			active_border = "rgba(5050cca6)",
			inactive_border = "rgba(59595999)",
		},

		resize_on_border = false,
		allow_tearing = false,

		layout = "dwindle",
	},

	decoration = {
		rounding = 8,
		active_opacity = 1,
		inactive_opacity = 0.88,

		blur = {
			enabled = true,
			size = 5,
			passes = 1,
			vibrancy = 0.2,
			new_optimizations = true,
			popups = true,
		},
	},

	dwindle = {
		preserve_split = true,
	},

	master = {
		new_status = "master",
	},

	misc = {
		font_family = "Inter",
		splash_font_family = "Inter",
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		middle_click_paste = true,
	},

	group = {
		groupbar = {
			font_family = "Inter",
		},
	},

	debug = {
		vfr = true,
	},

	binds = {
		workspace_center_on = 1,
	},

	-- Keep legacy XWayland clients at native resolution. Apps that need the
	-- desktop's 1.2x UI scale can request it themselves without bitmap blur.
	xwayland = {
		force_zero_scaling = true,
	},
})

-- Native wobble and acrylic blur require Hyprland 0.57+. Keep reloads safe
-- while an older compositor is still running after a package upgrade.
local major, minor = hl.version():match("(%d+)%.(%d+)")
if major and (tonumber(major) > 0 or tonumber(minor) >= 57) then
	hl.config({
		decoration = {
			-- Give opaque application backgrounds enough transparency for glass.
			-- active_opacity = 0.92,
			wobble = {
				enabled = true,
			},
			blur = {
				variant = "acrylic",
				acrylic = {
					aberration = 0.025,
					bulb = 48.0,
					clarity = 0.82,
					refraction = 24.0,
					tint = "rgba(eef5ff14)",
				},
			},
		},
	})
end

hl.config({
	animations = {
		enabled = true,
	},
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("smoothEase", { type = "bezier", points = { { 0.42, 0 }, { 0.2, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3.2, bezier = "smoothEase", style = "popin 96%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 0.7, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = false })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.6, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1, bezier = "almostLinear", style = "fade" })
