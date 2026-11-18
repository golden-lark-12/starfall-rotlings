--!strict
-- Starfall Rotlings: selling.
-- The gold SELL pad sits on the path between spawn and the crater. Press
-- E on it: it sells ONLY the Brainrot you are carrying. Empty hands =
-- nothing happens (and the banner says so) — the pad NEVER sells a
-- Brainrot placed on your base. Fix round 2's sellPlaced fallback (sell
-- the best placed Rotling when empty-handed) is gone: it wiped a whole
-- base one E press at a time, because every press sold one more placed
-- Rotling. The sold model is destroyed, and the payout (baseCps x
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
	-- Refresh the HUD NOW (not on the next 1s tick) so the payout is
	-- visible the moment the Brainrot leaves your hands. Deferred
	-- require: IncomeService does not require this module back.
	local IncomeService = require(script.Parent.IncomeService)
	IncomeService.broadcastHud()
	print("[Sell] " .. player.Name .. " sold carried " .. def.name .. " for " .. tostring(value))
	FeedbackService.playSound(player, 1.4, 0.7)
	local character = player.Character
	if character then
		FeedbackService.cashPopup(character, "+" .. Formatting.formatMoney(value))
	end
	return true, "💰 Sold " .. def.name .. " for " .. Formatting.formatMoney(value) .. "!"
end


-- Sell: ONLY the carried Rotling. Empty hands = nothing happens (the
-- banner says to carry one first). Placed Rotlings are NEVER sold by
-- the pad — the sellPlaced fallback that sold one placed Rotling per
-- E press (and so wiped a whole base) is removed. One entry point for
-- the remote and the pad prompt.
function SellService.sell(player: Player): (boolean, string)
	-- [Sell] log (fix round 4, item 2): every attempt and its result
	-- must show in Output, so the next playtest can prove the pad
	-- sold nothing with empty hands.
	local carried = CarryService.getCarried(player)
	local placedCount = #BaseService.getPlacedForPlayer(player)
	print("[Sell] attempt by " .. player.Name .. " (carried=" .. tostring(#carried) .. ", placed=" .. tostring(placedCount) .. ")")
	local ok, message
	if #carried > 0 then
		ok, message = SellService.sellCarried(player)
	else
		ok, message = false, "Carry a Brainrot to sell it"
	end
	print("[Sell] result for " .. player.Name .. ": " .. tostring(ok) .. " — " .. message)
	return ok, message
end

-- Wire the SellRotling remote and the SELL pad's prompt.
function SellService.init()
	Remotes.sellEvent().OnServerEvent:Connect(function(player: Player)
		local ok, message = SellService.sell(player)
		Remotes.bannerEvent():FireClient(player, message, 3)
	end)
	-- [Sell] wiring log (fix round 4, item 2): the pad prompt must
	-- prove it was found and wired at boot. If this warns, pressing E
	-- on the SELL pad can never reach sell() — the prompt shows but
	-- nothing is connected to it.
	local pad = workspace:FindFirstChild("SellPad")
	if not pad then
		warn("[Sell] SellPad NOT FOUND in workspace — pad selling disabled (remote only)")
		return
	end
	local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn("[Sell] SellPad has no ProximityPrompt — pad selling disabled (remote only)")
		return
	end
	print("[Sell] SELL pad prompt wired (pad=" .. pad.Name .. ", prompt=" .. prompt.ActionText .. ")")
	prompt.Triggered:Connect(function(player: Player)
		local ok, message = SellService.sell(player)
		Remotes.bannerEvent():FireClient(player, message, 3)
	end)
end

return SellService
