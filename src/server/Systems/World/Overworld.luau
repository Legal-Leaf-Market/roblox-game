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

local function buildTrees(parent: Instance)
	local rng = Random.new(7) -- deterministic: same forest every server
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(470, 900)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local height = rng:NextNumber(12, 20)
		BuildKit.part({
			name = "Tree_Trunk",
			size = Vector3.new(2, height, 2),
			position = Vector3.new(x, Overworld.GROUND_TOP + height / 2, z),
			color = Color3.fromRGB(105, 80, 60),
			material = Enum.Material.Wood,
			parent = parent,
		})
		BuildKit.part({
			name = "Tree_Canopy",
			size = Vector3.new(rng:NextNumber(9, 14), rng:NextNumber(7, 10), rng:NextNumber(9, 14)),
			position = Vector3.new(x, Overworld.GROUND_TOP + height + 3, z),
			color = if rng:NextNumber() < 0.35 then Color3.fromRGB(235, 170, 200) else Color3.fromRGB(90, 150, 90),
			material = Enum.Material.Grass,
			canCollide = false,
			parent = parent,
		})
	end
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
	buildTrees(parent)
	tuneSky()
end

return Overworld
