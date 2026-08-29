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
Island.COAST_RADIUS = 3600
Island.VALLEY_RADIUS = 585
Island.VALLEY_Y = 44 -- crater floor height (top surface)
Island.GAP_HALF_ANGLE = 26 -- degrees free of peaks, centered due south
Island.NORTH_PEAK = Vector3.new(0, 0, -820)
Island.NORTH_PEAK_TOP = 725 -- flattened summit height (pagoda floor)

export type Biome = "snow" | "desert" | "green"

-- Angle in degrees from north (0 = -Z), positive eastward.
local function angleOf(x: number, z: number): number
	return math.deg(math.atan2(x, -z))
end

function Island.biomeAt(x: number, z: number): Biome
	local wobble = math.noise(x * 0.001, z * 0.001) * 16
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
	local half = 5600
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
	return Island.COAST_RADIUS + math.noise(math.cos(math.rad(theta)) * 2.2, math.sin(math.rad(theta)) * 2.2) * 400
end

local function buildLandmass()
	local cell = 128
	for x = -4200, 4200, cell do
		for z = -4200, 4200, cell do
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
	for _ = 1, 220 do
		local theta = rng:NextNumber(-180, 180)
		local distance = rng:NextNumber(1530, 3270)
		local x = math.sin(math.rad(theta)) * distance
		local z = -math.cos(math.rad(theta)) * distance
		local biome = Island.biomeAt(x, z)
		if biome == "desert" and rng:NextNumber() < 0.4 then
			-- Stepped mesa.
			local width = rng:NextNumber(80, 185)
			local height = rng:NextNumber(40, 120)
			for step = 0, 2 do
				fillBlock(
					Vector3.new(x + rng:NextNumber(-6, 6), height * (0.2 + step * 0.3), z + rng:NextNumber(-6, 6)),
					Vector3.new(width * (1 - step * 0.28), height * 0.45, width * (1 - step * 0.28)),
					Enum.Material.Sandstone
				)
			end
		elseif biome == "snow" and rng:NextNumber() < 0.35 then
			-- Glacier shelf.
			fillBall(Vector3.new(x, rng:NextNumber(4, 18), z), rng:NextNumber(55, 120), Enum.Material.Glacier)
		else
			-- Rolling hill.
			local material = if biome == "snow"
				then Enum.Material.Snow
				elseif biome == "desert" then Enum.Material.Sand
				else Enum.Material.Grass
			fillBall(Vector3.new(x, rng:NextNumber(-8, 14), z), rng:NextNumber(40, 100), material)
		end
	end
	-- LeafyGrass patches through the green realm.
	for _ = 1, 90 do
		local theta = rng:NextNumber(50, 180)
		local distance = rng:NextNumber(1200, 3200)
		local x = math.sin(math.rad(theta)) * distance
		local z = -math.cos(math.rad(theta)) * distance
		fillBall(Vector3.new(x, -2, z), rng:NextNumber(40, 95), Enum.Material.LeafyGrass)
	end
end

-- --------------------------- The mountain ring --------------------------

local function buildPeak(rng: Random, base: Vector3, height: number, girth: number)
	-- Many smaller, hard-jittered masses instead of a few big spheres, so
	-- peaks come out craggy rather than domed.
	local levels = rng:NextInteger(9, 12)
	for level = 0, levels do
		local t = level / levels
		local radius = girth * (1 - t * 0.78) * rng:NextNumber(0.55, 0.95)
		local material = if t > 0.5 then Enum.Material.Slate else Enum.Material.Rock
		fillBall(
			Vector3.new(
				base.X + rng:NextNumber(-girth * 0.38, girth * 0.38),
				height * t,
				base.Z + rng:NextNumber(-girth * 0.38, girth * 0.38)
			),
			math.max(10, radius),
			material
		)
	end
	-- Shoulder spurs and splinter crags around the base.
	for _ = 1, rng:NextInteger(3, 5) do
		local spurAngle = rng:NextNumber(0, math.pi * 2)
		local spurDist = girth * rng:NextNumber(0.7, 1.15)
		fillBall(
			base + Vector3.new(math.cos(spurAngle) * spurDist, height * rng:NextNumber(0.1, 0.45), math.sin(spurAngle) * spurDist),
			girth * rng:NextNumber(0.22, 0.42),
			Enum.Material.Rock
		)
	end
