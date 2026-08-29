--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > Talents
-- Innate talents: the physiques, bones, meridians and aptitudes of
-- cultivation lore. Rolled with Destiny spins; up to Config.TALENT_SLOTS
-- equipped at once. Unlike races (whose stats derive from an archetype),
-- talents carry their modifiers directly: each is a small, named push in
-- one direction, and stacking three is the buildcraft.

local Types = require(script.Parent.Parent.Types)

export type TalentDef = {
	id: string,
	name: string,
	rarity: Types.Rarity,
	-- All optional; missing = no effect. Multipliers combine by product,
	-- bonuses by sum (see StatCalc).
	maxQiMult: number?,
	qiRegenMult: number?,
	xpMult: number?,
	damageMult: number?,
	qiCostMult: number?,
	cooldownMult: number?,
	defenseBonus: number?,
	maxHealthBonus: number?,
	walkSpeedBonus: number?,
	categoryDamage: { [string]: number }?, -- technique category -> mult
	elementDamage: { [string]: number }?, -- element id -> mult
	blurb: string,
}

local Talents = {}

Talents.SPIN_WEIGHTS = table.freeze({
	common = 51.5,
	uncommon = 27.0,
	rare = 13.0,
	epic = 6.0,
	legendary = 2.0,
	mythic = 0.5,
})

Talents.DUPLICATE_REFUND = table.freeze({
	common = 4,
	uncommon = 8,
	rare = 16,
	epic = 32,
	legendary = 64,
	mythic = 128,
})

local defs: { [string]: TalentDef } = {}
local order: { string } = {}

local function t(def: TalentDef)
	assert(defs[def.id] == nil, `duplicate talent id {def.id}`)
	defs[def.id] = def
	table.insert(order, def.id)
end

-- ============================ Common (10) ============================
t({ id = "iron_bones", name = "Iron Bones", rarity = "common", maxHealthBonus = 15,
	blurb = "A skeleton that argues back." })
t({ id = "ox_vigor", name = "Ox Vigor", rarity = "common", maxHealthBonus = 10, defenseBonus = 0.02,
	blurb = "Plow-beast stamina in a cultivator's frame." })
t({ id = "long_breath", name = "Long Breath", rarity = "common", qiRegenMult = 1.08,
	blurb = "Each breath draws a little deeper than the last." })
t({ id = "steady_dantian", name = "Steady Dantian", rarity = "common", maxQiMult = 1.06,
	blurb = "A qi sea with well-built shores." })
t({ id = "quick_soles", name = "Quick Soles", rarity = "common", walkSpeedBonus = 1,
	blurb = "Feet that finish deciding before the mind does." })
t({ id = "patient_mind", name = "Patient Mind", rarity = "common", xpMult = 1.08,
	blurb = "Insight favors those who sit still long enough to be found." })
t({ id = "thrifty_meridians", name = "Thrifty Meridians", rarity = "common", qiCostMult = 0.95,
	blurb = "Channels that spill not one drop in transit." })
t({ id = "calloused_skin", name = "Calloused Skin", rarity = "common", defenseBonus = 0.03,
	blurb = "The mountain wind did the tempering for free." })
t({ id = "heavy_hands", name = "Heavy Hands", rarity = "common", damageMult = 1.05,
	blurb = "Everything this body swings arrives with interest." })
t({ id = "cold_focus", name = "Cold Focus", rarity = "common", cooldownMult = 0.96,
	blurb = "The next technique is already half-formed behind the eyes." })

-- =========================== Uncommon (8) ===========================
t({ id = "sword_bone", name = "Sword Bone", rarity = "uncommon", categoryDamage = { sword = 1.08 },
	blurb = "Born with one bone too straight. It points at things." })
t({ id = "saber_marrow", name = "Saber Marrow", rarity = "uncommon", categoryDamage = { blade = 1.08 },
	blurb = "The marrow runs single-edged." })
t({ id = "hawk_eye", name = "Hawk Eye", rarity = "uncommon", categoryDamage = { bow = 1.08 },
	blurb = "Distance is a detail." })
t({ id = "featherfoot", name = "Featherfoot", rarity = "uncommon", walkSpeedBonus = 2,
	blurb = "Snow keeps no record of this one's passing." })
t({ id = "deep_wellspring", name = "Deep Wellspring", rarity = "uncommon", maxQiMult = 1.1,
	blurb = "The dantian's floor is further down than it should be." })
t({ id = "flowing_meridians", name = "Flowing Meridians", rarity = "uncommon", qiRegenMult = 1.12,
	blurb = "Qi returns like a river remembering its bed." })
t({ id = "clear_comprehension", name = "Clear Comprehension", rarity = "uncommon", xpMult = 1.12,
	blurb = "Scriptures read themselves aloud to this mind." })
t({ id = "tough_hide", name = "Tough Hide", rarity = "uncommon", defenseBonus = 0.05,
	blurb = "Blades must first agree with the skin, and it is stubborn." })

-- ============================= Rare (8) =============================
t({ id = "sword_heart", name = "Sword Heart", rarity = "rare", categoryDamage = { sword = 1.12 }, cooldownMult = 0.97,
	blurb = "A heart with an edge. Sword arts answer it like kin." })
