-- Builds a basketball court in Workspace at runtime (1 stud = 1 foot, NBA dimensions).

local Workspace = game:GetService("Workspace")

if Workspace:FindFirstChild("Court") then
	return
end

local COURT_LENGTH = 94
local COURT_WIDTH = 50
local FLOOR_TOP = 0.5
local LINE_Y = FLOOR_TOP + 0.025
local HOOP_FROM_BASELINE = 5.25
local THREE_RADIUS = 23.75
local THREE_CORNER_Z = 22

local WOOD = Color3.fromRGB(214, 165, 106)
local PAINT = Color3.fromRGB(200, 90, 30)
local WHITE = Color3.fromRGB(245, 245, 245)
local RIM = Color3.fromRGB(255, 100, 20)

local court = Instance.new("Model")
court.Name = "Court"

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = court
	return p
end

local function line(cf: CFrame, sizeX: number, sizeZ: number)
	part({
		Name = "Line",
		Size = Vector3.new(sizeX, 0.05, sizeZ),
		CFrame = cf,
		Color = WHITE,
		CanCollide = false,
	})
end

-- Ring of thin segments around `center` (flat on the floor or in the air).
-- keep(angle) decides which segments to draw (for arcs).
local function ring(center: Vector3, radius: number, segments: number, color: Color3, thickness: number, keep: ((number) -> boolean)?)
	local segLen = 2 * math.pi * radius / segments * 1.08
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * 2 * math.pi
		if not keep or keep(a) then
			local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			part({
				Name = "Ring",
				Size = Vector3.new(thickness, 0.05, segLen),
				CFrame = CFrame.new(pos) * CFrame.Angles(0, -a, 0),
				Color = color,
				CanCollide = false,
			})
		end
	end
end

-- Floor
part({
	Name = "Floor",
	Size = Vector3.new(COURT_LENGTH + 6, 1, COURT_WIDTH + 6),
	CFrame = CFrame.new(0, FLOOR_TOP - 0.5, 0),
	Color = WOOD,
	Material = Enum.Material.WoodPlanks,
})

-- Boundary + half-court line
local halfL, halfW = COURT_LENGTH / 2, COURT_WIDTH / 2
line(CFrame.new(0, LINE_Y, halfW), COURT_LENGTH, 0.4)
line(CFrame.new(0, LINE_Y, -halfW), COURT_LENGTH, 0.4)
line(CFrame.new(halfL, LINE_Y, 0), 0.4, COURT_WIDTH)
line(CFrame.new(-halfL, LINE_Y, 0), 0.4, COURT_WIDTH)
line(CFrame.new(0, LINE_Y, 0), 0.4, COURT_WIDTH)
ring(Vector3.new(0, LINE_Y, 0), 6, 32, WHITE, 0.4)

for _, side in { 1, -1 } do
	local baselineX = side * halfL
	local hoopX = side * (halfL - HOOP_FROM_BASELINE)

	-- Paint (the key): 16 ft wide, 19 ft deep. Sits just under the lines.
	part({
		Name = "Paint",
		Size = Vector3.new(19, 0.04, 16),
		CFrame = CFrame.new(baselineX - side * 9.5, FLOOR_TOP + 0.02, 0),
		Color = PAINT,
		CanCollide = false,
	})
	line(CFrame.new(baselineX - side * 19, LINE_Y, 0), 0.4, 16)
	ring(Vector3.new(baselineX - side * 19, LINE_Y, 0), 6, 24, WHITE, 0.4, function(a)
		return math.cos(a) * side < 0 -- free-throw semicircle faces half court
	end)

	-- Three-point line: arc + straight corner lines
	ring(Vector3.new(hoopX, LINE_Y, 0), THREE_RADIUS, 80, WHITE, 0.4, function(a)
		return math.cos(a) * side < 0 and math.abs(math.sin(a)) * THREE_RADIUS <= THREE_CORNER_Z
	end)
	local arcDepth = math.sqrt(THREE_RADIUS ^ 2 - THREE_CORNER_Z ^ 2)
	local cornerLen = HOOP_FROM_BASELINE + arcDepth
	for _, zSide in { 1, -1 } do
		line(CFrame.new(baselineX - side * cornerLen / 2, LINE_Y, zSide * THREE_CORNER_Z), cornerLen, 0.4)
	end

	-- Hoop: pole behind the baseline, arm, backboard 4 ft in, rim at 10 ft
	local poleX = baselineX + side * 2
	part({
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(13, 0.8, 0.8),
		CFrame = CFrame.new(poleX, FLOOR_TOP + 6.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(40, 40, 45),
		Material = Enum.Material.Metal,
	})
	local boardX = baselineX - side * 4
	part({
		Name = "Arm",
		Size = Vector3.new(math.abs(poleX - boardX), 0.4, 0.4),
		CFrame = CFrame.new((poleX + boardX) / 2, FLOOR_TOP + 12, 0),
		Color = Color3.fromRGB(40, 40, 45),
		Material = Enum.Material.Metal,
	})
	part({
		Name = "Backboard",
		Size = Vector3.new(0.3, 3.5, 6),
		CFrame = CFrame.new(boardX, FLOOR_TOP + 11.25, 0),
		Color = WHITE,
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})
	ring(Vector3.new(hoopX, FLOOR_TOP + 10, 0), 0.9, 14, RIM, 0.15)
end

court.Parent = Workspace
