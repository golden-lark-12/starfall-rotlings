-- Starfall Rotlings: tuning and world constants.
-- One place for every number the game balances on, so a balance pass
-- touches this file and nothing else.

local Config = {}

-- World layout (studs). The crater sits at the origin; bases ring it.
Config.BASE_COUNT = 8
Config.BASE_RADIUS = 110
Config.PADS_PER_BASE = 6
Config.CRATER_RADIUS = 28
Config.GROUND_SIZE = 480

-- Spawning.
Config.SPAWN_INTERVAL = 4 -- seconds between spawn attempts
Config.CRATER_MAX_FREE = 10 -- free Rotlings at once in the crater

-- Meteor storm: a full cycle is calm + warning + storm.
Config.STORM_PERIOD = 90
Config.STORM_WARN = 10 -- warning seconds before the meteors fall
Config.STORM_DURATION = 8
Config.STORM_METEOR_INTERVAL = 0.45
Config.STORM_DAMAGE = 15 -- health lost per meteor hit while in the crater

-- Bases and stealing.
Config.LOCK_DURATION = 60 -- seconds a base lock holds
Config.LOCK_COOLDOWN = 90 -- seconds before the lock can be used again
Config.CARRY_HEIGHT = 3.4 -- studs above the head while carried
Config.PLACE_RANGE = 14 -- how close to a free pad the carrier must stand

-- Economy.
Config.TICK_INTERVAL = 1 -- coins are paid out once a second
Config.REBIRTH_BASE_COST = 10000
Config.REBIRTH_MULT_PER = 0.25 -- +25% income per rebirth
Config.INCOME_TIER_MULT = 0.25 -- +25% income per shop income tier
Config.SPEED_PER_TIER = 2 -- +2 WalkSpeed per shop speed tier
Config.BASE_WALKSPEED = 16

-- Shop: each entry is a ladder of {cost, ...} tiers.
Config.SHOP = {
	Speed = {
		label = "Speed Boots",
		desc = "+2 WalkSpeed per tier",
		tiers = { 250, 1000, 5000 },
	},
	Carry = {
		label = "Extra Arms",
		desc = "+1 Rotling carried per tier",
		tiers = { 500, 3000 },
	},
	Income = {
		label = "Golden Trough",
		desc = "+25% base income per tier",
		tiers = { 750, 2500, 10000 },
	},
}

-- Saving.
Config.SAVE_INTERVAL = 60 -- seconds between autosaves
Config.DATASTORE_NAME = "StarfallRotlings_PlayerData"
Config.SAVE_VERSION = 1

-- Rarities, in ladder order. Weight is the spawn roll; cps is the base
-- coins-per-second a Rotling of this rarity earns on a pad.
Config.RARITIES = {
	{ name = "Common", color = Color3.fromRGB(200, 200, 200), weight = 45, cps = 1 },
	{ name = "Rare", color = Color3.fromRGB(80, 220, 100), weight = 28, cps = 4 },
	{ name = "Epic", color = Color3.fromRGB(180, 90, 255), weight = 15, cps = 12 },
	{ name = "Legendary", color = Color3.fromRGB(255, 200, 40), weight = 8, cps = 35 },
	{ name = "Mythic", color = Color3.fromRGB(255, 80, 140), weight = 3, cps = 100 },
	{ name = "Cosmic", color = Color3.fromRGB(60, 220, 255), weight = 1, cps = 300 },
}

-- Mutations rolled at spawn. Chance is per spawn; mult multiplies income.
Config.MUTATIONS = {
	{ name = "Gold", mult = 2, chance = 0.08, color = Color3.fromRGB(255, 215, 0) },
	{ name = "Frozen", mult = 3, chance = 0.05, color = Color3.fromRGB(150, 220, 255) },
	{ name = "Rainbow", mult = 5, chance = 0.02, color = Color3.fromRGB(255, 120, 220) },
}

function Config.rarityByName(name: string)
	for _, rarity in ipairs(Config.RARITIES) do
		if rarity.name == name then
			return rarity
		end
	end
	return Config.RARITIES[1]
end

function Config.rollRarity(): string
	local total = 0
	for _, rarity in ipairs(Config.RARITIES) do
		total += rarity.weight
	end
	local roll = math.random(1, total)
	local running = 0
	for _, rarity in ipairs(Config.RARITIES) do
		running += rarity.weight
		if roll <= running then
			return rarity.name
		end
	end
	return "Common"
end

function Config.rollMutation(): string?
	local roll = math.random()
	local running = 0
	for _, mutation in ipairs(Config.MUTATIONS) do
		running += mutation.chance
		if roll <= running then
			return mutation.name
		end
	end
	return nil
end

function Config.mutationByName(name: string?)
	if name == nil then
		return nil
	end
	for _, mutation in ipairs(Config.MUTATIONS) do
		if mutation.name == name then
			return mutation
		end
	end
	return nil
end

function Config.rebirthCost(rebirths: number): number
	return Config.REBIRTH_BASE_COST * (rebirths + 1) * (rebirths + 1)
end

return Config
