--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Island
-- The landmass, sculpted from voxel Terrain to match the reference map:
-- one island in an ocean, three biome realms around a ring of jagged grey
-- peaks (snow to the north, desert to the southwest, forest east and
-- south), a hidden crater valley inside the ring with a waterfall pouring
-- from the north peak, rivers on the green side, and offshore islets.
--
-- Everything is deterministic (seeded Random + math.noise), so every
-- server builds the same island.

local BuildKit = require(script.Parent.BuildKit)

local Island = {}

-- Shared layout facts other builders align to.
Island.COAST_RADIUS = 900
Island.VALLEY_RADIUS = 148
Island.VALLEY_Y = 26 -- crater floor height (top surface)
Island.GAP_HALF_ANGLE = 26 -- degrees free of peaks, centered due south
Island.NORTH_PEAK = Vector3.new(0, 0, -205)
Island.NORTH_PEAK_TOP = 244 -- flattened summit height (pagoda floor)

export type Biome = "snow" | "desert" | "green"

-- Angle in degrees from north (0 = -Z), positive eastward.
local function angleOf(x: number, z: number): number
	return math.deg(math.atan2(x, -z))
end

function Island.biomeAt(x: number, z: number): Biome
	local wobble = math.noise(x * 0.003, z * 0.003) * 16
	local theta = angleOf(x, z) + wobble
	if theta > -58 and theta <= 44 then
		return "snow"
	elseif theta <= -58 and theta > -168 then
		return "desert"
	end
	return "green"
end

local terrain = workspace.Terrain

local function fillBlock(center: Vector3, size: Vector3, material: Enum.Material)
	terrain:FillBlock(CFrame.new(center), size, material)
end

local function fillBall(center: Vector3, radius: number, material: Enum.Material)
	terrain:FillBall(center, radius, material)
end

local function fillCylinder(center: Vector3, height: number, radius: number, material: Enum.Material)
	terrain:FillCylinder(CFrame.new(center), height, radius, material)
end

-- ------------------------------- Ocean ----------------------------------

local function buildOcean()
	local half = 1500
	-- Four quadrant blocks of water; island fills overwrite their voxels.
	for cx = -1, 1, 2 do
		for cz = -1, 1, 2 do
			fillBlock(Vector3.new(cx * half / 2, -14, cz * half / 2), Vector3.new(half, 24, half), Enum.Material.Water)
		end
	end
	-- Sea floor so the water has a bed.
	fillBlock(Vector3.new(0, -34, 0), Vector3.new(half * 2, 12, half * 2), Enum.Material.Sand)
end

-- ------------------------------- Island ---------------------------------

local BIOME_GROUND: { [string]: Enum.Material } = {
	snow = Enum.Material.Snow,
	desert = Enum.Material.Sand,
	green = Enum.Material.Grass,
}

local function coastRadiusAt(theta: number): number
	return Island.COAST_RADIUS + math.noise(math.cos(math.rad(theta)) * 2.2, math.sin(math.rad(theta)) * 2.2) * 110
end

local function buildLandmass()
	local cell = 48
	for x = -1050, 1050, cell do
		for z = -1050, 1050, cell do
			local distance = math.sqrt(x * x + z * z)
			if distance > coastRadiusAt(angleOf(x, z)) then
				continue
			end
			local biome = Island.biomeAt(x, z)
			-- Land slab: from below the waterline up to y = 0.
			fillBlock(Vector3.new(x, -13, z), Vector3.new(cell + 2, 26, cell + 2), BIOME_GROUND[biome])
		end
	end
end

-- Gentle rolling bumps, mesas in the desert, glacier shelves in the snow.
local function buildRelief(rng: Random)
	for _ = 1, 90 do
		local theta = rng:NextNumber(-180, 180)
		local distance = rng:NextNumber(380, 820)
		local x = math.sin(math.rad(theta)) * distance
		local z = -math.cos(math.rad(theta)) * distance
		local biome = Island.biomeAt(x, z)
		if biome == "desert" and rng:NextNumber() < 0.4 then
			-- Stepped mesa.
			local width = rng:NextNumber(26, 60)
			local height = rng:NextNumber(14, 40)
			for step = 0, 2 do
				fillBlock(
					Vector3.new(x + rng:NextNumber(-6, 6), height * (0.2 + step * 0.3), z + rng:NextNumber(-6, 6)),
					Vector3.new(width * (1 - step * 0.28), height * 0.45, width * (1 - step * 0.28)),
					Enum.Material.Sandstone
				)
			end
		elseif biome == "snow" and rng:NextNumber() < 0.35 then
			-- Glacier shelf.
			fillBall(Vector3.new(x, rng:NextNumber(2, 10), z), rng:NextNumber(18, 40), Enum.Material.Glacier)
		else
			-- Rolling hill.
			local material = if biome == "snow"
				then Enum.Material.Snow
				elseif biome == "desert" then Enum.Material.Sand
				else Enum.Material.Grass
			fillBall(Vector3.new(x, rng:NextNumber(-4, 6), z), rng:NextNumber(14, 34), material)
		end
	end
	-- LeafyGrass patches through the green realm.
	for _ = 1, 40 do
		local theta = rng:NextNumber(50, 180)
		local distance = rng:NextNumber(300, 800)
		local x = math.sin(math.rad(theta)) * distance
		local z = -math.cos(math.rad(theta)) * distance
		fillBall(Vector3.new(x, -2, z), rng:NextNumber(14, 30), Enum.Material.LeafyGrass)
	end
end

-- --------------------------- The mountain ring --------------------------

