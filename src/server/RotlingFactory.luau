--!strict
-- Starfall Rotlings: builds a Rotling Model from a RotlingCatalog definition.
-- Every creature is Parts only: a body, a belly, big eyes, feet, one
-- accessory, a rarity glow light, a mutation sparkle and a name/rarity/
-- coins-per-second label. No meshes, decals or uploaded assets are used
-- anywhere. The body starts Anchored so a free Rotling rests on the
-- crater floor instead of falling through the world; carrying un-anchors
-- it and welds it to the player, placing re-anchors it.
-- SOLID, not ghost: every part is built with Transparency 0, so the
-- Rotlings read as solid characters with clear faces and colours per
-- rarity — never flat semi-transparent boxes.
--
-- ITEM 1 (models): each of the 12 Rotlings has its own silhouette
-- (bodyForSilhouette, one unique key per Rotling from the catalog),
-- 2-3 signature built-from-parts features (addNameProp), and a body
-- painted in its rarity tier colour (rarity.color, verbatim). Faces
-- are placed from the BODY's own size, not the nominal size, so a flat
-- puddle and a tall noodle both get eyes and a mouth that sit on the
-- face instead of floating or sinking; the mouth sits proud of the
-- belly patch (the old mouth was buried inside the belly). The name
-- tag is offset from the model's bounding-box top, so it always floats
-- above the tallest hat or crown and never covers the face, at any
-- scale (refreshLabelOffset after every scale change).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)

local RotlingFactory = {}

