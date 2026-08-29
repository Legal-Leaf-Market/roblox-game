--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Vale
-- The handcrafted layer of the Azure Vale: Willowrest village, the river
-- bridge, stone paths, the sacred meditation sites, and the beast ranges.
-- Every position is placed at Terrain.heightAt ground truth: nothing
-- floats, nothing sinks. Nothing here is scattered at random; the vale
-- is laid out like somebody lives in it.

local Kit = require(script.Parent.Kit)
local Terrain = require(script.Parent.Terrain)

local Vale = {}

local TIMBER = Color3.fromRGB(74, 53, 39)
local PLASTER = Color3.fromRGB(236, 229, 214)
local ROOF_BLUE = Color3.fromRGB(62, 74, 88)
local ROOF_STRAW = Color3.fromRGB(178, 148, 76)
local STONE = Color3.fromRGB(152, 148, 140)

local function ground(x: number, z: number): Vector3
	return Vector3.new(x, Terrain.heightAt(x, z), z)
end

-- Face a build position AWAY from a target so its +Z door looks at it.
local function doorToward(position: Vector3, target: Vector3): CFrame
	local flatTarget = Vector3.new(target.X, position.Y, target.Z)
	return CFrame.lookAt(position, position * 2 - flatTarget)
end

-- A stone path following the terrain, sampled and laid slab by slab.
local function path(parent: Instance, points: { Vector2 }, width: number)
	for index = 1, #points - 1 do
		local a = points[index]
		local b = points[index + 1]
		local length = (b - a).Magnitude
		local steps = math.max(1, math.floor(length / 13))
		for step = 0, steps - 1 do
			local t0 = step / steps
			local t1 = (step + 1) / steps
			local p0 = a:Lerp(b, t0)
			local p1 = a:Lerp(b, t1)
			local h0 = Terrain.heightAt(p0.X, p0.Y)
			local h1 = Terrain.heightAt(p1.X, p1.Y)
			local from = Vector3.new(p0.X, h0 + 0.55, p0.Y)
			local to = Vector3.new(p1.X, h1 + 0.55, p1.Y)
			Kit.part({
				name = "Path",
				size = Vector3.new(width, 0.7, (to - from).Magnitude + 2),
				cframe = CFrame.lookAt((from + to) / 2, to),
				color = Color3.fromRGB(172, 164, 150),
				material = Enum.Material.Cobblestone,
				canCollide = false,
				castShadow = false,
				parent = parent,
			})
		end
	end
end

-- ------------------------------ Willowrest -------------------------------

