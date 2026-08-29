--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Overworld
-- Built things on the island's surface: the road web connecting the four
-- cities, the grand stair down from the crater's southern pass, the mine
-- gate, river bridges, the dark pagoda on the north peak, waterfall
-- dressing, and the sky. The land itself is sculpted by World/Island.

local Lighting = game:GetService("Lighting")

local BuildKit = require(script.Parent.BuildKit)
local Island = require(script.Parent.Island)
local Cities = require(script.Parent.Cities)

local Overworld = {}

-- The mine shaft opening south of the crater (Underworld builds against it;
-- Island carves the terrain hollow around it).
Overworld.GROUND_TOP = 0
Overworld.HOLE = { x1 = -15, x2 = 15, z1 = 240, z2 = 300 }

local ROCK_DARK = Color3.fromRGB(92, 88, 90)
local ROAD_COLOR = Color3.fromRGB(203, 184, 148) -- the map's tan paths
local STAIR_COLOR = Color3.fromRGB(168, 162, 152)

-- ------------------------------- Roads ----------------------------------

local function road(parent: Instance, from: Vector3, to: Vector3, width: number)
	local mid = (from + to) / 2 + Vector3.new(0, 0.25, 0)
	BuildKit.part({
		name = "Road",
		size = Vector3.new(width, 0.4, (to - from).Magnitude + width * 0.5),
		cframe = CFrame.lookAt(mid, Vector3.new(to.X, mid.Y, to.Z)),
		color = ROAD_COLOR,
		material = Enum.Material.Ground,
		canCollide = false,
		parent = parent,
	})
end

local function ringRoad(parent: Instance, radius: number, segments: number)
	for index = 1, segments do
		local a1 = (index - 1) / segments * math.pi * 2
		local a2 = index / segments * math.pi * 2
		road(parent,
			Vector3.new(math.sin(a1) * radius, 0, math.cos(a1) * radius),
			Vector3.new(math.sin(a2) * radius, 0, math.cos(a2) * radius),
			9)
	end
end

