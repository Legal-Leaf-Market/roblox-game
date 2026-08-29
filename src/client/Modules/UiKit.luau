--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Modules > UiKit
-- Small UI construction kit shared by every controller: one dark ink-and-
-- gold theme, one way to make a window, a button, a bar. Controllers build
-- layouts; UiKit owns look and feel.

local Players = game:GetService("Players")

local UiKit = {}

UiKit.Colors = {
	ink = Color3.fromRGB(18, 16, 22),
	panel = Color3.fromRGB(28, 25, 34),
	panelLight = Color3.fromRGB(42, 38, 50),
	stroke = Color3.fromRGB(90, 80, 60),
	gold = Color3.fromRGB(212, 175, 55),
	text = Color3.fromRGB(235, 230, 215),
	textDim = Color3.fromRGB(160, 155, 145),
	qi = Color3.fromRGB(90, 200, 255),
	xp = Color3.fromRGB(212, 175, 55),
	health = Color3.fromRGB(120, 220, 120),
	danger = Color3.fromRGB(220, 90, 80),
}

UiKit.RarityColors = {
	common = Color3.fromRGB(180, 180, 180),
	uncommon = Color3.fromRGB(110, 220, 130),
	rare = Color3.fromRGB(90, 160, 255),
	epic = Color3.fromRGB(190, 110, 255),
	legendary = Color3.fromRGB(255, 170, 60),
	mythic = Color3.fromRGB(255, 90, 90),
}

local TITLE_FONT = Enum.Font.Garamond
local BODY_FONT = Enum.Font.Gotham

function UiKit.screen(name: string, displayOrder: number): ScreenGui
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = name
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = displayOrder
	screen.Parent = playerGui
	return screen
end

local function rounded(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = instance
end

local function stroked(instance: GuiObject, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UiKit.Colors.stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.25
	stroke.Parent = instance
end

function UiKit.frame(parent: Instance, size: UDim2, position: UDim2, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color or UiKit.Colors.panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	rounded(frame)
	return frame
end

export type LabelOptions = { textSize: number?, color: Color3?, bold: boolean?, xalign: Enum.TextXAlignment?, title: boolean?, wrap: boolean? }

function UiKit.label(parent: Instance, text: string, size: UDim2, position: UDim2, options: LabelOptions?): TextLabel
	local opts: LabelOptions = options or ({} :: LabelOptions)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = opts.textSize or 14
	label.TextColor3 = opts.color or UiKit.Colors.text
	label.Font = if opts.title then TITLE_FONT elseif opts.bold then Enum.Font.GothamBold else BODY_FONT
	label.TextXAlignment = opts.xalign or Enum.TextXAlignment.Left
	label.TextWrapped = opts.wrap == true
	label.TextTruncate = if opts.wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

export type ButtonOptions = { color: Color3?, textColor: Color3?, textSize: number? }

function UiKit.button(parent: Instance, text: string, size: UDim2, position: UDim2, callback: () -> (), options: ButtonOptions?): TextButton
	local opts: ButtonOptions = options or ({} :: ButtonOptions)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = opts.color or UiKit.Colors.panelLight
	button.BorderSizePixel = 0
	button.Text = text
	button.TextSize = opts.textSize or 14
	button.TextColor3 = opts.textColor or UiKit.Colors.text
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = true
	button.Parent = parent
	rounded(button)
	stroked(button)
	button.Activated:Connect(callback)
	return button
end

function UiKit.textBox(parent: Instance, placeholder: string, size: UDim2, position: UDim2): TextBox
	local box = Instance.new("TextBox")
	box.Size = size
	box.Position = position
	box.BackgroundColor3 = UiKit.Colors.ink
	box.BorderSizePixel = 0
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = UiKit.Colors.textDim
	box.Text = ""
	box.TextSize = 14
	box.TextColor3 = UiKit.Colors.text
	box.Font = BODY_FONT
	box.ClearTextOnFocus = false
	box.Parent = parent
	rounded(box, 6)
	stroked(box)
	return box
end

function UiKit.scroll(parent: Instance, size: UDim2, position: UDim2): (ScrollingFrame, UIListLayout)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = size
	scroll.Position = position
	scroll.BackgroundColor3 = UiKit.Colors.ink
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	rounded(scroll, 6)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = scroll
	return scroll, layout
end

export type Bar = { frame: Frame, fill: Frame, label: TextLabel, set: (fraction: number, text: string) -> () }

function UiKit.bar(parent: Instance, size: UDim2, position: UDim2, fillColor: Color3): Bar
	local frame = UiKit.frame(parent, size, position, UiKit.Colors.ink)
	stroked(frame)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = frame
	rounded(fill)
	local label = UiKit.label(frame, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), {
		textSize = 12,
		xalign = Enum.TextXAlignment.Center,
		bold = true,
	})
	label.ZIndex = 3
	local bar: Bar
	bar = {
		frame = frame,
		fill = fill,
		label = label,
		set = function(fraction: number, text: string)
			fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			label.Text = text
		end,
	}
	return bar
end

-- A draggable-feeling centered window with a title bar and close button.
export type Window = { screen: ScreenGui, root: Frame, body: Frame, setVisible: (visible: boolean) -> (), toggle: () -> (), visible: () -> boolean }

function UiKit.window(name: string, title: string, size: UDim2, displayOrder: number): Window
	local screen = UiKit.screen(name, displayOrder)
	screen.Enabled = false

	local root = UiKit.frame(screen, size, UDim2.new(0.5, 0, 0.5, 0))
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	stroked(root, UiKit.Colors.gold, 1)

	local titleBar = UiKit.frame(root, UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 0), UiKit.Colors.ink)
	UiKit.label(titleBar, title, UDim2.new(1, -50, 1, 0), UDim2.fromOffset(12, 0), {
		textSize = 20,
		color = UiKit.Colors.gold,
		title = true,
	})

	local window: Window
	local function setVisible(visible: boolean)
		screen.Enabled = visible
	end
	UiKit.button(titleBar, "X", UDim2.fromOffset(26, 26), UDim2.new(1, -30, 0, 4), function()
		setVisible(false)
	end, { color = UiKit.Colors.panel })

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -16, 1, -46)
	body.Position = UDim2.fromOffset(8, 38)
	body.BackgroundTransparency = 1
	body.Parent = root

	window = {
		screen = screen,
		root = root,
		body = body,
		setVisible = setVisible,
		toggle = function()
			setVisible(not screen.Enabled)
		end,
		visible = function()
			return screen.Enabled
		end,
	}
	return window
end

function UiKit.rarityColor(rarity: string): Color3
	return (UiKit.RarityColors :: { [string]: Color3 })[rarity] or UiKit.Colors.text
end

return UiKit
