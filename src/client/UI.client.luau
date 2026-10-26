-- All game UI, built in code. The server sends the full state after every action; render() redraws it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NBAData = require(Shared:WaitForChild("NBAData"))
local Rating = require(Shared:WaitForChild("Rating"))
local Config = require(Shared:WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ActionRemote: RemoteFunction = Remotes:WaitForChild("Action")
local LeaderboardRemote: RemoteFunction = Remotes:WaitForChild("GetLeaderboard")

local player = Players.LocalPlayer

---------------------------------------------------------------- style

local COLORS = {
	bg = Color3.fromRGB(12, 15, 26),
	panel = Color3.fromRGB(22, 27, 44),
	panel2 = Color3.fromRGB(34, 41, 66),
	accent = Color3.fromRGB(255, 132, 0),
	text = Color3.fromRGB(240, 242, 248),
	muted = Color3.fromRGB(150, 158, 182),
	green = Color3.fromRGB(70, 210, 120),
	yellow = Color3.fromRGB(255, 205, 70),
	red = Color3.fromRGB(235, 80, 80),
	blue = Color3.fromRGB(60, 130, 240),
	purple = Color3.fromRGB(140, 80, 230),
}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Black or white text, whichever reads better on `color`.
local function textOn(color: Color3): Color3
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if lum > 0.6 then Color3.fromRGB(15, 15, 20) else Color3.new(1, 1, 1)
end

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(inst: Instance, px: number?)
	make("UICorner", { CornerRadius = UDim.new(0, px or 8), Parent = inst })
end

local function outline(inst: Instance, color: Color3, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function label(props: { [string]: any }): TextLabel
	local maxSize = props.MaxSize or 28
	props.MaxSize = nil
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = COLORS.text,
		TextScaled = true,
		TextWrapped = true,
		Text = "",
	}
	for k, v in defaults do
		if props[k] == nil then
			props[k] = v
		end
	end
	local l = make("TextLabel", props)
	make("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = l })
	return l
end

local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	local maxSize = props.MaxSize or 22
	props.MaxSize = nil
	local defaults = {
		BackgroundColor3 = COLORS.accent,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		AutoButtonColor = true,
		Text = "",
	}
	for k, v in defaults do
		if props[k] == nil then
			props[k] = v
		end
	end
	local b = make("TextButton", props)
	corner(b)
	make("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = b })
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = b,
	})
	b.Activated:Connect(onClick)
	return b
end

local function clearChildren(parent: Instance, keepClass: string?)
	for _, c in parent:GetChildren() do
		if not keepClass or not c:IsA(keepClass) then
			c:Destroy()
		end
	end
end

---------------------------------------------------------------- forward declarations

local render: (state: any) -> ()
local act: (action: string, arg: any) -> any
local currentState: any = nil

---------------------------------------------------------------- root layout

local gui = make("ScreenGui", {
	Name = "NBATeamGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local root = make("Frame", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Parent = gui,
})

-- Top bar
local topBar = make("Frame", {
	Name = "TopBar",
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
	Parent = root,
})
label({
	Size = UDim2.new(0.3, 0, 1, -12),
	Position = UDim2.new(0, 12, 0, 6),
	Text = "BUILD THE STRONGEST NBA TEAM",
	Font = Enum.Font.GothamBlack,
	TextColor3 = COLORS.accent,
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxSize = 24,
	Parent = topBar,
})
local statsBar = make("Frame", {
	Size = UDim2.new(0.68, -12, 1, 0),
	Position = UDim2.new(0.32, 0, 0, 0),
	BackgroundTransparency = 1,
	Parent = topBar,
})
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0.012, 0),
	Parent = statsBar,
})

local function chip(title: string, order: number): TextLabel
	local f = make("Frame", {
		Size = UDim2.fromScale(0.125, 0.78),
		BackgroundColor3 = COLORS.panel2,
		LayoutOrder = order,
		Parent = statsBar,
	})
	corner(f)
	label({
		Size = UDim2.fromScale(1, 0.38),
		Position = UDim2.fromScale(0, 0.06),
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.muted,
		MaxSize = 12,
		Parent = f,
	})
	return label({
		Size = UDim2.fromScale(1, 0.5),
		Position = UDim2.fromScale(0, 0.44),
		Text = "-",
		Font = Enum.Font.GothamBlack,
		MaxSize = 20,
		Parent = f,
	})
