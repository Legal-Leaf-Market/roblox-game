--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > CraftingController
-- The Spirit Forge panel. Opens when the server says the player used the
-- forge prompt; lists every recipe with live affordability against the
-- inventory cache. Crafting itself is validated server-side (including
-- standing at the forge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Items = require(Shared:WaitForChild("Data"):WaitForChild("Items"))
local Ores = require(Shared:WaitForChild("Data"):WaitForChild("Ores"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)

local CraftingController = {}

local window: UiKit.Window
local recipeList: ScrollingFrame

local function clearList(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function render()
	clearList(recipeList)
	local inventory = ClientState.inventory
	local order = 0
	for _, itemId in Items.order do
		local item = Items.get(itemId)
		if item == nil or item.recipe == nil then
			continue
		end
		local recipe = item.recipe :: Items.Recipe
		order += 1

		local affordable = true
		local costLines: { string } = {}
		for oreId, needed in recipe.ores do
			local ore = Ores.get(oreId)
			local have = if inventory then inventory.ores[oreId] or 0 else 0
			if have < needed then
				affordable = false
			end
			table.insert(costLines, `{if ore then ore.name else oreId} {have}/{needed}`)
		end
		local stonesHave = if inventory then inventory.spiritStones else 0
		if stonesHave < recipe.spiritStones then
			affordable = false
		end
		table.insert(costLines, `stones {stonesHave}/{recipe.spiritStones}`)

		local row = UiKit.frame(recipeList, UDim2.new(1, -8, 0, 62), UDim2.fromOffset(0, 0), UiKit.Colors.panelLight)
		row.LayoutOrder = order
		local detail: string
		if item.kind == "weapon" then
			detail = `{item.category} · damage x{item.damageMult}`
		else
			detail = `robe · absorbs {math.floor(item.defense * 100)}%`
		end
		UiKit.label(row, item.name, UDim2.new(1, -100, 0, 18), UDim2.fromOffset(6, 3), {
			textSize = 13,
			bold = true,
			color = if affordable then UiKit.Colors.text else UiKit.Colors.textDim,
		})
		UiKit.label(row, detail, UDim2.new(1, -100, 0, 13), UDim2.fromOffset(6, 21), {
			textSize = 11,
			color = UiKit.Colors.textDim,
		})
		UiKit.label(row, table.concat(costLines, "  ·  "), UDim2.new(1, -100, 0, 13), UDim2.fromOffset(6, 37), {
			textSize = 10,
			color = if affordable then UiKit.Colors.health else UiKit.Colors.danger,
		})
		UiKit.button(row, "Forge", UDim2.fromOffset(84, 32), UDim2.new(1, -90, 0.5, -16), function()
			task.spawn(function()
				local result = Net.remoteFunction("CraftItem"):InvokeServer({ id = itemId })
				if typeof(result) == "table" and not result.ok and typeof(result.error) == "string" then
					-- Server refusals surface as toasts via Notify already
					-- for successes; show refusal inline here.
					render()
				end
			end)
		end, {
			textSize = 13,
			color = if affordable then UiKit.Colors.gold else UiKit.Colors.panel,
			textColor = if affordable then UiKit.Colors.panel else UiKit.Colors.textDim,
		})
	end
end

function CraftingController.Init()
	window = UiKit.window("Crafting", "The Spirit Forge", UDim2.fromOffset(520, 520), 45)
	recipeList = (UiKit.scroll(window.body, UDim2.new(1, 0, 1, 0), UDim2.fromOffset(0, 0)))

	Net.remoteEvent("OpenCrafting").OnClientEvent:Connect(function()
		render()
		window.setVisible(true)
	end)
	ClientState.InventoryChanged:Connect(function()
		if window.visible() then
			render()
		end
	end)
end

return CraftingController
