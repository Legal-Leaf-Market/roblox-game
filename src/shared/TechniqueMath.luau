--!strict
-- ModuleScript: ReplicatedStorage > Shared > TechniqueMath
-- Pure math for player-created techniques: composition (components ->
-- stats), rank, realm requirement, mastery, and inheritance. Shared so
-- the design UI can preview honestly; the SERVER's call is the one that
-- counts at cast time.

local Config = require(script.Parent.Config)
local Realms = require(script.Parent.Realms)
local TechniqueParts = require(script.Parent.TechniqueParts)

local TechniqueMath = {}

export type ComputedTechnique = {
	power: number, -- design potential
	damage: number, -- at full potential (realm cap may reduce in play)
	qiCost: number,
	cooldown: number,
	requiredStage: number, -- first stage whose powerCap fits this power
	rank: string, -- flavor grade from power
	reachMult: number, -- Far-Reaching Intent stretches distances
	steps: { TechniqueParts.Part }, -- executable (non-intent) parts, in order
}

local RANKS = table.freeze({
	{ threshold = 0, name = "Mortal-grade" },
	{ threshold = 120, name = "Earth-grade" },
	{ threshold = 260, name = "Heaven-grade" },
	{ threshold = 430, name = "Mystic-grade" },
	{ threshold = 640, name = "Divine-grade" },
})

function TechniqueMath.rankName(power: number): string
	local best = RANKS[1].name
	for _, rank in RANKS do
		if power >= rank.threshold then
			best = rank.name
		end
	end
	return best
end

-- The first stage allowed to wield a technique of this power.
function TechniqueMath.requiredStage(power: number): number
	for stage = 1, Realms.STAGE_COUNT do
		if Realms.statsFor(stage).powerCap >= power then
			return stage
		end
	end
	return Realms.STAGE_COUNT
end

-- Compose components (+ an intensity 1..10 chosen at creation) into a
-- technique. Returns nil + reason when the design is invalid.
function TechniqueMath.compute(category: string, componentIds: { string }, intensity: number): (ComputedTechnique?, string?)
	if table.find(TechniqueParts.CATEGORIES, category) == nil then
		return nil, "Unknown technique category"
	end
	if intensity ~= intensity or intensity < 1 or intensity > 10 or intensity % 1 ~= 0 then
		return nil, "Intensity must be a whole number from 1 to 10"
	end
	if #componentIds < 1 or #componentIds > Config.MAX_COMPONENTS then
		return nil, `A technique chains 1 to {Config.MAX_COMPONENTS} components`
	end

	local totalPower = 0
	local qiCost = 0
	local cooldown = 0.6
	local damageShare = 0
	local reachMult = 1
	local steps: { TechniqueParts.Part } = {}
	local seen: { [string]: boolean } = {}
	local hasAction = false

	for _, id in componentIds do
		local part = TechniqueParts.get(id)
		if part == nil then
			return nil, "Unknown component"
		end
		if seen[id] then
			return nil, `{part.name} cannot appear twice in one technique`
		end
		seen[id] = true
		if not TechniqueParts.allowedIn(id, category) then
			return nil, `{part.name} does not belong to the {category} path`
		end
		totalPower += part.power
		qiCost += part.qiCost
		cooldown += part.cooldown
		damageShare += part.damageShare or 0
		if part.kind == "intent" then
			if part.id == "far_intent" then
				reachMult = 1.34
			end
		else
			hasAction = true
			table.insert(steps, part)
		end
	end
	if not hasAction then
		return nil, "A technique needs at least one motion, strike, wave or burst"
	end

	-- Intensity scales potential, price and punch together.
	local scale = 0.7 + intensity * 0.3 -- 1.0 at intensity 1, 3.7 at 10
	local power = math.floor(totalPower * scale + 0.5)
	local damage = math.max(4, math.floor((10 + totalPower * 0.9) * damageShare * scale * 0.6 + 0.5))
	qiCost = math.max(2, math.floor(qiCost * scale + 0.5))
	cooldown = math.max(0.7, cooldown)

	return {
		power = power,
		damage = damage,
		qiCost = qiCost,
		cooldown = cooldown,
		requiredStage = TechniqueMath.requiredStage(power),
		rank = TechniqueMath.rankName(power),
		reachMult = reachMult,
		steps = steps,
	}, nil
end

-- ------------------------------- Mastery ---------------------------------
-- Mastery runs 0..100%. Stronger techniques take longer to internalize.

function TechniqueMath.masteryGoal(power: number): number
	return math.floor(80 + power * 1.4)
end

function TechniqueMath.masteryPercent(masteryXp: number, power: number): number
	return math.clamp(math.floor(100 * masteryXp / TechniqueMath.masteryGoal(power)), 0, 100)
end

-- Controlled bonuses, per the design bible: never overpowered.
function TechniqueMath.masteryDamageMult(percent: number): number
	return 1 + 0.1 * percent / 100 -- up to +10%
end

function TechniqueMath.masteryQiMult(percent: number): number
	return 1 - 0.15 * percent / 100 -- down to -15% cost
end

function TechniqueMath.masteryCooldownMult(percent: number): number
	return 1 - 0.1 * percent / 100 -- up to 10% faster
end

-- ------------------------------ Inheritance ------------------------------
-- A passed-down technique keeps its full design potential, but operates at
-- 70%, and the wielder's own realm cap applies on top. As the disciple's
-- realm rises, more of the original comes through.
function TechniqueMath.effectivePower(technique: { power: number, inherited: boolean? }, wielderStage: number): number
	local potential = technique.power
	if technique.inherited then
		potential *= Config.INHERITANCE_MULTIPLIER
	end
	local cap = Realms.statsFor(wielderStage).powerCap
	return math.min(potential, cap)
end

return TechniqueMath
