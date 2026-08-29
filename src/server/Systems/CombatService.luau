--!strict
-- ModuleScript: ServerScriptService > Server > Systems > CombatService
-- Server-authoritative damage. Every point of damage in the game flows
-- through DealDamage: safe-zone rules, armor, elemental side effects,
-- lifesteal, and training-dummy upkeep all live here so no technique can
-- reinvent (or bypass) them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local StatCalc = require(Shared:WaitForChild("StatCalc"))
local Elements = require(Shared:WaitForChild("Data"):WaitForChild("Elements"))
local Items = require(Shared:WaitForChild("Data"):WaitForChild("Items"))

local DataService = require(script.Parent.DataService)

local BASE_HEALTH = 100

local CombatService = {}

type Zone = { position: Vector3, radius: number }
local safeZones: { Zone } = {}

-- ------------------------------ Safe zones ------------------------------

local function registerZone(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local radius = part:GetAttribute("Radius")
	table.insert(safeZones, {
		position = part.Position,
		radius = if typeof(radius) == "number" then radius else math.max(part.Size.X, part.Size.Z) / 2,
	})
end

function CombatService.InSafeZone(position: Vector3): boolean
	for _, zone in safeZones do
		if (position - zone.position).Magnitude <= zone.radius then
			return true
		end
	end
	return false
end

-- ---------------------------- Character mods ----------------------------

-- Applies path/race/talent/armor modifiers to a live character. Called on
-- spawn and whenever gear, race or talents change.
function CombatService.RefreshMods(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if data == nil or humanoid == nil then
		return
	end

	local mods = StatCalc.combine(data.path, data.race, data.equippedTalents)

	local maxHealth = math.max(25, BASE_HEALTH + mods.maxHealthBonus)
	local healthFrac = humanoid.Health / humanoid.MaxHealth
	humanoid.MaxHealth = maxHealth
	humanoid.Health = math.min(maxHealth, maxHealth * healthFrac)

	humanoid.WalkSpeed = Config.BASE_WALKSPEED + mods.walkSpeedBonus

	local defense = mods.defenseBonus
	local armorId = data.equippedArmor
	if armorId then
		local armor = Items.get(armorId)
		if armor then
			defense += armor.defense
		end
	end
	humanoid:SetAttribute("DefenseFrac", math.clamp(defense, 0, 0.8))
end

-- ------------------------------- Damage ---------------------------------

local function healCaster(caster: Player, amount: number)
	local character = caster.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

local function applyEffect(caster: Player, target: Humanoid, effect: string, dealt: number, direction: Vector3)
	if effect == "burn" then
		task.spawn(function()
			for _ = 1, 3 do
				task.wait(1)
				if target.Health <= 0 then
					return
				end
				target:TakeDamage(math.max(1, dealt * 0.15))
			end
		end)
	elseif effect == "poison" then
		task.spawn(function()
			for _ = 1, 6 do
				task.wait(1)
				if target.Health <= 0 then
					return
				end
				target:TakeDamage(math.max(1, dealt * 0.08))
			end
		end)
	elseif effect == "slow" then
		task.spawn(function()
			local original = target.WalkSpeed
			target.WalkSpeed = original * 0.6
			task.wait(2.5)
			-- Restore through RefreshMods for players (authoritative),
			-- directly for NPCs.
			local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
			if targetPlayer then
				CombatService.RefreshMods(targetPlayer)
			elseif target.Parent ~= nil then
				target.WalkSpeed = original
			end
		end)
	elseif effect == "shock" then
		task.spawn(function()
			local original = target.WalkSpeed
			target.WalkSpeed = 0
			task.wait(0.4)
			local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
			if targetPlayer then
				CombatService.RefreshMods(targetPlayer)
			elseif target.Parent ~= nil then
				target.WalkSpeed = original
			end
		end)
	elseif effect == "knockback" or effect == "gust" then
		local root = if target.Parent then (target.Parent :: Instance):FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and not root.Anchored then
			local strength = if effect == "knockback" then 40 else 15
			root.AssemblyLinearVelocity += direction.Unit * strength + Vector3.new(0, strength * 0.4, 0)
		end
	elseif effect == "selfheal" then
		healCaster(caster, dealt * 0.15)
	elseif effect == "lifesteal" then
		healCaster(caster, dealt * 0.25)
	end
end

-- Returns damage actually dealt (0 = blocked by rules).
function CombatService.DealDamage(caster: Player, target: Humanoid, amount: number, elementId: string, direction: Vector3): number
	if amount <= 0 or target.Health <= 0 then
		return 0
	end
	local targetCharacter = target.Parent
	if targetCharacter == nil then
		return 0
	end

	-- No harming anyone inside a city, and no shooting in from outside.
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	if targetRoot and targetRoot:IsA("BasePart") and CombatService.InSafeZone(targetRoot.Position) then
		return 0
	end
	local casterCharacter = caster.Character
	local casterRoot = if casterCharacter then casterCharacter:FindFirstChild("HumanoidRootPart") else nil
	if casterRoot and casterRoot:IsA("BasePart") and CombatService.InSafeZone(casterRoot.Position) then
		return 0
	end
	if casterCharacter == targetCharacter then
		return 0
	end

	local defense = target:GetAttribute("DefenseFrac")
	local defenseFrac = if typeof(defense) == "number" then defense else 0
	local dealt = amount * (1 - math.clamp(defenseFrac, 0, 0.8))

	target:TakeDamage(dealt)

	local element = Elements.get(elementId)
	if element and element.effect ~= "none" then
		applyEffect(caster, target, element.effect, dealt, direction)
	end

	return dealt
end

-- --------------------------- Training dummies ---------------------------

local function dummyLoop(model: Instance)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	task.spawn(function()
		while model.Parent ~= nil do
			task.wait(1)
			if humanoid.Health <= 0 then
				task.wait(3)
				humanoid.Health = humanoid.MaxHealth
			elseif humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.05)
			end
		end
	end)
end

-- ------------------------------ Lifecycle -------------------------------

function CombatService.Init()
	for _, part in CollectionService:GetTagged("SafeZone") do
		registerZone(part)
	end
	CollectionService:GetInstanceAddedSignal("SafeZone"):Connect(registerZone)

	for _, dummy in CollectionService:GetTagged("TrainingDummy") do
		dummyLoop(dummy)
	end
	CollectionService:GetInstanceAddedSignal("TrainingDummy"):Connect(dummyLoop)

	DataService.ObserveLoaded(function(player)
		CombatService.RefreshMods(player)
		player.CharacterAdded:Connect(function()
			-- Humanoid may not exist for an instant on spawn.
			task.defer(CombatService.RefreshMods, player)
		end)
	end)
end

return CombatService
