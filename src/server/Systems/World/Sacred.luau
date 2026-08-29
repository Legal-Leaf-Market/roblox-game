--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Sacred
-- Places worth meditating in: a deck beside the waterfall pool, a bamboo
-- grove pavilion in the eastern forest, a blossom hill in the south, and
-- the summit platform's marker. Each carries the CultivationZone tag and a
-- QiDensity attribute; nothing reads them yet, so today they are pure
-- scenery, and the day meditation bonuses arrive the world is already
-- marked out. (QiSystem is the intended reader.)

local CollectionService = game:GetService("CollectionService")

local BuildKit = require(script.Parent.BuildKit)
local Island = require(script.Parent.Island)

local Sacred = {}

local MAT_COLOR = Color3.fromRGB(178, 150, 100)
local STONE = Color3.fromRGB(150, 148, 144)
local TIMBER = Color3.fromRGB(74, 53, 39)

-- Invisible marker the future bonus system will query.
local function markZone(parent: Instance, position: Vector3, radius: number, qiDensity: number, siteName: string)
	local marker = BuildKit.part({
		name = "CultivationZone",
		size = Vector3.new(1, 1, 1),
		position = position,
		transparency = 1,
		canCollide = false,
		parent = parent,
	})
	marker:SetAttribute("Radius", radius)
	marker:SetAttribute("QiDensity", qiDensity)
	marker:SetAttribute("SiteName", siteName)
	CollectionService:AddTag(marker, "CultivationZone")
end

