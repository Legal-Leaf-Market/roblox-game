--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > TechniqueForgeController
-- The Technique Forge (key T): where a player designs their own arts.
-- Pick a category, a form, an element, pour in power, name it, create.
-- The preview runs the same TechniqueMath the server enforces, so what
-- you read is what you get.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local StatCalc = require(Shared:WaitForChild("StatCalc"))
local TechniqueMath = require(Shared:WaitForChild("TechniqueMath"))
local Forms = require(Shared:WaitForChild("Data"):WaitForChild("TechniqueForms"))
local Elements = require(Shared:WaitForChild("Data"):WaitForChild("Elements"))
local Realms = require(Shared:WaitForChild("Data"):WaitForChild("Realms"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)

local TechniqueForgeController = {}

local window: UiKit.Window
local formList: ScrollingFrame
local elementList: ScrollingFrame
local myList: ScrollingFrame
local previewLabel: TextLabel
local powerLabel: TextLabel
local nameBox: TextBox

local selCategory = "sword"
local selForm: string? = "flowing_slash"
local selElement = "none"
local power = 0

local CATEGORIES = { "movement", "sword", "blade", "bow" }

local function clearList(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function renderPreview()
	if selForm == nil then
		previewLabel.Text = "Pick a form."
		return
	end
	local stats = (TechniqueMath.compute(selForm :: string, selElement, power))
	if stats == nil then
		previewLabel.Text = "Invalid design."
		return
	end
	local form = Forms.get(selForm :: string)
	local lines = {}
	if form and form.baseDamage > 0 then
		table.insert(lines, `Damage: {stats.damage}`)
	end
	table.insert(lines, `Qi cost: {stats.qiCost}`)
	table.insert(lines, `Cooldown: {stats.cooldown}s`)
	if stats.range > 0 then
		table.insert(lines, `Range: {stats.range}`)
	end
	if stats.radius > 0 then
		table.insert(lines, `Radius: {stats.radius}`)
	end
	if stats.duration > 0 then
		table.insert(lines, `Duration: {stats.duration}s`)
	end
	local realm = Realms[stats.requiredRealm]
	table.insert(lines, `Needs realm: {if realm then realm.name else "?"}`)
	table.insert(lines, `Design cost: {stats.createCost} spirit stones`)

	local stat = ClientState.stats
	if stat and stat.realm < stats.requiredRealm then
		table.insert(lines, "YOUR REALM IS TOO SHALLOW")
	end
	previewLabel.Text = table.concat(lines, "\n")
end

local function renderForms()
	clearList(formList)
	for _, formId in Forms.order do
		local form = Forms.get(formId)
		if form == nil or form.category ~= selCategory then
			continue
		end
		local selected = selForm == formId
		local button = UiKit.button(formList, form.name, UDim2.new(1, -8, 0, 30), UDim2.fromOffset(0, 0), function()
			selForm = formId
			renderForms()
			renderPreview()
		end, { color = if selected then UiKit.Colors.gold else UiKit.Colors.panelLight, textColor = if selected then UiKit.Colors.ink else UiKit.Colors.text })
		button.LayoutOrder = 1
	end
end

local function renderElements()
	clearList(elementList)
	local stats = ClientState.stats
	local path = if stats then stats.path else nil
	local race = if stats then stats.race else "fanren"
	for _, elementId in Elements.order do
		local element = Elements.get(elementId)
		if element == nil then
			continue
		end
		local allowed = StatCalc.elementAllowed(element.path, path, race, elementId)
		local selected = selElement == elementId
		local text = element.name .. (if allowed then "" else " (locked)")
		local button = UiKit.button(elementList, text, UDim2.new(1, -8, 0, 26), UDim2.fromOffset(0, 0), function()
			if allowed then
				selElement = elementId
				renderElements()
				renderPreview()
			end
		end, {
			color = if selected then UiKit.Colors.gold else UiKit.Colors.panelLight,
			textColor = if not allowed then UiKit.Colors.textDim elseif selected then UiKit.Colors.ink else element.color,
			textSize = 13,
		})
		button.LayoutOrder = 1
	end
end

local function renderMine()
	clearList(myList)
	local techniques = ClientState.techniques
	if techniques == nil then
		return
	end
	-- Which technique sits in which slot, for display.
	local slotOf: { [string]: number } = {}
	for slotKey, techniqueId in techniques.slots do
		slotOf[techniqueId] = tonumber(slotKey) or 0
	end
	for index, technique in techniques.techniques do
		local element = Elements.get(technique.element)
		local row = UiKit.frame(myList, UDim2.new(1, -8, 0, 54), UDim2.fromOffset(0, 0), UiKit.Colors.panelLight)
		row.LayoutOrder = index
		local slotText = if slotOf[technique.id] then ` [{slotOf[technique.id]}]` else ""
		UiKit.label(row, technique.name .. slotText, UDim2.new(1, -34, 0, 18), UDim2.fromOffset(6, 3), {
			textSize = 13,
			color = if element then element.color else UiKit.Colors.text,
			bold = true,
		})
		local form = Forms.get(technique.form)
		UiKit.label(row, `{if form then form.name else technique.form} · {if element then element.name else "?"} · power {technique.power}`, UDim2.new(1, -34, 0, 14), UDim2.fromOffset(6, 20), {
			textSize = 11,
			color = UiKit.Colors.textDim,
		})
		for slot = 1, Config.SLOT_COUNT do
			UiKit.button(row, tostring(slot), UDim2.fromOffset(20, 16), UDim2.fromOffset(6 + (slot - 1) * 23, 35), function()
				task.spawn(function()
					Net.remoteFunction("EquipTechnique"):InvokeServer({ slot = slot, id = technique.id })
				end)
			end, { textSize = 11 })
		end
		UiKit.button(row, "X", UDim2.fromOffset(24, 24), UDim2.new(1, -30, 0, 4), function()
			task.spawn(function()
				Net.remoteFunction("DeleteTechnique"):InvokeServer({ id = technique.id })
			end)
		end, { color = UiKit.Colors.danger, textSize = 12 })
	end
end

function TechniqueForgeController.Init()
	window = UiKit.window("TechniqueForge", "Technique Forge", UDim2.fromOffset(760, 540), 40)
	local body = window.body

	-- Column 1: category + forms
	UiKit.label(body, "FORM", UDim2.fromOffset(200, 16), UDim2.fromOffset(0, 0), { textSize = 12, color = UiKit.Colors.gold, bold = true })
	for index, category in CATEGORIES do
		UiKit.button(body, category:upper(), UDim2.fromOffset(102, 26), UDim2.fromOffset(((index - 1) % 2) * 106, 20 + math.floor((index - 1) / 2) * 30), function()
			selCategory = category
			selForm = nil
			renderForms()
			renderPreview()
		end, { textSize = 12 })
	end
	formList = (UiKit.scroll(body, UDim2.fromOffset(212, 380), UDim2.fromOffset(0, 86)))

	-- Column 2: element, power, name, preview, create
	UiKit.label(body, "ELEMENT", UDim2.fromOffset(200, 16), UDim2.fromOffset(224, 0), { textSize = 12, color = UiKit.Colors.gold, bold = true })
	elementList = (UiKit.scroll(body, UDim2.fromOffset(230, 250), UDim2.fromOffset(224, 20)))

	UiKit.label(body, "POWER", UDim2.fromOffset(100, 16), UDim2.fromOffset(224, 280), { textSize = 12, color = UiKit.Colors.gold, bold = true })
	powerLabel = UiKit.label(body, "0", UDim2.fromOffset(40, 28), UDim2.fromOffset(302, 298), { textSize = 18, bold = true, xalign = Enum.TextXAlignment.Center })
	UiKit.button(body, "-", UDim2.fromOffset(32, 28), UDim2.fromOffset(224, 298), function()
		power = math.max(0, power - 1)
		powerLabel.Text = tostring(power)
		renderPreview()
	end)
	UiKit.button(body, "+", UDim2.fromOffset(32, 28), UDim2.fromOffset(260, 298), function()
		power = math.min(Config.MAX_POWER, power + 1)
		powerLabel.Text = tostring(power)
		renderPreview()
	end)

	nameBox = UiKit.textBox(body, "Name your technique...", UDim2.fromOffset(230, 30), UDim2.fromOffset(224, 334))

	UiKit.button(body, "CREATE TECHNIQUE", UDim2.fromOffset(230, 38), UDim2.fromOffset(224, 372), function()
		local form = selForm
		if form == nil then
			return
		end
		local name = nameBox.Text
		if #name == 0 then
			name = "Nameless Art"
		end
		task.spawn(function()
			local result = Net.remoteFunction("CreateTechnique"):InvokeServer({
				form = form,
				element = selElement,
				power = power,
				name = name,
			})
			if typeof(result) == "table" and result.ok then
				nameBox.Text = ""
			end
		end)
	end, { color = UiKit.Colors.gold, textColor = UiKit.Colors.ink, textSize = 15 })

	previewLabel = UiKit.label(body, "", UDim2.fromOffset(230, 120), UDim2.fromOffset(224, 416), {
		textSize = 12,
		color = UiKit.Colors.textDim,
		wrap = true,
	})
	previewLabel.TextYAlignment = Enum.TextYAlignment.Top

	-- Column 3: my techniques
	UiKit.label(body, `MY TECHNIQUES (max {Config.MAX_TECHNIQUES})`, UDim2.fromOffset(260, 16), UDim2.fromOffset(468, 0), { textSize = 12, color = UiKit.Colors.gold, bold = true })
	myList = (UiKit.scroll(body, UDim2.fromOffset(268, 446), UDim2.fromOffset(468, 20)))

	renderForms()
	renderElements()
	renderPreview()
	renderMine()

	ClientState.TechniquesChanged:Connect(renderMine)
	ClientState.StatsChanged:Connect(function()
		renderElements()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.T then
			window.toggle()
		end
	end)
end

return TechniqueForgeController
