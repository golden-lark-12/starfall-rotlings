--!strict
-- Starfall Rotlings: meteor eggs.
-- During each storm, 1-2 glowing meteor eggs crash somewhere on the
-- map. Heavy — walk slower carrying one (BoostService applies the
-- slow); rivals chase you for it (RivalService.notifyEggCarrier). Bring
-- it to the incubator on your base and it hatches into a random Rotling
-- after a rarity-scaled wait (Common 60s, Cosmic 300s — rarer takes
-- longer), with a chance of Epic, Legendary or a mutation
-- (15% Meteor-scorched). Hatch animation + reveal popup, and the hatch
-- pays Stardust. Eggs drop if you are hit, slapped, or die.

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

local function eggPosition(): Vector3
	-- Anywhere on the open field, never on a base or the spawn pad.
	for _ = 1, 10 do
		local angle = math.random() * math.pi * 2
		local radius = math.random(40, 130)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local onBase = false
		for baseId = 1, Config.BASE_COUNT do
			local cf = WorldBuilder.baseCFrame(baseId)
			if cf and (Vector3.new(pos.X - cf.Position.X, 0, pos.Z - cf.Position.Z)).Magnitude < 18 then
				onBase = true
				break
			end
		end
		if not onBase and not (math.abs(pos.X) < 20 and pos.Z > 70) then
			return pos
		end
	end
	return Vector3.new(0, 0, 50)
end

-- Roll the hatch: a random Rotling, with a real chance of Epic or
-- Legendary, and 15% Meteor-scorched. Common/Rare rolls get one bump
-- chance toward Epic/Legendary so an egg never feels wasted.
-- Declared BEFORE buildEgg and spawnEggsForStorm on purpose: the
-- hatch is rolled at SPAWN time (fix round 7, item 6) so the ground
-- egg can show its rarity, and a local declared after its caller is
-- invisible to that caller — the same class of bug as fix round 3's
-- calmDuration-after-getStatus.
local function rollHatchDef(): (RotlingCatalog.RotlingDef, string?)
	local rarityName = RarityConfig.rollRarity()
	if RarityConfig.rarityTier(rarityName) < 3 and math.random() < 0.4 then
		rarityName = if math.random() < 0.6 then "Epic" else "Legendary"
	end
	local defs = RotlingCatalog.defsOfRarity(rarityName)
	local def = defs[math.random(1, #defs)]
	local mutation: string? = nil
	if math.random() < Config.EGG_SCORCHED_CHANCE then
		mutation = "Scorched"
	else
		mutation = MutationConfig.rollMutation()
	end
	return def, mutation
end

-- (fix round 6, item 6) The hatch wait scales with the rarity of
-- what's inside: Common 60s, Rare 90s, Epic 120s, Legendary 180s,
-- Mythic 240s, Cosmic 300s. Rarer eggs take longer, so the wait itself
-- tells the player something special is coming — and gives everyone
-- (bots included) more time to race for the next egg.
local function hatchTimeForRarity(rarity: string): number
	local tier = RarityConfig.rarityTier(rarity)
	return Config.EGG_HATCH_TIME[tier] or Config.EGG_HATCH_TIME[1]
end

-- Set an egg's label text (the EggLabel billboard on its shell).
-- Used for the rarity at spawn and the live countdown while it
-- incubates. (fix round 7, item 6)
local function setEggLabel(model: Model, text: string)
	local shell = model.PrimaryPart
	local billboard = shell and shell:FindFirstChild("EggLabel")
	local label = billboard and billboard:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
	end
end

local function buildEgg(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Meteor Egg"
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(3.4, 4.2, 3.4)
	shell.Color = Color3.fromRGB(255, 140, 50)
	shell.Material = Enum.Material.Neon
	shell.Anchored = true
	shell.CanCollide = false
	shell.CFrame = CFrame.new(position + Vector3.new(0, 100, 0))
	shell.Parent = model
	model.PrimaryPart = shell
	-- (v74, mystery eggs) The ground egg is a MYSTERY: every egg
	-- looks identical — "🥚 METEOR EGG", same gold label, same
	-- orange glow — no rarity name, no rarity-tinted colour. A
	-- ground egg labelled "COMMON EGG" gets ignored; players only
	-- chase the rare ones. The rarity is still rolled at spawn
	-- (see spawnEggsForStorm) and revealed in the incubator
	-- (placeEgg names it + the live countdown) — any egg could be
	-- Legendary, so normal eggs stay worth grabbing.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 50)
	light.Brightness = 3
	light.Range = 20
	light.Parent = shell
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EggLabel"
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 60
	billboard.Parent = shell
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "🥚 METEOR EGG"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 90)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab Meteor Egg"
	prompt.ObjectText = "Heavy! Walk slower"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell
	prompt.Triggered:Connect(function(player: Player)
		MeteorEggService.grabEgg(player, model)
	end)
	model.Parent = workspace
	return model
end

-- Drop one egg per storm at a random spot: it falls from the sky and
-- lands with a thud, then waits to be grabbed (5 minutes).
function MeteorEggService.spawnEggsForStorm()
	for _ = 1, Config.EGGS_PER_STORM do
		local target = eggPosition()
		-- (v74, mystery eggs) Roll the hatch NOW, at spawn — the
		-- ground egg knows its rarity from the moment it lands, but
		-- it does NOT show it: every ground egg is a mystery
		-- ("🥚 METEOR EGG"). The incubator reveals it (placeEgg
		-- names the rarity + the live countdown) — any egg could be
		-- Legendary, so normal eggs stay worth grabbing.
		local hatchDef, hatchMutation = rollHatchDef()
		local model = buildEgg(target)
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
		local shell = model.PrimaryPart
		if shell then
			local tween = TweenService:Create(shell, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(target + Vector3.new(0, 2.2, 0)),
			})
			tween:Play()
			tween.Completed:Connect(function()
				local egg = State.eggs[model]
				if egg and egg.phase == "falling" then
					egg.phase = "ground"
					print("[MeteorEgg] egg landed at (" .. tostring(math.floor(target.X)) .. ", " .. tostring(math.floor(target.Z)) .. ")")
				end
			end)
		end
		task.delay(300, function()
			local egg = State.eggs[model]
			if egg and (egg.phase == "ground" or egg.phase == "falling") then
				State.eggs[model] = nil
				model:Destroy()
			end
		end)
	end
