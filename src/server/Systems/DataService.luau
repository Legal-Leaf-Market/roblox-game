--!strict
-- ModuleScript: ServerScriptService > Server > Systems > DataService
-- Owns every player's persisted data: load on join, autosave, save on
-- leave and at server close, and every state push to clients. All other
-- systems mutate data through DataService.Get and then call one Push*.
--
-- DataStore access is wrapped in pcall with an in-memory fallback so
-- Studio (or an outage) degrades to a playable session that will not
-- save, and a profile that never loaded is NEVER written back (it would
-- clobber the real save with defaults). Serializable tables only.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Realms = require(Shared:WaitForChild("Realms"))

local STORE_NAME = "HeavenpillarData_v1"
local KEY_PREFIX = "u_"

local DataService = {}

type Profile = {
	data: Types.PlayerData,
	loaded: boolean,
	meditating: boolean,
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local loadedEvent = Instance.new("BindableEvent")

local statsChanged = Net.remoteEvent("StatsChanged")
local inventoryChanged = Net.remoteEvent("InventoryChanged")
local techniquesChanged = Net.remoteEvent("TechniquesChanged")
local socialChanged = Net.remoteEvent("SocialChanged")
local notify = Net.remoteEvent("Notify")

local function defaultData(): Types.PlayerData
	return {
		version = 1,
		stage = 1,
		cultivationXp = 0,
		qi = Realms.statsFor(1).maxQi,
		spiritStones = Config.STARTING_SPIRIT_STONES,
		items = { worn_sword = 1, breath_pill = 2 },
		manuals = {},
		equippedWeapon = "worn_sword",
		techniques = {},
		slots = {},
		sectId = nil,
		sectRank = nil,
		masterUserId = nil,
		masterName = nil,
		disciples = {},
		reputation = {},
		quests = {},
		settings = {},
	}
end

-- Fill keys missing from older saves so shape changes never nil-crash.
local function migrate(raw: any): Types.PlayerData
	local fresh = defaultData()
	if typeof(raw) ~= "table" then
		return fresh
	end
	for key, value in fresh :: any do
		if (raw :: any)[key] == nil then
			(raw :: any)[key] = value
		end
	end
	local data = raw :: Types.PlayerData
	data.stage = math.clamp(math.floor(data.stage), 1, Realms.STAGE_COUNT)
	for _, technique in data.techniques do
		if (technique :: any).masteryXp == nil then
			(technique :: any).masteryXp = 0
		end
	end
	return data
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

-- Runs callback for every player whose data is ready, now and later. How
-- systems subscribe without racing the async load.
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
	local stats = Realms.statsFor(data.stage)
	local cost = Realms.breakthroughCost(data.stage)
	statsChanged:FireClient(player, {
		stage = data.stage,
		realmName = Realms.displayName(data.stage),
		majorIndex = Realms.majorOf(data.stage),
		minorIndex = Realms.minorOf(data.stage),
		realmColor = Realms.major(data.stage).color,
		qi = data.qi,
		maxQi = stats.maxQi,
		cultivationXp = data.cultivationXp,
		breakthroughCost = cost,
		spiritStones = data.spiritStones,
		meditating = profile.meditating,
	})
end

function DataService.PushInventory(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	inventoryChanged:FireClient(player, {
		items = data.items,
		manuals = data.manuals,
		equippedWeapon = data.equippedWeapon,
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
		stage = data.stage,
	})
end

function DataService.PushSocial(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	socialChanged:FireClient(player, {
		masterUserId = data.masterUserId,
		masterName = data.masterName,
		disciples = data.disciples,
		sectId = data.sectId,
		sectRank = data.sectRank,
	})
end

function DataService.PushAll(player: Player)
	DataService.PushStats(player)
	DataService.PushInventory(player)
	DataService.PushTechniques(player)
	DataService.PushSocial(player)
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
