--!strict
-- ModuleScript: ReplicatedStorage > Shared > Net
-- Single owner of every RemoteEvent/RemoteFunction. The server CREATES
-- remotes (get-or-create), the client WAITS for them. Every remote name is
-- declared here and nowhere else, so a typo fails loudly at startup and
-- duplicates are impossible by construction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local REMOTE_EVENTS: { string } = {
	-- Server -> client state pushes
	"StatsChanged", -- stage, qi, xp, stones, meditating
	"InventoryChanged", -- items, manuals, equipped gear
	"TechniquesChanged", -- designs + hotbar slots
	"SocialChanged", -- sect, master, disciples
	"Notify", -- toast { text, color? }
	"CombatFx", -- broadcast: swings, hits, deaths, breakthroughs (VFX only)
	"DiscipleOffer", -- someone offers to take you as disciple

	-- Client -> server intents (server validates everything)
	"MeditateSet", -- (wants: boolean)
	"AttackRequest", -- (kind: "light"|"heavy", aim: Vector3)
	"BlockSet", -- (blocking: boolean)
	"DodgeRequest", -- () server opens the evasion window
	"CastTechnique", -- (slot: number, aim: Vector3)
}

local REMOTE_FUNCTIONS: { string } = {
	"BreakthroughRequest", -- attempt to advance a stage
	"CreateTechnique", -- design from components
	"DeleteTechnique",
	"EquipTechnique", -- bind to hotbar slot
	"WriteManual", -- author a technique manual (needs 100% mastery)
	"UseManual", -- learn from a held manual
	"GiveManual", -- hand a manual to a nearby player
	"EquipItem",
	"OfferDiscipleship",
	"RespondDiscipleship",
	"RenounceMaster",
	"TeachTechnique", -- direct master->disciple transmission
}

local Net = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if folder == nil then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function assertDeclared(name: string, list: { string }, kind: string)
	if table.find(list, name) == nil then
		error(`Net: "{name}" is not a declared {kind}. Add it to Net.luau.`, 3)
	end
end

function Net.remoteEvent(name: string): RemoteEvent
	assertDeclared(name, REMOTE_EVENTS, "RemoteEvent")
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.remoteFunction(name: string): RemoteFunction
	assertDeclared(name, REMOTE_FUNCTIONS, "RemoteFunction")
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteFunction
		end
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteFunction
end

-- Server bootstrap: create every declared remote up front so clients never
-- hang waiting on one a lazy system hasn't touched yet.
function Net.initServer()
	assert(RunService:IsServer(), "Net.initServer is server-only")
	for _, name in REMOTE_EVENTS do
		Net.remoteEvent(name)
	end
	for _, name in REMOTE_FUNCTIONS do
		Net.remoteFunction(name)
	end
end

return Net
