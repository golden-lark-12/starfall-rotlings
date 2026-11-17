--!strict
-- Starfall Rotlings: carrying, placing and dropping.
-- A player grabs a free Rotling in the crater, carries it home on their
-- head and sets it on a pad, where it earns. Dying or a meteor hit drops
-- everything carried back into the crater. Placed Rotlings are handed to
-- StealService by the grab prompt (deferred require: StealService calls
-- back into this module to carry what it lifts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
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

function CarryService.carryRotling(player: Player, model: Model)
	local carried = State.carried[player.UserId]
	if not carried then
		carried = {}
		State.carried[player.UserId] = carried
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
	local index = table.find(carried, model)
	if index then
		table.remove(carried, index)
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
		local baseId = model:GetAttribute("BaseId")
		prompt.ActionText = "Steal " .. name
		prompt.Enabled = not BaseService.isLocked(baseId)
	else
		prompt.ActionText = "Grab " .. name
		prompt.Enabled = true
	end
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
		-- Deferred require: StealService carries what it lifts via this module.
		local StealService = require(script.Parent.StealService)
		StealService.trySteal(player, model)
		return
	end
	if #CarryService.getCarried(player) >= CarryService.getCarrySlots(player) then
		Remotes.bannerEvent():FireClient(player, "Your arms are full! Buy Extra Arms in the shop.", 3)
		return
	end
	if not weldToPlayer(model, player) then
		return
	end
	CarryService.carryRotling(player, model)
	playPickupSound(player)
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	if def then
		IndexService.markFound(player, def.id)
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
	CarryService.placeOnPad(player, carried[1], baseId, padIndex)
end

function CarryService.placeOnPad(player: Player, model: Model, baseId: number, padIndex: number)
	unweld(model)
	CarryService.removeCarried(player, model)
	local padCf = WorldBuilder.padCFrame(baseId, padIndex)
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	local lift = if def then def.size * 0.55 + 0.6 else 2.5
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
	local angle = math.random() * math.pi * 2
	local radius = math.random() * Config.CRATER_RADIUS * 0.8
	local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	local lift = if def then def.size * 0.55 + 0.6 else 2.5
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
	local RotlingFactory = require(script.Parent.RotlingFactory)
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
