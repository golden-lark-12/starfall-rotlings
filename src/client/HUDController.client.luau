--!strict
-- Starfall Rotlings: HUD controller.
-- Builds the ScreenGui and the always-on HUD: the chunky coin counter
-- with K/M/B formatting, the income line, the storm timer, the base-lock
-- button, the hint line and the banner. It also owns the Rebirth panel.
-- The client never decides a number: every value here comes from the
-- server's UpdateHud feed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "StarfallGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Dark top bar behind the coins, income and storm timer: the HUD must
-- stay readable over any bright 3D background (bloom, beam, crystals),
-- so the top row always sits on a dark strip instead of bare sky.
-- Created first, so it renders behind every label and button.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 104)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
topBar.BackgroundTransparency = 0.4
topBar.BorderSizePixel = 0
topBar.Parent = gui

-- Coins, big and top-centre (clear of Roblox's own top-left buttons).
-- Anchored to the centre by scale, so a narrow window never pushes
-- them into the storm timer on the right. Narrowed so the top-left
-- Shop / Upgrade / Daily buttons fit beside them.
local coinsLabel = GuiKit.makeLabel(gui, "Coins", "$0", UDim2.new(0, 220, 0, 56), UDim2.new(0.5, 0, 0, 8), 44, GuiKit.COLORS.Gold)
coinsLabel.AnchorPoint = Vector2.new(0.5, 0)
local cpsLabel = GuiKit.makeLabel(gui, "Cps", "+$0/s", UDim2.new(0, 220, 0, 30), UDim2.new(0.5, 0, 0, 64), 24, GuiKit.COLORS.Green)
cpsLabel.AnchorPoint = Vector2.new(0.5, 0)

-- Top-left buttons: Upgrade opens the shop on the upgrade rows, Daily
-- claims the daily reward. Shop lives in ShopController (same row).
local upgradeButton = GuiKit.makeButton(gui, "UpgradeButton", "⬆️ Upgrade", UDim2.new(0, 120, 0, 44), UDim2.new(0, 140, 0, 30), GuiKit.COLORS.Pink)
local dailyButton = GuiKit.makeButton(gui, "DailyButton", "🎁 Daily", UDim2.new(0, 120, 0, 44), UDim2.new(0, 268, 0, 30), GuiKit.COLORS.Buy)

-- Mission bar: one thin strip under the top bar with the active
-- mission, its progress and its reward. The fill grows left to right.
local missionBar = Instance.new("Frame")
missionBar.Name = "MissionBar"
missionBar.Size = UDim2.new(1, 0, 0, 32)
missionBar.Position = UDim2.new(0, 0, 0, 104)
missionBar.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
missionBar.BackgroundTransparency = 0.3
missionBar.BorderSizePixel = 0
missionBar.Parent = gui
local missionFill = Instance.new("Frame")
missionFill.Name = "MissionFill"
missionFill.Size = UDim2.new(0, 0, 1, 0)
missionFill.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
missionFill.BackgroundTransparency = 0.4
missionFill.BorderSizePixel = 0
missionFill.Parent = missionBar
local missionLabel = GuiKit.makeLabel(missionBar, "MissionLabel", "🎯 Grab 3 Rotlings — 0/3 • $300", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), 18, GuiKit.COLORS.White)

-- Storm timer, top-right, 12px clear of the screen edge.
local stormLabel = GuiKit.makeLabel(gui, "Storm", "Next storm: --", UDim2.new(0, 230, 0, 36), UDim2.new(1, -242, 0, 10), 22, GuiKit.COLORS.White)
stormLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Right-side buttons, 12px clear of the screen edge.
local rebirthButton = GuiKit.makeButton(gui, "RebirthButton", "✨ Rebirth (R)", UDim2.new(0, 160, 0, 48), UDim2.new(1, -172, 0, 60), GuiKit.COLORS.Pink)
local lockButton = GuiKit.makeButton(gui, "LockButton", "🔓 Lock Base (L)", UDim2.new(0, 160, 0, 48), UDim2.new(1, -172, 0, 116), GuiKit.COLORS.Red)

