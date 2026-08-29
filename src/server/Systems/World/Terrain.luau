--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Terrain
-- The Azure Vale's landform, generated as a NOISE HEIGHTFIELD: one
-- deterministic height function evaluated per column, written as voxel
-- terrain. This is what finally kills the flat-faced wedge mountains and
-- balloon hills of the old world: every slope here is continuous, every
-- ridge is noise, and every placement in the world can ask heightAt() for
-- the exact ground level, so nothing floats and nothing is buried.
--
-- Deliberately compact (±768 studs). A small world drawn densely beats a
-- vast one drawn thin; new regions attach beyond the rim in later phases.

local Terrain = {}

Terrain.SPAN = 768 -- world runs x,z in [-SPAN, SPAN]
Terrain.CELL = 12 -- column width in studs
Terrain.SEA_LEVEL = 0

-- Landmark centers other modules build against.
Terrain.VILLAGE = Vector2.new(170, 150)
Terrain.VILLAGE_HEIGHT = 11
Terrain.SUMMIT = Vector2.new(0, -520)
Terrain.SUMMIT_HEIGHT = 296
Terrain.SHELF = Vector2.new(-140, -330) -- mountainside meditation shelf
Terrain.SHELF_HEIGHT = 95
Terrain.GROVE = Vector2.new(430, 60) -- bamboo grove clearing

local voxels = workspace.Terrain

-- The mountains: {x, z, height, radius}. The great peak is Heavenpillar;
-- the rest shape the vale's rim.
local MOUNTAINS = {
	{ x = 0, z = -520, h = 330, r = 350 },
	{ x = -380, z = -330, h = 150, r = 190 },
	{ x = 390, z = -350, h = 180, r = 210 },
	{ x = 560, z = 180, h = 80, r = 220 },
	{ x = -520, z = 280, h = 70, r = 200 },
	{ x = 180, z = 560, h = 60, r = 190 },
	{ x = -260, z = 520, h = 55, r = 170 },
}

-- The river: mountain gorge to the southern sea.
local RIVER: { Vector2 } = {
	Vector2.new(0, -330),
	Vector2.new(30, -80),
	Vector2.new(90, 160),
	Vector2.new(60, 400),
	Vector2.new(110, 720),
}
local RIVER_HALF_WIDTH = 17

local function distanceToPolyline(x: number, z: number, points: { Vector2 }): number
	local best = math.huge
	for index = 1, #points - 1 do
		local a = points[index]
		local b = points[index + 1]
		local abx, abz = b.X - a.X, b.Y - a.Y
		local lengthSq = abx * abx + abz * abz
		local t = math.clamp(((x - a.X) * abx + (z - a.Y) * abz) / lengthSq, 0, 1)
		local cx, cz = a.X + abx * t, a.Y + abz * t
		best = math.min(best, math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2))
	end
	return best
end

