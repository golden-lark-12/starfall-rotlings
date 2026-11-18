--!strict
-- Starfall Rotlings: shared server state.
-- Plain tables every server module reads and writes, so no two modules
-- have to require each other in a circle. Only the server writes here;
-- the client never sees this module.

export type PlacedEntry = {
	def: string,
	mut: string?,
	pad: number,
}

export type Profile = {
	version: number,
	coins: number, -- wallet: spendable cash (shop, rebirths, rerolls)
	banked: number, -- coins earned at the base, not yet collected into the wallet
	stardust: number, -- second currency: eggs + daily rewards; spent on mutations and boosts
	xp: number, -- player XP: +10 per grab, +15 per place
	level: number, -- 1 + floor(xp / XP_PER_LEVEL)
	buddyDefId: string?, -- the Rotling picked as Buddy in the Index (nil = best placed)
	rebirths: number,
	speedTier: number,
	carryTier: number,
	incomeTier: number,
	padsTier: number,
	lockTier: number,
	staminaTier: number, -- Endurance Training (fix round 8, item 6): +50 max stamina per tier
	eggTier: number, -- Egg Warmer (fix round 8, item 6): -25% hatch time per tier
	slapTier: number, -- Power Slap (fix round 8, item 6): +1.5 range / +20 knockback per tier
	index: { [string]: boolean },
	indexRewards: { [string]: boolean },
	indexFullRewarded: boolean,
	-- Mutations this player has collected (by name): shown in the
	-- Index as a "Mutations found" row. Filled by
	-- IndexService.markMutationFound on grab/place.
	mutations: { [string]: boolean },
	placed: { PlacedEntry },
	-- Contracts (the Contract Board): three active at a time, each
	-- { id, progress, done, claimed }. Replaces the old single
	-- rotating mission (missionIndex / missionProgress below are
	-- legacy fields, kept in the save shape but no longer read).
	contracts: { { id: string, progress: number, done: boolean, claimed: boolean } },
	missionIndex: number, -- LEGACY: which Config.MISSIONS entry was active (1-based). Contracts replaced the single-mission rotation; nothing reads this now.
	missionProgress: number, -- LEGACY: progress toward the old active mission. Contracts carry their own progress now.
	lastDailyClaim: number, -- os.time() of the last daily reward claim (0 = never)
	lastSeen: number, -- os.time() of the last save (0 = never; drives offline earnings)
}

export type Raider = {
	model: Model,
	name: string, -- our own bandit title, e.g. "Grimble the Grabber"
	phase: string, -- "hunt" | "carry" | "flee"
	targetBase: number,
	targetPad: number,
	targetFree: Model?, -- THE CHASE: a free Brainrot on the belt (crater raid, not a base raid)
	stolen: Model?,
	bornAt: number,
}

export type Rival = {
	model: Model,
	name: string,
	baseId: number,
	phase: string, -- "toCrater" | "grab" | "toBase" | "steal" | "chase" | "flee" | "idle"
	carried: Model?,
	coins: number,
	slapReadyAt: number,
	targetUserId: number?, -- the player this rival is stealing from or chasing
	targetBase: number?,
	lastThiefBannerAt: number, -- last "is IN your base" repeat banner (fix round 7, item 7)
	bornAt: number,
}

export type Boost = {
	kind: string, -- "speed" | "magnet" | "cash" | "shield"
	expiresAt: number,
}

export type Egg = {
	model: Model,
	phase: string, -- "falling" | "ground" | "carried" | "incubating" | "hatched"
	carrier: number?, -- UserId carrying it
	baseId: number?, -- base whose incubator holds it
	hatchAt: number?,
	hatchDef: string?, -- rolled at spawn time, so the ground egg can show its rarity and the hatch time scales with it (fix round 7, item 6)
	hatchMutation: string?, -- rolled with the hatch def above
	bornAt: number,
}

local State = {}

-- Player profiles, keyed by UserId (see DataService for the record shape).
State.profiles = {} :: { [number]: Profile }

-- Base ownership, keyed both ways.
State.playerBase = {} :: { [number]: number } -- [userId] = baseId
State.baseOwner = {} :: { [number]: number } -- [baseId] = userId

-- Rotlings on pads: [baseId][padIndex] = Model.
State.placed = {} :: { [number]: { [number]: Model } }

-- Rotlings being carried: [userId] = {Model, ...}.
State.carried = {} :: { [number]: { Model } }

-- Base locks: [baseId] = { lockedUntil = number, cooldownUntil = number, gateShown = boolean }.
-- gateShown tracks whether the red LockGate is currently visible: the
-- gate must vanish the moment the lock expires (rev 76 — it used to
-- stay solid forever, blocking the owner and every thief).
State.locks = {} :: { [number]: { lockedUntil: number, cooldownUntil: number, gateShown: boolean } }

-- Pads a base has unlocked: [baseId] = count (6 open, up to 8).
State.unlockedPads = {} :: { [number]: number }

-- Base colours after rebirth: [baseId] = Color3.
State.baseColors = {} :: { [number]: Color3 }

-- Live Rot Raiders, keyed by their Model.
State.raiders = {} :: { [Model]: Raider }

-- Rival bots, keyed by their Model.
State.rivals = {} :: { [Model]: Rival }

-- Active boosts per player: [userId] = { [kind] = Boost }.
State.boosts = {} :: { [number]: { [string]: Boost } }

-- Live meteor eggs, keyed by their Model.
State.eggs = {} :: { [Model]: Egg }

-- The egg a player is carrying: [userId] = Model.
State.eggCarriedByUser = {} :: { [number]: Model }

-- The Brainrot a player is carrying: [userId] = Model. Rivals chase a
-- Brainrot carrier the same as an egg carrier (rev 77).
State.brainrotCarriedByUser = {} :: { [number]: Model }

-- Global event state: { name = "cash" | "shower" | "", endsAt = number }.
State.globalEvent = { name = "", endsAt = 0 } :: { name: string, endsAt: number }

-- Coins earned per player since the current storm started (bounty).
State.stormEarnings = {} :: { [number]: number }

-- Buddy models: [userId] = Model following the player.
State.buddies = {} :: { [number]: Model }

-- DataStore health per player: [userId] = true when a load/save worked.
State.datastoreOk = {} :: { [number]: boolean }

return State
