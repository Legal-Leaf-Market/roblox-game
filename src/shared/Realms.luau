--!strict
-- ModuleScript: ReplicatedStorage > Shared > Realms
-- The cultivation ladder: 12 Major Realms, each of 12 Minor Realms, for
-- 144 stages between a mortal and a True Immortal. Stats are formulas,
-- not 144 hand-written rows, so the whole curve rebalances from a few
-- constants. All numbers are original to this game.

local Realms = {}

export type MajorRealm = {
	name: string,
	color: Color3, -- aura / UI accent for the realm band
	epithet: string, -- one line of flavor shown on breakthrough
}

local MAJORS: { MajorRealm } = table.freeze({
	{ name = "Body Tempering", color = Color3.fromRGB(155, 148, 138), epithet = "Flesh is the first furnace." },
	{ name = "Qi Gathering", color = Color3.fromRGB(120, 170, 220), epithet = "Breath by breath, the sea fills." },
	{ name = "Foundation Establishment", color = Color3.fromRGB(96, 180, 150), epithet = "What is built on stone endures." },
	{ name = "Core Formation", color = Color3.fromRGB(88, 150, 235), epithet = "A whirlpool learns to hold its center." },
	{ name = "Golden Core", color = Color3.fromRGB(232, 190, 80), epithet = "A sun the size of a seed." },
	{ name = "Nascent Soul", color = Color3.fromRGB(190, 130, 235), epithet = "The self that steps outside the self." },
	{ name = "Soul Transformation", color = Color3.fromRGB(226, 120, 180), epithet = "The river forgets it was rain." },
	{ name = "Void Refinement", color = Color3.fromRGB(110, 110, 160), epithet = "Emptiness, polished until it shines." },
	{ name = "Dao Integration", color = Color3.fromRGB(140, 220, 220), epithet = "The way walks with you now." },
	{ name = "Tribulation Transcendence", color = Color3.fromRGB(240, 240, 250), epithet = "The heavens themselves object." },
	{ name = "Immortal Ascension", color = Color3.fromRGB(255, 226, 160), epithet = "The last stair has no rail." },
	{ name = "True Immortal", color = Color3.fromRGB(255, 250, 235), epithet = "Mountains are brief. You are not." },
})
Realms.MAJORS = MAJORS

Realms.MINORS_PER_MAJOR = 12
Realms.STAGE_COUNT = #Realms.MAJORS * Realms.MINORS_PER_MAJOR -- 144

local ROMAN = table.freeze({ "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" })

function Realms.majorOf(stage: number): number
	return math.clamp(math.ceil(stage / Realms.MINORS_PER_MAJOR), 1, #Realms.MAJORS)
end

function Realms.minorOf(stage: number): number
	return ((stage - 1) % Realms.MINORS_PER_MAJOR) + 1
end

function Realms.major(stage: number): MajorRealm
	return Realms.MAJORS[Realms.majorOf(stage)]
end

-- "Foundation Establishment VII"
function Realms.displayName(stage: number): string
	return `{Realms.major(stage).name} {ROMAN[Realms.minorOf(stage)]}`
end

-- ------------------------------ Stat curve -------------------------------
-- Majors are geometric leaps; minors are steady steps inside a major.
-- Every derived stat flows from these few constants.

local HEALTH_BASE = 100
local HEALTH_MAJOR = 1.55
local HEALTH_MINOR = 1.03

local QI_BASE = 100
local QI_MAJOR = 1.6
local QI_MINOR = 1.035

local REGEN_BASE = 2
local REGEN_MAJOR = 1.35
local REGEN_MINOR = 1.02

local STRENGTH_BASE = 6
local STRENGTH_MAJOR = 1.42
local STRENGTH_MINOR = 1.03

export type StageStats = {
	maxHealth: number,
	maxQi: number,
	qiRegen: number,
	strength: number, -- base melee damage before weapons/techniques
	defenseFrac: number, -- 0..0.5 innate damage reduction
	speedBonus: number, -- studs/sec added to base walkspeed
	powerCap: number, -- ceiling on technique power at this stage
}

function Realms.statsFor(stage: number): StageStats
	local m = Realms.majorOf(stage)
	local n = Realms.minorOf(stage)
	local majorStep = m - 1
	local minorStep = n - 1
	return {
		maxHealth = math.floor(HEALTH_BASE * HEALTH_MAJOR ^ majorStep * HEALTH_MINOR ^ minorStep + 0.5),
		maxQi = math.floor(QI_BASE * QI_MAJOR ^ majorStep * QI_MINOR ^ minorStep + 0.5),
		qiRegen = REGEN_BASE * REGEN_MAJOR ^ majorStep * REGEN_MINOR ^ minorStep,
		strength = STRENGTH_BASE * STRENGTH_MAJOR ^ majorStep * STRENGTH_MINOR ^ minorStep,
		defenseFrac = math.min(0.5, 0.02 * majorStep + 0.004 * minorStep),
		speedBonus = 0.35 * majorStep,
		powerCap = 50 * m + 4 * n,
	}
end

-- Cultivation xp needed to leave `stage` for the next one. nil at the top.
-- Crossing into a new Major Realm costs extra: those are the walls the
-- story is about.
function Realms.breakthroughCost(stage: number): number?
	if stage >= Realms.STAGE_COUNT then
		return nil
	end
	local m = Realms.majorOf(stage)
	local n = Realms.minorOf(stage)
	local cost = 30 * 1.9 ^ (m - 1) * (1 + 0.12 * (n - 1))
	if n == Realms.MINORS_PER_MAJOR then
		cost *= 2.2
	end
	return math.floor(cost + 0.5)
end

-- True when leaving this stage means entering a new Major Realm.
function Realms.isMajorCrossing(stage: number): boolean
	return Realms.minorOf(stage) == Realms.MINORS_PER_MAJOR and stage < Realms.STAGE_COUNT
end

-- Heavenly Tribulations guard the gates of the highest majors. (The
-- tribulation encounter itself arrives in its own phase; callers treat
-- `true` as "storm the heavens first".)
function Realms.requiresTribulation(stage: number): boolean
	return Realms.isMajorCrossing(stage) and Realms.majorOf(stage) + 1 >= 10
end

return Realms
