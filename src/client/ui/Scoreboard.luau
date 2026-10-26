-- Game result: team blocks, big score, quarter-by-quarter grid, result banner, box score.
-- Used for solo games vs CPU and for duel results.

local Theme = require(script.Parent:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))

export type ScoreData = {
	leftName: string,
	leftOvr: number,
	rightName: string,
	rightOvr: number,
	left: { number },
	right: { number },
	win: boolean,
	resultText: string,
	box: { { name: string, pts: number, reb: number, ast: number } },
}

local Scoreboard = {}
Scoreboard.__index = Scoreboard

local function teamBlock(parent: Instance, xScale: number, align: Enum.TextXAlignment)
	local block = Kit.panel({
		Size = UDim2.fromScale(0.3, 0.26),
		Position = UDim2.fromScale(xScale, 0),
		BackgroundColor3 = Theme.color.panelHi,
		Parent = parent,
	}, 12)
	local name = Kit.text({
		Size = UDim2.fromScale(0.9, 0.5),
		Position = UDim2.fromScale(0.05, 0.1),
		Text = "",
		FontFace = Theme.font.display,
		TextXAlignment = align,
		MaxSize = 24,
		Parent = block,
	})
	local ovr = Kit.text({
		Size = UDim2.fromScale(0.9, 0.3),
		Position = UDim2.fromScale(0.05, 0.6),
		Text = "",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.sub,
		TextXAlignment = align,
		MaxSize = 15,
		Parent = block,
	})
	return name, ovr
end

local function periodName(i: number): string
	if i <= 4 then
		return "Q" .. i
	elseif i == 5 then
		return "OT"
	end
	return "OT" .. (i - 4)
end

function Scoreboard.new(parent: Instance)
	local root = Kit.make("Frame", {
		Name = "Scoreboard",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local leftName, leftOvr = teamBlock(root, 0, Enum.TextXAlignment.Left)
	local rightName, rightOvr = teamBlock(root, 0.7, Enum.TextXAlignment.Right)

	local status = Kit.text({
		Size = UDim2.fromScale(0.36, 0.06),
		Position = UDim2.fromScale(0.32, 0),
		Text = "",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.orange,
		MaxSize = 16,
		Parent = root,
	})
	local score = Kit.text({
		Size = UDim2.fromScale(0.38, 0.2),
		Position = UDim2.fromScale(0.31, 0.06),
		Text = "0 - 0",
		FontFace = Theme.font.display,
		MaxSize = 72,
		Parent = root,
	})

	local grid = Kit.panel({
		Size = UDim2.fromScale(1, 0.17),
		Position = UDim2.fromScale(0, 0.29),
		BackgroundColor3 = Theme.color.panelHi,
		Parent = root,
	}, 12)
	Kit.pad(grid, 10, 6)
	Kit.list(grid, false, UDim.new(0, 0))

	local banner = Kit.text({
		Size = UDim2.fromScale(0.6, 0.085),
		Position = UDim2.fromScale(0.2, 0.485),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.green,
		Text = "",
		FontFace = Theme.font.display,
		MaxSize = 30,
		Visible = false,
		Parent = root,
	})
	Kit.corner(banner, 12)
	Kit.gloss(banner, 12)

	local box = Kit.panel({
		Size = UDim2.fromScale(1, 0.4),
		Position = UDim2.fromScale(0, 0.6),
		BackgroundColor3 = Theme.color.panelHi,
		Visible = false,
		Parent = root,
	}, 12)
	Kit.pad(box, 12, 6)
	Kit.list(box, false, UDim.new(0, 0))

	-- Compact screens show one MVP line instead of the full box score.
	local mvp = Kit.text({
		Size = UDim2.fromScale(1, 0.1),
		Position = UDim2.fromScale(0, 0.8),
		Text = "",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.gold,
		MaxSize = 20,
		Visible = false,
		Parent = root,
	})

	return setmetatable({
		root = root,
		leftName = leftName,
		leftOvr = leftOvr,
		rightName = rightName,
		rightOvr = rightOvr,
		status = status,
		score = score,
		grid = grid,
		banner = banner,
		box = box,
		mvp = mvp,
		compact = false,
		token = 0,
		cells = {} :: { { TextLabel } },
	}, Scoreboard)
end

local function cellRow(parent: Instance, order: number, values: { string }, colors: { Color3 }?, font: Font?): { TextLabel }
	local row = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 1 / 3),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.list(row, true, UDim.new(0, 0))
	local labels = {}
	local n = #values
	for i, v in values do
		local width = if i == 1 then 0.22 else 0.78 / (n - 1)
		labels[i] = Kit.text({
			Size = UDim2.fromScale(width, 1),
			Text = v,
			FontFace = font or Theme.font.heavy,
			TextColor3 = if colors then colors[i] else Theme.color.text,
			TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			LayoutOrder = i,
			MaxSize = 17,
			Parent = row,
		})
	end
	return labels
end

local function boxRow(parent: Instance, order: number, values: { string }, color: Color3, font: Font)
	local row = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 1 / 9),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local widths = { 0.55, 0.15, 0.15, 0.15 }
	local x = 0
	for i, v in values do
		Kit.text({
			Size = UDim2.fromScale(widths[i], 1),
			Position = UDim2.fromScale(x, 0),
			Text = v,
			FontFace = font,
			TextColor3 = color,
			TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			MaxSize = 15,
			Parent = row,
		})
		x += widths[i]
	end