local function buildVillage(parent: Instance)
	local vx, vz = Terrain.VILLAGE.X, Terrain.VILLAGE.Y
	local plazaCenter = ground(vx, vz)

	-- Plaza: a stone circle with the spawn at its heart.
	Kit.cylinder(parent, "Plaza", plazaCenter + Vector3.new(0, 1, 0), 1.4, 62, STONE, Enum.Material.Cobblestone)
	Kit.spawnLocation(parent, plazaCenter + Vector3.new(0, 2, 8))

	-- The village gate, facing the south road.
	local gatePos = ground(vx, vz + 110)
	local sign = Kit.paifang(parent, gatePos, Vector3.new(0, 0, 1), 26, TIMBER, ROOF_BLUE)
	Kit.billboard(sign, "Willowrest\nA quiet place to begin an endless road", Color3.fromRGB(235, 228, 210), 20, 3, Vector3.new(0, 4, 0))

	-- Houses ringing the plaza: hand-placed, each angled to face it.
	local houses = {
		{ x = vx - 70, z = vz - 40, straw = false },
		{ x = vx + 72, z = vz - 30, straw = true },
		{ x = vx - 78, z = vz + 42, straw = true },
		{ x = vx + 80, z = vz + 48, straw = false },
		{ x = vx + 20, z = vz + 78, straw = true },
		{ x = vx - 30, z = vz - 84, straw = false },
	}
	for _, spot in houses do
		local position = ground(spot.x, spot.z)
		Kit.house(parent, doorToward(position, plazaCenter), {
			width = 26,
			depth = 20,
			floors = 1,
			plaster = PLASTER,
			timber = TIMBER,
			roofColor = if spot.straw then ROOF_STRAW else ROOF_BLUE,
			roofMaterial = if spot.straw then Enum.Material.Grass else Enum.Material.Slate,
		})
	end

	-- The village hall: two stories, enterable, lit. The seat of what
	-- passes for authority in Willowrest.
	local hallPos = ground(vx, vz - 95)
	Kit.house(parent, doorToward(hallPos, plazaCenter), {
		width = 42,
		depth = 30,
		floors = 2,
		plaster = PLASTER,
		timber = TIMBER,
		roofColor = ROOF_BLUE,
		roofMaterial = Enum.Material.Slate,
		hollow = true,
		lanternLights = true,
	})

	-- Training yard west of the plaza: mats, dummies, a weapon rack.
	local yardCenter = ground(vx - 95, vz + 5)
	Kit.cylinder(parent, "TrainingYard", yardCenter + Vector3.new(0, 0.8, 0), 1, 40, Color3.fromRGB(168, 158, 140), Enum.Material.Ground)
	for index = -1, 1 do
		Kit.trainingDummy(parent, yardCenter + Vector3.new(index * 12, 1.2, -8))
		Kit.part({
			name = "TrainingMat",
			size = Vector3.new(5, 0.3, 5),
			position = yardCenter + Vector3.new(index * 12, 1.5, 6),
			color = Color3.fromRGB(178, 150, 100),
			material = Enum.Material.Fabric,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
	end
	Kit.part({
		name = "WeaponRack",
		size = Vector3.new(8, 5, 1),
		position = yardCenter + Vector3.new(0, 3.6, 16),
		color = TIMBER,
		material = Enum.Material.Wood,
		parent = parent,
	})

	-- A well, a notice board, market stalls by the gate: the small
	-- furniture of an inhabited place.
	local wellPos = plazaCenter + Vector3.new(38, 0, -16)
	Kit.cylinder(parent, "Well_Ring", wellPos + Vector3.new(0, 2.4, 0), 2.6, 7.5, Color3.fromRGB(140, 138, 134), Enum.Material.Cobblestone)
	Kit.cylinder(parent, "Well_Hole", wellPos + Vector3.new(0, 3.85, 0), 0.3, 5, Color3.fromRGB(24, 26, 30), Enum.Material.SmoothPlastic, false, false)
	Kit.roof(parent, CFrame.new(wellPos.X, 0, wellPos.Z), 6, 6, wellPos.Y + 8.6, ROOF_BLUE)

	local boardPos = ground(vx + 26, vz + 92)
	Kit.part({
		name = "NoticeBoard",
		size = Vector3.new(8, 5.5, 0.7),
		cframe = doorToward(boardPos + Vector3.new(0, 5.4, 0), plazaCenter),
		color = Color3.fromRGB(96, 72, 50),
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})

	for stallSign = -1, 1, 2 do
		local stallPos = ground(vx + stallSign * 24, vz + 66)
		local stallCF = doorToward(stallPos, plazaCenter)
		Kit.part({
			name = "Stall_Counter",
			size = Vector3.new(9, 3.2, 2.8),
			cframe = stallCF * CFrame.new(0, 1.6, 0),
			color = Color3.fromRGB(124, 94, 62),
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
		Kit.part({
			name = "Stall_Awning",
			size = Vector3.new(10, 0.4, 5.5),
			cframe = stallCF * CFrame.new(0, 7.6, -0.5) * CFrame.Angles(math.rad(-9), 0, 0),
			color = if stallSign > 0 then Color3.fromRGB(178, 60, 48) else Color3.fromRGB(214, 200, 170),
			material = Enum.Material.Fabric,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
		for postSign = -1, 1, 2 do
			Kit.part({
				name = "Stall_Post",
				size = Vector3.new(0.7, 7.6, 0.7),
				cframe = stallCF * CFrame.new(postSign * 4.2, 3.8, -1),
				color = TIMBER,
				material = Enum.Material.Wood,
				canCollide = false,
				castShadow = false,
				parent = parent,
			})
		end
	end

	-- Lantern posts along the plaza rim: the village glows at dusk.
	for index = 0, 7 do
		local angle = index / 8 * math.pi * 2 + 0.4
		local postPos = ground(vx + math.cos(angle) * 48, vz + math.sin(angle) * 48)
		Kit.lanternPost(parent, postPos, index % 2 == 0)
	end

	-- Sanctuary: the whole village and its yard.
	Kit.safeZone(parent, plazaCenter, 165)
end

-- ------------------------------ The bridge -------------------------------

local function buildBridge(parent: Instance)
	local from = Vector3.new(122, 0, 296)
	local to = Vector3.new(42, 0, 308)
	local bankHeight = math.max(Terrain.heightAt(from.X, from.Z), Terrain.heightAt(to.X, to.Z))
	local deckY = bankHeight + 1.2
	local mid = (from + to) / 2
	local length = (to - from).Magnitude + 6
	local deckCF = CFrame.lookAt(Vector3.new(mid.X, deckY, mid.Z), Vector3.new(to.X, deckY, to.Z))
	Kit.part({
		name = "Bridge_Deck",
		size = Vector3.new(11, 1.4, length),
		cframe = deckCF,
		color = Color3.fromRGB(133, 100, 68),
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	for side = -1, 1, 2 do
		Kit.part({
			name = "Bridge_Rail",
			size = Vector3.new(0.9, 2.6, length),
			cframe = deckCF * CFrame.new(side * 5, 1.9, 0),
			color = Color3.fromRGB(94, 70, 48),
			material = Enum.Material.Wood,
			parent = parent,
		})
	end
	-- Gentle ramps so both banks meet the deck cleanly.
	for _, bank in { from, to } do
		local bankH = Terrain.heightAt(bank.X, bank.Z)
		local toward = (Vector3.new(mid.X, 0, mid.Z) - Vector3.new(bank.X, 0, bank.Z)).Unit
		Kit.wedge({
			name = "Bridge_Ramp",
			size = Vector3.new(11, math.max(0.5, deckY - bankH + 0.7), 8),
			cframe = CFrame.lookAt(Vector3.new(bank.X, (deckY + bankH) / 2, bank.Z), Vector3.new(bank.X, (deckY + bankH) / 2, bank.Z) + toward)
				* CFrame.Angles(0, math.pi, 0),
			color = Color3.fromRGB(133, 100, 68),
			material = Enum.Material.WoodPlanks,
			parent = parent,
		})
	end
	Kit.lantern(parent, Vector3.new(from.X, deckY + 6, from.Z), 1.8, true)
	Kit.lantern(parent, Vector3.new(to.X, deckY + 6, to.Z), 1.8, true)
end

-- ---------------------------- Sacred places ------------------------------

local function buildSacredSites(parent: Instance)
	-- Riverheart Pool: a listening deck on the bank where the gorge water
	-- settles. The first cultivation spot a new player finds.
	local poolPos = ground(75, -150)
	Kit.part({
		name = "PoolDeck",
		size = Vector3.new(22, 1.2, 15),
		position = poolPos + Vector3.new(0, 1, 0),
		color = Color3.fromRGB(133, 100, 68),
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	for matIndex = -1, 1 do
		Kit.part({
			name = "Meditation_Mat",
			size = Vector3.new(3.4, 0.25, 3.4),
			position = poolPos + Vector3.new(matIndex * 6, 1.75, 2),
			color = Color3.fromRGB(178, 150, 100),
			material = Enum.Material.Fabric,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
	end
	Kit.lantern(parent, poolPos + Vector3.new(-9, 7, 6), 1.8, true)
	Kit.lantern(parent, poolPos + Vector3.new(9, 7, 6), 1.8, true)
	local deck = parent:FindFirstChild("PoolDeck")
	if deck and deck:IsA("BasePart") then
		Kit.billboard(deck, "Riverheart Pool\nThe water carries qi down from the peak. Sit. Listen.", Color3.fromRGB(190, 225, 240), 20, 2.6, Vector3.new(0, 5, 0))
	end
	Kit.cultivationZone(parent, poolPos, 26, 2, "Riverheart Pool")

	-- The mountainside shelf: a pavilion halfway up Heavenpillar.
	local shelfPos = Vector3.new(Terrain.SHELF.X, Terrain.SHELF_HEIGHT, Terrain.SHELF.Y)
	Kit.pavilion(parent, shelfPos, 15, TIMBER, ROOF_BLUE)
	for matIndex = -1, 1 do
		Kit.part({
			name = "Meditation_Mat",
			size = Vector3.new(3.4, 0.25, 3.4),
			position = shelfPos + Vector3.new(matIndex * 5, 1.55, 0),
			color = Color3.fromRGB(178, 150, 100),
			material = Enum.Material.Fabric,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
	end
	Kit.cultivationZone(parent, shelfPos, 30, 2.2, "The Windrest Shelf")

	-- The summit: a stone ring, an old monolith, and the thinnest air on
	-- the island. The strongest open cultivation spot in the vale.
	local summitPos = Vector3.new(Terrain.SUMMIT.X, Terrain.SUMMIT_HEIGHT, Terrain.SUMMIT.Y)
	Kit.cylinder(parent, "Summit_Ring", summitPos + Vector3.new(0, 0.8, 0), 1.2, 52, Color3.fromRGB(210, 205, 190), Enum.Material.Marble)
	local monolith = Kit.part({
		name = "Summit_Monolith",
		size = Vector3.new(4.5, 12, 2.2),
		position = summitPos + Vector3.new(0, 7.4, -16),
		color = Color3.fromRGB(120, 122, 132),
		material = Enum.Material.Slate,
		parent = parent,
	})
	Kit.billboard(monolith, "The Crown of Heavenpillar\nWhat you gather here, the sky gave willingly.", Color3.fromRGB(255, 240, 200), 22, 3, Vector3.new(0, 8, 0))
	for index = 0, 5 do
		local angle = index / 6 * math.pi * 2
		Kit.part({
			name = "Summit_Stone",
			size = Vector3.new(2.2, 4 + (index % 2) * 1.5, 1.6),
			cframe = CFrame.new(summitPos + Vector3.new(math.cos(angle) * 23, 2.6, math.sin(angle) * 23))
				* CFrame.Angles(0, -angle, math.rad((index % 3 - 1) * 6)),
			color = Color3.fromRGB(150, 148, 144),
			material = Enum.Material.Slate,
			parent = parent,
		})
	end
	Kit.cultivationZone(parent, summitPos, 44, 3, "The Crown of Heavenpillar")

	-- The bamboo grove: a green room in the eastern meadow.
	local grovePos = ground(Terrain.GROVE.X, Terrain.GROVE.Y)
	local groveRng = Random.new(41)
	for index = 1, 16 do
		local angle = index / 16 * math.pi * 2
		if math.abs(math.atan2(math.sin(angle - math.pi * 1.5), math.cos(angle - math.pi * 1.5))) < 0.42 then
			continue -- the way in, from the west path
		end
		local culmBase = ground(
			grovePos.X + math.cos(angle) * groveRng:NextNumber(22, 32),
			grovePos.Z + math.sin(angle) * groveRng:NextNumber(22, 32)
		)
		local culmHeight = groveRng:NextNumber(42, 64)
		Kit.part({
			name = "Grove_Bamboo",
			size = Vector3.new(1.5, culmHeight, 1.5),
			cframe = CFrame.new(culmBase + Vector3.new(0, culmHeight / 2, 0))
				* CFrame.Angles(groveRng:NextNumber(-0.04, 0.04), 0, groveRng:NextNumber(-0.04, 0.04)),
			color = Color3.fromRGB(126, 168, 92),
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
		local leaves = Kit.part({
			name = "Grove_Leaves",
			size = Vector3.new(1, 1, 1),
			position = culmBase + Vector3.new(0, culmHeight, 0),
			color = Color3.fromRGB(104, 146, 78),
			material = Enum.Material.Grass,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(groveRng:NextNumber(10, 14), groveRng:NextNumber(5, 8), groveRng:NextNumber(10, 14))
		mesh.Parent = leaves
	end
	Kit.pavilion(parent, grovePos, 13, TIMBER, Color3.fromRGB(70, 96, 74))
	Kit.cultivationZone(parent, grovePos, 36, 1.8, "The Whispering Grove")
end

-- ------------------------------ Beast ranges -----------------------------

local function placeBeasts(parent: Instance)
	Kit.beastSpawn(parent, ground(-100, 80) + Vector3.new(0, 2, 0), "mistfang", 2)
	Kit.beastSpawn(parent, ground(300, 340) + Vector3.new(0, 2, 0), "mistfang", 3)
	Kit.beastSpawn(parent, ground(350, -120) + Vector3.new(0, 2, 0), "mistfang", 2)
	Kit.beastSpawn(parent, ground(-320, -80) + Vector3.new(0, 2, 0), "thornback", 2)
	Kit.beastSpawn(parent, ground(240, -260) + Vector3.new(0, 2, 0), "thornback", 2)
end

-- -------------------------------- Roads ----------------------------------

local function buildRoads(parent: Instance)
	-- Village gate south, west over the bridge.
	path(parent, {
		Vector2.new(170, 262),
		Vector2.new(140, 288),
		Vector2.new(122, 296),
	}, 9)
	path(parent, {
		Vector2.new(42, 308),
		Vector2.new(-40, 300),
		Vector2.new(-140, 270),
	}, 8)
	-- Plaza north toward the pool and the mountain.
	path(parent, {
		Vector2.new(170, 96),
		Vector2.new(150, 20),
		Vector2.new(110, -70),
		Vector2.new(80, -140),
	}, 8)
	-- Plaza east toward the grove.
	path(parent, {
		Vector2.new(226, 150),
		Vector2.new(320, 110),
		Vector2.new(392, 74),
	}, 7)
end

function Vale.build(parent: Instance)
	buildVillage(parent)
	buildBridge(parent)
	buildSacredSites(parent)
	buildRoads(parent)
	placeBeasts(parent)
end

return Vale
