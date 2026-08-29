--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Flora
-- Vegetation for the vale: cone pines (snowy up high), blossom trees,
-- bamboo clumps, boulders, shrubs and fallen logs. Placement queries
-- Terrain.heightAt and slopeAt directly, so trees stand ON the ground,
-- refuse cliffs, keep out of the river, the village, the roads' corridor
-- and the sacred clearings. Crowns never collide and never eat a
-- projectile; trunks do.

local Kit = require(script.Parent.Kit)
local Terrain = require(script.Parent.Terrain)

local Flora = {}

local TRUNK = Color3.fromRGB(92, 70, 52)
local PINE_GREEN = Color3.fromRGB(52, 84, 60)
local PINE_DARK = Color3.fromRGB(40, 66, 48)
local SNOW_WHITE = Color3.fromRGB(238, 242, 246)
local BLOSSOM_PINK = Color3.fromRGB(240, 184, 205)
local BLOSSOM_WHITE = Color3.fromRGB(246, 238, 230)
local BAMBOO_GREEN = Color3.fromRGB(126, 168, 92)

local function puff(parent: Instance, position: Vector3, size: Vector3, color: Color3)
	local part = Kit.part({
		name = "Foliage",
		size = Vector3.new(1, 1, 1),
		position = position,
		color = color,
		material = Enum.Material.Grass,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = part
end

local function pineTree(parent: Instance, position: Vector3, rng: Random, snowy: boolean)
	local height = rng:NextNumber(24, 42)
	local lean = rng:NextNumber(-0.06, 0.06)
	Kit.part({
		name = "Pine_Trunk",
		size = Vector3.new(2.6, height, 2.6),
		cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(lean, 0, lean),
		color = TRUNK,
		material = Enum.Material.Wood,
		parent = parent,
	})
	local layers = rng:NextInteger(4, 5)
	for layer = 1, layers do
		local t = (layer - 1) / layers
		local layerY = position.Y + height * (0.5 + 0.55 * t)
		local diameter = (22 - t * 13) * rng:NextNumber(0.9, 1.12)
		local color = if snowy and layer == layers
			then SNOW_WHITE
			elseif layer % 2 == 0 then PINE_DARK
			else PINE_GREEN
		Kit.cylinder(parent, "Pine_Canopy", Vector3.new(position.X, layerY, position.Z), height * 0.14, diameter,
			color, if snowy and layer == layers then Enum.Material.Snow else Enum.Material.Grass, false)
	end
	Kit.cylinder(parent, "Pine_Tip", Vector3.new(position.X, position.Y + height * 1.08, position.Z), height * 0.12, 5,
		if snowy then SNOW_WHITE else PINE_GREEN, if snowy then Enum.Material.Snow else Enum.Material.Grass, false, false)
end

local function blossomTree(parent: Instance, position: Vector3, rng: Random)
	local height = rng:NextNumber(18, 28)
	local lean = rng:NextNumber(-0.12, 0.12)
	Kit.part({
		name = "Blossom_Trunk",
		size = Vector3.new(2.2, height, 2.2),
		cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(lean, 0, -lean),
		color = Color3.fromRGB(70, 54, 44),
		material = Enum.Material.Wood,
		parent = parent,
	})
	local crown = position + Vector3.new(lean * height * 4, height, lean * height * 4)
	for _ = 1, rng:NextInteger(4, 6) do
		local offset = Vector3.new(rng:NextNumber(-7, 7), rng:NextNumber(-2, 5), rng:NextNumber(-7, 7))
		local width = rng:NextNumber(9, 14)
		puff(parent, crown + offset, Vector3.new(width, width * 0.65, width),
			if rng:NextNumber() < 0.7 then BLOSSOM_PINK else BLOSSOM_WHITE)
	end
end

local function bambooClump(parent: Instance, position: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(4, 6) do
		local culmHeight = rng:NextNumber(34, 56)
		local base = position + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
		Kit.part({
			name = "Bamboo_Culm",
			size = Vector3.new(1.3, culmHeight, 1.3),
			cframe = CFrame.new(base + Vector3.new(0, culmHeight / 2, 0))
				* CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05)),
			color = BAMBOO_GREEN,
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
		local top = base + Vector3.new(0, culmHeight, 0)
		puff(parent, top, Vector3.new(rng:NextNumber(10, 14), rng:NextNumber(6, 8), rng:NextNumber(10, 14)), Color3.fromRGB(104, 146, 78))
		puff(parent, top + Vector3.new(rng:NextNumber(-5, 5), -rng:NextNumber(4, 8), rng:NextNumber(-5, 5)),
			Vector3.new(rng:NextNumber(7, 10), rng:NextNumber(4, 6), rng:NextNumber(7, 10)), Color3.fromRGB(126, 166, 92))
	end
end

local function boulder(parent: Instance, position: Vector3, rng: Random, snowy: boolean)
	local size = rng:NextNumber(4, 11)
	Kit.part({
		name = "Boulder",
		size = Vector3.new(size, size * 0.7, size * rng:NextNumber(0.7, 1.3)),
		cframe = CFrame.new(position + Vector3.new(0, size * 0.2, 0))
			* CFrame.Angles(rng:NextNumber(0, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(0, 0.3)),
		color = if snowy then Color3.fromRGB(205, 212, 220) else Color3.fromRGB(120, 116, 112),
		material = Enum.Material.Slate,
		parent = parent,
	})
end

local function fallenLog(parent: Instance, position: Vector3, rng: Random)
	local length = rng:NextNumber(8, 13)
	Kit.part({
		name = "FallenLog",
		size = Vector3.new(length, 2, 2),
		cframe = CFrame.new(position + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		color = Color3.fromRGB(86, 66, 48),
		material = Enum.Material.Wood,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
end

local function shrubs(parent: Instance, position: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 3) do
		local size = rng:NextNumber(3, 5.5)
		puff(parent, position + Vector3.new(rng:NextNumber(-4, 4), size * 0.3, rng:NextNumber(-4, 4)),
			Vector3.new(size, size * 0.7, size),
			if rng:NextNumber() < 0.8 then Color3.fromRGB(78, 112, 64) else Color3.fromRGB(126, 150, 84))
	end
end

-- ------------------------------- Scatter ---------------------------------

-- Corridors trees must respect (the roads laid by Vale, by construction).
local ROAD_LINES: { { Vector2 } } = {
	{ Vector2.new(170, 262), Vector2.new(140, 288), Vector2.new(122, 296) },
	{ Vector2.new(42, 308), Vector2.new(-40, 300), Vector2.new(-140, 270) },
	{ Vector2.new(170, 96), Vector2.new(150, 20), Vector2.new(110, -70), Vector2.new(80, -140) },
	{ Vector2.new(226, 150), Vector2.new(320, 110), Vector2.new(392, 74) },
}

local function nearRoad(x: number, z: number): boolean
	for _, line in ROAD_LINES do
		for index = 1, #line - 1 do
			local a = line[index]
			local b = line[index + 1]
			local abx, abz = b.X - a.X, b.Y - a.Y
			local lengthSq = abx * abx + abz * abz
			local t = math.clamp(((x - a.X) * abx + (z - a.Y) * abz) / lengthSq, 0, 1)
			local cx, cz = a.X + abx * t, a.Y + abz * t
			if (x - cx) ^ 2 + (z - cz) ^ 2 < 13 * 13 then
				return true
			end
		end
	end
	return false
end

function Flora.build(parent: Instance)
	local rng = Random.new(9)
	local planted = 0
	local attempts = 0
	while planted < 230 and attempts < 900 do
		attempts += 1
		local x = rng:NextNumber(-680, 680)
		local z = rng:NextNumber(-680, 680)
		local h = Terrain.heightAt(x, z)
		if h < 3 or h > 200 then
			continue -- beach, sea, or the bare heights
		end
		if Terrain.slopeAt(x, z) > 0.65 then
			continue -- cliffs keep no orchards
		end
		if (Vector2.new(x, z) - Terrain.VILLAGE).Magnitude < 175 then
			continue
		end
		if (Vector2.new(x, z) - Terrain.GROVE).Magnitude < 60 then
			continue
		end
		if (Vector2.new(x, z) - Terrain.SHELF).Magnitude < 40 then
			continue
		end
		if Terrain.riverDistance(x, z) < 26 then
			continue
		end
		if nearRoad(x, z) then
			continue
		end
		planted += 1
		local position = Vector3.new(x, h, z)
		local roll = rng:NextNumber()
		if h > 110 then
			-- Mountain country: pines, snow-dusted higher up, and stone.
			if roll < 0.7 then
				pineTree(parent, position, rng, h > 150)
			else
				boulder(parent, position, rng, h > 150)
			end
		elseif x > 300 then
			-- The east runs to bamboo.
			if roll < 0.5 then
				bambooClump(parent, position, rng)
			elseif roll < 0.8 then
				blossomTree(parent, position, rng)
			else
				shrubs(parent, position, rng)
			end
		else
			if roll < 0.34 then
				pineTree(parent, position, rng, false)
			elseif roll < 0.6 then
				blossomTree(parent, position, rng)
			elseif roll < 0.74 then
				boulder(parent, position, rng, false)
			elseif roll < 0.88 then
				shrubs(parent, position, rng)
			else
				fallenLog(parent, position, rng)
			end
		end
	end
end

return Flora
