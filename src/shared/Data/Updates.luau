--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > Updates
-- The in-game changelog, newest first. The Updates button (top-left) reads
-- this. Add an entry with every release; players who can see the game
-- moving stay.

export type UpdateEntry = {
	version: string,
	date: string,
	title: string,
	notes: { string },
}

local Updates: { UpdateEntry } = {
	{
		version = "0.4.0",
		date = "2026-08-29",
		title = "The Island of Three Realms",
		notes = {
			"The world is now a true island, sculpted from terrain: snow in the north, desert in the southwest, forest to the east and south, ocean all around.",
			"Real mountains: a ring of jagged peaks hides the crater city of Cloudrest, where you now begin. The Deep Mines lie through the southern pass.",
			"A waterfall pours from the north peak, crowned by a dark pagoda.",
			"Circular ring-walled cities in every realm, rivers with bridges, offshore islets, and a web of roads.",
			"HUD reworked: health, qi and stamina bars by the hotbar, a breakthrough orb in its center colored by your path, and the menu moved to the top right, all in English.",
		},
	},
	{
		version = "0.3.0",
		date = "2026-08-29",
		title = "Sects, Lineage & Mastery",
		notes = {
			"Sects: found your own with a name of your choosing. Ranks: Sect Leader, Vice Sect Leader, Elder, Inner Disciple, Outer Disciple. Press N.",
			"Master & disciple: take up to 5 disciples. When a disciple breaks through, the master's qi gain grows.",
			"Technique mastery: casting an art levels it, up to Mastery 10. Each level adds damage and trims cooldown.",
			"Inheritance: a technique at Mastery 10 can be passed down, but only to your own disciples.",
			"Sprint with Shift (stamina bar) and dash with Q.",
			"Qi Step (O): qi wreathes your feet for extra speed, draining qi while it burns.",
			"Movement animations: a martial run while sprinting or qi-stepping, and dashes now leave a qi trail with a camera kick.",
			"New ink-brush HUD: realm medallion, path banner, and the top-left menu bar you are using right now.",
			"This Updates panel.",
		},
	},
	{
		version = "0.2.1",
		date = "2026-08-29",
		title = "The Ink & Paper Update",
		notes = {
			"All menus redrawn in black and white, like a page out of a manhwa.",
			"The three cities rebuilt in proper Chinese architecture: pagoda homes, paifang gates, shrine pavilions, red lanterns.",
			"New flora: layered pines, blossom trees, and bamboo groves in the southeast.",
			"A cobblestone ring road now circles Heavenpillar Mountain.",
		},
	},
	{
		version = "0.2.0",
		date = "2026-08-29",
		title = "The World Awakens",
		notes = {
			"Heavenpillar Mountain, three path cities, and the Deep Mines beneath.",
			"Qi cultivation with 8 realms, meditation, and breakthroughs.",
			"Design your own techniques: 14 forms, 9 elements, power 0-10, named by you.",
			"Destiny spins: 124 races of Chinese myth and 41 talents.",
			"Mining, Grandmaster Khadun's commissions, and the Spirit Forge.",
		},
	},
}

return table.freeze(Updates)
