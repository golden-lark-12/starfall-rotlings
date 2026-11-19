--!strict
-- Starfall Rotlings: the Crater Guardian (THE CHASE — the core of the game).
-- When anyone grabs a Brainrot from the crater, a space rock monster
-- (glowing red eyes) climbs out and chases them. Rarer Brainrot =
-- faster guardian: CAT-FAST at every tier (Common 28 to Cosmic 34),
-- faster than a sprint, so a walking player cannot outrun it and even
-- a sprinter only escapes by reaching the base. If it catches you, it
-- SMASHES you: 40 HP damage + knocked down + you drop the Brainrot
-- back — two catches kill you, so a catch is a real threat, not a
-- free reset. Reach your base interior and it gives up. The chase is
-- NOT bounded to the crater: it follows the target anywhere on the
-- map — the only approved stops are the base interior, the dropped
-- carry, and the 25s timeout.
-- Raider bots also grab from the crater, so the guardian chases them
-- too — and a player can slap/bonk a raider to steal its Brainrot.
-- The Cosmic Corn Dog is the final index entry: rarest spawn, and the
-- fastest guardian in the game chases whoever grabs it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local FeedbackService = require(script.Parent.FeedbackService)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local GuardianService = {}

local ROAR_SOUND = "rbxasset://sounds/electronicpingshort.wav"

-- Active guardians, keyed by their Model.
type Guardian = {
	model: Model,
	target: Model,
	targetPlayer: Player?,
	speed: number,
	bornAt: number,
	-- Chase telemetry: the proof the chase is real — total distance
	-- actually moved, closest approach, farthest radius reached (did
	-- it leave the crater?), and whether it ever got out of the
	-- crater at all. The despawn summary prints these.
	totalMoved: number,
	minDist: number,
	maxRadius: number,
	leftCrater: boolean,
}
local active: { [Model]: Guardian } = {}
-- Players currently being chased (for the HUD red-edge warning).
local chasedPlayers: { [number]: boolean } = {}

-- Is a guardian currently chasing this player? Read by broadcastHud
-- so the client can flash the red edges while the chase is on.
function GuardianService.isChasing(player: Player): boolean
	return chasedPlayers[player.UserId] == true
end

local function speedForRarity(rarity: string): number
	local tier = RarityConfig.rarityTier(rarity)
	return Config.GUARDIAN_SPEED[tier] or Config.GUARDIAN_SPEED[1]
end

-- Is this position on the target player's own base PLATFORM (a safe
-- zone)? The whole platform + ramp (fix round 13, item 3 — Malek:
-- "ZERO damage on my base, at all", reversing the round-9
-- interior-only rule). The guardian gives up once the player is
-- actually ON the base — slab or ramp — not only once they are
-- inside the walls.
local function onOwnBase(player: Player, position: Vector3): boolean
	local baseId = BaseService.getPlayerBase(player.UserId)
	if not baseId then
		return false
	end
	return WorldBuilder.isOnBasePlatform(baseId, position)
end

local function makePart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = 0
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	return part
end

