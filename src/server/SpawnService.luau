--!strict
-- Starfall Rotlings: the crater spawner.
-- Rotlings drift into the central crater on a slow timer, never more
-- than five free at once — scarcity is the whole game, so a Rare
-- showing up is a race, not a shopping trip. Every spawn rolls its
-- own rarity and mutation, and the creature comes from that rarity's
-- pool. Free Rotlings ride the conveyor belt: they bob, drift, turn
-- slowly, and wrap from the far end back to the start, so the crater
-- always looks alive instead of parked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local CarryService = require(script.Parent.CarryService)
local RotlingFactory = require(script.Parent.RotlingFactory)

local SpawnService = {}

local running = false
local drift: { [Model]: CFrame } = {}
local seeds: { [Model]: number } = {}
-- Rest height per free Rotling: the body's centre Y when it was
-- registered, i.e. standing ON the belt top (BELT_TOP_Y + half its
-- body height, set by RotlingFactory.build). The drift loop MUST use
-- this stored height. It used to rebuild the base with Y =
-- CRATER_FLOOR_Y (0.4) — the body's centre at the belt's surface
-- level — which sank every Rotling by half its height on the first
-- 0.1s tick, burying the prompt with it.
local restY: { [Model]: number } = {}
-- Prompts wired once per model (weak keys: a destroyed model drops
-- out on its own). placeOnPad re-wires every placed Rotling so a
-- Rotling restored from a save gets its Take prompt; without this
-- guard the fresh-place path would double-connect the same prompt
-- and tryGrab would fire twice.
local connected: { [Model]: boolean } = setmetatable({}, { __mode = "k" })

function SpawnService.countFree(): number
	local n = 0
	for _, thing in ipairs(workspace:GetDescendants()) do
		if thing:IsA("Model") and thing:GetAttribute("State") == "free" then
			n += 1
		end
	end
	return n
end

-- Where every free Rotling in the crater stands right now, so a new
-- spawn can keep its distance instead of piling onto the others.
local function freePositions(): { Vector3 }
	local spots = {}
	for _, thing in ipairs(workspace:GetDescendants()) do
		if thing:IsA("Model") and thing:GetAttribute("State") == "free" then
			local torso = thing.PrimaryPart
			if torso then
				table.insert(spots, torso.Position)
			end
		end
	end
	return spots
end

-- Pick a spawn point ON THE CONVEYOR BELT, at least CRATER_MIN_SPACING
-- studs from every other free Rotling, so their name tags never stack
-- into unreadable text. Tries several random spots along the belt and
-- keeps the first that clears the gap; if none does, keeps the spot
-- farthest from its nearest neighbour.
local function findSpawnPosition(): Vector3
	local others = freePositions()
	local bestSpot: Vector3? = nil
	local bestGap = -1
	for _ = 1, 20 do
		-- On the belt: x along the belt's length, z within the belt's
		-- width, so every Rotling stands on the conveyor in a line.
		-- Y = BELT_TOP_Y - 0.1: RotlingFactory.build seats the body
		-- bottom at position.Y + 0.1, so the body bottom lands exactly
		-- on the belt top (0.65). The old CRATER_FLOOR_Y (0.4) put the
		-- body bottom 0.15 under the belt top at spawn.
		local x = (math.random() * 2 - 1) * Config.BELT_HALF_LENGTH -- on the belt, not past its ends (a spawn past +20 would wrap to -20 on the first travel tick)
		local z = (math.random() * 2 - 1) * Config.BELT_SPAWN_Z
		local try = Vector3.new(x, Config.BELT_TOP_Y - 0.1, z)
		local gap = math.huge
		for _, pos in ipairs(others) do
			local flat = Vector3.new(try.X - pos.X, 0, try.Z - pos.Z)
			gap = math.min(gap, flat.Magnitude)
		end
		if #others == 0 or gap >= Config.CRATER_MIN_SPACING then
			return try
		end
		if gap > bestGap then
			bestGap = gap
			bestSpot = try
		end
	end
	if bestSpot then
		return bestSpot
	end
	local x = (math.random() * 2 - 1) * Config.BELT_HALF_LENGTH -- on the belt, not past its ends (a spawn past +20 would wrap to -20 on the first travel tick)
	local z = (math.random() * 2 - 1) * Config.BELT_SPAWN_Z
	return Vector3.new(x, Config.BELT_TOP_Y - 0.1, z)
