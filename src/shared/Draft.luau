--!strict
-- Draft rules shared by solo drafts and live duels. Pure: pass in rand(min, max) -> integer.

local Rating = if script then require(script.Parent.Rating) else (require :: any)("./Rating")

export type Rand = (number, number) -> number

export type RollOptions = {
	exclude: string?, -- don't roll this team-season again
	franchise: string?, -- only roll seasons of this franchise (Refresh)
	minAvailable: number?, -- roll must have at least this many undrafted players
}

-- Live duel: both players draft from the SAME roll, taking turns. A drafted player is gone for both.
export type Duel = {
	phase: string, -- "drafting" | "done"
	round: number, -- 1..#Rating.SLOTS (also the slot being filled)
	turn: number, -- side (1 or 2) whose pick it is
	picksThisRound: number,
	lineups: { { any } },
	roll: any?,
	rollId: number,
	log: { { side: number, name: string, ovr: number, round: number, auto: boolean } },
}

local Draft = {}

function Draft.takenNames(lineups: { { any } }): { [string]: boolean }
	local taken = {}
	for _, lineup in lineups do
		for _, p in lineup do
			if p then
				taken[p.name] = true
			end
		end
	end
	return taken
end

function Draft.availableCount(era: any, taken: { [string]: boolean }): number
	local n = 0
	for _, p in era.players do
		if not taken[p.name] then
			n += 1
		end
	end
	return n
end

function Draft.rollEra(eras: { any }, taken: { [string]: boolean }, rand: Rand, opts: RollOptions?): any?
	local o: RollOptions = opts or {}
	local minAvailable = o.minAvailable or 1
	local candidates = {}
	local totalWeight = 0
	for _, era in eras do
		if era.key ~= o.exclude
			and (o.franchise == nil or era.franchise == o.franchise)
			and Draft.availableCount(era, taken) >= minAvailable
		then
			table.insert(candidates, era)
			totalWeight += era.weight
		end
	end
	if #candidates == 0 then
		return nil
	end
	if o.franchise then
		-- Refresh: every other season of the franchise is equally likely.
		return candidates[rand(1, #candidates)]
	end
	local r = rand(1, totalWeight)
	for _, era in candidates do
		r -= era.weight
		if r <= 0 then
			return era
		end
	end
	return candidates[#candidates]
end

-- Best undrafted player for `slot` (used when the pick timer runs out, and by the bot).
-- `skill` 1 = always the best; lower = sometimes takes the 2nd/3rd best.
function Draft.bestPickIndex(roll: any, slot: any, taken: { [string]: boolean }, rand: Rand?, skill: number?): number?
	local options = {}
	for i, p in roll.players do
		if not taken[p.name] then
			table.insert(options, { i = i, score = Rating.effective(p, slot) + p.ovr * 0.001 })
		end
	end
	if #options == 0 then
		return nil
	end
	table.sort(options, function(a, b)
		return a.score > b.score
	end)
	if rand and skill and skill < 1 and #options > 1 then
		local roll100 = rand(1, 100)
		if roll100 > skill * 100 then
			return options[math.min(#options, rand(2, 3))].i
		end
	end
	return options[1].i
end

function Draft.firstPicker(round: number): number
	return if round % 2 == 1 then 1 else 2
end

function Draft.newDuel(eras: { any }, rand: Rand): Duel
	local n = #Rating.SLOTS
	local duel: Duel = {
		phase = "drafting",
		round = 1,
		turn = 1,
		picksThisRound = 0,
		lineups = { table.create(n, false), table.create(n, false) },
		roll = nil,
		rollId = 1,
		log = {},
	}
	duel.roll = Draft.rollEra(eras, {}, rand, { minAvailable = 2 })
	return duel
end

-- Returns (ok, errorMessage?)
function Draft.duelPick(duel: Duel, side: number, index: any, eras: { any }, rand: Rand, auto: boolean?): (boolean, string?)
	if duel.phase ~= "drafting" or not duel.roll then
		return false, "The draft is over."
	end
	if side ~= duel.turn then
		return false, "Wait for your turn!"
	end
	if typeof(index) ~= "number" or index % 1 ~= 0 then
		return false, "Invalid pick."
	end
	local pick = duel.roll.players[index]
	if not pick then
		return false, "Invalid pick."
	end
	if Draft.takenNames(duel.lineups)[pick.name] then
		return false, pick.name .. " is already taken."
	end

	duel.lineups[side][duel.round] = pick
	table.insert(duel.log, { side = side, name = pick.name, ovr = pick.ovr, round = duel.round, auto = auto == true })
	duel.picksThisRound += 1

	if duel.picksThisRound < 2 then
		duel.turn = 3 - side
		return true, nil
	end

	duel.round += 1
	duel.picksThisRound = 0
	if duel.round > #Rating.SLOTS then
		duel.phase = "done"
		duel.roll = nil
	else
		duel.roll = Draft.rollEra(eras, Draft.takenNames(duel.lineups), rand, { minAvailable = 2 })
		duel.rollId += 1
		duel.turn = Draft.firstPicker(duel.round)
	end
	return true, nil
end

return Draft
