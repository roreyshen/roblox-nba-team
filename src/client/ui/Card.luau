-- A player trading card: tier-colored frame, team band, big rating, position fit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NBAData = require(Shared:WaitForChild("NBAData"))
local Rating = require(Shared:WaitForChild("Rating"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Card = {}
Card.__index = Card

export type Card = typeof(setmetatable(
	{} :: {
		root: TextButton,
		scale: UIScale,
		overlay: Frame,
		stamp: TextLabel,
		enabled: boolean,
		taken: string?,
	},
	Card
))

function Card.new(parent: Instance, p: any, slot: any, index: number, onClick: (number) -> ()): Card
	local tierName = Rating.tier(p.ovr)
	local tier = Theme.tier[tierName]
	local franchise = NBAData.byFranchise[p.franchise]
	local teamColor = if franchise then Theme.rgb(franchise.color) else Theme.color.panelHi2

	local root = Kit.make("TextButton", {
		Name = "Card" .. index,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		LayoutOrder = index,
		Parent = parent,
	})
	Kit.corner(root, 12)
	Kit.gradient(root, tier.top, tier.bottom, 90)
	local scale = Kit.scale(root)

	local inner = Kit.make("Frame", {
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = root,
	})
	Kit.corner(inner, 10)
	Kit.gradient(inner, Theme.color.panelHi, Theme.color.panel, 90)

	-- Team band
	local band = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 0.17),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = inner,
	})
	Kit.gradient(band, teamColor, Theme.darken(teamColor, 0.35), 0)
	Kit.text({
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		Text = string.upper(p.shortLabel),
		TextColor3 = Theme.textOn(teamColor),
		FontFace = Theme.font.heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 14,
		Parent = band,
	})

	-- Rating, position, tier
	Kit.text({
		Size = UDim2.fromScale(0.52, 0.3),
		Position = UDim2.fromScale(0.06, 0.19),
		Text = tostring(p.ovr),
		FontFace = Theme.font.display,
		TextColor3 = tier.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 60,
		Parent = inner,
	})
	local pos = Kit.text({
		Size = UDim2.fromScale(0.38, 0.11),
		Position = UDim2.fromScale(0.56, 0.22),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.panelHi2,
		Text = p.posText,
		FontFace = Theme.font.heavy,
		MaxSize = 14,
		Parent = inner,
	})
	Kit.corner(pos, 6)
	Kit.text({
		Size = UDim2.fromScale(0.38, 0.11),
		Position = UDim2.fromScale(0.56, 0.34),
		Text = tierName,
		FontFace = Theme.font.heavy,
		TextColor3 = tier.text,
		MaxSize = 12,
		Parent = inner,
	})

	-- Name
	Kit.text({
		Size = UDim2.fromScale(0.9, 0.24),
		Position = UDim2.fromScale(0.05, 0.51),
		Text = p.name,
		FontFace = Theme.font.heavy,
		MaxSize = 21,
		Parent = inner,
	})

	-- Fit for the slot being drafted
	local natural = Rating.distance(p.positions, slot) == 0
	local eff = math.floor(Rating.effective(p, slot) + 0.5)
	local fit = Kit.text({
		Size = UDim2.fromScale(0.9, 0.13),
		Position = UDim2.fromScale(0.05, 0.8),
		BackgroundTransparency = 0,
		BackgroundColor3 = if natural then Theme.color.greenDeep else Theme.darken(Theme.color.gold, 0.6),
		Text = if natural then ("FITS " .. slot.short) else ("%d AT %s"):format(eff, slot.short),
		TextColor3 = if natural then Color3.new(1, 1, 1) else Theme.color.gold,
		FontFace = Theme.font.heavy,
		MaxSize = 14,
		Parent = inner,
	})
	Kit.corner(fit, 6)

	if tierName == "LEGEND" then
		Kit.shine(inner)
	end

	-- Dims the card when it's taken or not your turn
	local overlay = Kit.make("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.color.black,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.corner(overlay, 12)
	local stamp = Kit.text({
		Size = UDim2.fromScale(1, 0.17),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = -12,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.red,
		Text = "",
		FontFace = Theme.font.display,
		MaxSize = 24,
		ZIndex = 6,
		Parent = overlay,
	})

	local self = setmetatable({
		root = root,
		scale = scale,
		overlay = overlay,
		stamp = stamp,
		enabled = true,
		taken = nil,
	}, Card)

	root.MouseEnter:Connect(function()
		if self.enabled and not self.taken then
			Kit.tween(scale, 0.12, { Scale = 1.05 })
		end
	end)
	root.MouseLeave:Connect(function()
		Kit.tween(scale, 0.12, { Scale = 1 })
	end)
	root.MouseButton1Down:Connect(function()
		if self.enabled and not self.taken then
			Kit.tween(scale, 0.08, { Scale = 0.96 })
		end
	end)
	root.Activated:Connect(function()
		if self.enabled and not self.taken then
			Kit.sound("thud", 0.35)
			onClick(index)
		end
	end)

	return self
end

-- taken: stamp text ("ON YOUR TEAM", "TAKEN") or nil. enabled: can it be clicked right now.
function Card.setState(self: Card, taken: string?, enabled: boolean, takenByMe: boolean?)
	self.taken = taken
	self.enabled = enabled
	if taken then
		self.overlay.Visible = true
		self.overlay.BackgroundTransparency = 0.3
		self.stamp.Visible = true
		self.stamp.Text = taken
		self.stamp.BackgroundColor3 = if takenByMe then Theme.color.blueDeep else Theme.color.redDeep
		self.scale.Scale = 1
	elseif not enabled then
		self.overlay.Visible = true
		self.overlay.BackgroundTransparency = 0.6
		self.stamp.Visible = false
	else
		self.overlay.Visible = false
	end
end

return Card
