--!strict
-- Starfall Rotlings: builds a Rotling Model from a RotlingCatalog definition.
-- Every creature is Parts only: a body, a belly, big eyes, feet, one
-- accessory, a rarity glow light, a mutation sparkle and a name/rarity/
-- coins-per-second label. No meshes, decals or uploaded assets are used
-- anywhere. The body starts Anchored so a free Rotling rests on the
-- crater floor instead of falling through the world; carrying un-anchors
-- it and welds it to the player, placing re-anchors it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)

local RotlingFactory = {}

local function makePart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = 0 -- opaque: Rotlings must read as solid characters, never ghosts
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	return part
end

local function addEyes(model: Model, body: Part, size: number)
	-- Two big white eyes with dark pupils on the front face, large enough
	-- to read from across the crater.
	local eyeSize = size * 0.26
	local eyeY = size * 0.18
	local eyeZ = body.Size.Z / 2 + eyeSize * 0.35
	for _, side in ipairs({ -1, 1 }) do
		local white = makePart("Eye", Enum.PartType.Ball, Vector3.new(eyeSize, eyeSize, eyeSize), Color3.fromRGB(255, 255, 255))
		white.CFrame = body.CFrame * CFrame.new(side * size * 0.22, eyeY, eyeZ)
		white.Parent = model
		local pupil = makePart("Pupil", Enum.PartType.Ball, Vector3.new(eyeSize * 0.5, eyeSize * 0.5, eyeSize * 0.5), Color3.fromRGB(20, 20, 30))
		pupil.CFrame = body.CFrame * CFrame.new(side * size * 0.22, eyeY, eyeZ + eyeSize * 0.35)
		pupil.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = white
		weld.Parent = white
		local weld2 = Instance.new("WeldConstraint")
		weld2.Part0 = body
		weld2.Part1 = pupil
		weld2.Parent = pupil
	end
end

local function addMouth(model: Model, body: Part, size: number)
	-- A dark smile under the eyes, so the face reads as a character.
	local mouth = makePart("Mouth", Enum.PartType.Block, Vector3.new(size * 0.3, size * 0.07, size * 0.06), Color3.fromRGB(30, 20, 30))
	mouth.CFrame = body.CFrame * CFrame.new(0, -size * 0.08, body.Size.Z / 2 + size * 0.03)
	mouth.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = mouth
	weld.Parent = mouth
end

local function addFeet(model: Model, body: Part, size: number)
	for _, side in ipairs({ -1, 1 }) do
		local foot = makePart("Foot", Enum.PartType.Block, Vector3.new(size * 0.28, size * 0.14, size * 0.4), Color3.fromRGB(40, 40, 50))
		foot.CFrame = body.CFrame * CFrame.new(side * size * 0.24, -size * 0.5, size * 0.08)
		foot.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = foot
		weld.Parent = foot
	end
end

