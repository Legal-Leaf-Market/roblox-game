--!strict
-- ModuleScript: ServerScriptService > Server > Systems > PathService
-- The three paths as Teams, and the shrine in each city where a wanderer
-- pledges. Pledging is permanent (a dao is not a hat) and moves the
-- player's respawns to their path's city via team spawn locations.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paths = require(Shared:WaitForChild("Data"):WaitForChild("Paths"))
local Types = require(Shared:WaitForChild("Types"))

local DataService = require(script.Parent.DataService)

local WANDERER_TEAM = "Wanderers"
local WANDERER_COLOR = "Medium stone grey"

local PathService = {}

local teams: { [string]: Team } = {}

local function ensureTeam(name: string, brickColorName: string, autoAssignable: boolean): Team
	local existing = Teams:FindFirstChild(name)
	if existing and existing:IsA("Team") then
		return existing
	end
	local team = Instance.new("Team")
	team.Name = name
	team.TeamColor = (BrickColor.new :: any)(brickColorName)
	team.AutoAssignable = autoAssignable
	team.Parent = Teams
	return team
end

local function teamFor(pathId: string?): Team
	if pathId and teams[pathId] then
		return teams[pathId]
	end
	return teams[WANDERER_TEAM]
end

local function syncTeam(player: Player)
	local data = DataService.Get(player)
	player.Team = teamFor(if data then data.path else nil)
end

local function pledge(player: Player, pathId: Types.PathId)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local pathDef = Paths[pathId]
	if pathDef == nil then
		return
	end
	if data.path ~= nil then
		local current = Paths[data.path :: string]
		DataService.Notify(player, `Your dao is already set. The {current.name} does not release its own.`)
		return
	end
	data.path = pathId
	syncTeam(player)
	DataService.Notify(player, `You have pledged to the {pathDef.name}. {pathDef.cityName} is now your home.`, pathDef.accentColor)
	DataService.PushStats(player)
end

local function bindShrine(shrine: Instance)
	local prompt = shrine:FindFirstChildWhichIsA("ProximityPrompt", true)
	local pathId = shrine:GetAttribute("PathId")
	if prompt == nil or typeof(pathId) ~= "string" then
		return
	end
	prompt.Triggered:Connect(function(player)
		pledge(player, pathId :: Types.PathId)
	end)
end

function PathService.Init()
	teams[WANDERER_TEAM] = ensureTeam(WANDERER_TEAM, WANDERER_COLOR, true)
	for id, def in Paths do
		teams[id] = ensureTeam(def.name, def.teamBrickColor, false)
	end

	DataService.ObserveLoaded(syncTeam)

	for _, shrine in CollectionService:GetTagged("PathShrine") do
		bindShrine(shrine)
	end
	CollectionService:GetInstanceAddedSignal("PathShrine"):Connect(bindShrine)
end

return PathService
