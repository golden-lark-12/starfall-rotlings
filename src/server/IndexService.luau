--!strict
-- Starfall Rotlings: the Index.
-- Every Rotling a player has grabbed or placed is logged here. Cards stay
-- greyed out until found. Completing one rarity's set pays coins; finding
-- all twenty pay a big reward once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
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
		Remotes.bannerEvent():FireClient(player, "Index: every " .. def.rarity .. " found! +" .. Formatting.formatMoney(Config.INDEX_RARITY_REWARD) .. "!", 4)
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
			Remotes.bannerEvent():FireClient(player, "INDEX COMPLETE! All 12 Brainrots found! +" .. Formatting.formatMoney(Config.INDEX_FULL_REWARD) .. "!", 6)
		end
	end
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
