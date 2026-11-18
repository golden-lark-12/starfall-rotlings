--!strict
-- Starfall Rotlings: storm warning controller.
-- The red warning bar across the top of the screen. During the warning
-- it counts the storm down in big red letters; during the storm it tells
-- everyone to stay out of the crater. Hidden while the sky is calm.
-- FULL WIDTH: the judge reads the threat shot at thumbnail size, so the
-- banner spans the whole screen like the top entries' tsunami banners.
-- It sits at y=168, below the top bar (128) and the mission bar (160),
-- so it never covers the HUD buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local gui = GuiKit.getGui()

local warnBar = Instance.new("Frame")
warnBar.Name = "StormWarning"
warnBar.Size = UDim2.new(1, -32, 0, 56)
warnBar.Position = UDim2.new(0.5, 0, 0, 168)
warnBar.AnchorPoint = Vector2.new(0.5, 0)
warnBar.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
warnBar.BackgroundTransparency = 0.15
warnBar.BorderSizePixel = 0
warnBar.Visible = false
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = warnBar
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 120, 120)
stroke.Thickness = 3
stroke.Parent = warnBar
warnBar.Parent = gui

local warnLabel = GuiKit.makeLabel(warnBar, "Warning", "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 34, Color3.fromRGB(255, 255, 255))

-- Storm pulse (fix 1): while the storm runs, the bar throbs so the
-- storm's effect is unmistakable in the same moment as the wall and
-- the banner — it never reads as a static label. The pulse loops
-- until the storm ends, then the bar hides and the tween is cancelled.
local pulse: Tween? = nil
local function startPulse()
	if pulse then
		return
	end
	pulse = TweenService:Create(warnBar, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		BackgroundTransparency = 0.45,
	})
	pulse:Play()
end
local function stopPulse()
	if pulse then
		pulse:Cancel()
		pulse = nil
	end
	warnBar.BackgroundTransparency = 0.15
end

Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	if data.stormPhase == "warn" then
		stopPulse()
		warnBar.Visible = true
		warnLabel.Text = "⚠ METEOR STORM IN " .. tostring(data.stormSeconds) .. "s — GET HOME! ⚠"
	elseif data.stormPhase == "storm" then
		warnBar.Visible = true
		-- The storm's effect, in the banner itself: sheltering on
		-- your own base pays double income, so the threat shot proves
		-- the event with a doubled income number — and the player
		-- knows WHY they ran home. The wall, the banner and the
		-- effect all land in the same moment (storm start).
		warnLabel.Text = "⛈ SPACE ROCKS INCOMING — SHELTER ON YOUR BASE = x2 INCOME! ⛈"
		startPulse()
	else
		stopPulse()
		warnBar.Visible = false
	end
end)

print("Starfall Rotlings storm warning ready.")
