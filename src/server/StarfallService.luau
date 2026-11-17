--!strict
-- Starfall Rotlings: the meteor storm.
-- Every 90 seconds a storm sweeps the crater: ten seconds of warning
-- while the sky darkens, then eight seconds of falling meteors. Anyone
-- caught in the crater drops what they are carrying and takes damage.
-- Get home before it hits, or drop your catch. A free Rotling near an
-- impact may survive it and come back Starstruck, worth four times as
-- much — the only way that mutation is ever earned.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local CarryService = require(script.Parent.CarryService)
local RotlingFactory = require(script.Parent.RotlingFactory)
local WorldBuilder = require(script.Parent.WorldBuilder)

local StarfallService = {}

local ALARM_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local phase = "calm" -- calm | warn | storm
local phaseEndsAt = 0
local running = false
local stormActive = false -- true only while meteors fall; guards the lightning flash from racing restoreSky

function StarfallService.getStatus()
	return {
		phase = phase,
		-- time() is wall-clock seconds since the server started. os.clock()
		-- is CPU time: in a quiet Studio session it barely advances, so a
		-- countdown built on it never moves and the storm never fires.
		secondsLeft = math.max(0, math.ceil(phaseEndsAt - time())),
	}
end

local function setPhase(newPhase: string, duration: number)
	phase = newPhase
	phaseEndsAt = time() + duration
	if newPhase == "calm" then
		print("[Starfall] Calm: next storm in " .. tostring(duration) .. "s.")
	elseif newPhase == "warn" then
		print("[Starfall] Warning: storm in " .. tostring(duration) .. "s.")
	elseif newPhase == "storm" then
		print("[Starfall] METEOR STORM for " .. tostring(duration) .. "s.")
	end
end

-- Storm palette: the sky goes properly dark, not just a little dim.
-- These must restore to the bright base lighting in
-- default.project.json (Brightness 3, ClockTime 17.0, Ambient
-- 0.55/0.45/0.7, OutdoorAmbient 0.8/0.65/0.9): a storm darkens the
-- world, it never leaves it dark.
local function dimSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.65
		atmosphere.Color = Color3.fromRGB(200, 90, 80)
	end
	Lighting.ClockTime = 15.8
	Lighting.Brightness = 1.3
	Lighting.Ambient = Color3.new(0.22, 0.18, 0.32)
	Lighting.OutdoorAmbient = Color3.new(0.4, 0.32, 0.5)
end

local function restoreSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.35
		atmosphere.Color = Color3.fromRGB(218, 140, 242)
	end
	Lighting.ClockTime = 17.0
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.new(0.55, 0.45, 0.7)
	Lighting.OutdoorAmbient = Color3.new(0.8, 0.65, 0.9)
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
		Lighting.Brightness = 1.3
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

local function spawnMeteor()
	local angle = math.random() * math.pi * 2
	local radius = math.random() * Config.CRATER_RADIUS
	local target = Vector3.new(math.cos(angle) * radius, Config.CRATER_FLOOR_Y, math.sin(angle) * radius)
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
		Remotes.meteorImpactEvent():FireAllClients(target)
		maybeStarstruck(target)
		task.delay(0.25, function()
			meteor:Destroy()
		end)
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
		setPhase("calm", Config.STORM_PERIOD - Config.STORM_WARN - Config.STORM_DURATION)
		while true do
			-- Calm: the crater is safe, Rotlings spawn freely.
			while time() < phaseEndsAt do
				task.wait(0.5)
			end
			-- Warning: the sky darkens, everyone gets the message.
			setPhase("warn", Config.STORM_WARN)
			dimSky()
			playAlarm()
			Remotes.bannerEvent():FireAllClients("METEOR STORM IN 10 SECONDS! Get home or drop your catch!", 10)
			while time() < phaseEndsAt do
				task.wait(0.5)
			end
			-- Storm: meteors rain on the crater, lightning flashes, the
			-- wind blows. The lightning loop runs beside the meteor loop
			-- and stops the moment the storm ends.
			setPhase("storm", Config.STORM_DURATION)
			stormActive = true
			WorldBuilder.setWind(true)
			task.spawn(function()
				while stormActive do
					task.wait(1.5 + math.random() * 2)
					lightningFlash()
				end
			end)
			Remotes.bannerEvent():FireAllClients("METEOR STORM! Stay out of the crater!", 8)
			while time() < phaseEndsAt do
				spawnMeteor()
				task.wait(Config.STORM_METEOR_INTERVAL)
			end
			stormActive = false
			WorldBuilder.setWind(false)
			restoreSky()
			setPhase("calm", Config.STORM_PERIOD - Config.STORM_WARN - Config.STORM_DURATION)
		end
	end)
end

return StarfallService
