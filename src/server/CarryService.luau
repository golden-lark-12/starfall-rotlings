--!strict
-- Starfall Rotlings: carrying, placing and dropping.
-- A player grabs a free Rotling in the crater, carries it home in front
-- of their chest at arm height and sets it on a pad, where it earns.
-- Dying or a meteor hit drops everything carried back into the crater.
-- Placed Rotlings are handed to StealService by the grab prompt
-- (deferred require: StealService calls back into this module to carry
-- what it lifts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local FeedbackService = require(script.Parent.FeedbackService)
local IndexService = require(script.Parent.IndexService)
local MissionService = require(script.Parent.MissionService)
local RotlingFactory = require(script.Parent.RotlingFactory)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local CarryService = {}

local PICKUP_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local function playPickupSound(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = PICKUP_SOUND
	sound.Volume = 0.6
	sound.PlaybackSpeed = 1.2
	sound.Parent = root
	sound:Play()
	task.delay(1, function()
		sound:Destroy()
	end)
end

-- -- Carrying ---------------------------------------------------------------

function CarryService.getCarried(player: Player): { Model }
	return State.carried[player.UserId] or {}
end

function CarryService.getCarrySlots(player: Player): number
	local profile = DataService.getProfile(player)
	local tier = if profile then profile.carryTier else 0
	return 1 + tier
end

local function weldToPlayer(model: Model, player: Player): boolean
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
	-- In front of the chest at arm height: forward is -Z off the root,
	-- so a negative Z puts the Rotling ahead of the player, never over
	-- the head or the face.
	weld.C0 = CFrame.new(0, Config.CARRY_Y, Config.CARRY_Z)
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

function CarryService.carryRotling(player: Player, model: Model)
	local carried = State.carried[player.UserId]
	if not carried then
		carried = {}
		State.carried[player.UserId] = carried
	end
	-- Never insert the same model twice: a duplicate entry survives
	-- its place (removeCarried used to take only the first copy), so
	-- the slot read as full forever after one place. Insert is
	-- idempotent now — a second carry of the same model is a no-op.
	if table.find(carried, model) then
		return
	end
	table.insert(carried, model)
	model:SetAttribute("OwnerUserId", player.UserId)
	CarryService.setPromptState(model)
end

function CarryService.removeCarried(player: Player, model: Model)
	local carried = State.carried[player.UserId]
	if not carried then
		return
	end
	-- Remove EVERY copy, not just the first: a stale duplicate must
	-- never survive a place and leave the slot reading as full.
	local index = table.find(carried, model)
	while index do
		table.remove(carried, index)
		index = table.find(carried, model)
	end
end

-- -- Prompts ------------------------------------------------------------------

function CarryService.setPromptState(model: Model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local prompt = body:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	local name = if def then def.name else "Rotling"
	local state = model:GetAttribute("State")
	if state == "carried" then
		prompt.Enabled = false
	elseif state == "placed" then
		-- One prompt for everyone: "Take" covers both the owner
		-- picking their own Rotling back up and a rival stealing it.
		-- tryGrab routes owners to pickupOwn and everyone else to
		-- StealService.trySteal. The base id comes from the model's
		-- own BaseId attribute (fix 2): the old code read an undefined
		-- global, so the lock check silently never ran.
		prompt.ActionText = "Take " .. name
		local placedBaseId = model:GetAttribute("BaseId") :: number?
		prompt.Enabled = if placedBaseId then not BaseService.isLocked(placedBaseId) else true
	else
		prompt.ActionText = "Grab " .. name
		prompt.Enabled = true
	end
end

-- XP: grabbing pays 10, placing pays 15; one level per 100 XP.
local function addXp(player: Player, amount: number)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	profile.xp += amount
	profile.level = 1 + math.floor(profile.xp / Config.XP_PER_LEVEL)
end

-- Pick up your OWN placed Rotling: lift it off its pad and carry it
-- again, so you can move it to another pad or sell it at the SELL pad.
-- The old code routed every placed grab to StealService, which refused
-- your own Rotlings ("That one is already yours") — a placed Rotling
-- was stuck on its pad forever and could never be sold or moved.
function CarryService.pickupOwn(player: Player, model: Model)
	if #CarryService.getCarried(player) >= CarryService.getCarrySlots(player) then
		Remotes.bannerEvent():FireClient(player, "Your arms are full! Buy Extra Arms in the shop.", 3)
		return
	end
	local baseId = model:GetAttribute("BaseId") :: number
	local padIndex = model:GetAttribute("PadIndex") :: number
	BaseService.removePlaced(baseId, padIndex)
	RotlingFactory.setCarriedVisual(model, true)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local body = model.PrimaryPart
	if not root or not body then
		return
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
	weld.C0 = CFrame.new(0, Config.CARRY_Y, Config.CARRY_Z)
	weld.Parent = body
	model:SetAttribute("State", "carried")
	model:SetAttribute("BaseId", 0)
	model:SetAttribute("PadIndex", 0)
	CarryService.carryRotling(player, model)
	-- Picking a Rotling back up can change the best buddy.
	local BuddyService = require(script.Parent.BuddyService)
	BuddyService.refreshBuddy(player)
	Remotes.bannerEvent():FireClient(player, "Picked it back up — place it on another pad or sell it.", 3)
end

-- The one entry point for every grab prompt trigger.
function CarryService.tryGrab(player: Player, model: Model)
	if not model or not model.Parent then
		return
	end
	local state = model:GetAttribute("State")
	if state == "carried" then
		return
	end
	if state == "placed" then
		-- Your own Rotling: pick it back up (move it or sell it).
		-- Anyone else's: the steal path (lock and arms checked there).
		local ownerId = model:GetAttribute("OwnerUserId") :: number
		if ownerId == player.UserId then
			CarryService.pickupOwn(player, model)
			return
		end
		-- Deferred require: StealService carries what it lifts via this module.
		local StealService = require(script.Parent.StealService)
		StealService.trySteal(player, model)
		return
	end
	if #CarryService.getCarried(player) >= CarryService.getCarrySlots(player) then
		Remotes.bannerEvent():FireClient(player, "Your arms are full! Buy Extra Arms in the shop.", 3)
		return
	end
	-- Already carrying this exact model (a prompt double-fire must
	-- never insert it twice): ignore the second grab.
	if table.find(CarryService.getCarried(player), model) then
		return
	end
	-- The real model at a readable size, in front of the chest — never
	-- a shrunken box above the head, never a bubble.
	RotlingFactory.setCarriedVisual(model, true)
	if not weldToPlayer(model, player) then
		-- Weld failed: restore the crater look so the Rotling is not
		-- left shrunken on the floor.
		RotlingFactory.setCarriedVisual(model, false)
		RotlingFactory.setModelScale(model, 1.5)
		RotlingFactory.refreshLabelOffset(model)
		return
	end
	CarryService.carryRotling(player, model)
	MissionService.addProgress(player, "grab", 1)
	addXp(player, Config.XP_GRAB)
	playPickupSound(player)
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	if def then
		IndexService.markFound(player, def.id)
		-- Gold burst in the Rotling's rarity colour: the grab reads.
		FeedbackService.burst(model, RarityConfig.rarityByName(def.rarity).color)
		if RarityConfig.rarityTier(def.rarity) >= 4 then
			Remotes.rarityPopupEvent():FireClient(player, def.name, def.rarity, model:GetAttribute("Mutation") :: string?, RotlingCatalog.baseCps(def, model:GetAttribute("Mutation") :: string?))
		end
	end
	Remotes.bannerEvent():FireClient(player, "Got it! Carry it home to your base.", 3)
end

-- -- Placing ------------------------------------------------------------------

-- Place the carried Rotling nearest to the player onto their own free pad.
function CarryService.tryPlace(player: Player)
	local carried = CarryService.getCarried(player)
	if #carried == 0 then
		return
	end
	local baseId = BaseService.getPlayerBase(player.UserId)
	if not baseId then
		Remotes.bannerEvent():FireClient(player, "You have no base yet.", 2)
		return
	end
	local padIndex = BaseService.freePad(baseId)
	if not padIndex then
		Remotes.bannerEvent():FireClient(player, "Your base is full! Buy an Extra Pad in the shop.", 3)
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
		Remotes.bannerEvent():FireClient(player, "Stand on your base to place it.", 2)
		return
	end
	local model = carried[1]
	CarryService.placeOnPad(player, model, baseId, padIndex)
	-- Pop + coin burst on the pad (sound + particles in placePop).
	RotlingFactory.placePop(model)
end

function CarryService.placeOnPad(player: Player, model: Model, baseId: number, padIndex: number)
	unweld(model)
	CarryService.removeCarried(player, model)
	-- The slot MUST be clear now: if the model is still listed as
	-- carried, the arms-full bug is back — say so loudly in Output
	-- instead of leaving the player stuck.
	if table.find(CarryService.getCarried(player), model) then
		warn("[CarryService] placeOnPad: " .. model.Name .. " still in " .. player.Name .. "'s carried list after removeCarried")
		CarryService.removeCarried(player, model)
	end
	-- Full size again, glow and tag back — before the model is anchored
	-- and pivoted onto the pad.
	RotlingFactory.setCarriedVisual(model, false)
	RotlingFactory.setModelScale(model, 1)
	RotlingFactory.refreshLabelOffset(model)
	local padCf = WorldBuilder.padCFrame(baseId, padIndex)
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	-- Seat the Rotling ON the pad from its own body: the pad top is
	-- 0.3 above the pad centre and the feet hang 0.05*size below the
	-- body bottom, so the feet rest exactly on the pad. The old fixed
	-- lift (size*0.55 + 0.6) floated a flat puddle a full stud above
	-- its pad and sank a tall sock into it.
	local liftBody = model.PrimaryPart
	local lift = if liftBody and liftBody:IsA("BasePart")
		then liftBody.Size.Y / 2 + 0.3 + (if def then def.size * 0.05 else 0.15)
		elseif def then def.size * 0.55 + 0.6
		else 2.5
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	if padCf then
		model:PivotTo(padCf * CFrame.new(0, lift, 0))
	end
	model:SetAttribute("State", "placed")
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BaseId", baseId)
	model:SetAttribute("PadIndex", padIndex)
	if not State.placed[baseId] then
		State.placed[baseId] = {}
	end
	State.placed[baseId][padIndex] = model
	CarryService.setPromptState(model)
	if def then
		IndexService.markFound(player, def.id)
	end
	-- The idle loop bobs around this new rest pose.
	RotlingFactory.setRestPose(model)
	MissionService.addProgress(player, "place", 1)
	addXp(player, Config.XP_PLACE)
	-- A new placement can change the best buddy (highest income).
	local BuddyService = require(script.Parent.BuddyService)
	BuddyService.refreshBuddy(player)
	Remotes.bannerEvent():FireClient(player, "Placed! It now earns coins every second.", 3)
end

-- Wire the PlaceRotling remote event.
function CarryService.init()
	Remotes.placeEvent().OnServerEvent:Connect(function(player: Player)
		CarryService.tryPlace(player)
	end)
end

-- -- Dropping -----------------------------------------------------------------

-- Send a Rotling back to the crater as a free catch.
function CarryService.scatterToCrater(model: Model)
	unweld(model)
	-- Back to crater size (1.5x), carried look off, glow and tag back.
	RotlingFactory.setCarriedVisual(model, false)
	RotlingFactory.setModelScale(model, 1.5)
	RotlingFactory.refreshLabelOffset(model)
	local angle = math.random() * math.pi * 2
	local radius = math.random() * Config.CRATER_RADIUS * 0.8
	local pos = Vector3.new(math.cos(angle) * radius, Config.CRATER_FLOOR_Y, math.sin(angle) * radius)
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	-- Lift from the scaled body, so the bigger crater Rotling rests on
	-- the floor instead of sinking into it.
	local body = model.PrimaryPart
	local lift = if body and body:IsA("BasePart")
		then body.Size.Y / 2 + 0.8
		elseif def then def.size * 0.55 + 0.6
		else 2.5
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model:PivotTo(CFrame.new(pos + Vector3.new(0, lift, 0)))
	model:SetAttribute("State", "free")
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("BaseId", 0)
	model:SetAttribute("PadIndex", 0)
	CarryService.setPromptState(model)
	-- The idle loop bobs around this new rest pose.
	RotlingFactory.setRestPose(model)
	-- Deferred require: SpawnService grabs through this module.
	local SpawnService = require(script.Parent.SpawnService)
	SpawnService.registerFree(model)
end

function CarryService.dropAllCarried(player: Player)
	local carried = CarryService.getCarried(player)
	if #carried == 0 then
		return
	end
	for _, model in ipairs(table.clone(carried)) do
		CarryService.removeCarried(player, model)
		CarryService.scatterToCrater(model)
	end
	Remotes.bannerEvent():FireClient(player, "You dropped your Rotlings!", 3)
end

-- Rebuild a player's saved Rotlings onto their new base's pads.
function CarryService.restorePlaced(player: Player, saved: { State.PlacedEntry })
	local baseId = BaseService.getPlayerBase(player.UserId)
	if not baseId then
		return
	end
	for _, entry in ipairs(saved) do
		local padCf = WorldBuilder.padCFrame(baseId, entry.pad)
		if padCf and (State.placed[baseId] or {})[entry.pad] == nil then
			local model = RotlingFactory.build(entry.def, entry.mut, padCf.Position)
			if model then
				model.Parent = workspace
				CarryService.placeOnPad(player, model, baseId, entry.pad)
			end
		end
	end
end

return CarryService
