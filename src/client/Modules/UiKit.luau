--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Modules > UiKit
-- Small UI construction kit shared by every controller. One theme: black
-- ink on paper, the look of a Chinese manhwa page. Panels are paper,
-- chrome is ink, and color appears only where it carries meaning
-- (elements, rarities, danger).

local Players = game:GetService("Players")

local UiKit = {}

UiKit.Colors = {
	ink = Color3.fromRGB(27, 24, 21), -- the black: text, borders, fills
	panel = Color3.fromRGB(246, 243, 233), -- paper: windows, panels
	panelLight = Color3.fromRGB(255, 255, 253), -- raised paper: buttons
	inset = Color3.fromRGB(234, 228, 212), -- recessed paper: lists, inputs
	stroke = Color3.fromRGB(27, 24, 21),
	gold = Color3.fromRGB(27, 24, 21), -- accent = ink in the manhwa theme
	text = Color3.fromRGB(27, 24, 21),
	textDim = Color3.fromRGB(88, 82, 72),
	qi = Color3.fromRGB(35, 32, 28), -- bar fills stay monochrome
	xp = Color3.fromRGB(107, 101, 90),
	health = Color3.fromRGB(68, 64, 58),
	danger = Color3.fromRGB(163, 46, 36), -- the one color: seal red
}

UiKit.RarityColors = {
	common = Color3.fromRGB(120, 114, 104),
	uncommon = Color3.fromRGB(70, 130, 90),
	rare = Color3.fromRGB(60, 100, 160),
	epic = Color3.fromRGB(120, 70, 160),
	legendary = Color3.fromRGB(180, 110, 30),
	mythic = Color3.fromRGB(163, 46, 36),
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
	corner.CornerRadius = UDim.new(0, radius or 4)
	corner.Parent = instance
end

local function stroked(instance: GuiObject, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UiKit.Colors.stroke
	stroke.Thickness = thickness or 1.6
	stroke.Transparency = 0
	stroke.Parent = instance
end

-- The ink-kit double frame: an outer stroke plus an inset inner line, the
-- way brush-drawn UI borders its buttons and panels.
local function doubleBorder(instance: GuiObject, thickness: number?)
	local bg = instance.BackgroundColor3
	local darkGround = (bg.R + bg.G + bg.B) / 3 < 0.5
	local lineColor = if darkGround then UiKit.Colors.panel else UiKit.Colors.ink
	stroked(instance, lineColor, thickness or 1.6)
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Parent = instance
	rounded(inner, 3)
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = lineColor
	innerStroke.Thickness = 1
	innerStroke.Transparency = 0.35
	innerStroke.Parent = inner
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
	doubleBorder(button)
	button.Activated:Connect(callback)
	return button
end

-- A circular brush-ringed icon button carrying one hanzi glyph, with a tiny
-- caption underneath. The top-left menu bar is a row of these.
function UiKit.iconButton(parent: Instance, glyph: string, caption: string, position: UDim2, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(40, 40)
	button.Position = position
	button.BackgroundColor3 = UiKit.Colors.panel
	button.BorderSizePixel = 0
	button.Text = glyph
	button.TextSize = 20
	button.TextColor3 = UiKit.Colors.ink
	button.Font = Enum.Font.Garamond
	button.AutoButtonColor = true
	button.Parent = parent
	rounded(button, 20)
	stroked(button, UiKit.Colors.ink, 1.8)
	local caption2 = Instance.new("TextLabel")
	caption2.Size = UDim2.new(1, 12, 0, 12)
	caption2.Position = UDim2.new(0, -6, 1, 2)
	caption2.BackgroundTransparency = 1
	caption2.Text = caption
	caption2.TextSize = 10
	caption2.TextColor3 = UiKit.Colors.textDim
	caption2.Font = Enum.Font.Gotham
	caption2.Parent = button
	button.Activated:Connect(callback)
	return button
end

function UiKit.textBox(parent: Instance, placeholder: string, size: UDim2, position: UDim2): TextBox
	local box = Instance.new("TextBox")
	box.Size = size
	box.Position = position
	box.BackgroundColor3 = UiKit.Colors.panelLight
	box.BorderSizePixel = 0
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = UiKit.Colors.textDim
	box.Text = ""
	box.TextSize = 14
	box.TextColor3 = UiKit.Colors.text
	box.Font = BODY_FONT
	box.ClearTextOnFocus = false
	box.Parent = parent
	rounded(box, 4)
	stroked(box)
	return box
end

function UiKit.scroll(parent: Instance, size: UDim2, position: UDim2): (ScrollingFrame, UIListLayout)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = size
	scroll.Position = position
	scroll.BackgroundColor3 = UiKit.Colors.inset
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = UiKit.Colors.ink
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	rounded(scroll, 4)
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
	local frame = UiKit.frame(parent, size, position, UiKit.Colors.inset)
	-- Pill-shaped, like a loaded brush stroke.
	local pill = frame:FindFirstChildOfClass("UICorner")
	if pill then
		pill.CornerRadius = UDim.new(1, 0)
	end
	stroked(frame)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = frame
	rounded(fill, 999)
	-- Outlined text stays legible over both the ink fill and the paper gap.
	local label = UiKit.label(frame, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), {
		textSize = 12,
		xalign = Enum.TextXAlignment.Center,
		bold = true,
		color = UiKit.Colors.panel,
	})
	label.TextStrokeColor3 = UiKit.Colors.ink
	label.TextStrokeTransparency = 0
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

-- A centered window: paper body, ink title bar, brush-serif title.
export type Window = { screen: ScreenGui, root: Frame, body: Frame, setVisible: (visible: boolean) -> (), toggle: () -> (), visible: () -> boolean }

function UiKit.window(name: string, title: string, size: UDim2, displayOrder: number): Window
	local screen = UiKit.screen(name, displayOrder)
	screen.Enabled = false

	local root = UiKit.frame(screen, size, UDim2.new(0.5, 0, 0.5, 0))
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	doubleBorder(root, 2)

	-- Ink banner floating over the top edge, the way the kit titles panels.
	local banner = UiKit.frame(root, UDim2.new(0.62, 0, 0, 32), UDim2.new(0.19, 0, 0, -14), UiKit.Colors.ink)
	banner.ZIndex = 3
	stroked(banner, UiKit.Colors.ink, 1.2)
	local bannerText = UiKit.label(banner, title:upper(), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), {
		textSize = 19,
		color = UiKit.Colors.panel,
		title = true,
		xalign = Enum.TextXAlignment.Center,
	})
	bannerText.ZIndex = 4

	local window: Window
	local function setVisible(visible: boolean)
		screen.Enabled = visible
	end
	UiKit.button(root, "X", UDim2.fromOffset(26, 26), UDim2.new(1, -32, 0, 6), function()
		setVisible(false)
	end, { color = UiKit.Colors.ink, textColor = UiKit.Colors.panel })

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -20, 1, -48)
	body.Position = UDim2.fromOffset(10, 36)
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