end

local function buildMountains(rng: Random)
	-- Crater floor first, so peaks bury its rim.
	fillCylinder(Vector3.new(0, Island.VALLEY_Y - 23, 0), 46, Island.VALLEY_RADIUS + 60, Enum.Material.Ground)
	fillCylinder(Vector3.new(0, Island.VALLEY_Y - 1.25, 0), 2.5, Island.VALLEY_RADIUS + 30, Enum.Material.Grass)

	-- The ring: peaks all around except the southern gap.
	local peakCount = 17
	for index = 1, peakCount do
		local theta = -180 + (index - 0.5) * (360 / peakCount)
		if math.abs(180 - math.abs(theta)) < Island.GAP_HALF_ANGLE then
			continue -- the southern pass stays open
		end
		local ringRadius = rng:NextNumber(780, 980)
		local x = math.sin(math.rad(theta)) * ringRadius
		local z = -math.cos(math.rad(theta)) * ringRadius
		buildPeak(rng, Vector3.new(x, 0, z), rng:NextNumber(370, 690), rng:NextNumber(145, 215))
	end

	-- The great north peak: tallest, flattened summit for the dark pagoda.
	buildPeak(rng, Island.NORTH_PEAK, 745, 225)
	fillCylinder(Vector3.new(Island.NORTH_PEAK.X, Island.NORTH_PEAK_TOP - 4, Island.NORTH_PEAK.Z), 8, 80, Enum.Material.Slate)

	-- Waterfall: a sheet of water down the peak's inner face into a pool.
	fillBlock(Vector3.new(0, (Island.NORTH_PEAK_TOP + Island.VALLEY_Y) / 2, -585), Vector3.new(46, Island.NORTH_PEAK_TOP - Island.VALLEY_Y, 8), Enum.Material.Water)
	fillCylinder(Vector3.new(0, Island.VALLEY_Y - 2, -448), 5, 52, Enum.Material.Water)
end

-- ------------------------------- Rivers ---------------------------------

local function carveRiver(points: { Vector3 })
	for index = 1, #points - 1 do
		local from = points[index]
		local to = points[index + 1]
		local length = (to - from).Magnitude
		local direction = (to - from).Unit
		local step = 24
		local distance = 0
		while distance <= length do
			local at = from + direction * distance
			fillBall(Vector3.new(at.X, 1, at.Z), 20, Enum.Material.Air)
			fillBall(Vector3.new(at.X, -6, at.Z), 19, Enum.Material.Water)
			distance += step
		end
	end
end

local function buildRivers()
	carveRiver({
		Vector3.new(960, 0, -240),
		Vector3.new(1680, 0, -40),
		Vector3.new(2400, 0, 240),
		Vector3.new(3120, 0, 360),
		Vector3.new(3840, 0, 440),
	})
	carveRiver({
		Vector3.new(800, 0, 1000),
		Vector3.new(1440, 0, 1320),
		Vector3.new(2080, 0, 1840),
		Vector3.new(2800, 0, 2240),
		Vector3.new(3600, 0, 2560),
	})
end

-- --------------------------- Offshore islets ----------------------------

local function buildIslets(rng: Random)
	for _ = 1, 7 do
		local theta = rng:NextNumber(60, 220) -- scattered off the green/south coasts
		local distance = rng:NextNumber(4000, 5000)
		local x = math.sin(math.rad(theta)) * distance
		local z = -math.cos(math.rad(theta)) * distance
		local radius = rng:NextNumber(40, 100)
		fillBall(Vector3.new(x, -6, z), radius, Enum.Material.Rock)
		fillBall(Vector3.new(x, 2, z), radius * 0.7, Enum.Material.Grass)
	end
end

-- --------------------- Hollows for the built spaces ---------------------

-- The Deep Mines are parts, not terrain; scoop the rock out around them and
-- the shaft so the halls stay hollow under the sculpted ground.
local function carveUnderworld()
	fillBlock(Vector3.new(0, -33, 960), Vector3.new(44, 78, 76), Enum.Material.Air) -- shaft + ramp
	fillBlock(Vector3.new(0, -39, 1142), Vector3.new(208, 46, 316), Enum.Material.Air) -- both halls
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
