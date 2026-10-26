-- Solo mode pages: Home, Draft, Results, Game (vs CPU).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rating = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rating"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Board = require(script.Parent:WaitForChild("Board"))
local Scoreboard = require(script.Parent:WaitForChild("Scoreboard"))

local SoloPages = {}

-- ctx: { addPage(name) -> Frame, act(action, arg), setTab(tab) }
function SoloPages.new(ctx: any)
	local self = {}

	------------------------------------------------------------ HOME
	local home = ctx.addPage("SoloHome")

	local title = Kit.text({
		Size = UDim2.fromScale(1, 0.15),
		Position = UDim2.fromScale(0, 0.02),
		Text = "HOOPS DRAFT",
		FontFace = Theme.font.display,
		TextColor3 = Color3.new(1, 1, 1),
		MaxSize = 76,
		Parent = home,
	})
	Kit.gradient(title, Theme.color.gold, Theme.color.orangeDeep, 90)
	Kit.text({
		Size = UDim2.fromScale(1, 0.05),
		Position = UDim2.fromScale(0, 0.17),
		Text = "Build the strongest NBA team of all time.",
		FontFace = Theme.font.medium,
		TextColor3 = Theme.color.sub,
		MaxSize = 20,
		Parent = home,
	})

	local steps = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.26),
		BackgroundTransparency = 1,
		Parent = home,
	})
	Kit.list(steps, true, UDim.new(0.02, 0), { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	local STEPS = {
		{ "1", "ROLL", "Get a random NBA team from a random season." },
		{ "2", "PICK", "Take ONE player for the open slot. Real positions = more chemistry." },
		{ "3", "PLAY", "Fill 5 starters + 3 bench, earn coins, then play the CPU or a friend." },
	}
	for i, step in STEPS do
		local card = Kit.panel({
			Size = UDim2.fromScale(0.31, 1),
			BackgroundColor3 = Theme.color.panelHi,
			LayoutOrder = i,
			Parent = steps,
		}, 14)
		local num = Kit.text({
			Size = UDim2.fromScale(0.22, 0.28),
			Position = UDim2.fromScale(0.07, 0.08),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.color.orange,
			Text = step[1],
			FontFace = Theme.font.display,
			MaxSize = 28,
			Parent = card,
		})
		Kit.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = num })
		Kit.round(num)
		Kit.text({
			Size = UDim2.fromScale(0.6, 0.2),
			Position = UDim2.fromScale(0.34, 0.12),
			Text = step[2],
			FontFace = Theme.font.display,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 28,
			Parent = card,
		})
		Kit.text({
			Size = UDim2.fromScale(0.86, 0.5),
			Position = UDim2.fromScale(0.07, 0.42),
			Text = step[3],
			FontFace = Theme.font.medium,
			TextColor3 = Theme.color.sub,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			MaxSize = 17,
			Parent = card,
		})
	end

	local statsRow = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.13),
		Position = UDim2.fromScale(0, 0.6),
		BackgroundTransparency = 1,
		Parent = home,
	})
	Kit.list(statsRow, true, UDim.new(0.02, 0), { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	local statValues: { [string]: TextLabel } = {}
	for i, stat in { { "best", "BEST OVR" }, { "drafts", "DRAFTS" }, { "cpu", "VS CPU" }, { "duels", "DUELS" } } do
		local tile = Kit.panel({
			Size = UDim2.fromScale(0.225, 1),
			BackgroundColor3 = Theme.color.panelHi,
			LayoutOrder = i,
			Parent = statsRow,
		}, 12)
		Kit.text({
			Size = UDim2.fromScale(1, 0.3),
			Position = UDim2.fromScale(0, 0.1),
			Text = stat[2],
			FontFace = Theme.font.heavy,
			TextColor3 = Theme.color.sub,
			MaxSize = 12,
			Parent = tile,
		})
		statValues[stat[1]] = Kit.text({
			Size = UDim2.fromScale(1, 0.5),
			Position = UDim2.fromScale(0, 0.42),
			Text = "-",
			FontFace = Theme.font.display,
			MaxSize = 30,
			Parent = tile,
		})
	end

	local startButton = Kit.button({
		Name = "StartDraft",
		Size = UDim2.fromScale(0.44, 0.14),
		Position = UDim2.fromScale(0.05, 0.8),
		Text = "START DRAFT",
		MaxSize = 30,
		Parent = home,
	}, function()
		ctx.act("StartRun")
	end, "primary")
	Kit.button({
		Name = "GoDuels",
		Size = UDim2.fromScale(0.44, 0.14),
		Position = UDim2.fromScale(0.51, 0.8),
		Text = "DRAFT DUELS",
		MaxSize = 30,
		Parent = home,
	}, function()
		ctx.setTab("duels")
	end, "purple")

	------------------------------------------------------------ DRAFT
	local draft = ctx.addPage("SoloDraft")

	local pickLabel = Kit.text({
		Size = UDim2.fromScale(0.3, 0.07),
		Text = "",
		FontFace = Theme.font.display,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 30,
		Parent = draft,
	})
	local needPill = Kit.text({
		Size = UDim2.fromScale(0.17, 0.055),
		Position = UDim2.fromScale(0.3, 0.008),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.orange,
		Text = "",
		FontFace = Theme.font.heavy,
		MaxSize = 16,
		Parent = draft,
	})
	Kit.corner(needPill, 8)
	Kit.gloss(needPill, 8)

	local progress = Kit.make("Frame", {
		Size = UDim2.fromScale(0.32, 0.018),
		Position = UDim2.fromScale(0.5, 0.027),
		BackgroundTransparency = 1,
		Parent = draft,
	})
	Kit.list(progress, true, UDim.new(0.02, 0))
	local segments: { Frame } = {}
	for i = 1, #Rating.SLOTS do
		local seg = Kit.make("Frame", {
			Size = UDim2.fromScale(0.105, 1),
			BackgroundColor3 = Theme.color.panelHi2,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = progress,
		})
		Kit.round(seg)
		segments[i] = seg
	end

	Kit.button({
		Name = "Restart",
		Size = UDim2.new(0.15, 0, 0.05, 10),
		Position = UDim2.fromScale(0.85, 0.004),
		Text = "RESTART",
		MaxSize = 15,
		Parent = draft,
	}, function()
		ctx.act("StartRun")
	end, "ghost")

	local boardHolder = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.76),
		Position = UDim2.fromScale(0, 0.09),
		BackgroundTransparency = 1,
		Parent = draft,
	})
	local board = Board.new(boardHolder)

	local rerollButton = Kit.button({
		Name = "Reroll",
		Size = UDim2.fromScale(0.49, 0.12),
		Position = UDim2.fromScale(0, 0.88),
		Text = "",
		RichText = true,
		MaxSize = 22,
		Parent = draft,
	}, function()
		ctx.act("Reroll")
	end, "blue")
	local refreshButton = Kit.button({
		Name = "Refresh",
		Size = UDim2.fromScale(0.49, 0.12),
		Position = UDim2.fromScale(0.51, 0.88),
		Text = "",
		RichText = true,
		MaxSize = 22,
		Parent = draft,
	}, function()
		ctx.act("Refresh")
	end, "purple")

	------------------------------------------------------------ RESULTS
	local results = ctx.addPage("SoloResults")

	Kit.text({
		Size = UDim2.fromScale(1, 0.06),
		Position = UDim2.fromScale(0, 0.03),
		Text = "DRAFT COMPLETE",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.sub,
		MaxSize = 22,
		Parent = results,
	})
	local resOvr = Kit.text({
		Size = UDim2.fromScale(1, 0.27),
		Position = UDim2.fromScale(0, 0.09),
		Text = "0",
		FontFace = Theme.font.display,
		TextColor3 = Color3.new(1, 1, 1),
		MaxSize = 150,
		Parent = results,
	})
	local resOvrGradient = Kit.gradient(resOvr, Theme.color.gold, Theme.color.orangeDeep, 90)
	local resTier = Kit.text({
		Size = UDim2.fromScale(0.3, 0.07),
		Position = UDim2.fromScale(0.35, 0.37),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.gold,
		Text = "",
		FontFace = Theme.font.display,
		TextColor3 = Theme.color.black,
		MaxSize = 26,
		Parent = results,
	})
	Kit.corner(resTier, 10)
	Kit.gloss(resTier, 10)

	local resChem = Kit.text({
		Size = UDim2.fromScale(1, 0.045),
		Position = UDim2.fromScale(0, 0.46),
		Text = "",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.sub,
		MaxSize = 18,
		Parent = results,
	})
	local resCoins = Kit.text({
		Size = UDim2.fromScale(1, 0.07),
		Position = UDim2.fromScale(0, 0.52),
		Text = "",
		FontFace = Theme.font.display,
		TextColor3 = Theme.color.gold,
		MaxSize = 34,
		Parent = results,
	})
	local resBest = Kit.text({
		Size = UDim2.fromScale(0.44, 0.065),
		Position = UDim2.fromScale(0.28, 0.61),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.greenDeep,
		Text = "NEW PERSONAL BEST!",
		FontFace = Theme.font.display,
		MaxSize = 24,
		Visible = false,
		Parent = results,
	})
	Kit.corner(resBest, 10)
	Kit.gloss(resBest, 10)

	local resButtons = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.13),
		Position = UDim2.fromScale(0, 0.82),
		BackgroundTransparency = 1,
		Parent = results,
	})
	Kit.list(resButtons, true, UDim.new(0.02, 0), { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	Kit.button({
		Name = "PlayCPU",
		Size = UDim2.fromScale(0.31, 1),
		Text = "PLAY VS CPU",
		LayoutOrder = 1,
		MaxSize = 24,
		Parent = resButtons,
	}, function()
		ctx.act("SimGame")
	end, "green")
	Kit.button({
		Name = "DraftAgain",
		Size = UDim2.fromScale(0.31, 1),
		Text = "DRAFT AGAIN",
		LayoutOrder = 2,
		MaxSize = 24,
		Parent = resButtons,
	}, function()
		ctx.act("StartRun")
	end, "primary")
	Kit.button({
		Name = "ResultsDuels",
		Size = UDim2.fromScale(0.31, 1),
		Text = "DRAFT DUELS",
		LayoutOrder = 3,
		MaxSize = 24,
		Parent = resButtons,
	}, function()
		ctx.setTab("duels")
	end, "purple")

	------------------------------------------------------------ GAME vs CPU
	local gamePage = ctx.addPage("SoloGame")
	local scoreHolder = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.86),
		BackgroundTransparency = 1,
		Parent = gamePage,
	})
	local scoreboard = Scoreboard.new(scoreHolder)
	Kit.button({
		Name = "GameDraftAgain",
		Size = UDim2.fromScale(0.4, 0.11),
		Position = UDim2.fromScale(0.3, 0.89),
		Text = "DRAFT AGAIN",
		MaxSize = 26,
		Parent = gamePage,
	}, function()
		ctx.act("StartRun")
	end, "primary")

	------------------------------------------------------------ render

	local shownResult = nil
	local shownGameId = nil

	-- Returns the page to show.
	function self.render(state: any): string
		local profile = state.profile
		statValues.best.Text = tostring(profile.BestOVR)
		statValues.drafts.Text = tostring(profile.Drafts)
		statValues.cpu.Text = ("%d-%d"):format(profile.Wins, profile.Losses)
		statValues.duels.Text = ("%d-%d"):format(profile.DuelWins, profile.DuelLosses)
		startButton.Text = "START DRAFT"

		local run = state.run
		if not run then
			return "SoloHome"
		end

		if run.phase == "drafting" then
			local slot = Rating.SLOTS[run.slot]
			pickLabel.Text = ("PICK %d OF %d"):format(run.slot, #Rating.SLOTS)
			needPill.Text = "NEED: " .. slot.label
			for i, seg in segments do
				seg.BackgroundColor3 = if i < run.slot
					then Theme.color.orange
					elseif i == run.slot then Theme.color.text
					else Theme.color.panelHi2
			end
			rerollButton.Text = ("REROLL  <font transparency=\"0.35\">new team</font>  (%d)"):format(profile.Rerolls)
			refreshButton.Text = ("REFRESH  <font transparency=\"0.35\">new era</font>  (%d)"):format(profile.Refreshes)
			Kit.setDisabled(rerollButton, profile.Rerolls < 1)
			Kit.setDisabled(refreshButton, profile.Refreshes < 1)

			board:render(run.roll, slot, run.rollId, {
				canPick = true,
				takenInfo = function(i)
					if run.roll.taken[i] then
						return "ON YOUR TEAM", true
					end
					return nil, nil
				end,
				onPick = function(i)
					ctx.act("Pick", i)
				end,
			})
			shownResult = nil
			return "SoloDraft"
		end

		if run.game then
			local g = run.game
			if g.id ~= shownGameId then
				shownGameId = g.id
				scoreboard:show({
					leftName = "YOUR TEAM",
					leftOvr = g.myOvr,
					rightName = string.upper(g.oppLabel),
					rightOvr = g.oppOvr,
					left = g.home,
					right = g.away,
					win = g.win,
					resultText = (if g.win then "VICTORY" else "DEFEAT") .. ("  +%d COINS"):format(g.coins),
					box = g.box,
				}, true)
			end
			return "SoloGame"
		end

		local r = run.result
		if shownResult ~= r.ovr .. "/" .. r.coins then
			shownResult = r.ovr .. "/" .. r.coins
			local tier = Theme.tier[r.tier]
			resOvrGradient.Color = ColorSequence.new(tier.top, tier.bottom)
			resTier.BackgroundColor3 = tier.top
			resTier.Text = r.tier .. " TEAM"
			resTier.TextColor3 = Theme.textOn(tier.top)
			Kit.countUp(resOvr, 40, r.ovr, 1.2)
			Kit.pop(resTier, 1.1, 0.4)
			resChem.Text = ("CHEMISTRY %d / 100"):format(r.chemistry)
			resCoins.Text = ("+%s COINS"):format(Kit.fmt(r.coins))
			resBest.Visible = r.newBest
			if r.newBest then
				Kit.pop(resBest, 1.3, 0.3)
			end
		end
		return "SoloResults"
	end

	function self.setCompact(compact: boolean)
		board:setCompact(compact)
		scoreboard:setCompact(compact)
	end

	-- Re-spin the board next time (after leaving and coming back).
	function self.resetBoard()
		board:reset()
	end

	return self
end

return SoloPages
