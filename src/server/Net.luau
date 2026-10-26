-- Server -> client pushes. Duels need this: your opponent's pick has to show up on your screen
-- without you asking. Main registers the snapshot function that builds each player's state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Push: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Push")

local Net = {}

local snapshotFn: ((Player) -> { [string]: any }?)? = nil

function Net.setSnapshot(fn: (Player) -> { [string]: any }?)
	snapshotFn = fn
end

-- Send `player` their full state, optionally with a toast message.
function Net.push(player: Player?, msg: string?, ok: boolean?)
	if not player or not player:IsDescendantOf(Players) or not snapshotFn then
		return
	end
	local state = snapshotFn(player)
	if not state then
		return
	end
	Push:FireClient(player, { ok = if ok == nil then true else ok, msg = msg, state = state })
end

function Net.pushAll(except: { [Player]: boolean }?)
	for _, player in Players:GetPlayers() do
		if not except or not except[player] then
			Net.push(player)
		end
	end
end

return Net
