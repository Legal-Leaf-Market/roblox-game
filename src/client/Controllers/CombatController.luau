--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > CombatController
-- Combat input (left click light chain, right click heavy, hold F to
-- block) and the renderer for every CombatFx broadcast: swings, hits,
-- damage numbers, blocks, dodges, technique steps, breakthroughs. All
-- visuals; every outcome already happened on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local AnimUtil = require(script.Parent.Parent.Modules.AnimUtil)

local CombatController = {}

local player = Players.LocalPlayer
local attackRemote = Net.remoteEvent("AttackRequest")
local blockRemote = Net.remoteEvent("BlockSet")

local vfxFolder: Folder? = nil

local function effectsParent(): Folder
	if vfxFolder and vfxFolder.Parent then
		return vfxFolder :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "ClientVFX"
	folder.Parent = workspace
	vfxFolder = folder
	return folder
end

local function ghost(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if shape then
		part.Shape = shape
	end
	part.Parent = effectsParent()
	return part
end

local function fadeOut(part: Part, duration: number, goal: { [string]: any }?)
	local props: { [string]: any } = goal or {}
	props.Transparency = 1
	local tween = TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

local function characterRootOf(userId: number): BasePart?
	local other = Players:GetPlayerByUserId(userId)
	local model = if other then other.Character else nil
	local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- ------------------------------ Renderers --------------------------------

local SWING_COLOR = Color3.fromRGB(226, 230, 240)

local function renderSwing(origin: Vector3, direction: Vector3, swing: number)
	if swing == 0 then
		-- Heavy windup: a gathering ring at the feet.
		local ring = ghost(Vector3.new(0.6, 5, 5), CFrame.new(origin - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 170, 90), Enum.PartType.Cylinder)
		ring.Transparency = 0.4
		fadeOut(ring, 0.5, { Size = Vector3.new(0.4, 11, 11) })
		return
	end
	local arcCF = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -4.5)
		* CFrame.Angles(0, 0, math.rad((swing - 2) * 24))
	local arc = ghost(Vector3.new(8, 0.5, 8), arcCF, SWING_COLOR)
	arc.Transparency = 0.45
	fadeOut(arc, 0.22, { Size = Vector3.new(10.5, 0.2, 10.5) })
end

local function renderHit(position: Vector3, amount: number)
	local spark = ghost(Vector3.new(1.4, 1.4, 1.4), CFrame.new(position), Color3.fromRGB(255, 200, 120), Enum.PartType.Ball)
	spark.Transparency = 0.2
	fadeOut(spark, 0.3, { Size = Vector3.new(3.4, 3.4, 3.4) })

	-- A floating damage number, drifting up.
	local anchor = ghost(Vector3.new(0.2, 0.2, 0.2), CFrame.new(position + Vector3.new(math.random(-15, 15) / 10, 2.4, math.random(-15, 15) / 10)), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 1.6)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(amount)
	label.TextColor3 = Color3.fromRGB(255, 226, 160)
	label.TextStrokeTransparency = 0.1
	label.TextStrokeColor3 = Color3.fromRGB(40, 20, 10)
	label.TextScaled = true
	label.Font = Enum.Font.Merriweather
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = anchor.CFrame + Vector3.new(0, 3.4, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.75, function()
		anchor:Destroy()
	end)
end

local function renderShield(userId: number, color: Color3)
	local root = characterRootOf(userId)
	if root == nil then
		return
	end
	local shell = ghost(Vector3.new(6, 6, 6), root.CFrame, color, Enum.PartType.Ball)
	shell.Transparency = 0.65
	fadeOut(shell, 0.25, { Size = Vector3.new(7.5, 7.5, 7.5) })
end

