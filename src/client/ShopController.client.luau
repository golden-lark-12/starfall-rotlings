--!strict
-- Starfall Rotlings: shop controller.
-- The shop panel: eight ladders (speed, extra arms, income, extra
-- pads, longer locks, stamina, egg warmer, power slap — the last
-- three are fix round 8, item 6) with tier dots and buy buttons. The
-- client only asks to buy; the server checks the price and answers
-- with the result. The ladder rows live in a ScrollingFrame (8 rows
-- x 96px = 768px, taller than the panel's ladder area), so the panel
-- stays 780px tall and the rows scroll on a phone. The Shop button
-- sits in the top-left row at y=60, beside the HUD's Upgrade and
-- Daily buttons — below Roblox's own top-left menu, so it is never
-- covered by Roblox's own chrome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local SHOP_VIEW = {
	Speed = { label = "Speed Boots", desc = "+2 WalkSpeed per tier", tiers = { 200, 800, 4000, 12000, 30000 } },
	Carry = { label = "Extra Arms", desc = "+1 Brainrot carried per tier", tiers = { 400, 2500 } },
	Income = { label = "Golden Trough", desc = "+25% base income per tier", tiers = { 600, 2000, 8000 } },
	Pads = { label = "Extra Pad", desc = "+1 base pad per tier (max 8)", tiers = { 1500, 6000 } },
	Lock = { label = "Longer Lock", desc = "+30s base lock per tier", tiers = { 800, 3000 } },
	Stamina = { label = "Endurance Training", desc = "+50 max stamina per tier", tiers = { 500, 2000, 6000 } },
	Egg = { label = "Egg Warmer", desc = "-25% egg hatch time per tier", tiers = { 800, 3000 } },
	Slap = { label = "Power Slap", desc = "+1.5 slap range, +20 knockback per tier", tiers = { 300, 1500, 5000 } },
}
local SHOP_ORDER = { "Speed", "Carry", "Income", "Pads", "Lock", "Stamina", "Egg", "Slap" }

-- Boosts (item 11): bought with Stardust, not coins. One row each.
local BOOST_VIEW = {
	{ kind = "speed", label = "⚡ Speed Coil", desc = "+40% speed, 30s" },
	{ kind = "magnet", label = "🧲 Magnet", desc = "Auto-grab nearest Brainrot within 15 studs, 30s" },
	{ kind = "cash", label = "💰 2x Cash", desc = "Double income, 60s" },
	{ kind = "shield", label = "🛡️ Shield", desc = "Immune to slaps and meteors, 20s" },
}

local gui = GuiKit.getGui()

-- Top-left row, beside the HUD's Upgrade and Daily buttons, at y=60.
local shopButton = GuiKit.makeButton(gui, "ShopButton", "🛒 Shop (B)", UDim2.new(0, 120, 0, 44), UDim2.new(0, 12, 0, 60), GuiKit.COLORS.Blue)

local shopPanel = GuiKit.makePanel(gui, "ShopPanel", UDim2.new(0, 420, 0, 780), UDim2.new(0.5, -210, 0.5, -390))
shopPanel.Visible = false
GuiKit.makeLabel(shopPanel, "Title", "🛒 SHOP", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, GuiKit.COLORS.White)
local shopClose = GuiKit.makeButton(shopPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), GuiKit.COLORS.Close)

local tiers = { Speed = 0, Carry = 0, Income = 0, Pads = 0, Lock = 0, Stamina = 0, Egg = 0, Slap = 0 }

local refreshShop: () -> ()

