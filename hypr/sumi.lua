-- Sumi shell: its Hyprland settings, in one file.
--
-- hyprland.lua loads this right after hypr.looknfeel (install.sh adds the
-- require), so it overrides the look'n'feel defaults but Omarchy's toggles
-- load later and still win: the glassy bar/window toggles, for one, set their
-- own blur. Uninstalling removes the require and this file.

-- Windows wear the bar's hairline: the theme foreground (#f5f5f7) at 9%,
-- focused or not. It overrides the theme's border colours.
local hairline = "rgba(f5f5f717)"

hl.config({
	general = {
		col = {
			active_border = hairline,
			inactive_border = hairline,
		},
	},

	group = {
		col = {
			border_active = hairline,
			border_inactive = hairline,
		},
	},

	-- Frosted glass. Light settings keep it cheap on an integrated GPU; set
	-- enabled = false to turn every blur off.
	decoration = {
		blur = {
			enabled = true,
			size = 8,
			passes = 2,
			noise = 0.02,
			vibrancy = 0.1,
			new_optimizations = true,
		},
	},
})

-- Shell overlays Hyprland animates (clipboard, emojis, notifications, ...)
-- open in 160 ms and close in 120 ms, the same as the surfaces Sumi animates
-- itself (SumiTokens openMs / closeMs), on the same curve (SumiTokens easeOut).
hl.curve("sumiEaseOut", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.6, bezier = "sumiEaseOut", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.2, bezier = "sumiEaseOut", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.6, bezier = "sumiEaseOut" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.2, bezier = "sumiEaseOut" })

-- Omarchy's menus, launcher and dialogs in the interface font, matching the
-- bar. The terminal keeps the system monospace.
hl.env("OMARCHY_MENU_FONT", "Inter")

-- Blur behind the dock's see-through panel.
hl.layer_rule({
	match = { namespace = "^omarchy-dock$" },
	blur = true,
	ignore_alpha = 0.3,
})

-- Frosted glass behind the shell's own surfaces, as behind the bar and dock,
-- so their slight translucency reads as glass rather than see-through. The
-- Sumi surfaces stay mapped while closed (they open instantly that way) but
-- shrink to one pixel, so this rule costs nothing while they're hidden.
hl.layer_rule({
	match = {
		namespace = "^(omarchy-menu|omarchy-notifications|omarchy-osd|omarchy-polkit|omarchy-clipboard|omarchy-emojis|omarchy-reminders|omarchy-dock-apps|omarchy-image-selector|sumi-cc|sumi-control)$",
	},
	blur = true,
	ignore_alpha = 0.3,
})

-- The keybindings list through Sumi's faster copy of Omarchy's viewer.
hl.unbind("SUPER + K")
o.bind("SUPER + K", "Keybindings", os.getenv("HOME") .. "/.local/bin/sumi-keybindings")

-- Omarchy points these at the stock bar's panels, which the notch bar
-- replaces, so on their own they open nothing. Open the matching control
-- center section instead.
for _, panel in ipairs({
	{ keys = "SUPER + CTRL + A", name = "Audio", part = "sound" },
	{ keys = "SUPER + CTRL + B", name = "Bluetooth", part = "bluetooth" },
	{ keys = "SUPER + CTRL + D", name = "Display", part = "display" },
	{ keys = "SUPER + CTRL + W", name = "Network", part = "wifi" },
	{ keys = "SUPER + CTRL + P", name = "Power", part = "battery" },
	{ keys = "SUPER + CTRL + ALT + D", name = "Calendar", part = "clocks" },
	{ keys = "SUPER + CTRL + ALT + E", name = "World clock", part = "clocks" },
}) do
	hl.unbind(panel.keys)
	o.bind(panel.keys, panel.name, "omarchy-shell sumi.notch controlCenterAt " .. panel.part)
end
