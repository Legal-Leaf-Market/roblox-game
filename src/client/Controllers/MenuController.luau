--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > MenuController
-- The main menu, styled after the cinematic reference: the live world as
-- the backdrop under a slow camera orbit of Cloudrest, black letterbox
-- bars, the title floating over the scene, and three labeled actions along
-- the bottom bar. All of it in the ink-and-paper look. Reopens with M.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientSettings = require(script.Parent.Parent.Modules.ClientSettings)
local Panels = require(script.Parent.Parent.Modules.Panels)

local MenuController = {}

local player = Players.LocalPlayer

local screen: ScreenGui
local settingsPanel: Frame
local orbitConnection: RBXScriptConnection? = nil
local orbitTime = 0

-- The cinematic vantage orbits the crater city. (Kept in sync by hand with
-- Island.VALLEY_Y and the city layout; it is only a camera position.)
local ORBIT_CENTER = Vector3.new(0, 44, 0)
local ORBIT_RADIUS = 430
local ORBIT_HEIGHT = 150
local LOOK_TARGET = Vector3.new(0, 130, -260)

local CONTROLS_TEXT = table.concat({
	"1-6 . . . Cast technique in that slot",
	"Shift . . Sprint      Q . . . Dash      O . . . Qi Step",
	"T . . . . Technique Forge (design your arts)",
	"R . . . . Destiny (race & talent spins)",
	"I . . . . Inventory       N . . . Sect & Lineage",
	"G . . . . Meditate (restores qi, builds cultivation)",
	"M . . . . This menu",
	"",
	"Mine ore in the Deep Mines through the southern pass.",
	"Craft weapons at the Spirit Forge. Pledge a path at a city shrine. Once.",
}, "\n")

local function stopOrbit()
	if orbitConnection then
		orbitConnection:Disconnect()
		orbitConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function startOrbit()
	stopOrbit()
	orbitConnection = RunService.RenderStepped:Connect(function(deltaTime)
		orbitTime += deltaTime
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local angle = orbitTime * 0.03
		local position = ORBIT_CENTER + Vector3.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
		camera.CFrame = CFrame.lookAt(position, LOOK_TARGET)
	end)
end

local function setOpen(open: boolean)
	screen.Enabled = open
	-- The menu owns the whole screen; the HUD waits its turn.
	Panels.setHudVisible(not open)
	if open then
		startOrbit()
	else
		settingsPanel.Visible = false
		stopOrbit()
	end
end

-- A bottom-bar action: big serif title over a small dim subtitle, framed
-- in a paper stroke on the ink bar.
local function menuAction(parent: Instance, title: string, subtitle: string, xOffset: number, callback: () -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(250, 54)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.new(0.5, xOffset, 0.5, 0)
	button.BackgroundColor3 = UiKit.Colors.ink
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = UiKit.Colors.panel
	stroke.Thickness = 1.6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	UiKit.label(button, title, UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 6), {
		textSize = 19,
		color = UiKit.Colors.panel,
		title = true,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
	})
	UiKit.label(button, subtitle, UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 32), {
		textSize = 8,
		color = Color3.fromRGB(178, 172, 160),
		xalign = Enum.TextXAlignment.Center,
	})
	button.Activated:Connect(callback)
	return button
end

