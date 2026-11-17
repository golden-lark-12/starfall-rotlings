--!strict
-- Starfall Rotlings: builds a Rotling Model from a RotlingCatalog definition.
-- Every creature is Parts only: a body, a belly, big eyes, feet, one
-- accessory, a rarity glow light, a mutation sparkle and a name/rarity/
-- coins-per-second label. No meshes, decals or uploaded assets are used
-- anywhere. The body starts Anchored so a free Rotling rests on the
-- crater floor instead of falling through the world; carrying un-anchors
-- it and welds it to the player, placing re-anchors it.

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
-- the chest — no bubble, no shrink-to-a-box. The glow shell and the
-- highlight are dimmed while carried so the Rotling keeps its real
-- colours and face instead of reading as a big pale block over the
-- player's view. The name tag hides while carried too (it overlaps
-- the top HUD). Call with false on place/scatter to restore everything;
-- the caller re-sets the size (1 on a pad, 1.5x back in the crater).
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
	local hl = model:FindFirstChildOfClass("Highlight")
	if hl then
		hl.Enabled = not carried
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
					local state = model:GetAttribute("State")
					if body and (state == "free" or state == "placed") then
						local seed = bobSeed[model] or 0
						local bob = math.sin(now * 1.6 + seed) * 0.22
						-- Placed Rotlings slowly spin on display; free ones
						-- sway so their face stays toward the player.
						local angle = if state == "placed"
							then (now * 0.5 + seed) % (math.pi * 2)
							else math.sin(now * 0.6 + seed) * 0.25
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
	ding.Volume = 0.6
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

