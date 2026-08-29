--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > DestinyController
-- Destiny (key R): race and talent spins, the reveal, and the collection.
-- 124 races and the talent pool live in shared data; this panel is just an
-- honest window onto what the server rolled for you.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Races = require(Shared:WaitForChild("Data"):WaitForChild("Races"))
local Talents = require(Shared:WaitForChild("Data"):WaitForChild("Talents"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)

local DestinyController = {}

local window: UiKit.Window
local raceSpinButton: TextButton
local talentSpinButton: TextButton
local revealLabel: TextLabel
local raceList: ScrollingFrame
local talentList: ScrollingFrame
local spinning = false

local function clearList(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function renderSpinButtons()
	local destiny = ClientState.destiny
	local raceSpins = if destiny then destiny.raceSpins else 0
	local talentSpins = if destiny then destiny.talentSpins else 0
	raceSpinButton.Text = if raceSpins > 0
		then `SPIN RACE  ({raceSpins} free)`
		else `SPIN RACE  ({Config.RACE_SPIN_STONES} stones)`
	talentSpinButton.Text = if talentSpins > 0
		then `SPIN TALENT  ({talentSpins} free)`
		else `SPIN TALENT  ({Config.TALENT_SPIN_STONES} stones)`
end

local function renderRaces()
	clearList(raceList)
	local destiny = ClientState.destiny
	if destiny == nil then
		return
	end
	local index = 0
	for _, raceId in Races.order do
		local owned = destiny.ownedRaces[raceId]
		if owned == nil then
			continue
		end
		local race = Races.get(raceId)
		if race == nil then
			continue
		end
		index += 1
		local equipped = destiny.race == raceId
		local row = UiKit.frame(raceList, UDim2.new(1, -8, 0, 46), UDim2.fromOffset(0, 0), UiKit.Colors.panelLight)
		row.LayoutOrder = index
		UiKit.label(row, `{race.name} {race.hanzi}`, UDim2.new(1, -90, 0, 18), UDim2.fromOffset(6, 3), {
			textSize = 13,
			color = UiKit.rarityColor(race.rarity),
			bold = true,
		})
		UiKit.label(row, `{race.rarity} · {race.archetype}{if race.affinity then ` · affinity: {race.affinity}` else ""}`, UDim2.new(1, -90, 0, 14), UDim2.fromOffset(6, 24), {
			textSize = 11,
			color = UiKit.Colors.textDim,
		})
		if equipped then
			UiKit.label(row, "EQUIPPED", UDim2.fromOffset(76, 20), UDim2.new(1, -82, 0.5, -10), {
				textSize = 11,
				color = UiKit.Colors.gold,
				bold = true,
				xalign = Enum.TextXAlignment.Center,
			})
		else
			UiKit.button(row, "Equip", UDim2.fromOffset(76, 26), UDim2.new(1, -82, 0.5, -13), function()
				task.spawn(function()
					Net.remoteFunction("EquipRace"):InvokeServer({ id = raceId })
				end)
			end, { textSize = 12 })
		end
	end
	UiKit.label(raceList, `{index} / {#Races.order} bloodlines awakened`, UDim2.new(1, -8, 0, 20), UDim2.fromOffset(0, 0), {
		textSize = 11,
		color = UiKit.Colors.textDim,
		xalign = Enum.TextXAlignment.Center,
	}).LayoutOrder = 10000
end

local function renderTalents()
	clearList(talentList)
	local destiny = ClientState.destiny
	if destiny == nil then
		return
	end
	local equippedSet: { [string]: boolean } = {}
	for _, id in destiny.equippedTalents do
		equippedSet[id] = true
	end
	local index = 0
	for _, talentId in Talents.order do
		if destiny.ownedTalents[talentId] == nil then
			continue
		end
		local talent = Talents.get(talentId)
		if talent == nil then
			continue
		end
		index += 1
		local equipped = equippedSet[talentId] == true
		local row = UiKit.frame(talentList, UDim2.new(1, -8, 0, 46), UDim2.fromOffset(0, 0), UiKit.Colors.panelLight)
		row.LayoutOrder = index
		UiKit.label(row, talent.name, UDim2.new(1, -90, 0, 18), UDim2.fromOffset(6, 3), {
			textSize = 13,
			color = UiKit.rarityColor(talent.rarity),
			bold = true,
		})
		UiKit.label(row, talent.blurb, UDim2.new(1, -90, 0, 14), UDim2.fromOffset(6, 24), {
			textSize = 10,
			color = UiKit.Colors.textDim,
		})
		UiKit.button(row, if equipped then "Unequip" else "Equip", UDim2.fromOffset(76, 26), UDim2.new(1, -82, 0.5, -13), function()
			local newList: { string } = {}
			for _, id in destiny.equippedTalents do
				if id ~= talentId then
					table.insert(newList, id)
				end
			end
			if not equipped then
				if #newList >= Config.TALENT_SLOTS then
					return
				end
				table.insert(newList, talentId)
			end
			task.spawn(function()
				Net.remoteFunction("EquipTalent"):InvokeServer({ ids = newList })
			end)
		end, { textSize = 12, color = if equipped then UiKit.Colors.gold else UiKit.Colors.panelLight, textColor = if equipped then UiKit.Colors.panel else UiKit.Colors.text })
	end
end

local function spin(kind: "race" | "talent")
	if spinning then
		return
	end
	spinning = true
	revealLabel.Text = "The heavens turn..."
	revealLabel.TextColor3 = UiKit.Colors.textDim
	task.spawn(function()
		local remoteName = if kind == "race" then "SpinRace" else "SpinTalent"
		local result = Net.remoteFunction(remoteName):InvokeServer()
		task.wait(0.6) -- let the drum roll breathe
		if typeof(result) == "table" and result.ok then
			local id = tostring(result.id)
			local rarity = tostring(result.rarity)
			local displayName = id
			local blurb = ""
			if kind == "race" then
				local race = Races.get(id)
				if race then
					displayName = `{race.name} {race.hanzi}`
					blurb = race.blurb
				end
			else
				local talent = Talents.get(id)
				if talent then
					displayName = talent.name
					blurb = talent.blurb
				end
			end
			local suffix = if result.duplicate then `  (duplicate: +{result.refund} stones)` else ""
			revealLabel.Text = `{rarity:upper()}  ·  {displayName}{suffix}\n{blurb}`
			revealLabel.TextColor3 = UiKit.rarityColor(rarity)
		elseif typeof(result) == "table" and typeof(result.error) == "string" then
			revealLabel.Text = result.error
			revealLabel.TextColor3 = UiKit.Colors.danger
		end
		spinning = false
	end)
end

function DestinyController.Init()
	window = UiKit.window("Destiny", "Destiny: Bloodlines & Talents", UDim2.fromOffset(780, 560), 40)
	local body = window.body

	raceSpinButton = UiKit.button(body, "SPIN RACE", UDim2.fromOffset(370, 44), UDim2.fromOffset(0, 0), function()
		spin("race")
	end, { color = UiKit.Colors.gold, textColor = UiKit.Colors.panel, textSize = 16 })
	talentSpinButton = UiKit.button(body, "SPIN TALENT", UDim2.fromOffset(370, 44), UDim2.new(1, -370, 0, 0), function()
		spin("talent")
	end, { color = UiKit.Colors.panelLight, textSize = 16 })

	local revealFrame = UiKit.frame(body, UDim2.new(1, 0, 0, 66), UDim2.fromOffset(0, 52), UiKit.Colors.inset)
	revealLabel = UiKit.label(revealFrame, "Spin to awaken a bloodline of the old myths, or a talent of the flesh.", UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4), {
		textSize = 15,
		xalign = Enum.TextXAlignment.Center,
		wrap = true,
		title = true,
	})

	UiKit.label(body, "BLOODLINES", UDim2.fromOffset(300, 16), UDim2.fromOffset(0, 126), { textSize = 12, color = UiKit.Colors.gold, bold = true })
	raceList = (UiKit.scroll(body, UDim2.new(0.5, -6, 1, -146), UDim2.fromOffset(0, 144)))

	UiKit.label(body, `TALENTS (equip up to {Config.TALENT_SLOTS})`, UDim2.fromOffset(300, 16), UDim2.new(0.5, 6, 0, 126), { textSize = 12, color = UiKit.Colors.gold, bold = true })
	talentList = (UiKit.scroll(body, UDim2.new(0.5, -6, 1, -146), UDim2.new(0.5, 6, 0, 144)))

	renderSpinButtons()
	renderRaces()
	renderTalents()

	ClientState.DestinyChanged:Connect(function()
		renderSpinButtons()
		renderRaces()
		renderTalents()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			window.toggle()
		end
	end)
end

return DestinyController
