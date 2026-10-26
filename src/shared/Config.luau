--!strict
-- Tunable numbers shared by server and client. (Codes live server-side in Server/Codes.)

local Config = {}

Config.DEFAULT_DATA = {
	Coins = 100,
	Rerolls = 10,
	Refreshes = 5,
	BestOVR = 0,
	BestTeam = {},
	Drafts = 0,
	Wins = 0,
	Losses = 0,
	Codes = {},
}

export type ShopItem = { id: string, name: string, cost: number, give: { [string]: number } }

Config.SHOP = {
	{ id = "rerolls5", name = "5 Rerolls", cost = 100, give = { Rerolls = 5 } },
	{ id = "refreshes5", name = "5 Refreshes", cost = 150, give = { Refreshes = 5 } },
	{ id = "rerolls20", name = "20 Rerolls", cost = 350, give = { Rerolls = 20 } },
	{ id = "refreshes20", name = "20 Refreshes", cost = 500, give = { Refreshes = 20 } },
} :: { ShopItem }

-- Coins for a simulated game vs CPU.
Config.WIN_COINS = 60
Config.WIN_COINS_PER_POINT = 2 -- bonus per point of margin
Config.WIN_MARGIN_CAP = 30
Config.LOSS_COINS = 15

return Config