end

-- Register a free Rotling for the idle bob and spin. Records the
-- body's rest height (centre Y) so the drift loop can keep it
-- standing ON the belt instead of sinking it to the crater floor
-- level.
function SpawnService.registerFree(model: Model)
	local torso = model.PrimaryPart
	if not torso then
		return
	end
	drift[model] = torso.CFrame
	seeds[model] = math.random() * math.pi * 2
	restY[model] = torso.CFrame.Position.Y
end

function SpawnService.unregister(model: Model)
	drift[model] = nil
	seeds[model] = nil
	restY[model] = nil
end

-- Wire a Rotling's grab prompt to the server's grab logic.
-- Idempotent: a prompt wired once stays wired once, so placeOnPad
-- can safely re-wire a placed Rotling (restored from a save) without
-- double-firing tryGrab on a freshly placed one.
function SpawnService.connectPrompt(model: Model)
	if connected[model] then
		return
	end
	local torso = model.PrimaryPart
	if not torso then
		return
	end
	local prompt = torso:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	connected[model] = true
	prompt.Triggered:Connect(function(player: Player)
		-- [Grab] log: the prompt shows but the playtest said E does
		-- nothing, so the trigger itself must prove it reaches the
		-- server. If this line never prints, the prompt is not
		-- firing; if it prints and nothing is carried, the failure
		-- is inside tryGrab.
		print("[Grab] prompt triggered by " .. player.Name .. " on " .. model.Name)
		CarryService.tryGrab(player, model)
	end)
	-- Seat the prompt to the current carry state: a Rotling spawned
	-- while a player is carrying (at capacity) must not show a live
	-- Grab prompt, and a placed Rotling gets its Take prompt here.
	CarryService.setPromptState(model)
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
		for model, baseCf in pairs(drift) do
			if not model.Parent then
				drift[model] = nil
				seeds[model] = nil
				restY[model] = nil
			else
				local state = model:GetAttribute("State")
				if state ~= "free" then
					drift[model] = nil
					seeds[model] = nil
					restY[model] = nil
				else
					local seed = seeds[model] or 0
					-- Bob 0..0.25, never below rest: the old sin * 0.25
					-- dipped 0.25 UNDER the base every cycle, so the
					-- feet sank into the belt even at the right height.
					local hop = (math.sin(now * 2 + seed) + 1) / 2 * 0.25
					local twist = math.sin(now * 0.5 + seed) * 0.3
					-- Advance along the belt; wrap at the far end.
					-- The stored base moves with the Rotling, so the
					-- bob/spin stays relative to its current spot.
					local aheadX = baseCf.Position.X + Config.BELT_TRAVEL_SPEED * 0.1
					if aheadX > Config.BELT_HALF_LENGTH then
						-- Wrap only onto a clear spot: the old code
						-- teleported straight to -20, so a wrapper
						-- landed on top of whatever was already
						-- riding near the start. If the start is
						-- crowded, wait at the end (still bobbing)
						-- until the lane clears.
						local clear = true
						for other, otherCf in pairs(drift) do
							if other ~= model and other.Parent then
								local flat = Vector3.new(-Config.BELT_HALF_LENGTH - otherCf.Position.X, 0, baseCf.Position.Z - otherCf.Position.Z)
								if flat.Magnitude < Config.CRATER_MIN_SPACING then
									clear = false
									break
								end
							end
						end
						if clear then
							aheadX = -Config.BELT_HALF_LENGTH
						else
							aheadX = Config.BELT_HALF_LENGTH
						end
					end
					-- Face the travel direction (+X): -90 degrees
					-- about Y turns the model's +Z face toward +X.
					local facing = -math.pi / 2 + twist
					-- Rest height from registration, NOT CRATER_FLOOR_Y:
					-- the old code rebuilt the base at Y = 0.4 (the
					-- body's centre at the belt's surface), sinking
					-- the Rotling by half its height on the first tick.
					local restH = restY[model] or baseCf.Position.Y
					local nextPose = CFrame.new(aheadX, restH, baseCf.Position.Z) * CFrame.Angles(0, facing, 0)
					drift[model] = nextPose
					model:PivotTo(nextPose * CFrame.new(0, hop, 0))
				end
			end
		end
	end
end