local function addAccessory(model: Model, body: Part, def: RotlingCatalog.RotlingDef, rarityColor: Color3)
	local size = def.size
	local top = body.CFrame * CFrame.new(0, size * 0.55, 0)
	if def.accessory == "horns" then
		for _, side in ipairs({ -1, 1 }) do
			local horn = makePart("Horn", Enum.PartType.Wedge, Vector3.new(size * 0.16, size * 0.4, size * 0.16), Color3.fromRGB(240, 220, 180))
			horn.CFrame = top * CFrame.new(side * size * 0.3, size * 0.15, 0) * CFrame.Angles(0, 0, side * -0.5)
			horn.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = horn
			weld.Parent = horn
		end
	elseif def.accessory == "hat" then
		local brim = makePart("HatBrim", Enum.PartType.Cylinder, Vector3.new(size * 0.12, size * 0.7, size * 0.7), Color3.fromRGB(60, 50, 90))
		brim.CFrame = top * CFrame.Angles(0, 0, math.rad(90))
		brim.Parent = model
		local crown = makePart("HatTop", Enum.PartType.Cylinder, Vector3.new(size * 0.35, size * 0.4, size * 0.4), Color3.fromRGB(60, 50, 90))
		crown.CFrame = top * CFrame.new(0, size * 0.18, 0) * CFrame.Angles(0, 0, math.rad(90))
		crown.Parent = model
		for _, part in ipairs({ brim, crown }) do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	elseif def.accessory == "antenna" then
		local stem = makePart("Antenna", Enum.PartType.Cylinder, Vector3.new(size * 0.5, size * 0.08, size * 0.08), rarityColor)
		stem.CFrame = top * CFrame.new(0, size * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90))
		stem.Parent = model
		local tip = makePart("AntennaTip", Enum.PartType.Ball, Vector3.new(size * 0.22, size * 0.22, size * 0.22), Color3.fromRGB(255, 255, 150))
		tip.Material = Enum.Material.Neon
		tip.CFrame = top * CFrame.new(0, size * 0.48, 0)
		tip.Parent = model
		for _, part in ipairs({ stem, tip }) do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	elseif def.accessory == "crown" then
		local band = makePart("Crown", Enum.PartType.Cylinder, Vector3.new(size * 0.16, size * 0.55, size * 0.55), Color3.fromRGB(255, 215, 0))
		band.Material = Enum.Material.Metal
		band.CFrame = top * CFrame.Angles(0, 0, math.rad(90))
		band.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = band
		weld.Parent = band
		for i = 1, 3 do
			local spike = makePart("CrownSpike", Enum.PartType.Wedge, Vector3.new(size * 0.1, size * 0.22, size * 0.1), Color3.fromRGB(255, 215, 0))
			spike.Material = Enum.Material.Metal
			spike.CFrame = top * CFrame.new((i - 2) * size * 0.18, size * 0.14, 0)
			spike.Parent = model
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = spike
			w.Parent = spike
		end
	elseif def.accessory == "headphones" then
		for _, side in ipairs({ -1, 1 }) do
			local cup = makePart("Headphone", Enum.PartType.Cylinder, Vector3.new(size * 0.12, size * 0.3, size * 0.3), Color3.fromRGB(30, 30, 40))
			cup.CFrame = body.CFrame * CFrame.new(side * (body.Size.X / 2 + size * 0.04), size * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90))
			cup.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = cup
			weld.Parent = cup
		end
	elseif def.accessory == "cape" then
		local cape = makePart("Cape", Enum.PartType.Wedge, Vector3.new(size * 0.1, size * 0.9, size * 0.9), Color3.fromRGB(160, 20, 60))
		cape.CFrame = body.CFrame * CFrame.new(0, -size * 0.05, -body.Size.Z / 2 - size * 0.1) * CFrame.Angles(0, math.rad(180), 0)
		cape.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = cape
		weld.Parent = cape
	elseif def.accessory == "star" then
		local star = makePart("Star", Enum.PartType.Ball, Vector3.new(size * 0.3, size * 0.3, size * 0.3), Color3.fromRGB(255, 240, 120))
		star.Material = Enum.Material.Neon
		star.CFrame = top * CFrame.new(0, size * 0.35, 0)
		star.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = star
		weld.Parent = star
	end
end

local function addLabel(model: Model, body: Part, def: RotlingCatalog.RotlingDef, mutation: string?)
	local rarity = RarityConfig.rarityByName(def.rarity)
	local cps = RotlingCatalog.baseCps(def, mutation)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RotlingLabel"
	billboard.Size = UDim2.fromOffset(160, 72)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, def.size * 0.85, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Position = UDim2.new(0, 0, 0.4, 0)
	rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLabel.BackgroundTransparency = 1
	local rarityText = def.rarity
	if mutation then
		rarityText ..= " " .. mutation
	end
	rarityLabel.Text = rarityText
	rarityLabel.Font = Enum.Font.FredokaOne
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = rarity.color
	rarityLabel.TextStrokeTransparency = 0.4
	rarityLabel.Parent = billboard

	local cpsLabel = Instance.new("TextLabel")
	cpsLabel.Name = "Cps"
	cpsLabel.Position = UDim2.new(0, 0, 0.7, 0)
	cpsLabel.Size = UDim2.new(1, 0, 0.3, 0)
	cpsLabel.BackgroundTransparency = 1
	cpsLabel.Text = "$" .. tostring(math.floor(cps)) .. "/s"
	cpsLabel.Font = Enum.Font.FredokaOne
	cpsLabel.TextScaled = true
	cpsLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
	cpsLabel.TextStrokeTransparency = 0.4
	cpsLabel.Parent = billboard
end

-- Mutation sparkle: a slow particle emitter in the mutation's colour.
local function addMutationSparkle(model: Model, body: Part, mutation: string?)
	local mut = MutationConfig.mutationByName(mutation)
	if not mut then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MutationSparkle"
	emitter.Color = ColorSequence.new(mut.color)
	emitter.Size = NumberSequence.new(0.4)
	emitter.Transparency = NumberSequence.new(0.2, 0.9)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Parent = body
end

-- Rarity outline so a placed Rotling glows its tier colour from afar.
local function addRarityHighlight(model: Model, rarityColor: Color3)
	local highlight = Instance.new("Highlight")
	highlight.Name = "RarityGlow"
	highlight.FillColor = rarityColor
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = rarityColor
	highlight.OutlineTransparency = 0.25
	highlight.Parent = model
end

