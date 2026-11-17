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

local StarfallService = {}

local ALARM_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local phase = "calm" -- calm | warn | storm
local phaseEndsAt = 0
local running = false

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
end

-- Space-sunset palette: purple sky, orange storm light.
-- These must match the bright base lighting in default.project.json
-- (Brightness 3, ClockTime 17.0): a storm dims the sky a little, it
-- never drops the world back to navy-black.
local function dimSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.5
		atmosphere.Color = Color3.fromRGB(255, 120, 60)
	end
	Lighting.ClockTime = 16.8
	Lighting.Brightness = 2.4
end

local function restoreSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.35
		atmosphere.Color = Color3.fromRGB(218, 140, 242)
	end
	Lighting.ClockTime = 17.0
	Lighting.Brightness = 3
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
			-- Storm: meteors rain on the crater.
			setPhase("storm", Config.STORM_DURATION)
			Remotes.bannerEvent():FireAllClients("METEOR STORM! Stay out of the crater!", 8)
			while time() < phaseEndsAt do
				spawnMeteor()
				task.wait(Config.STORM_METEOR_INTERVAL)
			end
			restoreSky()
			setPhase("calm", Config.STORM_PERIOD - Config.STORM_WARN - Config.STORM_DURATION)
		end
	end)
end

return StarfallService
