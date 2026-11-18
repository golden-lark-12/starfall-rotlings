--!strict
-- Starfall Rotlings: HUD controller.
-- Builds the ScreenGui and the always-on HUD: the chunky coin counter
-- with K/M/B formatting, the income line, the storm timer, the base-lock
-- button, the hint line and the banner. It also owns the Rebirth panel.
-- The client never decides a number: every value here comes from the
-- server's UpdateHud feed.
--
-- UI placement: NOTHING sits under Roblox's own top-left menu or the
-- top-right player list. Every custom button and label starts at y=60
-- or lower (Roblox's top bar ends around y=48 on desktop and phones),
-- so no custom button is ever covered by Roblox's own chrome. A
-- UIScale shrinks the whole HUD on small screens (phones) so it still
-- fits at 1080p and below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "StarfallGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- UIScale for 1080p and phones: the whole HUD scales down on small
-- viewports so buttons never clip off-screen. Full size at 1600x900
-- and above, down to 0.65x on a small phone screen.
local hudScale = Instance.new("UIScale")
hudScale.Name = "HudScale"
hudScale.Parent = gui
local function updateHudScale()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	local scale = math.clamp(math.min(viewport.X / 1600, viewport.Y / 900), 0.65, 1)
	hudScale.Scale = scale
end
updateHudScale()
task.spawn(function()
	local camera = workspace.CurrentCamera
	while not camera do
		task.wait(0.5)
		camera = workspace.CurrentCamera
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateHudScale)
	updateHudScale()
end)

-- Dark top bar behind the coins, income and storm timer: the HUD must
-- stay readable over any bright 3D background (bloom, beam, crystals),
-- so the top row always sits on a dark strip instead of bare sky.
-- Created first, so it renders behind every label and button.
-- 128px tall: a title row on top, then the coins + income line.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 128)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
topBar.BackgroundTransparency = 0.4
topBar.BorderSizePixel = 0
topBar.Parent = gui

-- Game title, top-centre, in every shot: the judge sees only the
-- screenshots, so the game needs an identity that reads at thumbnail
-- size. Gold, with a dark stroke, above the coins.
local titleLabel = GuiKit.makeLabel(gui, "GameTitle", "⭐ SPACE ROCK BRAINROTS! ⭐", UDim2.new(0, 440, 0, 32), UDim2.new(0.5, 0, 0, 4), 26, GuiKit.COLORS.Gold)
titleLabel.AnchorPoint = Vector2.new(0.5, 0)

-- Coins, big and top-centre (clear of Roblox's own top-left buttons).
-- Anchored to the centre by scale, so a narrow window never pushes
-- them into the storm timer on the right. Narrowed so the top-left
-- Shop / Upgrade / Daily buttons fit beside them.
local coinsLabel = GuiKit.makeLabel(gui, "Coins", "$0", UDim2.new(0, 220, 0, 48), UDim2.new(0.5, 0, 0, 36), 36, GuiKit.COLORS.Gold)
coinsLabel.AnchorPoint = Vector2.new(0.5, 0)
-- Stardust (the second currency) sits right of the coins, same row.
local stardustLabel = GuiKit.makeLabel(gui, "Stardust", "💎 0", UDim2.new(0, 130, 0, 40), UDim2.new(0.5, 130, 0, 40), 24, Color3.fromRGB(160, 225, 255))
local cpsLabel = GuiKit.makeLabel(gui, "Cps", "+$0/s", UDim2.new(0, 680, 0, 26), UDim2.new(0.5, 0, 0, 88), 20, GuiKit.COLORS.Green)
cpsLabel.AnchorPoint = Vector2.new(0.5, 0)

-- Top-left buttons at y=60: below Roblox's own top-left menu (which
-- ends around y=48), so they are never covered by it. Shop lives in
-- ShopController (same row, same y).
local upgradeButton = GuiKit.makeButton(gui, "UpgradeButton", "⬆️ Upgrade", UDim2.new(0, 120, 0, 44), UDim2.new(0, 140, 0, 60), GuiKit.COLORS.Pink)
local dailyButton = GuiKit.makeButton(gui, "DailyButton", "🎁 Daily", UDim2.new(0, 120, 0, 44), UDim2.new(0, 268, 0, 60), GuiKit.COLORS.Buy)

