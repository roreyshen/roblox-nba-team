-- Global leaderboards (OrderedDataStore), cached and refreshed every minute:
--   best = highest team rating ever drafted, duel = total duel wins.
-- Players in this server are always merged in, so the board works even without DataStores.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = {}

export type Entry = { userId: number, name: string, value: number }

local TOP_N = 10
local REFRESH_SECONDS = 60

local BOARDS = {
	best = { storeName = "BestOVR_v1", field = "BestOVR" },
	duel = { storeName = "DuelWins_v1", field = "DuelWins" },
}

type Board = { store: OrderedDataStore?, cache: { Entry }, field: string }

local boards: { [string]: Board } = {}
for id, def in BOARDS do
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(def.storeName)
	end)
	boards[id] = { store = if ok then store else nil, cache = {}, field = def.field }
end

local nameCache: { [number]: string } = {}
local getOnlineProfiles: () -> { [Player]: { [string]: any } } = function()
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
			if entry.value > e.value then
				e.value = entry.value
			end
			return
		end
	end
	table.insert(list, { userId = entry.userId, name = entry.name, value = entry.value })
end

local function refresh(board: Board)
	local store = board.store
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP_N)
	end)
	if not ok then
		warn("[Leaderboard] Fetch failed:", pages)
		return
	end
	local fresh: { Entry } = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(fresh, { userId = userId, name = nameFor(userId), value = item.value })
		end
	end
	board.cache = fresh
end

function LeaderboardService.init(onlineProfiles: () -> { [Player]: { [string]: any } })
	getOnlineProfiles = onlineProfiles
	task.spawn(function()
		while true do
			for _, board in boards do
				refresh(board)
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

-- Record a new value (only ever goes up).
function LeaderboardService.submit(boardId: string, player: Player, value: number)
	local board = boards[boardId]
	if not board then
		return
	end
	nameCache[player.UserId] = player.Name
	upsert(board.cache, { userId = player.UserId, name = player.Name, value = value })
	local store = board.store
	if not store then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(tostring(player.UserId), function(old)
				if old and old >= value then
					return nil -- keep the higher value already saved
				end
				return value
			end)
		end)
		if not ok then
			warn("[Leaderboard] Submit failed:", err)
		end
	end)
end

function LeaderboardService.top(boardId: string): { Entry }
	local board = boards[boardId]
	if not board then
		return {}
	end
	local merged: { Entry } = {}
	for _, e in board.cache do
		upsert(merged, e)
	end
	for player, data in getOnlineProfiles() do
		local value = data[board.field]
		if type(value) == "number" and value > 0 then
			upsert(merged, { userId = player.UserId, name = player.Name, value = value })
		end
	end
	table.sort(merged, function(a, b)
		return a.value > b.value
	end)
	local out = {}
	for i = 1, math.min(TOP_N, #merged) do
		out[i] = merged[i]
	end
	return out
end

return LeaderboardService
