--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Cities
-- The four cities of the island, laid out like the reference map: circular
-- ring-walled cities, one per biome realm plus the neutral city inside the
-- mountain crater. White Cloud City in the snow (orthodox, north),
-- Blackfire City in the desert (demonic, southwest), Freewind City in the
-- forest (unorthodox, east), and Cloudrest, the free city, in the crater.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paths = require(Shared:WaitForChild("Data"):WaitForChild("Paths"))

local BuildKit = require(script.Parent.BuildKit)
local Island = require(script.Parent.Island)

local Cities = {}

-- City centers (ground level unless noted). Flora and roads read these.
Cities.POSITIONS = table.freeze({
	orthodox = Vector3.new(0, 0, -2560),
	demonic = Vector3.new(-2400, 0, 1320),
	unorthodox = Vector3.new(2480, 0, 960),
	central = Vector3.new(0, Island.VALLEY_Y, 0),
})

local TIMBER = Color3.fromRGB(74, 53, 39)

type CityTheme = {
	wall: Color3,
	wallMaterial: Enum.Material,
	roof: Color3,
	roofMaterial: Enum.Material?, -- nil = tile (Slate); Grass = thatch
	plaster: Color3,
	floor: Color3,
	floorMaterial: Enum.Material,
}

-- Palettes from the texture guide: white/stone/black tile for snow, sand
-- and red tile for desert, white stone and green tile for the forest city.
local THEMES: { [string]: CityTheme } = {
	orthodox = {
		wall = Color3.fromRGB(212, 216, 222),
		wallMaterial = Enum.Material.Slate,
		roof = Color3.fromRGB(43, 43, 50), -- tile roof black
		plaster = Color3.fromRGB(240, 240, 238),
		floor = Color3.fromRGB(198, 202, 210),
		floorMaterial = Enum.Material.Slate,
	},
	demonic = {
		wall = Color3.fromRGB(196, 156, 108),
		wallMaterial = Enum.Material.Sandstone,
		roof = Color3.fromRGB(143, 59, 46), -- tile roof red
		plaster = Color3.fromRGB(222, 191, 143),
		floor = Color3.fromRGB(186, 152, 105),
		floorMaterial = Enum.Material.Sandstone,
	},
	unorthodox = {
		wall = Color3.fromRGB(226, 222, 210),
		wallMaterial = Enum.Material.Slate,
		roof = Color3.fromRGB(185, 154, 74), -- thatch, like the reference
		roofMaterial = Enum.Material.Grass,
		plaster = Color3.fromRGB(237, 234, 224),
		floor = Color3.fromRGB(206, 202, 190),
		floorMaterial = Enum.Material.Cobblestone,
	},
	central = {
		wall = Color3.fromRGB(184, 180, 172),
		wallMaterial = Enum.Material.Slate,
		roof = Color3.fromRGB(74, 85, 96), -- slate blue
		plaster = Color3.fromRGB(238, 231, 214),
		floor = Color3.fromRGB(180, 174, 160),
		floorMaterial = Enum.Material.Cobblestone,
	},
}

-- A circular rampart with a gate gap facing `gateAngle` (radians from +X).
local function ringWall(parent: Instance, center: Vector3, radius: number, height: number, theme: CityTheme, gateAngle: number)
	local segments = 30
	local segmentLength = 2 * math.pi * radius / segments + 3
	for index = 1, segments do
		local angle = index / segments * math.pi * 2
		local delta = math.atan2(math.sin(angle - gateAngle), math.cos(angle - gateAngle))
		if math.abs(delta) < math.rad(10) then
			continue -- the gate opening
		end
		local position = center + Vector3.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		BuildKit.part({
			name = "CityWall",
			size = Vector3.new(4, height, segmentLength),
			cframe = CFrame.lookAt(position, position + tangent),
			color = theme.wall,
			material = theme.wallMaterial,
			parent = parent,
		})
		BuildKit.part({
			name = "CityWall_Coping",
			size = Vector3.new(7, 1.4, segmentLength + 1),
			cframe = CFrame.lookAt(position + Vector3.new(0, height / 2 + 0.7, 0), position + Vector3.new(0, height / 2 + 0.7, 0) + tangent),
			color = theme.roof,
			material = Enum.Material.Slate,
			parent = parent,
		})
	end
