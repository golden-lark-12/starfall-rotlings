--!strict
-- Starfall Rotlings: boosts.
-- Pickups that spawn around the map and in the Star Shop: Speed Coil
-- (+40% speed, 30s), Magnet (auto-grab the nearest Rotling within 15
-- studs, 30s), 2x Cash (double income, 60s), Shield (immune to slaps
-- and meteors, 20s). Active boosts show in the HUD as icons with
-- timers (IncomeService broadcasts them). Boosts are also sold in the
-- Star Shop for Stardust (BuyBoost remote).
--
-- WalkSpeed is owned here: base (16 + 2 per Speed tier) x Speed Coil
-- (1.4x) - egg slow (6 while carrying a meteor egg). SprintController
-- reads the same numbers from the HUD feed, so sprinting stacks on
-- top of a coil instead of wiping it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local FeedbackService = require(script.Parent.FeedbackService)
local State = require(script.Parent.State)

local BoostService = {}

BoostService.BOOSTS = {
	speed = { label = "Speed Coil", emoji = "🌀", desc = "+40% speed for 30s", duration = Config.BOOST_SPEED_DURATION },
	magnet = { label = "Magnet", emoji = "🧲", desc = "Auto-grab Brainrots within 15 studs for 30s", duration = Config.BOOST_MAGNET_DURATION },
	cash = { label = "2x Cash", emoji = "💰", desc = "Double income for 60s", duration = Config.BOOST_CASH_DURATION },
	shield = { label = "Shield", emoji = "🛡️", desc = "Immune to slaps and meteors for 20s", duration = Config.BOOST_SHIELD_DURATION },
} :: { [string]: { label: string, emoji: string, desc: string, duration: number } }

local BOOST_COLORS = {
	speed = Color3.fromRGB(120, 200, 255),
	magnet = Color3.fromRGB(255, 80, 80),
	cash = Color3.fromRGB(255, 215, 0),
	shield = Color3.fromRGB(120, 255, 170),
}

local running = false
local pickups: { Model } = {}

function BoostService.hasBoost(player: Player, kind: string): boolean
	local boosts = State.boosts[player.UserId]
	if not boosts then
		return false
	end
	local boost = boosts[kind]
	return boost ~= nil and time() < boost.expiresAt
end

-- Recompute a player's WalkSpeed from every modifier: shop Speed tier,
-- Speed Coil, and the meteor-egg slow. Called after any of those change.
function BoostService.applyWalkSpeed(player: Player)
	local profile = DataService.getProfile(player)
	local tier = if profile then profile.speedTier else 0
	local speed = Config.BASE_WALKSPEED + Config.SPEED_PER_TIER * tier
	if BoostService.hasBoost(player, "speed") then
		speed *= Config.BOOST_SPEED_MULT
	end
	if State.eggCarriedByUser[player.UserId] then
		speed = math.max(8, speed - Config.EGG_SLOW)
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

function BoostService.grantBoost(player: Player, kind: string)
	local info = BoostService.BOOSTS[kind]
	if not info then
		return
	end
	if not State.boosts[player.UserId] then
		State.boosts[player.UserId] = {}
	end
	State.boosts[player.UserId][kind] = { kind = kind, expiresAt = time() + info.duration }
	BoostService.applyWalkSpeed(player)
	FeedbackService.celebrate(player)
	Remotes.bannerEvent():FireClient(player, info.emoji .. " " .. info.label .. "! " .. info.desc, 4)
	-- Expiry: re-apply the walk speed when the boost runs out.
	task.delay(info.duration + 0.1, function()
		if player.Parent then
			BoostService.applyWalkSpeed(player)
		end
	end)
end

-- Buy a boost from the Star Shop for Stardust. Returns (ok, message).
function BoostService.buyBoost(player: Player, kind: string): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	local info = BoostService.BOOSTS[kind]
	if not info then
		return false, "No such boost."
	end
	if profile.stardust < Config.BOOST_STARDUST_COST then
		return false, info.label .. " costs " .. tostring(Config.BOOST_STARDUST_COST) .. " Stardust — earn more from meteor eggs and daily rewards."
	end
	profile.stardust -= Config.BOOST_STARDUST_COST
	BoostService.grantBoost(player, kind)
	DataService.saveProfile(player)
	return true, info.emoji .. " " .. info.label .. " active for " .. tostring(info.duration) .. "s!"
end

