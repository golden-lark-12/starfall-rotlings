--!strict
-- Starfall Rotlings: stealing.
-- Anyone can lift a placed Rotling off an unlocked base and carry it
-- home. A locked base bars every steal, and the victim is told at once.
-- The server checks the lock, the pad and the thief's arms before the
-- Rotling moves.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
local RotlingCatalog = require(game:GetService("ReplicatedStorage").Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local RotlingFactory = require(script.Parent.RotlingFactory)

local StealService = {}

local STEAL_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local function playStealSound(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = STEAL_SOUND
	sound.Volume = 0.7
	sound.PlaybackSpeed = 0.7
	sound.Parent = root
	sound:Play()
	task.delay(1, function()
		sound:Destroy()
	end)
end

-- Lift a placed Rotling off a rival's pad and carry it home.
function StealService.trySteal(player: Player, model: Model)
	if not model or not model.Parent then
		return
	end
	local ownerId = model:GetAttribute("OwnerUserId") :: number
	if ownerId == player.UserId then
		Remotes.bannerEvent():FireClient(player, "That one is already yours.", 2)
		return
	end
	local baseId = model:GetAttribute("BaseId") :: number
	if BaseService.isLocked(baseId) then
		Remotes.bannerEvent():FireClient(player, "That base is locked! Come back later.", 3)
		return
	end
	if #CarryService.getCarried(player) >= CarryService.getCarrySlots(player) then
		Remotes.bannerEvent():FireClient(player, "Your arms are full! Buy Extra Arms in the shop.", 3)
		return
	end
	local padIndex = model:GetAttribute("PadIndex") :: number
	BaseService.removePlaced(baseId, padIndex)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local body = model.PrimaryPart
	if not root or not body then
		return
	end
	-- Same carried look as a grab: shrink to head size, bubble it, dim
	-- the wash-out glow and hide the tag — a stolen Rotling must not
	-- be a huge pale block either.
	RotlingFactory.setCarriedVisual(model, true)
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
	model:SetAttribute("BaseId", 0)
	model:SetAttribute("PadIndex", 0)
	CarryService.carryRotling(player, model)
	playStealSound(player)
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	Remotes.bannerEvent():FireClient(player, "Stolen! Get it home before they notice!", 3)
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner then
		local stolenName = if def then def.name else "a Rotling"
		Remotes.bannerEvent():FireClient(owner, player.DisplayName .. " is stealing your " .. stolenName .. "!", 4)
		playStealSound(owner)
	end
end

return StealService
