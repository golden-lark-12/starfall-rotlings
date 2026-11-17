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

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Formatting = require(game:GetService("ReplicatedStorage").Shared.Formatting)

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
local levelLabels: { [number]: TextLabel } = {}
local padParts: { [number]: { [number]: Part } } = {}
local baseTrims: { [number]: Part } = {}
local baseFlags: { [number]: Part } = {}
local baseTiles: { [number]: { Part } } = {}
local baseWalls: { [number]: { Part } } = {}
local basePlinths: { [number]: { Part } } = {}
local cashLabels: { [number]: TextLabel } = {}
local baseColors: { [number]: Color3 } = {}
local windEmitters: { ParticleEmitter } = {}

-- Parts that float (floating islands, crater rocks): base pose + seed,
-- bobbed by one shared loop so nothing needs its own heartbeat.
type FloatEntry = { part: Part, base: CFrame, seed: number, amp: number }
local floatParts: { FloatEntry } = {}
local floatBobStarted = false

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

function WorldBuilder.setBaseSign(baseId: number, text: string)
	local label = signLabels[baseId]
	if label then
		label.Text = text
	end
end

-- The base level sign: "Lv N" under the owner sign. Level is 1 + the
-- Rotlings placed on that base, so a packed base visibly outranks an
-- empty one. Updated from the HUD feed every second.
function WorldBuilder.setBaseLevel(baseId: number, level: number)
	local label = levelLabels[baseId]
	if label then
		label.Text = "Lv " .. tostring(level) .. " ★"
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

-- Register a part for the shared float-bob loop. Parts of one island
-- share a seed so they bob together instead of drifting apart.
local function registerFloat(p: Part, amp: number, seed: number?)
	table.insert(floatParts, { part = p, base = p.CFrame, seed = seed or math.random() * 10, amp = amp })
end

local function startFloatBob()
	if floatBobStarted then
		return
	end
	floatBobStarted = true
	task.spawn(function()
		while true do
			task.wait(0.15)
			local now = time()
			for i = #floatParts, 1, -1 do
				local entry = floatParts[i]
				if entry.part.Parent == nil then
					table.remove(floatParts, i)
				else
					local bob = math.sin(now * 0.7 + entry.seed) * entry.amp
					entry.part.CFrame = entry.base * CFrame.new(0, bob, 0)
				end
			end
		end
	end)
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
	-- Level sign: a small gold "Lv N" billboard hung under the owner
	-- sign board, so every base shows its level at a glance.
	local levelSign = Instance.new("BillboardGui")
	levelSign.Name = "BaseLevel"
	levelSign.Size = UDim2.fromOffset(140, 44)
	levelSign.StudsOffsetWorldSpace = Vector3.new(0, -4.5, 0)
	levelSign.AlwaysOnTop = true
	levelSign.LightInfluence = 0
	levelSign.MaxDistance = 60
	levelSign.Parent = signBoard
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, 0, 1, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Lv 1 ★"
	levelLabel.Font = Enum.Font.FredokaOne
	levelLabel.TextScaled = true
	levelLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
	levelLabel.TextStrokeTransparency = 0.3
	levelLabel.Parent = levelSign
	levelLabels[baseId] = levelLabel

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
		placePrompt.ActionText = "Place Rotling"
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

	-- Lock gate: a shimmering wall across the entrance, hidden until locked.
	local gate = part("LockGate", Enum.PartType.Block, Vector3.new(26, 7, 0.6), Color3.fromRGB(255, 60, 60), cf * CFrame.new(0, 4.5, -11), Enum.Material.ForceField)
	gate:SetAttribute("BaseId", baseId)
	gate.Transparency = 1
	gate.CanCollide = false
	gate.CanQuery = false
end

-- Paths: a warm-stone walkway from each base's front gate to the crater rim.
local function buildPaths()
	local stoneA = Color3.fromRGB(205, 185, 145)
	local stoneB = Color3.fromRGB(185, 165, 125)
	for baseId = 1, Config.BASE_COUNT do
		local cf = baseCFrames[baseId]
		if cf then
			-- Six segments run from the front gate (local z -16.75) to
			-- the crater rim: the last one ends at local z -80, which is
			-- radius 30 from the origin, the rim wall.
			for i = 0, 5 do
				local z = -16.75 - i * 11.5
				local color = if i % 2 == 0 then stoneA else stoneB
				local seg = part("BasePath", Enum.PartType.Block, Vector3.new(4, 0.25, 11.5), color, cf * CFrame.new(0, 0.15, z), Enum.Material.Slate)
				seg.CanCollide = false
				seg.CastShadow = false
			end
		end
	end
