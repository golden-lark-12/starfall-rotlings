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
local BoostService = require(script.Parent.BoostService)
local BuddyService = require(script.Parent.BuddyService)
local CarryService = require(script.Parent.CarryService)
local DailyService = require(script.Parent.DailyService)
local DataService = require(script.Parent.DataService)
local MissionService = require(script.Parent.MissionService)
local StarfallService = require(script.Parent.StarfallService)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local IncomeService = {}

-- Safe Dome storm boost: a player standing on their OWN base platform
-- while the storm front passes earns double income. The dome is a
-- shelter that pays — the threat shot's income readout proves it.
-- Only the storm phase counts (not the warning), and only your own
-- base: a thief standing on someone else's base gets no boost.
function IncomeService.stormBoostActive(player: Player): boolean
	if StarfallService.getStatus().phase ~= "storm" then
		return false
	end
	local baseId = BaseService.getPlayerBase(player.UserId)
	if not baseId then
		return false
	end
	local cf = WorldBuilder.baseCFrame(baseId)
	if not cf then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	-- (fix round 9, item 4) the 2x storm income is for sheltering
	-- INSIDE the base — standing in the doorway does not count.
	return WorldBuilder.isOnBaseInterior(baseId, root.Position)
end

-- Player income multiplier: rebirths and shop income tiers stack, and
-- on top of those: a 2x Cash boost or global event, and the Buddy's +5%.
-- includeStormBoost (default true): pass false for the NORMAL rate —
-- the HUD shows it next to the boosted one during the storm.
function IncomeService.incomeMult(player: Player, includeStormBoost: boolean?): number
	local profile = DataService.getProfile(player)
	if not profile then
		return 1
	end
	local mult = (1 + Config.REBIRTH_MULT_PER * profile.rebirths)
		* (1 + Config.INCOME_TIER_MULT * profile.incomeTier)
	if BoostService.hasBoost(player, "cash") then
		mult *= Config.BOOST_CASH_MULT
	end
	if State.globalEvent.name == "cash" and time() < State.globalEvent.endsAt then
		mult *= Config.BOOST_CASH_MULT
	end
	if BuddyService.hasBuddy(player) then
		mult *= (1 + Config.BUDDY_CASH_BONUS)
	end
	if includeStormBoost ~= false and IncomeService.stormBoostActive(player) then
		mult *= Config.STORM_DOME_MULT
	end
	return mult
end

-- Storm bounty: earnings since the current storm started.
function IncomeService.resetStormEarnings()
	State.stormEarnings = {}
end

-- Storm bounty: the top earner this storm wins the bonus, paid to
-- the wallet with a server-wide banner. (The old live bounty BOARD
-- was removed in the simplify pass — the payout stays, the board
-- goes; the Contract Board took its spot in the plaza.)
function IncomeService.awardStormBounty()
	local bestPlayer: Player? = nil
	local bestEarned = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local earned = State.stormEarnings[player.UserId] or 0
		if earned > bestEarned then
			bestEarned = earned
			bestPlayer = player
		end
	end
	if bestPlayer and bestEarned > 0 then
		local profile = DataService.getProfile(bestPlayer)
		if profile then
			profile.coins += Config.BOUNTY_BONUS
			Remotes.bannerEvent():FireAllClients("🏆 STORM BOUNTY: " .. bestPlayer.DisplayName .. " earned the most this storm and wins " .. Formatting.formatMoney(Config.BOUNTY_BONUS) .. "!", 6)
		end
	end
	State.stormEarnings = {}
end

-- Coins per second from one player's placed Rotlings, after multipliers.
-- includeStormBoost (default true): pass false for the NORMAL rate —
-- the HUD shows it next to the boosted one during the storm.
function IncomeService.coinsPerSecond(player: Player, includeStormBoost: boolean?): number
	local total = 0
	for _, model in ipairs(BaseService.getPlacedForPlayer(player)) do
		local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
		if def then
			total += RotlingCatalog.baseCps(def, model:GetAttribute("Mutation") :: string?)
		end
	end
	return math.floor(total * IncomeService.incomeMult(player, includeStormBoost))
end

