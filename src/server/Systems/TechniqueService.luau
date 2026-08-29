--!strict
-- ModuleScript: ServerScriptService > Server > Systems > TechniqueService
-- The defining feature: player-created techniques. Creation from secure
-- components, hotbar slots, server-resolved casting, mastery by practice,
-- technique manuals as real inventory items, and master-to-disciple
-- transmission. Every number is recomputed server-side from the stored
-- design at cast time; a modified client gains nothing.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Realms = require(Shared:WaitForChild("Realms"))
local TechniqueMath = require(Shared:WaitForChild("TechniqueMath"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))

local DataService = require(script.Parent.DataService)
local CultivationService = require(script.Parent.CultivationService)
local CombatService = require(script.Parent.CombatService)

local TechniqueService = {}

local combatFx = Net.remoteEvent("CombatFx")
local castLimit = RateLimit.new(10, 1)
local editLimit = RateLimit.new(8, 5)

-- [userId][techniqueId] = os.clock() when ready again
local cooldowns: { [number]: { [string]: number } } = {}

local function fail(message: string): { [string]: any }
	return { ok = false, error = message }
end

local function findTechnique(data: Types.PlayerData, id: string): Types.Technique?
	for _, technique in data.techniques do
		if technique.id == id then
			return technique
		end
	end
	return nil
end

local function filterName(raw: string, userId: number): string
	local filtered = raw
	local ok, result = pcall(function()
		local obj = TextService:FilterStringAsync(raw, userId)
		return obj:GetNonChatStringForBroadcastAsync()
	end)
	if ok and typeof(result) == "string" then
		filtered = result
	end
	return filtered
end

