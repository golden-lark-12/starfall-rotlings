--!strict
-- Starfall Rotlings: Index controller.
-- The Index panel: one card per Rotling, greyed out until found, with
-- its rarity colour and coins-per-second. Found cards light up. The
-- server logs every grab and place; the client only shows the set.
-- The Index button sits at y=328 on the right side, below the
-- leaderboard panel (which ends at y=320), so it never overlaps the
-- leaderboard, the storm timer or the top-right player list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local gui = GuiKit.getGui()

-- The Index button sits at y=364 on the right side, below the
-- leaderboard panel (which ends at y=356), so it never overlaps the
-- leaderboard, the storm timer or the top-right player list.
local indexButton = GuiKit.makeButton(gui, "IndexButton", "📖 Index (I)", UDim2.new(0, 160, 0, 48), UDim2.new(1, -172, 0, 364), GuiKit.COLORS.Purple)

local indexPanel = GuiKit.makePanel(gui, "IndexPanel", UDim2.new(0, 520, 0, 420), UDim2.new(0.5, -260, 0.5, -210))
indexPanel.Visible = false
GuiKit.makeLabel(indexPanel, "Title", "📖 ROTLING INDEX", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, GuiKit.COLORS.White)
local indexClose = GuiKit.makeButton(indexPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), GuiKit.COLORS.Close)
local indexCount = GuiKit.makeLabel(indexPanel, "Count", "Found 0 / 20", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 48), 20, Color3.fromRGB(160, 255, 170))

-- The highest mutation multiplier, for the "✦ up to x5" line on every
-- card (cheap win 1: the multiplier shows in the index too).
local maxMult = 1
for _, mutation in ipairs(MutationConfig.MUTATIONS) do
	maxMult = math.max(maxMult, mutation.mult)
end

local indexCards = {}
local foundSet: { [string]: boolean } = {}
local buddyName: string? = nil
local refreshIndex: () -> ()
do
	-- Cards live in a scrolling frame so the 20-card grid never moves
	-- the title, the count line or the close button.
	local gridFrame = Instance.new("ScrollingFrame")
	gridFrame.Name = "Grid"
	gridFrame.Size = UDim2.new(1, -20, 1, -84)
	gridFrame.Position = UDim2.new(0, 10, 0, 84)
	gridFrame.BackgroundTransparency = 1
	gridFrame.BorderSizePixel = 0
	gridFrame.ScrollBarThickness = 6
	gridFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridFrame.Parent = indexPanel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 150, 0, 118)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = gridFrame
	for _, def in ipairs(RotlingCatalog.DEFS) do
		local card = GuiKit.makePanel(gridFrame, def.id .. "Card", UDim2.new(0, 150, 0, 118), UDim2.new(0, 0, 0, 0))
		local rarity = RarityConfig.rarityByName(def.rarity)
		GuiKit.makeLabel(card, "Name", "???", UDim2.new(1, -8, 0, 24), UDim2.new(0, 4, 0, 4), 18, Color3.fromRGB(255, 255, 255))
		GuiKit.makeLabel(card, "Rarity", def.rarity, UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 28), 15, rarity.color)
		GuiKit.makeLabel(card, "Cps", Formatting.formatMoney(math.floor(RotlingCatalog.baseCps(def, nil))) .. "/s · ✦ up to x" .. tostring(maxMult), UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 48), 14, Color3.fromRGB(255, 230, 90))
		local flavorLabel = GuiKit.makeLabel(card, "Flavor", def.flavor, UDim2.new(1, -8, 0, 16), UDim2.new(0, 4, 0, 68), 11, Color3.fromRGB(200, 200, 220))
		flavorLabel.TextWrapped = true
		-- Set as Buddy: swap your buddy Rotling from the Index.
		local buddyButton = GuiKit.makeButton(card, "Buddy", "Set as Buddy", UDim2.new(1, -8, 0, 22), UDim2.new(0, 4, 0, 88), GuiKit.COLORS.Purple)
		buddyButton.TextSize = 14
		buddyButton.MouseButton1Click:Connect(function()
			if not foundSet[def.id] then
				GuiKit.showBanner(gui, "Find " .. def.name .. " first!", 3)
				return
			end
			local ok, message = Remotes.setBuddyFunction():InvokeServer(def.id)
			GuiKit.showBanner(gui, message, 3)
			if ok then
				buddyName = def.name
				refreshIndex()
			end
		end)
		indexCards[def.id] = card
	end
end

function refreshIndex()
	local found = 0
	for _, def in ipairs(RotlingCatalog.DEFS) do
		local card = indexCards[def.id]
		local nameLabel = card:FindFirstChild("Name")
		local buddyButton = card:FindFirstChild("Buddy")
		if foundSet[def.id] then
			found += 1
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = def.name
			end
			card.BackgroundColor3 = Color3.fromRGB(50, 45, 90)
		else
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = "???"
			end
			card.BackgroundColor3 = Color3.fromRGB(30, 25, 55)
		end
		if buddyButton and buddyButton:IsA("TextButton") then
			if buddyName == def.name then
				buddyButton.Text = "Buddy ✓"
				buddyButton.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
			else
				buddyButton.Text = "Set as Buddy"
				buddyButton.BackgroundColor3 = GuiKit.COLORS.Purple
			end
		end
	end
	indexCount.Text = "Found " .. tostring(found) .. " / " .. tostring(#RotlingCatalog.DEFS)
end

local function toggleIndex()
	local wasOpen = indexPanel.Visible
	GuiKit.closeOtherPanels(gui, "IndexPanel")
	indexPanel.Visible = not wasOpen
	if indexPanel.Visible then
		refreshIndex()
	end
end

indexButton.MouseButton1Click:Connect(toggleIndex)
indexClose.MouseButton1Click:Connect(function()
	indexPanel.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		toggleIndex()
	end
end)

Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	foundSet = data.index
	buddyName = data.buddyName
	if indexPanel.Visible then
		refreshIndex()
	end
end)

print("Starfall Rotlings index ready.")
