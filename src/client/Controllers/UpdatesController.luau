--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > UpdatesController
-- The changelog window, reading Shared/UpdatesData. Players who can see
-- the game moving stay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpdatesData = require(Shared:WaitForChild("UpdatesData"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local Panels = require(script.Parent.Parent.Modules.Panels)

local UpdatesController = {}

function UpdatesController.Init()
	local screen = UiKit.screen("UpdatesWindow", 30)
	local windowRoot, body = UiKit.window(screen, "From the Annals", UDim2.fromOffset(400, 380), UDim2.new(0.5, -200, 0.5, -210))
	local scroll = UiKit.scroll(body, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0))

	local order = 0
	for _, entry in UpdatesData do
		order += 1
		local height = 44 + #entry.notes * 26
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -8, 0, height)
		card.BackgroundColor3 = UiKit.Colors.paper
		card.BorderSizePixel = 0
		card.LayoutOrder = order
		card.Parent = scroll
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = UiKit.Colors.ink
		stroke.Thickness = 1.2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = card

		UiKit.label(card, `{entry.version}  ·  {entry.title}`, UDim2.new(1, -12, 0, 20), UDim2.fromOffset(8, 2), {
			textSize = 13,
			bold = true,
		})
		UiKit.label(card, entry.date, UDim2.new(1, -12, 0, 12), UDim2.fromOffset(8, 22), {
			textSize = 9,
			color = UiKit.Colors.textDim,
		})
		for noteIndex, note in entry.notes do
			UiKit.label(card, "· " .. note, UDim2.new(1, -16, 0, 24), UDim2.fromOffset(10, 34 + (noteIndex - 1) * 26), {
				textSize = 10,
				wrap = true,
				yalign = Enum.TextYAlignment.Top,
			})
		end
	end

	Panels.register("updates", function()
		windowRoot.Visible = not windowRoot.Visible
	end)
end

return UpdatesController
