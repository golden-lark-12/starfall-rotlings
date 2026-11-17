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
Config.CRATER_FLOOR_Y = 0.4 -- top of the crater disc: Rotlings spawn and meteors land here
Config.GROUND_SIZE = 480

-- Spawning.
Config.SPAWN_INTERVAL = 4 -- seconds between spawn attempts
Config.CRATER_MAX_FREE = 10 -- free Rotlings at once in the crater
Config.CRATER_MIN_FREE = 6 -- the conveyor never drops below this: top up fast
Config.CRATER_INITIAL = 8 -- Rotlings waiting when the first player arrives

-- Missions: a short rotating list, one at a time. Progress is counted
-- on the server (grabs, places, coins earned); finishing one pays the
-- reward and moves to the next.
Config.MISSIONS = {
	{ id = "grab", text = "Grab 3 Rotlings", target = 3, reward = 300 },
	{ id = "place", text = "Place 3 Rotlings on your base", target = 3, reward = 500 },
	{ id = "earn", text = "Earn $5,000 coins", target = 5000, reward = 750 },
}

-- Daily reward: claimable once per cooldown from the HUD Daily button.
Config.DAILY_REWARD = 1000
Config.DAILY_COOLDOWN = 20 * 3600 -- 20 hours between claims

-- Selling: carry a Rotling to the gold SELL pad by spawn and press E.
-- A Rotling sells for one minute of its own income (baseCps x 60).
Config.SELL_MULT = 60

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
-- Carrying: the Rotling rides IN FRONT OF THE CHEST at arm height,
-- never above the head and never over the face. Forward is -Z off the
-- HumanoidRootPart, so a negative Z puts it in front of the player.
Config.CARRY_Y = -0.3 -- studs below the root centre: chest/arm height
Config.CARRY_Z = -2.2 -- studs in front of the chest
-- Carried size: the real model at a readable scale, never a tiny box.
Config.CARRY_MAX_HEIGHT = 3.0 -- a carried Rotling is at most 3 studs tall
Config.PLACE_RANGE = 14 -- how close to a free pad the carrier must stand

-- Name tags: only the nearest few, only up close, so they never stack
-- into unreadable text when Rotlings stand close together.
Config.TAG_MAX_DISTANCE = 25 -- a tag only shows within 25 studs
Config.TAG_MAX_SHOWN = 3 -- at most the 3 nearest tags at once
Config.TAG_PHOTO_MAX_DISTANCE = 40 -- in photo mode, show every tag within 40 studs
Config.TAG_PHOTO_MAX_SHOWN = 99 -- in photo mode, show all of them (the shots need every label)
Config.CRATER_MIN_SPACING = 6 -- crater Rotlings at least 6 studs apart

-- Conveyor belt: a flat dark strip across the crater diameter (along X,
-- the spawn-to-crater axis). Rotlings spawn ON it in a line, so the
-- crater reads as a conveyor delivering creatures, not a random scatter.
Config.BELT_HALF_WIDTH = 3 -- the belt is 6 studs wide (z in [-3, 3])
Config.BELT_SPAWN_Z = 2 -- spawn z stays within [-2, 2] so every Rotling stands on the belt

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
Config.SAVE_VERSION = 3 -- v3 adds missionIndex/missionProgress/lastDailyClaim

-- Index completion rewards.
Config.INDEX_RARITY_REWARD = 500 -- coins for completing one rarity's set
Config.INDEX_FULL_REWARD = 5000 -- coins for finding all twelve Rotlings

return Config
