--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Modules > AnimUtil
-- Loads animation slots from Shared/Animations onto the local character.
-- Placeholder slots (REPLACE_ME) are skipped SILENTLY, so the game plays
-- fully un-animated until real clips are uploaded, and each animation
-- simply appears the moment its id is filled in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animations = require(Shared:WaitForChild("Animations"))

local AnimUtil = {}

local player = Players.LocalPlayer
local tracks: { [string]: AnimationTrack } = {}

local function isReal(id: string): boolean
	return not string.find(id, "REPLACE_ME", 1, true)
end

local function loadFor(model: Model)
	table.clear(tracks)
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 10)
	if animator == nil or not animator:IsA("Animator") then
		return
	end
	for slot, id in Animations :: { [string]: string } do
		if not isReal(id) then
			continue
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			tracks[slot] = track
		end
	end
end

-- Play a slot if its animation exists; harmless no-op otherwise.
function AnimUtil.play(slot: string, fadeTime: number?, looped: boolean?): AnimationTrack?
	local track = tracks[slot]
	if track then
		if looped ~= nil then
			track.Looped = looped
		end
		track:Play(fadeTime or 0.1)
	end
	return track
end

function AnimUtil.stop(slot: string, fadeTime: number?)
	local track = tracks[slot]
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.2)
	end
end

function AnimUtil.Init()
	if player.Character then
		task.spawn(loadFor, player.Character)
	end
	player.CharacterAdded:Connect(function(model)
		task.spawn(loadFor, model)
	end)
end

return AnimUtil