-- Build the guardian: a hunched rock golem with glowing cracks.
-- Built from parts only (no meshes, no uploads), like every Rotling.
-- THE LOOK: the old guardian was a smooth ball with flat grey slabs —
-- Malek asked for a creature. Now it has a head jutting forward low
-- on the chest (the hunch), a heavy brow over glowing red eyes,
-- boulder shoulders, long arms with fists, stomp feet, and Neon magma
-- cracks instead of grey slabs. The body ball itself is UNCHANGED
-- (size + centre are the locomotion the chase was tuned on);
-- everything new is decorative and welded to it.
local function buildGuardian(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Crater Guardian"

	-- The rock: big, dark, rough.
	local body = makePart("Body", Enum.PartType.Ball, Vector3.new(5.5, 5, 5.5), Color3.fromRGB(45, 38, 48), Enum.Material.Slate)
	body.CFrame = CFrame.new(position + Vector3.new(0, 3.2, 0))
	body.CanCollide = true
	body.Parent = model
	model.PrimaryPart = body

	-- Head: a smaller rock ball mounted low and forward — the hunch.
	local head = makePart("Head", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), Color3.fromRGB(38, 32, 42), Enum.Material.Slate)
	head.CFrame = body.CFrame * CFrame.new(0, 1.2, 2.2)
	head.Parent = model
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.Parent = head

	-- Heavy brow slab over the eyes, tilted down — the menace.
	local brow = makePart("Brow", Enum.PartType.Block, Vector3.new(3.0, 0.9, 1.0), Color3.fromRGB(30, 25, 35), Enum.Material.Slate)
	brow.CFrame = body.CFrame * CFrame.new(0, 2.0, 3.0) * CFrame.Angles(math.rad(-15), 0, 0)
	brow.Parent = model
	local browWeld = Instance.new("WeldConstraint")
	browWeld.Part0 = body
	browWeld.Part1 = brow
	browWeld.Parent = brow

	-- Glowing red eyes, deep under the brow on the head's front.
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Eye", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
		eye.CFrame = body.CFrame * CFrame.new(side * 0.65, 1.4, 3.4)
		eye.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	-- Glowing cracks: thin Neon magma bars wedged into the torso and
	-- head at angles, replacing the old flat grey slabs.
	local cracks: { { pos: Vector3, len: number, rot: number } } = {
		{ pos = Vector3.new(0, -0.4, 2.6), len = 2.8, rot = 10 },
		{ pos = Vector3.new(-1.7, 0.9, 2.3), len = 1.8, rot = -35 },
		{ pos = Vector3.new(1.8, -0.2, 2.3), len = 2.0, rot = 30 },
		{ pos = Vector3.new(-0.6, -1.6, 2.4), len = 1.4, rot = 55 },
		{ pos = Vector3.new(0.9, 1.8, 3.3), len = 1.2, rot = -20 },
	}
	for _, c in ipairs(cracks) do
		local crack = makePart("GlowCrack", Enum.PartType.Block, Vector3.new(0.35, c.len, 0.35), Color3.fromRGB(255, 80, 30), Enum.Material.Neon)
		crack.CFrame = body.CFrame * CFrame.new(c.pos) * CFrame.Angles(0, 0, math.rad(c.rot))
		crack.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = crack
		weld.Parent = crack
	end

	-- Boulder shoulders.
	for _, side in ipairs({ -1, 1 }) do
		local shoulder = makePart("Shoulder", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), Color3.fromRGB(40, 34, 44), Enum.Material.Slate)
		shoulder.CFrame = body.CFrame * CFrame.new(side * 2.6, 1.6, 0)
		shoulder.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = shoulder
		weld.Parent = shoulder
	end

	-- Long arms hanging from the shoulders, fists at the ends.
	for _, side in ipairs({ -1, 1 }) do
		local arm = makePart("Arm", Enum.PartType.Block, Vector3.new(1.5, 3.4, 1.5), Color3.fromRGB(42, 36, 46), Enum.Material.Slate)
		arm.CFrame = body.CFrame * CFrame.new(side * 2.9, -0.6, 0.3) * CFrame.Angles(0, 0, math.rad(-side * 8))
		arm.Parent = model
		local armWeld = Instance.new("WeldConstraint")
		armWeld.Part0 = body
		armWeld.Part1 = arm
		armWeld.Parent = arm
		local fist = makePart("Fist", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(38, 32, 42), Enum.Material.Slate)
		fist.CFrame = body.CFrame * CFrame.new(side * 3.0, -2.2, 0.3)
		fist.Parent = model
		local fistWeld = Instance.new("WeldConstraint")
		fistWeld.Part0 = body
		fistWeld.Part1 = fist
		fistWeld.Parent = fist
	end

	-- Stomp feet, so it stands on the ground instead of floating.
	for _, side in ipairs({ -1, 1 }) do
		local foot = makePart("Foot", Enum.PartType.Block, Vector3.new(2.2, 1.0, 2.6), Color3.fromRGB(35, 30, 40), Enum.Material.Slate)
		foot.CFrame = body.CFrame * CFrame.new(side * 1.4, -2.7, 0.3)
		foot.Parent = model
		local footWeld = Instance.new("WeldConstraint")
		footWeld.Part0 = body
		footWeld.Part1 = foot
		footWeld.Parent = foot
	end

	-- Red light so the cracks and eyes glow in the dark.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Brightness = 2
	light.Range = 12
	light.Parent = body

	-- A red tag so the chase reads from across the crater. Raised:
	-- the shoulders now top out higher than the old ball.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GuardianTag"
	billboard.Size = UDim2.fromOffset(220, 36)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6.8, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 60
	billboard.Parent = body
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(1, 0, 1, 0)
	tag.BackgroundTransparency = 1
	tag.Text = "🪨 CRATER GUARDIAN"
	tag.Font = Enum.Font.FredokaOne
	tag.TextScaled = true
	tag.TextColor3 = Color3.fromRGB(255, 60, 50)
	tag.TextStrokeTransparency = 0.3
	tag.Parent = billboard

	-- A humanoid so it can walk with MoveTo (same pattern as raiders).
	-- HipHeight MUST match the build: the root sits at the body
	-- ball's centre, 3.2 studs above the floor (the ball is 5 tall,
	-- centred at +3.2). The default HipHeight 2 made the Humanoid
	-- push the whole model down into the floor while it walked —
	-- part of the jerky "in blocks" motion.
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = Config.GUARDIAN_SPEED[1]
	humanoid.HipHeight = 3.2
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