-- Current effect text per ladder (cheap win 3): the row shows the
-- level AND what it does right now, not just the next price.
local function effectText(key: string, tier: number): string
	if key == "Speed" then
		return "Lv " .. tostring(tier) .. "/5 — now +" .. tostring(2 * tier) .. " WalkSpeed"
	elseif key == "Carry" then
		return "Lv " .. tostring(tier) .. "/2 — carry " .. tostring(1 + tier) .. " at once"
	elseif key == "Income" then
		return "Lv " .. tostring(tier) .. "/3 — now +" .. tostring(25 * tier) .. "% income"
	elseif key == "Pads" then
		return "Lv " .. tostring(tier) .. "/2 — " .. tostring(6 + tier) .. " pads open"
	elseif key == "Lock" then
		return "Lv " .. tostring(tier) .. "/2 — lock lasts " .. tostring(60 + 30 * tier) .. "s"
	elseif key == "Stamina" then
		return "Lv " .. tostring(tier) .. "/3 — max stamina " .. tostring(100 + 50 * tier)
	elseif key == "Egg" then
		return "Lv " .. tostring(tier) .. "/2 — hatch " .. tostring(100 - 25 * tier) .. "% as long"
	elseif key == "Slap" then
		return "Lv " .. tostring(tier) .. "/3 — range " .. tostring(9 + 1.5 * tier) .. ", knockback " .. tostring(38 + 20 * tier)
	else
		return "Lv " .. tostring(tier)
	end
end

-- The ladder rows scroll (fix round 8, item 6): 8 rows x 96px = 768px,
-- taller than the panel's ladder area (60..540). A ScrollingFrame
-- keeps the panel 780px tall and the rows reachable on a phone.
local ladderScroll = Instance.new("ScrollingFrame")
ladderScroll.Name = "LadderScroll"
ladderScroll.Size = UDim2.new(1, -24, 0, 468)
ladderScroll.Position = UDim2.new(0, 12, 0, 60)
ladderScroll.BackgroundTransparency = 1
ladderScroll.BorderSizePixel = 0
ladderScroll.ScrollBarThickness = 6
ladderScroll.CanvasSize = UDim2.new(0, 0, 0, #SHOP_ORDER * 96)
ladderScroll.Parent = shopPanel

local shopRows = {}
for i, key in ipairs(SHOP_ORDER) do
	local item = SHOP_VIEW[key]
	local y = (i - 1) * 96
	local row = GuiKit.makePanel(ladderScroll, key .. "Row", UDim2.new(1, -12, 0, 88), UDim2.new(0, 0, 0, y))
	GuiKit.makeLabel(row, "Name", item.label, UDim2.new(1, -130, 0, 28), UDim2.new(0, 10, 0, 6), 22, Color3.fromRGB(255, 255, 255))
	GuiKit.makeLabel(row, "Desc", item.desc, UDim2.new(1, -130, 0, 22), UDim2.new(0, 10, 0, 34), 16, Color3.fromRGB(200, 200, 220))
	local tierLabel = GuiKit.makeLabel(row, "Tier", "Lv 0", UDim2.new(1, -130, 0, 22), UDim2.new(0, 10, 0, 58), 16, Color3.fromRGB(160, 255, 170))
	local buyButton = GuiKit.makeButton(row, "Buy", Formatting.formatMoney(item.tiers[1]), UDim2.new(0, 104, 0, 44), UDim2.new(1, -114, 0, 22), GuiKit.COLORS.Buy)
	shopRows[key] = { row = row, tierLabel = tierLabel, buyButton = buyButton }
	buyButton.MouseButton1Click:Connect(function()
		local ok, message = Remotes.buyFunction():InvokeServer(key)
		GuiKit.showBanner(gui, message, 3)
		if ok then
			tiers[key] += 1
			refreshShop()
		end
	end)
end

-- Boosts section: four rows, bought with Stardust (20 each).
GuiKit.makeLabel(shopPanel, "BoostsTitle", "✨ BOOSTS — 20 💎 each", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 0, 540), 20, GuiKit.COLORS.Gold)
for i, boost in ipairs(BOOST_VIEW) do
	local y = 568 + (i - 1) * 40
	local row = GuiKit.makePanel(shopPanel, "Boost" .. boost.kind .. "Row", UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 0, y))
	GuiKit.makeLabel(row, "Name", boost.label, UDim2.new(0, 130, 0, 22), UDim2.new(0, 10, 0, 7), 16, Color3.fromRGB(255, 255, 255))
	GuiKit.makeLabel(row, "Desc", boost.desc, UDim2.new(1, -140, 0, 22), UDim2.new(0, 140, 0, 7), 14, Color3.fromRGB(200, 200, 220))
	local buyButton = GuiKit.makeButton(row, "Buy", "20 💎", UDim2.new(0, 80, 0, 28), UDim2.new(1, -90, 0, 4), GuiKit.COLORS.Buy)
	buyButton.MouseButton1Click:Connect(function()
		local ok, message = Remotes.buyBoostFunction():InvokeServer(boost.kind)
		GuiKit.showBanner(gui, message, 3)
	end)
