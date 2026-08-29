--!strict
-- ModuleScript: ServerScriptService > Server > Systems > ForgeService
-- The Deepforge: Grandmaster Khadun's mining missions and the crafting of
-- weapons and robes from ore. The dwarf and the forge are world objects
-- tagged by WorldBuilder ("DwarfPrompt" / "ForgePrompt"); everything they
-- can do to a player's data happens here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))
local Types = require(Shared:WaitForChild("Types"))
local Items = require(Shared:WaitForChild("Data"):WaitForChild("Items"))
local Ores = require(Shared:WaitForChild("Data"):WaitForChild("Ores"))
local Missions = require(Shared:WaitForChild("Data"):WaitForChild("Missions"))
local Realms = require(Shared:WaitForChild("Data"):WaitForChild("Realms"))

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)

local DWARF_NAME = "Grandmaster Khadun"
local MAX_FORGE_DISTANCE = 35

local ForgeService = {}

local actionLimit = RateLimit.new(8, 4)
local forgePositions: { Vector3 } = {}

local function fail(message: string): { [string]: any }
	return { ok = false, error = message }
end

local function currentMission(data: Types.PlayerData)
	local index = math.clamp(data.missionIndex, 1, #Missions)
	return Missions[index], index
end

local function hasOres(data: Types.PlayerData, needs: { [string]: number }): boolean
	for oreId, count in needs do
		if (data.ores[oreId] or 0) < count then
			return false
		end
	end
	return true
end

local function nearForge(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	for _, position in forgePositions do
		if (root.Position - position).Magnitude <= MAX_FORGE_DISTANCE then
			return true
		end
	end
	return false
end

-- ------------------------------ Dialogue --------------------------------

local function sendDialogue(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local mission, index = currentMission(data)
	local needsText = {}
	for oreId, count in mission.needs do
		local ore = Ores.get(oreId)
		table.insert(needsText, `{count}x {if ore then ore.name else oreId}`)
	end

	local canTurnIn = data.missionAccepted and hasOres(data, mission.needs)
	local text: string
	if not data.missionAccepted then
		text = mission.intro
	elseif canTurnIn then
		text = "That gleam in your pack better be my ore. Hand it over."
	else
		text = `Still short. I need {table.concat(needsText, ", ")}. The veins are down in the halls, not up here in the chatting air.`
	end

	Net.remoteEvent("DwarfDialogue"):FireClient(player, {
		npcName = DWARF_NAME,
		missionTitle = mission.title,
		missionNumber = index,
		text = text,
		needs = mission.needs,
		rewardStones = mission.rewardStones,
		rewardRaceSpins = mission.rewardRaceSpins,
		rewardTalentSpins = mission.rewardTalentSpins,
		canAccept = not data.missionAccepted,
		canTurnIn = canTurnIn,
	})
end

local function missionAction(player: Player, payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local action = (payload :: { [string]: unknown }).action
	local mission = (currentMission(data))

	if action == "accept" then
		if data.missionAccepted then
			return fail("Already on a commission.")
		end
		data.missionAccepted = true
		DataService.Notify(player, `Commission accepted: {mission.title}`)
		sendDialogue(player)
		return { ok = true }
	elseif action == "turnin" then
		if not data.missionAccepted then
			return fail("Accept the commission first.")
		end
		if not hasOres(data, mission.needs) then
			return fail("You are short on ore.")
		end
		for oreId, count in mission.needs do
			data.ores[oreId] = (data.ores[oreId] or 0) - count
			if data.ores[oreId] <= 0 then
				data.ores[oreId] = nil
			end
		end
		data.spiritStones += mission.rewardStones
		data.raceSpins += mission.rewardRaceSpins
		data.talentSpins += mission.rewardTalentSpins
		data.missionAccepted = false
		if data.missionIndex < #Missions then
			data.missionIndex += 1
		end

		DataService.Notify(player, mission.turnIn)
		local rewards = `+{mission.rewardStones} spirit stones`
		if mission.rewardRaceSpins > 0 then
			rewards ..= `, +{mission.rewardRaceSpins} race spins`
		end
		if mission.rewardTalentSpins > 0 then
			rewards ..= `, +{mission.rewardTalentSpins} talent spins`
		end
		DataService.Notify(player, rewards, Color3.fromRGB(255, 215, 120))

		DataService.PushStats(player)
		DataService.PushInventory(player)
		DataService.PushDestiny(player)
		sendDialogue(player)
		return { ok = true }
	end
	return fail("Bad request")
end

-- ------------------------------ Crafting --------------------------------

local function craftItem(player: Player, payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local id = (payload :: { [string]: unknown }).id
	if typeof(id) ~= "string" then
		return fail("Bad request")
	end
	local item = Items.get(id)
	if item == nil or item.recipe == nil then
		return fail("The forge does not know that work.")
	end
	if not nearForge(player) then
		return fail("You must be at the Spirit Forge.")
	end
	local recipe = item.recipe :: Items.Recipe
	if data.spiritStones < recipe.spiritStones then
		return fail(`Needs {recipe.spiritStones} spirit stones.`)
	end
	if not hasOres(data, recipe.ores) then
		return fail("You are short on ore.")
	end

	data.spiritStones -= recipe.spiritStones
	for oreId, count in recipe.ores do
		data.ores[oreId] = (data.ores[oreId] or 0) - count
		if data.ores[oreId] <= 0 then
			data.ores[oreId] = nil
		end
	end
	data.items[id] = (data.items[id] or 0) + 1

	DataService.Notify(player, `Forged: {item.name}`, Color3.fromRGB(255, 180, 90))
	DataService.PushStats(player)
	DataService.PushInventory(player)
	return { ok = true }
end

local function equipItem(player: Player, payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local request = payload :: { [string]: unknown }
	local slot = request.slot
	local id = request.id
	if slot ~= "weapon" and slot ~= "armor" then
		return fail("Bad request")
	end
	if id ~= nil then
		if typeof(id) ~= "string" then
			return fail("Bad request")
		end
		local item = Items.get(id)
		if item == nil then
			return fail("Unknown item")
		end
		if (data.items[id] or 0) < 1 then
			return fail("You do not own that.")
		end
		local expectedKind = if slot == "weapon" then "weapon" else "armor"
		if item.kind ~= expectedKind then
			return fail("That does not go there.")
		end
		if data.realm < item.realmReq then
			local needed = Realms[item.realmReq]
			return fail(`Needs {needed.name} to wield.`)
		end
	end
	if slot == "weapon" then
		data.equippedWeapon = id :: string?
	else
		data.equippedArmor = id :: string?
	end
	CombatService.RefreshMods(player)
	DataService.PushInventory(player)
	return { ok = true }
end

-- ------------------------------ Lifecycle -------------------------------

local function bindDwarf(instance: Instance)
	local prompt = if instance:IsA("ProximityPrompt") then instance else instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(sendDialogue)
	end
end

local function bindForge(instance: Instance)
	local prompt = if instance:IsA("ProximityPrompt") then instance else instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt == nil then
		return
	end
	local parent = prompt:FindFirstAncestorWhichIsA("BasePart") or prompt.Parent
	if parent and parent:IsA("BasePart") then
		table.insert(forgePositions, parent.Position)
	end
	prompt.Triggered:Connect(function(player)
		Net.remoteEvent("OpenCrafting"):FireClient(player)
	end)
end

function ForgeService.Init()
	Net.remoteFunction("MissionAction").OnServerInvoke = missionAction
	Net.remoteFunction("CraftItem").OnServerInvoke = craftItem
	Net.remoteFunction("EquipItem").OnServerInvoke = equipItem

	for _, dwarf in CollectionService:GetTagged("DwarfPrompt") do
		bindDwarf(dwarf)
	end
	CollectionService:GetInstanceAddedSignal("DwarfPrompt"):Connect(bindDwarf)

	for _, forge in CollectionService:GetTagged("ForgePrompt") do
		bindForge(forge)
	end
	CollectionService:GetInstanceAddedSignal("ForgePrompt"):Connect(bindForge)
end

return ForgeService
