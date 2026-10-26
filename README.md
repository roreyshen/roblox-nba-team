# Build the Strongest NBA Team (Roblox)

Draft game in the style of *Build A Football Team*, for the NBA. Every pick you roll a random
team-season (like the 1995-96 Bulls) and choose one player from that roster for the open slot.
Fill 5 starters + 3 bench, get a team rating, earn coins, then play a simulated game vs a CPU team.

- **Reroll** = new random team. **Refresh** = same franchise, different era.
- Players at their real position keep their full rating and add chemistry. Teammates from the same season add bonus chemistry.
- Shop (coins -> rerolls/refreshes), Codes, and a global Best-OVR leaderboard.
- 21 franchises and 47 team-seasons, in `src/shared/NBAData.luau`.

## Run it in Studio with Rojo

1. In Terminal: `cd ~/roblox-nba-team && rojo serve`
2. Open Roblox Studio and create a new **Baseplate** place.
3. Go to the **Plugins** tab, click **Rojo**, then click **Connect** (localhost:34872).
4. Press **Play** (F5).

For saving and the leaderboard: publish the place (File > Publish to Roblox), then go to
**Game Settings > Security** and turn on **Enable Studio Access to API Services**.
Without this the game still runs, but your progress resets every time.

## Codes
`NBA`, `BALLIN`, `DYNASTY`, `GOAT`. Edit them in `src/server/Codes.luau`.

## Layout
| Path | Goes to | What |
|---|---|---|
| `src/shared` | ReplicatedStorage.Shared | Player data, rating math, game sim, config |
| `src/server` | ServerScriptService.Server | Draft logic, saving, leaderboard, court builder, codes |
| `src/client` | StarterPlayerScripts.Client | All UI |

## Tests
`luau tests/run.luau` checks the roster data, rating math, and sim with no Studio needed.
