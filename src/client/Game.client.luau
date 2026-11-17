-- Starfall Rotlings: the client.
-- Builds the whole HUD in code: coins and income up top, the storm timer,
-- Shop / Index / Rebirth / Lock buttons, and the banner line. The client
-- never decides a number: every buy, rebirth and lock is answered by the
-- server, and the HUD only shows what the server sends back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RotlingData = require(ReplicatedStorage.Shared.RotlingData)
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("StarfallRemotes")

local SHOP_VIEW = {
	Speed = { label = "Speed Boots", desc = "+2 WalkSpeed per tier", tiers = { 250, 1000, 5000 } },
	Carry = { label = "Extra Arms", desc = "+1 Rotling carried per tier", tiers = { 500, 3000 } },
	Income = { label = "Golden Trough", desc = "+25% base income per tier", tiers = { 750, 2500, 10000 } },
}
local SHOP_ORDER = { "Speed", "Carry", "Income" }

local hud = {
	coins = 0,
	cps = 0,
	rebirths = 0,
	speedTier = 0,
	carryTier = 0,
	incomeTier = 0,
	carried = 0,
	carrySlots = 1,
	lockRemaining = 0,
	lockCooldown = 0,
	stormPhase = "calm",
	stormSeconds = 0,
	index = {},
}

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return s .. out
end

local function makeLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Text = text
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 22
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.3
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = parent
	return button
end

local function makePanel(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = Color3.fromRGB(30, 25, 55)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.7
	stroke.Thickness = 2
	stroke.Parent = panel
	panel.Parent = parent
	return panel
end

-- -- Build the GUI ------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "StarfallGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Coins, big and top-centre (clear of Roblox's own top-left buttons).
local coinsLabel = makeLabel(gui, "Coins", "$0", UDim2.new(0, 320, 0, 56), UDim2.new(0.5, -160, 0, 8), 44, Color3.fromRGB(255, 225, 90))
local cpsLabel = makeLabel(gui, "Cps", "+$0/s", UDim2.new(0, 320, 0, 30), UDim2.new(0.5, -160, 0, 64), 24, Color3.fromRGB(160, 255, 170))

-- Storm timer, top-right.
local stormLabel = makeLabel(gui, "Storm", "Next storm: --", UDim2.new(0, 260, 0, 36), UDim2.new(1, -270, 0, 10), 22, Color3.fromRGB(255, 255, 255))
stormLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Right-side buttons.
local shopButton = makeButton(gui, "ShopButton", "🛒 Shop (B)", UDim2.new(0, 170, 0, 48), UDim2.new(1, -185, 0, 60), Color3.fromRGB(90, 160, 255))
local indexButton = makeButton(gui, "IndexButton", "📖 Index (I)", UDim2.new(0, 170, 0, 48), UDim2.new(1, -185, 0, 116), Color3.fromRGB(180, 110, 255))
local rebirthButton = makeButton(gui, "RebirthButton", "✨ Rebirth (R)", UDim2.new(0, 170, 0, 48), UDim2.new(1, -185, 0, 172), Color3.fromRGB(255, 110, 180))
local lockButton = makeButton(gui, "LockButton", "🔓 Lock Base (L)", UDim2.new(0, 170, 0, 48), UDim2.new(1, -185, 0, 228), Color3.fromRGB(255, 90, 90))

-- Hint line, bottom-centre.
local hintLabel = makeLabel(gui, "Hint", "Grab a Rotling in the crater!", UDim2.new(0, 700, 0, 30), UDim2.new(0.5, -350, 1, -44), 22, Color3.fromRGB(255, 255, 255))

-- Banner line, centre screen, fades on its own.
local bannerLabel = makeLabel(gui, "Banner", "", UDim2.new(0, 760, 0, 44), UDim2.new(0.5, -380, 0, 130), 30, Color3.fromRGB(255, 240, 120))
bannerLabel.Visible = false

-- -- Shop panel ---------------------------------------------------------------

local shopPanel = makePanel(gui, "ShopPanel", UDim2.new(0, 420, 0, 380), UDim2.new(0.5, -210, 0.5, -190))
shopPanel.Visible = false
makeLabel(shopPanel, "Title", "🛒 SHOP", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, Color3.fromRGB(255, 255, 255))
local shopClose = makeButton(shopPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), Color3.fromRGB(200, 60, 60))

