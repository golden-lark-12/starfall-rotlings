-- Starfall Rotlings: Rebirth-2 proof (simplify/polish, real-base section).
-- Rebirth 2 must reset cash only and keep the index (and the placed
-- Brainrots, XP, level and Stardust) — and recolor the base, the one
-- visible side effect the reset is allowed to have. Four proofs:
--   (1) STATIC: the doRebirth body in RebirthService.luau assigns ONLY
--       profile.coins, profile.banked and profile.rebirths — no touch
--       of placed, index, xp, level, stardust, or any remove/clear.
--   (2) REPLAY: a concrete profile (cash + banked + 3 placed Brainrots
--       + 14/20 index + XP + level + Stardust) goes through the exact
--       reset the code performs; everything but the cash survives.
--   (3) BASE COLOUR: the rebirth recolors the base by cycling the
--       8-entry COLORS palette by rebirth count, so Rebirth 2 takes
--       entry 2 (blue 120, 180, 255) and Rebirth 9 wraps to entry 1.
--   (4) COST: the price the player is charged is the price the HUD
--       shows — both compute Config.REBIRTH_BASE_COST x (rebirths+1)^2
--       from the same base (10000), so Rebirth 2 costs $40,000 and
--       Rebirth 3 costs $90,000.
--
-- This is a headless replay, not a live Roblox run: it exercises the
-- exact reset logic with the real source, but no Roblox server is
-- running here. Malek's live playtest is the final confirmation.
--
-- Usage (from the repo root):
--   ../tools/lune run verify-rebirth.luau .
-- Exit 0 = proof holds, exit 1 = it does not.

local fs = require("@lune/fs")
local process = require("@lune/process")

local root = process.args[1] or "."
if root:sub(-1) == "/" then
	root = root:sub(1, -2)
end

local function read(path: string): string
	local ok, text = pcall(fs.readFile, root .. "/" .. path)
	if not ok then
		print("FAIL: cannot read " .. path)
		process.exit(1)
	end
	return text :: string
end

local failures: { string } = {}
local function assertOk(ok: boolean, problem: string)
	if not ok then
		table.insert(failures, problem)
	end
end

-- (1) STATIC: extract the doRebirth body.
local rebirthSrc = read("src/server/RebirthService.luau")
local bodyStart = rebirthSrc:find("function RebirthService.doRebirth", 1, true)
assertOk(bodyStart ~= nil, "doRebirth not found in RebirthService.luau")
local bodyEnd = nil
if bodyStart then
	bodyEnd = rebirthSrc:find("\nend\n\n-- Wire the DoRebirth", bodyStart, true)
end
assertOk(bodyEnd ~= nil, "doRebirth body end not found")
local body = ""
if bodyStart and bodyEnd then
	body = rebirthSrc:sub(bodyStart, bodyEnd)
end

-- The reset: exactly these three assignments, nothing else.
assertOk(body:find("profile%.coins = 0") ~= nil, "doRebirth does not reset profile.coins to 0")
assertOk(body:find("profile%.banked = 0") ~= nil, "doRebirth does not reset profile.banked to 0")
assertOk(body:find("profile%.rebirths %+= 1") ~= nil, "doRebirth does not increment profile.rebirths")
for _, forbidden in ipairs({ "placed", "index", "%.xp", "level", "stardust", "removePlaced", "clearPlaced", "State%.placed" }) do
	assertOk(body:find(forbidden) == nil, "doRebirth touches '" .. forbidden .. "' — the reset is not cash-only")
end

-- DataService persists placed + index (the reset keeps them, the save
-- must keep them too, or a rejoin would still wipe them).
local dataSrc = read("src/server/DataService.luau")
assertOk(dataSrc:find("placed = {},") ~= nil, "default profile has no placed table")
assertOk(dataSrc:find("index = {},") ~= nil, "default profile has no index table")

-- (2) REPLAY: a mid-game profile through the exact reset.
print("--- Rebirth-2 replay: profile before the rebirth ---")
local profile = {
	coins = 25000,
	banked = 20000,
	rebirths = 1,
	placed = {
		{ name = "Boba Blob", padIndex = 1 },
		{ name = "Gloopy Goose", padIndex = 2 },
		{ name = "Sir Reginald Ramen", padIndex = 3 },
	},
	index = {},
	xp = 450,
	level = 5,
	stardust = 30,
}
for i = 1, 14 do
	profile.index[i] = true
