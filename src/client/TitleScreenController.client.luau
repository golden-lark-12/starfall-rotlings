--!strict
-- Starfall Rotlings: title screen.
-- The real start screen every player sees on join, rendered live in the
-- game: the big title, our tagline, the rarity ladder (one of OUR
-- Rotlings per tier, picked from the catalog at runtime), the 3-step
-- loop, a storm warning line, and a big PLAY button that drops you into
-- the game. No external images, no key art — everything here is built
-- from TextLabels and the game's own data, so it captures in Roblox
-- exactly like the other shots.
--
-- Our own layout: one centred column — title, tagline, ladder strips,
-- three step chips in a row, PLAY. (Not a 3D pedestal ladder, not a
-- vertical numbered list.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local gui = GuiKit.getGui()

-- The root frame covers the whole screen and sinks input (Active),
-- so no HUD button behind it can be clicked before PLAY.
local titleFrame = Instance.new("Frame")
titleFrame.Name = "TitleScreen"
titleFrame.Size = UDim2.new(1, 0, 1, 0)
titleFrame.Position = UDim2.new(0, 0, 0, 0)
titleFrame.BackgroundColor3 = Color3.fromRGB(24, 16, 48)
titleFrame.BackgroundTransparency = 0.05
titleFrame.BorderSizePixel = 0
titleFrame.Active = true
titleFrame.ZIndex = 50
titleFrame.Parent = gui

local function titleLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = GuiKit.makeLabel(parent, name, text, size, position, textSize, color)
	label.ZIndex = 51
	return label
end

-- Big title, top-centre.
local title = titleLabel(titleFrame, "TitleText", "⭐ STARFALL ROTLINGS ⭐", UDim2.new(0, 900, 0, 64), UDim2.new(0.5, 0, 0, 28), 48, GuiKit.COLORS.Gold)
title.AnchorPoint = Vector2.new(0.5, 0)

-- Our tagline, under the title (the same line as the crater billboard).
local tagline = titleLabel(titleFrame, "Tagline", "Grab them. Grow them. Guard your base.", UDim2.new(0, 700, 0, 32), UDim2.new(0.5, 0, 0, 96), 24, GuiKit.COLORS.White)
tagline.AnchorPoint = Vector2.new(0.5, 0)

-- Rarity ladder: six horizontal strips in one centred panel, one row
-- per tier — tier colour chip, tier name, and one of our Rotlings of
-- that tier with its income. The representative is picked from the
-- catalog at runtime, so the ladder always shows real game data.
local ladderPanel = GuiKit.makePanel(titleFrame, "LadderPanel", UDim2.new(0, 560, 0, 268), UDim2.new(0.5, -280, 0, 140))
ladderPanel.ZIndex = 51
local ladderTitle = GuiKit.makeLabel(ladderPanel, "LadderTitle", "THE ROTLINGS — 6 RARITIES", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 6), 20, GuiKit.COLORS.Gold)
ladderTitle.ZIndex = 52
for i, rarity in ipairs(RarityConfig.RARITIES) do
	local rowY = 40 + (i - 1) * 36
	-- Tier colour chip.
	local chip = Instance.new("Frame")
	chip.Name = "Chip" .. rarity.name
	chip.Size = UDim2.new(0, 24, 0, 24)
	chip.Position = UDim2.new(0, 16, 0, rowY + 4)
	chip.BackgroundColor3 = rarity.color
	chip.BorderSizePixel = 0
	chip.ZIndex = 52
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 6)
	chipCorner.Parent = chip
	chip.Parent = ladderPanel
	-- Tier name.
	local tierLabel = GuiKit.makeLabel(ladderPanel, "Tier" .. rarity.name, rarity.name, UDim2.new(0, 130, 0, 28), UDim2.new(0, 52, 0, rowY), 20, rarity.color)
	tierLabel.TextXAlignment = Enum.TextXAlignment.Left
	tierLabel.ZIndex = 52
	-- One of our Rotlings of this tier, with its income.
	local rep: RotlingCatalog.RotlingDef? = nil
	for _, def in ipairs(RotlingCatalog.DEFS) do
		if def.rarity == rarity.name then
			rep = def
			break
		end
	end
	local repText = "—"
	if rep then
		repText = rep.name .. " — " .. Formatting.formatMoney(math.floor(rarity.cps * rep.cpsMult)) .. "/s"
	end
	local repLabel = GuiKit.makeLabel(ladderPanel, "Rep" .. rarity.name, repText, UDim2.new(0, 350, 0, 28), UDim2.new(0, 190, 0, rowY), 20, GuiKit.COLORS.White)
	repLabel.TextXAlignment = Enum.TextXAlignment.Left
	repLabel.ZIndex = 52
end

-- The 3-step loop: three chips in a row, not a vertical list.
local stepsPanel = Instance.new("Frame")
stepsPanel.Name = "StepsPanel"
stepsPanel.Size = UDim2.new(0, 660, 0, 92)
stepsPanel.Position = UDim2.new(0.5, -330, 0, 424)
stepsPanel.AnchorPoint = Vector2.new(0, 0)
stepsPanel.BackgroundTransparency = 1
stepsPanel.ZIndex = 51
stepsPanel.Parent = titleFrame
local steps = {
	{ num = "1", verb = "GRAB", text = "a Rotling\nin the crater" },
	{ num = "2", verb = "CARRY", text = "it home\nto your base" },
	{ num = "3", verb = "EARN", text = "coins\nevery second" },
}
for i, step in ipairs(steps) do
	local chip = GuiKit.makePanel(stepsPanel, "Step" .. tostring(i), UDim2.new(0, 208, 0, 92), UDim2.new(0, (i - 1) * 226, 0, 0))
	chip.ZIndex = 52
	local numLabel = GuiKit.makeLabel(chip, "StepNum", step.num, UDim2.new(0, 40, 0, 40), UDim2.new(0, 8, 0, 8), 30, GuiKit.COLORS.Gold)
	numLabel.ZIndex = 53
	local verbLabel = GuiKit.makeLabel(chip, "StepVerb", step.verb, UDim2.new(0, 150, 0, 30), UDim2.new(0, 50, 0, 10), 22, GuiKit.COLORS.White)
	verbLabel.TextXAlignment = Enum.TextXAlignment.Left
	verbLabel.ZIndex = 53
	local textLabel = GuiKit.makeLabel(chip, "StepText", step.text, UDim2.new(0, 150, 0, 44), UDim2.new(0, 50, 0, 40), 16, GuiKit.COLORS.White)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.ZIndex = 53
end

-- Storm warning line: the threat, previewed before PLAY.
local stormLine = titleLabel(titleFrame, "StormLine", "🌠 Meteor storms sweep the map — run home before it hits!", UDim2.new(0, 700, 0, 30), UDim2.new(0.5, 0, 0, 532), 20, Color3.fromRGB(255, 150, 120))
stormLine.AnchorPoint = Vector2.new(0.5, 0)

-- The big PLAY button: the only way in.
local playButton = GuiKit.makeButton(titleFrame, "PlayButton", "▶ PLAY", UDim2.new(0, 300, 0, 64), UDim2.new(0.5, -150, 0, 578), GuiKit.COLORS.Buy)
playButton.TextSize = 30
playButton.ZIndex = 52
playButton.MouseButton1Click:Connect(function()
	titleFrame.Visible = false
	print("[Title] PLAY pressed — entering the game.")
end)

print("Starfall Rotlings title screen ready.")
