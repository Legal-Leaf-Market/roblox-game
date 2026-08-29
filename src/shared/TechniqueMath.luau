--!strict
-- ModuleScript: ReplicatedStorage > Shared > TechniqueMath
-- Pure derivation of a technique's numbers from (form, element, power).
-- Shared so the creation UI previews exactly what the server will enforce.
-- Character modifiers (path/race/talents/weapon) are applied on top by the
-- server at cast time; nothing here reads player state.

local Types = require(script.Parent.Types)
local Forms = require(script.Parent.Data.TechniqueForms)
local Elements = require(script.Parent.Data.Elements)

local TechniqueMath = {}

local function round1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

-- Returns nil (plus a reason) for unknown ids or out-of-range power, so
-- callers on both sides validate through the same gate.
function TechniqueMath.compute(formId: string, elementId: string, power: number): (Types.TechniqueStats?, string?)
	local form = Forms.get(formId)
	if form == nil then
		return nil, "Unknown form"
	end
	local element = Elements.get(elementId)
	if element == nil then
		return nil, "Unknown element"
	end
	if typeof(power) ~= "number" or power ~= power or power % 1 ~= 0 or power < 0 or power > 10 then
		return nil, "Power must be a whole number from 0 to 10"
	end

	local damageScale = 1 + power * 0.12
	local costScale = 1 + power * 0.10
	local cooldownScale = 1 + power * 0.05
	local magnitudeScale = 1 + power * 0.08

	local stats: Types.TechniqueStats = {
		damage = math.floor(form.baseDamage * damageScale * element.damageMult + 0.5),
		qiCost = math.max(1, math.floor(form.baseQiCost * costScale * element.costMult + 0.5)),
		cooldown = round1(form.baseCooldown * cooldownScale),
		range = math.floor(form.range * magnitudeScale + 0.5),
		speed = math.floor(form.speed * magnitudeScale + 0.5),
		radius = math.floor(form.radius * magnitudeScale + 0.5),
		duration = round1(form.duration * magnitudeScale),
		magnitude = round1(magnitudeScale),
		-- Stronger designs demand a deeper realm: power 0-1 -> realm 1,
		-- 2-3 -> 2, ... 10 -> 6.
		requiredRealm = 1 + math.floor(power / 2),
		-- Designing a technique costs spirit stones: comprehension aids,
		-- talisman paper, and a quiet room.
		createCost = 5 + power * 5 + (if element.id == "none" then 0 else 10),
	}
	return stats, nil
end

-- ------------------------------ Mastery ---------------------------------
-- Casting a technique earns mastery xp. Ten levels; at the cap the art can
-- be passed down to a disciple. Levels also sharpen the art itself, so
-- practice is never wasted.

TechniqueMath.MASTERY_MAX = 10

-- Total xp required to REACH a level (level n costs 40*n over level n-1).
function TechniqueMath.masteryTotalXpFor(level: number): number
	return 20 * level * (level + 1)
end

function TechniqueMath.masteryLevel(xp: number): number
	for level = TechniqueMath.MASTERY_MAX, 1, -1 do
		if xp >= TechniqueMath.masteryTotalXpFor(level) then
			return level
		end
	end
	return 0
end

-- Returns (level, xp into current level, xp needed for next level).
-- `needed` is 0 at the cap.
function TechniqueMath.masteryProgress(xp: number): (number, number, number)
	local level = TechniqueMath.masteryLevel(xp)
	if level >= TechniqueMath.MASTERY_MAX then
		return level, 0, 0
	end
	local floor = TechniqueMath.masteryTotalXpFor(level)
	local ceiling = TechniqueMath.masteryTotalXpFor(level + 1)
	return level, xp - floor, ceiling - floor
end

function TechniqueMath.masteryDamageMult(level: number): number
	return 1 + level * 0.02
end

function TechniqueMath.masteryCooldownMult(level: number): number
	return 1 - level * 0.01
end

return table.freeze(TechniqueMath)
