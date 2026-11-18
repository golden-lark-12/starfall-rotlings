--!strict
-- Starfall Rotlings: sprint controller.
-- Hold Shift (keyboard) or the on-screen Run button (touch) to sprint:
-- walk speed 16 -> 26, a stamina bar that drains while you run and
-- refills when you stop, and a field-of-view kick so the speed reads.
-- The base speed follows the shop Speed tier (16 + 2 per tier, from the
-- HUD feed); sprinting is always base + 10, so 16 -> 26 at tier 0.
-- Sprinting stops when stamina hits 0 and cannot restart until it
-- climbs back above SPRINT_STAMINA_MIN. The Run button sits at the
-- bottom-right, below the HUD, and only shows on touch devices.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer
local gui = GuiKit.getGui()

local stamina = Config.SPRINT_STAMINA_MAX
local shiftHeld = false
local runHeld = false
local sprinting = false
local baseSpeed = Config.SPRINT_BASE_SPEED -- 16 + 2 per Speed tier, from the HUD feed
local fovTween: Tween? = nil

-- Stamina bar: a thin bar above the hint line, bottom-centre. Hidden
-- when stamina is full and you are not sprinting, so it never clutters
-- a calm screenshot.
local staminaBar = Instance.new("Frame")
staminaBar.Name = "StaminaBar"
staminaBar.Size = UDim2.new(0, 220, 0, 12)
staminaBar.Position = UDim2.new(0.5, -110, 1, -84)
staminaBar.AnchorPoint = Vector2.new(0.5, 0)
staminaBar.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
staminaBar.BackgroundTransparency = 0.3
staminaBar.BorderSizePixel = 0
staminaBar.Visible = false
staminaBar.Parent = gui
local staminaCorner = Instance.new("UICorner")
staminaCorner.CornerRadius = UDim.new(0, 6)
staminaCorner.Parent = staminaBar
local staminaFill = Instance.new("Frame")
staminaFill.Name = "StaminaFill"
staminaFill.Size = UDim2.new(1, 0, 1, 0)
staminaFill.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
staminaFill.BorderSizePixel = 0
staminaFill.Parent = staminaBar
local staminaFillCorner = Instance.new("UICorner")
staminaFillCorner.CornerRadius = UDim.new(0, 6)
staminaFillCorner.Parent = staminaFill

-- Mobile Run button: bottom-right, big enough for a thumb. Only on
-- touch devices; keyboard players use Shift.
local runButton = GuiKit.makeButton(gui, "RunButton", "🏃 RUN", UDim2.new(0, 110, 0, 64), UDim2.new(1, -126, 1, -180), GuiKit.COLORS.Blue)
runButton.Visible = UserInputService.TouchEnabled

local function setSprinting(on: boolean)
	if on == sprinting then
		return
	end
	sprinting = on
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if on then
		if humanoid then
			humanoid.WalkSpeed = baseSpeed + (Config.SPRINT_SPEED - Config.SPRINT_BASE_SPEED)
		end
		if camera then
			if fovTween then
				fovTween:Cancel()
			end
			fovTween = TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FieldOfView = Config.SPRINT_FOV,
			})
			fovTween:Play()
		end
		staminaBar.Visible = true
	else
		if humanoid then
			humanoid.WalkSpeed = baseSpeed
		end
		if camera then
			if fovTween then
				fovTween:Cancel()
			end
			fovTween = TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FieldOfView = Config.SPRINT_FOV_BASE,
			})
			fovTween:Play()
		end
		if stamina >= Config.SPRINT_STAMINA_MAX then
			staminaBar.Visible = false
		end
	end
end

local function wantsSprint(): boolean
	return (shiftHeld or runHeld) and stamina > 0
end

-- Base speed follows the shop Speed tier in the HUD feed, the Speed
-- Coil boost (x1.4 while active) and the meteor-egg slow (-6 while
-- carrying an egg — the server enforces the same numbers, so the
-- client can never outrun its own carry).
local eggCarried = false
Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	local speedMult = 1
	for _, boost in ipairs(data.boosts or {}) do
		if boost.kind == "speed" then
			speedMult = Config.BOOST_SPEED_MULT
			break
		end
	end
	eggCarried = data.eggCarried or false
	baseSpeed = (Config.BASE_WALKSPEED + Config.SPEED_PER_TIER * (data.speedTier or 0)) * speedMult
	if eggCarried then
		baseSpeed = math.max(8, baseSpeed - Config.EGG_SLOW)
	end
	if not sprinting then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = baseSpeed
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		shiftHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		shiftHeld = false
	end
end)

runButton.MouseButton1Down:Connect(function()
	runHeld = true
end)
runButton.MouseButton1Up:Connect(function()
	runHeld = false
end)
runButton.MouseLeave:Connect(function()
	runHeld = false
end)

-- Stamina loop: drain while sprinting, refill when stopped. Sprint
-- cannot restart until stamina climbs back above SPRINT_STAMINA_MIN.
RunService.Heartbeat:Connect(function(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		setSprinting(false)
		return
	end
	if wantsSprint() and (sprinting or stamina > Config.SPRINT_STAMINA_MIN) then
		setSprinting(true)
		stamina = math.max(0, stamina - Config.SPRINT_STAMINA_DRAIN * dt)
		if stamina <= 0 then
			setSprinting(false)
		end
	else
		setSprinting(false)
		stamina = math.min(Config.SPRINT_STAMINA_MAX, stamina + Config.SPRINT_STAMINA_REGEN * dt)
	end
	staminaFill.Size = UDim2.new(math.clamp(stamina / Config.SPRINT_STAMINA_MAX, 0, 1), 0, 1, 0)
	staminaFill.BackgroundColor3 = if stamina < 25 then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(120, 220, 255)
	if sprinting or stamina < Config.SPRINT_STAMINA_MAX then
		staminaBar.Visible = true
	else
		staminaBar.Visible = false
	end
end)

print("Starfall Brainrots sprint ready (Shift or RUN).")
