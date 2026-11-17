--!strict
-- Starfall Rotlings: the rarity ladder.
-- Six tiers, each with its own glow colour, spawn weight and base
-- coins-per-second. The ladder is the game's spine: every spawn roll,
-- every label and every income number reads it.

export type Rarity = {
	name: string,
	color: Color3,
	weight: number,
	cps: number,
}

local RarityConfig = {}

RarityConfig.RARITIES = {
	{ name = "Common", color = Color3.fromRGB(200, 200, 200), weight = 45, cps = 1 },
	{ name = "Rare", color = Color3.fromRGB(80, 220, 100), weight = 28, cps = 4 },
	{ name = "Epic", color = Color3.fromRGB(180, 90, 255), weight = 15, cps = 12 },
	{ name = "Legendary", color = Color3.fromRGB(255, 200, 40), weight = 8, cps = 35 },
	{ name = "Mythic", color = Color3.fromRGB(255, 80, 140), weight = 3, cps = 100 },
	{ name = "Cosmic", color = Color3.fromRGB(60, 220, 255), weight = 1, cps = 300 },
} :: { Rarity }

RarityConfig.ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Cosmic" }

function RarityConfig.rarityByName(name: string): Rarity
	for _, rarity in ipairs(RarityConfig.RARITIES) do
		if rarity.name == name then
			return rarity
		end
	end
	return RarityConfig.RARITIES[1]
end

-- Weighted roll: Commons flood the crater, Cosmics almost never fall.
function RarityConfig.rollRarity(): string
	local total = 0
	for _, rarity in ipairs(RarityConfig.RARITIES) do
		total += rarity.weight
	end
	local roll = math.random(1, total)
	local running = 0
	for _, rarity in ipairs(RarityConfig.RARITIES) do
		running += rarity.weight
		if roll <= running then
			return rarity.name
		end
	end
	return "Common"
end

-- 1-based ladder step, for banners and the Index ("Tier 4 of 6").
function RarityConfig.rarityTier(name: string): number
	for i, rarity in ipairs(RarityConfig.RARITIES) do
		if rarity.name == name then
			return i
		end
	end
	return 1
end

return RarityConfig
