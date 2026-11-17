--!strict
-- Starfall Rotlings: name-tag manager.
-- One client, one rule: show at most the 3 nearest Rotling name tags,
-- and only within 25 studs. When Rotlings stand close, their tags used
-- to stack into unreadable text; now the client re-evaluates every
-- quarter second and enables only the three closest tags to the local
-- player. Carried Rotlings never show a tag (their State is "carried").
-- This is per-player by construction: each client decides for itself,
-- so one player's nearest three are not another's.
-- The server still hides a carried Rotling's tag the moment it is
-- grabbed (RotlingFactory.setCarriedVisual); this controller is the
-- second layer that thins the field, and it never re-enables a tag the
-- server hid for a carried Rotling.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local player = Players.LocalPlayer

local function updateTags()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local origin = root.Position
	-- Every Rotling with a label, with its distance from this player.
	local tagged: { { label: BillboardGui, dist: number, showable: boolean } } = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") then
			local body = descendant.PrimaryPart
			local label = body and body:FindFirstChild("RotlingLabel")
			if body and label and label:IsA("BillboardGui") then
				local state = descendant:GetAttribute("State")
				local flat = Vector3.new(body.Position.X - origin.X, 0, body.Position.Z - origin.Z)
				table.insert(tagged, {
					label = label,
					dist = flat.Magnitude,
					showable = state == "free" or state == "placed",
				})
			end
		end
	end
	table.sort(tagged, function(a, b)
		return a.dist < b.dist
	end)
	-- Only the nearest few, only up close: a tag shows when its
	-- Rotling is free or placed, within TAG_MAX_DISTANCE, and among
	-- the TAG_MAX_SHOWN nearest such Rotlings. Everything else stays
	-- off, including every carried Rotling and every tag past 25 studs.
	-- PHOTO MODE override: when the camera has the PhotoMode attribute
	-- (set by PhotoModeController while framing a shot), show EVERY
	-- tag within TAG_PHOTO_MAX_DISTANCE — the screenshots need every
	-- label readable, so the thinning is lifted for the shot only.
	local photoMode = workspace.CurrentCamera and workspace.CurrentCamera:GetAttribute("PhotoMode") == true
	local maxDist = if photoMode then Config.TAG_PHOTO_MAX_DISTANCE else Config.TAG_MAX_DISTANCE
	local maxShown = if photoMode then Config.TAG_PHOTO_MAX_SHOWN else Config.TAG_MAX_SHOWN
	local shown = 0
	for _, entry in ipairs(tagged) do
		local show = false
		if entry.showable and entry.dist <= maxDist then
			shown += 1
			show = shown <= maxShown
		end
		entry.label.Enabled = show
	end
end

task.spawn(function()
	while true do
		local ok, err = pcall(updateTags)
		if not ok then
			warn("[TagController] updateTags failed: " .. tostring(err))
		end
		task.wait(0.25)
	end
end)

print("Starfall Rotlings tag manager ready.")
