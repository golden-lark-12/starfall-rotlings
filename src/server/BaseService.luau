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
			State.locks[baseId] = { lockedUntil = 0, cooldownUntil = 0, gateShown = false }
			State.lockdowns[baseId] = { endsAt = 0, cooldownUntil = 0, gateShown = false }
			local DataService = require(script.Parent.DataService)
			local profile = DataService.getProfile(player)
			State.unlockedPads[baseId] = Config.PADS_OPEN + (if profile then profile.padsTier else 0)
			WorldBuilder.setBaseSign(baseId, player.DisplayName .. "'s Base")
			WorldBuilder.setBaseCoins(baseId, if profile then profile.banked else 0)
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
	State.lockdowns[baseId] = nil
	State.unlockedPads[baseId] = nil
	State.baseColors[baseId] = nil
	WorldBuilder.setBaseSign(baseId, "Base " .. tostring(baseId))
	WorldBuilder.setBaseCoins(baseId, 0)
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

-- The REGULAR lock only (L key / Lock button, 120s + tiers).
function BaseService.isLockRegular(baseId: number): boolean
	local lock = State.locks[baseId]
	if not lock then
		return false
	end
	return time() < lock.lockedUntil
end

-- LOCKED means sealed against stealing: the regular lock OR the
-- emergency lockdown (fix round 13, item 4). Every enforcement
-- point (StealService, RivalService pickVictim, RaiderService,
-- the place prompts) reads this one function, so a lockdown seals
-- the base exactly like a lock does — no second check needed at
-- any call site.
function BaseService.isLocked(baseId: number): boolean
	return BaseService.isLockRegular(baseId) or BaseService.isLockdown(baseId)
end

-- -- Emergency lockdown (fix round 13, item 4) ---------------------------

function BaseService.isLockdown(baseId: number): boolean
	local lockdown = State.lockdowns[baseId]
	if not lockdown then
		return false
	end
	return time() < lockdown.endsAt
end

function BaseService.lockdownRemaining(baseId: number): number
	local lockdown = State.lockdowns[baseId]
	if not lockdown then
		return 0
	end
	return math.max(0, lockdown.endsAt - time())
end

function BaseService.lockdownCooldownRemaining(baseId: number): number
	local lockdown = State.lockdowns[baseId]
	if not lockdown then
		return 0
	end
	return math.max(0, lockdown.cooldownUntil - time())
end

function BaseService.lockRemaining(baseId: number): number
	local lock = State.locks[baseId]
	if not lock then
		return 0
	end
	return math.max(0, lock.lockedUntil - time())
end

function BaseService.lockCooldownRemaining(baseId: number): number
	local lock = State.locks[baseId]
	if not lock then
		return 0
	end
	return math.max(0, lock.cooldownUntil - time())
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
	local now = time()
	State.locks[baseId].lockedUntil = now + duration
	State.locks[baseId].cooldownUntil = now + duration + Config.LOCK_COOLDOWN
	BaseService.setGateVisible(baseId, true)
	State.locks[baseId].gateShown = true
	-- The shield dome shows too, with its SAFE countdown label
	-- (cheap win 5) — the lock is visible in the world, not just a
	-- timer in the HUD. The label is refreshed every income broadcast
	-- and hidden when the lock expires. (fix round 13, item 4) If a
	-- lockdown is already sealing the base, its red LOCKDOWN label
	-- wins — the L press must not overwrite it with the blue SAFE
	-- label; the broadcast restores the lockdown label next tick
	-- either way.
	local WorldBuilder = require(script.Parent.WorldBuilder)
	WorldBuilder.setShieldVisible(baseId, true)
	if BaseService.isLockdown(baseId) then
		WorldBuilder.setShieldLockdown(baseId, BaseService.lockdownRemaining(baseId))
	else
		WorldBuilder.setShieldLabel(baseId, duration)
	end
	return true, "Base locked for " .. tostring(duration) .. "s! No one can steal from you."
end

