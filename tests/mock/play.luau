-- End-to-end playtest: real server + client scripts on the mock engine, driven by clicking buttons.
-- Run from repo root:  python3 tests/mock/gen.py <Full-API-Dump.json> && luau tests/mock/play.luau
local R = require("./roblox")

local function expect(cond: any, msg: string)
	if not cond then
		R.fail("EXPECT: " .. msg)
		print("  x " .. msg)
	end
end

local step = 0
local function log(msg: string)
	step += 1
	print(("[%5.1fs] %d. %s"):format(R.now(), step, msg))
end

-- Click an untaken, clickable card. Returns true if one was clicked.
local function pickCard(vm: any): boolean
	for i = 1, 8 do
		local card = R.button(vm, "Card" .. i)
		if card then
			local overlay = card:FindFirstChild("Overlay")
			if overlay and not overlay.Visible then
				return R.click(vm, "Card" .. i)
			end
		end
	end
	return false
end

local layoutIssues: { [string]: { string } } = {}
local SCREENS = { { "desktop", 1366, 768, 10 }, { "laptop", 1280, 720, 9 }, { "phone", 844, 390, 7 }, { "small-phone", 667, 375, 7 } }
local function checkLayout(vm: any, screen: string)
	for _, sc in SCREENS do
		R.setViewport(sc[2], sc[3])
		R.run(0.4)
		for _, issue in R.layoutCheck(vm, sc[2], sc[3], sc[4]) do
			local key = sc[1] .. " | " .. issue:gsub("[%d%.]+px", "Npx"):gsub("%b()", "")
			if not layoutIssues[key] then
				layoutIssues[key] = { screen, issue }
			end
		end
	end
	R.setViewport(1366, 768)
	R.run(0.4)
end

R.startServer()
R.run(1)

local DS = R.serverModule("src/server/DataService.luau")
expect(DS ~= nil, "DataService loaded on server")
local function data(vm: any): any
	return DS.get(vm.player)
end

------------------------------------------------------------------ join
log("Alice and Bob join")
local A = R.addPlayer(1001, "Alice")
local B = R.addPlayer(1002, "Bob")
R.run(3)
expect(R.button(A, "StartDraft"), "Alice sees START DRAFT")
expect(R.button(B, "StartDraft"), "Bob sees START DRAFT")
expect(R.visibleText(A, "HOOPS DRAFT"), "home title visible")
expect(R.visibleText(A, "100"), "coins shown in top bar")
checkLayout(A, "home")

------------------------------------------------------------------ solo draft
log("Alice drafts a full solo team")
R.click(A, "StartDraft")
R.run(1.5)
for pick = 1, 8 do
	expect(R.visibleText(A, ("PICK %d OF 8"):format(pick)), "pick header " .. pick)
	if pick == 1 or pick == 6 then
		checkLayout(A, "solo draft pick " .. pick)
	end
	expect(pickCard(A), "card clickable on pick " .. pick)
	R.run(1.5)
end
expect(R.button(A, "PlayCPU"), "results page after 8 picks")
expect(R.visibleText(A, "DRAFT COMPLETE"), "draft complete text")
R.run(2)
checkLayout(A, "solo results")
local d = data(A)
expect(d.Drafts == 1, "Drafts = 1")
expect(d.BestOVR > 0, "BestOVR set")
expect(d.Coins > 100, "coins awarded")
log(("Alice's team rated %d, coins now %d"):format(d.BestOVR, d.Coins))

log("Alice plays the CPU")
R.click(A, "PlayCPU")
R.run(7)
expect(R.button(A, "GameDraftAgain"), "game page shows draft again")
expect(R.visibleText(A, "FINAL"), "scoreboard reached FINAL")
checkLayout(A, "solo game")
expect(d.Wins + d.Losses == 1, "CPU game recorded")

