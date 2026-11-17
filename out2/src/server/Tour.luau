--!strict
-- Starfall Rotlings: screenshot scene setters for TOUR.json.
-- Each function arranges one of the four screenshots in the live game:
-- a full hero base, a storm with a Legendary on the run, a raider
-- stealing a Mythic at a rival base, and the Index screen (opened by
-- the I key in TOUR.json). These only ever run in Studio for
-- screenshots, never in normal play.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local MutationConfig = require(game:GetService("ReplicatedStorage").Shared.MutationConfig)
local RarityConfig = require(game:GetService("ReplicatedStorage").Shared.RarityConfig)
local RotlingCatalog = require(game:GetService("ReplicatedStorage").Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local RaiderService = require(script.Parent.RaiderService)
local RotlingFactory = require(script.Parent.RotlingFactory)
local SpawnService = require(script.Parent.SpawnService)
local StarfallService = require(script.Parent.StarfallService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Tour = {}

-- Fill every pad of every base with glowing Rotlings of mixed rarities
-- and mutations, so the hero shot shows the whole ladder at once.
function Tour.hero(_arg: string?)
	for baseId = 1, Config.BASE_COUNT do
		for padIndex = 1, Config.PADS_PER_BASE do
			local padCf = WorldBuilder.padCFrame(baseId, padIndex)
			if padCf then
				local rarity = RarityConfig.ORDER[math.random(1, #RarityConfig.ORDER)]
				local defs = RotlingCatalog.defsOfRarity(rarity)
				if #defs == 0 then
					defs = RotlingCatalog.DEFS
				end
				local def = defs[math.random(1, #defs)]
				local mutation = MutationConfig.rollMutation()
				local model = RotlingFactory.build(def.id, mutation, padCf.Position)
				if model then
					model.Parent = workspace
					model:SetAttribute("State", "placed")
					model:SetAttribute("BaseId", baseId)
					model:SetAttribute("PadIndex", padIndex)
					for _, part in ipairs(model:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Anchored = true
						end
					end
					model:PivotTo(padCf * CFrame.new(0, def.size * 0.55 + 0.6, 0))
					CarryService.setPromptState(model)
				end
			end
		end
	end
	return "hero bases filled with mixed rarities"
end

-- Start the storm and drop a Legendary in the crater to run home with.
function Tour.storm(_arg: string?)
	StarfallService.forceStorm()
	local defs = RotlingCatalog.defsOfRarity("Legendary")
	local def = defs[math.random(1, #defs)]
	local model = RotlingFactory.build(def.id, nil, Vector3.new(6, 0, 4))
	if model then
		model.Parent = workspace
		SpawnService.connectPrompt(model)
		SpawnService.registerFree(model)
	end
	return "storm started"
end

-- Put a Mythic on base 2's pads, unlocked, with a Raider mid-steal.
function Tour.steal(_arg: string?)
	local defs = RotlingCatalog.defsOfRarity("Mythic")
	local def = defs[math.random(1, #defs)]
	local padCf = WorldBuilder.padCFrame(2, 2)
	if padCf then
		local model = RotlingFactory.build(def.id, "Gold", padCf.Position)
		if model then
			model.Parent = workspace
			model:SetAttribute("State", "placed")
			model:SetAttribute("OwnerUserId", 0)
			model:SetAttribute("BaseId", 2)
			model:SetAttribute("PadIndex", 2)
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			model:PivotTo(padCf * CFrame.new(0, def.size * 0.55 + 0.6, 0))
			CarryService.setPromptState(model)
			SpawnService.connectPrompt(model)
			-- A raider stands beside the Mythic, sack in hand.
			RaiderService.spawnRaiderForTour(2, 2)
		end
	end
	return "mythic placed on base 2 with a raider"
end

return Tour
