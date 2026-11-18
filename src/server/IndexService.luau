--!strict
-- Starfall Rotlings: the Index.
-- Every Rotling a player has grabbed or placed is logged here. Cards stay
-- greyed out until found. Completing one rarity's set pays coins; finding
-- all twenty pay a big reward once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local DataService = require(script.Parent.DataService)

local IndexService = {}

-- Log a Rotling as found, and pay any completion reward it triggers.
function IndexService.markFound(player: Player, defId: string)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local firstTime = profile.index[defId] == nil
	profile.index[defId] = true
	if not firstTime then
		return
	end
	local def = RotlingCatalog.getDef(defId)
	if not def then
		return
	end
	-- Whole rarity set found? Pay once per rarity.
	local setComplete = true
	for _, other in ipairs(RotlingCatalog.defsOfRarity(def.rarity)) do
		if profile.index[other.id] == nil then
			setComplete = false
			break
		end
	end
	if setComplete and profile.indexRewards[def.rarity] == nil then
		profile.indexRewards[def.rarity] = true
		profile.coins += Config.INDEX_RARITY_REWARD
		-- THE CHASE goal: a BIG celebration when a rarity tier is
		-- completed — long banner + a bright chime, not just the
		-- small text the old code showed.
		Remotes.bannerEvent():FireClient(player, "🎉 " .. def.rarity:upper() .. " SET COMPLETE! Every " .. def.rarity .. " Brainrot found! +" .. Formatting.formatMoney(Config.INDEX_RARITY_REWARD) .. "! 🎉", 6)
		local FeedbackService = require(script.Parent.FeedbackService)
		FeedbackService.playSound(player, 1.8, 0.9)
	end
	-- All twenty found? Pay the big reward once.
	if not profile.indexFullRewarded then
		local found = 0
		for _ in pairs(profile.index) do
			found += 1
		end
		if found >= #RotlingCatalog.DEFS then
			profile.indexFullRewarded = true
			profile.coins += Config.INDEX_FULL_REWARD
			Remotes.bannerEvent():FireClient(player, "🏆 INDEX COMPLETE! All 20 Brainrots found! +" .. Formatting.formatMoney(Config.INDEX_FULL_REWARD) .. "! 🏆", 6)
			local FeedbackService = require(script.Parent.FeedbackService)
			FeedbackService.playSound(player, 2.0, 1.0)
		end
	end
end

-- Log a mutation as found. The Index shows which of the six
-- mutations this player has collected; the first find of each pays a
-- small banner (no coins — the mutation's multiplier IS the reward).
-- Called on grab and on place, like markFound (a mutated Rotling
-- placed from a save counts too). The "" attribute on an unmutated
-- Rotling is not a mutation.
function IndexService.markMutationFound(player: Player, mutation: string?)
	if not mutation or mutation == "" then
		return
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	if profile.mutations[mutation] then
		return
	end
	profile.mutations[mutation] = true
	local mut = MutationConfig.mutationByName(mutation)
	local mult = if mut then mut.mult else 1
	Remotes.bannerEvent():FireClient(player, "✦ New mutation found: " .. mutation .. " (x" .. tostring(mult) .. ")!", 4)
	print("[Index] " .. player.Name .. " found mutation " .. mutation .. " (x" .. tostring(mult) .. ")")
end

-- How many Rotlings this player has found, of the twenty.
function IndexService.foundCount(player: Player): number
	local profile = DataService.getProfile(player)
	if not profile then
		return 0
	end
	local found = 0
	for _ in pairs(profile.index) do
		found += 1
	end
	return found
end

return IndexService
