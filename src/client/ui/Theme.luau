-- Colors, fonts and tier styles for the whole UI.

local Theme = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Theme.color = {
	bgTop = rgb(10, 12, 26),
	bgBottom = rgb(26, 16, 44),
	panel = rgb(19, 23, 42),
	panelHi = rgb(30, 36, 62),
	panelHi2 = rgb(42, 50, 82),
	line = rgb(255, 255, 255),
	text = rgb(244, 246, 252),
	sub = rgb(156, 166, 196),
	dim = rgb(96, 106, 138),
	orange = rgb(255, 138, 30),
	orangeDeep = rgb(255, 70, 50),
	green = rgb(52, 214, 120),
	greenDeep = rgb(20, 150, 90),
	red = rgb(244, 72, 92),
	redDeep = rgb(170, 30, 60),
	gold = rgb(255, 206, 70),
	blue = rgb(70, 146, 255),
	blueDeep = rgb(40, 80, 210),
	purple = rgb(160, 96, 255),
	purpleDeep = rgb(96, 48, 200),
	black = rgb(10, 10, 16),
}

local function family(name: string): string
	return "rbxasset://fonts/families/" .. name .. ".json"
end

Theme.font = {
	display = Font.new(family("Oswald"), Enum.FontWeight.Bold),
	heavy = Font.new(family("BuilderSans"), Enum.FontWeight.ExtraBold),
	bold = Font.new(family("BuilderSans"), Enum.FontWeight.Bold),
	medium = Font.new(family("BuilderSans"), Enum.FontWeight.Medium),
	mono = Font.new(family("RobotoMono"), Enum.FontWeight.Bold),
}

export type TierStyle = { top: Color3, bottom: Color3, text: Color3, glow: Color3 }

-- Card border/badge gradient for each rating tier (see Rating.tier).
Theme.tier = {
	LEGEND = { top = rgb(255, 232, 130), bottom = rgb(214, 140, 18), text = rgb(255, 214, 90), glow = rgb(255, 200, 60) },
	ELITE = { top = rgb(214, 150, 255), bottom = rgb(110, 50, 220), text = rgb(200, 150, 255), glow = rgb(170, 100, 255) },
	STAR = { top = rgb(120, 200, 255), bottom = rgb(40, 100, 230), text = rgb(120, 190, 255), glow = rgb(80, 150, 255) },
	STARTER = { top = rgb(130, 240, 170), bottom = rgb(30, 150, 90), text = rgb(120, 230, 160), glow = rgb(60, 210, 130) },
	ROLE = { top = rgb(190, 196, 210), bottom = rgb(100, 106, 122), text = rgb(190, 196, 210), glow = rgb(150, 155, 170) },
} :: { [string]: TierStyle }

-- Black or white text, whichever reads better on `color`.
function Theme.textOn(color: Color3): Color3
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if lum > 0.6 then Theme.color.black else Color3.new(1, 1, 1)
end

function Theme.darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function Theme.rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

return Theme
