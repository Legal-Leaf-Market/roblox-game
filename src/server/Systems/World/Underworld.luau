--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Underworld
-- Everything beneath Heavenpillar: the shaft down from the surface, the
-- Mining Hall (tier-1 ore), the Deepforge Hall (tier-2 ore), the Spirit
-- Forge, and Grandmaster Khadun himself. Built against Overworld.HOLE so
-- the shaft lines up with the hole left in the ground.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ores = require(Shared:WaitForChild("Data"):WaitForChild("Ores"))

local BuildKit = require(script.Parent.BuildKit)
local Overworld = require(script.Parent.Overworld)

local Underworld = {}

local FLOOR_Y = -60 -- cave floor (top surface)
local CEILING_Y = -24 -- cave ceiling (bottom surface)
local SLAB = 6
local STONE = Color3.fromRGB(76, 72, 78)
local STONE_DARK = Color3.fromRGB(58, 55, 62)

-- Mining Hall interior bounds
local HALL = { x1 = -90, x2 = 90, z1 = 300, z2 = 460 }
-- Deepforge Hall interior bounds
local FORGE_HALL = { x1 = -70, x2 = 70, z1 = 460, z2 = 600 }
local DOOR_WIDTH = 24

local wallHeight = CEILING_Y - FLOOR_Y

local function floorAndCeiling(parent: Instance, name: string, bounds: { x1: number, x2: number, z1: number, z2: number })
	local cx = (bounds.x1 + bounds.x2) / 2
	local cz = (bounds.z1 + bounds.z2) / 2
	local sx = bounds.x2 - bounds.x1 + SLAB * 2
	local sz = bounds.z2 - bounds.z1
	BuildKit.part({
		name = name .. "_Floor",
		size = Vector3.new(sx, SLAB, sz),
		position = Vector3.new(cx, FLOOR_Y - SLAB / 2, cz),
		color = STONE_DARK,
		material = Enum.Material.Slate,
		parent = parent,
	})
	BuildKit.part({
		name = name .. "_Ceiling",
		size = Vector3.new(sx, SLAB, sz),
		position = Vector3.new(cx, CEILING_Y + SLAB / 2, cz),
		color = STONE_DARK,
		material = Enum.Material.Slate,
		parent = parent,
	})
end

local function torch(parent: Instance, position: Vector3)
	local sconce = BuildKit.part({
		name = "Torch",
		size = Vector3.new(0.8, 3, 0.8),
		position = position,
		color = Color3.fromRGB(70, 55, 40),
		material = Enum.Material.Wood,
		canCollide = false,
		parent = parent,
	})
	local flame = BuildKit.part({
		name = "Torch_Flame",
		size = Vector3.new(1, 1, 1),
		position = position + Vector3.new(0, 2, 0),
		color = Color3.fromRGB(255, 170, 80),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = parent,
	})
	BuildKit.pointLight(flame, Color3.fromRGB(255, 170, 90), 1.8, 34)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Parent = flame
	return sconce
end

local function buildShaft(parent: Instance)
	local hole = Overworld.HOLE
	-- Ramp from the surface lip (z1) down to the hall mouth (z2).
	local from = Vector3.new(0, Overworld.GROUND_TOP, hole.z1 + 1)
	local to = Vector3.new(0, FLOOR_Y, hole.z2 + 2)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude + 8
	BuildKit.part({
		name = "Shaft_Ramp",
		size = Vector3.new(hole.x2 - hole.x1 - 2, 2, length),
		cframe = CFrame.lookAt(mid, to),
		color = STONE,
		material = Enum.Material.Cobblestone,
		parent = parent,
	})
	-- Shaft side and head walls, sealing the underground faces of the hole.
	local depth = Overworld.GROUND_TOP - (FLOOR_Y - SLAB)
	BuildKit.wallZ(parent, "Shaft_WallW", hole.x1, hole.z1, hole.z2, FLOOR_Y - SLAB, depth, SLAB, STONE, Enum.Material.Slate)
	BuildKit.wallZ(parent, "Shaft_WallE", hole.x2, hole.z1, hole.z2, FLOOR_Y - SLAB, depth, SLAB, STONE, Enum.Material.Slate)
	BuildKit.wallX(parent, "Shaft_WallN", hole.z1 - SLAB / 2, hole.x1 - SLAB, hole.x2 + SLAB, FLOOR_Y - SLAB, depth, SLAB, STONE, Enum.Material.Slate)
