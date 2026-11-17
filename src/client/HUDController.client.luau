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

-- Coins, big and top-centre (clear of Roblox's own top-left buttons).
local coinsLabel = GuiKit.makeLabel(gui, "Coins", "$0", UDim2.new(0, 340, 0, 56), UDim2.new(0.5, -170, 0, 8), 44, Color3.fromRGB(255, 225, 90))
local cpsLabel = GuiKit.makeLabel(gui, "Cps", "+$0/s", UDim2.new(0, 340, 0, 30), UDim2.new(0.5, -170, 0, 64), 24, Color3.fromRGB(160, 255, 170))

-- Storm timer, top-right.
local stormLabel = GuiKit.makeLabel(gui, "Storm", "Next storm: --", UDim2.new(0, 260, 0, 36), UDim2.new(1, -270, 0, 10), 22, Color3.fromRGB(255, 255, 255))
stormLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Right-side buttons.
local rebirthButton = GuiKit.makeButton(gui, "RebirthButton", "✨ Rebirth (R)", UDim2.new(0, 170, 0, 48), UDim2.new(1, -185, 0, 60), Color3.fromRGB(255, 110, 180))
local lockButton = GuiKit.makeButton(gui, "LockButton", "🔓 Lock Base (L)", UDim2.new(0, 170, 0, 48), UDim2.new(1, -185, 0, 116), Color3.fromRGB(255, 90, 90))

-- Hint line, bottom-centre.
local hintLabel = GuiKit.makeLabel(gui, "Hint", "Grab a Rotling in the crater!", UDim2.new(0, 700, 0, 30), UDim2.new(0.5, -350, 1, -44), 22, Color3.fromRGB(255, 255, 255))

-- Banner line, centre screen, fades on its own.
local bannerLabel = GuiKit.makeLabel(gui, "Banner", "", UDim2.new(0, 760, 0, 44), UDim2.new(0.5, -380, 0, 130), 30, Color3.fromRGB(255, 240, 120))
bannerLabel.Visible = false

-- -- Rebirth panel ------------------------------------------------------------

local rebirthPanel = GuiKit.makePanel(gui, "RebirthPanel", UDim2.new(0, 420, 0, 260), UDim2.new(0.5, -210, 0.5, -130))
rebirthPanel.Visible = false
GuiKit.makeLabel(rebirthPanel, "Title", "✨ REBIRTH", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, Color3.fromRGB(255, 255, 255))
local rebirthClose = GuiKit.makeButton(rebirthPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), Color3.fromRGB(200, 60, 60))
local rebirthInfo = GuiKit.makeLabel(rebirthPanel, "Info", "", UDim2.new(1, -24, 0, 90), UDim2.new(0, 12, 0, 60), 20, Color3.fromRGB(255, 255, 255))
local rebirthBuy = GuiKit.makeButton(rebirthPanel, "RebirthBuy", "Rebirth!", UDim2.new(0, 240, 0, 52), UDim2.new(0.5, -120, 0, 170), Color3.fromRGB(255, 110, 180))

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
}

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

Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	hud.coins = data.coins
	hud.cps = data.cps
	hud.rebirths = data.rebirths
	hud.carried = data.carried
	hud.carrySlots = data.carrySlots
	hud.lockRemaining = data.lockRemaining
	hud.lockCooldown = data.lockCooldown
	hud.stormPhase = data.stormPhase
	hud.stormSeconds = data.stormSeconds

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
		lockButton.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
	end

	if hud.carried > 0 then
		hintLabel.Text = "Carrying " .. tostring(hud.carried) .. "/" .. tostring(hud.carrySlots) .. " — stand on your base and press E on a pad!"
	else
		hintLabel.Text = "Grab a Rotling in the crater! (E)"
	end

	if rebirthPanel.Visible then
		refreshRebirth()
	end
end)

print("Starfall Rotlings HUD ready.")
