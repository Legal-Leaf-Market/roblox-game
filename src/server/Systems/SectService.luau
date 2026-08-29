--!strict
-- ModuleScript: ServerScriptService > Server > Systems > SectService
-- Sects and lineage. Sects persist across servers in their own DataStore
-- (a name registry enforces uniqueness); membership rank lives on the sect
-- record, the player's sectId on their own save. Master-disciple bonds are
-- offered and accepted in person (both online), and everything a client
-- sees arrives through one SocialChanged push.
--
-- Ranks, highest to lowest: leader, vice, elder, inner, outer.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))

local DataService = require(script.Parent.DataService)

local SectService = {}

local SECT_STORE = "Sects_v1"
local NAME_STORE = "SectNames_v1"
local OFFER_TTL = 90

export type SectData = {
	id: string,
	name: string,
	created: number,
	ranks: { [string]: string }, -- userId (string) -> rank id
	names: { [string]: string }, -- userId (string) -> last known display name
}

local RANK_POWER: { [string]: number } = {
	leader = 5,
	vice = 4,
	elder = 3,
	inner = 2,
	outer = 1,
}

local RANK_NAMES: { [string]: string } = {
	leader = "Sect Leader",
	vice = "Vice Sect Leader",
	elder = "Elder",
	inner = "Inner Disciple",
	outer = "Outer Disciple",
}

local actionLimit = RateLimit.new(6, 5)

-- In-memory fallback so Studio without API access still runs everything.
local memSects: { [string]: SectData } = {}
local memNames: { [string]: string } = {}

local sectStore: DataStore? = nil
local nameStore: DataStore? = nil

-- pendingOffers[discipleUserId] = { masterUserId, expires }
local pendingOffers: { [number]: { masterUserId: number, expires: number } } = {}

local function fail(message: string): { [string]: any }
	return { ok = false, error = message }
end

-- ------------------------------- Storage --------------------------------

local function stores(): (DataStore?, DataStore?)
	if sectStore == nil then
		pcall(function()
			sectStore = DataStoreService:GetDataStore(SECT_STORE)
		end)
	end
	if nameStore == nil then
		pcall(function()
			nameStore = DataStoreService:GetDataStore(NAME_STORE)
		end)
	end
	return sectStore, nameStore
end

local function getSect(sectId: string): SectData?
	local store = (stores())
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(sectId)
		end)
		if ok and typeof(result) == "table" then
			return result :: SectData
		end
		if ok then
			return nil
		end
	end
	return memSects[sectId]
end

-- Atomic mutation; mutate returns false to abort. Returns the final record.
local function updateSect(sectId: string, mutate: (SectData?) -> SectData?): SectData?
	local store = (stores())
	if store then
		local final: SectData? = nil
		local ok = pcall(function()
			store:UpdateAsync(sectId, function(existing)
				local result = mutate(if typeof(existing) == "table" then existing :: SectData else nil)
				final = result
				return result
			end)
		end)
		if ok then
			return final
		end
	end
	local result = mutate(memSects[sectId])
	memSects[sectId] = result :: any
	return result
end

-- Claim a sect name (lowercased). Returns false if taken.
local function claimName(nameKey: string, sectId: string): boolean
	local _, store = stores()
	if store then
		local claimed = false
		local ok = pcall(function()
			store:UpdateAsync(nameKey, function(existing)
				if existing == nil then
					claimed = true
					return sectId
				end
				claimed = existing == sectId
				return existing
			end)
		end)
		if ok then
			return claimed
		end
	end
	if memNames[nameKey] == nil or memNames[nameKey] == sectId then
		memNames[nameKey] = sectId
		return true
	end
	return false
end

local function releaseName(nameKey: string)
	local _, store = stores()
	if store then
		local ok = pcall(function()
			store:RemoveAsync(nameKey)
		end)
		if ok then
			return
		end
	end
	memNames[nameKey] = nil
