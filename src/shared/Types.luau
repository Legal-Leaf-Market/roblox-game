--!strict
-- ModuleScript: ReplicatedStorage > Shared > Types
-- Shared type definitions. PlayerData is the persisted shape; it must stay
-- a plain serializable table (no Instances, no functions, string keys in
-- maps), because it goes straight into the DataStore.

export type Technique = {
	id: string, -- GUID
	name: string,
	category: string, -- "sword" | "fist" | "movement" | "qi"
	components: { string }, -- ordered component ids from TechniqueParts
	power: number, -- design potential (may exceed what the owner can use)
	masteryXp: number, -- raw xp; mastery % derives from it
	origin: string?, -- creator's name when inherited; nil when self-made
	inherited: boolean?, -- true = operates at INHERITANCE_MULTIPLIER
}

export type PlayerData = {
	version: number,

	-- Cultivation
	stage: number, -- 1..144 (see Realms)
	cultivationXp: number,
	qi: number,

	-- Wealth & inventory. items maps itemId -> count; unique items
	-- (technique manuals) live in `manuals` keyed by their BookId.
	spiritStones: number,
	items: { [string]: number },
	manuals: { [string]: { bookId: string, techniqueName: string, technique: Technique } },
	equippedWeapon: string?,

	-- Techniques
	techniques: { Technique },
	slots: { [string]: string }, -- hotbar: "1".."6" -> technique id (string
	-- keys on purpose: sparse numeric keys corrupt in DataStore JSON)

	-- Sect & lineage
	sectId: string?,
	sectRank: string?,
	masterUserId: number?,
	masterName: string?,
	disciples: { { userId: number, name: string } },

	-- Reputation per faction id, quest flags by quest id.
	reputation: { [string]: number },
	quests: { [string]: { state: string, progress: number } },

	settings: { [string]: boolean },
}

return table.freeze({})
