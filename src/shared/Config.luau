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
-- A Rotling sells for ~25 seconds of its own income (baseCps x 25):
-- selling is for clearing a pad to make room for a better Rotling, and
-- placing must ALWAYS be the better long-term choice (25s of income
-- beats the sale price, then it keeps earning forever). The auto-check
-- (al) proves SELL_MULT stays at or under 30.
Config.SELL_MULT = 25

-- Meteor storm: a full cycle is calm + warning + storm.
Config.STORM_PERIOD = 90
Config.STORM_WARN = 10 -- warning seconds before the meteors fall
Config.STORM_DURATION = 8
Config.STORM_METEOR_INTERVAL = 0.45
Config.STORM_DAMAGE = 15 -- health lost per meteor hit while in the crater
Config.STARSTRUCK_CHANCE = 0.4 -- a free Rotling near an impact survives as Starstruck
-- Storm spread (item 6): impacts cover the WHOLE map, not just the
-- crater centre. Meteors pick a zone — near a player anywhere, near a
-- base, or anywhere in the open field — and every impact is telegraphed
-- by a red warning circle on the ground STORM_WARNING_TIME seconds
-- before it lands. Bases are safe zones: a meteor never targets a base
-- platform and never hurts a player standing on one. A hit within
-- STORM_HIT_RADIUS knocks the player back and drops what they carry.
Config.STORM_SPREAD_RADIUS = 150 -- impacts anywhere inside this radius of the origin
Config.STORM_WARNING_TIME = 2 -- seconds the warning circle shows before impact
Config.STORM_BASE_SAFE_RADIUS = 17 -- no impact target this close to a base centre
Config.STORM_HIT_RADIUS = 6 -- a player this close to an impact is knocked back
Config.STORM_KNOCKBACK = 42 -- studs/sec of knockback velocity on a hit
Config.STORM_HAZARD_LABEL = "DANGER: CRATER-WIDE METEOR RAIN" -- hazard label on the storm banner
-- Storm front wall (step 2): a giant glowing meteor front that sweeps
-- across the whole map during the storm — the threat you can see coming
-- from far away. It is pure spectacle: the knockback and dropped
-- Rotlings still come from the falling meteors, never from the wall.
Config.STORM_FRONT_HEIGHT = 40 -- studs tall: visible over the whole map
Config.STORM_FRONT_LENGTH = 340 -- studs long: spans the map's width
Config.STORM_FRONT_RANGE = 170 -- sweeps from x=-170 to x=+170
-- Storm extras: meteors that land near a player, and rare Rotlings at
-- impact points. Half the storm's meteors aim near a random player so
-- 6-10 crash close enough to shake the camera; hero meteors always
-- leave a rare Rotling at the impact point for 30 seconds.
Config.STORM_NEAR_PLAYER_CHANCE = 0.5 -- half the rain meteors aim near a player
Config.STORM_NEAR_PLAYER_RADIUS = 15 -- studs around the player a near meteor may land
Config.STORM_RARE_LIFETIME = 30 -- seconds a storm-spawned rare Rotling stays grabbable

-- Sprint: hold Shift (or the mobile Run button) to run. Base walk
-- speed is 16; sprinting is 26. Stamina drains while sprinting and
-- refills when you stop, and the camera's field of view kicks out
-- while you run so the speed reads.
Config.SPRINT_BASE_SPEED = 16
Config.SPRINT_SPEED = 26
Config.SPRINT_STAMINA_MAX = 100
Config.SPRINT_STAMINA_DRAIN = 25 -- per second while sprinting
Config.SPRINT_STAMINA_REGEN = 15 -- per second while not sprinting
Config.SPRINT_STAMINA_MIN = 20 -- stamina must be above this to start sprinting again
Config.SPRINT_FOV = 82 -- field of view while sprinting (base is 70)
Config.SPRINT_FOV_BASE = 70

-- Bases and stealing.
Config.LOCK_DURATION = 60 -- seconds a base lock holds
Config.LOCK_COOLDOWN = 90 -- seconds before the lock can be used again
Config.LOCK_DURATION_PER_TIER = 30 -- +30s lock per shop lock tier
-- Carrying: the Rotling rides IN FRONT OF THE CHEST at arm height,
-- never above the head and never over the face. Forward is -Z off the
-- HumanoidRootPart, so a negative Z puts it in front of the player.
-- CARRY_Z is -3.2, not -2.2: at -2.2 the Rotling sat just past the
-- chest and the player's own torso hid it from the camera behind them
-- (Malek: "HUD says Carrying 1/1 but nothing is visible"). At -3.2 it
-- reads clearly in front of the body, and the bigger carried size
-- (CARRY_MAX_HEIGHT 3.6) keeps the face and colours readable.
Config.CARRY_Y = 0.0 -- studs below the root centre: chest/arm height
Config.CARRY_Z = -3.2 -- studs in front of the chest: clear of the torso, visible from behind
-- Carried size: the real model at a readable scale, never a tiny box.
Config.CARRY_MAX_HEIGHT = 3.6 -- a carried Rotling is at most 3.6 studs tall
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

