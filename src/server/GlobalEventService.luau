--!strict
-- Starfall Rotlings: global events.
-- One timed event every 60-90s between storms (never during a storm):
-- "Stardust Shower" (gems rain across the map — collect each for +5
-- Stardust) or "2x Cash Hour" (double income for 60s). A banner and a
-- HUD timer announce each one (IncomeService broadcasts the event name
-- and seconds left). Events make the world feel alive right now, not
-- just every 90s when the storm comes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local State = require(script.Parent.State)

local GlobalEventService = {}

local running = false

local function spawnShowerGem(position: Vector3)
	local gem = Instance.new("Part")
	gem.Name = "StardustGem"
	gem.Shape = Enum.PartType.Ball
	gem.Size = Vector3.new(1.6, 1.6, 1.6)
	gem.Color = Color3.fromRGB(190, 240, 255)
	gem.Material = Enum.Material.Neon
	gem.Anchored = true
	gem.CanCollide = false
	gem.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0))
	gem.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(160, 225, 255)
	light.Brightness = 1.5
	light.Range = 10
	light.Parent = gem
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect Stardust"
	prompt.ObjectText = "+5 💎"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = gem
	prompt.Triggered:Connect(function(player: Player)
		if gem.Parent then
			local profile = DataService.getProfile(player)
			if profile then
				profile.stardust += Config.EVENT_SHOWER_STARDUST
				DataService.saveProfile(player)
				Remotes.bannerEvent():FireClient(player, "💎 +" .. tostring(Config.EVENT_SHOWER_STARDUST) .. " Stardust!", 2)
			end
			gem:Destroy()
		end
	end)
	task.delay(45, function()
		gem:Destroy()
	end)
end

local function startShower()
	State.globalEvent = { name = "shower", endsAt = time() + 45 }
	Remotes.bannerEvent():FireAllClients("💎 STARDUST SHOWER! Gems are falling across the map — grab them for Stardust!", 6)
	for _ = 1, Config.EVENT_SHOWER_COUNT do
		local angle = math.random() * math.pi * 2
		local radius = math.random(35, 130)
		spawnShowerGem(Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
	end
	task.delay(45, function()
		if State.globalEvent.name == "shower" then
			State.globalEvent = { name = "", endsAt = 0 }
		end
	end)
end

local function startCashHour()
	State.globalEvent = { name = "cash", endsAt = time() + Config.EVENT_CASH_DURATION }
	Remotes.bannerEvent():FireAllClients("💰 2X CASH HOUR! Double income for 60 seconds!", 6)
	task.delay(Config.EVENT_CASH_DURATION, function()
		if State.globalEvent.name == "cash" then
			State.globalEvent = { name = "", endsAt = 0 }
		end
	end)
end

function GlobalEventService.start()
	if running then
		return
	end
	running = true
	task.spawn(function()
		task.wait(30) -- first event half a minute in, not instantly
		while true do
			task.wait(math.random(Config.EVENT_INTERVAL_MIN, Config.EVENT_INTERVAL_MAX))
			-- Events run between storms, never during one.
			local StarfallService = require(script.Parent.StarfallService)
			if StarfallService.getStatus().phase == "calm" and State.globalEvent.name == "" then
				if math.random() < 0.5 then
					startShower()
				else
					startCashHour()
				end
			end
		end
	end)
end

return GlobalEventService
