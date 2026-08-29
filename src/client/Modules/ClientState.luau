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
	masterBonus: number,
}

export type Inventory = {
	ores: { [string]: number },
	items: { [string]: number },
	equippedWeapon: string?,
	equippedArmor: string?,
	spiritStones: number,
}

export type Techniques = {
	techniques: { { id: string, name: string, form: string, element: string, power: number, masteryXp: number, origin: string? } },
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

export type SectMember = { userId: number, name: string, rank: string, rankName: string, power: number, online: boolean }

export type Social = {
	sect: { id: string, name: string, myRank: string, myRankName: string, members: { SectMember } }?,
	masterName: string?,
	disciples: { { userId: number, name: string, online: boolean } },
	discipleCap: number,
	masterBonus: number,
}

local ClientState = {
	stats = nil :: Stats?,
	inventory = nil :: Inventory?,
	techniques = nil :: Techniques?,
	destiny = nil :: Destiny?,
	social = nil :: Social?,
}

local statsEvent = Instance.new("BindableEvent")
local inventoryEvent = Instance.new("BindableEvent")
local techniquesEvent = Instance.new("BindableEvent")
local destinyEvent = Instance.new("BindableEvent")
local socialEvent = Instance.new("BindableEvent")
local cooldownEvent = Instance.new("BindableEvent")
local staminaEvent = Instance.new("BindableEvent")

ClientState.StatsChanged = statsEvent.Event
ClientState.InventoryChanged = inventoryEvent.Event
ClientState.TechniquesChanged = techniquesEvent.Event
ClientState.DestinyChanged = destinyEvent.Event
ClientState.SocialChanged = socialEvent.Event
-- Fired by TechniqueController when a cast starts a local cooldown:
-- (slot: number, duration: number)
ClientState.CooldownStarted = cooldownEvent.Event

function ClientState.FireCooldown(slot: number, duration: number)
	cooldownEvent:Fire(slot, duration)
end

-- Stamina is simulated by MovementController (client-side sprint/dash fuel);
-- the HUD listens here. (current: number, max: number)
ClientState.StaminaChanged = staminaEvent.Event

function ClientState.FireStamina(current: number, max: number)
	staminaEvent:Fire(current, max)
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

Net.remoteEvent("SocialChanged").OnClientEvent:Connect(function(payload)
	ClientState.social = payload
	socialEvent:Fire(payload)
end)

return ClientState
