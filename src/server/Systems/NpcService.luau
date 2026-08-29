--!strict
-- ModuleScript: ServerScriptService > Server > Systems > NpcService
-- The enemy framework: spirit beasts that wander, hunt, fight, die, drop,
-- and return. WorldService places tagged BeastSpawn markers; this system
-- populates them. Beast stats derive from their cultivation stage through
-- the same Realms curve players use, so region difficulty is honest.
--
-- All beast bodies are built from parts (no invented mesh ids). When real
-- models exist, swap buildBody for asset spawns and the AI is unchanged.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Realms = require(Shared:WaitForChild("Realms"))

local CombatService = require(script.Parent.CombatService)
local InventoryService = require(script.Parent.InventoryService)

local NpcService = {}

type BeastDef = {
	id: string,
	name: string,
	stageMin: number,
	stageMax: number,
	bodyColor: Color3,
	accentColor: Color3,
	size: number, -- overall scale
	walkSpeed: number,
	runSpeed: number,
	aggroRange: number,
	attackRange: number,
	attackCooldown: number,
	damageMult: number, -- vs its stage strength
	leash: number,
	respawnSeconds: number,
	stones: { min: number, max: number },
	drops: { { itemId: string, chance: number, count: number } },
}

local BEASTS: { [string]: BeastDef } = {
	mistfang = {
		id = "mistfang",
		name = "Mistfang Wolf",
		stageMin = 2,
		stageMax = 4,
		bodyColor = Color3.fromRGB(126, 132, 142),
		accentColor = Color3.fromRGB(210, 218, 228),
		size = 1,
		walkSpeed = 8,
		runSpeed = 17,
		aggroRange = 34,
		attackRange = 6.5,
		attackCooldown = 1.6,
		damageMult = 1,
		leash = 90,
		respawnSeconds = 25,
		stones = { min = 2, max = 5 },
		drops = {
			{ itemId = "beast_fang", chance = 0.6, count = 1 },
			{ itemId = "spirit_dust", chance = 0.35, count = 1 },
		},
	},
	thornback = {
		id = "thornback",
		name = "Thornback Boar",
		stageMin = 5,
		stageMax = 8,
		bodyColor = Color3.fromRGB(104, 82, 62),
		accentColor = Color3.fromRGB(58, 46, 38),
		size = 1.3,
		walkSpeed = 7,
		runSpeed = 19,
		aggroRange = 26,
		attackRange = 7,
		attackCooldown = 2,
		damageMult = 1.35,
		leash = 70,
		respawnSeconds = 40,
		stones = { min = 4, max = 9 },
		drops = {
			{ itemId = "beast_fang", chance = 0.5, count = 2 },
			{ itemId = "spirit_dust", chance = 0.5, count = 1 },
			{ itemId = "emberroot", chance = 0.2, count = 1 },
		},
	},
}

local rng = Random.new()

-- ------------------------------ Beast body -------------------------------

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.CanCollide = collide
	if not collide then
		p.CanQuery = false
		p.CanTouch = false
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildBody(def: BeastDef, position: Vector3): (Model, Humanoid, BasePart)
	local scale = def.size
	local model = Instance.new("Model")
	model.Name = def.name

	local root = part(model, "HumanoidRootPart",
		Vector3.new(4.4, 2.6, 6.5) * scale,
		CFrame.new(position + Vector3.new(0, 2.4 * scale, 0)),
		def.bodyColor, Enum.Material.SmoothPlastic, true)
	root.Transparency = 1

	-- Torso, head, muzzle, ears, tail, four stub legs. Stylized, honest.
	part(model, "Torso", Vector3.new(3.6, 2.6, 5.6) * scale,
		root.CFrame, def.bodyColor, Enum.Material.Fabric, false).Massless = true
	part(model, "Head", Vector3.new(2.2, 2, 2.4) * scale,
		root.CFrame * CFrame.new(0, 1 * scale, -3.4 * scale), def.bodyColor, Enum.Material.Fabric, false).Massless = true
	part(model, "Muzzle", Vector3.new(1.2, 1, 1.4) * scale,
		root.CFrame * CFrame.new(0, 0.6 * scale, -4.6 * scale), def.accentColor, Enum.Material.Fabric, false).Massless = true
	for side = -1, 1, 2 do
		part(model, "Ear", Vector3.new(0.6, 1, 0.4) * scale,
			root.CFrame * CFrame.new(side * 0.8 * scale, 2.1 * scale, -3.4 * scale), def.accentColor, Enum.Material.Fabric, false).Massless = true
		for along = -1, 1, 2 do
			part(model, "Leg", Vector3.new(0.9, 2.2, 0.9) * scale,
				root.CFrame * CFrame.new(side * 1.3 * scale, -1.6 * scale, along * 1.9 * scale), def.bodyColor, Enum.Material.Fabric, false).Massless = true
		end
	end
	part(model, "Tail", Vector3.new(0.6, 0.6, 2.2) * scale,
		root.CFrame * CFrame.new(0, 0.6 * scale, 3.6 * scale) * CFrame.Angles(math.rad(-25), 0, 0), def.accentColor, Enum.Material.Fabric, false).Massless = true

	-- Weld everything to the root so physics moves one assembly.
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = child
			weld.Parent = child
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoRotate = true
	humanoid.HipHeight = 1.2 * scale
	humanoid.Parent = model

	model.PrimaryPart = root
	CollectionService:AddTag(model, "Beast")
	return model, humanoid, root
end

-- -------------------------------- The AI ---------------------------------

