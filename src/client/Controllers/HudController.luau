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
local pathBanner: TextLabel
local nameLabel: TextLabel
local identityLabel: TextLabel
local qiBar: UiKit.Bar
local qiValue: TextLabel
local xpBar: UiKit.Bar
local xpValue: TextLabel
local stonesLabel: TextLabel
local meditateLabel: TextLabel
local hintsLabel: TextLabel
local toastArea: Frame

type SlotUi = { root: Frame, name: TextLabel, key: TextLabel, cooldown: Frame }
local slotUis: { SlotUi } = {}

local PATH_HANZI: { [string]: string } = {
	orthodox = "正\n道",
	unorthodox = "散\n修",
	demonic = "魔\n道",
}

local function renderStats()
	local stats = ClientState.stats
	if stats == nil then
		return
	end
	realmMedallion.Text = tostring(stats.realm)
	pathBanner.Text = PATH_HANZI[stats.path or ""] or "游\n侠"

	qiBar.set(math.clamp(stats.qi / math.max(stats.maxQi, 1), 0, 1), "")
	qiValue.Text = `{math.floor(stats.qi)} / {stats.maxQi}`
	xpBar.set(math.clamp(stats.cultivationXp / math.max(stats.breakthroughXp, 1), 0, 1), "")
	xpValue.Text = `{stats.cultivationXp} / {stats.breakthroughXp}`

	local race = Races.get(stats.race)
	local raceName = if race then `{race.name} {race.hanzi}` else stats.race
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
	card.Size = UDim2.new(1, 0, 0, 30)
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
	local label = UiKit.label(card, text, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0), {
		textSize = 14,
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

	-- ------------------------ Top-left identity ------------------------
	-- Realm medallion: a brush circle holding the realm number.
	local medallion = UiKit.frame(screen, UDim2.fromOffset(56, 56), UDim2.fromOffset(16, 14))
	local medallionCorner = medallion:FindFirstChildOfClass("UICorner")
	if medallionCorner then
		medallionCorner.CornerRadius = UDim.new(1, 0)
	end
	local medallionStroke = Instance.new("UIStroke")
	medallionStroke.Color = UiKit.Colors.ink
	medallionStroke.Thickness = 2.4
	medallionStroke.Parent = medallion
	realmMedallion = UiKit.label(medallion, "1", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), {
		textSize = 28,
		title = true,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
	})

	-- Vertical hanzi banner under the medallion: your path, brush-written.
	local banner = UiKit.frame(screen, UDim2.fromOffset(30, 74), UDim2.fromOffset(29, 76), UiKit.Colors.ink)
	pathBanner = UiKit.label(banner, "游\n侠", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), {
		textSize = 20,
		color = UiKit.Colors.panel,
		title = true,
		xalign = Enum.TextXAlignment.Center,
	})

	-- Name, identity line, and the brush bars.
	local vitals = Instance.new("Frame")
	vitals.Size = UDim2.fromOffset(320, 152)
	vitals.Position = UDim2.fromOffset(84, 12)
	vitals.BackgroundTransparency = 1
	vitals.Parent = screen

	nameLabel = UiKit.label(vitals, player.DisplayName, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 0), {
		textSize = 19,
		title = true,
		bold = true,
	})
	nameLabel.TextStrokeColor3 = UiKit.Colors.panel
	nameLabel.TextStrokeTransparency = 0.5
	identityLabel = UiKit.label(vitals, "", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 22), {
		textSize = 12,
	})
	identityLabel.TextStrokeColor3 = UiKit.Colors.panel
	identityLabel.TextStrokeTransparency = 0.4

	UiKit.label(vitals, "QI", UDim2.fromOffset(80, 12), UDim2.fromOffset(0, 44), { textSize = 10, bold = true })
	qiBar = UiKit.bar(vitals, UDim2.fromOffset(190, 13), UDim2.fromOffset(0, 57), UiKit.Colors.qi)
	qiValue = UiKit.label(vitals, "", UDim2.fromOffset(120, 13), UDim2.fromOffset(198, 57), { textSize = 11 })
	qiValue.TextStrokeColor3 = UiKit.Colors.panel
	qiValue.TextStrokeTransparency = 0.4

	UiKit.label(vitals, "CULTIVATION", UDim2.fromOffset(110, 12), UDim2.fromOffset(0, 74), { textSize = 10, bold = true })
	xpBar = UiKit.bar(vitals, UDim2.fromOffset(190, 13), UDim2.fromOffset(0, 87), UiKit.Colors.xp)
	xpValue = UiKit.label(vitals, "", UDim2.fromOffset(120, 13), UDim2.fromOffset(198, 87), { textSize = 11 })
	xpValue.TextStrokeColor3 = UiKit.Colors.panel
	xpValue.TextStrokeTransparency = 0.4

	UiKit.label(vitals, "STAMINA", UDim2.fromOffset(110, 12), UDim2.fromOffset(0, 104), { textSize = 10, bold = true })
	local staminaBar = UiKit.bar(vitals, UDim2.fromOffset(190, 10), UDim2.fromOffset(0, 117), UiKit.Colors.health)
	ClientState.StaminaChanged:Connect(function(current: number, max: number)
		staminaBar.set(math.clamp(current / math.max(max, 1), 0, 1), "")
	end)

	stonesLabel = UiKit.label(vitals, "", UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 132), { textSize = 11 })
	stonesLabel.TextStrokeColor3 = UiKit.Colors.panel
	stonesLabel.TextStrokeTransparency = 0.4

	-- ----------------------- Top-left icon menu ------------------------
	local menuEntries = {
		{ glyph = "新", caption = "Updates", panel = "updates" },
		{ glyph = "技", caption = "Arts", panel = "techniques" },
		{ glyph = "命", caption = "Destiny", panel = "destiny" },
		{ glyph = "囊", caption = "Bag", panel = "inventory" },
		{ glyph = "宗", caption = "Sect", panel = "sect" },
		{ glyph = "阁", caption = "Menu", panel = "menu" },
	}
	for index, entry in menuEntries do
		UiKit.iconButton(screen, entry.glyph, entry.caption, UDim2.fromOffset(16 + (index - 1) * 50, 180), function()
			Panels.toggle(entry.panel)
		end)
	end

	-- Meditation indicator.
	meditateLabel = UiKit.label(screen, "~ Meditating: qi gathers, the dao whispers ~", UDim2.new(0, 420, 0, 24), UDim2.new(0.5, -210, 0, 60), {
		textSize = 16,
		title = true,
		xalign = Enum.TextXAlignment.Center,
	})
	meditateLabel.TextStrokeColor3 = UiKit.Colors.panel
	meditateLabel.TextStrokeTransparency = 0.3
	meditateLabel.Visible = false

	-- ------------------------------ Hotbar -----------------------------
	local slotSize = 84
	local hotbar = Instance.new("Frame")
	hotbar.Size = UDim2.fromOffset(Config.SLOT_COUNT * (slotSize + 6), slotSize)
	hotbar.Position = UDim2.new(0.5, -(Config.SLOT_COUNT * (slotSize + 6)) / 2, 1, -slotSize - 14)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = screen
	for slot = 1, Config.SLOT_COUNT do
		-- Ink-filled slots with paper text, per the kit's quickbar.
		local root = UiKit.frame(hotbar, UDim2.fromOffset(slotSize, slotSize), UDim2.fromOffset((slot - 1) * (slotSize + 6), 0), UiKit.Colors.ink)
		root.BackgroundTransparency = 0.12
		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = UiKit.Colors.ink
		slotStroke.Thickness = 1.6
		slotStroke.Parent = root
		local key = UiKit.label(root, tostring(slot), UDim2.fromOffset(18, 16), UDim2.fromOffset(6, 3), {
			textSize = 13,
			color = UiKit.Colors.panel,
			bold = true,
		})
		local name = UiKit.label(root, "", UDim2.new(1, -8, 0, 44), UDim2.fromOffset(4, 22), {
			textSize = 12,
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
	hintsLabel = UiKit.label(screen, "1-6 Cast   Shift Sprint   Q Dash   O Qi Step   T Arts   R Destiny   I Bag   N Sect   G Meditate   M Menu", UDim2.new(0, 800, 0, 18), UDim2.new(0.5, -400, 1, -118), {
		textSize = 13,
		xalign = Enum.TextXAlignment.Center,
	})
	hintsLabel.TextStrokeColor3 = UiKit.Colors.panel
	hintsLabel.TextStrokeTransparency = 0.4

	-- Toasts.
	toastArea = Instance.new("Frame")
	toastArea.Size = UDim2.new(0, 460, 0, 220)
	toastArea.Position = UDim2.new(0.5, -230, 0, 96)
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
