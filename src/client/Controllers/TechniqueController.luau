--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > TechniqueController
-- Casting input (keys 1-6, aimed at the mouse) and the client-side face of
-- every technique: the VFX broadcast renderer, and the local application of
-- approved movement techniques (the client owns its character's physics, so
-- dashes and leaps feel instant; the server already charged the qi).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local TechniqueMath = require(Shared:WaitForChild("TechniqueMath"))
local Elements = require(Shared:WaitForChild("Data"):WaitForChild("Elements"))

local ClientState = require(script.Parent.Parent.Modules.ClientState)
local ClientSettings = require(script.Parent.Parent.Modules.ClientSettings)

local TechniqueController = {}

local player = Players.LocalPlayer
local castRemote = Net.remoteEvent("CastTechnique")

local SLOT_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

-- --------------------------------- Cast ---------------------------------

local localCooldowns: { [string]: number } = {}

local function cast(slot: number)
	local techniques = ClientState.techniques
	if techniques == nil then
		return
	end
	local techniqueId = techniques.slots[tostring(slot)]
	if techniqueId == nil then
		return
	end
	local technique: { id: string, name: string, form: string, element: string, power: number }? = nil
	for _, candidate in techniques.techniques do
		if candidate.id == techniqueId then
			technique = candidate
			break
		end
	end
	if technique == nil then
		return
	end

	-- Optimistic local cooldown so the hotbar reads honestly; the server
	-- keeps the real one.
	local stats = (TechniqueMath.compute(technique.form, technique.element, technique.power))
	local now = os.clock()
	if stats then
		local readyAt = localCooldowns[techniqueId]
		if readyAt and now < readyAt then
			return
		end
		localCooldowns[techniqueId] = now + stats.cooldown
		ClientState.FireCooldown(slot, stats.cooldown)
	end

	local mouse = player:GetMouse()
	castRemote:FireServer(slot, mouse.Hit.Position)
end

-- --------------------------------- VFX ----------------------------------

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

local function ghostPart(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
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

local function renderProjectile(origin: Vector3, direction: Vector3, speed: number, range: number, color: Color3)
	local ball = ghostPart(Vector3.new(1.6, 1.6, 1.6), CFrame.new(origin), color, Enum.PartType.Ball)
	local travelTime = range / math.max(speed, 1)
	local tween = TweenService:Create(ball, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(origin + direction.Unit * range),
	})
	tween.Completed:Once(function()
		fadeOut(ball, 0.15)
	end)
	tween:Play()
	-- Thin qi trail.
	local trail = ghostPart(Vector3.new(0.4, 0.4, range), CFrame.lookAt(origin + direction.Unit * (range / 2), origin + direction.Unit * range), color)
	trail.Transparency = 0.75
	fadeOut(trail, math.min(travelTime + 0.3, 1))
end

local function renderMelee(origin: Vector3, direction: Vector3, range: number, color: Color3)
	local arcCFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -range / 2)
	local arc = ghostPart(Vector3.new(range * 0.9, 0.6, range), arcCFrame, color)
	arc.Transparency = 0.35
	fadeOut(arc, 0.3, { Size = Vector3.new(range * 1.1, 0.2, range * 1.2) })
end

local function renderBlast(center: Vector3, radius: number, color: Color3, delay: number?)
	task.delay(delay or 0, function()
		local ring = ghostPart(Vector3.new(1, 0.6, 1), CFrame.new(center), color, Enum.PartType.Cylinder)
		ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.2
		fadeOut(ring, 0.45, { Size = Vector3.new(0.6, radius * 2, radius * 2) })
		local dome = ghostPart(Vector3.new(2, 2, 2), CFrame.new(center), color, Enum.PartType.Ball)
		dome.Transparency = 0.5
		fadeOut(dome, 0.45, { Size = Vector3.new(radius * 1.6, radius * 1.6, radius * 1.6) })
	end)
end

local function renderBreakthrough(origin: Vector3)
	local pillar = ghostPart(Vector3.new(6, 160, 6), CFrame.new(origin + Vector3.new(0, 80, 0)), Color3.fromRGB(255, 220, 130))
	pillar.Transparency = 0.25
	fadeOut(pillar, 1.6, { Size = Vector3.new(1, 180, 1) })
	renderBlast(origin, 14, Color3.fromRGB(255, 220, 130))
end

-- Movement application for our own approved casts.
local function applyMovement(formKind: string, direction: Vector3, speed: number, aim: Vector3)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	if formKind == "dash" then
		root.AssemblyLinearVelocity = direction.Unit * speed + Vector3.new(0, 12, 0)
	elseif formKind == "leap" then
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, speed, root.AssemblyLinearVelocity.Z)
	end
	-- teleport and speed_buff are fully server-side.
end

local function onVFX(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local event = payload :: { [string]: any }
	local isSelf = event.casterUserId == player.UserId

	if event.kind == "breakthrough" and typeof(event.origin) == "Vector3" then
		if ClientSettings.get("vfxEnabled") or isSelf then
			renderBreakthrough(event.origin)
		end
		return
	end
	if event.kind ~= "cast" then
		return
	end
	local origin = event.origin
	local direction = event.direction
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end

	-- Own movement always applies, even with VFX off; it is gameplay.
	if isSelf then
		applyMovement(event.formKind, direction, tonumber(event.speed) or 0, event.aim)
	end

	if not ClientSettings.get("vfxEnabled") then
		return
	end
	if not isSelf and not ClientSettings.get("othersVfx") then
		return
	end

	local element = Elements.get(tostring(event.element))
	local color = if element then element.color else Color3.fromRGB(170, 215, 255)
	local formKind = tostring(event.formKind)
	local range = tonumber(event.range) or 10
	local radius = tonumber(event.radius) or 8
	local speed = tonumber(event.speed) or 60

	if formKind == "melee" then
		renderMelee(origin, direction, range, color)
	elseif formKind == "projectile" then
		renderProjectile(origin, direction, speed, range, color)
	elseif formKind == "aoe_point" and typeof(event.aim) == "Vector3" then
		renderBlast(event.aim, radius, color, 0.35)
	elseif formKind == "aoe_self" then
		renderBlast(origin, radius, color)
	elseif formKind == "dash" or formKind == "leap" or formKind == "teleport" then
		renderBlast(origin, 4, color)
	elseif formKind == "speed_buff" then
		renderBlast(origin, 5, color)
	end
end

-- ------------------------------ Lifecycle -------------------------------

function TechniqueController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local slot = SLOT_KEYS[input.KeyCode]
		if slot then
			cast(slot)
		end
	end)

	Net.remoteEvent("TechniqueVFX").OnClientEvent:Connect(onVFX)
end

return TechniqueController
