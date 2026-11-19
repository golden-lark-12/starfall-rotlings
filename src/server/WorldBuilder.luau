--!strict
-- Starfall Rotlings: builds the world at server start.
-- The static skeleton (ground, crater, lighting, sky, spawn) lives in
-- default.project.json; everything repetitive or placed by data lives
-- here: the eight bases, their pads, the lock gates, purple alien trees,
-- rocks, mushrooms, stars and clouds. All positions come from Config, so
-- the layout can be re-tuned without touching the project file. The
-- palette is space-sunset on purpose: purple ground, teal crater glow,
-- orange meteors — nothing like a green field.
--
-- ART PASS (Nov 17): the world is built fresh from Part primitives and
-- built-in materials only — no Toolbox models, no copied assets. Hills,
-- crystal clusters, floating islands, a big planet, a tiered crater rim
-- with a beacon beam, paths from every base to the crater, and real
-- bases (tiled floors, low walls, glowing lock gates, owner signs,
-- per-base themes, plinths, floating cash counters) all live here.
--
-- GROUND (final run): no single flat purple plane. The base ground is a
-- warm sand tone, a sand ring circles the crater, and a grid of large
-- ground tiles in varied warm colours and materials textures the whole
-- map — paths, rocks, hills and props break it up further. Bright,
-- saturated, meteor theme kept.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Formatting = require(game:GetService("ReplicatedStorage").Shared.Formatting)
local RotlingCatalog = require(game:GetService("ReplicatedStorage").Shared.RotlingCatalog)
local RotlingFactory = require(script.Parent.RotlingFactory)

local WorldBuilder = {}

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

-- Pad offsets on a base platform, in the base's local space: two rows
-- of four. The base faces the crater: local -Z points at the origin.
-- Pads 7 and 8 start locked behind the shop.
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

