--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > SectController
-- The Sect & Lineage panel (key N): found or join a sect, manage ranks
-- (Sect Leader / Vice Sect Leader / Elder / Inner Disciple / Outer
-- Disciple), take disciples, and watch your dao fortune grow as they break
-- through. Discipleship offers pop a banner even when the panel is closed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)
local Panels = require(script.Parent.Parent.Modules.Panels)

local SectController = {}

local window: UiKit.Window
local sectArea: Frame
local lineageArea: Frame
local offerGui: ScreenGui

local RANK_STEPS = { "outer", "inner", "elder", "vice" } -- leader via Crown

local function clear(area: Frame)
	for _, child in area:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function invoke(remoteName: string, payload: any)
	task.spawn(function()
		local result = Net.remoteFunction(remoteName):InvokeServer(payload)
		-- Refusals surface inline; successes push fresh state on their own.
		if typeof(result) == "table" and result.ok ~= true and typeof(result.error) == "string" then
			local social = ClientState.social
			local _ = social
			-- Show the reason where the player is looking.
			local note = window.root:FindFirstChild("SectError")
			if note and note:IsA("TextLabel") then
				note.Text = result.error
			end
		end
	end)
end

local function stepOf(rank: string): number
	for index, step in RANK_STEPS do
		if step == rank then
			return index
		end
	end
	return if rank == "leader" then #RANK_STEPS + 1 else 0
end

local function renderSect()
	clear(sectArea)
	local social = ClientState.social
	local sect = if social then social.sect else nil

	if sect == nil then
		UiKit.label(sectArea, "You belong to no sect.", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 0), { textSize = 13, bold = true })

		UiKit.label(sectArea, `FOUND A SECT ({Config.SECT_CREATE_COST} spirit stones)`, UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 30), { textSize = 11, bold = true })
		local nameBox = UiKit.textBox(sectArea, "Sect name...", UDim2.new(1, -100, 0, 30), UDim2.fromOffset(0, 48))
		UiKit.button(sectArea, "Found", UDim2.fromOffset(92, 30), UDim2.new(1, -92, 0, 48), function()
			invoke("CreateSect", { name = nameBox.Text })
		end, { color = UiKit.Colors.ink, textColor = UiKit.Colors.panel })

		UiKit.label(sectArea, "OR JOIN ONE BY NAME", UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 92), { textSize = 11, bold = true })
		local joinBox = UiKit.textBox(sectArea, "Exact sect name...", UDim2.new(1, -100, 0, 30), UDim2.fromOffset(0, 110))
		UiKit.button(sectArea, "Join", UDim2.fromOffset(92, 30), UDim2.new(1, -92, 0, 110), function()
			invoke("JoinSect", { name = joinBox.Text })
		end)
		return
	end

	UiKit.label(sectArea, sect.name, UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 0), { textSize = 19, title = true, bold = true })
	UiKit.label(sectArea, `Your station: {sect.myRankName}`, UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 24), { textSize = 12, color = UiKit.Colors.textDim })

	local list = (UiKit.scroll(sectArea, UDim2.new(1, 0, 1, -86), UDim2.fromOffset(0, 44)))
	local myPower = stepOf(sect.myRank)
	local canManage = sect.myRank == "leader" or sect.myRank == "vice"
	for index, member in sect.members do
		local row = UiKit.frame(list, UDim2.new(1, -8, 0, 40), UDim2.fromOffset(0, 0), UiKit.Colors.panelLight)
		row.LayoutOrder = index
		local onlineMark = if member.online then "●  " else "○  "
		UiKit.label(row, onlineMark .. member.name, UDim2.new(0.5, -6, 0, 18), UDim2.fromOffset(6, 2), { textSize = 12, bold = true })
		UiKit.label(row, member.rankName, UDim2.new(0.5, -6, 0, 14), UDim2.fromOffset(6, 21), { textSize = 10, color = UiKit.Colors.textDim })

		local targetPower = stepOf(member.rank)
		if canManage and targetPower < myPower and member.rank ~= "leader" then
			local x = -28
			UiKit.button(row, "X", UDim2.fromOffset(24, 22), UDim2.new(1, x, 0.5, -11), function()
				invoke("SetSectRank", { targetUserId = member.userId, rank = "kick" })
			end, { textSize = 11, color = UiKit.Colors.danger, textColor = UiKit.Colors.panel })
			x -= 28
			if targetPower > 1 then
				UiKit.button(row, "▼", UDim2.fromOffset(24, 22), UDim2.new(1, x, 0.5, -11), function()
					invoke("SetSectRank", { targetUserId = member.userId, rank = RANK_STEPS[targetPower - 1] })
				end, { textSize = 11 })
				x -= 28
			end
			if targetPower < #RANK_STEPS and targetPower + 1 < myPower then
				UiKit.button(row, "▲", UDim2.fromOffset(24, 22), UDim2.new(1, x, 0.5, -11), function()
					invoke("SetSectRank", { targetUserId = member.userId, rank = RANK_STEPS[targetPower + 1] })
				end, { textSize = 11 })
				x -= 28
			end
			if sect.myRank == "leader" then
				UiKit.button(row, "Crown", UDim2.fromOffset(46, 22), UDim2.new(1, x - 20, 0.5, -11), function()
					invoke("SetSectRank", { targetUserId = member.userId, rank = "leader" })
				end, { textSize = 10, color = UiKit.Colors.ink, textColor = UiKit.Colors.panel })
			end
		end
	end

	UiKit.button(sectArea, "Leave Sect", UDim2.new(0.5, -4, 0, 30), UDim2.new(0, 0, 1, -34), function()
		invoke("LeaveSect", {})
	end)
	if sect.myRank == "leader" then
		UiKit.button(sectArea, "Disband", UDim2.new(0.5, -4, 0, 30), UDim2.new(0.5, 4, 1, -34), function()
			invoke("DisbandSect", {})
		end, { color = UiKit.Colors.danger, textColor = UiKit.Colors.panel })
	end
