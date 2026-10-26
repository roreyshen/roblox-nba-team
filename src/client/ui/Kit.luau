-- Small UI toolkit: instance builder, styled text/buttons/panels, tweens and sounds.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent:WaitForChild("Theme"))

local Kit = {}

function Kit.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(inst: Instance, px: number?): UICorner
	return Kit.make("UICorner", { CornerRadius = UDim.new(0, px or 10), Parent = inst })
end

function Kit.round(inst: Instance): UICorner
	return Kit.make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = inst })
end

function Kit.stroke(inst: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.make("UIStroke", {
		Color = color or Theme.color.line,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

function Kit.gradient(inst: Instance, a: Color3, b: Color3, rotation: number?): UIGradient
	return Kit.make("UIGradient", {
		Color = ColorSequence.new(a, b),
		Rotation = rotation or 90,
		Parent = inst,
	})
end

function Kit.pad(inst: Instance, px: number, py: number?): UIPadding
	local y = py or px
	return Kit.make("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
		Parent = inst,
	})
end

function Kit.list(inst: Instance, horizontal: boolean, padding: UDim?, props: { [string]: any }?): UIListLayout
	local layout = Kit.make("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = padding or UDim.new(0, 8),
		Parent = inst,
	})
	if props then
		for k, v in props do
			(layout :: any)[k] = v
		end
	end
	return layout
end

-- The UIScale inside `inst` (made on first use). Used for pops and hover effects.
function Kit.scale(inst: Instance): UIScale
	local existing = inst:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	return Kit.make("UIScale", { Parent = inst })
end

function Kit.clear(parent: Instance, keepClasses: { string }?)
	for _, child in parent:GetChildren() do
		local keep = false
		if keepClasses then
			for _, className in keepClasses do
				if child:IsA(className) then
					keep = true
					break
				end
			end
		end
		if not keep then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------- text

-- TextLabel with sensible defaults. `MaxSize` caps the auto-scaled text size.
function Kit.text(props: { [string]: any }): TextLabel
	local maxSize = props.MaxSize or 24
	props.MaxSize = nil
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = Theme.font.bold,
		TextColor3 = Theme.color.text,
		TextScaled = true,
		TextWrapped = true,
		Text = "",
	}
	for k, v in defaults do
		if props[k] == nil then
			props[k] = v
		end
	end
	local label = Kit.make("TextLabel", props)
	Kit.make("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = label })
	return label
end

function Kit.panel(props: { [string]: any }, radius: number?): Frame
	local defaults: { [string]: any } = {
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}
	for k, v in defaults do
		if props[k] == nil then
			props[k] = v
		end
	end
	local frame = Kit.make("Frame", props)
	Kit.corner(frame, radius or 14)
	Kit.stroke(frame, Theme.color.line, 1, 0.9)
	return frame
end

function Kit.fmt(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if s:sub(1, 1) == "-" then
		sign = "-"
		s = s:sub(2)
	end
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return sign .. out
end

function Kit.headshot(userId: number): string
	if userId <= 0 then
		return ""
	end
	return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(userId)
end

---------------------------------------------------------------- motion

function Kit.tween(inst: Instance, time: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goals
	)
	tween:Play()
	return tween
end

-- Repeats forever, back and forth.
function Kit.loop(inst: Instance, time: number, goals: { [string]: any }): Tween
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		goals
	)
	tween:Play()
	return tween
end

-- Bouncy scale-in.
function Kit.pop(inst: Instance, delay: number?, from: number?)
	local scale = Kit.scale(inst)
	scale.Scale = from or 0.6
	local function go()
		Kit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if delay and delay > 0 then
		task.delay(delay, go)
	else
		go()
	end
end

-- Animate a number in a label from `from` to `to`.
function Kit.countUp(label: TextLabel, from: number, to: number, duration: number, format: ((number) -> string)?)
	local fmt = format or function(x: number): string
		return tostring(math.floor(x + 0.5))
	end
	local value = Instance.new("NumberValue")
	value.Value = from
	label.Text = fmt(from)
	value.Changed:Connect(function(x)
		label.Text = fmt(x)
	end)
	local tween = Kit.tween(value, duration, { Value = to }, Enum.EasingStyle.Quart)
	tween.Completed:Connect(function()
		label.Text = fmt(to)
		value:Destroy()
	end)
end

-- Diagonal light sweep across `inst` (legendary cards).
function Kit.shine(inst: GuiObject)
	local sheen = Kit.make("Frame", {
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = inst,
	})
	local grad = Kit.make("UIGradient", {
		Rotation = 25,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
		Parent = sheen,
	})
	TweenService:Create(
		grad,
		TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 1.4),
		{ Offset = Vector2.new(1, 0) }
	):Play()
