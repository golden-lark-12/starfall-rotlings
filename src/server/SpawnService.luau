--!strict
-- Starfall Rotlings: the crater spawner.
-- Rotlings wander into the central crater on a timer, up to ten free at
-- once. Rarity and mutation are rolled per spawn (see RarityConfig and
-- MutationConfig), and the creature is picked from that rarity's pool
-- (see RotlingCatalog). Free Rotlings bob and slowly spin so the crater
-- always looks alive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local CarryService = require(script.Parent.CarryService)
local RotlingFactory = require(script.Parent.RotlingFactory)

local SpawnService = {}

local running = false
local bobBases: { [Model]: CFrame } = {}
local bobSeeds: { [Model]: number } = {}

function SpawnService.countFree(): number
	local count = 0
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:GetAttribute("State") == "free" then
			count += 1
		end
	end
	return count
end

-- Wire a Rotling's grab prompt to the server's grab logic.
function SpawnService.connectPrompt(model: Model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local prompt = body:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		CarryService.tryGrab(player, model)
	end)
end

-- Register a free Rotling for the idle bob and spin.
function SpawnService.registerFree(model: Model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	bobBases[model] = body.CFrame
	bobSeeds[model] = math.random() * math.pi * 2
end

function SpawnService.unregister(model: Model)
	bobBases[model] = nil
	bobSeeds[model] = nil
end

-- Bob every free Rotling up and down and turn it slowly.
local function animateFree()
	while true do
		task.wait(0.1)
		local now = time()
		for model, baseCf in pairs(bobBases) do
			if not model.Parent then
				bobBases[model] = nil
				bobSeeds[model] = nil
			else
				local state = model:GetAttribute("State")
				if state ~= "free" then
					bobBases[model] = nil
					bobSeeds[model] = nil
				else
					local seed = bobSeeds[model] or 0
					local bob = math.sin(now * 2 + seed) * 0.25
					local spin = math.sin(now * 0.5 + seed) * 0.3
					model:PivotTo(baseCf * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, 0))
				end
			end
		end
	end
end

function SpawnService.spawnOne(): Model?
	local def = RotlingCatalog.rollDef()
	local mutation = MutationConfig.rollMutation()
	local angle = math.random() * math.pi * 2
	local radius = math.random() * Config.CRATER_RADIUS * 0.8
	-- Spawn on the crater floor (top of the crater disc), never at Y=0:
	-- the disc sits above the ground, so Y=0 buries the Rotling in it.
	local position = Vector3.new(math.cos(angle) * radius, Config.CRATER_FLOOR_Y, math.sin(angle) * radius)
	local model = RotlingFactory.build(def.id, mutation, position)
	if not model then
		return nil
	end
	model.Parent = workspace
	SpawnService.connectPrompt(model)
	SpawnService.registerFree(model)
	return model
end

function SpawnService.start()
	if running then
		return
	end
	running = true
	-- A few Rotlings are already waiting when the first player arrives.
	for _ = 1, 5 do
		SpawnService.spawnOne()
	end
	task.spawn(animateFree)
	task.spawn(function()
		while true do
			task.wait(Config.SPAWN_INTERVAL)
			if SpawnService.countFree() < Config.CRATER_MAX_FREE then
				SpawnService.spawnOne()
			end
		end
	end)
end

return SpawnService
