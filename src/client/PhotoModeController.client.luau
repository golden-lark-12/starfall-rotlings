--!strict
-- Space Rock Brainrots!: photo mode.
-- Press P (or type /photo in chat) to step through FIVE fixed camera
-- shots: the FINAL 4 submission shots, all real gameplay, full HUD in
-- every frame — (1) hero row — the staged group in front of the title
-- sign: four distinct Brainrots with their labels on, the big title
-- sign and the crater behind them (the first thumbnail); (2) belt /
-- grab moment — low and close down the conveyor; (3) storm — the
-- glowing storm wall, the green SAFE DOME over a base, the (x2)
-- income boost readout and the red banner in one frame; (4) packed
-- base — pads full of placed Rotlings with the Lv sign — plus (5) the
-- ICON shot: the logo stage near spawn, its three hero Rotlings with
-- the fiery meteor behind them, framed square for the 512x512 icon. The title
-- screen stays in the game but is NOT one of the 4 shots: the
-- submission sheet is gameplay only, no key art. Each shot is a
-- deterministic fixed CFrame — never a free-fly — and the chat is
-- hidden while a shot is framed, so the capture is clean. A 6th press
-- exits photo mode and hands the camera back to the player.
--
-- Roblox gives a LocalScript no screenshot-file API, so a shot is
-- CAPTURED by the player: the bar at the bottom of each shot says so.
-- Open the ⋯ menu → Screenshot and it saves to the device's
-- Photos/Pictures, ready to send back. On desktop the same button is
-- in the in-game menu (Esc). The bar auto-hides 4 seconds after a
-- shot frames (fade, then invisible) so it is NEVER in the capture —
-- it comes straight back the moment the player presses P / Next /
-- Exit or the shot changes. The normal HUD stays up the whole time;
-- only the photo bar goes.
--
-- CameraFX shakes the camera during storms; it checks the camera's
-- "PhotoMode" attribute and never shakes while a shot is framed, so
-- every shot is a fixed frame even mid-storm. While photo mode is on,
-- TagController shows every tag within 40 studs, so the screenshots
-- have every label readable.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer

-- The 5 shots, in order — the FINAL 4 submission shots plus the icon
-- shot. Positions are fixed in world space (belt, storm, hero, icon)
-- or fixed relative to the player (base). Tune a CFrame here and every
-- capture of that shot moves.
local SHOTS = {
	{
		-- HERO ROW, and the first thumbnail: the staged group in
		-- front of the title sign (fix round 13, item 6) — four
		-- distinct Brainrots on the hero plinth with their labels
		-- on, the big "SPACE ROCK BRAINROTS!" sign behind them and
		-- the crater rim flanking it. Camera (1.75, 14, 96) looking
		-- at (1, 3, 80): the heroes read 16-19% of frame height,
		-- their labels clear of the sign text, the contract board
		-- (a wall at x~16) out of frame to the east. Do NOT move
		-- this camera back to a generic close-up — the staged
		-- composition IS shot 1.
		name = "1/4 — Hero",
		detail = "Hero row: four Brainrots with labels, title sign and crater behind",
		position = Vector3.new(1.75, 14, 96),
		lookAt = Vector3.new(1, 3, 80),
	},
	{
		-- BELT / GRAB MOMENT: low and close behind the belt's near
		-- end, looking down the conveyor at the crater and the
		-- beacon. The belt's Rotlings are ~24 studs away — big, with
		-- their rarity tags readable — instead of a distant landscape.
		-- Camera (41, 11, 8): the OLD camera (42, 4.5, 9) sat BELOW
		-- the crater rim top (5.5), so its sightline to (0, 2, 0)
		-- crossed the rim at y~4.3 and the whole frame was the rim
		-- wall (Malek's shot-2 photo, Nov 19 ~19:31: dark blue wall,
		-- one "Pip" label). Raised to y=11 — the sightline now
		-- clears the rim top by 2.5+ studs and the tallest meteor
		-- shard (7.0) by 2+ studs at every rim radius; the near rim
		-- sits below the frame's bottom edge, so it cannot block
		-- the belt. Same east-end viewpoint, same lookAt (0, 2, 0):
		-- belt receding to the beacon at frame centre, far rim as
		-- the backdrop. See the belt-shot check for the computed
		-- proof (clearances + framing angles).
		name = "2/4 — Belt",
		detail = "Grab moment: down the conveyor belt, Brainrots and the beacon",
		position = Vector3.new(41, 11, 8),
		lookAt = Vector3.new(0, 2, 0),
	},
	{
		name = "3/4 — Storm",
		detail = "Storm wall + dome + income boost: the glowing front, the green SAFE DOME, the (x2) readout, the red banner",
		-- Storm wall + dome + income boost in ONE frame: the glowing
		-- front sweeping the map, the green SAFE DOME over a base,
		-- the (x2) income readout in the HUD, the full-width red
		-- banner. Best captured while a storm is running — stand on
		-- your base so the dome and the boost both show.
		position = Vector3.new(48, 10, 18),
		lookAt = Vector3.new(0, 12, 0),
	},
	{
		name = "4/4 — Packed base",
		detail = "Pads full of placed Brainrots, Lv sign and banked cash",
		position = nil, -- computed from the nearest base, below
		lookAt = nil,
	},
	{
		name = "Icon — 512x512",
		detail = "Icon: logo stage near spawn — three hero Brainrots, fiery meteor behind, square crop",
		-- Icon shot: the logo stage at (0, 0, 118) with its three
		-- hero Rotlings (8 apart, labels readable) and the fiery
		-- meteor prop above/behind them. The stage MOVED in v74
		-- from (-25, 0, 88) to (0, 0, 118) and this camera never
		-- followed it — it framed empty field until fix round 13.
		-- Camera 18 studs south of the stage, looking north at the
		-- centre Rotling with the meteor above/behind it — framed
		-- for a square 512x512 icon crop.
		position = Vector3.new(0, 4, 100),
		lookAt = Vector3.new(0, 3, 118),
	},
}

