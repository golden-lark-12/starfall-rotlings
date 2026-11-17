--!strict
-- Starfall Rotlings: server bootstrap.
-- Builds the world, starts every service, wires the remotes, and handles
-- players joining, dying and leaving. One system per module; the server
-- owns every number and the client only ever asks.

local Players = game:GetService("Players")

local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local LeaderstatsService = require(script.Parent.LeaderstatsService)
local RaiderService = require(script.Parent.RaiderService)
local RebirthService = require(script.Parent.RebirthService)
local ShopService = require(script.Parent.ShopService)
local SpawnService = require(script.Parent.SpawnService)
local StarfallService = require(script.Parent.StarfallService)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

-- Build first, then start the services that depend on the world.
WorldBuilder.build()
BaseService.init()
CarryService.init()
ShopService.init()
RebirthService.init()
IncomeService.start()
StarfallService.start()
SpawnService.start()
RaiderService.start()

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
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		-- Dying drops everything you were carrying into the crater.
		CarryService.dropAllCarried(player)
	end)
end

local function onPlayerAdded(player: Player)
	DataService.loadProfile(player)
	LeaderstatsService.createLeaderstats(player)
	local baseId = BaseService.assignBase(player)
	if not baseId then
		player:Kick("Starfall Rotlings is full! All 8 bases are taken. Try again soon.")
		return
	end
	local profile = DataService.getProfile(player)
	if profile then
		CarryService.restorePlaced(player, profile.placed)
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

print("Starfall Rotlings server ready.")