end

function MeteorEggService.grabEgg(player: Player, model: Model)
	local egg = State.eggs[model]
	if not egg or (egg.phase ~= "ground" and egg.phase ~= "falling") then
		-- A press on an egg that is already carried (or incubating)
		-- used to fail silently — the prompt showed, E did nothing.
		-- Say so, so the next playtest can tell a carried egg from a
		-- dead prompt.
		print("[MeteorEgg] " .. player.Name .. " tried to grab an egg in phase " .. tostring(if egg then egg.phase else "none") .. " — ignored")
		if egg and egg.phase == "carried" then
			Remotes.bannerEvent():FireClient(player, "That meteor egg is already being carried!", 2)
		end
		return
	end
	if State.eggCarriedByUser[player.UserId] then
		Remotes.bannerEvent():FireClient(player, "You can only carry one meteor egg!", 3)
		return
	end
	-- Validate the weld BEFORE mutating state: the old order set
	-- phase="carried" and eggCarriedByUser first, then returned
	-- silently when the character or shell was missing — leaving the
	-- egg stuck in "carried" (never re-grabbable) while the player
	-- carried nothing, and blocking every later egg grab.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local shell = model.PrimaryPart
	if not root or not shell then
		print("[MeteorEgg] " .. player.Name .. " egg grab failed — no character root or shell")
		return
	end
	egg.phase = "carried"
	egg.carrier = player.UserId
	State.eggCarriedByUser[player.UserId] = model
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

