# Space Rock Brainrots!

[![roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/golden-lark-12/starfall-rotlings/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/golden-lark-12/starfall-rotlings/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

A 3D brainrot game for make.fun's roblox-brainrot-01 bounty: absurd
meme creatures fall from the sky into a central crater, and you grab
one, carry it home, and set it on a base pad where it earns coins
every second. A meteor storm sweeps the crater every 90 seconds, so
get home before it hits or drop your catch. Other players can sneak
into your base and steal your Rotlings — unless you lock the base.

- **12 original Rotlings** — Wobble Wombat, Sir Puddles, Noodle Ned,
  Captain Crumb, Disco Pickle, Toaster Ghost, Sir Reginald Socks,
  Quantum Quokka, DJ Turnip, Baron von Bloop, Emperor Couch Potato and
  Galactic Gummy Bear — each built from Parts with its own silhouette,
  big eyes and a name/rarity/coins-per-second label. Every name was
  checked against the Italian brainrot roster and appears on none of it.
- **Rarities** Common, Rare, Epic, Legendary, Mythic, Cosmic, each with
  its own glow colour, plus Gold, Frozen, Rainbow and **Starstruck**
  mutations that multiply income. Starstruck is never rolled: a Rotling
  only earns it by surviving a meteor hit during a storm.
- **Stealing with a base lock** (60 seconds, then a cooldown), a **meteor
  storm** to outrun, **Rot Raiders** — NPC thieves that raid your base
  on a timer, bonk them to make them drop the loot — **rebirths** for a
  permanent income multiplier and a new base colour, a **shop** (speed,
  carry slots, income, extra pads, longer locks), an **Index** of
  Rotlings found with completion rewards, **leaderstats** (Coins,
  Rebirths), a first-time **tutorial beam** pointing at the crater, and
  **DataStore saves** of coins, upgrades and placed Rotlings.
- **Real 3D world**: a space-sunset crater with Future lighting, bloom,
  atmosphere, ColorCorrection and sun rays — now dressed: hills, angular
  boulders, crystal clusters, glowing mushrooms, floating islands that
  bob, a big ringed planet and 120 stars overhead, a tiered crater rim
  with lava cracks, steam and a pulsing gold beacon beam, and a
  warm-stone path from every base to the crater. Bases are real places:
  tiled checkerboard floors, low walls, a gate that glows red when
  locked, an owner sign, a per-base theme colour, a plinth under every
  pad and a floating gold cash counter. Rotlings are chunky characters
  with big heads, eyes, mouths, arms, feet and a prop that fits each
  name (chef hat, toast slice, disco ball, monocle, orbit ring), rarity
  auras (sparkles, glow shells, a rainbow trail), an idle bob and spin,
  and a pop with a coin burst and ding when placed. Storms darken the
  sky with lightning, thunder, wind streaks and a shaking camera. The
  HUD is rounded and bouncy, one palette, nothing clipped at the edges.

## Layout

- `src/shared/` — `Config.luau` (every tuning number), `RarityConfig.luau`
  (the six-tier ladder), `MutationConfig.luau` (Gold / Frozen / Rainbow /
  Starstruck), `RotlingCatalog.luau` (the 12-creature cast),
  `Formatting.luau` (K/M/B money, clocks) and `Remotes.luau` (the typed
  client/server wire).
- `src/server/` — `WorldBuilder` (bases and decor), `RotlingFactory`
  (builds each creature from Parts), `SpawnService` (crater spawns and
  the idle bob), `BaseService` (bases, pads, locks), `CarryService`
  (carry / place / drop), `StealService` (stealing), `StarfallService`
  (the meteor cycle and Starstruck), `RaiderService` (Rot Raiders),
  `IncomeService` (coins per second, the HUD feed, floating income
  numbers), `ShopService` (the five shop ladders), `RebirthService`
  (rebirths and base colours), `IndexService` (found sets and rewards),
  `LeaderstatsService` (Coins / Rebirths), `DataService` (profiles and
  DataStore saves), `State` (shared server state), `Tour` (screenshot
  scene setters), `Main.server.luau` (bootstrap).
- `src/client/` — `HUDController` (coins, income, storm timer, lock,
  banner, rebirth), `ShopController`, `IndexController`,
  `RarityPopupController` (the big MYTHIC! banner), `StormWarningController`
  (the red warning bar), `TutorialController` (the crater beam),
  `CameraFX` (meteor shake) and `GuiKit` (shared builders). `PhotoModeController`
  (debug: press P or type `/photo` to step through 5 fixed camera shots —
  spawn, crater, my base, carrying, HUD + name tags — chat hidden while a
  shot is framed; capture each shot with the ⋯ menu → Screenshot, then
  press P for the next). The client never decides a number; the server
  validates every buy, rebirth, lock and placement.
- `auto-checks.luau` — the pre-publish auto-checks (Lune): fails the build
  on a carried Rotling above the head, a base sign overlapping a name tag,
  a name tag overlapping the HUD, a crater Rotling under 1.5x, or a flat
  cyan spawn platform. Run with `../tools/lune run auto-checks.luau .`
  (or point it at another tree to grade that build).
- `publish.sh` — the only way to publish: runs the auto-checks first and
  stops before building or publishing on any failure, then Rojo-builds and
  publishes to the Private place. Never call the Open Cloud helper directly.
- `default.project.json` — the Rojo project: the static world skeleton
  (ground, crater, lighting, sky, spawn) plus the script layout.
- `game.rbxl` — the place, built with Rojo from the project above.
- `screenshots/` — captures of the game running in Studio; the first
  by name is the cover and matches the first Roblox thumbnail.
- `PLAY.json` — the published Public place (url, place_id, universe_id).
- `main.ts` (Node 22, standard library only) — hands the entry in: it
  copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to
  `/output` and writes `/output/dossier.json` with the vendored
  `vendor/makefun-roblox.ts`, unchanged.

## Build it

    rojo build default.project.json --output game.rbxl
    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

Before every publish, the auto-checks must pass:

    ../tools/lune run auto-checks.luau .

`publish.sh` runs them first and refuses to publish while any check
fails — never publish around it. Photo mode is for judging the game
from the same views: in Play, press P (or type `/photo`) to step
through spawn → crater → my base → carrying → HUD + name tags, capture
each shot with the ⋯ menu → Screenshot, and send the shots back.

Play it in Roblox Studio: open `game.rbxl`, press Play, walk to the
crater, press E on a Rotling to grab it, then press E on a glowing pad
on your base to place it. Watch the coins tick. `TOUR.json` names the
keys and scene functions that bring the game to each screenshot.
