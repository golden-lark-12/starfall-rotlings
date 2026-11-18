--!strict
-- Starfall Rotlings: the Crater Guardian (THE CHASE — the core of the game).
-- When anyone grabs a Brainrot from the crater, a space rock monster
-- (glowing red eyes) climbs out and chases them. Rarer Brainrot =
-- faster guardian: Common is slow, Legendary and up are nearly as fast
-- as the player. If it catches you, you are knocked down and drop the
-- Brainrot back. Reach your base or the Safe Dome and it gives up.
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

-- Is this position on the target player's own base (a safe zone)?
-- Reuses the storm safe radius: a base platform is never a chase zone.
local function onOwnBase(player: Player, position: Vector3): boolean
	local baseId = BaseService.getPlayerBase(player.UserId)
	if not baseId then
		return false
	end
	local cf = WorldBuilder.baseCFrame(baseId)
	if not cf then
		return false
	end
	local flat = Vector3.new(position.X - cf.Position.X, 0, position.Z - cf.Position.Z)
	return flat.Magnitude <= Config.STORM_BASE_SAFE_RADIUS
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

-- Build the guardian: a big dark space rock with glowing red eyes.
-- Built from parts only (no meshes, no uploads), like every Rotling.
local function buildGuardian(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Crater Guardian"

	-- The rock: big, dark, rough.
	local body = makePart("Body", Enum.PartType.Ball, Vector3.new(5.5, 5, 5.5), Color3.fromRGB(45, 38, 48), Enum.Material.Slate)
	body.CFrame = CFrame.new(position + Vector3.new(0, 3.2, 0))
	body.CanCollide = true
	body.Parent = model
	model.PrimaryPart = body

	-- Cracks: lighter rock slabs stuck on the front, so it reads as
	-- a boulder, not a smooth ball.
	for _, offset in ipairs({ Vector3.new(-1.6, 0.8, 2.2), Vector3.new(1.4, -0.9, 2.3), Vector3.new(0, 1.8, 2.1) }) do
		local slab = makePart("Crack", Enum.PartType.Block, Vector3.new(1.6, 1.2, 0.5), Color3.fromRGB(90, 80, 95), Enum.Material.Slate)
		slab.CFrame = body.CFrame * CFrame.new(offset)
		slab.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = slab
		weld.Parent = slab
	end

	-- Glowing red eyes: the whole point of the monster. Two Neon red
	-- orbs on the front, plus a red light so it glows in the dark.
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Eye", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
		eye.CFrame = body.CFrame * CFrame.new(side * 1.2, 0.7, 2.4)
		eye.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Brightness = 2
	light.Range = 12
	light.Parent = body

	-- A red tag so the chase reads from across the crater.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GuardianTag"
	billboard.Size = UDim2.fromOffset(220, 36)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
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
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = Config.GUARDIAN_SPEED[1]
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
	sound.PlaybackSpeed = 0.15
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
	print("[Guardian] despawn (" .. tostring(reason or "?") .. ")")
	model:Destroy()
end

-- The knockdown: the guardian caught a player. Fall down, drop
-- everything carried back into the crater, then the guardian leaves.
local function catchPlayer(guardian: Model, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		if root then
			root.AssemblyLinearVelocity = Vector3.new(0, 12, 0)
		end
		CarryService.dropAllCarried(player)
		Remotes.bannerEvent():FireClient(player, "🪨 THE GUARDIAN CAUGHT YOU! You dropped your Brainrot!", 4)
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

-- Chase loop: re-target the moving target every 0.4s, jump when stuck.
-- Ends on catch, on give-up (safe base / nothing carried / timeout),
-- or when the target is gone.
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
	local lastPos = root.Position
	local stuckTime = 0
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
		-- Caught?
		if (root.Position - targetRoot.Position).Magnitude <= Config.GUARDIAN_CATCH_RADIUS then
			if entry.targetPlayer then
				catchPlayer(guardian, entry.targetPlayer)
			else
				catchRaider(guardian, target)
			end
			return
		end
		humanoid:MoveTo(targetRoot.Position)
		task.wait(0.4)
		if not guardian.Parent then
			return
		end
		-- Stuck? Hop. Same fix as raiders: MoveTo never jumps alone.
		if (root.Position - lastPos).Magnitude < 0.5 then
			stuckTime += 0.4
			if stuckTime >= 1.2 then
				humanoid.Jump = true
				stuckTime = 0
			end
		else
			stuckTime = 0
		end
		lastPos = root.Position
		if time() - entry.bornAt > Config.GUARDIAN_GIVEUP_TIME then
			GuardianService.despawnGuardian(guardian, "timeout")
			return
		end
	end
end

-- Spawn a guardian at the crater floor and start the chase.
-- `rarity` is the grabbed Brainrot's rarity: it sets the speed.
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
	}
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
	local spawnPos = if root then root.Position else Vector3.new(0, Config.CRATER_FLOOR_Y, 0)
	-- The guardian climbs out of the crater floor near the grab.
	spawnPos = Vector3.new(spawnPos.X, Config.CRATER_FLOOR_Y, spawnPos.Z)
	spawnGuardian(character, player, rarity, spawnPos)
end

-- A raider grabbed a Brainrot from the crater: the guardian chases it.
function GuardianService.onRaiderGrab(raiderModel: Model, stolen: Model)
	local def = RotlingCatalog.getDef(stolen:GetAttribute("DefId") :: string)
	local rarity = if def then def.rarity else "Common"
	local root = raiderModel:FindFirstChild("HumanoidRootPart")
	local spawnPos = if root then root.Position else Vector3.new(0, Config.CRATER_FLOOR_Y, 0)
	spawnPos = Vector3.new(spawnPos.X, Config.CRATER_FLOOR_Y, spawnPos.Z)
	spawnGuardian(raiderModel, nil, rarity, spawnPos)
end

return GuardianService
