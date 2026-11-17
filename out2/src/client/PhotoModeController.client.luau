--!strict
-- Starfall Rotlings: photo mode (debug).
-- Press P (or type /photo in chat) to step through 5 fixed camera
-- shots, the same views both sides judge: (1) spawn, (2) crater,
-- (3) my base with sign, (4) carrying a Rotling, (5) the HUD with
-- name tags. Each shot is a deterministic fixed CFrame — never a
-- free-fly — and the chat is hidden while a shot is framed, so the
-- capture is clean. A 6th press exits photo mode and hands the camera
-- back to the player.
--
-- Roblox gives a LocalScript no screenshot-file API, so a shot is
-- CAPTURED by the player: the bar at the bottom of each shot says so.
-- Open the ⋯ menu → Screenshot and it saves to the device's
-- Photos/Pictures, ready to send back. On desktop the same button is
-- in the in-game menu (Esc).
--
-- CameraFX shakes the camera during storms; it checks the camera's
-- "PhotoMode" attribute and never shakes while a shot is framed, so
-- every shot is a fixed frame even mid-storm.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer

-- The 5 shots, in order. Positions are fixed in world space (spawn,
-- crater and the HUD shot) or fixed relative to the player (base and
-- carrying). Tune a CFrame here and every capture of that shot moves.
local SHOTS = {
	{
		name = "1/5 — Spawn",
		detail = "The slab, the path and the crater ahead",
		position = Vector3.new(108, 7, 8),
		lookAt = Vector3.new(20, 8, -12),
	},
	{
		name = "2/5 — Crater",
		detail = "Free Rotlings, crystals and the beacon",
		position = Vector3.new(22, 13, 22),
		lookAt = Vector3.new(0, 1, 0),
	},
	{
		name = "3/5 — My base",
		detail = "Pads, sign and cash counter",
		position = nil, -- computed from the nearest base, below
		lookAt = nil,
	},
	{
		name = "4/5 — Carrying",
		detail = "The Rotling above your head",
		position = nil, -- computed from the character, below
		lookAt = nil,
	},
	{
		name = "5/5 — HUD + tags",
		detail = "Coins, storm, buttons and name tags",
		position = Vector3.new(28, 5, 8),
		lookAt = Vector3.new(0, 2, 0),
	},
}

local shotIndex = 0 -- 0 = photo mode off; 1-5 = the shot showing

local gui = Instance.new("ScreenGui")
gui.Name = "PhotoModeGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

-- Bottom bar: shot name on top, capture instruction under it. It sits
-- above the HUD hint line, so it covers no HUD element.
local bar = GuiKit.makePanel(gui, "PhotoBar", UDim2.new(0, 620, 0, 56), UDim2.new(0.5, -310, 1, -108))
bar.Visible = false
local titleLabel = GuiKit.makeLabel(bar, "PhotoTitle", "", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 2), 22, GuiKit.COLORS.Gold)
local helpLabel = GuiKit.makeLabel(bar, "PhotoHelp", "", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 28), 17, GuiKit.COLORS.White)
local nextButton = GuiKit.makeButton(bar, "NextShot", "Next ▶", UDim2.new(0, 110, 0, 40), UDim2.new(1, -122, 0, 8), GuiKit.COLORS.Blue)
local exitButton = GuiKit.makeButton(bar, "ExitPhoto", "Exit ✕", UDim2.new(0, 110, 0, 40), UDim2.new(0, 12, 0, 8), GuiKit.COLORS.Close)

-- Base centres ring the crater: base id 1 at angle 0, the rest every
-- 360/BASE_COUNT degrees. The nearest one to the player is their base.
local function nearestBaseCenter(): Vector3
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local from = if root then root.Position else Vector3.new(Config.BASE_RADIUS, 0, 0)
	local best = Vector3.new(Config.BASE_RADIUS, 0, 0)
	local bestDist = math.huge
	for baseId = 1, Config.BASE_COUNT do
		local angle = math.rad((baseId - 1) * (360 / Config.BASE_COUNT))
		local center = Vector3.new(math.cos(angle) * Config.BASE_RADIUS, 0, math.sin(angle) * Config.BASE_RADIUS)
		local dist = (Vector3.new(from.X, 0, from.Z) - center).Magnitude
		if dist < bestDist then
			bestDist = dist
			best = center
		end
	end
	return best
end

-- Is the player carrying a Rotling right now? The server marks a
-- carried model State "carried" with the carrier's UserId on it.
local function isCarrying(): boolean
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model")
			and descendant:GetAttribute("State") == "carried"
			and descendant:GetAttribute("OwnerUserId") == player.UserId
		then
			return true
		end
	end
	return false
end

local function shotCFrame(index: number): CFrame
	local shot = SHOTS[index]
	if index == 3 then
		-- My base: 30 studs out on the crater side, 12 up, looking
		-- back at the platform so the pads and the sign both show.
		local center = nearestBaseCenter()
		local towardCrater = (Vector3.new(0, 0, 0) - center).Unit
		local position = center + Vector3.new(towardCrater.X, 0, towardCrater.Z) * 30 + Vector3.new(0, 12, 0)
		return CFrame.lookAt(position, center + Vector3.new(0, 4, 0))
	elseif index == 4 then
		-- Carrying: close on the character from front-right-above,
		-- looking at the head where the Rotling rides.
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local at = if root then root.Position else Vector3.new(0, 3, 0)
		return CFrame.lookAt(at + Vector3.new(5, 3.5, 7), at + Vector3.new(0, 3.2, 0))
	end
	return CFrame.lookAt(shot.position :: Vector3, shot.lookAt :: Vector3)
end

local function hideChat()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	end)
end

local function showChat()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	end)
end

local function exitPhotoMode()
	shotIndex = 0
	bar.Visible = false
	local camera = workspace.CurrentCamera
	if camera then
		camera:SetAttribute("PhotoMode", false)
		camera.CameraType = Enum.CameraType.Custom
	end
	showChat()
end

local function showShot(index: number)
	shotIndex = index
	local shot = SHOTS[index]
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Scriptable camera, fixed frame, no storm shake (CameraFX reads
	-- the PhotoMode attribute and stands down while it is set).
	camera.CameraType = Enum.CameraType.Scriptable
	camera:SetAttribute("PhotoMode", true)
	camera.CFrame = shotCFrame(index)
	hideChat()
	local detail = shot.detail
	if index == 4 and not isCarrying() then
		detail ..= " — not carrying: grab a Rotling first, then press P"
	end
	titleLabel.Text = "📷 Photo " .. shot.name .. " — " .. detail
	helpLabel.Text = "Capture it: ⋯ menu → Screenshot (saves to Photos). P = next shot."
	nextButton.Text = if index == 5 then "Exit ✕" else "Next ▶"
	bar.Visible = true
end

local function advanceShot()
	if shotIndex == 0 then
		showShot(1)
	elseif shotIndex >= 5 then
		exitPhotoMode()
	else
		showShot(shotIndex + 1)
	end
end

nextButton.MouseButton1Click:Connect(function()
	advanceShot()
end)
exitButton.MouseButton1Click:Connect(function()
	exitPhotoMode()
end)

ContextActionService:BindAction("PhotoMode", function(_, inputState: EnumItem)
	if inputState == Enum.UserInputState.Begin then
		advanceShot()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.P)

player.Chatted:Connect(function(message: string)
	if message == "/photo" then
		advanceShot()
	end
end)

print("Starfall Rotlings photo mode ready (P or /photo).")
