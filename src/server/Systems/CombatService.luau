--!strict
-- ModuleScript: ServerScriptService > Server > Systems > CombatService
-- Server-authoritative combat. The client sends INTENT (swing, block,
-- dodge) and plays its own animations for responsiveness; the server
-- validates cooldowns, positions and states, resolves every hitbox, and
-- is the only writer of damage. Exploiters can fire these remotes all
-- day and get nothing the rules don't allow.
--
-- Combat also cultivates: damage dealt to real enemies and strikes on
-- training dummies feed CultivationService.AddXp.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Realms = require(Shared:WaitForChild("Realms"))
local Items = require(Shared:WaitForChild("Items"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))

local DataService = require(script.Parent.DataService)
local CultivationService = require(script.Parent.CultivationService)

local CombatService = {}

local combatFx = Net.remoteEvent("CombatFx")
local attackLimit = RateLimit.new(14, 2)
local stateLimit = RateLimit.new(20, 2)

-- Fired (killerPlayer: Player?, victimHumanoid: Humanoid) when anything
-- dies to combat damage. NpcService listens for loot and respawns.
local slainEvent = Instance.new("BindableEvent")
CombatService.Slain = slainEvent.Event

type CombatState = {
	lastLight: number,
	comboIndex: number,
	lastHeavy: number,
	blocking: boolean,
	dodgeUntil: number,
	lastDodge: number,
}

local states: { [Player]: CombatState } = {}

local function stateFor(player: Player): CombatState
	local state = states[player]
	if state == nil then
		state = { lastLight = 0, comboIndex = 0, lastHeavy = 0, blocking = false, dodgeUntil = 0, lastDodge = 0 }
		states[player] = state
	end
	return state
end

-- ------------------------------ Safe zones ------------------------------

type Zone = { position: Vector3, radius: number }
local safeZones: { Zone } = {}

