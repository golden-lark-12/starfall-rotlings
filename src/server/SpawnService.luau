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

-- Positions of every free Rotling in the crater, so a new spawn can
-- keep its distance instead of piling onto the others.
local function freePositions(): { Vector3 }
	local out = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:GetAttribute("State") == "free" then
			local body = descendant.PrimaryPart
			if body then
				table.insert(out, body.Position)
			end
		end
	end
	return out
end

-- Pick a spawn point ON THE CONVEYOR BELT, at least CRATER_MIN_SPACING
-- studs from every other free Rotling, so their name tags never stack
-- into unreadable text. Tries several random spots along the belt and
-- keeps the first that clears the gap; if none does, keeps the spot
-- farthest from its nearest neighbour.
local function findSpawnPosition(): Vector3
	local others = freePositions()
	local best: Vector3? = nil
	local bestGap = -1
	for _ = 1, 12 do
		-- On the belt: x along the belt's length, z within the belt's
		-- width, so every Rotling stands on the conveyor in a line.
		local x = (math.random() * 2 - 1) * Config.CRATER_RADIUS * 0.85
		local z = (math.random() * 2 - 1) * Config.BELT_SPAWN_Z
		local candidate = Vector3.new(x, Config.CRATER_FLOOR_Y, z)
		local gap = math.huge
		for _, pos in ipairs(others) do
			local flat = Vector3.new(candidate.X - pos.X, 0, candidate.Z - pos.Z)
			gap = math.min(gap, flat.Magnitude)
		end
		if #others == 0 or gap >= Config.CRATER_MIN_SPACING then
			return candidate
		end
		if gap > bestGap then
			bestGap = gap
			best = candidate
		end
	end
	if best then
		return best
	end
	local x = (math.random() * 2 - 1) * Config.CRATER_RADIUS * 0.85
	local z = (math.random() * 2 - 1) * Config.BELT_SPAWN_Z
	return Vector3.new(x, Config.CRATER_FLOOR_Y, z)
end

function SpawnService.spawnOne(): Model?
	local def = RotlingCatalog.rollDef()
	local mutation = MutationConfig.rollMutation()
	-- Spawn on the crater floor (top of the crater disc), never at Y=0:
	-- the disc sits above the ground, so Y=0 buries the Rotling in it.
	-- Spaced at least CRATER_MIN_SPACING from every other free Rotling.
	local position = findSpawnPosition()
	-- Crater spawns build at 1.5x so they read from the path.
	local model = RotlingFactory.build(def.id, mutation, position, 1.5)
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
	-- A few Rotlings are already waiting when the first player arrives:
	-- the conveyor starts full (CRATER_INITIAL), never empty.
	for _ = 1, Config.CRATER_INITIAL do
		SpawnService.spawnOne()
	end
	task.spawn(animateFree)
	task.spawn(function()
		while true do
			task.wait(Config.SPAWN_INTERVAL)
			-- The conveyor never drops below CRATER_MIN_FREE: top it
			-- back up fast so there is always something to grab.
			while SpawnService.countFree() < Config.CRATER_MIN_FREE
				and SpawnService.countFree() < Config.CRATER_MAX_FREE do
				SpawnService.spawnOne()
			end
			if SpawnService.countFree() < Config.CRATER_MAX_FREE then
				SpawnService.spawnOne()
			end
		end
	end)
end

return SpawnService
