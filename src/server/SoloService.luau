-- Solo draft: roll, pick, reroll/refresh, final rating, simulated game vs a CPU team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NBAData = require(Shared:WaitForChild("NBAData"))
local Rating = require(Shared:WaitForChild("Rating"))
local Sim = require(Shared:WaitForChild("Sim"))
local Draft = require(Shared:WaitForChild("Draft"))
local Config = require(Shared:WaitForChild("Config"))

local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

local SoloService = {}

local rng = Random.new()
local function rand(min: number, max: number): number
	return rng:NextInteger(min, max)
end

local SLOT_COUNT = #Rating.SLOTS

type Run = {
	phase: string, -- "drafting" | "done"
	slot: number,
	lineup: { any }, -- player table or false, one per slot
	roll: any?,
	rollId: number,
	result: { [string]: any }?,
	game: { [string]: any }?,
}

local runs: { [Player]: Run } = {}
local gameCounter = 0

-- CPU opponent ratings never change, so work them out once.
local eraOvr: { [string]: number } = {}
for _, era in NBAData.eras do
	eraOvr[era.key] = Rating.rosterOvr(era.players)
end

local function takenNames(run: Run): { [string]: boolean }
	return Draft.takenNames({ run.lineup })
end

local function setRoll(run: Run, era: any)
	run.roll = era
	run.rollId += 1
end

local function newRun(): Run
	local run: Run = {
		phase = "drafting",
		slot = 1,
		lineup = table.create(SLOT_COUNT, false),
		roll = nil,
		rollId = 0,
		result = nil,
		game = nil,
	}
	setRoll(run, Draft.rollEra(NBAData.eras, {}, rand))
	return run
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
		LeaderboardService.submit("best", player, team.ovr)
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

local function pickOpponent(myOvr: number): any
	local sorted = table.clone(NBAData.eras)
	table.sort(sorted, function(a, b)
		return math.abs(eraOvr[a.key] - myOvr) < math.abs(eraOvr[b.key] - myOvr)
	end)
	return sorted[rng:NextInteger(1, math.min(6, #sorted))]
end

function SoloService.view(player: Player): { [string]: any }?
	local run = runs[player]
	if not run then
		return nil
	end
	local view: { [string]: any } = {
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
		view.roll = {
			key = run.roll.key,
			label = run.roll.label,
			franchise = run.roll.franchise,
			weight = run.roll.weight,
			players = run.roll.players,
			taken = flags,
		}
	end
	return view
end

function SoloService.clear(player: Player)
	runs[player] = nil
end

---------------------------------------------------------------- actions (return ok, message?)

SoloService.handlers = {}

SoloService.handlers.StartRun = function(player)
	runs[player] = newRun()
	return true, nil
end

SoloService.handlers.Pick = function(player, data, index)
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
		setRoll(run, Draft.rollEra(NBAData.eras, takenNames(run), rand))
	end
	return true, nil
end

SoloService.handlers.Reroll = function(player, data)
	local run = runs[player]
	if not run or run.phase ~= "drafting" or not run.roll then
		return false, "Start a draft first."
	end
	if data.Rerolls < 1 then
		return false, "No rerolls left. Get more in the Shop!"
	end
	local era = Draft.rollEra(NBAData.eras, takenNames(run), rand, { exclude = run.roll.key })
	if not era then
		return false, "Nothing left to roll."
	end
	data.Rerolls -= 1
	setRoll(run, era)
	return true, nil
end

SoloService.handlers.Refresh = function(player, data)
	local run = runs[player]
	if not run or run.phase ~= "drafting" or not run.roll then
		return false, "Start a draft first."
	end
	if data.Refreshes < 1 then
		return false, "No refreshes left. Get more in the Shop!"
	end
	local era = Draft.rollEra(
		NBAData.eras,
		takenNames(run),
		rand,
		{ exclude = run.roll.key, franchise = run.roll.franchise }
	)
	if not era then
		return false, "No other seasons for this team."
	end
	data.Refreshes -= 1
	setRoll(run, era)
	return true, nil
end

SoloService.handlers.SimGame = function(player, data)
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

return SoloService
