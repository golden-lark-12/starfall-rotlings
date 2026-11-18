--!strict
-- Starfall Rotlings: banking.
-- Income accrues at the base (profile.banked), not in the wallet. The
-- player collects it with the HUD Collect button: the whole banked
-- balance moves into the wallet at once. Shop buys, rebirths and
-- rerolls all spend the wallet, so collecting is the tycoon loop's
-- heartbeat — and the base sign above your base shows exactly what is
-- waiting there. Direct payouts (missions, daily, sell, bounty,
-- offline earnings, index rewards) still land in the wallet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local BankService = {}

-- Move everything banked at the base into the wallet.
function BankService.collectBank(player: Player): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	if profile.banked <= 0 then
		return false, "Nothing to collect yet — your Rotlings are still earning."
	end
	local amount = profile.banked
	profile.banked = 0
	profile.coins += amount
	DataService.saveProfile(player)
	return true, "Collected " .. Formatting.formatMoney(amount) .. " from your base!"
end

-- Wire the CollectBank remote function.
function BankService.init()
	Remotes.collectBankFunction().OnServerInvoke = function(player: Player)
		local ok, message = BankService.collectBank(player)
		return ok, message
	end
end

return BankService
