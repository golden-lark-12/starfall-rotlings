--!strict
-- Starfall Rotlings: meteor eggs.
-- During each storm, 1-2 glowing meteor eggs crash somewhere on the
-- map. Heavy — walk slower carrying one (BoostService applies the
-- slow); rivals chase you for it (RivalService.notifyEggCarrier). Bring
-- it to the incubator on your base and it hatches after 60s into a
-- random Rotling, with a chance of Epic, Legendary or a mutation
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
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 60)
	light.Brightness = 3
	light.Range = 20
	light.Parent = shell
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EggLabel"
	billboard.Size = UDim2.fromOffset(160, 40)
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
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
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
		local model = buildEgg(target)
		State.eggs[model] = {
			model = model,
			phase = "falling",
			carrier = nil,
			baseId = nil,
			hatchAt = nil,
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
		return
	end
	if State.eggCarriedByUser[player.UserId] then
		Remotes.bannerEvent():FireClient(player, "You can only carry one meteor egg!", 3)
		return
	end
	egg.phase = "carried"
	egg.carrier = player.UserId
	State.eggCarriedByUser[player.UserId] = model
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local shell = model.PrimaryPart
	if not root or not shell then
		return
	end
	shell.Anchored = false
	local weld = Instance.new("Weld")
	weld.Name = "EggWeld"
	weld.Part0 = root
	weld.Part1 = shell
	weld.C0 = CFrame.new(0, Config.CARRY_Y, Config.CARRY_Z)
	weld.Parent = shell
	BoostService.applyWalkSpeed(player)
	Remotes.bannerEvent():FireClient(player, "🥚 Heavy! Carry it to the incubator on your base — rivals will chase you!", 4)
	local RivalService = require(script.Parent.RivalService)
	RivalService.notifyEggCarrier(player)
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
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local pos = if root then root.Position + Vector3.new(0, 0, 3) else Vector3.new(0, 0, 0)
		model:PivotTo(CFrame.new(pos + Vector3.new(0, 2.2, 0)))
	end
	BoostService.applyWalkSpeed(player)
end

-- Place a carried egg on your base's incubator: it hatches after 60s.
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
	if egg then
		egg.phase = "incubating"
		egg.carrier = nil
		egg.baseId = baseId
		egg.hatchAt = time() + Config.EGG_HATCH_TIME
	end
	BoostService.applyWalkSpeed(player)
	Remotes.bannerEvent():FireClient(player, "🥚 Egg on the incubator — hatches in 60s!", 4)
end

-- Roll the hatch: a random Rotling, with a real chance of Epic or
-- Legendary, and 15% Meteor-scorched. Common/Rare rolls get one bump
-- chance toward Epic/Legendary so an egg never feels wasted.
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

local function hatchEgg(model: Model)
	local egg = State.eggs[model]
	if not egg then
		return
	end
	local baseId = egg.baseId
	State.eggs[model] = nil
	model:Destroy()
	if not baseId then
		return
	end
	local def, mutation = rollHatchDef()
	local ownerId = BaseService.getBaseOwner(baseId)
	local owner = if ownerId then Players:GetPlayerByUserId(ownerId) else nil
	-- Hatch onto a free pad of that base, or back into the crater.
	local padIndex = BaseService.freePad(baseId)
	local hatched: Model? = nil
	if padIndex and owner then
		local padCf = WorldBuilder.padCFrame(baseId, padIndex)
		if padCf then
			hatched = RotlingFactory.build(def.id, mutation, padCf.Position, 1)
			if hatched then
				hatched.Parent = workspace
				CarryService.placeOnPad(owner, hatched, baseId, padIndex)
				RotlingFactory.placePop(hatched)
			end
		end
	end
	if not hatched then
		-- Base full (or the owner left): the hatchling wanders into
		-- the crater instead, free to catch.
		local position = Vector3.new((math.random() * 2 - 1) * 15, Config.CRATER_FLOOR_Y, (math.random() * 2 - 1) * 2)
		hatched = RotlingFactory.build(def.id, mutation, position, 1.5)
		if hatched then
			hatched.Parent = workspace
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
		Remotes.bannerEvent():FireClient(owner, "🥚 HATCHED: " .. def.name .. " (" .. def.rarity .. mutText .. ")! +" .. tostring(Config.EGG_STARDUST) .. " Stardust!", 6)
		FeedbackService.celebrate(owner)
		if RarityConfig.rarityTier(def.rarity) >= 4 then
			Remotes.rarityPopupEvent():FireClient(owner, def.name, def.rarity, mutation, RotlingCatalog.baseCps(def, mutation))
		end
		print("[MeteorEgg] hatched " .. def.name .. " (" .. def.rarity .. (if mutation then " " .. mutation else "") .. ") on base " .. tostring(baseId))
	end
end

-- Hatch loop: eggs on incubators pop after 60s.
function MeteorEggService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for model, egg in pairs(State.eggs) do
				if egg.phase == "incubating" and egg.hatchAt and time() >= egg.hatchAt then
					hatchEgg(model)
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
end

return MeteorEggService