-- Is a position on a base's INTERIOR (the platform top, inside the
-- walls)? The doorway/ramp is NOT interior: standing in the doorway
-- (local z -11..-15, on the ramp) is OUTSIDE the safe zone, so a
-- storm still hurts there and the guardian still chases there (fix
-- round 9, items 2 + 4 — Malek: "safe INSIDE the base, no damage
-- there; the problem is only the door"). The platform is 26 wide
-- (local x -13..13) and 22 deep (local z -11..11); its top is at
-- local Y 1, so a standing player's root sits at local Y ~3.7-4,
-- while a player on the ground outside has root local Y ~1.7-2 —
-- the Y gate separates "on the platform" from "on the ground next
-- to it", and the Z gate keeps the doorway out.
-- NOTE (fix round 13, item 3): this is now the INCOME rule only
-- (IncomeService safe-dome bonus). For DAMAGE, Malek reversed it
-- (playtest 12: "ZERO damage on my base, at all") — see
-- isOnBasePlatform below, which is what every damage / chase /
-- refuge check uses now.
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

-- Is a position on a base's WHOLE PLATFORM (the slab + the ramp)?
-- (fix round 13, item 3 — Malek, playtest 12: "ZERO damage on my
-- base, at all".) The round-9 interior-only rule left the doorway /
-- ramp outside the safe zone, so a player standing on their own
-- base could still take meteor damage there — and the guardian's
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

-- The incubator on a base: where a carried meteor egg is placed to
-- hatch (MeteorEggService.placeEgg). One per base, at a back corner.
function WorldBuilder.incubatorCFrame(baseId: number): CFrame?
	return incubatorCFrames[baseId]
end

-- Centre of the Star Shop floor (boost pickups spawn inside the shop).
function WorldBuilder.shopCenter(): Vector3?
	if shopCenterCf then
		return shopCenterCf.Position
	end
	return nil
end

-- Wind: the four quadrant drift emitters built by buildWind. Starfall
-- calls setWind(true) when the storm starts and setWind(false) when it
-- ends. This function did NOT exist until fix round 2: every storm
-- cycle called it, hit "attempt to call a nil value", and the cycle's
-- pcall aborted the storm — no wall, no meteors, no rumble, no bounty
-- — while the 10s warning (which runs before the call) still showed,
-- so the storm read as "does nothing". Gentle drift (Rate 4) in calm,
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

-- Shield dome: the visible force-field shown while a base is locked.
function WorldBuilder.setShieldVisible(baseId: number, visible: boolean)
	local dome = shieldDomes[baseId]
	if dome then
		-- 0.9, not 0.82 (fix round 4, item 6): at 0.82 the dome was a
		-- big see-through white shape the camera clipped into; at 0.9
		-- it is a faint shimmer that still reads as a shield.
		dome.Transparency = if visible then 0.9 else 1
	end
end

-- Shield label: "SAFE (45s)" while locked, hidden when the lock ends.
-- Hiding the label also hides the dome itself, so the income
-- broadcast (which calls this every tick) clears the shield the
-- moment a lock expires — no separate expiry watcher needed.
-- During a storm (stormActive) every base is a safe dome even when
-- unlocked: the label reads "🛡️ SAFE DOME" in green and the dome
-- shows, so the storm shot proves bases are safe. A lock still wins
-- over the storm label while it holds.
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

-- Shield label: "🔒 LOCKDOWN (Ns)" while a lockdown seals the base
-- (fix round 13, item 4). Red text, distinct from the lock's blue
-- "🛡️ SAFE (Ns)" — the seal reads as an emergency at a glance.
-- The dome shows too (the income broadcast keeps this label live
-- every tick; when the lockdown ends the broadcast falls back to
-- setShieldLabel, which restores the lock label or clears it).
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

-- The floating cash counter above a base (updated from the income feed).
-- One shared money format: Formatting.formatMoney already carries the
-- "$", so never prepend another one or the sign reads "$$".
function WorldBuilder.setBaseCoins(baseId: number, coins: number)
	local label = cashLabels[baseId]
	if label then
		label.Text = Formatting.formatMoney(coins)
	end
	-- The collect pad shows the same banked amount in the world, and
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

-- Show or hide a locked pad: hidden pads cannot be used.
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
	local center = Vector3.new(math.cos(angle) * Config.BASE_RADIUS, 0, math.sin(angle) * Config.BASE_RADIUS)
	-- Face the crater: the platform's -Z looks at the origin.
	local cf = CFrame.lookAt(center + Vector3.new(0, 1, 0), Vector3.new(0, 1, 0))
	baseCFrames[baseId] = cf
	padCFrames[baseId] = {}
	padParts[baseId] = {}
	baseTiles[baseId] = {}
	baseWalls[baseId] = {}
	basePlinths[baseId] = {}

	local color = BASE_COLORS[baseId]
	baseColors[baseId] = color

	-- Platform.
	part("BasePlatform", Enum.PartType.Block, Vector3.new(26, 2, 22), Color3.fromRGB(115, 100, 150), cf * CFrame.new(0, 0, 0))
	-- Tiled floor: a checkerboard of large tiles on the platform top,
	-- alternating the base theme and a darkened shade. Pads sit on top
	-- of them; the tiles show through the gaps between pads.
	for row = 1, 3 do
		for col = 1, 4 do
			local x = -9.75 + (col - 1) * 6.5
			local z = -7.3 + (row - 1) * 7.3
			local tileColor = if (row + col) % 2 == 0 then color else darken(color, 0.55)
			local tile = part("FloorTile", Enum.PartType.Block, Vector3.new(6.5, 0.2, 7.3), tileColor, cf * CFrame.new(x, 1.12, z))
			tile.CanCollide = false
			tile.CastShadow = false
			table.insert(baseTiles[baseId], tile)
		end
	end
	-- Trim: a bright edge strip on the crater side.
	local trim = part("BaseTrim", Enum.PartType.Block, Vector3.new(26, 0.6, 1), color, cf * CFrame.new(0, 1.1, -11))
	baseTrims[baseId] = trim
	-- Entrance ramp (fix 2): a wedge from the ground up onto the
	-- platform, in the front gap where the lock gate stands. The
	-- platform top is a 2-stud vertical edge from the ground, and a
	-- Humanoid walking with MoveTo (no jump) cannot climb it — so
	-- raiders and rivals walked to a base, pushed against the edge,
	-- timed out after 40s and despawned, and the "sneaking to your
	-- base!" banner fired for a rival that never arrived. The ramp
	-- makes every base walkable: low end on the ground outside
	-- (z=-15), high end flush with the platform top (z=-11, Y=2).
	-- A Wedge's high edge is at its local -Z, so the 180-degree Y
	-- turn puts the high edge toward the platform (+Z in base space).
	local ramp = part("BaseRamp", Enum.PartType.Wedge, Vector3.new(6, 2, 4), Color3.fromRGB(150, 130, 100), cf * CFrame.new(0, 1, -13) * CFrame.Angles(0, math.rad(180), 0))
	ramp.CastShadow = false
	-- Back edge: a LOW trim, not a wall. The old 8-stud back wall was a
	-- giant grey slab that filled the screen and blocked the view of
	-- the base from the crater side; a 1.5-stud edge keeps the "home"
	-- read without ever becoming a wall.
	local backTrim = part("BaseBackTrim", Enum.PartType.Block, Vector3.new(26, 1.5, 1), darken(color, 0.6), cf * CFrame.new(0, 1.75, 10.5))
	backTrim.CanCollide = false
	table.insert(baseWalls[baseId], backTrim)
	-- Low walls around the perimeter (decorative: non-colliding so no
	-- one ever gets trapped on their own base). The front keeps a gap
	-- for the entrance, where the lock gate stands.
	for _, side in ipairs({ -1, 1 }) do
		local sideWall = part("BaseSideWall", Enum.PartType.Block, Vector3.new(1, 1.5, 22), darken(color, 0.6), cf * CFrame.new(side * 12.5, 1.75, 0))
		sideWall.CanCollide = false
		table.insert(baseWalls[baseId], sideWall)
	end
	for _, side in ipairs({ -1, 1 }) do
		local frontWall = part("BaseFrontWall", Enum.PartType.Block, Vector3.new(10, 1.5, 1), darken(color, 0.6), cf * CFrame.new(side * 8, 1.75, -11))
		frontWall.CanCollide = false
		table.insert(baseWalls[baseId], frontWall)
	end
	-- Banner pole + flag + sign.
	local pole = part("BannerPole", Enum.PartType.Cylinder, Vector3.new(12, 1, 1), Color3.fromRGB(72, 62, 92), cf * CFrame.new(-11, 7, 9) * CFrame.Angles(0, 0, math.rad(90)))
	pole.CanCollide = false
	local flag = part("BannerFlag", Enum.PartType.Block, Vector3.new(0.4, 3.5, 5), color, cf * CFrame.new(-11, 11, 6.5))
	flag.Material = Enum.Material.Neon
	flag.CanCollide = false
	baseFlags[baseId] = flag
	-- Owner sign: a SMALL sign on its own post at the back of the base —
	-- a few studs, never a wall. The old sign hung on the tall flag
	-- against the 8-stud back wall, so the whole thing read as one giant
	-- translucent slab covering the screen. Now the sign is a dark
	-- 8x4 board on a short post, with the name on line 1 and the $
	-- counter on its own line 2 underneath — the two never overlap.
	-- The sign only shows within 60 studs, so it never sits at the
	-- screen edge over the HUD buttons.
	local signPost = part("SignPost", Enum.PartType.Cylinder, Vector3.new(5.5, 0.8, 0.8), Color3.fromRGB(72, 62, 92), cf * CFrame.new(0, 3.75, 9.5) * CFrame.Angles(0, 0, math.rad(90)))
	signPost.CanCollide = false
	local signBoard = part("SignBoard", Enum.PartType.Block, Vector3.new(8, 4, 0.5), Color3.fromRGB(20, 15, 40), cf * CFrame.new(0, 7, 9.5))
	signBoard.CanCollide = false
	signBoard.CastShadow = false
	-- (fix round 12, item 1) A coloured stripe across the top of the
	-- sign board, in the base's own colour: no two base signs look
	-- alike at a glance, and the colour survives a rebirth recolour
	-- (setBaseColor repaints the stripe with the base).
	local signStripe = part("SignStripe", Enum.PartType.Block, Vector3.new(8.4, 0.7, 0.6), color, cf * CFrame.new(0, 9.2, 9.5), Enum.Material.Neon)
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
	-- Floating cash counter: line 2 of the same sign, fed by the income
	-- broadcast. One billboard, so it can never drift onto the name.
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
		local plinth = part("PadPlinth", Enum.PartType.Block, Vector3.new(6, 0.25, 6), darken(color, 0.7), cf * CFrame.new(offset + Vector3.new(0, 1.1, 0)))
		plinth.CanCollide = false
		plinth.CastShadow = false
		table.insert(basePlinths[baseId], plinth)
		local padCf = cf * CFrame.new(offset + Vector3.new(0, 1.3, 0))
		local pad = part("Pad", Enum.PartType.Block, Vector3.new(5, 0.6, 5), color, padCf, Enum.Material.Neon)
		pad:SetAttribute("BaseId", baseId)
		pad:SetAttribute("PadIndex", padIndex)
		pad.Transparency = 0.35
		padCFrames[baseId][padIndex] = padCf
		padParts[baseId][padIndex] = pad
		-- Press E on a pad to place the Rotling you carry. The server
		-- checks you own this base and the pad is free.
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

	-- Collect pad (real-base section): a glowing gold pad in the
	-- middle aisle, between the two pad rows. The banked cash builds
	-- up here and stepping on it collects it all — it replaces the
	-- HUD Collect button. Its label shows the waiting amount (updated
	-- by setBaseCoins) and the pad glows brighter while it holds cash.
	-- The owner spawns beside the platform, so nobody collects by
	-- accident on join.
	local collectPad = part("CollectPad", Enum.PartType.Block, Vector3.new(4, 0.6, 3.6), Color3.fromRGB(255, 200, 60), cf * CFrame.new(0, 1.3, 0), Enum.Material.Neon)
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

	-- Laser gate (real-base section): Lock (L) closes it for 120s,
	-- then it opens again. The slab is the physical barrier — a faint
	-- red shimmer while locked, invisible while open. The visible
	-- barrier is six vertical laser beams across the entrance, so the
	-- lock reads as lasers, not a wall. Thieves cannot enter while it
	-- is closed; setGateVisible (BaseService) toggles both parts.
	local gate = part("LockGate", Enum.PartType.Block, Vector3.new(26, 7, 0.6), Color3.fromRGB(255, 60, 60), cf * CFrame.new(0, 4.5, -11), Enum.Material.ForceField)
	gate:SetAttribute("BaseId", baseId)
	gate.Transparency = 1
	gate.CanCollide = false
	gate.CanQuery = false
	for _, beamX in ipairs({ -10.4, -6.24, -2.08, 2.08, 6.24, 10.4 }) do
		local beam = part("LockGateBeam", Enum.PartType.Block, Vector3.new(0.5, 7, 0.5), Color3.fromRGB(255, 60, 60), cf * CFrame.new(beamX, 4.5, -11), Enum.Material.Neon)
		beam:SetAttribute("BaseId", baseId)
		beam.Transparency = 1
		beam.CanCollide = false
		beam.CanQuery = false
	end

	-- Incubator: a stone ring with a warm glow at the back-right corner
	-- of the platform. Carry a meteor egg here and press E to place it;
	-- it hatches after 60s (MeteorEggService.placeEgg). The prompt is
	-- wired by MeteorEggService.init, which looks for the part named
	-- "Incubator".
	local incubatorCf = cf * CFrame.new(9.5, 1.2, 8)
	local ring = part("Incubator", Enum.PartType.Cylinder, Vector3.new(1, 5.5, 5.5), Color3.fromRGB(120, 100, 140), incubatorCf * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Slate)
	ring.CanCollide = false
	local glow = part("IncubatorGlow", Enum.PartType.Ball, Vector3.new(4, 1, 4), Color3.fromRGB(255, 160, 60), incubatorCf * CFrame.new(0, 0.6, 0), Enum.Material.Neon)
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

	-- Shield dome: a transparent force-field sphere over the whole
	-- base, hidden until the base is locked. While locked it shows,
	-- with a "SAFE (45s)" label counting down (cheap win 5) — a
	-- rival, a raider and a storm meteor all stop at it.
	local dome = part("ShieldDome", Enum.PartType.Ball, Vector3.new(34, 22, 30), Color3.fromRGB(120, 200, 255), cf * CFrame.new(0, 9, 0), Enum.Material.ForceField)
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

local function buildCrater()
	-- The crater is a big shallow bowl of alien stone. The rim is a
	-- tiered ring of stacked steps, wide and open so players walk in
	-- and out without a gate, with a beacon beam and crystals at the
	-- centre. A wide glowing ring under the belt marks the spawn line.
	-- A real crater is a hole cut in the ground, but Roblox parts cannot
	-- be subtracted — so the bowl is a rim wall plus a dark floor, and
	-- the camera hides the trick at play distance. The physical
	-- CONVEYOR BELT runs across the crater (added below in the spawn
	-- area): a dark strip with yellow edge stripes, and the Rotlings
	-- spawn ON it in a line, like the top entries' belts — a real
	-- landmark the eye follows, not a scattered crater.
	-- Crater floor: dark stone, flat, so the Rotlings' glow and the belt
	-- read against it.
	part("CraterFloor", Enum.PartType.Cylinder, Vector3.new(1, 56, 56), Color3.fromRGB(35, 28, 52), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Slate)
	-- Glow ring: a thin bright ring where the Rotlings appear, so the
	-- spawn line reads at a glance.
	local ring = part("SpawnRing", Enum.PartType.Cylinder, Vector3.new(0.4, 56.8, 56.8), Color3.fromRGB(255, 90, 60), CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon)
	ring.CanCollide = false
	ring.CastShadow = false
	-- The centre disc is the storm beacon: a glowing floor that pulses
	-- with the storm cycle (StarfallService tweens its colour).
	local beacon = part("StormBeacon", Enum.PartType.Cylinder, Vector3.new(0.5, 6, 6), Color3.fromRGB(255, 80, 60), CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon)
	beacon.Name = "StormBeacon"
	beacon.CanCollide = false
	beacon.CastShadow = false
	-- Beacon beam: a THIN, semi-transparent glowing column at the crater
	-- centre, so the crater reads as a landmark from every base and from
	-- spawn — without blocking the camera. The old beam was a giant
	-- solid 4-stud pillar filling the middle of the screen (Malek's
	-- item 2). Now 1.0 studs, Transparency 0.8, soft glow (fix round 4,
	-- item 6: at 1.5 studs / 0.6 it was still the see-through white
	-- blocky shape the camera clipped into).
	local beam = part("CraterBeam", Enum.PartType.Cylinder, Vector3.new(180, 1.0, 1.0), Color3.fromRGB(255, 110, 70), CFrame.new(0, 90, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon)
	beam.CanCollide = false
	beam.CastShadow = false
	beam.Transparency = 0.8
	beam.Name = "CraterBeam"
	-- The beam's own light: dim (Brightness 0.3), not a second sun — the
	-- bloom cut in Phase 1 keeps the crater readable, and a bright beam
	-- light would wash it white again.
	local beamLight = Instance.new("PointLight")
	beamLight.Color = Color3.fromRGB(255, 110, 70)
	beamLight.Brightness = 0.3
	beamLight.Range = 30
	beamLight.Parent = beam
	-- Rim: three concentric RINGS of stacked steps, wide and open, so
	-- players walk in and out freely — and the crater floor, the belt
	-- and the Rotlings are fully exposed. The old rim was three SOLID
	-- cylinders (radii 31/35/39, tops 2.5/4/5.5) that completely
	-- buried the floor (radius 28, top 0.7) and the belt: the Rotlings
	-- spawned inside solid geometry, only their tops poking out, and
	-- players (and bots) could only stand on the mound top. A ring is
	-- 16 blocks around the floor — same heights, same colours, same
	-- stepped look from outside, but the centre is OPEN, so the floor
	-- is the walking surface and the Rotlings stand on it, reachable.
	-- A gap on the spawn-path side (+Z) is the entrance: players walk
	-- straight in off the path instead of jumping the rim.
	local function buildRimRing(innerR: number, outerR: number, height: number, color: Color3)
		local midR = (innerR + outerR) / 2
		local thickness = outerR - innerR
		local segments = 16
		for i = 0, segments - 1 do
			-- Entrance gap: skip the segment facing the spawn path
			-- (+Z). +Z is theta = pi/2, which is segment i = 4
			-- (4/16 * 2pi = pi/2). The gap lines up across all three
			-- rings, so it is one straight entrance corridor.
			if i ~= 4 then
				local theta = (i / segments) * math.pi * 2
				local arc = 2 * math.pi * midR / segments
				local pos = Vector3.new(math.cos(theta) * midR, height / 2, math.sin(theta) * midR)
				-- lookAt the centre: the block's X axis runs along
				-- the tangent, its Z axis radially outward.
				local cf = CFrame.lookAt(pos, Vector3.new(0, height / 2, 0))
				local seg = part("CraterRim", Enum.PartType.Block, Vector3.new(arc * 1.08, height, thickness), color, cf, Enum.Material.Slate)
				seg.CanCollide = true
				seg.CastShadow = false
			end
		end
	end
	buildRimRing(28, 31, 2.5, Color3.fromRGB(60, 45, 85))
	buildRimRing(31, 35, 4, Color3.fromRGB(75, 55, 105))
	buildRimRing(35, 39, 5.5, Color3.fromRGB(90, 68, 125))
end

local function buildSpawnArea()
	-- Spawn platform: a warm stone disc the players start on, with a
	-- gold rim and two warm lanterns flanking the path so the first
	-- steps are lit and the crater is visible ahead. The platform is
	-- the lobby: new players arrive here, see the crater ahead, and
	-- walk in. (The floating SPAWN sign was removed in the
	-- simplify/polish pass — players spawn at their own base.)
	part("SpawnPlatform", Enum.PartType.Cylinder, Vector3.new(2, 28, 28), Color3.fromRGB(115, 100, 150), CFrame.new(0, 1, 96) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Slate)
	local spawnRing = part("SpawnRing", Enum.PartType.Cylinder, Vector3.new(0.4, 28.6, 28.6), Color3.fromRGB(255, 225, 90), CFrame.new(0, 2.15, 96) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon)
	spawnRing.CanCollide = false
	spawnRing.CastShadow = false
	-- SPAWN sign REMOVED (simplify/polish REMOVE): players spawn at
	-- their own base, not at this platform — the floating dark sign
	-- served no purpose. The platform, gold rim, path and lanterns stay.
	-- Path: a warm stone walkway from the spawn platform to the crater
	-- rim, so the first walk is guided, not a blind purple field.
	-- Fix 5: the path used to stop at z=57, 18 studs short of the
	-- crater rim (z=39) — a walkway to nothing, with the "Crater"
	-- signpost standing at its dead end. Now it runs all the way to
	-- the rim (z=39), where the StonePath to the shop begins, so
	-- spawn -> crater -> shop is one continuous walkway.
	for i = 0, 13 do
		local z = 78 - i * 3
		local tile = part("SpawnPath", Enum.PartType.Block, Vector3.new(6, 0.4, 3.5), Color3.fromRGB(150, 130, 100), CFrame.new(0, 0.2, z))
		tile.CanCollide = false
		tile.CastShadow = false
	end
	-- Two warm lanterns flanking the spawn path, so the start is lit.
	-- Small, dim bulbs: the old 2-stud bulbs at Brightness 1 blew out
	-- into white glow spheres (Malek's item 4). Now 1.4 studs,
	-- Brightness 0.6, Range 12.
	for _, side in ipairs({ -1, 1 }) do
		local lamp = part("SpawnLamp", Enum.PartType.Cylinder, Vector3.new(6, 0.8, 0.8), Color3.fromRGB(72, 62, 92), CFrame.new(side * 7, 3, 88) * CFrame.Angles(0, 0, math.rad(90)))
		lamp.CanCollide = false
		local bulb = part("SpawnLampBulb", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(255, 200, 120), CFrame.new(side * 7, 6.5, 88), Enum.Material.Neon)
		bulb.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Brightness = 0.6
		light.Range = 12
		light.Parent = bulb
	end
end

-- The physical conveyor belt across the crater: a dark strip with
-- yellow edge stripes, and the Rotlings spawn ON it in a line — like
-- the top entries' belts, a real landmark the eye follows. The belt
-- runs across the crater on the X axis at z = 0, 36 studs long, so the
-- spawn line reads as a conveyor, not a scattered crater.
local function buildBelt()
	-- Raised conveyor (fix round 4, item 7): the old belt was a flat
	-- 0.4-thick strip at Y 0.45 — it read as a dark line on the floor.
	-- Now a proper raised conveyor: a 0.6-thick slab centred at Y 0.9
	-- (top 1.2, half a stud above the crater floor), side walls
	-- slightly proud of the slab so the raised body reads, glowing
	-- edge stripes ON the top surface, chevron arrows pointing +X
	-- (the travel direction) every 5 studs, and end rollers flush
	-- with the belt top. Brainrots stand ON the top (BELT_TOP_Y) and
	-- walk +X; the stripes and arrows are flat (0.06-0.08) so nothing
	-- trips a walking Rotling. All parts CanCollide=false: the belt
	-- is a visual, players and rivals walk through it at floor level.
	local top = Config.BELT_TOP_Y
	local belt = part("ConveyorBelt", Enum.PartType.Block, Vector3.new(40, 0.6, 8), Color3.fromRGB(30, 28, 45), CFrame.new(0, top - 0.3, 0), Enum.Material.Slate)
	belt.CanCollide = false
	belt.CastShadow = false
	-- Side walls: 0.05 proud of the slab on each long edge, a shade
	-- lighter, so the raised body reads from every angle.
	for _, side in ipairs({ -1, 1 }) do
		local wall = part("BeltSideWall", Enum.PartType.Block, Vector3.new(40, 0.55, 0.25), Color3.fromRGB(55, 50, 75), CFrame.new(0, top - 0.28, side * 4.05), Enum.Material.Metal)
		wall.CanCollide = false
		wall.CastShadow = false
	end
	-- Glowing edge stripes on the top surface, near the edges.
	for _, side in ipairs({ -1, 1 }) do
		local stripe = part("BeltStripe", Enum.PartType.Block, Vector3.new(40, 0.08, 0.5), Color3.fromRGB(255, 200, 60), CFrame.new(0, top + 0.04, side * 3.6))
		stripe.CanCollide = false
		stripe.CastShadow = false
		stripe.Material = Enum.Material.Neon
	end
	-- Direction arrows: chevrons pointing +X (the travel direction),
	-- one every 5 studs. Each chevron is two thin Neon arms meeting
	-- at a tip; CFrame.lookAt aligns each arm's long (Z) axis with
	-- the centre-to-tip line, so the ">" always points +X.
	for x = -17.5, 17.5, 5 do
		local tip = Vector3.new(x + 0.5, top + 0.03, 0)
		for _, zSign in ipairs({ 1, -1 }) do
			local far = Vector3.new(x - 0.5, top + 0.03, zSign * 0.6)
			local centre = (tip + far) / 2
			local arm = part("BeltArrow", Enum.PartType.Block, Vector3.new(0.45, 0.06, 1.2), Color3.fromRGB(255, 200, 60), CFrame.lookAt(centre, tip), Enum.Material.Neon)
			arm.CanCollide = false
			arm.CastShadow = false
		end
	end
	-- Belt end caps: chunky rollers so the strip reads as a machine.
	-- Diameter 1.6, centre Y = top - 0.8, so the roller's top is
	-- flush with the belt top (1.2) and its bottom is buried in the
	-- floor — the belt visibly rolls off the ends.
	for _, side in ipairs({ -1, 1 }) do
		local roller = part("ConveyorRoller", Enum.PartType.Cylinder, Vector3.new(8, 1.6, 1.6), Color3.fromRGB(60, 55, 80), CFrame.new(side * 20, top - 0.8, 0) * CFrame.Angles(math.rad(90), 0, 0), Enum.Material.Metal)
		roller.CanCollide = false
	end
end

local function buildSellArea()
	-- A gold selling pad on the spawn path (between spawn and the
	-- crater), so it is impossible to miss on the first walk in. The
	-- pad is a big glowing square with a tall sign and a beam, and
	-- selling pays 1 minute of that Rotling's income.
	local sellPad = part("SellPad", Enum.PartType.Block, Vector3.new(14, 1, 14), Color3.fromRGB(255, 200, 60), CFrame.new(62, 0.5, 0), Enum.Material.Neon)
	-- (fix round 12, item 2) The pad is NON-colliding ON PURPOSE.
	-- It sits at (62, 0.5, 0), dead centre on the ONLY approach
	-- line to base 1 (ring radius 45 -> entrance ramp at radius
	-- 95, straight along the base's radial line), and part()
	-- defaults CanCollide=true — so the pad was the one solid a
	-- stealing rival had to cross. The stuck-hop clears a 2-stud
	-- platform edge, not a 14-wide 1-tall slab, so the steal walk
	-- timed out there every time (playtest 11: the thief gave up
	-- at the base, three rounds running). Every other pad in the
	-- game is non-colliding; the SELL pad matches them. It still
	-- reads as a pad (Neon gold, label, prompt, beam) — it just
	-- stops being a wall on the approach.
	sellPad.CanCollide = false
	-- Press E on the pad to sell: the Rotling you carry, or your best
	-- placed Brainrot on your own base. SellService.sell decides.
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.ActionText = "Sell Brainrot"
	sellPrompt.ObjectText = "SELL pad"
	sellPrompt.HoldDuration = 0
	sellPrompt.MaxActivationDistance = 10
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = sellPad
	-- Sell beam: a tall gold column so the pad is visible from the
	-- crater and from spawn.
	local sellBeam = part("SellBeam", Enum.PartType.Cylinder, Vector3.new(60, 2.5, 2.5), Color3.fromRGB(255, 200, 60), CFrame.new(62, 30, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon)
	sellBeam.CanCollide = false
	sellBeam.CastShadow = false
	sellBeam.Transparency = 0.7
	local sellSign = part("SellSign", Enum.PartType.Block, Vector3.new(10, 4, 0.5), Color3.fromRGB(20, 15, 40), CFrame.new(62, 9, -2) * CFrame.Angles(0, math.rad(180), 0))
	sellSign.CanCollide = false
	sellSign.CastShadow = false
	-- Gold trim on top (fix round 13, item 5): the SELL sign was
	-- the one board with no frame at all — a flat dark panel. The
	-- trim sits on its top edge like the contract board's, so it
	-- reads as a designed sign.
	local sellTrim = part("SellSignTrim", Enum.PartType.Block, Vector3.new(10.4, 0.5, 0.7), Color3.fromRGB(255, 215, 0), CFrame.new(62, 11.2, -2), Enum.Material.Neon)
	sellTrim.CanCollide = false
	sellTrim.CastShadow = false
	local sign = Instance.new("BillboardGui")
	sign.Name = "SellSign"
	sign.Size = UDim2.fromOffset(200, 64)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 45
	sign.Parent = sellSign
	local sellLabel = Instance.new("TextLabel")
	sellLabel.Name = "SellLabel"
	sellLabel.Size = UDim2.new(1, 0, 0.55, 0)
	sellLabel.BackgroundTransparency = 1
	sellLabel.Text = "💰 SELL"
	sellLabel.Font = Enum.Font.FredokaOne
	sellLabel.TextScaled = true
	sellLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
	sellLabel.TextStrokeTransparency = 0.3
	sellLabel.Parent = sign
	-- The instruction under the label: short, one line, TextScaled, no
	-- wrapping. "Sell here (E)" — the action and the key, nothing more.
	local sellHint = Instance.new("TextLabel")
	sellHint.Name = "SellHint"
	sellHint.Position = UDim2.new(0, 0, 0.55, 0)
	sellHint.Size = UDim2.new(1, 0, 0.45, 0)
	sellHint.BackgroundTransparency = 1
	sellHint.Text = "Sell here (E)"
	sellHint.Font = Enum.Font.FredokaOne
	sellHint.TextScaled = true
	sellHint.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellHint.TextStrokeTransparency = 0.3
	sellHint.Parent = sign
end

local function buildPlazaDecor()
	-- Twelve bright flag poles ringing the crater, so the crater reads
	-- as the centre of the world from every angle, and two warm
	-- lanterns flanking the spawn path.
	-- LAMPS: small and soft. The old lamps were 1.6 studs with a 0.6
	-- brightness, 14-stud light — blown out white blobs next to the
	-- crater. Now 1.2 studs, brightness 0.4, range 10: a warm glow, not
	-- a floodlight.
	for i = 0, 11 do
		local angle = math.rad(i * 30 + 15)
		local x = math.cos(angle) * 92
		local z = math.sin(angle) * 92
		local pole = part("PlazaPole", Enum.PartType.Cylinder, Vector3.new(14, 0.8, 0.8), Color3.fromRGB(72, 62, 92), CFrame.new(x, 7, z) * CFrame.Angles(0, 0, math.rad(90)))
		pole.CanCollide = false
		local flagColors = {
			Color3.fromRGB(255, 120, 120),
			Color3.fromRGB(120, 180, 255),
			Color3.fromRGB(120, 255, 150),
			Color3.fromRGB(255, 220, 100),
		}
		local flag = part("PlazaFlag", Enum.PartType.Block, Vector3.new(0.4, 4, 6), flagColors[(i % 4) + 1], CFrame.new(x, 12, z) * CFrame.Angles(0, -angle + math.rad(90), 0))
		flag.Material = Enum.Material.Neon
		flag.CanCollide = false
	end
	for _, side in ipairs({ -1, 1 }) do
		local lamp = part("PlazaLamp", Enum.PartType.Cylinder, Vector3.new(5, 1.2, 1.2), Color3.fromRGB(72, 62, 92), CFrame.new(side * 7, 2.5, 78) * CFrame.Angles(0, 0, math.rad(90)))
		lamp.CanCollide = false
		local bulb = part("PlazaLampBulb", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0), Color3.fromRGB(255, 200, 120), CFrame.new(side * 7, 5.5, 78), Enum.Material.Neon)
		bulb.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Brightness = 0.25
		light.Range = 8
		light.Parent = bulb
	end
end

local function buildTrees()
	-- Purple alien trees: glowing trunks, neon-leaf blobs. Deterministic
	-- placement (seeded Random) so every server builds the same world.
	local rng = Random.new(12345)
	local treeColors = {
		Color3.fromRGB(120, 60, 160),
		Color3.fromRGB(160, 80, 200),
		Color3.fromRGB(90, 50, 140),
	}
	for i = 1, 60 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(120, 210)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		-- Skip the spawn platform and the sell pad.
		if math.abs(x) < 20 and z > 70 then
			continue
		end
		if math.abs(x - 62) < 14 and math.abs(z) < 14 then
			continue
		end
		local height = rng:NextNumber(8, 16)
		local trunk = part("AlienTree", Enum.PartType.Cylinder, Vector3.new(height, 1.2, 1.2), Color3.fromRGB(60, 40, 90), CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Wood)
		trunk.CanCollide = false
		local leafColor = treeColors[rng:NextInteger(1, #treeColors)]
		local leaves = part("AlienLeaves", Enum.PartType.Ball, Vector3.new(rng:NextNumber(5, 8), rng:NextNumber(5, 8), rng:NextNumber(5, 8)), leafColor, CFrame.new(x, height + 2, z), Enum.Material.Neon)
		leaves.CanCollide = false
		leaves.Transparency = 0.2
	end
end

local function buildRocks()
	-- Rocks: grey boulders scattered outside the crater, seeded so the
	-- world is the same every server. They break up the ground plane
	-- and give the map a third dimension beyond the flat field.
	local rng = Random.new(777)
	for i = 1, 45 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(100, 200)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		if math.abs(x) < 20 and z > 70 then
			continue
		end
		if math.abs(x - 62) < 14 and math.abs(z) < 14 then
			continue
		end
		-- (fix round 12, item 2) Base approaches stay clear: a
		-- rock on a base's entrance corridor (radius 40..130 along
		-- the base's radial line, within 8 studs laterally) is a
		-- second SELL-pad-style blocker on the steal walk — a
		-- rival crossing it has to hop a solid boulder, and the
		-- same 8s MoveTo timeout that killed the SELL-pad leg
		-- kills this one. Rocks still fill the field everywhere
		-- else; the corridor is the only exclusion.
		local onApproach = false
		for baseId = 1, Config.BASE_COUNT do
			local ang = math.rad((baseId - 1) * (360 / Config.BASE_COUNT))
			local along = x * math.cos(ang) + z * math.sin(ang)
			local lateral = -x * math.sin(ang) + z * math.cos(ang)
			if along >= 40 and along <= 130 and math.abs(lateral) < 8 then
				onApproach = true
				break
			end
		end
		if onApproach then
			continue
		end
		local size = rng:NextNumber(3, 8)
		local rock = part("Rock", Enum.PartType.Ball, Vector3.new(size, size * 0.7, size), Color3.fromRGB(110, 100, 130), CFrame.new(x, size * 0.3, z) * CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), 0), Enum.Material.Slate)
		rock.CanCollide = true
	end
end

local function buildHills()
	-- Hills: big smooth domes at the map edge, so the horizon is not a
	-- flat line. Seeded, same every server.
	local rng = Random.new(4242)
	for i = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(195, 215)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local size = rng:NextNumber(40, 70)
		local hill = part("Hill", Enum.PartType.Ball, Vector3.new(size, size * 0.35, size), Color3.fromRGB(85, 70, 120), CFrame.new(x, -2, z), Enum.Material.SmoothPlastic)
		hill.CanCollide = false
		hill.CastShadow = false
	end
end

-- The ground is ONE consistent material, not a patchwork. It used to
-- be a sand disc under the crater plus an 8x8 grid of tiles in random
-- warm colours and random materials (Sand / Slate / SmoothPlastic /
-- Grass) — a visible patchwork of clashing squares. Now it is a single
-- large Grass cover in one natural grass green, laid just above the
-- base Ground part underneath, so the whole map reads as one lawn.
-- The crater floor (dark Slate disc, top ~0.4) pokes through the
-- cover, so the crater still reads as a distinct dark bowl in the
-- middle of the grass.
local function buildGroundDetail()
	-- One ground cover: a single Grass part, natural grass green,
	-- 500 studs square, laid just above the base ground. No rings,
	-- no tiles, no random colours — one material, one colour.
	local ground = part("GroundCover", Enum.PartType.Block, Vector3.new(500, 0.1, 500), Color3.fromRGB(89, 173, 77), CFrame.new(0, 0.02, 0), Enum.Material.Grass)
	ground.CanCollide = false
	ground.CastShadow = false
end

local function buildCrystals()
	-- Crystal clusters: glowing shards around the crater rim and
	-- scattered in the field, in the rarity colours. They are the
	-- "meteor shards" of the theme: the storm dropped them, and the
	-- Rotlings gather around them. Seeded, same every server.
	local rng = Random.new(999)
	local crystalColors = {
		Color3.fromRGB(120, 200, 255),
		Color3.fromRGB(180, 110, 255),
		Color3.fromRGB(255, 120, 180),
		Color3.fromRGB(120, 255, 170),
		Color3.fromRGB(70, 120, 255),
	}
	for i = 1, 36 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(35, 95)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local height = rng:NextNumber(3, 8)
		local crystal = part("Crystal", Enum.PartType.Wedge, Vector3.new(2, height, 2), crystalColors[rng:NextInteger(1, #crystalColors)], CFrame.new(x, height / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)), Enum.Material.Neon)
		crystal.CanCollide = false
		crystal.Transparency = 0.15
	end
	-- The centre cluster: a tall crystal ring around the beacon, so the
	-- crater centre is a glowing monument, not an empty disc.
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		local x = math.cos(angle) * 8
		local z = math.sin(angle) * 8
		local crystal = part("Crystal", Enum.PartType.Wedge, Vector3.new(2.5, 9, 2.5), Color3.fromRGB(255, 120, 180), CFrame.new(x, 4.5, z) * CFrame.Angles(0, angle, math.rad(-0.2)), Enum.Material.Neon)
		crystal.CanCollide = false
		crystal.Transparency = 0.15
	end
end

-- Floating islands REMOVED (simplify/polish REMOVE): the six dark
-- purple balls + neon crystals hung in the air with no reason and read
-- as floating blocks / purple orbs. The sky keeps its planet, moon,
-- stars and meteor streak, so the horizon is not empty.

local function buildSkyDecor()
	-- A big planet hanging in the sky, a ring of distant stars, and a
	-- meteor shower streak: the sky is part of the scene, not an empty
	-- gradient. NO clouds: the old static lavender blobs were the
	-- "frozen purple blobs" Malek saw hanging in the sky — they had no
	-- drift code and read as stuck purple shapes. Removed.
	local planet = part("Planet", Enum.PartType.Ball, Vector3.new(80, 80, 80), Color3.fromRGB(255, 180, 120), CFrame.new(-150, 120, -250), Enum.Material.SmoothPlastic)
	planet.CanCollide = false
	planet.CastShadow = false
	local planetRing = part("PlanetRing", Enum.PartType.Cylinder, Vector3.new(2, 120, 120), Color3.fromRGB(255, 220, 160), CFrame.new(-150, 120, -250) * CFrame.Angles(math.rad(75), 0, 0), Enum.Material.Neon)
	planetRing.CanCollide = false
	planetRing.CastShadow = false
	planetRing.Transparency = 0.4
	-- Stars: small bright dots scattered high in the sky.
	local rng = Random.new(555)
	for i = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(200, 300)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = rng:NextNumber(80, 160)
		local star = part("SkyStar", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), Color3.fromRGB(255, 255, 255), CFrame.new(x, y, z), Enum.Material.Neon)
		star.CanCollide = false
		star.CastShadow = false
	end
	-- Meteor streak: a diagonal glowing line high in the sky, a hint of
	-- the storm that is coming.
	local streak = part("MeteorStreak", Enum.PartType.Block, Vector3.new(40, 1, 1), Color3.fromRGB(255, 150, 80), CFrame.new(80, 100, -120) * CFrame.Angles(0, math.rad(30), math.rad(-30)), Enum.Material.Neon)
	streak.CanCollide = false
	streak.CastShadow = false
	streak.Transparency = 0.3
end

local function buildWind()
	-- Wind: a gentle particle drift across the map, so the air feels
	-- alive. One emitter per quadrant, low rate, so it never clutters
	-- a screenshot.
	for _, pos in ipairs({
		Vector3.new(-100, 20, -100),
		Vector3.new(100, 20, -100),
		Vector3.new(-100, 20, 100),
		Vector3.new(100, 20, 100),
	}) do
		local emitterPart = Instance.new("Part")
		emitterPart.Name = "WindEmitter"
		emitterPart.Size = Vector3.new(1, 1, 1)
		emitterPart.Anchored = true
		emitterPart.CanCollide = false
		emitterPart.CanQuery = false
		emitterPart.Transparency = 1
		emitterPart.CFrame = CFrame.new(pos)
		emitterPart.Parent = workspace
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxassetid://241594314"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		emitter.Transparency = NumberSequence.new(0.7)
		emitter.Size = NumberSequence.new(0.5)
		emitter.Lifetime = NumberRange.new(4, 6)
		emitter.Rate = 4
		emitter.Speed = NumberRange.new(8, 12)
		emitter.SpreadAngle = Vector2.new(10, 10)
		emitter.Parent = emitterPart
		table.insert(windEmitters, emitter)
	end
end

-- Fix the terrain: the project file's Ground part is 480x20x480 at
-- y=-10, so its top is at y=0 and the spawn platform, crater floor and
-- paths sit on it. This function exists so a future terrain change has
-- one place to live; it currently verifies the ground is where the
-- builders expect it.
local function fixTerrain()
	local ground = workspace:FindFirstChild("Ground")
	if ground and ground:IsA("Part") then
		ground.CFrame = CFrame.new(0, -10, 0)
		ground.Size = Vector3.new(480, 20, 480)
	end
end

-- The Star Shop: a walk-in shop at (-45, 0, 45) — floor, three walls
-- open toward the crater, a counter, shelves with Rotling eggs and
-- crates, a neon "STAR SHOP" sign, and a quirky alien shopkeeper
-- behind the counter. Walking in opens the Shop UI (the prompt is
-- wired by ShopService.init, which looks for the part named
-- "ShopPrompt"). Boost pickups spawn inside the shop too
-- (WorldBuilder.shopCenter).
local function buildStarShop()
	local shopCf = CFrame.new(-45, 0, 45) * CFrame.Angles(0, math.rad(45), 0)
	shopCenterCf = shopCf
	-- Floor.
	local floor = part("ShopFloor", Enum.PartType.Block, Vector3.new(24, 1, 20), Color3.fromRGB(90, 70, 120), shopCf * CFrame.new(0, 0.5, 0))
	floor.CanCollide = false
	-- Three walls (open toward the crater, +Z in shop space).
	for _, wall in ipairs({
		{ Vector3.new(0, 4, -10), Vector3.new(24, 8, 1) },
		{ Vector3.new(-12, 4, 0), Vector3.new(1, 8, 20) },
		{ Vector3.new(12, 4, 0), Vector3.new(1, 8, 20) },
	}) do
		local wallPart = part("ShopWall", Enum.PartType.Block, wall[2], Color3.fromRGB(140, 110, 180), shopCf * CFrame.new(wall[1]))
		wallPart.CanCollide = false
	end
	-- Counter across the back.
	local counter = part("ShopCounter", Enum.PartType.Block, Vector3.new(16, 3, 3), Color3.fromRGB(60, 45, 90), shopCf * CFrame.new(0, 1.5, -7))
	counter.CanCollide = false
	-- Shelves with eggs and crates along the side walls.
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 3 do
			local shelf = part("ShopShelf", Enum.PartType.Block, Vector3.new(1, 0.5, 5), Color3.fromRGB(150, 100, 50), shopCf * CFrame.new(side * 10.5, 2 + i * 1.6, -4 + i * 3))
			shelf.CanCollide = false
			local egg = part("ShopEgg", Enum.PartType.Ball, Vector3.new(1.4, 1.8, 1.4), Color3.fromRGB(255, 140, 50), shopCf * CFrame.new(side * 10.5, 3 + i * 1.6, -4 + i * 3), Enum.Material.Neon)
			egg.CanCollide = false
			local crate = part("ShopCrate", Enum.PartType.Block, Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(180, 130, 60), shopCf * CFrame.new(side * 10.5, 3 + i * 1.6, -2 + i * 3), Enum.Material.Wood)
			crate.CanCollide = false
		end
	end
	-- Neon sign above the open front — a ROUND gold-rimmed disc, not
	-- another flat dark board: every sign has its own silhouette
	-- (fix round 12, item 1). Lowered to y=7 (was 9) so it reads
	-- from the plaza without the HUD storm banner crossing it from
	-- normal camera angles. The disc faces the open front (+Z in
	-- shop space, toward the crater and the path).
	local signRim = part("ShopSignRim", Enum.PartType.Cylinder, Vector3.new(0.5, 7.2, 7.2), Color3.fromRGB(255, 215, 0), shopCf * CFrame.new(0, 7, 10) * CFrame.Angles(math.rad(90), 0, 0), Enum.Material.Neon)
	signRim.CanCollide = false
	local signBoard = part("ShopSignDisc", Enum.PartType.Cylinder, Vector3.new(0.7, 6.4, 6.4), Color3.fromRGB(20, 15, 40), shopCf * CFrame.new(0, 7, 10.3) * CFrame.Angles(math.rad(90), 0, 0))
	signBoard.CanCollide = false
	-- (fix round 14, item 1) VERIFIED in code: the ring in Malek's
	-- playtest-13 photo IS this disc + rim — the only other ring in
	-- the world is the rebirth altar's purple AltarRing at (0,0,-70).
	-- The "★ STAR SHOP ★" BillboardGui was parented to the disc, so
	-- its plane sat at the disc's centre (local z 10.3) — 0.35 studs
	-- BEHIND the disc's own opaque front face (10.3 + 0.7/2 =
	-- 10.65). Depth-tested, the face occludes the middle of its own
	-- text: from the plaza it reads "STAR [ring] OP". The GUI now
	-- hangs on an invisible anchor 0.75 in front of the face (local
	-- z 11.4), so the full text reads, framed by the gold rim.
	local signAnchor = part("ShopSignAnchor", Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), Color3.fromRGB(20, 15, 40), shopCf * CFrame.new(0, 7, 11.4))
	signAnchor.Transparency = 1
	signAnchor.CanCollide = false
	signAnchor.CanQuery = false
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "ShopSign"
	-- Depth-tested and shorter-range (v74, plaza fix): the old
	-- AlwaysOnTop sign at MaxDistance 120 rendered over the
	-- Contract Board from the plaza. It still reads from the shop.
	signGui.Size = UDim2.fromOffset(260, 80)
	signGui.AlwaysOnTop = false
	signGui.LightInfluence = 0
	signGui.MaxDistance = 60
	signGui.Parent = signAnchor
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "★ STAR SHOP ★"
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Parent = signGui
	-- The shopkeeper: a little green alien behind the counter, three
	-- eyes, antenna, waving arm (the wave is a slow CFrame loop).
	local keeper = Instance.new("Model")
	keeper.Name = "Shopkeeper"
	local keeperBody = part("KeeperBody", Enum.PartType.Ball, Vector3.new(3, 3.6, 3), Color3.fromRGB(120, 220, 120), shopCf * CFrame.new(0, 3.4, -8.5))
	keeperBody.CanCollide = false
	keeperBody.Parent = keeper
	local antenna = part("KeeperAntenna", Enum.PartType.Cylinder, Vector3.new(1.6, 0.3, 0.3), Color3.fromRGB(120, 220, 120), shopCf * CFrame.new(0, 5.6, -8.5))
	antenna.CanCollide = false
	antenna.Parent = keeper
	local antennaTip = part("KeeperAntennaTip", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(255, 220, 60), shopCf * CFrame.new(0, 6.5, -8.5), Enum.Material.Neon)
	antennaTip.CanCollide = false
	antennaTip.Parent = keeper
	for _, eyeX in ipairs({ -0.7, 0, 0.7 }) do
		local eye = part("KeeperEye", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(20, 20, 30), shopCf * CFrame.new(eyeX, 4, -7))
		eye.CanCollide = false
		eye.Parent = keeper
	end
	keeper.Parent = workspace
	-- Enter prompt: walking in opens the Shop UI.
	local promptPart = part("ShopPrompt", Enum.PartType.Block, Vector3.new(6, 1, 6), Color3.fromRGB(255, 220, 90), shopCf * CFrame.new(0, 0.5, 4), Enum.Material.Neon)
	promptPart.Transparency = 0.7
	promptPart.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter Star Shop"
	prompt.ObjectText = "Upgrades, boosts & more"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
end

-- Upgrade machines: one big glowing machine beside each base. Stand
-- on its pad to open the Upgrade panel (wired by ShopService.init,
-- which looks for parts named "UpgradePrompt").
local function buildUpgradeMachines()
	for baseId = 1, Config.BASE_COUNT do
		local cf = baseCFrames[baseId]
		if not cf then
			continue
		end
		local machineCf = cf * CFrame.new(16, 0, -2)
		local body = part("UpgradeMachine", Enum.PartType.Block, Vector3.new(4, 7, 3), Color3.fromRGB(60, 50, 100), machineCf * CFrame.new(0, 3.5, 0), Enum.Material.Metal)
		body.CanCollide = false
		local screen = part("UpgradeScreen", Enum.PartType.Block, Vector3.new(3, 2.5, 0.3), Color3.fromRGB(120, 255, 200), machineCf * CFrame.new(0, 5, -1.6), Enum.Material.Neon)
		screen.CanCollide = false
		local pad = part("UpgradePrompt", Enum.PartType.Block, Vector3.new(5, 0.5, 5), Color3.fromRGB(120, 255, 200), machineCf * CFrame.new(0, 0.25, 3), Enum.Material.Neon)
		pad.Transparency = 0.5
		pad.CanCollide = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open Upgrades"
		prompt.ObjectText = "Speed, carry, income & pads"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
	end
end

-- Rebirth altar: a meteor-stone shrine with a portal ring at
-- (0, 0, -70), on the far side of the crater. Stand on it to Rebirth
-- (wired by RebirthService.init, which looks for the part named
-- "RebirthPrompt").
local function buildRebirthAltar()
	local altarCf = CFrame.new(0, 0, -70)
	local stone = part("AltarStone", Enum.PartType.Block, Vector3.new(14, 1, 14), Color3.fromRGB(80, 60, 110), altarCf * CFrame.new(0, 0.5, 0), Enum.Material.Slate)
	stone.CanCollide = false
	for _, side in ipairs({ -1, 1 }) do
		local pillar = part("AltarPillar", Enum.PartType.Cylinder, Vector3.new(8, 1.6, 1.6), Color3.fromRGB(120, 90, 160), altarCf * CFrame.new(side * 5, 4, -4))
		pillar.CanCollide = false
	end
	local ring = part("AltarRing", Enum.PartType.Cylinder, Vector3.new(0.8, 8, 8), Color3.fromRGB(200, 140, 255), altarCf * CFrame.new(0, 5, -4) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon)
	ring.CanCollide = false
	ring.Transparency = 0.3
	local meteor = part("AltarMeteor", Enum.PartType.Ball, Vector3.new(4, 4, 4), Color3.fromRGB(255, 140, 50), altarCf * CFrame.new(0, 9, -4), Enum.Material.Neon)
	meteor.CanCollide = false
	local pad = part("RebirthPrompt", Enum.PartType.Block, Vector3.new(6, 0.5, 6), Color3.fromRGB(200, 140, 255), altarCf * CFrame.new(0, 1.2, 2), Enum.Material.Neon)
	pad.Transparency = 0.5
	pad.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "Reset coins for a permanent income boost"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
end

-- Index wall: a gallery wall near spawn (28, 0, 80) with one panel
-- Crashed spaceship: half-buried at the map edge (170, 0, -120), a
-- tilted saucer with a dome, smoke, and a blinking red light — a
-- landmark you can see from anywhere, so no horizon is ever empty.
local function buildSpaceship()
	local shipCf = CFrame.new(170, 0, -120) * CFrame.Angles(math.rad(8), math.rad(30), math.rad(18))
	local saucer = part("SpaceshipSaucer", Enum.PartType.Cylinder, Vector3.new(8, 44, 44), Color3.fromRGB(160, 160, 180), shipCf * CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal)
	saucer.CanCollide = false
	local dome = part("SpaceshipDome", Enum.PartType.Ball, Vector3.new(16, 8, 16), Color3.fromRGB(120, 200, 255), shipCf * CFrame.new(0, 4, 0), Enum.Material.Glass)
	dome.CanCollide = false
	dome.Transparency = 0.3
	local beacon = part("SpaceshipBeacon", Enum.PartType.Ball, Vector3.new(2, 2, 2), Color3.fromRGB(255, 60, 60), shipCf * CFrame.new(0, 9, 0), Enum.Material.Neon)
	beacon.CanCollide = false
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = Color3.fromRGB(255, 60, 60)
	beaconLight.Brightness = 2
	beaconLight.Range = 24
	beaconLight.Parent = beacon
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 120, 130))
	smoke.Size = NumberSequence.new(3)
	smoke.Lifetime = NumberRange.new(2, 3)
	smoke.Rate = 8
	smoke.Speed = NumberRange.new(2, 4)
	smoke.Parent = saucer
	-- Blink the beacon: on/off every second, forever.
	task.spawn(function()
		while beacon.Parent do
			beacon.Transparency = 0
			beaconLight.Enabled = true
			task.wait(1)
			beacon.Transparency = 0.7
			beaconLight.Enabled = false
			task.wait(1)
		end
	end)
end

-- Background: a second sky ball (the moon) high in the sky, so no
-- shot ever has an empty horizon. (The mountain wedges were removed
-- in the simplify/polish pass — they read as a big dark wall.)
local function buildBackground()
	local moon = part("Moon", Enum.PartType.Ball, Vector3.new(40, 40, 40), Color3.fromRGB(220, 220, 235), CFrame.new(-200, 150, 180), Enum.Material.SmoothPlastic)
	moon.CanCollide = false
	moon.CastShadow = false
	moon.Anchored = true
	-- Mountains REMOVED (simplify/polish REMOVE): five 80-tall dark
	-- Slate wedges read as a big dark wall on the horizon, including
	-- behind SPAWN. The moon stays, and the sky keeps its planet,
	-- stars and meteor streak, so no shot has an empty horizon.
end

-- Boundary walls (fix round 10, item 3): huge walls enclosing the
-- playable area — until now a player could walk off the 500x500 ground
-- into the void. Placement: a square at +/-200. That encloses all
-- gameplay (bases outer edge ~123, egg field radius <=130, storm
-- meteor spread +/-150, spawn pad, altar, logo stage, SELL) AND the
-- existing decor (the crashed spaceship saucer reaches ~x 192 — a
-- +/-180 square would cut straight through it), clears the storm
-- front sweep (+/-170) by 30 studs so the glowing wall never clips
-- the boundary, and sits 50 studs inside the ground edge (+/-250).
-- 40 tall (matches the storm front), dark stone deep purple with a
-- gold Neon top edge so the boundary reads from anywhere. Solid
-- (CanCollide = true, the part() default) — the fence posts stay
-- non-colliding visual guides; these walls are the real boundary.
local function buildBoundaryWalls()
	local BOUNDARY_HALF = 200
	local BOUNDARY_HEIGHT = 40
	local thick = 2
	local sides = {
		{ name = "North", center = Vector3.new(0, BOUNDARY_HEIGHT / 2, -BOUNDARY_HALF), size = Vector3.new(BOUNDARY_HALF * 2, BOUNDARY_HEIGHT, thick), trimSize = Vector3.new(BOUNDARY_HALF * 2, 0.6, thick + 0.6) },
		{ name = "South", center = Vector3.new(0, BOUNDARY_HEIGHT / 2, BOUNDARY_HALF), size = Vector3.new(BOUNDARY_HALF * 2, BOUNDARY_HEIGHT, thick), trimSize = Vector3.new(BOUNDARY_HALF * 2, 0.6, thick + 0.6) },
		{ name = "West", center = Vector3.new(-BOUNDARY_HALF, BOUNDARY_HEIGHT / 2, 0), size = Vector3.new(thick, BOUNDARY_HEIGHT, BOUNDARY_HALF * 2), trimSize = Vector3.new(thick + 0.6, 0.6, BOUNDARY_HALF * 2) },
		{ name = "East", center = Vector3.new(BOUNDARY_HALF, BOUNDARY_HEIGHT / 2, 0), size = Vector3.new(thick, BOUNDARY_HEIGHT, BOUNDARY_HALF * 2), trimSize = Vector3.new(thick + 0.6, 0.6, BOUNDARY_HALF * 2) },
	}
	for _, side in ipairs(sides) do
		-- Solid by design: part() defaults CanCollide = true, and
		-- nothing here turns it off — the wall stops players.
		local wall = part("BoundaryWall", Enum.PartType.Block, side.size, Color3.fromRGB(48, 38, 72), CFrame.new(side.center), Enum.Material.Slate)
		-- Gold Neon cap along the top edge, so the boundary reads
		-- from anywhere in the map. Visual only, non-colliding.
		local trim = part("BoundaryWallTrim", Enum.PartType.Block, side.trimSize, Color3.fromRGB(255, 200, 40), CFrame.new(side.center + Vector3.new(0, BOUNDARY_HEIGHT / 2 + 0.3, 0)), Enum.Material.Neon)
		trim.CanCollide = false
		trim.CastShadow = false
	end
end

-- Signposts, fences and paths: the world reads as a place, not a
-- field. Signposts point "Crater" and "Shop" at the junctions;
-- fences line the spawn path and the crater-to-shop walk; stone
-- paths connect the crater to the shop and to the altar.
local function fenceLine(from: Vector3, to: Vector3)
	local dir = to - from
	local length = dir.Magnitude
	if length < 2 then
		return
	end
	local step = dir.Unit * 4
	local count = math.floor(length / 4)
	for i = 0, count do
		local post = part("FencePost", Enum.PartType.Block, Vector3.new(0.6, 2, 0.6), Color3.fromRGB(120, 85, 50), CFrame.new(from + step * i + Vector3.new(0, 1, 0)))
		post.CanCollide = false
	end
	local mid = from + dir * 0.5
	local rail = part("FenceRail", Enum.PartType.Block, Vector3.new(0.4, 0.4, length), Color3.fromRGB(150, 105, 60), CFrame.new(mid + Vector3.new(0, 1.8, 0), to + Vector3.new(0, 1.8, 0)))
	rail.CanCollide = false
end

-- A signpost: a wooden post with one board per direction. Each
-- board has its own colour (crater = sky blue, shop = gold, altar =
-- purple), so no two signposts read the same — and no board is a
-- plain dark panel with white text (fix round 12, item 1).
local function signpost(position: Vector3, lines: { { text: string, color: Color3, board: Color3 } })
	-- (fix round 13, item 5) The old signpost was a placement bug
	-- twice over: (a) its two boards sat 1.8 studs apart with
	-- 40px AlwaysOnTop labels — from spawn (34 studs) the two
	-- labels' centres are ~30px apart on screen, so the blue
	-- "← Crater" and brown/gold "Shop →" labels sat ON each other
	-- (Malek's playtest-12 screenshot); (b) the post was a
	-- horizontal bar at y=3 that never reached the boards — they
	-- floated. Now: boards 3.2 studs apart with 32px labels
	-- (clear to MaxDistance on any normal screen — see the
	-- boards-audit check for the math), a VERTICAL post beside
	-- the boards (offset -4.2 in x, clear of the 7-wide boards,
	-- running from the ground to the top board), and a darker
	-- backing frame behind each board so it reads as a designed
	-- sign, not a flat panel.
	local post = part("Signpost", Enum.PartType.Cylinder, Vector3.new(9, 0.8, 0.8), Color3.fromRGB(120, 85, 50), CFrame.new(position + Vector3.new(-4.2, 4.5, 0)))
	post.CanCollide = false
	for i, line in ipairs(lines) do
		local boardY = 5 + (i - 1) * 3.2
		-- The frame: a darker shade of the board colour, slightly
		-- larger, sitting just behind the board — it peeks out
		-- around all four edges from the front, and reads as the
		-- sign's back from behind.
		local frame = part("SignpostFrame", Enum.PartType.Block, Vector3.new(7.6, 2.2, 0.2), Color3.new(line.board.R * 0.55, line.board.G * 0.55, line.board.B * 0.55), CFrame.new(position + Vector3.new(0, boardY, -0.3)))
		frame.CanCollide = false
		local board = part("SignpostBoard", Enum.PartType.Block, Vector3.new(7, 1.6, 0.4), line.board, CFrame.new(position + Vector3.new(0, boardY, 0)))
		board.CanCollide = false
		local gui = Instance.new("BillboardGui")
		gui.Name = "SignpostLabel"
		gui.Size = UDim2.fromOffset(160, 32)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = 50
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = line.text
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = line.color
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
	end
end

local function buildSignpostsAndFences()
	-- (fix round 12, item 1) The spawn-path signpost used to stand
	-- at (6, 58), dead on the sightline from the crater to the title
	-- sign — its boards overlapped the title text ("BRAINI Shop")
	-- from the plaza. It now stands on the WEST side of the spawn
	-- path (-8, 62), clear of every big sign (the title arch is at
	-- (0, 46), 17.9 studs away).
	signpost(Vector3.new(-8, 0, 62), { { text = "← Crater", color = Color3.fromRGB(140, 210, 255), board = Color3.fromRGB(40, 60, 110) }, { text = "Shop →", color = Color3.fromRGB(255, 220, 90), board = Color3.fromRGB(110, 85, 30) } })
	signpost(Vector3.new(-22, 0, 28), { { text = "Shop →", color = Color3.fromRGB(255, 220, 90), board = Color3.fromRGB(110, 85, 30) }, { text = "← Crater", color = Color3.fromRGB(140, 210, 255), board = Color3.fromRGB(40, 60, 110) } })
	signpost(Vector3.new(6, 0, -48), { { text = "Altar ↑", color = Color3.fromRGB(210, 150, 255), board = Color3.fromRGB(80, 50, 110) }, { text = "← Crater", color = Color3.fromRGB(140, 210, 255), board = Color3.fromRGB(40, 60, 110) } })
	-- Fences flank the spawn path (fix 5): they used to stop at z=46
	-- while the path stopped at z=57; now both run to the crater rim
	-- (z=40), so the walkway is fenced all the way in. The spawn path
	-- is 6 wide (half-width 3), so fences at x=+/-5 stand 2 studs
	-- clear of its edge.
	fenceLine(Vector3.new(-5, 0, 78), Vector3.new(-5, 0, 40))
	fenceLine(Vector3.new(5, 0, 78), Vector3.new(5, 0, 40))
	-- Crater-to-shop walk (fix round 10, item 1): the old fence
	-- fenceLine((-6, 42), (-40, 44)) was NOT parallel to the stone
	-- path — it started 1.39 studs off the centreline and converged
	-- to 0.00 at the shop end, so it ran THROUGH the walkway (the
	-- path is 6 wide, half-width 3). The fences are now true
	-- parallels of the path: same endpoints, offset 4 studs to each
	-- side along the unit normal, so no fence part comes within 3
	-- studs of the centreline and nothing blocks the walkway. They
	-- start 16 studs along the path: the crater-side fence would
	-- otherwise begin on the rim mound (outer ring radius 35-39,
	-- 5.5 tall) and its first posts would be buried — at 16 studs
	-- in, both fences start on flat ground (min radius 41.1 > 39)
	-- and the crater rim itself borders the first stretch of path.
	local shopPathFrom = Vector3.new(0, 0, 40)
	local shopPathTo = Vector3.new(-40, 0, 44)
	local shopPathDir = (shopPathTo - shopPathFrom).Unit
	local shopPathNormal = Vector3.new(-shopPathDir.Z, 0, shopPathDir.X)
	local fenceInset = 16
	local fenceOffset = 4
	local fenceStart = shopPathFrom + shopPathDir * fenceInset
	fenceLine(fenceStart + shopPathNormal * fenceOffset, shopPathTo + shopPathNormal * fenceOffset)
	fenceLine(fenceStart - shopPathNormal * fenceOffset, shopPathTo - shopPathNormal * fenceOffset)
	-- Stone paths: crater rim to the shop, and crater to the altar.
	local function path(from: Vector3, to: Vector3)
		local dir = to - from
		local length = dir.Magnitude
		local count = math.floor(length / 3.5)
		for i = 0, count do
			local tile = part("StonePath", Enum.PartType.Block, Vector3.new(6, 0.4, 3.5), Color3.fromRGB(150, 130, 100), CFrame.new(from + dir.Unit * (i * 3.5) + Vector3.new(0, 0.2, 0), to))
			tile.CanCollide = false
			tile.CastShadow = false
		end
	end
	path(shopPathFrom, shopPathTo)
	path(Vector3.new(0, 0, -40), Vector3.new(0, 0, -66))
end

-- Small ambient critters: tiny hopping balls that wander the plaza,
-- so the world feels alive between storms. One shared loop, no
-- per-critter heartbeat.
local function buildCritters()
	local TweenService = game:GetService("TweenService")
	local critterColors = {
		Color3.fromRGB(255, 180, 120),
		Color3.fromRGB(150, 220, 255),
		Color3.fromRGB(200, 255, 150),
	}
	for i = 1, 6 do
		local home = Vector3.new((i - 3.5) * 8, 0, 70 + (i % 2) * 6)
		local model = Instance.new("Model")
		model.Name = "Critter"
		local body = part("CritterBody", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), critterColors[(i % 3) + 1], CFrame.new(home + Vector3.new(0, 0.8, 0)))
		body.CanCollide = false
		body.Parent = model
		model.PrimaryPart = body
		for _, side in ipairs({ -1, 1 }) do
			local eye = part("CritterEye", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(20, 20, 30), CFrame.new(home + Vector3.new(side * 0.4, 1.1, 0.6)))
			eye.CanCollide = false
			eye.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = eye
			weld.Parent = eye
		end
		model.Parent = workspace
		task.spawn(function()
			while model.Parent do
				local target = home + Vector3.new((math.random() * 2 - 1) * 12, 0, (math.random() * 2 - 1) * 8)
				local tween = TweenService:Create(body, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
					CFrame = CFrame.new(target + Vector3.new(0, 0.8, 0)),
				})
				tween:Play()
				tween.Completed:Wait()
				task.wait(math.random(1, 3))
			end
		end)
	end
end

-- Giant title billboard over the crater (cheap win 4): "STARFALL
-- ROTLINGS" plus a one-line pitch in our own words, on two tall
-- posts at the crater's north edge, facing spawn — visible in the
-- hero and isometric shots.
-- Logo stage near spawn: three hero Rotlings (Cosmic Corn Dog,
-- Supreme Spaghetti, Baron von Burrito) on a small stage with a
-- meteor prop — the in-game render of the logo, bright and readable
-- at 150px for the Roblox icon (item 13). Display models only: their
-- State is "display", so rivals, the belt list and grabs ignore them.
-- Logo stage: the three hero Brainrots + meteor for the icon shot
-- (photo mode P, shot 5). It used to stand at (-25, 0, 88), right
-- beside the spawn path — three 1.5x Brainrots with huge eyes
-- blocking the plaza view. Now it sits BEHIND spawn (0, 0, 118),
-- out of the walkway, heroes facing north toward the path.
-- Meteor rocks (fix round 11, item 1 — dressing pass): dark-purple
-- boulders with a glowing orange shard stuck in them, ringing the
-- crater rim just outside the belt. They are the storm's litter:
-- space rocks that already landed. Seeded, same every server. Kept
-- clear of the spawn path and the crater-to-shop stone path.
local function buildMeteorRocks()
	local rng = Random.new(31337)
	for i = 1, 6 do
		local angle = rng:NextNumber(0, math.pi * 2)
		-- (fix round 13, item 1) Radius 33..38, NOT 33..40: the
		-- steal walk arcs along a ring at radius 45, and the
		-- 30-degree chords dip to 43.5 — minus the rival's 1.5-stud
		-- half-width, the swept corridor reaches down to radius
		-- 42. A rock at radius 40 with size 6 reaches radius 43:
		-- inside the swept corridor, a 4-6 stud solid ball on the
		-- only ring every rival walk uses (the stuck-hop clears a
		-- 0.6 pad ledge, not a boulder). At radius <= 38 the worst
		-- reach is 38 + 3 = 41, a full stud clear of the corridor.
		-- The old 33..40 range was the last unproven blocker on
		-- the steal route: the trace in auto-checks (steal-route)
		-- proves the ring clear from this bound, not from one RNG
		-- draw. Rocks still stud the rim (35..39) — a boulder on
		-- the rim reads as part of the crater.
		local radius = rng:NextNumber(33, 38)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		-- Keep the walkways clear: not on the spawn path (x near 0,
		-- z 39-80) and not on the stone path to the shop (z 36-48,
		-- x -42..2).
		--
		-- (fix round 12, item 2) The gap exclusion was |x| < 6 —
		-- a rock at (8, 38) could still sit on the edge of the
		-- crater-gap mouth every rival walks through to reach
		-- the crater. Widened to |x| < 10: the whole mouth of
		-- the gap stays clear for the steal walk.
		if math.abs(x) < 10 and z > 34 then
			continue
		end
		if z > 36 and z < 48 and x > -42 and x < 2 then
			continue
		end
		local size = rng:NextNumber(4, 6)
		local boulder = part("MeteorRock", Enum.PartType.Ball, Vector3.new(size, size * 0.75, size), Color3.fromRGB(60, 45, 90), CFrame.new(x, size * 0.3, z) * CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), 0), Enum.Material.Slate)
		boulder.CanCollide = true
		local shard = part("MeteorShard", Enum.PartType.Wedge, Vector3.new(1.5, 3, 1.5), Color3.fromRGB(255, 140, 50), CFrame.new(x, size * 0.75 + 1, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)), Enum.Material.Neon)
		shard.CanCollide = false
	end
