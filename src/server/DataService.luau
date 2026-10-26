-- Loads/saves each player's coins, rerolls, refreshes, best rating, etc.
-- If DataStores are unavailable (unpublished place / Studio API access off) the game still
-- works for the session; it just won't save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

type Profile = { data: { [string]: any }, canSave: boolean }

local profiles: { [Player]: Profile } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("NBATeamData_v1")
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress won't save:", result)
	end
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function reconcile(data: { [string]: any }): { [string]: any }
	for k, v in Config.DEFAULT_DATA do
		if data[k] == nil then
			data[k] = deepCopy(v)
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

function DataService.load(player: Player): { [string]: any }?
	local data = nil
	local canSave = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				canSave = true
				break
			end
			warn(("[DataService] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
			if attempt < 3 then
				task.wait(1)
			end
		end
	end
	if not canSave then
		warn("[DataService] Using a temporary profile for " .. player.Name .. " (will not save)")
	end
	if type(data) ~= "table" then
		data = {}
	end

	-- Player left while we were loading.
	if not player:IsDescendantOf(Players) then
		return nil
	end

	local profile = { data = reconcile(data), canSave = canSave }
	profiles[player] = profile
	return profile.data
end

function DataService.get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(keyFor(player), profile.data, { player.UserId })
		end)
		if ok then
			return
		end
		warn(("[DataService] Save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		if attempt < 3 then
			task.wait(1)
		end
	end
end

function DataService.release(player: Player)
	DataService.save(player)
	profiles[player] = nil
end

function DataService.saveAll()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			DataService.save(player)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end

function DataService.allProfiles(): { [Player]: { [string]: any } }
	local out = {}
	for player, profile in profiles do
		out[player] = profile.data
	end
	return out
end

return DataService
