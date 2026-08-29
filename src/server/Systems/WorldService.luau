--!strict
-- ModuleScript: ServerScriptService > Server > Systems > WorldService
-- Builds the Azure Vale at server start (terrain, then the handcrafted
-- layer, then vegetation) and tunes the sky. Everything from code, so the
-- whole game rebuilds from a clean checkout; nothing is hand-placed in
-- Studio and later lost.

local Lighting = game:GetService("Lighting")

local Terrain = require(script.Parent.World.Terrain)
local Vale = require(script.Parent.World.Vale)
local Flora = require(script.Parent.World.Flora)

local WorldService = {}

local function tuneSky()
	-- Late golden afternoon: warm, hazy, readable. Combat clarity beats
	-- postcard saturation, so every effect here is conservative.
	Lighting.ClockTime = 16.4
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.Ambient = Color3.fromRGB(96, 90, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 128, 112)

	if Lighting:FindFirstChildOfClass("Atmosphere") == nil then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.38
		atmosphere.Offset = 0.5
		atmosphere.Color = Color3.fromRGB(222, 214, 198)
		atmosphere.Decay = Color3.fromRGB(130, 120, 104)
		atmosphere.Haze = 2.6
		atmosphere.Glare = 0.5
		atmosphere.Parent = Lighting
	end
	pcall(function()
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.66
		clouds.Density = 0.38
		clouds.Color = Color3.fromRGB(235, 230, 220)
		clouds.Parent = workspace.Terrain
	end)
	if Lighting:FindFirstChildOfClass("BloomEffect") == nil then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 26
		bloom.Threshold = 1.15
		bloom.Parent = Lighting
	end
	if Lighting:FindFirstChildOfClass("SunRaysEffect") == nil then
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.07
		rays.Spread = 0.7
		rays.Parent = Lighting
	end
	if Lighting:FindFirstChildOfClass("ColorCorrectionEffect") == nil then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Contrast = 0.05
		grade.Saturation = 0.05
		grade.TintColor = Color3.fromRGB(255, 246, 230)
		grade.Parent = Lighting
	end
end

function WorldService.Init()
	if workspace:FindFirstChild("World") then
		return -- already built (Studio re-run)
	end
	local world = Instance.new("Folder")
	world.Name = "World"

	Terrain.build()
	Vale.build(world)
	Flora.build(world)
	tuneSky()

	world.Parent = workspace
	print("[WorldService] The Azure Vale lies open beneath Heavenpillar.")
end

return WorldService