-- Drop the egg the player carries (hit, slapped, died, left).
function MeteorEggService.dropEgg(player: Player)
	local model = State.eggCarriedByUser[player.UserId]
	if not model then
		return
	end
	local egg = State.eggs[model]
	State.eggCarriedByUser[player.UserId] = nil
	if egg then
		egg.phase = "ground"
		egg.carrier = nil
	end
	local shell = model.PrimaryPart
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
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local pos = if root then root.Position + Vector3.new(0, 0, 3) else Vector3.new(0, 0, 0)
		model:PivotTo(CFrame.new(pos + Vector3.new(0, 2.2, 0)))
	end
	BoostService.applyWalkSpeed(player)
end

-- Place a carried egg on your base's incubator: it hatches after a
-- rarity-scaled wait (see hatchTimeForRarity).
function MeteorEggService.placeEgg(player: Player)
	local model = State.eggCarriedByUser[player.UserId]
	if not model then
		Remotes.bannerEvent():FireClient(player, "Carry a meteor egg to the incubator first!", 3)
		return
	end
	local baseId = BaseService.getPlayerBase(player.UserId)
	if not baseId then
		return
	end
	local incubatorCf = WorldBuilder.incubatorCFrame(baseId)
	if not incubatorCf then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if (root.Position - incubatorCf.Position).Magnitude > 16 then
		Remotes.bannerEvent():FireClient(player, "Stand on the incubator to place the egg.", 2)
		return
	end
	-- One egg per incubator (fix round 7, item 8): if an egg is
	-- already hatching on this base, the second egg cannot be placed
	-- — it would land on the same spot and the labels would overlap.
	-- The player keeps carrying it and is told the rule plainly:
	-- drop it outside the base (G) or wait for the hatch.
	for _, other in pairs(State.eggs) do
		if other.phase == "incubating" and other.baseId == baseId and other.hatchAt then
			local remaining = math.max(0, math.ceil(other.hatchAt - time()))
			Remotes.bannerEvent():FireClient(player, "Your incubator already has an egg — it hatches in " .. tostring(remaining) .. "s. Drop this one outside your base (G) or wait.", 4)
			print("[MeteorEgg] " .. player.Name .. " tried to place a second egg — incubator busy (" .. tostring(remaining) .. "s left)")
			return
		end
	end
	local egg = State.eggs[model]
	State.eggCarriedByUser[player.UserId] = nil
	local shell = model.PrimaryPart
	if shell then
		local weld = shell:FindFirstChild("EggWeld")
		if weld then
			weld:Destroy()
		end
		shell.Anchored = true
		model:PivotTo(incubatorCf * CFrame.new(0, 2.2, 0))
	end
	-- (fix round 7, item 6) The hatch was rolled at SPAWN, so the
	-- egg already knows its rarity — use the stored result. A fresh
	-- roll is only the fallback for an egg placed before this change.
	-- The banner and the egg's label now SHOW the rarity and the
	-- wait (Malek: "whhere do i see its rarity?") — the round-6
	-- hiding is overridden.
	local hatchTime = Config.EGG_HATCH_TIME[1]
	local placedRarity = "Common"
	if egg then
		egg.phase = "incubating"
		egg.carrier = nil
		egg.baseId = baseId
		local def: RotlingCatalog.RotlingDef? = if egg.hatchDef then RotlingCatalog.getDef(egg.hatchDef) else nil
		if not def then
			local freshDef, freshMutation = rollHatchDef()
			def = freshDef
			egg.hatchDef = freshDef.id
			egg.hatchMutation = freshMutation
		end
		placedRarity = (def :: RotlingCatalog.RotlingDef).rarity
		hatchTime = hatchTimeForRarity(placedRarity)
		-- Egg Warmer (fix round 8, item 6): -25% hatch time per tier,
		-- read live from the profile, never below 15s.
		local profile = DataService.getProfile(player)
		local eggTier = if profile then profile.eggTier else 0
		hatchTime = math.max(15, math.floor(hatchTime * (1 - Config.EGG_WARMER_REDUCTION * eggTier)))
		egg.hatchAt = time() + hatchTime
		setEggLabel(model, "🥚 " .. string.upper(placedRarity) .. " EGG — " .. tostring(hatchTime) .. "s")
		-- Reveal (v74, mystery eggs): the incubator is where the
		-- rarity shows — tint the label + glow to the rarity colour
		-- now that it is placed. On the ground it was identical gold.
		local rarityColor = RarityConfig.rarityByName(placedRarity).color
		local eggBillboard = shell:FindFirstChild("EggLabel")
		local revealLabel = eggBillboard and eggBillboard:FindFirstChildOfClass("TextLabel")
		if revealLabel then
			revealLabel.TextColor3 = rarityColor
		end
		local glow = shell:FindFirstChildOfClass("PointLight")
		if glow then
			glow.Color = rarityColor
		end
		print("[MeteorEgg] " .. player.Name .. " placed an egg (" .. placedRarity .. ") — hatches in " .. tostring(hatchTime) .. "s")
	end
	BoostService.applyWalkSpeed(player)
	Remotes.bannerEvent():FireClient(player, "🥚 " .. placedRarity .. " egg on the incubator — hatches in " .. tostring(hatchTime) .. "s!", 4)
