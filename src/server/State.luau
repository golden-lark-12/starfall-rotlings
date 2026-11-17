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
}

export type Raider = {
	model: Model,
	phase: string, -- "hunt" | "carry" | "flee"
	targetBase: number,
	targetPad: number,
	stolen: Model?,
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

-- DataStore health per player: [userId] = true when a load/save worked.
State.datastoreOk = {} :: { [number]: boolean }

return State