end

local function buildMiningHall(parent: Instance)
	local hole = Overworld.HOLE
	floorAndCeiling(parent, "MiningHall", HALL)
	-- North wall: opening where the shaft arrives.
	BuildKit.wallX(parent, "MiningHall_WallN", HALL.z1, HALL.x1 - SLAB, HALL.x2 + SLAB, FLOOR_Y, wallHeight, SLAB, STONE, Enum.Material.Slate, 0, (hole.x2 - hole.x1))
	-- South wall: doorway to the Deepforge.
	BuildKit.wallX(parent, "MiningHall_WallS", HALL.z2, HALL.x1 - SLAB, HALL.x2 + SLAB, FLOOR_Y, wallHeight, SLAB, STONE, Enum.Material.Slate, 0, DOOR_WIDTH)
	BuildKit.wallZ(parent, "MiningHall_WallW", HALL.x1, HALL.z1, HALL.z2, FLOOR_Y, wallHeight, SLAB, STONE, Enum.Material.Slate)
	BuildKit.wallZ(parent, "MiningHall_WallE", HALL.x2, HALL.z1, HALL.z2, FLOOR_Y, wallHeight, SLAB, STONE, Enum.Material.Slate)

	-- Torches along both long walls.
	for z = HALL.z1 + 20, HALL.z2 - 20, 40 do
		torch(parent, Vector3.new(HALL.x1 + 2, FLOOR_Y + 8, z))
		torch(parent, Vector3.new(HALL.x2 - 2, FLOOR_Y + 8, z))
	end

	-- A pair of dummies so miners can practice between veins.
	BuildKit.trainingDummy(parent, Vector3.new(-60, FLOOR_Y, 320))
	BuildKit.trainingDummy(parent, Vector3.new(60, FLOOR_Y, 320))
end

