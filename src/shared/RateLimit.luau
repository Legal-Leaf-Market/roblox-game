--!strict
-- ModuleScript: ReplicatedStorage > Shared > RateLimit
-- Fixed-window rate limiter keyed by userId. Every remote handler on the
-- server wraps itself in one of these; a client that spams a remote gets its
-- calls dropped instead of getting server work done.

local RateLimit = {}
RateLimit.__index = RateLimit

type Entry = { count: number, windowStart: number }

export type RateLimit = typeof(setmetatable({} :: {
	_max: number,
	_window: number,
	_entries: { [number]: Entry },
}, RateLimit))

function RateLimit.new(maxPerWindow: number, windowSeconds: number): RateLimit
	return setmetatable({
		_max = maxPerWindow,
		_window = windowSeconds,
		_entries = {},
	}, RateLimit)
end

function RateLimit.Allow(self: RateLimit, userId: number): boolean
	local now = os.clock()
	local entry = self._entries[userId]
	if entry == nil or (now - entry.windowStart) >= self._window then
		self._entries[userId] = { count = 1, windowStart = now }
		return true
	end
	if entry.count >= self._max then
		return false
	end
	entry.count += 1
	return true
end

function RateLimit.Forget(self: RateLimit, userId: number)
	self._entries[userId] = nil
end

return RateLimit
