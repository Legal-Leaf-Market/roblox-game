--!strict
-- Builds the lounge and the table from code, so the whole place comes out of
-- a clean checkout with `rojo build`. Returns the helpers the game needs to
-- turn table inches into world positions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local World = {}

local S = Config.STUDS_PER_INCH
local CENTER = Vector3.new(0, 0, 0)
local FELT_TOP = 3.3 -- stud height of the cloth surface

World.FELT_TOP = FELT_TOP
World.CENTER = CENTER

function World.toWorld(x: number, y: number): Vector3
	return Vector3.new(CENTER.X + x * S, FELT_TOP + Config.BALL_RADIUS * S, CENTER.Z + y * S)
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

function World.build(): (Model, Folder)
	local room = Instance.new("Model")
	room.Name = "Lounge"

	-- Room: dark wood floor, brick walls, low ceiling.
	part({ Name = "Floor", Size = Vector3.new(80, 1, 80), Position = Vector3.new(0, -0.5, 0), Color = Color3.fromRGB(58, 38, 28), Material = Enum.Material.WoodPlanks, Parent = room })
	for i, d in { Vector3.new(0, 0, -40), Vector3.new(0, 0, 40), Vector3.new(-40, 0, 0), Vector3.new(40, 0, 0) } do
		local horiz = i <= 2
		part({ Name = "Wall", Size = if horiz then Vector3.new(80, 16, 1) else Vector3.new(1, 16, 80), Position = d + Vector3.new(0, 8, 0), Color = Color3.fromRGB(70, 34, 30), Material = Enum.Material.Brick, Parent = room })
	end
	part({ Name = "Ceiling", Size = Vector3.new(80, 1, 80), Position = Vector3.new(0, 16.5, 0), Color = Color3.fromRGB(20, 18, 18), Parent = room })

	-- Neon sign on the far wall.
	local sign = part({ Name = "Sign", Size = Vector3.new(14, 3, 0.2), Position = Vector3.new(0, 10, -39.3), Color = Color3.fromRGB(20, 10, 10), Parent = room })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.LightInfluence = 0
	sg.Parent = sign
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "THE LOUNGE"
	tl.Font = Enum.Font.Arcade
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(255, 70, 90)
	tl.Parent = sg
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 70, 90)
	glow.Range = 18
	glow.Brightness = 1.2
	glow.Parent = sign

	-- Table: frame, legs, cloth, rails, cushions, pockets.
	local tbl = Instance.new("Model")
	tbl.Name = "PoolTable"
	tbl.Parent = room
	local L, W = Config.TABLE_LENGTH * S, Config.TABLE_WIDTH * S
	local railW = 5 * S
	part({ Name = "Cloth", Size = Vector3.new(L, 0.2, W), Position = Vector3.new(CENTER.X, FELT_TOP - 0.1, CENTER.Z), Color = Color3.fromRGB(18, 92, 70), Material = Enum.Material.Fabric, Parent = tbl })
	part({ Name = "Slate", Size = Vector3.new(L + railW * 2, 0.8, W + railW * 2), Position = Vector3.new(CENTER.X, FELT_TOP - 0.6, CENTER.Z), Color = Color3.fromRGB(60, 34, 20), Material = Enum.Material.Wood, Parent = tbl })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part({ Name = "Leg", Size = Vector3.new(0.8, FELT_TOP - 1, 0.8), Position = Vector3.new(sx * (L / 2 + railW / 2 - 0.4), (FELT_TOP - 1) / 2, sz * (W / 2 + railW / 2 - 0.4)), Color = Color3.fromRGB(50, 28, 16), Material = Enum.Material.Wood, Parent = tbl })
		end
	end
	local railH = 0.35
	local woodColor = Color3.fromRGB(92, 52, 28)
	-- Long rails, split at the side pockets.
	local cm, sm = Config.CORNER_MOUTH * S, Config.SIDE_MOUTH * S
	for _, sz in { -1, 1 } do
		for _, sx in { -1, 1 } do
			local x0, x1 = sx * sm, sx * (L / 2 - cm)
			local len = math.abs(x1 - x0)
			part({ Name = "Cushion", Size = Vector3.new(len, railH, 0.25), Position = Vector3.new((x0 + x1) / 2, FELT_TOP + railH / 2, sz * (W / 2 + 0.125)), Color = Color3.fromRGB(14, 74, 56), Material = Enum.Material.Fabric, Parent = tbl })
		end
		part({ Name = "Rail", Size = Vector3.new(L + railW * 2, railH + 0.05, railW - 0.25), Position = Vector3.new(0, FELT_TOP + railH / 2, sz * (W / 2 + 0.25 + (railW - 0.25) / 2)), Color = woodColor, Material = Enum.Material.Wood, Parent = tbl })
	end
	for _, sx in { -1, 1 } do
		part({ Name = "Cushion", Size = Vector3.new(0.25, railH, W - cm * 2), Position = Vector3.new(sx * (L / 2 + 0.125), FELT_TOP + railH / 2, 0), Color = Color3.fromRGB(14, 74, 56), Material = Enum.Material.Fabric, Parent = tbl })
		part({ Name = "Rail", Size = Vector3.new(railW - 0.25, railH + 0.05, W + 0.5), Position = Vector3.new(sx * (L / 2 + 0.25 + (railW - 0.25) / 2), FELT_TOP + railH / 2, 0), Color = woodColor, Material = Enum.Material.Wood, Parent = tbl })
	end
	for _, p in Config.POCKETS do
		local pos = World.toWorld(p.x, p.y)
		part({ Name = "Pocket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, p.r * 2 * S, p.r * 2 * S), CFrame = CFrame.new(pos.X, FELT_TOP + 0.01, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(8, 8, 8), Parent = tbl })
	end

	-- The lamp: a long shade over the table with warm downlights.
	local shade = part({ Name = "Lamp", Size = Vector3.new(L * 0.7, 0.5, 1.6), Position = Vector3.new(0, 9, 0), Color = Color3.fromRGB(18, 60, 40), Material = Enum.Material.SmoothPlastic, Parent = room })
	for _, ox in { -L * 0.22, 0, L * 0.22 } do
		local bulb = part({ Name = "Bulb", Size = Vector3.new(0.6, 0.2, 0.6), Position = Vector3.new(ox, 8.7, 0), Color = Color3.fromRGB(255, 228, 170), Material = Enum.Material.Neon, Parent = shade })
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 70
		spot.Range = 14
		spot.Brightness = 3
		spot.Color = Color3.fromRGB(255, 232, 190)
		spot.Shadows = true
		spot.Parent = bulb
	end

	room.Parent = workspace

	-- Balls. A stripe is a white ball with a coloured band around it.
	local balls = Instance.new("Folder")
	balls.Name = "Balls"
	local d = Config.BALL_RADIUS * 2 * S
	for n = 0, 15 do
		local stripe = n >= 9
		local b = part({ Name = "B" .. n, Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CanCollide = false, Material = Enum.Material.SmoothPlastic, Color = if stripe then rgb(Config.COLORS[0]) else rgb(Config.colorOf(n)), Reflectance = 0.08, Parent = balls })
		if stripe then
			part({ Name = "B" .. n .. "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(d * 0.5, d * 1.02, d * 1.02), CanCollide = false, Material = Enum.Material.SmoothPlastic, Color = rgb(Config.colorOf(n)), Parent = balls })
		end
		b:SetAttribute("Ball", n)
		-- The number: a white disc on top, the way a real ball shows it from
		-- above. Balls slide rather than roll here, so it stays on top.
		if n > 0 then
			local bb = Instance.new("BillboardGui")
			bb.Name = "Number"
			bb.Size = UDim2.new(d * 0.62, 0, d * 0.62, 0)
			bb.StudsOffsetWorldSpace = Vector3.new(0, d * 0.42, 0)
			bb.LightInfluence = 0
			bb.MaxDistance = 40
			bb.Parent = b
			local disc = Instance.new("TextLabel")
			disc.Size = UDim2.fromScale(1, 1)
			disc.BackgroundColor3 = Color3.fromRGB(250, 248, 240)
			disc.Text = tostring(n)
			disc.TextScaled = true
			disc.Font = Enum.Font.GothamBold
			disc.TextColor3 = Color3.fromRGB(20, 20, 20)
			disc.Parent = bb
			Instance.new("UICorner", disc).CornerRadius = UDim.new(1, 0)
		end
	end
	balls.Parent = workspace

	return tbl, balls
end

-- Put every ball part where the table state says. Pocketed balls go under the table.
function World.place(folder: Folder, balls: { any })
	for _, b in balls do
		local p = folder:FindFirstChild("B" .. b.id) :: BasePart?
		if p then
			local pos = if b.pocketed then Vector3.new(0, -20, 0) else World.toWorld(b.x, b.y)
			p.CFrame = CFrame.new(pos)
			local band = folder:FindFirstChild("B" .. b.id .. "Band") :: BasePart?
			if band then
				band.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end
end

return World
