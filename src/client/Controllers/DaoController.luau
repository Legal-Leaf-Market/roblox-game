--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > DaoController
-- The Dao panel: your master, your disciples, offering discipleship to
-- another cultivator by name, and cutting the bond. Sects join this
-- window in their own phase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)
local Panels = require(script.Parent.Parent.Modules.Panels)

local DaoController = {}

local windowRoot: Frame
local masterLabel: TextLabel
local disciplesLabel: TextLabel
local offerBox: TextBox

local function invoke(remoteName: string, payload: { [string]: any })
	task.spawn(function()
		local result = Net.remoteFunction(remoteName):InvokeServer(payload)
		if typeof(result) == "table" and result.ok ~= true and typeof(result.error) == "string" then
			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "The bond refuses",
					Text = result.error,
					Duration = 4,
				})
			end)
		end
	end)
end

local function renderSocial()
	local social = ClientState.social
	if social == nil then
		masterLabel.Text = "Master: none. You walk alone."
		disciplesLabel.Text = "Disciples: none yet."
		return
	end
	masterLabel.Text = if typeof(social.masterName) == "string"
		then `Master: {social.masterName}`
		else "Master: none. You walk alone."
	local disciples = social.disciples :: { { userId: number, name: string } }?
	if disciples and #disciples > 0 then
		local names = {}
		for _, disciple in disciples do
			table.insert(names, disciple.name)
		end
		disciplesLabel.Text = `Disciples ({#disciples}): {table.concat(names, ", ")}`
	else
		disciplesLabel.Text = "Disciples: none yet."
	end
end

function DaoController.Init()
	local screen = UiKit.screen("DaoWindow", 30)
	local body: Frame
	windowRoot, body = UiKit.window(screen, "The Dao of Others", UDim2.fromOffset(360, 250), UDim2.new(0.5, -180, 0.5, -160))

	masterLabel = UiKit.label(body, "", UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 4), { textSize = 13, bold = true })
	disciplesLabel = UiKit.label(body, "", UDim2.new(1, -8, 0, 36), UDim2.fromOffset(4, 26), { textSize = 11, wrap = true })

	UiKit.label(body, "Take a disciple (they must accept):", UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 72), {
		textSize = 11,
		color = UiKit.Colors.textDim,
	})
	offerBox = UiKit.textBox(body, "Their exact username...", UDim2.new(1, -110, 0, 24), UDim2.fromOffset(4, 90))
	UiKit.button(body, "Offer", UDim2.fromOffset(96, 24), UDim2.new(1, -100, 0, 90), function()
		if #offerBox.Text > 0 then
			invoke("OfferDiscipleship", { targetName = offerBox.Text })
		end
	end, { textSize = 11 })

	UiKit.label(body, "Mastered arts are taught from the Arts window.\nA manual can carry an art to anyone; transmission is disciples only.",
		UDim2.new(1, -8, 0, 34), UDim2.fromOffset(4, 122), {
			textSize = 10,
			color = UiKit.Colors.textDim,
			wrap = true,
		})

	UiKit.button(body, "Renounce my master", UDim2.fromOffset(150, 24), UDim2.new(0.5, -75, 1, -30), function()
		invoke("RenounceMaster", {})
	end, { textSize = 11, color = UiKit.Colors.danger })

	Panels.register("dao", function()
		windowRoot.Visible = not windowRoot.Visible
		if windowRoot.Visible then
			renderSocial()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.N then
			Panels.toggle("dao")
		end
	end)

	ClientState.SocialChanged:Connect(function()
		if windowRoot.Visible then
			renderSocial()
		end
	end)
end

return DaoController
