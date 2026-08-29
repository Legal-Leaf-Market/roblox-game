--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > DialogueController
-- Grandmaster Khadun's dialogue box: mission pitch, requirements, and the
-- Accept / Turn In buttons. Driven entirely by DwarfDialogue payloads from
-- the server; the buttons call MissionAction and the server re-sends the
-- updated dialogue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Ores = require(Shared:WaitForChild("Data"):WaitForChild("Ores"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)

local DialogueController = {}

local window: UiKit.Window
local nameLabel: TextLabel
local titleLabel: TextLabel
local textLabel: TextLabel
local needsLabel: TextLabel
local rewardLabel: TextLabel
local acceptButton: TextButton
local turnInButton: TextButton

local function onDialogue(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local dialogue = payload :: { [string]: any }
	nameLabel.Text = tostring(dialogue.npcName)
	titleLabel.Text = `Commission {dialogue.missionNumber}: {dialogue.missionTitle}`
	textLabel.Text = tostring(dialogue.text)

	local needs = dialogue.needs
	local needsLines: { string } = {}
	if typeof(needs) == "table" then
		for oreId, count in needs :: { [string]: number } do
			local ore = Ores.get(oreId)
			table.insert(needsLines, `{count}x {if ore then ore.name else oreId}`)
		end
	end
	needsLabel.Text = "Needs: " .. table.concat(needsLines, ", ")

	local rewards = { `{dialogue.rewardStones} spirit stones` }
	if tonumber(dialogue.rewardRaceSpins) and dialogue.rewardRaceSpins > 0 then
		table.insert(rewards, `{dialogue.rewardRaceSpins} race spins`)
	end
	if tonumber(dialogue.rewardTalentSpins) and dialogue.rewardTalentSpins > 0 then
		table.insert(rewards, `{dialogue.rewardTalentSpins} talent spins`)
	end
	rewardLabel.Text = "Pays: " .. table.concat(rewards, ", ")

	acceptButton.Visible = dialogue.canAccept == true
	turnInButton.Visible = dialogue.canTurnIn == true
	window.setVisible(true)
end

function DialogueController.Init()
	window = UiKit.window("Dialogue", "The Deepforge", UDim2.fromOffset(480, 300), 50)
	local body = window.body

	nameLabel = UiKit.label(body, "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 0), {
		textSize = 18,
		color = UiKit.Colors.gold,
		title = true,
	})
	titleLabel = UiKit.label(body, "", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 24), {
		textSize = 13,
		bold = true,
	})
	textLabel = UiKit.label(body, "", UDim2.new(1, 0, 0, 96), UDim2.fromOffset(0, 46), {
		textSize = 14,
		wrap = true,
	})
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	needsLabel = UiKit.label(body, "", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 148), {
		textSize = 12,
		color = UiKit.Colors.qi,
	})
	rewardLabel = UiKit.label(body, "", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 166), {
		textSize = 12,
		color = UiKit.Colors.xp,
	})

	acceptButton = UiKit.button(body, "Accept Commission", UDim2.new(0.5, -6, 0, 38), UDim2.new(0, 0, 1, -42), function()
		task.spawn(function()
			Net.remoteFunction("MissionAction"):InvokeServer({ action = "accept" })
		end)
	end, { color = UiKit.Colors.gold, textColor = UiKit.Colors.ink })

	turnInButton = UiKit.button(body, "Turn In Ore", UDim2.new(0.5, -6, 0, 38), UDim2.new(0.5, 6, 1, -42), function()
		task.spawn(function()
			Net.remoteFunction("MissionAction"):InvokeServer({ action = "turnin" })
		end)
	end, { color = UiKit.Colors.health, textColor = UiKit.Colors.ink })

	Net.remoteEvent("DwarfDialogue").OnClientEvent:Connect(onDialogue)
end

return DialogueController
