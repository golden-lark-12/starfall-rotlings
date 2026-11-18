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
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local CarryService = require(script.Parent.CarryService)
local RotlingFactory = require(script.Parent.RotlingFactory)

local SpawnService = {}

local running = false
local bobBases: { [Model]: CFrame } = {}
local bobSeeds: { [Model]: number } = {}
-- Prompts wired once per model (weak keys: a destroyed model drops
-- out on its own). placeOnPad re-wires every placed Rotling so a
-- Rotling restored from a save gets its Take prompt; without this
-- guard the fresh-place path would double-connect the same prompt
-- and tryGrab would fire twice.
local connected: { [Model]: boolean } = setmetatable({}, { __mode = "k" })

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
-- Idempotent: a prompt wired once stays wired once, so placeOnPad
-- can safely re-wire a placed Rotling (restored from a save) without
-- double-firing tryGrab on a freshly placed one.
function SpawnService.connectPrompt(model: Model)
	if connected[model] then
		return
	end
	local body = model.PrimaryPart
	if not body then
		return
	end
	local prompt = body:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	connected[model] = true
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

-- Bob, spin and BELT TRAVEL for free Rotlings. This is the ONLY loop
-- that moves a free Rotling: RotlingFactory.startIdleMotion handles
-- placed Rotlings only, so the two loops never fight over the same
-- model (the old fight tipped Rotlings over). A free Rotling walks
-- along the belt (+X) at BELT_TRAVEL_SPEED, bobbing and spinning as it
-- goes, and wraps from the far end back to the start — a real
-- conveyor, not a bob in place. The stored base CFrame advances with
-- it, so the bob/spin is always relative to where the Rotling is now,
-- not where it spawned. It faces its travel direction (+X) so it reads
-- as walking, not sliding sideways.
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
					-- Advance along the belt; wrap at the far end.
					-- The stored base moves with the Rotling, so the
					-- bob/spin stays relative to its current spot.
					local newX = baseCf.Position.X + Config.BELT_TRAVEL_SPEED * 0.1
					if newX > Config.BELT_HALF_LENGTH then
						newX = -Config.BELT_HALF_LENGTH
					end
					-- Face the travel direction (+X): -90 degrees
					-- about Y turns the model's +Z face toward +X.
					local yaw = -math.pi / 2 + spin
					local newBase = CFrame.new(newX, Config.CRATER_FLOOR_Y, baseCf.Position.Z) * CFrame.Angles(0, yaw, 0)
					bobBases[model] = newBase
					model:PivotTo(newBase * CFrame.new(0, bob, 0))
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
		local x = (math.random() * 2 - 1) * Config.BELT_HALF_LENGTH -- on the belt, not past its ends (a spawn past +20 would wrap to -20 on the first travel tick)
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
	local x = (math.random() * 2 - 1) * Config.BELT_HALF_LENGTH -- on the belt, not past its ends (a spawn past +20 would wrap to -20 on the first travel tick)
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

-- Spawn a RARE Rotling at an exact spot (a meteor impact point) and
-- leave it grabbable for STORM_RARE_LIFETIME seconds. If nobody grabs
-- it in that time it fades back into the crater (destroyed). Used by
-- the storm: every hero meteor leaves one behind, so the storm is a
-- hunt, not just a hazard. Rarity is rolled from Rare upward.
function SpawnService.spawnRareAt(position: Vector3): Model?
	-- Roll a rarity of Rare (tier 2) or better, weighted like the
	-- normal roll but with Common removed.
	local rarityName = RarityConfig.rollRarity()
	local tries = 0
	while RarityConfig.rarityTier(rarityName) < 2 and tries < 10 do
		rarityName = RarityConfig.rollRarity()
		tries += 1
	end
	if RarityConfig.rarityTier(rarityName) < 2 then
		rarityName = "Rare"
	end
	local defs = RotlingCatalog.defsOfRarity(rarityName)
	if #defs == 0 then
		return nil
	end
	local def = defs[math.random(1, #defs)]
	local mutation = MutationConfig.rollMutation()
	local model = RotlingFactory.build(def.id, mutation, position, 1.5)
	if not model then
		return nil
	end
	model.Parent = workspace
	SpawnService.connectPrompt(model)
	SpawnService.registerFree(model)
	-- A storm rare only stays for its lifetime: after 30s it is gone
	-- if it is still free (nobody grabbed it).
	task.delay(Config.STORM_RARE_LIFETIME, function()
		if model.Parent and model:GetAttribute("State") == "free" then
			SpawnService.unregister(model)
			model:Destroy()
		end
	end)
	return model
end

-- Spawn one Rotling of an exact def (and optional mutation) on the
-- crater floor. Used by the forced opening mix in start().
local function spawnForced(defId: string, mutation: string?): Model?
	local def = RotlingCatalog.getDef(defId)
	if not def then
		return nil
	end
	local position = findSpawnPosition()
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
	-- the conveyor starts full (CRATER_INITIAL), never empty. The
	-- opening mix is forced, not random: several rarity tiers together
	-- (Common, Rare, Epic, Legendary, Mythic) and at least 2 mutated
	-- Rotlings, so the hero and base shots always show the ladder and
	-- the mutations (item 13).
	local opening: { { defId: string, mutation: string? } } = {
		{ defId = "wombat", mutation = nil },
		{ defId = "boba", mutation = nil },
		{ defId = "puddles", mutation = nil },
		{ defId = "avocado", mutation = nil },
		{ defId = "crumb", mutation = "Gold" },
		{ defId = "quokka", mutation = nil },
		{ defId = "bloop", mutation = "Rainbow" },
		{ defId = "narwhal", mutation = nil },
	}
	-- GRADUAL, not all at once: 2 waiting when the first player
	-- arrives, then one more every 3s until the opening mix is out.
	-- A crater that starts with 8 stacked Rotlings reads as a pile;
	-- a few at a time, spread out, reads as a living conveyor.
	local openingDone = false
	task.spawn(function()
		for i, entry in ipairs(opening) do
			if i > 2 then
				task.wait(3)
			end
			spawnForced(entry.defId, entry.mutation)
		end
		for _ = 1, Config.CRATER_INITIAL - #opening do
			task.wait(3)
			SpawnService.spawnOne()
		end
		openingDone = true
	end)
	task.spawn(animateFree)
	task.spawn(function()
		-- Do not top up while the opening is still staggering, or the
		-- crater fills to the minimum before the gradual opening has
		-- had time to spread out.
		while not openingDone do
			task.wait(1)
		end
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
