--!strict
-- ModuleScript: ServerScriptService > Server > Systems > World > Kit
-- The construction toolkit for the handcrafted world. Xianxia
-- architecture: curved tiled roofs with upturned corners, timber-framed
-- halls on stone plinths, pavilions, paifang gates, round paper lanterns.
--
-- Standing rules, all learned the hard way:
--  * Decoration never collides, never answers queries, never eats a
--    projectile: canCollide=false implies CanQuery/CanTouch=false.
--  * Small decor casts no shadows (castShadow=false); there is a budget.
--  * Lanterns are BALLS with caps and tassels, never bare neon cubes.
--  * Doors are real openings; halls have interiors.
--  * Everything is placed at true ground height by the caller (the
--    terrain module exposes exact heights; nothing floats, nothing sinks).

local CollectionService = game:GetService("CollectionService")

local Kit = {}

export type PartProps = {
	name: string?,
	size: Vector3,
	cframe: CFrame?,
	position: Vector3?,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	castShadow: boolean?,
	shape: Enum.PartType?,
	parent: Instance,
}

function Kit.part(props: PartProps): Part
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
	local canCollide = if props.canCollide == nil then true else props.canCollide
	part.CanCollide = canCollide
	if not canCollide then
		part.CanQuery = false
		part.CanTouch = false
	end
	if props.castShadow == false then
		part.CastShadow = false
	end
	if props.shape then
		part.Shape = props.shape
	end
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.parent
	return part
end

function Kit.wedge(props: PartProps): WedgePart
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
	local canCollide = if props.canCollide == nil then true else props.canCollide
	wedge.CanCollide = canCollide
	if not canCollide then
		wedge.CanQuery = false
		wedge.CanTouch = false
	end
	if props.castShadow == false then
		wedge.CastShadow = false
	end
	wedge.Anchored = true
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = props.parent
	return wedge
end

