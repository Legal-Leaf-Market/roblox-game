--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > Items
-- Weapons and armor of the cultivation world, forged at the Deepforge from
-- mined ore. A weapon's `category` gates which technique categories it can
-- carry (sword techniques need a sword in hand, and so on; movement
-- techniques need nothing). Armor is a flat damage reduction fraction.

local Types = require(script.Parent.Parent.Types)

export type Recipe = {
	ores: { [string]: number },
	spiritStones: number,
}

export type ItemDef = {
	id: string,
	name: string,
	kind: "weapon" | "armor",
	category: Types.TechniqueCategory?, -- weapons only
	damageMult: number, -- weapons only (1.0 = baseline)
	defense: number, -- armor only, fraction of damage absorbed
	realmReq: number,
	recipe: Recipe?, -- nil = not craftable (starter gear)
	blurb: string,
}

local Items = {}

local function weapon(id: string, name: string, category: Types.TechniqueCategory, damageMult: number, realmReq: number, recipe: Recipe?, blurb: string): ItemDef
	return {
		id = id,
		name = name,
		kind = "weapon" :: "weapon",
		category = category,
		damageMult = damageMult,
		defense = 0,
		realmReq = realmReq,
		recipe = recipe,
		blurb = blurb,
	}
end

local function armor(id: string, name: string, defense: number, realmReq: number, recipe: Recipe?, blurb: string): ItemDef
	return {
		id = id,
		name = name,
		kind = "armor" :: "armor",
		category = nil,
		damageMult = 1,
		defense = defense,
		realmReq = realmReq,
		recipe = recipe,
		blurb = blurb,
	}
end

local defs: { [string]: ItemDef } = {
	-- ------------------------------ Starter ------------------------------
	training_sword = weapon("training_sword", "Training Sword", "sword", 1.0, 1, nil,
		"A sect-issue practice jian. It has taught ten thousand disciples and respected none of them."),

	-- ------------------------------ Swords -------------------------------
	azure_flying_sword = weapon("azure_flying_sword", "Azure Flying Sword", "sword", 1.25, 1,
		{ ores = { black_iron = 6 }, spiritStones = 8 },
		"A slim jian quenched in mountain spring water. Eager to leave the hand."),
	coldriver_jian = weapon("coldriver_jian", "Coldriver Jian", "sword", 1.5, 3,
		{ ores = { cold_iron = 8, black_iron = 4 }, spiritStones = 20 },
		"Cold iron folded ninety-nine times. The edge carries winter with it."),
	immortal_jade_sword = weapon("immortal_jade_sword", "Jade Immortal Sword", "sword", 1.9, 5,
		{ ores = { immortal_jade = 4, star_silver = 4 }, spiritStones = 80 },
		"A blade of living jade. It hums along to qi like an old friend joining a song."),

	-- ------------------------------ Sabers -------------------------------
	blackiron_dao = weapon("blackiron_dao", "Black Iron Dao", "blade", 1.2, 1,
		{ ores = { black_iron = 8 }, spiritStones = 8 },
		"A broad, honest saber. Subtlety costs extra."),
	meteoric_dao = weapon("meteoric_dao", "Meteoric Dao", "blade", 1.5, 3,
		{ ores = { meteoric_iron = 7, black_iron = 3 }, spiritStones = 24 },
		"Forged from a fallen star's spine. It still wants to hit the ground hard."),
	profound_gold_saber = weapon("profound_gold_saber", "Profound Gold Saber", "blade", 1.8, 4,
		{ ores = { profound_gold = 5, meteoric_iron = 3 }, spiritStones = 60 },
		"Xuanjin gives the blade its weight; the wielder supplies the grudge."),

	-- ------------------------------- Bows --------------------------------
	starwood_bow = weapon("starwood_bow", "Starwood Bow", "bow", 1.2, 1,
		{ ores = { black_iron = 5 }, spiritStones = 10 },
		"Mountain yew with black iron caps. Loyal out to the edge of sight."),
	star_silver_bow = weapon("star_silver_bow", "Star Silver Bow", "bow", 1.55, 3,
		{ ores = { star_silver = 7, cold_iron = 3 }, spiritStones = 28 },
		"Strung with drawn star silver. On a clear night it aims a little for you."),

	-- ------------------------------- Robes -------------------------------
	disciple_robe = armor("disciple_robe", "Outer Disciple Robe", 0.05, 1,
		{ ores = { black_iron = 2 }, spiritStones = 4 },
		"Coarse sect cloth with iron thread at the seams. Better than pride alone."),
	blackiron_guard_robe = armor("blackiron_guard_robe", "Black Iron Guard Robe", 0.12, 2,
		{ ores = { black_iron = 10 }, spiritStones = 14 },
		"Lamellar scales sewn under silk, the compromise every sect guard makes."),
	coldsilk_robe = armor("coldsilk_robe", "Coldsilk Robe", 0.18, 3,
		{ ores = { cold_iron = 8, star_silver = 2 }, spiritStones = 30 },
		"Cold iron drawn to thread. Blows arrive tired."),
	starweave_vestment = armor("starweave_vestment", "Starweave Vestment", 0.25, 4,
		{ ores = { star_silver = 8, profound_gold = 2 }, spiritStones = 55 },
		"Woven under a meteor shower, and it remembers the sky's indifference."),
	jade_immortal_vestment = armor("jade_immortal_vestment", "Jade Immortal Vestment", 0.35, 5,
		{ ores = { immortal_jade = 5, profound_gold = 3 }, spiritStones = 100 },
		"Plates of immortal jade over profound gold mail. Tribulation lightning has complained about it."),
}

Items.defs = table.freeze(defs)

Items.order = table.freeze({
	"training_sword",
	"azure_flying_sword", "coldriver_jian", "immortal_jade_sword",
	"blackiron_dao", "meteoric_dao", "profound_gold_saber",
	"starwood_bow", "star_silver_bow",
	"disciple_robe", "blackiron_guard_robe", "coldsilk_robe", "starweave_vestment", "jade_immortal_vestment",
})

function Items.get(id: string): ItemDef?
	return defs[id]
end

return table.freeze(Items)
