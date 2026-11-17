--!strict
-- Starfall Rotlings: selling.
-- The gold SELL pad sits on the path between spawn and the crater. Carry
-- a Rotling onto it and press E: the server takes the first Rotling you
-- carry, pays ~25 seconds of its income (baseCps x Config.SELL_MULT),
-- and destroys the model. Selling is for clearing a pad to make room
-- for a better Rotling — placing always pays more in the long run. The
-- client never decides the price: the server computes it from the
-- Rotling's own definition and mutation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local FeedbackService = require(script.Parent.FeedbackService)
local MissionService = require(script.Parent.MissionService)

local SellService = {}

-- What one Rotling sells for: ~25 seconds of its own income.
function SellService.sellValue(def: RotlingCatalog.RotlingDef, mutation: string?): number
	return math.floor(RotlingCatalog.baseCps(def, mutation) * Config.SELL_MULT)
end

-- Sell the first Rotling the player is carrying. Returns (ok, message).
function SellService.sellCarried(player: Player): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	local carried = CarryService.getCarried(player)
	if #carried == 0 then
		return false, "Carry a Rotling to the SELL pad first!"
	end
	local model = carried[1]
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	if not def then
		return false, "That Rotling has no price."
	end
	local mutation = model:GetAttribute("Mutation") :: string?
	local value = SellService.sellValue(def, mutation)
	-- Clear the carry slot first, then destroy the model: the slot
	-- must never read as full after a sale.
	CarryService.removeCarried(player, model)
	model:Destroy()
	-- Selling can change the best buddy (highest income).
	local BuddyService = require(script.Parent.BuddyService)
	BuddyService.refreshBuddy(player)
	profile.coins += value
	MissionService.addProgress(player, "earn", value)
	DataService.saveProfile(player)
	FeedbackService.playSound(player, 1.4, 0.7)
	local character = player.Character
	if character then
		FeedbackService.cashPopup(character, "+" .. Formatting.formatMoney(value))
	end
	return true, "💰 Sold " .. def.name .. " for " .. Formatting.formatMoney(value) .. "!"
end

-- Wire the SellRotling remote and the SELL pad's prompt.
function SellService.init()
	Remotes.sellEvent().OnServerEvent:Connect(function(player: Player)
		local ok, message = SellService.sellCarried(player)
		Remotes.bannerEvent():FireClient(player, message, 3)
	end)
	local pad = workspace:FindFirstChild("SellPad")
	if pad then
		local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				local ok, message = SellService.sellCarried(player)
				Remotes.bannerEvent():FireClient(player, message, 3)
			end)
		end
	end
end

return SellService
