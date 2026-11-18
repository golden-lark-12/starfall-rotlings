--!strict
-- Starfall Rotlings: offline earnings.
-- Your Rotlings keep earning while you are away. On join, the server
-- pays coins-per-second for the time since your last save, capped at
-- OFFLINE_CAP_SECONDS (8 hours), and tells the client to pop the
-- "While you were away..." panel. First joiners (lastSeen 0) and
-- players with nothing placed earn nothing and see no popup.
--
-- Called from Main.server.luau right after the placed Rotlings are
-- restored, because coinsPerSecond is computed from the restored pads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local OfflineService = {}

-- Pay the away-time earnings and show the popup. Returns the amount
-- paid (0 when nothing is owed).
function OfflineService.awardOffline(player: Player): number
	local profile = DataService.getProfile(player)
	if not profile then
		return 0
	end
	if profile.lastSeen == 0 then
		return 0 -- first join: no away time on record
	end
	local away = os.time() - profile.lastSeen
	if away <= 0 then
		return 0
	end
	away = math.min(away, Config.OFFLINE_CAP_SECONDS)
	local cps = IncomeService.coinsPerSecond(player)
	local earned = math.floor(cps * away)
	if earned <= 0 then
		return 0 -- nothing placed: nothing earned
	end
	profile.coins += earned
	print("[Offline] " .. player.Name .. " was away " .. tostring(away) .. "s at " .. tostring(cps) .. "/s, earned " .. tostring(earned))
	-- The popup fires a few seconds after join, so the client's
	-- OfflineController is listening before it arrives.
	task.delay(4, function()
		if player.Parent then
			Remotes.offlineEvent():FireClient(player, earned)
		end
	end)
	return earned
end

return OfflineService
