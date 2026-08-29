--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Modules > ClientState
-- Client-side cache of everything the server pushes, plus signals the UI
-- subscribes to. Controllers read state here instead of each wiring its
-- own remote listeners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = {}

ClientState.stats = nil :: { [string]: any }?
ClientState.inventory = nil :: { [string]: any }?
ClientState.techniques = nil :: { [string]: any }?
ClientState.social = nil :: { [string]: any }?

local statsEvent = Instance.new("BindableEvent")
local inventoryEvent = Instance.new("BindableEvent")
local techniquesEvent = Instance.new("BindableEvent")
local socialEvent = Instance.new("BindableEvent")
local staminaEvent = Instance.new("BindableEvent")
local cooldownEvent = Instance.new("BindableEvent")

ClientState.StatsChanged = statsEvent.Event
ClientState.InventoryChanged = inventoryEvent.Event
ClientState.TechniquesChanged = techniquesEvent.Event
ClientState.SocialChanged = socialEvent.Event
ClientState.StaminaChanged = staminaEvent.Event
ClientState.CooldownStarted = cooldownEvent.Event

function ClientState.FireStamina(current: number, max: number)
	staminaEvent:Fire(current, max)
end

function ClientState.FireCooldown(slot: number, duration: number)
	cooldownEvent:Fire(slot, duration)
end

function ClientState.Init()
	Net.remoteEvent("StatsChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			ClientState.stats = payload
			statsEvent:Fire()
		end
	end)
	Net.remoteEvent("InventoryChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			ClientState.inventory = payload
			inventoryEvent:Fire()
		end
	end)
	Net.remoteEvent("TechniquesChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			ClientState.techniques = payload
			techniquesEvent:Fire()
		end
	end)
	Net.remoteEvent("SocialChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			ClientState.social = payload
			socialEvent:Fire()
		end
	end)
end

return ClientState
