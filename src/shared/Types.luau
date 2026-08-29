--!strict
-- ModuleScript: ReplicatedStorage > Shared > Types
-- Shared type definitions. Data shapes that cross the network or the
-- DataStore boundary live here so server and client agree on them.

export type PathId = "orthodox" | "unorthodox" | "demonic"

export type TechniqueCategory = "movement" | "sword" | "blade" | "bow"

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "mythic"

-- A player-authored cultivation technique. `form` and `element` are ids into
-- Data/TechniqueForms and Data/Elements; `power` is how much qi the player
-- poured into the design (0..10). Stats are always derived from these three
-- via TechniqueMath, never stored, so balance changes apply retroactively.
export type Technique = {
	id: string,
	name: string,
	form: string,
	element: string,
	power: number,
	masteryXp: number, -- earned by casting; TechniqueMath derives the level
	origin: string?, -- who first passed this art down, nil = self-made
}

-- Persisted per player. Keep DataStore-safe: string keys, no Instances,
-- no mixed arrays. `slots` is keyed "1".."6" (DataStores reject sparse
-- numeric arrays).
export type PlayerData = {
	version: number,
	path: PathId?,
	realm: number,
	cultivationXp: number,
	qi: number,
	spiritStones: number,
	ores: { [string]: number },
	items: { [string]: number },
	equippedWeapon: string?,
	equippedArmor: string?,
	techniques: { Technique },
	slots: { [string]: string },
	missionIndex: number,
	missionAccepted: boolean,

	-- Destiny: races and talents, rolled with spins
	race: string, -- equipped race id (Data/Races), "fanren" by default
	ownedRaces: { [string]: number }, -- id -> times rolled
	equippedTalents: { string }, -- up to Config.TALENT_SLOTS ids
	ownedTalents: { [string]: number },
	raceSpins: number,
	talentSpins: number,

	-- Sect & lineage
	sectId: string?,
	masterUserId: number?,
	masterName: string?,
	disciples: { { userId: number, name: string } },
	masterBonus: number, -- +qi-gain multiplier earned from disciple breakthroughs
}

-- Derived stats for one technique at one power level.
export type TechniqueStats = {
	damage: number,
	qiCost: number,
	cooldown: number,
	range: number,
	speed: number,
	radius: number,
	duration: number,
	magnitude: number,
	requiredRealm: number,
	createCost: number,
}

-- Aggregate character modifiers from path + race + talents (see StatCalc).
export type Mods = {
	maxQiMult: number,
	qiRegenMult: number,
	xpMult: number,
	damageMult: number,
	qiCostMult: number,
	cooldownMult: number,
	defenseBonus: number, -- added to armor's damage-absorb fraction
	maxHealthBonus: number,
	walkSpeedBonus: number,
	categoryDamage: { [string]: number }, -- extra mult per technique category
	elementDamage: { [string]: number }, -- extra mult per element
}

-- ModuleScripts must return a non-nil value; types are exported above.
return table.freeze({})