end

function Scoreboard.setCompact(self: any, compact: boolean)
	self.compact = compact
	if compact then
		self.grid.Size = UDim2.fromScale(1, 0.3)
		self.banner.Size = UDim2.fromScale(0.7, 0.13)
		self.banner.Position = UDim2.fromScale(0.15, 0.63)
	else
		self.grid.Size = UDim2.fromScale(1, 0.17)
		self.banner.Size = UDim2.fromScale(0.6, 0.085)
		self.banner.Position = UDim2.fromScale(0.2, 0.485)
	end
	if self.banner.Visible then
		self.box.Visible = not compact
		self.mvp.Visible = compact
	end
end

local function sum(t: { number }, upTo: number): number
	local s = 0
	for i = 1, upTo do
		s += t[i]
	end
	return s
end

function Scoreboard.show(self: any, data: ScoreData, animate: boolean)
	self.token += 1
	local my = self.token
	local periods = #data.left

	self.leftName.Text = data.leftName
	self.leftOvr.Text = ("TEAM OVR %d"):format(data.leftOvr)
	self.rightName.Text = data.rightName
	self.rightOvr.Text = ("TEAM OVR %d"):format(data.rightOvr)

	-- Quarter grid
	Kit.clear(self.grid, { "UIListLayout", "UIPadding", "UICorner", "UIStroke" })
	local header = { "" }
	local leftRow = { data.leftName:sub(1, 12) }
	local rightRow = { data.rightName:sub(1, 12) }
	for i = 1, periods do
		table.insert(header, periodName(i))
		table.insert(leftRow, "-")
		table.insert(rightRow, "-")
	end
	table.insert(header, "T")
	table.insert(leftRow, "0")
	table.insert(rightRow, "0")
	local dimColors = table.create(#header, Theme.color.sub)
	cellRow(self.grid, 1, header, dimColors)
	local leftCells = cellRow(self.grid, 2, leftRow)
	local rightCells = cellRow(self.grid, 3, rightRow)

	local top = data.box[1]
	self.mvp.Text = if top then ("MVP  %s  •  %d PTS  %d REB  %d AST"):format(top.name, top.pts, top.reb, top.ast) else ""

	-- Box score
	Kit.clear(self.box, { "UIListLayout", "UIPadding", "UICorner", "UIStroke" })
	boxRow(self.box, 0, { "YOUR PLAYERS", "PTS", "REB", "AST" }, Theme.color.sub, Theme.font.heavy)
	for i, line in data.box do
		boxRow(
			self.box,
			i,
			{ line.name, tostring(line.pts), tostring(line.reb), tostring(line.ast) },
			if i == 1 then Theme.color.gold else Theme.color.text,
			Theme.font.bold
		)
	end

	local function reveal(upTo: number)
		for i = 1, upTo do
			leftCells[i + 1].Text = tostring(data.left[i])
			rightCells[i + 1].Text = tostring(data.right[i])
		end
		local l, r = sum(data.left, upTo), sum(data.right, upTo)
		leftCells[periods + 2].Text = tostring(l)
		rightCells[periods + 2].Text = tostring(r)
		self.score.Text = ("%d - %d"):format(l, r)
	end

	local function finish()
		reveal(periods)
		self.status.Text = "FINAL" .. (if periods > 4 then (" / " .. periodName(periods)) else "")
		local l, r = sum(data.left, periods), sum(data.right, periods)
		self.score.TextColor3 = if l > r then Theme.color.green else Theme.color.red
		self.banner.Text = data.resultText
		self.banner.BackgroundColor3 = if data.win then Theme.color.greenDeep else Theme.color.redDeep
		self.banner.Visible = true
		self.box.Visible = not self.compact
		self.mvp.Visible = self.compact
		if animate then
			Kit.pop(self.banner, 0, 0.5)
			Kit.sound("thud", 0.6)
		end
	end

	if not animate then
		finish()
		return
	end

	self.banner.Visible = false
	self.box.Visible = false
	self.mvp.Visible = false
	self.score.TextColor3 = Theme.color.text
	self.score.Text = "0 - 0"
	task.spawn(function()
		for i = 1, periods do
			task.wait(0.6)
			if self.token ~= my then
				return
			end
			self.status.Text = periodName(i)
			reveal(i)
			Kit.pop(self.score, 0, 0.85)
			Kit.sound("tick", 0.3)
		end
		task.wait(0.4)
		if self.token ~= my then
			return
		end
		finish()
	end)
end

return Scoreboard
