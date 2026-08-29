--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > TechniqueController
-- Casting (keys 1-6, aimed at the mouse) and the Arts window: the list of
-- known techniques with equip/teach/manual/discard actions, and the
-- creation desk where components are chained into a new art. The window
-- previews with the SAME shared math the server enforces, so what it
-- promises is what the server delivers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Realms = require(Shared:WaitForChild("Realms"))
local TechniqueMath = require(Shared:WaitForChild("TechniqueMath"))
local TechniqueParts = require(Shared:WaitForChild("TechniqueParts"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)
local Panels = require(script.Parent.Parent.Modules.Panels)

local TechniqueController = {}

local player = Players.LocalPlayer
local castRemote = Net.remoteEvent("CastTechnique")

local SLOT_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

local localCooldowns: { [string]: number } = {}

local function cast(slot: number)
	local techniques = ClientState.techniques
	if techniques == nil then
		return
	end
	local techniqueId = (techniques.slots :: { [string]: string })[tostring(slot)]
	if techniqueId == nil then
		return
	end
	local design: { [string]: any }? = nil
	for _, candidate in techniques.techniques :: { { [string]: any } } do
		if candidate.id == techniqueId then
			design = candidate
			break
		end
	end
	if design == nil then
		return
	end
	local computed = (TechniqueMath.compute(design.category, design.components, 1))
	local now = os.clock()
	if computed then
		local readyAt = localCooldowns[techniqueId]
		if readyAt and now < readyAt then
			return
		end
		localCooldowns[techniqueId] = now + computed.cooldown
		ClientState.FireCooldown(slot, computed.cooldown)
	end
	local mouse = player:GetMouse()
	castRemote:FireServer(slot, mouse.Hit.Position)
end

-- ------------------------------ The window -------------------------------

local windowRoot: Frame
local listScroll: ScrollingFrame
local previewLabel: TextLabel
local chainLabel: TextLabel
local nameBox: TextBox
local intensity = 3
local intensityLabel: TextLabel
local currentCategory = "sword"
local chain: { string } = {}
local categoryButtons: { [string]: TextButton } = {}
local partButtonsFrame: ScrollingFrame

local function refreshPreview()
	chainLabel.Text = if #chain == 0 then "Chain: (choose components)" else "Chain: " .. table.concat(
		(function()
			local names = {}
			for _, id in chain do
				local part = TechniqueParts.get(id)
				table.insert(names, if part then part.name else id)
			end
			return names
		end)(),
		"  >  "
	)
	local computed, reason = TechniqueMath.compute(currentCategory, chain, intensity)
	if computed == nil then
		previewLabel.Text = reason or ""
		return
	end
	previewLabel.Text = `{computed.rank}   power {computed.power}   damage ~{computed.damage}   qi {computed.qiCost}   cooldown {string.format("%.1f", computed.cooldown)}s\nRequires {Realms.displayName(computed.requiredStage)}`
end

local function rebuildPartButtons()
	for _, child in partButtonsFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local order = 0
	for _, part in TechniqueParts.LIST do
		if not TechniqueParts.allowedIn(part.id, currentCategory) then
			continue
		end
		order += 1
		local button = UiKit.button(partButtonsFrame, `{part.name}  ({part.kind})`, UDim2.new(1, -8, 0, 24), UDim2.fromOffset(0, 0), function()
			if table.find(chain, part.id) then
				local index = table.find(chain, part.id)
				if index then
					table.remove(chain, index)
				end
			elseif #chain < Config.MAX_COMPONENTS then
				table.insert(chain, part.id)
			end
			refreshPreview()
		end, { textSize = 11, color = UiKit.Colors.paperDim, textColor = UiKit.Colors.text })
		button.LayoutOrder = order
	end
end

