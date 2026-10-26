-- Global "best team rating" leaderboard (OrderedDataStore), cached and refreshed every minute.
-- Falls back to players in this server if DataStores are unavailable.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = {}

export type Entry = { userId: number, name: string, ovr: number }

local TOP_N = 10
local REFRESH_SECONDS = 60

local ordered: OrderedDataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("BestOVR_v1")
	end)
	if ok then
		ordered = result
	end
end

local cache: { Entry } = {}
local nameCache: { [number]: string } = {}
local getOnlineBests: () -> { Entry } = function()
	return {}
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else ("Player " .. userId)
	nameCache[userId] = result
	return result
end

local function upsert(list: { Entry }, entry: Entry)
	for _, e in list do
		if e.userId == entry.userId then
			if entry.ovr > e.ovr then
				e.ovr = entry.ovr
			end
			return
		end
	end
	table.insert(list, { userId = entry.userId, name = entry.name, ovr = entry.ovr })
end

local function refresh()
	if not ordered then
		return
	end
	local ok, pages = pcall(function()
		return ordered:GetSortedAsync(false, TOP_N)
	end)
	if not ok then
		warn("[Leaderboard] Fetch failed:", pages)
		return
	end
	local fresh: { Entry } = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(fresh, { userId = userId, name = nameFor(userId), ovr = item.value })
		end
	end
	cache = fresh
end

function LeaderboardService.init(onlineBests: () -> { Entry })
	getOnlineBests = onlineBests
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

function LeaderboardService.submit(player: Player, ovr: number)
	nameCache[player.UserId] = player.Name
	upsert(cache, { userId = player.UserId, name = player.Name, ovr = ovr })
	if not ordered then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			ordered:UpdateAsync(tostring(player.UserId), function(old)
				if old and old >= ovr then
					return nil -- keep the higher score already saved
				end
				return ovr
			end)
		end)
		if not ok then
			warn("[Leaderboard] Submit failed:", err)
		end
	end)
end

function LeaderboardService.top(): { Entry }
	local merged: { Entry } = {}
	for _, e in cache do
		upsert(merged, e)
	end
	for _, e in getOnlineBests() do
		upsert(merged, e)
	end
	table.sort(merged, function(a, b)
		return a.ovr > b.ovr
	end)
	local out = {}
	for i = 1, math.min(TOP_N, #merged) do
		out[i] = merged[i]
	end
	return out
end

return LeaderboardService
