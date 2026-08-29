--!strict
-- ModuleScript: ReplicatedStorage > Shared > RateLimit
-- Fixed-window per-key rate limiter. Every remote handler that an
-- exploiter could spam sits behind one of these.

local RateLimit = {}
RateLimit.__index = RateLimit

export type RateLimit = typeof(setmetatable(
	{} :: { maxCalls: number, window: number, counts: { [number]: number }, windowStart: { [number]: number } },
	RateLimit
))

function RateLimit.new(maxCalls: number, windowSeconds: number): RateLimit
	return setmetatable({
		maxCalls = maxCalls,
		window = windowSeconds,
		counts = {},
		windowStart = {},
	}, RateLimit)
end

function RateLimit.Allow(self: RateLimit, key: number): boolean
	local now = os.clock()
	local start = self.windowStart[key]
	if start == nil or now - start >= self.window then
		self.windowStart[key] = now
		self.counts[key] = 1
		return true
	end
	local count = (self.counts[key] or 0) + 1
	self.counts[key] = count
	return count <= self.maxCalls
end

function RateLimit.Forget(self: RateLimit, key: number)
	self.counts[key] = nil
	self.windowStart[key] = nil
end

return RateLimit
