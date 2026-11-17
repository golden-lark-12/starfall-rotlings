-- Starfall Rotlings: bases, carrying, placing and stealing.
-- A base is a home platform with six pads. A player grabs a free Rotling
-- in the crater, carries it home and sets it on a pad, where it earns.
-- Anyone can steal a placed Rotling from an unlocked base; a lock button
-- bars stealing for 60 seconds. Every rule is checked on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RotlingData = require(ReplicatedStorage.Shared.RotlingData)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)
local RotlingFactory = require(script.Parent.RotlingFactory)

local Bases = {}

local Remotes -- set by init() to avoid a require circle (Remotes needs Bases too)

function Bases.init(remotesModule)
	Remotes = remotesModule
end

-- -- Base assignment -------------------------------------------------------

function Bases.assignBase(player: Player): number?
	for baseId = 1, Config.BASE_COUNT do
		if State.baseOwner[baseId] == nil then
			State.baseOwner[baseId] = player.UserId
			State.playerBase[player.UserId] = baseId
			State.placed[baseId] = {}
			State.locks[baseId] = { lockedUntil = 0, cooldownUntil = 0 }
			WorldBuilder.setBaseSign(baseId, player.DisplayName .. "'s Base")
			return baseId
		end
	end
	return nil
end

function Bases.freeBase(player: Player)
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		return
	end
	-- Rotlings left on the pads wander back to the crater, free to catch.
	for _, model in pairs(State.placed[baseId] or {}) do
		Bases.scatterToCrater(model)
	end
	State.placed[baseId] = nil
	State.baseOwner[baseId] = nil
	State.playerBase[player.UserId] = nil
	State.locks[baseId] = nil
	WorldBuilder.setBaseSign(baseId, "Base " .. tostring(baseId))
end

function Bases.getPlayerBase(userId: number): number?
	return State.playerBase[userId]
end

function Bases.getBaseOwner(baseId: number): number?
	return State.baseOwner[baseId]
end

-- -- Locks ------------------------------------------------------------------

function Bases.isLocked(baseId: number): boolean
	local lock = State.locks[baseId]
	if not lock then
		return false
	end
	return os.clock() < lock.lockedUntil
end

function Bases.lockRemaining(baseId: number): number
	local lock = State.locks[baseId]
	if not lock then
		return 0
	end
	return math.max(0, lock.lockedUntil - os.clock())
end

function Bases.lockCooldownRemaining(baseId: number): number
	local lock = State.locks[baseId]
	if not lock then
		return 0
	end
	return math.max(0, lock.cooldownUntil - os.clock())
end

-- Turn a player's base lock on. Returns (ok, message).
function Bases.lockBase(player: Player): (boolean, string)
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		return false, "You have no base yet."
	end
	if Bases.isLocked(baseId) then
		return false, "Your base is already locked."
	end
	local cooldown = Bases.lockCooldownRemaining(baseId)
	if cooldown > 0 then
		return false, "Lock recharges in " .. tostring(math.ceil(cooldown)) .. "s."
	end
	local now = os.clock()
	State.locks[baseId].lockedUntil = now + Config.LOCK_DURATION
	State.locks[baseId].cooldownUntil = now + Config.LOCK_DURATION + Config.LOCK_COOLDOWN
	Bases.setGateVisible(baseId, true)
	return true, "Base locked for 60s! No one can steal from you."
end

function Bases.setGateVisible(baseId: number, visible: boolean)
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "LockGate" and descendant:GetAttribute("BaseId") == baseId then
			descendant.Transparency = if visible then 0.25 else 1
			descendant.CanCollide = visible
		end
	end
end

-- -- Carrying ---------------------------------------------------------------

function Bases.getCarried(player: Player): { Model }
	return State.carried[player.UserId] or {}
end

function Bases.getCarrySlots(player: Player): number
	local profile = State.profiles[player.UserId]
	local tier = if profile then profile.carryTier else 0
	return 1 + tier
end

local function weldToPlayer(model: Model, player: Player)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local body = model.PrimaryPart
	if not root or not body then
		return false
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = body
	weld.C0 = CFrame.new(0, Config.CARRY_HEIGHT, 0)
	weld.Parent = body
	model:SetAttribute("State", "carried")
	return true
end

local function unweld(model: Model)
	local body = model.PrimaryPart
	if body then
		local weld = body:FindFirstChild("CarryWeld")
		if weld then
			weld:Destroy()
		end
	end
end

function Bases.carryRotling(player: Player, model: Model)
	local carried = State.carried[player.UserId]
	if not carried then
		carried = {}
		State.carried[player.UserId] = carried
	end
	table.insert(carried, model)
	model:SetAttribute("OwnerUserId", player.UserId)
	Bases.setPromptState(model)
end

function Bases.removeCarried(player: Player, model: Model)
	local carried = State.carried[player.UserId]
	if not carried then
		return
	end
	local index = table.find(carried, model)
	if index then
		table.remove(carried, index)
	end
end

-- -- Grab / steal -----------------------------------------------------------