end

---------------------------------------------------------------- sound

local SOUND_IDS = {
	tick = "rbxasset://sounds/volume_slider.ogg",
	thud = "rbxasset://sounds/action_jump_land.mp3",
}
local sounds: { [string]: Sound } = {}

function Kit.sound(name: string, volume: number?)
	local sound = sounds[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = SOUND_IDS[name] or ""
		sound.Parent = SoundService
		sounds[name] = sound
	end
	sound.Volume = volume or 0.5
	SoundService:PlayLocalSound(sound)
end

-- Soft white shine over the top of `inst`. (Use this instead of a UIGradient on anything with
-- text: a UIGradient tints the text too, which makes white text vanish into the background.)
function Kit.gloss(inst: GuiObject, radius: number?): Frame
	local gloss = Kit.make("Frame", {
		Name = "Gloss",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = inst,
	})
	Kit.corner(gloss, radius or 10)
	Kit.make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.78),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = gloss,
	})
	return gloss
end

---------------------------------------------------------------- buttons

local BUTTON_STYLES: { [string]: { Color3 } } = {
	primary = { Theme.color.orange, Theme.color.orangeDeep },
	green = { Theme.color.green, Theme.color.greenDeep },
	blue = { Theme.color.blue, Theme.color.blueDeep },
	purple = { Theme.color.purple, Theme.color.purpleDeep },
	red = { Theme.color.red, Theme.color.redDeep },
	ghost = { Theme.color.panelHi, Theme.color.panelHi },
	dark = { Theme.color.panelHi2, Theme.color.panelHi },
}

-- Gradient button with hover/press bounce. style: primary|green|blue|purple|red|ghost|dark
function Kit.button(props: { [string]: any }, onClick: () -> (), style: string?): TextButton
	local maxSize = props.MaxSize or 22
	props.MaxSize = nil
	local colors = BUTTON_STYLES[style or "primary"] or BUTTON_STYLES.primary
	local defaults: { [string]: any } = {
		BackgroundColor3 = colors[1],
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = Theme.font.heavy,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Text = "",
	}
	for k, v in defaults do
		if props[k] == nil then
			props[k] = v
		end
	end
	local button = Kit.make("TextButton", props)
	Kit.corner(button, 10)
	Kit.gloss(button, 10)
	Kit.stroke(button, Theme.color.line, 1, if style == "ghost" then 0.8 else 0.85)
	Kit.make("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = button })
	Kit.pad(button, 8, 4)
	local scale = Kit.scale(button)

	local function disabled(): boolean
		return button:GetAttribute("Disabled") == true
	end
	button.MouseEnter:Connect(function()
		if not disabled() then
			Kit.tween(scale, 0.12, { Scale = 1.04 })
		end
	end)
	button.MouseLeave:Connect(function()
		Kit.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		if not disabled() then
			Kit.tween(scale, 0.08, { Scale = 0.95 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		Kit.tween(scale, 0.12, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		if disabled() then
			return
		end
		Kit.sound("tick", 0.3)
		onClick()
	end)
	return button
end

function Kit.setDisabled(button: GuiButton, isDisabled: boolean)
	button:SetAttribute("Disabled", isDisabled)
	button.BackgroundTransparency = if isDisabled then 0.6 else 0
	if button:IsA("TextButton") then
		button.TextTransparency = if isDisabled then 0.45 else 0
	end
end

-- Small round colored dot (currency icons etc.)
function Kit.dot(parent: Instance, color: Color3, props: { [string]: any }?): Frame
	local dot = Kit.make("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(dot :: any)[k] = v
		end
	end
	Kit.round(dot)
	Kit.gradient(dot, color:Lerp(Color3.new(1, 1, 1), 0.35), color, 45)
	Kit.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = dot })
	return dot
end

return Kit
