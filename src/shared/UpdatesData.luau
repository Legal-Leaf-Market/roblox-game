--!strict
-- ModuleScript: ReplicatedStorage > Shared > UpdatesData
-- The in-game changelog, newest first. Keep players seeing motion.

export type UpdateEntry = {
	version: string,
	date: string,
	title: string,
	notes: { string },
}

local Updates: { UpdateEntry } = {
	{
		version = "1.0.0",
		date = "2026-08-29",
		title = "Heavenpillar Rises",
		notes = {
			"The game begins again, rebuilt from the first stone: welcome to the Azure Vale, in the shadow of Mount Heavenpillar.",
			"144 steps of cultivation: 12 Major Realms, 12 Minor Realms each, from Body Tempering to True Immortal.",
			"Real combat: light combos, heavy strikes, blocking, dodging, all judged by the server.",
			"Meditate at qi-rich sacred sites for deeper cultivation. Fighting and training cultivate you too.",
			"Design your own techniques from secure components, practice them to 100% mastery, write them into manuals, and pass them to disciples.",
			"Wildlife prowls the vale. It is not friendly.",
		},
	},
}

return table.freeze(Updates)