local function characterParts(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return character, nil, nil
	end
	return character, root, humanoid
end

local function humanoidFromPart(part: BasePart): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- --------------------------- Create / manage ----------------------------

local function createTechnique(player: Player, payload: unknown): { [string]: any }
	if not editLimit:Allow(player.UserId) then
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
	local category = request.category
	local components = request.components
	local intensity = request.intensity
	local name = request.name
	if typeof(category) ~= "string" or typeof(components) ~= "table" or typeof(intensity) ~= "number" or typeof(name) ~= "string" then
		return fail("Bad request")
	end
	local componentIds: { string } = {}
	for _, id in components :: { unknown } do
		if typeof(id) ~= "string" then
			return fail("Bad request")
		end
		table.insert(componentIds, id)
	end

	if #data.techniques >= Config.MAX_TECHNIQUES then
		return fail(`You can hold {Config.MAX_TECHNIQUES} techniques. Discard one first.`)
	end

	local computed, reason = TechniqueMath.compute(category, componentIds, intensity)
	if computed == nil then
		return fail(reason or "Invalid design")
	end
	if computed.requiredStage > data.stage then
		return fail(`A design of that power needs {Realms.displayName(computed.requiredStage)}.`)
	end

	local cost = math.floor(10 + computed.power * 0.5)
	if data.spiritStones < cost then
		return fail(`Recording this design needs {cost} spirit stones.`)
	end

	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if #name < 1 or #name > Config.MAX_TECHNIQUE_NAME then
		return fail(`Name must be 1 to {Config.MAX_TECHNIQUE_NAME} characters.`)
	end
	name = filterName(name, player.UserId)

	data.spiritStones -= cost
	local technique: Types.Technique = {
		id = HttpService:GenerateGUID(false),
		name = name,
		category = category,
		components = componentIds,
		power = computed.power,
		masteryXp = 0,
		origin = nil,
		inherited = nil,
	}
	table.insert(data.techniques, technique)

	for slot = 1, Config.SLOT_COUNT do
		if data.slots[tostring(slot)] == nil then
			data.slots[tostring(slot)] = technique.id
			break
		end
	end

	DataService.Notify(player, `{name} takes shape: {computed.rank}, power {computed.power}.`, Color3.fromRGB(255, 215, 120))
	DataService.PushStats(player)
	DataService.PushTechniques(player)
	return { ok = true, technique = technique }
end

local function deleteTechnique(player: Player, payload: unknown): { [string]: any }
	if not editLimit:Allow(player.UserId) then
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
	for index, technique in data.techniques do
		if technique.id == id then
			table.remove(data.techniques, index)
			for slot, slotted in data.slots do
				if slotted == id then
					data.slots[slot] = nil
				end
			end
			DataService.PushTechniques(player)
			return { ok = true }
		end
	end
	return fail("No such technique")
end

local function equipTechnique(player: Player, payload: unknown): { [string]: any }
	if not editLimit:Allow(player.UserId) then
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
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > Config.SLOT_COUNT then
		return fail("Bad slot")
	end
	if id ~= nil and typeof(id) ~= "string" then
		return fail("Bad request")
	end
	if id ~= nil then
		if findTechnique(data, id :: string) == nil then
			return fail("No such technique")
		end
		for existingSlot, slotted in data.slots do
			if slotted == id then
				data.slots[existingSlot] = nil
			end
		end
		data.slots[tostring(slot)] = id :: string
	else
		data.slots[tostring(slot)] = nil
	end
	DataService.PushTechniques(player)
	return { ok = true }
end

-- ------------------------------- Casting --------------------------------

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function strikeBox(player: Player, root: BasePart, direction: Vector3, reach: number, damage: number)
	local boxCFrame = CFrame.lookAt(root.Position, root.Position + direction) * CFrame.new(0, 0, -reach / 2)
	overlapParams.FilterDescendantsInstances = { player.Character :: any }
	local seen: { [Humanoid]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(boxCFrame, Vector3.new(reach, 7, reach), overlapParams) do
		local humanoid = humanoidFromPart(part)
		if humanoid and not seen[humanoid] then
			seen[humanoid] = true
			CombatService.DealDamage(player, humanoid, damage, { kind = "technique", direction = direction, knockback = 14 })
		end
	end
end

local function burstSphere(player: Player, center: Vector3, radius: number, damage: number)
	overlapParams.FilterDescendantsInstances = { player.Character :: any }
	local seen: { [Humanoid]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(center, radius, overlapParams) do
		local humanoid = humanoidFromPart(part)
		if humanoid and not seen[humanoid] then
			seen[humanoid] = true
			local away = part.Position - center
			local direction = if away.Magnitude > 0.01 then away.Unit else Vector3.yAxis
			CombatService.DealDamage(player, humanoid, damage, { kind = "technique", direction = direction, knockback = 22, dodgeable = false })
		end
	end
end

local function runWave(player: Player, origin: Vector3, direction: Vector3, speed: number, range: number, damage: number)
	task.spawn(function()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { player.Character :: any }
		local position = origin
		local traveled = 0
		local unit = direction.Unit
		while traveled < range do
			local dt = task.wait()
			local step = math.min(speed * dt, range - traveled)
			local result = workspace:Raycast(position, unit * step, rayParams)
			if result then
				local humanoid = humanoidFromPart(result.Instance)
				if humanoid then
					CombatService.DealDamage(player, humanoid, damage, { kind = "technique", direction = unit, knockback = 18 })
				end
				return -- waves stop on whatever they meet
			end
			position += unit * step
			traveled += step
		end
	end)
end

local function castTechnique(player: Player, slotArg: unknown, aimArg: unknown)
	if not castLimit:Allow(player.UserId) then
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	if typeof(slotArg) ~= "number" or slotArg % 1 ~= 0 or slotArg < 1 or slotArg > Config.SLOT_COUNT then
		return
	end
	local techniqueId = data.slots[tostring(slotArg)]
	if techniqueId == nil then
		return
	end
	local technique = findTechnique(data, techniqueId)
	if technique == nil then
		return
	end

	local _, root, humanoid = characterParts(player)
	if root == nil or humanoid == nil then
		return
	end

	local computed = (TechniqueMath.compute(technique.category, technique.components, 1))
	-- Recompute from the STORED power (intensity already folded in at
	-- creation): compute() at intensity 1 gives shape; scale to potential.
	if computed == nil then
		return
	end
	local basePower = math.max(computed.power, 1)
	local potentialScale = technique.power / basePower

	-- Realm gate and the inheritance ceiling.
	local effectivePower = TechniqueMath.effectivePower(technique, data.stage)
	if effectivePower <= 0 then
		DataService.Notify(player, "This art is beyond your current realm.")
		return
	end
	local outputScale = effectivePower / technique.power

	-- Sword arts need a sword in hand.
	local weaponMult, qiMult = CombatService.WeaponMultipliers(player)
	if technique.category == "sword" then
		local weaponId = data.equippedWeapon
		if weaponId == nil then
			DataService.Notify(player, "A sword art needs a sword in hand.")
			return
		end
	end

	local masteryPct = TechniqueMath.masteryPercent(technique.masteryXp, technique.power)

	-- Cooldown
	local userCooldowns = cooldowns[player.UserId]
	if userCooldowns == nil then
		userCooldowns = {}
		cooldowns[player.UserId] = userCooldowns
	end
	local now = os.clock()
	local readyAt = userCooldowns[technique.id]
	if readyAt and now < readyAt then
		return
	end

	-- Qi price, eased by mastery.
	local qiCost = math.max(1, math.floor(computed.qiCost * potentialScale * TechniqueMath.masteryQiMult(masteryPct) + 0.5))
	if not CultivationService.Spend(player, qiCost) then
		DataService.Notify(player, "Not enough qi.")
		return
	end
	userCooldowns[technique.id] = now + computed.cooldown * TechniqueMath.masteryCooldownMult(masteryPct)
	DataService.SetMeditating(player, false)

	-- Aim
	local aim = if typeof(aimArg) == "Vector3" and (aimArg :: Vector3).Magnitude < 1e5
		then aimArg :: Vector3
		else root.Position + root.CFrame.LookVector * 10
	local direction = CombatService.MeleeDirection(root, aim)

	local totalDamage = computed.damage * potentialScale * outputScale
		* TechniqueMath.masteryDamageMult(masteryPct)
		* weaponMult
		* (if technique.category == "qi" then qiMult else 1)

	-- Damage divides across the damaging steps by their shares.
	local shareSum = 0
	for _, step in computed.steps do
		shareSum += step.damageShare or 0
	end

	-- Execute the chain, one component per beat.
	task.spawn(function()
		for index, step in computed.steps do
			if index > 1 then
				task.wait(0.28)
			end
			local _, rootNow, humanoidNow = characterParts(player)
			if rootNow == nil or humanoidNow == nil then
				return
			end
			local stepDamage = if shareSum > 0 and step.damageShare
				then totalDamage * (step.damageShare / shareSum)
				else 0
			local reach = (step.distance or 10) * computed.reachMult

			if step.kind == "motion" then
				if step.id == "blink_step" then
					-- Server-moved: a stitch through space, stopped by walls.
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					rayParams.FilterDescendantsInstances = { player.Character :: any }
					local distance = reach
					local blocked = workspace:Raycast(rootNow.Position, direction * distance, rayParams)
					if blocked then
						distance = math.max(0, (blocked.Position - rootNow.Position).Magnitude - 3)
					end
					rootNow.CFrame = CFrame.lookAt(rootNow.Position + direction * distance, rootNow.Position + direction * (distance + 10))
				end
				-- dash/leap velocity is applied by the caster's own client
				-- on the CombatFx event below (it owns its physics).
			elseif step.kind == "strike" then
				strikeBox(player, rootNow, direction, reach, stepDamage)
			elseif step.kind == "wave" then
				runWave(player, rootNow.Position + direction * 3, direction, step.speed or 90, reach, stepDamage)
			elseif step.kind == "burst" then
				burstSphere(player, rootNow.Position, (step.radius or 12) * computed.reachMult, stepDamage)
			end

			combatFx:FireAllClients({
				kind = "techniqueStep",
				userId = player.UserId,
				partId = step.id,
				stepKind = step.kind,
				category = technique.category,
				origin = rootNow.Position,
				direction = direction,
				reach = reach,
				radius = (step.radius or 12) * computed.reachMult,
				speed = step.speed or 90,
			})
		end
	end)

	-- Practice tempers the art and the artist.
	CultivationService.AddXp(player, 1 + technique.power * 0.01)
	if masteryPct < Config.MASTERY_MAX then
		technique.masteryXp += 2 + math.floor(technique.power * 0.02)
		local newPct = TechniqueMath.masteryPercent(technique.masteryXp, technique.power)
		if newPct >= 100 and masteryPct < 100 then
			DataService.Notify(player, `You have fully MASTERED {technique.name}. You may now write its manual, or pass it to a disciple.`, Color3.fromRGB(255, 215, 120))
			DataService.PushTechniques(player)
		elseif math.floor(newPct / 25) > math.floor(masteryPct / 25) then
			DataService.Notify(player, `{technique.name} mastery: {newPct}%.`)
			DataService.PushTechniques(player)
		end
	end
end

-- ---------------------- Manuals & transmission ---------------------------

local MANUAL_COST = 25

local function writeManual(player: Player, payload: unknown): { [string]: any }
	if not editLimit:Allow(player.UserId) then
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
	local technique = findTechnique(data, id)
	if technique == nil then
		return fail("No such technique")
	end
	if technique.inherited then
		return fail("An inherited art cannot be transcribed; only its original creator may write manuals.")
	end
	if TechniqueMath.masteryPercent(technique.masteryXp, technique.power) < 100 then
		return fail("Only a fully mastered art can be written down.")
	end
	if data.spiritStones < MANUAL_COST then
		return fail(`Ink, silk and patience: writing a manual costs {MANUAL_COST} spirit stones.`)
	end

	data.spiritStones -= MANUAL_COST
	local bookId = HttpService:GenerateGUID(false)
	data.manuals[bookId] = {
		bookId = bookId,
		techniqueName = technique.name,
		technique = {
			id = technique.id, -- references the original TechniqueId
			name = technique.name,
			category = technique.category,
			components = table.clone(technique.components),
			power = technique.power,
			masteryXp = 0,
			origin = player.Name,
			inherited = true,
		},
	}
	DataService.Notify(player, `You bind "{technique.name}" into a manual. Give it wisely.`, Color3.fromRGB(255, 215, 120))
	DataService.PushStats(player)
	DataService.PushInventory(player)
	return { ok = true, bookId = bookId }
end

local function useManual(player: Player, payload: unknown): { [string]: any }
	if not editLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local bookId = (payload :: { [string]: unknown }).bookId
	if typeof(bookId) ~= "string" then
		return fail("Bad request")
	end
	local manual = data.manuals[bookId]
	if manual == nil then
		return fail("You do not hold that manual.")
	end
	if #data.techniques >= Config.MAX_TECHNIQUES then
		return fail(`You already hold {Config.MAX_TECHNIQUES} techniques.`)
	end
	for _, owned in data.techniques do
		if owned.name == manual.technique.name and owned.category == manual.technique.category then
			return fail(`You already know {manual.technique.name}.`)
		end
	end

	local learned: Types.Technique = {
		id = HttpService:GenerateGUID(false),
		name = manual.technique.name,
		category = manual.technique.category,
		components = table.clone(manual.technique.components),
		power = manual.technique.power,
		masteryXp = 0,
		origin = manual.technique.origin,
		inherited = true,
	}
	table.insert(data.techniques, learned)
	data.manuals[bookId] = nil
	for slot = 1, Config.SLOT_COUNT do
		if data.slots[tostring(slot)] == nil then
			data.slots[tostring(slot)] = learned.id
			break
		end
	end
	DataService.Notify(player, `The pages of "{learned.name}" burn themselves into memory.`, Color3.fromRGB(255, 215, 120))
	DataService.PushInventory(player)
	DataService.PushTechniques(player)
	return { ok = true }
end

local function giveManual(player: Player, payload: unknown): { [string]: any }
	if not editLimit:Allow(player.UserId) then
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
	local bookId = request.bookId
	local targetUserId = request.targetUserId
	if typeof(bookId) ~= "string" or typeof(targetUserId) ~= "number" then
		return fail("Bad request")
	end
	local manual = data.manuals[bookId]
	if manual == nil then
		return fail("You do not hold that manual.")
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	local targetData = if target then DataService.Get(target) else nil
	if target == nil or targetData == nil then
		return fail("They must be here, in this world, to receive it.")
	end
	-- Hand to hand: both parties present and close.
	local _, myRoot = characterParts(player)
	local _, theirRoot = characterParts(target)
	if myRoot == nil or theirRoot == nil or (myRoot.Position - theirRoot.Position).Magnitude > 24 then
		return fail("Stand beside them to hand over a manual.")
	end

	data.manuals[bookId] = nil
	targetData.manuals[bookId] = manual
	DataService.Notify(player, `You hand "{manual.techniqueName}" to {target.Name}.`)
	DataService.Notify(target, `{player.Name} places a manual in your hands: "{manual.techniqueName}".`, Color3.fromRGB(255, 215, 120))
	DataService.PushInventory(player)
	DataService.PushInventory(target)
	return { ok = true }
end

-- Direct transmission: master to own disciple, mastered arts only.
local function teachTechnique(player: Player, payload: unknown): { [string]: any }
	if not editLimit:Allow(player.UserId) then
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
	local id = request.id
	local targetUserId = request.targetUserId
	if typeof(id) ~= "string" or typeof(targetUserId) ~= "number" then
		return fail("Bad request")
	end
	local technique = findTechnique(data, id)
	if technique == nil then
		return fail("No such technique")
	end
	if TechniqueMath.masteryPercent(technique.masteryXp, technique.power) < 100 then
		return fail("Master an art fully before passing it down.")
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	local targetData = if target then DataService.Get(target) else nil
	if target == nil or targetData == nil then
		return fail("Your disciple must be here, in this world.")
	end
	if targetData.masterUserId ~= player.UserId then
		return fail("Transmission passes only from master to disciple.")
	end
	if #targetData.techniques >= Config.MAX_TECHNIQUES then
		return fail(`{target.Name} already holds {Config.MAX_TECHNIQUES} techniques.`)
	end
	for _, owned in targetData.techniques do
		if owned.name == technique.name and owned.category == technique.category then
			return fail(`{target.Name} already knows {technique.name}.`)
		end
	end

	local inherited: Types.Technique = {
		id = HttpService:GenerateGUID(false),
		name = technique.name,
		category = technique.category,
		components = table.clone(technique.components),
		power = technique.power,
		masteryXp = 0,
		origin = technique.origin or player.Name,
		inherited = true,
	}
	table.insert(targetData.techniques, inherited)
	for slot = 1, Config.SLOT_COUNT do
		if targetData.slots[tostring(slot)] == nil then
			targetData.slots[tostring(slot)] = inherited.id
			break
		end
	end
	DataService.Notify(target, `Your master {player.Name} transmits {technique.name} to you!`, Color3.fromRGB(255, 215, 120))
	DataService.Notify(player, `You pass {technique.name} down to {target.Name}. Teaching sharpens your own dao.`)
	CultivationService.AddXp(player, 40)
	DataService.PushTechniques(target)
	return { ok = true }
end

-- ------------------------------ Lifecycle -------------------------------

function TechniqueService.Init()
	Net.remoteFunction("CreateTechnique").OnServerInvoke = createTechnique
	Net.remoteFunction("DeleteTechnique").OnServerInvoke = deleteTechnique
	Net.remoteFunction("EquipTechnique").OnServerInvoke = equipTechnique
	Net.remoteFunction("WriteManual").OnServerInvoke = writeManual
	Net.remoteFunction("UseManual").OnServerInvoke = useManual
	Net.remoteFunction("GiveManual").OnServerInvoke = giveManual
	Net.remoteFunction("TeachTechnique").OnServerInvoke = teachTechnique
	Net.remoteEvent("CastTechnique").OnServerEvent:Connect(castTechnique)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player.UserId] = nil
		castLimit:Forget(player.UserId)
		editLimit:Forget(player.UserId)
	end)
end

return TechniqueService