function Terrain.riverDistance(x: number, z: number): number
	return distanceToPolyline(x, z, RIVER)
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The height function. Deterministic; the entire vale flows from here.
function Terrain.heightAt(x: number, z: number): number
	-- Rolling meadow base.
	local h = 10
		+ math.noise(x * 0.0045 + 7.13, z * 0.0045 + 7.13) * 8
		+ math.noise(x * 0.013 + 31.7, z * 0.013 + 31.7) * 3

	-- Mountains: radial profile roughened by ridge noise so no slope is a
	-- clean cone.
	for _, mountain in MOUNTAINS do
		local d = math.sqrt((x - mountain.x) ^ 2 + (z - mountain.z) ^ 2)
		if d < mountain.r then
			local t = 1 - d / mountain.r
			local ridge = 0.78 + 0.44 * math.abs(math.noise(x * 0.008 + 3.3, z * 0.008 + 3.3))
			h += mountain.h * t ^ 1.7 * ridge
		end
	end

	-- Island falloff into the sea.
	local fromCenter = math.sqrt(x * x + z * z)
	if fromCenter > 620 then
		h -= ((fromCenter - 620) / 140) ^ 1.5 * 60
	end

	-- The river carves its channel below sea level; water self-fills.
	local dRiver = distanceToPolyline(x, z, RIVER)
	if dRiver < RIVER_HALF_WIDTH then
		local channel = -4 * smooth(1 - dRiver / RIVER_HALF_WIDTH) - 0.5
		local blend = smooth(dRiver / RIVER_HALF_WIDTH)
		h = math.min(h, channel * (1 - blend) + h * blend)
		h = math.min(h, -3.5 + 4 * blend)
	end

	-- Flattened build sites, blended smoothly into the land.
	local function plateau(centerX: number, centerZ: number, radius: number, blendRadius: number, level: number)
		local d = math.sqrt((x - centerX) ^ 2 + (z - centerZ) ^ 2)
		if d < blendRadius then
			local t = smooth(math.max(0, d - radius) / math.max(blendRadius - radius, 1))
			h = level * (1 - t) + h * t
		end
	end
	plateau(Terrain.VILLAGE.X, Terrain.VILLAGE.Y, 120, 190, Terrain.VILLAGE_HEIGHT)
	plateau(Terrain.SUMMIT.X, Terrain.SUMMIT.Y, 44, 90, Terrain.SUMMIT_HEIGHT)
	plateau(Terrain.SHELF.X, Terrain.SHELF.Y, 30, 60, Terrain.SHELF_HEIGHT)
	plateau(Terrain.GROVE.X, Terrain.GROVE.Y, 46, 90, 14)

	return h
end

function Terrain.slopeAt(x: number, z: number): number
	local step = Terrain.CELL
	local here = Terrain.heightAt(x, z)
	local dx = math.abs(Terrain.heightAt(x + step, z) - here)
	local dz = math.abs(Terrain.heightAt(x, z + step) - here)
	return math.max(dx, dz) / step
end

-- ------------------------------- Building --------------------------------

local function fillBlock(center: Vector3, size: Vector3, material: Enum.Material)
	voxels:FillBlock(CFrame.new(center), size, material)
end

function Terrain.build()
	local span = Terrain.SPAN
	local cell = Terrain.CELL

	-- The sea, in quadrants (single giant fills hit region limits), and a
	-- sand bed beneath it.
	for cx = -1, 1, 2 do
		for cz = -1, 1, 2 do
			fillBlock(
				Vector3.new(cx * span / 2, -13, cz * span / 2),
				Vector3.new(span + cell, 26, span + cell),
				Enum.Material.Water
			)
		end
	end
	fillBlock(Vector3.new(0, -29, 0), Vector3.new(span * 2 + cell * 2, 8, span * 2 + cell * 2), Enum.Material.Sand)

	-- Height columns. Grass by default; rock where steep, snow up high,
	-- sand at the waterline, leafy patches by noise.
	for x = -span, span, cell do
		for z = -span, span, cell do
			local h = Terrain.heightAt(x, z)
			if h <= -20 then
				continue -- open sea; the water fill already owns it
			end
			local slope = Terrain.slopeAt(x, z)
			local material: Enum.Material
			if h > 235 then
				material = Enum.Material.Snow
			elseif slope > 1.05 then
				material = Enum.Material.Rock
			elseif h < 2.5 then
				material = Enum.Material.Sand
			elseif math.noise(x * 0.006 + 91.2, z * 0.006 + 91.2) > 0.24 then
				material = Enum.Material.LeafyGrass
			else
				material = Enum.Material.Grass
			end
			local bottom = -24
			fillBlock(
				Vector3.new(x, (h + bottom) / 2, z),
				Vector3.new(cell + 0.5, h - bottom, cell + 0.5),
				material
			)
		end
	end

	-- Animated grass on the meadows.
	pcall(function()
		voxels.Decoration = true;
		(voxels :: any).GrassLength = 0.75
	end)
end

return Terrain
