--!strict
-- Every number the table, the physics and the rules share.
-- Table units are INCHES on a 9-foot table (100 x 50 playing surface),
-- origin at the centre, x along the length. Studs only appear where the
-- world is built (STUDS_PER_INCH).

local Config = {}

Config.TABLE_LENGTH = 100
Config.TABLE_WIDTH = 50
Config.BALL_RADIUS = 1.125

-- Cushions are where a ball's CENTRE bounces.
Config.HALF_X = Config.TABLE_LENGTH / 2 - Config.BALL_RADIUS
Config.HALF_Y = Config.TABLE_WIDTH / 2 - Config.BALL_RADIUS

-- A ball is pocketed when its centre comes within the capture radius of a
-- pocket point. Mouths are the gaps in the cushion that let it get there.
Config.POCKETS = {
	{ x = -50, y = -25, r = 2.6 },
	{ x = 0, y = -25.6, r = 2.4 },
	{ x = 50, y = -25, r = 2.6 },
	{ x = -50, y = 25, r = 2.6 },
	{ x = 0, y = 25.6, r = 2.4 },
	{ x = 50, y = 25, r = 2.6 },
}
Config.CORNER_MOUTH = 3.6 -- distance from a corner along each rail with no cushion
Config.SIDE_MOUTH = 2.4 -- half-width of the side pocket gap

-- Feel. Tuned so a full-power break crosses the table a few times and a
-- soft shot dies in a foot or two.
Config.MAX_SPEED = 260 -- in/s at full power
Config.ROLL_DECEL = 9 -- in/s^2, rolling resistance
Config.DRAG = 0.18 -- 1/s, extra slowdown proportional to speed
Config.BALL_RESTITUTION = 0.94
Config.CUSHION_RESTITUTION = 0.72
Config.STOP_SPEED = 0.4

Config.STEP = 1 / 480 -- physics substep
Config.FRAME = 1 / 60 -- playback frame
Config.MAX_TIME = 25 -- a shot can never run longer than this

-- World scale. 0.12 studs per inch puts the table at 12 x 6 studs and the
-- rail top at about the height of a standing character's waist.
Config.STUDS_PER_INCH = 0.12

-- Head spot and foot spot.
Config.HEAD_SPOT = { x = -25, y = 0 }
Config.FOOT_SPOT = { x = 25, y = 0 }

Config.COLORS = {
	[0] = { 245, 243, 235 },
	[1] = { 247, 197, 31 },
	[2] = { 31, 76, 196 },
	[3] = { 214, 38, 38 },
	[4] = { 102, 41, 150 },
	[5] = { 245, 120, 28 },
	[6] = { 22, 125, 64 },
	[7] = { 128, 31, 31 },
	[8] = { 20, 20, 20 },
}

function Config.colorOf(n: number): { number }
	return Config.COLORS[if n > 8 then n - 8 else n]
end

function Config.groupOf(n: number): string?
	if n >= 1 and n <= 7 then
		return "solids"
	elseif n >= 9 and n <= 15 then
		return "stripes"
	end
	return nil
end

return Config
