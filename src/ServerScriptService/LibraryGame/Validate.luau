--!strict
-- Small validation helpers for anything a client sends to the server.

local Validate = {}

function Validate.string(value: unknown, maxLength: number): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if #value == 0 or #value > maxLength then
		return nil
	end
	if utf8.len(value) == nil then
		return nil
	end
	return value
end

function Validate.integer(value: unknown, min: number, max: number): number?
	if typeof(value) ~= "number" or not math.isfinite(value) then
		return nil
	end
	if value < min or value > max or value ~= math.floor(value) then
		return nil
	end
	return value
end

function Validate.vector3(value: unknown, maxMagnitude: number): Vector3?
	if typeof(value) ~= "Vector3" then
		return nil
	end
	if not (math.isfinite(value.X) and math.isfinite(value.Y) and math.isfinite(value.Z)) then
		return nil
	end
	if value.Magnitude > maxMagnitude then
		return nil
	end
	return value
end

type Bucket = { tokens: number, last: number }

-- Token bucket: allows short bursts while capping sustained calls per second.
function Validate.rateLimiter(capacity: number, windowSeconds: number)
	local refillRate = capacity / windowSeconds
	local buckets: { [Player]: Bucket } = {}

	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { tokens = capacity, last = now }
			buckets[player] = bucket
		else
			bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.last) * refillRate)
			bucket.last = now
		end
		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end
end

return Validate
