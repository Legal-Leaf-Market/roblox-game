--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > HudController
-- The always-on interface, ink on paper: identity top-right, vitals and
-- hotbar bottom-center, the cultivation bar with its breakthrough seal,
-- menu chips, toasts, hints, and the disciple-offer prompt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)
local Panels = require(script.Parent.Parent.Modules.Panels)
local CultivationController = require(script.Parent.CultivationController)

local HudController = {}

local player = Players.LocalPlayer

local realmLabel: TextLabel
local stonesLabel: TextLabel
local healthBar: UiKit.Bar
local qiBar: UiKit.Bar
local staminaBar: UiKit.Bar
local cultivationBar: UiKit.Bar
local breakButton: TextButton
local meditateLabel: TextLabel
local toastArea: Frame

type SlotUi = { root: Frame, name: TextLabel, cooldown: Frame }
local slotUis: { SlotUi } = {}

local function renderStats()
	local stats = ClientState.stats
	if stats == nil then
		return
	end
	realmLabel.Text = tostring(stats.realmName)
	realmLabel.TextColor3 = if typeof(stats.realmColor) == "Color3" then stats.realmColor:Lerp(UiKit.Colors.ink, 0.45) else UiKit.Colors.text
	stonesLabel.Text = `Spirit Stones: {stats.spiritStones}`
	qiBar.set(math.clamp(stats.qi / math.max(stats.maxQi, 1), 0, 1), `QI  {math.floor(stats.qi)} / {stats.maxQi}`)

	local cost = tonumber(stats.breakthroughCost)
	if cost then
		local fraction = math.clamp(stats.cultivationXp / math.max(cost, 1), 0, 1)
		cultivationBar.set(fraction, `CULTIVATION  {math.floor(stats.cultivationXp)} / {cost}`)
		breakButton.Visible = fraction >= 1
	else
		cultivationBar.set(1, "THE PEAK")
		breakButton.Visible = false
	end
	meditateLabel.Visible = stats.meditating == true
end

local function renderSlots()
	local techniques = ClientState.techniques
	for slot = 1, Config.SLOT_COUNT do
		local ui = slotUis[slot]
		local techniqueId = if techniques then (techniques.slots :: { [string]: string })[tostring(slot)] else nil
		local slotName = ""
		if techniques and techniqueId then
			for _, technique in techniques.techniques :: { { [string]: any } } do
				if technique.id == techniqueId then
					slotName = tostring(technique.name)
					break
				end
			end
		end
		ui.name.Text = slotName
		ui.root.BackgroundTransparency = if slotName == "" then 0.7 else 0.1
	end
end

local function startCooldownSweep(slot: number, duration: number)
	local ui = slotUis[slot]
	if ui == nil or duration <= 0 then
		return
	end
	ui.cooldown.Size = UDim2.fromScale(1, 1)
	ui.cooldown.Visible = true
	local tween = TweenService:Create(ui.cooldown, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 0),
	})
	tween.Completed:Once(function()
		ui.cooldown.Visible = false
	end)
	tween:Play()
end

local function toast(text: string, color: Color3?)
	if color then
		local luminance = (color.R + color.G + color.B) / 3
		if luminance > 0.55 then
			color = color:Lerp(UiKit.Colors.ink, 0.55)
		end
	end
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 24)
	card.BackgroundColor3 = UiKit.Colors.paper
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.LayoutOrder = -math.floor(os.clock() * 100)
	card.Parent = toastArea
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = UiKit.Colors.ink
	stroke.Thickness = 1.3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	local label = UiKit.label(card, text, UDim2.new(1, -14, 1, 0), UDim2.fromOffset(7, 0), {
		textSize = 11,
		color = color or UiKit.Colors.ink,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
	})
	label.TextTruncate = Enum.TextTruncate.AtEnd
	task.delay(4.2, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 })
		TweenService:Create(card, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		fade.Completed:Once(function()
			card:Destroy()
		end)
		fade:Play()
	end)
end

