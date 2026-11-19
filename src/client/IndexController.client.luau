--!strict
-- Starfall Rotlings: Index controller.
-- The Index panel: one card per Rotling, greyed out until found, with
-- its rarity colour and coins-per-second. Found cards light up. The
-- server logs every grab and place; the client only shows the set.
-- The Index button sits at y=328 on the right side, below the
-- leaderboard panel (which ends at y=320), so it never overlaps the
-- leaderboard, the storm timer or the top-right player list.
-- (fix round 7, item 9) The index looked plain: text-only cards, a
-- subtle found/unfound shade change, no progress feel. Now each card
-- has a silhouette icon in the Brainrot's own colours (its unique
-- silhouette key from the catalog, body colour = rarity colour),
-- a rarity-coloured strip on top, and a rarity-coloured glow border
-- when found; unfound cards show a dark grey silhouette with "???".
-- A progress bar fills as the set grows, and a tier line shows each
-- rarity's found count in its colour. What it tracks is unchanged:
-- 22 Brainrots, X/22, tier completion rewards.

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
GuiKit.makeLabel(indexPanel, "Title", "📖 BRAINROT INDEX", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, GuiKit.COLORS.White)
local indexClose = GuiKit.makeButton(indexPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), GuiKit.COLORS.Close)
local indexCount = GuiKit.makeLabel(indexPanel, "Count", "Found 0 / 20", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 48), 20, Color3.fromRGB(160, 255, 170))

-- Progress bar (fix round 7, item 9): a fill that grows with the set,
-- so the collection feels like progress, not just a number.
local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBg"
progressBg.Size = UDim2.new(1, -20, 0, 12)
progressBg.Position = UDim2.new(0, 10, 0, 74)
progressBg.BackgroundColor3 = Color3.fromRGB(25, 20, 45)
progressBg.BorderSizePixel = 0
progressBg.Parent = indexPanel
local progressBgCorner = Instance.new("UICorner")
progressBgCorner.CornerRadius = UDim.new(0, 6)
progressBgCorner.Parent = progressBg
local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg
local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(0, 6)
progressFillCorner.Parent = progressFill

-- Tier line (fix round 7, item 9): each rarity's found count in its
-- own colour, so the player sees which tier is close to complete.
-- RichText: one label, a coloured dot per tier.
local tierLine = GuiKit.makeLabel(indexPanel, "TierLine", "", UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 90), 15, Color3.fromRGB(220, 220, 240))
tierLine.RichText = true

-- Mutations line (simplify pass, section B): which of the six
-- mutations this player has collected — found ones in their own
-- colour with their multiplier, unfound ones as grey "???". The
-- mutation set rides on the HUD feed (data.mutations).
local mutationLine = GuiKit.makeLabel(indexPanel, "MutationLine", "", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 110), 14, Color3.fromRGB(220, 220, 240))
mutationLine.RichText = true

-- The highest mutation multiplier, for the "✦ up to x5" line on every
-- card (cheap win 1: the multiplier shows in the index too).
local maxMult = 1
for _, mutation in ipairs(MutationConfig.MUTATIONS) do
	maxMult = math.max(maxMult, mutation.mult)
end

local indexCards = {}
local indexIcons: { [string]: { shape: Frame, belly: Frame?, ears: { Frame } } } = {}
local foundSet: { [string]: boolean } = {}
local mutationsSet: { [string]: boolean } = {}
local buddyName: string? = nil
local refreshIndex: () -> ()

