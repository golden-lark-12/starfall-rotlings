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
-- BaseService does NOT require MissionService, so a top-level require
-- here is safe (no circular require). It is only needed for the live
-- placed count in syncPlaceMission.
local BaseService = require(script.Parent.BaseService)

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

-- Complete the active mission: pay the reward, advance to the next
-- mission, save, celebrate, banner. Shared by addProgress and
-- syncPlaceMission so the two paths cannot drift.
local function completeMission(player: Player, profile, mission: Mission)
	profile.coins += mission.reward
	profile.missionIndex = (profile.missionIndex % #Config.MISSIONS) + 1
	profile.missionProgress = 0
	DataService.saveProfile(player)
	FeedbackService.celebrate(player)
	local nextMission = MissionService.currentMission(player)
	Remotes.bannerEvent():FireClient(player, "🎯 Mission complete! +" .. Formatting.formatMoney(mission.reward) .. " — next: " .. nextMission.text, 5)
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
	completeMission(player, profile, mission)
	-- The next mission might be a "place" mission the player already
	-- satisfies (14 placed, 0/3 shown): sync it now, or it would sit
	-- at 0 until they place 3 more.
	MissionService.syncPlaceMission(player)
end

-- Sync the "place" mission to the live placed count (fix round 4,
-- item 3): the quest said "Place 3 Brainrots on your base 0/3" while
-- the player already had 14 placed, because addProgress only counts
-- placements while "place" is the ACTIVE mission — placements made
-- while other missions were active never counted. The live count is
-- the truth: if the player already has enough placed, the mission
-- completes now. Called on join/restore (CarryService.restorePlaced)
-- and after every mission completion (addProgress).
function MissionService.syncPlaceMission(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	local mission = MissionService.currentMission(player)
	if mission.id ~= "place" then
		return
	end
	local placed = #BaseService.getPlacedForPlayer(player)
	if placed <= profile.missionProgress then
		return -- only move forward; never rewind progress
	end
	profile.missionProgress = placed
	if placed < mission.target then
		return
	end
	completeMission(player, profile, mission)
	-- The next mission might also be a "place" mission (the list has
	-- two "place" entries): sync again.
	MissionService.syncPlaceMission(player)
end

return MissionService