local shotIndex = 0 -- 0 = photo mode off; 1-5 = the shot showing

local gui = Instance.new("ScreenGui")
gui.Name = "PhotoModeGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

-- Bottom bar: shot name on top, capture instruction under it. It sits
-- above the HUD hint line, so it covers no HUD element.
-- AUTO-HIDE (Malek, Nov 19 ~19:40): the bar is a tool artifact — it
-- was in every screenshot he captured ("the text showing down isnt
-- the best thing"). It fades out BAR_HIDE_DELAY seconds after a shot
-- frames and stays hidden until the next P / Next / Exit, so the
-- capture is a clean game frame. The normal HUD is untouched.
local BAR_HIDE_DELAY = 4 -- seconds the bar stays up after a shot frames
local BAR_FADE_STEPS = 10 -- 10 x 0.05s = 0.5s fade
local BAR_FADE_STEP_WAIT = 0.05
local barToken = 0 -- bumped on every show/exit; a pending hide whose token no longer matches is dead
local bar = GuiKit.makePanel(gui, "PhotoBar", UDim2.new(0, 620, 0, 56), UDim2.new(0.5, -310, 1, -108))
bar.Visible = false
local titleLabel = GuiKit.makeLabel(bar, "PhotoTitle", "", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 2), 22, GuiKit.COLORS.Gold)
local helpLabel = GuiKit.makeLabel(bar, "PhotoHelp", "", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 28), 17, GuiKit.COLORS.White)
local nextButton = GuiKit.makeButton(bar, "NextShot", "Next ▶", UDim2.new(0, 110, 0, 40), UDim2.new(1, -122, 0, 8), GuiKit.COLORS.Blue)
local exitButton = GuiKit.makeButton(bar, "ExitPhoto", "Exit ✕", UDim2.new(0, 110, 0, 40), UDim2.new(0, 12, 0, 8), GuiKit.COLORS.Close)

-- Snapshot of the bar's designed transparency values, taken once, so
-- the fade can interpolate back to them exactly (labels start at
-- BackgroundTransparency 1, the panel at 0.15, strokes at 0.5/0.7 —
-- a blind "set everything to 0" restore would paint label
-- backgrounds solid and flatten the panel stroke).
local barOriginals: { [Instance]: { [string]: number } }? = nil
local function snapshotBar()
	if barOriginals then
		return
	end
	local snapped: { [Instance]: { [string]: number } } = {}
	local function snap(inst: Instance)
		local props: { [string]: number } = {}
		if inst:IsA("GuiObject") then
			props.BackgroundTransparency = inst.BackgroundTransparency
		end
		if inst:IsA("TextLabel") or inst:IsA("TextButton") then
			props.TextTransparency = inst.TextTransparency
			props.TextStrokeTransparency = inst.TextStrokeTransparency
		end
		if inst:IsA("UIStroke") then
			props.Transparency = inst.Transparency
		end
		if next(props) ~= nil then
			snapped[inst] = props
		end
	end
	snap(bar)
	for _, descendant in bar:GetDescendants() do
		snap(descendant)
	end
	barOriginals = snapped
end

local function applyBarFade(alpha: number)
	-- alpha 0 = as designed, 1 = fully invisible
	if not barOriginals then
		return
	end
	for inst, props in barOriginals do
		for prop, original in props do
			(inst :: any)[prop] = original + (1 - original) * alpha
		end
	end
end

local function showBar()
	snapshotBar()
	applyBarFade(0)
	bar.Visible = true
end

