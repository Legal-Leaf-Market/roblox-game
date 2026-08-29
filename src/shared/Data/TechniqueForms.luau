--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > TechniqueForms
-- The forms a player-authored technique can take. A technique = form +
-- element + power + a name of the player's choosing; TechniqueMath turns
-- that into final numbers. `kind` is what the server actually executes:
--   melee       swing hitbox in front of the caster
--   projectile  server-simulated bolt (pierce = passes through bodies)
--   aoe_point   delayed blast at the aimed point
--   aoe_self    blast centered on the caster
--   dash        forward burst (client-applied after server approval)
--   leap        upward burst
--   teleport    short blink toward the aim point (server moves the character)
--   speed_buff  temporary walkspeed increase

local Types = require(script.Parent.Parent.Types)

export type FormKind = "melee" | "projectile" | "aoe_point" | "aoe_self" | "dash" | "leap" | "teleport" | "speed_buff"

export type FormDef = {
	id: string,
	name: string,
	category: Types.TechniqueCategory,
	kind: FormKind,
	baseDamage: number,
	baseQiCost: number,
	baseCooldown: number,
	range: number, -- melee reach / projectile travel / aim distance
	radius: number, -- aoe radius (0 where unused)
	speed: number, -- projectile speed / dash impulse
	duration: number, -- buff duration (0 where unused)
	pierce: boolean,
	blurb: string,
}

local function form(def: FormDef): FormDef
	return def
end

local Forms = {}

