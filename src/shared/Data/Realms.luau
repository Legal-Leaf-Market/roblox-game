--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > Realms
-- The cultivation ladder. Index = realm number; breakthroughXp is the
-- cultivation experience needed to advance to the NEXT realm.

export type Realm = {
	name: string,
	maxQi: number,
	qiRegen: number, -- qi per tick while idle
	meditateMult: number, -- regen multiplier while meditating
	meditateXp: number, -- cultivation xp per tick while meditating
	breakthroughXp: number,
}

local Realms: { Realm } = {
	{ name = "Body Tempering", maxQi = 100, qiRegen = 2, meditateMult = 5, meditateXp = 2, breakthroughXp = 100 },
	{ name = "Qi Condensation", maxQi = 160, qiRegen = 3, meditateMult = 5, meditateXp = 3, breakthroughXp = 300 },
	{ name = "Foundation Establishment", maxQi = 240, qiRegen = 4, meditateMult = 5, meditateXp = 4, breakthroughXp = 700 },
	{ name = "Core Formation", maxQi = 350, qiRegen = 5, meditateMult = 6, meditateXp = 6, breakthroughXp = 1500 },
	{ name = "Nascent Soul", maxQi = 500, qiRegen = 7, meditateMult = 6, meditateXp = 8, breakthroughXp = 3000 },
	{ name = "Divine Transformation", maxQi = 700, qiRegen = 9, meditateMult = 6, meditateXp = 10, breakthroughXp = 6000 },
	{ name = "Void Refinement", maxQi = 950, qiRegen = 12, meditateMult = 7, meditateXp = 13, breakthroughXp = 12000 },
	-- Final realm: breakthroughXp is effectively unreachable until more
	-- realms are added above it.
	{ name = "Immortal Ascension", maxQi = 1300, qiRegen = 15, meditateMult = 7, meditateXp = 16, breakthroughXp = 10_000_000 },
}

return table.freeze(Realms)
