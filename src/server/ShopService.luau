--!strict
-- Starfall Rotlings: the shop.
-- Five ladders, all bought with coins the server owns: walk speed, extra
-- arms, income, extra base pads and longer base locks. The client only
-- asks to buy; the server checks the price and the tier before a coin
-- moves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BankService = require(script.Parent.BankService)
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
		tiers = { 200, 800, 4000 },
	},
	Carry = {
		label = "Extra Arms",
		desc = "+1 Rotling carried per tier",
		tiers = { 400, 2500 },
	},
	Income = {
		label = "Golden Trough",
		desc = "+25% base income per tier",
		tiers = { 600, 2000, 8000 },
	},
	Pads = {
		label = "Extra Pad",
		desc = "+1 base pad per tier (max 8)",
		tiers = { 1500, 6000 },
	},
	Lock = {
		label = "Longer Lock",
		desc = "+30s base lock per tier",
		tiers = { 800, 3000 },
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
	-- Spend from total wealth (fix 3): the wallet alone is not what
	-- the player has — income banks at the base. spendFromTotal
	-- collects the shortfall from the base first, then deducts, so
	-- the big HUD number is spendable.
	if not BankService.spendFromTotal(player, cost) then
		return false, "Not enough coins! Need " .. Formatting.formatMoney(cost) .. "."
	end
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

-- Reroll the mutation of your best placed Rotling for Stardust.
-- A new mutation is rolled (Gold / Diamond / Frozen / Rainbow); a plain
-- Rotling can come back mutated, and a mutated one can come back plain
-- or with a different mutation. Returns (ok, message).
function ShopService.rerollMutation(player: Player): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	if profile.stardust < Config.REROLL_STARDUST_COST then
		return false, "Mutation reroll costs 30 Stardust — earn more from meteor eggs and daily rewards."
	end
	local BaseService = require(script.Parent.BaseService)
	local placed = BaseService.getPlacedForPlayer(player)
	if #placed == 0 then
		return false, "Place a Rotling on your base first, then reroll its mutation."
	end
	-- Best = highest base income.
	local RotlingCatalog = require(game:GetService("ReplicatedStorage").Shared.RotlingCatalog)
	local MutationConfig = require(game:GetService("ReplicatedStorage").Shared.MutationConfig)
	local RotlingFactory = require(script.Parent.RotlingFactory)
	local best: Model? = nil
	local bestCps = -1
	for _, model in ipairs(placed) do
		local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
		if def then
			local cps = RotlingCatalog.baseCps(def, nil)
			if cps > bestCps then
				bestCps = cps
				best = model
			end
		end
	end
	if not best then
		return false, "No Rotling to reroll."
	end
	local mutation = MutationConfig.rollMutation()
	profile.stardust -= Config.REROLL_STARDUST_COST
	best:SetAttribute("Mutation", mutation or "")
	RotlingFactory.applyMutationVisual(best, mutation)
	DataService.saveProfile(player)
	FeedbackService.celebrate(player)
	local def = RotlingCatalog.getDef(best:GetAttribute("DefId") :: string)
	local name = if def then def.name else "Your Rotling"
	if mutation then
		local mut = MutationConfig.mutationByName(mutation)
		local mult = if mut then mut.mult else 1
		return true, "✦ " .. name .. " is now " .. mutation .. " x" .. tostring(mult) .. "!"
	end
	return true, name .. " came back plain — reroll again for another shot."
end

-- Wire the BuyItem remote function.
function ShopService.init()
	Remotes.buyFunction().OnServerInvoke = function(player: Player, itemName: string)
		local ok, message = ShopService.buyItem(player, itemName)
		return ok, message
	end
	Remotes.rerollFunction().OnServerInvoke = function(player: Player)
		local ok, message = ShopService.rerollMutation(player)
		return ok, message
	end
	Remotes.buyBoostFunction().OnServerInvoke = function(player: Player, kind: string)
		local BoostService = require(script.Parent.BoostService)
		local ok, message = BoostService.buyBoost(player, kind)
		return ok, message
	end
	-- World prompts: the Star Shop floor and each upgrade machine open
	-- the Shop UI on the client (ShopController listens for the event).
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			if descendant.Parent and descendant.Parent.Name == "ShopPrompt" then
				descendant.Triggered:Connect(function(player: Player)
					Remotes.openShopEvent():FireClient(player, "shop")
				end)
			elseif descendant.Parent and descendant.Parent.Name == "UpgradePrompt" then
				descendant.Triggered:Connect(function(player: Player)
					Remotes.openShopEvent():FireClient(player, "upgrade")
				end)
			end
		end
	end
end

return ShopService