-- Send every player their current HUD numbers.
-- Each player's send is protected: one bad profile or a dropped
-- connection must never take the whole feed down with it.
-- Fix round 6, item 1: getStatus() used to run unprotected at the
-- top, so a throw there failed the WHOLE broadcast for everyone and
-- the HUD froze at its initial $0/+$0/s/Lv 1 values. It now falls
-- back to a calm status so the feed never dies on the storm's account.
function IncomeService.broadcastHud()
	local okStatus, stormOrErr = pcall(function()
		return StarfallService.getStatus()
	end)
	local storm = if okStatus then stormOrErr else { phase = "calm", secondsLeft = 0, danger = 0 }
	if not okStatus then
		warn("Starfall broadcastHud: getStatus failed, using calm fallback: " .. tostring(stormOrErr))
	end
	-- Leaderboard top 3 by coins, computed once per broadcast (cheap:
	-- a handful of players) so every client's HUD can show it. Rivals
	-- compete too: their coins count alongside real players.
	local top3: { { name: string, coins: number } } = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local otherProfile = DataService.getProfile(other)
		if otherProfile then
			-- Leaderboard ranks total wealth: wallet + uncollected base cash.
			table.insert(top3, { name = other.Name, coins = otherProfile.coins + otherProfile.banked })
		end
	end
	local RivalService = require(script.Parent.RivalService)
	for _, rival in pairs(State.rivals) do
		table.insert(top3, { name = rival.name .. " (Rival)", coins = math.floor(rival.coins) })
	end
	table.sort(top3, function(a, b)
		return a.coins > b.coins
	end)
	while #top3 > 3 do
		table.remove(top3)
	end
	-- The belt list: what is on the conveyor right now (name + $/s).
	local belt: { { name: string, cps: number } } = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:GetAttribute("State") == "free" then
			local def = RotlingCatalog.getDef(descendant:GetAttribute("DefId") :: string)
			if def then
				table.insert(belt, { name = def.name, cps = math.floor(RotlingCatalog.baseCps(def, descendant:GetAttribute("Mutation") :: string?)) })
			end
		end
	end
	table.sort(belt, function(a, b)
		return a.cps > b.cps
	end)
	while #belt > 5 do
		table.remove(belt)
	end
	local eventName = State.globalEvent.name
	local eventSeconds = math.max(0, math.ceil(State.globalEvent.endsAt - time()))
	if eventName == "" or eventSeconds <= 0 then
		eventName = ""
		eventSeconds = 0
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local ok, err = pcall(function()
			local profile = DataService.getProfile(player)
			if profile then
				local baseId = BaseService.getPlayerBase(player.UserId)
				-- The floating cash counter above the owner's base: it
				-- shows the BANKED cash (the money sitting at the base,
				-- waiting to be collected), not the wallet.
				if baseId then
					WorldBuilder.setBaseCoins(baseId, profile.banked)
					-- The base level sign: 1 + Rotlings placed here.
					-- The shield label: "SAFE (Ns)" while locked, "SAFE DOME"
					-- in green while the storm passes (every base is safe).
					WorldBuilder.setShieldLabel(baseId, BaseService.lockRemaining(baseId), storm.phase == "storm")
					-- Lock-gate expiry (rev 76): the red gate is solid
					-- while locked and MUST vanish the moment the lock
					-- ends, or it blocks the owner and every thief
					-- forever (the old code never called
					-- setGateVisible(false) anywhere). The shield dome
					-- already clears via setShieldLabel above; the gate
					-- had no expiry path at all. Only touch it on the
					-- locked -> unlocked transition (gateShown flag),
					-- not every tick.
					local lock = State.locks[baseId]
					if lock and lock.gateShown and BaseService.lockRemaining(baseId) <= 0 then
						BaseService.setGateVisible(baseId, false)
						lock.gateShown = false
						print("[BaseService] lock expired on base " .. tostring(baseId) .. " — gate hidden")
					end
				end
				local found = 0
				for _ in pairs(profile.index) do
					found += 1
				end
				local mission = MissionService.currentMission(player)
				local rebirthCost = Config.REBIRTH_BASE_COST * (profile.rebirths + 1) * (profile.rebirths + 1)
				-- The name of the Rotling being carried (for the
				-- CARRYING banner — the threat shot names the catch).
				local carriedName: string? = nil
				local carriedModels = CarryService.getCarried(player)
				if #carriedModels > 0 then
					local carriedDef = RotlingCatalog.getDef(carriedModels[1]:GetAttribute("DefId") :: string)
					if carriedDef then
						carriedName = carriedDef.name
					end
				end
				local boosts: { { kind: string, seconds: number } } = {}
				for kind, boost in pairs(State.boosts[player.UserId] or {}) do
					local left = math.ceil(boost.expiresAt - time())
					if left > 0 then
						table.insert(boosts, { kind = kind, seconds = left })
					end
				end
				Remotes.hudEvent():FireClient(player, {
					-- Total wealth (fix 3): wallet + uncollected base
					-- cash. Income banks at the base, so the wallet
					-- alone is not what the player has — the old big
					-- number (wallet only) never moved from income
					-- and the player thought the money did not add
					-- up. "At base" still shows the banked part.
					coins = profile.coins + profile.banked,
					banked = profile.banked,
					stardust = profile.stardust,
					xp = profile.xp,
					level = profile.level,
					xpProgress = (profile.xp % Config.XP_PER_LEVEL) / Config.XP_PER_LEVEL,
					cps = IncomeService.coinsPerSecond(player),
					-- Storm income readout: the boosted rate (cps, with
					-- the Safe Dome x2 when active) next to the normal
					-- rate (baseCps, without it), plus the flag.
					stormBoost = IncomeService.stormBoostActive(player),
					baseCps = IncomeService.coinsPerSecond(player, false),
					rebirths = profile.rebirths,
					rebirthCost = rebirthCost,
					-- Rebirth progress is total wealth / cost (fix 3):
					-- income banks at the base, so the wallet-only
					-- bar never filled from income either.
					rebirthProgress = math.clamp((profile.coins + profile.banked) / rebirthCost, 0, 1),
					speedTier = profile.speedTier,
					carryTier = profile.carryTier,
					incomeTier = profile.incomeTier,
					padsTier = profile.padsTier,
					lockTier = profile.lockTier,
					staminaTier = profile.staminaTier,
					eggTier = profile.eggTier,
					slapTier = profile.slapTier,
					carried = #CarryService.getCarried(player),
					carrySlots = CarryService.getCarrySlots(player),
					carriedName = carriedName,
					lockRemaining = if baseId then BaseService.lockRemaining(baseId) else 0,
					lockCooldown = if baseId then BaseService.lockCooldownRemaining(baseId) else 0,
					stormPhase = storm.phase,
					stormSeconds = storm.secondsLeft,
					danger = storm.danger,
					index = profile.index,
					indexCount = found,
					indexTotal = #RotlingCatalog.DEFS,
					top3 = top3,
					firstTime = profile.coins == 0 and profile.banked == 0 and profile.rebirths == 0 and found == 0,
					missionText = mission.text,
					missionProgress = MissionService.progress(player),
					missionTarget = mission.target,
					missionReward = mission.reward,
					missionAdvanceIn = MissionService.currentAdvanceIn(player),
					contracts = MissionService.activeContracts(player),
					mutations = profile.mutations or {},
					dailyReady = DailyService.isReady(player),
					boosts = boosts,
					belt = belt,
					eventName = eventName,
					eventSeconds = eventSeconds,
					buddyName = BuddyService.buddyName(player),
					eggCarried = State.eggCarriedByUser[player.UserId] ~= nil,
					-- THE CHASE: a guardian is hunting this player now.
					-- Deferred require: GuardianService requires
					-- CarryService, which this module also requires.
					-- Pcall-guarded (fix round 6, item 1): a throw in
					-- isChasing used to kill this player's whole HUD
					-- send, freezing their HUD at $0/+$0/s/Lv 1.
					guardianActive = (function()
						local okChase, chasing = pcall(function()
							local GuardianService = require(script.Parent.GuardianService)
							return GuardianService.isChasing(player)
						end)
						if not okChase then
							warn("Starfall broadcastHud: isChasing failed for " .. player.Name .. ": " .. tostring(chasing))
							return false
						end
						return chasing
					end)(),
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
-- Fix round 2, fix 6 (money): the old tick wrapped the WHOLE loop in
-- one pcall, so a single bad player — or a failure in the float, the
-- broadcast or the bounty board — skipped broadcastHud for EVERYONE
-- that second and the HUD froze at $0/+$0/s. Now each player is
-- isolated in their own pcall, and the float, the broadcast and the
-- bounty board each get their own pcall, so no single failure can
-- silence the feed. A diagnostic line every 30s prints each player's
-- coins / banked / cps / placed count, so the Output proves the money
-- is flowing (or shows exactly where it sticks).
-- Fix round 6, item 1 (money still $0): the 30s diagnostic and the
-- 5-tick heartbeat ran OUTSIDE any pcall — a single throw in
-- coinsPerSecond or getStatus there killed the WHOLE loop forever,
-- freezing money and the HUD at $0/+$0/s with no further warning.
-- Both are pcall-guarded now, and the loop logs its own start so a
-- dead tick is visible in Output instead of silent.
function IncomeService.start()
	print("[Starfall] income tick started (interval " .. tostring(Config.TICK_INTERVAL) .. "s)")
	local tickCount = 0
	task.spawn(function()
		while true do
			task.wait(Config.TICK_INTERVAL)
			tickCount += 1
			-- Per-player: one bad profile can never block the others.
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(function()
					local profile = DataService.getProfile(player)
					if profile then
						local gained = IncomeService.coinsPerSecond(player)
						-- Banking: income accrues at the base, not in
						-- the wallet — the player collects it with the
						-- HUD Collect button (BankService).
						profile.banked += gained
						-- Bounty ledger: earnings during this storm.
						State.stormEarnings[player.UserId] = (State.stormEarnings[player.UserId] or 0) + gained
						MissionService.addProgress(player, "earn", gained)
						local LeaderstatsService = require(script.Parent.LeaderstatsService)
						LeaderstatsService.refresh(player)
						-- Self-check (fix round 6, item 1): placed
						-- Brainrots that earn $0 are the money bug —
						-- say so loudly instead of banking $0 forever.
						local placedCount = #BaseService.getPlacedForPlayer(player)
						if placedCount > 0 and gained <= 0 then
							warn("[Starfall] money stuck for " .. player.Name .. ": " .. tostring(placedCount) .. " placed but cps=0 (check DefId/baseCps on the placed models)")
						end
					end
				end)
				if not ok then
					warn("Starfall income tick failed for " .. player.Name .. ": " .. tostring(err))
				end
			end
			-- Feed: each step protected on its own, so a failure in
			-- one can never silence the HUD for everyone.
			local okFloat, errFloat = pcall(floatIncomeNumber)
			if not okFloat then
				warn("Starfall income float failed: " .. tostring(errFloat))
			end
			local okHud, errHud = pcall(IncomeService.broadcastHud)
			if not okHud then
				warn("Starfall broadcastHud failed: " .. tostring(errHud))
			end
			-- Diagnostic (every 30s): one line per player with the
			-- numbers the HUD should be showing, so the Output
			-- proves the money is flowing (or shows exactly where
			-- it sticks). This is the evidence the playtest asked
			-- for: action | HUD said | actually added.
			-- Pcall-guarded (fix round 6, item 1): this used to run
			-- unprotected, so a throw in coinsPerSecond killed the
			-- whole income loop and froze money + HUD at $0 forever.
			if tickCount % 30 == 0 then
				local okDiag, errDiag = pcall(function()
					for _, player in ipairs(Players:GetPlayers()) do
						local profile = DataService.getProfile(player)
						if profile then
							print("[Starfall] money " .. player.Name .. ": coins=" .. tostring(profile.coins) .. " banked=" .. tostring(profile.banked) .. " cps=" .. tostring(IncomeService.coinsPerSecond(player)) .. " placed=" .. tostring(#BaseService.getPlacedForPlayer(player)))
						end
					end
				end)
				if not okDiag then
					warn("Starfall money diagnostic failed: " .. tostring(errDiag))
				end
			end
			-- Storm heartbeat (every 5 ticks): proves the loop is alive
			-- and shows the phase + seconds the HUD should be displaying.
			-- Also the storm watchdog: if the phase machine ever stalls,
			-- ensureRunning restarts it, so a dead storm thread can
			-- never leave the countdown ticking to zero with no storm.
			-- Pcall-guarded (fix round 6, item 1): same as above — a
			-- throw in getStatus/ensureRunning used to kill the loop.
			if tickCount % 5 == 0 then
				local okBeat, errBeat = pcall(function()
					local status = StarfallService.getStatus()
					local playerCount = #Players:GetPlayers()
					print("[Starfall] tick " .. tostring(tickCount) .. ": storm phase=" .. tostring(status.phase) .. " secondsLeft=" .. tostring(math.ceil(status.secondsLeft)) .. " players=" .. tostring(playerCount))
					StarfallService.ensureRunning()
				end)
				if not okBeat then
					warn("Starfall storm heartbeat failed: " .. tostring(errBeat))
				end
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
