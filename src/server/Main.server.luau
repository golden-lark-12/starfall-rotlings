--!strict
print('[Server] boot ok')

-- Starfall Rotlings: server bootstrap.
-- Builds the world, starts every service, wires the remotes, and handles
-- players joining, dying and leaving. One system per module; the server
-- owns every number and the client only ever asks.
--
-- NOTE: this file is Main.server.luau, NOT init.server.luau, on purpose.
-- A folder with an init.server.luau collapses into the Script itself in
-- Rojo, so script.Parent inside it is ServerScriptService and every
-- require(script.Parent.X) fails — the whole server died on line 9 and
-- nothing (no map, no bases, no storm) ever ran. As a plain Script in the
-- Server folder, script.Parent is the folder and the requires resolve.

local Players = game:GetService("Players")

-- Run one startup step, warning (not dying) when it fails, so Studio's
-- Output shows exactly where the boot stops. Returns false on failure.
local function step(name: string, fn: () -> ()): boolean
	local ok, err = pcall(fn)
	if not ok then
		warn("[Server] step failed: " .. name .. " — " .. tostring(err))
	end
	return ok
end

local BaseService = require(script.Parent.BaseService)
local BankService = require(script.Parent.BankService)
local BoostService = require(script.Parent.BoostService)
local BuddyService = require(script.Parent.BuddyService)
local CarryService = require(script.Parent.CarryService)
local DailyService = require(script.Parent.DailyService)
local DataService = require(script.Parent.DataService)
local GlobalEventService = require(script.Parent.GlobalEventService)
local IncomeService = require(script.Parent.IncomeService)
local MissionService = require(script.Parent.MissionService)
local LeaderstatsService = require(script.Parent.LeaderstatsService)
local MeteorEggService = require(script.Parent.MeteorEggService)
local OfflineService = require(script.Parent.OfflineService)
local RaiderService = require(script.Parent.RaiderService)
local RebirthService = require(script.Parent.RebirthService)
local RivalService = require(script.Parent.RivalService)
local SellService = require(script.Parent.SellService)
local ShopService = require(script.Parent.ShopService)
local SlapService = require(script.Parent.SlapService)
local SpawnService = require(script.Parent.SpawnService)
local StarfallService = require(script.Parent.StarfallService)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

-- Build first, then start the services that depend on the world.
-- The map is critical: without it nothing else can run, so a failed map
-- aborts the boot. Every other step warns and continues.
if not step("map (WorldBuilder.build)", WorldBuilder.build) then
	warn("[Server] boot aborted: map failed to build.")
	return
end
step("bases (BaseService.init)", BaseService.init)
step("carry (CarryService.init)", CarryService.init)
step("shop (ShopService.init)", ShopService.init)
step("sell (SellService.init)", SellService.init)
step("bank (BankService.init)", BankService.init)
step("contracts (MissionService.init)", MissionService.init)
step("daily (DailyService.init)", DailyService.init)
step("rebirth (RebirthService.init)", RebirthService.init)
step("income (IncomeService.start)", IncomeService.start)
step("storm (StarfallService.start)", StarfallService.start)
step("spawner (SpawnService.start)", SpawnService.start)
step("raiders (RaiderService.start)", RaiderService.start)
-- Rivals claim bases 5-8 here, before any player is processed below,
-- so a joining player never collides with a rival's base.
step("rivals (RivalService.start)", RivalService.start)
step("eggs (MeteorEggService.init)", MeteorEggService.init)
step("eggs (MeteorEggService.start)", MeteorEggService.start)
step("events (GlobalEventService.start)", GlobalEventService.start)
step("boosts (BoostService.init)", BoostService.init)
step("boosts (BoostService.start)", BoostService.start)
step("buddy (BuddyService.init)", BuddyService.init)
step("slap (SlapService.init)", SlapService.init)

-- Pad prompts: pressing E on any pad asks the server to place the
-- Rotling you carry (it checks the pad is yours and free).
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") and descendant.Parent and descendant.Parent.Name == "Pad" then
		descendant.Triggered:Connect(function(player: Player)
			CarryService.tryPlace(player)
		end)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	ShopService.applyWalkSpeed(player)
	BoostService.applyWalkSpeed(player)
	BuddyService.attachBuddy(player, character)
	-- Spawn at your own base, facing the crater: stand beside the
	-- platform's front corner, so the glowing pads are right beside you
	-- and the crater is straight ahead. (The SpawnLocation alone can't
	-- do this: it is one fixed spot, and your base depends on join order.)
	local baseId = BaseService.getPlayerBase(player.UserId)
	local baseCf = if baseId then WorldBuilder.baseCFrame(baseId) else nil
	if baseCf then
		local side = baseCf * CFrame.new(18, 0, -4)
		local spawnPos = Vector3.new(side.Position.X, 3, side.Position.Z)
		local spawnCf = CFrame.lookAt(spawnPos, Vector3.new(0, 3, 0))
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			root = character:WaitForChild("HumanoidRootPart", 5)
		end
		if root then
			character:PivotTo(spawnCf)
		end
	end
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		-- Dying drops everything you were carrying into the crater.
		CarryService.dropAllCarried(player)
		MeteorEggService.dropEgg(player)
	end)
end

local function onPlayerAdded(player: Player)
	DataService.loadProfile(player)
	LeaderstatsService.createLeaderstats(player)
	local baseId = BaseService.assignBase(player)
	if not baseId then
		player:Kick("Starfall Brainrots is full! All 8 bases are taken. Try again soon.")
		return
	end
	local profile = DataService.getProfile(player)
	if profile then
		-- Profile-load observability (fix round 6, item 1): a fresh
		-- profile on a returning player means the DataStore load
		-- failed — log it, with how many placed Brainrots were
		-- restored, so the next F9 proves whether the profile (and
		-- the money) is loading at all.
		local loaded = State.datastoreOk[player.UserId] == true
		local placedCount = #profile.placed
		local indexCount = 0
		for _ in pairs(profile.index) do
			indexCount += 1
		end
		print("[Starfall] join " .. player.Name .. ": profile " .. (if loaded then "loaded from DataStore" else "FRESH (DataStore load failed or first join)") .. " coins=" .. tostring(profile.coins) .. " banked=" .. tostring(profile.banked) .. " xp=" .. tostring(profile.xp) .. " level=" .. tostring(profile.level) .. " rebirths=" .. tostring(profile.rebirths) .. " index=" .. tostring(indexCount) .. " placedSaved=" .. tostring(placedCount))
		CarryService.restorePlaced(player, profile.placed)
		-- Offline earnings: paid from the restored pads, so the
		-- away-time coins match what the base actually earns.
		OfflineService.awardOffline(player)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	task.delay(2, function()
		IncomeService.broadcastHud()
	end)
end

local function onPlayerRemoving(player: Player)
	CarryService.dropAllCarried(player)
	MeteorEggService.dropEgg(player)
	DataService.saveProfile(player)
	BaseService.freeBase(player)
	DataService.dropProfile(player)
	State.carried[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Save everyone when the server shuts down.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataService.saveProfile(player)
	end
end)

print("Starfall Brainrots server ready.")