local function renderBreakthrough(origin: Vector3, color: Color3, major: boolean)
	local pillar = ghost(Vector3.new(5, 140, 5), CFrame.new(origin + Vector3.new(0, 70, 0)), color)
	pillar.Transparency = 0.25
	fadeOut(pillar, if major then 2.2 else 1.4, { Size = Vector3.new(1, 170, 1) })
	local ring = ghost(Vector3.new(0.6, 2, 2), CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	ring.Transparency = 0.2
	fadeOut(ring, 0.8, { Size = Vector3.new(0.4, if major then 44 else 26, if major then 44 else 26) })
end

local function renderTechniqueStep(event: { [string]: any })
	local origin = event.origin :: Vector3
	local direction = event.direction :: Vector3
	local stepKind = tostring(event.stepKind)
	local color = if event.category == "sword" then Color3.fromRGB(200, 220, 255)
		elseif event.category == "fist" then Color3.fromRGB(255, 190, 120)
		elseif event.category == "movement" then Color3.fromRGB(160, 235, 200)
		else Color3.fromRGB(150, 200, 255)

	if stepKind == "strike" then
		local reach = tonumber(event.reach) or 10
		local arcCF = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -reach / 2)
		local arc = ghost(Vector3.new(reach, 0.6, reach), arcCF, color)
		arc.Transparency = 0.35
		fadeOut(arc, 0.3, { Size = Vector3.new(reach * 1.2, 0.2, reach * 1.2) })
	elseif stepKind == "wave" then
		local reach = tonumber(event.reach) or 60
		local speed = tonumber(event.speed) or 90
		local ball = ghost(Vector3.new(1.8, 1.8, 1.8), CFrame.new(origin), color, Enum.PartType.Ball)
		local travelTime = reach / math.max(speed, 1)
		local tween = TweenService:Create(ball, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(origin + direction.Unit * reach),
		})
		tween.Completed:Once(function()
			fadeOut(ball, 0.15)
		end)
		tween:Play()
	elseif stepKind == "burst" then
		local radius = tonumber(event.radius) or 12
		local ring = ghost(Vector3.new(0.6, 2, 2), CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
		ring.Transparency = 0.25
		fadeOut(ring, 0.45, { Size = Vector3.new(0.4, radius * 2, radius * 2) })
		local dome = ghost(Vector3.new(2, 2, 2), CFrame.new(origin), color, Enum.PartType.Ball)
		dome.Transparency = 0.55
		fadeOut(dome, 0.45, { Size = Vector3.new(radius * 1.5, radius * 1.5, radius * 1.5) })
	elseif stepKind == "motion" then
		local flash = ghost(Vector3.new(3, 3, 3), CFrame.new(origin), color, Enum.PartType.Ball)
		flash.Transparency = 0.5
		fadeOut(flash, 0.3, { Size = Vector3.new(6, 6, 6) })
		-- Our own dash/leap components apply their impulse HERE: the
		-- client owns its physics, so approved movement feels instant.
		if event.userId == player.UserId then
			local model = player.Character
			local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				local reach = tonumber(event.reach) or 28
				if event.partId == "dash" then
					root.AssemblyLinearVelocity = direction.Unit * (reach * 3.2) + Vector3.new(0, 10, 0)
				elseif event.partId == "leap" then
					root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, reach * 2.2, root.AssemblyLinearVelocity.Z)
				end
				AnimUtil.play("dodge", 0.05)
			end
		end
	end
	if event.userId == player.UserId and stepKind ~= "motion" then
		AnimUtil.play("castTechnique", 0.08)
	end
end

-- -------------------------------- Input ----------------------------------

local blocking = false

local function setBlocking(wants: boolean)
	if blocking == wants then
		return
	end
	blocking = wants
	blockRemote:FireServer(wants)
	if wants then
		AnimUtil.play("block", 0.1, true)
	else
		AnimUtil.stop("block", 0.15)
	end
end

local lightSwingIndex = 0

local function onVfx(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local event = payload :: { [string]: any }
	local kind = event.kind
	if kind == "swing" and typeof(event.origin) == "Vector3" and typeof(event.direction) == "Vector3" then
		renderSwing(event.origin, event.direction, tonumber(event.swing) or 1)
	elseif kind == "hit" and typeof(event.position) == "Vector3" then
		renderHit(event.position, tonumber(event.amount) or 0)
	elseif kind == "blocked" and typeof(event.userId) == "number" then
		renderShield(event.userId, Color3.fromRGB(190, 210, 240))
	elseif kind == "dodged" and typeof(event.userId) == "number" then
		renderShield(event.userId, Color3.fromRGB(160, 235, 200))
	elseif kind == "dodge" and typeof(event.userId) == "number" and event.userId ~= player.UserId then
		local root = characterRootOf(event.userId)
		if root then
			local flash = ghost(Vector3.new(2.4, 2.4, 2.4), root.CFrame, Color3.fromRGB(160, 235, 200), Enum.PartType.Ball)
			flash.Transparency = 0.5
			fadeOut(flash, 0.3, { Size = Vector3.new(5, 5, 5) })
		end
	elseif kind == "breakthrough" and typeof(event.origin) == "Vector3" then
		local color = if typeof(event.color) == "Color3" then event.color else Color3.fromRGB(255, 220, 130)
		renderBreakthrough(event.origin, color, event.major == true)
		if event.userId == player.UserId then
			AnimUtil.play("breakthrough", 0.1)
		end
	elseif kind == "techniqueStep" and typeof(event.origin) == "Vector3" and typeof(event.direction) == "Vector3" then
		renderTechniqueStep(event)
	end
end

function CombatController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mouse = player:GetMouse()
			attackRemote:FireServer("light", mouse.Hit.Position)
			lightSwingIndex = (lightSwingIndex % 3) + 1
			AnimUtil.play(`lightAttack{lightSwingIndex}`, 0.06)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			local mouse = player:GetMouse()
			attackRemote:FireServer("heavy", mouse.Hit.Position)
			AnimUtil.play("heavyAttack", 0.06)
		elseif input.KeyCode == Enum.KeyCode.F then
			setBlocking(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F then
			setBlocking(false)
		end
	end)

	Net.remoteEvent("CombatFx").OnClientEvent:Connect(onVfx)
end

return CombatController
