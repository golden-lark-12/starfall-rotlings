--!strict
-- Starfall Rotlings: slap bat controller (client).
-- No guns — a bat. Press F (or the BONK button on touch) to swing:
-- the server decides what you hit (rival, raider or another player),
-- knocks it back and makes it drop what it carries. The bat is a
-- visible part in your hand while you swing; a hit shows a shockwave
-- ring + a "BONK!" burst and plays a low thud, a whiff shows only a
-- faint swoosh. Cooldown 2s, enforced on the server.

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

-- BONK button, bottom-right above the Run button, touch + mouse.
-- (fix round 7, item 5) The button used to say "SLAP" with no
-- explanation — a new player did not know what "bonk" means or what
-- the button does. It now says BONK and carries a plain label under
-- it: hit a thief, they drop your Brainrot.
local slapButton = GuiKit.makeButton(gui, "SlapButton", "👊 BONK (F)", UDim2.new(0, 130, 0, 56), UDim2.new(1, -146, 1, -252), GuiKit.COLORS.Red)
local bonkLabel = GuiKit.makeLabel(gui, "BonkLabel", "Hit a thief — they drop your Brainrot", UDim2.new(0, 130, 0, 28), UDim2.new(1, -146, 1, -194), 13, GuiKit.COLORS.White)
bonkLabel.TextWrapped = true

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

-- The slap's hit effect (fired by the server): a real HIT shows an
-- impact, a whiff shows almost nothing. (fix round 7, item 3) The
-- old effect was a yellow Neon ball + gold particles — a glowing sun
-- that appeared at the click point even when the slap hit nothing,
-- because the server fired the same event for hits and whiffs and
-- the client could not tell them apart. Now the event carries a hit
-- flag: a hit shows a white shockwave ring + a "BONK!" burst + a low
-- thud at the impact point; a whiff shows only a small faint swoosh
-- where the bat swung — no sun, no "BONK!".
Remotes.slapEffectEvent().OnClientEvent:Connect(function(position: Vector3, hit: boolean?)
	if hit then
		local ring = Instance.new("Part")
		ring.Name = "BonkRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.15, 1.5, 1.5)
		ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 255, 255)
		ring.Transparency = 0.15
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Parent = workspace
		local burst = Instance.new("BillboardGui")
		burst.Name = "BonkBurst"
		burst.Size = UDim2.fromOffset(140, 50)
		burst.StudsOffset = Vector3.new(0, 2.5, 0)
		burst.AlwaysOnTop = true
		burst.Adornee = ring
		burst.Parent = ring
		local burstText = Instance.new("TextLabel")
		burstText.Size = UDim2.fromScale(1, 1)
		burstText.BackgroundTransparency = 1
		burstText.Text = "BONK!"
		burstText.Font = Enum.Font.GothamBlack
		burstText.TextSize = 30
		burstText.TextColor3 = Color3.fromRGB(255, 200, 40)
		burstText.TextStrokeColor3 = Color3.fromRGB(60, 20, 0)
		burstText.TextStrokeTransparency = 0
		burstText.Parent = burst
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sound.Volume = 0.8
		sound.PlaybackSpeed = 0.35
		sound.Parent = ring
		sound:Play()
		task.spawn(function()
			for i = 1, 7 do
				local t = i / 7
				ring.Size = Vector3.new(0.15, 1.5 + t * 4.5, 1.5 + t * 4.5)
				ring.Transparency = 0.15 + t * 0.85
				burst.StudsOffset = Vector3.new(0, 2.5 + t * 2, 0)
				burstText.TextTransparency = t
				burstText.TextStrokeTransparency = t
				task.wait(0.05)
			end
			ring:Destroy()
		end)
	else
		local swoosh = Instance.new("Part")
		swoosh.Name = "BonkSwoosh"
		swoosh.Shape = Enum.PartType.Cylinder
		swoosh.Size = Vector3.new(0.1, 1.2, 1.2)
		swoosh.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		swoosh.Material = Enum.Material.Neon
		swoosh.Color = Color3.fromRGB(200, 200, 200)
		swoosh.Transparency = 0.7
		swoosh.Anchored = true
		swoosh.CanCollide = false
		swoosh.CanQuery = false
		swoosh.CanTouch = false
		swoosh.Parent = workspace
		task.spawn(function()
			for i = 1, 4 do
				swoosh.Transparency = 0.7 + (i / 4) * 0.3
				task.wait(0.05)
			end
			swoosh:Destroy()
		end)
	end
end)

local function onCharacter(character: Model)
	attachBat(character)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

print("Starfall Brainrots slap bat ready (F or SLAP button).")
