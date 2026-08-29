--!strict
-- ModuleScript: ServerScriptService > Server > Systems > WorldBuilder
-- Stamps the whole map out of code at server start: surface, mountain,
-- three cities, and the caves. Keeping the world in code (rather than in a
-- place file) is what lets the entire game live in git and build from a
-- clean checkout; nothing in Studio is hand-placed.

local Overworld = require(script.Parent.World.Overworld)
local Cities = require(script.Parent.World.Cities)
local Underworld = require(script.Parent.World.Underworld)

local WorldBuilder = {}

function WorldBuilder.Init()
	if workspace:FindFirstChild("World") then
		return -- already built (Studio test re-run)
	end
	local world = Instance.new("Folder")
	world.Name = "World"

	Overworld.build(world)
	Cities.build(world)
	Underworld.build(world)

	world.Parent = workspace
	print("[WorldBuilder] Heavenpillar and the three cities stand.")
end

return WorldBuilder
