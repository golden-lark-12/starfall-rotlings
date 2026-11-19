--!strict
-- Starfall Rotlings: the meteor storm.
-- Every 90 seconds a storm sweeps the crater: ten seconds of warning
-- while the sky darkens, then eight seconds of falling meteors. Anyone
-- caught in the crater drops what they are carrying and takes damage.
-- Get home before it hits, or drop your catch. A free Rotling near an
-- impact may survive it and come back Starstruck, worth four times as
-- much — the only way that mutation is ever earned.
--
-- The storm is also a hunt: three giant hero meteors arc across the
-- sky at storm start, half the rain meteors aim near a player in the
-- crater (so 6-10 crash close enough to shake the camera), and every
-- hero impact — plus a quarter of the rain impacts — leaves a rare
-- Rotling at the impact point for 30 seconds. STORM START and
-- METEOR LANDED are logged to Output so a playtest can prove the storm
-- actually fired.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local CarryService = require(script.Parent.CarryService)
local RotlingFactory = require(script.Parent.RotlingFactory)
local SpawnService = require(script.Parent.SpawnService)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local StarfallService = {}

local ALARM_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local phase = "calm" -- calm | warn | storm
local phaseEndsAt = 0
local lastPhaseChangeAt = 0 -- wall-clock time of the last setPhase
local running = false
local stormActive = false -- true only while meteors fall; guards the lightning flash from racing restoreSky
local rumbleSound: Sound? = nil -- the low storm rumble, looping while the storm runs

-- Calm length (seconds between storms). Declared BEFORE getStatus:
-- a local defined after its first use resolves to a nil global inside
-- the earlier function, so getStatus called the calm length on nil and
-- every caller (income, rivals, raiders, HUD, bounty, events, offline
-- earnings) died with "StarfallService:49: attempt to call a nil value".
-- That one nil call killed money, competition, HUD and bounty together.
local function calmDuration(): number
	return Config.STORM_PERIOD - Config.STORM_WARN - Config.STORM_DURATION
end

function StarfallService.getStatus()
	-- "Meteor Danger" (cheap win 8): 0 when the next storm is far away,
	-- filling to 1 as it approaches, full during warn and storm.
	local danger = 0
	if phase == "warn" or phase == "storm" then
		danger = 1
	elseif phase == "calm" then
		local total = calmDuration()
		local left = math.max(0, phaseEndsAt - time())
		danger = if total > 0 then math.clamp(1 - left / total, 0, 1) else 0
	end
	return {
		phase = phase,
		-- time() is wall-clock seconds since the server started. os.clock()
		-- is CPU time: in a quiet Studio session it barely advances, so a
		-- countdown built on it never moves and the storm never fires.
		secondsLeft = math.max(0, math.ceil(phaseEndsAt - time())),
		danger = danger,
	}
end

local function setPhase(newPhase: string, duration: number)
	phase = newPhase
	phaseEndsAt = time() + duration
	lastPhaseChangeAt = time()
	if newPhase == "calm" then
		print("[Starfall] Calm: next storm in " .. tostring(duration) .. "s.")
	elseif newPhase == "warn" then
		print("[Starfall] Warning: storm in " .. tostring(duration) .. "s.")
	elseif newPhase == "storm" then
		print("[Starfall] STORM START")
	end
end

-- Wait out the current phase (calm, warn or storm) without ever
-- spinning: the loop wakes every half second to re-check the clock.
local function waitPhase()
	while time() < phaseEndsAt do
		task.wait(0.5)
	end
end

