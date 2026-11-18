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
		return false, "Nothing to collect yet — your Brainrots are still earning."
	end
	local amount = profile.banked
	profile.banked = 0
	profile.coins += amount
	DataService.saveProfile(player)
	return true, "Collected " .. Formatting.formatMoney(amount) .. " from your base!"
end

-- Total wealth: wallet + uncollected base cash. The HUD big number,
-- the rebirth bar and the leaderboard all show this (fix 3) — income
-- banks at the base, so the wallet alone is not what the player has.
function BankService.totalWealth(player: Player): number
	local profile = DataService.getProfile(player)
	if not profile then
		return 0
	end
	return profile.coins + profile.banked
end

-- Spend from total wealth (fix 3): shop buys and rebirths used to
-- check the wallet only, so a player with $9,000 in the wallet and
-- $5,000 at the base could not buy a $10,000 item even though they
-- had $14,000. Now, if the wallet is short but the total covers the
-- cost, the shortfall is collected from the base first, then the cost
-- is deducted from the wallet. Returns true when the purchase went
-- through.
function BankService.spendFromTotal(player: Player, cost: number): boolean
	local profile = DataService.getProfile(player)
	if not profile then
		return false
	end
	if profile.coins + profile.banked < cost then
		return false
	end
	if profile.coins < cost then
		local shortfall = cost - profile.coins
		profile.banked -= shortfall
		profile.coins += shortfall
	end
	profile.coins -= cost
	return true
end

-- Wire the CollectBank remote function.
function BankService.init()
	Remotes.collectBankFunction().OnServerInvoke = function(player: Player)
		local ok, message = BankService.collectBank(player)
		return ok, message
	end
end

return BankService