end

-- Mutation reroll: 30 Stardust, rerolls the mutation of your
-- highest-income placed Rotling.
local rerollRow = GuiKit.makePanel(shopPanel, "RerollRow", UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 0, 728))
GuiKit.makeLabel(rerollRow, "Name", "🎲 Reroll Mutation", UDim2.new(0, 170, 0, 22), UDim2.new(0, 10, 0, 7), 16, Color3.fromRGB(255, 255, 255))
GuiKit.makeLabel(rerollRow, "Desc", "Reroll your best Brainrot's mutation", UDim2.new(1, -180, 0, 22), UDim2.new(0, 180, 0, 7), 14, Color3.fromRGB(200, 200, 220))
local rerollButton = GuiKit.makeButton(rerollRow, "Buy", "30 💎", UDim2.new(0, 80, 0, 28), UDim2.new(1, -90, 0, 4), GuiKit.COLORS.Buy)
rerollButton.MouseButton1Click:Connect(function()
	local ok, message = Remotes.rerollFunction():InvokeServer()
	GuiKit.showBanner(gui, message, 3)
end)

function refreshShop()
	for _, key in ipairs(SHOP_ORDER) do
		local item = SHOP_VIEW[key]
		local tier = tiers[key]
		local row = shopRows[key]
		row.tierLabel.Text = effectText(key, tier)
		if tier >= #item.tiers then
			row.buyButton.Text = "MAXED"
			row.buyButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		else
			row.buyButton.Text = Formatting.formatMoney(item.tiers[tier + 1])
			row.buyButton.BackgroundColor3 = GuiKit.COLORS.Buy
		end
	end
end

local function toggleShop()
	local wasOpen = shopPanel.Visible
	GuiKit.closeOtherPanels(gui, "ShopPanel")
	shopPanel.Visible = not wasOpen
	if shopPanel.Visible then
		refreshShop()
	end
end

-- Open the shop from another controller (the HUD's Upgrade button).
-- "upgrade" flashes the base-upgrade rows (Income, Pads) so the player
-- sees where the upgrades live.
local function openShop(section: string?)
	GuiKit.closeOtherPanels(gui, "ShopPanel")
	shopPanel.Visible = true
	refreshShop()
	if section == "upgrade" then
		for _, key in ipairs({ "Income", "Pads" }) do
			local entry = shopRows[key]
			if entry then
				TweenService:Create(entry.row, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = Color3.fromRGB(255, 225, 90),
				}):Play()
				task.delay(1, function()
					TweenService:Create(entry.row, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = GuiKit.COLORS.Panel,
					}):Play()
				end)
			end
		end
	end
end

GuiKit.openShopEvent(gui).Event:Connect(openShop)

shopButton.MouseButton1Click:Connect(toggleShop)
shopClose.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		toggleShop()
	end
end)

Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	tiers.Speed = data.speedTier
	tiers.Carry = data.carryTier
	tiers.Income = data.incomeTier
	tiers.Pads = data.padsTier
	tiers.Lock = data.lockTier
	tiers.Stamina = data.staminaTier
	tiers.Egg = data.eggTier
	tiers.Slap = data.slapTier
	if shopPanel.Visible then
		refreshShop()
	end
end)

-- Walking into the Star Shop or onto an upgrade machine opens the
-- panel (the server fires this when the world prompt is pressed).
Remotes.openShopEvent().OnClientEvent:Connect(function(section: string?)
	openShop(section)
end)

print("Starfall Brainrots shop ready.")