end

-- The hatch EVENT (fix round 8, item 9): the egg does not just vanish
-- and a Brainrot appear on a pad — it cracks open in front of you,
-- the animal pops out, and (if you are standing there with a free
-- slot) it jumps straight into your arms so YOU place it on a pad.
-- Steal-an-Egg feel, original assets only (the egg, the crack parts
-- and the pop are all built here, no decals, no copied art). The
-- sequence runs in its own thread so the hatch loop keeps ticking.
local function crackEgg(model: Model, egg: State.Egg, baseId: number)
	local shell = model.PrimaryPart
	if not shell or not shell:IsA("BasePart") then
		model:Destroy()
		return
	end
	local hatchPos = shell.Position
	setEggLabel(model, "🥚 HATCHING!")
	print("[MeteorEgg] egg on base " .. tostring(baseId) .. " is hatching — cracking open")
	-- 1. The crack: the shell shakes, then a dark crack appears on
	-- it, three times — the shaking reads as the animal inside
	-- fighting its way out.
	local baseCf = shell.CFrame
	for _ = 1, 3 do
		for _ = 1, 3 do
			shell.CFrame = baseCf * CFrame.Angles(math.rad(math.random(-6, 6)), math.rad(math.random(-6, 6)), 0)
			task.wait(0.12)
		end
		shell.CFrame = baseCf
		local crack = Instance.new("Part")
		crack.Name = "Crack"
		crack.Shape = Enum.PartType.Block
		crack.Size = Vector3.new(0.3, 1.4, 0.3)
		crack.Color = Color3.fromRGB(40, 25, 15)
		crack.Material = Enum.Material.SmoothPlastic
		crack.Anchored = true
		crack.CanCollide = false
		local angle = math.rad(math.random(0, 360))
		crack.CFrame = baseCf * CFrame.Angles(0, angle, 0) * CFrame.new(0, math.random(-1, 1), 1.6) * CFrame.Angles(math.rad(math.random(-30, 30)), 0, math.rad(math.random(-30, 30)))
		crack.Parent = model
	end
	-- Flash: the shell goes white for a beat, then breaks.
	shell.Color = Color3.fromRGB(255, 255, 255)
	local light = shell:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = Color3.fromRGB(255, 255, 255)
		light.Brightness = 6
	end
	task.wait(0.3)
	-- 2. The break: the egg is gone, the animal pops out at the
	-- incubator with a scale-in bounce + gold burst.
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
	-- 2. The break: the egg is gone, the animal pops out at the
	-- incubator with a SMOOTH eased pop (fix round 9, item 6) — the
	-- old stepped scale-in (0.2 → 0.5 → 0.8 → 1, three hard jumps)
	-- read as a robot inflating in stages. Twelve steps over 0.6s on
	-- an ease-out-back curve: it bursts out, overshoots to ~1.12,
	-- then settles to 1.0, re-seated on the incubator each step so
	-- the bottom never sinks through it. Then the birth wiggle: three
	-- bounces + a full 360° spin over ~1.2s, so the hatch reads as a
	-- living animal stretching, not a statue appearing.
	local hatchBody = hatched.PrimaryPart
	local function seatHatched()
		if hatchBody then
			hatched:PivotTo(CFrame.new(hatchPos + Vector3.new(0, hatchBody.Size.Y / 2, 0)))
		end
	end
	RotlingFactory.setModelScale(hatched, 0.2)
	seatHatched()
	for step = 1, 12 do
		local t = step / 12
		-- ease-out-back: bursts past 1.0, then the last steps settle.
		local c1 = 1.70158
		local c3 = c1 + 1
		local eased = 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
		local target = 0.2 + (1.12 - 0.2) * eased
		if step >= 10 then
			target = 1.12 - (1.12 - 1.0) * ((step - 9) / 3)
		end
		RotlingFactory.setModelScale(hatched, math.max(0.2, target))
		seatHatched()
		task.wait(0.05)
	end
	RotlingFactory.setModelScale(hatched, 1)
	seatHatched()
	-- Birth wiggle: three bounces + a full spin.
	if hatchBody then
		local wiggleBase = hatchBody.CFrame
		for bounce = 1, 3 do
			for i = 1, 4 do
				local up = math.sin(i / 4 * math.pi) * 1.2
				local yaw = (bounce - 1 + i / 4) / 3 * math.pi * 2
				hatched:PivotTo(wiggleBase * CFrame.new(0, up, 0) * CFrame.Angles(0, yaw, 0))
				task.wait(0.1)
			end
		end
		hatched:PivotTo(wiggleBase)
	end
	RotlingFactory.placePop(hatched)
	-- 2b. Hatch SPECTACLE (fix round 9, item 7): the waiting player
	-- needs a MOMENT, not just a pop. A beam of light in the hatch's
	-- rarity colour shoots 30 studs up from the incubator and fades
	-- over ~3s; confetti bursts in gold + the rarity colour + white;
	-- a bright fanfare ping fires at the reveal. The beam is a Neon
	-- cylinder (its long axis is X, so it is rotated 90° to stand
	-- vertical) — nothing new to verify, no asset IDs.
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
		-- (fix round 9, item 7) the rarity reveal fires for EVERY
		-- hatch, not just tier 4+ — the waiting player deserves the
		-- reveal even for a Common.
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
	if not baseId then
		model:Destroy()
		return
	end
	task.spawn(crackEgg, model, egg, baseId)