local function setCategory(category: string)
	currentCategory = category
	table.clear(chain)
	for id, button in categoryButtons do
		button.BackgroundColor3 = if id == category then UiKit.Colors.ink else UiKit.Colors.paperDim
		button.TextColor3 = if id == category then UiKit.Colors.paper else UiKit.Colors.text
	end
	rebuildPartButtons()
	refreshPreview()
end

-- Invoke a RemoteFunction and surface a denial as a platform notification
-- (server-approved actions already toast through the Notify channel).
local function invoke(remoteName: string, payload: { [string]: any })
	task.spawn(function()
		local result = Net.remoteFunction(remoteName):InvokeServer(payload)
		if typeof(result) == "table" and result.ok ~= true and typeof(result.error) == "string" then
			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "The dao refuses",
					Text = result.error,
					Duration = 4,
				})
			end)
		end
	end)
end

local function renderList()
	for _, child in listScroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local techniques = ClientState.techniques
	if techniques == nil then
		return
	end
	local order = 0
	for _, design in techniques.techniques :: { { [string]: any } } do
		order += 1
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -8, 0, 66)
		card.BackgroundColor3 = UiKit.Colors.paper
		card.BorderSizePixel = 0
		card.LayoutOrder = order
		card.Parent = listScroll
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = UiKit.Colors.ink
		stroke.Thickness = 1.2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = card

		local mastery = TechniqueMath.masteryPercent(tonumber(design.masteryXp) or 0, tonumber(design.power) or 1)
		local inheritedTag = if design.inherited then "  (inherited)" else ""
		UiKit.label(card, `{design.name}{inheritedTag}`, UDim2.new(1, -12, 0, 18), UDim2.fromOffset(8, 2), {
			textSize = 13,
			bold = true,
		})
		UiKit.label(card, `{TechniqueMath.rankName(tonumber(design.power) or 0)}   power {design.power}   mastery {mastery}%{if design.origin then `   from {design.origin}` else ""}`,
			UDim2.new(1, -12, 0, 13), UDim2.fromOffset(8, 20), {
				textSize = 10,
				color = UiKit.Colors.textDim,
			})

		-- Slot buttons 1-6.
		for slot = 1, Config.SLOT_COUNT do
			UiKit.button(card, tostring(slot), UDim2.fromOffset(20, 18), UDim2.fromOffset(8 + (slot - 1) * 24, 40), function()
				invoke("EquipTechnique", { slot = slot, id = design.id })
			end, { textSize = 10, color = UiKit.Colors.paperDim, textColor = UiKit.Colors.text })
		end
		if mastery >= 100 then
			UiKit.button(card, "Manual", UDim2.fromOffset(52, 18), UDim2.new(1, -170, 0, 40), function()
				invoke("WriteManual", { id = design.id })
			end, { textSize = 10, color = UiKit.Colors.gold })
			UiKit.button(card, "Teach", UDim2.fromOffset(48, 18), UDim2.new(1, -114, 0, 40), function()
				-- Teach the first disciple stood nearby; the Dao panel
				-- explains the ritual.
				local social = ClientState.social
				local disciples = if social then social.disciples :: { { userId: number, name: string } } else nil
				if disciples and #disciples > 0 then
					invoke("TeachTechnique", { id = design.id, targetUserId = disciples[1].userId })
				else
					warn("[Arts] You have no disciples to teach.")
				end
			end, { textSize = 10 })
		end
		UiKit.button(card, "Discard", UDim2.fromOffset(56, 18), UDim2.new(1, -62, 0, 40), function()
			invoke("DeleteTechnique", { id = design.id })
		end, { textSize = 10, color = UiKit.Colors.danger })
	end
end

