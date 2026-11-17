--!strict
-- Starfall Rotlings: player profiles and saves.
-- One DataStore, one key per player, versioned records, autosave + leave
-- + shutdown saves. If DataStore is unavailable (a Studio playtest
-- without API access), the player keeps playing on a session-only
-- profile and nothing is overwritten.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local DataService = {}

local store: DataStore? = nil

local function getStore(): DataStore?
	if store ~= nil then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	end
	return store
end

function DataService.defaultProfile(): State.Profile
	return {
		version = Config.SAVE_VERSION,
		coins = 0,
		rebirths = 0,
		speedTier = 0,
		carryTier = 0,
		incomeTier = 0,
		padsTier = 0,
		lockTier = 0,
		index = {},
		indexRewards = {},
		indexFullRewarded = false,
		placed = {},
		missionIndex = 1,
		missionProgress = 0,
		lastDailyClaim = 0,
	}
end

local function reconcile(data: any): State.Profile
	local profile = DataService.defaultProfile()
	if typeof(data) ~= "table" then
		return profile
	end
	for key, value in pairs(data) do
		(profile :: any)[key] = value
	end
	profile.version = Config.SAVE_VERSION
	if typeof(profile.index) ~= "table" then
		profile.index = {}
	end
	if typeof(profile.indexRewards) ~= "table" then
		profile.indexRewards = {}
	end
	if typeof(profile.placed) ~= "table" then
		profile.placed = {}
	end
	if profile.padsTier == nil then
		profile.padsTier = 0
	end
	if profile.lockTier == nil then
		profile.lockTier = 0
	end
	return profile
end

-- Load a player's record (3 tries), falling back to a fresh profile.
function DataService.loadProfile(player: Player): State.Profile
	local profile = DataService.defaultProfile()
	local ds = getStore()
	if ds then
		for _ = 1, 3 do
			local ok, data = pcall(function()
				return ds:GetAsync("User_" .. tostring(player.UserId))
			end)
			if ok then
				if data ~= nil then
					profile = reconcile(data)
				end
				State.datastoreOk[player.UserId] = true
				break
			end
			task.wait(1)
		end
	end
	State.profiles[player.UserId] = profile
	return profile
end

-- Save a player's record now. Returns false when there is no store.
function DataService.saveProfile(player: Player): boolean
	local profile = State.profiles[player.UserId]
	if not profile then
		return false
	end
	local BaseService = require(script.Parent.BaseService)
	profile.placed = BaseService.snapshotPlaced(player)
	local ds = getStore()
	if not ds then
		return false
	end
	local ok = pcall(function()
		ds:SetAsync("User_" .. tostring(player.UserId), profile)
	end)
	if ok then
		State.datastoreOk[player.UserId] = true
	end
	return ok
end

function DataService.getProfile(player: Player): State.Profile?
	return State.profiles[player.UserId]
end

function DataService.dropProfile(player: Player)
	State.profiles[player.UserId] = nil
	State.datastoreOk[player.UserId] = nil
end

return DataService
