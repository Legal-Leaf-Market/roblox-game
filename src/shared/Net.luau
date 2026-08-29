--!strict
-- ModuleScript: ReplicatedStorage > Shared > Net
-- Single owner of every RemoteEvent/RemoteFunction in the game.
--
-- The server CREATES remotes (get-or-create), the client WAITS for them, so
-- there is exactly one code path that names a remote and no script ever
-- Instance.new()s one ad hoc. Add new remote names to the lists below; both
-- sides read the same definition, so a typo fails loudly at startup instead
-- of silently at first fire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

-- Every remote in the game is declared here and nowhere else.
local REMOTE_EVENTS: { string } = {
	-- Server -> client state pushes
	"StatsChanged", -- qi, realm, xp, path, race, spirit stones, meditating
	"InventoryChanged", -- ores, items, equipped gear
	"TechniquesChanged", -- designed techniques + hotbar slots
	"DestinyChanged", -- owned/equipped races and talents, spin counts
	"SpinResult", -- outcome of a race/talent spin, for the reveal animation
	"SocialChanged", -- sect membership, master, disciples, dao fortune
	"DiscipleOffer", -- someone offers to take you as their disciple
	"Notify", -- toast message { text, color? }
	"OpenCrafting", -- player used the Spirit Forge prompt
	"DwarfDialogue", -- mission dialogue payload
	"TechniqueVFX", -- broadcast: someone cast a technique / broke through

	-- Client -> server intents
	"MeditateSet", -- (meditating: boolean)
	"QiStepSet", -- (active: boolean) qi over the feet: speed for qi drain
	"CastTechnique", -- (slot: number, aimPosition: Vector3)
}

local REMOTE_FUNCTIONS: { string } = {
	"SpinRace", -- roll a new race (free spin if any, else spirit stones)
	"SpinTalent", -- roll a new talent
	"EquipRace", -- switch to any owned race
	"EquipTalent", -- set the equipped talent list
	"CreateTechnique", -- design a new technique
	"DeleteTechnique",
	"EquipTechnique", -- bind a technique to a hotbar slot
	"CraftItem", -- forge a weapon/armor from ores
	"EquipItem", -- equip owned weapon/armor
	"MissionAction", -- "accept" | "turnin" at the dwarf

	-- Sect & lineage
	"CreateSect", -- found a sect (name + spirit stones)
	"JoinSect", -- join an existing sect by name
	"LeaveSect",
	"DisbandSect", -- leader only
	"SetSectRank", -- promote/demote/kick/transfer leadership
	"OfferDiscipleship", -- (targetName) both online
	"RespondDiscipleship", -- (accept: boolean)
	"RenounceMaster",
	"TeachTechnique", -- pass a mastered technique to a disciple
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
-- wait on one that a lazily-required system hasn't touched yet.
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
