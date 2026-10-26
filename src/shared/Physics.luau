--!strict
-- The table, simulated. Pure Luau with no Roblox APIs, so the server runs it
-- for real and the local test runner runs exactly the same file.
--
-- The SERVER simulates every shot. Clients only send an angle and a power
-- and play back the frames the server returns, so nobody can send a ball
-- into a pocket by editing their own copy of the table.

local Config = if script then require(script.Parent.Config) else (_G :: any).requireShared("Config")

export type Ball = { id: number, x: number, y: number, vx: number, vy: number, pocketed: boolean }
export type Events = {
	firstHit: number?,
	pocketed: { number },
	railAfterContact: boolean,
	scratch: boolean,
}
export type Result = { frames: { { number } }, events: Events, duration: number }

local Physics = {}

local R = Config.BALL_RADIUS
local D2 = (2 * R) * (2 * R)

function Physics.rack(): { Ball }
	-- Standard 8-ball rack: apex on the foot spot, 8 in the centre, one solid
	-- and one stripe in the back corners. The rest are fixed rather than
	-- random so a rack is the same for both players.
	local order = { 1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15 }
	-- Back corners (indices 11 and 15) must be one solid and one stripe:
	-- 5 and 15 here. Middle of row three (index 5) is the 8.
	local balls: { Ball } = {}
	local dx = math.sqrt(3) * R + 0.01
	local i = 1
	for row = 0, 4 do
		for col = 0, row do
			local n = order[i]
			i += 1
			table.insert(balls, {
				id = n,
				x = Config.FOOT_SPOT.x + row * dx,
				y = (col - row / 2) * (2 * R + 0.01),
				vx = 0,
				vy = 0,
				pocketed = false,
			})
		end
	end
	table.insert(balls, 1, { id = 0, x = Config.HEAD_SPOT.x, y = 0, vx = 0, vy = 0, pocketed = false })
	return balls
end

function Physics.find(balls: { Ball }, id: number): Ball?
	for _, b in balls do
		if b.id == id then
			return b
		end
	end
	return nil
end

-- Can the cue ball sit at (x, y)? On the cloth and not touching anything.
function Physics.canPlace(balls: { Ball }, x: number, y: number): boolean
	if math.abs(x) > Config.HALF_X or math.abs(y) > Config.HALF_Y then
		return false
	end
	for _, b in balls do
		if b.id ~= 0 and not b.pocketed then
			local ddx, ddy = b.x - x, b.y - y
			if ddx * ddx + ddy * ddy < D2 * 1.02 then
				return false
			end
		end
	end
	return true
end

local function inMouthX(y: number): boolean
	return math.abs(y) > Config.TABLE_WIDTH / 2 - Config.CORNER_MOUTH
end
local function inMouthY(x: number): boolean
	return math.abs(x) > Config.TABLE_LENGTH / 2 - Config.CORNER_MOUTH or math.abs(x) < Config.SIDE_MOUTH
end