-- Hint line, bottom-centre, anchored so it never clips at the sides.
local hintLabel = GuiKit.makeLabel(gui, "Hint", "Grab a Rotling in the crater!", UDim2.new(0, 620, 0, 30), UDim2.new(0.5, 0, 1, -44), 22, GuiKit.COLORS.White)
hintLabel.AnchorPoint = Vector2.new(0.5, 0)

-- Banner line, centre screen, fades on its own. Sits below the
-- mission bar (which ends at y=136).
local bannerLabel = GuiKit.makeLabel(gui, "Banner", "", UDim2.new(0, 640, 0, 44), UDim2.new(0.5, 0, 0, 150), 30, GuiKit.COLORS.Gold)
bannerLabel.AnchorPoint = Vector2.new(0.5, 0)
bannerLabel.Visible = false

-- -- Rebirth panel ------------------------------------------------------------

local rebirthPanel = GuiKit.makePanel(gui, "RebirthPanel", UDim2.new(0, 420, 0, 260), UDim2.new(0.5, -210, 0.5, -130))
rebirthPanel.Visible = false
GuiKit.makeLabel(rebirthPanel, "Title", "✨ REBIRTH", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, GuiKit.COLORS.White)
local rebirthClose = GuiKit.makeButton(rebirthPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), GuiKit.COLORS.Close)
local rebirthInfo = GuiKit.makeLabel(rebirthPanel, "Info", "", UDim2.new(1, -24, 0, 90), UDim2.new(0, 12, 0, 60), 20, GuiKit.COLORS.White)
local rebirthBuy = GuiKit.makeButton(rebirthPanel, "RebirthBuy", "Rebirth!", UDim2.new(0, 240, 0, 52), UDim2.new(0.5, -120, 0, 170), GuiKit.COLORS.Pink)

local hud = {
	coins = 0,
	cps = 0,
	rebirths = 0,
	carried = 0,
	carrySlots = 1,
	lockRemaining = 0,
	lockCooldown = 0,
	stormPhase = "calm",
	stormSeconds = 0,
	missionText = "Grab 3 Rotlings",
	missionProgress = 0,
	missionTarget = 3,
	missionReward = 300,
	dailyReady = false,
}

-- Top buttons: Upgrade opens the shop on the upgrade rows; Daily asks
-- the server for the daily reward (it owns the clock).
upgradeButton.MouseButton1Click:Connect(function()
	GuiKit.openShopEvent(gui):Fire("upgrade")
end)
dailyButton.MouseButton1Click:Connect(function()
	local ok, message = Remotes.dailyFunction():InvokeServer()
	GuiKit.showBanner(gui, message, 4)
end)

local function refreshRebirth()
	local cost = 10000 * (hud.rebirths + 1) * (hud.rebirths + 1)
	local mult = 1 + 0.25 * hud.rebirths
	rebirthInfo.Text = "Rebirths: " .. tostring(hud.rebirths) .. " (income x" .. string.format("%.2f", mult) .. ")\nReset your coins for +25% income forever,\nand your base wears a new colour."
	rebirthBuy.Text = "Rebirth — " .. Formatting.formatMoney(cost)
end

local function toggleRebirth()
	local wasOpen = rebirthPanel.Visible
	GuiKit.closeOtherPanels(gui, "RebirthPanel")
	rebirthPanel.Visible = not wasOpen
	if rebirthPanel.Visible then
		refreshRebirth()
	end
end

rebirthButton.MouseButton1Click:Connect(toggleRebirth)
rebirthClose.MouseButton1Click:Connect(function()
	rebirthPanel.Visible = false
end)
rebirthBuy.MouseButton1Click:Connect(function()
	local ok, message = Remotes.rebirthFunction():InvokeServer()
	GuiKit.showBanner(gui, message, 4)
	refreshRebirth()
end)
lockButton.MouseButton1Click:Connect(function()
	Remotes.lockEvent():FireServer()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		toggleRebirth()
	elseif input.KeyCode == Enum.KeyCode.L then
		Remotes.lockEvent():FireServer()
	end
end)