t({ id = "blade_intent", name = "Blade Intent", rarity = "rare", categoryDamage = { blade = 1.12 }, damageMult = 1.03,
	blurb = "The saber's grudge, inherited whole." })
t({ id = "piercing_gaze", name = "Piercing Gaze", rarity = "rare", categoryDamage = { bow = 1.12 }, cooldownMult = 0.97,
	blurb = "It sees the landing before the loosing." })
t({ id = "cloudstep_bones", name = "Cloudstep Bones", rarity = "rare", walkSpeedBonus = 3, cooldownMult = 0.95,
	blurb = "Bones cut for treading things that will not hold weight." })
t({ id = "sea_of_qi", name = "Sea of Qi", rarity = "rare", maxQiMult = 1.15,
	blurb = "Where others carry a pond, this one carries weather." })
t({ id = "furnace_blood", name = "Furnace Blood", rarity = "rare", elementDamage = { fire = 1.15 },
	blurb = "The blood runs a few degrees past mortal." })
t({ id = "frost_marrow", name = "Frost Marrow", rarity = "rare", elementDamage = { ice = 1.15 },
	blurb = "Winter settled into the bones and paid rent." })
t({ id = "thunder_veins", name = "Thunder Veins", rarity = "rare", elementDamage = { lightning = 1.15 },
	blurb = "Some storms take shelter in a body." })

-- ============================= Epic (7) =============================
t({ id = "innate_sword_embryo", name = "Innate Sword Embryo", rarity = "epic", categoryDamage = { sword = 1.2 },
	blurb = "A sword seed planted before birth. It has been growing ever since." })
t({ id = "mountain_cleaving_arm", name = "Mountain-Cleaving Arm", rarity = "epic", categoryDamage = { blade = 1.2 },
	blurb = "One arm noticeably more certain than the other." })
t({ id = "heavens_quiver", name = "Heaven's Quiver", rarity = "epic", categoryDamage = { bow = 1.2 },
	blurb = "Arrows leave this hand already sure of their address." })
t({ id = "boundless_dantian", name = "Boundless Dantian", rarity = "epic", maxQiMult = 1.25,
	blurb = "Elders measured it twice and stopped publishing the result." })
t({ id = "hollow_meridians", name = "Hollow Meridians", rarity = "epic", qiCostMult = 0.85,
	blurb = "Channels wide as valley roads. Techniques travel them for almost nothing." })
t({ id = "dao_comprehension", name = "Dao Comprehension", rarity = "epic", xpMult = 1.25,
	blurb = "The dao explains itself here, patiently, twice if needed." })
t({ id = "immovable_body", name = "Immovable Body", rarity = "epic", defenseBonus = 0.08, maxHealthBonus = 30,
	blurb = "A vajra frame. Push it and reconsider your life." })

-- ========================== Legendary (5) ===========================
t({ id = "sword_dao_seed", name = "Sword Dao Seed", rarity = "legendary", categoryDamage = { sword = 1.3 }, cooldownMult = 0.94,
	blurb = "A fragment of the Sword Dao itself, sleeping shallowly." })
t({ id = "heavenly_whisper", name = "Heavenly Dao Whisper", rarity = "legendary", xpMult = 1.4,
	blurb = "Heaven talks in its sleep, and this one sits close." })
t({ id = "primordial_dantian", name = "Primordial Dantian", rarity = "legendary", maxQiMult = 1.35, qiRegenMult = 1.15,
	blurb = "A qi sea from before the seas were divided." })
t({ id = "devouring_veins", name = "Devouring Veins", rarity = "legendary", elementDamage = { shadow = 1.25 }, qiCostMult = 0.92,
	blurb = "Meridians that eat. The demonic path files them as a cautionary tale." })
t({ id = "war_god_physique", name = "War God Physique", rarity = "legendary", damageMult = 1.25, maxHealthBonus = 40,
	blurb = "A frame built to the old specifications, from when gods fought personally." })

-- ============================ Mythic (3) ============================
t({ id = "innate_dao_body", name = "Innate Dao Body", rarity = "mythic",
	maxQiMult = 1.15, qiRegenMult = 1.15, xpMult = 1.15, damageMult = 1.1, qiCostMult = 0.92,
	blurb = "Born already in agreement with the dao. Tribulations feel awkward about it." })
t({ id = "chaos_embryo", name = "Chaos Embryo", rarity = "mythic",
	damageMult = 1.2, maxQiMult = 1.2, qiCostMult = 0.9,
	blurb = "A yolk of the unopened universe, carried where a dantian should be." })
t({ id = "heaven_defying_meridians", name = "Heaven-Defying Meridians", rarity = "mythic",
	cooldownMult = 0.8, qiCostMult = 0.8,
	blurb = "Channels rerouted in defiance of the diagrams heaven approved." })

Talents.defs = table.freeze(defs)
Talents.order = table.freeze(order)

function Talents.get(id: string): TalentDef?
	return defs[id]
end

return table.freeze(Talents)
