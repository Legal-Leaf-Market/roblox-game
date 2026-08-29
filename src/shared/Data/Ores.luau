--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > Ores
-- The ores of the caves beneath Heavenpillar Mountain. `spirit_stone` is
-- special: mining it pays out spirit stones (the currency) directly instead
-- of stacking in the ore pouch. `tier` decides which cave hall a node may
-- spawn in (1 = Mining Hall, 2 = Deepforge Hall).

export type OreDef = {
	id: string,
	name: string,
	color: Color3,
	tier: number,
	harvestMin: number,
	harvestMax: number,
	respawnSeconds: number,
	blurb: string,
}

local Ores = {}

local defs: { [string]: OreDef } = {
	spirit_stone = {
		id = "spirit_stone",
		name = "Spirit Stone",
		color = Color3.fromRGB(160, 230, 255),
		tier = 1,
		harvestMin = 2,
		harvestMax = 4,
		respawnSeconds = 25,
		blurb = "Crystallized qi of heaven and earth. The only coin a cultivator fully trusts.",
	},
	black_iron = {
		id = "black_iron",
		name = "Black Iron",
		color = Color3.fromRGB(70, 70, 80),
		tier = 1,
		harvestMin = 1,
		harvestMax = 3,
		respawnSeconds = 20,
		blurb = "Mortal iron steeped in mountain yin until it darkened. The floor of every forge.",
	},
	cold_iron = {
		id = "cold_iron",
		name = "Cold Iron",
		color = Color3.fromRGB(140, 190, 220),
		tier = 1,
		harvestMin = 1,
		harvestMax = 2,
		respawnSeconds = 30,
		blurb = "Iron that never warms, even in the furnace. Blades of it bite twice.",
	},
	meteoric_iron = {
		id = "meteoric_iron",
		name = "Meteoric Iron",
		color = Color3.fromRGB(180, 120, 80),
		tier = 2,
		harvestMin = 1,
		harvestMax = 2,
		respawnSeconds = 45,
		blurb = "Fell from beyond the heavens and remembers the falling. Saber smiths pay in blood for it.",
	},
	star_silver = {
		id = "star_silver",
		name = "Star Silver",
		color = Color3.fromRGB(220, 225, 255),
		tier = 2,
		harvestMin = 1,
		harvestMax = 2,
		respawnSeconds = 60,
		blurb = "Silver veined with starlight. Bows strung with it do not miss so much as decline to.",
	},
	profound_gold = {
		id = "profound_gold",
		name = "Profound Gold",
		color = Color3.fromRGB(235, 190, 90),
		tier = 2,
		harvestMin = 1,
		harvestMax = 1,
		respawnSeconds = 90,
		blurb = "Xuanjin, the metal of the deep earth. Heavier than it should be, in every sense.",
	},
	immortal_jade = {
		id = "immortal_jade",
		name = "Immortal Jade",
		color = Color3.fromRGB(120, 235, 170),
		tier = 2,
		harvestMin = 1,
		harvestMax = 1,
		respawnSeconds = 120,
		blurb = "Jade that has drunk ten thousand years of qi. Immortals quarrel over gram weights of it.",
	},
}

Ores.defs = table.freeze(defs)
Ores.order = table.freeze({ "spirit_stone", "black_iron", "cold_iron", "meteoric_iron", "star_silver", "profound_gold", "immortal_jade" })

function Ores.get(id: string): OreDef?
	return defs[id]
end

return table.freeze(Ores)
