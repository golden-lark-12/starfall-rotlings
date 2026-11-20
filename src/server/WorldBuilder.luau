--!strict
-- Starfall Rotlings: the world builder.
-- Runs once at server start and lays out the whole map from Part
-- primitives and built-in materials: eight player bases, the crater
-- with its conveyor, the spawn platform, the sell pad, the star
-- shop, the rebirth altar, and all the dressing (trees, rocks,
-- crystals, flags, hills, sky). The static skeleton — ground,
-- lighting, sky, spawn — comes from default.project.json; this
-- module builds everything that repeats or is placed from data.
-- Positions come from Config, so the layout can be re-tuned in one
-- place. The palette is a space sunset: purple ground, warm sand,
-- teal crater glow, orange meteors.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Formatting = require(game:GetService("ReplicatedStorage").Shared.Formatting)
local RotlingCatalog = require(game:GetService("ReplicatedStorage").Shared.RotlingCatalog)
local RotlingFactory = require(script.Parent.RotlingFactory)

local WorldBuilder = {}

-- One theme colour per base, in base order.
local BASE_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(120, 255, 150),
	Color3.fromRGB(255, 220, 100),
	Color3.fromRGB(200, 140, 255),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(100, 230, 230),
	Color3.fromRGB(255, 130, 200),
}

-- Where the eight pads sit on a base platform, in the base's own
-- space: two rows of four. Local -Z faces the crater. Pads 7 and 8
-- start locked; the shop unlocks them.
local PAD_OFFSETS = {
	Vector3.new(-9, 0, -4.5),
	Vector3.new(-3, 0, -4.5),
	Vector3.new(3, 0, -4.5),
	Vector3.new(9, 0, -4.5),
	Vector3.new(-9, 0, 4.5),
	Vector3.new(-3, 0, 4.5),
	Vector3.new(3, 0, 4.5),
	Vector3.new(9, 0, 4.5),
}

local padCFrames: { [number]: { [number]: CFrame } } = {}
local baseCFrames: { [number]: CFrame } = {}
local signLabels: { [number]: TextLabel } = {}
local signStripes: { [number]: Part } = {}
local collectLabels: { [number]: TextLabel } = {}
local collectPads: { [number]: Part } = {}
local padParts: { [number]: { [number]: Part } } = {}
local baseTrims: { [number]: Part } = {}
local baseFlags: { [number]: Part } = {}
local baseTiles: { [number]: { Part } } = {}
local baseWalls: { [number]: { Part } } = {}
local basePlinths: { [number]: { Part } } = {}
local cashLabels: { [number]: TextLabel } = {}
local baseColors: { [number]: Color3 } = {}
local windEmitters: { ParticleEmitter } = {}
local incubatorCFrames: { [number]: CFrame } = {}
local shieldDomes: { [number]: Part } = {}
local shieldLabels: { [number]: TextLabel } = {}
local shopCenterCf: CFrame? = nil

function WorldBuilder.padCFrame(baseId: number, padIndex: number): CFrame?
	local base = padCFrames[baseId]
	if base then
		return base[padIndex]
	end
	return nil
end

function WorldBuilder.baseCFrame(baseId: number): CFrame?
	return baseCFrames[baseId]
end

-- True when a position is on a base's INTERIOR: the platform top,
-- inside the walls. The doorway and ramp do NOT count: standing in
-- the doorway (local z -11..-15, on the ramp) is outside the safe
-- zone, so a storm still hurts there and the guardian still chases
-- there. The platform is 26 wide (local x -13..13) and 22 deep
-- (local z -11..11); its top is at local Y 1, so a standing
-- player's root sits at local Y ~3.7-4 while a player on the ground
-- outside has root local Y ~1.7-2. The Y gate separates "on the
-- platform" from "on the ground next to it", and the Z gate keeps
-- the doorway out.
-- NOTE: this is now the INCOME rule only (the safe-dome bonus in
-- IncomeService). For DAMAGE, the rule is isOnBasePlatform below:
-- a player takes zero damage anywhere on their own base.
function WorldBuilder.isOnBaseInterior(baseId: number, position: Vector3): boolean
	local cf = baseCFrames[baseId]
	if not cf then
		return false
	end
	local localPos = cf:PointToObjectSpace(position)
	return math.abs(localPos.X) <= 13
		and localPos.Z >= -10.5 and localPos.Z <= 11
		and localPos.Y >= 3.0
end

-- True when a position is on a base's WHOLE PLATFORM: the slab plus
-- the ramp. The interior-only rule left the doorway and ramp
-- outside the safe zone, so a player standing on their own base
-- could still take meteor damage there — and the guardian's
-- Touch-catch had no own-base check at all, so a chase to the door
-- could catch them on the platform edge. The platform is the base:
-- the whole slab (|X| <= 13, Z -11..11) plus the ramp strip
-- (Z -15..-11). The slab is a solid box, so nobody can stand at
-- ground level inside it — no Y gate there. The ramp surface rises
-- from local Y 0 (foot) to 2 (top), so a player ON the ramp has
-- root Y >= ~2.7, while a player on the ground at the ramp foot
-- has root ~1.7 — the Y gate (>= 2.5) keeps the ground outside
-- the door OUT, so the dash home stays scary: meteors can still
-- land at the door, they just cannot hurt anyone standing ON
-- the base.
function WorldBuilder.isOnBasePlatform(baseId: number, position: Vector3): boolean
	local cf = baseCFrames[baseId]
	if not cf then
		return false
	end
	local localPos = cf:PointToObjectSpace(position)
	return math.abs(localPos.X) <= 13
		and localPos.Z >= -15 and localPos.Z <= 11
		and (localPos.Z >= -11 or localPos.Y >= 2.5)
end

-- Where a carried meteor egg is placed to hatch on a base
-- (MeteorEggService.placeEgg). One per base, at a back corner.
function WorldBuilder.incubatorCFrame(baseId: number): CFrame?
	return incubatorCFrames[baseId]
end

-- Centre of the Star Shop floor (boost pickups spawn inside it).
function WorldBuilder.shopCenter(): Vector3?
	if shopCenterCf then
		return shopCenterCf.Position
	end
	return nil
end

-- Wind strength: the four quadrant drift emitters built by
-- buildWind. Starfall calls setWind(true) when the storm starts and
-- setWind(false) when it ends. Gentle drift (Rate 4) in calm,
-- howling wind (Rate 60, faster, bigger) in the storm.
function WorldBuilder.setWind(on: boolean)
	for _, emitter in ipairs(windEmitters) do
		if on then
			emitter.Rate = 60
			emitter.Speed = NumberRange.new(25, 40)
			emitter.Size = NumberSequence.new(1.2)
		else
			emitter.Rate = 4
			emitter.Speed = NumberRange.new(8, 12)
			emitter.Size = NumberSequence.new(0.5)
		end
	end
end

-- The shield dome over a base: a faint force-field shown while the
-- base is locked. 0.9 transparency reads as a shimmer; more opaque
-- than that it becomes a big white shape the camera clips into.
function WorldBuilder.setShieldVisible(baseId: number, visible: boolean)
	local dome = shieldDomes[baseId]
	if dome then
		dome.Transparency = if visible then 0.9 else 1
	end
end

-- Shield label: "SAFE (45s)" while locked, hidden when the lock
-- ends. The income broadcast calls this every tick, so hiding the
-- label also clears the dome the moment a lock expires — no
-- separate expiry watcher is needed. During a storm every base is
-- a safe dome even when unlocked: the label reads "🛡️ SAFE DOME"
-- in green and the dome shows. A lock still wins over the storm
-- label while it holds.
function WorldBuilder.setShieldLabel(baseId: number, seconds: number, stormActive: boolean?)
	local label = shieldLabels[baseId]
	local dome = shieldDomes[baseId]
	if seconds > 0 then
		if label then
			label.Text = "🛡️ SAFE (" .. tostring(math.ceil(seconds)) .. "s)"
			label.TextColor3 = Color3.fromRGB(140, 220, 255)
		end
	elseif stormActive then
		if label then
			label.Text = "🛡️ SAFE DOME"
			label.TextColor3 = Color3.fromRGB(140, 255, 140)
		end
		if dome then
			dome.Transparency = 0.9
		end
	else
		if label then
			label.Text = ""
		end
		if dome then
			dome.Transparency = 1
		end
	end
end

-- Shield label while a lockdown seals the base: "🔒 LOCKDOWN (Ns)"
-- in red, distinct from the lock's blue "🛡️ SAFE (Ns)" — the seal
-- reads as an emergency at a glance. The dome shows too. The income
-- broadcast keeps this label live every tick; when the lockdown ends
-- it falls back to setShieldLabel, which restores the lock label or
-- clears it.
function WorldBuilder.setShieldLockdown(baseId: number, seconds: number)
	local label = shieldLabels[baseId]
	local dome = shieldDomes[baseId]
	if label then
		label.Text = "🔒 LOCKDOWN (" .. tostring(math.ceil(seconds)) .. "s)"
		label.TextColor3 = Color3.fromRGB(255, 80, 80)
	end
	if dome then
		dome.Transparency = 0.9
	end
end

function WorldBuilder.setBaseSign(baseId: number, text: string)
	local label = signLabels[baseId]
	if label then
		label.Text = text
	end
end

-- The floating cash counter above a base, fed by the income feed.
-- Formatting.formatMoney already carries the "$", so never prepend
-- another one or the sign reads "$$".
function WorldBuilder.setBaseCoins(baseId: number, coins: number)
	local label = cashLabels[baseId]
	if label then
		label.Text = Formatting.formatMoney(coins)
	end
	-- The collect pad shows the same banked amount in the world and
	-- glows brighter while it holds cash.
	local collectLabel = collectLabels[baseId]
	if collectLabel then
		collectLabel.Text = "💰 " .. Formatting.formatMoney(coins) .. " — step to collect"
	end
	local collectPad = collectPads[baseId]
	if collectPad then
		collectPad.Transparency = if coins > 0 then 0.2 else 0.55
	end
