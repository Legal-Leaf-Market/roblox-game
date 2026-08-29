--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Modules > Panels
-- Tiny registry mapping panel names to toggle functions, so the HUD's
-- top-left icon menu can open any controller's window without the
-- controllers knowing about each other.

local Panels = {}

local toggles: { [string]: () -> () } = {}

function Panels.register(name: string, toggle: () -> ())
	toggles[name] = toggle
end

function Panels.toggle(name: string)
	local toggle = toggles[name]
	if toggle then
		toggle()
	end
end

-- The HUD registers a visibility setter so overlays (the main menu) can
-- hide the whole HUD while they own the screen.
local hudSetter: ((boolean) -> ())? = nil

function Panels.registerHud(setter: (boolean) -> ())
	hudSetter = setter
end

function Panels.setHudVisible(visible: boolean)
	if hudSetter then
		hudSetter(visible)
	end
end

return Panels