-- Storm palette: a dark RED sky, not just dim. The storm darkens the
-- world and turns it red, so the threat reads even before a meteor
-- falls. These must restore to the bright base lighting in
-- default.project.json (Brightness 1.8, ClockTime 12.5, Ambient
-- 0.9/0.88/0.95, OutdoorAmbient 1/1/1, Atmosphere Density 0.08):
-- a storm darkens the world, it never leaves it dark.
-- The storm dark is SOFTENED (Brightness 1.2, not 0.9) so the storm
-- shot stays readable at thumbnail size: the wall, the dome, the base
-- and the (x2) income readout must all read in the same frame.
-- (Fix round 2, lighting: base Brightness lowered 3 -> 2 and Bloom
-- 0.35 -> 0.15 so nothing glows white; the storm dark follows it
-- down 1.5 -> 1.2 so the storm still reads darker than calm. Fix
-- round 4, item 7: base Brightness 2 -> 1.8 and Bloom 0.15 -> 0.1,
-- one more step down so nothing glows white; the storm dark stays
-- 1.2, still darker than calm.)
local function dimSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.7
		atmosphere.Color = Color3.fromRGB(200, 60, 50)
	end
	Lighting.ClockTime = 14.0
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.new(0.45, 0.25, 0.3)
	Lighting.OutdoorAmbient = Color3.new(0.65, 0.4, 0.45)
end

local function restoreSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.08
		atmosphere.Color = Color3.fromRGB(166, 191, 255)
	end
	Lighting.ClockTime = 12.5
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.new(0.9, 0.88, 0.95)
	Lighting.OutdoorAmbient = Color3.new(1.0, 1.0, 1.0)
end

local function playAlarm()
	local sound = Instance.new("Sound")
	sound.SoundId = ALARM_SOUND
	sound.Volume = 0.8
	-- (fix round 7, item 4) 0.6 was a low tone phone speakers barely
	-- reproduce — the storm siren read as silence. 0.8 is still low
	-- and alarming, but audible.
	sound.PlaybackSpeed = 0.8
	sound.Parent = workspace
	sound:Play()
	task.delay(2, function()
		sound:Destroy()
	end)
end

-- Thunder: the built-in ping pitched right down, a distant boom.
local function playThunder()
	local sound = Instance.new("Sound")
	sound.SoundId = ALARM_SOUND
	sound.Volume = 0.9
	-- (fix round 7, item 4) 0.25 was below what phone speakers
	-- reproduce — thunder was silent. 0.4 is still a deep boom.
	sound.PlaybackSpeed = 0.4
	sound.Parent = workspace
	sound:Play()
	task.delay(2, function()
		sound:Destroy()
	end)
end

-- The storm rumble: the built-in ping pitched right down and looped,
-- a low drone under the whole storm. Starts when the storm starts,
-- stops when it ends. One sound only; a second start is a no-op.
local function startRumble()
	if rumbleSound then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "StormRumble"
	sound.SoundId = ALARM_SOUND
	-- (fix round 7, item 4) 0.2 pitch / 0.4 volume was inaudible on
	-- phone speakers — the whole storm droned silently. 0.35 / 0.6
	-- is still low, but heard.
	sound.Volume = 0.6
	sound.PlaybackSpeed = 0.35
	sound.Looped = true
	sound.Parent = workspace
	sound:Play()
	rumbleSound = sound
end

local function stopRumble()
	if rumbleSound then
		rumbleSound:Stop()
		rumbleSound:Destroy()
		rumbleSound = nil
	end
end

-- One lightning flash: the sky whites out for a blink, then falls back
-- to the storm dark. Guarded by stormActive so a flash racing the end
-- of the storm can never leave the brightness stuck dark.
local function lightningFlash()
	if not stormActive then
		return
	end
	Lighting.Brightness = 6
	playThunder()
	task.wait(0.12)
	if stormActive then
		Lighting.Brightness = 1.2
	end
end

