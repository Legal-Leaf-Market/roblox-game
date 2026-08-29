--!strict
-- ModuleScript: ReplicatedStorage > Shared > Items
-- The item catalog. Stackable items live in PlayerData.items by id;
-- technique manuals are unique and live in PlayerData.manuals. Weapon
-- stats stay deliberately modest: cultivation, not gear, is the main
-- source of power in this game.

export type ItemDef = {
	id: string,
	name: string,
	kind: string, -- "weapon" | "herb" | "pill" | "material"
	blurb: string,
	rarity: string, -- "common" | "fine" | "rare" | "precious"

	-- Weapons
	weaponCategory: string?, -- "sword" (sabers, spears, bows arrive later)
	damageMult: number?, -- multiplies melee/technique damage
	qiConductivity: number?, -- multiplies qi technique damage specifically
	stageReq: number?,

	-- Pills
	restoreQiFrac: number?, -- fraction of max qi restored on use
	healFrac: number?,
}

local function item(def: ItemDef): ItemDef
	return table.freeze(def) :: ItemDef
end

local Items = {}

local LIST: { ItemDef } = table.freeze({
	item({ id = "worn_sword", name = "Worn Practice Sword", kind = "weapon", rarity = "common",
		weaponCategory = "sword", damageMult = 1.1, qiConductivity = 1, stageReq = 1,
		blurb = "Ten thousand beginners have held this exact sword. Now it is your turn." }),
	item({ id = "azure_iron_sword", name = "Azure Iron Sword", kind = "weapon", rarity = "fine",
		weaponCategory = "sword", damageMult = 1.25, qiConductivity = 1.1, stageReq = 13,
		blurb = "Vale iron, folded nine times. It hums faintly near running water." }),
	item({ id = "cloudpine_blade", name = "Cloudpine Blade", kind = "weapon", rarity = "rare",
		weaponCategory = "sword", damageMult = 1.4, qiConductivity = 1.25, stageReq = 25,
		blurb = "Quenched in mountain mist. Lighter than it has any right to be." }),

	item({ id = "mistleaf", name = "Mistleaf", kind = "herb", rarity = "common",
		blurb = "A gray-green herb that grows where fog lingers. Alchemists burn through sacks of it." }),
	item({ id = "emberroot", name = "Emberroot", kind = "herb", rarity = "fine",
		blurb = "Warm to the touch even in snow. The root remembers summer." }),

	item({ id = "breath_pill", name = "Breath-Gathering Pill", kind = "pill", rarity = "common",
		restoreQiFrac = 0.5,
		blurb = "Chalky, bitter, effective. Restores half of one's qi sea." }),
	item({ id = "mend_pill", name = "Knit-Flesh Pill", kind = "pill", rarity = "common",
		healFrac = 0.4,
		blurb = "Tastes like iron and regret. Closes wounds from the inside." }),

	item({ id = "spirit_dust", name = "Spirit Dust", kind = "material", rarity = "common",
		blurb = "What is left when a beast's core cools. Smiths and alchemists pay for it." }),
	item({ id = "beast_fang", name = "Beast Fang", kind = "material", rarity = "common",
		blurb = "Proof of a fight something else lost." }),
})
Items.LIST = LIST

local byId: { [string]: ItemDef } = {}
for _, def in LIST do
	byId[def.id] = def
end

function Items.get(id: string): ItemDef?
	return byId[id]
end

return Items