local function snapshot(balls: { Ball }): { number }
	-- Flat array: x1, y1, x2, y2, ... with pocketed balls at NaN-free sentinel 999.
	local f = table.create(#balls * 2)
	for _, b in balls do
		if b.pocketed then
			table.insert(f, 999)
			table.insert(f, 999)
		else
			table.insert(f, math.floor(b.x * 100 + 0.5) / 100)
			table.insert(f, math.floor(b.y * 100 + 0.5) / 100)
		end
	end
	return f
end

-- Strike the cue ball. angle in radians (0 = +x), power 0..1.
-- spin: where the tip meets the cue ball, each -1..1.
--   top > 0 is follow (hit high: it rolls on through the object ball),
--   top < 0 is draw (hit low: it comes back). side > 0 is right english,
--   which kicks the cue ball off a cushion toward its right.
-- A simple model on purpose: the spin is spent at the first ball contact
-- (follow/draw) and at cushions (side), and fades as the ball travels.
function Physics.shoot(balls: { Ball }, angle: number, power: number, top: number?, side: number?): Result
	local cue = Physics.find(balls, 0)
	assert(cue and not cue.pocketed, "cue ball must be on the table")
	power = math.clamp(power, 0.02, 1)
	local speed = Config.MAX_SPEED * power
	cue.vx, cue.vy = math.cos(angle) * speed, math.sin(angle) * speed
	local spinTop = math.clamp(top or 0, -1, 1)
	local spinSide = math.clamp(side or 0, -1, 1)
	local shotDx, shotDy = math.cos(angle), math.sin(angle)

	local events: Events = { firstHit = nil, pocketed = {}, railAfterContact = false, scratch = false }
	local frames = { snapshot(balls) }
	local t, sinceFrame = 0, 0
	local step = Config.STEP

	while t < Config.MAX_TIME do
		local moving = false

		-- Move and slow down.
		for _, b in balls do
			if not b.pocketed then
				local sp = math.sqrt(b.vx * b.vx + b.vy * b.vy)
				if sp > 0 then
					local ns = sp - (Config.ROLL_DECEL + Config.DRAG * sp) * step
					if ns <= Config.STOP_SPEED then
						b.vx, b.vy = 0, 0
					else
						local k = ns / sp
						b.vx, b.vy = b.vx * k, b.vy * k
						moving = true
					end
					b.x += b.vx * step
					b.y += b.vy * step
				end
			end
		end
		local fade = 1 - Config.SPIN_FADE * step
		spinTop *= fade
		spinSide *= fade

		-- Ball against ball.
		for i = 1, #balls do
			local a = balls[i]
			if not a.pocketed then
				for j = i + 1, #balls do
					local b = balls[j]
					if not b.pocketed then
						local nx, ny = b.x - a.x, b.y - a.y
						local d2 = nx * nx + ny * ny
						if d2 < D2 and d2 > 1e-9 then
							local d = math.sqrt(d2)
							nx, ny = nx / d, ny / d
							local rel = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny
							if rel > 0 then
								local j2 = rel * (1 + Config.BALL_RESTITUTION) / 2
								a.vx -= j2 * nx
								a.vy -= j2 * ny
								b.vx += j2 * nx
								b.vy += j2 * ny
								if a.id == 0 or b.id == 0 then
									-- Follow or draw, spent on the cue ball's first contact.
									if spinTop ~= 0 then
										local cueB = if a.id == 0 then a else b
										local kick = spinTop * Config.FOLLOW_DRAW * rel
										cueB.vx += shotDx * kick
										cueB.vy += shotDy * kick
										spinTop = 0
									end
								end
								if events.firstHit == nil then
									if a.id == 0 then
										events.firstHit = b.id
									elseif b.id == 0 then
										events.firstHit = a.id
									end
								end
							end
							-- Push apart so they never stick.
							local push = (2 * R - d) / 2
							a.x -= nx * push
							a.y -= ny * push
							b.x += nx * push
							b.y += ny * push
						end
					end
				end
			end
		end

		-- Cushions and pockets.
		for _, b in balls do
			if not b.pocketed then
				for _, p in Config.POCKETS do
					local px, py = b.x - p.x, b.y - p.y
					if px * px + py * py < p.r * p.r then
						b.pocketed = true
						b.vx, b.vy = 0, 0
						table.insert(events.pocketed, b.id)
						if b.id == 0 then
							events.scratch = true
						end
						break
					end
				end
				if not b.pocketed then
					local hit = false
					if math.abs(b.x) > Config.HALF_X and not inMouthX(b.y) then
						b.x = math.sign(b.x) * Config.HALF_X
						local into = math.abs(b.vx)
						b.vx = -b.vx * Config.CUSHION_RESTITUTION
						if b.id == 0 and spinSide ~= 0 then
							-- Right english sends the rebound to the shooter's right.
							-- Travelling (sx, 0), right is (0, sx) in table units,
							-- which is the camera's right in the world.
							b.vy += math.sign(b.x) * spinSide * Config.SIDE_KICK * into
							spinSide *= 0.5
						end
						hit = true
					end
					if math.abs(b.y) > Config.HALF_Y and not inMouthY(b.x) then
						b.y = math.sign(b.y) * Config.HALF_Y
						local into = math.abs(b.vy)
						b.vy = -b.vy * Config.CUSHION_RESTITUTION
						if b.id == 0 and spinSide ~= 0 then
							b.vx += -math.sign(b.y) * spinSide * Config.SIDE_KICK * into
							spinSide *= 0.5
						end
						hit = true
					end
					if hit and events.firstHit ~= nil then
						events.railAfterContact = true
					end
					-- Anything that slipped past a mouth without being captured
					-- has left the table: count it as pocketed.
					if math.abs(b.x) > Config.TABLE_LENGTH / 2 + 3 or math.abs(b.y) > Config.TABLE_WIDTH / 2 + 3 then
						b.pocketed = true
						b.vx, b.vy = 0, 0
						table.insert(events.pocketed, b.id)
						if b.id == 0 then
							events.scratch = true
						end
					end
				end
			end
		end

		t += step
		sinceFrame += step
		if sinceFrame >= Config.FRAME then
			sinceFrame -= Config.FRAME
			table.insert(frames, snapshot(balls))
		end
		if not moving then
			break
		end
	end

	table.insert(frames, snapshot(balls))
	for _, b in balls do
		b.vx, b.vy = 0, 0
	end
	return { frames = frames, events = events, duration = #frames * Config.FRAME }
end

-- For the aiming guide: where does a ball travelling from (x, y) along angle
-- first touch another ball or a cushion? Returns the ghost-ball centre and
-- the id it would hit (nil for a cushion).
function Physics.predict(balls: { Ball }, x: number, y: number, angle: number): (number, number, number?)
	local dx, dy = math.cos(angle), math.sin(angle)
	local best, bestId = math.huge, nil
	for _, b in balls do
		if b.id ~= 0 and not b.pocketed then
			local ox, oy = b.x - x, b.y - y
			local along = ox * dx + oy * dy
			if along > 0 then
				local perp2 = ox * ox + oy * oy - along * along
				if perp2 < D2 then
					local hit = along - math.sqrt(D2 - perp2)
					if hit < best then
						best, bestId = hit, b.id
					end
				end
			end
		end
	end
	local tx = if dx > 0 then (Config.HALF_X - x) / dx elseif dx < 0 then (-Config.HALF_X - x) / dx else math.huge
	local ty = if dy > 0 then (Config.HALF_Y - y) / dy elseif dy < 0 then (-Config.HALF_Y - y) / dy else math.huge
	local wall = math.min(tx, ty)
	if wall < best then
		best, bestId = wall, nil
	end
	return x + dx * best, y + dy * best, bestId
end

return Physics