local function addArms(model: Model, body: Part, size: number)
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
-- after the generic accessory; for noodle, crumb and toaster it IS the
-- accessory (addAccessory skips the generic one for those three).
local function addNameProp(model: Model, body: Part, def: RotlingCatalog.RotlingDef)
	local size = def.size
	local top = body.CFrame * CFrame.new(0, size * 0.55, 0)
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
	elseif def.id == "noodle" then
		-- A chef's hat: white brim and puffy crown.
		local brim = makePart("ChefBrim", Enum.PartType.Cylinder, Vector3.new(size * 0.12, size * 0.55, size * 0.55), Color3.fromRGB(245, 245, 245))
		brim.CFrame = top * CFrame.Angles(0, 0, math.rad(90))
		weldIt(brim)
		local crown = makePart("ChefTop", Enum.PartType.Ball, Vector3.new(size * 0.42, size * 0.36, size * 0.42), Color3.fromRGB(250, 250, 250))
		crown.CFrame = top * CFrame.new(0, size * 0.2, 0)
		weldIt(crown)
	elseif def.id == "crumb" then
		-- A captain's hat: dark blue cap with a white front band.
		local cap = makePart("CaptainHat", Enum.PartType.Cylinder, Vector3.new(size * 0.14, size * 0.55, size * 0.55), Color3.fromRGB(30, 60, 130))
		cap.CFrame = top * CFrame.Angles(0, 0, math.rad(90))
		weldIt(cap)
		local band = makePart("CaptainBand", Enum.PartType.Block, Vector3.new(size * 0.5, size * 0.08, size * 0.06), Color3.fromRGB(250, 250, 250))
		band.CFrame = top * CFrame.new(0, size * 0.02, size * 0.26)
		weldIt(band)
	elseif def.id == "pickle" then
		-- A tiny disco ball on a stem, above the headphones.
		local stem = makePart("DiscoStem", Enum.PartType.Cylinder, Vector3.new(size * 0.3, size * 0.06, size * 0.06), Color3.fromRGB(90, 90, 100))
		stem.CFrame = top * CFrame.new(0, size * 0.14, 0) * CFrame.Angles(0, 0, math.rad(90))
		weldIt(stem)
		local ball = makePart("DiscoBall", Enum.PartType.Ball, Vector3.new(size * 0.28, size * 0.28, size * 0.28), Color3.fromRGB(210, 210, 220))
		ball.Material = Enum.Material.Metal
		ball.CFrame = top * CFrame.new(0, size * 0.36, 0)
		weldIt(ball)
	elseif def.id == "toaster" then
		-- A slice of toast popping out of the ghost.
		local toast = makePart("Toast", Enum.PartType.Block, Vector3.new(size * 0.36, size * 0.5, size * 0.12), Color3.fromRGB(235, 190, 120))
		toast.CFrame = top * CFrame.new(0, size * 0.2, 0)
		weldIt(toast)
		local butter = makePart("Butter", Enum.PartType.Block, Vector3.new(size * 0.16, size * 0.1, size * 0.14), Color3.fromRGB(255, 230, 80))
		butter.CFrame = top * CFrame.new(0, size * 0.48, 0)
		weldIt(butter)
	elseif def.id == "socks" then
		-- A gold monocle lens over the right eye, with a chain. The lens
		-- is translucent glass so the eye shows through it.
		local ring = makePart("Monocle", Enum.PartType.Cylinder, Vector3.new(size * 0.05, size * 0.26, size * 0.26), Color3.fromRGB(255, 215, 0))
		ring.Material = Enum.Material.Glass
		ring.Transparency = 0.3
		ring.CFrame = body.CFrame * CFrame.new(size * 0.22, size * 0.18, body.Size.Z / 2 + size * 0.06) * CFrame.Angles(0, math.rad(90), 0)
		weldIt(ring)
		local chain = makePart("MonocleChain", Enum.PartType.Cylinder, Vector3.new(size * 0.3, size * 0.04, size * 0.04), Color3.fromRGB(255, 215, 0))
		chain.CFrame = body.CFrame * CFrame.new(size * 0.34, -size * 0.05, body.Size.Z / 2 + size * 0.04) * CFrame.Angles(0, 0, math.rad(90))
		weldIt(chain)
	elseif def.id == "quokka" then
		-- A quantum orbit ring around the body, with a tiny planet on it.
		-- The ring is a thin translucent disc so the body shows through
		-- from above and the glowing edge reads from the side.
		local orbit = makePart("OrbitRing", Enum.PartType.Cylinder, Vector3.new(size * 0.06, size * 1.35, size * 1.35), Color3.fromRGB(80, 220, 255))
		orbit.Material = Enum.Material.Neon
		orbit.Transparency = 0.5
		orbit.CFrame = body.CFrame * CFrame.Angles(0, 0, math.rad(90))
		weldIt(orbit)
		local planet = makePart("OrbitPlanet", Enum.PartType.Ball, Vector3.new(size * 0.16, size * 0.16, size * 0.16), Color3.fromRGB(255, 150, 80))
		planet.CFrame = body.CFrame * CFrame.new(size * 0.62, size * 0.1, 0)
		weldIt(planet)
	elseif def.id == "turnip" then
		-- Turnip leaves sprouting from the top.
		for i = 1, 3 do
			local leaf = makePart("Leaf", Enum.PartType.Wedge, Vector3.new(size * 0.12, size * 0.4, size * 0.2), Color3.fromRGB(60, 180, 80))
			leaf.CFrame = top * CFrame.new((i - 2) * size * 0.14, size * 0.14, 0) * CFrame.Angles(0, 0, (i - 2) * -0.4)
			weldIt(leaf)
		end
	elseif def.id == "bloop" then
		-- A bow tie at the neck.
		for _, side in ipairs({ -1, 1 }) do
			local wing = makePart("BowTie", Enum.PartType.Wedge, Vector3.new(size * 0.08, size * 0.18, size * 0.2), Color3.fromRGB(160, 20, 60))
			wing.CFrame = body.CFrame * CFrame.new(side * size * 0.14, -size * 0.28, body.Size.Z / 2 + size * 0.02) * CFrame.Angles(0, math.rad(180), 0)
			weldIt(wing)
		end
		local knot = makePart("BowKnot", Enum.PartType.Ball, Vector3.new(size * 0.1, size * 0.1, size * 0.1), Color3.fromRGB(160, 20, 60))
		knot.CFrame = body.CFrame * CFrame.new(0, -size * 0.28, body.Size.Z / 2 + size * 0.04)
		weldIt(knot)
	elseif def.id == "couch" then
		-- A TV remote held at the side.
		local remote = makePart("Remote", Enum.PartType.Block, Vector3.new(size * 0.22, size * 0.42, size * 0.1), Color3.fromRGB(35, 35, 45))
		remote.CFrame = body.CFrame * CFrame.new(body.Size.X / 2 + size * 0.14, -size * 0.1, size * 0.1)
		weldIt(remote)
		local btn = makePart("RemoteButton", Enum.PartType.Ball, Vector3.new(size * 0.07, size * 0.07, size * 0.07), Color3.fromRGB(255, 60, 60))
		btn.Material = Enum.Material.Neon
		btn.CFrame = body.CFrame * CFrame.new(body.Size.X / 2 + size * 0.14, size * 0.02, size * 0.16)
		weldIt(btn)
	elseif def.id == "gummy" then
		-- A wrapped candy on top.
		local candy = makePart("Candy", Enum.PartType.Ball, Vector3.new(size * 0.26, size * 0.26, size * 0.26), Color3.fromRGB(255, 120, 180))
		candy.CFrame = top * CFrame.new(0, size * 0.14, 0)
		weldIt(candy)
		for _, side in ipairs({ -1, 1 }) do
			local wrap = makePart("CandyWrap", Enum.PartType.Wedge, Vector3.new(size * 0.08, size * 0.16, size * 0.16), Color3.fromRGB(255, 120, 180))
			wrap.CFrame = top * CFrame.new(side * size * 0.2, size * 0.14, 0) * CFrame.Angles(0, 0, side * 0.6)
			weldIt(wrap)
		end
	end
end

local function addAccessory(model: Model, body: Part, def: RotlingCatalog.RotlingDef, rarityColor: Color3)
	-- Noodle, Crumb and Toaster get a name-specific prop instead of the
	-- generic one (see addNameProp): a chef hat, a captain's hat and a
	-- slice of toast read as those names far better than a bowler or an
	-- antenna.
	if def.id == "noodle" or def.id == "crumb" or def.id == "toaster" then
		return
	end
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
	billboard.Size = UDim2.fromOffset(200, 84)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, def.size * 0.85, 0)
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
	-- One shared money format (Formatting.formatMoney already carries
	-- the "$"): never prepend another "$" here or the sign reads "$$".
	cpsLabel.Text = Formatting.formatMoney(cps) .. "/s"
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

	-- Saturate the colours so they read vivid from the path, not pale.
	local bodyColor = saturate(def.bodyColor, 1.35)
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
	local belly = makePart("Belly", Enum.PartType.Ball, Vector3.new(size * 0.5, size * 0.45, size * 0.2), saturate(def.bellyColor, 1.2))
	belly.CFrame = body.CFrame * CFrame.new(0, -size * 0.12, bodySize.Z / 2)
	belly.Parent = model
	local bellyWeld = Instance.new("WeldConstraint")
	bellyWeld.Part0 = body
	bellyWeld.Part1 = belly
	bellyWeld.Parent = belly

	addEyes(model, body, size)
	addMouth(model, body, size)
	addFeet(model, body, size)
	addArms(model, body, size)
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
