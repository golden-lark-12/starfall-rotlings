--!strict
-- Starfall Rotlings: the shop.
-- Five ladders, all bought with coins the server owns: walk speed, extra
-- arms, income, extra base pads and longer base locks. The client only
-- asks to buy; the server checks the price and the tier before a coin
-- moves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local FeedbackService = require(script.Parent.FeedbackService)

export type ShopItem = {
	label: string,
	desc: string,
	tiers: { number },
}

local ShopService = {}

ShopService.SHOP = {
	Speed = {
		label = "Speed Boots",
		desc = "+2 WalkSpeed per tier",
		tiers = { 250, 1000, 5000 },
	},
	Carry = {
		label = "Extra Arms",
		desc = "+1 Rotling carried per tier",
		tiers = { 500, 3000 },
	},
	Income = {
		label = "Golden Trough",
		desc = "+25% base income per tier",
		tiers = { 750, 2500, 10000 },
	},
	Pads = {
		label = "Extra Pad",
		desc = "+1 base pad per tier (max 8)",
		tiers = { 2000, 8000 },
	},
	Lock = {
		label = "Longer Lock",
		desc = "+30s base lock per tier",
		tiers = { 1000, 4000 },
	},
} :: { [string]: ShopItem }

local TIER_KEYS = {
	Speed = "speedTier",
	Carry = "carryTier",
	Income = "incomeTier",
	Pads = "padsTier",
	Lock = "lockTier",
} :: { [string]: string }

-- Buy the next tier of an item. Returns (ok, message).
function ShopService.buyItem(player: Player, itemName: string): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	local item = ShopService.SHOP[itemName]
	if not item then
		return false, "No such shop item."
	end
	local tierKey = TIER_KEYS[itemName] :: string
	local tier = (profile :: any)[tierKey] :: number
	if tier >= #item.tiers then
		return false, item.label .. " is maxed out!"
	end
	local cost = item.tiers[tier + 1]
	if profile.coins < cost then
		return false, "Not enough coins! Need " .. Formatting.formatMoney(cost) .. "."
	end
	profile.coins -= cost
	local writable = profile :: any
	writable[tierKey] = tier + 1
	if itemName == "Speed" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local Config = require(ReplicatedStorage.Shared.Config)
			humanoid.WalkSpeed = Config.BASE_WALKSPEED + Config.SPEED_PER_TIER * profile.speedTier
		end
	elseif itemName == "Pads" then
		BaseService.unlockPad(player)
	end
	DataService.saveProfile(player)
	FeedbackService.celebrate(player)
	return true, item.label .. " upgraded to tier " .. tostring(tier + 1) .. "!"
end

-- Apply the player's speed tier to a fresh character.
function ShopService.applyWalkSpeed(player: Player)
	local profile = DataService.getProfile(player)
	local tier = if profile then profile.speedTier else 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local Config = require(ReplicatedStorage.Shared.Config)
		humanoid.WalkSpeed = Config.BASE_WALKSPEED + Config.SPEED_PER_TIER * tier
	end
end

-- Wire the BuyItem remote function.
function ShopService.init()
	Remotes.buyFunction().OnServerInvoke = function(player: Player, itemName: string)
		local ok, message = ShopService.buyItem(player, itemName)
		return ok, message
	end
end

return ShopService