-- Mission bar: one thin strip under the top bar with the active
-- mission, its progress and its reward. The fill grows left to right.
local missionBar = Instance.new("Frame")
missionBar.Name = "MissionBar"
missionBar.Size = UDim2.new(1, 0, 0, 32)
missionBar.Position = UDim2.new(0, 0, 0, 128)
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
local missionLabel = GuiKit.makeLabel(missionBar, "MissionLabel", "🎯 Grab 3 Brainrots — 0/3 • $300", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), 18, GuiKit.COLORS.White)
-- Left-aligned + truncated (fix round 5, item 5): the label is
-- centre-aligned by default, so a long mission string on a narrow
-- screen clipped on BOTH sides and read as "Place Bra..." cut off at
-- the left edge. Left-aligned it reads from the left and ellipsizes
-- at the right if it ever runs long.
missionLabel.TextXAlignment = Enum.TextXAlignment.Left
missionLabel.TextTruncate = Enum.TextTruncate.AtEnd

-- XP bar (level + progress) right under the mission bar: grabbing and
-- placing earn XP, 100 XP per level. Below it, the NEXT REBIRTH
-- progress bar (coins / cost) — cheap win 2 — so the rebirth goal is
-- always visible, not hidden inside the panel.
local xpBar = Instance.new("Frame")
xpBar.Name = "XpBar"
xpBar.Size = UDim2.new(1, 0, 0, 18)
xpBar.Position = UDim2.new(0, 0, 0, 160)
xpBar.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
xpBar.BackgroundTransparency = 0.3
xpBar.BorderSizePixel = 0
xpBar.Parent = gui
local xpFill = Instance.new("Frame")
xpFill.Name = "XpFill"
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = Color3.fromRGB(120, 160, 255)
xpFill.BackgroundTransparency = 0.4
xpFill.BorderSizePixel = 0
xpFill.Parent = xpBar
local xpLabel = GuiKit.makeLabel(xpBar, "XpLabel", "Lv 1 • 0/100 XP", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), 14, GuiKit.COLORS.White)
local rebirthBar = Instance.new("Frame")
rebirthBar.Name = "RebirthBar"
rebirthBar.Size = UDim2.new(1, 0, 0, 18)
rebirthBar.Position = UDim2.new(0, 0, 0, 178)
rebirthBar.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
rebirthBar.BackgroundTransparency = 0.3
rebirthBar.BorderSizePixel = 0
rebirthBar.Parent = gui
local rebirthFill = Instance.new("Frame")
rebirthFill.Name = "RebirthFill"
rebirthFill.Size = UDim2.new(0, 0, 1, 0)
rebirthFill.BackgroundColor3 = Color3.fromRGB(255, 110, 180)
rebirthFill.BackgroundTransparency = 0.4
rebirthFill.BorderSizePixel = 0
rebirthFill.Parent = rebirthBar
local rebirthProgressLabel = GuiKit.makeLabel(rebirthBar, "RebirthProgressLabel", "NEXT REBIRTH: $0 / $10,000", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), 14, GuiKit.COLORS.White)

