--!strict
-- Starfall Rotlings: tuning and world constants.
-- One place for every number the game balances on, so a balance pass
-- touches this file and nothing else. Rarities live in RarityConfig,
-- mutations in MutationConfig, shop ladders in ShopService, storm timing
-- in StarfallService and rebirth pricing in RebirthService.

local Config = {}

-- World layout (studs). The crater sits at the origin; bases ring it.
Config.BASE_COUNT = 8
Config.BASE_RADIUS = 110
Config.PADS_PER_BASE = 8 -- 6 open, 2 unlocked by the shop
Config.PADS_OPEN = 6 -- pads a fresh base starts with
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
Config.STARSTRUCK_CHANCE = 0.4 -- a free Rotling near an impact survives as Starstruck

-- Bases and stealing.
Config.LOCK_DURATION = 60 -- seconds a base lock holds
Config.LOCK_COOLDOWN = 90 -- seconds before the lock can be used again
Config.LOCK_DURATION_PER_TIER = 30 -- +30s lock per shop lock tier
Config.CARRY_HEIGHT = 3.4 -- studs above the head while carried
Config.PLACE_RANGE = 14 -- how close to a free pad the carrier must stand

-- Economy.
Config.TICK_INTERVAL = 1 -- coins are paid out once a second
Config.REBIRTH_BASE_COST = 10000
Config.REBIRTH_MULT_PER = 0.25 -- +25% income per rebirth
Config.INCOME_TIER_MULT = 0.25 -- +25% income per shop income tier
Config.SPEED_PER_TIER = 2 -- +2 WalkSpeed per shop speed tier
Config.BASE_WALKSPEED = 16

-- Rot Raiders: NPC thieves that raid bases on a timer.
Config.RAIDER_FIRST = 45 -- seconds after server start before the first raid
Config.RAIDER_INTERVAL = 75 -- seconds between raids
Config.RAIDER_LIFETIME = 90 -- seconds before a raider gives up and leaves
Config.RAIDER_WALK_SPEED = 14

-- Saving.
Config.SAVE_INTERVAL = 60 -- seconds between autosaves
Config.DATASTORE_NAME = "StarfallRotlings_PlayerData"
Config.SAVE_VERSION = 2

-- Index completion rewards.
Config.INDEX_RARITY_REWARD = 500 -- coins for completing one rarity's set
Config.INDEX_FULL_REWARD = 5000 -- coins for finding all twelve Rotlings

return Config
