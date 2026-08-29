--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > HudController
-- The always-on HUD: qi and cultivation bars, realm/path/race line, spirit
-- stones, the 6-slot technique hotbar with cooldown sweeps, toast
-- notifications, and the meditation indicator.

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

local HudController = {}

local qiBar: UiKit.Bar
local xpBar: UiKit.Bar
local identityLabel: TextLabel
local stonesLabel: TextLabel
local meditateLabel: TextLabel
local hintsLabel: TextLabel
local toastArea: Frame

type SlotUi = { root: Frame, name: TextLabel, key: TextLabel, cooldown: Frame }
local slotUis: { SlotUi } = {}

local function renderStats()
	local stats = ClientState.stats
	if stats == nil then
		return
	end
	qiBar.set(math.clamp(stats.qi / math.max(stats.maxQi, 1), 0, 1), `Qi {math.floor(stats.qi)} / {stats.maxQi}`)
	xpBar.set(math.clamp(stats.cultivationXp / math.max(stats.breakthroughXp, 1), 0, 1),
		`Cultivation {stats.cultivationXp} / {stats.breakthroughXp}`)

	local race = Races.get(stats.race)
	local raceName = if race then `{race.name} {race.hanzi}` else stats.race
	local pathDef = if stats.path then Paths[stats.path :: string] else nil
	local pathName = if pathDef then pathDef.name else "Wanderer"
	identityLabel.Text = `{stats.realmName}  ·  {pathName}  ·  {raceName}`
	stonesLabel.Text = `Spirit Stones: {stats.spiritStones}`
	meditateLabel.Visible = stats.meditating
end

local function renderSlots()
	local techniques = ClientState.techniques
	for slot = 1, Config.SLOT_COUNT do
		local ui = slotUis[slot]
		local techniqueId = if techniques then techniques.slots[tostring(slot)] else nil
		local name = ""
		local color = UiKit.Colors.textDim
		if techniques and techniqueId then
			for _, technique in techniques.techniques do
				if technique.id == techniqueId then
					name = technique.name
					local element = Elements.get(technique.element)
					if element then
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
		ui.root.BackgroundTransparency = if name == "" then 0.6 else 0.15
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
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or UiKit.Colors.text
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = UiKit.Colors.ink
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.LayoutOrder = -os.clock() -- newest on top
	label.Parent = toastArea
	task.delay(4, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade.Completed:Once(function()
			label:Destroy()
		end)
		fade:Play()
	end)
end

function HudController.Init()
	local screen = UiKit.screen("Hud", 10)

	-- Bottom-left vitals.
	local vitals = UiKit.frame(screen, UDim2.fromOffset(300, 96), UDim2.new(0, 16, 1, -190), UiKit.Colors.panel)
	vitals.BackgroundTransparency = 0.25
	identityLabel = UiKit.label(vitals, "", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 4), {
		textSize = 13,
		color = UiKit.Colors.gold,
	})
	qiBar = UiKit.bar(vitals, UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 26), UiKit.Colors.qi)
	xpBar = UiKit.bar(vitals, UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 52), UiKit.Colors.xp)
	stonesLabel = UiKit.label(vitals, "", UDim2.new(1, -16, 0, 16), UDim2.fromOffset(8, 76), {
		textSize = 12,
		color = UiKit.Colors.textDim,
	})

	-- Meditation indicator.
	meditateLabel = UiKit.label(screen, "~ Meditating: qi gathers, the dao whispers ~", UDim2.new(0, 420, 0, 24), UDim2.new(0.5, -210, 0, 60), {
		textSize = 16,
		color = UiKit.Colors.qi,
		title = true,
		xalign = Enum.TextXAlignment.Center,
	})
	meditateLabel.TextStrokeColor3 = UiKit.Colors.panel
	meditateLabel.TextStrokeTransparency = 0.3
	meditateLabel.Visible = false

	-- Hotbar.
	local slotSize = 86
	local hotbar = Instance.new("Frame")
	hotbar.Size = UDim2.fromOffset(Config.SLOT_COUNT * (slotSize + 6), slotSize)
	hotbar.Position = UDim2.new(0.5, -(Config.SLOT_COUNT * (slotSize + 6)) / 2, 1, -slotSize - 14)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = screen
	for slot = 1, Config.SLOT_COUNT do
		local root = UiKit.frame(hotbar, UDim2.fromOffset(slotSize, slotSize), UDim2.fromOffset((slot - 1) * (slotSize + 6), 0))
		root.BackgroundTransparency = 0.6
		local key = UiKit.label(root, tostring(slot), UDim2.fromOffset(18, 16), UDim2.fromOffset(5, 2), {
			textSize = 13,
			color = UiKit.Colors.gold,
			bold = true,
		})
		local name = UiKit.label(root, "", UDim2.new(1, -8, 0, 40), UDim2.fromOffset(4, 22), {
			textSize = 12,
			xalign = Enum.TextXAlignment.Center,
			wrap = true,
		})
		local cooldown = Instance.new("Frame")
		cooldown.AnchorPoint = Vector2.new(0, 1)
		cooldown.Position = UDim2.fromScale(0, 1)
		cooldown.Size = UDim2.fromScale(1, 0)
		cooldown.BackgroundColor3 = Color3.new(0, 0, 0)
		cooldown.BackgroundTransparency = 0.45
		cooldown.BorderSizePixel = 0
		cooldown.Visible = false
		cooldown.ZIndex = 5
		cooldown.Parent = root
		slotUis[slot] = { root = root, name = name, key = key, cooldown = cooldown }
	end

	-- Hints footer.
	hintsLabel = UiKit.label(screen, "T Techniques   R Destiny   I Inventory   G Meditate   M Menu", UDim2.new(0, 600, 0, 18), UDim2.new(0.5, -300, 1, -120), {
		textSize = 13,
		color = UiKit.Colors.textDim,
		xalign = Enum.TextXAlignment.Center,
	})

	-- Toasts.
	toastArea = Instance.new("Frame")
	toastArea.Size = UDim2.new(0, 520, 0, 200)
	toastArea.Position = UDim2.new(0.5, -260, 0, 96)
	toastArea.BackgroundTransparency = 1
	toastArea.Parent = screen
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Padding = UDim.new(0, 2)
	toastLayout.Parent = toastArea

	-- Wiring.
	ClientState.StatsChanged:Connect(renderStats)
	ClientState.TechniquesChanged:Connect(renderSlots)
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
