# Hoops Draft: Build the Strongest NBA Team (Roblox)

A draft game in the style of *Build A Football Team*, for the NBA. Every pick you roll a random
team-season (like the 1995-96 Bulls) and choose one player from that roster for the open slot.
Fill 5 starters + 3 bench, get a team rating, earn coins, then play the CPU or another player.

## Modes
- **Solo Draft**: roll, pick, use **Reroll** (new team) or **Refresh** (same franchise, different era), then play a simulated game vs a CPU team.
- **Draft Duels (PvP)**: challenge anyone in the server, or use **Quick Match**. You both draft from the *same* roll, taking turns. If they take Jordan, he's gone. 15 seconds per pick, with an auto-pick when time runs out. Then your teams play each other. Win +150 coins, loss +40. Duel wins go on their own leaderboard. There's also **Practice vs Bot**.
- Shop (coins for rerolls/refreshes), Codes, and leaderboards for Best Team OVR and Duel Wins.
- Players at their real position keep their full rating and add chemistry. Teammates from the same season add bonus chemistry.
- 21 franchises and 47 team-seasons, in `src/shared/NBAData.luau`.
- The UI adapts to the screen: on phones the team panel becomes a TEAM button and cards scroll sideways.

## Run it in Studio with Rojo
1. In Terminal: `cd ~/roblox-nba-team && rojo serve`
2. Open Roblox Studio and create a new **Baseplate** place.
3. Go to the **Plugins** tab, click **Rojo**, then click **Connect**.
4. Press **Play** (F5).

**To test PvP by yourself:** go to the **Test** tab, set the dropdown under "Clients and Servers" to **2 Players**, and click **Start**. Two player windows open. Go to DUELS in one and challenge the other.

**To make saving and leaderboards work:** File > Publish to Roblox, then
**Game Settings > Security > Enable Studio Access to API Services**.

## Codes
`NBA`, `BALLIN`, `DYNASTY`, `GOAT`. Edit them in `src/server/Codes.luau`.

## Layout
| Path | Goes to | What |
|---|---|---|
| `src/shared` | ReplicatedStorage.Shared | Player data, rating math, draft/duel rules, game sim, config |
| `src/server` | ServerScriptService.Server | Solo + duel services, saving, leaderboards, codes, court |
| `src/client` | StarterPlayerScripts.Client | UI (`ui/App` is the entry point) |

## Tests
`tests/run_all.sh` runs:
- `tests/run.luau`: roster data, rating math, sim balance, and 300 simulated duels.
- `tests/mock/play.luau`: the real server and client scripts running on a mock Roblox engine (`tests/mock/roblox.luau`).
  Every property, method and enum is checked against Roblox's API dump.
  Three players are scripted through solo drafts, shop, codes, leaderboards, duels (with timeouts, rematch, forfeit, quick match, disconnects), bot duels, invite expiry, DataStore outages, and saving.
  The UI layout is checked for overflow and unreadable text at desktop, laptop, phone and small-phone sizes.