-- A deep roar: the built-in ping pitched right down, loud.
local function playRoar(at: Vector3)
	local sound = Instance.new("Sound")
	sound.SoundId = ROAR_SOUND
	sound.Volume = 1
	-- (fix round 7, item 4) 0.15 was an extremely low drone phone
	-- speakers cannot reproduce — the guardian roared silently.
	-- 0.4 is still deep, but audible.
	sound.PlaybackSpeed = 0.4
	sound.Parent = workspace
	sound:Play()
	task.delay(2.5, function()
		sound:Destroy()
	end)
end

function GuardianService.despawnGuardian(model: Model, reason: string?)
	local guardian = active[model]
	if not guardian then
		return
	end
	active[model] = nil
	if guardian.targetPlayer then
		chasedPlayers[guardian.targetPlayer.UserId] = nil
	end
	local targetName = if guardian.targetPlayer then guardian.targetPlayer.Name else "raider"
	local lived = math.max(0.1, time() - guardian.bornAt)
	local avgSpeed = guardian.totalMoved / lived
	-- Chase summary: the proof, in one line — how long it chased,
	-- how close it got, its average REAL speed (not WalkSpeed), and
	-- whether it ever left the crater. If the average real speed is
	-- under 26, the chase is broken no matter what Config says; if
	-- max radius stayed under 40, it never left the crater.
	print("[Guardian] chase summary — " .. tostring(reason or "?") .. " — chased " .. targetName .. " for " .. tostring(math.floor(lived)) .. "s, min distance " .. string.format("%.1f", guardian.minDist) .. " studs, avg real speed " .. string.format("%.1f", avgSpeed) .. " studs/s, max radius " .. string.format("%.0f", guardian.maxRadius) .. " (left crater: " .. tostring(guardian.leftCrater) .. ")")
	model:Destroy()
end