local function buildRoads(parent: Instance)
	-- Inner ring skirts the mountains; outer ring laces the island, like
	-- the reference's web of tan paths.
	ringRoad(parent, 320, 24)
	ringRoad(parent, 620, 30)

	-- Spokes from the inner ring out to each biome city's gate.
	for _, key in { "orthodox", "demonic", "unorthodox" } do
		local center = Cities.POSITIONS[key]
		local direction = Vector3.new(center.X, 0, center.Z).Unit
		road(parent, direction * 320, Vector3.new(center.X, 0, center.Z) - direction * 100, 9)
	end

	-- Southern pass: stair landing to the mine gate and on to the ring.
	road(parent, Vector3.new(0, 0, 228), Vector3.new(0, 0, 320), 9)

	-- Wooden bridges where the spokes cross the rivers.
	local bridges = {
		{ position = Vector3.new(420, 0, -8), rotation = 20 },
		{ position = Vector3.new(360, 0, 330), rotation = -30 },
		{ position = Vector3.new(700, 0, 560), rotation = -35 },
	}
	for _, bridge in bridges do
		local deck = BuildKit.part({
			name = "Bridge",
			size = Vector3.new(14, 1.5, 40),
			cframe = CFrame.new(bridge.position + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, math.rad(bridge.rotation), 0),
			color = Color3.fromRGB(133, 100, 68),
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
		for side = -1, 1, 2 do
			BuildKit.part({
				name = "Bridge_Rail",
				size = Vector3.new(1, 2.4, 40),
				cframe = deck.CFrame * CFrame.new(side * 6.5, 1.9, 0),
				color = Color3.fromRGB(94, 70, 48),
				material = Enum.Material.Wood,
				parent = parent,
			})
		end
	end
end

-- --------------------------- The grand stair ----------------------------

local function buildCraterStair(parent: Instance)
	local steps = 14
	local topY = Island.VALLEY_Y
	local fromZ = 150
	local toZ = 228
	for index = 0, steps do
		local t = index / steps
		BuildKit.part({
			name = "GrandStair",
			size = Vector3.new(26, 2.2, (toZ - fromZ) / steps + 1.5),
			position = Vector3.new(0, topY - t * topY - 0.4, fromZ + t * (toZ - fromZ)),
			color = STAIR_COLOR,
			material = Enum.Material.Cobblestone,
			parent = parent,
		})
	end
	-- Flanking balustrades.
	for side = -1, 1, 2 do
		local from = Vector3.new(side * 14, topY + 1, fromZ)
		local to = Vector3.new(side * 14, 1, toZ)
		local mid = (from + to) / 2
		BuildKit.part({
			name = "GrandStair_Rail",
			size = Vector3.new(1.6, 3, (to - from).Magnitude + 2),
			cframe = CFrame.lookAt(mid, to),
			color = STAIR_COLOR,
			material = Enum.Material.Slate,
			parent = parent,
		})
	end
end

-- ------------------------------ Mine gate -------------------------------

local function buildMineEntrance(parent: Instance)
	local hole = Overworld.HOLE
	local gateZ = hole.z1 - 2
	for _, x in { hole.x1 - 2, hole.x2 + 2 } do
		BuildKit.part({
			name = "MineGate_Pillar",
			size = Vector3.new(4, 18, 4),
			position = Vector3.new(x, 9, gateZ),
			color = ROCK_DARK,
			material = Enum.Material.Slate,
			parent = parent,
		})
	end
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

-- ------------------- North peak pagoda and waterfall --------------------

local function buildNorthPeak(parent: Instance)
	local summit = Vector3.new(Island.NORTH_PEAK.X, Island.NORTH_PEAK_TOP, Island.NORTH_PEAK.Z)
	-- The dark pagoda from the reference, brooding over the falls.
	BuildKit.pagodaHouse(parent, summit, 26, 26, 3,
		Color3.fromRGB(62, 50, 48), Color3.fromRGB(34, 28, 26), Color3.fromRGB(48, 26, 26))
	local platform = BuildKit.cylinder(parent, "Summit_Platform", summit + Vector3.new(0, 0.5, 24), 1, 26,
		Color3.fromRGB(210, 205, 190), Enum.Material.Marble)
	BuildKit.billboard(platform, "The Summit of Heavenpillar. Meditate above the falls.", Color3.fromRGB(255, 235, 180), 18, 1.8, Vector3.new(0, 6, 0))

	-- Waterfall dressing: foam at the pool and drifting mist.
	local poolCenter = Vector3.new(0, Island.VALLEY_Y + 0.4, -112)
	local foam = BuildKit.cylinder(parent, "Waterfall_Foam", poolCenter, 0.6, 30, Color3.fromRGB(235, 245, 250), Enum.Material.SmoothPlastic)
	foam.Transparency = 0.45
	foam.CanCollide = false
	local mistAnchor = BuildKit.part({
		name = "Waterfall_Mist",
		size = Vector3.new(1, 1, 1),
		position = poolCenter + Vector3.new(0, 6, -20),
		transparency = 1,
		canCollide = false,
		parent = parent,
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Rate = 8
	mist.Lifetime = NumberRange.new(2, 4)
	mist.Speed = NumberRange.new(1, 3)
	mist.Size = NumberSequence.new(8, 16)
	mist.Transparency = NumberSequence.new(0.75, 1)
	mist.Color = ColorSequence.new(Color3.fromRGB(230, 240, 250))
	mist.Parent = mistAnchor
end

-- -------------------------------- Sky -----------------------------------

local function tuneSky()
	Lighting.ClockTime = 14.4
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	if Lighting:FindFirstChildOfClass("Atmosphere") == nil then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.4
		atmosphere.Color = Color3.fromRGB(199, 199, 214)
		atmosphere.Decay = Color3.fromRGB(106, 112, 125)
		atmosphere.Haze = 1.6
		atmosphere.Parent = Lighting
	end
end

function Overworld.build(parent: Instance)
	buildRoads(parent)
	buildCraterStair(parent)
	buildMineEntrance(parent)
	buildNorthPeak(parent)
	tuneSky()
end

return Overworld