Remotes.bannerEvent().OnClientEvent:Connect(function(text: string, duration: number)
	GuiKit.showBanner(gui, text, duration)
end)

-- The HUD feed: the server fires UpdateHud every second with coins, cps
-- and the storm phase/seconds. The remote lookup is retried in a loop so
-- a slow ReplicatedStorage replication can never silently kill the feed
-- (a failed top-level lookup used to die here, leaving "Next storm: --"
-- on screen forever). The server sends phases "calm" / "warn" /
-- "storm" — the names must match StarfallService.setPhase exactly.
local hudEventReceived = false
local function onHudData(data: Remotes.HudData)
	hud.coins = data.coins
	hud.cps = data.cps
	hud.rebirths = data.rebirths
	hud.carried = data.carried
	hud.carrySlots = data.carrySlots
	hud.lockRemaining = data.lockRemaining
	hud.lockCooldown = data.lockCooldown
	hud.stormPhase = data.stormPhase
	hud.stormSeconds = data.stormSeconds
	hud.missionText = data.missionText
	hud.missionProgress = data.missionProgress
	hud.missionTarget = data.missionTarget
	hud.missionReward = data.missionReward
	hud.dailyReady = data.dailyReady
	if not hudEventReceived then
		hudEventReceived = true
		print("[HUD] first UpdateHud received: phase=" .. tostring(hud.stormPhase) .. " seconds=" .. tostring(hud.stormSeconds) .. " coins=" .. tostring(hud.coins))
	end

	coinsLabel.Text = Formatting.formatMoney(hud.coins)
	cpsLabel.Text = Formatting.formatCps(hud.cps) .. "  •  Rebirths: " .. tostring(hud.rebirths)

	if hud.stormPhase == "storm" then
		stormLabel.Text = "🌠 METEOR STORM!"
		stormLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	elseif hud.stormPhase == "warn" then
		stormLabel.Text = "⚠ Storm in " .. tostring(hud.stormSeconds) .. "s!"
		stormLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
	else
		stormLabel.Text = "Next storm: " .. tostring(hud.stormSeconds) .. "s"
		stormLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	if hud.lockRemaining > 0 then
		lockButton.Text = "🔒 Locked " .. tostring(math.ceil(hud.lockRemaining)) .. "s"
		lockButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
	elseif hud.lockCooldown > 0 then
		lockButton.Text = "Lock (" .. tostring(math.ceil(hud.lockCooldown)) .. "s)"
		lockButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
	else
		lockButton.Text = "🔓 Lock Base (L)"
		lockButton.BackgroundColor3 = GuiKit.COLORS.Red
	end

	if hud.carried > 0 then
		hintLabel.Text = "Carrying " .. tostring(hud.carried) .. "/" .. tostring(hud.carrySlots) .. " — stand on your base and press E on a pad!"
	else
		hintLabel.Text = "Grab a Rotling in the crater! (E)"
	end

	-- Mission bar: text + progress + reward, fill grows left to right.
	local target = math.max(1, hud.missionTarget)
	missionLabel.Text = "🎯 " .. hud.missionText .. " — " .. tostring(math.min(hud.missionProgress, target)) .. "/" .. tostring(target)
		.. " • " .. Formatting.formatMoney(hud.missionReward)
	missionFill.Size = UDim2.new(math.clamp(hud.missionProgress / target, 0, 1), 0, 1, 0)

	-- Daily button: bright when a claim is up, dimmed once claimed.
	if hud.dailyReady then
		dailyButton.Text = "🎁 Daily"
		dailyButton.BackgroundColor3 = GuiKit.COLORS.Buy
	else
		dailyButton.Text = "🎁 Daily ✓"
		dailyButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
	end

	if rebirthPanel.Visible then
		refreshRebirth()
	end
end

task.spawn(function()
	while true do
		local ok, hudEvent = pcall(function()
			return Remotes.hudEvent()
		end)
		if ok and hudEvent then
			hudEvent.OnClientEvent:Connect(onHudData)
			print("[HUD] connected to UpdateHud")
			break
		end
		task.wait(1)
	end
end)

print("Starfall Rotlings HUD ready.")
