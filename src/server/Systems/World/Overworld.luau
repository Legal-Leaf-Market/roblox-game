--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Overworld
-- The surface: ground plane (with the mine-shaft hole), Heavenpillar
-- Mountain with its climbing ramps and summit platform, the wanderer spawn,
-- scattered blossom trees, and the sky's mood (Atmosphere).

local Lighting = game:GetService("Lighting")

local BuildKit = require(script.Parent.BuildKit)

local Overworld = {}

-- Shared layout constants (Underworld builds against the same hole).
Overworld.GROUND_TOP = 0
Overworld.HOLE = { x1 = -15, x2 = 15, z1 = 240, z2 = 300 } -- mine shaft opening
Overworld.MAP_HALF = 1024

local GROUND_THICKNESS = 16
local GRASS = Color3.fromRGB(96, 140, 84)
local ROCK = Color3.fromRGB(116, 110, 108)
local ROCK_DARK = Color3.fromRGB(92, 88, 90)

local TIERS = {
	{ radius = 220, height = 45 },
	{ radius = 185, height = 45 },
	{ radius = 150, height = 45 },
	{ radius = 115, height = 45 },
	{ radius = 80, height = 45 },
	{ radius = 50, height = 45 },
}

local function buildGround(parent: Instance)
	local hole = Overworld.HOLE
	local half = Overworld.MAP_HALF
	local y = Overworld.GROUND_TOP - GROUND_THICKNESS / 2
	local function slab(name: string, x1: number, x2: number, z1: number, z2: number)
		BuildKit.part({
			name = name,
			size = Vector3.new(x2 - x1, GROUND_THICKNESS, z2 - z1),
			position = Vector3.new((x1 + x2) / 2, y, (z1 + z2) / 2),
			color = GRASS,
			material = Enum.Material.Grass,
			parent = parent,
		})
	end
	-- Four slabs around the mine-shaft hole.
	slab("Ground_North", -half, half, -half, hole.z1)
	slab("Ground_South", -half, half, hole.z2, half)
	slab("Ground_West", -half, hole.x1, hole.z1, hole.z2)
	slab("Ground_East", hole.x2, half, hole.z1, hole.z2)
end

