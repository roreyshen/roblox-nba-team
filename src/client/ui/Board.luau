-- Draft board: the rolled-team banner (with a slot-machine spin) and the grid of player cards.
-- Used by both the solo draft and live duels. Cards are rebuilt only when a new team is rolled;
-- otherwise their taken/clickable state is updated in place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NBAData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NBAData"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Card = require(script.Parent:WaitForChild("Card"))

export type BoardOptions = {
	canPick: boolean,
	-- For card i: stamp text if taken (or nil), and whether it's on my team.
	takenInfo: (number) -> (string?, boolean?),
	onPick: (number) -> (),
}

local Board = {}
Board.__index = Board

function Board.new(parent: Instance)
	local banner = Kit.make("Frame", {
		Name = "Banner",
		Size = UDim2.fromScale(1, 0.17),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = parent,
	})
	Kit.corner(banner, 12)
	local bannerGradient = Kit.gradient(banner, Theme.color.panelHi, Theme.color.panel, 0)
	local bannerStroke = Kit.stroke(banner, Theme.color.gold, 2, 1)
	Kit.text({
		Size = UDim2.fromScale(0.5, 0.26),
		Position = UDim2.fromScale(0.03, 0.08),
		Text = "YOU ROLLED",
		FontFace = Theme.font.heavy,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 13,
		Parent = banner,
	})
	local bannerText = Kit.text({
		Size = UDim2.fromScale(0.74, 0.58),
		Position = UDim2.fromScale(0.03, 0.34),
		Text = "",
		FontFace = Theme.font.display,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 34,
		Parent = banner,
	})
	local dynasty = Kit.text({
		Size = UDim2.fromScale(0.2, 0.36),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.97, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.gold,
		Text = "DYNASTY ROLL",
		TextColor3 = Theme.color.black,
		FontFace = Theme.font.heavy,
		MaxSize = 14,
		Visible = false,
		Parent = banner,
	})
	Kit.corner(dynasty, 8)

	-- Desktop: 4x2 grid. Compact (phones): one row that scrolls sideways.
	local grid = Kit.make("ScrollingFrame", {
		Name = "Cards",
		Size = UDim2.fromScale(1, 0.8),
		Position = UDim2.fromScale(0, 0.2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Theme.color.dim,
		Parent = parent,
	})

	local self = setmetatable({
		banner = banner,
		bannerGradient = bannerGradient,
		bannerStroke = bannerStroke,
		bannerText = bannerText,
		dynasty = dynasty,
		grid = grid,
		cards = {} :: { any },
		rollId = nil :: number?,
		built = false,
		token = 0,
		latest = nil :: any,
		compact = nil :: boolean?,
	}, Board)
	self:setCompact(false)
	return self
end

local function sizeCard(card: any, compact: boolean)
	local aspect = card.root:FindFirstChildOfClass("UIAspectRatioConstraint")
	if compact then
		card.root.Size = UDim2.new(0, 400, 1, -6)
		if not aspect then
			Kit.make("UIAspectRatioConstraint", {
				AspectRatio = 0.72,
				DominantAxis = Enum.DominantAxis.Height,
				Parent = card.root,
			})
		end
	elseif aspect then
		aspect:Destroy()
	end
end

function Board.setCompact(self: any, compact: boolean)
	if self.compact == compact then
		return
	end
	self.compact = compact
	for _, child in self.grid:GetChildren() do
		if child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	if compact then
		Kit.list(self.grid, true, UDim.new(0, 8), { VerticalAlignment = Enum.VerticalAlignment.Center })
		self.grid.AutomaticCanvasSize = Enum.AutomaticSize.X
		self.grid.ScrollBarThickness = 4
		self.banner.Size = UDim2.fromScale(1, 0.2)
		self.grid.Size = UDim2.fromScale(1, 0.77)
		self.grid.Position = UDim2.fromScale(0, 0.23)
	else
		Kit.make("UIGridLayout", {
			CellSize = UDim2.fromScale(0.235, 0.475),
			CellPadding = UDim2.fromScale(0.018, 0.04),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Parent = self.grid,
		})
		self.grid.AutomaticCanvasSize = Enum.AutomaticSize.None
		self.grid.CanvasSize = UDim2.new()
		self.grid.ScrollBarThickness = 0
		self.banner.Size = UDim2.fromScale(1, 0.17)
		self.grid.Size = UDim2.fromScale(1, 0.8)
		self.grid.Position = UDim2.fromScale(0, 0.2)
	end
	for _, card in self.cards do
		sizeCard(card, compact)
	end
end

function Board.setBanner(self: any, roll: any, spinning: boolean)
	local franchise = NBAData.byFranchise[roll.franchise]
	local color = if franchise then Theme.rgb(franchise.color) else Theme.color.panelHi
	self.bannerGradient.Color = ColorSequence.new(color, Theme.darken(color, 0.45))
	self.bannerText.Text = string.upper(roll.label)
	self.bannerText.TextColor3 = Theme.textOn(color)
	self.dynasty.Visible = not spinning and roll.weight ~= nil and roll.weight <= 3
end

function Board.applyState(self: any)
	local opts: BoardOptions = self.latest.opts
	for i, card in self.cards do
		local stamp, mine = opts.takenInfo(i)
		card:setState(stamp, opts.canPick, mine)
	end
end

function Board.buildCards(self: any)
	Kit.clear(self.grid, { "UIGridLayout", "UIListLayout" })
	self.cards = {}
	self.grid.CanvasPosition = Vector2.new(0, 0)
	local latest = self.latest
	local legend = false
	for i, p in latest.roll.players do
		local card = Card.new(self.grid, p, latest.slot, i, function(index)
			local opts: BoardOptions = self.latest.opts
			if opts.canPick then
				opts.onPick(index)
			end
		end)
		self.cards[i] = card
		sizeCard(card, self.compact)
		Kit.pop(card.root, i * 0.035)
		if p.ovr >= 95 then
			legend = true
		end
	end
	self.built = true
	self:applyState()
	if legend then
		-- Gold flash when a legend is on the board.
		self.bannerStroke.Transparency = 0
		Kit.tween(self.bannerStroke, 1.2, { Transparency = 1 })
		Kit.sound("thud", 0.5)
	end
end

-- roll: { label, franchise, weight, players }. slot: Rating slot being filled.
function Board.render(self: any, roll: any, slot: any, rollId: number, opts: BoardOptions)
	self.latest = { roll = roll, slot = slot, opts = opts }
	if rollId == self.rollId then
		if self.built then
			self:applyState()
		end
		return -- (if still spinning, the spin uses self.latest when it lands)
	end

	self.rollId = rollId
	self.built = false
	self.token += 1
	local my = self.token
	Kit.clear(self.grid, { "UIGridLayout", "UIListLayout" })
	self.cards = {}

	task.spawn(function()
		for i = 1, 10 do
			if self.token ~= my then
				return
			end
			self:setBanner(NBAData.eras[math.random(1, #NBAData.eras)], true)
			Kit.sound("tick", 0.15)
			task.wait(0.035 + i * 0.007)
		end
		if self.token ~= my then
			return
		end
		self:setBanner(self.latest.roll, false)
		Kit.pop(self.banner, 0, 0.92)
		self:buildCards()
	end)
end

-- Forget the current roll so the next render spins again.
function Board.reset(self: any)
	self.rollId = nil
	self.built = false
	self.token += 1
end

return Board
