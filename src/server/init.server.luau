--!strict
-- The table's referee. Owns the balls, the turn and the rules; clients only
-- ever send an aim and a power, or where they want the cue ball in hand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Physics = require(Shared.Physics)
local Rules = require(Shared.Rules)
local Net = require(Shared.Net)
local World = require(script.World)

Net.folder()
local Shoot, Place, Play, StateEv = Net.get("Shoot"), Net.get("Place"), Net.get("Play"), Net.get("State")

local tbl, ballFolder = World.build()

local seated: { Player } = {}
local balls = Physics.rack()
local state = Rules.new({})
local busy = false
local lastMessage = "Walk up to the table and press E to play."

local function names(): { string }
	local t = {}
	for _, p in seated do
		table.insert(t, p.DisplayName)
	end
	return t
end

local function broadcast()
	local cue = Physics.find(balls, 0)
	StateEv:FireAllClients({
		players = state.players,
		userIds = (function()
			local t = {}
			for _, p in seated do
				table.insert(t, p.UserId)
			end
			return t
		end)(),
		turn = state.turn,
		groups = state.groups,
		open = state.open,
		ballInHand = state.ballInHand,
		winner = state.winner,
		busy = busy,
		message = lastMessage,
		balls = balls,
		cue = if cue then { x = cue.x, y = cue.y } else nil,
	})
end

local function newGame(breaker: number?)
	balls = Physics.rack()
	state = Rules.new(names())
	if breaker and #seated > 1 then
		state.turn = breaker
	end
	World.place(ballFolder, balls)
	lastMessage = if #seated == 0 then "Walk up to the table and press E to play."
		elseif #seated == 1 then seated[1].DisplayName .. " is practising. Press E at the table to challenge."
		else state.players[state.turn] .. " to break."
	broadcast()
end

-- The cue ball comes back after a scratch, at the head spot or the nearest
-- free spot behind it. The shooter can then move it anywhere.
local function respotCue()
	local cue = Physics.find(balls, 0) :: any
	cue.pocketed = false
	for dx = 0, 40, 2 do
		if Physics.canPlace(balls, Config.HEAD_SPOT.x - dx, 0) then
			cue.x, cue.y = Config.HEAD_SPOT.x - dx, 0
			return
		end
	end
end

local function respotEight()
	local eight = Physics.find(balls, 8) :: any
	eight.pocketed = false
	for dx = 0, 20, 0.5 do
		local ok = true
		for _, b in balls do
			if b.id ~= 8 and not b.pocketed and (b.x - (Config.FOOT_SPOT.x + dx)) ^ 2 + b.y ^ 2 < (2 * Config.BALL_RADIUS) ^ 2 then
				ok = false
			end
		end
		if ok then
			eight.x, eight.y = Config.FOOT_SPOT.x + dx, 0
			return
		end
	end
end

local function shooterIndex(player: Player): number?
	for i, p in seated do
		if p == player then
			return i
		end
	end
	return nil
end

local lastShot: { [Player]: number } = {}

Shoot.OnServerEvent:Connect(function(player: Player, angle: any, power: any, top: any, side: any)
	if busy or state.winner then
		return
	end
	if shooterIndex(player) ~= state.turn then
		return
	end
	if typeof(angle) ~= "number" or typeof(power) ~= "number" or angle ~= angle or power ~= power then
		return
	end
	-- Spin is optional; anything that is not a real number means none.
	local spinTop = if typeof(top) == "number" and top == top then math.clamp(top, -1, 1) else 0
	local spinSide = if typeof(side) == "number" and side == side then math.clamp(side, -1, 1) else 0
	if os.clock() - (lastShot[player] or 0) < 0.5 then
		return
	end
	lastShot[player] = os.clock()

	busy = true
	state.ballInHand = false
	local res = Physics.shoot(balls, angle, math.clamp(power, 0, 1), spinTop, spinSide)
	Play:FireAllClients(res.frames, (function()
		local ids = {}
		for _, b in balls do
			table.insert(ids, b.id)
		end
		return ids
	end)())
	task.wait(res.duration + 0.15)

	local onTable: { [number]: boolean } = {}
	for _, b in balls do
		if b.id ~= 0 then
			onTable[b.id] = not b.pocketed
		end
	end
	local wasBreak = state.isBreak
	local nextState, msg = Rules.apply(state, res.events, onTable)
	state = nextState
	lastMessage = msg
	if wasBreak and table.find(res.events.pocketed, 8) and not res.events.scratch then
		respotEight()
	end
	if res.events.scratch then
		respotCue()
	end
	World.place(ballFolder, balls)
	busy = false
	broadcast()

	if state.winner then
		local winner = state.winner
		task.delay(6, function()
			if state.winner == winner then
				newGame(winner)
			end
		end)
	end
end)

Place.OnServerEvent:Connect(function(player: Player, x: any, y: any)
	if busy or not state.ballInHand or shooterIndex(player) ~= state.turn then
		return
	end
	if typeof(x) ~= "number" or typeof(y) ~= "number" or x ~= x or y ~= y then
		return
	end
	if not Physics.canPlace(balls, x, y) then
		return
	end
	local cue = Physics.find(balls, 0) :: any
	cue.x, cue.y, cue.pocketed = x, y, false
	World.place(ballFolder, balls)
	broadcast()
end)

-- Join / leave at the table.
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Play or leave"
prompt.ObjectText = "Pool table"
prompt.HoldDuration = 0.2
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false
prompt.Parent = tbl:FindFirstChild("Cloth")

prompt.Triggered:Connect(function(player: Player)
	local i = shooterIndex(player)
	if i then
		table.remove(seated, i)
	elseif #seated < 2 then
		table.insert(seated, player)
	else
		return
	end
	newGame(nil)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local i = shooterIndex(player)
	if i then
		table.remove(seated, i)
		newGame(nil)
	end
end)

Players.PlayerAdded:Connect(function()
	task.wait(2)
	broadcast()
end)

newGame(nil)