-- Idle motion: one shared loop bobs and sways every free/placed Rotling
-- around a stored rest pose. Carried Rotlings are skipped (they ride the
-- player's weld). The pop tween marks a model so the loop never fights it.
local restPose: { [Model]: CFrame } = {}
local bobSeed: { [Model]: number } = {}
local popping: { [Model]: number } = {}
local idleStarted = false

-- Remember where a Rotling rests, so the idle loop can bob around it.
-- Called when a Rotling is built, placed or scattered back to the crater.
function RotlingFactory.setRestPose(model: Model)
	local body = model.PrimaryPart
	if body then
		restPose[model] = body.CFrame
		if not bobSeed[model] then
			bobSeed[model] = math.random() * 10
		end
	end
end

-- Deepen a colour (push each channel away from the mean) so a Rotling
-- reads vivid from across the crater instead of washed-out pale.
local function saturate(color: Color3, amount: number): Color3
	local mean = (color.R + color.G + color.B) / 3
	local function adj(c: number): number
		return math.clamp(mean + (c - mean) * amount, 0, 1)
	end
	return Color3.new(adj(color.R), adj(color.G), adj(color.B))
end

-- One unique silhouette per Rotling: the body size and shape come from
-- the catalog's silhouette key, never from the shared 4-way body type,
-- so no two Rotlings share an outline. Wide/flat, tall/thin, round,
-- long and couch-shaped bodies all read differently at thumbnail size.
-- Falls back to the legacy body type if a def ever lacks a silhouette.
local function bodyForSilhouette(def: RotlingCatalog.RotlingDef): (Vector3, Enum.PartType)
	local s = def.size
	if def.silhouette == "chunky-round" then
		return Vector3.new(s * 1.05, s * 0.95, s), Enum.PartType.Ball
	elseif def.silhouette == "flat-puddle" then
		return Vector3.new(s * 1.9, s * 0.45, s * 1.5), Enum.PartType.Block
	elseif def.silhouette == "long-wavy" then
		return Vector3.new(s * 0.62, s, s * 0.62), Enum.PartType.Block
	elseif def.silhouette == "chunky-cube" then
		return Vector3.new(s * 0.9, s * 0.95, s * 0.9), Enum.PartType.Block
	elseif def.silhouette == "tall-capsule" then
		return Vector3.new(s * 0.62, s, s * 0.62), Enum.PartType.Block
	elseif def.silhouette == "boxy-ghost" then
		return Vector3.new(s * 0.9, s * 0.95, s * 0.8), Enum.PartType.Block
	elseif def.silhouette == "tall-sock" then
		return Vector3.new(s * 0.5, s, s * 0.5), Enum.PartType.Block
	elseif def.silhouette == "round-bounce" then
		return Vector3.new(s, s * 0.9, s), Enum.PartType.Ball
	elseif def.silhouette == "root-round" then
		return Vector3.new(s, s, s), Enum.PartType.Ball
	elseif def.silhouette == "blob-dome" then
		return Vector3.new(s * 1.1, s * 0.9, s * 1.1), Enum.PartType.Ball
	elseif def.silhouette == "wide-couch" then
		return Vector3.new(s * 1.25, s * 0.55, s * 0.9), Enum.PartType.Block
	elseif def.silhouette == "bear" then
		return Vector3.new(s, s, s), Enum.PartType.Ball
	elseif def.silhouette == "mole-dig" then
		return Vector3.new(s * 1.3, s * 0.6, s * 1.1), Enum.PartType.Block
	elseif def.silhouette == "tortoise-shell" then
		return Vector3.new(s * 1.2, s * 0.7, s * 1.2), Enum.PartType.Ball
	elseif def.silhouette == "boba-round" then
		return Vector3.new(s * 0.9, s, s * 0.9), Enum.PartType.Ball
	elseif def.silhouette == "penguin-waddle" then
		return Vector3.new(s * 0.7, s, s * 0.7), Enum.PartType.Block
	elseif def.silhouette == "avocado-oval" then
		return Vector3.new(s * 0.9, s * 1.1, s * 0.9), Enum.PartType.Ball
	elseif def.silhouette == "llama-tall" then
		return Vector3.new(s * 0.5, s * 1.2, s * 0.5), Enum.PartType.Block
	elseif def.silhouette == "narwhal-horn" then
		return Vector3.new(s, s * 0.95, s), Enum.PartType.Ball
	elseif def.silhouette == "cat-sit" then
		return Vector3.new(s * 0.9, s * 0.9, s * 0.9), Enum.PartType.Block
	elseif def.body == "ball" then
		return Vector3.new(s, s, s), Enum.PartType.Ball
	elseif def.body == "tall" then
		return Vector3.new(s * 0.62, s, s * 0.62), Enum.PartType.Block
	elseif def.body == "wide" then
		return Vector3.new(s * 1.25, s * 0.7, s * 0.9), Enum.PartType.Block
	else
		return Vector3.new(s * 0.9, s * 0.85, s * 0.9), Enum.PartType.Block
	end
end

-- Re-seat the name tag after a scale change (crater 1.5x, pad 1x,
-- carry): the stored 1x offset times the live model scale, so the tag
-- always floats above the tallest part instead of sinking into a hat
-- when a Rotling grows or shrinking onto the face when it shrinks.
-- Called from build() after scaling and from CarryService after every
-- setModelScale; the label hides while carried, so no refresh is
-- needed on the carry path itself.
function RotlingFactory.refreshLabelOffset(model: Model)
	local body = model.PrimaryPart
	local base = model:GetAttribute("LabelBaseOffset")
	if not body or typeof(base) ~= "number" then
		return
	end
	local label = body:FindFirstChild("RotlingLabel")
	if label and label:IsA("BillboardGui") then
		label.StudsOffsetWorldSpace = Vector3.new(0, (base :: number) * model:GetScale(), 0)
	end
end

-- Set a Rotling's size as an ABSOLUTE scale relative to its build size
-- (1 = as built). Uses GetScale so every transition (crater 1.5x,
-- carried ~0.5x, placed 1x) lands exactly, however it got there.
function RotlingFactory.setModelScale(model: Model, target: number)
	local current = model:GetScale()
	if current <= 0 then
		current = 1
	end
	if math.abs(target - current) < 0.001 then
		return
	end
	model:ScaleTo(target / current)
end

-- Carried look: the REAL model at a readable size, riding in front of
-- the chest — no bubble, no shrink-to-a-box. The glow shell is hidden
-- while carried so the Rotling keeps its real colours and face instead
-- of reading as a big pale block over the player's view, but the rarity
-- outline stays on so the carried Rotling pops against any background.
-- The name tag hides while carried too (it overlaps the top HUD).
-- Call with false on place/scatter to restore everything; the caller
-- re-sets the size (1 on a pad, 1.5x back in the crater).
function RotlingFactory.setCarriedVisual(model: Model, carried: boolean)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	if carried then
		-- Readable, not tiny: at most CARRY_MAX_HEIGHT studs tall, so
		-- the face and colours read from the front instead of the
		-- model collapsing into a brown box.
		local size = if def then def.size else 4
		local factor = math.clamp(Config.CARRY_MAX_HEIGHT / size, 0.5, 1.0)
		RotlingFactory.setModelScale(model, factor)
	end
	local shell = model:FindFirstChild("GlowShell")
	if shell and shell:IsA("BasePart") then
		shell.Transparency = if carried then 1 else 0.88
	end
	-- The rarity outline stays ON while carried: the carried Rotling
	-- must pop in front of the chest (Malek's item 5), and the outline
	-- is the cheapest way to keep it readable against any background.
	local hl = model:FindFirstChildOfClass("Highlight")
	if hl then
		hl.Enabled = true
	end
	local label = body:FindFirstChild("RotlingLabel")
	if label and label:IsA("BillboardGui") then
		label.Enabled = not carried
	end
end

local function startIdleMotion()
	if idleStarted then
		return
	end
	idleStarted = true
	task.spawn(function()
		while true do
			task.wait(0.12)
			local now = time()
			for model, base in pairs(restPose) do
				if model.Parent == nil then
					restPose[model] = nil
					bobSeed[model] = nil
					popping[model] = nil
				elseif popping[model] and now < (popping[model] :: number) then
					-- A place pop is tweening this one; leave it alone.
					continue
				else
					local body = model.PrimaryPart
					-- PLACED Rotlings only. Free Rotlings are owned by
					-- SpawnService.animateFree, which moves them along
					-- the belt with model:PivotTo. This loop used to
					-- set body.CFrame for free Rotlings too, every
					-- 0.12s, pinning them back to their spawn pose
					-- while animateFree pushed them elsewhere every
					-- 0.1s — two loops fighting over the same model at
					-- different rates, with the body Anchored and the
					-- other parts unanchored on WeldConstraints, so
					-- the parts lagged and the model tipped over (and
					-- neither loop ever translated it, so it bobbed
					-- and swayed in place forever). One loop per
					-- state, no fight.
					local state = model:GetAttribute("State")
					if body and state == "placed" then
						local seed = bobSeed[model] or 0
						local bob = math.sin(now * 1.6 + seed) * 0.22
						-- Placed Rotlings slowly spin on display.
						local angle = (now * 0.5 + seed) % (math.pi * 2)
						body.CFrame = base * CFrame.new(0, bob, 0) * CFrame.Angles(0, angle, 0)
					end
				end
			end
		end
	end)
end

-- A pop + coin burst when a Rotling lands on a pad: a little hop, a
-- spray of gold particles and a coin ding. The idle loop is paused for
-- this model while the hop tween runs.
function RotlingFactory.placePop(model: Model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local burst = body:FindFirstChild("CoinBurst")
	if burst and burst:IsA("ParticleEmitter") then
		burst:Emit(18)
	end
	-- Coin ding: the built-in ping, pitched up bright.
	local ding = Instance.new("Sound")
	ding.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	-- (fix round 7, item 4) 0.6 was a short quiet blip — the place
	-- ding was easy to miss. 0.8 so the place is heard.
	ding.Volume = 0.8
	ding.PlaybackSpeed = 1.8
	ding.Parent = body
	ding:Play()
	task.delay(1, function()
		ding:Destroy()
	end)
	local base = restPose[model] or body.CFrame
	popping[model] = time() + 0.45
	local up = TweenService:Create(body, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = base * CFrame.new(0, 1.2, 0),
	})
	up:Play()
	up.Completed:Connect(function()
		local down = TweenService:Create(body, TweenInfo.new(0.22, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			CFrame = base,
		})
		down:Play()
	end)
end

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
	-- to read from across the crater. Sized from the BODY's own size, so
	-- a flat puddle gets eyes that fit its low face and a tall noodle
	-- gets eyes that fit its narrow one: at least ~0.5 studs across on
	-- the smallest Rotling (puddles, 2.2 studs: 0.54).
	local bodySize = body.Size
	local eyeSize = math.min(size * 0.28, bodySize.Y * 0.55, bodySize.X * 0.32)
	local eyeY = bodySize.Y * 0.16
	local eyeZ = bodySize.Z / 2 + eyeSize * 0.35
	for _, side in ipairs({ -1, 1 }) do
		local white = makePart("Eye", Enum.PartType.Ball, Vector3.new(eyeSize, eyeSize, eyeSize), Color3.fromRGB(255, 255, 255))
		white.CFrame = body.CFrame * CFrame.new(side * bodySize.X * 0.24, eyeY, eyeZ)
		white.Parent = model
		local pupil = makePart("Pupil", Enum.PartType.Ball, Vector3.new(eyeSize * 0.5, eyeSize * 0.5, eyeSize * 0.5), Color3.fromRGB(20, 20, 30))
		pupil.CFrame = body.CFrame * CFrame.new(side * bodySize.X * 0.24, eyeY, eyeZ + eyeSize * 0.35)
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
	-- It sits PROUD of the belly patch (z past the belly's front
	-- surface): the old mouth sat at the body face and was buried
	-- inside the belly ball, invisible.
	local bodySize = body.Size
	local mouthWidth = math.min(size * 0.34, bodySize.X * 0.5)
	local mouth = makePart("Mouth", Enum.PartType.Block, Vector3.new(mouthWidth, size * 0.08, size * 0.06), Color3.fromRGB(30, 20, 30))
	mouth.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.2, bodySize.Z / 2 + size * 0.12)
	mouth.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = mouth
	weld.Parent = mouth
end

local function addFeet(model: Model, body: Part, size: number)
	-- Feet hang from the body's own bottom, half-sunk into it, so a
	-- flat puddle and a tall noodle both stand on their feet instead of
	-- the feet floating below (old code hung them at -size*0.5, which
	-- floated under every non-ball body) or sinking through the floor.
	local bodySize = body.Size
	for _, side in ipairs({ -1, 1 }) do
		local foot = makePart("Foot", Enum.PartType.Block, Vector3.new(size * 0.28, size * 0.14, size * 0.4), Color3.fromRGB(40, 40, 50))
		foot.CFrame = body.CFrame * CFrame.new(side * size * 0.24, -bodySize.Y / 2 + size * 0.02, size * 0.08)
		foot.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = foot
		weld.Parent = foot
	end
end

local function addArms(model: Model, body: Part, def: RotlingCatalog.RotlingDef)
	-- A puddle has no arms; a couch has armrests instead. Everyone else
	-- gets little limbs, angled out, in a darker shade of the body colour.
	if def.id == "puddles" or def.id == "couch" then
		return
	end
	local size = def.size
	-- Little limbs, angled out, in a darker shade of the body colour.
	local armColor = Color3.new(body.Color.R * 0.7, body.Color.G * 0.7, body.Color.B * 0.7)
	for _, side in ipairs({ -1, 1 }) do
		local arm = makePart("Arm", Enum.PartType.Block, Vector3.new(size * 0.14, size * 0.36, size * 0.14), armColor)
		arm.CFrame = body.CFrame * CFrame.new(side * (body.Size.X / 2 + size * 0.08), -size * 0.05, 0) * CFrame.Angles(0, 0, side * -0.35)
		arm.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = arm
		weld.Parent = arm
	end
end

-- A small prop that fits the Rotling's NAME, 2-3 parts each. This runs
-- after the generic accessory; for noodle, crumb, toaster and couch it
-- IS the accessory (addAccessory skips the generic one for those four).
-- `top` is the body's own top edge (body.Size.Y / 2), not size*0.55:
-- the old top floated a helmet half a stud above a flat puddle and
-- buried a crown inside a tall sock. Every feature here is solid
-- Parts (Transparency 0): the old translucent monocle lens and orbit
-- disc are gone, replaced by a ring of solid gold balls and a ring of
-- solid neon orbit balls, so the eyes and body always show through.
local function addNameProp(model: Model, body: Part, def: RotlingCatalog.RotlingDef)
	local size = def.size
	local bodySize = body.Size
	local top = body.CFrame * CFrame.new(0, bodySize.Y / 2, 0)
	local function weldIt(p: Part)
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
	end
	if def.id == "wombat" then
		-- Wombat ears: two small rounded ears on top.
		for _, side in ipairs({ -1, 1 }) do
			local ear = makePart("Ear", Enum.PartType.Ball, Vector3.new(size * 0.2, size * 0.2, size * 0.2), Color3.fromRGB(110, 80, 50))
			ear.CFrame = top * CFrame.new(side * size * 0.22, size * 0.04, 0)
			weldIt(ear)
		end
		-- Snout with a dark nose, above the mouth.
		local snout = makePart("Snout", Enum.PartType.Block, Vector3.new(size * 0.3, size * 0.2, size * 0.18), Color3.fromRGB(190, 150, 110))
		snout.CFrame = body.CFrame * CFrame.new(0, -size * 0.02, bodySize.Z / 2 + size * 0.05)
		weldIt(snout)
		local nose = makePart("Nose", Enum.PartType.Ball, Vector3.new(size * 0.12, size * 0.1, size * 0.08), Color3.fromRGB(40, 25, 20))
		nose.CFrame = body.CFrame * CFrame.new(0, size * 0.02, bodySize.Z / 2 + size * 0.15)
		weldIt(nose)
		-- Stubby tail at the back.
		local tail = makePart("Tail", Enum.PartType.Ball, Vector3.new(size * 0.18, size * 0.18, size * 0.18), Color3.fromRGB(110, 80, 50))
		tail.CFrame = body.CFrame * CFrame.new(0, -size * 0.1, -bodySize.Z / 2 - size * 0.05)
		weldIt(tail)
	elseif def.id == "puddles" then
		-- A tiny knight's helmet with a blue plume.
		local helmet = makePart("Helmet", Enum.PartType.Ball, Vector3.new(size * 0.5, size * 0.26, size * 0.5), Color3.fromRGB(180, 185, 200))
		helmet.Material = Enum.Material.Metal
		helmet.CFrame = top * CFrame.new(0, size * 0.02, 0)
		weldIt(helmet)
		local plume = makePart("Plume", Enum.PartType.Ball, Vector3.new(size * 0.12, size * 0.12, size * 0.12), Color3.fromRGB(80, 140, 255))
		plume.Material = Enum.Material.Neon
		plume.CFrame = top * CFrame.new(0, size * 0.2, 0)
		weldIt(plume)
		-- Rim droplets: the puddle's edge beads up.
		for _, spot in ipairs({ { -0.45, 0.3 }, { 0.45, 0.3 }, { 0, -0.42 } }) do
			local drop = makePart("Droplet", Enum.PartType.Ball, Vector3.new(size * 0.16, size * 0.16, size * 0.16), Color3.fromRGB(150, 210, 255))
			drop.CFrame = body.CFrame * CFrame.new(spot[1] * bodySize.X, size * 0.02, spot[2] * bodySize.Z)
			weldIt(drop)
		end
		-- Splash spikes where the puddle jumps.
		for _, side in ipairs({ -1, 1 }) do
			local spike = makePart("Splash", Enum.PartType.Wedge, Vector3.new(size * 0.12, size * 0.3, size * 0.12), Color3.fromRGB(150, 210, 255))
			spike.CFrame = top * CFrame.new(side * bodySize.X * 0.3, size * 0.1, 0) * CFrame.Angles(0, 0, side * -0.35)
			weldIt(spike)
		end
	elseif def.id == "noodle" then
		-- A chef's hat: white brim and puffy crown.
		local brim = makePart("ChefBrim", Enum.PartType.Cylinder, Vector3.new(size * 0.12, size * 0.55, size * 0.55), Color3.fromRGB(245, 245, 245))
		brim.CFrame = top * CFrame.Angles(0, 0, math.rad(90))
		weldIt(brim)
		local crown = makePart("ChefTop", Enum.PartType.Ball, Vector3.new(size * 0.42, size * 0.36, size * 0.42), Color3.fromRGB(250, 250, 250))
		crown.CFrame = top * CFrame.new(0, size * 0.2, 0)
		weldIt(crown)
		-- Wavy side segments: balls bulging alternately left and right,
		-- so the long thin body reads as a wavy noodle, not a plank.
		for i, yFrac in ipairs({ -0.28, 0, 0.28 }) do
			local side = if i % 2 == 1 then -1 else 1
			local seg = makePart("NoodleWave", Enum.PartType.Ball, Vector3.new(size * 0.3, size * 0.3, size * 0.3), body.Color)
			seg.CFrame = body.CFrame * CFrame.new(side * (bodySize.X / 2 - size * 0.02), yFrac * bodySize.Y, 0)
			weldIt(seg)
		end
		-- A noodle curl spiralling off the top.
		for i = 1, 3 do
			local curl = makePart("NoodleCurl", Enum.PartType.Ball, Vector3.new(size * 0.1, size * 0.1, size * 0.1), body.Color)
			curl.CFrame = top * CFrame.new(bodySize.X / 2 + i * size * 0.08, i * size * 0.1, 0)
			weldIt(curl)
		end
	elseif def.id == "crumb" then
		-- A captain's hat: dark blue cap with a white front band.
		local cap = makePart("CaptainHat", Enum.PartType.Cylinder, Vector3.new(size * 0.14, size * 0.55, size * 0.55), Color3.fromRGB(30, 60, 130))
		cap.CFrame = top * CFrame.Angles(0, 0, math.rad(90))
		weldIt(cap)
		local band = makePart("CaptainBand", Enum.PartType.Block, Vector3.new(size * 0.5, size * 0.08, size * 0.06), Color3.fromRGB(250, 250, 250))
		band.CFrame = top * CFrame.new(0, size * 0.02, size * 0.26)
		weldIt(band)
		-- Crumb dots stuck on the body, clear of the face.
		local crumbColor = Color3.fromRGB(120, 80, 40)
		local crumb1 = makePart("CrumbDot", Enum.PartType.Ball, Vector3.new(size * 0.12, size * 0.12, size * 0.12), crumbColor)
		crumb1.CFrame = body.CFrame * CFrame.new(-size * 0.35, -bodySize.Y * 0.35, bodySize.Z / 2 + size * 0.04)
		weldIt(crumb1)
		local crumb2 = makePart("CrumbDot", Enum.PartType.Ball, Vector3.new(size * 0.12, size * 0.12, size * 0.12), crumbColor)
		crumb2.CFrame = body.CFrame * CFrame.new(size * 0.35, -bodySize.Y * 0.3, bodySize.Z / 2 + size * 0.04)
		weldIt(crumb2)
		local crumb3 = makePart("CrumbDot", Enum.PartType.Ball, Vector3.new(size * 0.12, size * 0.12, size * 0.12), crumbColor)
		crumb3.CFrame = body.CFrame * CFrame.new(-bodySize.X / 2 - size * 0.02, 0, 0)
		weldIt(crumb3)
		-- A white sailor collar under the belly.
		local collar = makePart("Collar", Enum.PartType.Block, Vector3.new(bodySize.X * 0.7, size * 0.1, size * 0.08), Color3.fromRGB(250, 250, 250))
		collar.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.42, bodySize.Z / 2 + size * 0.03)
		weldIt(collar)
	elseif def.id == "pickle" then
		-- Rounded capsule cap on top of the tall body.
		local cap = makePart("PickleCap", Enum.PartType.Ball, Vector3.new(bodySize.X * 1.08, size * 0.3, bodySize.Z * 1.08), Color3.fromRGB(70, 180, 60))
		cap.CFrame = top * CFrame.new(0, size * 0.05, 0)
		weldIt(cap)
		-- A tiny disco ball on a stem, rising from the cap.
		local stem = makePart("DiscoStem", Enum.PartType.Cylinder, Vector3.new(size * 0.3, size * 0.06, size * 0.06), Color3.fromRGB(90, 90, 100))
		stem.CFrame = top * CFrame.new(0, size * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
		weldIt(stem)
		local ball = makePart("DiscoBall", Enum.PartType.Ball, Vector3.new(size * 0.28, size * 0.28, size * 0.28), Color3.fromRGB(210, 210, 220))
		ball.Material = Enum.Material.Metal
		ball.CFrame = top * CFrame.new(0, size * 0.78, 0)
		weldIt(ball)
		-- Pickle dots, clear of the eyes.
		local dotColor = Color3.fromRGB(40, 140, 40)
		for _, spot in ipairs({ { -0.25, 0.05 }, { 0.3, -0.15 }, { 0.05, 0.3 } }) do
			local dot = makePart("PickleDot", Enum.PartType.Ball, Vector3.new(size * 0.11, size * 0.11, size * 0.11), dotColor)
			dot.CFrame = body.CFrame * CFrame.new(spot[1] * size, spot[2] * bodySize.Y, bodySize.Z / 2 + size * 0.03)
			weldIt(dot)
		end
	elseif def.id == "toaster" then
		-- The toast slot on top, with a slice of toast popping out.
		local slot = makePart("ToastSlot", Enum.PartType.Block, Vector3.new(size * 0.55, size * 0.06, size * 0.34), Color3.fromRGB(40, 40, 45))
		slot.CFrame = top * CFrame.new(0, size * 0.01, 0)
		weldIt(slot)
		local toast = makePart("Toast", Enum.PartType.Block, Vector3.new(size * 0.36, size * 0.5, size * 0.12), Color3.fromRGB(235, 190, 120))
		toast.CFrame = top * CFrame.new(0, size * 0.2, 0)
		weldIt(toast)
		local butter = makePart("Butter", Enum.PartType.Block, Vector3.new(size * 0.16, size * 0.1, size * 0.14), Color3.fromRGB(255, 230, 80))
		butter.CFrame = top * CFrame.new(0, size * 0.48, 0)
		weldIt(butter)
		-- A front dial with a red pointer, clear of the belly.
		local dial = makePart("Dial", Enum.PartType.Cylinder, Vector3.new(size * 0.06, size * 0.2, size * 0.2), Color3.fromRGB(50, 50, 60))
		dial.CFrame = body.CFrame * CFrame.new(size * 0.3, -size * 0.02, bodySize.Z / 2 + size * 0.02) * CFrame.Angles(0, math.rad(90), 0)
		weldIt(dial)
		local pointer = makePart("DialPointer", Enum.PartType.Ball, Vector3.new(size * 0.07, size * 0.07, size * 0.07), Color3.fromRGB(255, 60, 60))
		pointer.Material = Enum.Material.Neon
		pointer.CFrame = body.CFrame * CFrame.new(size * 0.3, size * 0.05, bodySize.Z / 2 + size * 0.06)
		weldIt(pointer)
		-- Scalloped ghost hem along the bottom front edge.
		for _, xFrac in ipairs({ -0.28, 0, 0.28 }) do
			local scallop = makePart("GhostHem", Enum.PartType.Ball, Vector3.new(size * 0.16, size * 0.16, size * 0.16), body.Color)
			scallop.CFrame = body.CFrame * CFrame.new(xFrac * size, -bodySize.Y / 2 + size * 0.02, bodySize.Z / 2 - size * 0.1)
			weldIt(scallop)
		end
	elseif def.id == "socks" then
		-- A folded cuff straddling the top of the tall sock.
		local cuff = makePart("Cuff", Enum.PartType.Block, Vector3.new(bodySize.X * 1.18, size * 0.2, bodySize.Z * 1.18), Color3.fromRGB(230, 220, 245))
		cuff.CFrame = top * CFrame.new(0, -size * 0.06, 0)
		weldIt(cuff)
		-- A gold monocle RING over the right eye: 8 solid gold balls in
		-- a circle, so the eye shows through the middle (the old glass
		-- lens hid it). Plus a chain down to the chest.
		local eyeSize = math.min(size * 0.28, bodySize.Y * 0.55, bodySize.X * 0.32)
		local eyeX = bodySize.X * 0.24
		local eyeY = bodySize.Y * 0.16
		local eyeZ = bodySize.Z / 2 + eyeSize * 0.35
		for k = 0, 7 do
			local a = math.rad(k * 45)
			local bead = makePart("Monocle", Enum.PartType.Ball, Vector3.new(eyeSize * 0.24, eyeSize * 0.24, eyeSize * 0.24), Color3.fromRGB(255, 215, 0))
			bead.Material = Enum.Material.Metal
			bead.CFrame = body.CFrame * CFrame.new(eyeX + math.cos(a) * eyeSize * 0.72, eyeY + math.sin(a) * eyeSize * 0.72, eyeZ + size * 0.04)
			weldIt(bead)
		end
		local chain = makePart("MonocleChain", Enum.PartType.Block, Vector3.new(size * 0.04, size * 0.5, size * 0.04), Color3.fromRGB(255, 215, 0))
		chain.CFrame = body.CFrame * CFrame.new(eyeX + size * 0.35, -size * 0.05, bodySize.Z / 2 + size * 0.04) * CFrame.Angles(0, 0, math.rad(-35))
		weldIt(chain)
		-- A white toe cap at the bottom front.
		local toe = makePart("ToeCap", Enum.PartType.Block, Vector3.new(bodySize.X * 0.7, size * 0.16, size * 0.08), Color3.fromRGB(250, 250, 250))
		toe.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y / 2 + size * 0.05, bodySize.Z / 2 + size * 0.02)
		weldIt(toe)
	elseif def.id == "quokka" then
		-- A quantum orbit ring around the body: solid neon balls in a
		-- flat ring, with a gap at the front so no ball sits on the
		-- face, and a tiny planet riding the ring at the back. The old
		-- translucent disc hid the body from above; the ball ring
		-- reads as an orbit from every angle.
		local ringR = bodySize.X * 0.62
		for k = 0, 9 do
			local a = math.rad(k * 36)
			local x = math.cos(a) * ringR
			local z = math.sin(a) * ringR
			if z > ringR * 0.8 and math.abs(x) < ringR * 0.5 then
				continue -- front gap: keep the face clear
			end
			local bead = makePart("OrbitBead", Enum.PartType.Ball, Vector3.new(size * 0.12, size * 0.12, size * 0.12), Color3.fromRGB(80, 220, 255))
			bead.Material = Enum.Material.Neon
			bead.CFrame = body.CFrame * CFrame.new(x, size * 0.05, z)
			weldIt(bead)
		end
		local planet = makePart("OrbitPlanet", Enum.PartType.Ball, Vector3.new(size * 0.16, size * 0.16, size * 0.16), Color3.fromRGB(255, 150, 80))
		planet.CFrame = body.CFrame * CFrame.new(-ringR * 0.9, size * 0.05, -ringR * 0.44)
		weldIt(planet)
		-- Round ears on top.
		for _, side in ipairs({ -1, 1 }) do
			local ear = makePart("Ear", Enum.PartType.Ball, Vector3.new(size * 0.2, size * 0.2, size * 0.2), body.Color)
			ear.CFrame = top * CFrame.new(side * size * 0.24, size * 0.08, 0)
			weldIt(ear)
		end
		-- Rosy cheeks and a pink tongue under the smile.
		for _, side in ipairs({ -1, 1 }) do
			local cheek = makePart("Blush", Enum.PartType.Ball, Vector3.new(size * 0.13, size * 0.13, size * 0.13), Color3.fromRGB(255, 150, 180))
			cheek.CFrame = body.CFrame * CFrame.new(side * bodySize.X * 0.32, -bodySize.Y * 0.05, bodySize.Z / 2 + size * 0.05)
			weldIt(cheek)
		end
		local tongue = makePart("Tongue", Enum.PartType.Block, Vector3.new(size * 0.16, size * 0.1, size * 0.05), Color3.fromRGB(255, 120, 150))
		tongue.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.2 - size * 0.08, bodySize.Z / 2 + size * 0.14)
		weldIt(tongue)
	elseif def.id == "turnip" then
		-- Turnip leaves sprouting from the top.
		for i = 1, 3 do
			local leaf = makePart("Leaf", Enum.PartType.Wedge, Vector3.new(size * 0.12, size * 0.4, size * 0.2), Color3.fromRGB(60, 180, 80))
			leaf.CFrame = top * CFrame.new((i - 2) * size * 0.14, size * 0.14, 0) * CFrame.Angles(0, 0, (i - 2) * -0.4)
			weldIt(leaf)
		end
		-- A root bulb under the body, with two thin root strands.
		local bulb = makePart("RootBulb", Enum.PartType.Ball, Vector3.new(size * 0.26, size * 0.26, size * 0.26), Color3.fromRGB(220, 190, 230))
		bulb.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y / 2 + size * 0.04, 0)
		weldIt(bulb)
		for _, side in ipairs({ -1, 1 }) do
			local strand = makePart("RootStrand", Enum.PartType.Cylinder, Vector3.new(size * 0.3, size * 0.05, size * 0.05), Color3.fromRGB(220, 190, 230))
			strand.CFrame = body.CFrame * CFrame.new(side * size * 0.12, -bodySize.Y / 2 - size * 0.08, 0) * CFrame.Angles(0, 0, side * 0.5)
			weldIt(strand)
		end
		-- Rosy cheeks.
		for _, side in ipairs({ -1, 1 }) do
			local cheek = makePart("Blush", Enum.PartType.Ball, Vector3.new(size * 0.13, size * 0.13, size * 0.13), Color3.fromRGB(255, 150, 180))
			cheek.CFrame = body.CFrame * CFrame.new(side * bodySize.X * 0.32, -bodySize.Y * 0.05, bodySize.Z / 2 + size * 0.05)
			weldIt(cheek)
		end
	elseif def.id == "bloop" then
		-- A bow tie at the neck, sitting ON the belly patch (proud of
		-- its front surface): the old tie sat at the body face and was
		-- buried inside the belly.
		for _, side in ipairs({ -1, 1 }) do
			local wing = makePart("BowTie", Enum.PartType.Wedge, Vector3.new(size * 0.08, size * 0.18, size * 0.2), Color3.fromRGB(160, 20, 60))
			wing.CFrame = body.CFrame * CFrame.new(side * size * 0.14, -size * 0.22, bodySize.Z / 2 + size * 0.14) * CFrame.Angles(0, math.rad(180), 0)
			weldIt(wing)
		end
		local knot = makePart("BowKnot", Enum.PartType.Ball, Vector3.new(size * 0.1, size * 0.1, size * 0.1), Color3.fromRGB(160, 20, 60))
		knot.CFrame = body.CFrame * CFrame.new(0, -size * 0.22, bodySize.Z / 2 + size * 0.16)
		weldIt(knot)
		-- Gold drips on the dome.
		for _, side in ipairs({ -1, 1 }) do
			local drip = makePart("GoldDrip", Enum.PartType.Ball, Vector3.new(size * 0.15, size * 0.15, size * 0.15), Color3.fromRGB(255, 215, 0))
			drip.Material = Enum.Material.Metal
			drip.CFrame = body.CFrame * CFrame.new(side * bodySize.X * 0.42, bodySize.Y * 0.28, bodySize.Z * 0.2)
			weldIt(drip)
		end
	elseif def.id == "couch" then
		-- The couch itself: a backrest and two armrests in a darker
		-- shade of the Mythic pink, so the wide low body reads as a
		-- couch from the front and the side.
		local couchColor = Color3.new(body.Color.R * 0.7, body.Color.G * 0.7, body.Color.B * 0.7)
		local back = makePart("Backrest", Enum.PartType.Block, Vector3.new(bodySize.X * 0.92, size * 0.7, size * 0.28), couchColor)
		back.CFrame = body.CFrame * CFrame.new(0, size * 0.15, -bodySize.Z / 2 - size * 0.1)
		weldIt(back)
		for _, side in ipairs({ -1, 1 }) do
			local rest = makePart("Armrest", Enum.PartType.Block, Vector3.new(size * 0.32, size * 0.42, bodySize.Z * 0.85), couchColor)
			rest.CFrame = body.CFrame * CFrame.new(side * (bodySize.X / 2 + size * 0.1), -size * 0.02, 0)
			weldIt(rest)
		end
		-- The emperor's crown, on top of the backrest.
		local backTop = size * 0.15 + size * 0.35
		local band = makePart("Crown", Enum.PartType.Cylinder, Vector3.new(size * 0.14, size * 0.5, size * 0.5), Color3.fromRGB(255, 215, 0))
		band.Material = Enum.Material.Metal
		band.CFrame = body.CFrame * CFrame.new(0, backTop + size * 0.05, -bodySize.Z / 2 - size * 0.1) * CFrame.Angles(0, 0, math.rad(90))
		weldIt(band)
		for i = 1, 3 do
			local spike = makePart("CrownSpike", Enum.PartType.Wedge, Vector3.new(size * 0.1, size * 0.22, size * 0.1), Color3.fromRGB(255, 215, 0))
			spike.Material = Enum.Material.Metal
			spike.CFrame = body.CFrame * CFrame.new((i - 2) * size * 0.18, backTop + size * 0.18, -bodySize.Z / 2 - size * 0.1)
			weldIt(spike)
		end
		-- A crimson cape draped over the back of the backrest.
		local cape = makePart("Cape", Enum.PartType.Block, Vector3.new(bodySize.X * 0.7, size * 0.45, size * 0.06), Color3.fromRGB(160, 20, 60))
		cape.CFrame = body.CFrame * CFrame.new(0, size * 0.28, -bodySize.Z / 2 - size * 0.24) * CFrame.Angles(-0.12, 0, 0)
		weldIt(cape)
		-- A TV remote leaning on the couch front, with a red button.
		local remote = makePart("Remote", Enum.PartType.Block, Vector3.new(size * 0.22, size * 0.42, size * 0.1), Color3.fromRGB(35, 35, 45))
		remote.CFrame = body.CFrame * CFrame.new(bodySize.X * 0.32, size * 0.02, bodySize.Z / 2 + size * 0.06) * CFrame.Angles(-0.3, 0, 0)
		weldIt(remote)
		local btn = makePart("RemoteButton", Enum.PartType.Ball, Vector3.new(size * 0.07, size * 0.07, size * 0.07), Color3.fromRGB(255, 60, 60))
		btn.Material = Enum.Material.Neon
		btn.CFrame = body.CFrame * CFrame.new(bodySize.X * 0.32, size * 0.14, bodySize.Z / 2 + size * 0.12)
		weldIt(btn)
		-- Cushion tufts on the seat front, above the belly.
		for _, side in ipairs({ -1, 1 }) do
			local tuft = makePart("Tuft", Enum.PartType.Ball, Vector3.new(size * 0.11, size * 0.11, size * 0.11), Color3.fromRGB(200, 50, 110))
			tuft.CFrame = body.CFrame * CFrame.new(side * size * 0.21, bodySize.Y * 0.16, bodySize.Z / 2 + size * 0.04)
			weldIt(tuft)
		end
	elseif def.id == "gummy" then
		-- Bear ears with pink inners.
		for _, side in ipairs({ -1, 1 }) do
			local ear = makePart("Ear", Enum.PartType.Ball, Vector3.new(size * 0.3, size * 0.3, size * 0.3), body.Color)
			ear.CFrame = top * CFrame.new(side * size * 0.28, size * 0.06, 0)
			weldIt(ear)
			local inner = makePart("EarInner", Enum.PartType.Ball, Vector3.new(size * 0.16, size * 0.16, size * 0.16), Color3.fromRGB(255, 150, 200))
			inner.CFrame = top * CFrame.new(side * size * 0.28, size * 0.06, size * 0.12)
			weldIt(inner)
		end
		-- A snout with a dark nose, above the mouth.
		local snout = makePart("Snout", Enum.PartType.Ball, Vector3.new(size * 0.42, size * 0.3, size * 0.22), Color3.fromRGB(150, 240, 255))
		snout.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.1, bodySize.Z / 2 + size * 0.04)
		weldIt(snout)
		local nose = makePart("Nose", Enum.PartType.Ball, Vector3.new(size * 0.1, size * 0.1, size * 0.08), Color3.fromRGB(40, 25, 20))
		nose.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.06, bodySize.Z / 2 + size * 0.16)
		weldIt(nose)
		-- A bright 4-point star on the belly (the gummy's star belly).
		local starColor = Color3.fromRGB(255, 240, 120)
		local starV = makePart("StarBelly", Enum.PartType.Block, Vector3.new(size * 0.09, size * 0.38, size * 0.05), starColor)
		starV.Material = Enum.Material.Neon
		starV.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.18, bodySize.Z / 2 + size * 0.12)
		weldIt(starV)
		local starH = makePart("StarBelly", Enum.PartType.Block, Vector3.new(size * 0.38, size * 0.09, size * 0.05), starColor)
		starH.Material = Enum.Material.Neon
		starH.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.18, bodySize.Z / 2 + size * 0.12)
		weldIt(starH)
	elseif def.id == "smore" then
		-- A dirt mound: the mole is half-buried, only the top shows.
		local mound = makePart("DirtMound", Enum.PartType.Ball, Vector3.new(bodySize.X * 1.1, size * 0.3, bodySize.Z * 1.1), Color3.fromRGB(120, 85, 50))
		mound.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.35, 0)
		weldIt(mound)
		-- A tiny shovel stuck in the mound, and a hard hat.
		local shovel = makePart("Shovel", Enum.PartType.Block, Vector3.new(size * 0.08, size * 0.6, size * 0.08), Color3.fromRGB(150, 110, 60), Enum.Material.Wood)
		shovel.CFrame = top * CFrame.new(bodySize.X * 0.35, size * 0.2, 0) * CFrame.Angles(0, 0, -0.3)
		weldIt(shovel)
		local hat = makePart("HardHat", Enum.PartType.Ball, Vector3.new(size * 0.45, size * 0.22, size * 0.45), Color3.fromRGB(255, 200, 40))
		hat.CFrame = top * CFrame.new(0, size * 0.02, 0)
		weldIt(hat)
	elseif def.id == "tortoise" then
		-- A domed shell plate on the back, with a shell rim.
		local shell = makePart("Shell", Enum.PartType.Ball, Vector3.new(bodySize.X * 0.9, size * 0.35, bodySize.Z * 0.9), Color3.fromRGB(90, 140, 70))
		shell.CFrame = top * CFrame.new(0, -size * 0.05, -bodySize.Z * 0.1)
		weldIt(shell)
		-- Four stubby feet peeking out, and a little tail.
		for _, spot in ipairs({ { -0.35, 0.3 }, { 0.35, 0.3 }, { -0.35, -0.3 }, { 0.35, -0.3 } }) do
			local foot = makePart("Foot", Enum.PartType.Ball, Vector3.new(size * 0.16, size * 0.16, size * 0.16), Color3.fromRGB(60, 110, 50))
			foot.CFrame = body.CFrame * CFrame.new(spot[1] * bodySize.X, -bodySize.Y * 0.4, spot[2] * bodySize.Z)
			weldIt(foot)
		end
		local tail = makePart("Tail", Enum.PartType.Ball, Vector3.new(size * 0.14, size * 0.14, size * 0.14), Color3.fromRGB(60, 110, 50))
		tail.CFrame = body.CFrame * CFrame.new(0, -size * 0.1, -bodySize.Z / 2 - size * 0.05)
		weldIt(tail)
	elseif def.id == "boba" then
		-- A wide straw poking out of the top, and three boba pearls
		-- floating in the body.
		local straw = makePart("Straw", Enum.PartType.Cylinder, Vector3.new(size * 0.5, size * 0.14, size * 0.14), Color3.fromRGB(255, 120, 150))
		straw.CFrame = top * CFrame.new(size * 0.1, size * 0.2, 0) * CFrame.Angles(0, 0, -0.25)
		weldIt(straw)
		for _, spot in ipairs({ { -0.2, -0.1 }, { 0.2, -0.25 }, { 0, 0.1 } }) do
			local pearl = makePart("Pearl", Enum.PartType.Ball, Vector3.new(size * 0.14, size * 0.14, size * 0.14), Color3.fromRGB(40, 25, 20))
			pearl.CFrame = body.CFrame * CFrame.new(spot[1] * bodySize.X, spot[2] * bodySize.Y, bodySize.Z / 2 + size * 0.03)
			weldIt(pearl)
		end
	elseif def.id == "penguin" then
		-- A white belly patch and a little orange beak.
		local bellyPatch = makePart("BellyPatch", Enum.PartType.Ball, Vector3.new(bodySize.X * 0.55, bodySize.Y * 0.5, size * 0.12), Color3.fromRGB(245, 245, 245))
		bellyPatch.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.1, bodySize.Z / 2 + size * 0.02)
		weldIt(bellyPatch)
		local beak = makePart("Beak", Enum.PartType.Block, Vector3.new(size * 0.2, size * 0.12, size * 0.16), Color3.fromRGB(255, 160, 40))
		beak.CFrame = body.CFrame * CFrame.new(0, -size * 0.02, bodySize.Z / 2 + size * 0.06)
		weldIt(beak)
		-- Two flipper wings on the sides.
		for _, side in ipairs({ -1, 1 }) do
			local flipper = makePart("Flipper", Enum.PartType.Block, Vector3.new(size * 0.1, size * 0.5, size * 0.25), Color3.fromRGB(40, 60, 90))
			flipper.CFrame = body.CFrame * CFrame.new(side * (bodySize.X / 2 + size * 0.04), 0, 0)
			weldIt(flipper)
		end
	elseif def.id == "avocado" then
		-- A big round pit in the middle, and a little leaf on top.
		local pit = makePart("Pit", Enum.PartType.Ball, Vector3.new(size * 0.35, size * 0.35, size * 0.15), Color3.fromRGB(120, 70, 30))
		pit.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.1, bodySize.Z / 2 + size * 0.04)
		weldIt(pit)
		local leaf = makePart("Leaf", Enum.PartType.Block, Vector3.new(size * 0.3, size * 0.08, size * 0.2), Color3.fromRGB(60, 180, 80))
		leaf.CFrame = top * CFrame.new(size * 0.15, size * 0.05, 0) * CFrame.Angles(0, 0.4, 0.4)
		weldIt(leaf)
		local stem = makePart("Stem", Enum.PartType.Cylinder, Vector3.new(size * 0.2, size * 0.08, size * 0.08), Color3.fromRGB(120, 80, 40))
		stem.CFrame = top * CFrame.new(0, size * 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
		weldIt(stem)
	elseif def.id == "llama" then
		-- A long neck with a small head, and a fluffy tail.
		local neck = makePart("Neck", Enum.PartType.Block, Vector3.new(size * 0.22, size * 0.5, size * 0.22), body.Color)
		neck.CFrame = top * CFrame.new(0, size * 0.2, 0)
		weldIt(neck)
		local head = makePart("Head", Enum.PartType.Block, Vector3.new(size * 0.3, size * 0.3, size * 0.3), body.Color)
		head.CFrame = top * CFrame.new(0, size * 0.55, 0)
		weldIt(head)
		local fluff = makePart("Fluff", Enum.PartType.Ball, Vector3.new(size * 0.3, size * 0.3, size * 0.3), Color3.fromRGB(255, 245, 220))
		fluff.CFrame = body.CFrame * CFrame.new(0, -size * 0.1, -bodySize.Z / 2 - size * 0.05)
		weldIt(fluff)
	elseif def.id == "narwhal" then
		-- The unicorn horn, spiralled, and a little tail fin.
		local horn = makePart("Horn", Enum.PartType.Cylinder, Vector3.new(size * 0.5, size * 0.12, size * 0.12), Color3.fromRGB(240, 240, 250))
		horn.CFrame = top * CFrame.new(0, size * 0.25, 0) * CFrame.Angles(0, 0, math.rad(90))
		weldIt(horn)
		local fin = makePart("TailFin", Enum.PartType.Block, Vector3.new(size * 0.4, size * 0.1, size * 0.25), body.Color)
		fin.CFrame = body.CFrame * CFrame.new(0, -size * 0.1, -bodySize.Z / 2 - size * 0.08)
		weldIt(fin)
		-- Two side fins.
		for _, side in ipairs({ -1, 1 }) do
			local sideFin = makePart("SideFin", Enum.PartType.Block, Vector3.new(size * 0.08, size * 0.3, size * 0.2), body.Color)
			sideFin.CFrame = body.CFrame * CFrame.new(side * (bodySize.X / 2 + size * 0.03), -bodySize.Y * 0.2, 0)
			weldIt(sideFin)
		end
	elseif def.id == "cat" then
		-- Pointy cat ears and a long comet tail with a star tip.
		for _, side in ipairs({ -1, 1 }) do
			local ear = makePart("Ear", Enum.PartType.Block, Vector3.new(size * 0.18, size * 0.3, size * 0.1), body.Color)
			ear.CFrame = top * CFrame.new(side * size * 0.25, size * 0.1, 0) * CFrame.Angles(0, 0, side * -0.2)
			weldIt(ear)
		end
		local tail = makePart("CometTail", Enum.PartType.Block, Vector3.new(size * 0.12, size * 0.12, size * 0.8), Color3.fromRGB(255, 180, 80))
		tail.Material = Enum.Material.Neon
		tail.CFrame = body.CFrame * CFrame.new(0, size * 0.1, -bodySize.Z / 2 - size * 0.35)
		weldIt(tail)
		local star = makePart("TailStar", Enum.PartType.Ball, Vector3.new(size * 0.25, size * 0.25, size * 0.25), Color3.fromRGB(255, 240, 120))
		star.Material = Enum.Material.Neon
		star.CFrame = body.CFrame * CFrame.new(0, size * 0.1, -bodySize.Z / 2 - size * 0.75)
		weldIt(star)
	end
end

local function addAccessory(model: Model, body: Part, def: RotlingCatalog.RotlingDef, rarityColor: Color3)
	-- Noodle, Crumb, Toaster and Couch get a name-specific prop instead
	-- of the generic one (see addNameProp): a chef hat, a captain's
	-- hat, a slice of toast and a couch with a cape read as those names
	-- far better than a bowler or an antenna. `top` is the body's own
	-- top edge, so a hat sits on the head instead of floating above a
	-- flat body or sinking into a tall one.
	if def.id == "noodle" or def.id == "crumb" or def.id == "toaster" or def.id == "couch" then
		return
	end
	local size = def.size
	local top = body.CFrame * CFrame.new(0, body.Size.Y / 2, 0)
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
	-- Idempotent: exactly ONE label per Rotling. addLabel used to
	-- create a fresh BillboardGui every time it ran, so a Rotling
	-- that was re-labelled (rebuild, restore, re-place) showed its
	-- name and rarity twice, overlapping. Remove any existing label
	-- first so there is never a second one.
	local existing = body:FindFirstChild("RotlingLabel")
	if existing then
		existing:Destroy()
	end
	local rarity = RarityConfig.rarityByName(def.rarity)
	local cps = RotlingCatalog.baseCps(def, mutation)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RotlingLabel"
	billboard.Size = UDim2.fromOffset(200, 84)
	-- The tag floats above the model's TALLEST part (chef hat, crown,
	-- disco ball), not at a fixed height: the bounding-box top plus a
	-- margin, so it never covers the face or a tall accessory. The 1x
	-- offset is stored on the model so refreshLabelOffset can re-seat
	-- it after any scale change (crater 1.5x, pad 1x).
	local boxCf, boxSize = model:GetBoundingBox()
	local tagOffset = (boxCf.Position.Y + boxSize.Y / 2) - body.Position.Y + 0.8
	billboard.StudsOffsetWorldSpace = Vector3.new(0, tagOffset, 0)
	model:SetAttribute("LabelBaseOffset", tagOffset)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	-- Big and readable at thumbnail size: the tag is the rarest readable
	-- surface in the game, so it is 200x84 with a dark card behind it
	-- and a border in the rarity colour — the bare-white-text version
	-- washed out against the bright sky. The billboard renders out to
	-- 40 studs (the photo-mode tag range); the client TagController is
	-- the real gate — nearest 3 within 25 studs in normal play, every
	-- tag within 40 in photo mode — so close tags never stack.
	billboard.MaxDistance = 40
	billboard.Parent = body

	-- Dark card behind the text, with a rarity-colour border.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(20, 15, 40)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	card.Parent = billboard
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = rarity.color
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 1 -- no stroke: the 0.4 stroke rendered a ghost offset of the text behind the real text, doubling the name at a glance; the dark card behind the text is the contrast, not a stroke
	nameLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Position = UDim2.new(0, 0, 0.4, 0)
	rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLabel.BackgroundTransparency = 1
	-- The mutation line carries the multiplier (cheap win 1): a mutated
	-- Rotling's tag reads "✦ RAINBOW x5" so the value is obvious from
	-- the path — and the cps line below already includes it.
	local rarityText = def.rarity
	if mutation then
		rarityText ..= " ✦ " .. mutation .. " x" .. tostring(MutationConfig.mutationMult(mutation))
	end
	rarityLabel.Text = rarityText
	rarityLabel.Font = Enum.Font.FredokaOne
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = rarity.color
	rarityLabel.TextStrokeTransparency = 1
	rarityLabel.Parent = billboard

	local cpsLabel = Instance.new("TextLabel")
	cpsLabel.Name = "Cps"
	cpsLabel.Position = UDim2.new(0, 0, 0.7, 0)
	cpsLabel.Size = UDim2.new(1, 0, 0.3, 0)
	cpsLabel.BackgroundTransparency = 1
	-- One shared money format (Formatting.formatMoney already carries
	-- the "$"): never prepend another "$" here or the sign reads "$$".
	cpsLabel.Text = Formatting.formatMoney(cps) .. "/s"
	cpsLabel.Font = Enum.Font.FredokaOne
	cpsLabel.TextScaled = true
	cpsLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
	cpsLabel.TextStrokeTransparency = 1
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
	emitter.Rate = 8
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Parent = body
end

