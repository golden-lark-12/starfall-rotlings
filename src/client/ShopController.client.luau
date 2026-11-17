--!strict
-- Starfall Rotlings: shop controller.
-- The shop panel: five ladders (speed, extra arms, income, extra pads,
-- longer locks) with tier dots and buy buttons. The client only asks to
-- buy; the server checks the price and answers with the result.
-- The Shop button sits in the top-left row at y=60, beside the HUD's
-- Upgrade and Daily buttons — below Roblox's own top-left menu, so it
-- is never covered by Roblox's own chrome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local SHOP_VIEW = {
	Speed = { label = "Speed Boots", desc = "+2 WalkSpeed per tier", tiers = { 250, 1000, 5000 } },
	Carry = { label = "Extra Arms", desc = "+1 Rotling carried per tier", tiers = { 500, 3000 } },
	Income = { label = "Golden Trough", desc = "+25% base income per tier", tiers = { 750, 2500, 10000 } },
	Pads = { label = "Extra Pad", desc = "+1 base pad per tier (max 8)", tiers = { 2000, 8000 } },
	Lock = { label = "Longer Lock", desc = "+30s base lock per tier", tiers = { 1000, 4000 } },
}
local SHOP_ORDER = { "Speed", "Carry", "Income", "Pads", "Lock" }

local gui = GuiKit.getGui()

-- Top-left row, beside the HUD's Upgrade and Daily buttons, at y=60.
local shopButton = GuiKit.makeButton(gui, "ShopButton", "🛒 Shop (B)", UDim2.new(0, 120, 0, 44), UDim2.new(0, 12, 0, 60), GuiKit.COLORS.Blue)

local shopPanel = GuiKit.makePanel(gui, "ShopPanel", UDim2.new(0, 420, 0, 560), UDim2.new(0.5, -210, 0.5, -280))
shopPanel.Visible = false
GuiKit.makeLabel(shopPanel, "Title", "🛒 SHOP", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, GuiKit.COLORS.White)
local shopClose = GuiKit.makeButton(shopPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), GuiKit.COLORS.Close)

local tiers = { Speed = 0, Carry = 0, Income = 0, Pads = 0, Lock = 0 }

local refreshShop: () -> ()

local shopRows = {}
for i, key in ipairs(SHOP_ORDER) do
	local item = SHOP_VIEW[key]
	local y = 60 + (i - 1) * 96
	local row = GuiKit.makePanel(shopPanel, key .. "Row", UDim2.new(1, -24, 0, 88), UDim2.new(0, 12, 0, y))
	GuiKit.makeLabel(row, "Name", item.label, UDim2.new(1, -130, 0, 28), UDim2.new(0, 10, 0, 6), 22, Color3.fromRGB(255, 255, 255))
	GuiKit.makeLabel(row, "Desc", item.desc, UDim2.new(1, -130, 0, 22), UDim2.new(0, 10, 0, 34), 16, Color3.fromRGB(200, 200, 220))
	local tierLabel = GuiKit.makeLabel(row, "Tier", "Tier 0/" .. tostring(#item.tiers), UDim2.new(1, -130, 0, 22), UDim2.new(0, 10, 0, 58), 16, Color3.fromRGB(160, 255, 170))
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

function refreshShop()
	for _, key in ipairs(SHOP_ORDER) do
		local item = SHOP_VIEW[key]
		local tier = tiers[key]
		local row = shopRows[key]
		row.tierLabel.Text = "Tier " .. tostring(tier) .. "/" .. tostring(#item.tiers)
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
	if shopPanel.Visible then
		refreshShop()
	end
end)

print("Starfall Rotlings shop ready.")