-- One boost pickup on the ground: a glowing orb with a label and a
-- grab prompt. Touching the prompt grants the boost and eats the orb.
local function buildPickup(kind: string, position: Vector3): Model
	local info = BoostService.BOOSTS[kind]
	local model = Instance.new("Model")
	model.Name = "BoostPickup"
	local orb = Instance.new("Part")
	orb.Name = "Orb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(2.4, 2.4, 2.4)
	orb.Color = BOOST_COLORS[kind] or Color3.fromRGB(255, 255, 255)
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0))
	orb.Parent = model
	model.PrimaryPart = orb
	local light = Instance.new("PointLight")
	light.Color = BOOST_COLORS[kind] or Color3.fromRGB(255, 255, 255)
	light.Brightness = 1.5
	light.Range = 12
	light.Parent = orb
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BoostLabel"
	billboard.Size = UDim2.fromOffset(140, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 40
	billboard.Parent = orb
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = (info and info.emoji or "⭐") .. " " .. (info and info.label or kind)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab " .. (info and info.label or kind)
	prompt.ObjectText = "Boost"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = orb
	prompt.Triggered:Connect(function(player: Player)
		if model.Parent then
			BoostService.grantBoost(player, kind)
			BoostService.removePickup(model)
		end
	end)
	model.Parent = workspace
	table.insert(pickups, model)
	-- A pickup that nobody takes fades after 90s.
	task.delay(90, function()
		BoostService.removePickup(model)
	end)
	return model
end

function BoostService.removePickup(model: Model)
	local index = table.find(pickups, model)
	if index then
		table.remove(pickups, index)
	end
	model:Destroy()
end

-- Minimum horizontal gap between two live pickups, so their orbs
-- and AlwaysOnTop labels never pile on top of each other: two
-- pickups in the Star Shop used to spawn within a stud and their
-- "Speed Coil" / "Shield" labels read as one jumbled line on the
-- shop disc (with their light pools painting a blue oval and a
-- green panel across it). 12 studs keeps the labels apart at any
-- camera angle; the shop is only 12x8, so at most one pickup sits
-- in the shop at a time and the rest spread over the field.
local MIN_PICKUP_SPACING = 12

local function isNearPickup(position: Vector3): boolean
	for _, pickup in ipairs(pickups) do
		local orb = pickup.PrimaryPart
		if orb then
			local dx = orb.Position.X - position.X
			local dz = orb.Position.Z - position.Z
			if dx * dx + dz * dz < MIN_PICKUP_SPACING * MIN_PICKUP_SPACING then
				return true
			end
		end
	end
	return false
end

local function randomPickupPositionOnce(): Vector3
	-- Anywhere on the open field, or inside the Star Shop.
	if math.random() < 0.25 then
		local WorldBuilder = require(script.Parent.WorldBuilder)
		local shop = WorldBuilder.shopCenter()
		return shop + Vector3.new((math.random() * 2 - 1) * 6, 0, (math.random() * 2 - 1) * 4)
	end
	local angle = math.random() * math.pi * 2
	local radius = math.random(45, 140)
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function randomPickupPosition(): Vector3
	local candidate = randomPickupPositionOnce()
	for _ = 1, 8 do
		if not isNearPickup(candidate) then
			return candidate
		end
		candidate = randomPickupPositionOnce()
	end
	return candidate
end

-- Magnet: while the boost is live, auto-grab the nearest free Rotling
-- within 15 studs whenever the player's arms are free.
local function magnetLoop(player: Player)
	local CarryService = require(script.Parent.CarryService)
	while player.Parent and BoostService.hasBoost(player, "magnet") do
		task.wait(0.5)
		if #CarryService.getCarried(player) >= CarryService.getCarrySlots(player) then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		local best: Model? = nil
		local bestDist = Config.BOOST_MAGNET_RADIUS
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("Model") and descendant:GetAttribute("State") == "free" then
				local body = descendant.PrimaryPart
				if body then
					local dist = (body.Position - root.Position).Magnitude
					if dist < bestDist then
						bestDist = dist
						best = descendant
					end
				end
			end
		end
		if best then
			CarryService.tryGrab(player, best)
		end
	end
end

function BoostService.start()
	if running then
		return
	end
	running = true
	-- Seed a few pickups at server start.
	for _ = 1, 3 do
		local kinds = { "speed", "magnet", "cash", "shield" }
		buildPickup(kinds[math.random(1, #kinds)], randomPickupPosition())
	end
	task.spawn(function()
		while true do
			task.wait(Config.BOOST_SPAWN_INTERVAL)
			if #pickups < Config.BOOST_MAX_ON_MAP then
				local kinds = { "speed", "magnet", "cash", "shield" }
				buildPickup(kinds[math.random(1, #kinds)], randomPickupPosition())
			end
		end
	end)
	-- Magnet loops, one per player, started on demand.
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(function()
			while player.Parent do
				task.wait(1)
				if BoostService.hasBoost(player, "magnet") then
					magnetLoop(player)
				end
			end
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			while player.Parent do
				task.wait(1)
				if BoostService.hasBoost(player, "magnet") then
					magnetLoop(player)
				end
			end
		end)
	end
end

function BoostService.init()
	Remotes.buyBoostFunction().OnServerInvoke = function(player: Player, kind: string)
		local ok, message = BoostService.buyBoost(player, kind)
		return ok, message
	end
end

return BoostService
