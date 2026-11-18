--!strict
-- Starfall Rotlings: tutorial controller.
-- A new player's first 60 seconds: a bouncing gold arrow hovers over
-- the next thing to do, in three steps — crater, then your own base,
-- then the SELL pad — with a one-line instruction under it. The arrow
-- moves itself; the player only has to follow it. It stops the moment
-- the player grabs their first Rotling (the loop is learned) or after
-- 60 seconds, whichever comes first. Returning players never see it:
-- it only starts when the HUD feed says firstTime.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer
local gui = GuiKit.getGui()

-- First 60 seconds only, in three 20-second steps.
local TUTORIAL_SECONDS = 60
local STEP_SECONDS = 20

local tutorialLabel = GuiKit.makeLabel(gui, "Tutorial", "", UDim2.new(0, 620, 0, 30), UDim2.new(0.5, 0, 1, -80), 22, GuiKit.COLORS.Green)
tutorialLabel.AnchorPoint = Vector2.new(0.5, 0)
tutorialLabel.Visible = false

local arrow: Part? = nil
local arrowBillboard: BillboardGui? = nil
local active = false
local startedAt = 0
local heartbeat: RBXScriptConnection? = nil
local baseTarget: Vector3? = nil

-- The step targets, in world space. The base is the nearest
-- BasePlatform to the player (they spawn beside their own base).
local function stepTarget(step: number): (Vector3, string)
	if step == 1 then
		return Vector3.new(0, 0, 0), "1. Walk to the crater — press E on a Brainrot to grab it!"
	elseif step == 2 then
		if not baseTarget then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local best: Vector3? = nil
			local bestDist = math.huge
			if root then
				for _, descendant in ipairs(workspace:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant.Name == "BasePlatform" then
						local d = (descendant.Position - root.Position).Magnitude
						if d < bestDist then
							bestDist = d
							best = descendant.Position
						end
					end
				end
			end
			baseTarget = best or Vector3.new(110, 0, 0)
		end
		return baseTarget :: Vector3, "2. Carry it home — press E on a glowing pad to place it!"
	else
		return Vector3.new(62, 0, 0), "3. Sell extras at the gold SELL pad — or press B to shop and upgrade!"
	end
end

local function buildArrow()
	local part = Instance.new("Part")
	part.Name = "TutorialArrow"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2, 2, 2)
	part.Color = Color3.fromRGB(255, 225, 90)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 0.2
	part.Parent = workspace
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TutorialArrowLabel"
	billboard.Size = UDim2.fromOffset(90, 90)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "⬇"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 225, 90)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	arrow = part
	arrowBillboard = billboard
end

local function stopTutorial()
	if not active then
		return
	end
	active = false
	tutorialLabel.Visible = false
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
	arrowBillboard = nil
	baseTarget = nil
end

local function startTutorial()
	if active then
		return
	end
	active = true
	startedAt = os.clock()
	tutorialLabel.Visible = true
	buildArrow()
	heartbeat = RunService.Heartbeat:Connect(function()
		if not active or not arrow then
			return
		end
		local elapsed = os.clock() - startedAt
		if elapsed >= TUTORIAL_SECONDS then
			stopTutorial()
			return
		end
		local step = math.min(3, math.floor(elapsed / STEP_SECONDS) + 1)
		local target, text = stepTarget(step)
		tutorialLabel.Text = text
		-- Bob above the target: 8 studs up, ±1 stud of bounce.
		local bob = math.sin(elapsed * 3) * 1
		arrow.CFrame = CFrame.new(target + Vector3.new(0, 8 + bob, 0))
	end)
end

Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	if data.carried > 0 then
		stopTutorial()
		return
	end
	if data.firstTime and not active then
		startTutorial()
	elseif not data.firstTime then
		stopTutorial()
	end
end)

print("Starfall Brainrots tutorial ready.")
