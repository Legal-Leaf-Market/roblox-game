--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Modules > ClientSettings
-- Player-local settings, owned by the menu's Settings panel and read by the
-- controllers (VFX rendering, hint labels). Purely cosmetic and client-side;
-- nothing here touches the server.

local settings = {
	vfxEnabled = true,
	showHints = true,
	othersVfx = true, -- render other players' technique effects
}

local changedEvent = Instance.new("BindableEvent")

local ClientSettings = {}

ClientSettings.Changed = changedEvent.Event

function ClientSettings.get(key: string): boolean
	return (settings :: { [string]: boolean })[key] == true
end

function ClientSettings.set(key: string, value: boolean)
	local map = settings :: { [string]: boolean }
	if map[key] == nil or map[key] == value then
		return
	end
	map[key] = value
	changedEvent:Fire(key, value)
end

return ClientSettings
