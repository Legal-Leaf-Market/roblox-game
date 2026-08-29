--!strict
-- ModuleScript: ReplicatedStorage > Shared > Config
-- Every tunable number with game-wide reach. One place to balance from.

local Config = {
	GAME_NAME = "Heavenpillar",

	-- ------------------------------ Cultivation ------------------------------
	QI_TICK_SECONDS = 1, -- cadence of the qi/cultivation heartbeat
	MEDITATE_REGEN_MULT = 4, -- qi regen multiplier while meditating
	MEDITATE_XP_MULT = 1, -- meditation cultivation gain (deliberately modest:
	-- fighting, training and questing must beat sitting)
	TRAINING_XP_PER_HIT = 2, -- striking a training dummy
	COMBAT_XP_PER_DAMAGE = 0.25, -- cultivation xp per point of damage dealt to
	-- a real enemy (not dummies)
	KILL_XP_MULT = 1.5, -- kill bonus: victim stage * this

	-- ------------------------------- Movement --------------------------------
	BASE_WALKSPEED = 16,
	SPRINT_MULT = 1.9,
	SPRINT_DRAIN = 16, -- stamina/second
	STAMINA_MAX = 100,
	STAMINA_REGEN = 18,
	DODGE_COOLDOWN = 1.6,
	DODGE_WINDOW = 0.3, -- seconds of evasion after a dodge
	DODGE_SPEED = 95,

	-- -------------------------------- Combat ---------------------------------
	LIGHT_COOLDOWN = 0.38, -- seconds between light swings
	LIGHT_CHAIN_WINDOW = 1.3, -- combo resets if idle longer than this
	HEAVY_COOLDOWN = 2.4,
	HEAVY_MULT = 2.1, -- heavy damage vs light
	FINISHER_MULT = 1.45, -- third light hit
	BLOCK_REDUCTION_LIGHT = 0.6, -- fraction of light damage a block absorbs
	BLOCK_REDUCTION_HEAVY = 0.3, -- heavies punish turtling
	MELEE_RANGE = 9, -- reach of an unarmed/sword swing hitbox
	STUN_ON_FINISHER = 0.5,

	-- ------------------------------ Techniques -------------------------------
	MAX_TECHNIQUES = 12, -- designs a cultivator can hold
	SLOT_COUNT = 6, -- hotbar keys 1-6
	MAX_TECHNIQUE_NAME = 28,
	MAX_COMPONENTS = 4, -- components chained into one technique
	MASTERY_MAX = 100, -- mastery is 0..100%
	INHERITANCE_MULTIPLIER = 0.7, -- passed-down techniques operate at 70%

	-- ----------------------------- Master/Disciple ---------------------------
	MAX_DISCIPLES = 5,

	-- -------------------------------- Economy --------------------------------
	STARTING_SPIRIT_STONES = 15,

	-- --------------------------------- Data ----------------------------------
	AUTOSAVE_SECONDS = 120,
}

return table.freeze(Config)