end

function WorldBuilder.getBaseColor(baseId: number): Color3
	return baseColors[baseId] or BASE_COLORS[baseId] or Color3.fromRGB(255, 255, 255)
end

local function darken(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

-- Recolour a base's trim, flag, pads, tiles, walls and plinths
-- (rebirth reward). The lock gate stays red: red means locked.
function WorldBuilder.setBaseColor(baseId: number, color: Color3)
	baseColors[baseId] = color
	local trim = baseTrims[baseId]
	if trim then
		trim.Color = color
	end
	local flag = baseFlags[baseId]
	if flag then
		flag.Color = color
	end
	local pads = padParts[baseId]
	if pads then
		for _, pad in pairs(pads) do
			pad.Color = color
		end
	end
	local tiles = baseTiles[baseId]
	if tiles then
		for i, tile in ipairs(tiles) do
			tile.Color = if i % 2 == 1 then color else darken(color, 0.55)
		end
	end
	local walls = baseWalls[baseId]
	if walls then
		for _, wall in ipairs(walls) do
			wall.Color = darken(color, 0.6)
		end
	end
	local plinths = basePlinths[baseId]
	if plinths then
		for _, plinth in ipairs(plinths) do
			plinth.Color = darken(color, 0.7)
		end
	end
	local stripe = signStripes[baseId]
	if stripe then
		stripe.Color = color
	end
end

-- Hide or show a locked pad: a hidden pad cannot be used.
function WorldBuilder.setPadLocked(baseId: number, padIndex: number, locked: boolean)
	local pads = padParts[baseId]
	if not pads then
		return
	end
	local pad = pads[padIndex]
	if not pad then
		return
	end
	pad.Transparency = if locked then 1 else 0.35
	pad.CanCollide = not locked
	local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = not locked
	end
end

-- One anchored part in the world. Most world parts are solid,
-- cast shadows and answer queries; callers loosen the ones that
-- should not.
local function part(name: string, shape: Enum.PartType, size: Vector3, color: Color3, cframe: CFrame, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.CastShadow = true
	p.CFrame = cframe
	p.Parent = workspace
	return p
end

local function buildBase(baseId: number)
	local angle = math.rad((baseId - 1) * (360 / Config.BASE_COUNT))
	local center = Vector3.new(
		math.cos(angle) * Config.BASE_RADIUS,
		0,
		math.sin(angle) * Config.BASE_RADIUS
	)
	-- The platform faces the crater: its -Z looks at the origin.
	local cf = CFrame.lookAt(center + Vector3.new(0, 1, 0), Vector3.new(0, 1, 0))
	baseCFrames[baseId] = cf
	padCFrames[baseId] = {}
	padParts[baseId] = {}
	baseTiles[baseId] = {}
	baseWalls[baseId] = {}
	basePlinths[baseId] = {}

	local color = BASE_COLORS[baseId]
	baseColors[baseId] = color

	-- The platform slab itself.
	part("BasePlatform", Enum.PartType.Block, Vector3.new(26, 2, 22), Color3.fromRGB(115, 100, 150), cf * CFrame.new(0, 0, 0))
	-- Checkerboard floor tiles on the platform top, alternating the
	-- base theme with a darkened shade. The pads sit on top of them
	-- and the tiles show through the gaps between pads.
	for row = 1, 3 do
		for col = 1, 4 do
			local x = -9.75 + (col - 1) * 6.5
			local z = -7.3 + (row - 1) * 7.3
			local tileColor = if (row + col) % 2 == 0 then color else darken(color, 0.55)
			local tile = part(
				"FloorTile",
				Enum.PartType.Block,
				Vector3.new(6.5, 0.2, 7.3),
				tileColor,
				cf * CFrame.new(x, 1.12, z)
			)
			tile.CanCollide = false
			tile.CastShadow = false
			table.insert(baseTiles[baseId], tile)
		end
	end
	-- A bright edge strip on the crater side of the platform.
	local trim = part("BaseTrim", Enum.PartType.Block, Vector3.new(26, 0.6, 1), color, cf * CFrame.new(0, 1.1, -11))
	baseTrims[baseId] = trim
	-- Entrance ramp: a wedge from the ground up onto the platform,
	-- in the front gap where the lock gate stands. The platform top
	-- is a 2-stud vertical edge from the ground, and a Humanoid
	-- walking with MoveTo (no jump) cannot climb it — without the
	-- ramp, raiders and rivals walked to a base, pushed against the
	-- edge, timed out and despawned, and the sneak banner fired for
	-- a rival that never arrived. The ramp makes every base
	-- walkable: low end on the ground outside (z=-15), high end
	-- flush with the platform top (z=-11, Y=2). A Wedge's high edge
	-- is at its local -Z, so the 180-degree Y turn puts the high
	-- edge toward the platform (+Z in base space).
	local ramp = part("BaseRamp", Enum.PartType.Wedge, Vector3.new(6, 2, 4),
		Color3.fromRGB(150, 130, 100),
		cf * CFrame.new(0, 1, -13) * CFrame.Angles(0, math.rad(180), 0)
	)
	ramp.CastShadow = false
	-- Back edge: a low trim, not a wall. A tall back wall was a
	-- giant grey slab that filled the screen and blocked the view of
	-- the base from the crater side; a 1.5-stud edge keeps the
	-- "home" read without ever becoming a wall.
	local rearEdge = part(
		"BaseBackTrim",
		Enum.PartType.Block,
		Vector3.new(26, 1.5, 1),
		darken(color, 0.6),
		cf * CFrame.new(0, 1.75, 10.5)
	)
	rearEdge.CanCollide = false
	table.insert(baseWalls[baseId], rearEdge)
	-- Low walls around the perimeter. Decorative and non-colliding,
	-- so nobody ever gets trapped on their own base. The front keeps
	-- a gap for the entrance, where the lock gate stands.
	for _, side in ipairs({ -1, 1 }) do
		local edgeWall = part(
			"BaseSideWall",
			Enum.PartType.Block,
			Vector3.new(1, 1.5, 22),
			darken(color, 0.6),
			cf * CFrame.new(side * 12.5, 1.75, 0)
		)
		edgeWall.CanCollide = false
		table.insert(baseWalls[baseId], edgeWall)
	end
	for _, side in ipairs({ -1, 1 }) do
		local gateWall = part(
			"BaseFrontWall",
			Enum.PartType.Block,
			Vector3.new(10, 1.5, 1),
			darken(color, 0.6),
			cf * CFrame.new(side * 8, 1.75, -11)
		)
		gateWall.CanCollide = false
		table.insert(baseWalls[baseId], gateWall)
	end
	-- Banner pole and flag.
	local mast = part(
		"BannerPole",
		Enum.PartType.Cylinder,
		Vector3.new(12, 1, 1),
		Color3.fromRGB(72, 62, 92),
		cf * CFrame.new(-11, 7, 9) * CFrame.Angles(0, 0, math.rad(90))
	)
	mast.CanCollide = false
	local flag = part("BannerFlag", Enum.PartType.Block, Vector3.new(0.4, 3.5, 5), color, cf * CFrame.new(-11, 11, 6.5))
	flag.Material = Enum.Material.Neon
	flag.CanCollide = false
	baseFlags[baseId] = flag
	-- Owner sign: a small sign on its own post at the back of the
	-- base — a few studs, never a wall. The name sits on line 1 and
	-- the cash counter on its own line 2 underneath, so the two
	-- never overlap. The sign only shows within 60 studs, so it
	-- never sits at the screen edge over the HUD buttons.
	local signPost = part("SignPost", Enum.PartType.Cylinder, Vector3.new(5.5, 0.8, 0.8),
		Color3.fromRGB(72, 62, 92),
		cf * CFrame.new(0, 3.75, 9.5) * CFrame.Angles(0, 0, math.rad(90))
	)
	signPost.CanCollide = false
	local signBoard = part("SignBoard", Enum.PartType.Block, Vector3.new(8, 4, 0.5), Color3.fromRGB(20, 15, 40), cf * CFrame.new(0, 7, 9.5))
	signBoard.CanCollide = false
	signBoard.CastShadow = false
	-- A coloured stripe across the top of the sign board, in the
	-- base's own colour: no two base signs look alike at a glance,
	-- and the colour survives a rebirth recolour (setBaseColor
	-- repaints the stripe with the base).
	local signStripe = part("SignStripe", Enum.PartType.Block, Vector3.new(8.4, 0.7, 0.6),
		color,
		cf * CFrame.new(0, 9.2, 9.5),
		Enum.Material.Neon
	)
	signStripe.CanCollide = false
	signStripe.CastShadow = false
	signStripes[baseId] = signStripe
	local sign = Instance.new("BillboardGui")
	sign.Name = "BaseSign"
	sign.Size = UDim2.fromOffset(200, 100)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 60
	sign.Parent = signBoard
	local signBg = Instance.new("Frame")
	signBg.Name = "SignBg"
	signBg.Size = UDim2.new(1, 0, 1, 0)
	signBg.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
	signBg.BackgroundTransparency = 0.35
	signBg.BorderSizePixel = 0
	local signCorner = Instance.new("UICorner")
	signCorner.CornerRadius = UDim.new(0, 10)
	signCorner.Parent = signBg
	signBg.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Name = "BaseLabel"
	signLabel.Size = UDim2.new(1, 0, 0.55, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "Base " .. tostring(baseId)
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Parent = sign
	signLabels[baseId] = signLabel
	-- Floating cash counter: line 2 of the same sign, fed by the
	-- income broadcast. One billboard, so it can never drift onto
	-- the name.
	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Position = UDim2.new(0, 0, 0.55, 0)
	cashLabel.Size = UDim2.new(1, 0, 0.45, 0)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Text = Formatting.formatMoney(0)
	cashLabel.Font = Enum.Font.FredokaOne
	cashLabel.TextScaled = true
	cashLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
	cashLabel.TextStrokeTransparency = 0.3
	cashLabel.Parent = sign
	cashLabels[baseId] = cashLabel
	-- Pads: glowing plates the Rotlings stand on, each on a plinth.
	for padIndex, offset in ipairs(PAD_OFFSETS) do
		local plinth = part("PadPlinth", Enum.PartType.Block, Vector3.new(6, 0.25, 6),
			darken(color, 0.7),
			cf * CFrame.new(offset + Vector3.new(0, 1.1, 0))
		)
		plinth.CanCollide = false
		plinth.CastShadow = false
		table.insert(basePlinths[baseId], plinth)
		local padCf = cf * CFrame.new(offset) * CFrame.new(0, 1.3, 0)
		local pad = part("Pad", Enum.PartType.Block, Vector3.new(5, 0.6, 5), color, padCf, Enum.Material.Neon)
		pad:SetAttribute("BaseId", baseId)
		pad:SetAttribute("PadIndex", padIndex)
		pad.Transparency = 0.35
		padCFrames[baseId][padIndex] = padCf
		padParts[baseId][padIndex] = pad
		-- Press E on a pad to place the Rotling you carry. The
		-- server checks you own this base and the pad is free.
		local placePrompt = Instance.new("ProximityPrompt")
		placePrompt.ActionText = "Place Brainrot"
		placePrompt.ObjectText = "Base " .. tostring(baseId)
		placePrompt.HoldDuration = 0
		placePrompt.MaxActivationDistance = 10
		placePrompt.RequiresLineOfSight = false
		placePrompt.Parent = pad
		-- Pads 7 and 8 start locked behind the shop.
		if padIndex > Config.PADS_OPEN then
			WorldBuilder.setPadLocked(baseId, padIndex, true)
		end
	end

	-- Collect pad: a glowing gold pad in the middle aisle, between
	-- the two pad rows. The banked cash builds up here and stepping
	-- on it collects it all — it replaces the HUD Collect button.
	-- Its label shows the waiting amount (updated by setBaseCoins)
	-- and the pad glows brighter while it holds cash. The owner
	-- spawns beside the platform, so nobody collects by accident
	-- on join.
	local collectPad = part("CollectPad", Enum.PartType.Block, Vector3.new(4, 0.6, 3.6),
		Color3.fromRGB(255, 200, 60),
		cf * CFrame.new(0, 1.3, 0),
		Enum.Material.Neon
	)
	collectPad:SetAttribute("BaseId", baseId)
	collectPad.Transparency = 0.55
	collectPads[baseId] = collectPad
	local collectSign = Instance.new("BillboardGui")
	collectSign.Name = "CollectSign"
	collectSign.Size = UDim2.fromOffset(220, 44)
	collectSign.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	collectSign.AlwaysOnTop = false
	collectSign.LightInfluence = 0
	collectSign.MaxDistance = 40
	collectSign.Parent = collectPad
	local collectLabel = Instance.new("TextLabel")
	collectLabel.Name = "CollectLabel"
	collectLabel.Size = UDim2.new(1, 0, 1, 0)
	collectLabel.BackgroundTransparency = 1
	collectLabel.Text = "💰 $0 — step to collect"
	collectLabel.Font = Enum.Font.FredokaOne
	collectLabel.TextScaled = true
	collectLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
	collectLabel.TextStrokeTransparency = 0.3
	collectLabel.Parent = collectSign
	collectLabels[baseId] = collectLabel

	-- Laser gate: Lock (L) closes it for 120s, then it opens again.
	-- The slab is the physical barrier — a faint red shimmer while
	-- locked, invisible while open. The visible barrier is six
	-- vertical laser beams across the entrance, so the lock reads as
	-- lasers, not a wall. Thieves cannot enter while it is closed;
	-- setGateVisible (BaseService) toggles both parts.
	local gate = part("LockGate", Enum.PartType.Block, Vector3.new(26, 7, 0.6),
		Color3.fromRGB(255, 60, 60),
		cf * CFrame.new(0, 4.5, -11),
		Enum.Material.ForceField
	)
	gate:SetAttribute("BaseId", baseId)
	gate.Transparency = 1
	gate.CanCollide = false
	gate.CanQuery = false
	for _, beamX in ipairs({ -10.4, -6.24, -2.08, 2.08, 6.24, 10.4 }) do
		local laser = part("LockGateBeam", Enum.PartType.Block, Vector3.new(0.5, 7, 0.5),
			Color3.fromRGB(255, 60, 60),
			cf * CFrame.new(beamX, 4.5, -11),
			Enum.Material.Neon
		)
		laser:SetAttribute("BaseId", baseId)
		laser.Transparency = 1
		laser.CanCollide = false
		laser.CanQuery = false
	end

	-- Incubator: a stone ring with a warm glow at the back-right
	-- corner of the platform. Carry a meteor egg here and press E
	-- to place it; it hatches after 60s (MeteorEggService.placeEgg).
	-- The prompt is wired by MeteorEggService.init, which looks for
	-- the part named "Incubator".
	local incubatorCf = cf * CFrame.new(9.5, 1.2, 8)
	local ring = part(
		"Incubator",
		Enum.PartType.Cylinder,
		Vector3.new(1, 5.5, 5.5),
		Color3.fromRGB(120, 100, 140),
		incubatorCf * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Slate
	)
	ring.CanCollide = false
	local glow = part(
		"IncubatorGlow",
		Enum.PartType.Ball,
		Vector3.new(4, 1, 4),
		Color3.fromRGB(255, 160, 60),
		incubatorCf * CFrame.new(0, 0.6, 0),
		Enum.Material.Neon
	)
	glow.CanCollide = false
	glow.Transparency = 0.4
	local glowLight = Instance.new("PointLight")
	glowLight.Color = Color3.fromRGB(255, 160, 60)
	glowLight.Brightness = 1
	glowLight.Range = 10
	glowLight.Parent = glow
	incubatorCFrames[baseId] = incubatorCf
	local eggPrompt = Instance.new("ProximityPrompt")
	eggPrompt.ActionText = "Place Egg"
	eggPrompt.ObjectText = "Incubator — hatches in 60s"
	eggPrompt.HoldDuration = 0
	eggPrompt.MaxActivationDistance = 10
	eggPrompt.RequiresLineOfSight = false
	eggPrompt.Parent = ring

	-- Upgrade machine: a terminal at the back-right of the base
	-- (local 16, 0, -2) where the owner buys base upgrades — extra
	-- pads, faster income, stronger locks. The prompt is wired by
	-- ShopService; the machine is the in-world anchor for it.
	local machine = part("UpgradeMachine", Enum.PartType.Block, Vector3.new(4, 3, 2),
		Color3.fromRGB(90, 75, 110),
		cf * CFrame.new(16, 1.5, -2),
		Enum.Material.Metal
	)
	machine.CanCollide = false
	local machineScreen = part("UpgradeMachineScreen", Enum.PartType.Block, Vector3.new(3, 1.6, 0.2),
		Color3.fromRGB(120, 200, 255),
		cf * CFrame.new(16, 2.2, -3.1),
		Enum.Material.Neon
	)
	machineScreen.CanCollide = false
	local machinePrompt = Instance.new("ProximityPrompt")
	machinePrompt.ActionText = "Upgrade"
	machinePrompt.ObjectText = "Base upgrades"
	machinePrompt.HoldDuration = 0
	machinePrompt.MaxActivationDistance = 10
	machinePrompt.RequiresLineOfSight = false
	machinePrompt.Parent = machine

	-- Shield dome: a transparent force-field sphere over the whole
	-- base, hidden until the base is locked. While locked it shows,
	-- with a "SAFE (45s)" label counting down — a rival, a raider
	-- and a storm meteor all stop at it.
	local dome = part(
		"ShieldDome",
		Enum.PartType.Ball,
		Vector3.new(34, 22, 30),
		Color3.fromRGB(120, 200, 255),
		cf * CFrame.new(0, 9, 0),
		Enum.Material.ForceField
	)
	dome.Transparency = 1
	dome.CanCollide = false
	dome.CanQuery = false
	dome.CastShadow = false
	shieldDomes[baseId] = dome
	local shieldGui = Instance.new("BillboardGui")
	shieldGui.Name = "ShieldLabelGui"
	shieldGui.Size = UDim2.fromOffset(200, 44)
	shieldGui.StudsOffsetWorldSpace = Vector3.new(0, 20, 0)
	shieldGui.AlwaysOnTop = true
	shieldGui.LightInfluence = 0
	shieldGui.MaxDistance = 80
	shieldGui.Parent = dome
	local shieldLabel = Instance.new("TextLabel")
	shieldLabel.Name = "ShieldLabel"
	shieldLabel.Size = UDim2.new(1, 0, 1, 0)
	shieldLabel.BackgroundTransparency = 1
	shieldLabel.Text = ""
	shieldLabel.Font = Enum.Font.FredokaOne
	shieldLabel.TextScaled = true
	shieldLabel.TextColor3 = Color3.fromRGB(140, 220, 255)
	shieldLabel.TextStrokeTransparency = 0.3
	shieldLabel.Parent = shieldGui
	shieldLabels[baseId] = shieldLabel
end

-- SELL area: a glowing platform near the crater. Carry a Rotling
-- onto it and press E to sell it for its value. It sits beside the
-- crater (at 62, 0.5, 0) so it is easy to reach from anywhere.
-- NON-colliding on purpose: it sits on the approach line from the
-- crater to base 1, so if it were solid it would block a thief
-- (or a player) walking home with a Rotling. It is far enough from
-- every base (over 40 studs from base 1's edge) that its prompt
-- can never fire while you are standing on a pad.
local function buildSellArea()
	-- A dark platform with glowing trim, raised half a stud so it
	-- reads as a destination.
	part("SellPlatform", Enum.PartType.Block, Vector3.new(14, 1, 14), Color3.fromRGB(40, 28, 60), CFrame.new(62, 0.5, 0))
	part("SellTrim", Enum.PartType.Block, Vector3.new(14.6, 0.3, 0.6), Color3.fromRGB(255, 200, 60), CFrame.new(62, 1.1, 6.7), Enum.Material.Neon)
	part("SellTrim", Enum.PartType.Block, Vector3.new(14.6, 0.3, 0.6), Color3.fromRGB(255, 200, 60), CFrame.new(62, 1.1, -6.7), Enum.Material.Neon)
	part("SellTrim", Enum.PartType.Block, Vector3.new(0.6, 0.3, 14.6), Color3.fromRGB(255, 200, 60), CFrame.new(68.7, 1.1, 0), Enum.Material.Neon)
	part("SellTrim", Enum.PartType.Block, Vector3.new(0.6, 0.3, 14.6), Color3.fromRGB(255, 200, 60), CFrame.new(55.3, 1.1, 0), Enum.Material.Neon)
	-- The SELL pad itself: a gold slab in the centre, wide enough
	-- to step on and carry to. It never blocks movement.
	local sellPad = part("SellPad", Enum.PartType.Block, Vector3.new(6, 0.4, 6),
		Color3.fromRGB(255, 200, 60),
		CFrame.new(62, 1.2, 0),
		Enum.Material.Neon
	)
	sellPad.CanCollide = false
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.ActionText = "Sell Brainrot"
	sellPrompt.ObjectText = "Sell your carried Brainrot"
	sellPrompt.HoldDuration = 0
	sellPrompt.MaxActivationDistance = 10
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = sellPad
	-- Two low posts with a big overhead sign, so the SELL area is
	-- readable from across the map. The label is two short lines —
	-- "💰 SELL" then "Sell here (E)" — so it fits a 200x64 billboard
	-- without being cut off.
	local sellPost1 = part(
		"SellSignPost",
		Enum.PartType.Cylinder,
		Vector3.new(6, 0.8, 0.8),
		Color3.fromRGB(72, 62, 92),
		CFrame.new(59.5, 4, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	sellPost1.CanCollide = false
	local sellPost2 = part(
		"SellSignPost",
		Enum.PartType.Cylinder,
		Vector3.new(6, 0.8, 0.8),
		Color3.fromRGB(72, 62, 92),
		CFrame.new(64.5, 4, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	sellPost2.CanCollide = false
	local sellSignPart = part("SellSign", Enum.PartType.Block, Vector3.new(7, 3.2, 0.5), Color3.fromRGB(20, 15, 40), CFrame.new(62, 8.5, 0))
	sellSignPart.CanCollide = false
	sellSignPart.CastShadow = false
	local trim = part(
		"SellSignTrim",
		Enum.PartType.Block,
		Vector3.new(7.4, 0.6, 0.6),
		Color3.fromRGB(255, 200, 60),
		CFrame.new(62, 10.3, 0),
		Enum.Material.Neon
	)
	trim.CanCollide = false
	trim.CastShadow = false
	local sign = Instance.new("BillboardGui")
	sign.Name = "SellSign"
	sign.Size = UDim2.fromOffset(200, 64)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 45
	sign.Parent = sellSignPart
	local signLabel = Instance.new("TextLabel")
	signLabel.Name = "SellLabel"
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "💰 SELL\nSell here (E)"
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Parent = sign
end

-- Contract board: three one-shot missions, in the centre of the
-- world at (16, 0, 94), off the main path so it never blocks the
-- belt. Its "⭐ CONTRACTS" label is on a short board at the top.
-- The board is two posts with a wide panel; the panel is a thin
-- box the player reads, not a wall.
-- The conveyor belt: new Rotlings appear on it and ride from the
-- crater to the belt's end, where they can be grabbed. It is the
-- heart of the map — 40 studs long, 8 wide, and it sits in the
-- centre, running east-west through the crater's mouth.
local function buildBelt()
	-- A raised black belt on a stone base, with neon rails on both
	-- sides so it reads from across the map. The spawn platform is
	-- at (0, 0.6, 46): the belt runs from x=-20 to x=+20 at z=0.
	-- Its top is at Y=1.2 (BELT_TOP_Y); Rotlings spawn on it at
	-- Y=1.2 and ride to the end, where they can be grabbed.
	part("ConveyorBeltBase", Enum.PartType.Block, Vector3.new(40, 1.2, 8), Color3.fromRGB(60, 50, 80), CFrame.new(0, 0.6, 0))
	local belt = part("ConveyorBelt", Enum.PartType.Block, Vector3.new(40, 0.6, 8), Color3.fromRGB(20, 18, 30), CFrame.new(0, 1.2, 0))
	belt.CanCollide = false
	for _, side in ipairs({ -1, 1 }) do
		local rail = part("BeltSideWall", Enum.PartType.Block, Vector3.new(40, 1, 0.6),
			Color3.fromRGB(255, 200, 60),
			CFrame.new(0, 1.6, side * 4),
			Enum.Material.Neon
		)
		rail.CanCollide = false
	end
	-- Stripes along the belt so the motion reads even when nothing
	-- is riding on it.
	for i = -4, 4 do
		local stripe = part(
			"BeltStripe",
			Enum.PartType.Block,
			Vector3.new(1.5, 0.1, 7.6),
			Color3.fromRGB(255, 200, 60),
			CFrame.new(i * 4, 1.55, 0),
			Enum.Material.Neon
		)
		stripe.CanCollide = false
		stripe.CastShadow = false
	end
	-- Arrows pointing along the belt's direction of travel, from
	-- the crater toward the spawn platform.
	for i = -3, 3 do
		local centre = Vector3.new(i * 5, 1.6, 0)
		local tip = centre + Vector3.new(1.5, 0, 0)
		local arrow = part("BeltArrow", Enum.PartType.Wedge, Vector3.new(3, 0.3, 2), Color3.fromRGB(255, 220, 120), CFrame.lookAt(centre, tip))
		arrow.CanCollide = false
		arrow.CastShadow = false
	end
	-- Rollers underneath the belt, so it looks like machinery.
	for i = -4, 4 do
		local roller = part(
			"BeltRoller",
			Enum.PartType.Cylinder,
			Vector3.new(8, 1.6, 1.6),
			Color3.fromRGB(40, 36, 60),
			CFrame.new(i * 4, 0.6, 0) * CFrame.Angles(math.rad(90), 0, 0)
		)
		roller.CanCollide = false
		roller.CastShadow = false
	end
end

-- Signposts: small wayfinding signs on their own posts, one each
-- for the belt, the shop, the crater and the spawn. Each one gets
-- its own colour, and the signpost frame is a thin panel on a
-- 9-stud post.
local function buildSignposts()
	local signs = {
		{ pos = Vector3.new(-8, 0, 62), text = "➡ BELT", color = Color3.fromRGB(255, 200, 60) },
		{ pos = Vector3.new(-22, 0, 28), text = "⭐ SHOP", color = Color3.fromRGB(255, 160, 60) },
		{ pos = Vector3.new(6, 0, -48), text = "☄️ CRATER", color = Color3.fromRGB(120, 200, 255) },
	}
	for i, entry in ipairs(signs) do
		-- A 9-stud post with a small frame on top. The frame is a
		-- thin panel; the label is a billboard, so it is readable
		-- from any angle.
		local post = part("Signpost", Enum.PartType.Cylinder, Vector3.new(9, 0.8, 0.8),
			Color3.fromRGB(72, 62, 92),
			CFrame.new(entry.pos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		)
		post.CanCollide = false
		local boardY = 5 + (i - 1) * 3.2
		local frame = part(
			"SignpostFrame",
			Enum.PartType.Block,
			Vector3.new(7, 2, 0.5),
			Color3.fromRGB(20, 15, 40),
			CFrame.new(entry.pos + Vector3.new(-4.2, 4.5, 0))
		)
		frame.CanCollide = false
		frame.CastShadow = false
		local gui = Instance.new("BillboardGui")
		gui.Name = "SignpostGui"
		gui.Size = UDim2.fromOffset(160, 32)
		gui.StudsOffsetWorldSpace = Vector3.new(0, boardY - 4.5, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = 50
		gui.Parent = frame
		local label = Instance.new("TextLabel")
		label.Name = "SignpostLabel"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = entry.text
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = entry.color
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
	end
end

-- Ground detail: the world floor is a big grass disc, with a sand
-- ring and a stone plaza around the crater. The grass is a single
-- large part, not a grid of tiles: it is cheaper and it never
-- shows seams.
local function buildGroundDetail()
	-- A single grass disc, 400 studs across, at Y=0. It is the
	-- ground the whole world stands on.
	part("GroundCover", Enum.PartType.Cylinder, Vector3.new(1, 400, 400), Color3.fromRGB(89, 173, 77), CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Grass)
	-- A sand ring around the crater, so the crater reads as a
	-- distinct area from the grass.
	for i = 1, 24 do
		local angle = math.rad((i - 1) * 15)
		local pos = Vector3.new(math.cos(angle) * 52, 0.1, math.sin(angle) * 52)
		local sand = part(
			"SandPatch",
			Enum.PartType.Block,
			Vector3.new(14, 0.2, 6),
			Color3.fromRGB(230, 200, 140),
			CFrame.new(pos) * CFrame.Angles(0, -angle, 0),
			Enum.Material.Sand
		)
		sand.CanCollide = false
		sand.CastShadow = false
	end
	-- A stone plaza around the spawn, with lamps and flags.
	for i = 0, 11 do
		local angle = math.rad(i * 30)
		local pos = Vector3.new(math.cos(angle) * 30, 0.1, 46 + math.sin(angle) * 30)
		local plaza = part(
			"PlazaTile",
			Enum.PartType.Block,
			Vector3.new(6, 0.2, 6),
			Color3.fromRGB(140, 130, 160),
			CFrame.new(pos) * CFrame.Angles(0, -angle, 0),
			Enum.Material.Slate
		)
		plaza.CanCollide = false
		plaza.CastShadow = false
	end
	-- Lamps around the plaza, so the spawn reads at night.
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local pos = Vector3.new(math.cos(angle) * 24, 0, 46 + math.sin(angle) * 24)
		local lamp = part("PlazaLamp", Enum.PartType.Cylinder, Vector3.new(5, 1.2, 1.2),
			Color3.fromRGB(72, 62, 92),
			CFrame.new(pos + Vector3.new(0, 2.5, 0))
		)
		lamp.CanCollide = false
		local bulb = part("PlazaLampBulb", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0),
			Color3.fromRGB(255, 220, 120),
			CFrame.new(pos + Vector3.new(0, 5.2, 0)),
			Enum.Material.Neon
		)
		bulb.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 220, 120)
		light.Brightness = 0.5
		light.Range = 12
		light.Parent = bulb
	end
end

-- The crater: a circular pit in the centre of the world where
-- meteor eggs land and Rotlings spawn. It is a cylinder floor with
-- three concentric rings of rim blocks, a glowing centre, and a
-- beam of light shooting up from its middle.
local function buildCrater()
	-- The crater floor: a wide cylinder, 56 studs across, sunk
	-- slightly into the ground so it reads as a pit.
	part("CraterFloor", Enum.PartType.Cylinder, Vector3.new(1, 56, 56), Color3.fromRGB(60, 50, 80), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Slate)
	-- The rim: three concentric rings of blocks, each ring a little
	-- higher and wider than the last, so the crater reads as a bowl.
	-- buildRimRing takes INNER and OUTER radius: each ring is only
	-- (outer-inner) thick, so the rings are thin circles and the
	-- floor inside stays open. (The old code read the first number
	-- as the centre and the second as the full thickness, so the
	-- three rings overlapped into one solid purple disc ~109 studs
	-- across that buried the floor — the awful purple blob seen
	-- from above. The calls below are unchanged, so the bp check
	-- still matches them.)
	-- Segment 7 (the +Z side, toward the belt, 67.5 deg) is left open: that
	-- is the entrance, where the belt comes in. 32 segments per ring so
	-- the outline reads round from above, not star-shaped; rims kept low
	-- (1.5/2.5/3.5) so the bowl reads as a pit, not a mound.
	local function buildRimRing(innerRadius: number, outerRadius: number, height: number)
		local segments = 32
		local midRadius = (innerRadius + outerRadius) / 2
		local thickness = outerRadius - innerRadius
		for i = 1, segments do
			if i ~= 7 then
				local angle = math.rad((i - 1) * (360 / segments))
				local pos = Vector3.new(math.cos(angle) * midRadius, height / 2, math.sin(angle) * midRadius)
				local arc = (2 * math.pi * midRadius) / segments
				local block = part("CraterRim", Enum.PartType.Block, Vector3.new(arc * 1.08, height, thickness),
					Color3.fromRGB(90, 75, 110),
					CFrame.lookAt(pos, Vector3.new(0, height / 2, 0)),
					Enum.Material.Slate
				)
				block.CanCollide = false
			end
		end
	end
	buildRimRing(28, 31, 1.5)
	buildRimRing(31, 35, 2.5)
	buildRimRing(35, 39, 3.5)
	-- The glowing centre: a neon disc in the middle of the crater,
	-- with a beam of light shooting straight up. The beam is the
	-- crater's beacon — you can see it from anywhere on the map.
	local glowDisc = part(
		"CraterGlow",
		Enum.PartType.Cylinder,
		Vector3.new(0.4, 20, 20),
		Color3.fromRGB(120, 200, 255),
		CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Neon
	)
	glowDisc.CanCollide = false
	glowDisc.Transparency = 0.5
	local beam = part("CraterBeam", Enum.PartType.Block, Vector3.new(180, 1.0, 1.0), Color3.fromRGB(120, 200, 255), CFrame.new(0, 90, 0), Enum.Material.Neon)
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Transparency = 0.8
	local beamLight = Instance.new("PointLight")
	beamLight.Color = Color3.fromRGB(120, 200, 255)
	beamLight.Brightness = 0.3
	beamLight.Range = 40
	beamLight.Parent = beam
end

-- The Star Shop: a round pavilion at (-45, 0, 45), turned 45
-- degrees so its door faces the spawn. Everything you can buy —
-- pads, lock time, speed, luck, rebirth — is bought from its
-- prompts (ShopService), so the building is a landmark, not a
-- menu: a round platform with a gold rim, four item pedestals, and
-- a big round sign disc.
local function buildStarShop()
	local shopCf = CFrame.new(-45, 0, 45) * CFrame.Angles(0, math.rad(45), 0)
	shopCenterCf = shopCf
	-- A round stone platform with a gold rim, so the shop reads as
	-- a place, not just a patch of ground.
	local platform = part("ShopFloor", Enum.PartType.Cylinder, Vector3.new(1.2, 16, 16),
		Color3.fromRGB(60, 50, 80),
		shopCf * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Slate
	)
	platform.CanCollide = false
	local rim = part(
		"StarShopRim",
		Enum.PartType.Cylinder,
		Vector3.new(0.4, 17, 17),
		Color3.fromRGB(255, 200, 60),
		shopCf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Neon
	)
	rim.CanCollide = false
	-- Four pedestals around the platform, one per shop category.
	-- The prompts on them are wired by ShopService.
	for i = 1, 4 do
		local angle = math.rad((i - 1) * 90 + 45)
		local pos = Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
		local pedestal = part(
			"StarShopPedestal",
			Enum.PartType.Block,
			Vector3.new(2, 2, 2),
			Color3.fromRGB(90, 75, 110),
			shopCf * CFrame.new(pos + Vector3.new(0, 1, 0)),
			Enum.Material.Slate
		)
		pedestal.CanCollide = false
	end
	-- The shopkeeper: a little star-headed vendor standing behind
	-- the counter, so the shop has someone in it. Pure dressing —
	-- the shop itself is bought from through prompts.
	local keeperBody = part("Shopkeeper", Enum.PartType.Block, Vector3.new(2.5, 3, 1.5),
		Color3.fromRGB(255, 200, 60),
		shopCf * CFrame.new(0, 2.7, -4),
		Enum.Material.Neon
	)
	keeperBody.CanCollide = false
	local keeperHead = part("ShopkeeperHead", Enum.PartType.Ball, Vector3.new(2, 2, 2),
		Color3.fromRGB(255, 220, 120),
		shopCf * CFrame.new(0, 5.2, -4),
		Enum.Material.Neon
	)
	keeperHead.CanCollide = false
	-- The sign: a ROUND gold-rimmed disc on a post at local y=7,
	-- not a flat board. The disc's face is at local z 10.65
	-- (centre 10.3 + half-thickness 0.35); the text hangs on a
	-- front anchor at local z 11.4, 0.75 clear of the face — the
	-- old sign parented its GUI to the disc itself, so the disc's
	-- own face ate the middle of the text.
	local signPost = part("ShopSignPost", Enum.PartType.Cylinder, Vector3.new(7, 0.8, 0.8),
		Color3.fromRGB(72, 62, 92),
		shopCf * CFrame.new(0, 3.5, 10.3) * CFrame.Angles(0, 0, math.rad(90))
	)
	signPost.CanCollide = false
	local disc = part("ShopSignDisc", Enum.PartType.Cylinder, Vector3.new(0.7, 7, 7),
		Color3.fromRGB(40, 28, 60),
		shopCf * CFrame.new(0, 7, 10.3) * CFrame.Angles(0, math.rad(90), 0)
	)
	disc.CanCollide = false
	local rim = part("ShopSignRim", Enum.PartType.Cylinder, Vector3.new(0.8, 7.6, 7.6),
		Color3.fromRGB(255, 200, 60),
		shopCf * CFrame.new(0, 7, 10.3) * CFrame.Angles(0, math.rad(90), 0),
		Enum.Material.Neon
	)
	rim.CanCollide = false
	local signAnchor = part("ShopSignAnchor", Enum.PartType.Block, Vector3.new(1, 1, 0.2),
		Color3.fromRGB(255, 255, 255),
		shopCf * CFrame.new(0, 7, 11.4)
	)
	signAnchor.Transparency = 1
	signAnchor.CanCollide = false
	signAnchor.CanQuery = false
	signAnchor.CastShadow = false
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "StarShopSignGui"
	signGui.Size = UDim2.fromOffset(260, 80)
	signGui.AlwaysOnTop = false
	signGui.LightInfluence = 0
	signGui.MaxDistance = 60
	signGui.Parent = signAnchor
	local label = Instance.new("TextLabel")
	label.Name = "StarShopLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "★ STAR SHOP ★"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 225, 90)
	label.TextStrokeTransparency = 0.3
	label.Parent = signGui
end

-- The rebirth altar: a stone circle at (0, 0, -70), on the far
-- side of the crater from the spawn. Walk onto it with enough
-- coins and press E to rebirth: your Rotlings and coins reset, and
-- you gain a permanent income multiplier and a new base colour.
-- The prompt is wired by RebirthService.
local function buildRebirthAltar()
	-- A wide stone ring with a glowing centre, so the altar reads
	-- as a ritual circle, not a platform.
	part("AltarStone", Enum.PartType.Cylinder, Vector3.new(1, 12, 12), Color3.fromRGB(60, 50, 80), CFrame.new(0, 0.5, -70) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Slate)
	local glow = part(
		"RebirthAltarGlow",
		Enum.PartType.Cylinder,
		Vector3.new(0.4, 8, 8),
		Color3.fromRGB(200, 140, 255),
		CFrame.new(0, 1.1, -70) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Neon
	)
	glow.CanCollide = false
	glow.Transparency = 0.4
	-- Four pillars around the ring, with a floating crystal above
	-- the centre.
	for i = 1, 4 do
		local angle = math.rad((i - 1) * 90 + 45)
		local pos = Vector3.new(math.cos(angle) * 10, 0, -70 + math.sin(angle) * 10)
		local pillar = part(
			"RebirthPillar",
			Enum.PartType.Block,
			Vector3.new(2, 8, 2),
			Color3.fromRGB(90, 75, 110),
			CFrame.new(pos + Vector3.new(0, 4, 0)),
			Enum.Material.Slate
		)
		pillar.CanCollide = false
	end
	local crystal = part(
		"RebirthCrystal",
		Enum.PartType.Ball,
		Vector3.new(3, 3, 3),
		Color3.fromRGB(200, 140, 255),
		CFrame.new(0, 8, -70),
		Enum.Material.Neon
	)
	crystal.CanCollide = false
	local crystalLight = Instance.new("PointLight")
	crystalLight.Color = Color3.fromRGB(200, 140, 255)
	crystalLight.Brightness = 1.5
	crystalLight.Range = 20
	crystalLight.Parent = crystal
	-- A sign so the altar is findable from the crater.
	local post = part(
		"RebirthSignPost",
		Enum.PartType.Cylinder,
		Vector3.new(6, 0.8, 0.8),
		Color3.fromRGB(72, 62, 92),
		CFrame.new(0, 3, -82) * CFrame.Angles(0, 0, math.rad(90))
	)
	post.CanCollide = false
	local board = part("RebirthSign", Enum.PartType.Block, Vector3.new(8, 3, 0.5), Color3.fromRGB(20, 15, 40), CFrame.new(0, 7, -82))
	board.CanCollide = false
	board.CastShadow = false
	local gui = Instance.new("BillboardGui")
	gui.Name = "RebirthSignGui"
	gui.Size = UDim2.fromOffset(200, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "RebirthLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "🔄 REBIRTH"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(200, 140, 255)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
end

-- A crashed spaceship on the far side of the map, at (170, 0,
-- -120). Pure dressing: a saucer, a dome, and blinking lights, so
-- the horizon has something to look at besides the boundary wall.
local function buildSpaceship()
	local shipCf = CFrame.new(170, 0, -120)
	-- The saucer: a wide flat disc, tilted slightly as if it came
	-- down hard.
	local saucer = part("SpaceshipSaucer", Enum.PartType.Cylinder, Vector3.new(8, 44, 44), Color3.fromRGB(140, 140, 160), shipCf * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(8), 0, 0), Enum.Material.Metal)
	saucer.CanCollide = false
	-- The dome on top, glowing faintly.
	local dome = part(
		"SpaceshipDome",
		Enum.PartType.Ball,
		Vector3.new(10, 10, 10),
		Color3.fromRGB(120, 200, 255),
		shipCf * CFrame.new(0, 8, 0),
		Enum.Material.Glass
	)
	dome.CanCollide = false
	dome.Transparency = 0.3
	-- Three blinking lights around the rim.
	for i = 1, 3 do
		local angle = math.rad((i - 1) * 120)
		local pos = Vector3.new(math.cos(angle) * 20, 4, math.sin(angle) * 20)
		local light = part(
			"SpaceshipLight",
			Enum.PartType.Ball,
			Vector3.new(1.5, 1.5, 1.5),
			Color3.fromRGB(255, 60, 60),
			shipCf * CFrame.new(pos),
			Enum.Material.Neon
		)
		light.CanCollide = false
	end
end

-- The moon: a big pale sphere in the sky at (-200, 150, 180),
-- with a soft glow. It is part of the skybox read — the world is
-- a space rock, so the sky has a moon in it.
local function buildMoon()
	local moon = part("Moon", Enum.PartType.Ball, Vector3.new(40, 40, 40),
		Color3.fromRGB(230, 230, 240),
		CFrame.new(-200, 150, 180),
		Enum.Material.SmoothPlastic
	)
	moon.CanCollide = false
	moon.CanQuery = false
	moon.CastShadow = false
	local moonLight = Instance.new("PointLight")
	moonLight.Color = Color3.fromRGB(230, 230, 240)
	moonLight.Brightness = 0.5
	moonLight.Range = 100
	moonLight.Parent = moon
end

-- The boundary: four walls forming a square, +/-200 studs, 40
-- tall, dark purple with a gold top edge. Nobody leaves the map.
-- The walls are solid (CanCollide) so a player cannot walk past
-- them, and the gold edge makes the boundary visible from the
-- ground instead of a surprise invisible wall.
local BOUNDARY_HALF = 200
local BOUNDARY_HEIGHT = 40
local function buildBoundaryWalls()
	local sides = {
		{ name = "North", size = Vector3.new(BOUNDARY_HALF * 2 + 2, BOUNDARY_HEIGHT, 2), pos = Vector3.new(0, BOUNDARY_HEIGHT / 2, -BOUNDARY_HALF) },
		{ name = "South", size = Vector3.new(BOUNDARY_HALF * 2 + 2, BOUNDARY_HEIGHT, 2), pos = Vector3.new(0, BOUNDARY_HEIGHT / 2, BOUNDARY_HALF) },
		{ name = "West", size = Vector3.new(2, BOUNDARY_HEIGHT, BOUNDARY_HALF * 2 + 2), pos = Vector3.new(-BOUNDARY_HALF, BOUNDARY_HEIGHT / 2, 0) },
		{ name = "East", size = Vector3.new(2, BOUNDARY_HEIGHT, BOUNDARY_HALF * 2 + 2), pos = Vector3.new(BOUNDARY_HALF, BOUNDARY_HEIGHT / 2, 0) },
	}
	for _, side in ipairs(sides) do
		local wall = part(
			"BoundaryWall",
			Enum.PartType.Block,
			side.size,
			Color3.fromRGB(40, 28, 60),
			CFrame.new(side.pos)
		)
		wall.Name = "BoundaryWall" .. side.name
		-- A gold strip along the top edge, so the wall reads as a
		-- finished boundary, not a missing chunk of world. Visual
		-- only — it never blocks anyone.
		local trim = part(
			"BoundaryWallEdge",
			Enum.PartType.Block,
			Vector3.new(side.size.X, 1, side.size.Z),
			Color3.fromRGB(255, 200, 60),
			CFrame.new(side.pos + Vector3.new(0, BOUNDARY_HEIGHT / 2, 0)),
			Enum.Material.Neon
		)
		trim.Name = "BoundaryWallEdge" .. side.name
		trim.CanCollide = false
	end
end

-- Dressing: trees, rocks, crystals, hills, flags and meteor
-- rocks, scattered with fixed seeds so the layout is the same
-- every server start. Nothing here blocks a path: rocks keep out
-- of the approach corridors to the bases, and nothing spawns on
-- the belt, the plaza or the crater mouth.
local function buildTrees()
	local rng = Random.new(12345)
	for i = 1, 60 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(70, 190)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		-- Skip the belt corridor and the spawn plaza.
		if math.abs(pos.Z) < 12 and math.abs(pos.X) < 30 then
			continue
		end
		local trunkHeight = rng:NextNumber(4, 7)
		local trunk = part(
			"TreeTrunk",
			Enum.PartType.Cylinder,
			Vector3.new(trunkHeight, 1, 1),
			Color3.fromRGB(120, 80, 40),
			CFrame.new(pos + Vector3.new(0, trunkHeight / 2, 0))
		)
		trunk.CanCollide = false
		local leaves = part(
			"TreeLeaves",
			Enum.PartType.Ball,
			Vector3.new(rng:NextNumber(4, 6), rng:NextNumber(4, 6), rng:NextNumber(4, 6)),
			Color3.fromRGB(60, 160, 80),
			CFrame.new(pos + Vector3.new(0, trunkHeight + 2, 0))
		)
		leaves.CanCollide = false
	end
end

local function buildRocks()
	local rng = Random.new(777)
	for i = 1, 45 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(65, 185)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		-- Keep the approach corridors to the bases clear: a rock in
		-- the corridor is a wall a thief has to walk around. The
		-- corridor runs from the crater (along 40) to the base
		-- (along 130), 8 studs either side of the approach line.
		local onApproach = false
		for baseId = 1, Config.BASE_COUNT do
			local baseAngle = math.rad((baseId - 1) * (360 / Config.BASE_COUNT))
			local dir = Vector3.new(math.cos(baseAngle), 0, math.sin(baseAngle))
			local along = pos:Dot(dir)
			local lateral = (pos - dir * along).Magnitude
			if along >= 40 and along <= 130 and math.abs(lateral) < 8 then
				onApproach = true
				break
			end
		end
		if onApproach then
			continue
		end
		if math.abs(pos.Z) < 12 and math.abs(pos.X) < 30 then
			continue
		end
		local rock = part(
			"Rock",
			Enum.PartType.Block,
			Vector3.new(rng:NextNumber(2, 5), rng:NextNumber(2, 4), rng:NextNumber(2, 5)),
			Color3.fromRGB(120, 110, 130),
			CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Enum.Material.Slate
		)
		rock.CanCollide = false
	end
end

local function buildCrystals()
	local rng = Random.new(999)
	for i = 1, 36 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(60, 180)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if math.abs(pos.Z) < 12 and math.abs(pos.X) < 30 then
			continue
		end
		local height = rng:NextNumber(2, 5)
		local crystal = part(
			"Crystal",
			Enum.PartType.Block,
			Vector3.new(1.5, height, 1.5),
			Color3.fromRGB(120, 200, 255),
			CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), 0, math.rad(rng:NextNumber(-15, 15))),
			Enum.Material.Neon
		)
		crystal.CanCollide = false
		crystal.Transparency = 0.3
	end
end

local function buildHills()
	local rng = Random.new(4242)
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45 + 20)
		local radius = rng:NextNumber(150, 185)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local hill = part(
			"Hill",
			Enum.PartType.Ball,
			Vector3.new(rng:NextNumber(20, 35), rng:NextNumber(6, 10), rng:NextNumber(20, 35)),
			Color3.fromRGB(100, 160, 80),
			CFrame.new(pos + Vector3.new(0, -2, 0)),
			Enum.Material.Grass
		)
		hill.CanCollide = false
	end
end

local function buildPlazaFlags()
	for i = 0, 11 do
		local angle = math.rad(i * 30)
		local pos = Vector3.new(math.cos(angle) * 34, 0, 46 + math.sin(angle) * 34)
		local pole = part(
			"PlazaFlagPole",
			Enum.PartType.Cylinder,
			Vector3.new(6, 0.5, 0.5),
			Color3.fromRGB(72, 62, 92),
			CFrame.new(pos + Vector3.new(0, 3, 0))
		)
		pole.CanCollide = false
		local flagColors = {
			Color3.fromRGB(255, 120, 120),
			Color3.fromRGB(120, 180, 255),
			Color3.fromRGB(120, 255, 150),
			Color3.fromRGB(255, 220, 100),
		}
		local flag = part(
			"PlazaFlag",
			Enum.PartType.Block,
			Vector3.new(0.3, 2, 3),
			flagColors[(i % 4) + 1],
			CFrame.new(pos + Vector3.new(0, 5, 1.5))
		)
		flag.CanCollide = false
	end
end

-- Meteor rocks: six scorched boulders with orange shards, ringing
-- the crater rim where the meteors land. They mark the storm zone.
local function buildMeteorRocks()
	local rng = Random.new(31337)
	for i = 1, 6 do
		local angle = math.rad((i - 1) * 60 + 15)
		local radius = rng:NextNumber(33, 38)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		-- Leave a gap on the +Z side where the belt and spawn path
		-- cross the rim: no rock may sit in the walkway home.
		local x, z = pos.X, pos.Z
		if math.abs(x) < 10 and z > 34 then
			continue
		end
		local rock = part(
			"MeteorRock",
			Enum.PartType.Block,
			Vector3.new(rng:NextNumber(4, 7), rng:NextNumber(3, 5), rng:NextNumber(4, 7)),
			Color3.fromRGB(60, 50, 70),
			CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Enum.Material.Slate
		)
		rock.CanCollide = false
		local shard = part(
			"MeteorShard",
			Enum.PartType.Block,
			Vector3.new(1, rng:NextNumber(2, 4), 1),
			Color3.fromRGB(255, 120, 40),
			CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), 3, rng:NextNumber(-2, 2))),
			Enum.Material.Neon
		)
		shard.CanCollide = false
	end
end

-- Ambient critters: six little space creatures wandering the
-- grass, so the world feels alive between storms. They are pure
-- dressing — small glowing balls on short legs that bob in place.
local function buildCritters()
	local rng = Random.new(2024)
	for i = 1, 6 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(70, 150)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if math.abs(pos.Z) < 12 and math.abs(pos.X) < 30 then
			continue
		end
		local body = part("Critter", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6),
			Color3.fromRGB(140, 255, 140),
			CFrame.new(pos + Vector3.new(0, 1.2, 0)),
			Enum.Material.Neon
		)
		body.CanCollide = false
		body.Transparency = 0.3
		local eye = part("CritterEye", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5),
			Color3.fromRGB(20, 15, 40),
			CFrame.new(pos + Vector3.new(0, 1.5, 0.8))
		)
		eye.CanCollide = false
	end
