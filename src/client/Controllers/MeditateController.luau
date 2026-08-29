--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > MeditateController
-- Meditation toggle (key G). Tells the server, sits the character down via
-- a client-side aura; the server owns the actual regen/xp effects and ends
-- meditation automatically when the player moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.Modules.ClientState)

local MeditateController = {}

local player = Players.LocalPlayer
local aura: Part? = nil

local function setAura(active: boolean)
	if not active then
		if aura then
			aura:Destroy()
			aura = nil
		end
		return
	end
	if aura and aura.Parent then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 9, 9)
	ring.CFrame = root.CFrame * CFrame.new(0, -2.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(120, 210, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Parent = workspace
	aura = ring
end

function MeditateController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G then
			local meditating = if ClientState.stats then ClientState.stats.meditating else false
			Net.remoteEvent("MeditateSet"):FireServer(not meditating)
		end
	end)

	ClientState.StatsChanged:Connect(function()
		local stats = ClientState.stats
		setAura(if stats then stats.meditating else false)
	end)
end

return MeditateController
