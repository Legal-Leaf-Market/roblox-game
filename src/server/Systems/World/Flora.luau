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
	-- Thick overlapping tiers build a solid cone; the old 2-stud pancake
	-- discs read as stacked umbrella tables from any distance. Crowns do
	-- not collide: an invisible ceiling under every tree feels terrible,
	-- and with CanQuery off, techniques fly through leaves.
	local layers = rng:NextInteger(4, 5)
	for layer = 1, layers do
		local t = (layer - 1) / layers
		local layerY = position.Y + height * (0.5 + 0.55 * t)
		local diameter = (30 - t * 17) * rng:NextNumber(0.9, 1.15)
		local color = if snowy and layer == layers
			then SNOW_WHITE
			elseif layer % 2 == 0 then PINE_DARK
			else PINE_GREEN
		BuildKit.cylinder(parent, "Pine_Canopy", Vector3.new(position.X, layerY, position.Z), height * 0.14, diameter,
			color, if snowy and layer == layers then Enum.Material.Snow else Enum.Material.Grass, false)
		if snowy and layer < layers then
			-- Snow dusting on the lower boughs' rims.
			BuildKit.cylinder(parent, "Pine_Snow", Vector3.new(position.X, layerY + height * 0.075, position.Z), 1.2, diameter * 0.85,
				SNOW_WHITE, Enum.Material.Snow, false, false)
		end
	end
	-- A pointed tip finishes the cone.
	BuildKit.cylinder(parent, "Pine_Tip", Vector3.new(position.X, position.Y + height * 1.08, position.Z), height * 0.12, 6.5,
		if snowy then SNOW_WHITE else PINE_GREEN, if snowy then Enum.Material.Snow else Enum.Material.Grass, false, false)
end