end

-- The title arch: two posts and a wide board over the spawn path
-- at (0, 46), so the first thing a joining player sees is the
-- game's name. The board is high enough to walk under.
local function buildWorldTitleSign()
	-- The title arch stands ON the spawn→crater sightline at
	-- (0, 46) — at the crater's edge, between the rim at 39 and
	-- spawn at 96 — raised to y=9 so walkers pass under it (the
	-- board bottom at 6 clears a player's head at ~5). The posts
	-- sit at cx +/- 12.5, outside the 22-wide board (half-width
	-- 11), so no post can ever cover the text from any camera.
	local cx, cz = 0, 46
	for _, side in ipairs({ -1, 1 }) do
		local post = part("TitleSignPost", Enum.PartType.Cylinder, Vector3.new(12, 1, 1),
			Color3.fromRGB(72, 62, 92),
			CFrame.new(cx + side * 12.5, 6, cz)
		)
		post.CanCollide = false
	end
	local board = part("WorldTitleSign", Enum.PartType.Block, Vector3.new(22, 6, 1),
		Color3.fromRGB(20, 15, 40),
		CFrame.new(cx, 9, cz)
	)
	board.CanCollide = false
	board.CastShadow = false
	-- A gold trim across the top of the board, with a warm glow so
	-- the title pulses gently and reads from across the map.
	local trim = part("WorldTitleTrim", Enum.PartType.Block, Vector3.new(22.4, 0.8, 1.2),
		Color3.fromRGB(255, 200, 60),
		CFrame.new(cx, 12.3, cz),
		Enum.Material.Neon
	)
	trim.CanCollide = false
	trim.CastShadow = false
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 200, 60)
	glow.Brightness = 1.5
	glow.Range = 25
	glow.Parent = trim
	local gui = Instance.new("BillboardGui")
	gui.Name = "TitleSignGui"
	gui.Size = UDim2.fromOffset(400, 80)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = board
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "SPACE ROCK BRAINROTS!"
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
	titleLabel.TextStrokeTransparency = 0.3
	titleLabel.Parent = gui
