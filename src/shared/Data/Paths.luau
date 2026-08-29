--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > Paths
-- The three great paths of cultivation. Each owns one of the map's cities.
-- Multipliers apply server-side (QiSystem regen, TechniqueService damage
-- and cooldowns); everything here is flavor plus those three numbers.

local Types = require(script.Parent.Parent.Types)

export type PathDef = {
	id: Types.PathId,
	name: string,
	cityName: string,
	teamBrickColor: string, -- BrickColor name for the Team
	primaryColor: Color3, -- city architecture
	accentColor: Color3,
	qiRegenMult: number,
	damageMult: number,
	cooldownMult: number,
	blurb: string,
}

local Paths: { [string]: PathDef } = {
	orthodox = {
		id = "orthodox",
		name = "Orthodox Path",
		cityName = "White Cloud City",
		teamBrickColor = "Institutional white",
		primaryColor = Color3.fromRGB(235, 231, 219),
		accentColor = Color3.fromRGB(212, 175, 55),
		qiRegenMult = 1.25,
		damageMult = 1.0,
		cooldownMult = 1.0,
		blurb = "Righteous sects who temper the self through discipline. Their qi flows deep and steady.",
	},
	unorthodox = {
		id = "unorthodox",
		name = "Unorthodox Path",
		cityName = "Freewind City",
		teamBrickColor = "Sand green",
		primaryColor = Color3.fromRGB(110, 124, 110),
		accentColor = Color3.fromRGB(120, 220, 140),
		qiRegenMult = 1.0,
		damageMult = 1.0,
		cooldownMult = 0.85,
		blurb = "Wandering cultivators bound by no sect law. Their arts strike faster than doctrine allows.",
	},
	demonic = {
		id = "demonic",
		name = "Demonic Path",
		cityName = "Blackfire City",
		teamBrickColor = "Really red",
		primaryColor = Color3.fromRGB(40, 34, 38),
		accentColor = Color3.fromRGB(220, 60, 50),
		qiRegenMult = 0.9,
		damageMult = 1.25,
		cooldownMult = 1.0,
		blurb = "Those who feed their dao with slaughter and forbidden arts. Power now, price later.",
	},
}

return table.freeze(Paths)
