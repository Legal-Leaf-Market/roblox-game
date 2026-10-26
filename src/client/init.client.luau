--!strict
-- Aiming, ball in hand, shot playback and the HUD.
--
-- On your turn the camera swings over the table. Move the mouse (or your
-- finger) to aim, hold to build power, let go to shoot. Q and E nudge the
-- aim a fraction of a degree for the fine cuts. With ball in hand, the cue
-- ball follows the pointer and a click puts it down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Physics = require(Shared.Physics)
local Net = require(Shared.Net)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ballFolder = workspace:WaitForChild("Balls")
local Shoot, Place, Play, StateEv = Net.get("Shoot"), Net.get("Place"), Net.get("Play"), Net.get("State")

local S = Config.STUDS_PER_INCH
local FELT_TOP = 3.3
local function toWorld(x: number, y: number): Vector3
	return Vector3.new(x * S, FELT_TOP + Config.BALL_RADIUS * S, y * S)
end

-- HUD -------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "PoolHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.Size = UDim2.new(0.6, 0, 0, 44)
banner.Position = UDim2.new(0.2, 0, 0, 56)
banner.BackgroundColor3 = Color3.fromRGB(16, 14, 14)
banner.BackgroundTransparency = 0.2
banner.TextColor3 = Color3.fromRGB(245, 236, 220)
banner.Font = Enum.Font.GothamBold
banner.TextScaled = true
banner.Text = ""
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 10)
local pad = Instance.new("UIPadding", banner)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)

local groupLabel = Instance.new("TextLabel")
groupLabel.Size = UDim2.new(0.6, 0, 0, 24)
groupLabel.Position = UDim2.new(0.2, 0, 0, 104)
groupLabel.BackgroundTransparency = 1
groupLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
groupLabel.Font = Enum.Font.Gotham
groupLabel.TextScaled = true
groupLabel.Text = ""
groupLabel.Parent = gui

local powerBack = Instance.new("Frame")
powerBack.Size = UDim2.new(0, 280, 0, 14)
powerBack.Position = UDim2.new(0.5, -140, 1, -60)
powerBack.BackgroundColor3 = Color3.fromRGB(30, 26, 26)
powerBack.Visible = false
powerBack.Parent = gui
Instance.new("UICorner", powerBack).CornerRadius = UDim.new(1, 0)
local powerFill = Instance.new("Frame")
powerFill.Size = UDim2.fromScale(0, 1)
powerFill.BackgroundColor3 = Color3.fromRGB(255, 90, 70)
powerFill.Parent = powerBack
Instance.new("UICorner", powerFill).CornerRadius = UDim.new(1, 0)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0.8, 0, 0, 20)
hint.Position = UDim2.new(0.1, 0, 1, -36)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(190, 180, 170)
hint.Font = Enum.Font.Gotham
hint.TextSize = 15
hint.Text = ""
hint.Parent = gui