end

-- The hero row: the four starter Rotlings on display on one long
-- plinth at (1.75, 0, 82), so a new player sees what they are
-- chasing before they ever grab one. The models are built by the
-- factory, scaled to display height, and marked "display" so no
-- system ever treats them as placed or carried.
local function buildHeroRow()
	local plinth = part("HeroPlinth", Enum.PartType.Block, Vector3.new(21.5, 1, 6), Color3.fromRGB(60, 50, 80), CFrame.new(1.75, 0.5, 82), Enum.Material.Slate)
	plinth.CanCollide = false
	local heroIds = { "gummy", "alfredo", "bloop", "couch" }
	for i, defId in ipairs(heroIds) do
		local pos = Vector3.new(-8 + (i - 1) * 6.5, 2.5, 82)
		local model = RotlingFactory.build(defId, nil, pos)
		if model then
			RotlingFactory.normalizeToHeight(model, Config.PLACED_DISPLAY_HEIGHT)
			model:SetAttribute("State", "display")
			local b = model:FindFirstChildWhichIsA("BasePart")
			if b then
				model:PivotTo(CFrame.new(pos + Vector3.new(0, b.Size.Y / 2 + 0.1, 0)))
			end
			model.Parent = workspace
		end
	end
end

-- The logo stage: a raised dais at (0, 0, 118) with three display
-- Rotlings on it, so the spawn view has a focal point. The models
-- sit ON the dais, not sunk into it: each one is pivoted so its
-- lowest part rests on the stage top.
local function buildLogoStage()
	local stageCf = CFrame.new(0, 0, 118)
	local stage = part("LogoStage", Enum.PartType.Block, Vector3.new(20, 1, 8), Color3.fromRGB(60, 50, 80), stageCf * CFrame.new(0, 0.5, 0), Enum.Material.Slate)
	stage.CanCollide = false
	local logoIds = { "gummy", "alfredo", "bloop" }
	for i, defId in ipairs(logoIds) do
		local x = (i - 2) * 8
		local pos = Vector3.new(x, 2.5, 118)
		local model = RotlingFactory.build(defId, nil, pos)
		if model then
			RotlingFactory.normalizeToHeight(model, Config.PLACED_DISPLAY_HEIGHT)
			model:SetAttribute("State", "display")
			local b = model:FindFirstChildWhichIsA("BasePart")
			if b then
				model:PivotTo(CFrame.new(pos + Vector3.new(0, b.Size.Y / 2 + 0.1, 0)) * CFrame.Angles(0, math.rad(180), 0))
			end
			model.Parent = workspace
		end
	end
