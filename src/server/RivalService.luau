--!strict
-- Starfall Rotlings: rival bots.
-- 3-4 named rivals that own the other bases (5-8, reserved at server
-- start so a joining player never collides with one), run to the
-- crater, grab Rotlings, carry them home and earn — and show on the
-- leaderboard, so the competition is visible in every shot. Every so
-- often a rival sneaks to a real player's unlocked base to steal a
-- Rotling (red alert + a THIEF sign over its head; Lock Base blocks
-- it), and when a player carries a meteor egg or a Brainrot, the
-- NEAREST rivals chase them — "THIEF ON YOUR TAIL!" with a live
-- distance readout — and a touch makes the carrier drop what they
-- carry (fix round 8, item 8: the chase used to need a rival within
-- 30 studs, but rivals sit at radius 110, so nobody ever chased).
-- A rival near a free-walking player HUNTS them too (follow-up,
-- item 2 — Malek: "shouldn't they also try to get me like the
-- guardian?"): the thief runs the player down at 22 studs/s and, on
-- the tag, steals the best carried Brainrot and runs home with it —
-- or knocks the player flat if they carry nothing. The base
-- interior is the refuge: the hunt ends at the door, like the
-- guardian giving up on the platform.
-- Slap a rival and it drops what it carries and flees; rivals slap
-- back. Real players can steal from rivals' bases too (their pads
-- are never locked).

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local RotlingFactory = require(script.Parent.RotlingFactory)
local FeedbackService = require(script.Parent.FeedbackService)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local RivalService = {}

local running = false

local RIVAL_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(120, 255, 150),
	Color3.fromRGB(255, 220, 100),
}

local function makePart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	return part
end

