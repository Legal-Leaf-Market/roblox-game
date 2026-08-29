--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Cities
-- The three path cities, ringed around Heavenpillar Mountain: White Cloud
-- City (orthodox, north), Freewind City (unorthodox, southeast), Blackfire
-- City (demonic, southwest). Each is a walled plaza with a pledge shrine,
-- team spawn, homes, lanterns and training dummies outside the gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paths = require(Shared:WaitForChild("Data"):WaitForChild("Paths"))

local BuildKit = require(script.Parent.BuildKit)

local Cities = {}

local CITY_RADIUS = 380
local PLAZA = 150 -- plaza edge length
local WALL_HEIGHT = 20
local WALL_THICKNESS = 4
local GATE_WIDTH = 30

type CitySpec = {
	pathId: string,
	angle: number, -- degrees around the mountain, 0 = +Z (south)
}

local SPECS: { CitySpec } = {
	{ pathId = "orthodox", angle = 180 }, -- north
	{ pathId = "unorthodox", angle = 60 }, -- southeast
	{ pathId = "demonic", angle = -60 }, -- southwest
}

local function buildCity(parent: Instance, spec: CitySpec)
	local path = Paths[spec.pathId]
	local rad = math.rad(spec.angle)
	local center = Vector3.new(math.sin(rad) * CITY_RADIUS, 0, math.cos(rad) * CITY_RADIUS)
	-- The gate faces the mountain (map origin).
	local toMountain = (Vector3.zero - center) * Vector3.new(1, 0, 1)
	local gateDir = toMountain.Unit

	local city = Instance.new("Folder")
	city.Name = path.cityName:gsub(" ", "")
	city.Parent = parent

	local stone = path.primaryColor
	local accent = path.accentColor
	local half = PLAZA / 2

	-- Plaza floor.
	BuildKit.part({
		name = "Plaza",
		size = Vector3.new(PLAZA, 1, PLAZA),
		position = center + Vector3.new(0, 0.5, 0),
		color = stone,
		material = Enum.Material.Cobblestone,
		parent = city,
	})

	-- Walls with a gate on the mountain-facing side. Cities are axis-
	-- aligned; the gate goes in whichever wall faces the mountain most.
	local north = center.Z - half
	local south = center.Z + half
	local west = center.X - half
	local east = center.X + half
	local gateOnZ = math.abs(gateDir.Z) >= math.abs(gateDir.X)
	local gateNorth = gateOnZ and gateDir.Z < 0
	local gateSouth = gateOnZ and gateDir.Z >= 0
	local gateWest = not gateOnZ and gateDir.X < 0
	local gateEast = not gateOnZ and gateDir.X >= 0

	BuildKit.wallX(city, "Wall_N", north, west, east, 0, WALL_HEIGHT, WALL_THICKNESS, stone, Enum.Material.Slate,
		if gateNorth then center.X else nil, if gateNorth then GATE_WIDTH else nil)
	BuildKit.wallX(city, "Wall_S", south, west, east, 0, WALL_HEIGHT, WALL_THICKNESS, stone, Enum.Material.Slate,
		if gateSouth then center.X else nil, if gateSouth then GATE_WIDTH else nil)
	BuildKit.wallZ(city, "Wall_W", west, north, south, 0, WALL_HEIGHT, WALL_THICKNESS, stone, Enum.Material.Slate,
		if gateWest then center.Z else nil, if gateWest then GATE_WIDTH else nil)
	BuildKit.wallZ(city, "Wall_E", east, north, south, 0, WALL_HEIGHT, WALL_THICKNESS, stone, Enum.Material.Slate,
		if gateEast then center.Z else nil, if gateEast then GATE_WIDTH else nil)

	-- Gate sign floating over the opening.
	local gateWallPos: Vector3
	if gateNorth then
		gateWallPos = Vector3.new(center.X, WALL_HEIGHT + 4, north)
	elseif gateSouth then
		gateWallPos = Vector3.new(center.X, WALL_HEIGHT + 4, south)
	elseif gateWest then
		gateWallPos = Vector3.new(west, WALL_HEIGHT + 4, center.Z)
	else
		gateWallPos = Vector3.new(east, WALL_HEIGHT + 4, center.Z)
	end
	local signPost = BuildKit.part({
		name = "GateSign",
		size = Vector3.new(2, 2, 2),
		position = gateWallPos,
		color = accent,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = city,
	})
	BuildKit.billboard(signPost, `{path.cityName}\n{path.name}`, accent, 18, 3, Vector3.new(0, 3, 0))

	-- Pledge shrine at the back of the plaza (opposite the gate).
	local shrinePos = center - gateDir * (half * 0.55)
	local dais = BuildKit.cylinder(city, "Shrine_Dais", shrinePos + Vector3.new(0, 1, 0), 2, 22, accent, Enum.Material.Marble)
	local monolith = BuildKit.part({
		name = "Shrine",
		size = Vector3.new(5, 13, 2.5),
		position = shrinePos + Vector3.new(0, 8.5, 0),
		color = stone,
		material = Enum.Material.Marble,
		parent = city,
	})
	monolith:SetAttribute("PathId", spec.pathId)
	CollectionService:AddTag(monolith, "PathShrine")
	BuildKit.prompt(monolith, "Pledge", path.name, 2, nil)
	BuildKit.billboard(monolith, `Shrine of the {path.name}\n"{path.blurb}"`, accent, 22, 3.4, Vector3.new(0, 9, 0))
	BuildKit.pointLight(dais, accent, 2, 30)

	-- Team spawn beside the shrine.
	BuildKit.spawnLocation(city, shrinePos + gateDir * 18 + Vector3.new(0, 1, 0), path.teamBrickColor, false)

	-- Homes in the four plaza corners.
	for cx = -1, 1, 2 do
		for cz = -1, 1, 2 do
			local homeCenter = center + Vector3.new(cx * half * 0.6, 0, cz * half * 0.6)
			-- Skip the corner the shrine sits nearest.
			if (homeCenter - shrinePos).Magnitude < 30 then
				continue
			end
			BuildKit.part({
				name = "Home",
				size = Vector3.new(24, 12, 20),
				position = homeCenter + Vector3.new(0, 6, 0),
				color = stone,
				material = Enum.Material.WoodPlanks,
				parent = city,
			})
			BuildKit.part({
				name = "Home_Roof",
				size = Vector3.new(30, 2, 26),
				position = homeCenter + Vector3.new(0, 13, 0),
				color = accent,
				material = Enum.Material.Slate,
				parent = city,
			})
		end
	end

	-- Lantern posts at the plaza corners.
	for cx = -1, 1, 2 do
		for cz = -1, 1, 2 do
			local post = BuildKit.part({
				name = "Lantern",
				size = Vector3.new(1, 11, 1),
				position = center + Vector3.new(cx * (half - 8), 5.5, cz * (half - 8)),
				color = Color3.fromRGB(60, 50, 45),
				material = Enum.Material.Wood,
				parent = city,
			})
			local lamp = BuildKit.part({
				name = "Lantern_Light",
				size = Vector3.new(2, 2.6, 2),
				position = post.Position + Vector3.new(0, 6.5, 0),
				color = accent,
				material = Enum.Material.Neon,
				canCollide = false,
				parent = city,
			})
			BuildKit.pointLight(lamp, accent, 1.6, 26)
		end
	end

	-- The whole city is sanctuary.
	BuildKit.safeZone(city, center, PLAZA * 0.75)

	-- Training dummies outside the gate, toward the mountain.
	local gatePos = center + gateDir * (half + 14)
	for i = -1, 1 do
		local side = Vector3.new(-gateDir.Z, 0, gateDir.X) -- perpendicular
		BuildKit.trainingDummy(city, gatePos + side * (i * 12) + gateDir * 16)
	end
end

function Cities.build(parent: Instance)
	for _, spec in SPECS do
		buildCity(parent, spec)
	end
end

return Cities
