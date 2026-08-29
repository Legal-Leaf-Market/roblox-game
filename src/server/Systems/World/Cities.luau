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

-- Everything each city actually placed (buildings, stalls, shrine, hall),
-- as {x, z, r} discs. Filled during build; Flora reads it so in-city trees
-- stop growing through houses.
export type Footprint = { x: number, z: number, r: number }
Cities.FOOTPRINTS = {} :: { [string]: { Footprint } }

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

-- A circular rampart with a gate gap facing `gateAngle` (radians from +X):
-- skirted base, tall curtain, tiled coping, crenellated parapet, and
-- roofed watchtowers on the ring.
local GATE_HALF_ANGLE = math.rad(8)

local function ringWall(parent: Instance, center: Vector3, radius: number, height: number, theme: CityTheme, gateAngle: number)
	local segments = 36
	local segmentLength = 2 * math.pi * radius / segments + 3
	for index = 1, segments do
		local angle = index / segments * math.pi * 2
		local delta = math.atan2(math.sin(angle - gateAngle), math.cos(angle - gateAngle))
		if math.abs(delta) < GATE_HALF_ANGLE then
			continue -- the gate opening
		end
		local position = center + Vector3.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local wallCF = CFrame.lookAt(position, position + tangent)
		BuildKit.part({
			name = "CityWall",
			size = Vector3.new(7, height, segmentLength),
			cframe = wallCF,
			color = theme.wall,
			material = theme.wallMaterial,
			parent = parent,
		})
		BuildKit.part({
			name = "CityWall_Skirt",
			size = Vector3.new(10, 4, segmentLength + 1),
			cframe = wallCF * CFrame.new(0, -height / 2 + 2, 0),
			color = theme.wall,
			material = Enum.Material.Cobblestone,
			parent = parent,
		})
		BuildKit.part({
			name = "CityWall_Coping",
			size = Vector3.new(10.5, 1.6, segmentLength + 1),
			cframe = wallCF * CFrame.new(0, height / 2 + 0.8, 0),
			color = theme.roof,
			material = Enum.Material.Slate,
			parent = parent,
		})
		-- Crenellated parapet along the outer lip. Merlons are small and
		-- many; they read fine without shadows and there are ~600 of them.
		local merlons = math.floor(segmentLength / 12)
		for merlonIndex = 1, merlons do
			local along = (merlonIndex - 0.5) / merlons * segmentLength - segmentLength / 2
			BuildKit.part({
				name = "CityWall_Merlon",
				size = Vector3.new(3, 3.2, 4.5),
				cframe = wallCF * CFrame.new(-4, height / 2 + 3.2, along),
				color = theme.wall,
				material = theme.wallMaterial,
				castShadow = false,
				parent = parent,
			})
		end
	end

	-- Watchtowers on the ring, skipping the gate bearing.
	for towerIndex = 1, 8 do
		local angle = towerIndex / 8 * math.pi * 2 + math.pi / 8
		local delta = math.atan2(math.sin(angle - gateAngle), math.cos(angle - gateAngle))
		if math.abs(delta) < math.rad(24) then
			continue
		end
		local towerPos = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		BuildKit.cylinder(parent, "Wall_Tower", towerPos + Vector3.new(0, (height + 14) / 2, 0), height + 14, 18, theme.wall, theme.wallMaterial)
		BuildKit.roofCF(parent, CFrame.new(towerPos.X, towerPos.Y, towerPos.Z), 14, 14, height + 14, theme.roof, theme.roofMaterial)
		local beacon = BuildKit.part({
			name = "Wall_TowerLantern",
			size = Vector3.new(2, 2.4, 2),
			position = towerPos + Vector3.new(0, height + 11, 0),
			color = Color3.fromRGB(214, 58, 44),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = parent,
		})
		BuildKit.pointLight(beacon, Color3.fromRGB(255, 150, 100), 1.4, 30)
	end
end

