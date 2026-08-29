--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > InventoryController
-- The Bag: stackable items with equip/use, and technique manuals with
-- learn/give. Giving hands the book to a nearby cultivator, chosen from
-- whoever stands within reach.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Items = require(Shared:WaitForChild("Items"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)
local Panels = require(script.Parent.Parent.Modules.Panels)

local InventoryController = {}

local player = Players.LocalPlayer

local windowRoot: Frame
local listScroll: ScrollingFrame

local function invoke(remoteName: string, payload: { [string]: any })
	task.spawn(function()
		local result = Net.remoteFunction(remoteName):InvokeServer(payload)
		if typeof(result) == "table" and result.ok ~= true and typeof(result.error) == "string" then
			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "The bag disagrees",
					Text = result.error,
					Duration = 4,
				})
			end)
		end
	end)
end

local function nearbyPlayers(range: number): { Player }
	local found: { Player } = {}
	local model = player.Character
	local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return found
	end
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local otherRoot = if other.Character then other.Character:FindFirstChild("HumanoidRootPart") else nil
		if otherRoot and otherRoot:IsA("BasePart") and (otherRoot.Position - (root :: BasePart).Position).Magnitude <= range then
			table.insert(found, other)
		end
	end
	return found
end

local function card(orderIndex: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, height)
	frame.BackgroundColor3 = UiKit.Colors.paper
	frame.BorderSizePixel = 0
	frame.LayoutOrder = orderIndex
	frame.Parent = listScroll
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = UiKit.Colors.ink
	stroke.Thickness = 1.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	return frame
end

local function renderList()
	for _, child in listScroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local inventory = ClientState.inventory
	if inventory == nil then
		return
	end
	local order = 0

	UiKit.label(card(order, 20), `Spirit Stones: {inventory.spiritStones}`, UDim2.new(1, -12, 1, 0), UDim2.fromOffset(8, 0), {
		textSize = 12,
		bold = true,
		color = UiKit.Colors.qi,
	})

	for itemId, count in inventory.items :: { [string]: number } do
		order += 1
		local def = Items.get(itemId)
		local itemCard = card(order, 46)
		local displayName = if def then def.name else itemId
		local equipped = inventory.equippedWeapon == itemId
		UiKit.label(itemCard, `{displayName}  x{count}{if equipped then "   [wielded]" else ""}`, UDim2.new(1, -12, 0, 18), UDim2.fromOffset(8, 2), {
			textSize = 12,
			bold = true,
		})
		UiKit.label(itemCard, if def then def.blurb else "", UDim2.new(1, -140, 0, 22), UDim2.fromOffset(8, 20), {
			textSize = 9,
			color = UiKit.Colors.textDim,
			wrap = true,
		})
		if def and def.kind == "weapon" then
			UiKit.button(itemCard, if equipped then "Unequip" else "Wield", UDim2.fromOffset(60, 20), UDim2.new(1, -66, 0, 22), function()
				invoke("EquipItem", { id = itemId, action = if equipped then "unequip" else "equip" })
			end, { textSize = 10 })
		elseif def and def.kind == "pill" then
			UiKit.button(itemCard, "Swallow", UDim2.fromOffset(60, 20), UDim2.new(1, -66, 0, 22), function()
				invoke("EquipItem", { id = itemId, action = "use" })
			end, { textSize = 10, color = UiKit.Colors.gold })
		end
	end

	for bookId, manual in inventory.manuals :: { [string]: { [string]: any } } do
		order += 1
		local manualCard = card(order, 52)
		UiKit.label(manualCard, `Manual: "{manual.techniqueName}"`, UDim2.new(1, -12, 0, 18), UDim2.fromOffset(8, 2), {
			textSize = 12,
			bold = true,
			color = UiKit.Colors.gold,
		})
		UiKit.label(manualCard, "A technique, bound in silk and patience.", UDim2.new(1, -200, 0, 20), UDim2.fromOffset(8, 22), {
			textSize = 9,
			color = UiKit.Colors.textDim,
		})
		UiKit.button(manualCard, "Study", UDim2.fromOffset(52, 20), UDim2.new(1, -180, 0, 24), function()
			invoke("UseManual", { bookId = bookId })
		end, { textSize = 10 })
		UiKit.button(manualCard, "Give (nearby)", UDim2.fromOffset(110, 20), UDim2.new(1, -122, 0, 24), function()
			local candidates = nearbyPlayers(22)
			if #candidates == 0 then
				pcall(function()
					game:GetService("StarterGui"):SetCore("SendNotification", {
						Title = "No one near",
						Text = "Stand beside someone to hand them a manual.",
						Duration = 4,
					})
				end)
				return
			end
			invoke("GiveManual", { bookId = bookId, targetUserId = candidates[1].UserId })
		end, { textSize = 10, color = UiKit.Colors.paperDim, textColor = UiKit.Colors.text })
	end
end

function InventoryController.Init()
	local screen = UiKit.screen("BagWindow", 30)
	local body: Frame
	windowRoot, body = UiKit.window(screen, "The Bag", UDim2.fromOffset(380, 380), UDim2.new(0.5, -190, 0.5, -210))
	listScroll = UiKit.scroll(body, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0))

	Panels.register("bag", function()
		windowRoot.Visible = not windowRoot.Visible
		if windowRoot.Visible then
			renderList()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.I then
			Panels.toggle("bag")
		end
	end)

	ClientState.InventoryChanged:Connect(function()
		if windowRoot.Visible then
			renderList()
		end
	end)
end

return InventoryController