-- Aim guide: a line to the ghost ball, the ghost ball, and the stick. ----
local function guidePart(name: string, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end
local line = guidePart("AimLine")
line.Material = Enum.Material.Neon
line.Color = Color3.fromRGB(255, 255, 255)
line.Transparency = 0.4
local ghost = guidePart("Ghost", Enum.PartType.Ball)
ghost.Size = Vector3.one * Config.BALL_RADIUS * 2 * S
ghost.Material = Enum.Material.ForceField
ghost.Color = Color3.fromRGB(255, 255, 255)
local stick = guidePart("Cue", Enum.PartType.Cylinder)
stick.Size = Vector3.new(57 * S, 0.12, 0.12)
stick.Color = Color3.fromRGB(196, 150, 96)
stick.Material = Enum.Material.Wood

local function hideGuide()
	for _, p in { line, ghost, stick } do
		p.Transparency = 1
	end
end
hideGuide()

-- State -----------------------------------------------------------------
local state: any = nil
local balls: { any } = {}
local animating = false
local angle = 0
local charging = false
local chargeStart = 0
local fine = 0

local function myIndex(): number?
	if not state then
		return nil
	end
	for i, id in state.userIds do
		if id == player.UserId then
			return i
		end
	end
	return nil
end

local function myTurn(): boolean
	return state ~= nil and not animating and not state.busy and state.winner == nil and myIndex() == state.turn
end

local function pointerOnTable(): (number?, number?)
	local pos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil, nil
	end
	local t = (FELT_TOP + Config.BALL_RADIUS * S - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil, nil
	end
	local hit = ray.Origin + ray.Direction * t
	return hit.X / S, hit.Z / S
end

StateEv.OnClientEvent:Connect(function(s)
	state = s
	balls = s.balls
	banner.Text = s.message or ""
	local me = myIndex()
	if me and s.groups[me] then
		groupLabel.Text = "You are " .. s.groups[me]
	elseif me and #s.players > 1 then
		groupLabel.Text = "Open table"
	elseif me then
		groupLabel.Text = "Practice"
	else
		groupLabel.Text = ""
	end
end)

Play.OnClientEvent:Connect(function(frames: { { number } }, ids: { number })
	animating = true
	hideGuide()
	local parts: { BasePart? } = {}
	local bands: { BasePart? } = {}
	for i, id in ids do
		parts[i] = ballFolder:FindFirstChild("B" .. id) :: BasePart?
		bands[i] = ballFolder:FindFirstChild("B" .. id .. "Band") :: BasePart?
	end
	local start = os.clock()
	while true do
		local f = math.floor((os.clock() - start) / Config.FRAME) + 1
		local frame = frames[math.min(f, #frames)]
		for i = 1, #ids do
			local x, y = frame[i * 2 - 1], frame[i * 2]
			local pos = if x == 999 then Vector3.new(0, -20, 0) else toWorld(x, y)
			local p = parts[i]
			if p then
				p.CFrame = CFrame.new(pos)
			end
			local band = bands[i]
			if band then
				band.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
		if f >= #frames then
			break
		end
		RunService.RenderStepped:Wait()
	end
	animating = false
end)

-- Input -------------------------------------------------------------------
local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not myTurn() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		fine -= math.rad(0.25)
	elseif input.KeyCode == Enum.KeyCode.E then
		fine += math.rad(0.25)
	elseif isPress(input) then
		if state.ballInHand then
			local x, y = pointerOnTable()
			if x and y and Physics.canPlace(balls, x, y) then
				Place:FireServer(x, y)
				state.ballInHand = false -- the server's next State confirms or reverts it
			end
		else
			charging = true
			chargeStart = os.clock()
		end
	end
end)

local function power(): number
	-- Ping-pongs 0 -> 1 -> 0 every 2.4 seconds, so waiting too long is a choice.
	local t = ((os.clock() - chargeStart) / 1.2) % 2
	return if t > 1 then 2 - t else t
end

UserInputService.InputEnded:Connect(function(input)
	if charging and isPress(input) then
		charging = false
		powerBack.Visible = false
		if myTurn() then
			Shoot:FireServer(angle + fine, math.max(power(), 0.03))
			fine = 0
			hideGuide()
		end
	end
end)

-- Every frame: camera, aim, guide. --------------------------------------
RunService.RenderStepped:Connect(function()
	local cueBall = nil
	for _, b in balls do
		if b.id == 0 then
			cueBall = b
		end
	end

	if not myTurn() or not cueBall then
		if camera.CameraType == Enum.CameraType.Scriptable and not animating then
			camera.CameraType = Enum.CameraType.Custom
		end
		if not animating then
			hideGuide()
		end
		powerBack.Visible = false
		hint.Text = if state and myIndex() and state.winner == nil and not animating then "Waiting for the other shot." else ""
		return
	end

	-- A high three-quarter view from your side of the table.
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(-9, FELT_TOP + 9, 0), Vector3.new(0.5, FELT_TOP, 0))

	local cuePart = ballFolder:FindFirstChild("B0") :: BasePart?
	if state.ballInHand then
		hint.Text = "Ball in hand: click where you want the cue ball."
		local x, y = pointerOnTable()
		if x and y and cuePart then
			x = math.clamp(x, -Config.HALF_X, Config.HALF_X)
			y = math.clamp(y, -Config.HALF_Y, Config.HALF_Y)
			cuePart.CFrame = CFrame.new(toWorld(x, y))
			cuePart.Transparency = if Physics.canPlace(balls, x, y) then 0 else 0.6
		end
		hideGuide()
		return
	end
	if cuePart then
		cuePart.Transparency = 0
	end

	hint.Text = "Aim with the pointer. Hold to power up, let go to shoot. Q / E fine-tune."
	if not charging then
		local px, py = pointerOnTable()
		if px and py then
			angle = math.atan2(py - cueBall.y, px - cueBall.x)
		end
	end
	local a = angle + fine
	local gx, gy, hitId = Physics.predict(balls, cueBall.x, cueBall.y, a)
	local from, to = toWorld(cueBall.x, cueBall.y), toWorld(gx, gy)
	local len = (to - from).Magnitude
	line.Size = Vector3.new(0.04, 0.02, len)
	line.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	line.Transparency = 0.4
	ghost.CFrame = CFrame.new(to)
	ghost.Transparency = if hitId then 0.3 else 1

	local p = if charging then power() else 0
	local back = (1.5 + p * 10) * S
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local tip = from - dir * (Config.BALL_RADIUS * S + back)
	local mid = tip - dir * (stick.Size.X / 2)
	stick.CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.15, 0), mid + dir + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, math.rad(90), 0)
	stick.Transparency = 0

	powerBack.Visible = charging
	powerFill.Size = UDim2.fromScale(p, 1)
end)