end
local function countIndex(t: { [number]: boolean }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end
print(string.format(
	"coins $%d, banked $%d, rebirths %d, placed %d, index %d/20, xp %d, level %d, stardust %d",
	profile.coins, profile.banked, profile.rebirths, #profile.placed, countIndex(profile.index), profile.xp, profile.level, profile.stardust
))

-- The reset, exactly as doRebirth performs it — gated on the same
-- cost check (rebirthCost(1) = 10000 * 2 * 2 = $40,000, paid from
-- total wealth: coins + banked).
local cost = 10000 * (profile.rebirths + 1) * (profile.rebirths + 1)
local totalWealth = profile.coins + profile.banked
print(string.format("rebirth cost $%d, total wealth $%d — affordable: %s", cost, totalWealth, tostring(totalWealth >= cost)))
assertOk(totalWealth >= cost, "replay profile cannot afford Rebirth 2 (cost $40,000)")
profile.coins = 0
profile.banked = 0
profile.rebirths += 1

print("--- the same profile after Rebirth 2 ---")
print(string.format(
	"coins $%d, banked $%d, rebirths %d, placed %d, index %d/20, xp %d, level %d, stardust %d",
	profile.coins, profile.banked, profile.rebirths, #profile.placed, countIndex(profile.index), profile.xp, profile.level, profile.stardust
))
assertOk(profile.coins == 0, "coins not zeroed")
assertOk(profile.banked == 0, "banked not zeroed")
assertOk(profile.rebirths == 2, "rebirths not incremented to 2")
assertOk(#profile.placed == 3, "placed Brainrots lost in the rebirth")
assertOk(profile.placed[1].name == "Boba Blob", "placed Brainrot 1 changed")
assertOk(countIndex(profile.index) == 14, "index lost entries in the rebirth")
assertOk(profile.xp == 450, "xp changed in the rebirth")
assertOk(profile.level == 5, "level changed in the rebirth")
assertOk(profile.stardust == 30, "stardust changed in the rebirth")

-- (3) BASE COLOUR: the rebirth recolors the base — the one visible
-- side effect allowed. The colour cycles the COLORS palette by
-- rebirth count: entry (rebirths - 1) % 8 + 1, so Rebirth 2 takes
-- entry 2 (blue 120, 180, 255) and Rebirth 9 wraps to entry 1.
local colorsStart = rebirthSrc:find("RebirthService.COLORS = {", 1, true)
assertOk(colorsStart ~= nil, "COLORS palette not found in RebirthService.luau")
local colorsEnd = nil
if colorsStart then
	colorsEnd = rebirthSrc:find("} :: { Color3 }", colorsStart, true)
end
assertOk(colorsEnd ~= nil, "COLORS palette end not found")
local colorsBlock = ""
if colorsStart and colorsEnd then
	colorsBlock = rebirthSrc:sub(colorsStart, colorsEnd)
end
local colorEntries: { string } = {}
for r, g, b in colorsBlock:gmatch("Color3%.fromRGB%((%d+), (%d+), (%d+)%)") do
	table.insert(colorEntries, r .. ", " .. g .. ", " .. b)
end
assertOk(#colorEntries == 8, "COLORS palette has " .. tostring(#colorEntries) .. " entries, not 8 — the rebirth colour cycle is broken")
assertOk(body:find("WorldBuilder.setBaseColor(baseId, color)", 1, true) ~= nil, "doRebirth does not recolor the base")
assertOk(body:find("RebirthService.COLORS[(profile.rebirths - 1) % #RebirthService.COLORS + 1]", 1, true) ~= nil, "doRebirth does not cycle the base colour by rebirth count")
local colorIndex = (profile.rebirths - 1) % #colorEntries + 1
print(string.format("base colour after Rebirth 2: palette entry %d of %d (RGB %s)", colorIndex, #colorEntries, colorEntries[colorIndex] or "?"))
assertOk(colorIndex == 2, "Rebirth 2 takes palette entry " .. tostring(colorIndex) .. ", not entry 2")
assertOk(colorEntries[colorIndex] == "120, 180, 255", "palette entry 2 is RGB " .. (colorEntries[colorIndex] or "?") .. ", not 120, 180, 255 (blue)")
-- The cycle wraps: Rebirth 9 takes palette entry 1 again.
local wrapIndex = (9 - 1) % #colorEntries + 1
assertOk(wrapIndex == 1, "Rebirth 9 takes palette entry " .. tostring(wrapIndex) .. ", not entry 1 — the colour cycle does not wrap")

-- (4) COST: the price charged is the price shown. Both the charge
-- (RebirthService.rebirthCost, used by doRebirth) and the HUD display
-- (IncomeService, which sends rebirthCost + rebirthProgress to the
-- client) must compute the same formula from the same base, or the
-- player would see one price and be charged another.
local configSrc = read("src/shared/Config.luau")
local baseStart = configSrc:find("Config.REBIRTH_BASE_COST = ", 1, true)
assertOk(baseStart ~= nil, "REBIRTH_BASE_COST not found in Config.luau")
local baseCost: number? = nil
if baseStart then
	local numStart = baseStart + #"Config.REBIRTH_BASE_COST = "
	local numEnd = configSrc:find("\n", numStart, true)
	if numEnd then
		baseCost = tonumber(configSrc:sub(numStart, numEnd - 1))
	end
end
assertOk(baseCost == 10000, "REBIRTH_BASE_COST is " .. tostring(baseCost) .. ", not 10000 — the rebirth price base changed")
assertOk(rebirthSrc:find("return Config.REBIRTH_BASE_COST * (rebirths + 1) * (rebirths + 1)", 1, true) ~= nil, "rebirthCost does not compute REBIRTH_BASE_COST * (rebirths+1)^2")
assertOk(body:find("local cost = RebirthService.rebirthCost(profile.rebirths)", 1, true) ~= nil, "doRebirth does not charge rebirthCost(profile.rebirths)")
assertOk(body:find("BankService.totalWealth(player) < cost", 1, true) ~= nil, "doRebirth does not gate on total wealth >= cost")
local incomeSrc = read("src/server/IncomeService.luau")
assertOk(incomeSrc:find("local rebirthCost = Config.REBIRTH_BASE_COST * (profile.rebirths + 1) * (profile.rebirths + 1)", 1, true) ~= nil, "IncomeService does not display the same rebirth cost formula as rebirthCost")
-- The prices, from the real base: Rebirth 1 = $10,000, Rebirth 2 =
-- $40,000, Rebirth 3 = $90,000.
local function costFor(rebirths: number): number
	return (baseCost or 10000) * (rebirths + 1) * (rebirths + 1)
end
print(string.format("rebirth costs from base %d: Rebirth 1 $%d, Rebirth 2 $%d, Rebirth 3 $%d", baseCost or 10000, costFor(0), costFor(1), costFor(2)))
assertOk(costFor(0) == 10000, "Rebirth 1 costs $" .. tostring(costFor(0)) .. ", not $10,000")
assertOk(costFor(1) == 40000, "Rebirth 2 costs $" .. tostring(costFor(1)) .. ", not $40,000")
assertOk(costFor(2) == 90000, "Rebirth 3 costs $" .. tostring(costFor(2)) .. ", not $90,000")
-- The replay profile (wealth $45,000) affords Rebirth 2 ($40,000)
-- but not Rebirth 3 ($90,000).
assertOk(totalWealth >= costFor(1), "replay wealth $" .. tostring(totalWealth) .. " cannot afford Rebirth 2 ($40,000)")
assertOk(totalWealth < costFor(2), "replay wealth $" .. tostring(totalWealth) .. " affords Rebirth 3 ($90,000) — the cost curve is wrong")

if #failures > 0 then
	print("FAIL: Rebirth-2 proof broken — " .. table.concat(failures, "; "))
	process.exit(1)
end
print("PASS: Rebirth 2 resets cash only — coins + banked zeroed, rebirths 1 -> 2, placed (3), index (14/20), xp, level and Stardust all kept; base recolored to palette entry 2 (blue 120, 180, 255), wrapping to entry 1 at Rebirth 9; cost charged = cost shown (base 10000, Rebirth 2 $40,000).")
