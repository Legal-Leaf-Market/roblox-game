--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Modules > ClientState
-- The client's cache of everything the server pushes, plus change signals.
-- Controllers read from here and re-render on the signals instead of each
-- binding its own remotes, so one server push updates every panel at once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

export type Stats = {
	qi: number,
	maxQi: number,
	realm: number,
	realmName: string,
	cultivationXp: number,
	breakthroughXp: number,
	path: string?,
	race: string,
	spiritStones: number,
	meditating: boolean,
	equippedTalents: { string },
}

export type Inventory = {
	ores: { [string]: number },
	items: { [string]: number },
	equippedWeapon: string?,
	equippedArmor: string?,
	spiritStones: number,
}

export type Techniques = {
	techniques: { { id: string, name: string, form: string, element: string, power: number } },
	slots: { [string]: string },
}

export type Destiny = {
	race: string,
	ownedRaces: { [string]: number },
	equippedTalents: { string },
	ownedTalents: { [string]: number },
	raceSpins: number,
	talentSpins: number,
}

local ClientState = {
	stats = nil :: Stats?,
	inventory = nil :: Inventory?,
	techniques = nil :: Techniques?,
	destiny = nil :: Destiny?,
}

local statsEvent = Instance.new("BindableEvent")
local inventoryEvent = Instance.new("BindableEvent")
local techniquesEvent = Instance.new("BindableEvent")
local destinyEvent = Instance.new("BindableEvent")
local cooldownEvent = Instance.new("BindableEvent")

ClientState.StatsChanged = statsEvent.Event
ClientState.InventoryChanged = inventoryEvent.Event
ClientState.TechniquesChanged = techniquesEvent.Event
ClientState.DestinyChanged = destinyEvent.Event
-- Fired by TechniqueController when a cast starts a local cooldown:
-- (slot: number, duration: number)
ClientState.CooldownStarted = cooldownEvent.Event

function ClientState.FireCooldown(slot: number, duration: number)
	cooldownEvent:Fire(slot, duration)
end

Net.remoteEvent("StatsChanged").OnClientEvent:Connect(function(payload)
	ClientState.stats = payload
	statsEvent:Fire(payload)
end)

Net.remoteEvent("InventoryChanged").OnClientEvent:Connect(function(payload)
	ClientState.inventory = payload
	inventoryEvent:Fire(payload)
end)

Net.remoteEvent("TechniquesChanged").OnClientEvent:Connect(function(payload)
	ClientState.techniques = payload
	techniquesEvent:Fire(payload)
end)

Net.remoteEvent("DestinyChanged").OnClientEvent:Connect(function(payload)
	ClientState.destiny = payload
	destinyEvent:Fire(payload)
end)

return ClientState
