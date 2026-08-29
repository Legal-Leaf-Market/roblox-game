--!strict
-- ModuleScript: ServerScriptService > Server > Systems > WorldBuilder
-- Builds the whole island at server start: sculpted terrain first (Island),
-- then surface works (roads, stairs, mine gate, peak pagoda), the four
-- cities, biome flora, and the Deep Mines below. All from code, so the
-- entire game builds from a clean checkout; nothing is hand-placed.

local Island = require(script.Parent.World.Island)
local Overworld = require(script.Parent.World.Overworld)
local Cities = require(script.Parent.World.Cities)
local Flora = require(script.Parent.World.Flora)
local Underworld = require(script.Parent.World.Underworld)
local Sacred = require(script.Parent.World.Sacred)

local WorldBuilder = {}

function WorldBuilder.Init()
	if workspace:FindFirstChild("World") then
		return -- already built (Studio test re-run)
	end
	local world = Instance.new("Folder")
	world.Name = "World"

	Island.build()
	Overworld.build(world)
	Cities.build(world)
	Flora.build(world)
	Underworld.build(world)
	Sacred.build(world)

	world.Parent = workspace
	print("[WorldBuilder] The island stands: three realms, four cities, one mountain.")
end

return WorldBuilder