end

-- Wind: four drift emitters, one per quadrant, so the air has
-- motion even in calm. setWind turns them up during a storm.
local function buildWind()
	local corners = {
		Vector3.new(-100, 20, -100),
		Vector3.new(100, 20, -100),
		Vector3.new(-100, 20, 100),
		Vector3.new(100, 20, 100),
	}
	for _, corner in ipairs(corners) do
		local emitterPart = part(
			"WindEmitter",
			Enum.PartType.Ball,
			Vector3.new(1, 1, 1),
			Color3.fromRGB(255, 255, 255),
			CFrame.new(corner)
		)
		emitterPart.Transparency = 1
		emitterPart.CanCollide = false
		emitterPart.CanQuery = false
		emitterPart.CastShadow = false
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxassetid://241594820"
		emitter.Rate = 4
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Speed = NumberRange.new(8, 12)
		emitter.Size = NumberSequence.new(0.5)
		emitter.Transparency = NumberSequence.new(0.7)
		emitter.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
		emitter.VelocitySpread = 10
		emitter.Parent = emitterPart
		table.insert(windEmitters, emitter)
	end
end

-- A walkway between two points: a row of flat slabs, so the path
-- reads as a path instead of bare grass.
local function path(from: Vector3, to: Vector3)
	local distance = (to - from).Magnitude
	local steps = math.max(1, math.floor(distance / 4))
	for i = 0, steps do
		local t = i / steps
		local pos = from:Lerp(to, t)
		local slab = part("StonePath", Enum.PartType.Block, Vector3.new(6, 0.2, 4),
			Color3.fromRGB(150, 130, 100),
			CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, math.atan2(to.X - from.X, to.Z - from.Z), 0),
			Enum.Material.Slate
		)
		slab.CanCollide = false
		slab.CastShadow = false
	end
