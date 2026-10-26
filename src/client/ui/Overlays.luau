-- Things that float above the pages: toasts, the Shop/Codes/Leaders modal, and duel invites.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Overlays = {}

-- ctx: { gui: ScreenGui, act(action, arg), getLeaderboard(board) -> list?, userId: number }
function Overlays.new(ctx: any)
	local self = {}
	local gui = ctx.gui

	------------------------------------------------------------ toasts
	local toastStack = Kit.make("Frame", {
		Name = "Toasts",
		Size = UDim2.new(0.4, 0, 0, 200),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = gui,
	})
	Kit.list(toastStack, false, UDim.new(0, 6), {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	})
	local toastCount = 0

	function self.toast(msg: string, isError: boolean?)
		toastCount += 1
		local frame = Kit.make("Frame", {
			Name = "Toast",
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Theme.color.panelHi,
			BorderSizePixel = 0,
			LayoutOrder = toastCount,
			ZIndex = 40,
			Parent = toastStack,
		})
		Kit.corner(frame, 12)
		Kit.stroke(frame, if isError then Theme.color.red else Theme.color.green, 2, 0)
		local bar = Kit.make("Frame", {
			Size = UDim2.new(0, 6, 1, -16),
			Position = UDim2.fromOffset(10, 8),
			BackgroundColor3 = if isError then Theme.color.red else Theme.color.green,
			BorderSizePixel = 0,
			ZIndex = 41,
			Parent = frame,
		})
		Kit.round(bar)
		Kit.text({
			Name = "Message",
			Size = UDim2.new(1, -34, 1, -10),
			Position = UDim2.fromOffset(24, 5),
			Text = msg,
			FontFace = Theme.font.heavy,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 41,
			MaxSize = 17,
			Parent = frame,
		})
		Kit.pop(frame, 0, 0.7)
		-- Keep at most 3 on screen.
		local toasts = {}
		for _, child in toastStack:GetChildren() do
			if child:IsA("Frame") then
				table.insert(toasts, child)
			end
		end
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #toasts - 3 do
			toasts[i]:Destroy()
		end
		task.delay(2.8, function()
			if frame.Parent then
				frame:Destroy()
			end
		end)
	end

	------------------------------------------------------------ modal
	local dim = Kit.make("Frame", {
		Name = "Modal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	-- Eats clicks so nothing behind the modal gets pressed.
	Kit.make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 20,
		Parent = dim,
	})
	local box = Kit.panel({
		Size = UDim2.fromScale(0.5, 0.7),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0,
		ZIndex = 21,
		Parent = dim,
	}, 16)
	Kit.make("UISizeConstraint", { MinSize = Vector2.new(320, 320), Parent = box })
	local boxTitle = Kit.text({
		Size = UDim2.new(1, -90, 0, 46),
		Position = UDim2.fromOffset(20, 14),
		Text = "",
		FontFace = Theme.font.display,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		MaxSize = 34,
		Parent = box,
	})
	local subTitle = Kit.text({
		Size = UDim2.new(0.5, 0, 0, 24),
		Position = UDim2.new(0.5, -76, 0, 26),
		Text = "",
		FontFace = Theme.font.heavy,
		TextColor3 = Theme.color.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 22,
		MaxSize = 18,
		Parent = box,
	})
	local modalKind: string? = nil
	local modalToken = 0
	local latestState: any = nil

	function self.closeModal()
		modalKind = nil
		modalToken += 1
		dim.Visible = false
	end

	Kit.button({
		Name = "CloseModal",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -58, 0, 14),
		Text = "X",
		ZIndex = 22,
		Parent = box,
	}, function()
		self.closeModal()
	end, "red")
	local body = Kit.make("Frame", {
		Size = UDim2.new(1, -40, 1, -86),
		Position = UDim2.fromOffset(20, 72),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = box,
	})

	local function open(kind: string, title: string)
		modalKind = kind
		modalToken += 1
		Kit.clear(body)
		boxTitle.Text = title
		subTitle.Text = ""
		dim.Visible = true
		Kit.pop(box, 0, 0.85)
	end

	local function refreshCoins()
		if modalKind == "shop" and latestState and latestState.profile then
			subTitle.Text = ("%s COINS"):format(Kit.fmt(latestState.profile.Coins))
		end
	end

	local SHOP_COLORS = { Rerolls = Theme.color.blue, Refreshes = Theme.color.purple }

	function self.openShop()
		open("shop", "SHOP")
		refreshCoins()
		Kit.make("UIGridLayout", {
			CellSize = UDim2.fromScale(0.48, 0.46),
			CellPadding = UDim2.fromScale(0.03, 0.06),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = body,
		})
		for i, item in Config.SHOP do
			local stat = next(item.give)
			local color = SHOP_COLORS[stat] or Theme.color.orange
			local card = Kit.panel({
				BackgroundColor3 = Theme.color.panelHi,
				LayoutOrder = i,
				ZIndex = 22,
				Parent = body,
			}, 14)
			Kit.dot(card, color, { Size = UDim2.fromScale(0.3, 0.3), Position = UDim2.fromScale(0.08, 0.1), ZIndex = 23 })
			Kit.text({
				Size = UDim2.fromScale(0.55, 0.3),
				Position = UDim2.fromScale(0.4, 0.1),
				Text = item.name,
				FontFace = Theme.font.display,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 23,
				MaxSize = 26,
				Parent = card,
			})
			Kit.button({
				Name = "Buy_" .. item.id,
				Size = UDim2.fromScale(0.84, 0.32),
				Position = UDim2.fromScale(0.08, 0.58),
				Text = ("%s COINS"):format(Kit.fmt(item.cost)),
				ZIndex = 23,
				MaxSize = 20,
				Parent = card,
			}, function()
				ctx.act("Buy", item.id)
			end, "green")
		end
	end

	function self.openCodes()
		open("codes", "CODES")
		Kit.text({
			Size = UDim2.fromScale(1, 0.14),
			Text = "Enter a code for free rerolls, refreshes, or coins.",
			FontFace = Theme.font.medium,
			TextColor3 = Theme.color.sub,
			ZIndex = 22,
			MaxSize = 20,
			Parent = body,
		})
		local input = Kit.make("TextBox", {
			Name = "CodeBox",
			Size = UDim2.fromScale(1, 0.2),
			Position = UDim2.fromScale(0, 0.22),
			BackgroundColor3 = Theme.color.panelHi,
			BorderSizePixel = 0,
			Text = "",
			PlaceholderText = "TYPE CODE HERE",
			PlaceholderColor3 = Theme.color.dim,
			TextColor3 = Theme.color.text,
			FontFace = Theme.font.display,
			TextScaled = true,
			ClearTextOnFocus = false,
			ZIndex = 22,
			Parent = body,
		})
		Kit.corner(input, 12)
		Kit.stroke(input, Theme.color.purple, 2, 0.2)
		Kit.make("UITextSizeConstraint", { MaxTextSize = 30, Parent = input })
		Kit.button({
			Name = "Redeem",
			Size = UDim2.fromScale(0.5, 0.18),
			Position = UDim2.fromScale(0.25, 0.52),
			Text = "REDEEM",
			ZIndex = 22,
			MaxSize = 26,
			Parent = body,
		}, function()
			local res = ctx.act("Redeem", input.Text)
			if res and res.ok then
				input.Text = ""
			end
		end, "purple")
	end

	local MEDALS = { Theme.color.gold, Color3.fromRGB(200, 205, 220), Color3.fromRGB(215, 140, 80) }

	function self.openLeaders(board: string?)
		local boardId = board or "best"
		open("leaders", "LEADERBOARD")
		local my = modalToken

		local tabs = Kit.make("Frame", {
			Size = UDim2.fromScale(1, 0.12),
			BackgroundTransparency = 1,
			ZIndex = 22,
			Parent = body,
		})
		Kit.list(tabs, true, UDim.new(0.02, 0))
		for i, def in { { "best", "BEST TEAM OVR" }, { "duel", "DUEL WINS" } } do
			Kit.button({
				Name = "Board_" .. def[1],
				Size = UDim2.fromScale(0.49, 1),
				Text = def[2],
				LayoutOrder = i,
				ZIndex = 22,
				MaxSize = 18,
				Parent = tabs,
			}, function()
				self.openLeaders(def[1])
			end, if def[1] == boardId then "primary" else "ghost")
		end

		local listFrame = Kit.make("Frame", {
			Size = UDim2.fromScale(1, 0.85),
			Position = UDim2.fromScale(0, 0.15),
			BackgroundTransparency = 1,
			ZIndex = 22,
			Parent = body,
		})
		local loading = Kit.text({
			Size = UDim2.fromScale(1, 0.1),
			Text = "Loading...",
			FontFace = Theme.font.heavy,
			TextColor3 = Theme.color.sub,
			ZIndex = 22,
			MaxSize = 20,
			Parent = listFrame,
		})

		task.spawn(function()
			local entries = ctx.getLeaderboard(boardId)
			if modalToken ~= my then
				return
			end
			if not entries then
				loading.Text = "Couldn't load the leaderboard."
				return
			end
			if #entries == 0 then
				loading.Text = "No one yet. Be the first!"
				return
			end
			loading:Destroy()
			Kit.list(listFrame, false, UDim.new(0.01, 0))
			for i, e in entries do
				local mine = e.userId == ctx.userId
				local row = Kit.make("Frame", {
					Size = UDim2.fromScale(1, 0.09),
					BackgroundColor3 = if mine then Theme.color.panelHi2 else Theme.color.panelHi,
					BorderSizePixel = 0,
					LayoutOrder = i,
					ZIndex = 22,
					Parent = listFrame,
				})
				Kit.corner(row, 8)
				Kit.text({
					Size = UDim2.fromScale(0.1, 0.8),
					Position = UDim2.fromScale(0.01, 0.1),
					Text = "#" .. i,
					FontFace = Theme.font.display,
					TextColor3 = MEDALS[i] or Theme.color.sub,
					ZIndex = 23,
					MaxSize = 20,
					Parent = row,
				})
				local avatar = Kit.make("ImageLabel", {
					Size = UDim2.fromScale(0.07, 0.84),
					Position = UDim2.fromScale(0.12, 0.08),
					BackgroundColor3 = Theme.color.panel,
					BorderSizePixel = 0,
					Image = Kit.headshot(e.userId),
					ZIndex = 23,
					Parent = row,
				})
				Kit.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = avatar })
				Kit.round(avatar)
				Kit.text({
					Size = UDim2.fromScale(0.55, 0.8),
					Position = UDim2.fromScale(0.21, 0.1),
					Text = e.name,
					FontFace = Theme.font.heavy,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 23,
					MaxSize = 20,
					Parent = row,
				})
				Kit.text({
					Size = UDim2.fromScale(0.2, 0.8),
					Position = UDim2.fromScale(0.78, 0.1),
					Text = tostring(e.value),
					FontFace = Theme.font.display,
					TextColor3 = MEDALS[i] or Theme.color.text,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 23,
					MaxSize = 24,
					Parent = row,
				})
			end
		end)
	end

	------------------------------------------------------------ duel invite popup
	local invite = Kit.panel({
		Name = "Invite",
		Size = UDim2.new(0.42, 0, 0, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		BackgroundColor3 = Theme.color.panel,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	}, 16)
	Kit.make("UISizeConstraint", { MinSize = Vector2.new(330, 150), Parent = invite })
	Kit.stroke(invite, Theme.color.purple, 3, 0)
	local inviteAvatar = Kit.make("ImageLabel", {
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.color.panelHi2,
		BorderSizePixel = 0,
		ZIndex = 31,
		Parent = invite,
	})
	Kit.round(inviteAvatar)
	local inviteText = Kit.text({
		Size = UDim2.new(1, -110, 0, 64),
		Position = UDim2.fromOffset(92, 16),
		Text = "",
		RichText = true,
		FontFace = Theme.font.heavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
		MaxSize = 22,
		Parent = invite,
	})
	local inviteBar = Kit.make("Frame", {
		Size = UDim2.new(1, -32, 0, 4),
		Position = UDim2.fromOffset(16, 88),
		BackgroundColor3 = Theme.color.purple,
		BorderSizePixel = 0,
		ZIndex = 31,
		Parent = invite,
	})
	Kit.round(inviteBar)
	Kit.button({
		Name = "AcceptInvite",
		Size = UDim2.new(0.5, -22, 0, 40),
		Position = UDim2.fromOffset(16, 100),
		Text = "ACCEPT",
		ZIndex = 31,
		Parent = invite,
	}, function()
		ctx.act("RespondInvite", true)
	end, "green")
	Kit.button({
		Name = "DeclineInvite",
		Size = UDim2.new(0.5, -22, 0, 40),
		Position = UDim2.new(0.5, 6, 0, 100),
		Text = "DECLINE",
		ZIndex = 31,
		Parent = invite,
	}, function()
		ctx.act("RespondInvite", false)
	end, "red")

	local inviteExpires: number? = nil
	local inviteFrom: number? = nil

	RunService.Heartbeat:Connect(function()
		if inviteExpires then
			local left = math.max(0, inviteExpires - Workspace:GetServerTimeNow())
			inviteBar.Size = UDim2.new((1 * left / Config.INVITE_SECONDS), -32 * left / Config.INVITE_SECONDS, 0, 4)
		end
	end)

	------------------------------------------------------------ render

	function self.render(state: any)
		latestState = state
		refreshCoins()

		local incoming = state.lobby and state.lobby.incoming
		if incoming and not state.duel then
			if inviteFrom ~= incoming.userId or not invite.Visible then
				inviteFrom = incoming.userId
				inviteAvatar.Image = Kit.headshot(incoming.userId)
				inviteText.Text = ("<font color=\"#a060ff\">%s</font> challenged you to a DRAFT DUEL!"):format(incoming.name)
				invite.Visible = true
				Kit.pop(invite, 0, 0.7)
				Kit.sound("thud", 0.6)
			end
			inviteExpires = incoming.expires
		else
			invite.Visible = false
			inviteExpires = nil
			inviteFrom = nil
		end
	end

	return self
end

return Overlays
