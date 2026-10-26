--!strict
-- 8-ball, the bar rules most people play. Pure: takes the state and what
-- happened on the table, returns the next state and what to tell everyone.
--
-- Fouls (ball in hand for the other player):
--   the cue ball goes in; the cue ball hits nothing; the first ball hit is
--   not yours (on an open table, the 8 first is the foul); nothing went in
--   and nothing touched a cushion after contact.
-- The 8: in legally after clearing your group wins. In early, or on a foul,
-- loses.

local Config = if script then require(script.Parent.Config) else (_G :: any).requireShared("Config")

export type State = {
	players: { string },
	turn: number,
	groups: { [number]: string },
	open: boolean,
	ballInHand: boolean,
	winner: number?,
	isBreak: boolean,
}

local Rules = {}

function Rules.new(players: { string }): State
	return { players = players, turn = 1, groups = {}, open = true, ballInHand = false, winner = nil, isBreak = true }
end

local function other(n: number, count: number): number
	if count < 2 then
		return 1
	end
	return if n == 1 then 2 else 1
end

-- How many of `group` are still on the table?
local function remaining(onTable: { [number]: boolean }, group: string): number
	local c = 0
	for id, on in onTable do
		if on and Config.groupOf(id) == group then
			c += 1
		end
	end
	return c
end

-- events: from Physics.shoot. onTable: ball id -> still on table AFTER the shot.
function Rules.apply(s: State, events: any, onTable: { [number]: boolean }): (State, string)
	local shooter = s.turn
	local name = s.players[shooter]
	local mine = s.groups[shooter]
	local pocketed: { number } = events.pocketed

	local foul: string? = nil
	if events.scratch then
		foul = "Scratch"
	elseif events.firstHit == nil then
		foul = "No ball hit"
	elseif not s.open and mine then
		-- Your target is your group, or the 8 once your group was already
		-- cleared BEFORE this shot.
		local leftBefore = remaining(onTable, mine)
		for _, id in pocketed do
			if Config.groupOf(id) == mine then
				leftBefore += 1
			end
		end
		local ok = if leftBefore == 0 then events.firstHit == 8 else Config.groupOf(events.firstHit) == mine
		if not ok then
			foul = "Hit the wrong ball first"
		end
	elseif s.open and events.firstHit == 8 and not s.isBreak then
		foul = "Hit the 8 first"
	end
	if not foul and #pocketed == 0 and not events.railAfterContact and not s.isBreak then
		foul = "No rail after contact"
	end

	local next = table.clone(s)
	next.groups = table.clone(s.groups)
	next.isBreak = false
	next.ballInHand = false

	-- The 8 decides the game.
	if table.find(pocketed, 8) then
		if s.isBreak and not events.scratch then
			-- On the break the 8 is spotted rather than ending the game; the
			-- server puts it back. Keep shooting.
			return next, name .. " made the 8 on the break. It's spotted, keep shooting."
		end
		local clearedFirst = mine ~= nil and remaining(onTable, mine) == 0
		if clearedFirst and not foul then
			next.winner = shooter
			return next, name .. " sinks the 8 and wins!"
		end
		next.winner = other(shooter, #s.players)
		local why = if foul then foul:lower() .. " on the 8" else "the 8 went in early"
		return next, name .. " loses: " .. why .. "."
	end

	if foul then
		next.turn = other(shooter, #s.players)
		next.ballInHand = true
		return next, foul .. ". Ball in hand for " .. next.players[next.turn] .. "."
	end

	-- Assign groups on an open table from the first ball made.
	if s.open and not s.isBreak and #pocketed > 0 then
		local g = Config.groupOf(pocketed[1])
		if g then
			next.open = false
			next.groups[shooter] = g
			if #s.players > 1 then
				next.groups[other(shooter, #s.players)] = if g == "solids" then "stripes" else "solids"
			end
			return next, name .. " is " .. g .. ". Keep shooting."
		end
	end

	-- Did the shooter make one of their own (or anything, on an open table)?
	local madeOwn = false
	for _, id in pocketed do
		local g = Config.groupOf(id)
		if g and (next.open or g == next.groups[shooter]) then
			madeOwn = true
		end
	end
	if madeOwn then
		return next, name .. " keeps shooting."
	end
	next.turn = other(shooter, #s.players)
	return next, next.players[next.turn] .. " to shoot."
end

return Rules
