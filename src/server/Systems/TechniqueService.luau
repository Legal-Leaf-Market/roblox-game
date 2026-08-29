--!strict
-- ModuleScript: ServerScriptService > Server > Systems > TechniqueService
-- Player-authored cultivation techniques: creation, hotbar slots, and
-- server-authoritative casting. The client only sends intent (slot + aim
-- point); every number — cost, cooldown, damage, reach — is recomputed here
-- from the stored design, so a modified client gains nothing.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local StatCalc = require(Shared:WaitForChild("StatCalc"))
local TechniqueMath = require(Shared:WaitForChild("TechniqueMath"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))
local Forms = require(Shared:WaitForChild("Data"):WaitForChild("TechniqueForms"))
local Elements = require(Shared:WaitForChild("Data"):WaitForChild("Elements"))
local Items = require(Shared:WaitForChild("Data"):WaitForChild("Items"))
local Realms = require(Shared:WaitForChild("Data"):WaitForChild("Realms"))

local DataService = require(script.Parent.DataService)
local QiSystem = require(script.Parent.QiSystem)
local CombatService = require(script.Parent.CombatService)

local TechniqueService = {}

local techniqueVFX = Net.remoteEvent("TechniqueVFX")

local castLimit = RateLimit.new(10, 1)
local editLimit = RateLimit.new(6, 5)

-- [userId][techniqueId] = os.clock() when ready again
local cooldowns: { [number]: { [string]: number } } = {}

-- ------------------------------ Helpers --------------------------------

local function fail(message: string): { ok: boolean, error: string }
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

local function validVector(v: unknown): Vector3?
	if typeof(v) ~= "Vector3" then
		return nil
	end
	local vec = v :: Vector3
	if vec.X ~= vec.X or vec.Y ~= vec.Y or vec.Z ~= vec.Z then
		return nil
	end
	if math.abs(vec.X) > 1e5 or math.abs(vec.Y) > 1e5 or math.abs(vec.Z) > 1e5 then
		return nil
	end
	return vec
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

-- --------------------------- Creation / slots ---------------------------

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
	local formId = request.form
	local elementId = request.element
	local power = request.power
	local name = request.name
	if typeof(formId) ~= "string" or typeof(elementId) ~= "string" or typeof(power) ~= "number" or typeof(name) ~= "string" then
		return fail("Bad request")
	end

	if #data.techniques >= Config.MAX_TECHNIQUES then
		return fail(`You can hold {Config.MAX_TECHNIQUES} techniques. Discard one first.`)
	end

	local stats, reason = TechniqueMath.compute(formId, elementId, power)
	if stats == nil then
		return fail(reason or "Invalid design")
	end
	if data.realm < stats.requiredRealm then
		local needed = Realms[stats.requiredRealm]
		return fail(`A design of that power needs {needed.name}.`)
	end

	local element = Elements.get(elementId)
	if element == nil then
		return fail("Unknown element")
	end
	if not StatCalc.elementAllowed(element.path, data.path, data.race, elementId) then
		return fail(`{element.name} is closed to you. It answers a path or a bloodline you do not hold.`)
	end

	if data.spiritStones < stats.createCost then
		return fail(`Designing this needs {stats.createCost} spirit stones.`)
	end

	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if #name < 1 or #name > Config.MAX_TECHNIQUE_NAME then
		return fail(`Name must be 1 to {Config.MAX_TECHNIQUE_NAME} characters.`)
	end
	name = filterName(name, player.UserId)

	data.spiritStones -= stats.createCost
	local technique: Types.Technique = {
		id = HttpService:GenerateGUID(false),
		name = name,
		form = formId,
		element = elementId,
		power = math.floor(power),
	}
	table.insert(data.techniques, technique)

	-- Auto-slot into the first free key so the technique is usable at once.
	for slot = 1, Config.SLOT_COUNT do
		if data.slots[tostring(slot)] == nil then
			data.slots[tostring(slot)] = technique.id
			break
		end
	end

	DataService.PushStats(player)
	DataService.PushInventory(player)
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
		-- One technique occupies one slot; clear it from any other.
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

