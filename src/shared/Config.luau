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
Config.SPAWN_INTERVAL = 17 -- seconds between spawn attempts (competition via scarcity: a new Brainrot walks in every 15-20s)
Config.CRATER_MAX_FREE = 5 -- free Brainrots at once in the crater (competition via scarcity: 3-5 at a time)

-- Contracts: the Contract Board's pool. Three are active at a time,
-- dealt in pool order; claiming one deals the next pool contract not
-- already active. Progress is counted on the server (grabs, places,
-- coins earned, Rare+ grabs); finishing one marks it ready, and the
-- player CLAIMS the reward at the board — never auto-paid, so the
-- board is the loop. Kinds must match MissionService.addProgress
-- call sites: "grab" (CarryService.tryGrab), "place"
-- (CarryService.placeOnPad), "earn" (IncomeService tick), "rare"
-- (CarryService.tryGrab, Rare tier or better).
Config.CONTRACTS = {
	{ id = "grab3", kind = "grab", text = "Grab 3 Brainrots", target = 3, reward = 300 },
	{ id = "place3", kind = "place", text = "Place 3 Brainrots on your base", target = 3, reward = 500 },
	{ id = "earn5k", kind = "earn", text = "Earn $5,000 coins", target = 5000, reward = 750 },
	{ id = "grab5", kind = "grab", text = "Grab 5 Brainrots", target = 5, reward = 500 },
	{ id = "place5", kind = "place", text = "Place 5 Brainrots on your base", target = 5, reward = 800 },
	{ id = "earn15k", kind = "earn", text = "Earn $15,000 coins", target = 15000, reward = 1500 },
	{ id = "rare1", kind = "rare", text = "Grab a Rare (or better) Brainrot", target = 1, reward = 600 },
	{ id = "rare3", kind = "rare", text = "Grab 3 Rare (or better) Brainrots", target = 3, reward = 1200 },
}
Config.CONTRACTS_AT_ONCE = 3 -- contracts active on the board at a time

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
Config.STORM_DAMAGE = 100 -- LETHAL: a hit outside the dome knocks the player out (100 HP), drops what they carry, and they respawn at their base. The old 15 never killed anyone, so the storm never knocked anyone out.
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
Config.STORM_HIT_RADIUS = 10 -- a player this close to an impact is knocked out (was 6: with a 15-stud near box only ~4% of near meteors ever hit, so the storm rarely did anything)
Config.STORM_KNOCKBACK = 42 -- studs/sec of knockback velocity on a hit
Config.STORM_HAZARD_LABEL = "DANGER: CRATER-WIDE FIREBALL RAIN" -- hazard label on the storm banner
-- Storm front wall (step 2): a giant glowing meteor front that sweeps
-- across the whole map during the storm — the threat you can see coming
-- from far away. It is pure spectacle: the knockback and dropped
-- Rotlings still come from the falling meteors, never from the wall.
Config.STORM_FRONT_HEIGHT = 40 -- studs tall: visible over the whole map
Config.STORM_FRONT_LENGTH = 340 -- studs long: spans the map's width
Config.STORM_FRONT_RANGE = 170 -- sweeps from x=-170 to x=+170
-- Safe Dome storm boost: a player standing on their OWN base platform
-- while the storm front passes earns double income — the dome is a
-- shelter that pays. The HUD shows the boosted rate with (x2) next to
-- the normal rate, so the threat shot proves the event with a doubled
-- income number.
Config.STORM_DOME_MULT = 2 -- income multiplier inside your own Safe Dome during the storm
-- Storm extras: meteors that land near a player, and rare Rotlings at
-- impact points. Half the storm's meteors aim near a random player so
-- 6-10 crash close enough to shake the camera; hero meteors always
-- leave a rare Rotling at the impact point for 30 seconds.
Config.STORM_NEAR_PLAYER_CHANCE = 0.5 -- half the rain meteors aim near a player
Config.STORM_NEAR_PLAYER_RADIUS = 8 -- studs around the player a near meteor may land (was 15: with a 10-stud hit radius a near meteor now lands close enough to matter — the 2s warning circle is the dodge window, not a random punishment)
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
Config.STAMINA_PER_TIER = 50 -- Endurance Training (fix round 8, item 6): +50 max stamina per tier
Config.EGG_WARMER_REDUCTION = 0.25 -- Egg Warmer (fix round 8, item 6): -25% hatch time per tier
Config.SLAP_RANGE_PER_TIER = 1.5 -- Power Slap (fix round 8, item 6): +1.5 slap range per tier
Config.SLAP_KNOCKBACK_PER_TIER = 20 -- Power Slap (fix round 8, item 6): +20 slap knockback per tier
Config.SPRINT_FOV = 82 -- field of view while sprinting (base is 70)
Config.SPRINT_FOV_BASE = 70

