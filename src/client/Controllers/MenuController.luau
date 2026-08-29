--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > MenuController
-- The main menu shown on join: title, Enter the World, Settings, Controls.
-- Reopens with M. The world loads behind it (spawning is untouched); the
-- menu is an overlay with a blur, so entering is instant.

local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local ClientSettings = require(script.Parent.Parent.Modules.ClientSettings)

local MenuController = {}

local screen: ScreenGui
local blur: BlurEffect

local CONTROLS_TEXT = table.concat({
	"1-6 . . . Cast technique in that slot",
	"T . . . . Technique Forge (design your arts)",
	"R . . . . Destiny (race & talent spins)",
	"I . . . . Inventory & equipment",
	"G . . . . Meditate (restores qi, builds cultivation)",
	"M . . . . This menu",
	"",
	"Mine ore in the caves under the mountain.",
	"Craft weapons at the Spirit Forge in the deep hall.",
	"Pledge a path at any city shrine. Once.",
}, "\n")

local function setOpen(open: boolean)
	screen.Enabled = open
	blur.Enabled = open
end

function MenuController.Init()
	screen = UiKit.screen("MainMenu", 100)
	screen.Enabled = true

	blur = Instance.new("BlurEffect")
	blur.Size = 18
	blur.Parent = Lighting

	-- Paper mist over the whole viewport: with the blur behind it, the world
	-- reads like an unfinished ink painting.
	local wash = Instance.new("Frame")
	wash.Size = UDim2.fromScale(1, 1)
	wash.BackgroundColor3 = UiKit.Colors.panel
	wash.BackgroundTransparency = 0.2
	wash.BorderSizePixel = 0
	wash.Parent = screen

	local panel = UiKit.frame(wash, UDim2.fromOffset(420, 430), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundTransparency = 0.1

	UiKit.label(panel, Config.GAME_NAME, UDim2.new(1, 0, 0, 64), UDim2.fromOffset(0, 22), {
		textSize = 46,
		color = UiKit.Colors.gold,
		title = true,
		xalign = Enum.TextXAlignment.Center,
	})
	UiKit.label(panel, "A world of qi, three cities, and one mountain.", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 86), {
		textSize = 14,
		color = UiKit.Colors.textDim,
		xalign = Enum.TextXAlignment.Center,
	})

	-- Sub-panels: settings and controls swap into this region.
	local subPanel = UiKit.frame(panel, UDim2.new(1, -40, 0, 150), UDim2.fromOffset(20, 250), UiKit.Colors.inset)
	subPanel.Visible = false
	local subMode = ""

	local function showSub(mode: string)
		for _, child in subPanel:GetChildren() do
			if not child:IsA("UICorner") then
				child:Destroy()
			end
		end
		if mode == subMode or mode == "" then
			subPanel.Visible = false
			subMode = ""
			return
		end
		subMode = mode
		subPanel.Visible = true
		if mode == "controls" then
			UiKit.label(subPanel, CONTROLS_TEXT, UDim2.new(1, -16, 1, -12), UDim2.fromOffset(10, 6), {
				textSize = 13,
				wrap = true,
			})
		elseif mode == "settings" then
			local entries = {
				{ key = "vfxEnabled", name = "Technique visual effects" },
				{ key = "othersVfx", name = "Show other players' effects" },
				{ key = "showHints", name = "On-screen hints" },
			}
			for index, entry in entries do
				local y = 10 + (index - 1) * 44
				UiKit.label(subPanel, entry.name, UDim2.new(1, -120, 0, 36), UDim2.fromOffset(12, y), { textSize = 14 })
				local toggle: TextButton
				local function render()
					local on = ClientSettings.get(entry.key)
					toggle.Text = if on then "ON" else "OFF"
					toggle.BackgroundColor3 = if on then UiKit.Colors.gold else UiKit.Colors.panelLight
					toggle.TextColor3 = if on then UiKit.Colors.panel else UiKit.Colors.text
				end
				toggle = UiKit.button(subPanel, "ON", UDim2.fromOffset(84, 32), UDim2.new(1, -100, 0, y), function()
					ClientSettings.set(entry.key, not ClientSettings.get(entry.key))
					render()
				end)
				render()
			end
		end
	end

	UiKit.button(panel, "Enter the World", UDim2.new(1, -80, 0, 46), UDim2.fromOffset(40, 122), function()
		showSub("")
		setOpen(false)
	end, { color = UiKit.Colors.gold, textColor = UiKit.Colors.panel, textSize = 18 })

	UiKit.button(panel, "Settings", UDim2.new(0.5, -50, 0, 38), UDim2.fromOffset(40, 180), function()
		showSub("settings")
	end)
	UiKit.button(panel, "Controls", UDim2.new(0.5, -50, 0, 38), UDim2.new(0.5, 10, 0, 180), function()
		showSub("controls")
	end)

	UiKit.label(panel, "M reopens this menu", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 1, -24), {
		textSize = 12,
		color = UiKit.Colors.textDim,
		xalign = Enum.TextXAlignment.Center,
	})

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			setOpen(not screen.Enabled)
		end
	end)
end

return MenuController
