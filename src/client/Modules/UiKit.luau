--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Modules > UiKit
-- The ink-and-paper interface language: paper panels, ink text, serif
-- faces, brush-stroke bars. Original to this game. One hard rule from a
-- costly lesson: every UIStroke uses ApplyStrokeMode.Border, or it
-- outlines the text glyphs themselves and everything reads blobby.

local UiKit = {}

UiKit.Colors = {
	ink = Color3.fromRGB(27, 24, 21),
	paper = Color3.fromRGB(246, 243, 233),
	paperDim = Color3.fromRGB(233, 228, 214),
	inset = Color3.fromRGB(222, 216, 200),
	text = Color3.fromRGB(38, 34, 30),
	textDim = Color3.fromRGB(110, 102, 92),
	health = Color3.fromRGB(194, 59, 46),
	qi = Color3.fromRGB(59, 125, 216),
	stamina = Color3.fromRGB(224, 138, 46),
	xp = Color3.fromRGB(150, 122, 200),
	gold = Color3.fromRGB(168, 130, 42),
	danger = Color3.fromRGB(178, 44, 38),
}

local TITLE_FONT = Enum.Font.Garamond
local BODY_FONT = Enum.Font.Garamond
local BOLD_FONT = Enum.Font.Merriweather

export type LabelOptions = {
	textSize: number?,
	color: Color3?,
	bold: boolean?,
	title: boolean?,
	wrap: boolean?,
	xalign: Enum.TextXAlignment?,
	yalign: Enum.TextYAlignment?,
}

function UiKit.screen(name: string, displayOrder: number): ScreenGui
	local player = game:GetService("Players").LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = displayOrder
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function stroked(instance: GuiObject, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
end

function UiKit.frame(parent: Instance, size: UDim2, position: UDim2, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color or UiKit.Colors.paper
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = frame
	stroked(frame, UiKit.Colors.ink, 1.8)
	return frame
end

function UiKit.label(parent: Instance, text: string, size: UDim2, position: UDim2, options: LabelOptions?): TextLabel
	local opts: LabelOptions = options or {}
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = opts.color or UiKit.Colors.text
	label.TextSize = (opts.textSize or 12) + (if opts.title then 2 else 0)
	label.Font = if opts.bold then BOLD_FONT elseif opts.title then TITLE_FONT else BODY_FONT
	label.TextWrapped = opts.wrap == true
	label.TextXAlignment = opts.xalign or Enum.TextXAlignment.Left
	label.TextYAlignment = opts.yalign or Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

export type ButtonOptions = {
	textSize: number?,
	color: Color3?,
	textColor: Color3?,
}

function UiKit.button(parent: Instance, text: string, size: UDim2, position: UDim2, callback: () -> (), options: ButtonOptions?): TextButton
	local opts: ButtonOptions = options or {}
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = opts.color or UiKit.Colors.ink
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = opts.textColor or UiKit.Colors.paper
	button.TextSize = opts.textSize or 12
	button.Font = BOLD_FONT
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	stroked(button, UiKit.Colors.ink, 1.4)
	button.Activated:Connect(callback)
	return button
end

function UiKit.textBox(parent: Instance, placeholder: string, size: UDim2, position: UDim2): TextBox
	local box = Instance.new("TextBox")
	box.Size = size
	box.Position = position
	box.BackgroundColor3 = UiKit.Colors.inset
	box.BorderSizePixel = 0
	box.PlaceholderText = placeholder
	box.Text = ""
	box.TextColor3 = UiKit.Colors.text
	box.PlaceholderColor3 = UiKit.Colors.textDim
	box.TextSize = 13
	box.Font = BODY_FONT
	box.ClearTextOnFocus = false
	box.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = box
	stroked(box, UiKit.Colors.ink, 1.2)
	return box
end

function UiKit.scroll(parent: Instance, size: UDim2, position: UDim2): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = size
	scroll.Position = position
	scroll.BackgroundColor3 = UiKit.Colors.paperDim
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = UiKit.Colors.ink
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = scroll
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = scroll
	return scroll
end

export type Bar = { root: Frame, set: (fraction: number, text: string) -> () }

function UiKit.bar(parent: Instance, size: UDim2, position: UDim2, color: Color3): Bar
	local root = Instance.new("Frame")
	root.Size = size
	root.Position = position
	root.BackgroundColor3 = UiKit.Colors.inset
	root.BorderSizePixel = 0
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = root
	stroked(root, UiKit.Colors.ink, 1.4)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = root
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local text = UiKit.label(root, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), {
		textSize = 10,
		bold = true,
		color = UiKit.Colors.paper,
		xalign = Enum.TextXAlignment.Center,
	})
	text.TextStrokeColor3 = UiKit.Colors.ink
	text.TextStrokeTransparency = 0.1
	text.ZIndex = 3

	return {
		root = root,
		set = function(fraction: number, barText: string)
			fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			text.Text = barText
		end,
	}
end

-- A titled paper window with a close button; hidden by default.
function UiKit.window(parent: Instance, title: string, size: UDim2, position: UDim2): (Frame, Frame)
	local root = UiKit.frame(parent, size, position)
	root.Visible = false

	local banner = Instance.new("Frame")
	banner.Size = UDim2.new(1, 0, 0, 30)
	banner.BackgroundColor3 = UiKit.Colors.ink
	banner.BorderSizePixel = 0
	banner.Parent = root
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 5)
	bannerCorner.Parent = banner
	UiKit.label(banner, title, UDim2.new(1, -40, 1, 0), UDim2.fromOffset(12, 0), {
		textSize = 15,
		title = true,
		bold = true,
		color = UiKit.Colors.paper,
	})
	UiKit.button(banner, "X", UDim2.fromOffset(22, 22), UDim2.new(1, -28, 0, 4), function()
		root.Visible = false
	end, { color = UiKit.Colors.danger, textSize = 12 })

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -16, 1, -42)
	body.Position = UDim2.fromOffset(8, 36)
	body.BackgroundTransparency = 1
	body.Parent = root

	return root, body
end

return UiKit
