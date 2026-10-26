-- Live draft duels between two players (or a player and a practice bot).
-- Both sides draft from the same rolled team, taking turns; a drafted player is gone for both.
-- When all 8 slots are filled, the teams play a simulated game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NBAData = require(Shared:WaitForChild("NBAData"))
local Rating = require(Shared:WaitForChild("Rating"))
local Sim = require(Shared:WaitForChild("Sim"))
local Draft = require(Shared:WaitForChild("Draft"))
local Config = require(Shared:WaitForChild("Config"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local Net = require(script.Parent:WaitForChild("Net"))

local DuelService = {}

local rng = Random.new()
local function rand(min: number, max: number): number
	return rng:NextInteger(min, max)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

type DuelRecord = {
	id: number,
	players: { any }, -- Player or false (bot / left the game), indexed by side
	names: { string },
	userIds: { number },
	bot: number?, -- side number played by the bot
	state: Draft.Duel,
	deadline: number, -- server time when the current pick auto-fires
	result: { [string]: any }?,
}

local duelOf: { [Player]: DuelRecord } = {}
local active: { [DuelRecord]: boolean } = {}
local queue: { Player } = {}
local invites: { [Player]: { from: Player, expires: number } } = {} -- keyed by the challenged player
local outgoing: { [Player]: Player } = {} -- challenger -> challenged
local duelCounter = 0
local leaving: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local onStatsChanged: (Player) -> () = function() end

function DuelService.setStatsChanged(fn: (Player) -> ())
	onStatsChanged = fn
end

---------------------------------------------------------------- helpers

local function sideOf(d: DuelRecord, player: Player): number?
	if d.players[1] == player then
		return 1
	elseif d.players[2] == player then
		return 2
	end
	return nil
end

local function isBusy(player: Player): boolean
	local d = duelOf[player]
	return d ~= nil and d.state.phase == "drafting"
end

local function queueIndex(player: Player): number?
	return table.find(queue, player)
end

local function removeFromQueue(player: Player)
	local i = queueIndex(player)
	if i then
		table.remove(queue, i)
	end
end

local function isOnline(player: any): boolean
	return typeof(player) == "Instance" and player:IsDescendantOf(Players) and not leaving[player :: Player]
end

-- Cancel anything `player` sent or received. Tells the other person.
local function clearInvites(player: Player, reason: string?)
	local inv = invites[player]
	if inv then
		invites[player] = nil
		outgoing[inv.from] = nil
		if reason then
			Net.push(inv.from, reason, false)
		else
			Net.push(inv.from)
		end
	end
	local target = outgoing[player]
	if target then
		outgoing[player] = nil
		invites[target] = nil
		Net.push(target)
	end
end

local function pushBoth(d: DuelRecord, msgs: { [number]: string? }?, ok: boolean?)
	for side = 1, 2 do
		local p = d.players[side]
		if p then
			Net.push(p, msgs and msgs[side], ok)
		end
	end
end

local function setDeadline(d: DuelRecord)
	if d.bot and d.state.turn == d.bot then
		local delay = Config.BOT_PICK_DELAY
		d.deadline = now() + delay[1] + rng:NextNumber() * (delay[2] - delay[1])
	else
		d.deadline = now() + Config.PICK_SECONDS
	end
end

local function boxPlayers(lineup: { any }): { any }
	local out = {}
	for i, slot in Rating.SLOTS do
		local p = lineup[i]
		if p then
			table.insert(out, {
				name = p.name,
				eff = Rating.effective(p, slot),
				pos = p.positions[1],
				bench = slot.bench,
			})
		end
	end
	return out
end

---------------------------------------------------------------- duel lifecycle

local function finishDuel(d: DuelRecord, forfeitSide: number?)
	active[d] = nil
	d.state.phase = "done"
	d.state.roll = nil

	local result: { [string]: any } = { forfeitSide = forfeitSide, coins = { 0, 0 } }
	local winner
	if forfeitSide then
		winner = 3 - forfeitSide
	else
		local t1 = Rating.team(d.state.lineups[1])
		local t2 = Rating.team(d.state.lineups[2])
		local score = Sim.play(t1.ovr, t2.ovr, rand)
		result.ovr = { t1.ovr, t2.ovr }
		result.chem = { t1.chemistry, t2.chemistry }
		result.quarters = { score.home, score.away }
		result.totals = { score.homeTotal, score.awayTotal }
		result.boxes = {
			Sim.boxScore(boxPlayers(d.state.lineups[1]), score.homeTotal, rand),
			Sim.boxScore(boxPlayers(d.state.lineups[2]), score.awayTotal, rand),
		}
		winner = if score.homeTotal > score.awayTotal then 1 else 2
	end
	result.winner = winner

	local msgs = {}
	for side = 1, 2 do
		local p = d.players[side]
		local data = if p then DataService.get(p) else nil
		if p and data then
			local won = side == winner
			local coins
			if d.bot then
				coins = if won then Config.BOT_WIN_COINS elseif forfeitSide == side then 0 else Config.BOT_LOSS_COINS
			else
				coins = if won then Config.DUEL_WIN_COINS elseif forfeitSide == side then 0 else Config.DUEL_LOSS_COINS
				if won then
					data.DuelWins += 1
					LeaderboardService.submit("duel", p, data.DuelWins)
				else
					data.DuelLosses += 1
				end
			end
			data.Coins += coins
			result.coins[side] = coins
			onStatsChanged(p)

			if forfeitSide == side then
				msgs[side] = "You forfeited the duel."
			elseif forfeitSide then
				msgs[side] = ("%s forfeited. You win! +%d coins"):format(d.names[3 - side], coins)
			elseif won then
				msgs[side] = ("You won the duel! +%d coins"):format(coins)
			else
				msgs[side] = ("You lost the duel. +%d coins"):format(coins)
			end
		end
	end
	d.result = result

	pushBoth(d, msgs)
	local except = {}
	for side = 1, 2 do
		local p = d.players[side]
		if p then
			except[p] = true
		end
	end
	Net.pushAll(except)
end

-- Returns (ok, err?)
local function doPick(d: DuelRecord, side: number, index: any, auto: boolean, autoMsg: string?): (boolean, string?)
	local ok, err = Draft.duelPick(d.state, side, index, NBAData.eras, rand, auto)
	if not ok then
		return false, err
	end
	if d.state.phase == "done" then
		finishDuel(d, nil)
	else
		setDeadline(d)
		pushBoth(d, if autoMsg then { [side] = autoMsg } else nil, if autoMsg then false else nil)
	end
	return true, nil
end

local function startDuel(p1: Player, p2: Player?)
	for _, p in { p1, p2 } do
		if p then
			removeFromQueue(p)
			clearInvites(p)
		end
	end

	duelCounter += 1
	local d: DuelRecord = {
		id = duelCounter,
		players = { p1, p2 or false },
		names = { p1.Name, if p2 then p2.Name else "CPU Bot" },
		userIds = { p1.UserId, if p2 then p2.UserId else 0 },
		bot = if p2 then nil else 2,
		state = Draft.newDuel(NBAData.eras, rand),
		deadline = 0,
		result = nil,
	}
	setDeadline(d)
	duelOf[p1] = d
	if p2 then
		duelOf[p2] = d
	end
	active[d] = true

	pushBoth(d, {
		("Duel vs %s! You pick first."):format(d.names[2]),
		("Duel vs %s! They pick first."):format(d.names[1]),
	})
	local except = { [p1] = true }
	if p2 then
		except[p2] = true
	end
	Net.pushAll(except)
end

local function tryMatch()
	for i = #queue, 1, -1 do
		local p = queue[i]
		if not isOnline(p) or isBusy(p) then
			table.remove(queue, i)
		end
	end
	while #queue >= 2 do
		local a = table.remove(queue, 1)
		local b = table.remove(queue, 1)
		startDuel(a, b)
	end
end

---------------------------------------------------------------- views (sent to clients)

function DuelService.view(player: Player): { [string]: any }?
	local d = duelOf[player]
	if not d then
		return nil
	end
	local side = sideOf(d, player)
	if not side then
		return nil
	end
	local opp = 3 - side
	local st = d.state

	local log = {}
	for i = math.max(1, #st.log - 2), #st.log do
		local e = st.log[i]
		table.insert(log, { mine = e.side == side, name = e.name, ovr = e.ovr, auto = e.auto })
	end

	local view: { [string]: any } = {
		id = d.id,
		phase = st.phase,
		round = math.min(st.round, #Rating.SLOTS),
		rounds = #Rating.SLOTS,
		myTurn = st.phase == "drafting" and st.turn == side,
		deadline = d.deadline,
		rollId = st.rollId,
		vsBot = d.bot ~= nil,
		me = { name = d.names[side], userId = d.userIds[side], lineup = st.lineups[side] },
		opp = { name = d.names[opp], userId = d.userIds[opp], lineup = st.lineups[opp] },
		log = log,
	}

	if st.roll then
		local mine = Draft.takenNames({ st.lineups[side] })
		local theirs = Draft.takenNames({ st.lineups[opp] })
		local takenBy = {}
		for i, p in st.roll.players do
			takenBy[i] = if mine[p.name] then 1 elseif theirs[p.name] then 2 else 0
		end
		view.roll = {
			key = st.roll.key,
			label = st.roll.label,
			franchise = st.roll.franchise,
			weight = st.roll.weight,
			players = st.roll.players,
			takenBy = takenBy,
		}
	end

	local r = d.result
	if r then
		view.result = {
			win = r.winner == side,
			forfeit = r.forfeitSide ~= nil,
			forfeitByMe = r.forfeitSide == side,
			coins = r.coins[side],
			myOvr = r.ovr and r.ovr[side],
			oppOvr = r.ovr and r.ovr[opp],
			myChem = r.chem and r.chem[side],
			oppChem = r.chem and r.chem[opp],
			mine = r.quarters and r.quarters[side],
			theirs = r.quarters and r.quarters[opp],
			myTotal = r.totals and r.totals[side],
			oppTotal = r.totals and r.totals[opp],
			box = r.boxes and r.boxes[side],
			oppBox = r.boxes and r.boxes[opp],
		}
	end
	return view
end

function DuelService.lobby(player: Player): { [string]: any }
	local list = {}
	for _, p in Players:GetPlayers() do
		local data = DataService.get(p)
		if p ~= player and data and not leaving[p] then
			table.insert(list, {
				userId = p.UserId,
				name = p.Name,
				duelWins = data.DuelWins,
				status = if isBusy(p) then "dueling" elseif queueIndex(p) then "searching" else "idle",
			})
		end
	end
	table.sort(list, function(a, b)
		return a.name:lower() < b.name:lower()
	end)

	local lobby: { [string]: any } = { players = list, queued = queueIndex(player) ~= nil }
	local target = outgoing[player]
	if target and invites[target] then
		lobby.outgoing = { name = target.Name, userId = target.UserId, expires = invites[target].expires }
	end
	local inv = invites[player]
	if inv then
		lobby.incoming = { name = inv.from.Name, userId = inv.from.UserId, expires = inv.expires }
	end
	return lobby
end

---------------------------------------------------------------- actions (return ok, message?)

DuelService.handlers = {}
local handlers = DuelService.handlers

handlers.Challenge = function(player, _data, targetUserId)
	if typeof(targetUserId) ~= "number" then
		return false, "Pick a player to challenge."
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or not DataService.get(target) then
		return false, "That player isn't here."
	end
	if isBusy(player) then
		return false, "Finish your duel first."
	end
	if isBusy(target) then
		return false, target.Name .. " is in a duel right now."
	end
	-- They already challenged us: just start.
	local mine = invites[player]
	if mine and mine.from == target then
		startDuel(target, player)
		return true, nil
	end
	if invites[target] then
		return false, target.Name .. " already has a challenge waiting."
	end

	local old = outgoing[player]
	if old then
		invites[old] = nil
		Net.push(old)
	end
	removeFromQueue(player)
	invites[target] = { from = player, expires = now() + Config.INVITE_SECONDS }
	outgoing[player] = target
	Net.push(target, player.Name .. " challenged you to a Draft Duel!")
	return true, "Challenge sent to " .. target.Name .. "!"
end

handlers.CancelChallenge = function(player)
	local target = outgoing[player]
	if not target then
		return false, "No challenge to cancel."
	end
	outgoing[player] = nil
	invites[target] = nil
	Net.push(target, player.Name .. " cancelled the challenge.", false)
	return true, "Challenge cancelled."
end

handlers.RespondInvite = function(player, _data, accept)
	local inv = invites[player]
	if not inv then
		return false, "That challenge expired."
	end
	invites[player] = nil
	outgoing[inv.from] = nil
	if accept ~= true then
		Net.push(inv.from, player.Name .. " declined your challenge.", false)
		return true, "Challenge declined."
	end
	if not isOnline(inv.from) then
		return false, "They left the game."
	end
	if isBusy(inv.from) or isBusy(player) then
		return false, "Someone is already in a duel."
	end
	startDuel(inv.from, player)
	return true, nil
end

handlers.QuickMatch = function(player)
	if isBusy(player) then
		return false, "Finish your duel first."
	end
	if queueIndex(player) then
		removeFromQueue(player)
		Net.pushAll({ [player] = true })
		return true, "Stopped searching."
	end
	local target = outgoing[player]
	if target then
		outgoing[player] = nil
		invites[target] = nil
		Net.push(target)
	end
	table.insert(queue, player)
	tryMatch()
	if queueIndex(player) then
		Net.pushAll({ [player] = true })
		return true, "Searching for an opponent..."
	end
	return true, nil
end

handlers.BotDuel = function(player)
	if isBusy(player) then
		return false, "Finish your duel first."
	end
	startDuel(player, nil)
	return true, nil
end

handlers.DuelPick = function(player, _data, index)
	local d = duelOf[player]
	if not d or d.state.phase ~= "drafting" then
		return false, "You're not in a duel."
	end
	return doPick(d, sideOf(d, player) :: number, index, false, nil)
end

handlers.Forfeit = function(player)
	local d = duelOf[player]
	if not d or d.state.phase ~= "drafting" then
		return false, "You're not in a duel."
	end
	finishDuel(d, sideOf(d, player))
	return true, nil
end

handlers.DismissDuel = function(player)
	local d = duelOf[player]
	if d and d.state.phase == "done" then
		duelOf[player] = nil
	end
	return true, nil
end

handlers.Rematch = function(player, data)
	local d = duelOf[player]
	if not d or d.state.phase ~= "done" then
		return false, "Nothing to rematch."
	end
	local side = sideOf(d, player) :: number
	duelOf[player] = nil
	if d.bot then
		return handlers.BotDuel(player, data, nil)
	end
	local opp = d.players[3 - side]
	if not isOnline(opp) then
		return false, "Your opponent left the game."
	end
	return handlers.Challenge(player, data, opp.UserId)
end

---------------------------------------------------------------- lifecycle

-- Call from PlayerRemoving BEFORE their data is saved, so a forfeit loss is recorded.
function DuelService.onLeave(player: Player)
	leaving[player] = true
	removeFromQueue(player)
	clearInvites(player, player.Name .. " left the game.")
	local d = duelOf[player]
	if d then
		local side = sideOf(d, player)
		if side and d.state.phase == "drafting" then
			if d.bot then
				active[d] = nil
				d.state.phase = "done"
			else
				finishDuel(d, side)
			end
		end
		if side then
			d.players[side] = false
		end
		duelOf[player] = nil
	end
end

function DuelService.start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			local t = now()
			for d in active do
				if d.state.phase == "drafting" and d.state.roll and t >= d.deadline then
					local side = d.state.turn
					local isBot = d.bot == side
					local slot = Rating.SLOTS[d.state.round]
					local taken = Draft.takenNames(d.state.lineups)
					local index = Draft.bestPickIndex(d.state.roll, slot, taken, rand, if isBot then Config.BOT_SKILL else 1)
					if index then
						local name = d.state.roll.players[index].name
						doPick(d, side, index, not isBot, if isBot then nil else ("Time's up! Auto-drafted " .. name))
					end
				end
			end
			for target, inv in invites do
				if t >= inv.expires then
					invites[target] = nil
					outgoing[inv.from] = nil
					Net.push(inv.from, target.Name .. " didn't answer your challenge.", false)
					Net.push(target)
				end
			end
		end
	end)
end

return DuelService