local defs: { [string]: FormDef } = {
	-- ============================== Movement ==============================
	gale_step = form({
		id = "gale_step",
		name = "Gale Step",
		category = "movement",
		kind = "dash",
		baseDamage = 0,
		baseQiCost = 12,
		baseCooldown = 4,
		range = 0,
		radius = 0,
		speed = 90, -- forward impulse
		duration = 0,
		pierce = false,
		blurb = "A single breath of qi driven through the legs. The ground forgets you touched it.",
	}),
	shadow_flicker = form({
		id = "shadow_flicker",
		name = "Flicker Step",
		category = "movement",
		kind = "teleport",
		baseDamage = 0,
		baseQiCost = 20,
		baseCooldown = 6,
		range = 32, -- blink distance
		radius = 0,
		speed = 0,
		duration = 0,
		pierce = false,
		blurb = "Fold the space of three steps into one. Watchers see only where you were.",
	}),
	crane_ascent = form({
		id = "crane_ascent",
		name = "Crane Ascent",
		category = "movement",
		kind = "leap",
		baseDamage = 0,
		baseQiCost = 15,
		baseCooldown = 5,
		range = 0,
		radius = 0,
		speed = 80, -- upward impulse
		duration = 0,
		pierce = false,
		blurb = "Rise the way the crane rises: without asking the earth's permission.",
	}),
	river_stride = form({
		id = "river_stride",
		name = "River Stride",
		category = "movement",
		kind = "speed_buff",
		baseDamage = 0,
		baseQiCost = 25,
		baseCooldown = 14,
		range = 0,
		radius = 0,
		speed = 12, -- walkspeed bonus
		duration = 6,
		pierce = false,
		blurb = "Let qi carry the body like a current. For a while, distance stops arguing.",
	}),

	-- ================================ Sword ================================
	flowing_slash = form({
		id = "flowing_slash",
		name = "Flowing Slash",
		category = "sword",
		kind = "melee",
		baseDamage = 18,
		baseQiCost = 10,
		baseCooldown = 2,
		range = 11,
		radius = 0,
		speed = 0,
		duration = 0,
		pierce = false,
		blurb = "The first sword any sect teaches, honed until water envies it.",
	}),
	crescent_wave = form({
		id = "crescent_wave",
		name = "Crescent Wave",
		category = "sword",
		kind = "projectile",
		baseDamage = 24,
		baseQiCost = 18,
		baseCooldown = 4,
		range = 70,
		radius = 0,
		speed = 90,
		duration = 0,
		pierce = false,
		blurb = "Sword qi released from the edge, a crescent moon thrown flat.",
	}),
	flying_sword = form({
		id = "flying_sword",
		name = "Flying Sword Strike",
		category = "sword",
		kind = "projectile",
		baseDamage = 34,
		baseQiCost = 28,
		baseCooldown = 6,
		range = 120,
		radius = 0,
		speed = 140,
		duration = 0,
		pierce = false,
		blurb = "The classic art of the sword immortals: the blade goes, the hand stays.",
	}),
	ten_thousand_swords = form({
		id = "ten_thousand_swords",
		name = "Ten Thousand Swords",
		category = "sword",
		kind = "aoe_point",
		baseDamage = 20,
		baseQiCost = 40,
		baseCooldown = 10,
		range = 60,
		radius = 14,
		speed = 0,
		duration = 0,
		pierce = false,
		blurb = "Point at a patch of sky and it rains edges.",
	}),

	-- ================================ Blade ================================
	mountain_cleave = form({
		id = "mountain_cleave",
		name = "Mountain Cleave",
		category = "blade",
		kind = "melee",
		baseDamage = 30,
		baseQiCost = 16,
		baseCooldown = 4,
		range = 12,
		radius = 0,
		speed = 0,
		duration = 0,
		pierce = false,
		blurb = "The saber does not fence. It decides, once, downward.",
	}),
	cleaving_gale = form({
		id = "cleaving_gale",
		name = "Cleaving Gale",
		category = "blade",
		kind = "projectile",
		baseDamage = 26,
		baseQiCost = 22,
		baseCooldown = 5,
		range = 60,
		radius = 0,
		speed = 70,
		duration = 0,
		pierce = true,
		blurb = "A saber wind wide as a door, and no more inclined to stop.",
	}),
	whirling_guillotine = form({
		id = "whirling_guillotine",
		name = "Whirling Guillotine",
		category = "blade",
		kind = "aoe_self",
		baseDamage = 22,
		baseQiCost = 24,
		baseCooldown = 6,
		range = 0,
		radius = 14,
		speed = 0,
		duration = 0,
		pierce = false,
		blurb = "One full turn. Everything within a blade's reach learns why the circle is feared.",
	}),

	-- ================================= Bow =================================
	piercing_shot = form({
		id = "piercing_shot",
		name = "Piercing Shot",
		category = "bow",
		kind = "projectile",
		baseDamage = 22,
		baseQiCost = 12,
		baseCooldown = 2.5,
		range = 150,
		radius = 0,
		speed = 160,
		duration = 0,
		pierce = true,
		blurb = "An arrow of condensed qi that treats bodies as suggestions.",
	}),
	comet_arrow = form({
		id = "comet_arrow",
		name = "Comet Arrow",
		category = "bow",
		kind = "projectile",
		baseDamage = 40,
		baseQiCost = 30,
		baseCooldown = 7,
		range = 200,
		radius = 0,
		speed = 200,
		duration = 0,
		pierce = false,
		blurb = "Draw until the bow argues, then loose a falling star sideways.",
	}),
	arrow_tempest = form({
		id = "arrow_tempest",
		name = "Arrow Tempest",
		category = "bow",
		kind = "aoe_point",
		baseDamage = 18,
		baseQiCost = 36,
		baseCooldown = 9,
		range = 90,
		radius = 12,
		speed = 0,
		duration = 0,
		pierce = false,
		blurb = "One arrow leaves the string. A weather system arrives.",
	}),
}

Forms.defs = table.freeze(defs)

Forms.order = table.freeze({
	"gale_step", "shadow_flicker", "crane_ascent", "river_stride",
	"flowing_slash", "crescent_wave", "flying_sword", "ten_thousand_swords",
	"mountain_cleave", "cleaving_gale", "whirling_guillotine",
	"piercing_shot", "comet_arrow", "arrow_tempest",
})

function Forms.get(id: string): FormDef?
	return defs[id]
end

return table.freeze(Forms)