local shopRows = {}
for i, key in ipairs(SHOP_ORDER) do
	local item = SHOP_VIEW[key]
	local y = 60 + (i - 1) * 100
	local row = makePanel(shopPanel, key .. "Row", UDim2.new(1, -24, 0, 88), UDim2.new(0, 12, 0, y))
	makeLabel(row, "Name", item.label, UDim2.new(1, -130, 0, 28), UDim2.new(0, 10, 0, 6), 22, Color3.fromRGB(255, 255, 255))
	makeLabel(row, "Desc", item.desc, UDim2.new(1, -130, 0, 22), UDim2.new(0, 10, 0, 34), 16, Color3.fromRGB(200, 200, 220))
	local tierLabel = makeLabel(row, "Tier", "Tier 0/" .. tostring(#item.tiers), UDim2.new(1, -130, 0, 22), UDim2.new(0, 10, 0, 58), 16, Color3.fromRGB(160, 255, 170))
	local buyButton = makeButton(row, "Buy", "$" .. tostring(item.tiers[1]), UDim2.new(0, 104, 0, 44), UDim2.new(1, -114, 0, 22), Color3.fromRGB(80, 200, 100))
	shopRows[key] = { tierLabel = tierLabel, buyButton = buyButton }
	buyButton.MouseButton1Click:Connect(function()
		local ok, message = remotes.BuyItem:InvokeServer(key)
		showBanner(message, 3)
		refreshShop()
	end)
end

function refreshShop()
	local tiers = { Speed = hud.speedTier, Carry = hud.carryTier, Income = hud.incomeTier }
	for _, key in ipairs(SHOP_ORDER) do
		local item = SHOP_VIEW[key]
		local tier = tiers[key]
		local row = shopRows[key]
		row.tierLabel.Text = "Tier " .. tostring(tier) .. "/" .. tostring(#item.tiers)
		if tier >= #item.tiers then
			row.buyButton.Text = "MAXED"
			row.buyButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		else
			row.buyButton.Text = "$" .. formatNumber(item.tiers[tier + 1])
			row.buyButton.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
		end
	end
end

-- -- Index panel --------------------------------------------------------------

local indexPanel = makePanel(gui, "IndexPanel", UDim2.new(0, 520, 0, 420), UDim2.new(0.5, -260, 0.5, -210))
indexPanel.Visible = false
makeLabel(indexPanel, "Title", "📖 ROTLING INDEX", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, Color3.fromRGB(255, 255, 255))
local indexClose = makeButton(indexPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), Color3.fromRGB(200, 60, 60))
local indexCount = makeLabel(indexPanel, "Count", "Found 0 / 12", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 48), 20, Color3.fromRGB(160, 255, 170))

local indexCards = {}
do
	-- Cards live in their own frame so the grid never moves the title,
	-- the count line or the close button.
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "Grid"
	gridFrame.Size = UDim2.new(1, -20, 1, -84)
	gridFrame.Position = UDim2.new(0, 10, 0, 84)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = indexPanel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 150, 0, 96)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = gridFrame
	for _, def in ipairs(RotlingData.DEFS) do
		local card = makePanel(gridFrame, def.id .. "Card", UDim2.new(0, 150, 0, 96), UDim2.new(0, 0, 0, 0))
		local rarity = Config.rarityByName(def.rarity)
		makeLabel(card, "Name", "???", UDim2.new(1, -8, 0, 26), UDim2.new(0, 4, 0, 6), 18, Color3.fromRGB(255, 255, 255))
		makeLabel(card, "Rarity", def.rarity, UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 32), 15, rarity.color)
		makeLabel(card, "Cps", "$" .. tostring(math.floor(RotlingData.baseCps(def, nil))) .. "/s", UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 54), 15, Color3.fromRGB(255, 230, 90))
		local flavorLabel = makeLabel(card, "Flavor", def.flavor, UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 74), 11, Color3.fromRGB(200, 200, 220))
		flavorLabel.TextWrapped = true
		indexCards[def.id] = card
	end
end

