--!strict
-- ModuleScript: ReplicatedStorage > Shared > StatCalc
-- Combines path + race + equipped talents into one Mods table. Pure and
-- shared: the server uses it as the authority, the client uses the same
-- function for previews, so the numbers a player sees are the numbers
-- the server enforces.

local Types = require(script.Parent.Types)
local Paths = require(script.Parent.Data.Paths)
local Races = require(script.Parent.Data.Races)
local Talents = require(script.Parent.Data.Talents)

local StatCalc = {}

function StatCalc.identity(): Types.Mods
	return {
		maxQiMult = 1,
		qiRegenMult = 1,
		xpMult = 1,
		damageMult = 1,
		qiCostMult = 1,
		cooldownMult = 1,
		defenseBonus = 0,
		maxHealthBonus = 0,
		walkSpeedBonus = 0,
		categoryDamage = {},
		elementDamage = {},
	}
end

function StatCalc.combine(path: string?, raceId: string, talentIds: { string }): Types.Mods
	local mods = StatCalc.identity()

	local pathDef = if path then Paths[path] else nil
	if pathDef then
		mods.qiRegenMult *= pathDef.qiRegenMult
		mods.damageMult *= pathDef.damageMult
		mods.cooldownMult *= pathDef.cooldownMult
	end

	local race = Races.statsFor(raceId)
	mods.maxQiMult *= race.maxQiMult
	mods.qiRegenMult *= race.qiRegenMult
	mods.xpMult *= race.xpMult
	mods.damageMult *= race.damageMult
	mods.qiCostMult *= race.qiCostMult
	mods.cooldownMult *= race.cooldownMult
	mods.defenseBonus += race.defenseBonus
	mods.maxHealthBonus += race.maxHealthBonus
	mods.walkSpeedBonus += race.walkSpeedBonus

	for _, talentId in talentIds do
		local talent = Talents.get(talentId)
		if talent == nil then
			continue
		end
		mods.maxQiMult *= talent.maxQiMult or 1
		mods.qiRegenMult *= talent.qiRegenMult or 1
		mods.xpMult *= talent.xpMult or 1
		mods.damageMult *= talent.damageMult or 1
		mods.qiCostMult *= talent.qiCostMult or 1
		mods.cooldownMult *= talent.cooldownMult or 1
		mods.defenseBonus += talent.defenseBonus or 0
		mods.maxHealthBonus += talent.maxHealthBonus or 0
		mods.walkSpeedBonus += talent.walkSpeedBonus or 0
		if talent.categoryDamage then
			for category, mult in talent.categoryDamage do
				mods.categoryDamage[category] = (mods.categoryDamage[category] or 1) * mult
			end
		end
		if talent.elementDamage then
			for element, mult in talent.elementDamage do
				mods.elementDamage[element] = (mods.elementDamage[element] or 1) * mult
			end
		end
	end

	return mods
end

-- Can this element be woven by this character? Path-locked elements open up
-- when the equipped race's affinity matches.
function StatCalc.elementAllowed(elementPath: string?, playerPath: string?, raceId: string, elementId: string): boolean
	if elementPath == nil then
		return true
	end
	if elementPath == playerPath then
		return true
	end
	local race = Races.get(raceId)
	if race and race.affinity == elementId then
		return true
	end
	return false
end

return table.freeze(StatCalc)