end

local coinsValue = chip("COINS", 1)
local rerollsValue = chip("REROLLS", 2)
local refreshesValue = chip("REFRESHES", 3)
local bestValue = chip("BEST OVR", 4)

-- Body: lineup on the left, page content on the right
local body = make("Frame", {
	Name = "Body",
	Size = UDim2.new(1, -24, 1, -80),
	Position = UDim2.new(0, 12, 0, 68),
	BackgroundTransparency = 1,
	Parent = root,
})

local lineupPanel = make("Frame", {
	Name = "Lineup",
	Size = UDim2.new(0.3, -6, 1, 0),
	BackgroundColor3 = COLORS.panel,
	Parent = body,
})
corner(lineupPanel, 12)
make("UIPadding", {
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	Parent = lineupPanel,
})

local content = make("Frame", {
	Name = "Content",
	Size = UDim2.new(0.7, -6, 1, 0),
	Position = UDim2.new(0.3, 6, 0, 0),
	BackgroundColor3 = COLORS.panel,
	Parent = body,
})
corner(content, 12)
make("UIPadding", {
	PaddingLeft = UDim.new(0, 14),
	PaddingRight = UDim.new(0, 14),
	PaddingTop = UDim.new(0, 12),
	PaddingBottom = UDim.new(0, 12),
	Parent = content,
})

---------------------------------------------------------------- toast

local toast = label({
	Size = UDim2.new(0.42, 0, 0, 44),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	BackgroundTransparency = 0,
	BackgroundColor3 = COLORS.panel2,
	Visible = false,
	ZIndex = 50,
	MaxSize = 18,
	Parent = gui,
})
corner(toast, 10)
local toastStroke = outline(toast, COLORS.green, 2)
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = toast })
local toastToken = 0

local function showToast(msg: string, isError: boolean?)
	toastToken += 1
	local my = toastToken
	toast.Text = msg
	toastStroke.Color = if isError then COLORS.red else COLORS.green
	toast.Visible = true
	task.delay(2.6, function()
		if toastToken == my then
			toast.Visible = false
		end
	end)
end

---------------------------------------------------------------- lineup panel

local teamOvrLabel = label({
	Size = UDim2.fromScale(0.34, 0.11),
	Position = UDim2.fromScale(0.66, 0),
	Text = "0",
	Font = Enum.Font.GothamBlack,
	TextColor3 = COLORS.accent,
	TextXAlignment = Enum.TextXAlignment.Right,
	MaxSize = 48,
	Parent = lineupPanel,
})
label({
	Size = UDim2.fromScale(0.64, 0.06),
	Text = "YOUR TEAM",
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxSize = 22,
	Parent = lineupPanel,
})
local chemLabel = label({
	Size = UDim2.fromScale(0.64, 0.045),
	Position = UDim2.fromScale(0, 0.065),
	Text = "OVR 0  •  CHEMISTRY 0",
	Font = Enum.Font.GothamMedium,
	TextColor3 = COLORS.muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxSize = 14,
	Parent = lineupPanel,
})

local slotList = make("Frame", {
	Size = UDim2.fromScale(1, 0.86),
	Position = UDim2.fromScale(0, 0.14),
	BackgroundTransparency = 1,
	Parent = lineupPanel,
})
make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0.012, 0),
	Parent = slotList,
})

type SlotRow = { stroke: UIStroke, name: TextLabel, sub: TextLabel, ovr: TextLabel }
local slotRows: { SlotRow } = {}

