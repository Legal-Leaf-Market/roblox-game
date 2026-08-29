--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > MovementController
-- Body movement the client owns (it owns its character's physics): hold
-- Shift to sprint on a stamina pool, press Q to dodge-dash (the server
-- grants the evasion window; the impulse is local so it feels instant).
--
-- The speed contract with the server: WalkSpeed is computed here every
-- frame as (BaseWalkSpeed + SpeedFlat) * SpeedFactor * sprint. The server
-- writes only those attributes, never WalkSpeed itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))

local ClientState = require(script.Parent.Parent.Modules.ClientState)
local AnimUtil = require(script.Parent.Parent.Modules.AnimUtil)

local MovementController = {}

local player = Players.LocalPlayer

local stamina = Config.STAMINA_MAX
local sprinting = false
local speedMult = 1 -- eased so speed ramps instead of popping
local lastDodge = 0

local function character(): (Humanoid?, BasePart?)
	local model = player.Character
	if model == nil then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

local function dodge()
	local now = os.clock()
	if now - lastDodge < Config.DODGE_COOLDOWN then
		return
	end
	local humanoid, root = character()
	if humanoid == nil or root == nil or humanoid.Health <= 0 then
		return
	end
	lastDodge = now
	Net.remoteEvent("DodgeRequest"):FireServer()

	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	root.AssemblyLinearVelocity = direction.Unit * Config.DODGE_SPEED + Vector3.new(0, 6, 0)
	AnimUtil.play("dodge", 0.05)

	-- A short qi ribbon off the feet.
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-0.9, -2.9, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0.9, -2.9, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(58, 132, 255), Color3.fromRGB(120, 190, 255))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.28
	trail.LightEmission = 0.6
	trail.Parent = root
	task.delay(0.35, function()
		trail.Enabled = false
		task.wait(0.3)
		trail:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)

	local camera = workspace.CurrentCamera
	if camera then
		local baseFov = camera.FieldOfView
		TweenService:Create(camera, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = baseFov + 7 }):Play()
		task.delay(0.14, function()
			TweenService:Create(camera, TweenInfo.new(0.22), { FieldOfView = baseFov }):Play()
		end)
	end
end

function MovementController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			sprinting = true
		end
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			dodge()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			sprinting = false
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		local humanoid = (character())
		if humanoid == nil then
			return
		end
		local baseAttr = humanoid:GetAttribute("BaseWalkSpeed")
		local base = if typeof(baseAttr) == "number" then baseAttr else Config.BASE_WALKSPEED
		local flatAttr = humanoid:GetAttribute("SpeedFlat")
		local flat = if typeof(flatAttr) == "number" then flatAttr else 0
		local factorAttr = humanoid:GetAttribute("SpeedFactor")
		local factor = if typeof(factorAttr) == "number" then factorAttr else 1

		local moving = humanoid.MoveDirection.Magnitude > 0.05
		local sprintingNow = sprinting and moving and stamina > 0
		if sprintingNow then
			stamina = math.max(0, stamina - Config.SPRINT_DRAIN * deltaTime)
		else
			stamina = math.min(Config.STAMINA_MAX, stamina + Config.STAMINA_REGEN * deltaTime)
		end
		local targetMult = if sprintingNow then Config.SPRINT_MULT else 1
		speedMult += (targetMult - speedMult) * math.min(1, deltaTime * 7)
		humanoid.WalkSpeed = (base + flat) * factor * speedMult
		ClientState.FireStamina(stamina, Config.STAMINA_MAX)

		-- Sprint animation slot, when one exists.
		if sprintingNow then
			AnimUtil.play("sprint", 0.25, true)
		else
			AnimUtil.stop("sprint", 0.3)
		end
	end)
end

return MovementController
