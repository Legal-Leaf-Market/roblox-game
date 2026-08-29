--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > CultivationController
-- Meditation (G to sit and gather qi; standing or walking ends it) and
-- the breakthrough request (B, or the HUD button). While meditating a
-- soft aura breathes around the character; the sit itself uses the
-- meditation animation slots when they exist and a plain Humanoid.Sit as
-- the graceful fallback.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.Modules.ClientState)
local AnimUtil = require(script.Parent.Parent.Modules.AnimUtil)

local CultivationController = {}

local player = Players.LocalPlayer
local meditating = false
local aura: ParticleEmitter? = nil

local function setAura(active: boolean)
	if not active then
		if aura then
			aura.Enabled = false
		end
		return
	end
	local model = player.Character
	local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	if aura == nil or aura.Parent == nil or aura.Parent.Parent ~= model then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "MeditationAura"
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(1.2, 2)
		emitter.Speed = NumberRange.new(0.6, 1.4)
		emitter.Size = NumberSequence.new(0.35, 0)
		emitter.Transparency = NumberSequence.new(0.35, 1)
		emitter.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
		emitter.LightEmission = 0.7
		emitter.Parent = root
		aura = emitter
	end
	(aura :: ParticleEmitter).Enabled = true
end

local function setMeditating(wants: boolean)
	if meditating == wants then
		return
	end
	meditating = wants
	Net.remoteEvent("MeditateSet"):FireServer(wants)
	local model = player.Character
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if wants then
		AnimUtil.play("meditateEnter", 0.15)
		task.delay(0.3, function()
			if meditating then
				local idle = AnimUtil.play("meditateIdle", 0.2, true)
				if idle == nil and humanoid then
					humanoid.Sit = true -- fallback until real animations exist
				end
			end
		end)
	else
		AnimUtil.stop("meditateIdle", 0.2)
		AnimUtil.play("meditateExit", 0.1)
		if humanoid then
			humanoid.Sit = false
		end
	end
	setAura(wants)
end

local function requestBreakthrough()
	task.spawn(function()
		Net.remoteFunction("BreakthroughRequest"):InvokeServer()
	end)
end

CultivationController.RequestBreakthrough = requestBreakthrough

function CultivationController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			setMeditating(not meditating)
		elseif input.KeyCode == Enum.KeyCode.B then
			requestBreakthrough()
		end
	end)

	-- The server may end meditation (movement, damage, breakthrough);
	-- mirror its verdict so pose and aura never linger wrongly.
	ClientState.StatsChanged:Connect(function()
		local stats = ClientState.stats
		if stats and stats.meditating == false and meditating then
			meditating = false
			AnimUtil.stop("meditateIdle", 0.2)
			local model = player.Character
			local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
			if humanoid then
				humanoid.Sit = false
			end
			setAura(false)
		end
	end)

	player.CharacterAdded:Connect(function()
		meditating = false
		aura = nil
	end)
end

return CultivationController
