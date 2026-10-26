--!strict
-- Simulated game vs a CPU team. Pure functions: pass in rand(min, max) -> integer.

export type GameScore = {
	home: { number },
	away: { number },
	homeTotal: number,
	awayTotal: number,
	overtimes: number,
}

export type BoxPlayer = { name: string, eff: number, pos: string, bench: boolean }
export type BoxLine = { name: string, pts: number, reb: number, ast: number }

type Rand = (number, number) -> number

local Sim = {}

local function sum(t: { number }): number
	local s = 0
	for _, v in t do
		s += v
	end
	return s
end

-- Random rounding (2.3 -> 3 about 30% of the time) so small rating edges still matter.
local function roundRandom(x: number, rand: Rand): number
	return math.floor(x + rand(0, 99) / 100)
end

function Sim.play(homeOvr: number, awayOvr: number, rand: Rand): GameScore
	local home, away = {}, {}
	local diff = homeOvr - awayOvr

	for q = 1, 4 do
		home[q] = math.max(12, 27 + roundRandom(diff * 0.2, rand) + rand(-6, 6))
		away[q] = math.max(12, 27 + roundRandom(-diff * 0.2, rand) + rand(-6, 6))
	end

	local overtimes = 0
	while sum(home) == sum(away) do
		if overtimes >= 6 then
			-- Six overtimes is enough. Better team (or home on a tie) hits the game-winner.
			if diff >= 0 then
				home[#home] += 1
			else
				away[#away] += 1
			end
			break
		end
		overtimes += 1
		table.insert(home, math.max(4, 10 + roundRandom(diff * 0.1, rand) + rand(-3, 3)))
		table.insert(away, math.max(4, 10 + roundRandom(-diff * 0.1, rand) + rand(-3, 3)))
	end

	return { home = home, away = away, homeTotal = sum(home), awayTotal = sum(away), overtimes = overtimes }
end

-- Split `total` into whole numbers proportional to weights (largest-remainder method).
function Sim.distribute(total: number, weights: { number }): { number }
	local n = #weights
	local out = table.create(n, 0)
	if n == 0 then
		return out
	end
	local wSum = sum(weights)
	local fracs = {}
	local used = 0
	for i, w in weights do
		local share = if wSum > 0 then total * w / wSum else total / n
		out[i] = math.floor(share)
		used += out[i]
		table.insert(fracs, { i = i, f = share - out[i] })
	end
	table.sort(fracs, function(a, b)
		if a.f == b.f then
			return a.i < b.i
		end
		return a.f > b.f
	end)
	local left = total - used
	local k = 1
	while left > 0 do
		out[fracs[k].i] += 1
		left -= 1
		k = k % n + 1
	end
	return out
end

local REB_WEIGHT: { [string]: number } = { PG = 0.5, SG = 0.6, SF = 0.9, PF = 1.3, C = 1.5 }
local AST_WEIGHT: { [string]: number } = { PG = 2.0, SG = 1.1, SF = 0.9, PF = 0.6, C = 0.5 }

function Sim.boxScore(players: { BoxPlayer }, totalPoints: number, rand: Rand): { BoxLine }
	local ptsW, rebW, astW = {}, {}, {}
	for i, p in players do
		local minutes = if p.bench then 0.45 else 1
		local skill = p.eff / 100
		ptsW[i] = skill ^ 6 * minutes * rand(85, 115) / 100
		rebW[i] = (REB_WEIGHT[p.pos] or 1) * minutes * skill ^ 2 * rand(80, 120) / 100
		astW[i] = (AST_WEIGHT[p.pos] or 1) * minutes * skill ^ 2 * rand(80, 120) / 100
	end
	local pts = Sim.distribute(totalPoints, ptsW)
	local reb = Sim.distribute(rand(38, 50), rebW)
	local ast = Sim.distribute(rand(20, 30), astW)

	local lines: { BoxLine } = {}
	for i, p in players do
		table.insert(lines, { name = p.name, pts = pts[i], reb = reb[i], ast = ast[i] })
	end
	table.sort(lines, function(a, b)
		return a.pts > b.pts
	end)
	return lines
end

return Sim
