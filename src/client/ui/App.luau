-- App shell: backdrop, top bar (tabs + currencies), team panel, page routing and server calls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Lineup = require(script.Parent:WaitForChild("Lineup"))
local SoloPages = require(script.Parent:WaitForChild("SoloPages"))
local DuelPages = require(script.Parent:WaitForChild("DuelPages"))
local Overlays = require(script.Parent:WaitForChild("Overlays"))

local App = {}

function App.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Our UI fills the screen: hide Roblox's player list (RANKS replaces it) and move chat to the
	-- bottom-left so it doesn't cover the tabs.
	local ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		local chatWindow = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if chatWindow then
			chatWindow.VerticalAlignment = Enum.VerticalAlignment.Bottom
			chatWindow.HorizontalAlignment = Enum.HorizontalAlignment.Left
		end
	end)
	if not ok then
		warn("[HoopsDraft] Couldn't adjust core UI:", err)
	end

	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local ActionRemote: RemoteFunction = Remotes:WaitForChild("Action")
	local LeaderboardRemote: RemoteFunction = Remotes:WaitForChild("GetLeaderboard")
	local PushRemote: RemoteEvent = Remotes:WaitForChild("Push")

	------------------------------------------------------------ backdrop (covers the top inset too)
	local backdrop = Kit.make("ScreenGui", {
		Name = "HoopsBackdrop",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 4,
		Parent = playerGui,
	})
	local bg = Kit.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = backdrop,
	})
	Kit.gradient(bg, Theme.color.bgTop, Theme.color.bgBottom, 90)
	-- Faint center-court circles for flavor.
	for i, size in { 1.1, 0.5 } do
		local ring = Kit.make("Frame", {
			Size = UDim2.fromScale(size, size),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.72, 0.6),
			BackgroundTransparency = 1,
			Parent = bg,
		})
		Kit.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = ring })
		Kit.round(ring)
		Kit.stroke(ring, Theme.color.orange, if i == 1 then 4 else 3, 0.88)
	end

	------------------------------------------------------------ main gui
	local gui = Kit.make("ScreenGui", {
		Name = "HoopsDraft",
		IgnoreGuiInset = false,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local shell = Kit.make("Frame", {
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local shellPadding = Kit.pad(shell, 12, 10)

	-- forward declarations
	local act: (string, any) -> any
	local render: (any) -> ()
	local setTab: (string) -> ()
	local overlays: any

	------------------------------------------------------------ top bar
	local top = Kit.panel({
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 58),
		Parent = shell,
	}, 14)
	Kit.text({
		Size = UDim2.new(0.15, 0, 1, -14),
		Position = UDim2.fromOffset(16, 7),
		Text = "<font color=\"#ff8a1e\">HOOPS</font> DRAFT",
		RichText = true,
		FontFace = Theme.font.display,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 32,
		Parent = top,
	})

	local tabsFrame = Kit.make("Frame", {
		Size = UDim2.new(0.25, 0, 1, -16),
		Position = UDim2.new(0.17, 0, 0, 8),
		BackgroundTransparency = 1,
		Parent = top,
	})
	Kit.list(tabsFrame, true, UDim.new(0.03, 0))
	local tabButtons: { [string]: TextButton } = {}
	for i, def in { { "solo", "SOLO DRAFT" }, { "duels", "DUELS" } } do
		tabButtons[def[1]] = Kit.button({
			Name = "Tab_" .. def[1],
			Size = UDim2.fromScale(0.485, 1),
			Text = def[2],
			LayoutOrder = i,
			MaxSize = 18,
			Parent = tabsFrame,
		}, function()
			setTab(def[1])
		end, "ghost")
	end
	local inviteBadge = Kit.text({
		Size = UDim2.fromOffset(20, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.color.red,
		Text = "!",
		FontFace = Theme.font.heavy,
		ZIndex = 3,
		Visible = false,
		MaxSize = 14,
		Parent = tabButtons.duels,
	})
	inviteBadge:SetAttribute("AllowOverflow", true) -- pokes out of the tab's corner on purpose
	Kit.round(inviteBadge)

	local function styleTab(active: string)
		for id, button in tabButtons do
			button.BackgroundColor3 = if id == active then Theme.color.orange else Theme.color.panelHi
			button.TextColor3 = if id == active then Color3.new(1, 1, 1) else Theme.color.sub
		end
	end

	local rightGroup = Kit.make("Frame", {
		Size = UDim2.new(0.57, -12, 1, 0),
		Position = UDim2.fromScale(0.43, 0),
		BackgroundTransparency = 1,
		Parent = top,
	})
	Kit.list(rightGroup, true, UDim.new(0.01, 0), {
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	local pillFrames: { Frame } = {}
	local function pill(caption: string, color: Color3, order: number): TextLabel
		local frame = Kit.make("Frame", {
			Size = UDim2.fromScale(0.15, 0.74),
			BackgroundColor3 = Theme.color.panelHi,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = rightGroup,
		})
		Kit.corner(frame, 10)
		Kit.dot(frame, color, {
			Size = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.07, 0.5),
		})
		local value = Kit.text({
			Size = UDim2.fromScale(0.62, 0.56),
			Position = UDim2.fromScale(0.34, 0.04),
			Text = "-",
			FontFace = Theme.font.display,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 20,
			Parent = frame,
		})
		Kit.text({
			Size = UDim2.fromScale(0.62, 0.34),
			Position = UDim2.fromScale(0.34, 0.58),
			Text = caption,
			FontFace = Theme.font.heavy,
			TextColor3 = Theme.color.sub,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 10,
			Parent = frame,
		})
		pillFrames[order] = frame
		return value
	end
	local coinsValue = pill("COINS", Theme.color.gold, 1)
	local rerollsValue = pill("REROLLS", Theme.color.blue, 2)
	local refreshesValue = pill("REFRESHES", Theme.color.purple, 3)
	local bestValue = pill("BEST OVR", Theme.color.orange, 4)

	local teamOpen = false
	local teamButton: TextButton
	local leftPanel: Frame
	for i, def in {
		{ "ToggleTeam", "TEAM", "primary" },
		{ "OpenShop", "SHOP", "green" },
		{ "OpenCodes", "CODES", "purple" },
		{ "OpenLeaders", "RANKS", "blue" },
	} do
		local button = Kit.button({
			Name = def[1],
			Size = UDim2.fromScale(0.11, 0.74),
			Text = def[2],
			LayoutOrder = 10 + i,
			MaxSize = 16,
			Parent = rightGroup,
		}, function()
			if def[1] == "ToggleTeam" then
				teamOpen = not teamOpen
				leftPanel.Visible = teamOpen
				if teamOpen then
					Kit.pop(leftPanel, 0, 0.9)
				end
			elseif def[1] == "OpenShop" then
				overlays.openShop()
			elseif def[1] == "OpenCodes" then
				overlays.openCodes()
			else
				overlays.openLeaders("best")
			end
		end, def[3])
		if def[1] == "ToggleTeam" then
			teamButton = button
			button.Visible = false
		end
	end

	------------------------------------------------------------ body
	local body = Kit.make("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -70),
		Position = UDim2.fromOffset(0, 70),
		BackgroundTransparency = 1,
		Parent = shell,
	})
	leftPanel = Kit.panel({
		Name = "TeamPanel",
		Size = UDim2.new(0.27, -6, 1, 0),
		ZIndex = 5,
		Parent = body,
	}, 16)
	Kit.pad(leftPanel, 12, 12)
	local lineup = Lineup.new(leftPanel)

	local content = Kit.panel({
		Name = "Content",
		Size = UDim2.new(0.73, -6, 1, 0),
		Position = UDim2.new(0.27, 6, 0, 0),
		Parent = body,
	}, 16)
	Kit.pad(content, 16, 14)
	local loadingLabel = Kit.text({
		Size = UDim2.fromScale(1, 0.1),
		Position = UDim2.fromScale(0, 0.45),
		Text = "LOADING YOUR TEAM...",
		FontFace = Theme.font.display,
		TextColor3 = Theme.color.sub,
		MaxSize = 30,
		Parent = content,
	})

	local pages: { [string]: Frame } = {}
	local currentPage: string? = nil

	local function addPage(name: string): Frame
		local frame = Kit.make("Frame", {
			Name = name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = content,
		})
		pages[name] = frame
		return frame
	end

	local function showPage(name: string)
		loadingLabel.Visible = false
		if currentPage == name then
			return
		end
		currentPage = name
		for pageName, frame in pages do
			frame.Visible = pageName == name
		end
		local frame = pages[name]
		frame.Position = UDim2.fromOffset(0, 18)
		Kit.tween(frame, 0.25, { Position = UDim2.fromOffset(0, 0) })
	end

	------------------------------------------------------------ state + server calls
	local tab: string = "solo"
	local currentState: any = nil
	local busy = false

	local function handle(res: any)
		if type(res) ~= "table" then
			return
		end
		if res.msg then
			overlays.toast(res.msg, res.ok == false)
		end
		if res.state then
			render(res.state)
		end
	end

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
			overlays.toast("Couldn't reach the server. Try again.", true)
			return nil
		end
		handle(res)
		return res
	end

	local function getLeaderboard(board: string): { any }?
		local ok, res = pcall(function()
			return LeaderboardRemote:InvokeServer(board)
		end)
		if ok and type(res) == "table" then
			return res
		end
		return nil
	end

	local ctx = {
		gui = gui,
		userId = player.UserId,
		act = function(action: string, arg: any)
			return act(action, arg)
		end,
		addPage = addPage,
		setTab = function(t: string)
			setTab(t)
		end,
		isVisible = function(name: string): boolean
			return currentPage == name
		end,
		getLeaderboard = getLeaderboard,
	}
	overlays = Overlays.new(ctx)
	local soloPages = SoloPages.new(ctx)
	local duelPages = DuelPages.new(ctx)

	render = function(state: any)
		local profile = state.profile
		if not profile then
			return
		end
		currentState = state

		coinsValue.Text = Kit.fmt(profile.Coins)
		rerollsValue.Text = tostring(profile.Rerolls)
		refreshesValue.Text = tostring(profile.Refreshes)
		bestValue.Text = tostring(profile.BestOVR)
		overlays.render(state)
		inviteBadge.Visible = state.lobby ~= nil and state.lobby.incoming ~= nil and state.duel == nil

		local page
		local duel = state.duel
		local run = state.run
		if duel then
			tab = "duels" -- so leaving the result lands back in the Duels lobby
			lineup:setTitle("YOUR DUEL TEAM")
			lineup:render(duel.me.lineup, if duel.phase == "drafting" then duel.round else nil)
			page = duelPages.render(state)
			styleTab("duels")
		elseif tab == "duels" then
			lineup:setTitle("YOUR TEAM")
			lineup:render(if run then run.lineup else {}, nil)
			page = duelPages.renderLobby(state)
			styleTab("duels")
		else
			lineup:setTitle("YOUR TEAM")
			lineup:render(if run then run.lineup else {}, if run and run.phase == "drafting" then run.slot else nil)
			page = soloPages.render(state)
			styleTab("solo")
		end
		showPage(page)
	end

	setTab = function(t: string)
		local duel = currentState and currentState.duel
		if duel and duel.phase == "drafting" and t ~= "duels" then
			overlays.toast("Finish your duel first!", true)
			return
		end
		tab = t
		if t == "solo" then
			soloPages.resetBoard()
		end
		if duel and duel.phase == "done" and t ~= "duels" then
			act("DismissDuel")
		elseif currentState then
			render(currentState)
		end
	end

	-- Phones / small windows: slimmer top bar, team panel becomes a TEAM toggle, pages go compact.
	local compact: boolean? = nil
	local function applyCompact(isCompact: boolean)
		if compact == isCompact then
			return
		end
		compact = isCompact
		local barHeight = if isCompact then 42 else 58
		local gap = if isCompact then 6 else 12
		shellPadding.PaddingLeft = UDim.new(0, gap)
		shellPadding.PaddingRight = UDim.new(0, gap)
		shellPadding.PaddingTop = UDim.new(0, if isCompact then 4 else 10)
		shellPadding.PaddingBottom = UDim.new(0, if isCompact then 4 else 10)
		top.Size = UDim2.new(1, 0, 0, barHeight)
		body.Position = UDim2.fromOffset(0, barHeight + gap)
		body.Size = UDim2.new(1, 0, 1, -(barHeight + gap))
		pillFrames[4].Visible = not isCompact
		teamButton.Visible = isCompact
		if isCompact then
			teamOpen = false
			leftPanel.Visible = false
			leftPanel.Size = UDim2.fromScale(0.42, 1)
			leftPanel.BackgroundTransparency = 0.02
			content.Position = UDim2.new()
			content.Size = UDim2.fromScale(1, 1)
		else
			leftPanel.Visible = true
			leftPanel.Size = UDim2.new(0.27, -6, 1, 0)
			leftPanel.BackgroundTransparency = 0.08
			content.Position = UDim2.new(0.27, 6, 0, 0)
			content.Size = UDim2.new(0.73, -6, 1, 0)
		end
		soloPages.setCompact(isCompact)
		duelPages.setCompact(isCompact)
	end

	local camera = Workspace.CurrentCamera
	while not camera do
		task.wait()
		camera = Workspace.CurrentCamera
	end
	local function onViewport()
		local size = camera.ViewportSize
		applyCompact(size.Y < 650 or size.X < 1000)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewport)
	onViewport()

	styleTab("solo")
	PushRemote.OnClientEvent:Connect(handle)

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
end

return App
