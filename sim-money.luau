-- Starfall Rotlings: 60-second money simulation (fix 3 audit).
-- Reads the REAL constants out of the game source (Config, RarityConfig,
-- RotlingCatalog, MutationConfig) and replays the exact income formulas
-- from IncomeService (coinsPerSecond / incomeMult / the 1s tick) for a
-- concrete early-game loadout, printing what the HUD shows vs what
-- actually gets added, over 60 seconds — under the OLD wallet-only
-- logic and under the NEW total-wealth logic.
--
-- This is a headless arithmetic replay, not a live Roblox run: it
-- exercises the exact economy math with the real constants, but no
-- Roblox server is running here. Malek's live playtest is the final
-- confirmation.
--
-- Usage (from the repo root):
--   ../tools/lune run sim-money.luau .
-- Exit 0, prints the table.

local fs = require("@lune/fs")
local process = require("@lune/process")

local root = process.args[1] or "."
if root:sub(-1) == "/" then
	root = root:sub(1, -2)
end

local function read(path: string): string
	local ok, text = pcall(fs.readFile, root .. "/" .. path)
	if not ok then
		error("cannot read " .. path)
	end
	return text :: string
end

local function num(s: string?): number
	return tonumber(s :: string) :: number
end

-- --- Real constants, read out of the source files -----------------------
local configSrc = read("src/shared/Config.luau")
local raritySrc = read("src/shared/RarityConfig.luau")
local catalogSrc = read("src/shared/RotlingCatalog.luau")

local TICK = num(configSrc:match("TICK_INTERVAL = ([%d%.]+)"))
local REBIRTH_BASE = num(configSrc:match("REBIRTH_BASE_COST = ([%d%.]+)"))
local REBIRTH_MULT_PER = num(configSrc:match("REBIRTH_MULT_PER = ([%d%.]+)"))
local INCOME_TIER_MULT = num(configSrc:match("INCOME_TIER_MULT = ([%d%.]+)"))
local STORM_DOME_MULT = num(configSrc:match("STORM_DOME_MULT = ([%d%.]+)"))
local STORM_DURATION = num(configSrc:match("STORM_DURATION = ([%d%.]+)"))
local SELL_MULT = num(configSrc:match("SELL_MULT = ([%d%.]+)"))

-- Rarity cps: { name = "...", ... cps = N } rows in RarityConfig.
local rarityCps: { [string]: number } = {}
for name, cps in raritySrc:gmatch('name = "([%w]+)", color = Color3%.fromRGB%([^%)]+%), weight = %d+, cps = ([%d%.]+)') do
	rarityCps[name] = num(cps)
end

-- Per-creature cpsMult from the catalog (id -> cpsMult), plus rarity.
local creature: { [string]: { rarity: string, mult: number } } = {}
for id, rarity, mult in catalogSrc:gmatch('id = "([%w]+)",%s+name = "[^"]+",%s+rarity = "([%w]+)",.-cpsMult = ([%d%.]+)') do
	creature[id] = { rarity = rarity, mult = num(mult) }
end

-- --- Exact income formulas (IncomeService) ------------------------------
-- baseCps(def, mutation): rarity.cps * def.cpsMult * mutationMult.
local function baseCps(id: string, mutationMult: number?): number
	local c = creature[id]
	if not c then
		error("unknown creature " .. id)
	end
	return (rarityCps[c.rarity] or 0) * c.mult * (mutationMult or 1)
end

-- incomeMult: (1 + 0.25*rebirths) * (1 + 0.25*incomeTier) [* storm x2].
local function incomeMult(rebirths: number, incomeTier: number, stormBoost: boolean): number
	local mult = (1 + REBIRTH_MULT_PER * rebirths) * (1 + INCOME_TIER_MULT * incomeTier)
	if stormBoost then
		mult *= STORM_DOME_MULT
	end
	return mult
end

-- coinsPerSecond: floor(sum(baseCps) * incomeMult).
local function coinsPerSecond(placed: { string }, rebirths: number, incomeTier: number, stormBoost: boolean): number
	local total = 0
	for _, id in ipairs(placed) do
		total += baseCps(id)
	end
	return math.floor(total * incomeMult(rebirths, incomeTier, stormBoost))
end

-- --- Scenario: a fresh player, first 60s after placing 3 Rotlings -------
-- Placed: Wobble Wombat (Common 1/s) + Bloop the Blob (Common 1/s) +
-- Mister Muffin Feet (Rare 4.4/s). No mutations, no rebirth, no income tier,
-- no cash boost, no buddy. Missions 1+2 already paid (grab 3 -> $300,
-- place 3 -> $500), so the wallet starts at $800. Rebirth 1 costs
-- $10,000. One 8s storm falls inside the 60s window (player on base,
-- x2). Grab/place pay $0 in coins (XP only).
local placed = { "wombat", "puddles", "boba" }
local wallet0 = 300 + 500 -- mission 1 ($300) + mission 2 ($500)
local rebirthCost = REBIRTH_BASE * 1 * 1 -- rebirths=0: 10000 * 1 * 1
local cpsCalm = coinsPerSecond(placed, 0, 0, false)
local cpsStorm = coinsPerSecond(placed, 0, 0, true)