local function mats(parent: Instance, center: Vector3, count: number, ringRadius: number)
	for index = 1, count do
		local angle = index / count * math.pi * 2
		BuildKit.part({
			name = "Meditation_Mat",
			size = Vector3.new(3.6, 0.25, 3.6),
			cframe = CFrame.new(center + Vector3.new(math.cos(angle) * ringRadius, 0.15, math.sin(angle) * ringRadius))
				* CFrame.Angles(0, -angle, 0),
			color = MAT_COLOR,
			material = Enum.Material.Fabric,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
	end
end

local function stoneLantern(parent: Instance, position: Vector3, lit: boolean)
	BuildKit.part({
		name = "Sacred_StoneLantern",
		size = Vector3.new(2, 4.6, 2),
		position = position + Vector3.new(0, 2.3, 0),
		color = STONE,
		material = Enum.Material.Slate,
		parent = parent,
	})
	local cap = BuildKit.part({
		name = "Sacred_LanternCap",
		size = Vector3.new(3, 1, 3),
		position = position + Vector3.new(0, 5.1, 0),
		color = Color3.fromRGB(120, 118, 116),
		material = Enum.Material.Slate,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})
	if lit then
		BuildKit.pointLight(cap, Color3.fromRGB(255, 200, 130), 1.1, 20)
	end
end

-- ------------------- The pool deck under the waterfall -------------------

local function buildPoolDeck(parent: Instance)
	local deckCenter = Vector3.new(0, Island.VALLEY_Y + 0.6, -376)
	BuildKit.part({
		name = "PoolDeck",
		size = Vector3.new(26, 1.2, 18),
		position = deckCenter,
		color = Color3.fromRGB(133, 100, 68),
		material = Enum.Material.WoodPlanks,
		parent = parent,
	})
	-- Low rail on the water side only; the view stays open.
	BuildKit.part({
		name = "PoolDeck_Rail",
		size = Vector3.new(26, 2, 0.8),
		position = deckCenter + Vector3.new(0, 1.6, -9),
		color = Color3.fromRGB(94, 70, 48),
		material = Enum.Material.Wood,
		parent = parent,
	})
	mats(parent, deckCenter + Vector3.new(0, 0.6, 2), 4, 7)
	stoneLantern(parent, deckCenter + Vector3.new(-11, -0.6, 8), true)
	stoneLantern(parent, deckCenter + Vector3.new(11, -0.6, 8), true)
	local deck = parent:FindFirstChild("PoolDeck")
	if deck and deck:IsA("BasePart") then
		BuildKit.billboard(deck, "The Listening Deck. The falls drown every thought but your own.", Color3.fromRGB(210, 230, 245), 20, 2.2, Vector3.new(0, 6, 0))
	end
	markZone(parent, deckCenter, 26, 2, "The Listening Deck")
end

-- ----------------------- The bamboo grove pavilion -----------------------

local function buildBambooGrove(parent: Instance)
	local center = Vector3.new(1750, 0, 1050)
	local rng = Random.new(77)
	-- A ring of giant bamboo enclosing the clearing, gap to the west.
	for index = 1, 14 do
		local angle = index / 14 * math.pi * 2
		if math.abs(math.atan2(math.sin(angle - math.pi), math.cos(angle - math.pi))) < 0.5 then
			continue -- the way in
		end
		local culmBase = center + Vector3.new(math.cos(angle) * rng:NextNumber(24, 34), 0, math.sin(angle) * rng:NextNumber(24, 34))
		local culmHeight = rng:NextNumber(55, 85)
		BuildKit.part({
			name = "Grove_Bamboo",
			size = Vector3.new(1.6, culmHeight, 1.6),
			cframe = CFrame.new(culmBase + Vector3.new(0, culmHeight / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.04, 0.04)),
			color = Color3.fromRGB(126, 168, 92),
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
		local leaves = BuildKit.part({
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
		mesh.Scale = Vector3.new(rng:NextNumber(11, 15), rng:NextNumber(6, 8), rng:NextNumber(11, 15))
		mesh.Parent = leaves
	end
	BuildKit.pavilion(parent, center, 16, TIMBER, Color3.fromRGB(70, 96, 74))
	mats(parent, center + Vector3.new(0, 0.4, 0), 4, 6)
	local zone = BuildKit.part({
		name = "GroveHeart",
		size = Vector3.new(2, 0.4, 2),
		position = center + Vector3.new(0, 0.2, 0),
		color = STONE,
		material = Enum.Material.Marble,
		canCollide = false,
		parent = parent,
	})
	BuildKit.billboard(zone, "The Whispering Grove. Bamboo bends; the cultivator does not.", Color3.fromRGB(170, 210, 150), 20, 2.2, Vector3.new(0, 8, 0))
	markZone(parent, center, 30, 2, "The Whispering Grove")
end

-- -------------------------- The blossom circle ---------------------------

local function buildBlossomHill(parent: Instance)
	local center = Vector3.new(-900, 0, 2200)
	-- One ancient blossom tree, far larger than its forest kin.
	local trunkHeight = 52
	BuildKit.part({
		name = "AncientBlossom_Trunk",
		size = Vector3.new(6, trunkHeight, 6),
		cframe = CFrame.new(center + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0.05, 0, -0.07),
		color = Color3.fromRGB(70, 54, 44),
		material = Enum.Material.Wood,
		parent = parent,
	})
	local canopyRng = Random.new(5)
	for _ = 1, 9 do
		local offset = Vector3.new(canopyRng:NextNumber(-16, 16), canopyRng:NextNumber(-4, 10), canopyRng:NextNumber(-16, 16))
		local width = canopyRng:NextNumber(16, 26)
		local puffPart = BuildKit.part({
			name = "AncientBlossom_Crown",
			size = Vector3.new(1, 1, 1),
			position = center + Vector3.new(0, trunkHeight, 0) + offset,
			color = if canopyRng:NextNumber() < 0.7 then Color3.fromRGB(240, 184, 205) else Color3.fromRGB(246, 238, 230),
			material = Enum.Material.Grass,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(width, width * 0.6, width)
		mesh.Parent = puffPart
	end
	-- Falling petals, sparse.
	local petalAnchor = BuildKit.part({
		name = "AncientBlossom_Petals",
		size = Vector3.new(1, 1, 1),
		position = center + Vector3.new(0, trunkHeight - 6, 0),
		transparency = 1,
		canCollide = false,
		parent = parent,
	})
	local petals = Instance.new("ParticleEmitter")
	petals.Rate = 3
	petals.Lifetime = NumberRange.new(4, 7)
	petals.Speed = NumberRange.new(1, 2)
	petals.Acceleration = Vector3.new(1.2, -2.4, 0.6)
	petals.Size = NumberSequence.new(0.5, 0.3)
	petals.Color = ColorSequence.new(Color3.fromRGB(244, 196, 212))
	petals.Transparency = NumberSequence.new(0.2, 1)
	petals.Parent = petalAnchor
	-- A circle of standing stones around the trunk, and mats within.
	for index = 1, 7 do
		local angle = index / 7 * math.pi * 2
		BuildKit.part({
			name = "BlossomCircle_Stone",
			size = Vector3.new(2.6, 5 + (index % 3), 1.8),
			cframe = CFrame.new(center + Vector3.new(math.cos(angle) * 20, 2.4, math.sin(angle) * 20))
				* CFrame.Angles(0, -angle, math.rad((index % 3 - 1) * 5)),
			color = STONE,
			material = Enum.Material.Slate,
			parent = parent,
		})
	end
	mats(parent, center + Vector3.new(0, 0.2, 0), 5, 12)
	local trunk = parent:FindFirstChild("AncientBlossom_Trunk")
	if trunk and trunk:IsA("BasePart") then
		BuildKit.billboard(trunk, "The Elder Blossom. It has shed a thousand springs and kept none.", Color3.fromRGB(240, 190, 205), 22, 2.4, Vector3.new(0, 30, 0))
	end
	markZone(parent, center, 34, 2, "The Elder Blossom")
end

function Sacred.build(parent: Instance)
	buildPoolDeck(parent)
	buildBambooGrove(parent)
	buildBlossomHill(parent)
	-- The summit was always the fourth site; now it is marked as one.
	markZone(parent, Vector3.new(Island.NORTH_PEAK.X, Island.NORTH_PEAK_TOP, Island.NORTH_PEAK.Z + 44), 42, 3, "The Summit of Heavenpillar")
end

return Sacred
