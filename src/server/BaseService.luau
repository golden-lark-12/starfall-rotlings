--!strict
-- Starfall Rotlings: bases, pads and locks.
-- A base is a home platform with eight pads (six open, two unlocked by
-- the shop). A lock button bars stealing for 60 seconds, longer with the
-- shop's lock tiers. Every rule is checked on the server. Placing and
-- carrying live in CarryService; stealing lives in StealService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local BaseService = {}

-- -- Base assignment -------------------------------------------------------

function BaseService.assignBase(player: Player): number?
	for baseId = 1, Config.BASE_COUNT do
		if State.baseOwner[baseId] == nil then
			State.baseOwner[baseId] = player.UserId
			State.playerBase[player.UserId] = baseId
			State.placed[baseId] = {}
			State.locks[baseId] = { lockedUntil = 0, cooldownUntil = 0 }
			local DataService = require(script.Parent.DataService)
			local profile = DataService.getProfile(player)
			State.unlockedPads[baseId] = Config.PADS_OPEN + (if profile then profile.padsTier else 0)
			WorldBuilder.setBaseSign(baseId, player.DisplayName .. "'s Base")
			if profile and profile.rebirths > 0 then
				local RebirthService = require(script.Parent.RebirthService)
				local color = RebirthService.COLORS[(profile.rebirths - 1) % #RebirthService.COLORS + 1]
				WorldBuilder.setBaseColor(baseId, color)
			end
			return baseId
		end
	end
	return nil
end

function BaseService.freeBase(player: Player)
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		return
	end
	-- Rotlings left on the pads wander back to the crater, free to catch.
	local CarryService = require(script.Parent.CarryService)
	for _, model in pairs(State.placed[baseId] or {}) do
		CarryService.scatterToCrater(model)
	end
	State.placed[baseId] = nil
	State.baseOwner[baseId] = nil
	State.playerBase[player.UserId] = nil
	State.locks[baseId] = nil
	State.unlockedPads[baseId] = nil
	State.baseColors[baseId] = nil
	WorldBuilder.setBaseSign(baseId, "Base " .. tostring(baseId))
end

function BaseService.getPlayerBase(userId: number): number?
	return State.playerBase[userId]
end

function BaseService.getBaseOwner(baseId: number): number?
	return State.baseOwner[baseId]
end

-- -- Locks ------------------------------------------------------------------

function BaseService.lockDurationFor(player: Player): number
	local DataService = require(script.Parent.DataService)
	local profile = DataService.getProfile(player)
	local tier = if profile then profile.lockTier else 0
	return Config.LOCK_DURATION + Config.LOCK_DURATION_PER_TIER * tier
end

function BaseService.isLocked(baseId: number): boolean
	local lock = State.locks[baseId]
	if not lock then
		return false
	end
	return os.clock() < lock.lockedUntil
end

function BaseService.lockRemaining(baseId: number): number
	local lock = State.locks[baseId]
	if not lock then
		return 0
	end
	return math.max(0, lock.lockedUntil - os.clock())
end

function BaseService.lockCooldownRemaining(baseId: number): number
	local lock = State.locks[baseId]
	if not lock then
		return 0
	end
	return math.max(0, lock.cooldownUntil - os.clock())
end

-- Turn a player's base lock on. Returns (ok, message).
function BaseService.lockBase(player: Player): (boolean, string)
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		return false, "You have no base yet."
	end
	if BaseService.isLocked(baseId) then
		return false, "Your base is already locked."
	end
	local cooldown = BaseService.lockCooldownRemaining(baseId)
	if cooldown > 0 then
		return false, "Lock recharges in " .. tostring(math.ceil(cooldown)) .. "s."
	end
	local duration = BaseService.lockDurationFor(player)
	local now = os.clock()
	State.locks[baseId].lockedUntil = now + duration
	State.locks[baseId].cooldownUntil = now + duration + Config.LOCK_COOLDOWN
	BaseService.setGateVisible(baseId, true)
	return true, "Base locked for " .. tostring(duration) .. "s! No one can steal from you."
end

function BaseService.setGateVisible(baseId: number, visible: boolean)
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "LockGate" and descendant:GetAttribute("BaseId") == baseId then
			descendant.Transparency = if visible then 0.25 else 1
			descendant.CanCollide = visible
		end
	end
end

-- Wire the ToggleLock remote event.
function BaseService.init()
	Remotes.lockEvent().OnServerEvent:Connect(function(player: Player)
		local ok, message = BaseService.lockBase(player)
		Remotes.bannerEvent():FireClient(player, message, 3)
	end)
end

-- -- Pads ---------------------------------------------------------------------

-- First free pad among the ones this base has unlocked, if any.
function BaseService.freePad(baseId: number): number?
	local placed = State.placed[baseId]
	if not placed then
		return nil
	end
	local unlocked = State.unlockedPads[baseId] or Config.PADS_OPEN
	for padIndex = 1, math.min(unlocked, Config.PADS_PER_BASE) do
		if placed[padIndex] == nil then
			return padIndex
		end
	end
	return nil
end

-- How many pads this base has unlocked.
function BaseService.unlockedPadCount(baseId: number): number
	return State.unlockedPads[baseId] or Config.PADS_OPEN
end

-- Open the next pad on a player's base (shop Pads tier).
function BaseService.unlockPad(player: Player)
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		return
	end
	local unlocked = State.unlockedPads[baseId] or Config.PADS_OPEN
	if unlocked >= Config.PADS_PER_BASE then
		return
	end
	State.unlockedPads[baseId] = unlocked + 1
	WorldBuilder.setPadLocked(baseId, unlocked + 1, false)
end

-- Lift a Rotling off its pad without carrying it (steals and raids use this).
function BaseService.removePlaced(baseId: number, padIndex: number): Model?
	local placed = State.placed[baseId]
	if not placed then
		return nil
	end
	local model = placed[padIndex]
	placed[padIndex] = nil
	return model
end

function BaseService.getPlacedForPlayer(player: Player): { Model }
	local out = {}
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		return out
	end
	for _, model in pairs(State.placed[baseId] or {}) do
		table.insert(out, model)
	end
	return out
end

-- Snapshot a player's placed Rotlings for the save record.
function BaseService.snapshotPlaced(player: Player): { State.PlacedEntry }
	local out = {}
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		return out
	end
	for padIndex, model in pairs(State.placed[baseId] or {}) do
		local mut = model:GetAttribute("Mutation")
		table.insert(out, {
			def = model:GetAttribute("DefId"),
			mut = if mut == "" then nil else mut,
			pad = padIndex,
		})
	end
	return out
end

return BaseService
