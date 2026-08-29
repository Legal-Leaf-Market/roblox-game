--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > BuildKit
-- Part-factory helpers for the programmatic map. Everything the world
-- builders stamp out flows through here so geometry defaults (anchored,
-- named, parented) stay consistent.

local CollectionService = game:GetService("CollectionService")

local BuildKit = {}

export type PartProps = {
	name: string?,
	size: Vector3,
	cframe: CFrame?,
	position: Vector3?,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	shape: Enum.PartType?,
	parent: Instance,
}

function BuildKit.part(props: PartProps): Part
	local part = Instance.new("Part")
	part.Name = props.name or "Part"
	part.Size = props.size
	if props.cframe then
		part.CFrame = props.cframe
	elseif props.position then
		part.Position = props.position
	end
	part.Color = props.color or Color3.fromRGB(163, 162, 165)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.CanCollide = if props.canCollide == nil then true else props.canCollide
	if props.shape then
		part.Shape = props.shape
	end
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.parent
	return part
end

-- Axis-aligned box by center.
function BuildKit.box(parent: Instance, name: string, center: Vector3, size: Vector3, color: Color3, material: Enum.Material): Part
	return BuildKit.part({
		name = name,
		size = size,
		position = center,
		color = color,
		material = material,
		parent = parent,
	})
end

-- A wall running along the X axis at depth z, from x1 to x2, with an
-- optional doorway gap (gapCenter/gapWidth in X). Returns the segments.
function BuildKit.wallX(parent: Instance, name: string, z: number, x1: number, x2: number, yBottom: number, height: number, thickness: number, color: Color3, material: Enum.Material, gapCenter: number?, gapWidth: number?)
	local yMid = yBottom + height / 2
	local function segment(fromX: number, toX: number)
		if toX - fromX < 0.5 then
			return
		end
		BuildKit.part({
			name = name,
			size = Vector3.new(toX - fromX, height, thickness),
			position = Vector3.new((fromX + toX) / 2, yMid, z),
			color = color,
			material = material,
			parent = parent,
		})
	end
	if gapCenter and gapWidth then
		segment(x1, gapCenter - gapWidth / 2)
		segment(gapCenter + gapWidth / 2, x2)
	else
		segment(x1, x2)
	end
end

-- Same, running along the Z axis at x.
function BuildKit.wallZ(parent: Instance, name: string, x: number, z1: number, z2: number, yBottom: number, height: number, thickness: number, color: Color3, material: Enum.Material, gapCenter: number?, gapWidth: number?)
	local yMid = yBottom + height / 2
	local function segment(fromZ: number, toZ: number)
		if toZ - fromZ < 0.5 then
			return
		end
		BuildKit.part({
			name = name,
			size = Vector3.new(thickness, height, toZ - fromZ),
			position = Vector3.new(x, yMid, (fromZ + toZ) / 2),
			color = color,
			material = material,
			parent = parent,
		})
	end
	if gapCenter and gapWidth then
		segment(z1, gapCenter - gapWidth / 2)
		segment(gapCenter + gapWidth / 2, z2)
	else
		segment(z1, z2)
	end
end

function BuildKit.wedgePart(props: PartProps): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = props.name or "Wedge"
	wedge.Size = props.size
	if props.cframe then
		wedge.CFrame = props.cframe
	elseif props.position then
		wedge.Position = props.position
	end
	wedge.Color = props.color or Color3.fromRGB(163, 162, 165)
	wedge.Material = props.material or Enum.Material.SmoothPlastic
	wedge.Transparency = props.transparency or 0
	wedge.CanCollide = if props.canCollide == nil then true else props.canCollide
	wedge.Anchored = true
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = props.parent
	return wedge
end

-- A Chinese tiled roof layer: flat cap plus four outward-sloping eave
-- wedges hanging past the walls. `y` is the underside of the roof.
function BuildKit.chineseRoof(parent: Instance, center: Vector3, width: number, depth: number, y: number, roofColor: Color3)
	local overhang = 3.5
	local capW = width + overhang * 2
	local capD = depth + overhang * 2
	BuildKit.part({
		name = "Roof_Cap",
		size = Vector3.new(capW, 1, capD),
		position = Vector3.new(center.X, y + 0.5, center.Z),
		color = roofColor,
		material = Enum.Material.Slate,
		parent = parent,
	})
	-- Eaves on each side, sloping down and out.
	local eaveH = 1.8
	local sides = {
		{ dir = Vector3.new(0, 0, 1), len = capW },
		{ dir = Vector3.new(0, 0, -1), len = capW },
		{ dir = Vector3.new(1, 0, 0), len = capD },
		{ dir = Vector3.new(-1, 0, 0), len = capD },
	}
	for _, side in sides do
		local edge = Vector3.new(center.X, y + 0.4, center.Z)
			+ side.dir * (if side.dir.Z ~= 0 then capD / 2 + 1.4 else capW / 2 + 1.4)
		BuildKit.wedgePart({
			name = "Roof_Eave",
			size = Vector3.new(side.len + 2, eaveH, 3),
			cframe = CFrame.lookAt(edge, edge + side.dir) * CFrame.Angles(0, math.pi, 0),
			color = roofColor,
			material = Enum.Material.Slate,
			canCollide = false,
			parent = parent,
		})
	end
	-- Ridge beam along the longer axis.
	local ridgeAlongX = width >= depth
	BuildKit.part({
		name = "Roof_Ridge",
		size = if ridgeAlongX then Vector3.new(width * 0.7, 1, 1.6) else Vector3.new(1.6, 1, depth * 0.7),
		position = Vector3.new(center.X, y + 1.4, center.Z),
		color = roofColor,
		material = Enum.Material.Slate,
		parent = parent,
	})