-- A dead, wind-bent tree for the harsh country: bare trunk, a few gnarled
-- branches, no leaves. The desert had "the odd hardy pine", which read as
-- a lush park tree standing in sand.
local function deadTree(parent: Instance, position: Vector3, rng: Random)
	local height = rng:NextNumber(18, 34)
	local lean = rng:NextNumber(-0.16, 0.16)
	local wood = Color3.fromRGB(96, 82, 66)
	BuildKit.part({
		name = "DeadTree_Trunk",
		size = Vector3.new(2.4, height, 2.4),
		cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(lean, 0, lean * 0.7),
		color = wood,
		material = Enum.Material.Wood,
		parent = parent,
	})
	for _ = 1, rng:NextInteger(2, 4) do
		local branchY = height * rng:NextNumber(0.45, 0.9)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local pitch = rng:NextNumber(0.5, 1.1)
		BuildKit.part({
			name = "DeadTree_Branch",
			size = Vector3.new(0.9, rng:NextNumber(6, 12), 0.9),
			cframe = CFrame.new(position + Vector3.new(0, branchY, 0))
				* CFrame.Angles(0, yaw, pitch)
				* CFrame.new(0, 3.5, 0),
			color = wood,
			material = Enum.Material.Wood,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
	end
end

-- Forest-floor filler: a mossy fallen log or a huddle of shrubs. What
-- breaks "hundreds of evenly spaced trees" into something walked-through.
local function fallenLog(parent: Instance, position: Vector3, rng: Random)
	local length = rng:NextNumber(9, 16)
	local yaw = rng:NextNumber(0, math.pi * 2)
	-- Roblox cylinders already lie along local X, so a log needs only yaw.
	local log = BuildKit.part({
		name = "FallenLog",
		size = Vector3.new(length, 2.2, 2.2),
		cframe = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, yaw, 0),
		color = Color3.fromRGB(86, 66, 48),
		material = Enum.Material.Wood,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	BuildKit.part({
		name = "FallenLog_Moss",
		size = Vector3.new(length * 0.6, 0.4, 2),
		cframe = log.CFrame * CFrame.new(0, 1.1, 0),
		color = Color3.fromRGB(88, 120, 70),
		material = Enum.Material.Grass,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})
end

local function shrubs(parent: Instance, position: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local size = rng:NextNumber(3, 6)
		puff(parent,
			position + Vector3.new(rng:NextNumber(-5, 5), size * 0.3, rng:NextNumber(-5, 5)),
			Vector3.new(size, size * 0.7, size),
			if rng:NextNumber() < 0.8 then Color3.fromRGB(78, 112, 64) else Color3.fromRGB(126, 150, 84))
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
	local LEAF = Color3.fromRGB(104, 146, 78)
	local LEAF_LIGHT = Color3.fromRGB(126, 166, 92)
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
		-- A real leafy crown, not one tiny nub on a bare pole: a big canopy
		-- puff at the tip, a second offset lower, and a drooping side spray.
		local top = base + Vector3.new(0, culmHeight, 0)
		puff(parent, top, Vector3.new(rng:NextNumber(13, 18), rng:NextNumber(7, 10), rng:NextNumber(13, 18)), LEAF)
		puff(parent,
			top + Vector3.new(rng:NextNumber(-6, 6), -rng:NextNumber(5, 10), rng:NextNumber(-6, 6)),
			Vector3.new(rng:NextNumber(9, 13), rng:NextNumber(5, 7), rng:NextNumber(9, 13)), LEAF_LIGHT)
		puff(parent,
			top + Vector3.new(rng:NextNumber(-9, 9), -rng:NextNumber(14, 24), rng:NextNumber(-9, 9)),
			Vector3.new(rng:NextNumber(6, 9), rng:NextNumber(3, 5), rng:NextNumber(6, 9)), LEAF)
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

-- Distance from point P to the segment A-B, in the ground plane.
local function distanceToSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local abx, abz = bx - ax, bz - az
	local lengthSq = abx * abx + abz * abz
	if lengthSq < 1e-4 then
		return math.sqrt((px - ax) ^ 2 + (pz - az) ^ 2)
	end
	local t = math.clamp(((px - ax) * abx + (pz - az) * abz) / lengthSq, 0, 1)
	local cx, cz = ax + abx * t, az + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- The spoke roads Overworld lays from the inner ring to each biome city
-- gate; kept in sync with Overworld.buildRoads by construction from the
-- same city positions.
local SPOKES: { { ax: number, az: number, bx: number, bz: number } } = {}
for _, key in { "orthodox", "demonic", "unorthodox" } do
	local center = Cities.POSITIONS[key]
	local direction = Vector3.new(center.X, 0, center.Z).Unit
	table.insert(SPOKES, {
		ax = direction.X * 1280,
		az = direction.Z * 1280,
		bx = center.X - direction.X * 380,
		bz = center.Z - direction.Z * 380,
	})
end

-- The Sacred sites' clearings (kept in sync with World/Sacred by hand;
-- both are code, so a drift shows up the first time either moves).
local SACRED_CLEARINGS = {
	{ x = 1750, z = 1050, r = 50 }, -- the bamboo grove
	{ x = -900, z = 2200, r = 50 }, -- the blossom hill
}

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
	for _, clearing in SACRED_CLEARINGS do
		local dx = x - clearing.x
		local dz = z - clearing.z
		if dx * dx + dz * dz < clearing.r * clearing.r then
			return false
		end
	end
	-- Off the roads: the two ring roads are circles about the origin, the
	-- spokes are segments. A tree in the road is a tree in the road.
	if math.abs(distance - 1280) < 18 or math.abs(distance - 2480) < 18 then
		return false
	end
	for _, spoke in SPOKES do
		if distanceToSegment(x, z, spoke.ax, spoke.az, spoke.bx, spoke.bz) < 16 then
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
			if roll < 0.7 then
				pineTree(parent, position, rng, true)
			elseif roll < 0.88 then
				boulder(parent, position, rng, true)
			else
				deadTree(parent, position, rng)
			end
		elseif biome == "desert" then
			if roll < 0.5 then
				cactus(parent, position, rng)
			elseif roll < 0.75 then
				boulder(parent, position, rng, false)
			else
				deadTree(parent, position, rng) -- wind-bent, bare; not a park pine
			end
		else
			if roll < 0.36 then
				pineTree(parent, position, rng, false)
			elseif roll < 0.58 then
				blossomTree(parent, position, rng)
			elseif roll < 0.74 then
				bambooClump(parent, position, rng)
			elseif roll < 0.84 then
				boulder(parent, position, rng, false)
			elseif roll < 0.92 then
				shrubs(parent, position, rng)
			else
				fallenLog(parent, position, rng)
			end
		end
	end

	-- Trees inside every city's walls, like the reference village: blossoms
	-- and pines between the houses (biome-appropriate outside the crater).
	-- Each candidate is checked against what the city actually built, so a
	-- tree no longer grows out of somebody's roof.
	for key, center in Cities.POSITIONS :: { [string]: Vector3 } do
		local cityRng = Random.new(31 + #key)
		local footprints: { Cities.Footprint } = Cities.FOOTPRINTS[key] or {}
		local planted = 0
		local attempts = 0
		while planted < 7 and attempts < 40 do
			attempts += 1
			local angle = cityRng:NextNumber(0, math.pi * 2)
			local dist = cityRng:NextNumber(70, 220)
			local position = Vector3.new(center.X + math.cos(angle) * dist, center.Y, center.Z + math.sin(angle) * dist)
			local blocked = false
			for _, footprint in footprints do
				local dx = position.X - footprint.x
				local dz = position.Z - footprint.z
				if dx * dx + dz * dz < (footprint.r + 6) * (footprint.r + 6) then
					blocked = true
					break
				end
			end
			if blocked then
				continue
			end
			planted += 1
			local biome: Island.Biome = if key == "central" then "green" else Island.biomeAt(position.X, position.Z)
			if biome == "snow" then
				pineTree(parent, position, cityRng, true)
			elseif biome == "desert" then
				cactus(parent, position, cityRng)
			elseif cityRng:NextNumber() < 0.6 then
				blossomTree(parent, position, cityRng)
			else
				pineTree(parent, position, cityRng, false)
			end
		end
	end
end

return Flora
