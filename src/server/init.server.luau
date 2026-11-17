-- Starfall Rotlings: server bootstrap.
-- Builds the world, starts the spawner, the storm and the economy, wires
-- the remotes, and handles players joining, dying and leaving.

local Players = game:GetService("Players")

local Bases = require(script.Parent.Bases)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)
local Spawner = require(script.Parent.Spawner)
local State = require(script.Parent.State)
local Storm = require(script.Parent.Storm)
local WorldBuilder = require(script.Parent.WorldBuilder)

-- Build first, then wire the modules that depend on the world.
WorldBuilder.build()
Bases.init(Remotes)
Remotes.init()
Economy.start(Remotes)
Storm.start(Remotes)
Spawner.start()

-- Pad prompts: pressing E on any pad asks the server to place the
-- Rotling you carry (it checks the pad is yours and free).
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") and descendant.Parent and descendant.Parent.Name == "Pad" then
		descendant.Triggered:Connect(function(player: Player)
			Bases.tryPlace(player)
		end)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	Economy.applyWalkSpeed(player)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		-- Dying drops everything you were carrying into the crater.
		Bases.dropAllCarried(player)
	end)
end

local function onPlayerAdded(player: Player)
	Economy.loadProfile(player)
	local baseId = Bases.assignBase(player)
	if not baseId then
		player:Kick("Starfall Rotlings is full! All 8 bases are taken. Try again soon.")
		return
	end
	local profile = State.profiles[player.UserId]
	if profile then
		Bases.restorePlaced(player, profile.placed)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	Remotes.fireBanner(player, "Welcome to Starfall Rotlings! Grab a Rotling in the crater!", 5)
	task.delay(2, function()
		Remotes.broadcastHud()
	end)
end

local function onPlayerRemoving(player: Player)
	Bases.dropAllCarried(player)
	Economy.saveProfile(player)
	Bases.freeBase(player)
	State.profiles[player.UserId] = nil
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
		Economy.saveProfile(player)
	end
end)

print("Starfall Rotlings server ready.")
