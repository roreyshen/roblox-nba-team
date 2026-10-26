-- Duel pages: Lobby (players list, quick match, bot), live Draft, and Result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rating = require(Shared:WaitForChild("Rating"))
local Config = require(Shared:WaitForChild("Config"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Board = require(script.Parent:WaitForChild("Board"))
local Scoreboard = require(script.Parent:WaitForChild("Scoreboard"))

local DuelPages = {}

local STATUS_STYLE = {
	idle = { "READY", Theme.color.green },
	searching = { "SEARCHING", Theme.color.gold },
	dueling = { "IN A DUEL", Theme.color.red },
}

local function secondsLeft(deadline: number): number
	return math.max(0, deadline - Workspace:GetServerTimeNow())
end

-- ctx: { addPage(name) -> Frame, act(action, arg), isVisible(name) -> boolean }
function DuelPages.new(ctx: any)
	local self = {}

	------------------------------------------------------------ LOBBY
	local lobby = ctx.addPage("DuelLobby")

	local left = Kit.panel({
		Size = UDim2.fromScale(0.4, 1),
		BackgroundColor3 = Theme.color.panelHi,
		Parent = lobby,
	}, 14)
	Kit.pad(left, 16, 14)
	local leftTitle = Kit.text({
		Size = UDim2.fromScale(1, 0.12),
		Text = "DRAFT DUELS",
		FontFace = Theme.font.display,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 44,
		Parent = left,
	})
	Kit.gradient(leftTitle, Theme.color.purple, Theme.color.blue, 0)
	Kit.text({
		Size = UDim2.fromScale(1, 0.26),
		Position = UDim2.fromScale(0, 0.13),
		Text = ("Take turns drafting from the SAME rolled team. If they take Jordan, he's gone. %d seconds per pick, then your teams play.\n\nWin: +%d coins   Loss: +%d coins"):format(
			Config.PICK_SECONDS,
			Config.DUEL_WIN_COINS,
			Config.DUEL_LOSS_COINS
		),
		FontFace = Theme.font.medium,
		TextColor3 = Theme.color.sub,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxSize = 17,
		Parent = left,
	})
	local quickButton = Kit.button({
		Name = "QuickMatch",
		Size = UDim2.fromScale(1, 0.15),
		Position = UDim2.fromScale(0, 0.42),
		Text = "QUICK MATCH",
		MaxSize = 28,
		Parent = left,
	}, function()
		ctx.act("QuickMatch")
	end, "primary")
	local botButton = Kit.button({
		Name = "BotDuel",
		Size = UDim2.fromScale(1, 0.11),
		Position = UDim2.fromScale(0, 0.6),
		Text = "PRACTICE VS BOT",
		MaxSize = 20,
		Parent = left,
	}, function()
		ctx.act("BotDuel")
	end, "dark")
	local recordLabel = Kit.text({
		Size = UDim2.fromScale(1, 0.06),
		Position = UDim2.fromScale(0, 0.73),
		Text = "",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.sub,
		MaxSize = 16,
		Parent = left,
	})

	local outgoingCard = Kit.panel({
		Size = UDim2.fromScale(1, 0.17),
		Position = UDim2.fromScale(0, 0.83),
		BackgroundColor3 = Theme.color.panel,
		Visible = false,
		Parent = left,
	}, 12)
	local outgoingLabel = Kit.text({
		Size = UDim2.fromScale(0.62, 0.8),
		Position = UDim2.fromScale(0.04, 0.1),
		Text = "",
		FontFace = Theme.font.heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 16,
		Parent = outgoingCard,
	})
	Kit.button({
		Name = "CancelChallenge",
		Size = UDim2.fromScale(0.3, 0.6),
		Position = UDim2.fromScale(0.67, 0.2),
		Text = "CANCEL",
		MaxSize = 16,
		Parent = outgoingCard,
	}, function()
		ctx.act("CancelChallenge")
	end, "red")

	local right = Kit.panel({
		Size = UDim2.fromScale(0.58, 1),
		Position = UDim2.fromScale(0.42, 0),
		BackgroundColor3 = Theme.color.panelHi,
		Parent = lobby,
	}, 14)
	Kit.pad(right, 14, 12)
	local playersTitle = Kit.text({
		Size = UDim2.fromScale(1, 0.08),
		Text = "PLAYERS IN THIS SERVER",
		FontFace = Theme.font.display,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 26,
		Parent = right,
	})
	local list = Kit.make("ScrollingFrame", {
		Name = "PlayerList",
		Size = UDim2.fromScale(1, 0.9),
		Position = UDim2.fromScale(0, 0.1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.color.dim,
		Parent = right,
	})
	Kit.list(list, false, UDim.new(0, 8))
	local emptyLabel = Kit.text({
		Size = UDim2.fromScale(0.9, 0.3),
		Position = UDim2.fromScale(0.05, 0.35),
		Text = "Nobody else is here yet.\nInvite a friend, or practice vs the bot!",
		FontFace = Theme.font.medium,
		TextColor3 = Theme.color.dim,
		MaxSize = 20,
		Visible = false,
		Parent = right,
	})

	local function playerRow(entry: any, order: number, canChallenge: boolean)
		local row = Kit.make("Frame", {
			Name = "Player_" .. entry.userId,
			Size = UDim2.new(1, -8, 0, 64),
			BackgroundColor3 = Theme.color.panel,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = list,
		})
		Kit.corner(row, 12)
		local avatar = Kit.make("ImageLabel", {
			Size = UDim2.fromOffset(48, 48),
			Position = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Theme.color.panelHi2,
			BorderSizePixel = 0,
			Image = Kit.headshot(entry.userId),
			Parent = row,
		})
		Kit.round(avatar)
		Kit.text({
			Size = UDim2.new(0.5, -64, 0, 26),
			Position = UDim2.fromOffset(66, 8),
			Text = entry.name,
			FontFace = Theme.font.heavy,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 20,
			Parent = row,
		})
		local style = STATUS_STYLE[entry.status] or STATUS_STYLE.idle
		local statusText = Kit.text({
			Size = UDim2.new(0.5, -64, 0, 18),
			Position = UDim2.fromOffset(66, 36),
			Text = ("%s  •  %d duel wins"):format(style[1], entry.duelWins),
			FontFace = Theme.font.heavy,
			TextColor3 = style[2],
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 13,
			Parent = row,
		})
		statusText.Name = "Status"
		local challenge = Kit.button({
			Name = "Challenge_" .. entry.userId,
			Size = UDim2.new(0.34, 0, 0, 44),
			Position = UDim2.new(0.64, 0, 0, 10),
			Text = "CHALLENGE",
			MaxSize = 18,
			Parent = row,
		}, function()
			ctx.act("Challenge", entry.userId)
		end, "green")
		Kit.setDisabled(challenge, not canChallenge or entry.status == "dueling")
	end

	------------------------------------------------------------ DRAFT
	local draft = ctx.addPage("DuelDraft")

	local roundLabel = Kit.text({
		Size = UDim2.fromScale(0.26, 0.07),
		Text = "",
		FontFace = Theme.font.display,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 30,
		Parent = draft,
	})
	local turnPill = Kit.text({
		Name = "TurnPill",
		Size = UDim2.fromScale(0.4, 0.07),
		Position = UDim2.fromScale(0.27, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.green,
		Text = "",
		FontFace = Theme.font.display,
		MaxSize = 24,
		Parent = draft,
	})
	Kit.corner(turnPill, 10)
	Kit.gloss(turnPill, 10)
	local timerLabel = Kit.text({
		Size = UDim2.fromScale(0.12, 0.07),
		Position = UDim2.fromScale(0.68, 0),
		Text = "",
		FontFace = Theme.font.display,
		MaxSize = 30,
		Parent = draft,
	})
	Kit.button({
		Name = "Forfeit",
		Size = UDim2.new(0.16, 0, 0.05, 10),
		Position = UDim2.fromScale(0.84, 0.005),
		Text = "FORFEIT",
		MaxSize = 15,
		Parent = draft,
	}, function()
		ctx.act("Forfeit")
	end, "ghost")

	local timerBar = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.012),
		Position = UDim2.fromScale(0, 0.085),
		BackgroundColor3 = Theme.color.panelHi2,
		BorderSizePixel = 0,
		Parent = draft,
	})
	Kit.round(timerBar)
	local timerFill = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.color.green,
		BorderSizePixel = 0,
		Parent = timerBar,
	})
	Kit.round(timerFill)

	local boardHolder = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.63),
		Position = UDim2.fromScale(0, 0.11),
		BackgroundTransparency = 1,
		Parent = draft,
	})
	local board = Board.new(boardHolder)

	local feed = Kit.text({
		Size = UDim2.fromScale(1, 0.045),
		Position = UDim2.fromScale(0, 0.75),
		Text = "",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.sub,
		RichText = true,
		MaxSize = 16,
		Parent = draft,
	})

	local oppPanel = Kit.panel({
		Size = UDim2.fromScale(1, 0.19),
		Position = UDim2.fromScale(0, 0.81),
		BackgroundColor3 = Theme.color.panelHi,
		Parent = draft,
	}, 12)
	Kit.pad(oppPanel, 10, 6)
	local oppHeader = Kit.text({
		Size = UDim2.fromScale(1, 0.3),
		Text = "",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.red,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 16,
		Parent = oppPanel,
	})
	local oppChips = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.66),
		Position = UDim2.fromScale(0, 0.34),
		BackgroundTransparency = 1,
		Parent = oppPanel,
	})
	Kit.list(oppChips, true, UDim.new(0.008, 0))
	local chipLabels: { { name: TextLabel, ovr: TextLabel } } = {}
	for i, slot in Rating.SLOTS do
		local chip = Kit.make("Frame", {
			Size = UDim2.fromScale(0.118, 1),
			BackgroundColor3 = Theme.color.panel,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = oppChips,
		})
		Kit.corner(chip, 8)
		Kit.text({
			Size = UDim2.fromScale(1, 0.3),
			Position = UDim2.fromScale(0, 0.04),
			Text = slot.short,
			FontFace = Theme.font.heavy,
			TextColor3 = Theme.color.dim,
			MaxSize = 11,
			Parent = chip,
		})
		local ovr = Kit.text({
			Size = UDim2.fromScale(1, 0.36),
			Position = UDim2.fromScale(0, 0.3),
			Text = "-",
			FontFace = Theme.font.display,
			MaxSize = 20,
			Parent = chip,
		})
		local name = Kit.text({
			Size = UDim2.fromScale(0.94, 0.28),
			Position = UDim2.fromScale(0.03, 0.68),
			Text = "",
			FontFace = Theme.font.bold,
			TextColor3 = Theme.color.sub,
			MaxSize = 11,
			Parent = chip,
		})
		chipLabels[i] = { name = name, ovr = ovr }
	end

	------------------------------------------------------------ RESULT
	local resultPage = ctx.addPage("DuelResult")
	local scoreHolder = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.86),
		BackgroundTransparency = 1,
		Parent = resultPage,
	})
	local scoreboard = Scoreboard.new(scoreHolder)
	local forfeitPanel = Kit.panel({
		Size = UDim2.fromScale(1, 0.86),
		BackgroundColor3 = Theme.color.panelHi,
		Visible = false,
		Parent = resultPage,
	}, 14)
	local forfeitTitle = Kit.text({
		Size = UDim2.fromScale(0.9, 0.25),
		Position = UDim2.fromScale(0.05, 0.25),
		Text = "",
		FontFace = Theme.font.display,
		MaxSize = 60,
		Parent = forfeitPanel,
	})
	local forfeitSub = Kit.text({
		Size = UDim2.fromScale(0.9, 0.1),
		Position = UDim2.fromScale(0.05, 0.52),
		Text = "",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.gold,
		MaxSize = 26,
		Parent = forfeitPanel,
	})

	local resultButtons = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.11),
		Position = UDim2.fromScale(0, 0.89),
		BackgroundTransparency = 1,
		Parent = resultPage,
	})
	Kit.list(resultButtons, true, UDim.new(0.03, 0), { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	Kit.button({
		Name = "Rematch",
		Size = UDim2.fromScale(0.35, 1),
		Text = "REMATCH",
		LayoutOrder = 1,
		MaxSize = 24,
		Parent = resultButtons,
	}, function()
		ctx.act("Rematch")
	end, "green")
	Kit.button({
		Name = "BackToLobby",
		Size = UDim2.fromScale(0.35, 1),
		Text = "BACK TO LOBBY",
		LayoutOrder = 2,
		MaxSize = 24,
		Parent = resultButtons,
	}, function()
		ctx.act("DismissDuel")
	end, "dark")

	------------------------------------------------------------ timer (runs every frame)

	local current: any = nil -- latest duel view
	local outgoingExpires: number? = nil
	local outgoingName = ""

	RunService.Heartbeat:Connect(function()
		if current and current.phase == "drafting" and ctx.isVisible("DuelDraft") then
			local left = secondsLeft(current.deadline)
			local fraction = math.clamp(left / Config.PICK_SECONDS, 0, 1)
			timerFill.Size = UDim2.fromScale(fraction, 1)
			timerFill.BackgroundColor3 = Theme.color.red:Lerp(Theme.color.green, fraction)
			timerLabel.Text = ("%ds"):format(math.ceil(left))
			timerLabel.TextColor3 = if left <= 5 then Theme.color.red else Theme.color.text
		end
		if outgoingExpires and ctx.isVisible("DuelLobby") then
			outgoingLabel.Text = ("Waiting for %s...  %ds"):format(outgoingName, math.ceil(secondsLeft(outgoingExpires)))
		end
	end)

	------------------------------------------------------------ render

	local shownResultId = nil
	local compactMode = false

	function self.setCompact(compact: boolean)
		compactMode = compact
		board:setCompact(compact)
		scoreboard:setCompact(compact)
		oppPanel.Visible = not compact
		feed.Visible = not compact
		boardHolder.Size = if compact then UDim2.fromScale(1, 0.88) else UDim2.fromScale(1, 0.63)
	end

	function self.renderLobby(state: any): string
		local lobbyState = state.lobby
		local profile = state.profile
		recordLabel.Text = ("YOUR DUEL RECORD:  %d W  -  %d L"):format(profile.DuelWins, profile.DuelLosses)

		quickButton.Text = if lobbyState.queued then "SEARCHING...  (CANCEL)" else "QUICK MATCH"

		local out = lobbyState.outgoing
		outgoingCard.Visible = out ~= nil
		if out then
			outgoingExpires = out.expires
			outgoingName = out.name
		else
			outgoingExpires = nil
		end

		Kit.clear(list, { "UIListLayout" })
		for i, entry in lobbyState.players do
			playerRow(entry, i, out == nil)
		end
		emptyLabel.Visible = #lobbyState.players == 0
		playersTitle.Text = ("PLAYERS IN THIS SERVER (%d)"):format(#lobbyState.players)
		Kit.setDisabled(botButton, false)
		return "DuelLobby"
	end

	function self.render(state: any): string
		local duel = state.duel
		current = duel

		if duel.phase == "drafting" then
			local slot = Rating.SLOTS[duel.round]
			local oppTeam = Rating.team(duel.opp.lineup)
			local oppOvrText = if oppTeam.filled > 0 then tostring(oppTeam.ovr) else "--"
			if compactMode then
				roundLabel.Text = ("ROUND %d / %d  •  OPP %s"):format(duel.round, duel.rounds, oppOvrText)
			else
				roundLabel.Text = ("ROUND %d / %d  •  %s"):format(duel.round, duel.rounds, slot.short)
			end
			if duel.myTurn then
				turnPill.Text = "YOUR PICK!"
				turnPill.TextColor3 = Color3.new(1, 1, 1)
				turnPill.BackgroundColor3 = Theme.color.green
			else
				turnPill.Text = string.upper(duel.opp.name) .. " IS PICKING..."
				turnPill.TextColor3 = Theme.color.sub
				turnPill.BackgroundColor3 = Theme.color.panelHi2
			end

			board:render(duel.roll, slot, duel.rollId, {
				canPick = duel.myTurn,
				takenInfo = function(i)
					local by = duel.roll.takenBy[i]
					if by == 1 then
						return "YOUR PICK", true
					elseif by == 2 then
						return "TAKEN", false
					end
					return nil, nil
				end,
				onPick = function(i)
					ctx.act("DuelPick", i)
				end,
			})

			local parts = {}
			for _, e in duel.log do
				local who = if e.mine then "<font color=\"#46d278\">You</font>" else ("<font color=\"#f4485c\">" .. duel.opp.name .. "</font>")
				table.insert(parts, ("%s took %s (%d)%s"):format(who, e.name, e.ovr, if e.auto then " [auto]" else ""))
			end
			feed.Text = if #parts > 0 then table.concat(parts, "   •   ") else "Draft started! Highest rating wins the game."

			oppHeader.Text = ("%s  •  TEAM OVR %s"):format(string.upper(duel.opp.name), oppOvrText)
			for i, s in Rating.SLOTS do
				local p = duel.opp.lineup[i]
				local chip = chipLabels[i]
				if p then
					local eff = math.floor(Rating.effective(p, s) + 0.5)
					chip.ovr.Text = tostring(eff)
					chip.ovr.TextColor3 = Theme.tier[Rating.tier(eff)].text
					local last = p.name:match("(%S+)$") or p.name
					chip.name.Text = last
				else
					chip.ovr.Text = "-"
					chip.ovr.TextColor3 = Theme.color.dim
					chip.name.Text = ""
				end
			end
			shownResultId = nil
			return "DuelDraft"
		end

		-- Result
		local r = duel.result
		if r and shownResultId ~= duel.id then
			shownResultId = duel.id
			board:reset()
			if r.forfeit then
				scoreboard.root.Visible = false
				forfeitPanel.Visible = true
				forfeitTitle.Text = if r.forfeitByMe then "YOU FORFEITED" else (string.upper(duel.opp.name) .. " FORFEITED")
				forfeitTitle.TextColor3 = if r.win then Theme.color.green else Theme.color.red
				forfeitSub.Text = if r.win then ("YOU WIN!  +%d COINS"):format(r.coins) else "No coins this time."
			else
				scoreboard.root.Visible = true
				forfeitPanel.Visible = false
				scoreboard:show({
					leftName = string.upper(duel.me.name),
					leftOvr = r.myOvr,
					rightName = string.upper(duel.opp.name),
					rightOvr = r.oppOvr,
					left = r.mine,
					right = r.theirs,
					win = r.win,
					resultText = (if r.win then "YOU WIN" else "YOU LOSE") .. ("  +%d COINS"):format(r.coins),
					box = r.box,
				}, true)
			end
		end
		return "DuelResult"
	end

	return self
end

return DuelPages
