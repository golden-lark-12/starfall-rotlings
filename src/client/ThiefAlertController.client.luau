--!strict
-- Starfall Rotlings: thief alert controller (fix round 9, item 9).
-- When a thief is stealing from YOUR base, the screen itself must
-- scream danger — the old warning was a small banner + a red
-- Highlight on the thief, and Malek still could not see the thief in
-- his base in playtest 10. The server fires ThiefAlert at the victim
-- every 3s while the thief is actually inside the base; each fire
-- shows for 4s, so the alert stays live until the thief leaves or is
-- bonked. (It used to fire at steal start too — but then it claimed
-- "IS IN YOUR BASE" while the thief was still ~100 studs away, so
-- the player learned to distrust it. Follow-up, item 1: the alert
-- fires only on real presence now.) The treatment: a full-screen red
-- flash wash, a pulsing red edge vignette, a big flashing centre
-- banner ("🚨 NAME IS IN YOUR BASE! 🚨" + "Go bonk them!") that
-- jitters while live, and a low alarm ping on every fire. The jitter
-- is on the GUI, not the camera — CameraFX owns the camera shake,
-- and two controllers writing the camera CFrame every frame would
-- fight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer
local gui = GuiKit.getGui()

-- Full-screen red flash wash (transparent at rest).
local flash = Instance.new("Frame")
flash.Name = "ThiefAlertFlash"
flash.Size = UDim2.new(1, 0, 1, 0)
flash.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 90
flash.Parent = gui

-- Red edge vignette (own frames — StormWarningController has its own
-- edges for storms; these are the thief's).
local edgeFrames: { Frame } = {}
local function makeEdge(name: string, size: UDim2, position: UDim2)
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.Size = size
	edge.Position = position
	edge.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
	edge.BackgroundTransparency = 1
	edge.BorderSizePixel = 0
	edge.ZIndex = 91
	edge.Parent = gui
	table.insert(edgeFrames, edge)
	return edge
end
makeEdge("ThiefEdgeTop", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 0))
makeEdge("ThiefEdgeBottom", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 1, -24))
makeEdge("ThiefEdgeLeft", UDim2.new(0, 24, 1, 0), UDim2.new(0, 0, 0, 0))
makeEdge("ThiefEdgeRight", UDim2.new(0, 24, 1, 0), UDim2.new(1, -24, 0, 0))

-- Big flashing centre banner + sub-line.
local alertLabel = GuiKit.makeLabel(gui, "ThiefAlertText", "🚨 THIEF IN YOUR BASE! 🚨", UDim2.new(1, 0, 0, 64), UDim2.new(0.5, 0, 0, 300), 44, Color3.fromRGB(255, 60, 60))
alertLabel.AnchorPoint = Vector2.new(0.5, 0)
alertLabel.ZIndex = 92
alertLabel.Visible = false
local alertSub = GuiKit.makeLabel(gui, "ThiefAlertSub", "Go bonk them!", UDim2.new(1, 0, 0, 32), UDim2.new(0.5, 0, 0, 368), 24, Color3.fromRGB(255, 255, 255))
alertSub.AnchorPoint = Vector2.new(0.5, 0)
alertSub.ZIndex = 92
alertSub.Visible = false

-- Low alarm ping on every fire (the built-in ping the game already
-- uses — no new asset IDs).
local alarm = Instance.new("Sound")
alarm.Name = "ThiefAlarm"
alarm.SoundId = "rbxasset://sounds/electronicpingshort.wav"
alarm.Volume = 0.9
alarm.PlaybackSpeed = 0.7
alarm.Parent = gui

local alertUntil = 0
local edgeTweens: { Tween } = {}

local function stopEdgePulse()
	for _, tween in ipairs(edgeTweens) do
		tween:Cancel()
	end
	table.clear(edgeTweens)
	for _, edge in ipairs(edgeFrames) do
		edge.BackgroundTransparency = 1
	end
end

local function startEdgePulse()
	if #edgeTweens > 0 then
		return
	end
	for _, edge in ipairs(edgeFrames) do
		edge.BackgroundTransparency = 0.45
		local tween = TweenService:Create(edge, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			BackgroundTransparency = 0.85,
		})
		tween:Play()
		table.insert(edgeTweens, tween)
	end
end

local function hideAlert()
	alertUntil = 0
	alertLabel.Visible = false
	alertSub.Visible = false
	flash.BackgroundTransparency = 1
	stopEdgePulse()
end

local function showAlert(thiefName: string)
	alertUntil = os.clock() + 4
	alertLabel.Text = "🚨 " .. thiefName .. " IS IN YOUR BASE! 🚨"
	alertLabel.Visible = true
	alertSub.Visible = true
	alarm:Play()
	startEdgePulse()
	print("[ThiefAlert] danger alert fired for " .. thiefName .. " — visible 4s")
end

-- The banner jitters while live (GUI jitter, not camera shake) and
-- the flash wash pulses — the alert never sits still on screen.
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now < alertUntil then
		local jx = (math.random() * 2 - 1) * 4
		local jy = (math.random() * 2 - 1) * 4
		alertLabel.Position = UDim2.new(0.5, jx, 0, 300 + jy)
		alertSub.Position = UDim2.new(0.5, -jx, 0, 368 - jy)
		flash.BackgroundTransparency = 0.88 + math.sin(now * 12) * 0.07
	elseif alertLabel.Visible then
		hideAlert()
	end
end)

-- The server fires this at the victim every 3s while the thief is
-- actually inside their base (follow-up, item 1: no fire at steal
-- start — the thief is not in the base yet then).
task.spawn(function()
	while true do
		local ok, event = pcall(function()
			return Remotes.thiefAlertEvent()
		end)
		if ok and event then
			event.OnClientEvent:Connect(function(thiefName: string)
				showAlert(thiefName)
			end)
			break
		end
		task.wait(1)
	end
end)

print("Starfall Brainrots thief alert ready.")
