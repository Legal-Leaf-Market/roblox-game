--!strict
-- ModuleScript: ServerScriptService > Server > Systems > DataService
-- Owns every player's persisted data: load on join, autosave, save on leave
-- and on server close. Also owns the state pushes to clients, so every
-- mutation site calls one Push* function instead of hand-rolling payloads.
--
-- DataStore access is wrapped in pcall with an in-memory fallback so Studio
-- (or an API outage) degrades to a playable session that simply won't save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local StatCalc = require(Shared:WaitForChild("StatCalc"))
local Realms = require(Shared:WaitForChild("Data"):WaitForChild("Realms"))
local Races = require(Shared:WaitForChild("Data"):WaitForChild("Races"))

local STORE_NAME = "PlayerData_v1"
local KEY_PREFIX = "u_"

local DataService = {}

type Profile = {
	data: Types.PlayerData,
	loaded: boolean, -- false = fallback default (do NOT overwrite the store)
	meditating: boolean,
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local loadedEvent = Instance.new("BindableEvent")

local statsChanged = Net.remoteEvent("StatsChanged")
local inventoryChanged = Net.remoteEvent("InventoryChanged")
local techniquesChanged = Net.remoteEvent("TechniquesChanged")
local destinyChanged = Net.remoteEvent("DestinyChanged")
local notify = Net.remoteEvent("Notify")

local function defaultData(): Types.PlayerData
	return {
		version = 1,
		path = nil,
		realm = 1,
		cultivationXp = 0,
		qi = Realms[1].maxQi,
		spiritStones = 10,
		ores = {},
		items = { training_sword = 1 },
		equippedWeapon = "training_sword",
		equippedArmor = nil,
		techniques = {},
		slots = {},
		missionIndex = 1,
		missionAccepted = false,
		race = Races.DEFAULT_RACE,
		ownedRaces = { [Races.DEFAULT_RACE] = 1 },
		equippedTalents = {},
		ownedTalents = {},
		raceSpins = Config.STARTING_RACE_SPINS,
		talentSpins = Config.STARTING_TALENT_SPINS,
	}
end

-- Fill any keys missing from an older save so shape changes never nil-crash.
local function migrate(data: any): Types.PlayerData
	local fresh = defaultData()
	if typeof(data) ~= "table" then
		return fresh
	end
	for key, value in fresh :: any do
		if (data :: any)[key] == nil then
			(data :: any)[key] = value
		end
	end
	return data :: Types.PlayerData
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	end
	return store
end

local function load(player: Player): Profile
	local profile: Profile = { data = defaultData(), loaded = false, meditating = false }
	local dataStore = getStore()
	if dataStore then
		local ok, result = pcall(function()
			return dataStore:GetAsync(KEY_PREFIX .. player.UserId)
		end)
		if ok then
			profile.data = migrate(result)
			profile.loaded = true
		else
			warn(`[DataService] Load failed for {player.Name}: {result}`)
		end
	end
	return profile
end

local function save(player: Player, profile: Profile)
	-- A profile that never loaded must not clobber the real save with defaults.
	if not profile.loaded then
		return
	end
	local dataStore = getStore()
	if dataStore == nil then
		return
	end
	local data = profile.data
	local ok, err = pcall(function()
		dataStore:UpdateAsync(KEY_PREFIX .. player.UserId, function()
			return data
		end)
	end)
	if not ok then
		warn(`[DataService] Save failed for {player.Name}: {err}`)
	end
end

-- ------------------------------ Public API ------------------------------

function DataService.Get(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

-- Runs `callback` for every player whose data is ready, now and in the
-- future. The way systems like PathService and CombatService subscribe
-- without racing the async load.
function DataService.ObserveLoaded(callback: (Player) -> ()): RBXScriptConnection
	for player in profiles do
		task.spawn(callback, player)
	end
	return loadedEvent.Event:Connect(callback)
end

function DataService.IsMeditating(player: Player): boolean
	local profile = profiles[player]
	return if profile then profile.meditating else false
end

function DataService.SetMeditating(player: Player, meditating: boolean)
	local profile = profiles[player]
	if profile then
		profile.meditating = meditating
	end
end

function DataService.Notify(player: Player, text: string, color: Color3?)
	notify:FireClient(player, { text = text, color = color })
end

function DataService.PushStats(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	local data = profile.data
	local realm = Realms[data.realm] or Realms[1]
	local mods = StatCalc.combine(data.path, data.race, data.equippedTalents)
	statsChanged:FireClient(player, {
		qi = data.qi,
		maxQi = math.floor(realm.maxQi * mods.maxQiMult + 0.5),
		realm = data.realm,
		realmName = realm.name,
		cultivationXp = data.cultivationXp,
		breakthroughXp = realm.breakthroughXp,
		path = data.path,
		race = data.race,
		spiritStones = data.spiritStones,
		meditating = profile.meditating,
		equippedTalents = data.equippedTalents,
	})
end

function DataService.PushInventory(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	inventoryChanged:FireClient(player, {
		ores = data.ores,
		items = data.items,
		equippedWeapon = data.equippedWeapon,
		equippedArmor = data.equippedArmor,
		spiritStones = data.spiritStones,
	})
end

function DataService.PushTechniques(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	techniquesChanged:FireClient(player, {
		techniques = data.techniques,
		slots = data.slots,
	})
end

function DataService.PushDestiny(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	destinyChanged:FireClient(player, {
		race = data.race,
		ownedRaces = data.ownedRaces,
		equippedTalents = data.equippedTalents,
		ownedTalents = data.ownedTalents,
		raceSpins = data.raceSpins,
		talentSpins = data.talentSpins,
	})
end

function DataService.PushAll(player: Player)
	DataService.PushStats(player)
	DataService.PushInventory(player)
	DataService.PushTechniques(player)
	DataService.PushDestiny(player)
end

-- ------------------------------ Lifecycle -------------------------------

local function onPlayerAdded(player: Player)
	local profile = load(player)
	if player.Parent == nil then
		return -- left while loading
	end
	profiles[player] = profile
	DataService.PushAll(player)
	loadedEvent:Fire(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		save(player, profile)
	end
end

function DataService.Init()
	Net.initServer()

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		if profiles[player] == nil then
			task.spawn(onPlayerAdded, player)
		end
	end

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for player, profile in profiles do
			save(player, profile)
		end
	end)
end

function DataService.Start()
	while true do
		task.wait(Config.AUTOSAVE_SECONDS)
		for player, profile in profiles do
			task.spawn(save, player, profile)
		end
	end
end

return DataService