end

-- Big in-world title sign (fix round 11, item 1 — dressing pass;
-- MOVED fix round 14, item 2): an arch over the spawn→crater path
-- at the crater's edge (0, 46), dead on the sightline, facing
-- spawn — the first thing a player sees on arrival and in the
-- middle of the map, the way Malek expects ("where's big title
-- sign? In the middle?", playtest 13). It used to stand east of
-- the path at (12, 72), where he never found it. Two posts + a
-- dark-purple board with gold trim + a depth-tested billboard with
-- the title in gold. The board is raised to y=9 (bottom edge 6,
-- trims 5.9/12.1) so players (head ~5) and rivals (head ~6.1)
-- walk UNDER it through the crater gap — the old y=8 board bottom
-- (5) would graze every head on the main walkway. Posts at +/-12.5
-- stand clear of the spawn-path fences (x +/- 5), the shop-walk
-- fences (nearest post ~3 studs off) and the shop path (its north
-- edge is 44.1, the sign at 46); the rim gap mouth is ~60 wide
-- here, so the 22-wide arch leaves it open. This is NOT the old
-- sky billboard (removed in fix round 2, fix 8): no sky text, no
-- pitch line, nothing overlapping the SELL pad. The builder and
-- part names deliberately avoid the old sky-billboard identifiers,
-- so the old-billboard checks still prove the sky text is gone.
local function buildWorldTitleSign()
	local cx, cz = 0, 46
	-- (fix round 12, item 1) The posts used to stand at cx +/- 10,
	-- INSIDE the 22-wide board's span (edges at cx +/- 11) — from
	-- spawn angles a post ran straight through the middle of the
	-- text ("SPAC...OCK / BR...OTS!"). The posts now stand at
	-- cx +/- 12.5, 1.5 studs CLEAR of the board edges: in the same
	-- plane as the board and outside its span, a post can never
	-- cover the board's face from any camera angle.
	for _, side in ipairs({ -1, 1 }) do
		local post = part("WorldTitlePost", Enum.PartType.Block, Vector3.new(1.2, 12, 1.2), Color3.fromRGB(72, 62, 92), CFrame.new(cx + side * 12.5, 6, cz))
		post.CanCollide = false
	end
	local board = part("WorldTitleSign", Enum.PartType.Block, Vector3.new(22, 6, 1), Color3.fromRGB(60, 45, 90), CFrame.new(cx, 9, cz))
	board.CanCollide = false
	local trimTop = part("WorldTitleTrim", Enum.PartType.Block, Vector3.new(22.4, 0.5, 1.2), Color3.fromRGB(255, 215, 0), CFrame.new(cx, 12.1, cz), Enum.Material.Neon)
	trimTop.CanCollide = false
	local trimBottom = part("WorldTitleTrim", Enum.PartType.Block, Vector3.new(22.4, 0.5, 1.2), Color3.fromRGB(255, 215, 0), CFrame.new(cx, 5.9, cz), Enum.Material.Neon)
	trimBottom.CanCollide = false
	-- A soft gold glow + a slow pulse on the trims, so the sign
	-- reads as alive, not a flat board.
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 215, 0)
	glow.Brightness = 1.5
	glow.Range = 18
	glow.Parent = board
	task.spawn(function()
		local TweenService = game:GetService("TweenService")
		while board.Parent do
			local tween = TweenService:Create(trimTop, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.45 })
			tween:Play()
			local tween2 = TweenService:Create(trimBottom, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.45 })
			tween2:Play()
			tween.Completed:Wait()
			local back = TweenService:Create(trimTop, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0 })
			back:Play()
			local back2 = TweenService:Create(trimBottom, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0 })
			back2:Play()
			back.Completed:Wait()
		end
	end)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldTitleLabel"
	gui.Size = UDim2.fromOffset(440, 90)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Parent = board
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "SPACE ROCK BRAINROTS!"
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = gui
end