-- A Brainrot's silhouette as a mini icon (fix round 7, item 9): the
-- catalog's unique silhouette key, drawn with Gui shapes in the
-- Brainrot's own colours (body = rarity colour, belly = lighter
-- tint). Found cards show it in colour; unfound cards show the same
-- shape in dark grey — a silhouette to discover, like a Pokédex.
local function buildIcon(parent: Instance, def: RotlingCatalog.RotlingDef): { shape: Frame, belly: Frame?, ears: { Frame } }
	local size = UDim2.new(0, 48, 0, 48)
	local corner = 0.5
	if def.silhouette == "chunky-cube" or def.silhouette == "boxy-ghost" then
		corner = 0.2
	elseif def.silhouette == "wide-couch" then
		size = UDim2.new(0, 56, 0, 40)
		corner = 0.25
	elseif def.silhouette == "tall-capsule" or def.silhouette == "tall-sock" then
		size = UDim2.new(0, 36, 0, 56)
		corner = 0.5
	elseif def.silhouette == "flat-puddle" then
		size = UDim2.new(0, 56, 0, 28)
		corner = 0.5
	elseif def.silhouette == "long-wavy" then
		size = UDim2.new(0, 56, 0, 36)
		corner = 0.3
	end
	local shape = Instance.new("Frame")
	shape.Name = "Icon"
	shape.Size = size
	-- Centred in the 10-66 icon zone, so short shapes (flat
	-- puddle) do not float high above the name.
	shape.Position = UDim2.new(0.5, -size.X.Offset / 2, 0, 10 + (56 - size.Y.Offset) / 2)
	shape.BackgroundColor3 = def.bodyColor
	shape.BorderSizePixel = 0
	shape.Parent = parent
	local shapeCorner = Instance.new("UICorner")
	shapeCorner.CornerRadius = UDim.new(0, math.floor(size.X.Offset * corner))
	shapeCorner.Parent = shape
	-- Belly: a lighter tint, low on the shape.
	local belly = Instance.new("Frame")
	belly.Name = "IconBelly"
	belly.Size = UDim2.new(0.6, 0, 0.45, 0)
	belly.Position = UDim2.new(0.2, 0, 0.5, 0)
	belly.BackgroundColor3 = def.bellyColor
	belly.BorderSizePixel = 0
	belly.Parent = shape
	local bellyCorner = Instance.new("UICorner")
	bellyCorner.CornerRadius = UDim.new(0, 8)
	bellyCorner.Parent = belly
	-- Bear ears: two small circles on top.
	local ears: { Frame } = {}
	if def.silhouette == "bear" then
		for _, dx in ipairs({ -16, 10 }) do
			local ear = Instance.new("Frame")
			ear.Name = "IconEar"
			ear.Size = UDim2.new(0, 14, 0, 14)
			ear.Position = UDim2.new(0, dx + 17, 0, -6)
			ear.BackgroundColor3 = def.bodyColor
			ear.BorderSizePixel = 0
			ear.Parent = shape
			local earCorner = Instance.new("UICorner")
			earCorner.CornerRadius = UDim.new(0, 7)
			earCorner.Parent = ear
			table.insert(ears, ear)
		end
	end
	return { shape = shape, belly = belly, ears = ears }
end

