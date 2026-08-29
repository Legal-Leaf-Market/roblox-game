--!strict
-- ModuleScript: ServerScriptService > Server > Systems > InventoryService
-- Equipping gear and consuming items. Ownership lives in PlayerData and
-- only the server writes it; the client's inventory screen is a view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Items = require(Shared:WaitForChild("Items"))
local Realms = require(Shared:WaitForChild("Realms"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))

local DataService = require(script.Parent.DataService)
local CultivationService = require(script.Parent.CultivationService)

local InventoryService = {}

local actionLimit = RateLimit.new(10, 4)

local function fail(message: string): { [string]: any }
	return { ok = false, error = message }
end

-- One endpoint for equip/unequip/use, switched on the item's kind.
local function equipItem(player: Player, payload: unknown): { [string]: any }
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
	local request = payload :: { [string]: unknown }
	local id = request.id
	local action = request.action -- "equip" | "unequip" | "use"
	if action == "unequip" then
		data.equippedWeapon = nil
		DataService.PushInventory(player)
		return { ok = true }
	end
	if typeof(id) ~= "string" then
		return fail("Bad request")
	end
	local def = Items.get(id)
	if def == nil then
		return fail("Unknown item")
	end
	if (data.items[id] or 0) < 1 then
		return fail("You do not own that.")
	end

	if action == "equip" then
		if def.kind ~= "weapon" then
			return fail("That cannot be wielded.")
		end
		if def.stageReq and data.stage < def.stageReq then
			return fail(`Needs {Realms.displayName(def.stageReq)} to wield.`)
		end
		data.equippedWeapon = id
		DataService.Notify(player, `You take up the {def.name}.`)
		DataService.PushInventory(player)
		return { ok = true }
	elseif action == "use" then
		if def.kind ~= "pill" then
			return fail("That is not something you swallow.")
		end
		data.items[id] -= 1
		if data.items[id] <= 0 then
			data.items[id] = nil
		end
		if def.restoreQiFrac then
			CultivationService.RestoreQi(player, CultivationService.MaxQi(player) * def.restoreQiFrac)
			DataService.Notify(player, `The {def.name} dissolves; qi floods back.`)
		end
		if def.healFrac then
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * def.healFrac)
			end
			DataService.Notify(player, `The {def.name} knits you back together.`)
		end
		DataService.PushInventory(player)
		return { ok = true }
	end
	return fail("Bad request")
end

function InventoryService.Init()
	Net.remoteFunction("EquipItem").OnServerInvoke = equipItem
	Players.PlayerRemoving:Connect(function(player)
		actionLimit:Forget(player.UserId)
	end)
end

-- Grant helper other systems (loot, quests) call.
function InventoryService.Grant(player: Player, itemId: string, count: number)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	data.items[itemId] = (data.items[itemId] or 0) + count
	local def = Items.get(itemId)
	DataService.Notify(player, `+{count} {if def then def.name else itemId}`)
	DataService.PushInventory(player)
end

function InventoryService.GrantStones(player: Player, amount: number)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	data.spiritStones += amount
	DataService.Notify(player, `+{amount} spirit stones`, Color3.fromRGB(150, 220, 255))
	DataService.PushStats(player)
	DataService.PushInventory(player)
end

return InventoryService