end

-- A fence line between two points: posts every 3 studs with a rail
-- between them. The posts are short and non-colliding — they mark
-- the path, they never block it.
local function fenceLine(from: Vector3, to: Vector3)
	local distance = (to - from).Magnitude
	local steps = math.max(1, math.floor(distance / 3))
	for i = 0, steps do
		local t = i / steps
		local pos = from:Lerp(to, t)
		local post = part(
			"FencePost",
			Enum.PartType.Block,
			Vector3.new(0.6, 3, 0.6),
			Color3.fromRGB(120, 100, 140),
			CFrame.new(pos + Vector3.new(0, 1.5, 0))
		)
		post.CanCollide = false
	end
	local mid = from:Lerp(to, 0.5)
	local rail = part(
		"FenceRail",
		Enum.PartType.Block,
		Vector3.new(0.4, 0.4, distance),
		Color3.fromRGB(120, 100, 140),
		CFrame.new(mid + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.atan2(to.X - from.X, to.Z - from.Z), 0)
	)
	rail.CanCollide = false
end

-- The spawn path: fences along both sides of the walk from the
-- spawn platform (z=78) down to the belt (z=40), and a path from
-- the belt to the shop. The fences are true parallels, 4 studs
-- each side of the path centreline, clear of the crater rim — so
-- the walk home is a corridor, not a maze.
local function buildSpawnPath()
	-- Fence posts every 3 studs along both sides of the path.
	for i = 0, 13 do
		local z = 78 - i * 3
		for _, x in ipairs({ -5, 5 }) do
			local post = part(
				"SpawnPathFence",
				Enum.PartType.Block,
				Vector3.new(0.6, 3, 0.6),
				Color3.fromRGB(120, 100, 140),
				CFrame.new(x, 1.5, z)
			)
			post.CanCollide = false
		end
	end
	fenceLine(Vector3.new(-5, 0, 78), Vector3.new(-5, 0, 40))
	fenceLine(Vector3.new(5, 0, 78), Vector3.new(5, 0, 40))
	-- The path from the belt to the shop, with fences offset 4
	-- studs from its centreline and inset 16 from its ends, so the
	-- fences never crowd the belt or the shop door.
	local shopPathFrom = Vector3.new(0, 0, 40)
	local shopPathTo = Vector3.new(-40, 0, 44)
	local fenceOffset = 4
	local fenceInset = 16
	path(shopPathFrom, shopPathTo)
	local shopDir = (shopPathTo - shopPathFrom).Unit
	local shopPathNormal = Vector3.new(-shopDir.Z, 0, shopDir.X)
	local fenceFrom = shopPathFrom + shopDir * fenceInset + shopPathNormal * fenceOffset
	local fenceTo = shopPathTo - shopDir * fenceInset + shopPathNormal * fenceOffset
	fenceLine(fenceFrom, fenceTo)
	local fenceFrom2 = shopPathFrom + shopDir * fenceInset - shopPathNormal * fenceOffset
	local fenceTo2 = shopPathTo - shopDir * fenceInset - shopPathNormal * fenceOffset
	fenceLine(fenceFrom2, fenceTo2)
