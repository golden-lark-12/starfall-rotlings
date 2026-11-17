-- Starfall Rotlings: coins, shop, rebirth and saves.
-- The server owns every number: the client only asks to buy, and the
-- server checks the price. One DataStore, one key per player, versioned
-- records, autosave + leave + shutdown saves. If DataStore is unavailable
-- (a Studio playtest without API access), the player keeps playing on a
-- session-only profile and nothing is overwritten.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RotlingData = require(ReplicatedStorage.Shared.RotlingData)
local State = require(script.Parent.State)
local Bases = require(script.Parent.Bases)

local Economy = {}

local Remotes -- set by init()
local store: DataStore?

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

local function defaultProfile()
	return {
		version = Config.SAVE_VERSION,
		coins = 0,
		rebirths = 0,
		speedTier = 0,
		carryTier = 0,
		incomeTier = 0,
		index = {},
		placed = {},
	}
end

local function reconcile(data): { [string]: any }
	local profile = defaultProfile()
	if typeof(data) ~= "table" then
		return profile
	end
	for key, value in pairs(data) do
		profile[key] = value
	end
	profile.version = Config.SAVE_VERSION
	if typeof(profile.index) ~= "table" then
		profile.index = {}
	end
	if typeof(profile.placed) ~= "table" then
		profile.placed = {}
	end
	return profile
end

function Economy.loadProfile(player: Player)
	local profile = defaultProfile()
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

function Economy.saveProfile(player: Player)
	local profile = State.profiles[player.UserId]
	if not profile then
		return false
	end
	profile.placed = Bases.snapshotPlaced(player)
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

-- -- Income ------------------------------------------------------------------

function Economy.incomeMult(player: Player): number
	local profile = State.profiles[player.UserId]
	if not profile then
		return 1
	end
	return (1 + Config.REBIRTH_MULT_PER * profile.rebirths)
		* (1 + Config.INCOME_TIER_MULT * profile.incomeTier)
end

function Economy.coinsPerSecond(player: Player): number
	local total = 0
	for _, model in ipairs(Bases.getPlacedForPlayer(player)) do
		local def = RotlingData.getDef(model:GetAttribute("DefId") or "")
		if def then
			total += RotlingData.baseCps(def, model:GetAttribute("Mutation"))
		end
	end
	return math.floor(total * Economy.incomeMult(player))
end

function Economy.getCoins(player: Player): number
	local profile = State.profiles[player.UserId]
	return if profile then profile.coins else 0
end

-- -- Shop and rebirth ---------------------------------------------------------

function Economy.buyItem(player: Player, itemName: string): (boolean, string)
	local profile = State.profiles[player.UserId]
	if not profile then
		return false, "Profile not loaded yet."
	end
	local item = Config.SHOP[itemName]
	if not item then
		return false, "No such shop item."
	end
	local tierKey = itemName == "Speed" and "speedTier" or itemName == "Carry" and "carryTier" or "incomeTier"
	local tier = profile[tierKey]
	if tier >= #item.tiers then
		return false, item.label .. " is maxed out!"
	end
	local cost = item.tiers[tier + 1]
	if profile.coins < cost then
		return false, "Not enough coins! Need $" .. tostring(cost) .. "."
	end
	profile.coins -= cost
	profile[tierKey] = tier + 1
	if itemName == "Speed" then
		Economy.applyWalkSpeed(player)
	end
	Economy.saveProfile(player)
	return true, item.label .. " upgraded to tier " .. tostring(tier + 1) .. "!"
end

function Economy.doRebirth(player: Player): (boolean, string)
	local profile = State.profiles[player.UserId]
	if not profile then
		return false, "Profile not loaded yet."
	end
	local cost = Config.rebirthCost(profile.rebirths)
	if profile.coins < cost then
		return false, "Rebirth costs $" .. tostring(cost) .. ". Keep earning!"
	end
	profile.coins = 0
	profile.rebirths += 1
	Economy.saveProfile(player)
	return true, "Rebirth " .. tostring(profile.rebirths) .. "! Income x" .. string.format("%.2f", Economy.incomeMult(player)) .. " forever."
end

function Economy.applyWalkSpeed(player: Player)
	local profile = State.profiles[player.UserId]
	local tier = if profile then profile.speedTier else 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.BASE_WALKSPEED + Config.SPEED_PER_TIER * tier
	end
end

-- -- Loops ----------------------------------------------------------------------

function Economy.start(remotesModule)
	Remotes = remotesModule

	-- Coin tick: pay every placed Rotling's income once a second.
	task.spawn(function()
		while true do
			task.wait(Config.TICK_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = State.profiles[player.UserId]
				if profile then
					profile.coins += Economy.coinsPerSecond(player)
				end
			end
			Remotes.broadcastHud()
		end
	end)

	-- Autosave, staggered by join order so servers do not spike together.
	task.spawn(function()
		while true do
			task.wait(Config.SAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				Economy.saveProfile(player)
				task.wait(1)
			end
		end
	end)
end

return Economy
