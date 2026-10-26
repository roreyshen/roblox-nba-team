-- Server-authoritative draft. The client only ever asks; the server decides rolls, ratings and rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NBAData = require(Shared:WaitForChild("NBAData"))
local Rating = require(Shared:WaitForChild("Rating"))
local Sim = require(Shared:WaitForChild("Sim"))
local Config = require(Shared:WaitForChild("Config"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local Codes = require(script.Parent:WaitForChild("Codes"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ActionRemote: RemoteFunction = Remotes:WaitForChild("Action")
local LeaderboardRemote: RemoteFunction = Remotes:WaitForChild("GetLeaderboard")

local rng = Random.new()
local function rand(min: number, max: number): number
	return rng:NextInteger(min, max)
end

local SLOT_COUNT = #Rating.SLOTS
local ACTION_COOLDOWN = 0.12

type Run = {
	phase: string, -- "drafting" | "done"
	slot: number,
	lineup: { any }, -- player table or false, one per slot
	roll: NBAData.Era?,
	rollId: number,
	result: { [string]: any }?,
	game: { [string]: any }?,
}

local runs: { [Player]: Run } = {}
local lastAction: { [Player]: number } = {}
local gameCounter = 0

-- Opponent ratings never change, so work them out once.
local eraOvr: { [string]: number } = {}
for _, era in NBAData.eras do
	eraOvr[era.key] = Rating.rosterOvr(era.players)
end

---------------------------------------------------------------- helpers

local function takenNames(run: Run): { [string]: boolean }
	local taken = {}
	for _, p in run.lineup do
		if p then
			taken[p.name] = true
		end
	end
	return taken
end

local function hasAvailable(era: NBAData.Era, taken: { [string]: boolean }): boolean
	for _, p in era.players do
		if not taken[p.name] then
			return true
		end
	end
	return false
end

local function weightedPick(eras: { NBAData.Era }): NBAData.Era
	local total = 0
	for _, e in eras do
		total += e.weight
	end
	local r = rng:NextNumber() * total
	for _, e in eras do
		r -= e.weight
		if r <= 0 then
			return e
		end
	end
	return eras[#eras]
end

local function rollRandom(run: Run, excludeKey: string?)
	local taken = takenNames(run)
	local candidates = {}
	for _, era in NBAData.eras do
		if era.key ~= excludeKey and hasAvailable(era, taken) then
			table.insert(candidates, era)
		end
	end
	run.roll = weightedPick(candidates)
	run.rollId += 1
end

local function rollSameFranchise(run: Run): boolean
	local current = run.roll
	if not current then
		return false
	end
	local taken = takenNames(run)
	local candidates = {}
	for _, era in NBAData.byFranchise[current.franchise].eras do
		if era.key ~= current.key and hasAvailable(era, taken) then
			table.insert(candidates, era)
		end
	end
	if #candidates == 0 then
		return false
	end
	run.roll = candidates[rng:NextInteger(1, #candidates)]
	run.rollId += 1
	return true
end

local function newRun(): Run
	local lineup = table.create(SLOT_COUNT, false)
	local run: Run = { phase = "drafting", slot = 1, lineup = lineup, roll = nil, rollId = 0, result = nil, game = nil }
	rollRandom(run, nil)
	return run
end

local function updateLeaderstats(player: Player)
	local data = DataService.get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	local best = stats:FindFirstChild("Best OVR") :: IntValue
	local coins = stats:FindFirstChild("Coins") :: IntValue
	best.Value = data.BestOVR
	coins.Value = data.Coins
end

local function snapshot(player: Player)
	local data = DataService.get(player)
	local state: { [string]: any } = {}
	if data then
		state.profile = {
			Coins = data.Coins,
			Rerolls = data.Rerolls,
			Refreshes = data.Refreshes,
			BestOVR = data.BestOVR,
			Drafts = data.Drafts,
			Wins = data.Wins,
			Losses = data.Losses,
		}
	end
	local run = runs[player]
	if run then
		local r: { [string]: any } = {
			phase = run.phase,
			slot = run.slot,
			lineup = run.lineup,
			rollId = run.rollId,
			result = run.result,
			game = run.game,
		}
		if run.roll then
			local taken = takenNames(run)
			local flags = {}
			for i, p in run.roll.players do
				flags[i] = taken[p.name] == true
			end
			r.roll = {
				key = run.roll.key,
				label = run.roll.label,
				franchise = run.roll.franchise,
				players = run.roll.players,
				taken = flags,
			}
		end
		state.run = r
	end
	return state
end

local function finishRun(player: Player, data: { [string]: any }, run: Run)
	local team = Rating.team(run.lineup)
	local coins = Rating.coinsFor(team.ovr)
	data.Coins += coins
	data.Drafts += 1

	local newBest = team.ovr > data.BestOVR
	if newBest then
		data.BestOVR = team.ovr
		local names = {}
		for _, p in run.lineup do
			table.insert(names, p.name)
		end
		data.BestTeam = names
		LeaderboardService.submit(player, team.ovr)
	end

	run.phase = "done"
	run.roll = nil
	run.result = {
		ovr = team.ovr,
		chemistry = team.chemistry,
		tier = Rating.tier(team.ovr),
		coins = coins,
		newBest = newBest,
	}
end

local function pickOpponent(myOvr: number): NBAData.Era
	local sorted = table.clone(NBAData.eras)
	table.sort(sorted, function(a, b)
		return math.abs(eraOvr[a.key] - myOvr) < math.abs(eraOvr[b.key] - myOvr)
	end)
	return sorted[rng:NextInteger(1, math.min(6, #sorted))]
end

---------------------------------------------------------------- actions
-- Each handler returns (ok, message?)

local handlers: { [string]: (Player, { [string]: any }, any) -> (boolean, string?) } = {}

handlers.GetState = function()
	return true, nil
end

handlers.StartRun = function(player)
	runs[player] = newRun()
	return true, nil
end

handlers.Pick = function(player, data, index)
	local run = runs[player]
	if not run or run.phase ~= "drafting" or not run.roll then
		return false, "Start a draft first."
	end
	if typeof(index) ~= "number" or index % 1 ~= 0 then
		return false, "Invalid pick."
	end
	local pick = run.roll.players[index]
	if not pick then
		return false, "Invalid pick."
	end
	if takenNames(run)[pick.name] then
		return false, pick.name .. " is already on your team."
	end

	run.lineup[run.slot] = pick
	run.slot += 1
	if run.slot > SLOT_COUNT then
		finishRun(player, data, run)
	else
		rollRandom(run, nil)
	end
	return true, nil
end

handlers.Reroll = function(player, data)
	local run = runs[player]
	if not run or run.phase ~= "drafting" or not run.roll then
		return false, "Start a draft first."
	end
	if data.Rerolls < 1 then
		return false, "No rerolls left. Get more in the Shop!"
	end
	data.Rerolls -= 1
	rollRandom(run, run.roll.key)
	return true, nil
end

handlers.Refresh = function(player, data)
	local run = runs[player]
	if not run or run.phase ~= "drafting" or not run.roll then
		return false, "Start a draft first."
	end
	if data.Refreshes < 1 then
		return false, "No refreshes left. Get more in the Shop!"
	end
	if not rollSameFranchise(run) then
		return false, "No other seasons for this team."
	end
	data.Refreshes -= 1
	return true, nil
end

handlers.SimGame = function(player, data)
	local run = runs[player]
	if not run or run.phase ~= "done" or not run.result then
		return false, "Finish your draft first."
	end
	if run.game then
		return false, "You already played this team. Draft again!"
	end

	local myOvr = run.result.ovr
	local opp = pickOpponent(myOvr)
	local oppOvr = eraOvr[opp.key]
	local score = Sim.play(myOvr, oppOvr, rand)

	local boxPlayers = {}
	for i, slot in Rating.SLOTS do
		local p = run.lineup[i]
		table.insert(boxPlayers, {
			name = p.name,
			eff = Rating.effective(p, slot),
			pos = p.positions[1],
			bench = slot.bench,
		})
	end
	local box = Sim.boxScore(boxPlayers, score.homeTotal, rand)

	local win = score.homeTotal > score.awayTotal
	local coins
	if win then
		local margin = math.min(score.homeTotal - score.awayTotal, Config.WIN_MARGIN_CAP)
		coins = Config.WIN_COINS + margin * Config.WIN_COINS_PER_POINT
		data.Wins += 1
	else
		coins = Config.LOSS_COINS
		data.Losses += 1
	end
	data.Coins += coins

	gameCounter += 1
	run.game = {
		id = gameCounter,
		oppLabel = opp.label,
		oppFranchise = opp.franchise,
		oppOvr = oppOvr,
		myOvr = myOvr,
		home = score.home,
		away = score.away,
		homeTotal = score.homeTotal,
		awayTotal = score.awayTotal,
		win = win,
		coins = coins,
		box = box,
	}
	return true, nil
end

handlers.Buy = function(player, data, itemId)
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

handlers.Redeem = function(player, data, code)
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

LeaderboardRemote.OnServerInvoke = function()
	return LeaderboardService.top()
end

---------------------------------------------------------------- players

local function onPlayerAdded(player: Player)
	local data = DataService.load(player)
	if not data then
		return
	end

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local best = Instance.new("IntValue")
	best.Name = "Best OVR"
	best.Parent = stats
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	stats.Parent = player
	updateLeaderstats(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	runs[player] = nil
	lastAction[player] = nil
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

LeaderboardService.init(function()
	local out = {}
	for player, data in DataService.allProfiles() do
		if data.BestOVR > 0 then
			table.insert(out, { userId = player.UserId, name = player.Name, ovr = data.BestOVR })
		end
	end
	return out
end)