function refreshIndex()
	local found = 0
	for _, def in ipairs(RotlingData.DEFS) do
		local card = indexCards[def.id]
		local nameLabel = card:FindFirstChild("Name")
		if hud.index[def.id] then
			found += 1
			nameLabel.Text = def.name
			card.BackgroundColor3 = Color3.fromRGB(50, 45, 90)
		else
			nameLabel.Text = "???"
			card.BackgroundColor3 = Color3.fromRGB(30, 25, 55)
		end
	end
	indexCount.Text = "Found " .. tostring(found) .. " / " .. tostring(#RotlingData.DEFS)
end

-- -- Rebirth panel --------------------------------------------------------------

local rebirthPanel = makePanel(gui, "RebirthPanel", UDim2.new(0, 420, 0, 260), UDim2.new(0.5, -210, 0.5, -130))
rebirthPanel.Visible = false
makeLabel(rebirthPanel, "Title", "✨ REBIRTH", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, Color3.fromRGB(255, 255, 255))
local rebirthClose = makeButton(rebirthPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), Color3.fromRGB(200, 60, 60))
local rebirthInfo = makeLabel(rebirthPanel, "Info", "", UDim2.new(1, -24, 0, 90), UDim2.new(0, 12, 0, 60), 20, Color3.fromRGB(255, 255, 255))
local rebirthBuy = makeButton(rebirthPanel, "RebirthBuy", "Rebirth!", UDim2.new(0, 240, 0, 52), UDim2.new(0.5, -120, 0, 170), Color3.fromRGB(255, 110, 180))

function refreshRebirth()
	local cost = 10000 * (hud.rebirths + 1) * (hud.rebirths + 1)
	local mult = 1 + 0.25 * hud.rebirths
	rebirthInfo.Text = "Rebirths: " .. tostring(hud.rebirths) .. " (income x" .. string.format("%.2f", mult) .. ")\nReset your coins for +25% income forever."
	rebirthBuy.Text = "Rebirth — $" .. formatNumber(cost)
end

rebirthBuy.MouseButton1Click:Connect(function()
	local ok, message = remotes.DoRebirth:InvokeServer()
	showBanner(message, 4)
	refreshRebirth()
end)

-- -- Panel toggling ---------------------------------------------------------------

local panels = { Shop = shopPanel, Index = indexPanel, Rebirth = rebirthPanel }

function togglePanel(name: string)
	local panel = panels[name]
	local wasOpen = panel.Visible
	for _, other in pairs(panels) do
		other.Visible = false
	end
	panel.Visible = not wasOpen
	if name == "Shop" then
		refreshShop()
	elseif name == "Index" then
		refreshIndex()
	elseif name == "Rebirth" then
		refreshRebirth()
	end
end

shopButton.MouseButton1Click:Connect(function()
	togglePanel("Shop")
end)
indexButton.MouseButton1Click:Connect(function()
	togglePanel("Index")
end)
rebirthButton.MouseButton1Click:Connect(function()
	togglePanel("Rebirth")
end)
shopClose.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)
indexClose.MouseButton1Click:Connect(function()
	indexPanel.Visible = false
end)
rebirthClose.MouseButton1Click:Connect(function()
	rebirthPanel.Visible = false
end)
lockButton.MouseButton1Click:Connect(function()
	remotes.ToggleLock:FireServer()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		togglePanel("Shop")
	elseif input.KeyCode == Enum.KeyCode.I then
		togglePanel("Index")
	elseif input.KeyCode == Enum.KeyCode.R then
		togglePanel("Rebirth")
	elseif input.KeyCode == Enum.KeyCode.L then
		remotes.ToggleLock:FireServer()
	end
end)

-- -- Server updates ---------------------------------------------------------------

local bannerToken = 0

function showBanner(text: string, duration: number)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = text
	bannerLabel.Visible = true
	task.delay(duration, function()
		if token == bannerToken then
			bannerLabel.Visible = false
		end
	end)
end

remotes.ShowBanner.OnClientEvent:Connect(function(text: string, duration: number)
	showBanner(text, duration)
end)

remotes.UpdateHud.OnClientEvent:Connect(function(data)
	hud.coins = data.coins or hud.coins
	hud.cps = data.cps or hud.cps
	hud.rebirths = data.rebirths or hud.rebirths
	hud.speedTier = data.speedTier or hud.speedTier
	hud.carryTier = data.carryTier or hud.carryTier
	hud.incomeTier = data.incomeTier or hud.incomeTier
	hud.carried = data.carried or hud.carried
	hud.carrySlots = data.carrySlots or hud.carrySlots
	hud.lockRemaining = data.lockRemaining or 0
	hud.lockCooldown = data.lockCooldown or 0
	hud.stormPhase = data.stormPhase or hud.stormPhase
	hud.stormSeconds = data.stormSeconds or 0
	hud.index = data.index or hud.index

	coinsLabel.Text = "$" .. formatNumber(hud.coins)
	cpsLabel.Text = "+$" .. formatNumber(hud.cps) .. "/s  •  Rebirths: " .. tostring(hud.rebirths)

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

	if shopPanel.Visible then
		refreshShop()
	end
	if indexPanel.Visible then
		refreshIndex()
	end
	if rebirthPanel.Visible then
		refreshRebirth()
	end
end)

print("Starfall Rotlings client ready.")