-- Rarity outline so a placed Rotling glows its tier colour from afar.
-- Kept subtle (mostly transparent) so the outline reads as a rim, not
-- a translucent wash over the whole model.
local function addRarityHighlight(model: Model, rarityColor: Color3)
	local highlight = Instance.new("Highlight")
	highlight.Name = "RarityGlow"
	highlight.FillColor = rarityColor
	highlight.FillTransparency = 0.75
	highlight.OutlineColor = rarityColor
	highlight.OutlineTransparency = 0.5
	highlight.Parent = model
end

-- Rarity aura, on top of the highlight: Common has none, Rare sparkles,
-- Epic sparkles too (no shell — a translucent shell around every Epic
-- made the whole crater read as semi-transparent blobs), Legendary adds
-- a faint shell plus a rainbow trail, and Mythic/Cosmic get the shell
-- plus sparkles. The shell is nearly transparent (0.88) so the solid
-- body and face underneath always read first. Rates, light range and
-- trail length are tuned so the aura reads from the path, not only up
-- close.
local function addRarityAura(model: Model, body: Part, def: RotlingCatalog.RotlingDef, rarityColor: Color3)
	local tier = RarityConfig.rarityTier(def.rarity)
	local size = def.size
	if tier < 2 then
		return
	end
	local function sparkles(rate: number)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "RaritySparkle"
		emitter.Color = ColorSequence.new(rarityColor)
		emitter.Size = NumberSequence.new(0.35)
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.9) })
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Rate = rate
		emitter.Speed = NumberRange.new(1, 2.5)
		emitter.SpreadAngle = Vector2.new(360, 360)
		emitter.Parent = body
	end
	local function glowShell()
		local shell = makePart("GlowShell", Enum.PartType.Ball, Vector3.new(body.Size.X * 1.18, body.Size.Y * 1.18, body.Size.Z * 1.18), rarityColor, Enum.Material.Neon)
		shell.Transparency = 0.88
		shell.CFrame = body.CFrame
		shell.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = shell
		weld.Parent = shell
	end
	if tier == 2 then
		sparkles(8)
	elseif tier == 3 then
		sparkles(8)
	elseif tier == 4 then
		glowShell()
		sparkles(8)
		-- Rainbow trail: two attachments, one rainbow colour sequence.
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailA0"
		a0.Position = Vector3.new(-size * 0.3, size * 0.3, 0)
		a0.Parent = body
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailA1"
		a1.Position = Vector3.new(size * 0.3, -size * 0.3, 0)
		a1.Parent = body
		local trail = Instance.new("Trail")
		trail.Name = "RainbowTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 160, 40)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 230, 60)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 100)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 90, 255)),
		})
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.85) })
		trail.Lifetime = 0.9
		trail.MinLength = 0.6
		trail.Parent = body
	else
		-- Mythic and Cosmic: strongest glow plus sparkles.
		glowShell()
		sparkles(12)
	end
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
	elseif mutation == "Diamond" then
		body.Color = Color3.fromRGB(190, 240, 255)
		body.Material = Enum.Material.Glass
	elseif mutation == "Scorched" then
		body.Color = Color3.fromRGB(60, 35, 25)
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
				text ..= " ✦ " .. mutation .. " x" .. tostring(MutationConfig.mutationMult(mutation))
			end
			rarityLabel.Text = text
		end
		local cpsLabel = label:FindFirstChild("Cps")
		if cpsLabel and cpsLabel:IsA("TextLabel") then
			cpsLabel.Text = Formatting.formatMoney(RotlingCatalog.baseCps(def, mutation)) .. "/s"
		end
	end