-- Repaint a live Rotling when its mutation changes (Starstruck at runtime).
function RotlingFactory.applyMutationVisual(model: Model, mutation: string?)
	local body = model.PrimaryPart
	if not body or not body:IsA("BasePart") then
		return
	end
	local mut = MutationConfig.mutationByName(mutation)
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	if not def then
		return
	end
	if mutation == "Gold" then
		body.Color = Color3.fromRGB(255, 215, 0)
	elseif mutation == "Frozen" then
		body.Color = Color3.fromRGB(170, 225, 255)
	elseif mutation == "Starstruck" then
		body.Color = Color3.fromRGB(255, 240, 170)
		body.Material = Enum.Material.Neon
	end
	local old = body:FindFirstChild("MutationSparkle")
	if old then
		old:Destroy()
	end
	addMutationSparkle(model, body, mutation)
	if mut then
		local light = body:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = mut.glow
		end
	end
	-- Refresh the label's rarity line and coins-per-second.
	local label = body:FindFirstChild("RotlingLabel")
	if label then
		local rarityLabel = label:FindFirstChild("Rarity")
		if rarityLabel and rarityLabel:IsA("TextLabel") then
			local text = def.rarity
			if mutation then
				text ..= " " .. mutation
			end
			rarityLabel.Text = text
		end
		local cpsLabel = label:FindFirstChild("Cps")
		if cpsLabel and cpsLabel:IsA("TextLabel") then
			cpsLabel.Text = "$" .. tostring(math.floor(RotlingCatalog.baseCps(def, mutation))) .. "/s"
		end
	end
end

-- Build a Rotling Model at the given position, unowned and free.
function RotlingFactory.build(defId: string, mutation: string?, position: Vector3): Model?
	local def = RotlingCatalog.getDef(defId)
	if not def then
		return nil
	end
	local rarity = RarityConfig.rarityByName(def.rarity)
	local size = def.size

	local model = Instance.new("Model")
	model.Name = def.name

	local bodySize: Vector3
	local bodyShape: Enum.PartType
	if def.body == "ball" then
		bodySize = Vector3.new(size, size, size)
		bodyShape = Enum.PartType.Ball
	elseif def.body == "tall" then
		bodySize = Vector3.new(size * 0.62, size, size * 0.62)
		bodyShape = Enum.PartType.Block
	elseif def.body == "wide" then
		bodySize = Vector3.new(size * 1.25, size * 0.7, size * 0.9)
		bodyShape = Enum.PartType.Block
	else
		bodySize = Vector3.new(size * 0.9, size * 0.85, size * 0.9)
		bodyShape = Enum.PartType.Block
	end

	local bodyColor = def.bodyColor
	if mutation == "Gold" then
		bodyColor = Color3.fromRGB(255, 215, 0)
	elseif mutation == "Frozen" then
		bodyColor = Color3.fromRGB(170, 225, 255)
	elseif mutation == "Starstruck" then
		bodyColor = Color3.fromRGB(255, 240, 170)
	end
	local body = makePart("Body", bodyShape, bodySize, bodyColor)
	body.Material = if mutation == "Rainbow" or mutation == "Starstruck" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	-- Rest the body's bottom on the given surface: centre it half its
	-- own height above the position, so no Rotling is ever sunk into the
	-- crater disc or a pad by a fixed size*0.55 guess.
	body.CFrame = CFrame.new(position + Vector3.new(0, bodySize.Y / 2 + 0.1, 0))
	body.Anchored = true -- rests on the crater floor; carrying un-anchors it
	body.Parent = model
	model.PrimaryPart = body

	-- Belly patch on the front.
	local belly = makePart("Belly", Enum.PartType.Ball, Vector3.new(size * 0.5, size * 0.45, size * 0.2), def.bellyColor)
	belly.CFrame = body.CFrame * CFrame.new(0, -size * 0.12, bodySize.Z / 2)
	belly.Parent = model
	local bellyWeld = Instance.new("WeldConstraint")
	bellyWeld.Part0 = body
	bellyWeld.Part1 = belly
	bellyWeld.Parent = belly

	addEyes(model, body, size)
	addMouth(model, body, size)
	addFeet(model, body, size)
	addAccessory(model, body, def, rarity.color)
	addLabel(model, body, def, mutation)
	addMutationSparkle(model, body, mutation)
	addRarityHighlight(model, rarity.color)

	-- Rarity glow.
	local mut = MutationConfig.mutationByName(mutation)
	local light = Instance.new("PointLight")
	light.Color = if mut then mut.glow else rarity.color
	light.Brightness = 2
	light.Range = 12
	light.Parent = body

	-- State the rest of the server reads and writes.
	model:SetAttribute("DefId", defId)
	model:SetAttribute("Mutation", mutation or "")
	model:SetAttribute("State", "free") -- free | carried | placed
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("BaseId", 0)
	model:SetAttribute("PadIndex", 0)

	-- Grab prompt. The server validates every trigger.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab " .. def.name
	prompt.ObjectText = def.rarity .. (mutation and (" " .. mutation) or "")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	return model
end

return RotlingFactory
