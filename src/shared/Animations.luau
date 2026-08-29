--!strict
-- ModuleScript: ReplicatedStorage > Shared > Animations
-- Every animation the game plays, by slot name. NO invented asset ids:
-- each slot ships as REPLACE_ME until a real animation is uploaded, and
-- the loader (client Modules/AnimUtil) silently skips placeholders, so
-- the game is fully playable before any animation exists.
--
-- To wire one up: upload the animation to the game's group/owner account,
-- then paste its id in place of REPLACE_ME (keep the rbxassetid:// prefix).
--
-- Recommended priorities: Action for attacks/casts, Movement for run and
-- dodge, Idle for meditation idle.

local REPLACE_ME = "rbxassetid://REPLACE_ME"

local Animations = {
	-- Movement
	run = REPLACE_ME, -- looped, forward-leaning cultivator run
	sprint = REPLACE_ME, -- looped, faster martial sprint
	dodge = REPLACE_ME, -- short directional burst

	-- Meditation
	meditateEnter = REPLACE_ME, -- settle into a cross-legged seat
	meditateIdle = REPLACE_ME, -- looped seated breathing
	meditateExit = REPLACE_ME, -- rise from the seat

	-- Unarmed / sword combat
	lightAttack1 = REPLACE_ME,
	lightAttack2 = REPLACE_ME,
	lightAttack3 = REPLACE_ME, -- the finisher swing
	heavyAttack = REPLACE_ME, -- long windup, big follow-through
	block = REPLACE_ME, -- looped guard pose
	hitReact = REPLACE_ME, -- flinch on taking damage

	-- Techniques & cultivation
	castTechnique = REPLACE_ME, -- generic one-hand seal + palm push
	breakthrough = REPLACE_ME, -- arms wide, qi eruption
	auraRelease = REPLACE_ME, -- stance for releasing pressure
}

return table.freeze(Animations)
