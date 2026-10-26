-- The left-hand team panel: team rating badge, chemistry bar, and the 8 roster slots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rating = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rating"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Lineup = {}
Lineup.__index = Lineup

type Row = {
	frame: Frame,
	stroke: UIStroke,
	name: TextLabel,
	sub: TextLabel,
	ovr: TextLabel,
	filled: string?,
}

function Lineup.new(parent: Instance)
	local root = Kit.make("Frame", {
		Name = "LineupPanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local title = Kit.text({
		Size = UDim2.fromScale(0.66, 0.055),
		Text = "YOUR TEAM",
		FontFace = Theme.font.display,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 26,
		Parent = root,
	})
	local chemLabel = Kit.text({
		Size = UDim2.fromScale(0.66, 0.035),
		Position = UDim2.fromScale(0, 0.062),
		Text = "CHEMISTRY 0",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.sub,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 13,
		Parent = root,
	})
	local chemBar = Kit.make("Frame", {
		Size = UDim2.fromScale(0.62, 0.014),
		Position = UDim2.fromScale(0, 0.104),
		BackgroundColor3 = Theme.color.panelHi2,
		BorderSizePixel = 0,
		Parent = root,
	})
	Kit.round(chemBar)
	local chemFill = Kit.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = chemBar,
	})
	Kit.round(chemFill)
	Kit.gradient(chemFill, Theme.color.green, Color3.fromRGB(60, 220, 230), 0)

	local badge = Kit.make("Frame", {
		Size = UDim2.fromScale(0.3, 0.115),
		Position = UDim2.fromScale(0.7, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = root,
	})
	Kit.corner(badge, 12)
	local badgeGradient = Kit.gradient(badge, Theme.color.panelHi2, Theme.color.panelHi, 90)
	Kit.text({
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.06),
		Text = "TEAM OVR",
		FontFace = Theme.font.heavy,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.25,
		MaxSize = 11,
		Parent = badge,
	})
	local badgeValue = Kit.text({
		Size = UDim2.fromScale(1, 0.62),
		Position = UDim2.fromScale(0, 0.34),
		Text = "--",
		FontFace = Theme.font.display,
		MaxSize = 40,
		Parent = badge,
	})

	local rowsFrame = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.85),
		Position = UDim2.fromScale(0, 0.145),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Kit.list(rowsFrame, false, UDim.new(0.008, 0))

	local rows: { Row } = {}
	for i, slot in Rating.SLOTS do
		if i == 6 then
			Kit.text({
				Size = UDim2.fromScale(1, 0.04),
				Text = "BENCH",
				FontFace = Theme.font.heavy,
				TextColor3 = Theme.color.dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 55,
				MaxSize = 12,
				Parent = rowsFrame,
			})
		end
		local frame = Kit.make("Frame", {
			Name = "Slot" .. i,
			Size = UDim2.fromScale(1, 0.11),
			BackgroundColor3 = Theme.color.panelHi,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			LayoutOrder = i * 10,
			Parent = rowsFrame,
		})
		Kit.corner(frame, 10)
		local stroke = Kit.stroke(frame, Theme.color.orange, 2, 0)
		stroke.Enabled = false
		Kit.loop(stroke, 0.7, { Transparency = 0.7 })

		local tag = Kit.text({
			Size = UDim2.new(0.18, 0, 1, -10),
			Position = UDim2.new(0, 5, 0, 5),
			BackgroundTransparency = 0,
			BackgroundColor3 = if slot.bench then Theme.color.panelHi2 else Theme.color.orange,
			Text = slot.short,
			FontFace = Theme.font.display,
			TextColor3 = Color3.new(1, 1, 1),
			MaxSize = 16,
			Parent = frame,
		})
		Kit.corner(tag, 8)
		Kit.gloss(tag, 8)

		local name = Kit.text({
			Size = UDim2.fromScale(0.6, 0.48),
			Position = UDim2.fromScale(0.22, 0.1),
			Text = "Empty",
			FontFace = Theme.font.heavy,
			TextColor3 = Theme.color.dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 17,
			Parent = frame,
		})
		local sub = Kit.text({
			Size = UDim2.fromScale(0.6, 0.32),
			Position = UDim2.fromScale(0.22, 0.58),
			Text = slot.label,
			FontFace = Theme.font.medium,
			TextColor3 = Theme.color.dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 12,
			Parent = frame,
		})
		local ovr = Kit.text({
			Size = UDim2.fromScale(0.16, 0.8),
			Position = UDim2.fromScale(0.83, 0.1),
			Text = "",
			FontFace = Theme.font.display,
			MaxSize = 26,
			Parent = frame,
		})
		rows[i] = { frame = frame, stroke = stroke, name = name, sub = sub, ovr = ovr, filled = nil }
	end

	return setmetatable({
		root = root,
		title = title,
		chemLabel = chemLabel,
		chemFill = chemFill,
		badgeGradient = badgeGradient,
		badgeValue = badgeValue,
		rows = rows,
		lastOvr = -1,
	}, Lineup)
end

function Lineup.setTitle(self: any, text: string)
	self.title.Text = text
end

-- lineup[i] = player table or false. activeSlot = slot being drafted right now (highlighted).
function Lineup.render(self: any, lineup: { any }, activeSlot: number?)
	for i, slot in Rating.SLOTS do
		local row: Row = self.rows[i]
		local p = lineup[i]
		if p then
			local eff = math.floor(Rating.effective(p, slot) + 0.5)
			local natural = Rating.distance(p.positions, slot) == 0
			row.name.Text = p.name
			row.name.TextColor3 = Theme.color.text
			row.sub.Text = string.upper(p.shortLabel) .. "  •  " .. p.posText .. (if natural then "" else "  •  OFF POS")
			row.sub.TextColor3 = if natural then Theme.color.sub else Theme.color.gold
			row.ovr.Text = tostring(eff)
			row.ovr.TextColor3 = Theme.tier[Rating.tier(eff)].text
			if row.filled ~= p.name then
				row.filled = p.name
				Kit.pop(row.frame, 0, 0.85)
			end
		else
			row.name.Text = "Empty"
			row.name.TextColor3 = Theme.color.dim
			row.sub.Text = slot.label
			row.sub.TextColor3 = Theme.color.dim
			row.ovr.Text = ""
			row.filled = nil
		end
		row.stroke.Enabled = activeSlot == i and not p
	end

	local team = Rating.team(lineup)
	self.chemLabel.Text = ("CHEMISTRY %d"):format(team.chemistry)
	Kit.tween(self.chemFill, 0.4, { Size = UDim2.fromScale(team.chemistry / 100, 1) })
	if team.filled == 0 then
		self.badgeValue.Text = "--"
		self.badgeGradient.Color = ColorSequence.new(Theme.color.panelHi2, Theme.color.panelHi)
		self.lastOvr = -1
	elseif team.ovr ~= self.lastOvr then
		local tier = Theme.tier[Rating.tier(team.ovr)]
		self.badgeGradient.Color = ColorSequence.new(tier.top, tier.bottom)
		self.badgeValue.TextColor3 = Theme.textOn(tier.bottom)
		Kit.countUp(self.badgeValue, math.max(0, self.lastOvr), team.ovr, 0.5)
		self.lastOvr = team.ovr
	end
end

return Lineup
