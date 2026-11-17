-- Starfall Rotlings: screenshot scene setters for TOUR.json.
-- Each function arranges one of the four screenshots in the live game:
-- a full hero base, a storm with a Legendary on the run, a steal at a
-- rival base, and the Index screen (opened by the I key in TOUR.json).
-- These only ever run in Studio for screenshots, never in normal play.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RotlingData = require(game:GetService("ReplicatedStorage").Shared.RotlingData)
local Bases = require(script.Parent.Bases)
local RotlingFactory = require(script.Parent.RotlingFactory)
local Spawner = require(script.Parent.Spawner)
local Storm = require(script.Parent.Storm)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Tour = {}

-- Fill every pad of every base with glowing high-rarity Rotlings.
function Tour.hero(_arg: string?)
	for baseId = 1, Config.BASE_COUNT do
		for padIndex = 1, Config.PADS_PER_BASE do
			local padCf = WorldBuilder.padCFrame(baseId, padIndex)
			if padCf then
				local defs = RotlingData.defsOfRarity("Legendary")
				if #defs == 0 then
					defs = RotlingData.DEFS
				end
				local def = defs[math.random(1, #defs)]
				local model = RotlingFactory.build(def.id, "Rainbow", padCf.Position)
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
					Bases.setPromptState(model)
				end
			end
		end
	end
	return "hero base filled"
end

-- Start the storm and drop a Legendary in the crater to run home with.
function Tour.storm(_arg: string?)
	Storm.forceStorm()
	local defs = RotlingData.defsOfRarity("Legendary")
	local def = defs[math.random(1, #defs)]
	local model = RotlingFactory.build(def.id, nil, Vector3.new(6, 0, 4))
	if model then
		model.Parent = workspace
		Spawner.connectPrompt(model)
	end
	return "storm started"
end

-- Put a Mythic on base 2's pads, unlocked, ready to steal.
function Tour.steal(_arg: string?)
	local defs = RotlingData.defsOfRarity("Mythic")
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
			Bases.setPromptState(model)
			Spawner.connectPrompt(model)
		end
	end
	return "mythic placed on base 2"
end

return Tour