end

-- A multi-story pagoda-style house: plaster walls, timber corner posts,
-- a tiled roof over every floor, each floor slightly narrower.
function BuildKit.pagodaHouse(parent: Instance, center: Vector3, width: number, depth: number, floors: number, plaster: Color3, timber: Color3, roofColor: Color3)
	local floorHeight = 9
	local y = center.Y
	local w, d = width, depth
	for _ = 1, floors do
		BuildKit.part({
			name = "House_Wall",
			size = Vector3.new(w, floorHeight, d),
			position = Vector3.new(center.X, y + floorHeight / 2, center.Z),
			color = plaster,
			material = Enum.Material.SmoothPlastic,
			parent = parent,
		})
		for cx = -1, 1, 2 do
			for cz = -1, 1, 2 do
				BuildKit.part({
					name = "House_Post",
					size = Vector3.new(1.2, floorHeight, 1.2),
					position = Vector3.new(center.X + cx * (w / 2), y + floorHeight / 2, center.Z + cz * (d / 2)),
					color = timber,
					material = Enum.Material.Wood,
					parent = parent,
				})
			end
		end
		BuildKit.chineseRoof(parent, Vector3.new(center.X, 0, center.Z), w, d, y + floorHeight, roofColor)
		y += floorHeight + 1.4
		w *= 0.78
		d *= 0.78
	end
	-- Finial at the peak.
	BuildKit.part({
		name = "House_Finial",
		size = Vector3.new(0.9, 2.4, 0.9),
		position = Vector3.new(center.X, y + 1.2, center.Z),
		color = Color3.fromRGB(212, 175, 55),
		material = Enum.Material.Metal,
		canCollide = false,
		parent = parent,
	})
end

-- A paifang: the ceremonial gate arch that marks a Chinese city entrance.
-- Returns the signboard part so callers can hang a label on it.
function BuildKit.paifang(parent: Instance, center: Vector3, facing: Vector3, width: number, timber: Color3, roofColor: Color3): Part
	local side = Vector3.new(-facing.Z, 0, facing.X)
	local pillarHeight = 17
	for s = -1, 1, 2 do
		BuildKit.part({
			name = "Paifang_Pillar",
			size = Vector3.new(2, pillarHeight, 2),
			position = center + side * (s * width / 2) + Vector3.new(0, pillarHeight / 2, 0),
			color = timber,
			material = Enum.Material.Wood,
			parent = parent,
		})
	end
	local lintelCF = CFrame.lookAt(center + Vector3.new(0, pillarHeight - 1, 0), center + Vector3.new(0, pillarHeight - 1, 0) + facing)
	BuildKit.part({
		name = "Paifang_Lintel",
		size = Vector3.new(width + 5, 1.6, 2.4),
		cframe = lintelCF,
		color = timber,
		material = Enum.Material.Wood,
		parent = parent,
	})
	local sign = BuildKit.part({
		name = "Paifang_Sign",
		size = Vector3.new(width * 0.55, 3, 1.2),
		cframe = lintelCF * CFrame.new(0, 2.4, 0),
		color = Color3.fromRGB(32, 28, 26),
		material = Enum.Material.Wood,
		parent = parent,
	})
	-- Little roof riding the top.
	local roofCenter = center + Vector3.new(0, 0, 0)
	BuildKit.chineseRoof(parent, roofCenter, width * 0.7, 4, pillarHeight + 3.2, roofColor)
	return sign
end

-- An open pavilion: four posts and a tiered roof, no walls. Shelters shrines.
function BuildKit.pavilion(parent: Instance, center: Vector3, size: number, timber: Color3, roofColor: Color3)
	local postHeight = 13
	for cx = -1, 1, 2 do
		for cz = -1, 1, 2 do
			BuildKit.part({
				name = "Pavilion_Post",
				size = Vector3.new(1.4, postHeight, 1.4),
				position = center + Vector3.new(cx * size / 2, postHeight / 2, cz * size / 2),
				color = timber,
				material = Enum.Material.Wood,
				parent = parent,
			})
		end
	end
	BuildKit.chineseRoof(parent, Vector3.new(center.X, 0, center.Z), size + 2, size + 2, center.Y + postHeight, roofColor)
	BuildKit.chineseRoof(parent, Vector3.new(center.X, 0, center.Z), size * 0.5, size * 0.5, center.Y + postHeight + 3.4, roofColor)
