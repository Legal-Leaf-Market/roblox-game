--!strict
-- ModuleScript: ReplicatedStorage > Shared > TechniqueParts
-- The secure component library for player-created techniques. Players
-- never script anything: they chain up to MAX_COMPONENTS of these
-- predefined parts (Dash -> Slash -> Spin -> Qi Wave), name the result,
-- and the server computes every number from this data. Adding a part
-- here is the ONLY way new technique behavior enters the game.

export type Part = {
	id: string,
	name: string,
	kind: string, -- "motion" | "strike" | "wave" | "burst" | "intent"
	categories: { string }, -- which technique categories may use it
	power: number, -- contribution to the technique's power rating
	qiCost: number,
	cooldown: number,
	blurb: string,

	-- Execution numbers (used by the kinds that need them)
	distance: number?, -- motion travel / strike reach / wave range
	radius: number?, -- burst AoE
	speed: number?, -- wave projectile speed
	damageShare: number?, -- fraction of technique damage this part carries
}

local function part(p: Part): Part
	return table.freeze(p) :: Part
end

local TechniqueParts = {}

TechniqueParts.CATEGORIES = table.freeze({ "sword", "fist", "movement", "qi" })

local LIST: { Part } = table.freeze({
	-- ------------------------------ Motions ------------------------------
	part({ id = "dash", name = "Gale Step", kind = "motion", categories = { "sword", "fist", "movement", "qi" },
		power = 8, qiCost = 6, cooldown = 1.2, distance = 28,
		blurb = "A burst of footwork that closes or opens distance." }),
	part({ id = "leap", name = "Crane Rise", kind = "motion", categories = { "fist", "movement" },
		power = 8, qiCost = 6, cooldown = 1.2, distance = 34,
		blurb = "Qi under the heels; the ground lets go." }),
	part({ id = "blink_step", name = "Shadow Thread", kind = "motion", categories = { "movement", "qi" },
		power = 18, qiCost = 14, cooldown = 2.6, distance = 42,
		blurb = "A stitch through space. Walls object; distance does not." }),

	-- ------------------------------ Strikes ------------------------------
	part({ id = "slash", name = "Falling Petal Cut", kind = "strike", categories = { "sword" },
		power = 12, qiCost = 7, cooldown = 0.9, distance = 11, damageShare = 1,
		blurb = "One clean arc. The oldest lesson a sword teaches." }),
	part({ id = "thrust", name = "Heron Beak", kind = "strike", categories = { "sword" },
		power = 14, qiCost = 8, cooldown = 1, distance = 15, damageShare = 1.1,
		blurb = "A point moving faster than the eye that follows it." }),
	part({ id = "palm", name = "River-Turning Palm", kind = "strike", categories = { "fist", "qi" },
		power = 12, qiCost = 7, cooldown = 0.9, distance = 9, damageShare = 1,
		blurb = "The open hand, and the current behind it." }),
	part({ id = "flurry", name = "Ten Sparrow Fists", kind = "strike", categories = { "fist" },
		power = 16, qiCost = 10, cooldown = 1.4, distance = 8, damageShare = 1.25,
		blurb = "Not one blow. A weather of them." }),
	part({ id = "spin_cut", name = "Moon-Circling Blade", kind = "strike", categories = { "sword" },
		power = 16, qiCost = 10, cooldown = 1.4, distance = 12, damageShare = 1.2,
		blurb = "The blade orbits; everything near pays the toll." }),

	-- ------------------------------- Waves -------------------------------
	part({ id = "qi_wave", name = "Azure Crescent", kind = "wave", categories = { "sword", "qi" },
		power = 18, qiCost = 12, cooldown = 1.8, distance = 90, speed = 90, damageShare = 1.15,
		blurb = "The cut leaves the sword and keeps going." }),
	part({ id = "qi_bolt", name = "Sky Needle", kind = "wave", categories = { "qi" },
		power = 14, qiCost = 9, cooldown = 1.2, distance = 110, speed = 130, damageShare = 0.95,
		blurb = "A thin, fast thought with an argument at the end." }),

	-- ------------------------------- Bursts ------------------------------
	part({ id = "nova", name = "Bellows Heart", kind = "burst", categories = { "fist", "qi" },
		power = 20, qiCost = 15, cooldown = 2.4, radius = 16, damageShare = 1.1,
		blurb = "Qi held one breath too long, then all at once." }),
	part({ id = "quake", name = "Ox Stamp", kind = "burst", categories = { "fist" },
		power = 18, qiCost = 13, cooldown = 2.2, radius = 13, damageShare = 1,
		blurb = "The mountain does not move. The ground reconsiders." }),

	-- ------------------------------- Intents -----------------------------
	-- Modifiers: no action of their own; they reshape the whole technique.
	part({ id = "swift_intent", name = "Swift Intent", kind = "intent", categories = { "sword", "fist", "movement", "qi" },
		power = 6, qiCost = 4, cooldown = -0.4,
		blurb = "Trades depth for speed: the technique recovers sooner." }),
	part({ id = "heavy_intent", name = "Heavy Intent", kind = "intent", categories = { "sword", "fist" },
		power = 10, qiCost = 8, cooldown = 0.5, damageShare = 0.35,
		blurb = "Slower, and it lands like a verdict." }),
	part({ id = "far_intent", name = "Far-Reaching Intent", kind = "intent", categories = { "sword", "qi" },
		power = 8, qiCost = 6, cooldown = 0.2,
		blurb = "The technique's reach grows a third again." }),
})
TechniqueParts.LIST = LIST

local byId: { [string]: Part } = {}
for _, entry in LIST do
	byId[entry.id] = entry
end

function TechniqueParts.get(id: string): Part?
	return byId[id]
end

function TechniqueParts.allowedIn(id: string, category: string): boolean
	local entry = byId[id]
	return entry ~= nil and table.find(entry.categories, category) ~= nil
end

return TechniqueParts
