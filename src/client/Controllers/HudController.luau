--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > HudController
-- The always-on HUD, laid out after the ink-kit reference: a realm
-- medallion with a vertical hanzi banner top-left, name and brush-stroke
-- bars beside it, a circular icon menu bar underneath (Updates first), the
-- ink-slot technique hotbar, banner-style notifications, and the
-- meditation indicator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Races = require(Shared:WaitForChild("Data"):WaitForChild("Races"))
local Paths = require(Shared:WaitForChild("Data"):WaitForChild("Paths"))
local Forms = require(Shared:WaitForChild("Data"):WaitForChild("TechniqueForms"))
local Elements = require(Shared:WaitForChild("Data"):WaitForChild("Elements"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientState = require(script.Parent.Parent.Modules.ClientState)
local ClientSettings = require(script.Parent.Parent.Modules.ClientSettings)
local Panels = require(script.Parent.Parent.Modules.Panels)

local HudController = {}

local player = Players.LocalPlayer

local realmMedallion: TextLabel
local nameLabel: TextLabel
local identityLabel: TextLabel
local qiBar: UiKit.Bar
local healthBar: UiKit.Bar
local staminaBar: UiKit.Bar
local xpBar: UiKit.Bar
local xpValue: TextLabel
local stonesLabel: TextLabel
local meditateLabel: TextLabel
local hintsLabel: TextLabel
local toastArea: Frame
local orbFill: Frame
local orbLabel: TextLabel
local orbStroke: UIStroke

type SlotUi = { root: Frame, name: TextLabel, key: TextLabel, cooldown: Frame }
local slotUis: { SlotUi } = {}

local function renderStats()
	local stats = ClientState.stats
	if stats == nil then
		return
	end
	realmMedallion.Text = tostring(stats.realm)

	qiBar.set(math.clamp(stats.qi / math.max(stats.maxQi, 1), 0, 1), `QI  {math.floor(stats.qi)} / {stats.maxQi}`)
	local breakFraction = math.clamp(stats.cultivationXp / math.max(stats.breakthroughXp, 1), 0, 1)
	xpBar.set(breakFraction, "")
	xpValue.Text = `{stats.cultivationXp} / {stats.breakthroughXp}`

	-- Breakthrough orb: fills toward the next realm; burns when ready. Its
	-- color is the player's path.
	local diameter = 6 + 36 * math.sqrt(breakFraction)
	orbFill.Size = UDim2.fromOffset(diameter, diameter)
	local pathForOrb = if stats.path then Paths[stats.path :: string] else nil
	orbFill.BackgroundColor3 = if pathForOrb then pathForOrb.accentColor else UiKit.Colors.textDim
	orbLabel.Text = if breakFraction >= 1 then "BREAK" else `{math.floor(breakFraction * 100)}%`
	orbStroke.Color = if breakFraction >= 1 then UiKit.Colors.danger else UiKit.Colors.ink

	local race = Races.get(stats.race)
	local raceName = if race then race.name else stats.race
	local pathDef = if stats.path then Paths[stats.path :: string] else nil
	local pathName = if pathDef then pathDef.name else "Wanderer"
	local social = ClientState.social
	local sectSuffix = if social and social.sect then `  ·  {social.sect.name}` else ""
	identityLabel.Text = `{stats.realmName}  ·  {pathName}  ·  {raceName}{sectSuffix}`

	local bonus = if stats.masterBonus and stats.masterBonus > 0 then `   Dao Fortune +{stats.masterBonus}x qi` else ""
	stonesLabel.Text = `Spirit Stones: {stats.spiritStones}{bonus}`
	meditateLabel.Visible = stats.meditating
end

local function renderSlots()
	local techniques = ClientState.techniques
	for slot = 1, Config.SLOT_COUNT do
		local ui = slotUis[slot]
		local techniqueId = if techniques then techniques.slots[tostring(slot)] else nil
		local name = ""
		local color = UiKit.Colors.panel
		if techniques and techniqueId then
			for _, technique in techniques.techniques do
				if technique.id == techniqueId then
					name = technique.name
					local element = Elements.get(technique.element)
					if element and element.id ~= "none" then
						color = element.color
					end
					local form = Forms.get(technique.form)
					if form and name == "" then
						name = form.name
					end
					break
				end
			end
		end
		ui.name.Text = name
		ui.name.TextColor3 = color
		ui.root.BackgroundTransparency = if name == "" then 0.75 else 0.12
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

-- Banner-style notification cards, per the kit's notification blocks.
local function toast(text: string, color: Color3?)
	-- Server accent colors are tuned for dark grounds; pull bright ones
	-- toward ink so they stay readable on paper.
	if color then
		local luminance = (color.R + color.G + color.B) / 3
		if luminance > 0.55 then
			color = color:Lerp(UiKit.Colors.ink, 0.55)
		end
	end
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 24)
	card.BackgroundColor3 = UiKit.Colors.panel
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.LayoutOrder = -math.floor(os.clock() * 100)
	card.Parent = toastArea
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = UiKit.Colors.ink
	stroke.Thickness = 1.4
	stroke.Parent = card
	local label = UiKit.label(card, text, UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0), {
		textSize = 11,
		color = color or UiKit.Colors.ink,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
	})
	label.TextTruncate = Enum.TextTruncate.AtEnd
	task.delay(4, function()
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
	-- Respect Roblox's topbar so the medallion and identity line don't
	-- slide under the platform's own buttons.
	screen.IgnoreGuiInset = false
	-- Let the main menu hide the HUD while it owns the screen.
	Panels.registerHud(function(visible: boolean)
		screen.Enabled = visible
	end)

	-- ------------------------ Top-right identity -----------------------
	-- Realm medallion: a brush circle holding the realm number, pinned to
	-- the top-right corner; the vitals block hangs to its left.
	local medallion = UiKit.frame(screen, UDim2.fromOffset(42, 42), UDim2.new(1, -54, 0, 10))
	local medallionCorner = medallion:FindFirstChildOfClass("UICorner")
	if medallionCorner then
		medallionCorner.CornerRadius = UDim.new(1, 0)
	end
	local medallionStroke = Instance.new("UIStroke")
	medallionStroke.Color = UiKit.Colors.ink
	medallionStroke.Thickness = 2.4
	medallionStroke.Parent = medallion
	realmMedallion = UiKit.label(medallion, "1", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), {
		textSize = 21,
		title = true,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
	})

	-- Name, identity line, and the brush bars.
	local vitals = Instance.new("Frame")
	vitals.Size = UDim2.fromOffset(250, 104)
	vitals.Position = UDim2.new(1, -312, 0, 10)
	vitals.BackgroundTransparency = 1
	vitals.Parent = screen

	nameLabel = UiKit.label(vitals, player.DisplayName, UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 0), {
		textSize = 15,
		title = true,
		bold = true,
	})
	nameLabel.TextStrokeColor3 = UiKit.Colors.panel
	nameLabel.TextStrokeTransparency = 0.5
	identityLabel = UiKit.label(vitals, "", UDim2.new(1, 0, 0, 13), UDim2.fromOffset(0, 18), {
		textSize = 9,
	})
	identityLabel.TextStrokeColor3 = UiKit.Colors.panel
	identityLabel.TextStrokeTransparency = 0.4

	UiKit.label(vitals, "CULTIVATION", UDim2.fromOffset(110, 10), UDim2.fromOffset(0, 34), { textSize = 8, bold = true })
	xpBar = UiKit.bar(vitals, UDim2.fromOffset(150, 10), UDim2.fromOffset(0, 45), UiKit.Colors.xp)
	xpValue = UiKit.label(vitals, "", UDim2.fromOffset(94, 10), UDim2.fromOffset(156, 45), { textSize = 9 })
	xpValue.TextStrokeColor3 = UiKit.Colors.panel
	xpValue.TextStrokeTransparency = 0.4

	stonesLabel = UiKit.label(vitals, "", UDim2.new(1, 0, 0, 12), UDim2.fromOffset(0, 60), { textSize = 9 })
	stonesLabel.TextStrokeColor3 = UiKit.Colors.panel
	stonesLabel.TextStrokeTransparency = 0.4

	-- ----------------------- Top-right menu bar ------------------------
	local menuEntries = {
		{ caption = "Updates", panel = "updates" },
		{ caption = "Arts", panel = "techniques" },
		{ caption = "Destiny", panel = "destiny" },
		{ caption = "Bag", panel = "inventory" },
		{ caption = "Sect", panel = "sect" },
		{ caption = "Menu", panel = "menu" },
	}
	local buttonWidth = 50
	local rowWidth = #menuEntries * (buttonWidth + 4)
	for index, entry in menuEntries do
		UiKit.button(screen, entry.caption, UDim2.fromOffset(buttonWidth, 18), UDim2.new(1, -12 - rowWidth + (index - 1) * (buttonWidth + 4), 0, 120), function()
			Panels.toggle(entry.panel)
		end, { textSize = 7 })
	end

	-- Meditation indicator.
	meditateLabel = UiKit.label(screen, "~ Meditating: qi gathers, the dao whispers ~", UDim2.new(0, 360, 0, 20), UDim2.new(0.5, -180, 0, 52), {
		textSize = 14,
		title = true,
		xalign = Enum.TextXAlignment.Center,
	})
	meditateLabel.TextStrokeColor3 = UiKit.Colors.panel
	meditateLabel.TextStrokeTransparency = 0.3
	meditateLabel.Visible = false

	-- --------------------- Vital bars above the hotbar -----------------
	local barsWidth = 230
	local bottomBars = Instance.new("Frame")
	bottomBars.Size = UDim2.fromOffset(barsWidth, 38)
	bottomBars.Position = UDim2.new(0.5, -barsWidth / 2, 1, -122)
	bottomBars.BackgroundTransparency = 1
	bottomBars.Parent = screen

	healthBar = UiKit.bar(bottomBars, UDim2.new(1, 0, 0, 11), UDim2.fromOffset(0, 0), UiKit.Colors.health)
	qiBar = UiKit.bar(bottomBars, UDim2.new(1, 0, 0, 11), UDim2.fromOffset(0, 13), UiKit.Colors.qi)
	staminaBar = UiKit.bar(bottomBars, UDim2.new(1, 0, 0, 8), UDim2.fromOffset(0, 26), UiKit.Colors.stamina)

	ClientState.StaminaChanged:Connect(function(current: number, max: number)
		staminaBar.set(math.clamp(current / math.max(max, 1), 0, 1), "")
	end)

	-- Health straight from our humanoid, re-hooked on every respawn.
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

	-- ------------------------------ Hotbar -----------------------------
	-- Slots 1-3, the breakthrough orb, slots 4-6.
	local slotSize = 54
	local orbSize = 48
	local hotbarWidth = Config.SLOT_COUNT * (slotSize + 6) + orbSize + 12
	local hotbar = Instance.new("Frame")
	hotbar.Size = UDim2.fromOffset(hotbarWidth, slotSize)
	hotbar.Position = UDim2.new(0.5, -hotbarWidth / 2, 1, -slotSize - 10)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = screen

	local orb = UiKit.frame(hotbar, UDim2.fromOffset(orbSize, orbSize), UDim2.fromOffset(3 * (slotSize + 6) + 6, (slotSize - orbSize) / 2), UiKit.Colors.inset)
	local orbCorner = orb:FindFirstChildOfClass("UICorner")
	if orbCorner then
		orbCorner.CornerRadius = UDim.new(1, 0)
	end
	orbStroke = Instance.new("UIStroke")
	orbStroke.Color = UiKit.Colors.ink
	orbStroke.Thickness = 2.4
	orbStroke.Parent = orb
	orbFill = Instance.new("Frame")
	orbFill.AnchorPoint = Vector2.new(0.5, 0.5)
	orbFill.Position = UDim2.fromScale(0.5, 0.5)
	orbFill.Size = UDim2.fromOffset(8, 8)
	orbFill.BackgroundColor3 = UiKit.Colors.textDim
	orbFill.BorderSizePixel = 0
	orbFill.Parent = orb
	local orbFillCorner = Instance.new("UICorner")
	orbFillCorner.CornerRadius = UDim.new(1, 0)
	orbFillCorner.Parent = orbFill
	orbLabel = UiKit.label(orb, "0%", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), {
		textSize = 11,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
		color = UiKit.Colors.panel,
	})
	orbLabel.ZIndex = 3
	orbLabel.TextStrokeColor3 = UiKit.Colors.ink
	orbLabel.TextStrokeTransparency = 0

	for slot = 1, Config.SLOT_COUNT do
		-- Ink-filled slots with paper text; slots 4-6 sit past the orb.
		local slotX = (slot - 1) * (slotSize + 6) + (if slot > 3 then orbSize + 12 else 0)
		local root = UiKit.frame(hotbar, UDim2.fromOffset(slotSize, slotSize), UDim2.fromOffset(slotX, 0), UiKit.Colors.ink)
		root.BackgroundTransparency = 0.12
		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = UiKit.Colors.ink
		slotStroke.Thickness = 1.6
		slotStroke.Parent = root
		local key = UiKit.label(root, tostring(slot), UDim2.fromOffset(14, 12), UDim2.fromOffset(4, 2), {
			textSize = 10,
			color = UiKit.Colors.panel,
			bold = true,
		})
		local name = UiKit.label(root, "", UDim2.new(1, -6, 0, 32), UDim2.fromOffset(3, 15), {
			textSize = 9,
			color = UiKit.Colors.panel,
			xalign = Enum.TextXAlignment.Center,
			wrap = true,
		})
		local cooldown = Instance.new("Frame")
		cooldown.AnchorPoint = Vector2.new(0, 1)
		cooldown.Position = UDim2.fromScale(0, 1)
		cooldown.Size = UDim2.fromScale(1, 0)
		cooldown.BackgroundColor3 = UiKit.Colors.panel
		cooldown.BackgroundTransparency = 0.65
		cooldown.BorderSizePixel = 0
		cooldown.Visible = false
		cooldown.ZIndex = 5
		cooldown.Parent = root
		slotUis[slot] = { root = root, name = name, key = key, cooldown = cooldown }
	end

	-- Hints footer.
	hintsLabel = UiKit.label(screen, "1-6 Cast   Shift Sprint   Q Dash   O Qi Step   T Arts   R Destiny   I Bag   N Sect   G Meditate   M Menu", UDim2.new(0, 640, 0, 14), UDim2.new(0.5, -320, 1, -140), {
		textSize = 9,
		xalign = Enum.TextXAlignment.Center,
	})
	hintsLabel.TextStrokeColor3 = UiKit.Colors.panel
	hintsLabel.TextStrokeTransparency = 0.4

	-- Toasts.
	toastArea = Instance.new("Frame")
	toastArea.Size = UDim2.new(0, 360, 0, 170)
	toastArea.Position = UDim2.new(0.5, -180, 0, 72)
	toastArea.BackgroundTransparency = 1
	toastArea.Parent = screen
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Padding = UDim.new(0, 4)
	toastLayout.Parent = toastArea

	-- Wiring.
	ClientState.StatsChanged:Connect(renderStats)
	ClientState.TechniquesChanged:Connect(renderSlots)
	ClientState.SocialChanged:Connect(renderStats)
	ClientState.CooldownStarted:Connect(startCooldownSweep)
	Net.remoteEvent("Notify").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.text) == "string" then
			toast(payload.text, payload.color)
		end
	end)
	ClientSettings.Changed:Connect(function(key)
		if key == "showHints" then
			hintsLabel.Visible = ClientSettings.get("showHints")
		end
	end)
	renderStats()
	renderSlots()
end

return HudController
