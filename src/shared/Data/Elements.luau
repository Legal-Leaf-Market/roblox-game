--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > Elements
-- The aspects a technique can be woven with. `path` restricts an element to
-- one of the three paths; a race whose affinity matches the element bypasses
-- that restriction (see Data/Races). `effect` is interpreted by the server's
-- CombatService when a technique of that element lands.

local Types = require(script.Parent.Parent.Types)

export type EffectId = "none" | "burn" | "slow" | "shock" | "knockback" | "poison" | "selfheal" | "lifesteal" | "gust"

export type ElementDef = {
	id: string,
	name: string,
	color: Color3,
	damageMult: number,
	costMult: number,
	path: Types.PathId?, -- nil = open to every path
	effect: EffectId,
	blurb: string,
}

local Elements = {}

local defs: { [string]: ElementDef } = {
	none = {
		id = "none",
		name = "Pure Qi",
		color = Color3.fromRGB(170, 215, 255),
		damageMult = 1.0,
		costMult = 1.0,
		path = nil,
		effect = "none",
		blurb = "Unaspected qi, exactly as it was drawn from heaven and earth.",
	},
	fire = {
		id = "fire",
		name = "Fire",
		color = Color3.fromRGB(255, 120, 60),
		damageMult = 1.1,
		costMult = 1.1,
		path = nil,
		effect = "burn",
		blurb = "Yang at its most violent. Wounds it leaves keep burning.",
	},
	ice = {
		id = "ice",
		name = "Ice",
		color = Color3.fromRGB(150, 220, 255),
		damageMult = 0.95,
		costMult = 1.05,
		path = nil,
		effect = "slow",
		blurb = "Yin condensed to a killing stillness. Struck limbs forget how to hurry.",
	},
	lightning = {
		id = "lightning",
		name = "Lightning",
		color = Color3.fromRGB(180, 140, 255),
		damageMult = 1.2,
		costMult = 1.25,
		path = nil,
		effect = "shock",
		blurb = "Heavenly tribulation, borrowed. Expensive, and it hits like judgment.",
	},
	wind = {
		id = "wind",
		name = "Wind",
		color = Color3.fromRGB(180, 255, 195),
		damageMult = 0.85,
		costMult = 0.8,
		path = nil,
		effect = "gust",
		blurb = "The lightest of the aspects. Techniques woven with wind ask for less qi.",
	},
	earth = {
		id = "earth",
		name = "Earth",
		color = Color3.fromRGB(205, 160, 110),
		damageMult = 1.0,
		costMult = 1.1,
		path = nil,
		effect = "knockback",
		blurb = "The mountain's patience given force. What it strikes, it moves.",
	},
	radiance = {
		id = "radiance",
		name = "Radiance",
		color = Color3.fromRGB(255, 230, 150),
		damageMult = 1.0,
		costMult = 1.05,
		path = "orthodox",
		effect = "selfheal",
		blurb = "The orthodox sects' guarded light. Striking with it mends the striker.",
	},
	venom = {
		id = "venom",
		name = "Venom",
		color = Color3.fromRGB(130, 235, 120),
		damageMult = 0.9,
		costMult = 1.0,
		path = "unorthodox",
		effect = "poison",
		blurb = "The unorthodox answer to a longer blade. The wound is the beginning, not the end.",
	},
	shadow = {
		id = "shadow",
		name = "Shadow",
		color = Color3.fromRGB(140, 90, 200),
		damageMult = 1.05,
		costMult = 1.0,
		path = "demonic",
		effect = "lifesteal",
		blurb = "The demonic path's oldest bargain: what it takes from the struck, it feeds to the striker.",
	},
}

Elements.defs = table.freeze(defs)
Elements.order = table.freeze({ "none", "fire", "ice", "lightning", "wind", "earth", "radiance", "venom", "shadow" })

function Elements.get(id: string): ElementDef?
	return defs[id]
end

return table.freeze(Elements)