end

local function buildTrees()
	-- Alien trees: purple and magenta canopies, never green.
	for _ = 1, 30 do
		local angle = math.random() * math.pi * 2
		local radius = 135 + math.random() * 70
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local height = 6 + math.random() * 6
		local trunk = part("TreeTrunk", Enum.PartType.Cylinder, Vector3.new(height * 0.5, 1.2, 1.2), Color3.fromRGB(135, 100, 155), CFrame.new(x, height * 0.25, z) * CFrame.Angles(0, 0, math.rad(90)))
		trunk.CanCollide = false
		local canopyColor = Color3.fromRGB(120 + math.random(0, 80), 50 + math.random(0, 40), 170 + math.random(0, 60))
		local canopy = part("TreeTop", Enum.PartType.Ball, Vector3.new(height * 0.9, height * 0.9, height * 0.9), canopyColor, CFrame.new(x, height * 0.75, z))
		canopy.CanCollide = false
	end
end

local function buildRocksAndMushrooms()
	for _ = 1, 24 do
		local angle = math.random() * math.pi * 2
		local radius = 45 + math.random() * 90
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local s = 1.5 + math.random() * 3
		local rock = part("Rock", Enum.PartType.Ball, Vector3.new(s, s * 0.7, s), Color3.fromRGB(145, 125, 170), CFrame.new(x, s * 0.3, z) * CFrame.Angles(math.random(), math.random(), math.random()))
		rock.Material = Enum.Material.Slate
	end
	-- Angular boulders: grey and brown wedges, half-buried.
	local boulderColors = {
		Color3.fromRGB(120, 105, 120),
		Color3.fromRGB(150, 120, 95),
		Color3.fromRGB(100, 95, 130),
	}
	for _ = 1, 14 do
		local angle = math.random() * math.pi * 2
		local radius = 45 + math.random() * 100
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local s = 2 + math.random() * 3.5
		local boulder = part("Boulder", Enum.PartType.Wedge, Vector3.new(s, s * 0.8, s), boulderColors[math.random(1, #boulderColors)], CFrame.new(x, s * 0.3, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0), Enum.Material.Slate)
		boulder.CanCollide = false
	end
	-- Glowing mushrooms ring the crater, bigger and brighter than before.
	local mushroomColors = {
		Color3.fromRGB(255, 120, 180),
		Color3.fromRGB(120, 220, 255),
		Color3.fromRGB(180, 255, 120),
		Color3.fromRGB(255, 200, 90),
	}
	for _ = 1, 24 do
		local angle = math.random() * math.pi * 2
		local radius = Config.CRATER_RADIUS + 4 + math.random() * 14
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local color = mushroomColors[math.random(1, #mushroomColors)]
		local stemH = 1.6 + math.random() * 1.2
		local stem = part("MushroomStem", Enum.PartType.Cylinder, Vector3.new(stemH, 0.7, 0.7), Color3.fromRGB(240, 235, 220), CFrame.new(x, stemH * 0.5, z) * CFrame.Angles(0, 0, math.rad(90)))
		stem.CanCollide = false
		local cap = part("MushroomCap", Enum.PartType.Ball, Vector3.new(2.6, 1.3, 2.6), color, CFrame.new(x, stemH + 0.5, z), Enum.Material.Neon)
		cap.CanCollide = false
	end
end

-- Hills: big smooth mounds in the outer ring, breaking up the flat plane.
local function buildHills()
	local hillColors = {
		Color3.fromRGB(105, 80, 140),
		Color3.fromRGB(125, 95, 160),
		Color3.fromRGB(90, 70, 125),
		Color3.fromRGB(140, 110, 170),
	}
	for _ = 1, 14 do
		local angle = math.random() * math.pi * 2
		local radius = 145 + math.random() * 75
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local w = 30 + math.random() * 35
		local h = 7 + math.random() * 9
		local hill = part("Hill", Enum.PartType.Ball, Vector3.new(w, h, w * (0.7 + math.random() * 0.6)), hillColors[math.random(1, #hillColors)], CFrame.new(x, -h * 0.35, z), Enum.Material.SmoothPlastic)
		hill.CanCollide = false
		hill.CastShadow = false
	end
end

local CRYSTAL_COLORS = {
	Color3.fromRGB(80, 230, 220),
	Color3.fromRGB(255, 110, 200),
	Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(120, 200, 255),
}

-- One crystal: a chunky 3D neon wedge. Width sets the footprint and
-- tilt splays it outward, so a cluster reads as 3D from the path
-- instead of a flat slab.
local function crystal(x: number, y: number, z: number, height: number, width: number, color: Color3, tiltX: number, tiltZ: number)
	local c = part("Crystal", Enum.PartType.Wedge, Vector3.new(width, height, width), color, CFrame.new(x, y + height * 0.4, z) * CFrame.Angles(tiltX, math.random() * math.pi * 2, tiltZ), Enum.Material.Neon)
	c.CanCollide = false
	c.CastShadow = false
	return c
end

-- Crystal clusters scattered across the map: each one a splayed bunch
-- of wedges in a few sizes (small, medium, large) and mixed colours
-- (pink, cyan, violet, light blue), tilted outward in all directions.
local function buildCrystalClusters()
	for _ = 1, 9 do
		local angle = math.random() * math.pi * 2
		local radius = 42 + math.random() * 95
		local cx = math.cos(angle) * radius
		local cz = math.sin(angle) * radius
		local count = 4 + math.random(0, 2)
		for _ = 1, count do
			local ox = cx + (math.random() - 0.5) * 5
			local oz = cz + (math.random() - 0.5) * 5
			local roll = math.random()
			local height: number
			local width: number
			if roll < 0.4 then
				-- Small.
				height = 2 + math.random() * 1.5
				width = 1.4 + math.random() * 0.6
			elseif roll < 0.8 then
				-- Medium.
				height = 3.5 + math.random() * 2
				width = 2 + math.random() * 1
			else
				-- Large.
				height = 6 + math.random() * 2.5
				width = 3 + math.random() * 1
			end
			local color = CRYSTAL_COLORS[math.random(1, #CRYSTAL_COLORS)]
			crystal(ox, 0, oz, height, width, color, (math.random() - 0.5) * 0.7, (math.random() - 0.5) * 0.7)
		end
	end
end

-- Floating islands: a small platform with crystals and a tiny tree,
-- bobbing slowly above the map.
local function buildFloatingIslands()
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi * 2 / 4) + 0.4
		local radius = 55 + math.random() * 35
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = 22 + math.random() * 8
		local w = 7 + math.random() * 3
		local platform = part("FloatIsland", Enum.PartType.Cylinder, Vector3.new(1.5, w, w), Color3.fromRGB(120, 95, 150), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Slate)
		platform.CanCollide = false
		platform.CastShadow = false
		local islandSeed = math.random() * 10
		registerFloat(platform, 1.2, islandSeed)
		-- A crystal and a tiny tree on top, riding the same bob.
		local color = CRYSTAL_COLORS[math.random(1, #CRYSTAL_COLORS)]
		local top = part("IslandCrystal", Enum.PartType.Wedge, Vector3.new(1.2, 2.5, 1.2), color, CFrame.new(x + w * 0.2, y + 1.6, z), Enum.Material.Neon)
		top.CanCollide = false
		top.CastShadow = false
		registerFloat(top, 1.2, islandSeed)
		local trunk = part("IslandTree", Enum.PartType.Cylinder, Vector3.new(2, 0.5, 0.5), Color3.fromRGB(135, 100, 155), CFrame.new(x - w * 0.2, y + 1.6, z) * CFrame.Angles(0, 0, math.rad(90)))
		trunk.CanCollide = false
		trunk.CastShadow = false
		registerFloat(trunk, 1.2, islandSeed)
		local canopy = part("IslandCanopy", Enum.PartType.Ball, Vector3.new(2.5, 2.5, 2.5), Color3.fromRGB(150, 70, 200), CFrame.new(x - w * 0.2, y + 3.2, z))
		canopy.CanCollide = false
		canopy.CastShadow = false
		registerFloat(canopy, 1.2, islandSeed)
	end
end

local function buildSkyDecor()
	-- Stars: small glowing spheres high above the map.
	for _ = 1, 120 do
		local angle = math.random() * math.pi * 2
		local radius = 60 + math.random() * 160
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = 55 + math.random() * 45
		local s = 0.8 + math.random() * 1.6
		local star = part("Star", Enum.PartType.Ball, Vector3.new(s, s, s), Color3.fromRGB(255, 240, 180), CFrame.new(x, y, z), Enum.Material.Neon)
		star.CanCollide = false
		star.CanQuery = false
		star.CastShadow = false
	end
	-- A big planet in the sky, ahead of spawn, with a ring: the landmark
	-- every screenshot's sky gets. Spawn faces -X, so it hangs up-left.
	local planet = part("Planet", Enum.PartType.Ball, Vector3.new(52, 52, 52), Color3.fromRGB(255, 150, 80), CFrame.new(-230, 125, -45), Enum.Material.SmoothPlastic)
	planet.CanCollide = false
	planet.CanQuery = false
	planet.CastShadow = false
	local ring = part("PlanetRing", Enum.PartType.Cylinder, Vector3.new(2, 85, 85), Color3.fromRGB(255, 220, 170), CFrame.new(-230, 125, -45) * CFrame.Angles(math.rad(70), 0, math.rad(20)), Enum.Material.Neon)
	ring.Transparency = 0.4
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	-- Clouds: soft lavender blobs drifting high up.
	for _ = 1, 10 do
		local angle = math.random() * math.pi * 2
		local radius = 60 + math.random() * 120
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local cloud = part("Cloud", Enum.PartType.Ball, Vector3.new(18, 6, 12), Color3.fromRGB(215, 190, 240), CFrame.new(x, 48 + math.random() * 12, z))
		cloud.Transparency = 0.35
		cloud.CanCollide = false
		cloud.CanQuery = false
		cloud.CastShadow = false
	end
	-- Floating rocks above the crater, slowly bobbing (shared loop).
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local x = math.cos(angle) * 40
		local z = math.sin(angle) * 40
		local rock = part("FloatRock", Enum.PartType.Ball, Vector3.new(3, 2, 3), Color3.fromRGB(135, 120, 165), CFrame.new(x, 26 + math.random() * 8, z), Enum.Material.Slate)
		rock.CanCollide = false
		registerFloat(rock, 1.5)
	end
end

-- The crater, dressed: a low rocky rim wall, more lava cracks, steam,
-- a ring of crystals and a beacon beam so players see it from spawn.
local function buildCraterDecor()
	-- Rim wall: sixteen rock segments in a ring, low enough to step
	-- over in spirit, non-colliding so no one ever gets stuck on it.
	for i = 1, 16 do
		local angle = (i - 1) * (math.pi * 2 / 16)
		local x = math.cos(angle) * 30
		local z = math.sin(angle) * 30
		-- Tangent to the circle: a Y rotation of -angle - 90deg maps the
		-- segment's long X axis onto the tangent direction.
		local seg = part("CraterRim", Enum.PartType.Block, Vector3.new(11, 1.6, 2), Color3.fromRGB(110, 90, 120), CFrame.new(x, 1.1, z) * CFrame.Angles(0, -angle - math.rad(90), 0), Enum.Material.Slate)
		seg.CanCollide = false
	end
	-- Extra lava cracks on the bowl floor, brighter than the old three.
	local crackSpots = {
		{ -14, 10, 40 },
		{ 12, 12, -60 },
		{ 0, -16, 15 },
		{ 16, 2, 75 },
	}
	for _, spot in ipairs(crackSpots) do
		local crack = part("LavaCrack", Enum.PartType.Block, Vector3.new(10, 0.2, 1.2), Color3.fromRGB(255, 120, 30), CFrame.new(spot[1], 0.45, spot[2]) * CFrame.Angles(0, math.rad(spot[3]), 0), Enum.Material.Neon)
		crack.CanCollide = false
		crack.CastShadow = false
	end
	-- Steam: three soft emitters rising off the bowl floor.
	local steamSpots = { Vector3.new(-10, 0.5, 8), Vector3.new(12, 0.5, -6), Vector3.new(2, 0.5, 14) }
	for _, pos in ipairs(steamSpots) do
		local anchor = part("SteamAnchor", Enum.PartType.Block, Vector3.new(1, 1, 1), Color3.fromRGB(255, 255, 255), CFrame.new(pos))
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CastShadow = false
		local steam = Instance.new("ParticleEmitter")
		steam.Name = "CraterSteam"
		steam.Color = ColorSequence.new(Color3.fromRGB(220, 210, 235))
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
		steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		steam.Lifetime = NumberRange.new(2, 3.5)
		steam.Rate = 5
		steam.Speed = NumberRange.new(2, 4)
		steam.SpreadAngle = Vector2.new(25, 25)
		steam.Parent = anchor
	end
	-- Crystal ring around the rim: chunky wedges, mixed sizes/colours.
	for i = 1, 12 do
		local angle = (i - 1) * (math.pi * 2 / 12) + 0.26
		local x = math.cos(angle) * 33
		local z = math.sin(angle) * 33
		crystal(x, 0.4, z, 3 + math.random() * 2.5, 2 + math.random(), CRYSTAL_COLORS[math.random(1, #CRYSTAL_COLORS)], (math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5)
	end
	-- Beacon beam: a tall thin gold column from the crater centre,
	-- pulsing slowly so it reads from spawn. Kept dim (a bright beam
	-- plus Bloom washed the whole crater white): mostly transparent,
	-- with a soft light, not a floodlight.
	local beam = part("CraterBeacon", Enum.PartType.Cylinder, Vector3.new(90, 2.4, 2.4), Color3.fromRGB(255, 200, 60), CFrame.new(0, 45, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon)
	beam.Transparency = 0.6
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	local beamLight = Instance.new("PointLight")
	beamLight.Color = Color3.fromRGB(255, 200, 60)
	beamLight.Brightness = 1
	beamLight.Range = 25
	beamLight.Parent = beam
	local TweenService = game:GetService("TweenService")
	local pulse = TweenService:Create(beam, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.75,
	})
	pulse:Play()
end

-- The spawn platform, dressed: the bare cyan Neon slab is gone. A
-- warm stone trim frames the platform, a centre pad marks where to
-- stand, and four small corner posts with glowing tips finish it — so
-- spawn reads as a place, not a flat block.
local function buildSpawnDecor()
	local spawnCf = CFrame.new(94, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0)
	-- Trim: four warm-stone strips framing the 14x14 platform top.
	local trimColor = Color3.fromRGB(205, 185, 145)
	for _, side in ipairs({ -1, 1 }) do
		local trimX = part("SpawnTrim", Enum.PartType.Block, Vector3.new(14, 0.3, 1), trimColor, spawnCf * CFrame.new(0, 0.65, side * 6.5), Enum.Material.Slate)
		trimX.CanCollide = false
		trimX.CastShadow = false
		local trimZ = part("SpawnTrim", Enum.PartType.Block, Vector3.new(1, 0.3, 14), trimColor, spawnCf * CFrame.new(side * 6.5, 0.65, 0), Enum.Material.Slate)
		trimZ.CanCollide = false
		trimZ.CastShadow = false
	end
	-- Centre pad: a slate medallion where players stand.
	local pad = part("SpawnPad", Enum.PartType.Cylinder, Vector3.new(0.3, 6, 6), Color3.fromRGB(90, 70, 120), spawnCf * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Slate)
	pad.CanCollide = false
	pad.CastShadow = false
	-- Corner posts with glowing tips.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local post = part("SpawnDecor", Enum.PartType.Cylinder, Vector3.new(2, 0.6, 0.6), Color3.fromRGB(72, 62, 92), spawnCf * CFrame.new(sx * 6.5, 1.5, sz * 6.5) * CFrame.Angles(0, 0, math.rad(90)))
			post.CanCollide = false
			post.CastShadow = false
			local tip = part("SpawnDecor", Enum.PartType.Ball, Vector3.new(1, 1, 1), Color3.fromRGB(120, 220, 255), spawnCf * CFrame.new(sx * 6.5, 2.8, sz * 6.5), Enum.Material.Neon)
			tip.CanCollide = false
			tip.CastShadow = false
		end
	end
end

-- The SELL area: a gold pad on the path between spawn and the crater.
-- Carry a Rotling here and press E to sell it for a minute of its
-- income. Big gold SELL sign, so no one can miss it from spawn.
local function buildSellArea()
	local sellCf = CFrame.new(62, 0.5, 0)
	local pad = part("SellPad", Enum.PartType.Block, Vector3.new(12, 1, 12), Color3.fromRGB(255, 200, 60), sellCf, Enum.Material.Neon)
	pad.Transparency = 0.25
	pad.CanCollide = false
	pad.CastShadow = false
	-- Gold trim ring around the pad.
	for _, side in ipairs({ -1, 1 }) do
		local trimX = part("SellTrim", Enum.PartType.Block, Vector3.new(12, 0.4, 1), Color3.fromRGB(255, 240, 150), sellCf * CFrame.new(0, 0.6, side * 6), Enum.Material.SmoothPlastic)
		trimX.CanCollide = false
		trimX.CastShadow = false
		local trimZ = part("SellTrim", Enum.PartType.Block, Vector3.new(1, 0.4, 12), Color3.fromRGB(255, 240, 150), sellCf * CFrame.new(side * 6, 0.6, 0), Enum.Material.SmoothPlastic)
		trimZ.CanCollide = false
		trimZ.CastShadow = false
	end
	-- The SELL sign: a gold billboard on two posts behind the pad.
	local postColor = Color3.fromRGB(72, 62, 92)
	for _, sx in ipairs({ -1, 1 }) do
		local post = part("SellPost", Enum.PartType.Cylinder, Vector3.new(6, 0.8, 0.8), postColor, sellCf * CFrame.new(sx * 4, 3.5, -6.5) * CFrame.Angles(0, 0, math.rad(90)))
		post.CanCollide = false
	end
	local board = part("SellBoard", Enum.PartType.Block, Vector3.new(10, 4, 0.5), Color3.fromRGB(20, 15, 40), sellCf * CFrame.new(0, 7, -6.5))
	board.CanCollide = false
	board.CastShadow = false
	local sign = Instance.new("BillboardGui")
	sign.Name = "SellSign"
	sign.Size = UDim2.fromOffset(300, 120)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 80
	sign.Parent = board
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
	local sellHint = Instance.new("TextLabel")
	sellHint.Name = "SellHint"
	sellHint.Size = UDim2.new(1, 0, 0.45, 0)
	sellHint.Position = UDim2.new(0, 0, 0.55, 0)
	sellHint.BackgroundTransparency = 1
	sellHint.Text = "Carry a Rotling here, press E"
	sellHint.Font = Enum.Font.FredokaOne
	sellHint.TextScaled = true
	sellHint.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellHint.TextStrokeTransparency = 0.3
	sellHint.Parent = sign
	-- Press E on the pad to sell what you carry.
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.ActionText = "Sell Rotling"
	sellPrompt.ObjectText = "SELL — 1 min of income"
	sellPrompt.HoldDuration = 0
	sellPrompt.MaxActivationDistance = 12
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = pad
end

-- Plaza decor: bright flag poles ringing the crater and warm lanterns
-- flanking the path from spawn, so the middle of the map reads as a
-- busy plaza instead of empty ground.
local function buildPlazaDecor()
	local flagColors = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(80, 230, 220),
		Color3.fromRGB(255, 110, 200),
		Color3.fromRGB(120, 255, 150),
		Color3.fromRGB(255, 160, 90),
		Color3.fromRGB(170, 120, 255),
		Color3.fromRGB(120, 200, 255),
	}
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8) + 0.39
		local x = math.cos(angle) * 36
		local z = math.sin(angle) * 36
		local color = flagColors[i]
		local pole = part("PlazaFlagPole", Enum.PartType.Cylinder, Vector3.new(9, 0.6, 0.6), Color3.fromRGB(72, 62, 92), CFrame.new(x, 4.5, z) * CFrame.Angles(0, 0, math.rad(90)))
		pole.CanCollide = false
		local flag = part("PlazaFlag", Enum.PartType.Block, Vector3.new(0.4, 2.5, 3.5), color, CFrame.new(x, 8, z) * CFrame.Angles(0, -angle + math.rad(90), 0), Enum.Material.Neon)
		flag.CanCollide = false
		flag.CastShadow = false
	end
	-- Lantern posts flanking the spawn-to-crater path.
	for _, z in ipairs({ -8, 8 }) do
		local post = part("PlazaLantern", Enum.PartType.Cylinder, Vector3.new(5, 0.7, 0.7), Color3.fromRGB(72, 62, 92), CFrame.new(78, 2.5, z) * CFrame.Angles(0, 0, math.rad(90)))
		post.CanCollide = false
		local lamp = part("PlazaLamp", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(255, 220, 130), CFrame.new(78, 5.4, z), Enum.Material.Neon)
		lamp.CanCollide = false
		lamp.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 220, 130)
		light.Brightness = 0.6
		light.Range = 14
		light.Parent = lamp
	end
end

-- Storm wind: horizontal streak emitters, off until a storm starts.
local function buildWind()
	for _, x in ipairs({ -70, 0, 70 }) do
		local anchor = part("WindAnchor", Enum.PartType.Block, Vector3.new(1, 1, 1), Color3.fromRGB(255, 255, 255), CFrame.new(x, 24, 0))
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CastShadow = false
		local wind = Instance.new("ParticleEmitter")
		wind.Name = "StormWind"
		wind.Color = ColorSequence.new(Color3.fromRGB(230, 225, 245))
		wind.Size = NumberSequence.new(0.25)
		wind.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		wind.Lifetime = NumberRange.new(1.2, 2)
		wind.Rate = 30
		wind.Speed = NumberRange.new(35, 50)
		wind.SpreadAngle = Vector2.new(8, 8)
		wind.Enabled = false
		wind.Parent = anchor
		table.insert(windEmitters, wind)
	end
end

-- Turn the storm wind on or off (called by StarfallService).
function WorldBuilder.setWind(enabled: boolean)
	for _, emitter in ipairs(windEmitters) do
		emitter.Enabled = enabled
	end
end

-- The static skeleton (ground, crater, glow, lava cracks, spawn) lives in
-- default.project.json as direct CFrame arrays. Rojo 7.7.1 silently drops
-- "Position" and "Rotation" properties (verified by a minimal test build:
-- a Part with Position+Rotation gets NO CFrame in the rbxl, only a direct
-- "CFrame" array is written), so the project file MUST use CFrame. As a
-- belt-and-braces guarantee, fixTerrain() re-asserts the same CFrames in
-- code at boot, so the world is flat and correct in Studio even if the
-- project file's CFrame is ever lost again.
local function fixTerrain()
	local function setCFrame(name: string, cf: CFrame)
		local inst = workspace:FindFirstChild(name)
		if inst and inst:IsA("BasePart") then
			inst.CFrame = cf
		else
			warn("[WorldBuilder] terrain part missing: " .. name)
		end
	end
	-- Flat discs: a Roblox cylinder's axis is X; rotating 90 deg about Z
	-- makes the axis vertical, so Size [0.4, 56, 56] is a flat disc 0.4
	-- thick and 56 wide. The glow ring is 58 wide, a 1-stud neon rim.
	setCFrame("Crater", CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
	setCFrame("CraterGlow", CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)))
	setCFrame("Ground", CFrame.new(0, -10, 0))
	setCFrame("LavaCrack1", CFrame.new(-8, 0.45, 6) * CFrame.Angles(0, math.rad(35), 0))
	setCFrame("LavaCrack2", CFrame.new(10, 0.45, -8) * CFrame.Angles(0, math.rad(-50), 0))
	setCFrame("LavaCrack3", CFrame.new(2, 0.45, 14) * CFrame.Angles(0, math.rad(80), 0))
	setCFrame("SpawnLocation", CFrame.new(94, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0))
end

function WorldBuilder.build()
	math.randomseed(os.time())
	fixTerrain()
	for baseId = 1, Config.BASE_COUNT do
		buildBase(baseId)
	end
	buildPaths()
	buildSpawnDecor()
	buildSellArea()
	buildPlazaDecor()
	buildTrees()
	buildRocksAndMushrooms()
	buildHills()
	buildCrystalClusters()
	buildFloatingIslands()
	buildSkyDecor()
	buildCraterDecor()
	buildWind()
	startFloatBob()
end

return WorldBuilder