log("Reroll and refresh")
R.click(A, "GameDraftAgain")
R.run(1.5)
local rerolls, refreshes = d.Rerolls, d.Refreshes
R.click(A, "Reroll")
R.run(1.5)
R.click(A, "Refresh")
R.run(1.5)
expect(d.Rerolls == rerolls - 1, "reroll used")
expect(d.Refreshes == refreshes - 1, "refresh used")
expect(pickCard(A), "can pick after reroll/refresh")
R.run(1)

------------------------------------------------------------------ shop, codes, leaderboard
log("Shop: buy 5 rerolls")
local coins = d.Coins
rerolls = d.Rerolls
R.click(A, "OpenShop")
R.run(0.5)
checkLayout(A, "shop")
R.click(A, "Buy_rerolls5")
R.run(0.5)
expect(d.Coins == coins - 100, "shop took 100 coins")
expect(d.Rerolls == rerolls + 5, "shop gave 5 rerolls")
expect(R.visibleText(A, "Bought 5 Rerolls!"), "purchase toast")
R.click(A, "CloseModal")
R.run(0.5)

log("Codes: redeem NBA twice")
R.click(A, "OpenCodes")
R.run(0.5)
checkLayout(A, "codes")
local box = R.findAll(A, function(i)
	return i.ClassName == "TextBox" and i.Name == "CodeBox"
end)[1]
expect(box, "code box exists")
rerolls = d.Rerolls
box.Text = " nba "
R.click(A, "Redeem")
R.run(0.5)
expect(d.Rerolls == rerolls + 10, "code gave 10 rerolls")
expect(box.Text == "", "code box cleared")
box.Text = "NBA"
R.click(A, "Redeem")
R.run(0.5)
expect(R.visibleText(A, "already used"), "second redeem rejected")
R.click(A, "CloseModal")
R.run(0.5)

log("Leaderboards")
R.click(A, "OpenLeaders")
R.run(1)
expect(R.visibleText(A, "Alice"), "Alice on best-OVR board")
checkLayout(A, "leaderboard")
R.click(A, "Board_duel")
R.run(1)
expect(R.visibleText(A, "No one yet") , "duel board empty before duels")
R.click(A, "CloseModal")
R.run(0.5)

------------------------------------------------------------------ duel by challenge
local function playDuel(vm1: any, vm2: any, timeoutEvery: number?)
	local picks = 0
	for _ = 1, 60 do
		if R.button(vm1, "Rematch") and R.button(vm2, "Rematch") then
			break
		end
		local mover = nil
		if R.visibleText(vm1, "YOUR PICK!") then
			mover = vm1
		elseif R.visibleText(vm2, "YOUR PICK!") then
			mover = vm2
		end
		if mover then
			picks += 1
			if timeoutEvery and picks % timeoutEvery == 0 then
				R.run(16) -- let the timer run out: auto-pick
			else
				expect(pickCard(mover), "duel card clickable for " .. mover.name)
				R.run(1.2)
			end
		else
			R.run(0.5)
		end
	end
	return picks
end

log("Alice challenges Bob from the Duels tab")
R.click(A, "Tab_duels")
R.run(0.5)
expect(R.visibleText(A, "PLAYERS IN THIS SERVER (1)"), "Alice sees 1 other player")
checkLayout(A, "duel lobby")
R.click(A, "Challenge_1002")
R.run(1)
expect(R.visibleText(A, "Waiting for Bob"), "Alice sees waiting card")
expect(R.button(B, "AcceptInvite"), "Bob gets invite popup")
expect(R.visibleText(B, "challenged you"), "invite text")
checkLayout(A, "lobby waiting")
checkLayout(B, "invite popup")
R.click(B, "AcceptInvite")
R.run(2)
expect(R.visibleText(A, "ROUND 1 / 8"), "Alice in duel draft")
expect(R.visibleText(B, "ROUND 1 / 8"), "Bob in duel draft")
expect(R.visibleText(A, "YOUR PICK!"), "Alice (challenger) picks first")
expect(R.visibleText(B, "ALICE IS PICKING"), "Bob waits")
R.run(1)
checkLayout(A, "duel draft")
checkLayout(B, "duel draft waiting")

