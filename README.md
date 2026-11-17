# Starfall Rotlings

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
  big eyes and a name/rarity/coins-per-second label.
- **Rarities** Common, Rare, Epic, Legendary, Mythic, Cosmic, each with
  its own glow colour, plus Gold, Frozen and Rainbow **mutations** that
  multiply income.
- **Stealing with a base lock** (60 seconds, then a cooldown), a **meteor
  storm** to outrun, **rebirths** for a permanent income multiplier, a
  **shop** (speed, carry slots, income), an **Index** of Rotlings found,
  and **DataStore saves** of coins, upgrades and placed Rotlings.
- **Real 3D world**: a sunset crater with Future lighting, bloom and
  atmosphere, eight coloured bases, trees, glowing mushrooms, stars and
  floating rocks, all under a 3D camera with a ScreenGui HUD on top.

## Layout

- `src/shared/` — `Config.luau` (every tuning number) and `RotlingData.luau` (the 12-creature cast).
- `src/server/` — `WorldBuilder` (bases and decor), `RotlingFactory`
  (builds each creature from Parts), `Spawner` (crater spawns),
  `Bases` (carry / place / steal / lock), `Storm` (the meteor cycle),
  `Economy` (coins, shop, rebirth, DataStore), `Remotes` (the wire),
  `Tour` (screenshot scene setters), `init.server.luau` (bootstrap).
- `src/client/Game.client.luau` — the HUD, shop, Index, rebirth and
  lock button. The client never decides a number; the server validates
  every buy, rebirth, lock and placement.
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

Play it in Roblox Studio: open `game.rbxl`, press Play, walk to the
crater, press E on a Rotling to grab it, then press E on a glowing pad
on your base to place it. Watch the coins tick. `TOUR.json` names the
keys and scene functions that bring the game to each screenshot.
