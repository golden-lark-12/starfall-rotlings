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
local WorldBuilder = require(script.Parent.WorldBuilder)

local StarfallService = {}

local ALARM_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local phase = "calm" -- calm | warn | storm
local phaseEndsAt = 0
local lastPhaseChangeAt = 0 -- wall-clock time of the last setPhase
local running = false
local stormActive = false -- true only while meteors fall; guards the lightning flash from racing restoreSky
local rumbleSound: Sound? = nil -- the low storm rumble, looping while the storm runs

function StarfallService.getStatus()
	return {
		phase = phase,
		-- time() is wall-clock seconds since the server started. os.clock()
		-- is CPU time: in a quiet Studio session it barely advances, so a
		-- countdown built on it never moves and the storm never fires.
		secondsLeft = math.max(0, math.ceil(phaseEndsAt - time())),
	}
end

local function calmDuration(): number
	return Config.STORM_PERIOD - Config.STORM_WARN - Config.STORM_DURATION
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
-- default.project.json (Brightness 3, ClockTime 12.5, Ambient
-- 0.9/0.88/0.95, OutdoorAmbient 1/1/1, Atmosphere Density 0.12):
-- a storm darkens the world, it never leaves it dark.
local function dimSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.7
		atmosphere.Color = Color3.fromRGB(200, 60, 50)
	end
	Lighting.ClockTime = 14.0
	Lighting.Brightness = 0.9
	Lighting.Ambient = Color3.new(0.3, 0.12, 0.15)
	Lighting.OutdoorAmbient = Color3.new(0.5, 0.25, 0.3)
end

local function restoreSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.12
		atmosphere.Color = Color3.fromRGB(166, 191, 255)
	end
	Lighting.ClockTime = 12.5
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.new(0.9, 0.88, 0.95)
	Lighting.OutdoorAmbient = Color3.new(1.0, 1.0, 1.0)
end

local function playAlarm()
	local sound = Instance.new("Sound")
	sound.SoundId = ALARM_SOUND
	sound.Volume = 0.8
	sound.PlaybackSpeed = 0.6
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
	sound.PlaybackSpeed = 0.25
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
	sound.Volume = 0.4
	sound.PlaybackSpeed = 0.2
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
		Lighting.Brightness = 0.9
	end
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
						local name = if def then def.name else "A Rotling"
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
-- for nearby free Rotlings, and damage + dropped carries for anyone
-- standing in the crater.
local function onMeteorLanded(target: Vector3, isHero: boolean)
	print("[Starfall] METEOR LANDED at (" .. tostring(math.floor(target.X)) .. ", " .. tostring(math.floor(target.Y)) .. ", " .. tostring(math.floor(target.Z)) .. ")")
	Remotes.meteorImpactEvent():FireAllClients(target)
	maybeStarstruck(target)
	if isHero or math.random() < 0.25 then
		SpawnService.spawnRareAt(target)
	end
	-- Anyone standing in the crater is hit.
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
			if flat.Magnitude <= Config.CRATER_RADIUS + 4 then
				humanoid:TakeDamage(Config.STORM_DAMAGE)
				CarryService.dropAllCarried(player)
			end
		end
	end
end

-- Pick a meteor target. Half the time, aim near a player who is in or
-- near the crater, so 6-10 meteors per storm crash close enough to
-- shake that player's camera; otherwise a random spot in the crater.
local function pickTarget(): Vector3
	local nearPlayers: { Player } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
			if flat.Magnitude <= Config.CRATER_RADIUS + 17 then
				table.insert(nearPlayers, player)
			end
		end
	end
	if #nearPlayers > 0 and math.random() < Config.STORM_NEAR_PLAYER_CHANCE then
		local player = nearPlayers[math.random(1, #nearPlayers)]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local offset = Vector3.new((math.random() * 2 - 1) * Config.STORM_NEAR_PLAYER_RADIUS, 0, (math.random() * 2 - 1) * Config.STORM_NEAR_PLAYER_RADIUS)
			local pos = root.Position + offset
			return Vector3.new(pos.X, Config.CRATER_FLOOR_Y, pos.Z)
		end
	end
	local angle = math.random() * math.pi * 2
	local radius = math.random() * Config.CRATER_RADIUS
	return Vector3.new(math.cos(angle) * radius, Config.CRATER_FLOOR_Y, math.sin(angle) * radius)
end

local function spawnMeteor()
	local target = pickTarget()
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
	-- Start high and off to one side so the fall is a long diagonal
	-- streak across the sky, not a straight drop.
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
				Remotes.bannerEvent():FireAllClients("METEOR STORM IN 10 SECONDS! Get home or drop your catch!", 10)
				waitPhase()
				-- Storm: meteors rain on the crater, lightning flashes, the
				-- wind blows, the rumble drones. The lightning loop runs
				-- beside the meteor loop and stops the moment the storm ends.
				setPhase("storm", Config.STORM_DURATION)
				stormActive = true
				WorldBuilder.setWind(true)
				startRumble()
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
				Remotes.bannerEvent():FireAllClients("METEOR STORM! Stay out of the crater!", 8)
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