local function damageInBox(caster: Player, cframe: CFrame, size: Vector3, damage: number, elementId: string, direction: Vector3)
	local character = caster.Character
	overlapParams.FilterDescendantsInstances = if character then { character } else {}
	local seen: { [Humanoid]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(cframe, size, overlapParams) do
		local humanoid = humanoidFromPart(part)
		if humanoid and not seen[humanoid] then
			seen[humanoid] = true
			CombatService.DealDamage(caster, humanoid, damage, elementId, direction)
		end
	end
end

local function damageInSphere(caster: Player, center: Vector3, radius: number, damage: number, elementId: string)
	local character = caster.Character
	overlapParams.FilterDescendantsInstances = if character then { character } else {}
	local seen: { [Humanoid]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(center, radius, overlapParams) do
		local humanoid = humanoidFromPart(part)
		if humanoid and not seen[humanoid] then
			seen[humanoid] = true
			local root = part
			local away = (root.Position - center)
			local direction = if away.Magnitude > 0.01 then away else Vector3.new(0, 1, 0)
			CombatService.DealDamage(caster, humanoid, damage, elementId, direction)
		end
	end
end

local function runProjectile(caster: Player, origin: Vector3, direction: Vector3, speed: number, range: number, pierce: boolean, damage: number, elementId: string)
	task.spawn(function()
		local character = caster.Character
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = if character then { character } else {}

		local position = origin
		local traveled = 0
		local unit = direction.Unit
		local hitHumanoids: { [Humanoid]: boolean } = {}

		while traveled < range do
			local dt = task.wait()
			local step = math.min(speed * dt, range - traveled)
			local result = workspace:Raycast(position, unit * step, rayParams)
			if result then
				local humanoid = humanoidFromPart(result.Instance)
				if humanoid and not hitHumanoids[humanoid] then
					hitHumanoids[humanoid] = true
					CombatService.DealDamage(caster, humanoid, damage, elementId, unit)
					if not pierce then
						return
					end
					-- Pass through this body: exclude its whole model and re-step.
					local model = result.Instance:FindFirstAncestorOfClass("Model")
					if model then
						local filter = rayParams.FilterDescendantsInstances
						table.insert(filter, model)
						rayParams.FilterDescendantsInstances = filter
					end
				elseif humanoid == nil then
					return -- terrain, wall, anything solid that isn't a body
				end
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
	local form = Forms.get(technique.form)
	local element = Elements.get(technique.element)
	if form == nil or element == nil then
		return
	end

	local character, root, humanoid = characterParts(player)
	if character == nil or root == nil or humanoid == nil then
		return
	end

	local stats = (TechniqueMath.compute(technique.form, technique.element, technique.power))
	if stats == nil then
		return
	end
	if data.realm < stats.requiredRealm then
		DataService.Notify(player, "Your realm is too shallow for this technique.")
		return
	end
	-- Race/path can change after creation; the element must still answer you.
	if not StatCalc.elementAllowed(element.path, data.path, data.race, element.id) then
		DataService.Notify(player, `{element.name} no longer answers you.`)
		return
	end

	-- Weapon gate: sword/blade/bow techniques need that weapon in hand.
	local weaponMult = 1
	if form.category ~= "movement" then
		local weaponId = data.equippedWeapon
		local weapon = if weaponId then Items.get(weaponId) else nil
		if weapon == nil or weapon.category ~= form.category then
			DataService.Notify(player, `You need a {form.category} equipped to cast this.`)
			return
		end
		weaponMult = weapon.damageMult
	end

	local mods = StatCalc.combine(data.path, data.race, data.equippedTalents)

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

	-- Qi
	local qiCost = math.max(1, math.floor(stats.qiCost * mods.qiCostMult + 0.5))
	if not QiSystem.Spend(player, qiCost) then
		DataService.Notify(player, "Not enough qi.")
		return
	end
	userCooldowns[technique.id] = now + stats.cooldown * mods.cooldownMult
	DataService.SetMeditating(player, false)

	-- Aim
	local aim = validVector(aimArg) or (root.Position + root.CFrame.LookVector * 10)
	local flatAim = Vector3.new(aim.X, root.Position.Y, aim.Z)
	local aimDelta = flatAim - root.Position
	local direction = if aimDelta.Magnitude > 0.5 then aimDelta.Unit else root.CFrame.LookVector

	local damage = stats.damage
		* mods.damageMult
		* (mods.categoryDamage[form.category] or 1)
		* (mods.elementDamage[element.id] or 1)
		* weaponMult

	-- Execute by kind. Movement application happens on the caster's client
	-- (it owns its character's physics); everything else resolves here.
	local kind = form.kind
	if kind == "melee" then
		local hitCFrame = CFrame.lookAt(root.Position, root.Position + direction) * CFrame.new(0, 0, -stats.range / 2)
		damageInBox(player, hitCFrame, Vector3.new(stats.range * 0.9, 6, stats.range), damage, element.id, direction)
	elseif kind == "projectile" then
		runProjectile(player, root.Position + direction * 2, direction, stats.speed, stats.range, form.pierce, damage, element.id)
	elseif kind == "aoe_point" then
		local target = aim
		local offset = target - root.Position
		if offset.Magnitude > stats.range then
			target = root.Position + offset.Unit * stats.range
		end
		task.delay(0.35, damageInSphere, player, target, stats.radius, damage, element.id)
	elseif kind == "aoe_self" then
		damageInSphere(player, root.Position, stats.radius, damage, element.id)
	elseif kind == "teleport" then
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { character }
		local distance = stats.range
		local blocked = workspace:Raycast(root.Position, direction * distance, rayParams)
		if blocked then
			distance = math.max(0, (blocked.Position - root.Position).Magnitude - 3)
		end
		root.CFrame = CFrame.lookAt(root.Position + direction * distance, root.Position + direction * (distance + 10))
	end
	-- dash / leap / speed_buff: applied by the caster's client on the VFX
	-- event below; the qi price and cooldown were already paid here.

	if kind == "speed_buff" then
		task.spawn(function()
			humanoid.WalkSpeed += stats.speed
			task.wait(stats.duration)
			CombatService.RefreshMods(player)
		end)
	end

	-- Practicing an art tempers the practitioner.
	QiSystem.AddXp(player, 1 + technique.power)

	techniqueVFX:FireAllClients({
		kind = "cast",
		casterUserId = player.UserId,
		form = form.id,
		formKind = form.kind,
		element = element.id,
		power = technique.power,
		origin = root.Position,
		direction = direction,
		aim = aim,
		range = stats.range,
		speed = stats.speed,
		radius = stats.radius,
	})
end

-- ------------------------------ Lifecycle -------------------------------

function TechniqueService.Init()
	Net.remoteFunction("CreateTechnique").OnServerInvoke = createTechnique
	Net.remoteFunction("DeleteTechnique").OnServerInvoke = deleteTechnique
	Net.remoteFunction("EquipTechnique").OnServerInvoke = equipTechnique
	Net.remoteEvent("CastTechnique").OnServerEvent:Connect(castTechnique)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player.UserId] = nil
		castLimit:Forget(player.UserId)
		editLimit:Forget(player.UserId)
	end)
end

return TechniqueService
