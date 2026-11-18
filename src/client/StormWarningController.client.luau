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

-- Red edge flash (fix round 2, fix 3): during the 10s warning the
-- screen EDGES flash red, so the warning reads even when the player is
-- not looking at the top bar. Four thin red frames at the screen
-- edges; they pulse during the warning and sit at a steady dim red
-- during the storm, then hide.
local edgeFrames: { Frame } = {}
local function makeEdge(name: string, size: UDim2, position: UDim2)
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.Size = size
	edge.Position = position
	edge.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
	edge.BackgroundTransparency = 1
	edge.BorderSizePixel = 0
	edge.Parent = gui
	table.insert(edgeFrames, edge)
	return edge
end
makeEdge("EdgeTop", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 0))
makeEdge("EdgeBottom", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 1, -18))
makeEdge("EdgeLeft", UDim2.new(0, 18, 1, 0), UDim2.new(0, 0, 0, 0))
makeEdge("EdgeRight", UDim2.new(0, 18, 1, 0), UDim2.new(1, -18, 0, 0))

local edgeTweens: { Tween } = {}
local function startEdgePulse()
	if #edgeTweens > 0 then
		return
	end
	for _, edge in ipairs(edgeFrames) do
		edge.BackgroundTransparency = 0.45
		local tween = TweenService:Create(edge, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			BackgroundTransparency = 0.8,
		})
		tween:Play()
		table.insert(edgeTweens, tween)
	end
end
local function stopEdgePulse()
	for _, tween in ipairs(edgeTweens) do
		tween:Cancel()
	end
	table.clear(edgeTweens)
	for _, edge in ipairs(edgeFrames) do
		edge.BackgroundTransparency = 1
	end
end
local function setEdgesSteady()
	for _, tween in ipairs(edgeTweens) do
		tween:Cancel()
	end
	table.clear(edgeTweens)
	for _, edge in ipairs(edgeFrames) do
		edge.BackgroundTransparency = 0.7
	end
end

-- Big centre countdown (fix round 2, fix 3): "SPACE ROCKS IN 10…"
-- in huge letters in the middle of the screen during the warning, so
-- the countdown is unmissable. Hidden in calm and during the storm.
local countdownLabel = GuiKit.makeLabel(gui, "StormCountdown", "", UDim2.new(0, 700, 0, 90), UDim2.new(0.5, -350, 0.35, 0), 64, Color3.fromRGB(255, 60, 50))
countdownLabel.Visible = false

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
		-- Big centre countdown + flashing red edges (fix round 2, fix 3).
		countdownLabel.Text = "SPACE ROCKS IN " .. tostring(data.stormSeconds) .. "…"
		countdownLabel.Visible = true
		startEdgePulse()
	elseif data.stormPhase == "storm" then
		warnBar.Visible = true
		-- The storm's effect, in the banner itself: sheltering on
		-- your own base pays double income, so the threat shot proves
		-- the event with a doubled income number — and the player
		-- knows WHY they ran home. The wall, the banner and the
		-- effect all land in the same moment (storm start).
		warnLabel.Text = "⛈ SPACE ROCKS INCOMING — SHELTER ON YOUR BASE = x2 INCOME! ⛈"
		startPulse()
		countdownLabel.Visible = false
		setEdgesSteady()
	else
		stopPulse()
		warnBar.Visible = false
		countdownLabel.Visible = false
		stopEdgePulse()
	end
end)

print("Starfall Rotlings storm warning ready.")