end

local function lookupSectIdByName(nameKey: string): string?
	local _, store = stores()
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(nameKey)
		end)
		if ok then
			return if typeof(result) == "string" then result else nil
		end
	end
	return memNames[nameKey]
end

-- ------------------------------ The push --------------------------------

function SectService.PushSocial(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end

	local sectPayload: { [string]: any }? = nil
	if data.sectId then
		local sect = getSect(data.sectId :: string)
		local myRank = if sect then sect.ranks[tostring(player.UserId)] else nil
		if sect == nil or myRank == nil then
			data.sectId = nil -- disbanded, or we were cast out
		else
			local members = {}
			for userIdKey, rank in sect.ranks do
				local userId = tonumber(userIdKey) or 0
				table.insert(members, {
					userId = userId,
					name = sect.names[userIdKey] or "?",
					rank = rank,
					rankName = RANK_NAMES[rank] or rank,
					power = RANK_POWER[rank] or 0,
					online = Players:GetPlayerByUserId(userId) ~= nil,
				})
			end
			table.sort(members, function(a, b)
				return (a.power :: number) > (b.power :: number)
			end)
			sectPayload = {
				id = sect.id,
				name = sect.name,
				myRank = myRank,
				myRankName = RANK_NAMES[myRank] or myRank,
				members = members,
			}
		end
	end

	local disciples = {}
	for _, disciple in data.disciples do
		table.insert(disciples, {
			userId = disciple.userId,
			name = disciple.name,
			online = Players:GetPlayerByUserId(disciple.userId) ~= nil,
		})
	end

	Net.remoteEvent("SocialChanged"):FireClient(player, {
		sect = sectPayload,
		masterName = data.masterName,
		disciples = disciples,
		discipleCap = Config.MAX_DISCIPLES,
		masterBonus = data.masterBonus,
	})
end

local function pushIfOnline(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		SectService.PushSocial(player)
	end
end

-- ------------------------------- Sects ----------------------------------

local function sanitizeSectName(player: Player, raw: unknown): (string?, string?)
	if typeof(raw) ~= "string" then
		return nil, "Bad request"
	end
	local name = (raw :: string):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if #name < Config.SECT_NAME_MIN or #name > Config.SECT_NAME_MAX then
		return nil, `Sect names run {Config.SECT_NAME_MIN} to {Config.SECT_NAME_MAX} characters.`
	end
	if name:match("^[%w%s'%-]+$") == nil then
		return nil, "Letters, numbers, spaces, hyphens and apostrophes only."
	end
	local filtered = name
	pcall(function()
		local obj = TextService:FilterStringAsync(name, player.UserId)
		filtered = obj:GetNonChatStringForBroadcastAsync()
	end)
	if filtered:find("#") then
		return nil, "That name does not pass the heavens' censors."
	end
	return filtered, nil
end

local function createSect(player: Player, payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if data.sectId then
		return fail("You already belong to a sect.")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local name, reason = sanitizeSectName(player, (payload :: { [string]: unknown }).name)
	if name == nil then
		return fail(reason or "Bad name")
	end
	if data.spiritStones < Config.SECT_CREATE_COST then
		return fail(`Founding a sect takes {Config.SECT_CREATE_COST} spirit stones.`)
	end

	local sectId = "sect_" .. HttpService:GenerateGUID(false)
	local nameKey = (name :: string):lower()
	if not claimName(nameKey, sectId) then
		return fail("A sect already bears that name.")
	end

	updateSect(sectId, function()
		return {
			id = sectId,
			name = name :: string,
			created = os.time(),
			ranks = { [tostring(player.UserId)] = "leader" },
			names = { [tostring(player.UserId)] = player.Name },
		}
	end)

	data.spiritStones -= Config.SECT_CREATE_COST
	data.sectId = sectId
	DataService.Notify(player, `The {name} stands. You are its Sect Leader.`, Color3.fromRGB(255, 215, 120))
	DataService.PushStats(player)
	DataService.PushInventory(player)
	SectService.PushSocial(player)
	return { ok = true }
end

local function joinSect(player: Player, payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if data.sectId then
		return fail("You already belong to a sect.")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local raw = (payload :: { [string]: unknown }).name
	if typeof(raw) ~= "string" then
		return fail("Bad request")
	end
	local sectId = lookupSectIdByName((raw :: string):gsub("^%s+", ""):gsub("%s+$", ""):lower())
	if sectId == nil then
		return fail("No sect bears that name.")
	end

	local joined = false
	local sect = updateSect(sectId, function(existing)
		if existing == nil then
			return nil
		end
		local count = 0
		for _ in existing.ranks do
			count += 1
		end
		if count >= Config.SECT_MEMBER_CAP then
			return existing
		end
		existing.ranks[tostring(player.UserId)] = "outer"
		existing.names[tostring(player.UserId)] = player.Name
		joined = true
		return existing
	end)
	if sect == nil then
		return fail("That sect has scattered to the winds.")
	end
	if not joined then
		return fail("That sect is full.")
	end
	data.sectId = sectId
	DataService.Notify(player, `You enter the {sect.name} as an Outer Disciple.`)
	SectService.PushSocial(player)
	-- Refresh online sect-mates' member lists.
	for userIdKey in sect.ranks do
		pushIfOnline(tonumber(userIdKey) or 0)
	end
	return { ok = true }
end

local function leaveSect(player: Player, _payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil or data.sectId == nil then
		return fail("You belong to no sect.")
	end
	local sectId = data.sectId :: string
	local blocked = false
	local sect = updateSect(sectId, function(existing)
		if existing == nil then
			return nil
		end
		local key = tostring(player.UserId)
		local memberCount = 0
		for _ in existing.ranks do
			memberCount += 1
		end
		if existing.ranks[key] == "leader" and memberCount > 1 then
			blocked = true
			return existing
		end
		existing.ranks[key] = nil
		existing.names[key] = nil
		return existing
	end)
	if blocked then
		return fail("A Sect Leader must pass on leadership (or disband) before leaving.")
	end
	data.sectId = nil
	DataService.Notify(player, "You walk your own road once more.")
	SectService.PushSocial(player)
	if sect then
		for userIdKey in sect.ranks do
			pushIfOnline(tonumber(userIdKey) or 0)
		end
		local remaining = 0
		for _ in sect.ranks do
			remaining += 1
		end
		if remaining == 0 then
			releaseName(sect.name:lower())
		end
	end
	return { ok = true }
end

local function disbandSect(player: Player, _payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil or data.sectId == nil then
		return fail("You belong to no sect.")
	end
	local sectId = data.sectId :: string
	local sect = getSect(sectId)
	if sect == nil then
		data.sectId = nil
		SectService.PushSocial(player)
		return fail("That sect is already gone.")
	end
	if sect.ranks[tostring(player.UserId)] ~= "leader" then
		return fail("Only the Sect Leader may disband the sect.")
	end
	updateSect(sectId, function()
		return nil
	end)
	releaseName(sect.name:lower())
	for userIdKey in sect.ranks do
		local member = Players:GetPlayerByUserId(tonumber(userIdKey) or 0)
		local memberData = if member then DataService.Get(member) else nil
		if member and memberData then
			memberData.sectId = nil
			DataService.Notify(member, `The {sect.name} has been disbanded.`)
			SectService.PushSocial(member)
		end
		-- Offline members clear their stale sectId on next PushSocial.
	end
	return { ok = true }
end

local function setSectRank(player: Player, payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil or data.sectId == nil then
		return fail("You belong to no sect.")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local request = payload :: { [string]: unknown }
	local targetUserId = request.targetUserId
	local newRank = request.rank
	if typeof(targetUserId) ~= "number" or typeof(newRank) ~= "string" then
		return fail("Bad request")
	end
	if newRank ~= "kick" and RANK_POWER[newRank :: string] == nil then
		return fail("Unknown rank")
	end
	if targetUserId == player.UserId then
		return fail("One does not promote oneself.")
	end

	local sectId = data.sectId :: string
	local errorMessage: string? = nil
	local sect = updateSect(sectId, function(existing)
		if existing == nil then
			errorMessage = "That sect has scattered."
			return nil
		end
		local actorRank = existing.ranks[tostring(player.UserId)]
		local targetRank = existing.ranks[tostring(targetUserId)]
		local actorPower = RANK_POWER[actorRank or ""] or 0
		local targetPower = RANK_POWER[targetRank or ""] or 0
		if targetRank == nil then
			errorMessage = "They are not of this sect."
			return existing
		end
		if actorPower < RANK_POWER.vice then
			errorMessage = "Only the Sect Leader and Vice Sect Leader manage ranks."
			return existing
		end
		if actorPower <= targetPower then
			errorMessage = "You cannot judge one who stands at or above your station."
			return existing
		end
		if newRank == "kick" then
			existing.ranks[tostring(targetUserId)] = nil
			existing.names[tostring(targetUserId)] = nil
			return existing
		end
		if newRank == "leader" then
			if actorRank ~= "leader" then
				errorMessage = "Only the Sect Leader may pass on leadership."
				return existing
			end
			existing.ranks[tostring(targetUserId)] = "leader"
			existing.ranks[tostring(player.UserId)] = "vice"
			return existing
		end
		if RANK_POWER[newRank :: string] >= actorPower then
			errorMessage = "You cannot raise another to your own station or above."
			return existing
		end
		existing.ranks[tostring(targetUserId)] = newRank :: string
		return existing
	end)
	if errorMessage then
		return fail(errorMessage)
	end
	if sect == nil then
		data.sectId = nil
		SectService.PushSocial(player)
		return fail("That sect has scattered.")
	end

	local target = Players:GetPlayerByUserId(targetUserId :: number)
	if newRank == "kick" then
		local targetData = if target then DataService.Get(target) else nil
		if target and targetData then
			targetData.sectId = nil
			DataService.Notify(target, `You have been cast out of the {sect.name}.`)
			SectService.PushSocial(target)
		end
	elseif target then
		DataService.Notify(target, `Within the {sect.name}, you are now {RANK_NAMES[newRank :: string]}.`)
	end
	for userIdKey in sect.ranks do
		pushIfOnline(tonumber(userIdKey) or 0)
	end
	SectService.PushSocial(player)
	return { ok = true }
end

-- --------------------------- Master & disciple ---------------------------

local function offerDiscipleship(player: Player, payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if typeof(payload) ~= "table" then
		return fail("Bad request")
	end
	local targetName = (payload :: { [string]: unknown }).targetName
	if typeof(targetName) ~= "string" then
		return fail("Bad request")
	end
	if #data.disciples >= Config.MAX_DISCIPLES then
		return fail(`You may guide at most {Config.MAX_DISCIPLES} disciples.`)
	end

	local target: Player? = nil
	local lowered = (targetName :: string):lower()
	for _, candidate in Players:GetPlayers() do
		if candidate.Name:lower() == lowered or candidate.DisplayName:lower() == lowered then
			target = candidate
			break
		end
	end
	if target == nil then
		return fail("No cultivator by that name walks this land right now.")
	end
	local targetPlayer = target :: Player
	if targetPlayer.UserId == player.UserId then
		return fail("One cannot be one's own master. Many have tried.")
	end
	local targetData = DataService.Get(targetPlayer)
	if targetData == nil then
		return fail("They are still arriving in this world.")
	end
	if targetData.masterUserId ~= nil then
		return fail("They already follow a master.")
	end
	if data.masterUserId == targetPlayer.UserId then
		return fail("Your own master? The heavens would laugh.")
	end
	for _, disciple in data.disciples do
		if disciple.userId == targetPlayer.UserId then
			return fail("They are already your disciple.")
		end
	end

	pendingOffers[targetPlayer.UserId] = { masterUserId = player.UserId, expires = os.clock() + OFFER_TTL }
	Net.remoteEvent("DiscipleOffer"):FireClient(targetPlayer, {
		masterUserId = player.UserId,
		masterName = player.Name,
	})
	DataService.Notify(player, `You have offered to take {targetPlayer.Name} as your disciple.`)
	return { ok = true }
end

local function respondDiscipleship(player: Player, payload: unknown): { [string]: any }
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	local offer = pendingOffers[player.UserId]
	pendingOffers[player.UserId] = nil
	if offer == nil or os.clock() > offer.expires then
		return fail("The offer has lapsed.")
	end
	local accept = typeof(payload) == "table" and (payload :: { [string]: unknown }).accept == true

	local master = Players:GetPlayerByUserId(offer.masterUserId)
	local masterData = if master then DataService.Get(master) else nil
	if not accept then
		if master then
			DataService.Notify(master, `{player.Name} has declined your guidance.`)
		end
		return { ok = true }
	end
	if master == nil or masterData == nil then
		return fail("Your would-be master has left this world.")
	end
	if data.masterUserId ~= nil then
		return fail("You already follow a master.")
	end
	if #masterData.disciples >= Config.MAX_DISCIPLES then
		return fail("Their courtyard is full.")
	end

	data.masterUserId = master.UserId
	data.masterName = master.Name
	table.insert(masterData.disciples, { userId = player.UserId, name = player.Name })
	DataService.Notify(player, `You kneel and rise a disciple of {master.Name}.`, Color3.fromRGB(255, 215, 120))
	DataService.Notify(master, `{player.Name} is now your disciple.`, Color3.fromRGB(255, 215, 120))
	SectService.PushSocial(player)
	SectService.PushSocial(master)
	return { ok = true }
end

local function renounceMaster(player: Player, _payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	if data.masterUserId == nil then
		return fail("You follow no master.")
	end
	local masterUserId = data.masterUserId :: number
	data.masterUserId = nil
	data.masterName = nil

	local master = Players:GetPlayerByUserId(masterUserId)
	local masterData = if master then DataService.Get(master) else nil
	if master and masterData then
		for index, disciple in masterData.disciples do
			if disciple.userId == player.UserId then
				table.remove(masterData.disciples, index)
				break
			end
		end
		DataService.Notify(master, `{player.Name} has left your tutelage.`)
		SectService.PushSocial(master)
	else
		DataService.MailRemoveDisciple(masterUserId, player.UserId)
	end
	DataService.Notify(player, "You bow once, and walk on alone.")
	SectService.PushSocial(player)
	return { ok = true }
end

-- ------------------------------ Lifecycle -------------------------------

function SectService.Init()
	Net.remoteFunction("CreateSect").OnServerInvoke = createSect
	Net.remoteFunction("JoinSect").OnServerInvoke = joinSect
	Net.remoteFunction("LeaveSect").OnServerInvoke = leaveSect
	Net.remoteFunction("DisbandSect").OnServerInvoke = disbandSect
	Net.remoteFunction("SetSectRank").OnServerInvoke = setSectRank
	Net.remoteFunction("OfferDiscipleship").OnServerInvoke = offerDiscipleship
	Net.remoteFunction("RespondDiscipleship").OnServerInvoke = respondDiscipleship
	Net.remoteFunction("RenounceMaster").OnServerInvoke = renounceMaster

	DataService.ObserveLoaded(function(player)
		SectService.PushSocial(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingOffers[player.UserId] = nil
		actionLimit:Forget(player.UserId)
	end)
end

return SectService