local function nearestPrey(origin: Vector3, range: number): (Player?, BasePart?)
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			-- Beasts do not hunt into sanctuaries.
			if CombatService.InSafeZone(root.Position) then
				continue
			end
			local distance = (root.Position - origin).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestPlayer = player
				bestRoot = root
			end
		end
	end
	return bestPlayer, bestRoot
end

local function runBeast(def: BeastDef, home: Vector3, spawnStage: number)
	local model, humanoid, root = buildBody(def, home)
	local stats = Realms.statsFor(spawnStage)
	humanoid.MaxHealth = math.floor(stats.maxHealth * 0.8)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = def.walkSpeed
	humanoid:SetAttribute("Stage", spawnStage)
	humanoid:SetAttribute("DefenseFrac", stats.defenseFrac * 0.5)

	-- Name and realm over its head.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 2.4)
	gui.StudsOffset = Vector3.new(0, 3.4 * def.size, 0)
	gui.MaxDistance = 140
	gui.Adornee = root
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = `{def.name}\n{Realms.displayName(spawnStage)}`
	label.TextColor3 = Color3.fromRGB(255, 120, 100)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.Garamond
	label.Parent = gui

	model.Parent = workspace
	root:SetNetworkOwner(nil) -- the server drives this body, always

	local lastAttack = 0
	local wanderTarget = home

	task.spawn(function()
		while model.Parent ~= nil and humanoid.Health > 0 do
			local origin = root.Position
			local overLeash = (origin - home).Magnitude > def.leash
			local prey: Player? = nil
			local preyRoot: BasePart? = nil
			if not overLeash then
				prey, preyRoot = nearestPrey(origin, def.aggroRange)
			end

			if prey and preyRoot then
				humanoid.WalkSpeed = def.runSpeed
				local distance = (preyRoot.Position - origin).Magnitude
				if distance <= def.attackRange then
					humanoid:MoveTo(origin)
					local now = os.clock()
					if now - lastAttack >= def.attackCooldown then
						lastAttack = now
						local target = (prey.Character :: Model):FindFirstChildOfClass("Humanoid")
						if target then
							local direction = (preyRoot.Position - origin)
							CombatService.DealDamage(nil, target, stats.strength * def.damageMult, {
								kind = "npc",
								direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.zAxis,
								knockback = 12,
							})
						end
					end
				else
					humanoid:MoveTo(preyRoot.Position)
				end
			else
				humanoid.WalkSpeed = def.walkSpeed
				if overLeash then
					humanoid:MoveTo(home)
					if (origin - home).Magnitude > def.leash * 1.5 then
						-- Hard reset: something dragged it too far.
						root.CFrame = CFrame.new(home + Vector3.new(0, 3, 0))
						humanoid.Health = humanoid.MaxHealth
					end
				else
					if (origin - wanderTarget).Magnitude < 4 or rng:NextNumber() < 0.15 then
						wanderTarget = home + Vector3.new(rng:NextNumber(-24, 24), 0, rng:NextNumber(-24, 24))
					end
					humanoid:MoveTo(wanderTarget)
				end
			end
			task.wait(0.4)
		end
	end)

	-- Death: linger briefly, vanish, and let the spawner refill the pack.
	humanoid.Died:Connect(function()
		task.delay(2.5, function()
			model:Destroy()
		end)
	end)

	return model, humanoid
end

-- ------------------------------- Spawners --------------------------------

local function runSpawner(marker: BasePart)
	local beastId = marker:GetAttribute("BeastId")
	local count = marker:GetAttribute("Count")
	local def = if typeof(beastId) == "string" then BEASTS[beastId] else nil
	if def == nil then
		warn(`[NpcService] Unknown beast id on {marker:GetFullName()}`)
		return
	end
	local wanted = if typeof(count) == "number" then count else 2

	task.spawn(function()
		local alive: { Model } = {}
		while marker.Parent ~= nil do
			-- Prune the fallen.
			for index = #alive, 1, -1 do
				local model = alive[index]
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if model.Parent == nil or humanoid == nil or humanoid.Health <= 0 then
					table.remove(alive, index)
				end
			end
			while #alive < wanted do
				local offset = Vector3.new(rng:NextNumber(-16, 16), 0, rng:NextNumber(-16, 16))
				local stage = rng:NextInteger(def.stageMin, def.stageMax)
				local model = (runBeast(def, marker.Position + offset, stage))
				table.insert(alive, model)
				task.wait(0.2)
			end
			task.wait(def.respawnSeconds)
		end
	end)
end

local function bindSpawner(marker: Instance)
	if marker:IsA("BasePart") then
		runSpawner(marker)
	end
end

-- --------------------------------- Loot ----------------------------------

local function onSlain(killer: Player?, victim: Humanoid)
	if killer == nil then
		return
	end
	local model = victim.Parent
	if model == nil or not CollectionService:HasTag(model, "Beast") then
		return
	end
	local defId: string? = nil
	for id, def in BEASTS do
		if def.name == model.Name then
			defId = id
			break
		end
	end
	local def = if defId then BEASTS[defId] else nil
	if def == nil then
		return
	end
	InventoryService.GrantStones(killer, rng:NextInteger(def.stones.min, def.stones.max))
	for _, drop in def.drops do
		if rng:NextNumber() < drop.chance then
			InventoryService.Grant(killer, drop.itemId, drop.count)
		end
	end
end

-- ------------------------------ Lifecycle -------------------------------

function NpcService.Init()
	CombatService.Slain:Connect(onSlain)
	for _, marker in CollectionService:GetTagged("BeastSpawn") do
		bindSpawner(marker)
	end
	CollectionService:GetInstanceAddedSignal("BeastSpawn"):Connect(bindSpawner)
end

return NpcService