end

-- Vertical-axis cylinder (Roblox cylinders lie along local X; we stand it up).
function BuildKit.cylinder(parent: Instance, name: string, center: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material): Part
	return BuildKit.part({
		name = name,
		size = Vector3.new(height, diameter, diameter),
		cframe = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		material = material,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
end

function BuildKit.billboard(adornee: BasePart, text: string, color: Color3, width: number, height: number, studsOffset: Vector3?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(width, height)
	gui.StudsOffset = studsOffset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 220
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextScaled = true
	label.Font = Enum.Font.Garamond
	label.Parent = gui
end

function BuildKit.prompt(parent: BasePart, actionText: string, objectText: string, holdDuration: number, tag: string?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	if tag then
		CollectionService:AddTag(prompt, tag)
	end
	return prompt
end

function BuildKit.pointLight(parent: BasePart, color: Color3, brightness: number, lightRange: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = lightRange
	light.Shadows = false
	light.Parent = parent
end

-- Invisible safe-zone marker; CombatService reads the tag + Radius attribute.
function BuildKit.safeZone(parent: Instance, position: Vector3, radius: number)
	local marker = BuildKit.part({
		name = "SafeZone",
		size = Vector3.new(1, 1, 1),
		position = position,
		transparency = 1,
		canCollide = false,
		parent = parent,
	})
	marker:SetAttribute("Radius", radius)
	CollectionService:AddTag(marker, "SafeZone")
end

function BuildKit.spawnLocation(parent: Instance, position: Vector3, teamColorName: string?, neutral: boolean): SpawnLocation
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Size = Vector3.new(10, 1, 10)
	spawnLoc.Position = position
	spawnLoc.Anchored = true
	spawnLoc.Neutral = neutral
	if teamColorName then
		spawnLoc.TeamColor = (BrickColor.new :: any)(teamColorName)
	end
	spawnLoc.AllowTeamChangeOnTouch = false
	spawnLoc.Duration = 0
	spawnLoc.Material = Enum.Material.Slate
	spawnLoc.Color = Color3.fromRGB(120, 118, 122)
	spawnLoc.Parent = parent
	return spawnLoc
end

-- An anchored training dummy with a Humanoid so techniques have something
-- honest to hit. CombatService keeps it healed.
function BuildKit.trainingDummy(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Training Dummy"

	local root = BuildKit.part({
		name = "HumanoidRootPart",
		size = Vector3.new(2.4, 3.6, 1.6),
		position = position + Vector3.new(0, 2.8, 0),
		color = Color3.fromRGB(150, 110, 70),
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	BuildKit.part({
		name = "Head",
		size = Vector3.new(1.6, 1.6, 1.6),
		position = position + Vector3.new(0, 5.4, 0),
		color = Color3.fromRGB(170, 130, 85),
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	BuildKit.part({
		name = "Base",
		size = Vector3.new(4, 1, 4),
		position = position + Vector3.new(0, 0.5, 0),
		color = Color3.fromRGB(110, 85, 55),
		material = Enum.Material.WoodPlanks,
		parent = model,
	})

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 250
	humanoid.Health = 250
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	model.PrimaryPart = root
	CollectionService:AddTag(model, "TrainingDummy")
	BuildKit.billboard(root, "Training Dummy", Color3.fromRGB(230, 220, 200), 8, 1.4, Vector3.new(0, 4.6, 0))
	model.Parent = parent
	return model
end

-- An ore node: rock base plus glowing crystals. MiningService binds the tag.
function BuildKit.oreNode(parent: Instance, position: Vector3, oreId: string, oreName: string, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "OreNode_" .. oreId

	local rock = BuildKit.part({
		name = "Rock",
		size = Vector3.new(4.5, 3, 4.5),
		cframe = CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, (position.X + position.Z) % 3, 0),
		color = Color3.fromRGB(88, 86, 92),
		material = Enum.Material.Slate,
		parent = model,
	})

	for i = 1, 3 do
		local angle = i * (math.pi * 2 / 3) + position.X
		BuildKit.part({
			name = "Crystal",
			size = Vector3.new(1.1, 2.2 - (i % 2) * 0.6, 1.1),
			cframe = CFrame.new(position + Vector3.new(math.cos(angle) * 1.3, 2.8, math.sin(angle) * 1.3))
				* CFrame.Angles(math.rad(15 * i), angle, math.rad(-10 * i)),
			color = color,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = model,
		})
	end

	model.PrimaryPart = rock
	model:SetAttribute("OreId", oreId)
	BuildKit.prompt(rock, "Mine", oreName, 1.5, nil)
	CollectionService:AddTag(model, "OreNode")
	model.Parent = parent
	return model
end

return BuildKit