end

type CitySpec = {
	key: string, -- into POSITIONS/THEMES; also a path id except "central"
	radius: number,
	name: string,
	subtitle: string,
	accent: Color3,
}

local function buildCity(parent: Instance, spec: CitySpec)
	local center = Cities.POSITIONS[spec.key]
	local theme = THEMES[spec.key]
	local pathDef = Paths[spec.key] -- nil for the central city
	local radius = spec.radius

	local city = Instance.new("Folder")
	city.Name = spec.name:gsub("[%s,]", "")
	city.Parent = parent

	-- The gate faces the mountain (map origin); for the central city it
	-- faces the southern pass.
	local toCenter = if spec.key == "central"
		then Vector3.new(0, 0, 1)
		else (Vector3.new(-center.X, 0, -center.Z)).Unit
	local gateAngle = math.atan2(toCenter.Z, toCenter.X)

	-- Floor disc and walls.
	BuildKit.cylinder(city, "Plaza", center + Vector3.new(0, 0.5, 0), 1, radius * 2, theme.floor, theme.floorMaterial)
	ringWall(city, center, radius, 24, theme, gateAngle)

	-- Paifang at the gate.
	local gatePos = center + toCenter * (radius + 10)
	local sign = BuildKit.paifang(city, Vector3.new(gatePos.X, center.Y, gatePos.Z), toCenter, 44, TIMBER, theme.roof)
	BuildKit.billboard(sign, `{spec.name}\n{spec.subtitle}`, spec.accent, 18, 3, Vector3.new(0, 4, 0))

	-- Pagoda homes on two rings so the plaza reads as a lived-in city.
	local rings = {
		{ fraction = 0.44, count = 7, width = 40, depth = 32, stagger = 0.45 },
		{ fraction = 0.72, count = 11, width = 44, depth = 34, stagger = 0 },
	}
	for _, ring in rings do
		for index = 1, ring.count do
			local angle = index / ring.count * math.pi * 2 + ring.stagger
			local gateDelta = math.atan2(math.sin(angle - gateAngle), math.cos(angle - gateAngle))
			if math.abs(gateDelta) < math.rad(26) then
				continue -- keep the gate avenue open
			end
			if ring.fraction < 0.6 and math.abs(gateDelta) > math.rad(150) then
				continue -- the sect hall and shrine own the back of the inner ring
			end
			local homeCenter = center + Vector3.new(math.cos(angle) * radius * ring.fraction, 0, math.sin(angle) * radius * ring.fraction)
			BuildKit.pagodaHouse(city, homeCenter, ring.width, ring.depth, 2, theme.plaster, TIMBER, theme.roof, theme.roofMaterial)
		end
	end

	-- Cobbled avenues: gate to center, and a cross through the plaza.
	local roadColor = Color3.fromRGB(158, 150, 138)
	local function plazaRoad(from: Vector3, to: Vector3, width: number)
		local mid = (from + to) / 2 + Vector3.new(0, 0.85, 0)
		BuildKit.part({
			name = "Plaza_Road",
			size = Vector3.new(width, 0.5, (to - from).Magnitude),
			cframe = CFrame.lookAt(mid, Vector3.new(to.X, mid.Y, to.Z)),
			color = roadColor,
			material = Enum.Material.Cobblestone,
			canCollide = false,
			parent = city,
		})
	end
	local crossDir = Vector3.new(-toCenter.Z, 0, toCenter.X)
	plazaRoad(center + toCenter * radius, center - toCenter * radius * 0.35, 16)
	plazaRoad(center - crossDir * radius * 0.85, center + crossDir * radius * 0.85, 12)

	-- Central dais the shrine/waypost stands on.
	BuildKit.cylinder(city, "Plaza_Dais", center + Vector3.new(0, 1, 0) + (-toCenter) * radius * 0.22, 1.6, 70, roadColor, Enum.Material.Slate)

	-- Sect hall tower opposite the gate, shrine (or sign) before it.
	local backDir = -toCenter
	BuildKit.pagodaHouse(city, center + backDir * radius * 0.52, 56, 56, 4, theme.plaster, TIMBER, theme.roof, theme.roofMaterial)

	local shrinePos = center + backDir * radius * 0.22
	if pathDef then
		local dais = BuildKit.cylinder(city, "Shrine_Dais", shrinePos + Vector3.new(0, 1, 0), 2, 22, spec.accent, Enum.Material.Marble)
		local monolith = BuildKit.part({
			name = "Shrine",
			size = Vector3.new(5, 13, 2.5),
			position = shrinePos + Vector3.new(0, 8.5, 0),
			color = theme.wall,
			material = Enum.Material.Marble,
			parent = city,
		})
		monolith:SetAttribute("PathId", spec.key)
		CollectionService:AddTag(monolith, "PathShrine")
		BuildKit.prompt(monolith, "Pledge", pathDef.name, 2, nil)
		BuildKit.billboard(monolith, `Shrine of the {pathDef.name}\n"{pathDef.blurb}"`, spec.accent, 22, 3.4, Vector3.new(0, 9, 0))
		BuildKit.pointLight(dais, spec.accent, 2, 30)
		BuildKit.pavilion(city, shrinePos, 24, TIMBER, theme.roof)
	else
		local waypost = BuildKit.part({
			name = "Waypost",
			size = Vector3.new(2, 10, 2),
			position = shrinePos + Vector3.new(0, 5, 0),
			color = TIMBER,
			material = Enum.Material.Wood,
			parent = city,
		})
		BuildKit.billboard(waypost, "Cloudrest, the free city. Three realms, three paths, one mountain.\nThe Deep Mines lie through the southern pass.", spec.accent, 24, 3, Vector3.new(0, 7, 0))
	end

	-- Spawn, lanterns, sanctuary, and gate dummies.
	local spawnColor = if pathDef then pathDef.teamBrickColor else "Medium stone grey"
	BuildKit.spawnLocation(city, shrinePos + toCenter * 18 + Vector3.new(0, 1, 0), spawnColor, false)

	local lanternRed = Color3.fromRGB(210, 60, 45)
	for index = 1, 10 do
		local angle = index / 10 * math.pi * 2 + 0.3
		local post = BuildKit.part({
			name = "Lantern",
			size = Vector3.new(1, 11, 1),
			position = center + Vector3.new(math.cos(angle) * radius * 0.86, 5.5, math.sin(angle) * radius * 0.86),
			color = TIMBER,
			material = Enum.Material.Wood,
			parent = city,
		})
		local lamp = BuildKit.part({
			name = "Lantern_Light",
			size = Vector3.new(2.2, 2.8, 2.2),
			position = post.Position + Vector3.new(0, 6.5, 0),
			color = lanternRed,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = city,
		})
		BuildKit.pointLight(lamp, Color3.fromRGB(255, 150, 110), 1.6, 26)
	end

	BuildKit.safeZone(city, center, radius * 1.05)

	for i = -1, 1 do
		local side = Vector3.new(-toCenter.Z, 0, toCenter.X)
		BuildKit.trainingDummy(city, Vector3.new(gatePos.X, center.Y, gatePos.Z) + side * (i * 16) + toCenter * 26)
	end
end

function Cities.build(parent: Instance)
	local specs: { CitySpec } = {
		{
			key = "orthodox",
			radius = 260,
			name = Paths.orthodox.cityName,
			subtitle = Paths.orthodox.name,
			accent = Paths.orthodox.accentColor,
		},
		{
			key = "demonic",
			radius = 260,
			name = Paths.demonic.cityName,
			subtitle = Paths.demonic.name,
			accent = Paths.demonic.accentColor,
		},
		{
			key = "unorthodox",
			radius = 260,
			name = Paths.unorthodox.cityName,
			subtitle = Paths.unorthodox.name,
			accent = Paths.unorthodox.accentColor,
		},
		{
			key = "central",
			radius = 330,
			name = "Cloudrest",
			subtitle = "The Free City",
			accent = Color3.fromRGB(235, 230, 215),
		},
	}
	for _, spec in specs do
		buildCity(parent, spec)
	end
end

return Cities