local function buildPeak(rng: Random, base: Vector3, height: number, girth: number)
	local levels = rng:NextInteger(6, 8)
	local position = base
	for level = 0, levels do
		local t = level / levels
		local radius = girth * (1 - t * 0.82) * rng:NextNumber(0.85, 1.15)
		local material = if t > 0.55 then Enum.Material.Slate else Enum.Material.Rock
		fillBall(
			Vector3.new(
				position.X + rng:NextNumber(-girth * 0.2, girth * 0.2),
				height * t,
				position.Z + rng:NextNumber(-girth * 0.2, girth * 0.2)
			),
			math.max(10, radius),
			material
		)
	end
	-- A spur or two at the shoulder.
	for _ = 1, rng:NextInteger(1, 2) do
		local spurAngle = rng:NextNumber(0, math.pi * 2)
		fillBall(
			base + Vector3.new(math.cos(spurAngle) * girth * 0.9, height * rng:NextNumber(0.2, 0.4), math.sin(spurAngle) * girth * 0.9),
			girth * rng:NextNumber(0.35, 0.55),
			Enum.Material.Rock
		)
	end
end

local function buildMountains(rng: Random)
	-- Crater floor first, so peaks bury its rim.
	fillCylinder(Vector3.new(0, Island.VALLEY_Y / 2, 0), Island.VALLEY_Y + 6, Island.VALLEY_RADIUS + 40, Enum.Material.Ground)
	fillCylinder(Vector3.new(0, Island.VALLEY_Y - 1, 0), 2.5, Island.VALLEY_RADIUS + 20, Enum.Material.Grass)

	-- The ring: peaks all around except the southern gap.
	local peakCount = 15
	for index = 1, peakCount do
		local theta = -180 + (index - 0.5) * (360 / peakCount)
		if math.abs(180 - math.abs(theta)) < Island.GAP_HALF_ANGLE then
			continue -- the southern pass stays open
		end
		local ringRadius = rng:NextNumber(195, 245)
		local x = math.sin(math.rad(theta)) * ringRadius
		local z = -math.cos(math.rad(theta)) * ringRadius
		buildPeak(rng, Vector3.new(x, 0, z), rng:NextNumber(120, 215), rng:NextNumber(44, 62))
	end

	-- The great north peak: tallest, flattened summit for the dark pagoda.
	buildPeak(rng, Island.NORTH_PEAK, 250, 68)
	fillCylinder(Vector3.new(Island.NORTH_PEAK.X, Island.NORTH_PEAK_TOP - 3, Island.NORTH_PEAK.Z), 6, 34, Enum.Material.Slate)

	-- Waterfall: a sheet of water down the peak's inner face into a pool.
	fillBlock(Vector3.new(0, (Island.NORTH_PEAK_TOP + Island.VALLEY_Y) / 2, -146), Vector3.new(14, Island.NORTH_PEAK_TOP - Island.VALLEY_Y, 6), Enum.Material.Water)
	fillCylinder(Vector3.new(0, Island.VALLEY_Y - 2, -112), 5, 24, Enum.Material.Water)
end

-- ------------------------------- Rivers ---------------------------------

local function carveRiver(points: { Vector3 })
	for index = 1, #points - 1 do
		local from = points[index]
		local to = points[index + 1]
		local length = (to - from).Magnitude
		local direction = (to - from).Unit
		local step = 14
		local distance = 0
		while distance <= length do
			local at = from + direction * distance
			fillBall(Vector3.new(at.X, 1, at.Z), 11, Enum.Material.Air)
			fillBall(Vector3.new(at.X, -5, at.Z), 10, Enum.Material.Water)
			distance += step
		end
	end
end

local function buildRivers()
	carveRiver({
		Vector3.new(240, 0, -60),
		Vector3.new(420, 0, -10),
		Vector3.new(600, 0, 60),
		Vector3.new(780, 0, 90),
		Vector3.new(960, 0, 110),
	})
	carveRiver({
		Vector3.new(200, 0, 250),
		Vector3.new(360, 0, 330),
		Vector3.new(520, 0, 460),
		Vector3.new(700, 0, 560),
		Vector3.new(900, 0, 640),
	})
end

-- --------------------------- Offshore islets ----------------------------

local function buildIslets(rng: Random)
	for _ = 1, 7 do
		local theta = rng:NextNumber(60, 220) -- scattered off the green/south coasts
		local distance = rng:NextNumber(1000, 1250)
		local x = math.sin(math.rad(theta)) * distance
		local z = -math.cos(math.rad(theta)) * distance
		local radius = rng:NextNumber(16, 42)
		fillBall(Vector3.new(x, -6, z), radius, Enum.Material.Rock)
		fillBall(Vector3.new(x, 2, z), radius * 0.7, Enum.Material.Grass)
	end
end

-- --------------------- Hollows for the built spaces ---------------------

-- The Deep Mines are parts, not terrain; scoop the rock out around them and
-- the shaft so the halls stay hollow under the sculpted ground.
local function carveUnderworld()
	fillBlock(Vector3.new(0, -33, 270), Vector3.new(44, 78, 76), Enum.Material.Air) -- shaft + ramp
	fillBlock(Vector3.new(0, -39, 452), Vector3.new(208, 46, 316), Enum.Material.Air) -- both halls
end

-- ------------------------------ Entrypoint ------------------------------

function Island.build()
	local rng = Random.new(41)
	buildOcean()
	buildLandmass()
	buildRelief(rng)
	buildMountains(rng)
	buildRivers()
	buildIslets(rng)
	carveUnderworld()
	-- A touch of shoreline foam color where land meets sea.
	local _ = BuildKit -- (parts-based shoreline props may come later)
end

return Island
