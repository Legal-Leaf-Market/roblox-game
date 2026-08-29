--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > MovementController
-- Body movement that belongs to the client (it owns its character's
-- physics): hold Shift to sprint on a stamina pool, press Q for a short
-- dash on a 2-second cooldown. Stamina is sprint/dash fuel only; qi and
-- combat stay fully server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.Modules.ClientState)
local ClientSettings = require(script.Parent.Parent.Modules.ClientSettings)

local MovementController = {}

local MAX_STAMINA = 100
local SPRINT_DRAIN = 18 -- per second
local STAMINA_REGEN = 14 -- per second, when not sprinting
local SPRINT_MULT = 2
local DASH_COST = 25
local DASH_COOLDOWN = 2
local DASH_SPEED = 110

-- Roblox-owned Ninja animation pack (usable in any experience, R15): a
-- forward-leaning martial run for sprinting, Qi Step, and dashes.
local SPRINT_ANIM_ID = "rbxassetid://656118852"

local player = Players.LocalPlayer

local stamina = MAX_STAMINA
local sprinting = false
local dashReadyAt = 0
local dashAnimUntil = 0
local movementTrack: AnimationTrack? = nil

local function setupAnimations(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 10)
	if animator == nil or not animator:IsA("Animator") then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = SPRINT_ANIM_ID
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		movementTrack = track
	end
end

local function character(): (Humanoid?, BasePart?)
	local model = player.Character
	if model == nil then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

-- ------------------------ Qi Step foot glow ------------------------
-- QiStepping is a replicated humanoid attribute set by the server, so every
-- client can dress every stepping cultivator's feet in light.

local footGlows: { [Humanoid]: BasePart } = {}

local function setFootGlow(humanoid: Humanoid, active: boolean)
	local existing = footGlows[humanoid]
	if not active then
		if existing then
			footGlows[humanoid] = nil
			existing:Destroy()
		end
		return
	end
	if existing and existing.Parent then
		return
	end
	local model = humanoid.Parent
	local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local glow = Instance.new("Part")
	glow.Name = "QiStepGlow"
	glow.Shape = Enum.PartType.Cylinder
	glow.Size = Vector3.new(0.3, 5.6, 5.6)
	glow.Color = Color3.fromRGB(120, 210, 255)
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.45
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Massless = true
	glow.CFrame = root.CFrame * CFrame.new(0, -2.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	glow.Parent = root
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = glow
	weld.Parent = glow
	footGlows[humanoid] = glow
end

local function watchCharacter(model: Model, isOwn: boolean)
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	local function refresh()
		local active = humanoid:GetAttribute("QiStepping") == true
		if not isOwn and not ClientSettings.get("othersVfx") then
			active = false
		end
		setFootGlow(humanoid, active)
	end
	humanoid:GetAttributeChangedSignal("QiStepping"):Connect(refresh)
	refresh()
end

local function watchPlayer(otherPlayer: Player)
	local isOwn = otherPlayer == player
	if otherPlayer.Character then
		task.spawn(watchCharacter, otherPlayer.Character, isOwn)
	end
	otherPlayer.CharacterAdded:Connect(function(model)
		task.spawn(watchCharacter, model, isOwn)
	end)
end

local function dash()
	local now = os.clock()
	if now < dashReadyAt or stamina < DASH_COST then
		return
	end
	local humanoid, root = character()
	if humanoid == nil or root == nil or humanoid.Health <= 0 then
		return
	end
	dashReadyAt = now + DASH_COOLDOWN
	stamina -= DASH_COST
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	root.AssemblyLinearVelocity = direction.Unit * DASH_SPEED + Vector3.new(0, 8, 0)

	-- Feel: an animation burst, a qi trail, and a camera FOV punch.
	dashAnimUntil = now + 0.35
	local track = movementTrack
	if track then
		if not track.IsPlaying then
			track:Play(0.05)
		end
		track:AdjustSpeed(2.4)
	end

	-- Blue qi ribbon streaming off the feet.
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
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.32
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.LightEmission = 0.6
	trail.Parent = root
	task.delay(0.4, function()
		trail.Enabled = false
		task.wait(0.3)
		trail:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)

	local camera = workspace.CurrentCamera
	if camera then
		local baseFov = camera.FieldOfView
		TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = baseFov + 9 }):Play()
		task.delay(0.15, function()
			TweenService:Create(camera, TweenInfo.new(0.25), { FieldOfView = baseFov }):Play()
		end)
	end
end

function MovementController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			sprinting = true -- sprint may start even when typing ends elsewhere
		end
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			dash()
		elseif input.KeyCode == Enum.KeyCode.O then
			-- Toggle Qi Step; the server is the authority on whether qi
			-- suffices and on the drain.
			local humanoid = (character())
			local active = if humanoid then humanoid:GetAttribute("QiStepping") == true else false
			Net.remoteEvent("QiStepSet"):FireServer(not active)
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
		-- The server owns base walkspeed (path/race/talents/buffs) and
		-- publishes it as an attribute; sprint multiplies it locally.
		local baseSpeed = humanoid:GetAttribute("BaseWalkSpeed")
		local base = if typeof(baseSpeed) == "number" then baseSpeed else 16
		local flatAttr = humanoid:GetAttribute("SpeedFlat")
		local flat = if typeof(flatAttr) == "number" then flatAttr else 0
		local factorAttr = humanoid:GetAttribute("SpeedFactor")
		local factor = if typeof(factorAttr) == "number" then factorAttr else 1
		local qiStepAttr = humanoid:GetAttribute("QiStepBonus")
		local qiStep = if typeof(qiStepAttr) == "number" then qiStepAttr else 0

		local moving = humanoid.MoveDirection.Magnitude > 0.05
		local sprintingNow = sprinting and moving and stamina > 0
		if sprintingNow then
			stamina = math.max(0, stamina - SPRINT_DRAIN * deltaTime)
		else
			stamina = math.min(MAX_STAMINA, stamina + STAMINA_REGEN * deltaTime)
		end
		humanoid.WalkSpeed = (base + flat + qiStep) * factor * (if sprintingNow then SPRINT_MULT else 1)
		ClientState.FireStamina(stamina, MAX_STAMINA)

		-- Martial run animation while sprinting, qi-stepping, or dashing;
		-- ordinary walking keeps the default gait.
		local track = movementTrack
		if track then
			local dashing = os.clock() < dashAnimUntil
			local shouldRun = dashing or (moving and (sprintingNow or qiStep > 0))
			if shouldRun then
				if not track.IsPlaying then
					track:Play(0.15)
				end
				track:AdjustSpeed(if dashing then 2.4 else math.max(0.8, humanoid.WalkSpeed / 16))
			elseif track.IsPlaying then
				track:Stop(0.2)
			end
		end
	end)

	-- Foot glow for everyone who qi-steps, ourselves included.
	for _, otherPlayer in Players:GetPlayers() do
		watchPlayer(otherPlayer)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	-- Movement animation track, re-loaded on every respawn.
	if player.Character then
		task.spawn(setupAnimations, player.Character)
	end
	player.CharacterAdded:Connect(function(model)
		movementTrack = nil
		task.spawn(setupAnimations, model)
	end)
end

return MovementController