local function buildWindow(screen: ScreenGui)
	local body: Frame
	windowRoot, body = UiKit.window(screen, "The Hundred Arts", UDim2.fromOffset(560, 420), UDim2.new(0.5, -280, 0.5, -230))

	-- Left: known techniques.
	UiKit.label(body, "KNOWN ARTS", UDim2.fromOffset(200, 14), UDim2.fromOffset(2, 0), { textSize = 10, bold = true, color = UiKit.Colors.textDim })
	listScroll = UiKit.scroll(body, UDim2.new(0.5, -8, 1, -18), UDim2.fromOffset(0, 18))

	-- Right: the creation desk.
	local desk = Instance.new("Frame")
	desk.Size = UDim2.new(0.5, -4, 1, -18)
	desk.Position = UDim2.new(0.5, 8, 0, 18)
	desk.BackgroundTransparency = 1
	desk.Parent = body

	UiKit.label(desk, "CREATE A NEW ART", UDim2.fromOffset(220, 14), UDim2.fromOffset(2, 0), { textSize = 10, bold = true, color = UiKit.Colors.textDim })
	for index, category in TechniqueParts.CATEGORIES do
		local button = UiKit.button(desk, category:upper(), UDim2.fromOffset(62, 20), UDim2.fromOffset((index - 1) * 66, 18), function()
			setCategory(category)
		end, { textSize = 10, color = UiKit.Colors.paperDim, textColor = UiKit.Colors.text })
		categoryButtons[category] = button
	end

	partButtonsFrame = UiKit.scroll(desk, UDim2.new(1, 0, 0, 150), UDim2.fromOffset(0, 44))
	chainLabel = UiKit.label(desk, "Chain:", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(2, 198), { textSize = 10, wrap = true })
	previewLabel = UiKit.label(desk, "", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(2, 226), { textSize = 10, color = UiKit.Colors.textDim, wrap = true })

	UiKit.label(desk, "Intensity", UDim2.fromOffset(60, 20), UDim2.fromOffset(2, 264), { textSize = 11 })
	UiKit.button(desk, "-", UDim2.fromOffset(22, 20), UDim2.fromOffset(64, 264), function()
		intensity = math.max(1, intensity - 1)
		intensityLabel.Text = tostring(intensity)
		refreshPreview()
	end, { textSize = 12 })
	intensityLabel = UiKit.label(desk, "3", UDim2.fromOffset(24, 20), UDim2.fromOffset(90, 264), { textSize = 12, bold = true, xalign = Enum.TextXAlignment.Center })
	UiKit.button(desk, "+", UDim2.fromOffset(22, 20), UDim2.fromOffset(116, 264), function()
		intensity = math.min(10, intensity + 1)
		intensityLabel.Text = tostring(intensity)
		refreshPreview()
	end, { textSize = 12 })
	UiKit.button(desk, "Clear chain", UDim2.fromOffset(80, 20), UDim2.new(1, -84, 0, 264), function()
		table.clear(chain)
		refreshPreview()
	end, { textSize = 10, color = UiKit.Colors.paperDim, textColor = UiKit.Colors.text })

	nameBox = UiKit.textBox(desk, "Name your art...", UDim2.new(1, -96, 0, 24), UDim2.fromOffset(0, 292))
	UiKit.button(desk, "CREATE", UDim2.fromOffset(88, 24), UDim2.new(1, -90, 0, 292), function()
		invoke("CreateTechnique", {
			category = currentCategory,
			components = table.clone(chain),
			intensity = intensity,
			name = nameBox.Text,
		})
	end, { textSize = 11 })

	setCategory("sword")
end

function TechniqueController.Init()
	local screen = UiKit.screen("ArtsWindow", 30)
	buildWindow(screen)

	Panels.register("arts", function()
		windowRoot.Visible = not windowRoot.Visible
		if windowRoot.Visible then
			renderList()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local slot = SLOT_KEYS[input.KeyCode]
		if slot then
			cast(slot)
		elseif input.KeyCode == Enum.KeyCode.T then
			Panels.toggle("arts")
		end
	end)

	ClientState.TechniquesChanged:Connect(function()
		if windowRoot.Visible then
			renderList()
		end
	end)
end

return TechniqueController
