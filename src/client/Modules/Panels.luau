--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Modules > Panels
-- Tiny registry mapping panel names to toggle functions so the HUD's menu
-- can open any controller's window without controllers knowing each other.

local Panels = {}

local toggles: { [string]: () -> () } = {}

function Panels.register(name: string, toggle: () -> ())
	toggles[name] = toggle
end

function Panels.toggle(name: string)
	local handler = toggles[name]
	if handler then
		handler()
	end
end

return Panels