-- Vertical cylinder (Roblox cylinders lie along X; this stands one up).
function Kit.cylinder(parent: Instance, name: string, center: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material, canCollide: boolean?, castShadow: boolean?): Part
	return Kit.part({
		name = name,
		size = Vector3.new(height, diameter, diameter),
		cframe = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		material = material,
		canCollide = canCollide,
		castShadow = castShadow,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
end

-- ------------------------------- Roofs ----------------------------------

-- A Chinese tiled roof about a yaw frame: cap, four sloping eaves, ridge
-- beam, upturned corner tips, gable ornaments.
function Kit.roof(parent: Instance, cf: CFrame, width: number, depth: number, y: number, color: Color3, material: Enum.Material?)
	local mat = material or Enum.Material.Slate
	local overhang = 5
	local capW = width + overhang * 2
	local capD = depth + overhang * 2
	local function at(offset: Vector3): CFrame
		return cf * CFrame.new(offset)
	end
	Kit.part({
		name = "Roof_Cap",
		size = Vector3.new(capW, 2, capD),
		cframe = at(Vector3.new(0, y + 1, 0)),
		color = color,
		material = mat,
		parent = parent,
	})
	local sides = { Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) }
	for _, dir in sides do
		local len = if dir.Z ~= 0 then capW else capD
		local off = if dir.Z ~= 0 then capD / 2 + 2 else capW / 2 + 2
		local edge = at(dir * off + Vector3.new(0, y + 0.8, 0))
		local outward = at(dir * (off + 5) + Vector3.new(0, y + 0.8, 0))
		Kit.wedge({
			name = "Roof_Eave",
			size = Vector3.new(len + 2, 2.4, 4.4),
			cframe = CFrame.lookAt(edge.Position, outward.Position) * CFrame.Angles(0, math.pi, 0),
			color = color,
			material = mat,
			canCollide = false,
			castShadow = false,
			parent = parent,
		})
	end
	local alongX = width >= depth
	local ridgeLen = (if alongX then width else depth) * 0.7
	Kit.part({
		name = "Roof_Ridge",
		size = if alongX then Vector3.new(ridgeLen, 1.4, 1.8) else Vector3.new(1.8, 1.4, ridgeLen),
		cframe = at(Vector3.new(0, y + 2.3, 0)),
		color = color,
		material = mat,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})
	for cornerX = -1, 1, 2 do
		for cornerZ = -1, 1, 2 do
			Kit.wedge({
				name = "Roof_Upturn",
				size = Vector3.new(3, 2, 3.6),
				cframe = at(Vector3.new(cornerX * (capW / 2 + 1.4), y + 1.4, cornerZ * (capD / 2 + 1.4)))
					* CFrame.Angles(0, math.atan2(cornerX :: number, cornerZ :: number), 0)
					* CFrame.Angles(math.rad(-28), 0, 0),
				color = color,
				material = mat,
				canCollide = false,
				castShadow = false,
				parent = parent,
			})
		end
	end
end

-- ------------------------------ Lanterns ---------------------------------

-- Round red paper lantern with cap and tassel. The only lantern shape in
-- the game; bare neon cubes are banned by bitter experience.
function Kit.lantern(parent: Instance, position: Vector3, diameter: number, withLight: boolean): Part
	local ball = Kit.part({
		name = "Lantern_Ball",
		size = Vector3.new(diameter, diameter, diameter),
		position = position,
		color = Color3.fromRGB(226, 66, 46),
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		shape = Enum.PartType.Ball,
		parent = parent,
	})
	Kit.part({
		name = "Lantern_Cap",
		size = Vector3.new(diameter * 0.5, 0.45, diameter * 0.5),
		position = position + Vector3.new(0, diameter * 0.55, 0),
		color = Color3.fromRGB(56, 42, 32),
		material = Enum.Material.Wood,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})
	Kit.part({
		name = "Lantern_Tassel",
		size = Vector3.new(0.28, diameter * 0.5, 0.28),
		position = position - Vector3.new(0, diameter * 0.7, 0),
		color = Color3.fromRGB(206, 172, 84),
		material = Enum.Material.Fabric,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 158, 108)
		light.Brightness = 1.3
		light.Range = 24
		light.Shadows = false
		light.Parent = ball
	end
	return ball
end

-- A wooden post with a hanging lantern; the street light of the vale.
function Kit.lanternPost(parent: Instance, position: Vector3, withLight: boolean)
	Kit.part({
		name = "LanternPost",
		size = Vector3.new(0.9, 10, 0.9),
		position = position + Vector3.new(0, 5, 0),
		color = Color3.fromRGB(74, 53, 39),
		material = Enum.Material.Wood,
		parent = parent,
	})
	Kit.part({
		name = "LanternPost_Arm",
		size = Vector3.new(0.7, 0.7, 3),
		position = position + Vector3.new(0, 9.6, 1.4),
		color = Color3.fromRGB(74, 53, 39),
		material = Enum.Material.Wood,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})
	Kit.lantern(parent, position + Vector3.new(0, 8.2, 2.6), 1.9, withLight)
end

-- ------------------------------ Buildings --------------------------------

export type HouseSpec = {
	width: number,
	depth: number,
	floors: number,
	plaster: Color3,
	timber: Color3,
	roofColor: Color3,
	roofMaterial: Enum.Material?,
	hollow: boolean?, -- true = enterable room with furniture
	lanternLights: boolean?,
}

local STONE = Color3.fromRGB(148, 146, 142)

function Kit.house(parent: Instance, cf: CFrame, spec: HouseSpec)
	local w, d = spec.width, spec.depth
	local floorHeight = 13
	local seed = Random.new(math.floor(cf.X * 7 + cf.Z * 13) % 100000)
	local tint = seed:NextNumber(-0.04, 0.05)
	local plaster = if tint >= 0
		then spec.plaster:Lerp(Color3.new(1, 1, 1), tint)
		else spec.plaster:Lerp(Color3.fromRGB(96, 84, 66), -tint)
	local timber = spec.timber
	local doorW = if spec.hollow then 9 else 6.5
	local doorX = if spec.hollow then 0 else -w / 4
	local function at(offset: Vector3): CFrame
		return cf * CFrame.new(offset)
	end

	-- Stone plinth and steps to the door.
	Kit.part({
		name = "House_Plinth",
		size = Vector3.new(w + 5, 2.2, d + 5),
		cframe = at(Vector3.new(0, 1.1, 0)),
		color = STONE,
		material = Enum.Material.Slate,
		parent = parent,
	})
	for stepIndex = 1, 3 do
		Kit.part({
			name = "House_Step",
			size = Vector3.new(doorW + 4, 0.7, 1.7),
			cframe = at(Vector3.new(doorX, 2.2 - stepIndex * 0.7, d / 2 + 2.6 + stepIndex * 1.5)),
			color = STONE,
			material = Enum.Material.Slate,
			parent = parent,
		})
	end

	local y = 2.2
	for floor = 1, spec.floors do
		if spec.hollow and floor == 1 then
			local wallT = 1.5
			Kit.part({ name = "House_Wall", size = Vector3.new(w, floorHeight, wallT),
				cframe = at(Vector3.new(0, y + floorHeight / 2, -d / 2 + wallT / 2)),
				color = plaster, material = Enum.Material.SmoothPlastic, parent = parent })
			for sideSign = -1, 1, 2 do
				Kit.part({ name = "House_Wall", size = Vector3.new(wallT, floorHeight, d - wallT * 2),
					cframe = at(Vector3.new(sideSign * (w / 2 - wallT / 2), y + floorHeight / 2, 0)),
					color = plaster, material = Enum.Material.SmoothPlastic, parent = parent })
			end
			local segW = (w - doorW - 2) / 2
			for doorSide = -1, 1, 2 do
				Kit.part({ name = "House_Wall", size = Vector3.new(segW, floorHeight, wallT),
					cframe = at(Vector3.new(doorSide * (doorW / 2 + 1 + segW / 2), y + floorHeight / 2, d / 2 - wallT / 2)),
					color = plaster, material = Enum.Material.SmoothPlastic, parent = parent })
			end
			Kit.part({ name = "House_Lintel", size = Vector3.new(doorW + 2, floorHeight - 10, wallT),
				cframe = at(Vector3.new(0, y + 10 + (floorHeight - 10) / 2, d / 2 - wallT / 2)),
				color = plaster, material = Enum.Material.SmoothPlastic, parent = parent })
			Kit.part({ name = "House_Floor", size = Vector3.new(w - wallT, 0.4, d - wallT),
				cframe = at(Vector3.new(0, y + 0.2, 0)),
				color = Color3.fromRGB(124, 96, 66), material = Enum.Material.WoodPlanks, parent = parent })
		else
			Kit.part({
				name = "House_Wall",
				size = Vector3.new(w, floorHeight, d),
				cframe = at(Vector3.new(0, y + floorHeight / 2, 0)),
				color = plaster,
				material = Enum.Material.SmoothPlastic,
				parent = parent,
			})
		end
		-- Corner posts and timber bands.
		for cx = -1, 1, 2 do
			for cz = -1, 1, 2 do
				Kit.part({
					name = "House_Post",
					size = Vector3.new(1.8, floorHeight, 1.8),
					cframe = at(Vector3.new(cx * w / 2, y + floorHeight / 2, cz * d / 2)),
					color = timber,
					material = Enum.Material.Wood,
					parent = parent,
				})
			end
		end
		for _, bandY in { y + 0.6, y + floorHeight - 0.6 } do
			Kit.part({
				name = "House_Band",
				size = Vector3.new(w + 1, 1.2, d + 1),
				cframe = at(Vector3.new(0, bandY, 0)),
				color = timber,
				material = Enum.Material.Wood,
				canCollide = false,
				castShadow = false,
				parent = parent,
			})
		end
		-- Windows (skip the door bay on the front face).
		for faceSign = -1, 1, 2 do
			for _, windowX in { -w / 4, w / 4 } do
				if floor == 1 and faceSign == 1 and math.abs(windowX - doorX) < (doorW + 5) / 2 + 2.5 then
					continue
				end
				local faceZ = faceSign * (d / 2 + 0.3)
				Kit.part({
					name = "House_Window",
					size = Vector3.new(4.4, 5.2, 0.6),
					cframe = at(Vector3.new(windowX, y + floorHeight / 2, faceZ)),
					color = timber,
					material = Enum.Material.Wood,
					canCollide = false,
					castShadow = false,
					parent = parent,
				})
				Kit.part({
					name = "House_WindowPanel",
					size = Vector3.new(3.4, 4.2, 0.5),
					cframe = at(Vector3.new(windowX, y + floorHeight / 2, faceZ + faceSign * 0.12)),
					color = Color3.fromRGB(216, 203, 170),
					material = Enum.Material.WoodPlanks,
					canCollide = false,
					castShadow = false,
					parent = parent,
				})
			end
		end
		if floor == 1 then
			Kit.part({
				name = "House_DoorFrame",
				size = Vector3.new(doorW + 1.4, 10.4, 0.7),
				cframe = at(Vector3.new(doorX, y + 5.2, d / 2 + 0.3)),
				color = timber,
				material = Enum.Material.Wood,
				canCollide = false,
				castShadow = false,
				parent = parent,
			})
			if not spec.hollow then
				Kit.part({
					name = "House_Door",
					size = Vector3.new(doorW, 9.6, 0.55),
					cframe = at(Vector3.new(doorX, y + 4.8, d / 2 + 0.45)),
					color = Color3.fromRGB(66, 47, 33),
					material = Enum.Material.WoodPlanks,
					canCollide = false,
					castShadow = false,
					parent = parent,
				})
			end
			-- Couplets and door lanterns.
			for coupletSign = -1, 1, 2 do
				Kit.part({
					name = "House_Couplet",
					size = Vector3.new(1.4, 7.6, 0.3),
					cframe = at(Vector3.new(doorX + coupletSign * (doorW / 2 + 1.6), y + 5, d / 2 + 0.4)),
					color = Color3.fromRGB(178, 44, 38),
					material = Enum.Material.SmoothPlastic,
					canCollide = false,
					castShadow = false,
					parent = parent,
				})
				local lanternWorld = at(Vector3.new(doorX + coupletSign * (doorW / 2 + 3.6), y + 8.6, d / 2 + 1.6))
				Kit.lantern(parent, lanternWorld.Position, 1.7, spec.lanternLights == true)
			end
		end
		Kit.roof(parent, cf, w, d, y + floorHeight, spec.roofColor, spec.roofMaterial)
		y += floorHeight + 1.8
		if spec.floors > 1 then
			w *= 0.82
			d *= 0.82
		end
	end

	-- Furnished interior for hollow builds.
	if spec.hollow then
		local floorY = 2.2 + 0.4
		Kit.part({ name = "Hall_Dais", size = Vector3.new(11, 1.1, 6.5),
			cframe = at(Vector3.new(0, floorY + 0.55, -spec.depth / 2 + 5.5)),
			color = STONE, material = Enum.Material.Slate, parent = parent })
		Kit.part({ name = "Hall_Seat", size = Vector3.new(4.4, 4, 2.6),
			cframe = at(Vector3.new(0, floorY + 3, -spec.depth / 2 + 5)),
			color = spec.timber, material = Enum.Material.Wood, parent = parent })
		for shelfSign = -1, 1, 2 do
			Kit.part({ name = "Hall_Shelf", size = Vector3.new(2, 8, 10),
				cframe = at(Vector3.new(shelfSign * (spec.width / 2 - 3), floorY + 4, -spec.depth / 2 + 8.5)),
				color = Color3.fromRGB(96, 72, 50), material = Enum.Material.WoodPlanks, parent = parent })
		end
		for matIndex = 0, 3 do
			Kit.part({ name = "Hall_Mat", size = Vector3.new(3.6, 0.25, 3.6),
				cframe = at(Vector3.new(-5 + (matIndex % 2) * 10, floorY + 0.15, 1.5 + math.floor(matIndex / 2) * 6)),
				color = Color3.fromRGB(178, 150, 100), material = Enum.Material.Fabric,
				canCollide = false, castShadow = false, parent = parent })
		end
		local hallLantern = Kit.lantern(parent, (at(Vector3.new(0, floorY + 10.5, 0))).Position, 2, true)
		hallLantern.Color = Color3.fromRGB(230, 170, 90)
	end
end

-- Open pavilion: four posts, a tiered roof, a raised floor. Shelter for
-- shrines and meditation.
function Kit.pavilion(parent: Instance, center: Vector3, size: number, timber: Color3, roofColor: Color3)
	Kit.part({
		name = "Pavilion_Floor",
		size = Vector3.new(size + 4, 1.2, size + 4),
		position = center + Vector3.new(0, 0.6, 0),
		color = STONE,
		material = Enum.Material.Slate,
		parent = parent,
	})
	local postHeight = 15
	for cx = -1, 1, 2 do
		for cz = -1, 1, 2 do
			Kit.part({
				name = "Pavilion_Post",
				size = Vector3.new(1.7, postHeight, 1.7),
				position = center + Vector3.new(cx * size / 2, 1.2 + postHeight / 2, cz * size / 2),
				color = timber,
				material = Enum.Material.Wood,
				parent = parent,
			})
		end
	end
	local yaw = CFrame.new(center.X, center.Y, center.Z)
	Kit.roof(parent, yaw, size + 2, size + 2, 1.2 + postHeight, roofColor)
	Kit.roof(parent, yaw, size * 0.45, size * 0.45, 1.2 + postHeight + 3.8, roofColor)
end

-- Paifang: the ceremonial gate. Returns the signboard for a billboard.
function Kit.paifang(parent: Instance, center: Vector3, facing: Vector3, width: number, timber: Color3, roofColor: Color3): Part
	local side = Vector3.new(-facing.Z, 0, facing.X)
	local pillarHeight = 22
	for s = -1, 1, 2 do
		Kit.part({
			name = "Paifang_Pillar",
			size = Vector3.new(2.6, pillarHeight, 2.6),
			position = center + side * (s * width / 2) + Vector3.new(0, pillarHeight / 2, 0),
			color = timber,
			material = Enum.Material.Wood,
			parent = parent,
		})
		-- Guardian stones at the pillar feet.
		Kit.part({
			name = "Paifang_Foot",
			size = Vector3.new(4, 2.6, 4),
			position = center + side * (s * width / 2) + Vector3.new(0, 1.3, 0),
			color = STONE,
			material = Enum.Material.Slate,
			parent = parent,
		})
	end
	local lintelCF = CFrame.lookAt(center + Vector3.new(0, pillarHeight - 1, 0), center + Vector3.new(0, pillarHeight - 1, 0) + facing)
	Kit.part({
		name = "Paifang_Lintel",
		size = Vector3.new(width + 6, 2.2, 2.8),
		cframe = lintelCF,
		color = timber,
		material = Enum.Material.Wood,
		parent = parent,
	})
	local sign = Kit.part({
		name = "Paifang_Sign",
		size = Vector3.new(width * 0.5, 4, 1.4),
		cframe = lintelCF * CFrame.new(0, 3.2, 0),
		color = Color3.fromRGB(32, 28, 26),
		material = Enum.Material.Wood,
		parent = parent,
	})
	-- Roof measured from the gate's own altitude (a paifang on a hill
	-- once wore its roof at its knees; never again).
	Kit.roof(parent, CFrame.new(center.X, 0, center.Z), width * 0.7, 5, center.Y + pillarHeight + 4, roofColor)
	Kit.lantern(parent, center + side * (width / 2 - 2) + Vector3.new(0, pillarHeight - 3, 0), 1.9, true)
	Kit.lantern(parent, center - side * (width / 2 - 2) + Vector3.new(0, pillarHeight - 3, 0), 1.9, true)
	return sign
end

-- ------------------------------ Gameplay bits ----------------------------

function Kit.billboard(adornee: BasePart, text: string, color: Color3, width: number, height: number, studsOffset: Vector3?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(width, height)
	gui.StudsOffset = studsOffset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 200
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

function Kit.safeZone(parent: Instance, position: Vector3, radius: number)
	local marker = Kit.part({
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

function Kit.cultivationZone(parent: Instance, position: Vector3, radius: number, qiMult: number, siteName: string)
	local marker = Kit.part({
		name = "CultivationZone",
		size = Vector3.new(1, 1, 1),
		position = position,
		transparency = 1,
		canCollide = false,
		parent = parent,
	})
	marker:SetAttribute("Radius", radius)
	marker:SetAttribute("QiMult", qiMult)
	marker:SetAttribute("SiteName", siteName)
	CollectionService:AddTag(marker, "CultivationZone")
end

function Kit.beastSpawn(parent: Instance, position: Vector3, beastId: string, count: number)
	local marker = Kit.part({
		name = "BeastSpawn_" .. beastId,
		size = Vector3.new(1, 1, 1),
		position = position,
		transparency = 1,
		canCollide = false,
		parent = parent,
	})
	marker:SetAttribute("BeastId", beastId)
	marker:SetAttribute("Count", count)
	CollectionService:AddTag(marker, "BeastSpawn")
end

function Kit.spawnLocation(parent: Instance, position: Vector3): SpawnLocation
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Size = Vector3.new(10, 1, 10)
	spawnLoc.Position = position
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Duration = 0
	spawnLoc.Material = Enum.Material.Slate
	spawnLoc.Color = Color3.fromRGB(120, 118, 122)
	spawnLoc.Parent = parent
	return spawnLoc
end

function Kit.trainingDummy(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Training Dummy"
	local root = Kit.part({
		name = "HumanoidRootPart",
		size = Vector3.new(2.4, 3.6, 1.6),
		position = position + Vector3.new(0, 2.8, 0),
		color = Color3.fromRGB(150, 110, 70),
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	Kit.part({
		name = "Head",
		size = Vector3.new(1.6, 1.6, 1.6),
		position = position + Vector3.new(0, 5.4, 0),
		color = Color3.fromRGB(170, 130, 85),
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	Kit.part({
		name = "Base",
		size = Vector3.new(4, 1, 4),
		position = position + Vector3.new(0, 0.5, 0),
		color = Color3.fromRGB(110, 85, 55),
		material = Enum.Material.WoodPlanks,
		parent = model,
	})
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 400
	humanoid.Health = 400
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	model.PrimaryPart = root
	CollectionService:AddTag(model, "TrainingDummy")
	Kit.billboard(root, "Training Dummy", Color3.fromRGB(230, 220, 200), 8, 1.4, Vector3.new(0, 4.4, 0))
	model.Parent = parent
	return model
end

return Kit