-- Bases and stealing.
Config.LOCK_DURATION = 120 -- seconds a base lock holds (fix round 6, item 3: Malek — "add more time for the lockups"; was 60, too short to stop a thief)
Config.LOCK_COOLDOWN = 90 -- seconds before the lock can be used again
Config.LOCK_DURATION_PER_TIER = 30 -- +30s lock per shop lock tier

-- Emergency LOCKDOWN (fix round 13, item 4 — Malek, playtest 12):
-- a second, shorter seal on top of the regular lock. 30s sealed,
-- 60s cooldown, FIXED (no shop tiers — it is an emergency button,
-- not an upgrade). Distinct from the L lock: its own key (K), its
-- own button, its own opaque red gate. Works on top of the regular
-- lock: sealing while locked keeps the lock underneath, and the
-- lockdown ending never opens a lock that is still running.
Config.LOCKDOWN_DURATION = 30 -- seconds a lockdown seals a base
Config.LOCKDOWN_COOLDOWN = 60 -- seconds before the lockdown can be used again
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
-- Placed size: every Brainrot on a pedestal is ONE uniform height, so
-- the base reads as a tidy display case instead of a staircase — the
-- biggest placed Brainrot was 2.3x the smallest (Count Croissant 5.0
-- vs Bloop 2.2) and the tall ones towered over the player. The
-- per-type sizes live on only in the crater (1.5x spawns) and while
-- carried (CARRY_MAX_HEIGHT). 4.5 studs (fix round 8, item 4): Malek
-- said 3.5 read too small on the pedestal — the Brainrots are the
-- collection on display, so they stand tall, just under the
-- player's eye line (walk 16, eye ~5 studs up).
Config.PLACED_DISPLAY_HEIGHT = 4.5 -- BODY height of a placed Brainrot (the animal itself, not the hat — fix round 9, item 5)
Config.PLACED_MAX_WIDTH = 6.0 -- widest a placed body may be (a pad plinth is 6 wide; wider would overlap the neighbour's pad)
Config.PLACE_RANGE = 14 -- how close to a free pad the carrier must stand

-- Name tags: only the nearest few, only up close, so they never stack
-- into unreadable text when Rotlings stand close together.
Config.TAG_MAX_DISTANCE = 25 -- a tag only shows within 25 studs
Config.TAG_MIN_DISTANCE = 6 -- a tag hides closer than 6 studs: a 200x84 AlwaysOnTop tag right in front of the camera fills the screen and overlaps the base sign and the thief banner (Playtest 5's "Mister Muffin Feet"). Step back and it reads again.
Config.TAG_PLACED_MIN_DISTANCE = 12 -- a PLACED tag hides closer than 12 studs (fix round 9, item 10): a placed tag overlaps the base sign when the player stands on their own base (playtest 10's "Bloop the Blob" over the base sign) — placed Rotlings are read from further away than free ones.
Config.TAG_MAX_SHOWN = 3 -- at most the 3 nearest tags at once
Config.TAG_PHOTO_MAX_DISTANCE = 40 -- in photo mode, show every tag within 40 studs
Config.TAG_PHOTO_MAX_SHOWN = 99 -- in photo mode, show all of them (the shots need every label)
Config.CRATER_MIN_SPACING = 6 -- crater Rotlings at least 6 studs apart

-- Conveyor belt: a flat dark strip across the crater diameter (along X,
-- the spawn-to-crater axis). Rotlings spawn ON it in a line, so the
-- crater reads as a conveyor delivering creatures, not a random scatter.
Config.BELT_HALF_WIDTH = 3 -- the belt is 6 studs wide (z in [-3, 3])
Config.BELT_SPAWN_Z = 2 -- spawn z stays within [-2, 2] so every Rotling stands on the belt
Config.BELT_HALF_LENGTH = 20 -- the belt is 40 studs long (x in [-20, 20]); free Rotlings spawn and travel on it
Config.BELT_TRAVEL_SPEED = 1.5 -- studs/sec a free Rotling walks along the belt (fix round 3, item 8): slow enough to grab, fast enough to see it travel; ~27s end to end, then it wraps to the start
-- Belt walking surface (fix round 4, items 1 + 7): the belt's top face.
-- WorldBuilder.buildBelt builds a RAISED conveyor: a 0.6-thick slab
-- centred at Y=0.9, so its top is 1.2 — half a stud above the crater
-- floor (0.7), with glowing edge stripes, direction arrows and end
-- rollers. Rotlings spawn and rest with their body bottom ON this
-- surface — never on CRATER_FLOOR_Y (0.4), which sits 0.8 below the
-- belt and sank every Rotling halfway into the ground.
Config.BELT_TOP_Y = 1.2

-- Economy.
Config.TICK_INTERVAL = 1 -- coins are paid out once a second
Config.REBIRTH_BASE_COST = 10000
Config.REBIRTH_MULT_PER = 0.25 -- +25% income per rebirth
Config.INCOME_TIER_MULT = 0.25 -- +25% income per shop income tier
Config.SPEED_PER_TIER = 2 -- +2 WalkSpeed per shop speed tier
Config.BASE_WALKSPEED = 16

-- Rot Raiders: NPC thieves that raid bases on a timer.
Config.RAIDER_FIRST = 15 -- seconds after server start before the first raid (was 45: too slow to notice in a short playtest)
Config.RAIDER_INTERVAL = 75 -- seconds between raids (competition via scarcity: raider/thief bots every 60-90s; was 45 — the 45s cadence was set when thieves were broken and silent, now they work)
Config.RAIDER_LIFETIME = 90 -- seconds before a raider gives up and leaves
Config.RAIDER_WALK_SPEED = 14

-- Crater Guardian (THE CHASE): a space rock monster that chases
-- anyone who grabs a Brainrot from the crater. Speed by the grabbed
-- Brainrot's rarity tier. THE NUMBERS HAVE TO BEAT THE PLAYER, CLEARLY:
-- a walking player moves 16 studs/s, sprinting is 26. The guardian is
-- CAT-FAST at EVERY tier (Common 28 up to Cosmic 34 — fix round 9,
-- item 1): it gains 12 studs/s on a walker and still gains on a
-- sprinter, so the only escapes are the base (or the 25s timeout) and
-- Speed Boots at full tilt (walk 26, sprint 36). The old speeds
-- (Common 19, Cosmic 24) were only just above a walk — and the chase
-- steered on a pathfinder route through the crater's entrance gap,
-- so the guardian's real speed along that detour was BELOW a walk:
-- Malek proved it in playtests 9 and 10, three rounds in a row.
-- The chase now steers DIRECTLY at the target (no pathfinding detour)
-- and jumps the rim tiers when stuck, with a lunge inside 14 studs.
-- It spawns 14 studs from the grabber (close enough to be a threat
-- the moment it wakes, far enough that it is not an instant catch —
-- the old 24-stud head start plus the slow speed meant it never
-- arrived at all). If a future tweak ever drops a tier back under 26,
-- the guardian is decorative again — the auto-check (df) proves every
-- tier beats the sprint speed.
Config.GUARDIAN_SPEED = { [1] = 28, [2] = 29, [3] = 30, [4] = 31, [5] = 32, [6] = 34, [7] = 36 } -- per rarity tier (fix round 9, item 1: CAT-FAST — every tier beats sprint 26; the escape is the base, the 25s timeout, or full Speed Boots; Divine 36 is the fastest chase, still tied by full Speed Boots at 36)
Config.GUARDIAN_LUNGE_BONUS = 12 -- studs/s burst while lunging (fix round 9, item 1)
Config.GUARDIAN_LUNGE_RANGE = 14 -- studs: this close, the guardian lunges
Config.GUARDIAN_LUNGE_COOLDOWN = 4 -- seconds between lunges
Config.GUARDIAN_SPAWN_DISTANCE = 14 -- studs from the grabber, on the opposite rim
Config.GUARDIAN_CATCH_RADIUS = 5 -- studs: this close and it catches you
Config.GUARDIAN_CATCH_DAMAGE = 40 -- HP lost when it catches you (fix round 8, item 2: the catch used to only drop the Brainrot — Malek: "all it does is him getting dropped the brainrot". 40 HP + a knockdown means two catches kill you, so a catch is a real threat, not a free reset)
Config.GUARDIAN_GIVEUP_TIME = 25 -- seconds: a chase that drags on ends on its own

-- Rival bots (item 7): 3-4 named rivals that own the other bases,
-- run to the crater, grab Rotlings, carry them home and earn. They show
-- on the leaderboard and compete for the storm bounty.
Config.RIVAL_COUNT = 4
Config.RIVAL_NAMES = { "Ziggy", "Nova", "Pip", "Comet" }
Config.RIVAL_WALK_SPEED = 16 -- rival walk speed (fix round 7, item 2: 13 -> 16 — thieves must move visibly, not dawdle)
Config.RIVAL_GRAB_RADIUS = 12 -- a rival grabs the nearest free Rotling this close
Config.RIVAL_STEAL_CHANCE = 0.5 -- per rival trip, chance it targets a player's base instead (fix round 7, item 2: 0.35 -> 0.5 — with a 60-90s cycle, 0.35 meant about one steal attempt per rival every 2-3 minutes; the 75s steal clock now guarantees a beat on top of the roll)
Config.RIVAL_CHASE_MAX = 2 -- max rivals chasing one carrier at once (fix round 8, item 8: one chaser reads as "nobody", four read as a swarm — two is "others")
Config.RIVAL_CHASE_SPEED = 19 -- a chasing rival runs at 19 (fix round 8, item 8: walk is 16, so a chaser GAINS on a walking carrier; sprint 26 still escapes). The old RIVAL_CHASE_RADIUS = 30 is GONE: a rival only chased a carrier within 30 studs, but rivals sit at their bases at radius 110 — so a grab in the crater almost never had a rival in range and Malek was never chased. Assignment is now by NEAREST rival, any distance (notifyCarrier).
Config.RIVAL_HUNT_SPEED = 22 -- a HUNTING thief runs at 22 (follow-up, item 2): faster than a walking player (16) and the carrier chase (19), slower than the guardian (28-34) — threatening, escapable, distinct from both. The guardian smashes you; the thief mugs you.
Config.RIVAL_HUNT_RADIUS = 30 -- a rival this close to a free-walking player starts hunting them (follow-up, item 2)
Config.RIVAL_HUNT_GIVEUP_DIST = 60 -- the hunt ends if the player gets this far away
Config.RIVAL_HUNT_TIMEOUT = 20 -- seconds a hunt lasts at most
Config.RIVAL_HUNT_COOLDOWN = 10 -- seconds after a hunt ends (knockdown tag) before the same rival hunts again
Config.RIVAL_SLAP_COOLDOWN = 3 -- seconds between a rival's slap-backs

-- Slap bat (item 10): swing knocks a rival or player back and drops
-- what they carry. Cooldown 2s, fun sound + stars effect.
Config.SLAP_COOLDOWN = 2
Config.SLAP_RANGE = 9 -- studs in front of the swinger
Config.SLAP_KNOCKBACK = 38

-- Meteor eggs (item 12, rebalanced fix round 10): 4 glowing eggs crash
-- somewhere on the open field during each storm. Heavy to carry (walk
-- slower); rivals chase you for one. Bring it to the incubator on your
-- base: it hatches after a rarity-scaled wait into a random Rotling,
-- with a chance of Epic, Legendary or a mutation. Eggs also pay
-- Stardust on hatch.
Config.EGGS_PER_STORM = 4
-- Egg-only rarity weights (fix round 10, item 2): steeper than the belt
-- weights in RarityConfig — Commons flood, a Legendary egg is a real
-- event (4% per egg, ~0.16 per storm at 4/storm, one per ~6 storms).
-- The old 40% bump that flattened the distribution is gone; the
-- guaranteed legendary drop (every 240s, crater) is the Epic/Legendary
-- safety net. Indexed by rarity tier 1-6.
Config.EGG_RARITY_WEIGHTS = { [1] = 550, [2] = 280, [3] = 100, [4] = 40, [5] = 20, [6] = 10, [7] = 5 } -- egg-only rarity weights x10 (fix round 11: the round-10 weights 55/28/10/4/2/1 rescaled so Divine fits below Cosmic as an integer weight — Divine 5 < Cosmic 10, 0.5% per egg; same proportions otherwise)
Config.LEGENDARY_EGG_INTERVAL = 240 -- seconds between legendary egg drops (fix round 9, item 11)
Config.LEGENDARY_EGG_LIFETIME = 75 -- seconds a legendary egg stays grabbable before it vanishes
Config.EGG_HATCH_TIME = { [1] = 60, [2] = 90, [3] = 120, [4] = 180, [5] = 240, [6] = 300, [7] = 360 } -- seconds on the incubator before hatching, by rarity tier (fix round 6, item 6: rarer eggs take longer — Common 60s, Rare 90s, Epic 120s, Legendary 180s, Mythic 240s, Cosmic 300s, Divine 360s)
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
-- pick in the Index), shrunk to about a quarter size at knee height,
-- floating beside and slightly behind you with a small tag. +5% cash
-- while it follows you. (Fix round 4, item 6: at half size the buddy
-- blocked the whole view — 0.5 on a 1.5x crater model is still huge.
-- 0.28 is knee height; the offset sits it low, beside, and behind.)
Config.BUDDY_SCALE = 0.28
Config.BUDDY_CASH_BONUS = 0.05
Config.BUDDY_OFFSET = Vector3.new(2.2, -0.8, 1.4) -- low, beside you, behind you — never in front of the camera

-- Storm bounty (item 7d): top earner during a storm wins a bonus.
Config.BOUNTY_BONUS = 500 -- coins to the storm's top earner

-- Saving.
Config.SAVE_INTERVAL = 60 -- seconds between autosaves
Config.DATASTORE_NAME = "StarfallRotlings_PlayerData"
Config.SAVE_VERSION = 4 -- v4 adds stardust / xp / level / buddyDefId
-- Offline earnings (step 4): Rotlings keep earning while the player is
-- away, capped at this many hours so a long absence never pays a
-- fortune. The popup shows the amount on join.
Config.OFFLINE_CAP_SECONDS = 8 * 3600 -- 8 hours of away time, max

-- Index completion rewards.
Config.INDEX_RARITY_REWARD = 500 -- coins for completing one rarity's set
Config.INDEX_FULL_REWARD = 5000 -- coins for finding all twenty Rotlings

return Config