-- A light beam marks a Rare-or-better (or mutated) spawn: a tall Neon
-- pillar in the rarity colour at the spawn point, fading over 5s, so
-- the whole map can see the race target. Beams are cheap (one part,
-- destroyed after the fade) and only fire for Rare+ — Commons never
-- get one.
local function spawnBeam(spot: Vector3, tint: Color3)
	local beam = Instance.new("Part")
	beam.Name = "SpawnBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(40, 1.2, 1.2)
	beam.Material = Enum.Material.Neon
	beam.Color = tint
	beam.Transparency = 0.25
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CFrame = CFrame.new(spot + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	task.spawn(function()
		for step = 1, 10 do
			task.wait(0.5)
			if beam.Parent then
				beam.Transparency = 0.25 + 0.075 * step
			end
		end
		beam:Destroy()
	end)
end

-- Announce a mutated or Rare-or-better spawn server-wide: mutations
-- were invisible because nothing ever said one had arrived, and a Rare
-- with no mutation spawned in silence. Either kind gets a beam + a
-- banner ("✨ A GOLD Boba Blob spawned in the crater!" / "🌟 A RARE
-- Boba Blob spawned in the crater!") so everyone — players and bots —
-- can race for it. Commons stay silent: a banner every 17 seconds
-- would be noise.
local function announceSpawn(def: RotlingCatalog.RotlingDef, mut: string?, spot: Vector3)
	local tier = RarityConfig.rarityTier(def.rarity)
	if not mut and tier < 2 then
		return
	end
	spawnBeam(spot, RarityConfig.rarityByName(def.rarity).color)
	if mut then
		Remotes.bannerEvent():FireAllClients("✨ A " .. mut:upper() .. " " .. def.name .. " spawned in the crater!", 4)
		print("[Spawn] mutated " .. mut .. " " .. def.name .. " (" .. def.rarity .. ") spawned")
	else
		Remotes.bannerEvent():FireAllClients("🌟 A " .. def.rarity:upper() .. " " .. def.name .. " spawned in the crater!", 4)
		print("[Spawn] rare " .. def.name .. " (" .. def.rarity .. ") spawned")
	end
end

-- Spawn one Rotling of an exact def (and optional mutation) on the
-- crater floor. Used by the forced opening mix in start().
local function spawnForced(id: string, mut: string?): Model?
	local entry = RotlingCatalog.getDef(id)
	if not entry then
		return nil
	end
	local spot = findSpawnPosition()
	local built = RotlingFactory.build(entry.id, mut, spot, 1.5)
	if not built then
		return nil
	end
	built.Parent = workspace
	announceSpawn(entry, mut, spot)
	SpawnService.connectPrompt(built)
	SpawnService.registerFree(built)
	return built
end

function SpawnService.spawnOne(): Model?
	local mutation = MutationConfig.rollMutation()
	local def = RotlingCatalog.rollDef()
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
	announceSpawn(def, mutation, position)
	SpawnService.connectPrompt(model)
	SpawnService.registerFree(model)
	return model
end

-- A belt spot near `near`, at least CRATER_MIN_SPACING from every
-- other free Rotling. Tries the spot itself, then steps along the
-- belt in both directions, then any clear spot on the belt.
local function findNearPosition(near: Vector3): Vector3
	local others = freePositions()
	local function clear(spot: Vector3): boolean
		for _, pos in ipairs(others) do
			local flat = Vector3.new(spot.X - pos.X, 0, spot.Z - pos.Z)
			if flat.Magnitude < Config.CRATER_MIN_SPACING then
				return false
			end
		end
		return true
	end
	local z = math.clamp(near.Z, -Config.BELT_SPAWN_Z, Config.BELT_SPAWN_Z)
	for _, dx in ipairs({ 0, 9, -9, 18, -18 }) do
		local x = math.clamp(near.X + dx, -Config.BELT_HALF_LENGTH, Config.BELT_HALF_LENGTH)
		local spot = Vector3.new(x, Config.BELT_TOP_Y - 0.1, z)
		if clear(spot) then
			return spot
		end
	end
	return findSpawnPosition()
end

-- Spawn a RARE Rotling at an exact spot (a meteor impact point) and
-- leave it grabbable for STORM_RARE_LIFETIME seconds. If nobody grabs
-- it in that time it fades back into the crater (destroyed). Used by
-- the storm: every hero meteor leaves one behind, so the storm is a
-- hunt, not just a hazard. Rarity is rolled from Rare upward.
function SpawnService.spawnRareAt(position: Vector3): Model?
	-- Roll a rarity of Rare (tier 2) or better, weighted like the
	-- normal roll but with Common removed.
	local drawn = RarityConfig.rollRarity()
	local tries = 0
	while RarityConfig.rarityTier(drawn) < 2 and tries < 10 do
		drawn = RarityConfig.rollRarity()
		tries += 1
	end
	if RarityConfig.rarityTier(drawn) < 2 then
		drawn = "Rare"
	end
	local pool = RotlingCatalog.defsOfRarity(drawn)
	if #pool == 0 then
		return nil
	end
	local def = pool[math.random(1, #pool)]
	local mutation = MutationConfig.rollMutation()
	-- Seat it on the belt top, not at the meteor's impact Y: the impact
	-- point sits at CRATER_FLOOR_Y (0.4), 0.25 under the belt, so a rare
	-- built there would spawn sunk. BELT_TOP_Y - 0.1 puts its body
	-- bottom exactly on the belt (build adds +0.1).
	-- Seat it on the belt top NEAR the impact point, spaced from the
	-- other free Rotlings: the old code built it exactly at the
	-- impact point, so a storm that targeted near the player left
	-- several rares piled on top of each other (and on the free
	-- ones already riding the belt).
	local buildPos = findNearPosition(position)
	local built = RotlingFactory.build(def.id, mutation, buildPos, 1.5)
	if not built then
		return nil
	end
	built.Parent = workspace
	announceSpawn(def, mutation, buildPos)
	SpawnService.connectPrompt(built)
	SpawnService.registerFree(built)
	-- A storm rare only stays for its lifetime: after 30s it is gone
	-- if it is still free (nobody grabbed it).
	task.delay(Config.STORM_RARE_LIFETIME, function()
		if built.Parent and built:GetAttribute("State") == "free" then
			SpawnService.unregister(built)
			built:Destroy()
		end
	end)
	return built
end

function SpawnService.start()
	if running then
		return
	end
	running = true
	-- A few Rotlings are already waiting when the first player arrives:
	-- the crater starts with 5 (competition via scarcity: 3-5 at a
	-- time), never empty, never a pile. The opening mix is forced, not
	-- random: several rarity tiers together (Common, Rare, Legendary)
	-- and TWO mutated Rotlings (Gold crumb, Rainbow bloop — the
	-- guarantee, so the player meets mutations in the first minute), so
	-- the hero and base shots always show the ladder and the mutations.
	-- The other three (quokka, avocado, narwhal) roll in later through
	-- the normal spawn.
	local opener: { { defId: string, mutation: string? } } = {
		{ defId = "wombat", mutation = nil },
		{ defId = "boba", mutation = nil },
		{ defId = "puddles", mutation = nil },
		{ defId = "bloop", mutation = "Rainbow" },
		{ defId = "crumb", mutation = "Gold" },
	}
	-- GRADUAL, not all at once: 2 waiting when the first player
	-- arrives, then one more every 3s until the opening mix is out.
	-- A crater that starts with 5 stacked Rotlings reads as a pile;
	-- a few at a time, spread out, reads as a living conveyor.
	local openerDone = false
	task.spawn(function()
		for k, pick in ipairs(opener) do
			if k > 2 then
				task.wait(3)
			end
			spawnForced(pick.defId, pick.mutation)
		end
		openerDone = true
	end)
	task.spawn(animateFree)
	task.spawn(function()
		-- Do not top up while the opening is still staggering, or the
		-- crater fills to the minimum before the gradual opening has
		-- had time to spread out.
		while not openerDone do
			task.wait(1)
		end
		while true do
			task.wait(Config.SPAWN_INTERVAL)
			-- Scarcity: ONE new Brainrot per tick, only while the crater
			-- holds fewer than CRATER_MAX_FREE (5). No fast refill — if
			-- the crater is picked clean it stays thin until the next
			-- tick, and that thinness is the competition: a Rare+ spawn
			-- is a race, not a pile to browse.
			if SpawnService.countFree() < Config.CRATER_MAX_FREE then
				SpawnService.spawnOne()
			end
		end
	end)
end

return SpawnService