-- Build a rival: a blocky bot in its base colour, with a name tag and
-- a red THIEF sign (hidden until it steals).
local function buildRival(name: string, color: Color3, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Rival " .. name

	local body = makePart("Body", Enum.PartType.Block, Vector3.new(3, 3.4, 2), color)
	body.CFrame = CFrame.new(position + Vector3.new(0, 2.4, 0))
	body.CanCollide = true
	body.Parent = model
	model.PrimaryPart = body

	local head = makePart("Head", Enum.PartType.Ball, Vector3.new(2.2, 2.2, 2.2), Color3.fromRGB(255, 220, 180))
	head.CFrame = body.CFrame * CFrame.new(0, 2.6, 0)
	head.Parent = model
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.Parent = head

	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Eye", Enum.PartType.Ball, Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(20, 20, 30))
		eye.CFrame = body.CFrame * CFrame.new(side * 0.5, 3.1, 1)
		eye.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	-- Name tag above the head.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RivalTag"
	billboard.Size = UDim2.fromOffset(140, 36)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 60
	billboard.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "🤖 " .. name
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	-- THIEF sign: hidden until this rival steals. Big (220x48, fix
	-- round 9, item 9 — the old 160x36 was easy to miss at a glance).
	local thiefSign = Instance.new("BillboardGui")
	thiefSign.Name = "ThiefSign"
	thiefSign.Size = UDim2.fromOffset(220, 48)
	thiefSign.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	thiefSign.AlwaysOnTop = true
	thiefSign.LightInfluence = 0
	thiefSign.MaxDistance = 80
	thiefSign.Enabled = false
	thiefSign.Parent = body
	local thiefLabel = Instance.new("TextLabel")
	thiefLabel.Size = UDim2.new(1, 0, 1, 0)
	thiefLabel.BackgroundTransparency = 1
	thiefLabel.Text = "🚨 THIEF!"
	thiefLabel.Font = Enum.Font.FredokaOne
	thiefLabel.TextScaled = true
	thiefLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
	thiefLabel.TextStrokeTransparency = 0.2
	thiefLabel.Parent = thiefSign

	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = Config.RIVAL_WALK_SPEED
	humanoid.Parent = model
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = body.CFrame
	root.Parent = model
	local rootWeld = Instance.new("WeldConstraint")
	rootWeld.Part0 = body
	rootWeld.Part1 = root
	rootWeld.Parent = root

	return model
end

-- True while a storm is running: a rival mid-walk aborts and runs for
-- its Safe Dome instead of finishing the trip in the meteor rain.
local function stormRunning(): boolean
	local StarfallService = require(script.Parent.StarfallService)
	return StarfallService.getStatus().phase == "storm"
end

-- Walk a rival to a point: MoveTo, wait until close (4 studs) or
-- the timeout. A stuck rival hops (the 2-stud platform edge and the
-- tiered crater rim need a jump). Roblox gives a MoveTo an internal
-- ~8s timeout and then stops the Humanoid WITHOUT an error — the old
-- code issued MoveTo ONCE and waited up to 40s, so a rival whose
-- MoveTo timed out stood hopping in place for the rest of the walk
-- and the steal aborted ("Ziggy couldn't reach the base", playtest
-- 9). Re-issuing MoveTo every 2s keeps it pushing until the timeout
-- (fix round 8, item 3).
local function walkTo(model: Model, target: Vector3, timeout: number, shouldCancel: (() -> boolean)?): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return false
	end
	humanoid:MoveTo(target)
	local lastMoveAt = 0
	local done = false
	local connection
	connection = humanoid.MoveToFinished:Connect(function(reached: boolean)
		done = reached
	end)
	local waited = 0
	local lastPos = root.Position
	local stuckTime = 0
	while not done and waited < timeout do
		task.wait(0.5)
		waited += 0.5
		if not model.Parent then
			break
		end
		-- MoveTo's internal ~8s timeout stops the Humanoid silently:
		-- re-issue it every 2s so the walk never dies mid-route.
		if waited - lastMoveAt >= 2 then
			humanoid:MoveTo(target)
			lastMoveAt = waited
		end
		-- Storm: stop the trip now — the next stepRival tick runs
		-- for the Safe Dome. The shelter walk itself passes no
		-- shouldCancel, so it is never aborted by its own storm.
		if shouldCancel and shouldCancel() then
			break
		end
		if (root.Position - target).Magnitude < 4 then
			done = true
		end
		-- Stuck? Hop. MoveTo never jumps, so a bot that walks into
		-- the crater rim or a base edge just pushes against it until
		-- the timeout. The jump clears the step (fix 2).
		if (root.Position - lastPos).Magnitude < 0.5 then
			stuckTime += 0.5
			if stuckTime >= 1.5 then
				humanoid.Jump = true
				stuckTime = 0
			end
		else
			stuckTime = 0
		end
		lastPos = root.Position
	end
	if connection then
		connection:Disconnect()
	end
	return done
end

-- (fix round 7, item 7) The THIEF sign is also a red Highlight on the
-- whole model, visible THROUGH walls (DepthMode Occluded) — so the
-- player can see the thief even when it is behind the base walls or
-- across the map. The sign and the Highlight are one switch: both go
-- on when a steal starts and both go off at every steal end (all
-- six setThiefSign(model, false) call sites), so a Highlight can
-- never leak onto a rival that is not stealing. A red PointLight
-- joins them (fix round 9, item 9): the thief glows red in the dark,
-- so it reads as danger at a glance.
local function setThiefSign(model: Model, on: boolean)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local sign = body:FindFirstChild("ThiefSign")
	if sign and sign:IsA("BillboardGui") then
		sign.Enabled = on
	end
	local thiefLight = body:FindFirstChild("ThiefLight")
	if on then
		if not thiefLight then
			thiefLight = Instance.new("PointLight")
			thiefLight.Name = "ThiefLight"
			thiefLight.Color = Color3.fromRGB(255, 40, 40)
			thiefLight.Brightness = 2
			thiefLight.Range = 12
			thiefLight.Parent = body
		end
	else
		if thiefLight then
			thiefLight:Destroy()
		end
	end
	local highlight = model:FindFirstChild("ThiefHighlight")
	if on then
		if not highlight then
			highlight = Instance.new("Highlight")
			highlight.Name = "ThiefHighlight"
			highlight.FillColor = Color3.fromRGB(255, 40, 40)
			highlight.FillTransparency = 0.8
			highlight.OutlineColor = Color3.fromRGB(255, 40, 40)
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = model
		end
	else
		if highlight then
			highlight:Destroy()
		end
	end
end

-- Clear the thief visuals (sign + light + Highlight) and any hunt
-- state, wherever the rival's thief behaviour ends — bonked, hunt
-- over, steal over. One call so no path can leak the sign onto a
-- rival that is not stealing or hunting: a sign that is on all the
-- time means nothing (follow-up, item 1: slapRival used to flee
-- without clearing it, so a bonked thief kept the red sign and the
-- through-walls highlight forever, until its next steal ended).
function RivalService.clearThiefVisuals(rival: State.Rival)
	setThiefSign(rival.model, false)
	rival.chaseKind = nil
end

-- Walk to a target WITHOUT crossing the crater: route along a ring
-- of open ground at radius 45 (the rim's outer ring ends at 39),
-- then straight in. (fix round 7, item 2) The straight-line walks
-- are why rivals read as dead: a rival starts at its own base
-- (radius 110) and a far-side victim's "around" point is at radius
-- 45 on the opposite side, so the chord passes near the origin —
-- straight through the tiered rim (2.5 / 4 / 5.5 studs). The
-- stuck-hop cannot reliably clear those rings, so the walk timed out
-- at 40s and the steal aborted. Same for the crater approach: the
-- gap is at +Z, so a rival on the -Z side walked straight through
-- the crater to reach it. The ring route never crosses the rim: from
-- inside the crater, exit through the entrance gap (+Z, the one open
-- side); from outside, drop radially to the ring at your own angle;
-- arc along the ring to the target's angle (shorter way); then walk
-- straight to the target. Every rival walk uses this — toCrater,
-- steal, and toBase — so a rival can never stall on the rim again.
local function walkAround(model: Model, target: Vector3, timeout: number, shouldCancel: (() -> boolean)?): boolean
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local start = root.Position
	local startR = Vector3.new(start.X, 0, start.Z).Magnitude
	if startR < 42 then
		-- Inside the rim: leave through the entrance gap (+Z).
		if not walkTo(model, Vector3.new(0, Config.CRATER_FLOOR_Y, 45), timeout, shouldCancel) then
			return false
		end
	else
		-- Outside the rim: drop radially to the ring at our angle.
		local startAngle = math.atan2(start.Z, start.X)
		local ringPoint = Vector3.new(math.cos(startAngle) * 45, 0, math.sin(startAngle) * 45)
		if (Vector3.new(start.X, 0, start.Z) - ringPoint).Magnitude > 4 then
			if not walkTo(model, ringPoint, timeout, shouldCancel) then
				return false
			end
		end
	end
	-- Arc along the ring to the target's angle, 30° at a time, the
	-- shorter way around. Re-read the angle after the first leg (the
	-- gap exit lands at +Z, 90°).
	local cur = model:FindFirstChild("HumanoidRootPart")
	if not cur then
		return false
	end
	local curPos = (cur :: BasePart).Position
	local curAngle = math.atan2(curPos.Z, curPos.X)
	local targetFlat = Vector3.new(target.X, 0, target.Z)
	local targetAngle = math.atan2(targetFlat.Z, targetFlat.X)
	local diff = targetAngle - curAngle
	while diff > math.pi do
		diff -= 2 * math.pi
	end
	while diff < -math.pi do
		diff += 2 * math.pi
	end
	local step = math.rad(30) * (if diff >= 0 then 1 else -1)
	local remaining = math.abs(diff)
	while remaining > 0.01 do
		local move = math.min(math.rad(30), remaining)
		curAngle += step * (move / math.rad(30))
		local waypoint = Vector3.new(math.cos(curAngle) * 45, 0, math.sin(curAngle) * 45)
		if not walkTo(model, waypoint, timeout, shouldCancel) then
			return false
		end
		remaining -= move
	end
	-- Straight in from the ring to the target (never crosses the rim:
	-- the target is outside the ring, or the gap side is open).
	return walkTo(model, target, timeout, shouldCancel)
end

-- (fix round 6, item 3) The sneak alert promised a thief at the
-- victim's base. When the steal aborts for any reason, the victim
-- must see the resolution on screen — a silent abort reads as a
-- false alarm ("Ziggy is sneaking!" while no one is there).
local function giveUpBanner(victim: Player?, rivalName: string, reason: string)
	if victim then
		Remotes.bannerEvent():FireClient(victim, "🚨 " .. rivalName .. " gave up sneaking to your base — " .. reason .. "!", 4)
	end
end

-- (fix round 13, item 1) Give-up diagnostic: when a steal walk
-- fails, log WHERE it died (which leg, rival position, target)
-- and the NEAREST solid part, so the F9 trail names the blocker
-- instead of "couldn't reach your base". The trace in auto-checks
-- proves the route clear on paper; this proves it (or finds the
-- miss) in the live game. A placed Brainrot on the target pad
-- reads as the nearest solid on the final leg — that is expected,
-- not a block: the walk only needs to get within 4 studs of the
-- pad centre, and the Brainrot stands on the pad.
local function logWalkDiagnostic(rival: State.Rival, model: Model, leg: string, target: Vector3)
	local root = model:FindFirstChild("HumanoidRootPart")
	local pos = if root then root.Position else Vector3.new(0, 0, 0)
	local nearest: BasePart? = nil
	local nearestDist = math.huge
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = { model }
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _, part in ipairs(workspace:GetPartBoundsInRadius(pos, 14, params)) do
		if part:IsA("BasePart") and part.CanCollide and part.Anchored then
			local d = (part.Position - pos).Magnitude
			if d < nearestDist then
				nearestDist = d
				nearest = part
			end
		end
	end
	local blocker = if nearest
		then nearest.Name .. " at " .. tostring(nearest.Position) .. " (" .. string.format("%.1f", nearestDist) .. " studs)"
		else "none within 14 studs"
	print("[Rival] " .. rival.name .. " STEAL WALK DIAGNOSTIC — leg '" .. leg .. "' failed; rival at " .. tostring(pos) .. ", target " .. tostring(target) .. "; nearest solid: " .. blocker)
end

-- Weld a Rotling to the rival's chest (the rival's own mini-carry).
local function carryModel(rival: State.Rival, model: Model)
	local body = rival.model.PrimaryPart
	local modelBody = model.PrimaryPart
	if not body or not modelBody then
		return
	end
	RotlingFactory.setCarriedVisual(model, true)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = body
	weld.Part1 = modelBody
	weld.C0 = CFrame.new(0, Config.CARRY_Y, Config.CARRY_Z)
	weld.Parent = modelBody
	model:SetAttribute("State", "carried")
	-- A rival-carried Rotling must not show a Grab prompt: the prompt
	-- is how a player finds a catch, and a live prompt on a carried
	-- Rotling reads as "E does nothing" (Playtest 5's grab — the
	-- prompt showed, tryGrab hit state == "carried" and returned
	-- silently). The prompt comes back when the loot is dropped
	-- (scatterToCrater) or placed (setPromptState there).
	-- (fix round 6, item 3) ROOT CAUSE of "the thief still doesn't
	-- do anything": this used to call CarryService2.setPromptState —
	-- a name that does not exist in this file (the only CarryService2
	-- is a LOCAL inside stepRival's toBase branch). Reading the
	-- undefined global returned nil, so every rival grab — crater and
	-- steal alike — errored HERE, after the weld and State="carried"
	-- but before rival.carried was set and before the "stole your X"
	-- banner. The pcall in runRival caught it, the rival went idle
	-- next tick (pad already emptied by removePlaced), and the
	-- Brainrot stayed welded to the rival, earning nothing and never
	-- placed or dropped — which is also why Ziggy/Nova read $0 on the
	-- leaderboard. It is CarryService here.
	CarryService.setPromptState(model)
	model:SetAttribute("BaseId", 0)
	model:SetAttribute("PadIndex", 0)
	rival.carried = model
end

-- Drop what the rival carries back into the crater (slapped, bonked).
function RivalService.dropCarried(rival: State.Rival)
	local model = rival.carried
	if not model then
		return
	end
	rival.carried = nil
	-- A dropped carry is a failed steal: clear the stolen flag, or a
	-- later crater grab placed on the base would log a false STEAL
	-- COMPLETE (fix round 9, item 3).
	rival.stolenName = nil
	rival.stolenFrom = nil
	local body = model.PrimaryPart
	if body then
		local weld = body:FindFirstChild("CarryWeld")
		if weld then
			weld:Destroy()
		end
	end
	CarryService.scatterToCrater(model)
end

function RivalService.getRival(model: Model): State.Rival?
	return State.rivals[model]
end

function RivalService.isRival(model: Model): boolean
	return State.rivals[model] ~= nil
end

-- Wake the NEAREST rivals to chase a carrier (fix round 8, item 8):
-- the old code only woke rivals within 30 studs, but rivals sit at
-- their bases at radius 110 — so a grab in the crater almost never
-- had a rival in range and Malek was never chased ("STILL not chased
-- by anyone", playtest 9). Now the nearest RIVAL_CHASE_MAX (2)
-- available rivals chase, any distance, and the start is logged with
-- the distance so the F9 trail proves it fired.
local function notifyCarrier(player: Player, kind: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local candidates: { { rival: State.Rival, dist: number } } = {}
	for _, rival in pairs(State.rivals) do
		local rivalRoot = rival.model:FindFirstChild("HumanoidRootPart")
		if rivalRoot and rival.phase ~= "chase" and rival.phase ~= "steal" and rival.phase ~= "flee" then
			table.insert(candidates, { rival = rival, dist = (rivalRoot.Position - root.Position).Magnitude })
		end
	end
	table.sort(candidates, function(a, b)
		return a.dist < b.dist
	end)
	local woken = 0
	for _, entry in ipairs(candidates) do
		if woken >= Config.RIVAL_CHASE_MAX then
			break
		end
		entry.rival.phase = "chase"
		entry.rival.chaseKind = "carrier"
		entry.rival.targetUserId = player.UserId
		entry.rival.chaseWaypoints = {}
		entry.rival.chaseWpIndex = 1
		entry.rival.chasePathTarget = nil
		entry.rival.chaseRepathAt = 0
		woken += 1
		print("[Rival] " .. entry.rival.name .. " chasing " .. player.Name .. " (" .. kind .. " carrier, " .. tostring(math.floor(entry.dist)) .. " studs away)")
	end
end

-- A player grabbed a meteor egg: the nearest rivals turn and chase them.
function RivalService.notifyEggCarrier(player: Player)
	notifyCarrier(player, "egg")
end

-- A player grabbed a Brainrot: the nearest rivals give chase, same as an
-- egg carrier (rev 77). Carrying was risk-free before this — rivals
-- only chased egg carriers, so the core loop (grab, run home, don't
-- get tagged) had no teeth for Brainrots.
function RivalService.notifyBrainrotCarrier(player: Player)
	notifyCarrier(player, "Brainrot")
end

-- Is any rival currently chasing this player for a carried Brainrot?
-- (fix round 12, item 3) The heat watcher uses it so it engages
-- once per carry, not once per 0.5s tick while the carrier is out.
function RivalService.isChasingPlayer(userId: number): boolean
	for _, rival in pairs(State.rivals) do
		if rival.phase == "chase" and rival.targetUserId == userId then
			return true
		end
	end
	return false
end

-- Pick a victim: a real player with Rotlings on an unlocked base.
local function pickVictim(): (Player?, number?)
	local candidates: { Player } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local baseId = BaseService.getPlayerBase(player.UserId)
		if baseId and not BaseService.isLocked(baseId) and #BaseService.getPlacedForPlayer(player) > 0 then
			table.insert(candidates, player)
		end
	end
	if #candidates == 0 then
		return nil, nil
	end
	local victim = candidates[math.random(1, #candidates)]
	return victim, BaseService.getPlayerBase(victim.UserId)
end

-- Try to start a HUNT (follow-up, item 2): Malek asked "shouldn't
-- they also try to get me like the guardian?" — a thief near a
-- free-walking player chases the PLAYER, not just the base. The hunt
-- is for players walking free: carriers are the carrier chase's job
-- (they already draw the nearest 2 rivals), and the base interior is
-- safe (a player who made it home is not hunted). One hunter per
-- victim, so a hunt never becomes a swarm. The hunt runs at
-- RIVAL_HUNT_SPEED (22) and the thief reads as a thief the whole
-- time (sign + light + Highlight, same as a steal).
local function tryStartHunt(rival: State.Rival, model: Model): boolean
	if rival.carried or time() < rival.huntReadyAt then
		return false
	end
	if rival.phase ~= "idle" and rival.phase ~= "toCrater" then
		return false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local best: Player? = nil
	local bestDist = Config.RIVAL_HUNT_RADIUS
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if playerRoot and humanoid and humanoid.Health > 0 then
			if State.eggCarriedByUser[player.UserId] == nil and State.brainrotCarriedByUser[player.UserId] == nil then
				local baseId = BaseService.getPlayerBase(player.UserId)
				-- (fix round 13, item 3) The refuge is the whole
				-- platform + ramp, not just the interior — a player
				-- standing on their own base is home, not prey.
				local safe = baseId and WorldBuilder.isOnBasePlatform(baseId, playerRoot.Position)
				if not safe then
					local alreadyHunted = false
					for _, other in pairs(State.rivals) do
						if other ~= rival and other.phase == "chase" and other.targetUserId == player.UserId then
							alreadyHunted = true
							break
						end
					end
					if not alreadyHunted then
						local dist = (playerRoot.Position - root.Position).Magnitude
						if dist < bestDist then
							bestDist = dist
							best = player
						end
					end
				end
			end
		end
	end
	if not best then
		return false
	end
	rival.phase = "chase"
	rival.chaseKind = "hunt"
	rival.targetUserId = best.UserId
	rival.chaseWaypoints = {}
	rival.chaseWpIndex = 1
	rival.chasePathTarget = nil
	rival.chaseRepathAt = 0
	rival.huntStartedAt = time()
	setThiefSign(model, true)
	Remotes.bannerEvent():FireClient(best, "🚨 " .. rival.name .. " is hunting you — run!", 3)
	print("[Rival] " .. rival.name .. " hunting " .. best.Name .. " (" .. tostring(math.floor(bestDist)) .. " studs away)")
	return true
end

-- Try to start a steal: pick a victim with Rotlings on an unlocked
-- base, raise the THIEF sign, warn the victim, and switch the rival
-- to the steal phase. Used by the idle roll AND the steal clock, so
-- both paths start a steal the same way. (fix round 7, item 2)
local function tryStartSteal(rival: State.Rival, model: Model): boolean
	local victim, victimBase = pickVictim()
	if not victim or not victimBase then
		return false
	end
	-- One thief per victim (rev 78): if another rival is already
	-- stealing from this victim, wait for the next roll/clock beat
	-- instead of piling four thieves on the same base at once.
	-- Malek is the only player with placed Brainrots, so all four
	-- rivals could pick him at once — a swarm, not a thief. (Pairs
	-- with the gate fix: once the gate clears, they enter one by
	-- one instead of piling up at the entrance.)
	for _, other in pairs(State.rivals) do
		if other ~= rival and other.phase == "steal" and other.targetUserId == victim.UserId then
			return false
		end
	end
	rival.phase = "steal"
	rival.targetUserId = victim.UserId
	rival.targetBase = victimBase
	setThiefSign(model, true)
	Remotes.bannerEvent():FireClient(victim, "🚨 " .. rival.name .. " is sneaking to your base! Lock it (L)!", 4)
	-- Steal alarm (fix round 7, item 4): the warning banner was
	-- silent — a low alarm so the player HEARS the thief coming.
	FeedbackService.playSound(victim, 0.7, 1)
	-- NO danger alert here (follow-up, item 1): the full-screen
	-- "NAME IS IN YOUR BASE!" treatment used to fire at steal start,
	-- when the thief is still at its own base ~100 studs away — the
	-- alert claimed a presence the thief did not have yet, so the
	-- player learned to distrust it ("it says he's in my base but I
	-- look and nobody's there"). The alert fires ONLY while the thief
	-- is actually inside (the watcher below, every 3s, dist <= 20),
	-- so when it screams, the thief is really there.
	print("[Rival] " .. rival.name .. " stealing from " .. victim.Name .. " (base " .. tostring(victimBase) .. ")")
	return true
end

-- Steer a chasing rival toward the victim's live position on a
-- computed path (fix round 8, item 8): a straight MoveTo from a base
-- at radius 110 to the crater crosses the tiered rim and the rival
-- pushes against it until it stalls. The path routes around the rim
-- through the entrance gap; it is recomputed toward the target's
-- live position whenever the target moved far or 1.5s passed.
-- Shared by the carrier chase and the hunt (follow-up, item 2).
local function steerChase(rival: State.Rival, model: Model, root: BasePart, victimRoot: BasePart)
	local chaseHumanoid = model:FindFirstChildOfClass("Humanoid")
	if not chaseHumanoid then
		return
	end
	local now = time()
	local targetPos = victimRoot.Position
	if #rival.chaseWaypoints == 0 or now - rival.chaseRepathAt >= 1.5 or (rival.chasePathTarget and (targetPos - rival.chasePathTarget).Magnitude > 12) then
		local path = PathfindingService:CreatePath({
			AgentRadius = 3,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentMaxSlope = 45,
		})
		local computed = pcall(function()
			path:ComputeAsync(root.Position, targetPos)
		end)
		if computed and path.Status == Enum.PathStatus.Success then
			local wps: { { pos: Vector3, jump: boolean } } = {}
			for _, wp in ipairs(path:GetWaypoints()) do
				table.insert(wps, { pos = wp.Position, jump = wp.Action == Enum.PathWaypointAction.Jump })
			end
			rival.chaseWaypoints = wps
			rival.chaseWpIndex = 2
			rival.chasePathTarget = targetPos
			rival.chaseRepathAt = now
		else
			rival.chaseWaypoints = {}
			rival.chasePathTarget = nil
		end
	end
	local steered = false
	while rival.chaseWpIndex <= #rival.chaseWaypoints do
		local wp = rival.chaseWaypoints[rival.chaseWpIndex]
		if (wp.pos - root.Position).Magnitude <= 3 then
			rival.chaseWpIndex += 1
		else
			if wp.jump then
				chaseHumanoid.Jump = true
			end
			chaseHumanoid:MoveTo(wp.pos)
			steered = true
			break
		end
	end
	if not steered then
		chaseHumanoid:MoveTo(targetPos)
	end
end

-- One rival's life: a state machine that walks, grabs, carries home,
-- earns, and occasionally steals or chases.
-- One tick of a rival's behaviour (fix round 4, item 5): extracted
-- so runRival can pcall-guard it. The whole step used to run
-- unguarded inside runRival's loop, so any error (a nil getStatus,
-- a failed walkTo, a missing pad) froze that rival forever with no
-- log. Now a failed step warns and the rival keeps going next tick.
local function stepRival(rival: State.Rival, model: Model)
	task.wait(0.5)
	-- HUNT (follow-up, item 2): checked before the storm block, so
	-- a hunt can start in a storm — and once started it is
	-- storm-proof (phase "chase" is exempt from storm cover, like
	-- the carrier chase).
	tryStartHunt(rival, model)
	-- Storm cover (fix 2): when a storm runs, a rival runs home
	-- to its own base and waits there until the storm ends, then
	-- resumes. Bots that ignore the storm look dead; bots that
	-- run for cover look alive. A rival MID-CHASE or MID-STEAL
	-- does NOT run for cover (fix round 8, item 8): abandoning a
	-- chase the moment a storm starts reads as "the thief did
	-- nothing" — the chase outlives the storm.
	local StarfallService = require(script.Parent.StarfallService)
	if StarfallService.getStatus().phase == "storm" and rival.phase ~= "chase" and rival.phase ~= "steal" then
		local homeCf = WorldBuilder.baseCFrame(rival.baseId)
		if homeCf then
			walkTo(model, homeCf.Position, 30)
		end
		while StarfallService.getStatus().phase == "storm" do
			task.wait(1)
			if not model.Parent then
				return
			end
		end
		rival.phase = "idle"
	end
	-- Slap-back: a real player crowding the rival gets slapped.
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and time() >= rival.slapReadyAt then
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
			if playerRoot and (playerRoot.Position - root.Position).Magnitude <= 6 then
				rival.slapReadyAt = time() + Config.RIVAL_SLAP_COOLDOWN
				local SlapService = require(script.Parent.SlapService)
				SlapService.applySlapFromRival(rival, player)
				break
			end
		end
	end
	-- Chase speed (fix round 8, item 8): a chasing rival runs at
	-- RIVAL_CHASE_SPEED (19 — faster than a walking carrier at 16,
	-- slower than a sprint at 26), every other phase walks at 16.
	-- A HUNTING rival runs at RIVAL_HUNT_SPEED (22 — follow-up,
	-- item 2: faster than the carrier chase, slower than the
	-- guardian at 28-34). Synced every tick so the speed is right
	-- however the phase changed (chase start, tag, slap, storm
	-- cover, give-up).
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if rival.phase == "chase" and rival.chaseKind == "hunt" then Config.RIVAL_HUNT_SPEED
			elseif rival.phase == "chase" then Config.RIVAL_CHASE_SPEED
			else Config.RIVAL_WALK_SPEED
	end

	if rival.phase == "idle" then
		task.wait(math.random(1, 3))
		if rival.carried then
			rival.phase = "toBase"
		elseif math.random() < Config.RIVAL_STEAL_CHANCE then
			-- tryStartSteal picks the victim, raises the THIEF sign,
			-- warns the victim and logs the steal start — the same
			-- call the steal clock uses (fix round 7, item 2), so a
			-- steal started by either path is identical.
			tryStartSteal(rival, model)
		else
			rival.phase = "toCrater"
		end
	elseif rival.phase == "toCrater" then
		-- Walk in through the entrance gap (+Z side), then to a spot
		-- on the belt, then grab the RAREST free Rotling within
		-- reach. The old straight-line walk crossed the crater rim
		-- from whatever side the rival's base is on, so rivals pushed
		-- against the rim wall until the 30s timeout and never reached
		-- the belt — the leaderboard read $0 because no rival ever
		-- grabbed or placed. The gap route is the same path the
		-- crater raider uses (walk straight in, no rim climb).
		local spot = Vector3.new((math.random() * 2 - 1) * 20, Config.CRATER_FLOOR_Y, (math.random() * 2 - 1) * 2)
		local gap = Vector3.new(0, Config.CRATER_FLOOR_Y, 45)
		if walkAround(model, gap, 30, stormRunning) and walkTo(model, spot, 30, stormRunning) then
			-- Rarest first: the best Brainrot within reach, not the
			-- nearest Common. Highest rarity tier wins, cps breaks ties.
			local best: Model? = nil
			local bestTier = -1
			local bestCps = -1
			local bestDist = Config.RIVAL_GRAB_RADIUS
			for _, descendant in ipairs(workspace:GetDescendants()) do
				if descendant:IsA("Model") and descendant:GetAttribute("State") == "free" then
					local body = descendant.PrimaryPart
					if body then
						local dist = (body.Position - spot).Magnitude
						if dist < bestDist then
							local def = RotlingCatalog.getDef(descendant:GetAttribute("DefId") :: string)
							if def then
								local tier = RarityConfig.rarityTier(def.rarity)
								local cps = RotlingCatalog.baseCps(def, descendant:GetAttribute("Mutation") :: string?)
								if tier > bestTier or (tier == bestTier and cps > bestCps) then
									bestTier = tier
									bestCps = cps
									best = descendant
								end
							end
						end
					end
				end
			end
			if best then
				local def = RotlingCatalog.getDef(best:GetAttribute("DefId") :: string)
				carryModel(rival, best)
				-- The grab is visible: every player sees which rival
				-- took what, so the competition reads on screen.
				local rarity = if def then def.rarity else "Brainrot"
				local grabName = if def then def.name else "a Brainrot"
				for _, player in ipairs(Players:GetPlayers()) do
					Remotes.bannerEvent():FireClient(player, "🏆 " .. rival.name .. " grabbed a " .. string.upper(rarity) .. " " .. grabName .. "!", 3)
				end
				print("[Rival] " .. rival.name .. " grabbed " .. grabName .. " (" .. rarity .. ") from the crater — carrying it home")
				rival.phase = "toBase"
			else
				print("[Rival] " .. rival.name .. " reached the belt but found no free Brainrot within " .. tostring(Config.RIVAL_GRAB_RADIUS))
				task.wait(1)
				rival.phase = "idle"
			end
		else
			print("[Rival] " .. rival.name .. " could not reach the belt — going idle")
			rival.phase = "idle"
		end
	elseif rival.phase == "toBase" then
		local baseId = rival.baseId
		local padIndex = BaseService.freePad(baseId)
		if not padIndex then
			-- Base full: drop the catch back in the crater.
			RivalService.dropCarried(rival)
			rival.phase = "idle"
		else
			local padCf = WorldBuilder.padCFrame(baseId, padIndex)
			local homeCf = WorldBuilder.baseCFrame(baseId)
			-- Entrance leg (fix round 8, item 3): the straight line
			-- from the ring to the pad crosses the platform's
			-- 2-stud edge anywhere — usually NOT at the 6-wide
			-- entrance ramp — so the rival pushes against the edge
			-- until the walk times out. Route through the ramp's low
			-- end first (the only way up), then to the pad. Same
			-- geometry as the steal leg below.
			local entrancePos = if homeCf then (homeCf * CFrame.new(0, 0, -15)).Position else nil
			local rampTopPos = if homeCf then (homeCf * CFrame.new(0, 2, -10)).Position else nil
			local reachedPad = false
			if padCf and entrancePos then
				-- Ramp-top waypoint (fix round 9, item 3): same edge
				-- geometry as the steal leg — from the ramp's low end
				-- straight to the pad crosses the platform edge
				-- outside the ramp for pads 1 and 4.
				-- (fix round 13, item 1) Final leg via the clear
				-- strip, same as the steal leg: along the lane
				-- between the ramp top (local z -11) and the front
				-- pads (local z -7) at the pad's own local X, then
				-- straight to the pad — one pad crossing at most,
				-- never the diagonal across three pads + CollectPad.
				local stripPos: Vector3? = nil
				if homeCf and padCf then
					local localPad = homeCf:PointToObjectSpace(padCf.Position)
					stripPos = (homeCf * CFrame.new(localPad.X, 2, -9)).Position
				end
				reachedPad = walkAround(model, entrancePos, 40, stormRunning)
					and (not rampTopPos or walkTo(model, rampTopPos, 20, stormRunning))
					and (not stripPos or walkTo(model, stripPos, 20, stormRunning))
					and walkTo(model, padCf.Position, 40, stormRunning)
			elseif padCf then
				reachedPad = walkAround(model, padCf.Position, 40, stormRunning)
			end
			if padCf and reachedPad then
				local carried = rival.carried
				rival.carried = nil
				if carried then
					local body = carried.PrimaryPart
					if body then
						local weld = body:FindFirstChild("CarryWeld")
						if weld then
							weld:Destroy()
						end
					end
					-- Place it on the pad, rival-owned (players can
					-- steal it back: rival bases are never locked).
					local CarryService2 = require(script.Parent.CarryService)
					-- Place by hand: anchored, full size, on the pad.
					RotlingFactory.setCarriedVisual(carried, false)
					-- (fix round 9, item 5) normalize like a player
					-- placement — the old setModelScale(carried, 1)
					-- skipped the placed-size rule, so rival-placed
					-- Brainrots kept their build size and read
					-- uneven against player-placed ones.
					RotlingFactory.normalizeToHeight(carried, Config.PLACED_DISPLAY_HEIGHT)
					RotlingFactory.refreshLabelOffset(carried)
					local def = RotlingCatalog.getDef(carried:GetAttribute("DefId") :: string)
					local liftBody = carried.PrimaryPart
					local lift = if liftBody and liftBody:IsA("BasePart")
						then liftBody.Size.Y / 2 + 0.3 + (if def then def.size * 0.05 else 0.15)
						elseif def then def.size * 0.55 + 0.6
						else 2.5
					for _, part in ipairs(carried:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Anchored = true
						end
					end
					carried:PivotTo(padCf * CFrame.new(0, lift, 0))
					carried:SetAttribute("State", "placed")
					carried:SetAttribute("OwnerUserId", -rival.baseId)
					carried:SetAttribute("BaseId", baseId)
					carried:SetAttribute("PadIndex", padIndex)
					if not State.placed[baseId] then
						State.placed[baseId] = {}
					end
					State.placed[baseId][padIndex] = carried
					CarryService2.setPromptState(carried)
					RotlingFactory.setRestPose(carried)
					-- (fix round 6, item 3) The steal is only complete
					-- when the loot is placed and earning — log it, so
					-- the F9 trail reads triggered → walking →
					-- arrived → grabbed → running home → placed.
					print("[Rival] " .. rival.name .. " placed " .. (if def then def.name else "a Brainrot") .. " on its base — earning now")
					-- (fix round 9, item 3) STEAL COMPLETE: the steal
					-- is only PROVEN when the stolen Brainrot is
					-- placed and earning on the thief's base — this
					-- is the line Malek reads in F9 to know the thief
					-- actually did something this time.
					if rival.stolenName then
						print("[Rival] STEAL COMPLETE — " .. rival.name .. " stole " .. rival.stolenName .. " from " .. (rival.stolenFrom or "a player") .. " and placed it on its base — earning now")
						rival.stolenName = nil
						rival.stolenFrom = nil
					end
				end
			else
				print("[Rival] " .. rival.name .. " could not reach its own base (pad " .. tostring(padIndex) .. ") — still carrying, will retry next cycle")
				-- (fix round 13, item 1) Same diagnostic as the
				-- steal: name the leg + nearest solid in F9.
				if padCf then
					logWalkDiagnostic(rival, model, "toBase", padCf.Position)
				end
			end
			rival.phase = "idle"
		end
	elseif rival.phase == "steal" then
		local victim = if rival.targetUserId then Players:GetPlayerByUserId(rival.targetUserId) else nil
		local victimBase = rival.targetBase
		if not victim or not victimBase then
			print("[Rival] " .. rival.name .. " steal aborted — victim left")
			setThiefSign(model, false)
			rival.phase = "idle"
		elseif BaseService.isLocked(victimBase) then
			-- Locked mid-sneak: give up and go home. The victim sees
			-- the lock work instead of a thief that never arrives.
			print("[Rival] " .. rival.name .. " steal aborted — " .. victim.Name .. "'s base is locked")
			giveUpBanner(victim, rival.name, "your base is locked")
			setThiefSign(model, false)
			rival.phase = "toBase"
		else
			local placed = State.placed[victimBase]
			local padIndex: number? = nil
			if placed then
				for index in pairs(placed) do
					padIndex = index
					break
				end
			end
			if not padIndex then
				print("[Rival] " .. rival.name .. " steal aborted — nothing on " .. victim.Name .. "'s base to steal")
				giveUpBanner(victim, rival.name, "nothing to steal")
				setThiefSign(model, false)
				rival.phase = "idle"
			else
				local padCf = WorldBuilder.padCFrame(victimBase, padIndex)
				-- (fix round 6, item 3) Walk AROUND the crater, not
				-- through it. Bases sit on a circle around the crater,
				-- and a rival on the far side walks a straight line
				-- through the rim twice and pushes against the wall
				-- until the timeout — the sneak alert fires but the
				-- thief never arrives (Ziggy's base is directly
				-- opposite the player's, so its line goes straight
				-- through the crater centre). Leg 1 goes to open
				-- ground outside the rim at the victim base's angle
				-- (radius 45, the same approach the raider uses);
				-- leg 2 walks straight in to the pad.
				print("[Rival] " .. rival.name .. " walking to " .. victim.Name .. "'s base (pad " .. tostring(padIndex) .. ") — around the crater")
				local victimCf = WorldBuilder.baseCFrame(victimBase)
				local victimAngle = if victimCf then math.atan2(victimCf.Position.Z, victimCf.Position.X) else nil
				local arrived = false
				if padCf and victimAngle then
					local around = Vector3.new(math.cos(victimAngle) * 45, 0, math.sin(victimAngle) * 45)
					-- Entrance leg (fix round 8, item 3; rewritten fix
					-- round 9, item 3): three real causes of "the
					-- thief does nothing". (a) The walk passed
					-- stormRunning as the cancel, so any storm
					-- starting mid-walk (a 20-40s walk against an 8s
					-- storm every 90s cycle) aborted the steal — even
					-- though stepRival's header exempts steal/chase
					-- from storm cover. The steal walk is storm-proof
					-- now (nil cancel). (b) The final leg ran from
					-- the ramp's LOW end straight to the pad, crossing
					-- the 2-stud platform edge OUTSIDE the 6-wide
					-- ramp for pads 1 and 4 (crossing at x ≈ ±3.43)
					-- — the rival pushed the edge until the 40s
					-- timeout. Route UP the ramp first (ramp-top
					-- waypoint, local (0,2,-10)), then along the
					-- platform to the pad. (c) The pad picked at the
					-- start could empty during the walk — re-pick the
					-- first occupied pad on arrival instead of
					-- grabbing at an empty one.
					local entrancePos = if victimCf then (victimCf * CFrame.new(0, 0, -15)).Position else padCf.Position
					local rampTopPos = if victimCf then (victimCf * CFrame.new(0, 2, -10)).Position else nil
					-- (fix round 13, item 1) Per-leg tracking: the
					-- old `and`-chain knew the walk failed but not
					-- WHERE (ring? entrance? ramp? pad?) — so four
					-- rounds guessed at single parts. failedLeg names
					-- the leg for the diagnostic below.
					local failedLeg: string? = nil
					local reachedRamp = false
					if walkAround(model, around, 40, nil) then
						if walkTo(model, entrancePos, 20, nil) then
							if not rampTopPos or walkTo(model, rampTopPos, 20, nil) then
								reachedRamp = true
							else
								failedLeg = "ramp"
							end
						else
							failedLeg = "entrance"
						end
					else
						failedLeg = "ring"
					end
					if reachedRamp then
						local freshPad: number? = nil
						local freshPlaced = State.placed[victimBase]
						if freshPlaced then
							for index in pairs(freshPlaced) do
								freshPad = index
								break
							end
						end
						if freshPad then
							padIndex = freshPad
							padCf = WorldBuilder.padCFrame(victimBase, freshPad)
							-- (fix round 13, item 1) Final leg via
							-- the clear strip: the old diagonal from
							-- the ramp top straight to the pad crossed
							-- up to 3 intermediate pads plus the
							-- CollectPad (the trace: pad 6's line
							-- clips the CollectPad at 0.05 studs) —
							-- every crossing is a 0.6 ledge the rival
							-- must hop, and a hop that lands wrong
							-- stalls the walk. The strip is the clear
							-- lane between the ramp top (local z -11)
							-- and the front pads (local z -7): walk
							-- along it at the pad's own local X, then
							-- straight to the pad. A front-row pad
							-- needs no crossing at all; a back-row pad
							-- crosses exactly one front pad.
							local stripPos: Vector3? = nil
							if victimCf and padCf then
								local localPad = victimCf:PointToObjectSpace(padCf.Position)
								stripPos = (victimCf * CFrame.new(localPad.X, 2, -9)).Position
							end
							arrived = if padCf
								then (not stripPos or walkTo(model, stripPos, 20, nil)) and walkTo(model, padCf.Position, 40, nil)
								else false
							if not arrived then
								failedLeg = "pad"
							end
						else
							print("[Rival] " .. rival.name .. " reached " .. victim.Name .. "'s base but every pad emptied on the walk — steal aborted")
						end
					end
				elseif padCf then
					arrived = walkTo(model, padCf.Position, 60, nil)
				end
				if arrived then
					print("[Rival] " .. rival.name .. " arrived at " .. victim.Name .. "'s base")
					if BaseService.isLocked(victimBase) then
						print("[Rival] " .. rival.name .. " steal aborted — " .. victim.Name .. " locked the base mid-sneak")
						giveUpBanner(victim, rival.name, "your base is locked")
						setThiefSign(model, false)
						rival.phase = "toBase"
					else
						local stolen = BaseService.removePlaced(victimBase, padIndex)
						if stolen then
							carryModel(rival, stolen)
							local stolenDef = RotlingCatalog.getDef(stolen:GetAttribute("DefId") :: string)
							local stolenName = if stolenDef then stolenDef.name else "Brainrot"
							-- (fix round 9, item 3) remember what was
							-- stolen, so the placement logs STEAL
							-- COMPLETE — the proof the steal worked.
							rival.stolenName = stolenName
							rival.stolenFrom = victim.Name
							Remotes.bannerEvent():FireClient(victim, "🚨 " .. rival.name .. " stole your " .. stolenName .. "! Slap them to get it back!", 5)
							print("[Rival] " .. rival.name .. " stole " .. stolenName .. " from " .. victim.Name .. " — carrying it home")
							rival.phase = "toBase"
						else
							print("[Rival] " .. rival.name .. " steal aborted — the Brainrot was gone when it arrived")
							giveUpBanner(victim, rival.name, "nothing to steal")
							rival.phase = "idle"
						end
						setThiefSign(model, false)
					end
				else
					-- The walk failed: log it AND tell the victim, or
					-- the sneak alert reads as a false alarm. The log
					-- carries positions + the remaining distance, so
					-- the F9 trail shows WHERE the walk died (ring?
					-- entrance? pad?) instead of just "couldn't
					-- reach" (fix round 8, item 3).
					local rivalPos = if root then root.Position else Vector3.new(0, 0, 0)
					local padPos = if padCf then padCf.Position else Vector3.new(0, 0, 0)
					print("[Rival] " .. rival.name .. " could not reach " .. victim.Name .. "'s base (pad " .. tostring(padIndex) .. ") — steal aborted; rival at " .. tostring(rivalPos) .. ", pad at " .. tostring(padPos) .. ", " .. tostring(math.floor((rivalPos - padPos).Magnitude)) .. " studs short")
					-- (fix round 13, item 1) Name the blocker: the
					-- leg + the nearest solid part, in F9.
					logWalkDiagnostic(rival, model, failedLeg or "unknown", padPos)
					giveUpBanner(victim, rival.name, "couldn't reach your base")
					setThiefSign(model, false)
					rival.phase = "idle"
				end
			end
		end
	elseif rival.phase == "chase" then
		-- Two chases share this branch (follow-up, item 2):
		-- "carrier" — a carrier (egg or Brainrot). "THIEF ON YOUR
		-- TAIL!" with a live distance readout; a touch makes the
		-- carrier drop what they carry and the rival flees.
		-- "hunt" — a free-walking player, chased like the guardian
		-- chases: on the tag the thief steals the best carried
		-- Brainrot and runs home, or knocks the player flat if they
		-- carry nothing. The base interior ends the hunt, like the
		-- guardian giving up on the platform.
		local victim = if rival.targetUserId then Players:GetPlayerByUserId(rival.targetUserId) else nil
		local character = victim and victim.Character
		local victimRoot = character and character:FindFirstChild("HumanoidRootPart")
		local victimHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		local carryingEgg = victim and State.eggCarriedByUser[victim.UserId] ~= nil
		local carryingBrainrot = victim and State.brainrotCarriedByUser[victim.UserId] ~= nil
		local isHunt = rival.chaseKind == "hunt"
		if not victim or not victimRoot then
			print("[Rival] " .. rival.name .. " chase ended — " .. (if not victim then "victim left" else "victim has no root"))
			if isHunt then
				RivalService.clearThiefVisuals(rival)
			end
			rival.phase = "idle"
			rival.targetUserId = nil
		elseif isHunt then
			local victimBase = BaseService.getPlayerBase(victim.UserId)
			local dist = if root then (root.Position - victimRoot.Position).Magnitude else 999
			if not root then
				print("[Rival] " .. rival.name .. " hunt ended — rival has no root")
				RivalService.clearThiefVisuals(rival)
				rival.phase = "idle"
				rival.targetUserId = nil
			elseif victimBase and WorldBuilder.isOnBasePlatform(victimBase, victimRoot.Position) then
				-- Made it home: the hunt ends at the door, like the
				-- guardian giving up on the platform. (fix round 13,
				-- item 3: the refuge is the whole platform + ramp.)
				print("[Rival] " .. rival.name .. " hunt ended — " .. victim.Name .. " reached their base platform")
				RivalService.clearThiefVisuals(rival)
				rival.phase = "idle"
				rival.targetUserId = nil
			elseif dist > Config.RIVAL_HUNT_GIVEUP_DIST or time() - rival.huntStartedAt > Config.RIVAL_HUNT_TIMEOUT then
				print("[Rival] " .. rival.name .. " hunt ended — gave up (" .. tostring(math.floor(dist)) .. " studs, " .. tostring(math.floor(time() - rival.huntStartedAt)) .. "s)")
				RivalService.clearThiefVisuals(rival)
				rival.phase = "idle"
				rival.targetUserId = nil
			elseif dist <= 4 then
				-- THE TAG: steal what they carry, or knock them down.
				local carried = CarryService.getCarried(victim)
				local bestModel: Model? = nil
				local bestCps = -1
				for _, carriedModel in ipairs(carried) do
					local def = RotlingCatalog.getDef(carriedModel:GetAttribute("DefId") :: string)
					local cps = if def then RotlingCatalog.baseCps(def, carriedModel:GetAttribute("Mutation") :: string?) else 0
					if cps > bestCps then
						bestCps = cps
						bestModel = carriedModel
					end
				end
				if bestModel then
					-- Mug them: the best carried Brainrot goes home
					-- with the thief, and the placement logs STEAL
					-- COMPLETE like a base steal.
					local def = RotlingCatalog.getDef(bestModel:GetAttribute("DefId") :: string)
					local stolenName = if def then def.name else "Brainrot"
					CarryService.removeCarried(victim, bestModel)
					carryModel(rival, bestModel)
					rival.stolenName = stolenName
					rival.stolenFrom = victim.Name
					Remotes.bannerEvent():FireClient(victim, "🚨 " .. rival.name .. " stole your carried " .. stolenName .. "! Bonk them to get it back!", 5)
					print("[Rival] " .. rival.name .. " stole your carried " .. stolenName .. " from " .. victim.Name .. " — running home")
					RivalService.clearThiefVisuals(rival)
					rival.phase = "toBase"
					rival.targetUserId = nil
				elseif carryingEgg then
					-- An egg is dropped, not stolen: a rival has no
					-- incubator to hatch it in.
					local MeteorEggService = require(script.Parent.MeteorEggService)
					MeteorEggService.dropEgg(victim)
					Remotes.bannerEvent():FireClient(victim, "🚨 " .. rival.name .. " tagged you — you dropped the meteor egg!", 4)
					print("[Rival] " .. rival.name .. " tagged " .. victim.Name .. " — they dropped the meteor egg")
					RivalService.clearThiefVisuals(rival)
					rival.phase = "flee"
					rival.targetUserId = nil
				else
					-- Empty hands: knocked flat, briefly — the
					-- guardian's knockdown without the smash (no
					-- damage, nothing lost). A cooldown keeps the
					-- thief from chain-tagging the same player.
					if victimHumanoid and victimHumanoid.Health > 0 then
						victimHumanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
						victimRoot.AssemblyLinearVelocity = Vector3.new(0, 12, 0)
						if character then
							FeedbackService.burst(character, Color3.fromRGB(255, 60, 50))
						end
						FeedbackService.playSound(victim, 0.4, 1)
					end
					Remotes.bannerEvent():FireClient(victim, "🚨 " .. rival.name .. " knocked you down!", 4)
					print("[Rival] " .. rival.name .. " knocked " .. victim.Name .. " down (carrying nothing) — moving on")
					rival.huntReadyAt = time() + Config.RIVAL_HUNT_COOLDOWN
					RivalService.clearThiefVisuals(rival)
					rival.phase = "idle"
					rival.targetUserId = nil
				end
			else
				if math.random() < 0.5 then
					Remotes.bannerEvent():FireClient(victim, "🚨 " .. rival.name .. " is hunting you — " .. tostring(math.floor(dist)) .. " studs away, run!", 2)
				end
				if root then
					steerChase(rival, model, root, victimRoot)
				end
				task.wait(1)
			end
		elseif not carryingEgg and not carryingBrainrot then
			-- (fix round 12, item 3) The carrier chase gets the
			-- same safe-base end the hunt branch has: a carrier
			-- who makes it back onto their own base platform
			-- is home — the chase ends instead of piling rivals
			-- up at the gate while the player stands safe inside.
			-- (fix round 13, item 3: platform + ramp, not interior.)
			local victimBase = BaseService.getPlayerBase(victim.UserId)
			if victimBase and WorldBuilder.isOnBasePlatform(victimBase, victimRoot.Position) then
				print("[Rival] " .. rival.name .. " chase ended — " .. victim.Name .. " reached their base platform")
				rival.phase = "idle"
				rival.targetUserId = nil
			else
				print("[Rival] " .. rival.name .. " chase ended — victim stopped carrying")
				rival.phase = "idle"
				rival.targetUserId = nil
			end
		else
			local dist = (root.Position - victimRoot.Position).Magnitude
			if dist <= 4 then
				if carryingEgg then
					local MeteorEggService = require(script.Parent.MeteorEggService)
					MeteorEggService.dropEgg(victim)
					Remotes.bannerEvent():FireClient(victim, "🚨 " .. rival.name .. " tagged you — you dropped the meteor egg!", 4)
				else
					CarryService.dropAllCarried(victim)
					Remotes.bannerEvent():FireClient(victim, "🚨 " .. rival.name .. " tagged you — you dropped your Brainrots!", 4)
				end
				print("[Rival] " .. rival.name .. " tagged " .. victim.Name .. " — they dropped everything")
				rival.phase = "flee"
				rival.targetUserId = nil
			else
				if math.random() < 0.5 then
					Remotes.bannerEvent():FireClient(victim, "🚨 THIEF ON YOUR TAIL! " .. rival.name .. " is " .. tostring(math.floor(dist)) .. " studs behind you — sprint home!", 2)
				end
				if root then
					steerChase(rival, model, root, victimRoot)
				end
				task.wait(1)
			end
		end
	elseif rival.phase == "flee" then
		local angle = math.random() * math.pi * 2
		local exit = Vector3.new(math.cos(angle) * (Config.CRATER_RADIUS + 30), 0, math.sin(angle) * (Config.CRATER_RADIUS + 30))
		walkTo(model, exit, 30)
		rival.phase = "idle"
	else
		rival.phase = "idle"
	end
end

-- The rival's loop (fix round 4, item 5): every tick is pcall-guarded,
-- so an error in one step warns and the rival keeps going next tick
-- instead of freezing forever with no log.
local function runRival(rival: State.Rival)
	local model = rival.model
	while model.Parent do
		task.wait(0.5)
		local ok, err = pcall(stepRival, rival, model)
		if not ok then
			warn("[Rival] " .. rival.name .. " step failed: " .. tostring(err) .. " — continuing next tick")
		end
	end
end

-- Rivals earn like players: every second, each rival's placed Rotlings
-- pay their income into the rival's coins (the leaderboard shows it).
local function earningsLoop()
	while true do
		task.wait(1)
		for _, rival in pairs(State.rivals) do
			local total = 0
			for _, placed in pairs(State.placed[rival.baseId] or {}) do
				local def = RotlingCatalog.getDef(placed:GetAttribute("DefId") :: string)
				if def then
					total += RotlingCatalog.baseCps(def, placed:GetAttribute("Mutation") :: string?)
				end
			end
			rival.coins += total
		end
	end
end

-- Coins survive a knock-out: a rival that dies to a meteor keeps its
-- earnings and resumes from them when it respawns.
local savedCoins: { [number]: number } = {}

-- Spawn (or respawn) one rival: a fresh model + record on its base.
-- The base itself (owner, pads, placed Rotlings, lock) is set up once
-- in start() and is NOT reset here, so a respawned rival keeps its
-- placed Rotlings and its coins.
local function spawnRival(index: number)
	local baseId = 4 + index
	local name = Config.RIVAL_NAMES[index]
	local color = RIVAL_COLORS[index]
	local cf = WorldBuilder.baseCFrame(baseId)
	local spawnPos = if cf then cf.Position + Vector3.new(0, 0, 0) else Vector3.new(0, 0, 0)
	local model = buildRival(name, color, spawnPos)
	model.Parent = workspace
	local rival: State.Rival = {
		model = model,
		name = name,
		baseId = baseId,
		phase = "idle",
		carried = nil,
		coins = savedCoins[index] or 0,
		slapReadyAt = 0,
		targetUserId = nil,
		targetBase = nil,
		lastThiefBannerAt = 0,
		bornAt = time(),
		stolenName = nil,
		stolenFrom = nil,
		chaseWaypoints = {},
		chaseWpIndex = 1,
		chasePathTarget = nil,
		chaseRepathAt = 0,
		chaseKind = nil,
		huntReadyAt = 0,
		huntStartedAt = 0,
	}
	State.rivals[model] = rival
	-- Knocked out: a meteor (or anything else) that kills the rival
	-- drops what it carries, banks its coins, and brings it back
	-- after 15s — a dead rival that never returns is a rival the
	-- player never competes with again.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if State.rivals[model] == nil then
				return
			end
			RivalService.dropCarried(rival)
			savedCoins[index] = rival.coins
			State.rivals[model] = nil
			print("[Rival] " .. rival.name .. " was knocked out! Respawning in 15s (coins kept: " .. tostring(math.floor(rival.coins)) .. ")")
			task.delay(2, function()
				if model.Parent then
					model:Destroy()
				end
			end)
			task.delay(15, function()
				spawnRival(index)
			end)
		end)
	end
	task.spawn(runRival, rival)
end

function RivalService.start()
	if running then
		return
	end
	running = true
	-- Claim bases 5-8 for the rivals (negative owner ids reserve them:
	-- a joining player never collides with a rival's base).
	for i = 1, Config.RIVAL_COUNT do
		local baseId = 4 + i
		local name = Config.RIVAL_NAMES[i]
		local color = RIVAL_COLORS[i]
		State.baseOwner[baseId] = -i
		State.playerBase[-i] = baseId
		State.placed[baseId] = {}
		State.locks[baseId] = { lockedUntil = 0, cooldownUntil = 0, gateShown = false }
		State.lockdowns[baseId] = { endsAt = 0, cooldownUntil = 0, gateShown = false }
		State.unlockedPads[baseId] = Config.PADS_OPEN
		WorldBuilder.setBaseSign(baseId, name .. "'s Base")
		WorldBuilder.setBaseCoins(baseId, 0)
		spawnRival(i)
	end
	task.spawn(earningsLoop)
	task.spawn(function()
		-- Thief-in-base watcher (fix round 7, item 7): a stealing
		-- rival must be UNMISSABLE while it is inside the victim's
		-- base. Every second, any rival in the steal phase that is
		-- inside its victim's base re-banners the victim ("🚨 NAME
		-- is IN your base — bonk them!") at most once per 3s — so
		-- the player is told, repeatedly, while the thief is there.
		-- (The red Highlight from setThiefSign makes the thief
		-- visible through walls; the banner tells the player to look.)
		while true do
			task.wait(1)
			for _, rival in pairs(State.rivals) do
				if rival.phase == "steal" and rival.targetUserId and rival.targetBase then
					local victim = Players:GetPlayerByUserId(rival.targetUserId)
					local victimCf = WorldBuilder.baseCFrame(rival.targetBase)
					local root = rival.model:FindFirstChild("HumanoidRootPart")
					if victim and victimCf and root then
						local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(victimCf.Position.X, 0, victimCf.Position.Z)).Magnitude
						if dist <= 20 and time() - rival.lastThiefBannerAt >= 3 then
							rival.lastThiefBannerAt = time()
							Remotes.bannerEvent():FireClient(victim, "🚨 " .. rival.name .. " is IN your base — bonk them!", 3)
							-- (fix round 9, item 9) re-fire the danger
							-- alert with every repeat banner, so the
							-- vignette + flashing text + alarm stay
							-- live the whole time the thief is inside.
							Remotes.thiefAlertEvent():FireClient(victim, rival.name)
						end
					end
				end
			end
		end
	end)
	task.spawn(function()
		-- Base-grab heat watcher (fix round 12, item 3): a player
		-- who picks a Brainrot up inside their OWN base arms the
		-- heat (State.baseHeat, set in carryRotling) instead of
		-- unleashing it — the chase must not spawn and instantly
		-- despawn on a safe base, and it must not punish standing
		-- in your own base. Every 0.5s, any armed carrier who has
		-- stepped OUTSIDE their own base interior engages: the
		-- Guardian wakes (onGrab) and the nearest rivals give
		-- chase (notifyBrainrotCarrier). Engages once per carry —
		-- the isChasing guards keep it from re-firing every tick
		-- while the carrier is out. The flag clears when the
		-- player stops carrying (removeCarried, or here), and it
		-- stays set while carrying, so re-exiting the base after
		-- a safe return re-engages the heat.
		while true do
			task.wait(0.5)
			for userId, _ in pairs(State.baseHeat) do
				local player = Players:GetPlayerByUserId(userId)
				local carried = player and CarryService.getCarried(player)
				if not player or not carried or #carried == 0 then
					State.baseHeat[userId] = nil
				else
					local baseId = BaseService.getPlayerBase(userId)
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if baseId and root and not WorldBuilder.isOnBasePlatform(baseId, root.Position) then
						-- (fix round 13, item 3) The heat engages
						-- the moment the carrier steps OFF the
						-- platform + ramp — the ramp is part of the
						-- base, so carrying down the ramp is still
						-- safe; stepping onto the ground is not.
						local GuardianService = require(script.Parent.GuardianService)
						if not GuardianService.isChasing(player) and not RivalService.isChasingPlayer(userId) then
							print("[Heat] " .. player.Name .. " left their base carrying — heat engages")
							GuardianService.onGrab(player, carried[1])
							RivalService.notifyBrainrotCarrier(player)
						end
					end
				end
			end
		end
	end)
	task.spawn(function()
		-- Steal clock (fix round 7, item 2): the 0.35 idle roll plus a
		-- 60-90s rival cycle made steals too rare to ever see — about
		-- one attempt per rival every 2-3 minutes, only if the player
		-- had placed Rotlings. Every 75s, force the idlest rival to
		-- attempt a steal if any victim exists, so a steal is
		-- guaranteed on a regular beat instead of left to the roll.
		-- A steal still needs a victim with Rotlings on an unlocked
		-- base; with no victim the clock just waits for the next beat.
		while true do
			task.wait(75)
			local best: State.Rival? = nil
			for _, rival in pairs(State.rivals) do
				if rival.phase == "idle" and not rival.carried then
					best = rival
					break
				end
			end
			if best then
				local model = best.model
				if model then
					if tryStartSteal(best, model) then
						print("[Rival] steal clock — forced a steal for " .. best.name)
					else
						print("[Rival] steal clock — no victim (no placed Brainrots on an unlocked base)")
					end
				end
			end
		end
	end)
	print("[RivalService] " .. tostring(Config.RIVAL_COUNT) .. " rivals live on bases 5-8.")
end

return RivalService