local function hideBarSoon()
	-- Any later show/exit bumps the token and cancels this hide.
	barToken += 1
	local token = barToken
	task.spawn(function()
		task.wait(BAR_HIDE_DELAY)
		if token ~= barToken or shotIndex == 0 then
			return
		end
		for step = 1, BAR_FADE_STEPS do
			task.wait(BAR_FADE_STEP_WAIT)
			if token ~= barToken or shotIndex == 0 then
				-- A new shot (or exit) took over mid-fade: leave the
				-- bar exactly as the new state set it.
				return
			end
			applyBarFade(step / BAR_FADE_STEPS)
		end
		if token == barToken and shotIndex ~= 0 then
			bar.Visible = false
		end
	end)
end

-- Base centres ring the crater: base id 1 at angle 0, the rest every
-- 360/BASE_COUNT degrees. The nearest one to the player is their base.
local function nearestBaseCenter(): Vector3
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local from = if root then root.Position else Vector3.new(Config.BASE_RADIUS, 0, 0)
	local best = Vector3.new(Config.BASE_RADIUS, 0, 0)
	local bestDist = math.huge
	for baseId = 1, Config.BASE_COUNT do
		local angle = math.rad((baseId - 1) * (360 / Config.BASE_COUNT))
		local center = Vector3.new(math.cos(angle) * Config.BASE_RADIUS, 0, math.sin(angle) * Config.BASE_RADIUS)
		local dist = (Vector3.new(from.X, 0, from.Z) - center).Magnitude
		if dist < bestDist then
			bestDist = dist
			best = center
		end
	end
	return best
end

local function shotCFrame(index: number): CFrame
	local shot = SHOTS[index]
	if index == 4 then
		-- My base: 26 studs out on the crater side, 10 up, looking
		-- back at the platform so the pads, the labels, the sign
		-- and the banked cash all show. The OLD camera (16 out /
		-- 7 up, "closer so the base fills the frame and the tags
		-- read") framed too tight — Malek's shot-4 captures (Nov
		-- 19 ~19:39 and ~19:49) are giant Brainrots filling the
		-- whole frame, their labels occluded behind them, no Lv
		-- sign, no banked cash, no sense of pads full of
		-- Brainrots. Pulled back: near-row bodies read ~16% of
		-- frame height (was ~29%), far-row labels clear the
		-- near-row bodies by ~1.9 studs, the whole 26x22 platform
		-- and the sign board are in frame. See the packed-base-shot
		-- check for the computed proof.
		local center = nearestBaseCenter()
		local towardCrater = (Vector3.new(0, 0, 0) - center).Unit
		local position = center + Vector3.new(towardCrater.X, 0, towardCrater.Z) * 26 + Vector3.new(0, 10, 0)
		return CFrame.lookAt(position, center + Vector3.new(0, 4, 0))
	end
	return CFrame.lookAt(shot.position :: Vector3, shot.lookAt :: Vector3)
end

local function hideChat()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	end)
end

local function showChat()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	end)
end

local function exitPhotoMode()
	shotIndex = 0
	-- Cancel any pending auto-hide; the bar is gone with the mode.
	barToken += 1
	bar.Visible = false
	local camera = workspace.CurrentCamera
	if camera then
		camera:SetAttribute("PhotoMode", false)
		camera.CameraType = Enum.CameraType.Custom
	end
	showChat()
end

local function showShot(index: number)
	shotIndex = index
	local shot = SHOTS[index]
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Scriptable camera, fixed frame, no storm shake (CameraFX reads
	-- the PhotoMode attribute and stands down while it is set).
	camera.CameraType = Enum.CameraType.Scriptable
	camera:SetAttribute("PhotoMode", true)
	camera.CFrame = shotCFrame(index)
	hideChat()
	titleLabel.Text = "📷 Photo " .. shot.name .. " — " .. shot.detail
	helpLabel.Text = "Capture it: ⋯ menu → Screenshot (saves to Photos). P = next shot."
	nextButton.Text = if index == #SHOTS then "Exit ✕" else "Next ▶"
	-- Bar up (restored to full opacity), then gone again in 4s so
	-- the capture is clean. P / Next / Exit re-shows it via showShot.
	showBar()
	hideBarSoon()
end

local function advanceShot()
	if shotIndex == 0 then
		showShot(1)
	elseif shotIndex >= #SHOTS then
		exitPhotoMode()
	else
		showShot(shotIndex + 1)
	end
end

nextButton.MouseButton1Click:Connect(function()
	advanceShot()
end)
exitButton.MouseButton1Click:Connect(function()
	exitPhotoMode()
end)

ContextActionService:BindAction("PhotoMode", function(_, inputState: EnumItem)
	if inputState == Enum.UserInputState.Begin then
		advanceShot()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.P)

player.Chatted:Connect(function(message: string)
	if message == "/photo" then
		advanceShot()
	end
end)

print("Starfall Brainrots photo mode ready (P or /photo).")
