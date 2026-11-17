-- Starfall Rotlings: shared server state.
-- Plain tables every server module reads and writes, so no two modules
-- have to require each other in a circle. Only the server writes here;
-- the client never sees this module.

local State = {}

-- Player profiles, keyed by UserId (see Economy for the record shape).
State.profiles = {}

-- Base ownership, keyed both ways.
State.playerBase = {} -- [userId] = baseId
State.baseOwner = {} -- [baseId] = userId

-- Rotlings on pads: [baseId][padIndex] = Model.
State.placed = {}

-- Rotlings being carried: [userId] = {Model, ...}.
State.carried = {}

-- Base locks: [baseId] = { lockedUntil = number, cooldownUntil = number }.
State.locks = {}

-- DataStore health per player: [userId] = true when a load/save worked.
State.datastoreOk = {}

return State