for i, slot in Rating.SLOTS do
	local row = make("Frame", {
		Size = UDim2.fromScale(1, 0.113),
		BackgroundColor3 = COLORS.panel2,
		LayoutOrder = i,
		Parent = slotList,
	})
	corner(row)
	local stroke = outline(row, COLORS.accent, 2)
	stroke.Enabled = false

	local tag = label({
		Size = UDim2.new(0.22, 0, 1, -10),
		Position = UDim2.new(0, 5, 0, 5),
		BackgroundTransparency = 0,
		BackgroundColor3 = if slot.bench then COLORS.muted else COLORS.accent,
		TextColor3 = if slot.bench then COLORS.bg else Color3.new(1, 1, 1),
		Text = slot.short,
		Font = Enum.Font.GothamBlack,
		MaxSize = 16,
		Parent = row,
	})
	corner(tag, 6)

	local name = label({
		Size = UDim2.new(0.56, 0, 0.5, 0),
		Position = UDim2.new(0.25, 0, 0.08, 0),
		Text = "—",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 16,
		Parent = row,
	})
	local sub = label({
		Size = UDim2.new(0.56, 0, 0.32, 0),
		Position = UDim2.new(0.25, 0, 0.58, 0),
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 12,
		Parent = row,
	})
	local ovr = label({
		Size = UDim2.new(0.17, 0, 0.8, 0),
		Position = UDim2.new(0.82, 0, 0.1, 0),
		Text = "",
		Font = Enum.Font.GothamBlack,
		MaxSize = 24,
		Parent = row,
	})
	slotRows[i] = { stroke = stroke, name = name, sub = sub, ovr = ovr }
end

local function renderLineup(run: any)
	local lineup = if run then run.lineup else {}
	for i, slot in Rating.SLOTS do
		local row = slotRows[i]
		local p = lineup[i]
		if p then
			local eff = Rating.effective(p, slot)
			local natural = Rating.distance(p.positions, slot) == 0
			row.name.Text = p.name
			row.sub.Text = p.shortLabel .. "  •  " .. p.posText
			row.ovr.Text = tostring(math.floor(eff + 0.5))
			row.ovr.TextColor3 = if natural then COLORS.green else COLORS.yellow
		else
			row.name.Text = "—"
			row.sub.Text = "Empty"
			row.ovr.Text = ""
		end
		row.stroke.Enabled = run ~= nil and run.phase == "drafting" and run.slot == i
	end
	local team = Rating.team(lineup)
	teamOvrLabel.Text = tostring(team.ovr)
	chemLabel.Text = ("OVR %d  •  CHEMISTRY %d"):format(team.ovr, team.chemistry)
end

---------------------------------------------------------------- pages

local pages: { [string]: Frame } = {}
local function newPage(name: string): Frame
	local f = make("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = content,
	})
	pages[name] = f
	return f
end
local function showPage(name: string)
	for n, f in pages do
		f.Visible = n == name
	end
end

-- HOME ------------------------------------------------------------------

local home = newPage("Home")
label({
	Size = UDim2.fromScale(1, 0.14),
	Position = UDim2.fromScale(0, 0.06),
	Text = "BUILD THE STRONGEST NBA TEAM",
	Font = Enum.Font.GothamBlack,
	TextColor3 = COLORS.accent,
	MaxSize = 44,
	Parent = home,
})
label({
	Size = UDim2.fromScale(0.86, 0.34),
	Position = UDim2.fromScale(0.07, 0.24),
	Text = "Every pick, you roll a random NBA team from a random season. Choose ONE player from that roster for the open slot.\n\n"
		.. "Fill 5 starters + 3 bench. Players at their real position keep their full rating and boost chemistry. "
		.. "Teammates from the same season add bonus chemistry.\n\n"
		.. "REROLL = new random team.  REFRESH = same franchise, different era.",
	Font = Enum.Font.GothamMedium,
	TextColor3 = COLORS.text,
	MaxSize = 20,
	Parent = home,
})
local homeStats = label({
	Size = UDim2.fromScale(1, 0.06),
	Position = UDim2.fromScale(0, 0.62),
	Text = "",
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.muted,
	MaxSize = 18,
	Parent = home,
})
local startButton = button({
	Size = UDim2.fromScale(0.4, 0.13),
	Position = UDim2.fromScale(0.3, 0.74),
	Text = "LOADING...",
	MaxSize = 30,
	Parent = home,
}, function()
	if currentState and currentState.profile then
		act("StartRun")
	end
end)