local function buildDeepforgeHall(parent: Instance)
	floorAndCeiling(parent, "Deepforge", FORGE_HALL)
	BuildKit.wallX(parent, "Deepforge_WallS", FORGE_HALL.z2, FORGE_HALL.x1 - SLAB, FORGE_HALL.x2 + SLAB, FLOOR_Y, wallHeight, SLAB, STONE, Enum.Material.Slate)
	BuildKit.wallZ(parent, "Deepforge_WallW", FORGE_HALL.x1, FORGE_HALL.z1, FORGE_HALL.z2, FLOOR_Y, wallHeight, SLAB, STONE, Enum.Material.Slate)
	BuildKit.wallZ(parent, "Deepforge_WallE", FORGE_HALL.x2, FORGE_HALL.z1, FORGE_HALL.z2, FLOOR_Y, wallHeight, SLAB, STONE, Enum.Material.Slate)
	-- Filler walls narrowing the hall mouth to the shared doorway.
	BuildKit.wallX(parent, "Deepforge_WallN_W", FORGE_HALL.z1, FORGE_HALL.x1 - SLAB, -DOOR_WIDTH / 2, FLOOR_Y, wallHeight, SLAB, STONE, Enum.Material.Slate)
	BuildKit.wallX(parent, "Deepforge_WallN_E", FORGE_HALL.z1, DOOR_WIDTH / 2, FORGE_HALL.x2 + SLAB, FLOOR_Y, wallHeight, SLAB, STONE, Enum.Material.Slate)

	for z = FORGE_HALL.z1 + 20, FORGE_HALL.z2 - 20, 35 do
		torch(parent, Vector3.new(FORGE_HALL.x1 + 2, FLOOR_Y + 8, z))
		torch(parent, Vector3.new(FORGE_HALL.x2 - 2, FLOOR_Y + 8, z))
	end

	-- ------------------------- The Spirit Forge -------------------------
	BuildKit.part({
		name = "Forge_Furnace",
		size = Vector3.new(10, 12, 10),
		position = Vector3.new(-24, FLOOR_Y + 6, 560),
		color = Color3.fromRGB(50, 46, 52),
		material = Enum.Material.Basalt,
		parent = parent,
	})
	local maw = BuildKit.part({
		name = "Forge_Maw",
		size = Vector3.new(6, 5, 1),
		position = Vector3.new(-24, FLOOR_Y + 4, 554.6),
		color = Color3.fromRGB(255, 120, 40),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = parent,
	})
	BuildKit.pointLight(maw, Color3.fromRGB(255, 130, 50), 3, 44)
	local forgeFire = Instance.new("Fire")
	forgeFire.Size = 8
	forgeFire.Heat = 10
	forgeFire.Parent = maw

	local anvil = BuildKit.part({
		name = "SpiritForge_Anvil",
		size = Vector3.new(6, 3.5, 3),
		position = Vector3.new(-10, FLOOR_Y + 2.5, 552),
		color = Color3.fromRGB(120, 124, 136),
		material = Enum.Material.Metal,
		parent = parent,
	})
	BuildKit.prompt(anvil, "Craft", "Spirit Forge", 0.5, "ForgePrompt")
	BuildKit.billboard(anvil, "The Spirit Forge", Color3.fromRGB(255, 180, 90), 12, 1.8, Vector3.new(0, 4, 0))
	BuildKit.safeZone(parent, Vector3.new(-14, FLOOR_Y, 556), 45)

	-- ---------------------- Grandmaster Khadun ---------------------------
	local dwarf = Instance.new("Model")
	dwarf.Name = "GrandmasterKhadun"
	local base = Vector3.new(-16, FLOOR_Y, 545)
	local skin = Color3.fromRGB(224, 172, 128)
	local body = BuildKit.part({
		name = "Body",
		size = Vector3.new(3.4, 2.8, 2),
		position = base + Vector3.new(0, 2.4, 0),
		color = Color3.fromRGB(122, 62, 44),
		material = Enum.Material.Fabric,
		parent = dwarf,
	})
	BuildKit.part({
		name = "Legs",
		size = Vector3.new(3, 1, 1.8),
		position = base + Vector3.new(0, 0.5, 0),
		color = Color3.fromRGB(60, 52, 48),
		material = Enum.Material.Fabric,
		parent = dwarf,
	})
	BuildKit.part({
		name = "Head",
		size = Vector3.new(1.9, 1.7, 1.8),
		position = base + Vector3.new(0, 4.6, 0),
		color = skin,
		material = Enum.Material.SmoothPlastic,
		parent = dwarf,
	})
	BuildKit.part({
		name = "Beard",
		size = Vector3.new(1.7, 2.4, 0.6),
		position = base + Vector3.new(0, 3.5, -0.9),
		color = Color3.fromRGB(200, 120, 60),
		material = Enum.Material.Fabric,
		canCollide = false,
		parent = dwarf,
	})
	BuildKit.part({
		name = "Helm",
		size = Vector3.new(2.1, 0.9, 2),
		position = base + Vector3.new(0, 5.7, 0),
		color = Color3.fromRGB(130, 134, 146),
		material = Enum.Material.Metal,
		canCollide = false,
		parent = dwarf,
	})
	dwarf.PrimaryPart = body
	BuildKit.prompt(body, "Talk", "Grandmaster Khadun", 0, "DwarfPrompt")
	BuildKit.billboard(body, "Grandmaster Khadun\nKeeper of the Deepforge", Color3.fromRGB(255, 200, 130), 14, 2.4, Vector3.new(0, 5, 0))
	dwarf.Parent = parent
end

local function scatterOre(parent: Instance)
	local rng = Random.new(23) -- deterministic layout
	local function place(oreId: string, count: number, bounds: { x1: number, x2: number, z1: number, z2: number })
		local ore = Ores.get(oreId)
		if ore == nil then
			return
		end
		for _ = 1, count do
			local x = rng:NextNumber(bounds.x1 + 12, bounds.x2 - 12)
			local z = rng:NextNumber(bounds.z1 + 14, bounds.z2 - 14)
			-- Keep the forge corner clear for the dwarf's floor space.
			if z > 530 and x < 5 then
				x += 40
			end
			BuildKit.oreNode(parent, Vector3.new(x, FLOOR_Y, z), ore.id, ore.name, ore.color)
		end
	end

	-- Tier 1: Mining Hall
	place("black_iron", 8, HALL)
	place("cold_iron", 5, HALL)
	place("spirit_stone", 6, HALL)
	-- Tier 2: Deepforge Hall
	place("meteoric_iron", 4, FORGE_HALL)
	place("star_silver", 3, FORGE_HALL)
	place("profound_gold", 2, FORGE_HALL)
	place("immortal_jade", 2, FORGE_HALL)
	place("spirit_stone", 2, FORGE_HALL)
end

function Underworld.build(parent: Instance)
	buildShaft(parent)
	buildMiningHall(parent)
	buildDeepforgeHall(parent)
	scatterOre(parent)
end

return Underworld
