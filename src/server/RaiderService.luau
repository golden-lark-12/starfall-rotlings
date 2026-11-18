--!strict
-- Starfall Rotlings: Rot Raiders.
-- NPC thieves that raid bases on a timer, so even a solo server feels
-- the steal threat. A raider walks to a base with Rotlings on its pads,
-- grabs one and runs for the crater edge. Touch it (or press its Bonk
-- prompt) and it drops the loot and flees. If it reaches the edge, the
-- Rotling is gone for good.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local RaiderService = {}

-- Our own bandit titles, one per raider — invented here, none of them
-- a real meme name and none borrowed from any other entry.
local RAIDER_TITLES = {
	"Grimble the Grabber",
	"Snatch",
	"Lootfang",
	"Nabbit",
	"Pilfer Pete",
	"Slink the Sneak",
}

local running = false

local function makePart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	return part
end

-- Build a raider: a dark hooded figure with red glowing eyes and a sack.
-- Each one gets its own bandit title, shown under the THIEF sign.
local function buildRaider(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Rot Raider"
	local raiderTitle = RAIDER_TITLES[math.random(1, #RAIDER_TITLES)]
	model:SetAttribute("RaiderName", raiderTitle)

	local body = makePart("Body", Enum.PartType.Block, Vector3.new(3, 3.6, 2.2), Color3.fromRGB(45, 30, 70))
	body.CFrame = CFrame.new(position + Vector3.new(0, 2.4, 0))
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model
	model.PrimaryPart = body

	-- Hood: a wedge over the head.
	local hood = makePart("Hood", Enum.PartType.Wedge, Vector3.new(3.2, 2.2, 2.4), Color3.fromRGB(30, 20, 50))
	hood.CFrame = body.CFrame * CFrame.new(0, 2.2, 0)
	hood.Parent = model
	local hoodWeld = Instance.new("WeldConstraint")
	hoodWeld.Part0 = body
	hoodWeld.Part1 = hood
	hoodWeld.Parent = hood

	-- Red glowing eyes.
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Eye", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		eye.CFrame = body.CFrame * CFrame.new(side * 0.6, 0.7, 1.1)
		eye.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	-- Loot sack on its back.
	local sack = makePart("Sack", Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8), Color3.fromRGB(120, 85, 40))
	sack.CFrame = body.CFrame * CFrame.new(0, 0.4, -1.6)
	sack.Parent = model
	local sackWeld = Instance.new("WeldConstraint")
	sackWeld.Part0 = body
	sackWeld.Part1 = sack
	sackWeld.Parent = sack

	-- Feet.
	for _, side in ipairs({ -1, 1 }) do
		local foot = makePart("Foot", Enum.PartType.Block, Vector3.new(0.9, 0.4, 1.2), Color3.fromRGB(20, 15, 30))
		foot.CFrame = body.CFrame * CFrame.new(side * 0.8, -1.9, 0.2)
		foot.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = foot
		weld.Parent = foot
	end

	-- Red glow so it reads as a threat from across the map.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 50)
	light.Brightness = 1.5
	light.Range = 10
	light.Parent = body

	-- A red THIEF sign over its head, with the raider's own bandit
	-- title under it, so the steal is visible — and named — from
	-- across the map (item 7b).
	local thiefSign = Instance.new("BillboardGui")
	thiefSign.Name = "ThiefSign"
	thiefSign.Size = UDim2.fromOffset(200, 64)
	thiefSign.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	thiefSign.AlwaysOnTop = true
	thiefSign.LightInfluence = 0
	thiefSign.MaxDistance = 80
	thiefSign.Parent = body
	local thiefLabel = Instance.new("TextLabel")
	thiefLabel.Size = UDim2.new(1, 0, 1, 0)
	thiefLabel.BackgroundTransparency = 1
	thiefLabel.Text = "🚨 THIEF!\n" .. raiderTitle
	thiefLabel.Font = Enum.Font.FredokaOne
	thiefLabel.TextScaled = true
	thiefLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
	thiefLabel.TextStrokeTransparency = 0.2
	thiefLabel.Parent = thiefSign

	-- A humanoid so it can walk with MoveTo.
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = Config.RAIDER_WALK_SPEED
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

	-- "Bonk the Raider!" prompt: the reliable way to hit it.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Bonk the Raider!"
	prompt.ObjectText = "Save your Brainrot"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	return model
end

-- The raider drops whatever it stole into the crater and runs away.
function RaiderService.bonkRaider(model: Model, byPlayer: Player?)
	local raider = State.raiders[model]
	if not raider then
		return
	end
	if raider.stolen then
		CarryService.scatterToCrater(raider.stolen)
		raider.stolen = nil
	end
	raider.phase = "flee"
	if byPlayer then
		Remotes.bannerEvent():FireClient(byPlayer, "Bonk! " .. raider.name .. " dropped your Brainrot!", 3)
	end
end

-- Walk a raider to a position, giving up after a timeout. If the
-- raider gets stuck (no progress for a while), it jumps: MoveTo never
-- jumps on its own, so a bot that walks into a step or a rim edge just
-- pushes against it until the timeout. The jump clears the 2-stud base
-- edge and the crater rim steps, so a stuck bot hops over the obstacle
-- instead of timing out and despawning.
-- shouldCancel (fix 4): a function that returns true when the walk
-- must stop early — a bonked raider (phase "flee") stops walking to
-- its target and runs away instead of standing still until the
-- timeout expires.
local function walkTo(model: Model, target: Vector3, timeout: number, shouldCancel: (() -> boolean)?): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return false
	end
	humanoid:MoveTo(target)
	local done = false
	local connection
	connection = humanoid.MoveToFinished:Connect(function(reached: boolean)
		done = reached
	end)
	local waited = 0
	local lastPos = root.Position
	local stuckTime = 0
	while not done and waited < timeout do
		task.wait(0.5)
		waited += 0.5
		if not model.Parent then
			break
		end
		if shouldCancel and shouldCancel() then
			break
		end
		if (root.Position - target).Magnitude < 4 then
			done = true
		end
		-- Stuck? Hop. A bot that has not moved in 1.5s is pushing
		-- against a step; a jump clears it.
		if (root.Position - lastPos).Magnitude < 0.5 then
			stuckTime += 0.5
			if stuckTime >= 1.5 then
				humanoid.Jump = true
				stuckTime = 0
			end
		else
			stuckTime = 0
		end
		lastPos = root.Position
	end
	if connection then
		connection:Disconnect()
	end
	return done
end

-- Flee visibly (fix 4): a bonked raider runs for the crater edge and
-- despawns, instead of standing still until its walk times out. The
-- player sees the bonk work — the thief drops the loot and runs.
local function fleeAndDespawn(model: Model)
	local raider = State.raiders[model]
	if not raider then
		return
	end
	local angle = math.random() * math.pi * 2
	local exit = Vector3.new(math.cos(angle) * (Config.CRATER_RADIUS + 30), 0, math.sin(angle) * (Config.CRATER_RADIUS + 30))
	walkTo(model, exit, 20)
	RaiderService.despawnRaider(model)
end

-- Storm cover (fix 2): when a storm is running, a raider runs for the
-- nearest base platform and waits there until the storm ends, then
-- resumes the raid. Returns true if it sheltered (the caller resumes
-- after the storm), false if there was no storm to shelter from.
local function shelterIfStorm(model: Model): boolean
	local StarfallService = require(script.Parent.StarfallService)
	if StarfallService.getStatus().phase ~= "storm" then
		return false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	-- Nearest base platform is cover.
	local WorldBuilder = require(script.Parent.WorldBuilder)
	local bestCf: CFrame? = nil
	local bestDist = math.huge
	for baseId = 1, Config.BASE_COUNT do
		local cf = WorldBuilder.baseCFrame(baseId)
		if cf then
			local dist = (root.Position - cf.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestCf = cf
			end
		end
	end
	if bestCf then
		walkTo(model, bestCf.Position, 30)
	end
	while StarfallService.getStatus().phase == "storm" do
		task.wait(1)
		if not model.Parent then
			return true
		end
	end
	return true
end

-- Run one raid: pick a base with Rotlings, grab one, run for the edge.
local function runRaid(model: Model)
	local raider = State.raiders[model]
	if not raider then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	-- A storm means cover first: shelter on the nearest base until
	-- it passes, then resume the raid.
	shelterIfStorm(model)
	if not model.Parent or State.raiders[model] == nil then
		return
	end
	-- Hunt: walk to the target pad.
	local padCf = nil
	local WorldBuilder = require(script.Parent.WorldBuilder)
	padCf = WorldBuilder.padCFrame(raider.targetBase, raider.targetPad)
	if not padCf then
		RaiderService.despawnRaider(model)
		return
	end
	-- Hunt: walk to the target pad. A bonk mid-hunt cancels the walk
	-- (the raider flees instead of standing still until the timeout).
	if not walkTo(model, padCf.Position, 40, function()
		return raider.phase == "flee"
	end) then
		if raider.phase == "flee" then
			fleeAndDespawn(model)
		else
			RaiderService.despawnRaider(model)
		end
		return
	end
	local stolen = BaseService.removePlaced(raider.targetBase, raider.targetPad)
	if not stolen then
		RaiderService.despawnRaider(model)
		return
	end
	raider.stolen = stolen
	raider.phase = "carry"
	local body = model.PrimaryPart
	local stolenBody = stolen.PrimaryPart
	if body and stolenBody then
		for _, part in ipairs(stolen:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
			end
		end
		local weld = Instance.new("Weld")
		weld.Name = "StolenWeld"
		weld.Part0 = body
		weld.Part1 = stolenBody
		weld.C0 = CFrame.new(0, 3.2, -1.5)
		weld.Parent = stolenBody
		stolen:SetAttribute("State", "carried")
	end
	local ownerId = BaseService.getBaseOwner(raider.targetBase)
	if ownerId then
		local owner = Players:GetPlayerByUserId(ownerId)
		if owner then
			local def = RotlingCatalog.getDef(stolen:GetAttribute("DefId") :: string)
			local name = if def then def.name else "a Brainrot"
			Remotes.bannerEvent():FireClient(owner, "🚨 THIEF AT YOUR BASE! " .. raider.name .. " is stealing your " .. name .. "! Bonk it!", 5)
		end
	end
	-- A storm mid-carry means cover first (it keeps the loot).
	shelterIfStorm(model)
	if not model.Parent or State.raiders[model] == nil then
		return
	end
	-- Carry: run for the crater edge. If it gets there, the loot is gone.
	-- A bonk mid-carry cancels the escape (the raider drops the loot
	-- and flees instead of standing still until the timeout).
	local angle = math.random() * math.pi * 2
	local exit = Vector3.new(math.cos(angle) * (Config.CRATER_RADIUS + 30), 0, math.sin(angle) * (Config.CRATER_RADIUS + 30))
	walkTo(model, exit, 40, function()
		return raider.phase == "flee"
	end)
	if not model.Parent or State.raiders[model] == nil then
		return
	end
	if raider.phase == "flee" then
		-- Bonked: the loot was already scattered by bonkRaider, so
		-- the thief just runs.
		fleeAndDespawn(model)
		return
	end
	if raider.phase == "carry" and raider.stolen then
		-- It escaped with the Rotling.
		raider.stolen:Destroy()
		raider.stolen = nil
		if ownerId then
			local owner = Players:GetPlayerByUserId(ownerId)
			if owner then
				Remotes.bannerEvent():FireClient(owner, raider.name .. " escaped with your Brainrot!", 4)
			end
		end
	end
	RaiderService.despawnRaider(model)
end

-- Crater raid (THE CHASE): a raider snatches a FREE Brainrot off the
-- belt and runs for the edge, so the guardian chases it and players
-- can bonk it to steal the Brainrot back. Same steal-and-run as a base
-- raid, but the loot comes from the crater, not a pad.
local function runCraterRaid(model: Model)
	local raider = State.raiders[model]
	if not raider then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local target = raider.targetFree
	if not target or not target.Parent or target:GetAttribute("State") ~= "free" then
		RaiderService.despawnRaider(model)
		return
	end
	-- A storm means cover first: shelter on the nearest base until
	-- it passes, then resume the raid.
	shelterIfStorm(model)
	if not model.Parent or State.raiders[model] == nil then
		return
	end
	-- Hunt: walk to the free Brainrot on the belt.
	local body = target.PrimaryPart
	if not body then
		RaiderService.despawnRaider(model)
		return
	end
	if not walkTo(model, body.Position, 40, function()
		return raider.phase == "flee"
	end) then
		if raider.phase == "flee" then
			fleeAndDespawn(model)
		else
			RaiderService.despawnRaider(model)
		end
		return
	end
	-- Grab it: stop the idle bob, weld it to the raider, mark carried.
	local stolen = target
	if not stolen.Parent or stolen:GetAttribute("State") ~= "free" then
		RaiderService.despawnRaider(model)
		return
	end
	local SpawnService = require(script.Parent.SpawnService)
	SpawnService.unregister(stolen)
	raider.stolen = stolen
	raider.phase = "carry"
	local raiderBody = model.PrimaryPart
	local stolenBody = stolen.PrimaryPart
	if raiderBody and stolenBody then
		for _, part in ipairs(stolen:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
			end
		end
		local weld = Instance.new("Weld")
		weld.Name = "StolenWeld"
		weld.Part0 = raiderBody
		weld.Part1 = stolenBody
		weld.C0 = CFrame.new(0, 3.2, -1.5)
		weld.Parent = stolenBody
		stolen:SetAttribute("State", "carried")
	end
	-- The guardian wakes: it chases whoever grabs from the crater,
	-- raider included. Everyone sees the chase start.
	local def = RotlingCatalog.getDef(stolen:GetAttribute("DefId") :: string)
	local name = if def then def.name else "a Brainrot"
	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.bannerEvent():FireClient(player, "🚨 " .. raider.name .. " snatched " .. name .. " from the crater! The Guardian is after it — bonk the raider to steal it back!", 5)
	end
	local GuardianService = require(script.Parent.GuardianService)
	GuardianService.onRaiderGrab(model, stolen)
	-- A storm mid-carry means cover first (it keeps the loot).
	shelterIfStorm(model)
	if not model.Parent or State.raiders[model] == nil then
		return
	end
	-- Carry: run for the crater edge. If it gets there, the loot is gone.
	local angle = math.random() * math.pi * 2
	local exit = Vector3.new(math.cos(angle) * (Config.CRATER_RADIUS + 30), 0, math.sin(angle) * (Config.CRATER_RADIUS + 30))
	walkTo(model, exit, 40, function()
		return raider.phase == "flee"
	end)
	if not model.Parent or State.raiders[model] == nil then
		return
	end
	if raider.phase == "flee" then
		fleeAndDespawn(model)
		return
	end
	if raider.phase == "carry" and raider.stolen then
		raider.stolen:Destroy()
		raider.stolen = nil
		for _, player in ipairs(Players:GetPlayers()) do
			Remotes.bannerEvent():FireClient(player, raider.name .. " escaped with " .. name .. "!", 4)
		end
	end
	RaiderService.despawnRaider(model)
end

-- Spawn a crater raider: it targets a free Brainrot on the belt.
-- Spawns at the crater entrance gap (+Z side) so it walks straight in
-- through the gap instead of climbing the rim wall.
function RaiderService.spawnCraterRaider(): Model?
	local free: { Model } = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:GetAttribute("State") == "free" then
			table.insert(free, descendant)
		end
	end
	if #free == 0 then
		return nil
	end
	local target = free[math.random(1, #free)]
	-- Entrance gap side (+Z): walk straight in, no rim climb.
	local spawnPos = Vector3.new(0, 8, 45)
	local model = buildRaider(spawnPos)
	model.Parent = workspace
	State.raiders[model] = {
		model = model,
		name = model:GetAttribute("RaiderName") :: string,
		phase = "hunt",
		targetBase = 0,
		targetPad = 0,
		targetFree = target,
		stolen = nil,
		bornAt = time(),
	}
	-- Touching it bonks it (same as a base raider).
	local body = model.PrimaryPart
	if body then
		local lastBonk = 0
		body.Touched:Connect(function(hit: BasePart)
			if time() - lastBonk < 1 then
				return
			end
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then
				lastBonk = time()
				RaiderService.bonkRaider(model, player)
			end
		end)
		local prompt = body:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				RaiderService.bonkRaider(model, player)
			end)
		end
	end
	task.spawn(runCraterRaid, model)
	task.delay(Config.RAIDER_LIFETIME, function()
		if State.raiders[model] ~= nil then
			RaiderService.despawnRaider(model)
		end
	end)
	return model
end

-- Spawn one raider at the crater edge, targeting a random stocked base.
-- Fix 4: prefer a REAL player's base over a rival's — the one clear
-- rival behaviour is a raider coming for YOUR Rotlings, not a bot
-- raiding another bot where the player never sees it. Only when no
-- real player's base is stocked does it fall back to any stocked base.
function RaiderService.spawnRaider(): Model?
	local playerBases: { number } = {}
	local anyBases: { number } = {}
	for baseId = 1, Config.BASE_COUNT do
		local ownerId = BaseService.getBaseOwner(baseId)
		if ownerId and not BaseService.isLocked(baseId) then
			local placed = State.placed[baseId]
			if placed then
				for _ in pairs(placed) do
					table.insert(anyBases, baseId)
					-- A real player owns this base (rival bases have
					-- a negative owner id, reserved at server start).
					if ownerId > 0 then
						table.insert(playerBases, baseId)
					end
					break
				end
			end
		end
	end
	local candidates = if #playerBases > 0 then playerBases else anyBases
	if #candidates == 0 then
		return nil
	end
	local baseId = candidates[math.random(1, #candidates)]
	local placed = State.placed[baseId]
	if not placed then
		return nil
	end
	local pads: { number } = {}
	for padIndex in pairs(placed) do
		table.insert(pads, padIndex)
	end
	local padIndex = pads[math.random(1, #pads)]
	-- Spawn on the TARGET base's side (fix round 2, fix 4): the old
	-- spawn used a random angle, so half the time the raider's
	-- straight-line path to the base crossed the crater — it hit the
	-- rim wall, stuck-jumped forever, and despawned without ever
	-- arriving, so raiders read as "doing nothing". Now the raider
	-- spawns at the target base's angle (± a spread) at radius 45,
	-- outside the rim, and walks straight outward to the base without
	-- crossing the crater.
	local baseCf = WorldBuilder.baseCFrame(baseId)
	local baseAngle = if baseCf then math.atan2(baseCf.Position.Z, baseCf.Position.X) else math.random() * math.pi * 2
	local angle = baseAngle + (math.random() * 2 - 1) * 0.5
	-- Spawn outside the crater rim, above the ground (fix 2): the old
	-- spawn at radius CRATER_RADIUS + 6 (34) and Y=0 sat INSIDE the
	-- rim mound (the radius-35 rim step tops at Y=4), so the raider
	-- spawned buried in solid geometry and never moved. Radius 45 is
	-- open ground past the rim (39); Y=8 lets it fall to the surface.
	local spawnPos = Vector3.new(math.cos(angle) * 45, 8, math.sin(angle) * 45)
	local model = buildRaider(spawnPos)
	model.Parent = workspace
	State.raiders[model] = {
		model = model,
		name = model:GetAttribute("RaiderName") :: string,
		phase = "hunt",
		targetBase = baseId,
		targetPad = padIndex,
		stolen = nil,
		bornAt = time(),
	}
	-- Telegraph the raid (fix 4): the owner is warned the moment the
	-- raider spawns, not only after it grabs — so the steal is a
	-- threat the player can see coming and stop in time.
	local ownerId = BaseService.getBaseOwner(baseId)
	if ownerId and ownerId > 0 then
		local owner = Players:GetPlayerByUserId(ownerId)
		if owner then
			Remotes.bannerEvent():FireClient(owner, "🚨 " .. (model:GetAttribute("RaiderName") :: string) .. " is sneaking toward your base! Guard your Brainrots — bonk it or slap it!", 5)
		end
	end
	-- Touching it bonks it (with a short debounce per raider).
	local body = model.PrimaryPart
	if body then
		local lastBonk = 0
		body.Touched:Connect(function(hit: BasePart)
			if time() - lastBonk < 1 then
				return
			end
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then
				lastBonk = time()
				RaiderService.bonkRaider(model, player)
			end
		end)
		local prompt = body:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				RaiderService.bonkRaider(model, player)
			end)
		end
	end
	task.spawn(runRaid, model)
	-- Lifetime: give up and leave if the raid drags on.
	task.delay(Config.RAIDER_LIFETIME, function()
		if State.raiders[model] ~= nil then
			RaiderService.despawnRaider(model)
		end
	end)
	return model
end

-- Spawn a raider mid-steal for the TOUR.json steal screenshot.
function RaiderService.spawnRaiderForTour(baseId: number, padIndex: number): Model?
	local placed = State.placed[baseId]
	if not placed or placed[padIndex] == nil then
		return nil
	end
	local WorldBuilder = require(script.Parent.WorldBuilder)
	local padCf = WorldBuilder.padCFrame(baseId, padIndex)
	if not padCf then
		return nil
	end
	local model = buildRaider(padCf.Position + Vector3.new(4, 0, 4))
	model.Parent = workspace
	State.raiders[model] = {
		model = model,
		name = model:GetAttribute("RaiderName") :: string,
		phase = "carry",
		targetBase = baseId,
		targetPad = padIndex,
		stolen = placed[padIndex],
		bornAt = time(),
	}
	return model
end

function RaiderService.despawnRaider(model: Model)
	local raider = State.raiders[model]
	if raider and raider.stolen and raider.stolen.Parent then
		CarryService.scatterToCrater(raider.stolen)
	end
	State.raiders[model] = nil
	model:Destroy()
end

-- Start the raid timer.
function RaiderService.start()
	if running then
		return
	end
	running = true
	task.spawn(function()
		task.wait(Config.RAIDER_FIRST)
		while true do
			-- Half the raids are crater grabs (THE CHASE): a raider
			-- snatches a free Brainrot off the belt and runs, so the
			-- guardian chases it and players can bonk it to steal it
			-- back. Only when free Brainrots exist; otherwise a base
			-- raid as before.
			local didCrater = false
			if math.random() < 0.5 then
				didCrater = RaiderService.spawnCraterRaider() ~= nil
			end
			if not didCrater then
				RaiderService.spawnRaider()
			end
			task.wait(Config.RAIDER_INTERVAL)
		end
	end)
end

return RaiderService