log("Bob tries to pick out of turn (should be ignored)")
local before = data(B).Coins
pickCard(B)
R.run(1)
expect(R.visibleText(A, "YOUR PICK!"), "still Alice's turn")

log("Duel draft with some timer auto-picks")
local picks = playDuel(A, B, 5)
expect(picks >= 16, "16 picks made, got " .. picks)
R.run(8)
expect(R.button(A, "BackToLobby") and R.button(B, "BackToLobby"), "both on duel result")
checkLayout(A, "duel result")
local aw, bw = data(A).DuelWins, data(B).DuelWins
expect(aw + bw == 1, "exactly one duel winner")
expect(data(A).DuelLosses + data(B).DuelLosses == 1, "exactly one loser")
expect(R.visibleText(A, "COINS"), "result banner shows coins")
log(("Duel 1 winner: %s"):format(if aw == 1 then "Alice" else "Bob"))
expect(data(B).Coins > before, "Bob got duel coins")

log("Tab switch is fine on results; Alice asks for a rematch")
R.click(B, "BackToLobby")
R.run(1)
expect(R.button(B, "QuickMatch"), "Bob back in lobby")
R.click(A, "Rematch")
R.run(1)
expect(R.button(B, "AcceptInvite"), "Bob gets rematch invite")
R.click(B, "AcceptInvite")
R.run(2)
expect(R.visibleText(A, "ROUND 1 / 8"), "rematch started")

log("Alice can't leave to Solo mid-duel; then forfeits")
R.click(A, "Tab_solo")
R.run(0.5)
expect(R.visibleText(A, "Finish your duel first"), "tab switch blocked")
expect(R.visibleText(A, "ROUND 1 / 8"), "still in duel")
local bWins = data(B).DuelWins
R.click(A, "Forfeit")
R.run(2)
expect(data(B).DuelWins == bWins + 1, "Bob wins by forfeit")
expect(R.visibleText(A, "YOU FORFEITED"), "Alice sees forfeit")
expect(R.visibleText(B, "ALICE FORFEITED"), "Bob sees forfeit")
checkLayout(B, "forfeit result")
R.click(A, "BackToLobby")
R.click(B, "BackToLobby")
R.run(1)

------------------------------------------------------------------ quick match + leaving
log("Quick match pairs Alice and Bob")
R.click(A, "QuickMatch")
R.run(1)
expect(R.visibleText(A, "SEARCHING"), "Alice searching")
expect(R.visibleText(B, "SEARCHING  •"), "Bob sees Alice searching")
R.click(B, "QuickMatch")
R.run(2)
expect(R.visibleText(A, "ROUND 1 / 8") and R.visibleText(B, "ROUND 1 / 8"), "quick match started")
R.click(A, "Card1")
R.run(1.5)

log("Bob leaves mid-duel -> Alice wins by forfeit")
local aWins = data(A).DuelWins
local bLosses = data(B).DuelLosses
R.removePlayer(B)
R.run(2)
expect(data(A).DuelWins == aWins + 1, "Alice credited the win")
expect(R.visibleText(A, "BOB FORFEITED"), "Alice sees Bob forfeited")
local saved = nil
R.run(1)
R.click(A, "BackToLobby")
R.run(1)
expect(R.visibleText(A, "Nobody else is here yet"), "lobby empty after Bob left")

------------------------------------------------------------------ bot duel
log("Alice practices vs the bot")
local coinsBefore = data(A).Coins
local duelWinsBefore = data(A).DuelWins
R.click(A, "BotDuel")
R.run(2)
expect(R.visibleText(A, "ROUND 1 / 8"), "bot duel started")
for _ = 1, 80 do
	if R.button(A, "Rematch") then
		break
	end
	if R.visibleText(A, "YOUR PICK!") then
		pickCard(A)
	end
	R.run(1)
