--!strict
-- ModuleScript: ReplicatedStorage > Shared > Config
-- Shared, read-only game configuration. Both server and client require this;
-- nothing here may be secret and nothing here is authoritative on its own —
-- the server re-checks every value that matters (costs, cooldowns, limits).

local Config = table.freeze({
	GAME_NAME = "Three Paths", -- working title, rename freely
	VERSION = "0.2.0",

	-- Technique authoring
	MAX_TECHNIQUES = 12, -- techniques a player may keep designed at once
	SLOT_COUNT = 6, -- hotbar slots (keys 1..6)
	MAX_POWER = 10, -- power points pourable into one technique
	MAX_TECHNIQUE_NAME = 30,

	-- Movement / combat baselines
	BASE_WALKSPEED = 16,

	-- Destiny spins (races + talents)
	TALENT_SLOTS = 3,
	RACE_SPIN_STONES = 30, -- spirit stone price when out of free spins
	TALENT_SPIN_STONES = 20,
	STARTING_RACE_SPINS = 3,
	STARTING_TALENT_SPINS = 3,
	BREAKTHROUGH_RACE_SPINS = 2, -- granted on every realm breakthrough
	BREAKTHROUGH_TALENT_SPINS = 2,

	-- Qi loop
	QI_TICK_SECONDS = 1,
	AUTOSAVE_SECONDS = 120,

	-- Qi Step (O): qi over the feet, speed for drain
	QISTEP_DRAIN = 4, -- qi per tick while active
	QISTEP_SPEED_BONUS = 6, -- added walkspeed

	-- Technique mastery
	MASTERY_MAX_LEVEL = 10, -- at max, a technique can be passed down

	-- Sects
	SECT_CREATE_COST = 500, -- spirit stones
	SECT_NAME_MIN = 3,
	SECT_NAME_MAX = 24,
	SECT_MEMBER_CAP = 50,

	-- Master & disciple
	MAX_DISCIPLES = 5,
	MASTER_BONUS_PER_BREAKTHROUGH = 1, -- +1.0x qi gain per disciple breakthrough
	MASTER_BONUS_CAP = 10, -- total bonus cap; tune before this becomes an economy
})

return Config