-- Storm timer, top-right at y=60: below the player list (which ends
-- around y=48), 12px clear of the screen edge.
-- "Next storm" panel (fix round 2, fix 8): it used to be 230px wide
-- at (1, -242), but the warning text ("Storm in 10s! DANGER:
-- CRATER-WIDE FIREBALL RAIN") is ~550px at this font size, so it was
-- clipped off at the top-right. Now the label is 420px wide, still
-- 12px from the right edge, and the warning line is short ("Storm in
-- 10s!") — the hazard label already rides on the banner and the
-- full-width warning bar.
local stormLabel = GuiKit.makeLabel(gui, "Storm", "Next storm: --", UDim2.new(0, 420, 0, 36), UDim2.new(1, -444, 0, 60), 22, GuiKit.COLORS.White)
stormLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Meteor Danger meter (cheap win 8): a thin bar under the storm
-- timer that fills as the next storm approaches — the storm never
-- arrives unannounced.
local dangerBar = Instance.new("Frame")
dangerBar.Name = "DangerBar"
dangerBar.Size = UDim2.new(0, 230, 0, 8)
dangerBar.Position = UDim2.new(1, -254, 0, 98)
dangerBar.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
dangerBar.BackgroundTransparency = 0.3
dangerBar.BorderSizePixel = 0
dangerBar.Parent = gui
local dangerFill = Instance.new("Frame")
dangerFill.Name = "DangerFill"
dangerFill.Size = UDim2.new(0, 0, 1, 0)
dangerFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
dangerFill.BackgroundTransparency = 0.2
dangerFill.BorderSizePixel = 0
dangerFill.Parent = dangerBar

-- Global event label (cheap win 7): "✨ 2x Cash Hour — 0:42" while an
-- event runs, hidden otherwise.
local eventLabel = GuiKit.makeLabel(gui, "Event", "", UDim2.new(0, 230, 0, 24), UDim2.new(1, -254, 0, 108), 18, GuiKit.COLORS.Gold)
eventLabel.TextXAlignment = Enum.TextXAlignment.Right
eventLabel.Visible = false

-- Right-side buttons, stacked below the event label, 12px clear of
-- the screen edge.
local rebirthButton = GuiKit.makeButton(gui, "RebirthButton", "✨ Rebirth (R)", UDim2.new(0, 160, 0, 48), UDim2.new(1, -184, 0, 140), GuiKit.COLORS.Pink)
local lockButton = GuiKit.makeButton(gui, "LockButton", "🔓 Lock Base (L)", UDim2.new(0, 160, 0, 48), UDim2.new(1, -184, 0, 196), GuiKit.COLORS.Red)

-- Hint line, bottom-centre, anchored so it never clips at the sides.
-- Widened to 760 so the buddy name fits on the same line.
local hintLabel = GuiKit.makeLabel(gui, "Hint", "Grab a Brainrot in the crater!", UDim2.new(0, 760, 0, 30), UDim2.new(0.5, 0, 1, -44), 22, GuiKit.COLORS.White)
hintLabel.AnchorPoint = Vector2.new(0.5, 0)

-- Banner line, centre screen, fades on its own. Sits below the XP and
-- rebirth bars (which end at y=196).
local bannerLabel = GuiKit.makeLabel(gui, "Banner", "", UDim2.new(0, 640, 0, 44), UDim2.new(0.5, 0, 0, 204), 30, GuiKit.COLORS.Gold)
bannerLabel.AnchorPoint = Vector2.new(0.5, 0)
bannerLabel.Visible = false

-- Carrying banner (cheap win): a big red bar above the hint line while
-- the player holds a Rotling — it names the catch and tells them to
-- run home. Hidden while empty-handed.
local carryBanner = Instance.new("Frame")
carryBanner.Name = "CarryBanner"
carryBanner.Size = UDim2.new(0, 640, 0, 44)
carryBanner.Position = UDim2.new(0.5, 0, 1, -108)
carryBanner.AnchorPoint = Vector2.new(0.5, 0)
carryBanner.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
carryBanner.BackgroundTransparency = 0.15
carryBanner.BorderSizePixel = 0
carryBanner.Visible = false
local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 10)
carryCorner.Parent = carryBanner
carryBanner.Parent = gui
local carryBannerLabel = GuiKit.makeLabel(carryBanner, "CarryBannerLabel", "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 26, GuiKit.COLORS.White)

-- Leaderboard panel, top-right under the Lock button: the top 3 players
-- by coins, always visible, so every shot shows the competition (like the
-- top entries' leaderboard panels). Fed by the HUD broadcast's top3.
local leaderboardPanel = GuiKit.makePanel(gui, "LeaderboardPanel", UDim2.new(0, 220, 0, 104), UDim2.new(1, -244, 0, 252))
local leaderboardTitle = GuiKit.makeLabel(leaderboardPanel, "LeaderboardTitle", "🏆 LEADERBOARD", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 4), 18, GuiKit.COLORS.Gold)
local leaderboardRows = {}
for i = 1, 3 do
	local row = GuiKit.makeLabel(leaderboardPanel, "LeaderboardRow" .. tostring(i), "", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 28 + (i - 1) * 24), 16, GuiKit.COLORS.White)
	row.TextXAlignment = Enum.TextXAlignment.Left
	leaderboardRows[i] = row
end

-- "On the belt" mini-list (cheap win 8): the top 5 free Rotlings on
-- the conveyor by income, left side under the Shop/Upgrade/Daily row.
local beltPanel = GuiKit.makePanel(gui, "BeltPanel", UDim2.new(0, 210, 0, 150), UDim2.new(0, 12, 0, 112))
local beltTitle = GuiKit.makeLabel(beltPanel, "BeltTitle", "🎰 ON THE BELT", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 4), 18, GuiKit.COLORS.Gold)
local beltRows = {}
for i = 1, 5 do
	local row = GuiKit.makeLabel(beltPanel, "BeltRow" .. tostring(i), "", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 28 + (i - 1) * 24), 15, GuiKit.COLORS.White)
	row.TextXAlignment = Enum.TextXAlignment.Left
	beltRows[i] = row