-- DRAFT -----------------------------------------------------------------

local draft = newPage("Draft")
local pickLabel = label({
	Size = UDim2.fromScale(0.78, 0.08),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxSize = 26,
	Parent = draft,
})
button({
	Size = UDim2.fromScale(0.18, 0.07),
	Position = UDim2.fromScale(0.82, 0.005),
	Text = "RESTART",
	BackgroundColor3 = COLORS.panel2,
	MaxSize = 16,
	Parent = draft,
}, function()
	act("StartRun")
end)

local banner = label({
	Size = UDim2.fromScale(1, 0.12),
	Position = UDim2.fromScale(0, 0.1),
	BackgroundTransparency = 0,
	BackgroundColor3 = COLORS.panel2,
	Text = "",
	Font = Enum.Font.GothamBlack,
	MaxSize = 30,
	Parent = draft,
})
corner(banner, 10)

local cardsFrame = make("Frame", {
	Size = UDim2.fromScale(1, 0.62),
	Position = UDim2.fromScale(0, 0.25),
	BackgroundTransparency = 1,
	Parent = draft,
})
make("UIGridLayout", {
	CellSize = UDim2.fromScale(0.235, 0.47),
	CellPadding = UDim2.fromScale(0.02, 0.04),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Parent = cardsFrame,
})

local rerollButton = button({
	Size = UDim2.fromScale(0.49, 0.1),
	Position = UDim2.fromScale(0, 0.9),
	BackgroundColor3 = COLORS.blue,
	Parent = draft,
}, function()
	act("Reroll")
end)
local refreshButton = button({
	Size = UDim2.fromScale(0.49, 0.1),
	Position = UDim2.fromScale(0.51, 0.9),
	BackgroundColor3 = COLORS.purple,
	Parent = draft,
}, function()
	act("Refresh")
end)

local function makeCard(p: any, slot: Rating.Slot, taken: boolean, index: number): TextButton
	local tier = Rating.tier(p.ovr)
	local tierColor = rgb(Rating.TIER_COLORS[tier])
	local franchise = NBAData.byFranchise[p.franchise]
	local teamColor = if franchise then rgb(franchise.color) else COLORS.panel2

	local card = make("TextButton", {
		Text = "",
		AutoButtonColor = not taken,
		BackgroundColor3 = COLORS.panel2,
		LayoutOrder = index,
		Parent = cardsFrame,
	})
	corner(card, 10)
	outline(card, if taken then COLORS.panel else tierColor, 2)

	local strip = label({
		Size = UDim2.fromScale(1, 0.18),
		BackgroundTransparency = 0,
		BackgroundColor3 = teamColor,
		TextColor3 = textOn(teamColor),
		Text = tier,
		Font = Enum.Font.GothamBlack,
		MaxSize = 14,
		Parent = card,
	})
	corner(strip, 10)

	label({
		Size = UDim2.fromScale(1, 0.28),
		Position = UDim2.fromScale(0, 0.2),
		Text = tostring(p.ovr),
		Font = Enum.Font.GothamBlack,
		TextColor3 = tierColor,
		MaxSize = 44,
		Parent = card,
	})
	label({
		Size = UDim2.new(1, -8, 0.22, 0),
		Position = UDim2.new(0, 4, 0.49, 0),
		Text = p.name,
		MaxSize = 18,
		Parent = card,
	})

	local eff = math.floor(Rating.effective(p, slot) + 0.5)
	local natural = Rating.distance(p.positions, slot) == 0
	local fitText
	if taken then
		fitText = "ALREADY DRAFTED"
	elseif natural then
		fitText = p.posText .. "  ✓ FITS"
	else
		fitText = ("%s  → %d at %s"):format(p.posText, eff, slot.short)
	end
	label({
		Size = UDim2.new(1, -8, 0.18, 0),
		Position = UDim2.new(0, 4, 0.76, 0),
		Text = fitText,
		Font = Enum.Font.GothamBold,
		TextColor3 = if taken then COLORS.muted elseif natural then COLORS.green else COLORS.yellow,
		MaxSize = 14,
		Parent = card,
	})

	if taken then
		card.BackgroundTransparency = 0.6
		for _, d in card:GetDescendants() do
			if d:IsA("TextLabel") then
				d.TextTransparency = 0.5
			end
		end
	else
		card.Activated:Connect(function()
			act("Pick", index)
		end)
	end
	return card