-- The knockdown: the guardian caught a player. It SMASHES them — 40 HP
-- damage, knocked flat, everything carried drops back into the crater —
-- then the guardian leaves. Two catches kill (100 HP), so a catch is a
-- real threat, not a free reset: the old catch only dropped the
-- Brainrot and Malek read it as harmless.
local function catchPlayer(guardian: Model, player: Player)
	-- ZERO damage on your own base, at all. The Touch-catch handler
	-- fires the moment the guardian's body touches the target, with
	-- no own-base check — a guardian chasing you to the door could
	-- touch-catch you while you stood on the platform edge, even
	-- though the chaseLoop gives up first. So the gate lives HERE,
	-- in the catch itself: on your own base platform the catch never
	-- lands — no damage, no knockdown, no dropped Brainrot — the
	-- guardian just leaves. (The distance catch in the chaseLoop is
	-- already gated by the give-up check above it; this gate covers
	-- the Touch path, which bypasses the loop entirely.)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and onOwnBase(player, root.Position) then
		Remotes.bannerEvent():FireClient(player, "🛡 Safe on your base! The Guardian gives up and sinks back into the crater.", 3)
		print("[Guardian] catch refused — " .. player.Name .. " is on their own base platform")
		GuardianService.despawnGuardian(guardian, "safe-base")
		return
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		if root then
			root.AssemblyLinearVelocity = Vector3.new(0, 12, 0)
		end
		-- THE CATCH HURTS: 40 damage + knocked down + everything
		-- carried drops back into the crater. The guardian is a
		-- threat, not a pet.
		humanoid:TakeDamage(Config.GUARDIAN_CATCH_DAMAGE)
		FeedbackService.burst(character, Color3.fromRGB(255, 60, 50))
		FeedbackService.playSound(player, 0.4, 1)
		local dropped = #CarryService.getCarried(player)
		CarryService.dropAllCarried(player)
		Remotes.bannerEvent():FireClient(player, "🪨 THE GUARDIAN SMASHED YOU! -" .. tostring(Config.GUARDIAN_CATCH_DAMAGE) .. " HP — you dropped your Brainrot!", 4)
		print("[Guardian] caught " .. player.Name .. " — smashed for " .. tostring(Config.GUARDIAN_CATCH_DAMAGE) .. " HP (now " .. tostring(math.floor(humanoid.Health)) .. " HP), knocked down, dropped " .. tostring(dropped) .. " Brainrot(s)")
	end
	GuardianService.despawnGuardian(guardian, "caught-player")
end

-- The guardian caught a raider: bonk it (it drops the Brainrot it
-- grabbed and flees), then the guardian leaves.
local function catchRaider(guardian: Model, raiderModel: Model)
	local RaiderService = require(script.Parent.RaiderService)
	RaiderService.bonkRaider(raiderModel, nil)
	GuardianService.despawnGuardian(guardian, "caught-raider")
end

