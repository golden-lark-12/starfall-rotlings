--!strict
-- Starfall Rotlings: storm warning controller.
-- The red warning bar across the top of the screen. During the warning
-- it counts the storm down in big red letters; during the storm it tells
-- everyone to stay out of the crater. Hidden while the sky is calm.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local gui = GuiKit.getGui()

local warnBar = Instance.new("Frame")
warnBar.Name = "StormWarning"
warnBar.Size = UDim2.new(0, 520, 0, 52)
warnBar.Position = UDim2.new(0.5, 0, 0, 100)
warnBar.AnchorPoint = Vector2.new(0.5, 0)
warnBar.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
warnBar.BackgroundTransparency = 0.25
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

local warnLabel = GuiKit.makeLabel(warnBar, "Warning", "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 28, Color3.fromRGB(255, 255, 255))

Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	if data.stormPhase == "warn" then
		warnBar.Visible = true
		warnLabel.Text = "⚠ METEOR STORM IN " .. tostring(data.stormSeconds) .. "s — GET HOME! ⚠"
	elseif data.stormPhase == "storm" then
		warnBar.Visible = true
		warnLabel.Text = "🌠 METEOR STORM — STAY OUT OF THE CRATER! 🌠"
	else
		warnBar.Visible = false
	end
end)

print("Starfall Rotlings storm warning ready.")