function BaseService.setGateVisible(baseId: number, visible: boolean)
	-- (fix round 13, item 4) A lockdown overrides the regular
	-- lock's look: while sealed, the gate is the opaque red wall,
	-- never the faint shimmer — no call site can downgrade it by
	-- calling setGateVisible(true) while a lockdown holds.
	if BaseService.isLockdown(baseId) then
		BaseService.setGateLockdown(baseId, true)
		return
	end
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:GetAttribute("BaseId") == baseId then
			if descendant.Name == "LockGate" then
				-- The slab is the barrier: a faint red shimmer while
				-- locked (the beams do the visible work), invisible
				-- and uncollidable while open.
				descendant.Transparency = if visible then 0.9 else 1
				descendant.CanCollide = visible
				if descendant:IsA("BasePart") then
					descendant.Material = if visible then Enum.Material.Neon else Enum.Material.ForceField
				end
			elseif descendant.Name == "LockGateBeam" then
				-- The laser beams: bright red Neon while locked,
				-- invisible while open. They never collide — the slab
				-- is the barrier.
				descendant.Transparency = if visible then 0 else 1
			end
		end
	end
end

-- Turn a player's emergency lockdown on. Returns (ok, message).
-- Fixed 30s seal, 60s cooldown, no shop tiers — it is an emergency
-- button, not an upgrade. Works on top of the regular lock: sealing
-- while locked keeps the lock underneath, and the lockdown ending
-- never opens a lock that is still running (setGateLockdown(false)
-- falls back to the regular lock's look).
function BaseService.lockdownBase(player: Player): (boolean, string)
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		return false, "You have no base yet."
	end
	if BaseService.isLockdown(baseId) then
		return false, "Your base is already in lockdown."
	end
	local cooldown = BaseService.lockdownCooldownRemaining(baseId)
	if cooldown > 0 then
		return false, "Lockdown recharges in " .. tostring(math.ceil(cooldown)) .. "s."
	end
	local now = time()
	if not State.lockdowns[baseId] then
		State.lockdowns[baseId] = { endsAt = 0, cooldownUntil = 0, gateShown = false }
	end
	State.lockdowns[baseId].endsAt = now + Config.LOCKDOWN_DURATION
	State.lockdowns[baseId].cooldownUntil = now + Config.LOCKDOWN_DURATION + Config.LOCKDOWN_COOLDOWN
	State.lockdowns[baseId].gateShown = true
	BaseService.setGateLockdown(baseId, true)
	-- The shield dome shows too, with its LOCKDOWN countdown label
	-- (the income broadcast keeps the label live every tick).
	local WorldBuilder = require(script.Parent.WorldBuilder)
	WorldBuilder.setShieldVisible(baseId, true)
	WorldBuilder.setShieldLockdown(baseId, Config.LOCKDOWN_DURATION)
	return true, "🔒 LOCKDOWN! Your base is sealed for " .. tostring(Config.LOCKDOWN_DURATION) .. "s — no one can get in!"
end

-- Show or hide the LOCKDOWN gate. Active: the slab is an OPAQUE
-- red wall (Transparency 0), not the regular lock's faint shimmer
-- (0.9) — the seal reads as a wall, distinct at a glance. Ending:
-- fall back to the regular lock's look (or hidden). isLockdown is
-- false by the time this runs with active = false, so the guard in
-- setGateVisible cannot re-trigger.
function BaseService.setGateLockdown(baseId: number, active: boolean)
	if active then
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:GetAttribute("BaseId") == baseId then
				if descendant.Name == "LockGate" then
					descendant.Transparency = 0
					descendant.CanCollide = true
					if descendant:IsA("BasePart") then
						descendant.Material = Enum.Material.Neon
					end
				elseif descendant.Name == "LockGateBeam" then
					descendant.Transparency = 0
				end
			end
		end
	else
		BaseService.setGateVisible(baseId, BaseService.isLockRegular(baseId))
	end
	local lock = State.locks[baseId]
	if lock then
		lock.gateShown = active or BaseService.isLockRegular(baseId)
	end
end

-- Wire the ToggleLock remote event.
function BaseService.init()
	Remotes.lockEvent().OnServerEvent:Connect(function(player: Player)
		local ok, message = BaseService.lockBase(player)
		Remotes.bannerEvent():FireClient(player, message, 3)
	end)
	-- Wire the ToggleLockdown remote event (fix round 13, item 4).
	Remotes.lockdownEvent().OnServerEvent:Connect(function(player: Player)
		local ok, message = BaseService.lockdownBase(player)
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
