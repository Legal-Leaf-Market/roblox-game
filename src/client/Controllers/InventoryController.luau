--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > InventoryController
-- Inventory (key I): the ore pouch and forged gear, with equip buttons.
-- Weapons gate technique categories, so this is also where a swordsman
-- becomes an archer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Ores = require(Shared:WaitForChild("Data"):WaitForChild("Ores"))
local Items = require(Shared:WaitForChild("Data"):WaitForChild("Items"))
local Realms = require(Shared:WaitForChild("Data"):WaitForChild("Realms"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)

local InventoryController = {}

local window: UiKit.Window
local oreList: ScrollingFrame
local itemList: ScrollingFrame

local function clearList(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function render()
	local inventory = ClientState.inventory
	if inventory == nil then
		return
	end

	clearList(oreList)
	local order = 0
	UiKit.label(oreList, `Spirit Stones: {inventory.spiritStones}`, UDim2.new(1, -8, 0, 22), UDim2.fromOffset(0, 0), {
		textSize = 13,
		color = UiKit.Colors.gold,
		bold = true,
	}).LayoutOrder = 0
	for _, oreId in Ores.order do
		local count = inventory.ores[oreId]
		if count == nil or count <= 0 then
			continue
		end
		local ore = Ores.get(oreId)
		if ore == nil then
			continue
		end
		order += 1
		local row = UiKit.frame(oreList, UDim2.new(1, -8, 0, 26), UDim2.fromOffset(0, 0), UiKit.Colors.panelLight)
		row.LayoutOrder = order
		UiKit.label(row, `{ore.name}  x{count}`, UDim2.new(1, -12, 1, 0), UDim2.fromOffset(6, 0), {
			textSize = 13,
			color = ore.color,
		})
	end
	if order == 0 then
		UiKit.label(oreList, "The pouch is empty. The mines are under the mountain.", UDim2.new(1, -8, 0, 30), UDim2.fromOffset(0, 0), {
			textSize = 12,
			color = UiKit.Colors.textDim,
			wrap = true,
		}).LayoutOrder = 1
	end

	clearList(itemList)
	local itemOrder = 0
	for _, itemId in Items.order do
		local count = inventory.items[itemId]
		if count == nil or count <= 0 then
			continue
		end
		local item = Items.get(itemId)
		if item == nil then
			continue
		end
		itemOrder += 1
		local slot: "weapon" | "armor" = if item.kind == "weapon" then "weapon" else "armor"
		local equipped = (slot == "weapon" and inventory.equippedWeapon == itemId)
			or (slot == "armor" and inventory.equippedArmor == itemId)
		local row = UiKit.frame(itemList, UDim2.new(1, -8, 0, 48), UDim2.fromOffset(0, 0), UiKit.Colors.panelLight)
		row.LayoutOrder = itemOrder
		UiKit.label(row, `{item.name}{if count > 1 then ` x{count}` else ""}`, UDim2.new(1, -96, 0, 18), UDim2.fromOffset(6, 4), {
			textSize = 13,
			bold = true,
		})
		local detail: string
		if item.kind == "weapon" then
			detail = `{item.category} · damage x{item.damageMult}`
		else
			detail = `robe · absorbs {math.floor(item.defense * 100)}%`
		end
		local realm = Realms[item.realmReq]
		if item.realmReq > 1 and realm then
			detail ..= ` · needs {realm.name}`
		end
		UiKit.label(row, detail, UDim2.new(1, -96, 0, 14), UDim2.fromOffset(6, 24), {
			textSize = 11,
			color = UiKit.Colors.textDim,
		})
		if equipped then
			UiKit.button(row, "Unequip", UDim2.fromOffset(80, 28), UDim2.new(1, -86, 0.5, -14), function()
				task.spawn(function()
					Net.remoteFunction("EquipItem"):InvokeServer({ slot = slot, id = nil })
				end)
			end, { textSize = 12, color = UiKit.Colors.gold, textColor = UiKit.Colors.panel })
		else
			UiKit.button(row, "Equip", UDim2.fromOffset(80, 28), UDim2.new(1, -86, 0.5, -14), function()
				task.spawn(function()
					Net.remoteFunction("EquipItem"):InvokeServer({ slot = slot, id = itemId })
				end)
			end, { textSize = 12 })
		end
	end
end

function InventoryController.Init()
	window = UiKit.window("Inventory", "Inventory", UDim2.fromOffset(560, 480), 40)
	local body = window.body

	UiKit.label(body, "ORE POUCH", UDim2.fromOffset(200, 16), UDim2.fromOffset(0, 0), { textSize = 12, color = UiKit.Colors.gold, bold = true })
	oreList = (UiKit.scroll(body, UDim2.new(0.45, -6, 1, -20), UDim2.fromOffset(0, 18)))

	UiKit.label(body, "GEAR", UDim2.fromOffset(200, 16), UDim2.new(0.45, 6, 0, 0), { textSize = 12, color = UiKit.Colors.gold, bold = true })
	itemList = (UiKit.scroll(body, UDim2.new(0.55, -6, 1, -20), UDim2.new(0.45, 6, 0, 18)))

	render()
	ClientState.InventoryChanged:Connect(render)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.I then
			window.toggle()
		end
	end)
end

return InventoryController
