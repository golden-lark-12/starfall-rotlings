-- Starfall Rotlings: the meteor storm.
-- Every 90 seconds a storm sweeps the crater: ten seconds of warning
-- while the sky darkens, then eight seconds of falling meteors. Anyone
-- caught in the crater drops what they are carrying and takes damage.
-- Get home before it hits, or drop your catch.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Bases = require(script.Parent.Bases)

local Storm = {}

local Remotes -- set by init()
local phase = "calm" -- calm | warn | storm
local phaseEndsAt = 0
local running = false

function Storm.getStatus()
	return {
		phase = phase,
		secondsLeft = math.max(0, math.ceil(phaseEndsAt - os.clock())),
	}
end

local function setPhase(newPhase: string, duration: number)
	phase = newPhase
	phaseEndsAt = os.clock() + duration
end

local function dimSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.55
		atmosphere.Color = Color3.fromRGB(255, 120, 60)
	end
	Lighting.ClockTime = 17.2
	Lighting.Brightness = 1.4
end

local function restoreSky()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.35
		atmosphere.Color = Color3.fromRGB(255, 170, 110)
	end
	Lighting.ClockTime = 17.8
	Lighting.Brightness = 2
end

local function spawnMeteor()
	local angle = math.random() * math.pi * 2
	local radius = math.random() * Config.CRATER_RADIUS
	local target = Vector3.new(math.cos(angle) * radius, 1, math.sin(angle) * radius)
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
					Bases.dropAllCarried(player)
				end
			end
		end
	end)
end

-- Force a storm right now (used by the TOUR.json scene setter).
function Storm.forceStorm()
	if phase ~= "storm" then
		setPhase("storm", Config.STORM_DURATION)
		dimSky()
	end
end

function Storm.start(remotesModule)
	Remotes = remotesModule
	if running then
		return
	end
	running = true
	task.spawn(function()
		setPhase("calm", Config.STORM_PERIOD - Config.STORM_WARN - Config.STORM_DURATION)
		while true do
			-- Calm: the crater is safe, Rotlings spawn freely.
			while os.clock() < phaseEndsAt do
				task.wait(0.5)
			end
			-- Warning: the sky darkens, everyone gets the message.
			setPhase("warn", Config.STORM_WARN)
			dimSky()
			Remotes.fireBannerAll("METEOR STORM IN 10 SECONDS! Get home or drop your catch!", 10)
			while os.clock() < phaseEndsAt do
				task.wait(0.5)
			end
			-- Storm: meteors rain on the crater.
			setPhase("storm", Config.STORM_DURATION)
			Remotes.fireBannerAll("METEOR STORM! Stay out of the crater!", 8)
			while os.clock() < phaseEndsAt do
				spawnMeteor()
				task.wait(Config.STORM_METEOR_INTERVAL)
			end
			restoreSky()
			setPhase("calm", Config.STORM_PERIOD - Config.STORM_WARN - Config.STORM_DURATION)
		end
	end)
end

return Storm
