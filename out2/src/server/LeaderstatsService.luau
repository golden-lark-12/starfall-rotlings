--!strict
-- Starfall Rotlings: leaderstats.
-- Coins and Rebirths on the leaderboard, kept in step with the profile
-- by the income tick and by every purchase and rebirth.

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local LeaderstatsService = {}

-- Build the leaderstats folder for a joining player.
function LeaderstatsService.createLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = folder
	folder.Parent = player
	LeaderstatsService.refresh(player)
end

-- Copy the profile's numbers onto the leaderboard values.
function LeaderstatsService.refresh(player: Player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local coins = folder:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value = profile.coins
	end
	local rebirths = folder:FindFirstChild("Rebirths")
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = profile.rebirths
	end
end

return LeaderstatsService
