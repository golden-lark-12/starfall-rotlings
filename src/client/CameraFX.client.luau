--!strict
-- Starfall Rotlings: camera effects.
-- The camera shakes when a meteor lands, harder the closer the impact
-- is to the player. Small shakes sell the storm without making anyone
-- seasick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local trauma = 0
local stormPhase = "calm"

-- Red damage flash (fix 1): a meteor hit used to be silent — the
-- player took damage and dropped their carry with no visible cue, so
-- the storm felt like nothing. When a meteor lands close enough to
-- hurt (near-player range), the whole screen flashes red and fades.
local gui = GuiKit.getGui()
local flash = Instance.new("Frame")
flash.Name = "MeteorHitFlash"
flash.Size = UDim2.new(1, 0, 1, 0)
flash.Position = UDim2.new(0, 0, 0, 0)
flash.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

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
	-- Red flash when the impact is close enough to hurt: the hit
	-- reads on screen, not just in the camera shake.
	if distance <= 15 then
		flash.BackgroundTransparency = 0.3
		local fade = TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		fade:Play()
	end
end)

RunService.RenderStepped:Connect(function()
	-- Photo mode holds a fixed frame: never shake it. PhotoModeController
	-- sets the camera's PhotoMode attribute while a shot is framed.
	local cam = workspace.CurrentCamera
	if cam and cam:GetAttribute("PhotoMode") then
		return
	end
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