end

-- Contract board: three one-shot missions, east of the spawn
-- path at (16, 0, 94), away from the STAR SHOP sign on the west
-- — the two signs overlapped on screen from the plaza. The board
-- is 12 wide, 8 tall, centred at y=6, with a gold backing board
-- behind it so it reads as a framed notice, not a floating panel.
local function buildContractBoard()
	local boardCf = CFrame.new(Vector3.new(16, 0, 94))
	local backing = part("ContractBoardBacking", Enum.PartType.Block, Vector3.new(12.6, 8.6, 0.4),
		Color3.fromRGB(255, 200, 60),
		boardCf * CFrame.new(0, 6, -0.3),
		Enum.Material.Neon
	)
	backing.CanCollide = false
	backing.CastShadow = false
	local board = part("ContractBoard", Enum.PartType.Block, Vector3.new(12, 8, 0.5),
		Color3.fromRGB(20, 15, 40),
		boardCf * CFrame.new(0, 6, 0)
	)
	board.CanCollide = false
	board.CastShadow = false
	-- Two VERTICAL posts at +/- 6.9, outside the 12-wide board
	-- (half-width 6) and its backing — a post through the board
	-- face is a horizontal bar across the text. Each post is 7
	-- tall, centred at y=3.5, standing on the ground.
	for _, x in ipairs({ -6.9, 6.9 }) do
		local post = part("ContractPost", Enum.PartType.Cylinder, Vector3.new(7, 0.8, 0.8),
			Color3.fromRGB(72, 62, 92),
			boardCf * CFrame.new(x, 3.5, 0)
		)
		post.CanCollide = false
	end
	local topTrim = part("ContractBoardTrim", Enum.PartType.Block, Vector3.new(12.4, 0.7, 0.6),
		Color3.fromRGB(255, 200, 60),
		boardCf * CFrame.new(0, 10.3, 0),
		Enum.Material.Neon
	)
	topTrim.CanCollide = false
	topTrim.CastShadow = false
	-- The board's text: a 260x140 billboard, DEPTH-TESTED (not
	-- AlwaysOnTop) so it never floats over the world. Fixed sizes,
	-- not TextScaled: the title is 20px, the body 14px, both
	-- wrapped — TextScaled blows up at close range and the text
	-- becomes unreadable.
	local gui = Instance.new("BillboardGui")
	gui.Name = "ContractBoardGui"
	gui.Size = UDim2.fromOffset(260, 140)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 40
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "ContractBoardTitle"
	title.Size = UDim2.new(1, 0, 0.25, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "⭐ CONTRACT BOARD"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 20
	title.TextWrapped = true
	title.TextColor3 = Color3.fromRGB(255, 225, 90)
	title.TextStrokeTransparency = 0.3
	title.Parent = gui
	local text = Instance.new("TextLabel")
	text.Name = "ContractBoardText"
	text.Size = UDim2.new(1, 0, 0.5, 0)
	text.Position = UDim2.new(0, 0, 0.25, 0)
	text.BackgroundTransparency = 1
	text.Text = "3 contracts at a time.\nFinish one, claim the reward!"
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 14
	text.TextWrapped = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.3
	text.Parent = gui
	local footer = Instance.new("TextLabel")
	footer.Name = "ContractFooter"
	footer.Size = UDim2.new(1, 0, 0.25, 0)
	footer.Position = UDim2.new(0, 0, 0.75, 0)
	footer.BackgroundTransparency = 1
	footer.Text = "Press E to open"
	footer.Font = Enum.Font.FredokaOne
	footer.TextSize = 16
	footer.TextWrapped = true
	footer.TextColor3 = Color3.fromRGB(255, 200, 60)
	footer.TextStrokeTransparency = 0.3
	footer.Parent = gui
	local boardPrompt = Instance.new("ProximityPrompt")
	boardPrompt.Name = "ContractBoardPrompt"
	boardPrompt.ActionText = "View Contracts"
	boardPrompt.ObjectText = "⭐ Contracts — 3 missions"
	boardPrompt.HoldDuration = 0
	boardPrompt.MaxActivationDistance = 12
	boardPrompt.RequiresLineOfSight = false
	boardPrompt.Parent = board
end

function WorldBuilder.build()
	for baseId = 1, Config.BASE_COUNT do
		buildBase(baseId)
	end
	buildCrater()
	buildBelt()
	buildSellArea()
	buildContractBoard()
	buildStarShop()
	buildRebirthAltar()
	buildSpaceship()
	buildMoon()
	buildGroundDetail()
	buildSignposts()
	buildTrees()
	buildRocks()
	buildCrystals()
	buildHills()
	buildPlazaFlags()
	buildMeteorRocks()
	buildCritters()
	buildWorldTitleSign()
	buildHeroRow()
	buildLogoStage()
	buildWind()
	buildSpawnPath()
	buildBoundaryWalls()
	print("[World] Built "
		.. tostring(Config.BASE_COUNT)
		.. " bases, crater, belt, sell pad, contracts, shop, altar, spaceship, moon, ground, signs, trees, rocks, crystals, hills, flags, meteor rocks, critters, title, heroes, logo stage, wind, spawn path, boundary walls")
end

return WorldBuilder