-- Chase loop: steer DIRECTLY at the target's live position, every
-- 0.1s tick — so the guardian flows continuously instead of hopping
-- in blocks.
-- Ends on catch, on give-up (safe base / nothing carried / timeout),
-- or when the target is gone. The chase is NOT bounded to the crater:
-- it follows the target anywhere on the map — the only approved
-- stops are the base interior, the dropped carry, and the 25s timeout.
-- WHY IT STILL READ SLOW (fix round 9, item 1) — three causes, all
-- proven from the old code: (1) the chase steered on a PATHFINDER
-- route that detoured through the crater's entrance gap (+Z), so the
-- guardian's route was far longer than the player's straight line
-- home — at WalkSpeed 19-24 along a 2x detour, its closing speed was
-- ~10-12, BELOW a walk (16); (2) the loop re-pathed every 1.5s and
-- re-issued MoveTo to a new first waypoint each time, so the heading
-- snapped on every repath — the jerky "in blocks" motion; (3) the
-- give-up fired at the base DOOR (radius 17), so the guardian quit
-- ~15 studs before the player was even on the platform. The fix:
-- direct steering (MoveTo at the live target, no pathfinding at
-- all — the crater floor and the open field have nothing to route
-- around, and the rim tiers are jumpable), a fast stuck-hop (0.8s,
-- not 3s) that jumps the tiers, CAT-FAST speeds (28-34, every tier
-- beats sprint 26), and a lunge inside 14 studs (+12 speed burst +
-- jump, every 4s). The climb-out teleport stays as the last resort
-- if direct steering ever stalls for a full 3s.
local function chaseLoop(guardian: Model)
	local entry = active[guardian]
	if not entry then
		return
	end
	local humanoid = guardian:FindFirstChildOfClass("Humanoid")
	local root = guardian:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		GuardianService.despawnGuardian(guardian, "no-humanoid")
		return
	end
	local lastChasePos = root.Position
	local noProgressTime = 0
	-- Chase telemetry: the guardian's speed is a NUMBER, not a
	-- feeling — every 2s the loop logs the real studs/s the guardian
	-- actually moved (not its WalkSpeed, which is what it is TOLD to
	-- move at) plus the distance to the target. That is the proof the
	-- speed fix works: a real speed above 26 means it gains even on a
	-- sprinter, and the distance should shrink tick by tick. Malek
	-- reads it in F9. The per-chase totals feed the despawn summary.
	local lastTelemetryAt = time()
	local lastTelemetryPos = root.Position
	local lastLungeAt = 0
	local lungeUntil = 0
	while guardian.Parent and active[guardian] do
		local target = entry.target
		local targetRoot = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
		if not targetRoot or not target.Parent then
			GuardianService.despawnGuardian(guardian, "target-gone")
			return
		end
		-- Give up: the target reached safety.
		if entry.targetPlayer then
			local character = entry.targetPlayer.Character
			local tRoot = character and character:FindFirstChild("HumanoidRootPart")
			if tRoot and onOwnBase(entry.targetPlayer, tRoot.Position) then
				Remotes.bannerEvent():FireClient(entry.targetPlayer, "🛡 Safe! The Guardian gives up and sinks back into the crater.", 3)
				GuardianService.despawnGuardian(guardian, "safe-base")
				return
			end
			-- Nothing carried anymore (placed, sold or dropped)? Nothing to chase.
			if #CarryService.getCarried(entry.targetPlayer) == 0 then
				GuardianService.despawnGuardian(guardian, "dropped")
				return
			end
		else
			-- Raider target: if it is no longer carrying (bonked), give up.
			local raider = State.raiders[target]
			if not raider or not raider.stolen then
				GuardianService.despawnGuardian(guardian, "dropped")
				return
			end
		end
		-- Caught? Checked every 0.1s tick, so a fast guardian cannot
		-- step over the catch radius between ticks.
		local distToTarget = (root.Position - targetRoot.Position).Magnitude
		if distToTarget <= Config.GUARDIAN_CATCH_RADIUS then
			if entry.targetPlayer then
				catchPlayer(guardian, entry.targetPlayer)
			else
				catchRaider(guardian, target)
			end
			return
		end
		-- Track the chase totals for the despawn summary.
		entry.minDist = math.min(entry.minDist, distToTarget)
		local guardianRadius = Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude
		entry.maxRadius = math.max(entry.maxRadius, guardianRadius)
		if not entry.leftCrater and guardianRadius > Config.CRATER_RADIUS + 12 then
			entry.leftCrater = true
			print("[Guardian] LEFT THE CRATER — chasing at radius " .. string.format("%.0f", guardianRadius) .. ", target " .. string.format("%.0f", distToTarget) .. " studs away")
		end
		-- Lunge: inside 14 studs, the guardian pounces — +12 speed
		-- for 0.6s plus a jump toward the target, at most once every
		-- 4s. The pounce is what makes a close guardian feel like a
		-- cat, not a rolling rock.
		local now = time()
		if distToTarget <= Config.GUARDIAN_LUNGE_RANGE and now - lastLungeAt >= Config.GUARDIAN_LUNGE_COOLDOWN then
			lastLungeAt = now
			lungeUntil = now + 0.6
			humanoid.Jump = true
			print("[Guardian] LUNGE at " .. string.format("%.1f", distToTarget) .. " studs!")
		end
		if now < lungeUntil then
			humanoid.WalkSpeed = entry.speed + Config.GUARDIAN_LUNGE_BONUS
		else
			humanoid.WalkSpeed = entry.speed
		end
		-- Steer: DIRECTLY at the target's live position, every tick.
		-- No pathfinding, no waypoints, no repaths — the heading
		-- never snaps, so the motion is smooth and continuous, and
		-- the guardian's full speed goes toward closing the distance
		-- instead of along a detour. The rim tiers (2.5 / 4 / 5.5
		-- studs) are cleared by the stuck-hop below, and the 3s
		-- climb-out is the last resort if steering ever stalls.
		humanoid:MoveTo(targetRoot.Position)
		task.wait(0.1)
		if not guardian.Parent then
			return
		end
		-- Stuck? Hop — fast (0.8s, not 3s): MoveTo never jumps, so a
		-- guardian pushing against a rim tier or the belt edge hops
		-- over it instead of grinding there. The jump clears up to
		-- ~7 studs; the tallest rim tier is 5.5.
		if (root.Position - lastChasePos).Magnitude < 0.5 then
			noProgressTime += 0.1
			if noProgressTime >= 0.8 and noProgressTime < 3 then
				humanoid.Jump = true
				noProgressTime = 0
			elseif noProgressTime >= 3 then
				local flat = Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z)
				local dir = if flat.Magnitude > 1 then flat.Unit else Vector3.new(1, 0, 0)
				local outPos = dir * (Config.CRATER_RADIUS + 14)
				guardian:PivotTo(CFrame.new(Vector3.new(outPos.X, 3.2, outPos.Z)))
				print("[Guardian] climbed out of the crater (stuck " .. tostring(noProgressTime) .. "s) — chasing from the rim")
				noProgressTime = 0
				lastChasePos = root.Position
			end
		else
			noProgressTime = 0
			lastChasePos = root.Position
		end
		-- Telemetry: real speed over the last sample, so a slow
		-- guardian cannot hide behind its WalkSpeed setting — if this
		-- number is under 26, the chase is broken no matter what
		-- Config says. The distance should shrink every sample while
		-- the target runs.
		local telemetryNow = time()
		if telemetryNow - lastTelemetryAt >= 2 then
			local moved = (root.Position - lastTelemetryPos).Magnitude
			local realSpeed = moved / math.max(0.1, telemetryNow - lastTelemetryAt)
			entry.totalMoved += moved
			local distNow = (root.Position - targetRoot.Position).Magnitude
			print("[Guardian] chase telemetry — real speed " .. string.format("%.1f", realSpeed) .. " studs/s (WalkSpeed " .. tostring(entry.speed) .. "), distance to target " .. string.format("%.1f", distNow) .. " studs")
			lastTelemetryAt = telemetryNow
			lastTelemetryPos = root.Position
		end
		if time() - entry.bornAt > Config.GUARDIAN_GIVEUP_TIME then
			GuardianService.despawnGuardian(guardian, "timeout")
			return
		end
	end