end

local shownRollId = -1
local rollToken = 0

local function setBanner(roll: any)
	local franchise = NBAData.byFranchise[roll.franchise]
	local color = if franchise then rgb(franchise.color) else COLORS.panel2
	banner.BackgroundColor3 = color
	banner.TextColor3 = textOn(color)
	banner.Text = string.upper(roll.label)
end

local function renderCards(run: any)
	clearChildren(cardsFrame, "UIGridLayout")
	local slot = Rating.SLOTS[run.slot]
	for i, p in run.roll.players do
		makeCard(p, slot, run.roll.taken[i], i)
	end
	cardsFrame.Visible = true
end

local function renderDraft(run: any, profile: any)
	local slot = Rating.SLOTS[run.slot]
	pickLabel.Text = ("PICK %d / %d  •  NEED: %s"):format(run.slot, #Rating.SLOTS, slot.label)
	rerollButton.Text = ("REROLL (%d)  —  new team"):format(profile.Rerolls)
	refreshButton.Text = ("REFRESH (%d)  —  new era"):format(profile.Refreshes)

	rollToken += 1
	local my = rollToken
	if run.rollId == shownRollId then
		setBanner(run.roll)
		renderCards(run)
		return
	end
	shownRollId = run.rollId

	-- Slot-machine spin through random teams before landing on the real roll.
	cardsFrame.Visible = false
	task.spawn(function()
		for i = 1, 12 do
			if rollToken ~= my then
				return
			end
			setBanner(NBAData.eras[math.random(1, #NBAData.eras)])
			task.wait(0.04 + i * 0.008)
		end
		if rollToken ~= my then
			return
		end
		setBanner(run.roll)
		renderCards(run)
	end)
end

-- RESULTS ---------------------------------------------------------------

local results = newPage("Results")
label({
	Size = UDim2.fromScale(1, 0.08),
	Position = UDim2.fromScale(0, 0.04),
	Text = "FINAL TEAM RATING",
	Font = Enum.Font.GothamBlack,
	TextColor3 = COLORS.muted,
	MaxSize = 26,
	Parent = results,
})
local resOvr = label({
	Size = UDim2.fromScale(1, 0.26),
	Position = UDim2.fromScale(0, 0.12),
	Text = "0",
	Font = Enum.Font.GothamBlack,
	MaxSize = 120,
	Parent = results,
})
local resTier = label({
	Size = UDim2.fromScale(1, 0.07),
	Position = UDim2.fromScale(0, 0.38),
	Text = "",
	Font = Enum.Font.GothamBlack,
	MaxSize = 28,
	Parent = results,
})
local resChem = label({
	Size = UDim2.fromScale(1, 0.05),
	Position = UDim2.fromScale(0, 0.47),
	Text = "",
	Font = Enum.Font.GothamMedium,
	TextColor3 = COLORS.muted,
	MaxSize = 18,
	Parent = results,
})
local resCoins = label({
	Size = UDim2.fromScale(1, 0.07),
	Position = UDim2.fromScale(0, 0.54),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextColor3 = COLORS.yellow,
	MaxSize = 28,
	Parent = results,
})
local resBest = label({
	Size = UDim2.fromScale(1, 0.06),
	Position = UDim2.fromScale(0, 0.62),
	Text = "NEW PERSONAL BEST!",
	Font = Enum.Font.GothamBlack,
	TextColor3 = COLORS.green,
	MaxSize = 24,
	Parent = results,
})
button({
	Size = UDim2.fromScale(0.42, 0.12),
	Position = UDim2.fromScale(0.06, 0.78),
	Text = "PLAY VS CPU",
	BackgroundColor3 = COLORS.green,
	MaxSize = 26,
	Parent = results,
}, function()
	act("SimGame")
end)
button({
	Size = UDim2.fromScale(0.42, 0.12),
	Position = UDim2.fromScale(0.52, 0.78),
	Text = "DRAFT AGAIN",
	MaxSize = 26,
	Parent = results,
}, function()
	act("StartRun")
end)

local function renderResults(run: any)
	local r = run.result
	local tierColor = rgb(Rating.TIER_COLORS[r.tier])
	resOvr.Text = tostring(r.ovr)
	resOvr.TextColor3 = tierColor
	resTier.Text = r.tier .. " TEAM"
	resTier.TextColor3 = tierColor
	resChem.Text = ("Chemistry %d / 100"):format(r.chemistry)
	resCoins.Text = ("+%d COINS"):format(r.coins)
	resBest.Visible = r.newBest
end

-- GAME ------------------------------------------------------------------

local gamePage = newPage("Game")
local gameTitle = label({
	Size = UDim2.fromScale(1, 0.07),
	Text = "",
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.muted,
	MaxSize = 20,
	Parent = gamePage,
})
local scoreLabel = label({
	Size = UDim2.fromScale(1, 0.16),
	Position = UDim2.fromScale(0, 0.07),
	Text = "",
	Font = Enum.Font.GothamBlack,
	MaxSize = 64,
	Parent = gamePage,
})
local quarterLabel = label({
	Size = UDim2.fromScale(1, 0.13),
	Position = UDim2.fromScale(0, 0.24),
	Text = "",
	Font = Enum.Font.RobotoMono,
	MaxSize = 20,
	Parent = gamePage,
})
local resultLabel = label({
	Size = UDim2.fromScale(1, 0.08),
	Position = UDim2.fromScale(0, 0.38),
	Text = "",
	Font = Enum.Font.GothamBlack,
	MaxSize = 30,
	Parent = gamePage,
})
local boxLabel = label({
	Size = UDim2.fromScale(0.9, 0.33),
	Position = UDim2.fromScale(0.05, 0.47),
	Text = "",
	Font = Enum.Font.RobotoMono,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	MaxSize = 17,
	Parent = gamePage,
})
local gameAgain = button({
	Size = UDim2.fromScale(0.4, 0.11),
	Position = UDim2.fromScale(0.3, 0.86),
	Text = "DRAFT AGAIN",
	MaxSize = 26,
	Parent = gamePage,
}, function()
	act("StartRun")
end)

local function periodName(i: number): string
	if i <= 4 then
		return "Q" .. i
	elseif i == 5 then
		return "OT"
	end
	return "OT" .. (i - 4)
end

local function quarterTable(g: any, upTo: number): (string, number, number)
	local head = ("%-5s"):format("")
	local you = ("%-5s"):format("YOU")
	local opp = ("%-5s"):format("OPP")
	local youSum, oppSum = 0, 0
	for i = 1, upTo do
		head ..= ("%5s"):format(periodName(i))
		you ..= ("%5d"):format(g.home[i])
		opp ..= ("%5d"):format(g.away[i])
		youSum += g.home[i]
		oppSum += g.away[i]
	end
	head ..= ("%6s"):format("T")
	you ..= ("%6d"):format(youSum)
	opp ..= ("%6d"):format(oppSum)
	return head .. "\n" .. you .. "\n" .. opp, youSum, oppSum
end

local function boxText(g: any): string
	local lines = { ("%-22s %4s %4s %4s"):format("PLAYER", "PTS", "REB", "AST") }
	for _, b in g.box do
		table.insert(lines, ("%-22s %4d %4d %4d"):format(b.name:sub(1, 22), b.pts, b.reb, b.ast))
	end
	return table.concat(lines, "\n")
end

local shownGameId = -1
local gameToken = 0

local function showGameFinal(g: any)
	local text = quarterTable(g, #g.home)
	quarterLabel.Text = text
	scoreLabel.Text = ("%d  -  %d"):format(g.homeTotal, g.awayTotal)
	scoreLabel.TextColor3 = if g.win then COLORS.green else COLORS.red
	resultLabel.Text = if g.win then ("WIN!  +%d COINS"):format(g.coins) else ("LOSS  +%d COINS"):format(g.coins)
	resultLabel.TextColor3 = if g.win then COLORS.green else COLORS.red
	resultLabel.Visible = true
	boxLabel.Text = boxText(g)
	boxLabel.Visible = true
	gameAgain.Visible = true
end

local function renderGame(run: any)
	local g = run.game
	gameTitle.Text = ("YOUR TEAM (%d)  vs  %s (%d)"):format(g.myOvr, string.upper(g.oppLabel), g.oppOvr)
	gameToken += 1
	local my = gameToken
	if g.id == shownGameId then
		showGameFinal(g)
		return
	end
	shownGameId = g.id

	-- Reveal the score one period at a time.
	resultLabel.Visible = false
	boxLabel.Visible = false
	gameAgain.Visible = false
	scoreLabel.TextColor3 = COLORS.text
	task.spawn(function()
		for i = 1, #g.home do
			if gameToken ~= my then
				return
			end
			local text, youSum, oppSum = quarterTable(g, i)
			quarterLabel.Text = text
			scoreLabel.Text = ("%d  -  %d"):format(youSum, oppSum)
			task.wait(0.7)
		end
		if gameToken ~= my then
			return
		end
		showGameFinal(g)
	end)
end

---------------------------------------------------------------- modal (shop / codes / leaderboard)

local overlay = make("Frame", {
	Name = "Overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
	Visible = false,
	ZIndex = 10,
	Parent = gui,
})
-- Swallow clicks so nothing behind the modal is pressed.
make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Parent = overlay,
})
local modal = make("Frame", {
	Size = UDim2.fromScale(0.5, 0.66),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = COLORS.panel,
	ZIndex = 2,
	Parent = overlay,
})
corner(modal, 14)
outline(modal, COLORS.accent, 2)
make("UISizeConstraint", { MinSize = Vector2.new(300, 300), Parent = modal })
local modalTitle = label({
	Size = UDim2.new(1, -80, 0, 44),
	Position = UDim2.new(0, 16, 0, 10),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextColor3 = COLORS.accent,
	TextXAlignment = Enum.TextXAlignment.Left,
	MaxSize = 30,
	Parent = modal,
})
button({
	Size = UDim2.new(0, 44, 0, 44),
	Position = UDim2.new(1, -56, 0, 10),
	Text = "X",
	BackgroundColor3 = COLORS.red,
	Parent = modal,
}, function()
	overlay.Visible = false
end)
local modalBody = make("Frame", {
	Size = UDim2.new(1, -32, 1, -74),
	Position = UDim2.new(0, 16, 0, 62),
	BackgroundTransparency = 1,
	Parent = modal,
})
local modalToken = 0

local function openModal(title: string): Frame
	modalToken += 1
	clearChildren(modalBody)
	modalTitle.Text = title
	overlay.Visible = true
	return modalBody
end

local function openShop()
	local bodyFrame = openModal("SHOP")
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.03, 0), Parent = bodyFrame })
	for i, item in Config.SHOP do
		local row = make("Frame", {
			Size = UDim2.fromScale(1, 0.2),
			BackgroundColor3 = COLORS.panel2,
			LayoutOrder = i,
			Parent = bodyFrame,
		})
		corner(row)
		label({
			Size = UDim2.fromScale(0.58, 0.7),
			Position = UDim2.fromScale(0.04, 0.15),
			Text = item.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 22,
			Parent = row,
		})
		button({
			Size = UDim2.fromScale(0.32, 0.7),
			Position = UDim2.fromScale(0.65, 0.15),
			Text = ("%d COINS"):format(item.cost),
			BackgroundColor3 = COLORS.green,
			MaxSize = 18,
			Parent = row,
		}, function()
			act("Buy", item.id)
		end)
	end
