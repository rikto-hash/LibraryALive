--!strict
-- Per-player persistence for profile Stats.
-- v1: the shared world library is session-only; carried books are session-only.
-- NOTE: for a public launch use ProfileStore (session locking). This is a compact
--       starting point, safe enough for a small co-op server.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ProfileTemplate = require(script.Parent.Parent.Data.ProfileTemplate)

local STORE_NAME = "PlayerProfiles_v1"
local store = DataStoreService:GetDataStore(STORE_NAME)

local profiles: { [number]: any } = {}
local lastAccrual: { [number]: number } = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function retry(fn: () -> any): (boolean, any)
	local lastErr
	for i = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(i)
	end
	return false, lastErr
end

-- Fill missing keys from the template (one level into Stats).
local function prepare(data: any): any
	data = if type(data) == "table" then data else {}
	for key, value in pairs(ProfileTemplate) do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" then
			for subKey, subValue in pairs(value) do
				if data[key][subKey] == nil then
					data[key][subKey] = deepCopy(subValue)
				end
			end
		end
	end
	-- No migrations yet. When SchemaVersion bumps, add steps here.
	data.SchemaVersion = ProfileTemplate.SchemaVersion
	return data
end

local function keyFor(player: Player): string
	return "User_" .. player.UserId
end

local function loadProfile(player: Player)
	if profiles[player.UserId] then
		return profiles[player.UserId]
	end

	local ok, data = retry(function()
		return store:UpdateAsync(keyFor(player), function(old)
			local result = prepare(old)
			result.Stats.SessionsPlayed = (result.Stats.SessionsPlayed or 0) + 1
			return result
		end)
	end)

	if not ok then
		warn("[DataService] load failed for", player.Name, data)
		data = deepCopy(ProfileTemplate)
	end

	profiles[player.UserId] = data
	lastAccrual[player.UserId] = time()
	return data
end

local function saveProfile(player: Player)
	local data = profiles[player.UserId]
	if not data then
		return
	end

	local now = time()
	local last = lastAccrual[player.UserId] or now
	data.Stats.SecondsPlayed = (data.Stats.SecondsPlayed or 0) + math.max(0, now - last)
	lastAccrual[player.UserId] = now

	local ok, err = retry(function()
		return store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[DataService] save failed for", player.Name, err)
	end
end

local DataService = {}

function DataService.get(player: Player): any
	return profiles[player.UserId]
end

function DataService.getStat(player: Player, statName: string): number
	local data = profiles[player.UserId]
	local stats = data and data.Stats
	if stats and type(stats[statName]) == "number" then
		return stats[statName]
	end
	return 0
end

function DataService.incrementStat(player: Player, statName: string, amount: number?)
	local data = profiles[player.UserId]
	local stats = data and data.Stats
	if not stats then
		return
	end
	stats[statName] = (stats[statName] or 0) + (amount or 1)
end

function DataService.init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		profiles[player.UserId] = nil
		lastAccrual[player.UserId] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadProfile, player)
	end
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			saveProfile(player)
		end
		task.wait(2)
	end)
end

return DataService
