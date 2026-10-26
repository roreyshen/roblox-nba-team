--!strict
-- Team rating math. Used by the server (real result) and the client (live preview).

export type Slot = { id: string, label: string, short: string, accepts: { string }, bench: boolean }

export type RatedPlayer = { ovr: number, positions: { string }, teamKey: string }

export type TeamRating = { ovr: number, chemistry: number, natural: number, links: number, filled: number }

local Rating = {}

local POS_INDEX: { [string]: number } = { PG = 1, SG = 2, SF = 3, PF = 4, C = 5 }
Rating.POS_INDEX = POS_INDEX

Rating.SLOTS = {
	{ id = "PG", label = "PG", short = "PG", accepts = { "PG" }, bench = false },
	{ id = "SG", label = "SG", short = "SG", accepts = { "SG" }, bench = false },
	{ id = "SF", label = "SF", short = "SF", accepts = { "SF" }, bench = false },
	{ id = "PF", label = "PF", short = "PF", accepts = { "PF" }, bench = false },
	{ id = "C", label = "C", short = "C", accepts = { "C" }, bench = false },
	{ id = "G", label = "BENCH G", short = "BN G", accepts = { "PG", "SG" }, bench = true },
	{ id = "F", label = "BENCH F", short = "BN F", accepts = { "SF", "PF" }, bench = true },
	{ id = "B", label = "BENCH BIG", short = "BN BIG", accepts = { "PF", "C" }, bench = true },
} :: { Slot }

-- How much of a player's rating survives when he plays out of position.
-- Key = how many positions away he is (PG -> C is 4 away).
local FIT_MULT: { [number]: number } = { [0] = 1.0, [1] = 0.94, [2] = 0.87, [3] = 0.8, [4] = 0.74 }

Rating.TIER_COLORS = {
	LEGEND = { 255, 200, 40 },
	ELITE = { 175, 95, 255 },
	STAR = { 70, 150, 255 },
	STARTER = { 80, 200, 120 },
	ROLE = { 150, 150, 160 },
} :: { [string]: { number } }

function Rating.distance(positions: { string }, slot: Slot): number
	local best = 4
	for _, p in positions do
		local pi = POS_INDEX[p]
		if pi then
			for _, a in slot.accepts do
				local d = math.abs(pi - POS_INDEX[a])
				if d < best then
					best = d
				end
			end
		end
	end
	return best
end

function Rating.effective(player: RatedPlayer, slot: Slot): number
	return player.ovr * FIT_MULT[Rating.distance(player.positions, slot)]
end

-- lineup[i] is the player in Rating.SLOTS[i], or false/nil if that slot is empty.
function Rating.team(lineup: { any }): TeamRating
	local startSum, startCount, benchSum, benchCount, natural = 0, 0, 0, 0, 0
	local eraCounts: { [string]: number } = {}

	for i, slot in Rating.SLOTS do
		local p = lineup[i]
		if p then
			local eff = Rating.effective(p, slot)
			if slot.bench then
				benchSum += eff
				benchCount += 1
			else
				startSum += eff
				startCount += 1
			end
			if Rating.distance(p.positions, slot) == 0 then
				natural += 1
			end
			eraCounts[p.teamKey] = (eraCounts[p.teamKey] or 0) + 1
		end
	end

	-- Chemistry: +10 per player at a natural position (max 80),
	-- +5 per extra teammate from the same team-season (max 20).
	local links = 0
	for _, n in eraCounts do
		links += n - 1
	end
	local chemistry = math.min(100, natural * 10 + math.min(20, links * 5))

	local base = 0
	if startCount > 0 and benchCount > 0 then
		base = (startSum / startCount) * 0.8 + (benchSum / benchCount) * 0.2
	elseif startCount > 0 then
		base = startSum / startCount
	elseif benchCount > 0 then
		base = benchSum / benchCount
	end

	local filled = startCount + benchCount
	local ovr = 0
	if filled > 0 then
		ovr = math.clamp(math.floor(base + chemistry / 100 * 3 + 0.5), 0, 99)
	end

	return { ovr = ovr, chemistry = chemistry, natural = natural, links = links, filled = filled }
end

-- Rating of a real team-season (used for CPU opponents): best 5 start, next 3 come off the bench,
-- full chemistry because they actually played together.
function Rating.rosterOvr(players: { RatedPlayer }): number
	local sorted = table.clone(players)
	table.sort(sorted, function(a, b)
		return a.ovr > b.ovr
	end)
	local startSum, startCount, benchSum, benchCount = 0, 0, 0, 0
	for i, p in sorted do
		if i <= 5 then
			startSum += p.ovr
			startCount += 1
		elseif i <= 8 then
			benchSum += p.ovr
			benchCount += 1
		end
	end
	local base = startSum / math.max(1, startCount)
	if benchCount > 0 then
		base = base * 0.8 + (benchSum / benchCount) * 0.2
	end
	return math.clamp(math.floor(base + 3 + 0.5), 0, 99)
end

function Rating.coinsFor(ovr: number): number
	return math.max(10, math.floor((ovr - 70) * 6))
end

function Rating.tier(ovr: number): string
	if ovr >= 95 then
		return "LEGEND"
	elseif ovr >= 90 then
		return "ELITE"
	elseif ovr >= 85 then
		return "STAR"
	elseif ovr >= 78 then
		return "STARTER"
	end
	return "ROLE"
end

return Rating