end

local function openCodes()
	local bodyFrame = openModal("CODES")
	label({
		Size = UDim2.fromScale(1, 0.15),
		Text = "Enter a code for free rerolls, refreshes, or coins.",
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.muted,
		MaxSize = 18,
		Parent = bodyFrame,
	})
	local box = make("TextBox", {
		Size = UDim2.fromScale(1, 0.2),
		Position = UDim2.fromScale(0, 0.22),
		BackgroundColor3 = COLORS.panel2,
		TextColor3 = COLORS.text,
		PlaceholderText = "Type code here",
		PlaceholderColor3 = COLORS.muted,
		Text = "",
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Parent = bodyFrame,
	})
	corner(box)
	make("UITextSizeConstraint", { MaxTextSize = 26, Parent = box })
	button({
		Size = UDim2.fromScale(0.5, 0.18),
		Position = UDim2.fromScale(0.25, 0.5),
		Text = "REDEEM",
		BackgroundColor3 = COLORS.green,
		MaxSize = 24,
		Parent = bodyFrame,
	}, function()
		local res = act("Redeem", box.Text)
		if res and res.ok then
			box.Text = ""
		end
	end)
end

local function openLeaderboard()
	local bodyFrame = openModal("TOP TEAMS")
	local my = modalToken
	local text = label({
		Size = UDim2.fromScale(1, 1),
		Text = "Loading...",
		Font = Enum.Font.RobotoMono,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxSize = 22,
		Parent = bodyFrame,
	})
	task.spawn(function()
		local ok, list = pcall(function()
			return LeaderboardRemote:InvokeServer()
		end)
		if modalToken ~= my then
			return
		end
		if not ok or type(list) ~= "table" then
			text.Text = "Couldn't load the leaderboard."
			return
		end
		if #list == 0 then
			text.Text = "No teams yet. Finish a draft to get on the board!"
			return
		end
		local lines = {}
		for i, e in list do
			table.insert(lines, ("%2d. %-20s %3d"):format(i, tostring(e.name):sub(1, 20), e.ovr))
		end
		text.Text = table.concat(lines, "\n")
	end)