end

-- Spawn a guardian at the crater floor and start the chase.
-- `rarity` is the grabbed Brainrot's rarity: it sets the speed.
-- Where it spawns: at the crater rim OPPOSITE the target, never on
-- top of them. The old code spawned it at the target's exact position
-- (same X/Z, Y = CRATER_FLOOR_Y), so the guardian's root landed ~0
-- studs from the player's root — inside the 5-stud catch radius on
-- the FIRST chase tick. Every grab was caught instantly, the Brainrot
-- dropped straight back into the crater, and pressing E read as "does
-- nothing". A rim spawn is always >= 14 studs away
-- (Config.GUARDIAN_SPAWN_DISTANCE), so the player gets a real head
-- start to run home — and the escape is the base interior (or the 25s
-- timeout): even the SLOWEST guardian (Common 28) gains 12 studs/s
-- on a walker at 16, so it closes on a straight-line runner in ~2s;
-- a sprinter (26) is still slower than the guardian, so sprinting
-- only buys time to reach the base — full Speed Boots (walk 26,
-- sprint 36) are the outrun answer.
local function guardianSpawnPos(targetPos: Vector3): Vector3
	local flat = Vector3.new(targetPos.X, 0, targetPos.Z)
	local dir: Vector3
	if flat.Magnitude > 1 then
		dir = -flat.Unit -- opposite side of the crater from the target
	else
		dir = Vector3.new(1, 0, 0) -- target at the centre: fixed rim point
	end
	local p = dir * Config.GUARDIAN_SPAWN_DISTANCE
	return Vector3.new(p.X, Config.CRATER_FLOOR_Y, p.Z)