end

-- Build a Rotling Model at the given position, unowned and free.
-- `scale` is the build size relative to the catalogue size: crater
-- spawns build at 1.5x so they read from the path; pads and showcases
-- build at 1x. Carrying shrinks to ~head size and placing restores 1x.
function RotlingFactory.build(defId: string, mutation: string?, position: Vector3, scale: number?): Model?
	local def = RotlingCatalog.getDef(defId)
	if not def then
		return nil
	end
	local rarity = RarityConfig.rarityByName(def.rarity)
	local size = def.size

	local model = Instance.new("Model")
	model.Name = def.name

	-- One unique silhouette per Rotling (see bodyForSilhouette).
	local bodySize, bodyShape = bodyForSilhouette(def)

	-- The body IS the rarity colour, verbatim — no re-saturation, so a
	-- Common reads rarity blue and a Cosmic reads rarity cyan, exactly
	-- as RarityConfig defines them (checked by auto-check (ai)).
	local bodyColor = rarity.color
	if mutation == "Gold" then
		bodyColor = Color3.fromRGB(255, 215, 0)
	elseif mutation == "Frozen" then
		bodyColor = Color3.fromRGB(170, 225, 255)
	elseif mutation == "Starstruck" then
		bodyColor = Color3.fromRGB(255, 240, 170)
	elseif mutation == "Diamond" then
		bodyColor = Color3.fromRGB(190, 240, 255)
	elseif mutation == "Scorched" then
		bodyColor = Color3.fromRGB(60, 35, 25)
	end
	local body = makePart("Body", bodyShape, bodySize, bodyColor)
	-- Gummy Bear reads "translucent" without any transparency: a bright
	-- Neon body in its Cosmic cyan, solid (Transparency 0) like the
	-- rest, with the glow shell and sparkles on top.
	body.Material = if mutation == "Rainbow" or mutation == "Starstruck" then Enum.Material.Neon
		elseif mutation == "Diamond" then Enum.Material.Glass
		elseif def.id == "gummy" then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	-- Rest the body's bottom on the given surface: centre it half its
	-- own height above the position, so no Rotling is ever sunk into the
	-- crater disc or a pad by a fixed size*0.55 guess.
	body.CFrame = CFrame.new(position + Vector3.new(0, bodySize.Y / 2 + 0.1, 0))
	body.Anchored = true -- rests on the crater floor; carrying un-anchors it
	body.Parent = model
	model.PrimaryPart = body

	-- Belly patch on the front, sized from the body's own size.
	local belly = makePart("Belly", Enum.PartType.Ball, Vector3.new(bodySize.X * 0.45, bodySize.Y * 0.42, size * 0.2), saturate(def.bellyColor, 1.2))
	belly.CFrame = body.CFrame * CFrame.new(0, -bodySize.Y * 0.18, bodySize.Z / 2)
	belly.Parent = model
	local bellyWeld = Instance.new("WeldConstraint")
	bellyWeld.Part0 = body
	bellyWeld.Part1 = belly
	bellyWeld.Parent = belly

	addEyes(model, body, size)
	addMouth(model, body, size)
	addFeet(model, body, size)
	addArms(model, body, def)
	addAccessory(model, body, def, rarity.color)
	addNameProp(model, body, def)
	addLabel(model, body, def, mutation)
	addMutationSparkle(model, body, mutation)
	addRarityHighlight(model, rarity.color)
	addRarityAura(model, body, def, rarity.color)

	-- Rarity glow: dimmer and shorter the higher the tier, so a crowd
	-- of Rotlings never washes the crater white. The colour still reads
	-- the tier from the path.
	local mut = MutationConfig.mutationByName(mutation)
	local tier = RarityConfig.rarityTier(def.rarity)
	local light = Instance.new("PointLight")
	light.Color = if mut then mut.glow else rarity.color
	light.Brightness = 1 + tier * 0.35
	light.Range = 8 + tier * 1.5
	light.Parent = body

	-- Coin burst, fired once when the Rotling lands on a pad (placePop).
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "CoinBurst"
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
	burst.Size = NumberSequence.new(0.5)
	burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	burst.Lifetime = NumberRange.new(0.5, 0.9)
	burst.Rate = 0
	burst.Speed = NumberRange.new(8, 13)
	burst.SpreadAngle = Vector2.new(360, 360)
	burst.Enabled = false
	burst.Parent = body

	-- Build size: crater spawns are 1.5x so they read from the path.
	-- Scaling grows the body around its centre, so re-seat the whole
	-- model so its bottom rests on the surface again, then record the
	-- rest pose the idle loop bobs around.
	local targetScale = scale or 1
	RotlingFactory.setModelScale(model, targetScale)
	local b = model.PrimaryPart
	if b and b:IsA("BasePart") then
		model:PivotTo(CFrame.new(position + Vector3.new(0, b.Size.Y / 2 + 0.1, 0)))
	end
	-- The tag offset is in studs, not model scale: re-seat it for the
	-- build scale, or a 1.5x crater Rotling's tag sinks into its hat.
	RotlingFactory.refreshLabelOffset(model)

	-- Remember the rest pose so the idle loop can bob around it.
	RotlingFactory.setRestPose(model)
	startIdleMotion()

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