local function registerZone(marker: Instance)
	if not marker:IsA("BasePart") then
		return
	end
	local radius = marker:GetAttribute("Radius")
	table.insert(safeZones, {
		position = marker.Position,
		radius = if typeof(radius) == "number" then radius else 32,
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

-- ------------------------------- Helpers --------------------------------

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

local function sanitizeAim(aim: unknown, fallback: Vector3): Vector3
	if typeof(aim) ~= "Vector3" then
		return fallback
	end
	local v = aim :: Vector3
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z or v.Magnitude > 1e5 then
		return fallback
	end
	return v
end

local function weaponMultipliers(player: Player): (number, number)
	local data = DataService.Get(player)
	local weaponId = if data then data.equippedWeapon else nil
	local weapon = if weaponId then Items.get(weaponId) else nil
	if weapon and weapon.kind == "weapon" then
		return weapon.damageMult or 1, weapon.qiConductivity or 1
	end
	return 1, 1
end

function CombatService.WeaponMultipliers(player: Player): (number, number)
	return weaponMultipliers(player)
end

-- ------------------------------- Damage ---------------------------------

export type DamageOptions = {
	kind: string, -- "light" | "heavy" | "technique" | "npc"
	direction: Vector3?,
	knockback: number?,
	stun: number?,
	dodgeable: boolean?, -- default true; AoE bursts pass false
}

-- The single gate all damage passes through. Returns damage dealt.
function CombatService.DealDamage(attacker: Player?, target: Humanoid, amount: number, options: DamageOptions): number
	if amount <= 0 or target.Health <= 0 then
		return 0
	end
	local targetModel = target.Parent
	if targetModel == nil then
		return 0
	end
	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")

	-- Sanctuary: no player is harmed in a safe zone, and no one may harm
	-- outward from one. (NPC beasts never enter them by design.)
	if targetPlayer and targetRoot and targetRoot:IsA("BasePart") and CombatService.InSafeZone(targetRoot.Position) then
		return 0
	end
	if attacker then
		local _, attackerRoot = characterParts(attacker)
		if targetPlayer and attackerRoot and CombatService.InSafeZone(attackerRoot.Position) then
			return 0
		end
		if attacker.Character == targetModel then
			return 0
		end
	end

	-- A well-timed dodge makes melee and single-target technique blows miss.
	if targetPlayer and (options.dodgeable ~= false) then
		local targetState = states[targetPlayer]
		if targetState and os.clock() < targetState.dodgeUntil then
			combatFx:FireAllClients({ kind = "dodged", userId = targetPlayer.UserId })
			return 0
		end
	end

	local dealt = amount

	-- Innate defense from the target's realm (attribute set by whoever
	-- owns the target: CultivationService for players, NpcService for NPCs).
	local defense = target:GetAttribute("DefenseFrac")
	if typeof(defense) == "number" then
		dealt *= 1 - math.clamp(defense, 0, 0.8)
	end

	-- Blocking: strong against light blows, weaker against heavies.
	if targetPlayer then
		local targetState = states[targetPlayer]
		if targetState and targetState.blocking then
			local reduction = if options.kind == "heavy" then Config.BLOCK_REDUCTION_HEAVY else Config.BLOCK_REDUCTION_LIGHT
			dealt *= 1 - reduction
			combatFx:FireAllClients({ kind = "blocked", userId = targetPlayer.UserId })
		end
	end

	dealt = math.max(1, math.floor(dealt + 0.5))
	local wasAlive = target.Health > 0
	target:TakeDamage(dealt)

	-- Knockback and stun ride along the damage.
	local direction = options.direction
	if direction and options.knockback and targetRoot and targetRoot:IsA("BasePart") and not targetRoot.Anchored then
		if direction.Magnitude > 0.01 then
			targetRoot.AssemblyLinearVelocity += direction.Unit * options.knockback + Vector3.new(0, options.knockback * 0.35, 0)
		end
	end
	if options.stun and options.stun > 0 then
		if targetPlayer then
			target:SetAttribute("SpeedFactor", 0)
			task.delay(options.stun, function()
				if targetPlayer.Parent and target.Parent then
					target:SetAttribute("SpeedFactor", 1)
				end
			end)
		else
			local original = target.WalkSpeed
			target.WalkSpeed = 0
			task.delay(options.stun, function()
				if target.Parent then
					target.WalkSpeed = original
				end
			end)
		end
	end

	-- Combat is cultivation. Dummies pay flat training xp; live enemies
	-- pay by the wound, and again on the kill.
	if attacker then
		local isDummy = CollectionService:HasTag(targetModel, "TrainingDummy")
		if isDummy then
			CultivationService.AddXp(attacker, Config.TRAINING_XP_PER_HIT)
		else
			CultivationService.AddXp(attacker, dealt * Config.COMBAT_XP_PER_DAMAGE)
		end
		if wasAlive and target.Health <= 0 then
			if not isDummy then
				local victimStage = target:GetAttribute("Stage")
				local stage = if typeof(victimStage) == "number" then victimStage else 1
				CultivationService.AddXp(attacker, stage * Config.KILL_XP_MULT)
			end
			slainEvent:Fire(attacker, target)
		end
	elseif target.Health <= 0 and wasAlive then
		slainEvent:Fire(nil, target)
	end

	if targetRoot and targetRoot:IsA("BasePart") then
		combatFx:FireAllClients({
			kind = "hit",
			position = targetRoot.Position,
			amount = dealt,
			targetUserId = if targetPlayer then targetPlayer.UserId else nil,
		})
	end

	return dealt
end

-- ---------------------------- Melee resolution ---------------------------

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function meleeTargets(attacker: Player, root: BasePart, aim: Vector3, reach: number): { Humanoid }
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	local direction = if flat.Magnitude > 0.5 then flat.Unit else root.CFrame.LookVector
	local boxCFrame = CFrame.lookAt(root.Position, root.Position + direction) * CFrame.new(0, 0, -reach / 2)
	local attackerCharacter = attacker.Character
	overlapParams.FilterDescendantsInstances = if attackerCharacter then { attackerCharacter :: Instance } else {}
	local found: { Humanoid } = {}
	local seen: { [Humanoid]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(boxCFrame, Vector3.new(reach * 0.9, 6, reach), overlapParams) do
		local humanoid = humanoidFromPart(part)
		if humanoid and not seen[humanoid] then
			seen[humanoid] = true
			table.insert(found, humanoid)
		end
	end
	return found
end

function CombatService.MeleeDirection(root: BasePart, aim: Vector3): Vector3
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	return if flat.Magnitude > 0.5 then flat.Unit else root.CFrame.LookVector
end

local function onAttack(player: Player, kindArg: unknown, aimArg: unknown)
	if not attackLimit:Allow(player.UserId) then
		return
	end
	if kindArg ~= "light" and kindArg ~= "heavy" then
		return
	end
	local kind = kindArg :: string
	local _, root, humanoid = characterParts(player)
	if root == nil or humanoid == nil then
		return
	end
	local state = stateFor(player)
	if state.blocking then
		return -- no swinging from behind a guard
	end
	local now = os.clock()

	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local strength = Realms.statsFor(data.stage).strength
	local weaponMult = (weaponMultipliers(player))
	local aim = sanitizeAim(aimArg, root.Position + root.CFrame.LookVector * 10)
	local direction = CombatService.MeleeDirection(root, aim)

	if kind == "light" then
		if now - state.lastLight < Config.LIGHT_COOLDOWN then
			return
		end
		-- The combo chain: 1 -> 2 -> 3(finisher), resetting when idle.
		if now - state.lastLight > Config.LIGHT_CHAIN_WINDOW then
			state.comboIndex = 0
		end
		state.comboIndex = (state.comboIndex % 3) + 1
		state.lastLight = now

		local isFinisher = state.comboIndex == 3
		local damage = strength * weaponMult * (if isFinisher then Config.FINISHER_MULT else 1)
		for _, target in meleeTargets(player, root, aim, Config.MELEE_RANGE) do
			CombatService.DealDamage(player, target, damage, {
				kind = "light",
				direction = direction,
				knockback = if isFinisher then 26 else nil,
				stun = if isFinisher then Config.STUN_ON_FINISHER else nil,
			})
		end
		combatFx:FireAllClients({
			kind = "swing",
			userId = player.UserId,
			swing = state.comboIndex,
			origin = root.Position,
			direction = direction,
		})
	else
		if now - state.lastHeavy < Config.HEAVY_COOLDOWN then
			return
		end
		state.lastHeavy = now
		state.comboIndex = 0
		local damage = strength * weaponMult * Config.HEAVY_MULT
		-- The heavy lands after its windup; the server owns the timing.
		combatFx:FireAllClients({
			kind = "swing",
			userId = player.UserId,
			swing = 0, -- 0 = heavy windup
			origin = root.Position,
			direction = direction,
		})
		task.delay(0.45, function()
			local _, rootNow, humanoidNow = characterParts(player)
			if rootNow == nil or humanoidNow == nil then
				return
			end
			for _, target in meleeTargets(player, rootNow, aim, Config.MELEE_RANGE + 2) do
				CombatService.DealDamage(player, target, damage, {
					kind = "heavy",
					direction = direction,
					knockback = 34,
				})
			end
		end)
	end
end

-- ------------------------- Block / dodge intents -------------------------

local function onBlockSet(player: Player, wants: unknown)
	if not stateLimit:Allow(player.UserId) then
		return
	end
	stateFor(player).blocking = wants == true
end

local function onDodge(player: Player)
	if not stateLimit:Allow(player.UserId) then
		return
	end
	local state = stateFor(player)
	local now = os.clock()
	if now - state.lastDodge < Config.DODGE_COOLDOWN then
		return
	end
	state.lastDodge = now
	state.dodgeUntil = now + Config.DODGE_WINDOW
	-- The dash itself is client physics (they own their character); the
	-- server only grants the evasion window and tells everyone else.
	combatFx:FireAllClients({ kind = "dodge", userId = player.UserId })
end

-- --------------------------- Training dummies ----------------------------

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
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.06)
			end
		end
	end)
end

-- ------------------------------ Lifecycle -------------------------------

function CombatService.Init()
	for _, marker in CollectionService:GetTagged("SafeZone") do
		registerZone(marker)
	end
	CollectionService:GetInstanceAddedSignal("SafeZone"):Connect(registerZone)

	for _, dummy in CollectionService:GetTagged("TrainingDummy") do
		dummyLoop(dummy)
	end
	CollectionService:GetInstanceAddedSignal("TrainingDummy"):Connect(dummyLoop)

	Net.remoteEvent("AttackRequest").OnServerEvent:Connect(onAttack)
	Net.remoteEvent("BlockSet").OnServerEvent:Connect(onBlockSet)
	Net.remoteEvent("DodgeRequest").OnServerEvent:Connect(onDodge)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		attackLimit:Forget(player.UserId)
		stateLimit:Forget(player.UserId)
	end)

	-- Death clears combat state so nobody respawns mid-block.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					local state = states[player]
					if state then
						state.blocking = false
						state.comboIndex = 0
					end
				end)
			end
		end)
	end)
end

return CombatService
