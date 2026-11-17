--!strict
-- Starfall Rotlings: tutorial controller.
-- A new player's first minute: a glowing beam of light rises from the
-- crater and a step-by-step hint tells them what to do. The beam points
-- at the crater from the spawn, and it goes away the moment the player
-- grabs their first Rotling — or after two minutes, whichever is first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer
local gui = GuiKit.getGui()

local tutorialLabel = GuiKit.makeLabel(gui, "Tutorial", "", UDim2.new(0, 620, 0, 30), UDim2.new(0.5, 0, 1, -80), 22, GuiKit.COLORS.Green)
tutorialLabel.AnchorPoint = Vector2.new(0.5, 0)
tutorialLabel.Visible = false

local beam: Part? = nil
local active = false

local function buildBeam()
	local part = Instance.new("Part")
	part.Name = "TutorialBeam"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(120, 4, 4)
	part.Color = Color3.fromRGB(100, 255, 180)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 0.3
	part.CFrame = CFrame.new(0, 60, 0)
	part.Parent = workspace
	beam = part
	local tween = TweenService:Create(part, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.6,
	})
	tween:Play()
end

local function stopTutorial()
	if not active then
		return
	end
	active = false
	tutorialLabel.Visible = false
	if beam then
		beam:Destroy()
		beam = nil
	end
end

Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	if data.carried > 0 then
		stopTutorial()
		return
	end
	if data.firstTime and not active then
		active = true
		tutorialLabel.Text = "1. Walk to the glowing crater  •  2. Press E on a Rotling  •  3. Carry it home to your base!"
		tutorialLabel.Visible = true
		buildBeam()
		task.delay(120, stopTutorial)
	elseif not data.firstTime then
		stopTutorial()
	end
end)

print("Starfall Rotlings tutorial ready.")
