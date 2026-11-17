--!strict
-- Starfall Rotlings: builds the world at server start.
-- The static skeleton (ground, crater, lighting, sky, spawn) lives in
-- default.project.json; everything repetitive or placed by data lives
-- here: the eight bases, their pads, the lock gates, purple alien trees,
-- rocks, mushrooms, stars and clouds. All positions come from Config, so
-- the layout can be re-tuned without touching the project file. The
-- palette is space-sunset on purpose: purple ground, teal crater glow,
-- orange meteors — nothing like a green field.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

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
local padParts: { [number]: { [number]: Part } } = {}
local baseTrims: { [number]: Part } = {}
local baseFlags: { [number]: Part } = {}

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

-- Recolour a base's trim, flag and pads (rebirth reward).
function WorldBuilder.setBaseColor(baseId: number, color: Color3)
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

	local color = BASE_COLORS[baseId]

	-- Platform.
	part("BasePlatform", Enum.PartType.Block, Vector3.new(26, 2, 22), Color3.fromRGB(115, 100, 150), cf * CFrame.new(0, 0, 0))
	-- Trim: a bright edge strip on the crater side.
	local trim = part("BaseTrim", Enum.PartType.Block, Vector3.new(26, 0.6, 1), color, cf * CFrame.new(0, 1.1, -11))
	baseTrims[baseId] = trim
	-- Back wall so placed Rotlings read as "home".
	local wall = part("BaseWall", Enum.PartType.Block, Vector3.new(26, 8, 1.5), Color3.fromRGB(88, 78, 118), cf * CFrame.new(0, 5, 10.5))
	wall.Transparency = 0.15
	-- Banner pole + flag + sign.
	local pole = part("BannerPole", Enum.PartType.Cylinder, Vector3.new(12, 1, 1), Color3.fromRGB(72, 62, 92), cf * CFrame.new(-11, 7, 9) * CFrame.Angles(0, 0, math.rad(90)))
	pole.CanCollide = false
	local flag = part("BannerFlag", Enum.PartType.Block, Vector3.new(0.4, 3.5, 5), color, cf * CFrame.new(-11, 11, 6.5))
	flag.Material = Enum.Material.Neon
	flag.CanCollide = false
	baseFlags[baseId] = flag
	local sign = Instance.new("BillboardGui")
	sign.Name = "BaseSign"
	sign.Size = UDim2.fromOffset(180, 56)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.Parent = flag
	local signLabel = Instance.new("TextLabel")
	signLabel.Name = "BaseLabel"
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "Base " .. tostring(baseId)
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Parent = sign
	signLabels[baseId] = signLabel

	-- Pads: glowing plates the Rotlings stand on.
	for padIndex, offset in ipairs(PAD_OFFSETS) do
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
	-- Glowing mushrooms ring the crater.
	local mushroomColors = {
		Color3.fromRGB(255, 120, 180),
		Color3.fromRGB(120, 220, 255),
		Color3.fromRGB(180, 255, 120),
	}
	for _ = 1, 16 do
		local angle = math.random() * math.pi * 2
		local radius = Config.CRATER_RADIUS + 4 + math.random() * 14
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local color = mushroomColors[math.random(1, #mushroomColors)]
		local stem = part("MushroomStem", Enum.PartType.Cylinder, Vector3.new(1.6, 0.7, 0.7), Color3.fromRGB(240, 235, 220), CFrame.new(x, 0.8, z) * CFrame.Angles(0, 0, math.rad(90)))
		stem.CanCollide = false
		local cap = part("MushroomCap", Enum.PartType.Ball, Vector3.new(2.2, 1.1, 2.2), color, CFrame.new(x, 1.9, z), Enum.Material.Neon)
		cap.CanCollide = false
	end
end

local function buildSkyDecor()
	-- Stars: small glowing spheres high above the map.
	for _ = 1, 80 do
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
	-- Floating rocks above the crater, slowly bobbing (animated by Storm).
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local x = math.cos(angle) * 40
		local z = math.sin(angle) * 40
		local rock = part("FloatRock", Enum.PartType.Ball, Vector3.new(3, 2, 3), Color3.fromRGB(135, 120, 165), CFrame.new(x, 26 + math.random() * 8, z), Enum.Material.Slate)
		rock.CanCollide = false
		rock:SetAttribute("FloatSeed", i * 1.7)
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
	buildTrees()
	buildRocksAndMushrooms()
	buildSkyDecor()
end

return WorldBuilder
