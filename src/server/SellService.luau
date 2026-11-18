--!strict
-- Starfall Rotlings: selling.
-- The gold SELL pad sits on the path between spawn and the crater. Press
-- E on it: it sells the Rotling you carry, or — if you carry none — the
-- highest-value Brainrot placed on your own base (the playtest showed
-- selling only worked while carrying, so a player with Rotlings on their
-- base got "Carry a Brainrot first!" and no money). The sold model is
-- removed from its pad and destroyed, and the payout (baseCps x
-- Config.SELL_MULT, ~25 seconds of its income) lands in the wallet.
-- Selling is for clearing a pad to make room for a better Rotling —
-- placing always pays more in the long run. The client never decides
-- the price: the server computes it from the Rotling's own definition
-- and mutation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
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
		return false, "Carry a Brainrot to the SELL pad first!"
	end
	local model = carried[1]
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	if not def then
		return false, "That Brainrot has no price."
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

-- Sell the best Rotling placed on the player's own base. The playtest
-- showed the sell only worked for a CARRIED Rotling: a player standing
-- at the SELL pad with Rotlings on their base got "Carry a Rotling to
-- the SELL pad first!" and no money, so selling read as broken. Now the
-- pad sells the carried Rotling if there is one, else the highest-value
-- placed Rotling on the player's own base — the model is removed from
-- its pad (it disappears from the base) and the payout lands in the
-- wallet. The banner names which Rotling was sold and the exact amount.
function SellService.sellPlaced(player: Player): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	local baseId = BaseService.getPlayerBase(player.UserId)
	if not baseId then
		return false, "You have no base yet."
	end
	local placed = BaseService.getPlacedForPlayer(player)
	if #placed == 0 then
		return false, "Nothing to sell — grab a Brainrot first!"
	end
	-- Highest value wins: the most expensive Rotling on the base.
	local best: Model? = nil
	local bestValue = -1
	for _, model in ipairs(placed) do
		local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
		if def then
			local value = SellService.sellValue(def, model:GetAttribute("Mutation") :: string?)
			if value > bestValue then
				bestValue = value
				best = model
			end
		end
	end
	if not best then
		return false, "That Brainrot has no price."
	end
	local def = RotlingCatalog.getDef(best:GetAttribute("DefId") :: string)
	local mutation = best:GetAttribute("Mutation") :: string?
	local value = bestValue
	-- Remove it from its pad first, then destroy the model: the pad
	-- must read as free and the Rotling must be gone from the base.
	local padIndex = best:GetAttribute("PadIndex") :: number?
	if padIndex then
		BaseService.removePlaced(baseId, padIndex)
	end
	best:Destroy()
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
	return true, "💰 Sold " .. (if def then def.name else "Brainrot") .. " for " .. Formatting.formatMoney(value) .. "!"
end

-- Sell: the carried Rotling first, else the best placed one on the
-- player's own base. One entry point for the remote and the pad prompt.
function SellService.sell(player: Player): (boolean, string)
	local carried = CarryService.getCarried(player)
	if #carried > 0 then
		return SellService.sellCarried(player)
	end
	return SellService.sellPlaced(player)
end

-- Wire the SellRotling remote and the SELL pad's prompt.
function SellService.init()
	Remotes.sellEvent().OnServerEvent:Connect(function(player: Player)
		local ok, message = SellService.sell(player)
		Remotes.bannerEvent():FireClient(player, message, 3)
	end)
	local pad = workspace:FindFirstChild("SellPad")
	if pad then
		local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				local ok, message = SellService.sell(player)
				Remotes.bannerEvent():FireClient(player, message, 3)
			end)
		end
	end
end

return SellService