function HudController.Init()
	local screen = UiKit.screen("Hud", 10)

	-- ------------------------ Top-right identity ------------------------
	local identity = UiKit.frame(screen, UDim2.fromOffset(230, 66), UDim2.new(1, -242, 0, 10))
	identity.BackgroundTransparency = 0.12
	UiKit.label(identity, player.DisplayName, UDim2.new(1, -16, 0, 20), UDim2.fromOffset(10, 4), {
		textSize = 15,
		title = true,
		bold = true,
	})
	realmLabel = UiKit.label(identity, "Body Tempering I", UDim2.new(1, -16, 0, 16), UDim2.fromOffset(10, 24), {
		textSize = 12,
	})
	stonesLabel = UiKit.label(identity, "", UDim2.new(1, -16, 0, 14), UDim2.fromOffset(10, 42), {
		textSize = 10,
		color = UiKit.Colors.textDim,
	})

	-- Menu chips under the identity card.
	local menuEntries = {
		{ caption = "Arts", panel = "arts" },
		{ caption = "Bag", panel = "bag" },
		{ caption = "Dao", panel = "dao" },
		{ caption = "Updates", panel = "updates" },
	}
	for index, entry in menuEntries do
		UiKit.button(screen, entry.caption, UDim2.fromOffset(54, 20), UDim2.new(1, -242 + (index - 1) * 58, 0, 82), function()
			Panels.toggle(entry.panel)
		end, { textSize = 10 })
	end

	-- ---------------------- Bottom center: vitals ----------------------
	local barsWidth = 240
	local bottom = Instance.new("Frame")
	bottom.Size = UDim2.fromOffset(barsWidth, 66)
	bottom.Position = UDim2.new(0.5, -barsWidth / 2, 1, -150)
	bottom.BackgroundTransparency = 1
	bottom.Parent = screen

	healthBar = UiKit.bar(bottom, UDim2.new(1, 0, 0, 12), UDim2.fromOffset(0, 0), UiKit.Colors.health)
	qiBar = UiKit.bar(bottom, UDim2.new(1, 0, 0, 12), UDim2.fromOffset(0, 14), UiKit.Colors.qi)
	staminaBar = UiKit.bar(bottom, UDim2.new(1, 0, 0, 8), UDim2.fromOffset(0, 28), UiKit.Colors.stamina)
	cultivationBar = UiKit.bar(bottom, UDim2.new(1, 0, 0, 10), UDim2.fromOffset(0, 40), UiKit.Colors.xp)

	breakButton = UiKit.button(screen, "BREAK THROUGH", UDim2.fromOffset(130, 24), UDim2.new(0.5, -65, 1, -180), function()
		CultivationController.RequestBreakthrough()
	end, { textSize = 12, color = UiKit.Colors.danger })
	breakButton.Visible = false

	meditateLabel = UiKit.label(screen, "~ Meditating: qi gathers, the dao whispers ~", UDim2.new(0, 380, 0, 20), UDim2.new(0.5, -190, 0, 64), {
		textSize = 14,
		title = true,
		xalign = Enum.TextXAlignment.Center,
	})
	meditateLabel.TextStrokeColor3 = UiKit.Colors.paper
	meditateLabel.TextStrokeTransparency = 0.3
	meditateLabel.Visible = false

	-- ------------------------------ Hotbar ------------------------------
	local slotSize = 52
	local hotbarWidth = Config.SLOT_COUNT * (slotSize + 6)
	local hotbar = Instance.new("Frame")
	hotbar.Size = UDim2.fromOffset(hotbarWidth, slotSize)
	hotbar.Position = UDim2.new(0.5, -hotbarWidth / 2, 1, -slotSize - 12)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = screen
	for slot = 1, Config.SLOT_COUNT do
		local root = UiKit.frame(hotbar, UDim2.fromOffset(slotSize, slotSize), UDim2.fromOffset((slot - 1) * (slotSize + 6), 0), UiKit.Colors.ink)
		root.BackgroundTransparency = 0.1
		UiKit.label(root, tostring(slot), UDim2.fromOffset(14, 12), UDim2.fromOffset(4, 2), {
			textSize = 10,
			color = UiKit.Colors.paper,
			bold = true,
		})
		local slotName = UiKit.label(root, "", UDim2.new(1, -6, 0, 32), UDim2.fromOffset(3, 15), {
			textSize = 9,
			color = UiKit.Colors.paper,
			xalign = Enum.TextXAlignment.Center,
			wrap = true,
		})
		local cooldown = Instance.new("Frame")
		cooldown.AnchorPoint = Vector2.new(0, 1)
		cooldown.Position = UDim2.fromScale(0, 1)
		cooldown.Size = UDim2.fromScale(1, 0)
		cooldown.BackgroundColor3 = UiKit.Colors.paper
		cooldown.BackgroundTransparency = 0.6
		cooldown.BorderSizePixel = 0
		cooldown.Visible = false
		cooldown.ZIndex = 5
		cooldown.Parent = root
		slotUis[slot] = { root = root, name = slotName, cooldown = cooldown }
	end

	-- Hints.
	local hints = UiKit.label(screen,
		"Click Attack   RClick Heavy   F Block   Q Dodge   Shift Sprint   G Meditate   B Break Through   1-6 Techniques",
		UDim2.new(0, 700, 0, 14), UDim2.new(0.5, -350, 1, -168), {
			textSize = 9,
			xalign = Enum.TextXAlignment.Center,
		})
	hints.TextStrokeColor3 = UiKit.Colors.paper
	hints.TextStrokeTransparency = 0.4

	-- Toasts.
	toastArea = Instance.new("Frame")
	toastArea.Size = UDim2.new(0, 380, 0, 170)
	toastArea.Position = UDim2.new(0.5, -190, 0, 88)
	toastArea.BackgroundTransparency = 1
	toastArea.Parent = screen
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Padding = UDim.new(0, 4)
	toastLayout.Parent = toastArea

	-- Health straight from the humanoid, re-hooked each respawn.
	local function hookHealth(model: Model)
		local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 10)
		if humanoid == nil or not humanoid:IsA("Humanoid") then
			return
		end
		local function renderHealth()
			healthBar.set(math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1),
				`HP  {math.floor(humanoid.Health)} / {math.floor(humanoid.MaxHealth)}`)
		end
		humanoid.HealthChanged:Connect(renderHealth)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(renderHealth)
		renderHealth()
	end
	if player.Character then
		task.spawn(hookHealth, player.Character)
	end
	player.CharacterAdded:Connect(function(model)
		task.spawn(hookHealth, model)
	end)

	-- The disciple-offer prompt.
	local offerFrame = UiKit.frame(screen, UDim2.fromOffset(300, 84), UDim2.new(0.5, -150, 0, 180))
	offerFrame.Visible = false
	local offerText = UiKit.label(offerFrame, "", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, 4), {
		textSize = 13,
		wrap = true,
		xalign = Enum.TextXAlignment.Center,
	})
	UiKit.button(offerFrame, "Accept", UDim2.fromOffset(110, 26), UDim2.new(0.5, -120, 1, -34), function()
		offerFrame.Visible = false
		task.spawn(function()
			Net.remoteFunction("RespondDiscipleship"):InvokeServer({ accept = true })
		end)
	end, { textSize = 12 })
	UiKit.button(offerFrame, "Decline", UDim2.fromOffset(110, 26), UDim2.new(0.5, 10, 1, -34), function()
		offerFrame.Visible = false
		task.spawn(function()
			Net.remoteFunction("RespondDiscipleship"):InvokeServer({ accept = false })
		end)
	end, { textSize = 12, color = UiKit.Colors.danger })
	Net.remoteEvent("DiscipleOffer").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.masterName) == "string" then
			offerText.Text = `{payload.masterName} offers to take you as their disciple.`
			offerFrame.Visible = true
		end
	end)

	-- Wiring.
	ClientState.StatsChanged:Connect(renderStats)
	ClientState.TechniquesChanged:Connect(renderSlots)
	ClientState.StaminaChanged:Connect(function(current: number, max: number)
		staminaBar.set(math.clamp(current / math.max(max, 1), 0, 1), "")
	end)
	ClientState.CooldownStarted:Connect(startCooldownSweep)
	Net.remoteEvent("Notify").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.text) == "string" then
			toast(payload.text, payload.color)
		end
	end)
	renderStats()
	renderSlots()
end

return HudController