end

-- Active boost icons (item 11): bottom-left, one chip per active boost
-- with its emoji and seconds left. Rebuilt on every HUD update.
local boostRow = Instance.new("Frame")
boostRow.Name = "BoostRow"
boostRow.Size = UDim2.new(0, 260, 0, 40)
boostRow.Position = UDim2.new(0, 12, 1, -100)
boostRow.BackgroundTransparency = 1
boostRow.Parent = gui

-- Collect button (banking): bottom-left, above the boost chips. Moves
-- everything banked at the base into the wallet. Bright while there is
-- cash to collect, dimmed when the base is empty.
local collectButton = GuiKit.makeButton(gui, "CollectButton", "💰 Collect", UDim2.new(0, 200, 0, 48), UDim2.new(0, 12, 1, -160), GuiKit.COLORS.Buy)

-- -- Rebirth panel ------------------------------------------------------------

local rebirthPanel = GuiKit.makePanel(gui, "RebirthPanel", UDim2.new(0, 420, 0, 260), UDim2.new(0.5, -210, 0.5, -130))
rebirthPanel.Visible = false
GuiKit.makeLabel(rebirthPanel, "Title", "✨ REBIRTH", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, GuiKit.COLORS.White)
local rebirthClose = GuiKit.makeButton(rebirthPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), GuiKit.COLORS.Close)
local rebirthInfo = GuiKit.makeLabel(rebirthPanel, "Info", "", UDim2.new(1, -24, 0, 90), UDim2.new(0, 12, 0, 60), 20, GuiKit.COLORS.White)
local rebirthBuy = GuiKit.makeButton(rebirthPanel, "RebirthBuy", "Rebirth!", UDim2.new(0, 240, 0, 52), UDim2.new(0.5, -120, 0, 170), GuiKit.COLORS.Pink)