end

-- Hatch loop: eggs on incubators pop when their rarity-scaled hatch time is up.
-- (fix round 7, item 6) The incubating egg's label shows a LIVE
-- countdown, updated every second: "🥚 LEGENDARY EGG — 173s". The
-- player can look at the egg and know both its rarity and how long
-- until it hatches.
function MeteorEggService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for model, egg in pairs(State.eggs) do
				if egg.phase == "incubating" and egg.hatchAt then
					if time() >= egg.hatchAt then
						hatchEgg(model)
					else
						local def = if egg.hatchDef then RotlingCatalog.getDef(egg.hatchDef) else nil
						local rarity = if def then def.rarity else "Common"
						local remaining = math.max(0, math.ceil(egg.hatchAt - time()))
						setEggLabel(model, "🥚 " .. string.upper(rarity) .. " EGG — " .. tostring(remaining) .. "s")
					end
				end
			end
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
	-- Voluntary egg drop (fix round 7, item 8): dropEgg used to run
	-- only involuntarily (slapped, hit, died, left) — the player had
	-- no way to put a carried egg down. Now G (or the DROP EGG
	-- button) drops it at the player's feet, anywhere on the map,
	-- ground phase, prompt re-enabled, grabbable again.
	Remotes.dropEggEvent().OnServerEvent:Connect(function(player: Player)
		if State.eggCarriedByUser[player.UserId] then
			MeteorEggService.dropEgg(player)
			Remotes.bannerEvent():FireClient(player, "🥚 Dropped your egg — grab it again any time.", 3)
			print("[MeteorEgg] " .. player.Name .. " dropped their egg (voluntary)")
		end
	end)
end

return MeteorEggService
