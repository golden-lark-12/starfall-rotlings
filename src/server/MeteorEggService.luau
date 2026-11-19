--!strict
-- Starfall Rotlings: meteor eggs.
-- A storm drops four glowing eggs on the open field. They are heavy:
-- carrying one slows you down, and every rival on the map will come
-- for you while you lug it home. Set it on your base incubator and it
-- hatches into a Rotling after a wait that grows with the rarity
-- inside (a Common pops in a minute, a Divine takes six). The egg
-- never tells you what is inside while it sits on the ground — the
-- reveal happens on the incubator. One hatch in six or seven comes
-- out Meteor-scorched, and every hatch pays Stardust. Get hit,
-- slapped, or killed and the egg drops where you stand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
local BoostService = require(script.Parent.BoostService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local FeedbackService = require(script.Parent.FeedbackService)
local RotlingFactory = require(script.Parent.RotlingFactory)
local SpawnService = require(script.Parent.SpawnService)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local MeteorEggService = {}

-- The live legendary drop, if one is on the map right now.
local legendaryEggModel: Model? = nil
local legendaryBeam: Part? = nil

-- Rewrite the text on an egg's floating label. Every label change in
-- this file goes through here so the billboard lookup lives in one
-- place: the label is a TextLabel inside the EggLabel billboard that
-- hangs off the shell.
local function setEggLabel(model: Model, text: string)
	local shell = model.PrimaryPart
	local board = shell and shell:FindFirstChild("EggLabel")
	local label = board and board:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
	end
end

-- Pick a landing spot for a storm egg: open field only. The crater
-- floor and the belt are Rotling ground, and the busy corners of the
-- map (SELL pad, shop, altar, spawn) would hide an egg behind a
-- building or drop it where a Brainrot belongs. Ten tries to find a
-- clear spot, then a fixed fallback in the open field.
local function eggPosition(): Vector3
	for _ = 1, 10 do
		local angle = math.random() * math.pi * 2
		local radius = math.random(48, 130)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local nearBase = false
		for baseId = 1, Config.BASE_COUNT do
			local centre = WorldBuilder.baseCFrame(baseId)
			if centre and (pos - centre.Position).Magnitude < 24 then
				nearBase = true
				break
			end
		end
		if nearBase then
			continue
		end
		local onSell = math.abs(pos.X - 62) < 14 and math.abs(pos.Z) < 14
		local onShop = math.abs(pos.X + 45) < 16 and math.abs(pos.Z - 45) < 14
		local onAltar = math.abs(pos.X) < 12 and math.abs(pos.Z + 70) < 12
		local onSpawn = math.abs(pos.X) < 20 and pos.Z > 70
		if not onSell and not onShop and not onAltar and not onSpawn then
			return pos
		end
	end
	return Vector3.new(60, 0, -60)
end

-- Roll an egg's rarity from the egg-only weight table. Eggs are
-- kinder than crater spawns: Commons dominate, but every tier up to
-- Divine is on the table, so a storm egg can always surprise you.
local function rollEggRarity(): string
	local total = 0
	for _, weight in ipairs(Config.EGG_RARITY_WEIGHTS) do
		total += weight
	end
	local roll = math.random(1, total)
	local running = 0
	for tier = 1, 7 do
		running += Config.EGG_RARITY_WEIGHTS[tier]
		if roll <= running then
			return RarityConfig.ORDER[tier]
		end
	end
	return RarityConfig.ORDER[1]
end

-- Roll what is inside an egg: a random creature from the rolled
-- rarity's pool, plus a mutation. Scorched is the egg mutation — a
-- flat chance, rolled before the normal mutation table so an egg can
-- come out Meteor-scorched instead of Gold or Rainbow.
local function rollHatchDef(): (RotlingCatalog.RotlingDef, string?)
	local rarity = rollEggRarity()
	local pool = RotlingCatalog.defsOfRarity(rarity)
	local def = pool[math.random(1, #pool)]
	if math.random() < Config.EGG_SCORCHED_CHANCE then
		return def, "Scorched"
	end
	return def, MutationConfig.rollMutation()
end

-- How long an egg of this rarity sits on the incubator before it
-- pops. Rarer takes longer, straight from the per-rarity table.
local function hatchTimeForRarity(rarity: string): number
	local tier = RarityConfig.rarityTier(rarity)
	return Config.EGG_HATCH_TIME[tier] or Config.EGG_HATCH_TIME[1]
end

-- Build one meteor egg at a map position. The shell is a tall ovoid
-- (ratio 1.5, cream, not a ball), with two smooth coloured bands
-- wrapped around it and welded on, a warm glow, a mystery label, and
-- a grab prompt. It spawns high above the spot and falls — the caller
-- tweens it down. Nothing here names a rarity: on the ground every
-- egg looks exactly the same.
local function buildEgg(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Meteor Egg"
	local shell = Instance.new("Part")
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(3.2, 4.8, 3.2)
	shell.Color = Color3.fromRGB(255, 244, 214)
	shell.Material = Enum.Material.SmoothPlastic
	shell.Anchored = true
	shell.CanCollide = true
	shell.CFrame = CFrame.new(position + Vector3.new(0, 100, 0))
	shell.Parent = model
	model.PrimaryPart = shell
	-- The layered look: two flattened balls hugging the shell, one
	-- purple high up, one teal low down, each wider than the shell at
	-- its own height so the rim shows. Welded, so they ride the shell.
	local bands = {
		{ 0.8, 3.3, Color3.fromRGB(190, 150, 255) },
		{ -0.9, 3.2, Color3.fromRGB(120, 220, 200) },
	}
	for _, spec in ipairs(bands) do
		local band = Instance.new("Part")
		band.Name = "EggBand"
		band.Shape = Enum.PartType.Ball
		band.Size = Vector3.new(spec[2], 0.6, spec[2])
		band.Color = spec[3]
		band.Material = Enum.Material.SmoothPlastic
		band.Anchored = true
		band.CanCollide = false
		band.CFrame = shell.CFrame * CFrame.new(0, spec[1], 0)
		band.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = shell
		weld.Part1 = band
		weld.Parent = band
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 130)
	light.Brightness = 2
	light.Range = 16
	light.Parent = shell
	local board = Instance.new("BillboardGui")
	board.Name = "EggLabel"
	board.Size = UDim2.fromOffset(200, 40)
	board.ExtentsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	board.MaxDistance = 60
	board.AlwaysOnTop = true
	board.Parent = shell
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "🥚 METEOR EGG"
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 20
	label.TextScaled = true
	label.Parent = board
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab Meteor Egg"
	prompt.ObjectText = "Heavy! Walk slower"
	prompt.MaxActivationDistance = 8
	prompt.Parent = shell
	prompt.Triggered:Connect(function(player: Player)
		MeteorEggService.grabEgg(player, model)
	end)
	model.Parent = workspace
	return model
end

-- Drop EGGS_PER_STORM eggs per storm at random spots: each falls from
-- the sky to its landing spot over 1.2s, then sits grabbable for five
-- minutes. The hatch is rolled NOW, at spawn, and stored on the egg —
-- the incubator wait scales with what is actually inside, and the
-- ground egg can stay a mystery while still knowing its own secret.
function MeteorEggService.spawnEggsForStorm()
	for _ = 1, Config.EGGS_PER_STORM do
		local hatchDef, hatchMutation = rollHatchDef()
		local spot = eggPosition()
		local model = buildEgg(spot)
		local shell = model.PrimaryPart
		State.eggs[model] = {
			model = model,
			phase = "falling",
			carrier = nil,
			baseId = nil,
			hatchAt = nil,
			hatchDef = hatchDef.id,
			hatchMutation = hatchMutation,
			bornAt = time(),
		}
		if shell and shell:IsA("BasePart") then
			local fall = TweenService:Create(
				shell,
				TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = CFrame.new(spot + Vector3.new(0, 2.4, 0)) }
			)
			fall.Completed:Connect(function()
				local entry = State.eggs[model]
				if entry and entry.phase == "falling" then
					entry.phase = "ground"
				end
			end)
			fall:Play()
		end
		-- Five minutes on the ground, then it is gone: a storm egg
		-- nobody grabs fades rather than littering the field all
		-- match. Carried and incubating eggs are untouched.
		task.delay(300, function()
			local entry = State.eggs[model]
			if entry and (entry.phase == "ground" or entry.phase == "falling") then
				State.eggs[model] = nil
				model:Destroy()
			end
		end)
	end
	print("[MeteorEgg] storm dropped " .. tostring(Config.EGGS_PER_STORM) .. " eggs")
end

-- Clear the gold beam that marks the legendary drop.
local function clearLegendaryBeam()
	if legendaryBeam then
		legendaryBeam:Destroy()
		legendaryBeam = nil
	end
end

-- The legendary drop: every 240s (first one a minute after boot) a
-- single gold egg falls into the crater — same layered shape, gold
-- all over, under a gold beam, announced to the whole server. It
-- hatches into a Legendary, guaranteed: the hatch is forced at spawn.
-- Grab it within 75s or it vanishes. Only one can be live at a time.
local function spawnLegendaryEgg()
	if legendaryEggModel then
		return
	end
	local pool = RotlingCatalog.defsOfRarity("Legendary")
	if #pool == 0 then
		return
	end
	local def = pool[math.random(1, #pool)]
	local angle = math.random() * math.pi * 2
	local radius = math.random(5, 24)
	local target = Vector3.new(math.cos(angle) * radius, Config.CRATER_FLOOR_Y, math.sin(angle) * radius)
	local model = buildEgg(target)
	local shell = model.PrimaryPart
	if shell and shell:IsA("BasePart") then
		shell.Color = Color3.fromRGB(255, 215, 0)
		local glow = shell:FindFirstChildOfClass("PointLight")
		if glow then
			glow.Color = Color3.fromRGB(255, 215, 0)
			glow.Range = 30
		end
	end
	for _, child in ipairs(model:GetDescendants()) do
		if child.Name == "EggBand" then
			child.Color = Color3.fromRGB(255, 215, 0)
		end
	end
	setEggLabel(model, "🌟 LEGENDARY EGG — " .. tostring(Config.LEGENDARY_EGG_LIFETIME) .. "s!")
	local beam = Instance.new("Part")
	beam.Name = "LegendaryEggBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(40, 3, 3)
	beam.Color = Color3.fromRGB(255, 215, 0)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.3
	beam.Anchored = true
	beam.CanCollide = false
	beam.CFrame = CFrame.new(target + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	legendaryBeam = beam
	legendaryEggModel = model
	State.eggs[model] = {
		model = model,
		phase = "falling",
		carrier = nil,
		baseId = nil,
		hatchAt = nil,
		hatchDef = def.id,
		hatchMutation = nil,
		bornAt = time(),
	}
	if shell and shell:IsA("BasePart") then
		local fall = TweenService:Create(
			shell,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(target + Vector3.new(0, 2.4, 0)) }
		)
		fall.Completed:Connect(function()
			local entry = State.eggs[model]
			if entry and entry.phase == "falling" then
				entry.phase = "ground"
			end
		end)
		fall:Play()
	end
	Remotes.bannerEvent():FireAllClients("🌟 LEGENDARY EGG HAS FALLEN IN THE CRATER — grab it in " .. tostring(Config.LEGENDARY_EGG_LIFETIME) .. "s!", 6)
	for _, player in ipairs(Players:GetPlayers()) do
		FeedbackService.playSound(player, 1.6, 0.9)
	end
	print("[MeteorEgg] legendary egg dropped in the crater")
	task.delay(Config.LEGENDARY_EGG_LIFETIME, function()
		local entry = State.eggs[model]
		if entry and (entry.phase == "ground" or entry.phase == "falling") then
			State.eggs[model] = nil
			legendaryEggModel = nil
			clearLegendaryBeam()
			model:Destroy()
			Remotes.bannerEvent():FireAllClients("💨 The legendary egg vanished…", 4)
			print("[MeteorEgg] LEGENDARY egg vanished unclaimed")
		end
	end)
end

-- Pick up a meteor egg. Everything is validated BEFORE any state
-- changes: a failed grab logs and leaves the egg exactly as it was.
function MeteorEggService.grabEgg(player: Player, model: Model)
	local entry = State.eggs[model]
	if not entry then
		print("[MeteorEgg] egg grab failed — no egg record for " .. player.Name)
		return
	end
	if entry.phase == "carried" then
		Remotes.bannerEvent():FireClient(player, "That egg is already being carried!", 3)
		print("[MeteorEgg] egg grab failed — already carried (" .. player.Name .. ")")
		return
	end
	if entry.phase ~= "ground" and entry.phase ~= "falling" then
		print("[MeteorEgg] egg grab failed — egg is " .. entry.phase .. " (" .. player.Name .. ")")
		return
	end
	if State.eggCarriedByUser[player.UserId] then
		Remotes.bannerEvent():FireClient(player, "You can only carry one meteor egg!", 3)
		print("[MeteorEgg] egg grab failed — " .. player.Name .. " already carries one")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local shell = model.PrimaryPart
	if not root or not shell then
		print("[MeteorEgg] egg grab failed — no root or shell for " .. player.Name)
		return
	end
	-- All checks passed: now mutate.
	entry.phase = "carried"
	entry.carrier = player.UserId
	State.eggCarriedByUser[player.UserId] = model
	if model == legendaryEggModel then
		legendaryEggModel = nil
		clearLegendaryBeam()
	end
	shell.Anchored = false
	local weld = Instance.new("Weld")
	weld.Name = "EggWeld"
	weld.Part0 = root
	weld.Part1 = shell
	weld.C0 = CFrame.new(0, Config.CARRY_Y, Config.CARRY_Z)
	weld.Parent = shell
	-- The prompt goes off once the egg is carried: a live "Grab
	-- Meteor Egg" prompt on a carried egg reads as "E does nothing".
	local prompt = shell:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	BoostService.applyWalkSpeed(player)
	Remotes.bannerEvent():FireClient(player, "🥚 Heavy! Carry it to the incubator on your base — rivals will chase you!", 4)
	local RivalService = require(script.Parent.RivalService)
	RivalService.notifyEggCarrier(player)
	print("[MeteorEgg] " .. player.Name .. " grabbed an egg")
end

-- Drop the egg the player carries (hit, slapped, died, left, or G).
function MeteorEggService.dropEgg(player: Player)
	local carried = State.eggCarriedByUser[player.UserId]
	if not carried then
		return
	end
	local entry = State.eggs[carried]
	State.eggCarriedByUser[player.UserId] = nil
	if entry then
		entry.phase = "ground"
		entry.carrier = nil
	end
	local shell = carried.PrimaryPart
	if shell then
		local weld = shell:FindFirstChild("EggWeld")
		if weld then
			weld:Destroy()
		end
		shell.Anchored = true
		-- The prompt comes back: the dropped egg is grabbable again.
		local prompt = shell:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = true
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local dropAt = if root then root.Position + Vector3.new(0, 0, 3) else Vector3.new(0, 0, 0)
		carried:PivotTo(CFrame.new(dropAt + Vector3.new(0, 2.4, 0)))
	end
	BoostService.applyWalkSpeed(player)
end

-- Place a carried egg on your base's incubator: it hatches after a
-- rarity-scaled wait (see hatchTimeForRarity).
function MeteorEggService.placeEgg(player: Player)
	local carried = State.eggCarriedByUser[player.UserId]
	if not carried then
		Remotes.bannerEvent():FireClient(player, "Carry a meteor egg to the incubator first!", 3)
		return
	end
	local baseId = BaseService.getPlayerBase(player.UserId)
	if not baseId then
		return
	end
	local nestCf = WorldBuilder.incubatorCFrame(baseId)
	if not nestCf then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if (root.Position - nestCf.Position).Magnitude > 16 then
		Remotes.bannerEvent():FireClient(player, "Stand on the incubator to place the egg.", 2)
		return
	end
	-- One egg per incubator: if an egg is already hatching on this
	-- base, the second egg cannot be placed — it would land on the
	-- same spot and the labels would overlap. The player keeps
	-- carrying it and is told the rule plainly: drop it outside the
	-- base (G) or wait for the hatch.
	for _, other in pairs(State.eggs) do
		if other.phase == "incubating" and other.baseId == baseId and other.hatchAt then
			local remaining = math.max(0, math.ceil(other.hatchAt - time()))
			Remotes.bannerEvent():FireClient(player, "Your incubator already has an egg — it hatches in " .. tostring(remaining) .. "s. Drop this one outside your base (G) or wait.", 4)
			print("[MeteorEgg] " .. player.Name .. " tried to place a second egg — incubator busy (" .. tostring(remaining) .. "s left)")
			return
		end
	end
	local entry = State.eggs[carried]
	State.eggCarriedByUser[player.UserId] = nil
	local shell = carried.PrimaryPart
	if shell then
		local weld = shell:FindFirstChild("EggWeld")
		if weld then
			weld:Destroy()
		end
		shell.Anchored = true
		carried:PivotTo(nestCf * CFrame.new(0, 2.4, 0))
	end
	-- The hatch was rolled at SPAWN, so the egg already knows its
	-- rarity — use the stored result. A fresh roll is only the
	-- fallback for an egg placed before this change. The banner and
	-- the egg's label now SHOW the rarity and the wait — the
	-- incubator is where the mystery ends.
	local hatchTime = Config.EGG_HATCH_TIME[1]
	local placedRarity = "Common"
	if entry then
		entry.phase = "incubating"
		entry.carrier = nil
		entry.baseId = baseId
		local def: RotlingCatalog.RotlingDef? = if entry.hatchDef then RotlingCatalog.getDef(entry.hatchDef) else nil
		if not def then
			local freshDef, freshMutation = rollHatchDef()
			def = freshDef
			entry.hatchDef = freshDef.id
			entry.hatchMutation = freshMutation
		end
		placedRarity = (def :: RotlingCatalog.RotlingDef).rarity
		hatchTime = hatchTimeForRarity(placedRarity)
		-- Egg Warmer: -25% hatch time per tier, read live from the
		-- profile, never below 15s.
		local profile = DataService.getProfile(player)
		local eggTier = if profile then profile.eggTier else 0
		hatchTime = math.max(15, math.floor(hatchTime * (1 - Config.EGG_WARMER_REDUCTION * eggTier)))
		entry.hatchAt = time() + hatchTime
		setEggLabel(carried, "🥚 " .. string.upper(placedRarity) .. " EGG — " .. tostring(hatchTime) .. "s")
		-- Reveal: the incubator is where the rarity shows — tint the
		-- label + glow to the rarity colour now that it is placed.
		-- On the ground it was identical gold.
		local rarityColor = RarityConfig.rarityByName(placedRarity).color
		local eggBillboard = shell and shell:FindFirstChild("EggLabel")
		local revealLabel = eggBillboard and eggBillboard:FindFirstChildOfClass("TextLabel")
		if revealLabel then
			revealLabel.TextColor3 = rarityColor
		end
		local glow = shell and shell:FindFirstChildOfClass("PointLight")
		if glow then
			glow.Color = rarityColor
		end
		print("[MeteorEgg] " .. player.Name .. " placed an egg (" .. placedRarity .. ") — hatches in " .. tostring(hatchTime) .. "s")
	end
	BoostService.applyWalkSpeed(player)
	Remotes.bannerEvent():FireClient(player, "🥚 " .. placedRarity .. " egg on the incubator — hatches in " .. tostring(hatchTime) .. "s!", 4)
end

-- The hatch EVENT: the egg does not just vanish and a Brainrot appear
-- on a pad — it cracks open in front of you, the animal pops out,
-- and (if you are standing there with a free slot) it jumps straight
-- into your arms so YOU place it on a pad. Steal-an-Egg feel, original
-- assets only (the egg, the crack parts and the pop are all built
-- here, no decals, no copied art). The sequence runs in its own
-- thread so the hatch loop keeps ticking.
local function crackEgg(model: Model, egg: State.Egg, baseId: number)
	local husk = model.PrimaryPart
	if not husk or not husk:IsA("BasePart") then
		model:Destroy()
		return
	end
	local hatchPos = husk.Position
	setEggLabel(model, "🥚 HATCHING!")
	print("[MeteorEgg] egg on base " .. tostring(baseId) .. " is hatching — cracking open")
	-- 1. The crack: the shell shakes, then a dark crack appears on
	-- it, three times — the shaking reads as the animal inside
	-- fighting its way out.
	local restCf = husk.CFrame
	for _ = 1, 3 do
		for _ = 1, 3 do
			husk.CFrame = restCf * CFrame.Angles(math.rad(math.random(-6, 6)), math.rad(math.random(-6, 6)), 0)
			task.wait(0.12)
		end
		husk.CFrame = restCf
		local crack = Instance.new("Part")
		crack.Name = "Crack"
		crack.Shape = Enum.PartType.Block
		crack.Size = Vector3.new(0.3, 1.4, 0.3)
		crack.Color = Color3.fromRGB(40, 25, 15)
		crack.Material = Enum.Material.SmoothPlastic
		crack.Anchored = true
		crack.CanCollide = false
		local angle = math.rad(math.random(0, 360))
		crack.CFrame = restCf * CFrame.Angles(0, angle, 0) * CFrame.new(0, math.random(-1, 1), 1.6) * CFrame.Angles(math.rad(math.random(-30, 30)), 0, math.rad(math.random(-30, 30)))
		crack.Parent = model
	end
	-- Flash: the shell goes white for a beat, then breaks.
	husk.Color = Color3.fromRGB(255, 255, 255)
	local glow = husk:FindFirstChildOfClass("PointLight")
	if glow then
		glow.Color = Color3.fromRGB(255, 255, 255)
		glow.Brightness = 6
	end
	task.wait(0.3)
	-- 2. The break: the egg is gone, the animal pops out at the
	-- incubator with a smooth eased pop — twelve steps over 0.6s on
	-- an ease-out-back curve: it bursts out, overshoots to ~1.12,
	-- then settles to 1.0, re-seated on the incubator each step so
	-- the bottom never sinks through it. Then the birth wiggle: three
	-- bounces + a full 360° spin over ~1.2s, so the hatch reads as a
	-- living animal stretching, not a statue appearing.
	local def, mutation = rollHatchDef()
	if egg.hatchDef then
		local stored = RotlingCatalog.getDef(egg.hatchDef)
		if stored then
			def = stored
			mutation = egg.hatchMutation
		end
	end
	model:Destroy()
	local hatched = RotlingFactory.build(def.id, mutation, hatchPos, 1)
	if not hatched then
		return
	end
	hatched.Parent = workspace
	local hatchBody = hatched.PrimaryPart
	local function seatHatched()
		if hatchBody then
			hatched:PivotTo(CFrame.new(hatchPos + Vector3.new(0, hatchBody.Size.Y / 2, 0)))
		end
	end
	RotlingFactory.setModelScale(hatched, 0.2)
	seatHatched()
	for step = 1, 12 do
		local progress = step / 12
		-- ease-out-back: bursts past 1.0, then the last steps settle.
		local overshoot = 1.70158
		local overshootPlus = overshoot + 1
		local curve = 1 + overshootPlus * (progress - 1) ^ 3 + overshoot * (progress - 1) ^ 2
		local scale = 0.2 + (1.12 - 0.2) * curve
		if step >= 10 then
			scale = 1.12 - (1.12 - 1.0) * ((step - 9) / 3)
		end
		RotlingFactory.setModelScale(hatched, math.max(0.2, scale))
		seatHatched()
		task.wait(0.05)
	end
	RotlingFactory.setModelScale(hatched, 1)
	seatHatched()
	-- Birth wiggle: three bounces + a full spin.
	if hatchBody then
		local swayBase = hatchBody.CFrame
		for hop = 1, 3 do
			for i = 1, 4 do
				local up = math.sin(i / 4 * math.pi) * 1.2
				local yaw = (hop - 1 + i / 4) / 3 * math.pi * 2
				hatched:PivotTo(swayBase * CFrame.new(0, up, 0) * CFrame.Angles(0, yaw, 0))
				task.wait(0.1)
			end
		end
		hatched:PivotTo(swayBase)
	end
	RotlingFactory.placePop(hatched)
	-- 2b. Hatch SPECTACLE: the waiting player needs a MOMENT, not
	-- just a pop. A beam of light in the hatch's rarity colour shoots
	-- 30 studs up from the incubator and fades over ~3s; confetti
	-- bursts in gold + the rarity colour + white; a bright fanfare
	-- ping fires at the reveal. The beam is a Neon cylinder (its long
	-- axis is X, so it is rotated 90° to stand vertical) — nothing
	-- new to verify, no asset IDs.
	local rarityColor = RarityConfig.rarityByName(def.rarity).color
	local beam = Instance.new("Part")
	beam.Name = "HatchBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(30, 3, 3)
	beam.Color = rarityColor
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.3
	beam.Anchored = true
	beam.CanCollide = false
	beam.CFrame = CFrame.new(hatchPos + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.3)
			if beam.Parent then
				beam.Transparency = 0.3 + i * 0.07
			end
		end
		beam:Destroy()
	end)
	FeedbackService.burst(hatched, rarityColor)
	FeedbackService.burst(hatched, Color3.fromRGB(255, 225, 90))
	FeedbackService.burst(hatched, Color3.fromRGB(255, 255, 255))
	-- The owner is needed here for the fanfare (and again below for
	-- the auto-carry) — looked up once, before the reveal.
	local ownerId = BaseService.getBaseOwner(baseId)
	local owner = if ownerId then Players:GetPlayerByUserId(ownerId) else nil
	if owner then
		FeedbackService.playSound(owner, 1.6, 0.7)
	end
	print("[MeteorEgg] hatch spectacle — " .. def.name .. " (" .. def.rarity .. ") beam + confetti at base " .. tostring(baseId))
	-- 3. The animal comes out: if the owner is standing nearby with
	-- a free slot, it jumps straight into their arms — they place it
	-- on a pad themselves. Otherwise the old fallback: a free pad,
	-- or the crater if the base is full / the owner left. (owner /
	-- ownerId were looked up above, for the fanfare.)
	local carried = false
	if owner then
		local character = owner.Character
		local ownerRoot = character and character:FindFirstChild("HumanoidRootPart")
		if ownerRoot and (ownerRoot.Position - hatchPos).Magnitude <= 20 and #CarryService.getCarried(owner) < CarryService.getCarrySlots(owner) then
			RotlingFactory.setCarriedVisual(hatched, true)
			local body = hatched.PrimaryPart
			if body then
				for _, part in ipairs(hatched:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = false
					end
				end
				local weld = Instance.new("Weld")
				weld.Name = "CarryWeld"
				weld.Part0 = ownerRoot
				weld.Part1 = body
				weld.C0 = CFrame.new(0, Config.CARRY_Y, Config.CARRY_Z)
				weld.Parent = body
				hatched:SetAttribute("State", "carried")
				CarryService.carryRotling(owner, hatched)
				carried = true
				Remotes.bannerEvent():FireClient(owner, "🥚 IT HATCHED! " .. def.name .. " jumped into your arms — place it on a pad!", 5)
				print("[MeteorEgg] " .. def.name .. " hatched into " .. owner.Name .. "'s arms (owner nearby, free slot)")
			end
		end
	end
	if not carried then
		local padIndex = BaseService.freePad(baseId)
		if padIndex and owner then
			local padCf = WorldBuilder.padCFrame(baseId, padIndex)
			if padCf then
				CarryService.placeOnPad(owner, hatched, baseId, padIndex)
				RotlingFactory.placePop(hatched)
			end
		else
			-- Base full (or the owner left): the hatchling wanders into
			-- the crater instead, free to catch.
			local position = Vector3.new((math.random() * 2 - 1) * 15, Config.CRATER_FLOOR_Y, (math.random() * 2 - 1) * 2)
			hatched:PivotTo(CFrame.new(position))
			SpawnService.connectPrompt(hatched)
			SpawnService.registerFree(hatched)
		end
	end
	if owner then
		local profile = DataService.getProfile(owner)
		if profile then
			profile.stardust += Config.EGG_STARDUST
			DataService.saveProfile(owner)
		end
		local mutText = if mutation then " ✦ " .. mutation .. " x" .. tostring(MutationConfig.mutationMult(mutation)) else ""
		Remotes.bannerEvent():FireClient(owner, "✨ HATCHED: " .. def.name .. " (" .. string.upper(def.rarity) .. mutText .. ")! +" .. tostring(Config.EGG_STARDUST) .. " Stardust!", 6)
		FeedbackService.celebrate(owner)
		-- The rarity reveal fires for EVERY hatch, not just the rare
		-- ones — the waiting player deserves the reveal even for a
		-- Common.
		Remotes.rarityPopupEvent():FireClient(owner, def.name, def.rarity, mutation, RotlingCatalog.baseCps(def, mutation))
		print("[MeteorEgg] hatched " .. def.name .. " (" .. def.rarity .. (if mutation then " " .. mutation else "") .. ") on base " .. tostring(baseId))
	end
end

local function hatchEgg(model: Model)
	local egg = State.eggs[model]
	if not egg then
		return
	end
	local baseId = egg.baseId
	State.eggs[model] = nil
	-- The legendary slot frees when the egg hatches, and the beam is
	-- gone (the egg is in the incubator now).
	if model == legendaryEggModel then
		legendaryEggModel = nil
		clearLegendaryBeam()
	end
	if not baseId then
		model:Destroy()
		return
	end
	task.spawn(crackEgg, model, egg, baseId)
end

-- Hatch loop: eggs on incubators pop when their rarity-scaled hatch
-- time is up. The incubating egg's label shows a LIVE countdown,
-- updated every second: "🥚 LEGENDARY EGG — 173s". The player can
-- look at the egg and know both its rarity and how long until it
-- hatches.
function MeteorEggService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for model, entry in pairs(State.eggs) do
				if entry.phase == "incubating" and entry.hatchAt then
					if time() >= entry.hatchAt then
						hatchEgg(model)
					else
						local def = if entry.hatchDef then RotlingCatalog.getDef(entry.hatchDef) else nil
						local rarity = if def then def.rarity else "Common"
						local remaining = math.max(0, math.ceil(entry.hatchAt - time()))
						setEggLabel(model, "🥚 " .. string.upper(rarity) .. " EGG — " .. tostring(remaining) .. "s")
					end
				end
			end
			-- Legendary egg countdown: the ground label shows the
			-- seconds left, so the urgency reads on the egg itself.
			if legendaryEggModel then
				local legendEntry = State.eggs[legendaryEggModel]
				if legendEntry and (legendEntry.phase == "ground" or legendEntry.phase == "falling") then
					local remaining = math.max(0, math.ceil(Config.LEGENDARY_EGG_LIFETIME - (time() - legendEntry.bornAt)))
					setEggLabel(legendaryEggModel, "🌟 LEGENDARY EGG — " .. tostring(remaining) .. "s!")
				end
			end
		end
	end)
	task.spawn(function()
		-- Legendary egg timer: first drop 60s after boot (so the
		-- first playtest sees it), then one every 240s — only if
		-- none is active.
		task.wait(60)
		while true do
			spawnLegendaryEgg()
			task.wait(Config.LEGENDARY_EGG_INTERVAL)
		end
	end)
end

-- Wire the incubator prompts (one per base, built by WorldBuilder).
function MeteorEggService.init()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Parent and descendant.Parent.Name == "Incubator" then
			descendant.Triggered:Connect(function(player: Player)
				MeteorEggService.placeEgg(player)
			end)
		end
	end
	-- Voluntary egg drop: dropEgg used to run only involuntarily
	-- (slapped, hit, died, left) — the player had no way to put a
	-- carried egg down. Now G (or the DROP EGG button) drops it at
	-- the player's feet, anywhere on the map, ground phase, prompt
	-- re-enabled, grabbable again.
	Remotes.dropEggEvent().OnServerEvent:Connect(function(player: Player)
		if State.eggCarriedByUser[player.UserId] then
			MeteorEggService.dropEgg(player)
			Remotes.bannerEvent():FireClient(player, "🥚 Dropped your egg — grab it again any time.", 3)
			print("[MeteorEgg] " .. player.Name .. " dropped their egg (voluntary)")
		end
	end)
end

return MeteorEggService
