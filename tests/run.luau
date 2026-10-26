-- Run from repo root: luau tests/run.luau
local NBAData = require("../src/shared/NBAData")
local Rating = require("../src/shared/Rating")
local Sim = require("../src/shared/Sim")
local Draft = require("../src/shared/Draft")

local failures = 0
local function check(cond: boolean, msg: string)
	if not cond then
		failures += 1
		print("FAIL: " .. msg)
	end
end

-- Data integrity -----------------------------------------------------------
local keys = {}
for _, f in NBAData.franchises do
	check(#f.eras >= 2, f.id .. " needs 2+ eras for Refresh")
	check(#f.color == 3, f.id .. " color")
	for _, era in f.eras do
		check(not keys[era.key], "duplicate key " .. era.key)
		keys[era.key] = true
		check(#era.players >= 7 and #era.players <= 8, era.key .. " has " .. #era.players .. " players (need 7-8)")
		local names = {}
		for _, p in era.players do
			check(not names[p.name], era.key .. " duplicate player " .. p.name)
			names[p.name] = true
			check(p.ovr >= 60 and p.ovr <= 99 and p.ovr % 1 == 0, p.name .. " bad ovr")
			check(#p.positions >= 1, p.name .. " no positions")
			for _, pos in p.positions do
				check(Rating.POS_INDEX[pos] ~= nil, p.name .. " bad position " .. pos)
			end
		end
		check(era.weight > 0, era.key .. " weight")
	end
end
print(("Data: %d franchises, %d team-seasons"):format(#NBAData.franchises, #NBAData.eras))

-- Rating -------------------------------------------------------------------
local function P(name, pos, ovr, key)
	local positions = {}
	for s in string.gmatch(pos, "[^/]+") do
		table.insert(positions, s)
	end
	return { name = name, positions = positions, ovr = ovr, teamKey = key or name }
end

local perfect = {
	P("a", "PG", 90), P("b", "SG", 90), P("c", "SF", 90), P("d", "PF", 90), P("e", "C", 90),
	P("f", "SG", 80), P("g", "SF", 80), P("h", "C", 80),
}
local r = Rating.team(perfect)
-- base = 90*0.8 + 80*0.2 = 88, chem 80 -> +2.4 -> 90
check(r.ovr == 90, "perfect team ovr expected 90 got " .. r.ovr)
check(r.chemistry == 80, "chem expected 80 got " .. r.chemistry)

local wrong = table.clone(perfect)
wrong[1] = P("a", "C", 90) -- center at PG: 4 away -> 66.6
local r2 = Rating.team(wrong)
check(r2.ovr < r.ovr, "out-of-position should lower ovr")
check(r2.natural == 7, "natural count 7")

local sameTeam = {}
for i, p in perfect do
	sameTeam[i] = P(p.name, table.concat(p.positions, "/"), p.ovr, "X_2000")
end
check(Rating.team(sameTeam).chemistry == 100, "same-season chem caps at 100")

local partial = { P("a", "PG", 95), false, false, false, false, false, false, false }
check(Rating.team(partial).ovr == 95, "partial lineup expected 95 got " .. Rating.team(partial).ovr)
check(Rating.team({}).ovr == 0, "empty lineup 0")
check(Rating.distance({ "SF", "PF" }, Rating.SLOTS[8]) == 0, "PF fits bench big")
check(Rating.distance({ "PG" }, Rating.SLOTS[5]) == 4, "PG at C is 4 away")
check(Rating.coinsFor(50) == 10, "min coins")
check(Rating.coinsFor(90) == 120, "coins at 90")

local best, worst = 0, 100
for _, era in NBAData.eras do
	local o = Rating.rosterOvr(era.players)
	best = math.max(best, o)
	worst = math.min(worst, o)
end
print(("CPU team OVR range: %d - %d"):format(worst, best))

-- Sim ----------------------------------------------------------------------
local seed = 12345
local function rand(a: number, b: number): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return a + math.floor(seed / 65536) % (b - a + 1)
end

for _, diff in { 0, 3, 6, 10 } do
	local wins, games = 0, 4000
	for _ = 1, games do
		local g = Sim.play(85 + diff, 85, rand)
		check(g.homeTotal ~= g.awayTotal, "no ties")
		check(#g.home == #g.away and #g.home == 4 + g.overtimes, "period counts")
		if g.homeTotal > g.awayTotal then
			wins += 1
		end
	end
	print(("+%d OVR -> win rate %.0f%%"):format(diff, wins / games * 100))
end

for _ = 1, 500 do
	local players = {}
	for i, slot in Rating.SLOTS do
		table.insert(players, { name = "P" .. i, eff = 70 + rand(0, 29), pos = slot.accepts[1], bench = slot.bench })
	end
	local total = rand(80, 140)
	local box = Sim.boxScore(players, total, rand)
	local s = 0
	for _, b in box do
		s += b.pts
		check(b.pts >= 0 and b.reb >= 0 and b.ast >= 0, "non-negative stats")
	end
	check(s == total, "box points sum " .. s .. " ~= " .. total)
	check(#box == 8, "8 box lines")
end

-- Draft / duels --------------------------------------------------------------
for _ = 1, 300 do
	local duel = Draft.newDuel(NBAData.eras, rand)
	check(duel.roll ~= nil and duel.turn == 1, "duel starts with a roll, side 1 first")
	local picks = 0
	while duel.phase == "drafting" do
		local side = duel.turn
		local round = duel.round
		-- wrong side can't pick
		local okWrong = Draft.duelPick(duel, 3 - side, 1, NBAData.eras, rand)
		check(not okWrong, "other side cannot pick")
		local taken = Draft.takenNames(duel.lineups)
		local idx = Draft.bestPickIndex(duel.roll, Rating.SLOTS[round], taken, rand, 0.7)
		check(idx ~= nil, "always something to pick")
		-- taken players can't be picked
		for i, p in duel.roll.players do
			if taken[p.name] then
				check(not Draft.duelPick(duel, side, i, NBAData.eras, rand), "taken player rejected")
			end
		end
		local ok, err = Draft.duelPick(duel, side, idx :: number, NBAData.eras, rand)
		check(ok, "valid pick failed: " .. tostring(err))
		picks += 1
		if duel.phase == "drafting" and duel.round == round then
			check(duel.turn == 3 - side, "turn passes within a round")
		end
		if duel.phase == "drafting" and duel.round ~= round then
			check(duel.turn == Draft.firstPicker(duel.round), "first picker alternates")
		end
	end
	check(picks == 16, "16 picks per duel, got " .. picks)
	local names = {}
	for s = 1, 2 do
		for i = 1, #Rating.SLOTS do
			local p = duel.lineups[s][i]
			check(p ~= false, "slot filled")
			check(not names[p.name], "no player on both teams: " .. p.name)
			names[p.name] = true
		end
	end
	check(not Draft.duelPick(duel, 1, 1, NBAData.eras, rand), "no picks after done")
end

for _ = 1, 300 do
	local roll = NBAData.eras[rand(1, #NBAData.eras)]
	local r = Draft.rollEra(NBAData.eras, {}, rand, { exclude = roll.key, franchise = roll.franchise })
	check(r ~= nil and r.franchise == roll.franchise and r.key ~= roll.key, "refresh = same franchise, other era")
	local r2 = Draft.rollEra(NBAData.eras, {}, rand, { exclude = roll.key })
	check(r2 ~= nil and r2.key ~= roll.key, "reroll = different team")
end
check(Draft.bestPickIndex(NBAData.byKey.Bulls_1996, Rating.SLOTS[2], {}) == 1, "best SG on '96 Bulls is Jordan")
check(Draft.bestPickIndex(NBAData.byKey.Bulls_1996, Rating.SLOTS[2], { ["Michael Jordan"] = true }) ~= 1, "skips taken")

local d = Sim.distribute(10, { 0, 0, 0 })
check(d[1] + d[2] + d[3] == 10, "distribute zero weights")

if failures == 0 then
	print("ALL TESTS PASSED")
else
	print(failures .. " FAILURE(S)")
	error("tests failed")
end
