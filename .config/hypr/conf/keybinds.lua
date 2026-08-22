local mainMod = "SUPER"

local terminal = "kitty"
local fileManager = "nautilus"
local browser = "brave-origin"
local menu = os.getenv("HOME") .. "/.config/wofi/launcher"
local powermenu = os.getenv("HOME") .. "/.config/wofi/powermenu.sh"
local screenshotScript = os.getenv("HOME") .. "/.config/hypr/scripts/hyprshot-gradia"

local function takeScreenshot(mode)
	local command = "sh -c 'pgrep -x hyprshot >/dev/null || exec " .. screenshotScript .. " " .. mode .. "'"
	return hl.dsp.exec_cmd(command)
end

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(powermenu))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind("PRINT", takeScreenshot("region"))
hl.bind(mainMod .. " + PRINT", takeScreenshot("output"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + R", takeScreenshot("output"))
hl.bind(mainMod .. " + S", takeScreenshot("region"))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + SHIFT + CTRL + right", hl.dsp.window.resize({ x = 10, y = 0 }))
hl.bind(mainMod .. " + SHIFT + CTRL + left", hl.dsp.window.resize({ x = -10, y = 0 }))
hl.bind(mainMod .. " + SHIFT + CTRL + up", hl.dsp.window.resize({ x = 0, y = -10 }))
hl.bind(mainMod .. " + SHIFT + CTRL + down", hl.dsp.window.resize({ x = 0, y = 10 }))

hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.swap({ direction = "down" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
