--!strict
-- Starfall Rotlings: the daily reward.
-- One claim per cooldown (Config.DAILY_COOLDOWN, 20h) from the HUD Daily
-- button. The server owns the clock: the client only asks, and the
-- server checks lastDailyClaim before any coins move. The HUD feed
-- carries dailyReady so the button can show whether a claim is up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local DailyService = {}

-- Is a daily claim up for this player right now?
function DailyService.isReady(player: Player): boolean
	local profile = DataService.getProfile(player)
	if not profile then
		return false
	end
	return os.time() - profile.lastDailyClaim >= Config.DAILY_COOLDOWN
end

-- Claim the daily reward. Returns (ok, message).
function DailyService.claimDaily(player: Player): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	if not DailyService.isReady(player) then
		local waitSecs = Config.DAILY_COOLDOWN - (os.time() - profile.lastDailyClaim)
		local waitHours = math.ceil(waitSecs / 3600)
		return false, "Daily already claimed — come back in ~" .. tostring(waitHours) .. "h."
	end
	profile.lastDailyClaim = os.time()
	profile.coins += Config.DAILY_REWARD
	DataService.saveProfile(player)
	return true, "🎁 Daily reward! +" .. Formatting.formatMoney(Config.DAILY_REWARD)
end

-- Wire the ClaimDaily remote function.
function DailyService.init()
	Remotes.dailyFunction().OnServerInvoke = function(player: Player)
		local ok, message = DailyService.claimDaily(player)
		return ok, message
	end
end

return DailyService