end

local function topButton(text: string, color: Color3, order: number, onClick: () -> ())
	button({
		Size = UDim2.fromScale(0.11, 0.7),
		Text = text,
		BackgroundColor3 = color,
		LayoutOrder = order,
		MaxSize = 16,
		Parent = statsBar,
	}, onClick)
end
topButton("SHOP", COLORS.green, 5, openShop)
topButton("CODES", COLORS.purple, 6, openCodes)
topButton("LEADERS", COLORS.blue, 7, openLeaderboard)

---------------------------------------------------------------- state + server calls

local busy = false

act = function(action: string, arg: any): any
	if busy then
		return nil
	end
	busy = true
	local ok, res = pcall(function()
		return ActionRemote:InvokeServer(action, arg)
	end)
	busy = false
	if not ok or type(res) ~= "table" then
		showToast("Couldn't reach the server. Try again.", true)
		return nil
	end
	if res.msg then
		showToast(res.msg, not res.ok)
	end
	if res.state then
		render(res.state)
	end
	return res
end

render = function(state: any)
	currentState = state
	local profile = state.profile
	if profile then
		coinsValue.Text = tostring(profile.Coins)
		rerollsValue.Text = tostring(profile.Rerolls)
		refreshesValue.Text = tostring(profile.Refreshes)
		bestValue.Text = tostring(profile.BestOVR)
		homeStats.Text = ("Best OVR: %d   •   Drafts: %d   •   Record vs CPU: %d-%d"):format(
			profile.BestOVR,
			profile.Drafts,
			profile.Wins,
			profile.Losses
		)
		startButton.Text = "START DRAFT"
	end

	local run = state.run
	renderLineup(run)
	if not run then
		showPage("Home")
	elseif run.phase == "drafting" then
		renderDraft(run, profile)
		showPage("Draft")
	elseif run.game then
		renderGame(run)
		showPage("Game")
	else
		renderResults(run)
		showPage("Results")
	end
end

renderLineup(nil)
showPage("Home")

-- Wait until the server has loaded our data, then draw the real state.
task.spawn(function()
	while true do
		local ok, res = pcall(function()
			return ActionRemote:InvokeServer("GetState")
		end)
		if ok and type(res) == "table" and res.state and res.state.profile then
			render(res.state)
			return
		end
		task.wait(1)
	end
end)
