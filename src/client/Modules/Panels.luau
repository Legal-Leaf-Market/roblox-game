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

return Panels