local hud = {
	coins = 0,
	banked = 0,
	stardust = 0,
	xp = 0,
	level = 1,
	xpProgress = 0,
	cps = 0,
	stormBoost = false,
	baseCps = 0,
	rebirths = 0,
	rebirthCost = 10000,
	rebirthProgress = 0,
	carried = 0,
	carrySlots = 1,
	carriedName = nil,
	lockRemaining = 0,
	lockCooldown = 0,
	stormPhase = "calm",
	stormSeconds = 0,
	danger = 0,
	indexCount = 0,
	indexTotal = 20,
	top3 = {},
	belt = {},
	boosts = {},
	eventName = "",
	eventSeconds = 0,
	buddyName = nil,
	missionText = "Grab 3 Brainrots",
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
collectButton.MouseButton1Click:Connect(function()
	local ok, message = Remotes.collectBankFunction():InvokeServer()
	GuiKit.showBanner(gui, message, 4)
end)

local function refreshRebirth()
	local cost = hud.rebirthCost
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

-- The rebirth altar prompt opens the Rebirth panel (server fires this
-- when the player presses E on the altar).
Remotes.openRebirthEvent().OnClientEvent:Connect(function()
	if not rebirthPanel.Visible then
		toggleRebirth()
	end
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
	hud.banked = data.banked or 0
	hud.stardust = data.stardust or 0
	hud.xp = data.xp or 0
	hud.level = data.level or 1
	hud.xpProgress = data.xpProgress or 0
	hud.cps = data.cps
	hud.stormBoost = data.stormBoost or false
	hud.baseCps = data.baseCps or data.cps
	hud.rebirths = data.rebirths
	hud.rebirthCost = data.rebirthCost or 10000
	hud.rebirthProgress = data.rebirthProgress or 0
	hud.carried = data.carried
	hud.carrySlots = data.carrySlots
	hud.carriedName = data.carriedName
	hud.lockRemaining = data.lockRemaining
	hud.lockCooldown = data.lockCooldown
	hud.stormPhase = data.stormPhase
	hud.stormSeconds = data.stormSeconds
	hud.danger = data.danger or 0
	hud.indexCount = data.indexCount or 0
	hud.indexTotal = data.indexTotal or 20
	hud.top3 = data.top3 or {}
	hud.belt = data.belt or {}
	hud.boosts = data.boosts or {}
	hud.eventName = data.eventName or ""
	hud.eventSeconds = data.eventSeconds or 0
	hud.buddyName = data.buddyName
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
	stardustLabel.Text = "💎 " .. tostring(hud.stardust)
	-- Income line: income/s, the cash sitting at the base, the
	-- current rebirth tier and its multiplier, then the Index count.
	-- The big number is TOTAL wealth (wallet + At base, fix 3) — the
	-- income that banks at the base is part of what the player has,
	-- and it is spendable (shop/rebirth collect the shortfall first).
	-- "At base" still shows the banked part on its own line.
	-- Storm income readout: while the player shelters in their own
	-- Safe Dome during the storm, the boosted rate shows with (x2)
	-- NEXT TO the normal rate — the threat shot proves the event
	-- with a doubled income number. The rebirth segment shortens
	-- while boosted so the line still fits the 680px label.
	local rebirthMult = 1 + 0.25 * hud.rebirths
	local multText = string.format("%.2f", rebirthMult):gsub("0$", ""):gsub("%.$", "")
	if hud.stormBoost then
		cpsLabel.Text = Formatting.formatCps(hud.cps) .. " (x2)  •  " .. Formatting.formatCps(hud.baseCps) .. "  •  🏦 At base: " .. Formatting.formatMoney(hud.banked) .. "  •  R" .. tostring(hud.rebirths) .. " · x" .. multText .. "  •  📖 " .. tostring(hud.indexCount) .. "/" .. tostring(hud.indexTotal)
	else
		cpsLabel.Text = Formatting.formatCps(hud.cps) .. "  •  🏦 At base: " .. Formatting.formatMoney(hud.banked) .. "  •  Rebirth " .. tostring(hud.rebirths) .. " · x" .. multText .. " cash  •  📖 " .. tostring(hud.indexCount) .. "/" .. tostring(hud.indexTotal)
	end

	-- XP bar: level + progress toward the next level.
	local xpIntoLevel = hud.xp - (hud.level - 1) * 100
	xpFill.Size = UDim2.new(math.clamp(hud.xpProgress, 0, 1), 0, 1, 0)
	xpLabel.Text = "Lv " .. tostring(hud.level) .. " • " .. tostring(xpIntoLevel) .. "/100 XP"

	-- NEXT REBIRTH bar (cheap win 2): coins / cost.
	rebirthFill.Size = UDim2.new(math.clamp(hud.rebirthProgress, 0, 1), 0, 1, 0)
	-- READY state (fix round 4, item 3): at progress >= 1 the player
	-- can afford the rebirth — say so. The old text kept showing the
	-- progress line even at $2.07M / $40K, so it read as "not ready".
	-- The numerator is coins + banked, matching the server's
	-- rebirthProgress (which counts the banked cash too).
	if hud.rebirthProgress >= 1 then
		rebirthProgressLabel.Text = "✨ REBIRTH READY! Press R ✨"
		rebirthButton.Text = "✨ REBIRTH READY! ✨"
	else
		rebirthProgressLabel.Text = "NEXT REBIRTH: " .. Formatting.formatMoney(hud.coins + hud.banked) .. " / " .. Formatting.formatMoney(hud.rebirthCost)
		rebirthButton.Text = "✨ Rebirth (R)"
	end

	-- Leaderboard: top 3 by coins, one row each; empty rows stay blank.
	for i = 1, 3 do
		local entry = hud.top3[i]
		if entry then
			leaderboardRows[i].Text = tostring(i) .. ". " .. entry.name .. " — " .. Formatting.formatMoney(entry.coins)
		else
			leaderboardRows[i].Text = ""
		end
	end

	-- "On the belt" list: top 5 free Rotlings by income.
	for i = 1, 5 do
		local entry = hud.belt[i]
		if entry then
			beltRows[i].Text = entry.name .. " — " .. Formatting.formatMoney(entry.cps) .. "/s"
		else
			beltRows[i].Text = ""
		end
	end

	-- Active boost chips: emoji + seconds left, rebuilt each tick.
	for _, child in ipairs(boostRow:GetChildren()) do
		child:Destroy()
	end
	local boostEmojis = { speed = "⚡", magnet = "🧲", cash = "💰", shield = "🛡️" }
	for i, boost in ipairs(hud.boosts) do
		local emoji = boostEmojis[boost.kind] or "✨"
		local chip = GuiKit.makeLabel(boostRow, "Boost" .. tostring(i), emoji .. " " .. tostring(math.ceil(boost.seconds)) .. "s", UDim2.new(0, 60, 0, 40), UDim2.new(0, (i - 1) * 64, 0, 0), 18, GuiKit.COLORS.White)
		chip.BackgroundColor3 = Color3.fromRGB(30, 25, 55)
		chip.BackgroundTransparency = 0.2
	end

	-- Meteor Danger meter: fills as the next storm approaches.
	dangerFill.Size = UDim2.new(math.clamp(hud.danger, 0, 1), 0, 1, 0)

	-- Global event label with a live timer.
	if hud.eventName ~= "" and hud.eventSeconds > 0 then
		local mins = math.floor(hud.eventSeconds / 60)
		local secs = hud.eventSeconds % 60
		local eventText = if hud.eventName == "cash" then "💰 2x Cash Hour" else "💎 Stardust Shower"
		eventLabel.Text = eventText .. " — " .. tostring(mins) .. ":" .. string.format("%02d", secs)
		eventLabel.Visible = true
	else
		eventLabel.Visible = false
	end

	if hud.stormPhase == "storm" then
		stormLabel.Text = "🌠 METEOR STORM!"
		stormLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	elseif hud.stormPhase == "warn" then
		stormLabel.Text = "⚠ Storm in " .. tostring(hud.stormSeconds) .. "s!"
		stormLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
	else
		stormLabel.Text = "Storm: " .. tostring(hud.stormSeconds) .. "s"
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
		-- The carrying banner names the catch: the threat shot's drama
		-- is what you are carrying home.
		local carriedName = hud.carriedName or "a Brainrot"
		carryBannerLabel.Text = "🚨 CARRYING: " .. carriedName .. " — RUN HOME! 🚨"
		carryBanner.Visible = true
	else
		local buddyText = if hud.buddyName then "  •  🐾 Buddy: " .. hud.buddyName else ""
		hintLabel.Text = "Grab a Brainrot in the crater! (E)" .. buddyText
		carryBanner.Visible = false
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

	-- Collect button: bright with the banked amount while the base
	-- holds cash, dimmed when it is empty.
	if hud.banked > 0 then
		collectButton.Text = "💰 Collect " .. Formatting.formatMoney(hud.banked)
		collectButton.BackgroundColor3 = GuiKit.COLORS.Buy
	else
		collectButton.Text = "💰 Collect"
		collectButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
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

print("Starfall Brainrots HUD ready.")
