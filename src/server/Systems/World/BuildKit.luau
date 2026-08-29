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