end
R.run(8)
expect(R.button(A, "Rematch"), "bot duel finished")
expect(data(A).Coins > coinsBefore, "bot duel paid coins")
expect(data(A).DuelWins == duelWinsBefore, "bot duels don't count for the duel leaderboard")
R.click(A, "BackToLobby")
R.run(1)

------------------------------------------------------------------ invites: expire + decline
log("Cara joins; Alice's challenge expires, then Cara declines one")
local C = R.addPlayer(1003, "Cara")
R.run(3)
R.click(A, "Challenge_1003")
R.run(1)
expect(R.button(C, "AcceptInvite"), "Cara invited")
R.run(21)
expect(R.button(C, "AcceptInvite") == nil, "invite popup gone after expiry")
expect(R.visibleText(A, "didn't answer"), "Alice told it expired")
R.run(3)
R.click(A, "Challenge_1003")
R.run(1)
R.click(C, "DeclineInvite")
R.run(1)
expect(R.visibleText(A, "declined"), "Alice told Cara declined")

------------------------------------------------------------------ data saving
log("Saving: Cara leaves, data is in the DataStore")
R.removePlayer(C)
R.run(3)
local DSmod = R.serverModule("src/server/DataService.luau")
expect(DSmod.get(C.player) == nil, "Cara's profile released")

log("DataStore outage: a new player still gets a working session")
R.datastoreFailing = true
local D = R.addPlayer(1004, "Dan")
R.run(6)
expect(R.button(D, "StartDraft"), "Dan can play with DataStores down")
R.click(D, "StartDraft")
R.run(1.5)
expect(pickCard(D), "Dan can pick")
R.run(1.5)
R.datastoreFailing = false
R.run(5)

log("Alice leaves and rejoins: coins and duel record come back from the DataStore")
local saved = { Coins = data(A).Coins, DuelWins = data(A).DuelWins, BestOVR = data(A).BestOVR, Codes = data(A).Codes.NBA }
R.removePlayer(A)
R.run(3)
local A2 = R.addPlayer(1001, "Alice")
R.run(4)
local d2 = data(A2)
expect(d2 ~= nil, "Alice reloaded")
if d2 then
	expect(d2.Coins == saved.Coins, ("coins persisted (%s vs %s)"):format(tostring(d2.Coins), tostring(saved.Coins)))
	expect(d2.DuelWins == saved.DuelWins, "duel wins persisted")
	expect(d2.BestOVR == saved.BestOVR, "best OVR persisted")
	expect(d2.Codes.NBA == saved.Codes, "redeemed codes persisted")
end
expect(R.visibleText(A2, tostring(saved.BestOVR)), "rejoined UI shows best OVR")
R.run(2)

------------------------------------------------------------------ report
print()
local keys = {}
for k in layoutIssues do
	table.insert(keys, k)
end
table.sort(keys)
if #keys > 0 then
	print(("%d layout issue(s):"):format(#keys))
	for _, k in keys do
		local entry = layoutIssues[k]
		print(("  [%s] %s: %s"):format(k:match("^(%w+)"), entry[1], entry[2]))
	end
end
local realWarnings = {}
for _, w in R.warnings do
	if not w:find("will not save") and not w:find("Load attempt") and not w:find("Fetch failed") then
		table.insert(realWarnings, w)
	end
end
if #realWarnings > 0 then
	print(("%d warning(s):"):format(#realWarnings))
	for i = 1, math.min(10, #realWarnings) do
		print("  " .. realWarnings[i])
	end
end
if #R.errors > 0 then
	print(("%d ERROR(S):"):format(#R.errors))
	for i = 1, math.min(15, #R.errors) do
		print("---\n" .. R.errors[i])
	end
	error("playtest failed")
end
print("PLAYTEST PASSED")