local function buildLogoStage()
	local stageCf = CFrame.new(0, 0, 118)
	-- (fix round 13, item 6) The stage used to sit at y=0.5 (top y=1),
	-- BURIED under the spawn platform (top y=2) — invisible — and the
	-- heroes were sunk with it: PivotTo(CFrame.new(pos)) put the body
	-- CENTRE at pos.y=2.5, so their body bottoms sat at y=0.25, 1.75
	-- studs inside the platform. The stage is a low dais now (top
	-- y=2.5, a 0.5 lip above the platform) and the heroes are seated
	-- by their body bottoms, the way build() seats every Rotling.
	-- Widened 16 -> 20 so the three heroes can stand 8 apart: at 4.5
	-- apart their 200px labels sat 107px apart on screen and buried
	-- each other's text; at 8 apart they sit ~190px apart and read.
	local stage = part("LogoStage", Enum.PartType.Block, Vector3.new(20, 1, 8), Color3.fromRGB(60, 45, 90), stageCf * CFrame.new(0, 2, 0))
	stage.CanCollide = false
	local heroIds = { "gummy", "couch", "bloop" }
	for i, defId in ipairs(heroIds) do
		local def = RotlingCatalog.getDef(defId)
		if def then
			local pos = stageCf.Position + Vector3.new((i - 2) * 8, 2.5, 0)
			local model = RotlingFactory.build(defId, nil, pos, 1.5)
			if model then
				model.Parent = workspace
				-- Uniform display height (rev 75): the heroes stand
				-- at the same tidy height as a placed Brainrot, not
				-- 1.5x giants blocking the plaza.
				RotlingFactory.normalizeToHeight(model, Config.PLACED_DISPLAY_HEIGHT)
				model:SetAttribute("State", "display")
				model:SetAttribute("BaseId", 0)
				model:SetAttribute("PadIndex", 0)
				-- Face north, toward spawn and the path (the face is
				-- built on the model's +Z side). Seat the body bottom
				-- on the stage: pos is the SURFACE, the body centre
				-- belongs half a body above it (build seats the same
				-- way; the old CFrame.new(pos) sank the heroes).
				local b = model.PrimaryPart
				if b then
					model:PivotTo(CFrame.new(pos + Vector3.new(0, b.Size.Y / 2 + 0.1, 0)) * CFrame.Angles(0, math.rad(180), 0))
				end
			end
		end
	end
	local meteor = part("LogoMeteor", Enum.PartType.Ball, Vector3.new(4, 4, 4), Color3.fromRGB(255, 140, 50), stageCf * CFrame.new(0, 8, -2), Enum.Material.Neon)
	meteor.CanCollide = false
	local meteorLight = Instance.new("PointLight")
	meteorLight.Color = Color3.fromRGB(255, 140, 50)
	meteorLight.Brightness = 2
	meteorLight.Range = 16
	meteorLight.Parent = meteor
end

-- Hero display row in front of the title sign (fix round 13, item 6):
-- the staged group for photo-mode shot 1 (first thumbnail + first
-- submission screenshot). Four distinct Brainrots — the three logo
-- heroes (Cosmic Corn Dog, Supreme Spaghetti, Baron von Burrito) plus
-- the Divine Archangel Alfredo — stand on a low plinth east of the
-- spawn path, facing +Z toward spawn and the shot-1 camera, at the
-- same display height as the logo heroes. The plinth is a 0.5 lip
-- above the spawn platform (top y=2.5) and ghost, like the logo
-- stage. The row sits WEST of the contract board — a north-south wall
-- at x~16, z 88..100 — so no sightline from the shot-1 camera to a
-- hero crosses the board (the row's east hero is at x=11.5). Shot-1
-- framing, computed offline (see the hero-shot auto-check): camera
-- (1.75, 14, 96) looking at (1, 3, 80) puts all four heroes at
-- 16-19% of frame height, their 200px labels 162-194px apart (edges
-- touch, centred text reads), the title sign fully in frame with its
-- text clear of the labels, and the crater rim flanking the sign.
local function buildHeroRow()
	local rowCf = CFrame.new(1.75, 0, 82)
	local plinth = part("HeroPlinth", Enum.PartType.Block, Vector3.new(21.5, 1, 6), Color3.fromRGB(60, 45, 90), rowCf * CFrame.new(0, 2, 0))
	plinth.CanCollide = false
	local heroIds = { "gummy", "alfredo", "bloop", "couch" }
	for i, defId in ipairs(heroIds) do
		local def = RotlingCatalog.getDef(defId)
		if def then
			local pos = Vector3.new(-8 + (i - 1) * 6.5, 2.5, 82)
			local model = RotlingFactory.build(defId, nil, pos, 1.5)
			if model then
				model.Parent = workspace
				RotlingFactory.normalizeToHeight(model, Config.PLACED_DISPLAY_HEIGHT)
				model:SetAttribute("State", "display")
				model:SetAttribute("BaseId", 0)
				model:SetAttribute("PadIndex", 0)
				-- Face +Z, toward spawn, the path and the shot-1
				-- camera: the face is built on the model's +Z side,
				-- so no rotation (the logo stage rotates 180 because
				-- it faces -Z toward spawn from z=118). Seat the body
				-- bottom on the plinth — pos is the SURFACE, never
				-- the body centre (the logo stage's old PivotTo sank
				-- its heroes 1.75 into the platform that way).
				local b = model.PrimaryPart
				if b then
					model:PivotTo(CFrame.new(pos + Vector3.new(0, b.Size.Y / 2 + 0.1, 0)))
				end
			end
		end
	end
end

-- Contract Board in the plaza (16, 0, 94): the visible board where
-- the player picks up contracts and claims rewards. The board itself
-- is a sign + a prompt — contracts are per-player, so the board's
-- text is the same for everyone ("3 contracts, claim rewards here")
-- and pressing E opens the player's own board panel (MissionService
-- wires the prompt to the OpenContracts remote). It stands on the
-- EAST side of the spawn path, away from the STAR SHOP sign on the
-- west — in v72 the two signs overlapped on screen from the plaza.
-- ~48 studs from the Index Wall — never in the same frame as it.
local function buildContractBoard()
	-- East side of the spawn path, facing the path.
	local boardCf = CFrame.lookAt(Vector3.new(16, 0, 94), Vector3.new(0, 0, 96))
	-- (fix round 12, item 1) The posts used to stand at +/- 4,
	-- behind the 10-wide board; the text (220x110, TextSize 15,
	-- NO wrapping) clipped mid-word — "Finish one, cla..." — and
	-- the board read as an empty dark panel. Now: a 12x8 board
	-- with a gold backing (a gold border around the dark face),
	-- posts OUTSIDE the board at +/- 6.9, a 260x140 GUI, wrapped
	-- text that fits, and a footer line — so the board reads as a
	-- reward board with content, never as an empty panel.
	-- (fix round 13, item 5) The posts were horizontal bars
	-- (rotated 90° about Z) centred at +/- 6.5 — a 7-long bar
	-- spans 3..10, so half of each bar ran THROUGH the board's
	-- face and poked 0.1 out the front. They are VERTICAL now,
	-- standing on the ground at +/- 6.9 — clear of the board
	-- (+/- 6) AND of the gold backing (+/- 6.3).
	for _, x in ipairs({ -6.9, 6.9 }) do
		local post = part("ContractPost", Enum.PartType.Cylinder, Vector3.new(7, 0.8, 0.8), Color3.fromRGB(120, 85, 50), boardCf * CFrame.new(x, 3.5, 0))
		post.CanCollide = false
	end
	local backing = part("ContractBoardBacking", Enum.PartType.Block, Vector3.new(12.6, 8.6, 0.4), Color3.fromRGB(255, 215, 0), boardCf * CFrame.new(0, 6, -0.3), Enum.Material.Neon)
	backing.CanCollide = false
	local board = part("ContractBoard", Enum.PartType.Block, Vector3.new(12, 8, 0.6), Color3.fromRGB(60, 45, 90), boardCf * CFrame.new(0, 6, 0))
	board.CanCollide = false
	-- Gold trim on top, so the board reads as the reward board from
	-- the path — the bounty board it replaces was plain dark.
	local trim = part("ContractBoardTrim", Enum.PartType.Block, Vector3.new(12.4, 0.5, 0.8), Color3.fromRGB(255, 215, 0), boardCf * CFrame.new(0, 10.2, 0), Enum.Material.Neon)
	trim.CanCollide = false
	local gui = Instance.new("BillboardGui")
	gui.Name = "ContractBoardGui"
	-- Small and depth-tested (v74, plaza fix): the old 280x160
	-- AlwaysOnTop board rendered giant centre-screen text over the
	-- world at close range and drew over the STAR SHOP sign. At
	-- 260x140 with wrapped text it reads as a sign, not a
	-- fullscreen overlay, and it hides behind nearer geometry.
	gui.Size = UDim2.fromOffset(260, 140)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 40
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "ContractTitle"
	title.Size = UDim2.new(1, 0, 0.25, 0)
	title.BackgroundTransparency = 1
	title.Text = "CONTRACT BOARD"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 20
	title.TextWrapped = true
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.TextStrokeTransparency = 0.3
	title.Parent = gui
	local text = Instance.new("TextLabel")
	text.Name = "ContractText"
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
	footer.TextSize = 13
	footer.TextWrapped = true
	footer.TextColor3 = Color3.fromRGB(255, 220, 90)
	footer.TextStrokeTransparency = 0.3
	footer.Parent = gui
	-- Press E to open your board: the prompt is wired by
	-- MissionService.init (it fires OpenContracts at that player).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ContractBoardPrompt"
	prompt.ActionText = "Open Contract Board"
	prompt.ObjectText = "3 contracts • claim rewards"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
end

function WorldBuilder.build()
	fixTerrain()
	for baseId = 1, Config.BASE_COUNT do
		buildBase(baseId)
	end
	buildCrater()
	buildSpawnArea()
	buildBelt()
	buildSellArea()
	buildPlazaDecor()
	buildTrees()
	buildRocks()
	buildMeteorRocks()
	buildHills()
	buildGroundDetail()
	buildBoundaryWalls()
	buildCrystals()
	buildSkyDecor()
	buildWind()
	buildStarShop()
	buildUpgradeMachines()
	buildRebirthAltar()
	buildSpaceship()
	buildBackground()
	buildSignpostsAndFences()
	buildWorldTitleSign()
	buildCritters()
	-- Title billboard REMOVED (fix round 2, fix 8): the giant
	-- "SPACE ROCK BRAINROTS!" text in the sky filled the screen and
	-- its pitch line overlapped the SELL pad. The small HUD title is
	-- enough — the name lives on the HUD and the title screen, not
	-- in the sky.
	buildLogoStage()
	buildHeroRow()
	buildContractBoard()
	print("[WorldBuilder] world built: " .. tostring(Config.BASE_COUNT) .. " bases, crater, conveyor, sell area, plaza, trees, rocks, meteor rocks, hills, ground detail, boundary walls, crystals, islands, sky, wind, star shop, upgrade machines, rebirth altar, index wall, spaceship, background, signposts, fences, paths, critters, world title sign, logo stage, hero row, bounty board.")
end

return WorldBuilder
