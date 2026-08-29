--!strict
-- ModuleScript: ServerScriptService > Server > Systems > DiscipleService
-- The master/disciple bond. Offers must be accepted, relationships
-- persist in both players' data, and everything downstream (transmission,
-- inheritance) checks these records server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))

local DataService = require(script.Parent.DataService)

local DiscipleService = {}

local actionLimit = RateLimit.new(6, 5)

-- pendingOffers[discipleUserId] = masterUserId
local pendingOffers: { [number]: number } = {}

local function fail(message: string): { [string]: any }
	return { ok = false, error = message }
end

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
	local target = Players:FindFirstChild(targetName)
	if target == nil or not target:IsA("Player") then
		return fail("No such cultivator here.")
	end
	if target == player then
		return fail("One cannot kowtow to oneself.")
	end
	local targetData = DataService.Get(target :: Player)
	if targetData == nil then
		return fail("They are still arriving.")
	end
	if targetData.masterUserId ~= nil then
		return fail(`{target.Name} already serves a master.`)
	end
	if data.masterUserId == target.UserId then
		return fail("Your own master? The sect would talk.")
	end
	if #data.disciples >= Config.MAX_DISCIPLES then
		return fail(`You already guide {Config.MAX_DISCIPLES} disciples.`)
	end
	for _, disciple in data.disciples do
		if disciple.userId == target.UserId then
			return fail(`{target.Name} is already your disciple.`)
		end
	end

	pendingOffers[target.UserId] = player.UserId
	Net.remoteEvent("DiscipleOffer"):FireClient(target :: Player, {
		masterUserId = player.UserId,
		masterName = player.Name,
	})
	DataService.Notify(player, `You offer to take {target.Name} as your disciple.`)
	return { ok = true }
end

local function respondDiscipleship(player: Player, payload: unknown): { [string]: any }
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
	local accept = (payload :: { [string]: unknown }).accept
	local masterUserId = pendingOffers[player.UserId]
	pendingOffers[player.UserId] = nil
	if masterUserId == nil then
		return fail("No offer stands.")
	end
	local master = Players:GetPlayerByUserId(masterUserId)
	local masterData = if master then DataService.Get(master) else nil
	if master == nil or masterData == nil then
		return fail("The master has departed.")
	end
	if accept ~= true then
		DataService.Notify(master, `{player.Name} declines the bond.`)
		return { ok = true, accepted = false }
	end
	if data.masterUserId ~= nil then
		return fail("You already serve a master.")
	end
	if #masterData.disciples >= Config.MAX_DISCIPLES then
		return fail("Their hall is full.")
	end

	data.masterUserId = master.UserId
	data.masterName = master.Name
	table.insert(masterData.disciples, { userId = player.UserId, name = player.Name })

	DataService.Notify(player, `You bow. {master.Name} is now your master.`, Color3.fromRGB(255, 215, 120))
	DataService.Notify(master, `{player.Name} kneels and calls you master.`, Color3.fromRGB(255, 215, 120))
	DataService.PushSocial(player)
	DataService.PushSocial(master)
	return { ok = true, accepted = true }
end

local function renounceMaster(player: Player, _payload: unknown): { [string]: any }
	if not actionLimit:Allow(player.UserId) then
		return fail("Too many requests")
	end
	local data = DataService.Get(player)
	if data == nil then
		return fail("Data not loaded yet")
	end
	local masterUserId = data.masterUserId
	if masterUserId == nil then
		return fail("You serve no master.")
	end
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
		DataService.Notify(master, `{player.Name} has renounced you as master.`)
		DataService.PushSocial(master)
	end
	-- If the master is offline the stale entry is pruned the next time
	-- their disciple list is used; records always defer to the disciple's
	-- own masterUserId, which is authoritative.

	DataService.Notify(player, "The bond is cut. You walk alone again.")
	DataService.PushSocial(player)
	return { ok = true }
end

function DiscipleService.Init()
	Net.remoteFunction("OfferDiscipleship").OnServerInvoke = offerDiscipleship
	Net.remoteFunction("RespondDiscipleship").OnServerInvoke = respondDiscipleship
	Net.remoteFunction("RenounceMaster").OnServerInvoke = renounceMaster

	Players.PlayerRemoving:Connect(function(player)
		pendingOffers[player.UserId] = nil
		actionLimit:Forget(player.UserId)
	end)
end

return DiscipleService
