--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Flora
-- Biome vegetation and rocks, scattered to match the reference: snowy
-- pines in the white north, cacti and dry scrub in the desert, mixed
-- pine/blossom/bamboo through the green realm. Keeps clear of the
-- mountain ring, the cities, and the coast.

local BuildKit = require(script.Parent.BuildKit)
local Island = require(script.Parent.Island)
local Cities = require(script.Parent.Cities)

local Flora = {}

local TRUNK = Color3.fromRGB(92, 70, 52)
local PINE_GREEN = Color3.fromRGB(52, 84, 60)
local PINE_DARK = Color3.fromRGB(40, 66, 48)
local SNOW_WHITE = Color3.fromRGB(238, 242, 246)
local BLOSSOM_PINK = Color3.fromRGB(240, 184, 205)
local BLOSSOM_WHITE = Color3.fromRGB(246, 238, 230)
local BAMBOO_GREEN = Color3.fromRGB(126, 168, 92)
local CACTUS_GREEN = Color3.fromRGB(96, 142, 74)

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

local function pineTree(parent: Instance, position: Vector3, rng: Random, snowy: boolean)
	local height = rng:NextNumber(34, 62)
	local lean = rng:NextNumber(-0.08, 0.08)
	BuildKit.part({
		name = "Pine_Trunk",
		size = Vector3.new(3.2, height, 3.2),
		cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(lean, 0, lean),
		color = TRUNK,
		material = Enum.Material.Wood,
		parent = parent,
	})
	local layers = rng:NextInteger(4, 5)
	for layer = 1, layers do
		local t = (layer - 1) / layers
		local layerY = position.Y + height * (0.5 + 0.55 * t)
		local diameter = (30 - t * 16) * rng:NextNumber(0.9, 1.15)
		local color = if snowy and layer == layers
			then SNOW_WHITE
			elseif layer % 2 == 0 then PINE_DARK
			else PINE_GREEN
		BuildKit.cylinder(parent, "Pine_Canopy", Vector3.new(position.X, layerY, position.Z), 2.2, diameter,
			color, if snowy and layer == layers then Enum.Material.Snow else Enum.Material.Grass)
		if snowy and layer < layers then
			-- Snow dusting on the lower boughs' rims.
			BuildKit.cylinder(parent, "Pine_Snow", Vector3.new(position.X, layerY + 1.3, position.Z), 0.8, diameter * 0.8,
				SNOW_WHITE, Enum.Material.Snow)
		end
	end
end

local function blossomTree(parent: Instance, position: Vector3, rng: Random)
	local height = rng:NextNumber(24, 38)
	local lean = rng:NextNumber(-0.14, 0.14)
	BuildKit.part({
		name = "Blossom_Trunk",
		size = Vector3.new(2.8, height, 2.8),
		cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(lean, 0, -lean),
		color = Color3.fromRGB(70, 54, 44),
		material = Enum.Material.Wood,
		parent = parent,
	})
	local crown = position + Vector3.new(lean * height * 4, height, lean * height * 4)
	for _ = 1, rng:NextInteger(4, 6) do
		local offset = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-2, 7), rng:NextNumber(-9, 9))
		local width = rng:NextNumber(11, 18)
		puff(parent, crown + offset, Vector3.new(width, width * 0.65, width),
			if rng:NextNumber() < 0.7 then BLOSSOM_PINK else BLOSSOM_WHITE)
	end
end

local function bambooClump(parent: Instance, position: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(5, 8) do
		local culmHeight = rng:NextNumber(50, 90)
		local base = position + Vector3.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7))
		BuildKit.part({
			name = "Bamboo_Culm",
			size = Vector3.new(1.4, culmHeight, 1.4),
			cframe = CFrame.new(base + Vector3.new(0, culmHeight / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05)),
			color = BAMBOO_GREEN,
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
		puff(parent, base + Vector3.new(0, culmHeight, 0), Vector3.new(8, 5, 8), Color3.fromRGB(110, 150, 82))
	end
end

local function cactus(parent: Instance, position: Vector3, rng: Random)
	local height = rng:NextNumber(12, 22)
	local body = BuildKit.part({
		name = "Cactus",
		size = Vector3.new(2.2, height, 2.2),
		position = position + Vector3.new(0, height / 2, 0),
		color = CACTUS_GREEN,
		material = Enum.Material.Grass,
		parent = parent,
	})
	for side = -1, 1, 2 do
		if rng:NextNumber() < 0.7 then
			local armY = rng:NextNumber(0.35, 0.6) * height
			BuildKit.part({
				name = "Cactus_Arm",
				size = Vector3.new(1.4, 1.4, 3),
				position = body.Position + Vector3.new(side * 2.4, armY - height / 2, 0),
				color = CACTUS_GREEN,
				material = Enum.Material.Grass,
				canCollide = false,
				parent = parent,
			})
			BuildKit.part({
				name = "Cactus_ArmUp",
				size = Vector3.new(1.4, 4, 1.4),
				position = body.Position + Vector3.new(side * 3.2, armY - height / 2 + 2, 0),
				color = CACTUS_GREEN,
				material = Enum.Material.Grass,
				canCollide = false,
				parent = parent,
			})
		end
	end
end

local function boulder(parent: Instance, position: Vector3, rng: Random, snowy: boolean)
	local size = rng:NextNumber(5, 14)
	BuildKit.part({
		name = "Boulder",
		size = Vector3.new(size, size * 0.7, size * rng:NextNumber(0.7, 1.3)),
		cframe = CFrame.new(position + Vector3.new(0, size * 0.2, 0))
			* CFrame.Angles(rng:NextNumber(0, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(0, 0.3)),
		color = if snowy then Color3.fromRGB(205, 212, 220) else Color3.fromRGB(120, 116, 112),
		material = Enum.Material.Slate,
		parent = parent,
	})
end

local function clearOfLandmarks(x: number, z: number): boolean
	local distance = math.sqrt(x * x + z * z)
	if distance < 1080 or distance > 3350 then
		return false -- mountain ring / open sea
	end
	for _, center in Cities.POSITIONS :: { [string]: Vector3 } do
		local dx = x - center.X
		local dz = z - center.Z
		if dx * dx + dz * dz < 400 * 400 then
			return false
		end
	end
	return true
end

function Flora.build(parent: Instance)
	local rng = Random.new(7)
	for _ = 1, 480 do
		local theta = rng:NextNumber(-180, 180)
		local distance = rng:NextNumber(1100, 3300)
		local x = math.sin(math.rad(theta)) * distance
		local z = -math.cos(math.rad(theta)) * distance
		if not clearOfLandmarks(x, z) then
			continue
		end
		local position = Vector3.new(x, 0, z)
		local biome = Island.biomeAt(x, z)
		local roll = rng:NextNumber()
		if biome == "snow" then
			if roll < 0.75 then
				pineTree(parent, position, rng, true)
			else
				boulder(parent, position, rng, true)
			end
		elseif biome == "desert" then
			if roll < 0.55 then
				cactus(parent, position, rng)
			elseif roll < 0.8 then
				boulder(parent, position, rng, false)
			else
				pineTree(parent, position, rng, false) -- the odd hardy tree
			end
		else
			if roll < 0.42 then
				pineTree(parent, position, rng, false)
			elseif roll < 0.68 then
				blossomTree(parent, position, rng)
			elseif roll < 0.85 then
				bambooClump(parent, position, rng)
			else
				boulder(parent, position, rng, false)
			end
		end
	end
end

return Flora
