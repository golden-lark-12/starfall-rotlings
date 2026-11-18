--!strict
-- Starfall Rotlings: index wall controller (client).
-- The gallery wall near spawn (built by WorldBuilder) has one panel
-- per Rotling, named "IndexWall_<defId>". Panels start dark; this
-- controller lights a panel in its rarity colour once the Rotling is
-- found (from the HUD feed's index set), so the wall is a live
-- progress board in the world, not just a panel in the UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)

local foundSet: { [string]: boolean } = {}

local function refreshWall()
	for _, def in ipairs(RotlingCatalog.DEFS) do
		local panel = workspace:FindFirstChild("IndexWall_" .. def.id, true)
		if panel and panel:IsA("BasePart") then
			local gui = panel:FindFirstChild("IndexPanelGui")
			local frame = gui and gui:FindFirstChild("PanelFrame")
			if frame and frame:IsA("Frame") then
				if foundSet[def.id] then
					frame.BackgroundColor3 = RarityConfig.rarityByName(def.rarity).color
				else
					frame.BackgroundColor3 = Color3.fromRGB(30, 25, 50)
				end
			end
		end
	end
end

Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	foundSet = data.index or {}
	refreshWall()
end)

-- The wall is built at server start; refresh once in case the first
-- HUD feed arrived before the parts replicated.
task.delay(5, refreshWall)

print("Starfall Brainrots index wall ready.")