local function buildMountain(parent: Instance)
	local y = Overworld.GROUND_TOP
	for index, tier in TIERS do
		BuildKit.cylinder(
			parent,
			`Mountain_Tier{index}`,
			Vector3.new(0, y + tier.height / 2, 0),
			tier.height,
			tier.radius * 2,
			if index % 2 == 0 then ROCK_DARK else ROCK,
			Enum.Material.Slate
		)
		y += tier.height
	end

	-- Climbing ramps, alternating around the mountain so the ascent is a
	-- walk, not a wall. Ramp i runs from just outside tier i's radius (on
	-- the surface below) up onto tier i's top.
	local base = Overworld.GROUND_TOP
	for index, tier in TIERS do
		local angle = math.rad(150 + index * 137)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local outer = dir * (tier.radius + 24)
		local inner = dir * (tier.radius - 24)
		local from = Vector3.new(outer.X, base, outer.Z)
		local to = Vector3.new(inner.X, base + tier.height, inner.Z)
		local mid = (from + to) / 2
		local length = (to - from).Magnitude + 10
		BuildKit.part({
			name = `Mountain_Ramp{index}`,
			size = Vector3.new(14, 2, length),
			cframe = CFrame.lookAt(mid, to),
			color = ROCK,
			material = Enum.Material.Cobblestone,
			parent = parent,
		})
		base += tier.height
	end

	-- Summit meditation platform.
	local summitY = base
	local disc = BuildKit.cylinder(parent, "Summit_Platform", Vector3.new(0, summitY + 0.5, 0), 1, 60, Color3.fromRGB(210, 205, 190), Enum.Material.Marble)
	BuildKit.billboard(disc, "Summit of Heavenpillar. Meditate here, above the clouds.", Color3.fromRGB(255, 235, 180), 16, 1.6, Vector3.new(0, 8, 0))
	for i = 1, 6 do
		local angle = i * math.pi / 3
		local pillar = BuildKit.part({
			name = "Summit_Pillar",
			size = Vector3.new(2, 9, 2),
			position = Vector3.new(math.cos(angle) * 26, summitY + 4.5, math.sin(angle) * 26),
			color = Color3.fromRGB(190, 60, 55),
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
		BuildKit.pointLight(pillar, Color3.fromRGB(255, 200, 120), 1.5, 24)
	end
end

local function buildMineEntrance(parent: Instance)
	local hole = Overworld.HOLE
	-- Stone gate arch on the surface at the shaft's north lip.
	local gateZ = hole.z1 - 2
	BuildKit.part({
		name = "MineGate_PillarWest",
		size = Vector3.new(4, 18, 4),
		position = Vector3.new(hole.x1 - 2, 9, gateZ),
		color = ROCK_DARK,
		material = Enum.Material.Slate,
		parent = parent,
	})
	BuildKit.part({
		name = "MineGate_PillarEast",
		size = Vector3.new(4, 18, 4),
		position = Vector3.new(hole.x2 + 2, 9, gateZ),
		color = ROCK_DARK,
		material = Enum.Material.Slate,
		parent = parent,
	})
	local lintel = BuildKit.part({
		name = "MineGate_Lintel",
		size = Vector3.new((hole.x2 - hole.x1) + 12, 4, 5),
		position = Vector3.new(0, 20, gateZ),
		color = ROCK_DARK,
		material = Enum.Material.Slate,
		parent = parent,
	})
	BuildKit.billboard(lintel, "The Deep Mines of Heavenpillar", Color3.fromRGB(190, 220, 255), 14, 1.6, Vector3.new(0, 3, 0))
end

local function buildWandererSpawn(parent: Instance)
	local position = Vector3.new(0, Overworld.GROUND_TOP, 170)
	local plaza = BuildKit.cylinder(parent, "Wanderer_Plaza", position + Vector3.new(0, 0.25, 0), 0.5, 56, Color3.fromRGB(180, 174, 160), Enum.Material.Cobblestone)
	BuildKit.spawnLocation(parent, position + Vector3.new(0, 1, 0), "Medium stone grey", false)
	BuildKit.safeZone(parent, position, 40)
	BuildKit.billboard(plaza, "Wayfarer's Rest. Three cities, three paths. Choose with care; a dao is for life.", Color3.fromRGB(235, 230, 215), 20, 2, Vector3.new(0, 10, 0))
end

-- A soft foliage puff: a part carrying a sphere mesh so it can be scaled
-- into an ellipsoid (Ball-shaped Parts cannot).
local function puff(parent: Instance, position: Vector3, size: Vector3, color: Color3)
	local part = BuildKit.part({
		name = "Foliage",
		size = Vector3.new(1, 1, 1),
		position = position,
		color = color,
		material = Enum.Material.Grass,
		canCollide = false,
		parent = parent,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = part
end

local TRUNK = Color3.fromRGB(92, 70, 52)
local PINE_GREEN = Color3.fromRGB(52, 84, 60)
local PINE_DARK = Color3.fromRGB(40, 66, 48)
local BLOSSOM_PINK = Color3.fromRGB(240, 184, 205)
local BLOSSOM_WHITE = Color3.fromRGB(246, 238, 230)
local BAMBOO_GREEN = Color3.fromRGB(126, 168, 92)

-- Ink-painting pine: a leaning trunk with flat, layered canopy discs.
local function pineTree(parent: Instance, position: Vector3, rng: Random)
	local height = rng:NextNumber(14, 22)
	local lean = rng:NextNumber(-0.09, 0.09)
	BuildKit.part({
		name = "Pine_Trunk",
		size = Vector3.new(1.8, height, 1.8),
		cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(lean, 0, lean),
		color = TRUNK,
		material = Enum.Material.Wood,
		parent = parent,
	})
	local layers = rng:NextInteger(3, 4)
	for layer = 1, layers do
		local t = (layer - 1) / layers
		local layerY = position.Y + height * (0.5 + 0.55 * t)
		local diameter = (14 - t * 8) * rng:NextNumber(0.9, 1.15)
		BuildKit.cylinder(
			parent,
			"Pine_Canopy",
			Vector3.new(position.X + lean * height * t * 6, layerY, position.Z + lean * height * t * 6),
			1.4,
			diameter,
			if layer % 2 == 0 then PINE_DARK else PINE_GREEN,
			Enum.Material.Grass
		)
	end
end

-- Blossom tree: leaning trunk, clustered pink and white puffs.
local function blossomTree(parent: Instance, position: Vector3, rng: Random)
	local height = rng:NextNumber(10, 15)
	local lean = rng:NextNumber(-0.14, 0.14)
	BuildKit.part({
		name = "Blossom_Trunk",
		size = Vector3.new(1.6, height, 1.6),
		cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(lean, 0, -lean),
		color = Color3.fromRGB(70, 54, 44),
		material = Enum.Material.Wood,
		parent = parent,
	})
	local crown = position + Vector3.new(lean * height * 4, height, lean * height * 4)
	local puffs = rng:NextInteger(4, 6)
	for _ = 1, puffs do
		local offset = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-1, 4), rng:NextNumber(-5, 5))
		local width = rng:NextNumber(6, 10)
		puff(parent, crown + offset, Vector3.new(width, width * 0.65, width),
			if rng:NextNumber() < 0.7 then BLOSSOM_PINK else BLOSSOM_WHITE)
	end
end

-- Bamboo clump: a handful of thin, tall culms with small leaf puffs.
local function bambooClump(parent: Instance, position: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(5, 8) do
		local culmHeight = rng:NextNumber(16, 26)
		local offset = Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		local base = position + offset
		BuildKit.part({
			name = "Bamboo_Culm",
			size = Vector3.new(0.7, culmHeight, 0.7),
			cframe = CFrame.new(base + Vector3.new(0, culmHeight / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05)),
			color = BAMBOO_GREEN,
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
		puff(parent, base + Vector3.new(0, culmHeight, 0), Vector3.new(4, 2.5, 4), Color3.fromRGB(110, 150, 82))
	end
end

local function buildFlora(parent: Instance)
	local rng = Random.new(7) -- deterministic: same forest every server
	for _ = 1, 70 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(460, 940)
		local position = Vector3.new(math.cos(angle) * radius, Overworld.GROUND_TOP, math.sin(angle) * radius)
		-- Southeast quadrant grows bamboo (Freewind country); elsewhere
		-- pines dominate with blossoms scattered through.
		if position.X > 120 and position.Z > 60 and rng:NextNumber() < 0.5 then
			bambooClump(parent, position, rng)
		elseif rng:NextNumber() < 0.35 then
			blossomTree(parent, position, rng)
		else
			pineTree(parent, position, rng)
		end
	end
	-- A few blossoms right around the Wayfarer's Rest for the first view.
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		blossomTree(parent, Vector3.new(math.cos(angle) * rng:NextNumber(45, 70), Overworld.GROUND_TOP, 170 + math.sin(angle) * rng:NextNumber(45, 70)), rng)
	end

	-- Boulders, half-set into the grass.
	for _ = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(300, 900)
		local size = rng:NextNumber(3, 9)
		BuildKit.part({
			name = "Boulder",
			size = Vector3.new(size, size * 0.7, size * rng:NextNumber(0.7, 1.3)),
			cframe = CFrame.new(math.cos(angle) * radius, Overworld.GROUND_TOP + size * 0.2, math.sin(angle) * radius)
				* CFrame.Angles(rng:NextNumber(0, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(0, 0.3)),
			color = Color3.fromRGB(120, 116, 112),
			material = Enum.Material.Slate,
			parent = parent,
		})
	end
end

-- A ring road around the mountain plus a spur, so the three cities and the
-- mine read as connected places instead of objects dropped on a lawn.
local function buildRoads(parent: Instance)
	local roadColor = Color3.fromRGB(203, 194, 172)
	local function road(from: Vector3, to: Vector3, width: number)
		local mid = (from + to) / 2 + Vector3.new(0, 0.15, 0)
		BuildKit.part({
			name = "Road",
			size = Vector3.new(width, 0.35, (to - from).Magnitude + width * 0.5),
			cframe = CFrame.lookAt(mid, Vector3.new(to.X, mid.Y, to.Z)),
			color = roadColor,
			material = Enum.Material.Cobblestone,
			canCollide = false,
			parent = parent,
		})
	end

	local segments = 22
	local ringRadius = 302
	for index = 1, segments do
		local a1 = (index - 1) / segments * math.pi * 2
		local a2 = index / segments * math.pi * 2
		road(
			Vector3.new(math.sin(a1) * ringRadius, Overworld.GROUND_TOP, math.cos(a1) * ringRadius),
			Vector3.new(math.sin(a2) * ringRadius, Overworld.GROUND_TOP, math.cos(a2) * ringRadius),
			9
		)
	end
	-- Spur from the Wayfarer's Rest through the mine gate toward the ring.
	road(Vector3.new(0, Overworld.GROUND_TOP, 170), Vector3.new(0, Overworld.GROUND_TOP, 236), 9)
end

local function tuneSky()
	Lighting.ClockTime = 14.4
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	if Lighting:FindFirstChildOfClass("Atmosphere") == nil then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.35
		atmosphere.Offset = 0.4
		atmosphere.Color = Color3.fromRGB(199, 199, 214)
		atmosphere.Decay = Color3.fromRGB(106, 112, 125)
		atmosphere.Haze = 1.8
		atmosphere.Parent = Lighting
	end
end

function Overworld.build(parent: Instance)
	buildGround(parent)
	buildMountain(parent)
	buildMineEntrance(parent)
	buildWandererSpawn(parent)
	buildFlora(parent)
	buildRoads(parent)
	tuneSky()
end

return Overworld