function MenuController.Init()
	screen = UiKit.screen("MainMenu", 100)
	screen.Enabled = true
	Panels.register("menu", function()
		setOpen(not screen.Enabled)
	end)

	-- Letterbox bars.
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0.13, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(8, 7, 6)
	topBar.BorderSizePixel = 0
	topBar.Parent = screen

	local bottomBar = Instance.new("Frame")
	bottomBar.Size = UDim2.new(1, 0, 0.17, 0)
	bottomBar.Position = UDim2.new(0, 0, 0.83, 0)
	bottomBar.BackgroundColor3 = Color3.fromRGB(8, 7, 6)
	bottomBar.BorderSizePixel = 0
	bottomBar.Parent = screen

	-- Title cluster floating over the scene.
	local titleArea = Instance.new("Frame")
	titleArea.Size = UDim2.new(1, 0, 0, 150)
	titleArea.Position = UDim2.new(0, 0, 0.16, 0)
	titleArea.BackgroundTransparency = 1
	titleArea.Parent = screen

	local eyebrow = UiKit.label(titleArea, "A  W O R L D  O F  Q I", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 0), {
		textSize = 12,
		color = UiKit.Colors.panel,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
	})
	eyebrow.TextStrokeColor3 = UiKit.Colors.ink
	eyebrow.TextStrokeTransparency = 0.2

	local title = UiKit.label(titleArea, Config.GAME_NAME:upper(), UDim2.new(1, 0, 0, 74), UDim2.fromOffset(0, 20), {
		textSize = 62,
		color = UiKit.Colors.panel,
		title = true,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
	})
	title.TextStrokeColor3 = UiKit.Colors.ink
	title.TextStrokeTransparency = 0

	local tagline = UiKit.label(titleArea, "MEDITATE  ·  CULTIVATE  ·  ASCEND", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 98), {
		textSize = 11,
		color = UiKit.Colors.panel,
		bold = true,
		xalign = Enum.TextXAlignment.Center,
	})
	tagline.TextStrokeColor3 = UiKit.Colors.ink
	tagline.TextStrokeTransparency = 0.2

	local rule = Instance.new("Frame")
	rule.Size = UDim2.fromOffset(300, 2)
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.new(0.5, 0, 0, 122)
	rule.BackgroundColor3 = UiKit.Colors.panel
	rule.BackgroundTransparency = 0.3
	rule.BorderSizePixel = 0
	rule.Parent = titleArea

	-- Bottom actions.
	menuAction(bottomBar, "CONTINUE", "ENTER WORLD", -290, function()
		setOpen(false)
	end)
	menuAction(bottomBar, "DESTINY", "TALENT  ·  RACE", 0, function()
		-- Straight into the spin panel: enter the world with Destiny open.
		setOpen(false)
		task.defer(Panels.toggle, "destiny:open")
	end)
	menuAction(bottomBar, "SETTINGS", "OPTIONS  ·  CONTROLS", 290, function()
		settingsPanel.Visible = not settingsPanel.Visible
	end)

	-- Settings overlay: a paper panel over the scene.
	settingsPanel = UiKit.frame(screen, UDim2.fromOffset(420, 380), UDim2.new(0.5, -210, 0.5, -220))
	settingsPanel.Visible = false
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = UiKit.Colors.ink
	panelStroke.Thickness = 2
	panelStroke.Parent = settingsPanel

	local entries = {
		{ key = "vfxEnabled", name = "Technique visual effects" },
		{ key = "othersVfx", name = "Show other players' effects" },
		{ key = "showHints", name = "On-screen hints" },
	}
	for index, entry in entries do
		local y = 14 + (index - 1) * 40
		UiKit.label(settingsPanel, entry.name, UDim2.new(1, -130, 0, 32), UDim2.fromOffset(14, y), { textSize = 13 })
		local toggle: TextButton
		local function render()
			local on = ClientSettings.get(entry.key)
			toggle.Text = if on then "ON" else "OFF"
			toggle.BackgroundColor3 = if on then UiKit.Colors.ink else UiKit.Colors.panelLight
			toggle.TextColor3 = if on then UiKit.Colors.panel else UiKit.Colors.text
		end
		toggle = UiKit.button(settingsPanel, "ON", UDim2.fromOffset(76, 28), UDim2.new(1, -92, 0, y), function()
			ClientSettings.set(entry.key, not ClientSettings.get(entry.key))
			render()
		end)
		render()
	end
	UiKit.label(settingsPanel, CONTROLS_TEXT, UDim2.new(1, -28, 0, 230), UDim2.fromOffset(14, 138), {
		textSize = 11,
		color = UiKit.Colors.textDim,
		wrap = true,
	})

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			setOpen(not screen.Enabled)
		end
	end)

	-- The menu opens on join: begin the cinematic with the HUD hidden.
	Panels.setHudVisible(false)
	startOrbit()
end

return MenuController
