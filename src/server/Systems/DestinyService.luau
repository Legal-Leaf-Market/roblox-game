--!strict
-- ModuleScript: ServerScriptService > Server > Systems > DestinyService
-- Destiny spins: races and talents. All RNG is server-side (one Random
-- instance), spins are paid from free-spin balances first and spirit stones
-- second, and duplicates refund stones by rarity. The client only renders
-- the reveal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))
local Races = require(Shared:WaitForChild("Data"):WaitForChild("Races"))
local Talents = require(Shared:WaitForChild("Data"):WaitForChild("Talents"))

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)

local DestinyService = {}

local rng = Random.new()
local spinLimit = RateLimit.new(5, 2)
local spinResult = Net.remoteEvent("SpinResult")

local function fail(message: string): { [string]: any }
	return { ok = false, error = message }
end

-- Rarity buckets, precomputed once per pool.
local function bucket(order: { string }, rarityOf: (string) -> string): { [string]: { string } }
	local buckets: { [string]: { string } } = {}
	for _, id in order do
		local rarity = rarityOf(id)
		if buckets[rarity] == nil then
			buckets[rarity] = {}
		end
		table.insert(buckets[rarity], id)
	end
	return buckets
end

local raceBuckets = bucket(Races.order, function(id)
	local def = Races.get(id)
	return if def then def.rarity else "common"
end)

local talentBuckets = bucket(Talents.order, function(id)
	local def = Talents.get(id)
	return if def then def.rarity else "common"
end)

local function rollRarity(weights: { [string]: number }): string
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for rarity, weight in weights do
		roll -= weight
		if roll <= 0 then
			return rarity
		end
	end
	return "common"
end

local function rollFrom(buckets: { [string]: { string } }, weights: { [string]: number }): string
	local rarity = rollRarity(weights)
	local pool = buckets[rarity]
	if pool == nil or #pool == 0 then
		pool = buckets.common
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- ------------------------------- Spins ----------------------------------

type SpinKind = "race" | "talent"

local function spin(player: Player, kindName: SpinKind): { [string]: any }
	if not spinLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end

	local isRace = kindName == "race"
	local stonePrice = if isRace then Config.RACE_SPIN_STONES else Config.TALENT_SPIN_STONES
	local freeSpins = if isRace then data.raceSpins else data.talentSpins

	local usedFreeSpin = false
	if freeSpins > 0 then
		usedFreeSpin = true
		if isRace then
			data.raceSpins -= 1
		else
			data.talentSpins -= 1
		end
	elseif data.spiritStones >= stonePrice then
		data.spiritStones -= stonePrice
	else
		return fail(`No spins left, and a spin costs {stonePrice} spirit stones.`)
	end

	local rolledId: string
	local rarity: string
	local duplicate = false
	local refund = 0

	if isRace then
		rolledId = rollFrom(raceBuckets, Races.SPIN_WEIGHTS)
		local def = Races.get(rolledId)
		rarity = if def then def.rarity else "common"
		if data.ownedRaces[rolledId] then
			duplicate = true
			refund = (Races.DUPLICATE_REFUND :: { [string]: number })[rarity] or 0
			data.spiritStones += refund
			data.ownedRaces[rolledId] += 1
		else
			data.ownedRaces[rolledId] = 1
		end
	else
		rolledId = rollFrom(talentBuckets, Talents.SPIN_WEIGHTS)
		local def = Talents.get(rolledId)
		rarity = if def then def.rarity else "common"
		if data.ownedTalents[rolledId] then
			duplicate = true
			refund = (Talents.DUPLICATE_REFUND :: { [string]: number })[rarity] or 0
			data.spiritStones += refund
			data.ownedTalents[rolledId] += 1
		else
			data.ownedTalents[rolledId] = 1
		end
	end

	spinResult:FireClient(player, {
		kind = kindName,
		id = rolledId,
		rarity = rarity,
		duplicate = duplicate,
		refund = refund,
		usedFreeSpin = usedFreeSpin,
	})
	DataService.PushStats(player)
	DataService.PushDestiny(player)
	return { ok = true, id = rolledId, rarity = rarity, duplicate = duplicate, refund = refund }
end

-- ------------------------------- Equips ---------------------------------

local function equipRace(player: Player, payload: unknown): { [string]: any }
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local id = (payload :: { [string]: unknown }).id
	if typeof(id) ~= "string" or Races.get(id) == nil then
		return fail("Unknown race")
	end
	if data.ownedRaces[id] == nil then
		return fail("You have not awakened that bloodline.")
	end
	data.race = id
	CombatService.RefreshMods(player)
	DataService.PushStats(player)
	DataService.PushDestiny(player)
	return { ok = true }
end

local function equipTalent(player: Player, payload: unknown): { [string]: any }
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local ids = (payload :: { [string]: unknown }).ids
	if typeof(ids) ~= "table" then
		return fail("Bad request")
	end
	local list = ids :: { unknown }
	if #list > Config.TALENT_SLOTS then
		return fail(`At most {Config.TALENT_SLOTS} talents.`)
	end
	local cleaned: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, id in list do
		if typeof(id) ~= "string" or Talents.get(id) == nil then
			return fail("Unknown talent")
		end
		if data.ownedTalents[id] == nil then
			return fail("You have not awakened that talent.")
		end
		if seen[id] then
			return fail("Duplicate talent")
		end
		seen[id] = true
		table.insert(cleaned, id)
	end
	data.equippedTalents = cleaned
	CombatService.RefreshMods(player)
	DataService.PushStats(player)
	DataService.PushDestiny(player)
	return { ok = true }
end

-- ------------------------------ Lifecycle -------------------------------

function DestinyService.Init()
	Net.remoteFunction("SpinRace").OnServerInvoke = function(player)
		return spin(player, "race")
	end
	Net.remoteFunction("SpinTalent").OnServerInvoke = function(player)
		return spin(player, "talent")
	end
	Net.remoteFunction("EquipRace").OnServerInvoke = equipRace
	Net.remoteFunction("EquipTalent").OnServerInvoke = equipTalent

	Players.PlayerRemoving:Connect(function(player)
		spinLimit:Forget(player.UserId)
	end)
end

return DestinyService
