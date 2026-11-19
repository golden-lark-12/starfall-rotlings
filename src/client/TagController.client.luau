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
-- PHOTO MODE ORIGIN (fix: hero labels, Nov 19) — in photo mode the
-- distance is measured from the CAMERA, not the player's feet. The
-- player spawns at their own base (Main pivots the character beside
-- the base platform on join), ~145 studs from the hero row — so a
-- player-origin distance hid every label in shot 1 even though the
-- shot-1 camera sits ~18 studs from the heroes. Both of Malek's Nov
-- 19 hero captures show the four heroes with no labels above any of
-- them, while the frame itself is identical either way: only the tag
-- gate moved. The camera is what frames the shot, so in photo mode
-- the camera is what the 40-stud range is measured from. In normal
-- play the origin stays the player's root.
-- DIAGNOSTIC (TEMPORARY — remove once the hero-label cause is known):
-- the camera-origin fix above reads correctly in source but the four
-- hero labels STILL do not render in Malek's captures (fresh rejoin,
-- rev 129 confirmed live, Nov 19 ~20:09). updateTags therefore returns
-- its counts and the loop below prints one [TagDiag] F9 line every ~2s
-- while photo mode is active, so the live numbers say which gate is
-- eating the labels instead of another static guess.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local player = Players.LocalPlayer

-- Returns the tag counts for this tick (nil when there is no origin
-- to measure from). The DIAGNOSTIC loop below prints them while
-- photo mode is active.
local function updateTags()
	local camera = workspace.CurrentCamera
	local photoMode = camera ~= nil and camera:GetAttribute("PhotoMode") == true
	-- Origin: the camera in photo mode, the player's root in normal
	-- play (see the header: the player spawns ~145 studs from the
	-- hero row, so a player-origin distance hid every shot-1 label).
	local origin: Vector3? = nil
	if photoMode and camera then
		origin = camera.CFrame.Position
	else
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			origin = root.Position
		end
	end
	if not origin then
		return nil
	end
	-- Every Rotling with a label, with its distance from the origin
	-- (the camera in photo mode, the player otherwise).
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
					state = state,
					showable = state == "free" or state == "placed" or state == "display",
				})
			end
		end
	end
	table.sort(tagged, function(a, b)
		return a.dist < b.dist
	end)
	-- Only the nearest few, only up close: a tag shows when its
	-- Rotling is free, placed or a display hero, within
	-- TAG_MAX_DISTANCE, and among the TAG_MAX_SHOWN nearest such
	-- Rotlings. Everything else stays off, including every carried
	-- Rotling and every tag past 25 studs. Display heroes (the logo
	-- stage and the hero row, State "display") show their tags in
	-- normal play too — they are a showcase, and a player walking
	-- the plaza reads their names — and in photo mode, where the
	-- staged shots need every label. They take the free tag's 6-stud
	-- minimum (not the placed 12): they stand in the open plaza,
	-- not on a base under its sign.
	-- PHOTO MODE override (computed above): when the camera has the
	-- PhotoMode attribute (set by PhotoModeController while framing
	-- a shot), show EVERY tag within TAG_PHOTO_MAX_DISTANCE — the
	-- screenshots need every label readable, so the thinning is
	-- lifted for the shot only. The origin is the camera here too
	-- (see above), so the range is measured from the frame, not
	-- from where the player's feet happen to be.
	local maxDist = if photoMode then Config.TAG_PHOTO_MAX_DISTANCE else Config.TAG_MAX_DISTANCE
	local maxShown = if photoMode then Config.TAG_PHOTO_MAX_SHOWN else Config.TAG_MAX_SHOWN
	-- DIAGNOSTIC counts (see the header): display = tagged models
	-- whose State is "display"; showable = showable state AND inside
	-- the [minDist, maxDist] window; shown = labels actually set
	-- Enabled=true this tick.
	local shown = 0
	local enabledCount = 0
	local displayCount = 0
	local showableCount = 0
	for _, entry in ipairs(tagged) do
		if entry.state == "display" then
			displayCount += 1
		end
		local show = false
		-- Too close hides the tag (fix round 5, item 5): a 200x84
		-- AlwaysOnTop tag right in front of the camera fills the
		-- screen and overlaps the base sign and the thief banner
		-- (Playtest 5's "Mister Muffin Feet"). A hidden close tag
		-- does not consume one of the 3 shown slots. Step back and
		-- it reads again. Placed tags hide until 12 studs (fix round
		-- 9, item 10): they overlap the base sign from on the base;
		-- free tags keep 6 — they are the crater's readable names.
		local minDist = if entry.state == "placed" then Config.TAG_PLACED_MIN_DISTANCE else Config.TAG_MIN_DISTANCE
		if entry.showable and entry.dist >= minDist and entry.dist <= maxDist then
			showableCount += 1
			shown += 1
			show = shown <= maxShown
		end
		if show then
			enabledCount += 1
		end
		entry.label.Enabled = show
	end
	local nearest = tagged[1] and tagged[1].dist or nil
	return {
		photoMode = photoMode,
		tagged = #tagged,
		display = displayCount,
		showable = showableCount,
		shown = enabledCount,
		nearestDist = nearest,
	}
end

task.spawn(function()
	local diagTicks = 0
	while true do
		local ok, stats = pcall(updateTags)
		if not ok then
			warn("[TagController] updateTags failed: " .. tostring(stats))
			diagTicks = 0
		elseif type(stats) == "table" and stats.photoMode then
			-- DIAGNOSTIC (TEMPORARY): one F9 line every ~2s while
			-- photo mode is active (8 ticks x 0.25s). See the header
			-- for how to read the numbers.
			diagTicks += 1
			if diagTicks >= 8 then
				diagTicks = 0
				print(string.format("[TagDiag] photoMode=%s tagged=%d display=%d showable=%d shown=%d nearestDist=%s",
					tostring(stats.photoMode),
					stats.tagged,
					stats.display,
					stats.showable,
					stats.shown,
					if stats.nearestDist then string.format("%.1f", stats.nearestDist) else "none"))
			end
		else
			diagTicks = 0
		end
		task.wait(0.25)
	end
end)

print("Starfall Brainrots tag manager ready.")