-- Is a position on a base INTERIOR (a safe zone)? The dome protects
-- the platform top only (fix round 9, item 4 — Malek: "safe INSIDE
-- the base, no damage there; the problem is only the door"). A player
-- standing in the doorway/ramp is OUTSIDE the safe zone, so a storm
-- still hurts there and meteors can still target it. The old radial
-- check (17 studs from the centre) counted the doorway as safe.
local function onBase(position: Vector3): boolean
	for baseId = 1, Config.BASE_COUNT do
		if WorldBuilder.isOnBaseInterior(baseId, position) then
			return true
		end
	end
	return false
end

-- A free Rotling near an impact may survive it as Starstruck.
local function maybeStarstruck(impact: Vector3)
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:GetAttribute("State") == "free" then
			local body = descendant.PrimaryPart
			if body then
				local flat = Vector3.new(body.Position.X - impact.X, 0, body.Position.Z - impact.Z)
				if flat.Magnitude <= 10 then
					local mutation = descendant:GetAttribute("Mutation")
					if (mutation == nil or mutation == "") and math.random() < Config.STARSTRUCK_CHANCE then
						descendant:SetAttribute("Mutation", "Starstruck")
						RotlingFactory.applyMutationVisual(descendant, "Starstruck")
						local def = RotlingCatalog.getDef(descendant:GetAttribute("DefId") :: string)
						local name = if def then def.name else "A Brainrot"
						Remotes.bannerEvent():FireAllClients(name .. " survived a meteor and went STARSTRUCK! x4 income!", 4)
					end
				end
			end
		end
	end
end

-- What happens when a meteor lands: the log, the camera shake for
-- every client, a rare Rotling at the impact point (always for a hero
-- meteor, a quarter of the time for a rain meteor), a Starstruck roll
-- for nearby free Rotlings, and damage + knockback + dropped carries
-- for anyone caught close to the blast. Bases are safe zones: a player
-- standing on a base platform is never hurt, and a shielded player
-- (BoostService) is immune too.
local function onMeteorLanded(target: Vector3, isHero: boolean)
	print("[Starfall] METEOR LANDED at (" .. tostring(math.floor(target.X)) .. ", " .. tostring(math.floor(target.Y)) .. ", " .. tostring(math.floor(target.Z)) .. ")")
	Remotes.meteorImpactEvent():FireAllClients(target)
	maybeStarstruck(target)
	if isHero or math.random() < 0.25 then
		SpawnService.spawnRareAt(target)
	end
	-- Anyone close to the blast is hit: knocked back, hurt, and drops
	-- everything they carry (a rival can grab the drop). Anyone on a
	-- base platform is safe — the storm must force a dash home, not
	-- punish players who already made it there.
	local BoostService = require(script.Parent.BoostService)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not onBase(root.Position) then
			local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
			if flat.Magnitude <= Config.STORM_HIT_RADIUS then
				if not BoostService.hasBoost(player, "shield") then
					humanoid:TakeDamage(Config.STORM_DAMAGE)
					-- Knockback: shove the player away from the blast.
					local away = if flat.Magnitude > 0.5 then flat.Unit else Vector3.new(0, 0, 1)
					root.AssemblyLinearVelocity = away * Config.STORM_KNOCKBACK + Vector3.new(0, 18, 0)
					CarryService.dropAllCarried(player)
					local MeteorEggService = require(script.Parent.MeteorEggService)
					MeteorEggService.dropEgg(player)
					-- Hit feedback: a meteor hit used to be silent —
					-- damage + knockback + dropped carries with no
					-- banner, no flash, no sound, so a player caught
					-- outside their base felt nothing and thought the
					-- storm did nothing. Say it out loud. The hit is
					-- LETHAL now (STORM_DAMAGE 100): the player is
					-- knocked out, drops what they carry, and respawns
					-- at their base.
					Remotes.bannerEvent():FireClient(player, "🌠 METEOR HIT! You were knocked out — you dropped what you were carrying! Get to your base!", 4)
				end
			end
		end
	end
	-- Bots are hit too (fix round 5, item 4): a rival or raider caught
	-- outside a base is knocked out — it drops what it carries. A
	-- rival dies and respawns after 15s (its Died handler, coins
	-- kept); a raider just despawns (its loot scatters back to the
	-- crater). Bots on a base (in their Safe Dome) are safe, same as
	-- players. Collect first, then knock out, so the Died handler
	-- removing a rival from State.rivals never mutates the table
	-- mid-iteration.
	local hitRivals: { State.Rival } = {}
	for rivalModel, rival in pairs(State.rivals) do
		local root = rivalModel:FindFirstChild("HumanoidRootPart")
		local humanoid = rivalModel:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not onBase(root.Position) then
			local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
			if flat.Magnitude <= Config.STORM_HIT_RADIUS then
				table.insert(hitRivals, rival)
			end
		end
	end
	for _, rival in ipairs(hitRivals) do
		local RivalService = require(script.Parent.RivalService)
		RivalService.dropCarried(rival)
		local humanoid = rival.model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(Config.STORM_DAMAGE)
		end
		print("[Starfall] METEOR knocked out rival " .. rival.name .. "!")
		for _, player in ipairs(Players:GetPlayers()) do
			Remotes.bannerEvent():FireClient(player, "🌠 METEOR knocked out " .. rival.name .. "!", 3)
		end
	end
	local hitRaiders: { Model } = {}
	for raiderModel, _ in pairs(State.raiders) do
		local root = raiderModel:FindFirstChild("HumanoidRootPart")
		if root and not onBase(root.Position) then
			local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
			if flat.Magnitude <= Config.STORM_HIT_RADIUS then
				table.insert(hitRaiders, raiderModel)
			end
		end
	end
	for _, raiderModel in ipairs(hitRaiders) do
		local RaiderService = require(script.Parent.RaiderService)
		RaiderService.despawnRaider(raiderModel)
		print("[Starfall] METEOR knocked out a raider!")
	end
end

-- A red warning circle on the ground, 2s before the meteor lands, so
-- the impact is always dodgeable: the storm is a threat you outrun,
-- not a random punishment. Returns immediately; the fall runs in its
-- own thread so the rain loop keeps its pace.
local function showWarningCircle(target: Vector3): Part
	local circle = Instance.new("Part")
	circle.Name = "MeteorWarning"
	circle.Shape = Enum.PartType.Cylinder
	circle.Size = Vector3.new(0.3, Config.STORM_HIT_RADIUS * 2 + 2, Config.STORM_HIT_RADIUS * 2 + 2)
	circle.Color = Color3.fromRGB(255, 50, 40)
	circle.Material = Enum.Material.Neon
	circle.Transparency = 0.45
	circle.Anchored = true
	circle.CanCollide = false
	circle.CanQuery = false
	circle.CastShadow = false
	circle.CFrame = CFrame.new(target + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	circle.Parent = workspace
	task.delay(Config.STORM_WARNING_TIME + 1.2, function()
		circle:Destroy()
	end)
	return circle
end

-- Pick a meteor target. Impacts spread across the WHOLE map now, not
-- just the crater centre: near a player anywhere (paths, fields), near
-- a base (just outside its safe ring, so the dash home stays scary),
-- or anywhere in the open field. A base platform is never targeted.
local function pickTarget(): Vector3
	for _ = 1, 12 do
		local roll = math.random()
		local candidate: Vector3
		if roll < Config.STORM_NEAR_PLAYER_CHANCE then
			-- Near a random player, anywhere on the map.
			local players = Players:GetPlayers()
			if #players == 0 then
				candidate = Vector3.new(0, Config.CRATER_FLOOR_Y, 0)
			else
				local player = players[math.random(1, #players)]
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local offset = Vector3.new((math.random() * 2 - 1) * Config.STORM_NEAR_PLAYER_RADIUS, 0, (math.random() * 2 - 1) * Config.STORM_NEAR_PLAYER_RADIUS)
					local pos = root.Position + offset
					candidate = Vector3.new(pos.X, Config.CRATER_FLOOR_Y, pos.Z)
				else
					candidate = Vector3.new(0, Config.CRATER_FLOOR_Y, 0)
				end
			end
		elseif roll < Config.STORM_NEAR_PLAYER_CHANCE + 0.2 then
			-- Near a random base: the doorway ring (fix round 9, item
			-- 4) — meteors can land at the door now, because the
			-- doorway is outside the safe zone. The `not
			-- onBase(candidate)` filter below keeps interior targets
			-- out, so the platform top is still never hit.
			local baseId = math.random(1, Config.BASE_COUNT)
			local cf = WorldBuilder.baseCFrame(baseId)
			if cf then
				local angle = math.random() * math.pi * 2
				local dist = 12 + math.random(0, 8)
				candidate = Vector3.new(
					cf.Position.X + math.cos(angle) * dist,
					Config.CRATER_FLOOR_Y,
					cf.Position.Z + math.sin(angle) * dist
				)
			else
				candidate = Vector3.new(0, Config.CRATER_FLOOR_Y, 0)
			end
		else
			-- Anywhere in the open field.
			local angle = math.random() * math.pi * 2
			local radius = math.random() * Config.STORM_SPREAD_RADIUS
			candidate = Vector3.new(math.cos(angle) * radius, Config.CRATER_FLOOR_Y, math.sin(angle) * radius)
		end
		if not onBase(candidate) then
			return candidate
		end
	end
	-- Fallback: the crater centre is never on a base.
	return Vector3.new(0, Config.CRATER_FLOOR_Y, 0)
end

local function spawnMeteor()
	local target = pickTarget()
	showWarningCircle(target)
	-- The fall starts after the 2s warning: the circle is the telegraph,
	-- the meteor is the payoff. Runs in its own thread so the rain loop
	-- keeps spawning on its 0.45s pace.
	task.delay(Config.STORM_WARNING_TIME, function()
		local start = target + Vector3.new(0, 120, 0)

		local meteor = Instance.new("Part")
		meteor.Name = "Meteor"
		meteor.Shape = Enum.PartType.Ball
		meteor.Size = Vector3.new(4, 4, 4)
		meteor.Color = Color3.fromRGB(255, 110, 40)
		meteor.Material = Enum.Material.Neon
		meteor.Anchored = true
		meteor.CanCollide = false
		meteor.CanQuery = false
		meteor.CFrame = CFrame.new(start)
		meteor.Parent = workspace

		local fire = Instance.new("PointLight")
		fire.Color = Color3.fromRGB(255, 140, 50)
		fire.Brightness = 3
		fire.Range = 18
		fire.Parent = meteor

		local tween = TweenService:Create(meteor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(target + Vector3.new(0, 2, 0)),
		})
		tween:Play()
		tween.Completed:Connect(function()
			-- Impact flash, then the meteor is gone.
			meteor.Size = Vector3.new(8, 8, 8)
			meteor.Color = Color3.fromRGB(255, 220, 120)
			fire.Brightness = 5
			onMeteorLanded(target, false)
			task.delay(0.25, function()
				meteor:Destroy()
			end)
		end)
	end)
end

-- The storm front: a giant glowing meteor wall that sweeps across the
-- whole map during the storm, so the threat is visible from far away
-- in a still screenshot. Pure spectacle — it never collides, never
-- hurts anyone and never drops anything: the knockback and dropped
-- Rotlings still come only from the falling meteors.
local function spawnStormFront()
	local wall = Instance.new("Part")
	wall.Name = "StormFront"
	wall.Shape = Enum.PartType.Block
	wall.Size = Vector3.new(6, Config.STORM_FRONT_HEIGHT, Config.STORM_FRONT_LENGTH)
	wall.Color = Color3.fromRGB(255, 90, 30)
	wall.Material = Enum.Material.Neon
	wall.Transparency = 0.45
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.CastShadow = false
	wall.CFrame = CFrame.new(-Config.STORM_FRONT_RANGE, Config.STORM_FRONT_HEIGHT / 2, 0)
	wall.Parent = workspace

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 40)
	glow.Brightness = 4
	glow.Range = 40
	glow.Parent = wall

	local sweep = TweenService:Create(wall, TweenInfo.new(Config.STORM_DURATION, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(Config.STORM_FRONT_RANGE, Config.STORM_FRONT_HEIGHT / 2, 0),
	})
	sweep:Play()
	sweep.Completed:Connect(function()
		task.delay(0.5, function()
			wall:Destroy()
		end)
	end)
	-- Safety: never leave a wall behind if the tween stalls.
	task.delay(Config.STORM_DURATION + 3, function()
		if wall.Parent then
			wall:Destroy()
		end
	end)
end

-- Hero meteors: a few GIANT flaming rocks that arc across the sky at
-- storm start, so the threat reads in a still screenshot (the small
-- rain meteors are too fast and too small to see in one frame). Bigger,
-- slower, brighter, with a long diagonal fall — the sky's exclamation
-- mark. They land in the crater like the small ones (same damage and
-- Starstruck rules), just louder, and each one leaves a rare Rotling
-- at its impact point for 30 seconds.
local function spawnHeroMeteor()
	local target = pickTarget()
	showWarningCircle(target)
	-- Start high and off to one side so the fall is a long diagonal
	-- streak across the sky, not a straight drop. The fall starts after
	-- the 2s warning, in its own thread.
	task.delay(Config.STORM_WARNING_TIME, function()
		local start = target + Vector3.new(math.random(-60, 60), 130, math.random(-60, 60))

		local meteor = Instance.new("Part")
		meteor.Name = "HeroMeteor"
		meteor.Shape = Enum.PartType.Ball
		meteor.Size = Vector3.new(10, 10, 10)
		meteor.Color = Color3.fromRGB(255, 140, 30)
		meteor.Material = Enum.Material.Neon
		meteor.Anchored = true
		meteor.CanCollide = false
		meteor.CanQuery = false
		meteor.CFrame = CFrame.new(start)
		meteor.Parent = workspace

		local fire = Instance.new("PointLight")
		fire.Color = Color3.fromRGB(255, 160, 60)
		fire.Brightness = 5
		fire.Range = 30
		fire.Parent = meteor

		local tween = TweenService:Create(meteor, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(target + Vector3.new(0, 4, 0)),
		})
		tween:Play()
		tween.Completed:Connect(function()
			meteor.Size = Vector3.new(16, 16, 16)
			meteor.Color = Color3.fromRGB(255, 220, 120)
			fire.Brightness = 8
			onMeteorLanded(target, true)
			task.delay(0.3, function()
				meteor:Destroy()
			end)
		end)
	end)
end

-- Force a storm right now (used by the TOUR.json scene setter).
function StarfallService.forceStorm()
	if phase ~= "storm" then
		setPhase("storm", Config.STORM_DURATION)
		dimSky()
	end
end

function StarfallService.start()
	if running then
		return
	end
	running = true
	task.spawn(function()
		setPhase("calm", calmDuration())
		while true do
			-- One full cycle (calm -> warn -> storm) is pcall-guarded:
			-- the old loop had no error handling, so a single error
			-- anywhere killed the storm forever, silently, while the
			-- HUD countdown (driven by IncomeService's own loop) kept
			-- ticking down from the stale phaseEndsAt — the countdown
			-- hit zero and nothing ever happened. Now a failed cycle
			-- warns, restores the sky, and the machine resets to calm
			-- and tries again next cycle instead of dying.
			local ok, err = pcall(function()
				-- Calm: the crater is safe, Rotlings spawn freely.
				waitPhase()
				-- Warning: the sky darkens, everyone gets the message.
				setPhase("warn", Config.STORM_WARN)
				dimSky()
				playAlarm()
				-- Siren repeats through the 10s warning (fix round 2,
				-- fix 3): one short ping at the start is easy to miss;
				-- three pings across the warning make the countdown
				-- unmissable. Guarded by the phase so a stale thread
				-- can never sound after the warning ends.
				task.spawn(function()
					for i = 2, 3 do
						task.wait(Config.STORM_WARN / 3)
						if phase == "warn" then
							playAlarm()
						end
					end
				end)
				-- (fix round 9, item 10) the server storm banner is
				-- REMOVED — StormWarningController owns the storm
				-- voice now. The old banner ("METEOR STORM IN 10
				-- SECONDS…") drew over the controller's warnBar +
				-- countdown in playtest 10: two storm warnings
				-- overlapping. One voice, one banner.
				waitPhase()
				-- Storm: meteors rain across the WHOLE map, lightning flashes, the
				-- wind blows, the rumble drones. The lightning loop runs
				-- beside the meteor loop and stops the moment the storm ends.
				setPhase("storm", Config.STORM_DURATION)
				stormActive = true
				WorldBuilder.setWind(true)
				startRumble()
				-- The storm front wall sweeps the map for the whole
				-- storm (its own thread, so a wall failure can never
				-- kill the meteor loop).
				task.spawn(function()
					local ok, err = pcall(spawnStormFront)
					if not ok then
						warn("[Starfall] storm front failed: " .. tostring(err))
					end
				end)
				-- Bounty: earnings during this storm decide the bonus.
				-- Each wrapped in its own pcall (fix round 4, item 4):
				-- a failure in either used to abort the whole storm
				-- pcall BEFORE the rain loop, so the first storm
				-- dropped no rocks at all. Now a failure only warns
				-- and the rain still falls.
				local IncomeService = require(script.Parent.IncomeService)
				local resetOk, resetErr = pcall(IncomeService.resetStormEarnings)
				if not resetOk then
					warn("[Starfall] resetStormEarnings failed: " .. tostring(resetErr) .. " — storm bounty starts unreset, rain continues")
				end
				-- Meteor eggs crash with the storm (1-2 of them).
				local MeteorEggService = require(script.Parent.MeteorEggService)
				local eggsOk, eggsErr = pcall(MeteorEggService.spawnEggsForStorm)
				if not eggsOk then
					warn("[Starfall] spawnEggsForStorm failed: " .. tostring(eggsErr) .. " — no meteor eggs this storm, rain continues")
				end
				-- Three hero meteors at storm start: big, slow, bright —
				-- the threat shot needs a giant hazard visible in a still.
				-- They spawn immediately (no wait before the first), so a
				-- meteor is always in the air within a second of the storm
				-- starting and lands within 10s.
				for _ = 1, 3 do
					task.spawn(spawnHeroMeteor)
					task.wait(0.4)
				end
				task.spawn(function()
					while stormActive do
						task.wait(1.5 + math.random() * 2)
						lightningFlash()
					end
				end)
				-- (fix round 9, item 10) the storm-start server banner
				-- is REMOVED too — same overlap as the warning one.
				-- The rain loop spawns the first meteor immediately
				-- (no wait before the first call), so a meteor is
				-- falling within a second of the storm starting.
				while time() < phaseEndsAt do
					spawnMeteor()
					task.wait(Config.STORM_METEOR_INTERVAL)
				end
				stormActive = false
				WorldBuilder.setWind(false)
				stopRumble()
				restoreSky()
				-- Bounty: the storm's top earner wins the bonus.
				local IncomeService2 = require(script.Parent.IncomeService)
				IncomeService2.awardStormBounty()
			end)
			if not ok then
				warn("[Starfall] storm cycle failed: " .. tostring(err) .. " — resetting to calm.")
				stormActive = false
				pcall(function()
					WorldBuilder.setWind(false)
				end)
				pcall(stopRumble)
				pcall(restoreSky)
			end
			setPhase("calm", calmDuration())
		end
	end)
end

-- Watchdog: if the phase machine ever stalls (the phase expired 10+
-- seconds ago but never advanced — the loop thread died), restart it.
-- Called from IncomeService's 5-second heartbeat, which is a separate
-- healthy loop, so a dead storm thread can never hide again.
function StarfallService.ensureRunning()
	if not running then
		return
	end
	if time() > phaseEndsAt + 10 and time() - lastPhaseChangeAt > 10 then
		warn("[Starfall] watchdog: phase '" .. phase .. "' stalled (ended " .. tostring(math.floor(time() - phaseEndsAt)) .. "s ago) — restarting the storm loop.")
		stormActive = false
		pcall(function()
			WorldBuilder.setWind(false)
		end)
		pcall(stopRumble)
		pcall(restoreSky)
		running = false
		StarfallService.start()
	end
end

return StarfallService