-- A proper city gatehouse: flanking square towers with tiled caps, a
-- roofed arch bridging them, a name board, guardian lions, lanterns, and
-- wall stubs closing the curtain up to the towers.
local function gatehouse(parent: Instance, center: Vector3, radius: number, theme: CityTheme, toCenter: Vector3, wallHeight: number): Part
	local gatePos = Vector3.new(center.X + toCenter.X * radius, center.Y, center.Z + toCenter.Z * radius)
	local cf = CFrame.lookAt(gatePos, gatePos + toCenter) -- -Z faces out of the city
	local function at(offset: Vector3): CFrame
		return cf * CFrame.new(offset)
	end

	for towerSign = -1, 1, 2 do
		BuildKit.part({
			name = "Gate_Tower",
			size = Vector3.new(14, wallHeight + 18, 14),
			cframe = at(Vector3.new(towerSign * 32, (wallHeight + 18) / 2, 0)),
			color = theme.wall,
			material = theme.wallMaterial,
			parent = parent,
		})
		BuildKit.roofCF(parent, cf * CFrame.new(towerSign * 32, 0, 0), 13, 13, wallHeight + 18, theme.roof, theme.roofMaterial)
		local lantern = BuildKit.part({
			name = "Gate_Lantern",
			size = Vector3.new(2.4, 3, 2.4),
			cframe = at(Vector3.new(towerSign * 32, wallHeight - 2, -9)),
			color = Color3.fromRGB(214, 58, 44),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = parent,
		})
		BuildKit.pointLight(lantern, Color3.fromRGB(255, 150, 100), 1.6, 30)
	end

	-- Arch beam and its roof bridge the towers.
	BuildKit.part({
		name = "Gate_Arch",
		size = Vector3.new(52, 9, 12),
		cframe = at(Vector3.new(0, wallHeight + 4, 0)),
		color = theme.wall,
		material = theme.wallMaterial,
		parent = parent,
	})
	BuildKit.roofCF(parent, cf, 48, 16, wallHeight + 8.5, theme.roof, theme.roofMaterial)

	-- The name board hangs on the OUTER face (-Z is out of the city): the
	-- traveler arriving reads it; before this it greeted people leaving.
	local board = BuildKit.part({
		name = "Gate_Board",
		size = Vector3.new(24, 6, 1.6),
		cframe = at(Vector3.new(0, wallHeight + 1, -7)),
		color = Color3.fromRGB(32, 28, 26),
		material = Enum.Material.Wood,
		canCollide = false,
		parent = parent,
	})

	-- Guardian lions flank the approach OUTSIDE the gate, as guardian
	-- lions do; they had been placed inside, watching residents' backs.
	for lionSign = -1, 1, 2 do
		BuildKit.part({
			name = "Gate_LionPedestal",
			size = Vector3.new(7, 5, 7),
			cframe = at(Vector3.new(lionSign * 20, 2.5, -14)),
			color = Color3.fromRGB(148, 146, 142),
			material = Enum.Material.Slate,
			parent = parent,
		})
		BuildKit.part({
			name = "Gate_Lion",
			size = Vector3.new(4.5, 5.5, 6.5),
			cframe = at(Vector3.new(lionSign * 20, 7.5, -14)) * CFrame.Angles(0, math.rad(lionSign * 8 + 180), math.rad(lionSign * 4)),
			color = Color3.fromRGB(126, 122, 116),
			material = Enum.Material.Slate,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
	end

	-- Close the curtain from the towers to the wall ends.
	local gapChord = 2 * radius * math.sin(GATE_HALF_ANGLE)
	local stubLength = gapChord / 2 - 39
	if stubLength > 3 then
		for stubSign = -1, 1, 2 do
			BuildKit.part({
				name = "Gate_WallStub",
				size = Vector3.new(stubLength, wallHeight, 7),
				cframe = at(Vector3.new(stubSign * (39 + stubLength / 2), wallHeight / 2, 0)),
				color = theme.wall,
				material = theme.wallMaterial,
				parent = parent,
			})
		end
	end
	return board
end

type CitySpec = {
	key: string, -- into POSITIONS/THEMES; also a path id except "central"
	radius: number,
	name: string,
	subtitle: string,
	accent: Color3,
}

-- How each city carries itself: seed (its own village layout), snap
-- (orderly compass-aligned vs loose organic rotation), mixThatch (some
-- roofs go straw, Freewind's habit).
local PERSONALITIES: { [string]: { seed: number, snap: boolean, mixThatch: boolean } } = {
	orthodox = { seed = 101, snap = true, mixThatch = false },
	demonic = { seed = 202, snap = false, mixThatch = false },
	unorthodox = { seed = 303, snap = false, mixThatch = true },
	central = { seed = 404, snap = true, mixThatch = false },
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
	BuildKit.cylinder(city, "Plaza", center + Vector3.new(0, 0.2, 0), 0.8, radius * 2, theme.floor, theme.floorMaterial)
	ringWall(city, center, radius, 30, theme, gateAngle)

	-- The gatehouse carries the city's name board.
	local gatePos = center + toCenter * (radius + 10)
	local board = gatehouse(city, center, radius, theme, toCenter, 30)
	BuildKit.billboard(board, `{spec.name}\n{spec.subtitle}`, spec.accent, 18, 3, Vector3.new(0, 5, 0))

	-- Organic village scatter, in the reference's manner: a seeded mix of
	-- building styles dropped with collision checks, keeping the gate
	-- avenue, the dais, and the sect hall's ground clear. Each city has a
	-- personality: orderly (snapped to the compass) or loose.
	local personality = PERSONALITIES[spec.key]
	local rng = Random.new(personality.seed)
	local sectHallPos = center + (-toCenter) * radius * 0.52
	local shrineFocus = center + (-toCenter) * radius * 0.22
	local crossDirEarly = Vector3.new(-toCenter.Z, 0, toCenter.X)

	local placed: { Footprint } = {}
	Cities.FOOTPRINTS[spec.key] = placed

	local function tryPlace(buildingW: number, buildingD: number, build: (CFrame) -> ())
		local footprint = math.max(buildingW, buildingD) / 2 + 8
		for _ = 1, 40 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(0.18, 0.86) * radius
			local x = center.X + math.cos(angle) * dist
			local z = center.Z + math.sin(angle) * dist
			local toSpot = Vector3.new(x - center.X, 0, z - center.Z)
			-- Keep the gate avenue open: reject spots near the center-gate line.
			local along = toSpot:Dot(toCenter)
			local lateral = (toSpot - toCenter * along).Magnitude
			if along > 0 and lateral < 26 + footprint * 0.4 then
				continue
			end
			-- And the cross avenue: buildings were straddling it.
			local alongCross = toSpot:Dot(crossDirEarly)
			local lateralCross = (toSpot - crossDirEarly * alongCross).Magnitude
			if math.abs(alongCross) < radius * 0.88 and lateralCross < 14 + footprint * 0.4 then
				continue
			end
			-- The sect compound (walled court) and shrine keep wide ground.
			if (Vector3.new(x, 0, z) - Vector3.new(sectHallPos.X, 0, sectHallPos.Z)).Magnitude < footprint + 64 then
				continue
			end
			if (Vector3.new(x, 0, z) - Vector3.new(shrineFocus.X, 0, shrineFocus.Z)).Magnitude < footprint + 44 then
				continue
			end
			local clear = true
			for _, other in placed do
				local dx = x - other.x
				local dz = z - other.z
				if math.sqrt(dx * dx + dz * dz) < footprint + other.r then
					clear = false
					break
				end
			end
			if not clear then
				continue
			end
			table.insert(placed, { x = x, z = z, r = footprint })
			local yaw = if personality.snap
				then rng:NextInteger(0, 3) * math.pi / 2
				else rng:NextNumber(0, math.pi * 2)
			build(CFrame.new(x, center.Y, z) * CFrame.Angles(0, yaw, 0))
			return
		end
	end

	local function roofFor(): (Color3, Enum.Material?)
		if personality.mixThatch and rng:NextNumber() < 0.45 then
			return Color3.fromRGB(185, 154, 74), Enum.Material.Grass
		end
		return theme.roof, theme.roofMaterial
	end

	local mix = {
		{ count = 13, style = "house", floors = 2, w = 44, d = 34 },
		{ count = 12, style = "house", floors = 1, w = 38, d = 30 },
		{ count = 11, style = "hut", floors = 1, w = 24, d = 18 },
		{ count = 4, style = "hall", floors = 1, w = 70, d = 34 },
		{ count = 3, style = "tower", floors = 3, w = 28, d = 28 },
	}
	for _, entry in mix do
		for _ = 1, entry.count do
			tryPlace(entry.w, entry.d, function(cf)
				local roofColor, roofMaterial = roofFor()
				BuildKit.house(city, cf, {
					width = entry.w,
					depth = entry.d,
					floors = entry.floors,
					plaster = theme.plaster,
					timber = TIMBER,
					roofColor = roofColor,
					roofMaterial = roofMaterial,
					style = entry.style,
					-- Halls and towers matter; only they spend PointLights.
					lanternLights = entry.style == "hall" or entry.style == "tower",
				})
				-- The odd attached wing makes an L-shaped compound.
				if entry.style == "house" and entry.floors == 2 and rng:NextNumber() < 0.35 then
					BuildKit.house(city, cf * CFrame.new(entry.w / 2 + 12, 0, 4), {
						width = 22,
						depth = 16,
						floors = 1,
						plaster = theme.plaster,
						timber = TIMBER,
						roofColor = roofColor,
						roofMaterial = roofMaterial,
						style = "hut",
					})
				end
			end)
		end
	end

	-- Cobbled avenues: gate to center, and a cross through the plaza.
	local roadColor = Color3.fromRGB(158, 150, 138)
	local function plazaRoad(from: Vector3, to: Vector3, width: number)
		local mid = (from + to) / 2 + Vector3.new(0, 0.45, 0)
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

	-- ------------------- The sect compound -------------------
	-- The pagoda opposite the gate is the city's seat of power, and a seat
	-- of power has a forecourt: low walls with a gap facing the plaza,
	-- banner poles, stone lanterns, mats and dummies to train on. This is
	-- what makes it read as a sect, not a tall house.
	local backDir = -toCenter
	-- Oriented so the pagoda's door faces the plaza; the axis-aligned
	-- wrapper had every city's hall staring at world +Z, walls or not.
	BuildKit.house(city, CFrame.lookAt(sectHallPos, sectHallPos - toCenter), {
		width = 56,
		depth = 56,
		floors = 4,
		plaster = theme.plaster,
		timber = TIMBER,
		roofColor = theme.roof,
		roofMaterial = theme.roofMaterial,
		lanternLights = true,
	})
	table.insert(placed, { x = sectHallPos.X, z = sectHallPos.Z, r = 60 })

	local courtHalf = 52
	local courtGap = 20
	do
		local courtCF = CFrame.lookAt(sectHallPos, sectHallPos + toCenter) -- -Z faces the plaza
		local wallColor = theme.wall
		local function courtWall(offset: Vector3, size: Vector3)
			BuildKit.part({
				name = "SectCourt_Wall",
				size = size,
				cframe = courtCF * CFrame.new(offset),
				color = wallColor,
				material = theme.wallMaterial,
				parent = city,
			})
		end
		-- Back and side walls solid; the front wall opens toward the plaza.
		courtWall(Vector3.new(0, 3, courtHalf), Vector3.new(courtHalf * 2, 6, 2))
		courtWall(Vector3.new(-courtHalf, 3, 0), Vector3.new(2, 6, courtHalf * 2))
		courtWall(Vector3.new(courtHalf, 3, 0), Vector3.new(2, 6, courtHalf * 2))
		local frontSeg = courtHalf - courtGap / 2
		courtWall(Vector3.new(-(courtGap / 2 + frontSeg / 2), 3, -courtHalf), Vector3.new(frontSeg, 6, 2))
		courtWall(Vector3.new(courtGap / 2 + frontSeg / 2, 3, -courtHalf), Vector3.new(frontSeg, 6, 2))
		-- Court ground: packed gravel, flush with the plaza.
		BuildKit.part({
			name = "SectCourt_Ground",
			size = Vector3.new(courtHalf * 2 - 2, 0.5, courtHalf * 2 - 2),
			cframe = courtCF * CFrame.new(0, 0.65, 0),
			color = Color3.fromRGB(168, 158, 140),
			material = Enum.Material.Ground,
			canCollide = false,
			parent = city,
		})
		-- Banner poles flank the court gate, hung with the path's color.
		for bannerSign = -1, 1, 2 do
			local poleBase = courtCF * CFrame.new(bannerSign * (courtGap / 2 + 4), 0, -courtHalf)
			BuildKit.part({
				name = "SectCourt_BannerPole",
				size = Vector3.new(1.2, 26, 1.2),
				cframe = poleBase * CFrame.new(0, 13, 0),
				color = TIMBER,
				material = Enum.Material.Wood,
				parent = city,
			})
			BuildKit.part({
				name = "SectCourt_Banner",
				size = Vector3.new(4.6, 14, 0.3),
				cframe = poleBase * CFrame.new(bannerSign * 2.9, 17, 0),
				color = spec.accent,
				material = Enum.Material.Fabric,
				canCollide = false,
				castShadow = false,
				parent = city,
			})
			-- Stone lantern by each pole.
			local stoneLantern = BuildKit.part({
				name = "SectCourt_StoneLantern",
				size = Vector3.new(2.2, 5, 2.2),
				cframe = poleBase * CFrame.new(bannerSign * -6, 2.5, -3),
				color = Color3.fromRGB(148, 146, 142),
				material = Enum.Material.Slate,
				parent = city,
			})
			BuildKit.pointLight(stoneLantern, Color3.fromRGB(255, 190, 120), 1.2, 22)
		end
		-- Training ground inside the court: mats and two dummies.
		for matSign = -1, 1, 2 do
			BuildKit.part({
				name = "SectCourt_Mat",
				size = Vector3.new(6, 0.3, 6),
				cframe = courtCF * CFrame.new(matSign * 24, 0.95, -18),
				color = Color3.fromRGB(178, 150, 100),
				material = Enum.Material.Fabric,
				canCollide = false,
				castShadow = false,
				parent = city,
			})
			local dummyWorld = courtCF * CFrame.new(matSign * 24, 0, -30)
			BuildKit.trainingDummy(city, Vector3.new(dummyWorld.X, center.Y, dummyWorld.Z))
		end
	end

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

	-- Record the fixed landmarks so lanterns and flora keep clear of them.
	table.insert(placed, { x = shrinePos.X, z = shrinePos.Z, r = 40 })
	table.insert(placed, { x = gatePos.X, z = gatePos.Z, r = 44 })

	-- ------------------- Street life along the avenue -------------------
	-- Market stalls where the gate road meets the plaza, a well, benches
	-- by the dais, and a notice board inside the gate: the things people
	-- actually leave in a town square. All of it hugs the avenue so combat
	-- lanes and the plaza stay open.
	do
		local avenueSide = Vector3.new(-toCenter.Z, 0, toCenter.X)
		for stallIndex = 0, 3 do
			local stallSide = if stallIndex % 2 == 0 then 1 else -1
			local along = radius * (0.42 + 0.14 * math.floor(stallIndex / 2))
			local stallPos = center + toCenter * along + avenueSide * (stallSide * 24)
			local stallCF = CFrame.lookAt(stallPos, stallPos - avenueSide * stallSide)
			BuildKit.part({ -- counter
				name = "Stall_Counter",
				size = Vector3.new(10, 3.4, 3),
				cframe = stallCF * CFrame.new(0, 1.7 + center.Y - stallPos.Y, 0),
				color = Color3.fromRGB(124, 94, 62),
				material = Enum.Material.WoodPlanks,
				parent = city,
			})
			for postSign = -1, 1, 2 do
				BuildKit.part({
					name = "Stall_Post",
					size = Vector3.new(0.8, 9, 0.8),
					cframe = stallCF * CFrame.new(postSign * 4.6, 4.5, -1),
					color = TIMBER,
					material = Enum.Material.Wood,
					canCollide = false,
					castShadow = false,
					parent = city,
				})
			end
			BuildKit.part({ -- cloth awning, tilted, in the city's accent
				name = "Stall_Awning",
				size = Vector3.new(11, 0.4, 6),
				cframe = stallCF * CFrame.new(0, 8.6, 0) * CFrame.Angles(math.rad(-10), 0, 0),
				color = if stallIndex % 2 == 0 then spec.accent else Color3.fromRGB(214, 200, 170),
				material = Enum.Material.Fabric,
				canCollide = false,
				castShadow = false,
				parent = city,
			})
			BuildKit.part({ -- goods crate
				name = "Stall_Crate",
				size = Vector3.new(2.6, 2.6, 2.6),
				cframe = stallCF * CFrame.new(6.4, 1.3, 0.5) * CFrame.Angles(0, 0.5, 0),
				color = Color3.fromRGB(140, 108, 72),
				material = Enum.Material.WoodPlanks,
				castShadow = false,
				parent = city,
			})
			table.insert(placed, { x = stallPos.X, z = stallPos.Z, r = 10 })
		end

		-- The town well, off the dais toward the cross road.
		local wellPos = center + avenueSide * (radius * 0.16) + toCenter * (radius * 0.06)
		BuildKit.cylinder(city, "Well_Ring", wellPos + Vector3.new(0, 1.4, 0), 2.8, 8, Color3.fromRGB(140, 138, 134), Enum.Material.Cobblestone)
		BuildKit.cylinder(city, "Well_Hole", wellPos + Vector3.new(0, 2.9, 0), 0.3, 5.5, Color3.fromRGB(24, 26, 30), Enum.Material.SmoothPlastic, false, false)
		for wellSign = -1, 1, 2 do
			BuildKit.part({
				name = "Well_Post",
				size = Vector3.new(0.8, 7, 0.8),
				position = wellPos + Vector3.new(wellSign * 3.6, 3.5, 0),
				color = TIMBER,
				material = Enum.Material.Wood,
				canCollide = false,
				castShadow = false,
				parent = city,
			})
		end
		BuildKit.chineseRoof(city, wellPos, 7, 7, wellPos.Y + 7, theme.roof, theme.roofMaterial)
		BuildKit.part({
			name = "Well_Bucket",
			size = Vector3.new(1.4, 1.6, 1.4),
			position = wellPos + Vector3.new(1.2, 5.2, 0),
			color = Color3.fromRGB(104, 76, 50),
			material = Enum.Material.Wood,
			canCollide = false,
			castShadow = false,
			parent = city,
		})
		table.insert(placed, { x = wellPos.X, z = wellPos.Z, r = 10 })

		-- Notice board just inside the gate, by the avenue's edge.
		local boardPos = center + toCenter * (radius * 0.8) + avenueSide * 22
		local noticeCF = CFrame.lookAt(boardPos, boardPos - avenueSide)
		BuildKit.part({
			name = "NoticeBoard",
			size = Vector3.new(9, 6, 0.8),
			cframe = noticeCF * CFrame.new(0, 6, 0),
			color = Color3.fromRGB(96, 72, 50),
			material = Enum.Material.WoodPlanks,
			canCollide = false,
			parent = city,
		})
		for boardSign = -1, 1, 2 do
			BuildKit.part({
				name = "NoticeBoard_Post",
				size = Vector3.new(1, 9.5, 1),
				cframe = noticeCF * CFrame.new(boardSign * 4, 4.75, 0),
				color = TIMBER,
				material = Enum.Material.Wood,
				parent = city,
			})
		end
		BuildKit.chineseRoof(city, boardPos, 8, 3, boardPos.Y + 9.6, theme.roof, theme.roofMaterial)
		table.insert(placed, { x = boardPos.X, z = boardPos.Z, r = 8 })

		-- Benches around the dais rim.
		for benchIndex = 0, 2 do
			local benchAngle = benchIndex * (math.pi * 2 / 3) + 0.6
			local benchPos = shrinePos + Vector3.new(math.cos(benchAngle) * 42, 0, math.sin(benchAngle) * 42)
			BuildKit.part({
				name = "Bench",
				size = Vector3.new(6.5, 1.6, 2),
				cframe = CFrame.lookAt(benchPos + Vector3.new(0, 0.8 + center.Y - benchPos.Y, 0), Vector3.new(shrinePos.X, benchPos.Y + 0.8, shrinePos.Z)),
				color = Color3.fromRGB(118, 90, 60),
				material = Enum.Material.Wood,
				castShadow = false,
				parent = city,
			})
		end
	end

	-- Spawn, lanterns, sanctuary, and gate dummies.
	local spawnColor = if pathDef then pathDef.teamBrickColor else "Medium stone grey"
	BuildKit.spawnLocation(city, shrinePos + toCenter * 18 + Vector3.new(0, 1, 0), spawnColor, false)

	local lanternRed = Color3.fromRGB(210, 60, 45)
	for index = 1, 10 do
		local angle = index / 10 * math.pi * 2 + 0.3
		local lanternPos = center + Vector3.new(math.cos(angle) * radius * 0.86, 0, math.sin(angle) * radius * 0.86)
		-- Skip a post that would stand inside something already built.
		local blocked = false
		for _, other in placed do
			local dx = lanternPos.X - other.x
			local dz = lanternPos.Z - other.z
			if dx * dx + dz * dz < (other.r + 2) * (other.r + 2) then
				blocked = true
				break
			end
		end
		if blocked then
			continue
		end
		local post = BuildKit.part({
			name = "Lantern",
			size = Vector3.new(1, 11, 1),
			position = lanternPos + Vector3.new(0, 5.5, 0),
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
			castShadow = false,
			parent = city,
		})
		BuildKit.pointLight(lamp, Color3.fromRGB(255, 150, 110), 1.6, 26)
	end

	BuildKit.safeZone(city, center, radius * 1.05)

	for i = -1, 1 do
		local side = Vector3.new(-toCenter.Z, 0, toCenter.X)
		BuildKit.trainingDummy(city, Vector3.new(gatePos.X, center.Y, gatePos.Z) + side * (i * 16) + toCenter * 44)
	end
end

function Cities.build(parent: Instance)
	local specs: { CitySpec } = {
		{
			key = "orthodox",
			radius = 320,
			name = Paths.orthodox.cityName,
			subtitle = Paths.orthodox.name,
			accent = Paths.orthodox.accentColor,
		},
		{
			key = "demonic",
			radius = 320,
			name = Paths.demonic.cityName,
			subtitle = Paths.demonic.name,
			accent = Paths.demonic.accentColor,
		},
		{
			key = "unorthodox",
			radius = 320,
			name = Paths.unorthodox.cityName,
			subtitle = Paths.unorthodox.name,
			accent = Paths.unorthodox.accentColor,
		},
		{
			key = "central",
			radius = 430,
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