end

local function renderLineage()
	clear(lineageArea)
	local social = ClientState.social

	local masterName = if social then social.masterName else nil
	UiKit.label(lineageArea, "MASTER", UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 0), { textSize = 11, bold = true })
	if masterName then
		UiKit.label(lineageArea, masterName, UDim2.new(1, -100, 0, 20), UDim2.fromOffset(0, 16), { textSize = 14, bold = true })
		UiKit.button(lineageArea, "Renounce", UDim2.fromOffset(92, 24), UDim2.new(1, -92, 0, 14), function()
			invoke("RenounceMaster", {})
		end, { textSize = 11 })
	else
		UiKit.label(lineageArea, "You follow no master.", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 16), { textSize = 12, color = UiKit.Colors.textDim })
	end

	local cap = if social then social.discipleCap else Config.MAX_DISCIPLES
	local disciples: { { userId: number, name: string, online: boolean } } = if social then social.disciples else {}
	UiKit.label(lineageArea, `DISCIPLES ({#disciples}/{cap})`, UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 48), { textSize = 11, bold = true })
	for index, disciple in disciples do
		local mark = if disciple.online then "●  " else "○  "
		UiKit.label(lineageArea, mark .. disciple.name, UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 48 + index * 18), { textSize = 12 })
	end

	local offerY = 76 + #disciples * 18
	local offerBox = UiKit.textBox(lineageArea, "Player name...", UDim2.new(1, -100, 0, 28), UDim2.fromOffset(0, offerY))
	UiKit.button(lineageArea, "Offer", UDim2.fromOffset(92, 28), UDim2.new(1, -92, 0, offerY), function()
		invoke("OfferDiscipleship", { targetName = offerBox.Text })
	end, { color = UiKit.Colors.ink, textColor = UiKit.Colors.panel })
	UiKit.label(lineageArea, "A disciple may receive your mastered techniques. Each of their breakthroughs deepens your qi gain.", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, offerY + 32), {
		textSize = 11,
		color = UiKit.Colors.textDim,
		wrap = true,
	})

	local bonus = if social then social.masterBonus else 0
	UiKit.label(lineageArea, `Dao Fortune: +{bonus}x qi gain`, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 1, -22), { textSize = 13, bold = true })
end

local function showOffer(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local offer = payload :: { [string]: any }
	for _, child in offerGui:GetChildren() do
		child:Destroy()
	end
	local banner = UiKit.frame(offerGui, UDim2.fromOffset(420, 76), UDim2.new(0.5, -210, 0, 130))
	local stroke = Instance.new("UIStroke")
	stroke.Color = UiKit.Colors.ink
	stroke.Thickness = 2
	stroke.Parent = banner
	UiKit.label(banner, `{tostring(offer.masterName)} offers to take you as a disciple.`, UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 6), {
		textSize = 13,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
		wrap = true,
	})
	UiKit.button(banner, "Kneel (Accept)", UDim2.new(0.5, -12, 0, 28), UDim2.fromOffset(8, 40), function()
		invoke("RespondDiscipleship", { accept = true })
		banner:Destroy()
	end, { color = UiKit.Colors.ink, textColor = UiKit.Colors.panel, textSize = 12 })
	UiKit.button(banner, "Decline", UDim2.new(0.5, -12, 0, 28), UDim2.new(0.5, 4, 0, 40), function()
		invoke("RespondDiscipleship", { accept = false })
		banner:Destroy()
	end, { textSize = 12 })
	task.delay(85, function()
		if banner.Parent then
			banner:Destroy()
		end
	end)
end

function SectController.Init()
	window = UiKit.window("Sect", "Sect & Lineage", UDim2.fromOffset(680, 520), 40)
	Panels.register("sect", window.toggle)
	local body = window.body

	UiKit.label(body, "THE SECT", UDim2.fromOffset(200, 16), UDim2.fromOffset(0, 0), { textSize = 12, bold = true })
	sectArea = Instance.new("Frame")
	sectArea.Size = UDim2.new(0.55, -8, 1, -40)
	sectArea.Position = UDim2.fromOffset(0, 20)
	sectArea.BackgroundTransparency = 1
	sectArea.Parent = body

	UiKit.label(body, "MASTER & DISCIPLES", UDim2.fromOffset(240, 16), UDim2.new(0.55, 8, 0, 0), { textSize = 12, bold = true })
	lineageArea = Instance.new("Frame")
	lineageArea.Size = UDim2.new(0.45, -8, 1, -40)
	lineageArea.Position = UDim2.new(0.55, 8, 0, 20)
	lineageArea.BackgroundTransparency = 1
	lineageArea.Parent = body

	local errorNote = UiKit.label(window.root, "", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 1, -20), {
		textSize = 11,
		color = UiKit.Colors.danger,
		xalign = Enum.TextXAlignment.Center,
	})
	errorNote.Name = "SectError"

	offerGui = UiKit.screen("DiscipleOffers", 90)

	renderSect()
	renderLineage()
	ClientState.SocialChanged:Connect(function()
		renderSect()
		renderLineage()
	end)
	Net.remoteEvent("DiscipleOffer").OnClientEvent:Connect(showOffer)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.N then
			window.toggle()
		end
	end)
end

return SectController