-- Rival bots (item 7): 3-4 named rivals that own the other bases,
-- run to the crater, grab Rotlings, carry them home and earn. They show
-- on the leaderboard and compete for the storm bounty.
Config.RIVAL_COUNT = 4
Config.RIVAL_NAMES = { "Ziggy", "Nova", "Pip", "Comet" }
Config.RIVAL_WALK_SPEED = 13
Config.RIVAL_GRAB_RADIUS = 12 -- a rival grabs the nearest free Rotling this close
Config.RIVAL_STEAL_CHANCE = 0.35 -- per rival trip, chance it targets a player's base instead
Config.RIVAL_CHASE_RADIUS = 30 -- a rival chases an egg carrier this close
Config.RIVAL_SLAP_COOLDOWN = 3 -- seconds between a rival's slap-backs

-- Slap bat (item 10): swing knocks a rival or player back and drops
-- what they carry. Cooldown 2s, fun sound + stars effect.
Config.SLAP_COOLDOWN = 2
Config.SLAP_RANGE = 9 -- studs in front of the swinger
Config.SLAP_KNOCKBACK = 38

-- Meteor eggs (item 12): 1-2 glowing eggs crash somewhere on the map
-- during each storm. Heavy to carry (walk slower); rivals chase you
-- for one. Bring it to the incubator on your base: it hatches after
-- 60s into a random Rotling, with a chance of Epic, Legendary or a
-- mutation. Eggs also pay Stardust on hatch.
Config.EGGS_PER_STORM = 2
Config.EGG_HATCH_TIME = 60 -- seconds on the incubator before hatching
Config.EGG_SLOW = 6 -- WalkSpeed lost while carrying an egg
Config.EGG_STARDUST = 25 -- Stardust paid when an egg hatches
Config.EGG_SCORCHED_CHANCE = 0.15 -- hatch comes out Meteor-scorched

-- Boosts (item 11): pickups around the map and in the Star Shop.
Config.BOOST_SPEED_MULT = 1.4 -- Speed Coil: +40% speed
Config.BOOST_SPEED_DURATION = 30
Config.BOOST_MAGNET_RADIUS = 15 -- Magnet: auto-grab nearest Rotling this close
Config.BOOST_MAGNET_DURATION = 30
Config.BOOST_CASH_MULT = 2 -- 2x Cash: double income
Config.BOOST_CASH_DURATION = 60
Config.BOOST_SHIELD_DURATION = 20 -- Shield: immune to slaps and meteors
Config.BOOST_SPAWN_INTERVAL = 25 -- seconds between boost pickup spawns
Config.BOOST_MAX_ON_MAP = 6

-- Global events (cheap win 7): one every 60-90s between storms.
Config.EVENT_INTERVAL_MIN = 60
Config.EVENT_INTERVAL_MAX = 90
Config.EVENT_CASH_DURATION = 60 -- "2x Cash Hour" lasts 60s
Config.EVENT_SHOWER_COUNT = 12 -- Stardust Shower drops this many gems
Config.EVENT_SHOWER_STARDUST = 5 -- Stardust per gem collected

-- Stardust (item 13): second currency, earned from meteor eggs and
-- daily rewards, spent on mutations and boosts. Shown in the HUD next
-- to cash.
Config.DAILY_STARDUST = 50 -- Stardust in the daily reward
Config.REROLL_STARDUST_COST = 30 -- mutation reroll of your best placed Rotling
Config.BOOST_STARDUST_COST = 20 -- one boost from the Star Shop

-- Player level and XP (item 13): XP from grabbing (+10) and placing
-- (+15). One level per 100 XP.
Config.XP_GRAB = 10
Config.XP_PLACE = 15
Config.XP_PER_LEVEL = 100

-- Buddy Rotling: your highest-income placed Rotling (or the one you
-- pick in the Index), shrunk to half size, floating beside you with a
-- small tag. +5% cash while it follows you.
Config.BUDDY_SCALE = 0.5
Config.BUDDY_CASH_BONUS = 0.05
Config.BUDDY_OFFSET = Vector3.new(2.6, 0.6, 0.4) -- beside you, never in front of the camera

-- Storm bounty (item 7d): top earner during a storm wins a bonus.
Config.BOUNTY_BONUS = 500 -- coins to the storm's top earner

-- Saving.
Config.SAVE_INTERVAL = 60 -- seconds between autosaves
Config.DATASTORE_NAME = "StarfallRotlings_PlayerData"
Config.SAVE_VERSION = 4 -- v4 adds stardust / xp / level / buddyDefId

-- Index completion rewards.
Config.INDEX_RARITY_REWARD = 500 -- coins for completing one rarity's set
Config.INDEX_FULL_REWARD = 5000 -- coins for finding all twenty Rotlings

return Config
