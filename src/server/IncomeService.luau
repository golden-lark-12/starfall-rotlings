--!strict
-- Starfall Rotlings: coins per second and the HUD feed.
-- The server owns every number. Once a second it pays every placed
-- Rotling's income, floats one "+$N" above a random earner, and sends
-- every player their HUD numbers. The client only ever shows what this
-- module sends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local StarfallService = require(script.Parent.StarfallService)
local State = require(script.Parent.State)

local IncomeService = {}

-- Player income multiplier: rebirths and shop income tiers stack.
function IncomeService.incomeMult(player: Player): number
	local profile = DataService.getProfile(player)
	if not profile then
		return 1
	end
	return (1 + Config.REBIRTH_MULT_PER * profile.rebirths)
		* (1 + Config.INCOME_TIER_MULT * profile.incomeTier)
end

-- Coins per second from one player's placed Rotlings, after multipliers.
function IncomeService.coinsPerSecond(player: Player): number
	local total = 0
	for _, model in ipairs(BaseService.getPlacedForPlayer(player)) do
		local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
		if def then
			total += RotlingCatalog.baseCps(def, model:GetAttribute("Mutation") :: string?)
		end
	end
	return math.floor(total * IncomeService.incomeMult(player))
end

-- Send every player their current HUD numbers.
-- Each player's send is protected: one bad profile or a dropped
-- connection must never take the whole feed down with it.
function IncomeService.broadcastHud()
	local storm = StarfallService.getStatus()
	for _, player in ipairs(Players:GetPlayers()) do
		local ok, err = pcall(function()
			local profile = DataService.getProfile(player)
			if profile then
				local baseId = BaseService.getPlayerBase(player.UserId)
				local found = 0
				for _ in pairs(profile.index) do
					found += 1
				end
				Remotes.hudEvent():FireClient(player, {
					coins = profile.coins,
					cps = IncomeService.coinsPerSecond(player),
					rebirths = profile.rebirths,
					speedTier = profile.speedTier,
					carryTier = profile.carryTier,
					incomeTier = profile.incomeTier,
					padsTier = profile.padsTier,
					lockTier = profile.lockTier,
					carried = #CarryService.getCarried(player),
					carrySlots = CarryService.getCarrySlots(player),
					lockRemaining = if baseId then BaseService.lockRemaining(baseId) else 0,
					lockCooldown = if baseId then BaseService.lockCooldownRemaining(baseId) else 0,
					stormPhase = storm.phase,
					stormSeconds = storm.secondsLeft,
					index = profile.index,
					firstTime = profile.coins == 0 and profile.rebirths == 0 and found == 0,
				})
			end
		end)
		if not ok then
			warn("Starfall broadcastHud failed for " .. player.Name .. ": " .. tostring(err))
		end
	end
end

-- Float one "+$N" above a random placed Rotling, rising and fading.
local function floatIncomeNumber()
	local allPlaced: { Model } = {}
	for _, byPad in pairs(State.placed) do
		for _, model in pairs(byPad) do
			table.insert(allPlaced, model)
		end
	end
	if #allPlaced == 0 then
		return
	end
	local model = allPlaced[math.random(1, #allPlaced)]
	local body = model.PrimaryPart
	if not body then
		return
	end
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	if not def then
		return
	end
	local ownerId = model:GetAttribute("OwnerUserId") :: number
	local owner = Players:GetPlayerByUserId(ownerId)
	local amount = 0
	if owner then
		amount = math.floor(RotlingCatalog.baseCps(def, model:GetAttribute("Mutation") :: string?) * IncomeService.incomeMult(owner))
	end
	if amount <= 0 then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "IncomeFloat"
	billboard.Size = UDim2.fromOffset(120, 36)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, def.size + 1, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "+" .. Formatting.formatMoney(amount)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 90)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	local tween = TweenService:Create(billboard, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, def.size + 4, 0),
	})
	tween:Play()
	local fade = TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	fade:Play()
	task.delay(1.3, function()
		billboard:Destroy()
	end)
end

-- Start the coin tick and the autosave loop.
-- The tick is wrapped so one bad player or value can never kill the
-- loop: a dead loop means the HUD (and the storm timer) freeze for
-- everyone, with nothing in the Output to explain it.
function IncomeService.start()
	local tickCount = 0
	task.spawn(function()
		while true do
			task.wait(Config.TICK_INTERVAL)
			tickCount += 1
			local ok, err = pcall(function()
				for _, player in ipairs(Players:GetPlayers()) do
					local profile = DataService.getProfile(player)
					if profile then
						profile.coins += IncomeService.coinsPerSecond(player)
						local LeaderstatsService = require(script.Parent.LeaderstatsService)
						LeaderstatsService.refresh(player)
					end
				end
				floatIncomeNumber()
				IncomeService.broadcastHud()
			end)
			if not ok then
				warn("Starfall income tick failed: " .. tostring(err))
			end
			-- Storm heartbeat (every 5 ticks): proves the loop is alive
			-- and shows the phase + seconds the HUD should be displaying.
			if tickCount % 5 == 0 then
				local status = StarfallService.getStatus()
				local playerCount = #Players:GetPlayers()
				print("[Starfall] tick " .. tostring(tickCount) .. ": storm phase=" .. tostring(status.phase) .. " secondsLeft=" .. tostring(math.ceil(status.secondsLeft)) .. " players=" .. tostring(playerCount))
			end
		end
	end)

	-- Autosave, staggered by join order so servers do not spike together.
	task.spawn(function()
		while true do
			task.wait(Config.SAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.saveProfile(player)
				task.wait(1)
			end
		end
	end)
end

return IncomeService
