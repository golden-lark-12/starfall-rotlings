--!strict
-- Starfall Rotlings: missions.
-- One active mission at a time from Config.MISSIONS, rotating in order.
-- Progress is counted on the server only (grabs, places, coins earned);
-- finishing one pays the reward, shows a banner, and moves to the next.
-- The HUD feed carries the active mission so the client can draw the
-- mission bar. Nothing here trusts the client: it only ever reports
-- progress the server itself observed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local FeedbackService = require(script.Parent.FeedbackService)

local MissionService = {}

export type Mission = {
	id: string,
	text: string,
	target: number,
	reward: number,
}

-- The active mission for a profile (index wraps around the list).
function MissionService.currentMission(player: Player): Mission
	local profile = DataService.getProfile(player)
	local index = if profile then profile.missionIndex else 1
	local missions = Config.MISSIONS
	if index < 1 or index > #missions then
		index = 1
	end
	return missions[index]
end

function MissionService.progress(player: Player): number
	local profile = DataService.getProfile(player)
	return if profile then profile.missionProgress else 0
end

-- Report server-observed progress toward the active mission. Only the
-- matching kind counts; anything else is ignored. On completion the
-- reward is paid, the banner fires, and the next mission starts fresh.
function MissionService.addProgress(player: Player, kind: string, amount: number)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local mission = MissionService.currentMission(player)
	if mission.id ~= kind then
		return
	end
	profile.missionProgress += amount
	if profile.missionProgress < mission.target then
		return
	end
	profile.coins += mission.reward
	profile.missionIndex = (profile.missionIndex % #Config.MISSIONS) + 1
	profile.missionProgress = 0
	DataService.saveProfile(player)
	FeedbackService.celebrate(player)
	local nextMission = MissionService.currentMission(player)
	Remotes.bannerEvent():FireClient(player, "🎯 Mission complete! +" .. Formatting.formatMoney(mission.reward) .. " — next: " .. nextMission.text, 5)
end

return MissionService
