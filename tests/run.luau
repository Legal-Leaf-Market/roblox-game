-- Runs the real shared modules. tools/luau-run/target/release/luau-run tests/run.luau
local Config = requireShared("Config")
local Physics = requireShared("Physics")
local Rules = requireShared("Rules")

local fails, passes = 0, 0
local function ok(c, m)
	if c then passes += 1 else fails += 1; print("FAIL " .. m) end
end

-- Rack: 16 balls, none overlapping, 8 in the middle of row three.
local balls = Physics.rack()
ok(#balls == 16, "rack has 16 balls")
local ids = {}
for _, b in balls do ids[b.id] = true end
for n = 0, 15 do ok(ids[n], "ball " .. n .. " racked") end
for i = 1, #balls do for j = i + 1, #balls do
	local a, b = balls[i], balls[j]
	local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
	ok(d >= 2 * Config.BALL_RADIUS - 1e-6, ("balls %d,%d overlap at rest"):format(a.id, b.id))
end end

-- Break: full power straight at the rack. Things move, the cue hits the apex
-- ball first, the shot ends, and every ball is on the cloth or in a pocket.
local res = Physics.shoot(balls, 0, 1)
ok(res.events.firstHit == 1, "break hits the apex ball first (got " .. tostring(res.events.firstHit) .. ")")
ok(res.duration > 1 and res.duration < Config.MAX_TIME, "break duration is sane: " .. res.duration)
local moved = 0
for _, b in balls do
	if b.pocketed then
		moved += 1
	else
		ok(math.abs(b.x) <= Config.HALF_X + 1e-6 and math.abs(b.y) <= Config.HALF_Y + 1e-6, "ball " .. b.id .. " stayed on the cloth")
		if b.x < 20 then moved += 1 end
	end
end
ok(moved >= 5, "the break spreads the rack (" .. moved .. " balls left the rack area)")
print(("break: %.1fs, %d pocketed, first frame %d values"):format(res.duration, #res.events.pocketed, #res.frames[1]))

-- A ball rolled straight at a corner goes in.
local t = { { id = 0, x = 0, y = 0, vx = 0, vy = 0, pocketed = false } }
local r2 = Physics.shoot(t, math.atan2(25, 50), 0.6)
ok(r2.events.scratch and t[1].pocketed, "cue rolled into a corner is pocketed")

-- A soft shot stops on the table and never touches anything.
local t2 = { { id = 0, x = -30, y = 0, vx = 0, vy = 0, pocketed = false } }
local r3 = Physics.shoot(t2, 0, 0.05)
ok(not t2[1].pocketed and r3.events.firstHit == nil, "soft shot rolls and stops")
ok(t2[1].x > -30 and t2[1].x < 0, "soft shot travels a short way: " .. t2[1].x)

-- A cushion bounce comes back.
local t3 = { { id = 0, x = 30, y = 5, vx = 0, vy = 0, pocketed = false } }
Physics.shoot(t3, 0, 0.5)
ok(t3[1].x < Config.HALF_X and not t3[1].pocketed, "ball bounces off the end cushion")

-- predict: aiming straight at a ball reports that ball.
local p = { { id = 0, x = -20, y = 0, vx = 0, vy = 0, pocketed = false }, { id = 3, x = 10, y = 0, vx = 0, vy = 0, pocketed = false } }
local gx, _, hit = Physics.predict(p, -20, 0, 0)
ok(hit == 3 and math.abs(gx - (10 - 2 * Config.BALL_RADIUS)) < 1e-6, "predict finds the ghost ball")

-- canPlace refuses overlaps and the rail.
ok(not Physics.canPlace(p, 10.5, 0), "cannot place on top of a ball")
ok(not Physics.canPlace(p, 60, 0), "cannot place off the cloth")
ok(Physics.canPlace(p, -30, 0), "can place in open cloth")

-- Rules.
local function onTable(list)
	local m = {}
	for n = 1, 15 do m[n] = true end
	for _, n in list do m[n] = false end
	return m
end
local s = Rules.new({ "Steven", "Jake" })
local s2, msg = Rules.apply(s, { firstHit = 1, pocketed = { 3 }, railAfterContact = true, scratch = false }, onTable({ 3 }))
ok(s2.turn == 1 and s2.open, "making a ball on the break keeps the turn, table stays open: " .. msg)
local s3, msg3 = Rules.apply(s2, { firstHit = 10, pocketed = { 10 }, railAfterContact = true, scratch = false }, onTable({ 3, 10 }))
ok(s3.groups[1] == "stripes" and s3.groups[2] == "solids" and s3.turn == 1, "first ball made assigns groups: " .. msg3)
local s4, msg4 = Rules.apply(s3, { firstHit = 2, pocketed = {}, railAfterContact = true, scratch = false }, onTable({ 3, 10 }))
ok(s4.turn == 2 and s4.ballInHand, "hitting the other group first is a foul: " .. msg4)
local s5, msg5 = Rules.apply(s4, { firstHit = 4, pocketed = {}, railAfterContact = false, scratch = false }, onTable({ 3, 10 }))
ok(s5.turn == 1 and s5.ballInHand, "no rail after contact is a foul: " .. msg5)
local s6, msg6 = Rules.apply(s5, { firstHit = 11, pocketed = { 8 }, railAfterContact = true, scratch = false }, onTable({ 3, 10, 8 }))
ok(s6.winner == 2, "the 8 early loses: " .. msg6)
local s7, msg7 = Rules.apply(s5, { firstHit = 11, pocketed = {}, railAfterContact = true, scratch = true }, onTable({ 3, 10 }))
ok(s7.turn == 2 and s7.ballInHand, "scratch passes ball in hand: " .. msg7)
-- Steven clears stripes, then legally makes the 8.
local cleared = {}
for n = 9, 15 do table.insert(cleared, n) end
local sW = table.clone(s5); sW.turn = 1
local after = onTable(cleared); after[8] = false
local sWin, msgWin = Rules.apply(sW, { firstHit = 8, pocketed = { 8 }, railAfterContact = true, scratch = false }, after)
ok(sWin.winner == 1, "the 8 after clearing wins: " .. msgWin)
-- Same, but scratching on the 8 loses.
local sL, msgL = Rules.apply(sW, { firstHit = 8, pocketed = { 8, 0 }, railAfterContact = true, scratch = true }, after)
ok(sL.winner == 2, "scratching on the 8 loses: " .. msgL)
-- Practice: one player never passes the turn.
local solo = Rules.new({ "Steven" })
local so2 = Rules.apply(solo, { firstHit = nil, pocketed = {}, railAfterContact = false, scratch = false }, onTable({}))
ok(so2.turn == 1, "practice keeps the one player shooting")

-- Spin. Straight shot into a ball: plain stops dead, follow goes on, draw comes back.
local function straight(top)
	local t = { { id = 0, x = -20, y = 0, vx = 0, vy = 0, pocketed = false }, { id = 5, x = 0, y = 0, vx = 0, vy = 0, pocketed = false } }
	Physics.shoot(t, 0, 0.14, top, 0)
	return t[1].x
end
local plain, follow, draw = straight(0), straight(1), straight(-1)
ok(follow > plain + 3, ("follow rolls on through (%.1f vs %.1f)"):format(follow, plain))
ok(draw < plain - 3, ("draw comes back (%.1f vs %.1f)"):format(draw, plain))
-- Side spin changes a straight-on cushion rebound; left and right go opposite ways.
local function rail(side)
	local t = { { id = 0, x = 38, y = 0, vx = 0, vy = 0, pocketed = false } }
	Physics.shoot(t, 0, 0.15, 0, side)
	return t[1].y
end
local r0, rR, rL = rail(0), rail(1), rail(-1)
ok(math.abs(r0) < 0.01, "no english: straight back")
ok(rR > 1 and rL < -1, ("right english goes right, left goes left (%.1f, %.1f)"):format(rR, rL))

print(("%d passed, %d failed"):format(passes, fails))
if fails > 0 then error("tests failed") end