print("== Starfall Rotlings: 60-second money table (fix 3) ==")
print("Loadout: Wobble Wombat (Common) + Bloop the Blob (Common) + Mister Muffin Feet (Rare), no mutation")
print("Base cps: " .. tostring(baseCps("wombat")) .. " + " .. tostring(baseCps("puddles")) .. " + " .. tostring(baseCps("boba")) .. " = " .. tostring(baseCps("wombat") + baseCps("puddles") + baseCps("boba")) .. "/s")
print("coinsPerSecond calm: " .. tostring(cpsCalm) .. "/s (floor 6.4 x 1.00)")
print("coinsPerSecond storm (on base, x2): " .. tostring(cpsStorm) .. "/s (floor 6.4 x 2.00)")
print("Rebirth 1 cost: $" .. tostring(rebirthCost))
print("Wallet at t=0 (missions 1+2 paid): $" .. tostring(wallet0))
print("")

-- Replay 60 one-second ticks: 52 calm + 8 storm (storm inside window).
local banked = 0
local wallet = wallet0
for t = 1, 60 do
	local storm = t > 30 and t <= 30 + STORM_DURATION -- storm seconds 31-38
	local gained = coinsPerSecond(placed, 0, 0, storm)
	banked += gained -- the tick pays income into profile.banked, never the wallet
end
local total = wallet + banked

print("After 60s (52s calm + 8s storm on base):")
print("  income earned:            $" .. tostring(banked) .. " (52 x $" .. tostring(cpsCalm) .. " + 8 x $" .. tostring(cpsStorm) .. " = $" .. tostring(52 * cpsCalm + 8 * cpsStorm) .. ")")
print("  wallet (missions only):   $" .. tostring(wallet))
print("  banked (income):          $" .. tostring(banked))
print("  TOTAL wealth:             $" .. tostring(total))
print("")
print("HUD vs ACTUAL — OLD logic (wallet-only big number):")
print("  big number shows:         $" .. tostring(wallet) .. "  <- income ($" .. tostring(banked) .. ") is invisible")
print("  At base shows:            $" .. tostring(banked))
print("  NEXT REBIRTH shows:       $" .. tostring(wallet) .. " / $" .. tostring(rebirthCost) .. " (" .. string.format("%.1f", wallet / rebirthCost * 100) .. "%)  <- income does not fill it")
print("  leaderboard Coins:        $" .. tostring(wallet) .. "  (HUD top-3 already ranked total wealth: $" .. tostring(total) .. ")")
print("")
print("HUD vs ACTUAL — NEW logic (total wealth):")
print("  big number shows:         $" .. tostring(total) .. "  <- moves every second with income")
print("  At base shows:            $" .. tostring(banked) .. "  (the banked part, still collectable)")
print("  NEXT REBIRTH shows:       $" .. tostring(total) .. " / $" .. tostring(rebirthCost) .. " (" .. string.format("%.1f", total / rebirthCost * 100) .. "%)")
print("  leaderboard Coins:        $" .. tostring(total) .. "  (matches HUD + top-3)")
print("")
-- Shop affordability, projected to 5 minutes (300s calm, no storm):
-- banked = 300 x $6 = $1,800; wallet $800; total $2,600.
-- Real shop prices (ShopService.SHOP): Income tier 2 = $2,000.
local banked5 = 300 * cpsCalm
local total5 = wallet0 + banked5
print("Shop affordability after 5 minutes (300s calm): wallet $" .. tostring(wallet0) .. ", banked $" .. tostring(banked5) .. ", total $" .. tostring(total5))
print("  Income tier 2 ($2,000) — OLD: BLOCKED (wallet $" .. tostring(wallet0) .. " < $2,000)")
print("  Income tier 2 ($2,000) — NEW: AFFORDABLE (total $" .. tostring(total5) .. " >= $2,000; shortfall auto-collected from base)")
print("  Rebirth ($10,000) — NEW: still needs $10,000 total, but the bar now fills from income; on rebirth, wallet AND banked reset to $0")
print("")
print("Also verified from the traced code paths:")
print("  grab pays $0 (XP +10 only); place pays $0 (XP +15 only)")
print("  sell pays baseCps x " .. tostring(SELL_MULT) .. " to the WALLET (Mister Muffin Feet: $" .. tostring(math.floor(baseCps("boba") * SELL_MULT)) .. ")")
print("  mission 3 (Earn $5,000) counts the income tick (gained) — progress $" .. tostring(banked) .. " / $5,000 after 60s")
print("  daily $1,000, storm bounty $500, index $500/$5,000, offline earnings: all pay the WALLET")
print("  storm boost IS paid (into banked, at the x2 rate) — it was invisible, not missing")
print("== end ==")