end

local function spawnGuardian(target: Model, targetPlayer: Player?, rarity: string, spawnPos: Vector3): Model?
	local speed = speedForRarity(rarity)
	local model = buildGuardian(spawnPos)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
	model.Parent = workspace
	active[model] = {
		model = model,
		target = target,
		targetPlayer = targetPlayer,
		speed = speed,
		bornAt = time(),
		totalMoved = 0,
		minDist = math.huge,
		maxRadius = 0,
		leftCrater = false,
	}
	-- Touch-catch: the catch radius is checked every 0.1s tick, but a
	-- touch is instant — if the target's character touches the
	-- guardian's body, the catch fires right away instead of waiting
	-- for the next tick. The body only ever touches the target this
	-- close (its own welded parts never fire Touched on each other,
	-- and the ground is not the target), so a touch IS a catch. This
	-- is what makes the guardian actually hurt.
	local body = model.PrimaryPart
	if body then
		body.Touched:Connect(function(hit: BasePart)
			local entry = active[model]
			if not entry then
				return
			end
			local hitCharacter = hit.Parent
			if not hitCharacter then
				return
			end
			if entry.targetPlayer then
				if Players:GetPlayerFromCharacter(hitCharacter :: Model) == entry.targetPlayer then
					catchPlayer(model, entry.targetPlayer)
				end
			elseif hitCharacter == entry.target then
				catchRaider(model, entry.target)
			end
		end)
	end
	if targetPlayer then
		chasedPlayers[targetPlayer.UserId] = true
	end
	-- The warning: banner + roar + red edges (the HUD reads
	-- isChasing and flashes the edges while the chase is on).
	playRoar(spawnPos)
	if targetPlayer then
		Remotes.bannerEvent():FireClient(targetPlayer, "🪨 THE GUARDIAN IS AWAKE! RUN! 🪨", 4)
	end
	print("[Guardian] spawned, speed " .. tostring(speed) .. " (" .. rarity .. "), target " .. (if targetPlayer then targetPlayer.Name else "raider"))
	task.spawn(chaseLoop, model)
	return model
end

-- A player grabbed a Brainrot from the crater: wake the guardian.
-- One guardian per player at a time; a second grab while chased just
-- keeps the one already hunting.
function GuardianService.onGrab(player: Player, grabbed: Model)
	if chasedPlayers[player.UserId] then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local def = RotlingCatalog.getDef(grabbed:GetAttribute("DefId") :: string)
	local rarity = if def then def.rarity else "Common"
	local root = character:FindFirstChild("HumanoidRootPart")
	-- The guardian climbs out of the crater rim opposite the grabber
	-- (guardianSpawnPos): never on top of the player, or the catch is
	-- instant and the grab reads as broken.
	local spawnPos = if root then guardianSpawnPos(root.Position) else Vector3.new(Config.GUARDIAN_SPAWN_DISTANCE, Config.CRATER_FLOOR_Y, 0)
	spawnGuardian(character, player, rarity, spawnPos)
end

-- A raider grabbed a Brainrot from the crater: the guardian chases it.
function GuardianService.onRaiderGrab(raiderModel: Model, stolen: Model)
	local def = RotlingCatalog.getDef(stolen:GetAttribute("DefId") :: string)
	local rarity = if def then def.rarity else "Common"
	local root = raiderModel:FindFirstChild("HumanoidRootPart")
	local spawnPos = if root then guardianSpawnPos(root.Position) else Vector3.new(Config.GUARDIAN_SPAWN_DISTANCE, Config.CRATER_FLOOR_Y, 0)
	spawnGuardian(raiderModel, nil, rarity, spawnPos)
end

return GuardianService
