--!strict
-- Starfall Rotlings: camera effects.
-- The camera shakes when a meteor lands, harder the closer the impact
-- is to the player. Small shakes sell the storm without making anyone
-- seasick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local trauma = 0
local stormPhase = "calm"

local function addTrauma(amount: number)
	trauma = math.min(1, trauma + amount)
end

-- The storm phase rides the HUD feed: during a storm the camera shakes
-- gently the whole time, with random bigger jolts (lightning); during
-- the warning it trembles faintly.
Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	stormPhase = data.stormPhase
end)

Remotes.meteorImpactEvent().OnClientEvent:Connect(function(impact: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local distance = (root.Position - impact).Magnitude
	-- Full shake within 20 studs, fading out to nothing at 100.
	local strength = math.clamp(1 - (distance - 20) / 80, 0, 1)
	if strength > 0.05 then
		addTrauma(strength * 0.6)
	end
end)

RunService.RenderStepped:Connect(function()
	if stormPhase == "storm" then
		-- A steady low rumble, plus the odd lightning jolt.
		trauma = math.min(1, trauma + 0.008)
		if math.random() < 0.03 then
			addTrauma(0.25)
		end
	elseif stormPhase == "warn" then
		trauma = math.max(trauma, 0.06)
	end
	if trauma <= 0 then
		return
	end
	if not camera then
		camera = workspace.CurrentCamera
		return
	end
	local shake = trauma * trauma
	local offset = Vector3.new(
		(math.random() * 2 - 1) * shake * 0.6,
		(math.random() * 2 - 1) * shake * 0.6,
		0
	)
	camera.CFrame *= CFrame.new(offset)
	trauma = math.max(0, trauma - 0.02)
end)

print("Starfall Rotlings camera FX ready.")
