--!strict
-- Starfall Rotlings: rebirths.
-- Reset your coins to zero for a permanent +25% income per rebirth, and
-- your base takes on a new colour so the whole map can see how far you
-- have climbed. The price grows with the square of your rebirth count.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local FeedbackService = require(script.Parent.FeedbackService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local RebirthService = {}

-- One colour per rebirth, cycling through the palette.
RebirthService.COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(120, 255, 150),
	Color3.fromRGB(255, 220, 100),
	Color3.fromRGB(200, 140, 255),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(100, 230, 230),
	Color3.fromRGB(255, 130, 200),
} :: { Color3 }

function RebirthService.rebirthCost(rebirths: number): number
	return Config.REBIRTH_BASE_COST * (rebirths + 1) * (rebirths + 1)
end

function RebirthService.incomeMult(rebirths: number): number
	return 1 + Config.REBIRTH_MULT_PER * rebirths
end

-- Reset coins for a permanent multiplier and a new base colour.
function RebirthService.doRebirth(player: Player): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	local cost = RebirthService.rebirthCost(profile.rebirths)
	if profile.coins < cost then
		return false, "Rebirth costs " .. Formatting.formatMoney(cost) .. ". Keep earning!"
	end
	profile.coins = 0
	profile.rebirths += 1
	local baseId = BaseService.getPlayerBase(player.UserId)
	if baseId then
		local color = RebirthService.COLORS[(profile.rebirths - 1) % #RebirthService.COLORS + 1]
		WorldBuilder.setBaseColor(baseId, color)
	end
	DataService.saveProfile(player)
	local LeaderstatsService = require(script.Parent.LeaderstatsService)
	LeaderstatsService.refresh(player)
	FeedbackService.celebrate(player)
	local character = player.Character
	if character then
		FeedbackService.cashPopup(character, "Income x" .. string.format("%.2f", RebirthService.incomeMult(profile.rebirths)), Color3.fromRGB(255, 110, 180))
	end
	return true, "Rebirth " .. tostring(profile.rebirths) .. "! Income x"
		.. string.format("%.2f", RebirthService.incomeMult(profile.rebirths))
		.. " forever, and your base wears a new colour."
end

-- Wire the DoRebirth remote function.
function RebirthService.init()
	Remotes.rebirthFunction().OnServerInvoke = function(player: Player)
		local ok, message = RebirthService.doRebirth(player)
		return ok, message
	end
	-- The rebirth altar prompt opens the Rebirth panel on the client
	-- (HUDController listens for the event).
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Parent and descendant.Parent.Name == "RebirthPrompt" then
			descendant.Triggered:Connect(function(player: Player)
				Remotes.openRebirthEvent():FireClient(player)
			end)
		end
	end
end

return RebirthService
