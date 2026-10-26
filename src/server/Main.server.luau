-- Server entry point: wires remotes, players and services together.
-- Server-authoritative: the client only ever asks; the server decides rolls, ratings and rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Server = script.Parent
local DataService = require(Server:WaitForChild("DataService"))
local LeaderboardService = require(Server:WaitForChild("LeaderboardService"))
local SoloService = require(Server:WaitForChild("SoloService"))
local DuelService = require(Server:WaitForChild("DuelService"))
local Net = require(Server:WaitForChild("Net"))
local Codes = require(Server:WaitForChild("Codes"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ActionRemote: RemoteFunction = Remotes:WaitForChild("Action")
local LeaderboardRemote: RemoteFunction = Remotes:WaitForChild("GetLeaderboard")

local ACTION_COOLDOWN = 0.12
local lastAction: { [Player]: number } = {}

---------------------------------------------------------------- leaderstats

local STATS = { { "Best OVR", "BestOVR" }, { "Duel Wins", "DuelWins" }, { "Coins", "Coins" } }

local function updateLeaderstats(player: Player)
	local data = DataService.get(player)
	local folder = player:FindFirstChild("leaderstats")
	if not data or not folder then
		return
	end
	for _, stat in STATS do
		local value = folder:FindFirstChild(stat[1]) :: IntValue?
		if value then
			value.Value = data[stat[2]]
		end
	end
end

---------------------------------------------------------------- state sent to the client

local function snapshot(player: Player): { [string]: any }?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	return {
		profile = {
			Coins = data.Coins,
			Rerolls = data.Rerolls,
			Refreshes = data.Refreshes,
			BestOVR = data.BestOVR,
			Drafts = data.Drafts,
			Wins = data.Wins,
			Losses = data.Losses,
			DuelWins = data.DuelWins,
			DuelLosses = data.DuelLosses,
		},
		run = SoloService.view(player),
		duel = DuelService.view(player),
		lobby = DuelService.lobby(player),
	}
end

Net.setSnapshot(snapshot)
DuelService.setStatsChanged(updateLeaderstats)

---------------------------------------------------------------- actions

local handlers: { [string]: (Player, { [string]: any }, any) -> (boolean, string?) } = {}

for name, fn in SoloService.handlers do
	handlers[name] = fn
end
for name, fn in DuelService.handlers do
	handlers[name] = fn
end

handlers.GetState = function()
	return true, nil
end

handlers.Buy = function(_player, data, itemId)
	for _, item in Config.SHOP do
		if item.id == itemId then
			if data.Coins < item.cost then
				return false, ("You need %d more coins."):format(item.cost - data.Coins)
			end
			data.Coins -= item.cost
			for stat, amount in item.give do
				data[stat] += amount
			end
			return true, "Bought " .. item.name .. "!"
		end
	end
	return false, "That item doesn't exist."
end

handlers.Redeem = function(_player, data, code)
	if typeof(code) ~= "string" or #code == 0 or #code > 30 then
		return false, "Enter a code."
	end
	code = string.upper((code:gsub("%s", "")))
	local reward = Codes[code]
	if not reward then
		return false, "Invalid code."
	end
	if data.Codes[code] then
		return false, "You already used that code."
	end
	data.Codes[code] = true
	local parts = {}
	for stat, amount in reward do
		data[stat] += amount
		table.insert(parts, ("+%d %s"):format(amount, stat))
	end
	table.sort(parts)
	return true, "Code redeemed! " .. table.concat(parts, ", ")
end

ActionRemote.OnServerInvoke = function(player: Player, action: any, arg: any)
	local data = DataService.get(player)
	if not data then
		return { ok = false, msg = "Loading your data..." }
	end
	if typeof(action) ~= "string" or not handlers[action] then
		return { ok = false, msg = "Unknown action.", state = snapshot(player) }
	end
	if action ~= "GetState" then
		local now = os.clock()
		if lastAction[player] and now - lastAction[player] < ACTION_COOLDOWN then
			return { ok = false, state = snapshot(player) }
		end
		lastAction[player] = now
	end

	local ok, msg = handlers[action](player, data, arg)
	updateLeaderstats(player)
	return { ok = ok, msg = msg, state = snapshot(player) }
end

LeaderboardRemote.OnServerInvoke = function(_player: Player, board: any)
	if board ~= "best" and board ~= "duel" then
		board = "best"
	end
	return LeaderboardService.top(board)
end

---------------------------------------------------------------- players

local function onPlayerAdded(player: Player)
	local data = DataService.load(player)
	if not data then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, stat in STATS do
		local value = Instance.new("IntValue")
		value.Name = stat[1]
		value.Parent = folder
	end
	folder.Parent = player
	updateLeaderstats(player)

	-- Let everyone else see the new player in the Duels list.
	Net.pushAll({ [player] = true })
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	DuelService.onLeave(player) -- before saving, so a forfeit loss is recorded
	SoloService.clear(player)
	lastAction[player] = nil
	Net.pushAll({ [player] = true })
	DataService.release(player)
end)

game:BindToClose(function()
	DataService.saveAll()
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.save, player)
		end
	end
end)

LeaderboardService.init(DataService.allProfiles)
DuelService.start()
