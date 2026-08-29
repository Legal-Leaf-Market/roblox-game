--!strict
-- ModuleScript: StarterPlayer > StarterPlayerScripts > Client > Controllers > UpdatesController
-- The Updates panel: the in-game changelog from Data/Updates, opened from
-- the top-left menu bar. Newest entries first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Updates = require(Shared:WaitForChild("Data"):WaitForChild("Updates"))

local UiKit = require(script.Parent.Parent.Modules.UiKit)
local Panels = require(script.Parent.Parent.Modules.Panels)

local UpdatesController = {}

function UpdatesController.Init()
	local window = UiKit.window("Updates", "Updates", UDim2.fromOffset(520, 500), 60)
	local list = (UiKit.scroll(window.body, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0)))

	for index, entry in Updates do
		local height = 64 + #entry.notes * 30
		local card = UiKit.frame(list, UDim2.new(1, -8, 0, height), UDim2.fromOffset(0, 0), UiKit.Colors.panelLight)
		card.LayoutOrder = index
		UiKit.label(card, entry.title, UDim2.new(1, -120, 0, 24), UDim2.fromOffset(10, 8), {
			textSize = 18,
			title = true,
			bold = true,
		})
		UiKit.label(card, `v{entry.version} · {entry.date}`, UDim2.fromOffset(110, 16), UDim2.new(1, -118, 0, 12), {
			textSize = 11,
			color = UiKit.Colors.textDim,
			xalign = Enum.TextXAlignment.Right,
		})
		for noteIndex, note in entry.notes do
			UiKit.label(card, "- " .. note, UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 30 + (noteIndex - 1) * 30), {
				textSize = 12,
				wrap = true,
			})
		end
	end

	Panels.register("updates", window.toggle)
end

return UpdatesController
