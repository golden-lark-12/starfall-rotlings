--!strict
-- Starfall Rotlings: slap bat controller (client).
-- No guns — a bat. Press F (or the SLAP button on touch) to swing:
-- the server decides what you hit (rival, raider or another player),
-- knocks it back and makes it drop what it carries. The bat is a
-- visible part in your hand while you swing; a hit shows gold stars
-- and plays a bonk. Cooldown 2s, enforced on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer
local gui = GuiKit.getGui()

local bat: Part? = nil
local batWeld: Weld? = nil
local swinging = false

-- SLAP button, bottom-right above the Run button, touch + mouse.
local slapButton = GuiKit.makeButton(gui, "SlapButton", "👋 SLAP (F)", UDim2.new(0, 130, 0, 56), UDim2.new(1, -146, 1, -252), GuiKit.COLORS.Red)

local function attachBat(character: Model)
	local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	if not arm or not arm:IsA("BasePart") then
		return
	end
	local part = Instance.new("Part")
	part.Name = "SlapBat"
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(0.7, 3.4, 0.7)
	part.Color = Color3.fromRGB(150, 100, 50)
	part.Material = Enum.Material.Wood
	part.Transparency = 1 -- hidden until you swing
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Parent = character
	local weld = Instance.new("Weld")
	weld.Name = "BatWeld"
	weld.Part0 = arm
	weld.Part1 = part
	weld.C0 = CFrame.new(0, -1.2, 0) * CFrame.Angles(0, 0, 0)
	weld.Parent = part
	bat = part
	batWeld = weld
end

local function swingBat()
	if swinging or not bat or not batWeld then
		return
	end
	swinging = true
	bat.Transparency = 0
	-- A quick arc: out to the side, across, and back.
	for _, angle in ipairs({ -0.6, -1.4, -2.2, -1.4, -0.6, 0 }) do
		if not batWeld.Parent then
			break
		end
		batWeld.C0 = CFrame.new(0, -1.2, 0) * CFrame.Angles(angle, 0, 0)
		task.wait(0.05)
	end
	if bat.Parent then
		bat.Transparency = 1
	end
	swinging = false
end

local function slap()
	Remotes.slapEvent():FireServer()
	swingBat()
end

slapButton.MouseButton1Click:Connect(slap)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		slap()
	end
end)

-- Stars + bonk where a slap lands (fired by the server to everyone).
Remotes.slapEffectEvent().OnClientEvent:Connect(function(position: Vector3)
	local star = Instance.new("Part")
	star.Name = "SlapStars"
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.new(1.5, 1.5, 1.5)
	star.Color = Color3.fromRGB(255, 220, 60)
	star.Material = Enum.Material.Neon
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
	star.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60))
	emitter.Size = NumberSequence.new(0.6)
	emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Parent = star
	emitter:Emit(14)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.8
	sound.PlaybackSpeed = 0.5
	sound.Parent = star
	sound:Play()
	task.delay(1, function()
		star:Destroy()
	end)
end)

local function onCharacter(character: Model)
	attachBat(character)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

print("Starfall Brainrots slap bat ready (F or SLAP button).")