function Bases.setPromptState(model: Model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local prompt = body:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	local def = RotlingData.getDef(model:GetAttribute("DefId") or "")
	local name = if def then def.name else "Rotling"
	local state = model:GetAttribute("State")
	if state == "carried" then
		prompt.Enabled = false
	elseif state == "placed" then
		local baseId = model:GetAttribute("BaseId")
		prompt.ActionText = "Steal " .. name
		prompt.Enabled = not Bases.isLocked(baseId)
	else
		prompt.ActionText = "Grab " .. name
		prompt.Enabled = true
	end
end

-- The one entry point for every grab and steal prompt trigger.
function Bases.tryGrab(player: Player, model: Model)
	if not model or not model.Parent then
		return
	end
	local state = model:GetAttribute("State")
	if state == "carried" then
		return
	end
	if #Bases.getCarried(player) >= Bases.getCarrySlots(player) then
		Remotes.fireBanner(player, "Your arms are full! Buy Extra Arms in the shop.", 3)
		return
	end
	if state == "free" then
		if not weldToPlayer(model, player) then
			return
		end
		Bases.carryRotling(player, model)
		local def = RotlingData.getDef(model:GetAttribute("DefId") or "")
		if def then
			local profile = State.profiles[player.UserId]
			if profile then
				profile.index[def.id] = true
			end
		end
		Remotes.fireBanner(player, "Got it! Carry it home to your base.", 3)
	elseif state == "placed" then
		local ownerId = model:GetAttribute("OwnerUserId")
		if ownerId == player.UserId then
			Remotes.fireBanner(player, "That one is already yours.", 2)
			return
		end
		local baseId = model:GetAttribute("BaseId")
		if Bases.isLocked(baseId) then
			Remotes.fireBanner(player, "That base is locked! Come back later.", 3)
			return
		end
		-- Lift it off the pad, then carry it.
		local padIndex = model:GetAttribute("PadIndex")
		if State.placed[baseId] then
			State.placed[baseId][padIndex] = nil
		end
		if not weldToPlayer(model, player) then
			return
		end
		Bases.carryRotling(player, model)
		model:SetAttribute("BaseId", 0)
		model:SetAttribute("PadIndex", 0)
		Remotes.fireBanner(player, "Stolen! Get it home before they notice!", 3)
		local owner = Players:GetPlayerByUserId(ownerId)
		if owner then
			Remotes.fireBanner(owner, player.DisplayName .. " is stealing your Rotling!", 4)
		end
	end
end

-- -- Placing ------------------------------------------------------------------

function Bases.freePad(baseId: number): number?
	local placed = State.placed[baseId]
	if not placed then
		return nil
	end
	for padIndex = 1, Config.PADS_PER_BASE do
		if placed[padIndex] == nil then
			return padIndex
		end
	end
	return nil
end

-- Place the carried Rotling nearest to the player onto their own free pad.
function Bases.tryPlace(player: Player)
	local carried = Bases.getCarried(player)
	if #carried == 0 then
		return
	end
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		Remotes.fireBanner(player, "You have no base yet.", 2)
		return
	end
	local padIndex = Bases.freePad(baseId)
	if not padIndex then
		Remotes.fireBanner(player, "Your base is full! (6 pads)", 3)
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local padCf = WorldBuilder.padCFrame(baseId, padIndex)
	if not padCf then
		return
	end
	if (root.Position - padCf.Position).Magnitude > Config.PLACE_RANGE + 12 then
		Remotes.fireBanner(player, "Stand on your base to place it.", 2)
		return
	end
	local model = carried[1]
	Bases.placeOnPad(player, model, baseId, padIndex)
end

function Bases.placeOnPad(player: Player, model: Model, baseId: number, padIndex: number)
	unweld(model)
	Bases.removeCarried(player, model)
	local padCf = WorldBuilder.padCFrame(baseId, padIndex)
	local def = RotlingData.getDef(model:GetAttribute("DefId") or "")
	local lift = if def then def.size * 0.55 + 0.6 else 2.5
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model:PivotTo(padCf * CFrame.new(0, lift, 0))
	model:SetAttribute("State", "placed")
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BaseId", baseId)
	model:SetAttribute("PadIndex", padIndex)
	if not State.placed[baseId] then
		State.placed[baseId] = {}
	end
	State.placed[baseId][padIndex] = model
	Bases.setPromptState(model)
	local profile = State.profiles[player.UserId]
	if profile and def then
		profile.index[def.id] = true
	end
	Remotes.fireBanner(player, "Placed! It now earns coins every second.", 3)
end

-- -- Dropping -----------------------------------------------------------------

-- Send a Rotling back to the crater as a free catch.
function Bases.scatterToCrater(model: Model)
	unweld(model)
	local angle = math.random() * math.pi * 2
	local radius = math.random() * Config.CRATER_RADIUS * 0.8
	local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	local def = RotlingData.getDef(model:GetAttribute("DefId") or "")
	local lift = if def then def.size * 0.55 + 0.6 else 2.5
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	model:PivotTo(CFrame.new(pos + Vector3.new(0, lift, 0)))
	model:SetAttribute("State", "free")
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("BaseId", 0)
	model:SetAttribute("PadIndex", 0)
	Bases.setPromptState(model)
end

function Bases.dropAllCarried(player: Player)
	local carried = Bases.getCarried(player)
	if #carried == 0 then
		return
	end
	for _, model in ipairs(table.clone(carried)) do
		Bases.removeCarried(player, model)
		Bases.scatterToCrater(model)
	end
	Remotes.fireBanner(player, "You dropped your Rotlings!", 3)
end

-- Rebuild a player's saved Rotlings onto their new base's pads.
function Bases.restorePlaced(player: Player, saved: { { def: string, mut: string?, pad: number } })
	local baseId = State.playerBase[player.UserId]
	if not baseId then
		return
	end
	for _, entry in ipairs(saved) do
		local padCf = WorldBuilder.padCFrame(baseId, entry.pad)
		if padCf and (State.placed[baseId] or {})[entry.pad] == nil then
			local model = RotlingFactory.build(entry.def, entry.mut, padCf.Position)
			if model then
				model.Parent = workspace
				Bases.placeOnPad(player, model, baseId, entry.pad)
			end
		end
	end
end

function Bases.snapshotPlaced(player: Player): { { def: string, mut: string?, pad: number } }
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

function Bases.getPlacedForPlayer(player: Player): { Model }
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

return Bases