do
	-- Cards live in a scrolling frame so the 20-card grid never moves
	-- the title, the count line, the progress bar, the tier line or
	-- the close button.
	local gridFrame = Instance.new("ScrollingFrame")
	gridFrame.Name = "Grid"
	gridFrame.Size = UDim2.new(1, -20, 1, -140)
	gridFrame.Position = UDim2.new(0, 10, 0, 130)
	gridFrame.BackgroundTransparency = 1
	gridFrame.BorderSizePixel = 0
	gridFrame.ScrollBarThickness = 6
	gridFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridFrame.Parent = indexPanel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 150, 0, 160)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = gridFrame
	-- Cards in tier order (Common first, Divine last), so the grid
	-- reads as a ladder, not a random pile.
	local defs = table.clone(RotlingCatalog.DEFS)
	table.sort(defs, function(a, b)
		return RarityConfig.rarityTier(a.rarity) < RarityConfig.rarityTier(b.rarity)
	end)
	for _, def in ipairs(defs) do
		local card = GuiKit.makePanel(gridFrame, def.id .. "Card", UDim2.new(0, 150, 0, 160), UDim2.new(0, 0, 0, 0))
		local rarity = RarityConfig.rarityByName(def.rarity)
		-- Rarity strip on top: the tier at a glance, even unfound.
		local strip = Instance.new("Frame")
		strip.Name = "RarityStrip"
		strip.Size = UDim2.new(1, 0, 0, 4)
		strip.Position = UDim2.new(0, 0, 0, 0)
		strip.BackgroundColor3 = rarity.color
		strip.BorderSizePixel = 0
		strip.Parent = card
		-- Glow border when found (a UIStroke in the rarity colour,
		-- added here and enabled in refreshIndex).
		local glow = Instance.new("UIStroke")
		glow.Name = "FoundGlow"
		glow.Color = rarity.color
		glow.Thickness = 2
		glow.Transparency = 1
		glow.Parent = card
		indexIcons[def.id] = buildIcon(card, def)
		GuiKit.makeLabel(card, "Name", "???", UDim2.new(1, -8, 0, 22), UDim2.new(0, 4, 0, 66), 18, Color3.fromRGB(255, 255, 255))
		GuiKit.makeLabel(card, "Rarity", def.rarity, UDim2.new(1, -8, 0, 16), UDim2.new(0, 4, 0, 88), 15, rarity.color)
		GuiKit.makeLabel(card, "Cps", Formatting.formatMoney(math.floor(RotlingCatalog.baseCps(def, nil))) .. "/s · ✦ up to x" .. tostring(maxMult), UDim2.new(1, -8, 0, 16), UDim2.new(0, 4, 0, 104), 14, Color3.fromRGB(255, 230, 90))
		local flavorLabel = GuiKit.makeLabel(card, "Flavor", def.flavor, UDim2.new(1, -8, 0, 14), UDim2.new(0, 4, 0, 120), 11, Color3.fromRGB(200, 200, 220))
		flavorLabel.TextWrapped = true
		-- BUDDY_PARKED (simplify pass, v74): the buddy pet is off, so
		-- its button stays hidden. The button and its handler stay in
		-- the tree for a later return.
		local buddyButton = GuiKit.makeButton(card, "Buddy", "Set as Buddy", UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 136), GuiKit.COLORS.Purple)
		buddyButton.TextSize = 14
		buddyButton.Visible = false
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
	local tierFound: { [string]: number } = {}
	local tierTotal: { [string]: number } = {}
	for _, def in ipairs(RotlingCatalog.DEFS) do
		tierTotal[def.rarity] = (tierTotal[def.rarity] or 0) + 1
		if foundSet[def.id] then
			tierFound[def.rarity] = (tierFound[def.rarity] or 0) + 1
		end
	end
	for _, def in ipairs(RotlingCatalog.DEFS) do
		local card = indexCards[def.id]
		local nameLabel = card:FindFirstChild("Name")
		local buddyButton = card:FindFirstChild("Buddy")
		local glow = card:FindFirstChild("FoundGlow")
		local icon = indexIcons[def.id]
		if foundSet[def.id] then
			found += 1
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = def.name
			end
			-- Found: brighter card, rarity-coloured glow border, the
			-- icon in the Brainrot's own colours.
			card.BackgroundColor3 = Color3.fromRGB(50, 45, 90)
			if glow and glow:IsA("UIStroke") then
				glow.Transparency = 0
			end
			if icon then
				icon.shape.BackgroundColor3 = def.bodyColor
				if icon.belly then
					icon.belly.BackgroundColor3 = def.bellyColor
				end
				for _, ear in ipairs(icon.ears) do
					ear.BackgroundColor3 = def.bodyColor
				end
			end
		else
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = "???"
			end
			-- Unfound: dim card, no glow, the icon as a dark grey
			-- silhouette — a shape to discover.
			card.BackgroundColor3 = Color3.fromRGB(30, 25, 55)
			if glow and glow:IsA("UIStroke") then
				glow.Transparency = 1
			end
			if icon then
				icon.shape.BackgroundColor3 = Color3.fromRGB(60, 55, 80)
				if icon.belly then
					icon.belly.BackgroundColor3 = Color3.fromRGB(60, 55, 80)
				end
				for _, ear in ipairs(icon.ears) do
					ear.BackgroundColor3 = Color3.fromRGB(60, 55, 80)
				end
			end
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
	-- Progress bar: the fill grows with the set.
	progressFill.Size = UDim2.new(found / #RotlingCatalog.DEFS, 0, 1, 0)
	-- Tier line: a coloured dot + found/total per rarity, in tier
	-- order — the player sees which tier is close to complete.
	local parts: { string } = {}
	for _, rarityName in ipairs(RarityConfig.ORDER) do
		local rarity = RarityConfig.rarityByName(rarityName)
		local hex = string.format("#%02X%02X%02X", math.floor(rarity.color.R * 255), math.floor(rarity.color.G * 255), math.floor(rarity.color.B * 255))
		table.insert(parts, '<font color="' .. hex .. '">● ' .. tostring(tierFound[rarityName] or 0) .. "/" .. tostring(tierTotal[rarityName] or 0) .. "</font>")
	end
	tierLine.Text = table.concat(parts, "  ")
	-- Mutations line: one chip per mutation — found in its own colour
	-- with its multiplier, unfound as a grey "???".
	local mutParts: { string } = {}
	for _, mutation in ipairs(MutationConfig.MUTATIONS) do
		if mutationsSet[mutation.name] then
			local hex = string.format("#%02X%02X%02X", math.floor(mutation.color.R * 255), math.floor(mutation.color.G * 255), math.floor(mutation.color.B * 255))
			table.insert(mutParts, '<font color="' .. hex .. '">✦ ' .. mutation.name .. " x" .. tostring(mutation.mult) .. "</font>")
		else
			table.insert(mutParts, '<font color="#555566">✦ ???</font>')
		end
	end
	mutationLine.Text = "Mutations: " .. table.concat(mutParts, "  ")
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
	mutationsSet = data.mutations or {}
	buddyName = data.buddyName
	if indexPanel.Visible then
		refreshIndex()
	end
end)

print("Starfall Brainrots index ready.")
