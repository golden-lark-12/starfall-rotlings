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
	coins: number,
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
	index: { [string]: boolean },
	indexRewards: { [string]: boolean },
	indexFullRewarded: boolean,
	placed: { PlacedEntry },
	missionIndex: number, -- which Config.MISSIONS entry is active (1-based)
	missionProgress: number, -- progress toward the active mission
	lastDailyClaim: number, -- os.time() of the last daily reward claim (0 = never)
}

export type Raider = {
	model: Model,
	phase: string, -- "hunt" | "carry" | "flee"
	targetBase: number,
	targetPad: number,
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

-- Base locks: [baseId] = { lockedUntil = number, cooldownUntil = number }.
State.locks = {} :: { [number]: { lockedUntil: number, cooldownUntil: number } }

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

-- Global event state: { name = "cash" | "shower" | "", endsAt = number }.
State.globalEvent = { name = "", endsAt = 0 } :: { name: string, endsAt: number }

-- Coins earned per player since the current storm started (bounty).
State.stormEarnings = {} :: { [number]: number }
State.stormBountyText = "Top earner this storm wins a bonus!"

-- Buddy models: [userId] = Model following the player.
State.buddies = {} :: { [number]: Model }

-- DataStore health per player: [userId] = true when a load/save worked.
State.datastoreOk = {} :: { [number]: boolean }

return State
