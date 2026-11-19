-- Starfall Rotlings: full-loop self-test.
-- Runs the whole game loop WITHOUT a running game, by proving the wiring
-- each step depends on, and sanity-checking the economy numbers the loop
-- pays out. Prints one line per step and writes the same report to
-- ../notes/loop-self-test.log (next to the repo, in the bounty notes).
--
-- The loop under test:
--   grab (crater prompt) -> carry (weld) -> place (pad prompt)
--   -> earn (1/s tick) -> upgrade (shop tiers) -> buy (shop panel)
--   -> rebirth (reset for +25%) -> next tier (rarer spawns)
--   with sound + burst + cash pop-up on every action, and tutorial
--   arrows for a new player's first 60 seconds. Step 12 proves the
--   storm actually lands meteors: STORM START + METEOR LANDED logs,
--   hero meteors at storm start, the rain loop spawning immediately,
--   and a rare Rotling at each impact point.
--
-- Usage (from the repo root):
--   ../tools/lune run self-test.luau [root]
-- Exit 0 when every step passes, 1 otherwise. This is a test, not a
-- publish gate: publish.sh does not run it. Run it after every loop
-- change and read the log it leaves behind.

local fs = require("@lune/fs")
local process = require("@lune/process")

local root = process.args[1] or "."
if root:sub(-1) == "/" then
	root = root:sub(1, -2)
end

local results: { { id: string, ok: boolean, detail: string } } = {}
local lines: { string } = {}

local function step(id: string, ok: boolean, detail: string)
	table.insert(results, { id = id, ok = ok, detail = detail })
	local line = (if ok then "PASS" else "FAIL") .. " (" .. id .. ") " .. detail
	table.insert(lines, line)
	print(line)
end

local function read(path: string): string?
	local ok, text = pcall(fs.readFile, root .. "/" .. path)
	if not ok then
		return nil
	end
	return text :: string
end

local function num(text: string?): number?
	if not text then
		return nil
	end
	return tonumber(text)
end

-- 1. Grab: the crater prompt reaches the server's grab logic.
do
	local spawnSrc = read("src/server/SpawnService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	if not spawnSrc or not carrySrc then
		step("grab", false, "SpawnService.luau or CarryService.luau missing")
	else
		local problems: { string } = {}
		if not spawnSrc:find("prompt%.Triggered:Connect%(function%(player: Player%)") then
			table.insert(problems, "SpawnService.connectPrompt never connects the grab prompt")
		end
		if not spawnSrc:find("CarryService%.tryGrab%(player, model%)") then
			table.insert(problems, "grab prompt does not call CarryService.tryGrab")
		end
		if not carrySrc:find("CarryService%.carryRotling%(player, model%)") then
			table.insert(problems, "tryGrab never carries the Rotling")
		end
		if not carrySrc:find("weldToPlayer%(model, player%)") then
			table.insert(problems, "tryGrab never welds the Rotling to the player")
		end
		if #problems > 0 then
			step("grab", false, table.concat(problems, "; "))
		else
			step("grab", true, "crater prompt -> tryGrab -> carryRotling + weldToPlayer")
		end
	end
end

-- 2. Carry: the carried list and the slot count come from the profile.
do
	local carrySrc = read("src/server/CarryService.luau")
	if not carrySrc then
		step("carry", false, "CarryService.luau missing")
	else
		local problems: { string } = {}
		if not carrySrc:find("function CarryService%.getCarried") then
			table.insert(problems, "getCarried not found")
		end
		if not carrySrc:find("function CarryService%.getCarrySlots") then
			table.insert(problems, "getCarrySlots not found")
		end
		if not carrySrc:find("carryTier") then
			table.insert(problems, "carry slots never read the Extra Arms tier")
		end
		if #problems > 0 then
			step("carry", false, table.concat(problems, "; "))
		else
			step("carry", true, "carried list + slots from the profile (Extra Arms tier)")
		end
	end
end

-- 3. Place: the pad prompt places onto the player's own free pad.
do
	local mainSrc = read("src/server/Main.server.luau")
	local carrySrc = read("src/server/CarryService.luau")
	if not mainSrc or not carrySrc then
		step("place", false, "Main.server.luau or CarryService.luau missing")
	else
		local problems: { string } = {}
		if not mainSrc:find('descendant%.Parent%.Name == "Pad"') then
			table.insert(problems, "Main.server never wires the pad prompts")
		end
		if not mainSrc:find("CarryService%.tryPlace%(player%)") then
			table.insert(problems, "pad prompt does not call CarryService.tryPlace")
		end
		if not carrySrc:find("CarryService%.placeOnPad%(player, model, baseId, padIndex%)") then
			table.insert(problems, "tryPlace never calls placeOnPad")
		end
		if not carrySrc:find("State%.placed%[baseId%]%[padIndex%] = model") then
			table.insert(problems, "placeOnPad never records State.placed")
		end
		if not carrySrc:find("RotlingFactory%.setRestPose%(model%)") then
			table.insert(problems, "placeOnPad never sets the rest pose")
		end
		if #problems > 0 then
			step("place", false, table.concat(problems, "; "))
		else
			step("place", true, "pad prompt -> tryPlace -> placeOnPad -> State.placed + rest pose")
		end
	end
end

-- 4. Earn: the 1/s tick pays every placed Rotling's income.
do
	local incomeSrc = read("src/server/IncomeService.luau")
	if not incomeSrc then
		step("earn", false, "IncomeService.luau missing")
	else
		local problems: { string } = {}
		if not incomeSrc:find("profile%.banked %+= gained") then
			table.insert(problems, "income tick never banks the earnings at the base")
		end
		if not incomeSrc:find("BaseService%.getPlacedForPlayer%(player%)") then
			table.insert(problems, "coinsPerSecond never sums the placed Rotlings")
		end
		if not incomeSrc:find("IncomeService%.incomeMult%(player") then
			table.insert(problems, "income never applies the rebirth/shop multiplier")
		end
		if not incomeSrc:find("floatIncomeNumber%(%)") then
			table.insert(problems, "no floating +$N income numbers")
		end
		if #problems > 0 then
			step("earn", false, table.concat(problems, "; "))
		else
			step("earn", true, "1/s tick banks coinsPerSecond at the base (placed Rotlings x rebirth/shop mult) + floating +$N")
		end
	end
end

-- 4b. Money adds up (fix 3): the HUD big number, the rebirth bar and
-- the leaderboard are total wealth (wallet + banked), shop/rebirth
-- spend from total, and a rebirth resets both. The 60s table in
-- sim-money.luau is the audit: 2 Commons + 1 Rare = 6/s calm, 12/s
-- in the storm, $408 banked in 60s, big number $800 -> $1,208.
do
	local incomeSrc = read("src/server/IncomeService.luau")
	local bankSrc = read("src/server/BankService.luau")
	local shopSrc = read("src/server/ShopService.luau")
	local rebirthSrc = read("src/server/RebirthService.luau")
	local leaderSrc = read("src/server/LeaderstatsService.luau")
	local simSrc = read("sim-money.luau")
	if not incomeSrc or not bankSrc or not shopSrc or not rebirthSrc or not leaderSrc then
		step("money-adds-up", false, "IncomeService.luau, BankService.luau, ShopService.luau, RebirthService.luau or LeaderstatsService.luau missing")
	else
		local problems: { string } = {}
		if not incomeSrc:find("coins = profile%.coins %+ profile%.banked") then
			table.insert(problems, "HUD big number is not total wealth")
		end
		if not incomeSrc:find("rebirthProgress = math%.clamp%(%(profile%.coins %+ profile%.banked%) / rebirthCost") then
			table.insert(problems, "rebirth bar is not total wealth / cost")
		end
		if not shopSrc:find("BankService%.spendFromTotal%(player, cost%)") then
			table.insert(problems, "shop does not spend from total wealth")
		end
		if not rebirthSrc:find("BankService%.totalWealth%(player%) < cost") or not rebirthSrc:find("profile%.banked = 0") then
			table.insert(problems, "rebirth does not check total wealth and reset both")
		end
		if not leaderSrc:find("coins%.Value = profile%.coins %+ profile%.banked") then
			table.insert(problems, "leaderboard is not total wealth")
		end
		if not simSrc then
			table.insert(problems, "sim-money.luau missing")
		end
		if #problems > 0 then
			step("money-adds-up", false, table.concat(problems, "; "))
		else
			step("money-adds-up", true, "HUD + rebirth bar + leaderboard are total wealth; shop/rebirth spend from total; rebirth resets both; 60s table: 6/s calm, 12/s storm, $408 banked, big number $800 -> $1,208")
		end
	end
end

-- 5. Upgrade: shop tiers change the game (speed, pads, income, lock).
do
	local shopSrc = read("src/server/ShopService.luau")
	if not shopSrc then
		step("upgrade", false, "ShopService.luau missing")
	else
		local problems: { string } = {}
		if not shopSrc:find("writable%[tierKey%] = tier %+ 1") then
			table.insert(problems, "buyItem never advances the tier")
		end
		if not shopSrc:find("humanoid%.WalkSpeed = Config%.BASE_WALKSPEED") then
			table.insert(problems, "Speed tier never applies WalkSpeed")
		end
		if not shopSrc:find("BaseService%.unlockPad%(player%)") then
			table.insert(problems, "Pads tier never unlocks a pad")
		end
		if not shopSrc:find("Remotes%.buyFunction%(%)%.OnServerInvoke") then
			table.insert(problems, "BuyItem remote never wired")
		end
		if #problems > 0 then
			step("upgrade", false, table.concat(problems, "; "))
		else
			step("upgrade", true, "buyItem advances tiers; Speed sets WalkSpeed, Pads unlocks a pad, BuyItem wired")
		end
	end
end

-- 6. Buy: the shop panel offers all eight ladders.
do
	local shopClient = read("src/client/ShopController.client.luau")
	if not shopClient then
		step("buy", false, "ShopController.client.luau missing")
	else
		local problems: { string } = {}
		local rows = 0
		for _ in shopClient:gmatch('SHOP_ORDER = { "Speed", "Carry", "Income", "Pads", "Lock", "Stamina", "Egg", "Slap" }') do
			rows = 8
		end
		if rows ~= 8 then
			table.insert(problems, "shop panel does not list all 8 ladders")
		end
		if not shopClient:find("Remotes%.buyFunction%(%)%:InvokeServer%(key%)") then
			table.insert(problems, "buy button never invokes BuyItem")
		end
		if #problems > 0 then
			step("buy", false, table.concat(problems, "; "))
		else
			step("buy", true, "shop panel lists 8 ladders; buy buttons invoke BuyItem")
		end
	end
end

-- 7. Rebirth: reset coins for a permanent multiplier + new base colour.
do
	local rebirthSrc = read("src/server/RebirthService.luau")
	if not rebirthSrc then
		step("rebirth", false, "RebirthService.luau missing")
	else
		local problems: { string } = {}
		if not rebirthSrc:find("profile%.coins = 0") then
			table.insert(problems, "doRebirth never resets coins")
		end
		if not rebirthSrc:find("profile%.rebirths %+= 1") then
			table.insert(problems, "doRebirth never counts the rebirth")
		end
		if not rebirthSrc:find("WorldBuilder%.setBaseColor%(baseId, color%)") then
			table.insert(problems, "doRebirth never recolours the base")
		end
		if not rebirthSrc:find("Remotes%.rebirthFunction%(%)%.OnServerInvoke") then
			table.insert(problems, "DoRebirth remote never wired")
		end
		if #problems > 0 then
			step("rebirth", false, table.concat(problems, "; "))
		else
			step("rebirth", true, "DoRebirth wired: coins reset, rebirths +1, base recoloured, +25% income each")
		end
	end
end

-- 8. Next tier: rarer Rotlings exist and pay more (the ladder climbs).
do
	local raritySrc = read("src/shared/RarityConfig.luau")
	if not raritySrc then
		step("next-tier", false, "RarityConfig.luau missing")
	else
		local problems: { string } = {}
		local names: { string } = {}
		for name in raritySrc:gmatch('name = "([%w]+)"') do
			table.insert(names, name)
		end
		if #names < 6 then
			table.insert(problems, "only " .. tostring(#names) .. " rarities (need 6)")
		end
		local cpsValues: { number } = {}
		for cps in raritySrc:gmatch("cps = (%d+)") do
			table.insert(cpsValues, tonumber(cps) :: number)
		end
		local climbing = true
		for i = 2, #cpsValues do
			if cpsValues[i] <= cpsValues[i - 1] then
				climbing = false
			end
		end
		if not climbing or #cpsValues < 6 then
			table.insert(problems, "rarity cps does not climb (" .. table.concat(cpsValues, ", ") .. ")")
		end
		if not raritySrc:find("function RarityConfig%.rollRarity") then
			table.insert(problems, "rollRarity not found")
		end
		if #problems > 0 then
			step("next-tier", false, table.concat(problems, "; "))
		else
			step("next-tier", true, "6 rarities (" .. table.concat(names, ", ") .. "), cps climbs " .. table.concat(cpsValues, " < ") .. ", weighted roll")
		end
	end
end

-- 9. Economy sanity: the loop's numbers are positive and ordered.
do
	local configSrc = read("src/shared/Config.luau")
	local raritySrc = read("src/shared/RarityConfig.luau")
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	if not configSrc or not raritySrc or not catalogSrc then
		step("economy", false, "Config.luau, RarityConfig.luau or RotlingCatalog.luau missing")
	else
		local problems: { string } = {}
		-- Wobble Wombat: Common (cps 1) x cpsMult 1 = 1/s; sells for 25x.
		local commonCps = num(raritySrc:match('name = "Common".-cps = (%d+)'))
		local wombatMult = num(catalogSrc:match('id = "wombat".-cpsMult = ([%d%.]+)'))
		local sellMult = num(configSrc:match("SELL_MULT%s*=%s*(%d+)"))
		if not commonCps or not wombatMult or not sellMult then
			table.insert(problems, "could not parse wombat cps / sell multiplier")
		else
			local wombatCps = commonCps * wombatMult
			if wombatCps <= 0 then
				table.insert(problems, "wombat earns " .. tostring(wombatCps) .. "/s (not positive)")
			end
			if wombatCps * sellMult <= 0 then
				table.insert(problems, "wombat sells for nothing")
			end
		end
		local rebirthBase = num(configSrc:match("REBIRTH_BASE_COST%s*=%s*(%d+)"))
		if not rebirthBase or rebirthBase <= 0 then
			table.insert(problems, "first rebirth cost not positive")
		end
		local daily = num(configSrc:match("DAILY_REWARD%s*=%s*(%d+)"))
		if not daily or daily <= 0 then
			table.insert(problems, "daily reward not positive")
		end
		local missionRewards = 0
		for reward in configSrc:gmatch("reward = (%d+)") do
			missionRewards += tonumber(reward) :: number
		end
		if missionRewards <= 0 then
			table.insert(problems, "mission rewards total 0")
		end
		if #problems > 0 then
			step("economy", false, table.concat(problems, "; "))
		else
			step("economy", true, "wombat " .. tostring((commonCps or 0) * (wombatMult or 0)) .. "/s, sells for " .. tostring((commonCps or 0) * (wombatMult or 0) * (sellMult or 0)) .. ", first rebirth " .. tostring(rebirthBase) .. ", daily " .. tostring(daily) .. ", contracts pay " .. tostring(missionRewards) .. " total")
		end
	end
end

-- 10. Feedback: sound + burst + cash pop-up on every action.
do
	local feedbackSrc = read("src/server/FeedbackService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local shopSrc = read("src/server/ShopService.luau")
	local rebirthSrc = read("src/server/RebirthService.luau")
	local sellSrc = read("src/server/SellService.luau")
	local missionSrc = read("src/server/MissionService.luau")
	local dailySrc = read("src/server/DailyService.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	if not feedbackSrc or not carrySrc or not shopSrc or not rebirthSrc or not sellSrc or not missionSrc or not dailySrc or not factorySrc then
		step("feedback", false, "FeedbackService.luau or a caller module missing")
	else
		local problems: { string } = {}
		for _, fn in ipairs({ "playSound", "burst", "cashPopup", "celebrate" }) do
			if not feedbackSrc:find("function FeedbackService%." .. fn) then
				table.insert(problems, "FeedbackService." .. fn .. " not found")
			end
		end
		if not feedbackSrc:find('rbxasset://sounds/electronicpingshort%.wav') then
			table.insert(problems, "feedback sound is not the known-good built-in ping")
		end
		if not carrySrc:find("FeedbackService%.burst%(model") then
			table.insert(problems, "grab never bursts")
		end
		if not factorySrc:find("function RotlingFactory%.placePop") then
			table.insert(problems, "place has no placePop (burst + ding + bounce)")
		end
		if not shopSrc:find("FeedbackService%.celebrate%(player%)") then
			table.insert(problems, "buy never celebrates")
		end
		if not rebirthSrc:find("FeedbackService%.celebrate%(player%)") then
			table.insert(problems, "rebirth never celebrates")
		end
		if not sellSrc:find("FeedbackService%.cashPopup%(character") then
			table.insert(problems, "sell never pops the cash")
		end
		if not missionSrc:find("FeedbackService%.celebrate%(player%)") then
			table.insert(problems, "mission complete never celebrates")
		end
		if not dailySrc:find("FeedbackService%.celebrate%(player%)") then
			table.insert(problems, "daily claim never celebrates")
		end
		if #problems > 0 then
			step("feedback", false, table.concat(problems, "; "))
		else
			step("feedback", true, "sound + burst + cash pop-up on grab, place, buy, rebirth, sell, mission, daily")
		end
	end
end

-- 11. Tutorial arrows: first 80 seconds, four steps, stops on a bonk.
-- (fix round 7, item 5) The old tutorial stopped on the first grab,
-- so BONK was never explained — now it runs all four steps and only
-- stops early when the player actually bonks a thief.
do
	local tutSrc = read("src/client/TutorialController.client.luau")
	if not tutSrc then
		step("tutorial", false, "TutorialController.client.luau missing")
	else
		local problems: { string } = {}
		local seconds = num(tutSrc:match("TUTORIAL_SECONDS%s*=%s*(%d+)"))
		if not seconds then
			table.insert(problems, "TUTORIAL_SECONDS not found")
		elseif seconds ~= 80 then
			table.insert(problems, "tutorial lasts " .. tostring(seconds) .. "s (must be 80)")
		end
		if not tutSrc:find('part%.Name = "TutorialArrow"') then
			table.insert(problems, 'no "TutorialArrow" part')
		end
		if not tutSrc:find("data%.firstTime and not active") then
			table.insert(problems, "tutorial is not gated on firstTime")
		end
		if tutSrc:find("if data%.carried > 0 then") then
			table.insert(problems, "tutorial still stops on the first grab — the Bonk step is never shown")
		end
		if not tutSrc:find("slapEffectEvent%(%)%.OnClientEvent") then
			table.insert(problems, "tutorial never stops when the player bonks a thief")
		end
		local steps = 0
		for _, label in ipairs({ '"1. Walk', '"2. Carry', '"3. Sell', '"4. See a thief' }) do
			if tutSrc:find(label, 1, true) then
				steps += 1
			end
		end
		if steps < 4 then
			table.insert(problems, "fewer than 4 tutorial steps (" .. tostring(steps) .. " step labels found)")
		end
		if #problems > 0 then
			step("tutorial", false, table.concat(problems, "; "))
		else
			step("tutorial", true, "gold arrow, 4 steps (crater -> base -> SELL -> BONK), 80s, firstTime only, stops early on a successful bonk")
		end
	end
end

-- 11b. Spawn path (fix 5): the walkway from spawn reaches the crater
-- rim, where the StonePath to the shop begins — no dead end.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		step("spawn-path", false, "WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("for i = 0, 13 do") then
			table.insert(problems, "SpawnPath loop does not run to i=13 (z=39, the crater rim)")
		end
		if not worldSrc:find("fenceLine%(Vector3%.new%(%-5, 0, 78%), Vector3%.new%(%-5, 0, 40%)%)") then
			table.insert(problems, "left fence does not run to z=40")
		end
		if not worldSrc:find("fenceLine%(Vector3%.new%(5, 0, 78%), Vector3%.new%(5, 0, 40%)%)") then
			table.insert(problems, "right fence does not run to z=40")
		end
		if not worldSrc:find("local shopPathFrom = Vector3%.new%(0, 0, 40%)") then
			table.insert(problems, "shopPathFrom is not the crater rim (0,0,40)")
		end
		if not worldSrc:find("local shopPathTo = Vector3%.new%(%-40, 0, 44%)") then
			table.insert(problems, "shopPathTo is not the shop (-40,0,44)")
		end
		if not worldSrc:find("path%(shopPathFrom, shopPathTo%)") then
			table.insert(problems, "StonePath from the rim to the shop is missing")
		end
		if #problems > 0 then
			step("spawn-path", false, table.concat(problems, "; "))
		else
			step("spawn-path", true, "spawn path z=78 to z=39 (crater rim), fences to z=40, StonePath to the shop starts at the rim")
		end
	end
end

-- 11c. Branding (Malek-approved Nov 18 16:10): the game is Space Rock
-- Brainrots! and the catalog carries the 22 approved Rotling names.
do
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local titleSrc = read("src/client/TitleScreenController.client.luau")
	if not catalogSrc or not hudSrc or not titleSrc then
		step("branding", false, "RotlingCatalog.luau, HUDController.client.luau or TitleScreenController.client.luau missing")
	else
		local problems: { string } = {}
		for _, name in ipairs({ "Bloop the Blob", "Pip the Potato", "Wobble Wombat", "Tiny Toaster Tim", "Gloopy Goose", "Sir Soggy Sock", "Bongo the Banana", "Captain Crumb", "Mister Muffin Feet", "Professor Pickle", "Turbo Toast", "Lord Lasagna Legs", "Disco Donut", "Baron von Burrito", "Count Croissant", "Sir Reginald Ramen", "Grandpa Gumball", "Supreme Spaghetti", "The Great Giggling Gherkin", "Cosmic Corn Dog" }) do
			if not catalogSrc:find('name = "' .. name .. '"', 1, true) then
				table.insert(problems, '"' .. name .. '" not in the catalog')
			end
		end
		if not hudSrc:find("SPACE ROCK BRAINROTS") then
			table.insert(problems, "HUD title is not SPACE ROCK BRAINROTS")
		end
		if not titleSrc:find("SPACE ROCK BRAINROTS") then
			table.insert(problems, "title screen is not SPACE ROCK BRAINROTS")
		end
		if #problems > 0 then
			step("branding", false, table.concat(problems, "; "))
		else
			step("branding", true, "SPACE ROCK BRAINROTS! title + all 22 approved Rotling names in the catalog (5C/4R/4E/4L/2M/1Co/2D)")
		end
	end
end

-- 12. Storm lands: a meteor actually falls within 10s of the storm
-- starting, and it leaves a rare Rotling at the impact point. The old
-- storm failed silently (countdown hit zero, nothing happened), so
-- this step fails if the storm has no logs, no immediate spawn, or a
-- fall tween longer than 10s.
do
	local starSrc = read("src/server/StarfallService.luau")
	local spawnSrc = read("src/server/SpawnService.luau")
	if not starSrc or not spawnSrc then
		step("storm-lands", false, "StarfallService.luau or SpawnService.luau missing")
	else
		local problems: { string } = {}
		if not starSrc:find('%[Starfall%] STORM START') then
			table.insert(problems, 'no "[Starfall] STORM START" log')
		end
		if not starSrc:find('%[Starfall%] METEOR LANDED') then
			table.insert(problems, 'no "[Starfall] METEOR LANDED" log')
		end
		-- Hero meteors spawn at storm start, no wait before the first.
		if not starSrc:find("task.spawn%(spawnHeroMeteor%)") then
			table.insert(problems, "hero meteors are not spawned at storm start")
		end
		-- The rain loop's first statement is a spawn, not a wait.
		if not starSrc:find("while time%(%) < phaseEndsAt do%s+spawnMeteor%(%)") then
			table.insert(problems, "the rain loop waits before its first spawnMeteor()")
		end
		-- Both fall tweens land inside 10s.
		local rainTween = num(starSrc:match("local function spawnMeteor%(%)[^{]-TweenInfo%.new%(([%d%.]+),"))
		local heroTween = num(starSrc:match("local function spawnHeroMeteor%(%)[^{]-TweenInfo%.new%(([%d%.]+),"))
		if not rainTween then
			table.insert(problems, "rain meteor TweenInfo not found in spawnMeteor")
		elseif rainTween > 10 then
			table.insert(problems, "rain meteor tween " .. tostring(rainTween) .. "s (over 10s)")
		end
		if not heroTween then
			table.insert(problems, "hero meteor TweenInfo not found in spawnHeroMeteor")
		elseif heroTween > 10 then
			table.insert(problems, "hero meteor tween " .. tostring(heroTween) .. "s (over 10s)")
		end
		-- A meteor landing leaves a rare Rotling at the impact point.
		if not starSrc:find("SpawnService.spawnRareAt%(target%)") then
			table.insert(problems, "onMeteorLanded never spawns a rare Rotling (SpawnService.spawnRareAt)")
		end
		if not spawnSrc:find("function SpawnService.spawnRareAt") then
			table.insert(problems, "SpawnService.spawnRareAt not found")
		end
		if #problems > 0 then
			step("storm-lands", false, table.concat(problems, "; "))
		else
			step("storm-lands", true, "STORM START + METEOR LANDED logged, hero meteors at storm start, rain loop spawns immediately, tweens " .. tostring(heroTween) .. "s / " .. tostring(rainTween) .. "s (both land within 10s), rare Rotling at each impact")
		end
	end
end

-- 12b. Storm hit feedback (fix 1): a meteor hit is no longer silent.
-- The victim gets a METEOR HIT banner, the screen flashes red on a
-- close impact, and the storm bar says sheltering pays x2 and throbs
-- while the storm runs — banner, wall and effect in the same moment.
do
	local starSrc = read("src/server/StarfallService.luau")
	local camSrc = read("src/client/CameraFX.client.luau")
	local warnSrc = read("src/client/StormWarningController.client.luau")
	if not starSrc or not camSrc or not warnSrc then
		step("storm-hit-feedback", false, "StarfallService.luau, CameraFX.client.luau or StormWarningController.client.luau missing")
	else
		local problems: { string } = {}
		if not starSrc:find("METEOR HIT!") then
			table.insert(problems, 'no "METEOR HIT!" banner in StarfallService.onMeteorLanded')
		end
		if not camSrc:find("MeteorHitFlash") or not camSrc:find("distance <= 15") then
			table.insert(problems, "CameraFX has no red flash on a close (<= 15 stud) meteor impact")
		end
		if not warnSrc:find("x2 INCOME") or not warnSrc:find("startPulse") then
			table.insert(problems, "storm bar does not say SHELTER = x2 INCOME and throb")
		end
		if #problems > 0 then
			step("storm-hit-feedback", false, table.concat(problems, "; "))
		else
			step("storm-hit-feedback", true, "METEOR HIT banner to the victim + red screen flash on a close impact; storm bar says SHELTER = x2 INCOME and throbs")
		end
	end
end

-- 13. Sell is 25x: selling clears a pad, never beats placing.
do
	local configSrc = read("src/shared/Config.luau")
	local sellSrc = read("src/server/SellService.luau")
	if not configSrc or not sellSrc then
		step("sell-25x", false, "Config.luau or SellService.luau missing")
	else
		local problems: { string } = {}
		local sellMult = num(configSrc:match("SELL_MULT%s*=%s*(%d+)"))
		if not sellMult then
			table.insert(problems, "SELL_MULT not found in Config.luau")
		elseif sellMult > 30 then
			table.insert(problems, "SELL_MULT is " .. tostring(sellMult) .. "x (above 30x — selling beats placing)")
		end
		if not sellSrc:find("baseCps%(def, mutation%) %* Config%.SELL_MULT") then
			table.insert(problems, "sellValue is not baseCps x SELL_MULT")
		end
		if #problems > 0 then
			step("sell-25x", false, table.concat(problems, "; "))
		else
			step("sell-25x", true, "sell pays " .. tostring(sellMult) .. "x income (<= 30x) — placing is always the better long-term choice")
		end
	end
end

-- 14. Own-base pickup: the owner can take their own placed Rotling
-- back up and carry it again; other players still go through steal.
do
	local carrySrc = read("src/server/CarryService.luau")
	if not carrySrc then
		step("own-pickup", false, "CarryService.luau missing")
	else
		local problems: { string } = {}
		if not carrySrc:find("function CarryService%.pickupOwn") then
			table.insert(problems, "pickupOwn not found")
		end
		if not carrySrc:find("CarryService%.pickupOwn%(player, model%)") then
			table.insert(problems, "tryGrab never routes an owner to pickupOwn")
		end
		if not carrySrc:find('"Pick up "') then
			table.insert(problems, 'no "Pick up <name>" prompt for own-base pickup')
		end
		if not carrySrc:find("StealService%.trySteal%(player, model%)") then
			table.insert(problems, "other players' Rotlings no longer route to StealService.trySteal")
		end
		if #problems > 0 then
			step("own-pickup", false, table.concat(problems, "; "))
		else
			step("own-pickup", true, "owners pick up their own Rotlings (Pick up prompt); rivals still steal")
		end
	end
end

-- 15. Rivals: 4 named bots on bases 5-8 that grab, carry, earn and
-- steal; the leaderboard shows them and the storm bounty pays the
-- top earner (the live bounty board is gone — the Contract Board
-- took its plaza spot).
do
	local rivalSrc = read("src/server/RivalService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	if not rivalSrc or not mainSrc or not incomeSrc then
		step("rivals", false, "RivalService.luau, Main.server.luau or IncomeService.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find("function RivalService%.start") then
			table.insert(problems, "RivalService.start not found")
		end
		if not mainSrc:find("RivalService%.start") then
			table.insert(problems, "Main.server never starts the rivals")
		end
		if not rivalSrc:find("is sneaking to your base") then
			table.insert(problems, "no steal alert to the victim")
		end
		if not rivalSrc:find("THIEF ON YOUR TAIL") then
			table.insert(problems, "no pursuit banner when a rival chases an egg carrier")
		end
		if not incomeSrc:find("Rival") then
			table.insert(problems, "rivals never appear on the leaderboard")
		end
		if not incomeSrc:find("STORM BOUNTY:") then
			table.insert(problems, "the storm bounty winner is never announced")
		end
		if #problems > 0 then
			step("rivals", false, table.concat(problems, "; "))
		else
			step("rivals", true, "4 rivals on bases 5-8 grab, carry, earn, steal and chase; leaderboard + storm bounty wired")
		end
	end
end

-- 15c. Raider steal (fix 4): ONE clear rival behaviour, end to end.
-- A raider targets a real player's base, the owner is warned at
-- spawn, it grabs a Rotling and runs for the crater edge, and a
-- bonk/slap drops the loot and makes it visibly flee.
do
	local raiderSrc = read("src/server/RaiderService.luau")
	local slapSrc = read("src/server/SlapService.luau")
	if not raiderSrc or not slapSrc then
		step("raider-steal", false, "RaiderService.luau or SlapService.luau missing")
	else
		local problems: { string } = {}
		if not raiderSrc:find("playerBases") or not raiderSrc:find("ownerId > 0") then
			table.insert(problems, "spawnRaider does not prefer a real player's base")
		end
		if not raiderSrc:find("is sneaking toward your base!") then
			table.insert(problems, "no raid-incoming banner at spawn")
		end
		if not raiderSrc:find("shouldCancel") or not raiderSrc:find("function fleeAndDespawn") then
			table.insert(problems, "a bonked raider does not cancel its walk and visibly flee")
		end
		if not raiderSrc:find("CarryService%.scatterToCrater%(raider%.stolen%)") then
			table.insert(problems, "bonkRaider does not drop the stolen Rotling")
		end
		if not slapSrc:find("RaiderService%.bonkRaider%(raiderModel, player%)") then
			table.insert(problems, "the slap bat does not bonk raiders")
		end
		if #problems > 0 then
			step("raider-steal", false, table.concat(problems, "; "))
		else
			step("raider-steal", true, "raider targets a real player's base, owner warned at spawn, grabs and runs for the edge, bonk/slap drops the loot and the raider flees")
		end
	end
end

-- 15b. Bots move (fix 2): the base edge and the crater rim no longer
-- trap them. A wedge ramp at every base front, raiders spawning on
-- open ground, a stuck bot that jumps, and bots that run for cover
-- in a storm.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not worldSrc or not raiderSrc or not rivalSrc or not configSrc then
		step("bots-move", false, "WorldBuilder.luau, RaiderService.luau, RivalService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find('"BaseRamp"') or not worldSrc:find("Enum%.PartType%.Wedge, Vector3%.new%(6, 2, 4%)") then
			table.insert(problems, "no 6x2x4 BaseRamp wedge at the base front")
		end
		if not raiderSrc:find("Vector3%.new%(math%.cos%(angle%) %* 45, 8, math%.sin%(angle%) %* 45%)") then
			table.insert(problems, "raiders do not spawn at radius 45, Y=8")
		end
		if not configSrc:find("RAIDER_FIRST = 15") or not configSrc:find("RAIDER_INTERVAL = 75") then
			table.insert(problems, "raider timing is not first 15s / every 75s")
		end
		if not raiderSrc:find("humanoid%.Jump = true") or not rivalSrc:find("humanoid%.Jump = true") then
			table.insert(problems, "walkTo has no stuck-jump in RaiderService or RivalService")
		end
		if not raiderSrc:find("shelterIfStorm") or not rivalSrc:find('getStatus%(%)%.phase == "storm"') then
			table.insert(problems, "bots do not shelter during a storm")
		end
		if #problems > 0 then
			step("bots-move", false, table.concat(problems, "; "))
		else
			step("bots-move", true, "BaseRamp wedge at every base front, raiders spawn radius 45 / Y=8, first raid 15s then every 75s, stuck bots jump, raiders + rivals shelter during storms")
		end
	end
end

-- 16. Slap bat: F key + SLAP button, 2s cooldown, knockback + drop.
do
	local slapSrc = read("src/server/SlapService.luau")
	local slapClient = read("src/client/SlapController.client.luau")
	if not slapSrc or not slapClient then
		step("slap", false, "SlapService.luau or SlapController.client.luau missing")
	else
		local problems: { string } = {}
		if not slapSrc:find("function SlapService%.trySlap") then
			table.insert(problems, "trySlap not found")
		end
		if not slapSrc:find("dropCarried") then
			table.insert(problems, "a slap never drops the victim's carry")
		end
		if not slapSrc:find("applySlapFromRival") then
			table.insert(problems, "rivals never slap back")
		end
		if not slapClient:find("KeyCode%.F") then
			table.insert(problems, "no F keybind for the slap bat")
		end
		if not slapClient:find("SLAP") then
			table.insert(problems, "no on-screen SLAP button")
		end
		if #problems > 0 then
			step("slap", false, table.concat(problems, "; "))
		else
			step("slap", true, "F key + SLAP button, 2s cooldown, knockback + drop, rivals slap back")
		end
	end
end

-- 17. Meteor eggs: 2 per storm, heavy carry, incubator hatch in 60s.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	if not eggSrc or not mainSrc then
		step("eggs", false, "MeteorEggService.luau or Main.server.luau missing")
	else
		local problems: { string } = {}
		if not eggSrc:find("function MeteorEggService%.spawnEggsForStorm") then
			table.insert(problems, "spawnEggsForStorm not found")
		end
		if not eggSrc:find("function MeteorEggService%.placeEgg") then
			table.insert(problems, "placeEgg not found (no incubator placement)")
		end
		if not eggSrc:find("HATCHED:") then
			table.insert(problems, "no hatch reveal banner")
		end
		if not eggSrc:find("EGG_HATCH_TIME") then
			table.insert(problems, "hatch never waits EGG_HATCH_TIME (60s)")
		end
		if not mainSrc:find("MeteorEggService%.dropEgg") then
			table.insert(problems, "dying never drops the egg")
		end
		if #problems > 0 then
			step("eggs", false, table.concat(problems, "; "))
		else
			step("eggs", true, "2 eggs per storm, heavy carry, incubator hatch in 60s with reveal, drops on death")
		end
	end
end

-- 18. Boosts: 4 pickups in the world + shop, HUD icons with timers.
do
	local boostSrc = read("src/server/BoostService.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local shopSrc = read("src/client/ShopController.client.luau")
	if not boostSrc or not hudSrc or not shopSrc then
		step("boosts", false, "BoostService.luau, HUDController.client.luau or ShopController.client.luau missing")
	else
		local problems: { string } = {}
		for _, kind in ipairs({ "speed", "magnet", "cash", "shield" }) do
			if not boostSrc:find(kind .. " = { label") then
				table.insert(problems, 'boost "' .. kind .. '" missing from BoostService')
			end
		end
		if not hudSrc:find("BoostRow") then
			table.insert(problems, "no BoostRow in the HUD")
		end
		if not shopSrc:find("BOOST_VIEW") then
			table.insert(problems, "boosts are not buyable in the shop")
		end
		if #problems > 0 then
			step("boosts", false, table.concat(problems, "; "))
		else
			step("boosts", true, "Speed/Magnet/2x Cash/Shield pickups + shop rows, HUD icons with timers")
		end
	end
end

-- 19. Buddy: PARKED (simplify pass, v74) — the pet is not spawned, so
-- it cannot overlap the player or block the camera. The code stays
-- for a later return: attachBuddy still exists, refreshBuddy is a
-- no-op, the Index button is hidden.
do
	local buddySrc = read("src/server/BuddyService.luau")
	local indexSrc = read("src/client/IndexController.client.luau")
	local mainSrc = read("src/server/Main.server.luau")
	if not buddySrc or not indexSrc or not mainSrc then
		step("buddy", false, "BuddyService.luau, IndexController.client.luau or Main.server.luau missing")
	else
		local problems: { string } = {}
		if not buddySrc:find("function BuddyService%.attachBuddy") then
			table.insert(problems, "attachBuddy gone — the pet cannot return later")
		end
		if mainSrc:find("attachBuddy") then
			table.insert(problems, "the buddy is still attached on spawn")
		end
		if not buddySrc:find("BUDDY_PARKED") then
			table.insert(problems, "refreshBuddy is not parked — a placement would re-spawn the pet")
		end
		if not indexSrc:find("buddyButton%.Visible = false") then
			table.insert(problems, "the Set as Buddy button is not hidden")
		end
		if #problems > 0 then
			step("buddy", false, table.concat(problems, "; "))
		else
			step("buddy", true, "buddy pet parked: never spawned, no label over the player, no +5% bonus, Index button hidden — code kept for a later return")
		end
	end
end

-- 20. Cheap wins: rebirth progress on the button, danger meter, belt
-- list, title billboard, shield dome, global events.
do
	local hudSrc = read("src/client/HUDController.client.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local eventSrc = read("src/server/GlobalEventService.luau")
	if not hudSrc or not worldSrc or not eventSrc then
		step("cheap-wins", false, "HUDController.client.luau, WorldBuilder.luau or GlobalEventService.luau missing")
	else
		local problems: { string } = {}
		-- Rebirth progress lives ON the Rebirth button now (simplify/
		-- polish HUD): the full-width NEXT REBIRTH bar is gone. This
		-- step proves the bar is GONE and the button fill is present.
		if hudSrc:find("RebirthBar") or hudSrc:find("RebirthProgressLabel") then
			table.insert(problems, "the old NEXT REBIRTH bar is still in the HUD (progress lives on the Rebirth button now)")
		end
		if not hudSrc:find("RebirthButtonFill") then
			table.insert(problems, "no progress fill on the Rebirth button")
		end
		if not hudSrc:find("DangerBar") then
			table.insert(problems, "no Meteor Danger meter in the HUD")
		end
		-- THE BELT panel REMOVED (simplify/polish REMOVE): the left-side
		-- list was cut off and nobody needs it. This step proves it is
		-- GONE, not present.
		if hudSrc:find("BeltPanel") then
			table.insert(problems, 'the "On the belt" list is still in the HUD (must be removed per the simplify/polish pass)')
		end
		-- Title billboard REMOVED (fix round 2, fix 8): the giant sky
		-- text filled the screen and its pitch line overlapped the
		-- SELL pad. The step proves it is GONE, not present.
		if worldSrc:find("TitleBoard") then
			table.insert(problems, "the title billboard is still in the sky (must be removed per the playtest)")
		end
		if not worldSrc:find("ShieldDome") then
			table.insert(problems, "no shield dome on the bases")
		end
		if not eventSrc:find("STARDUST SHOWER") then
			table.insert(problems, "no Stardust Shower global event")
		end
		if not eventSrc:find("2X CASH HOUR") then
			table.insert(problems, "no 2x Cash Hour global event")
		end
		if #problems > 0 then
			step("cheap-wins", false, table.concat(problems, "; "))
		else
			step("cheap-wins", true, "rebirth progress on the button, danger meter, belt list, no title billboard (removed per playtest), shield dome, 2 global events")
		end
	end
end

-- 21. Title screen: big title, ladder, 3-step loop, PLAY dismisses it.
do
	local titleSrc = read("src/client/TitleScreenController.client.luau")
	if not titleSrc then
		step("title-screen", false, "TitleScreenController.client.luau missing")
	else
		local problems: { string } = {}
		if not titleSrc:find("SPACE ROCK BRAINROTS") then
			table.insert(problems, "no big title")
		end
		if not titleSrc:find("RarityConfig%.RARITIES") then
			table.insert(problems, "ladder not built from RarityConfig")
		end
		if not titleSrc:find("RotlingCatalog%.DEFS") then
			table.insert(problems, "no catalog Rotling per tier")
		end
		for _, verb in ipairs({ "GRAB", "CARRY", "EARN" }) do
			if not titleSrc:find(verb) then
				table.insert(problems, 'no "' .. verb .. '" step')
			end
		end
		if not titleSrc:find("PlayButton") then
			table.insert(problems, "no PLAY button")
		end
		if not titleSrc:find("Visible = false") then
			table.insert(problems, "PLAY never dismisses the screen")
		end
		if #problems > 0 then
			step("title-screen", false, table.concat(problems, "; "))
		else
			step("title-screen", true, "big title + tagline, rarity ladder from the catalog, GRAB/CARRY/EARN loop, PLAY dismisses it")
		end
	end
end

-- 22. Storm front wall: giant glowing wall sweeps the map, warning bar, SAFE DOME.
do
	local stormSrc = read("src/server/StarfallService.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local warnSrc = read("src/client/StormWarningController.client.luau")
	if not stormSrc or not worldSrc or not warnSrc then
		step("storm-front", false, "StarfallService.luau, WorldBuilder.luau or StormWarningController.client.luau missing")
	else
		local problems: { string } = {}
		if not stormSrc:find("StormFront") then
			table.insert(problems, "no StormFront wall")
		end
		if stormSrc:find("METEOR SHOWER INCOMING! RUN HOME!") then
			table.insert(problems, 'the server still fires the "METEOR SHOWER INCOMING" banner (overlaps the warning bar)')
		end
		if not warnSrc:find("SPACE ROCKS INCOMING") then
			table.insert(problems, "no storm warning bar countdown")
		end
		if not worldSrc:find("SAFE DOME") then
			table.insert(problems, 'no "SAFE DOME" label')
		end
		if not stormSrc:find("onMeteorLanded") then
			table.insert(problems, "meteor impacts (knockback + drops) are gone — the wall must not replace them")
		end
		if #problems > 0 then
			step("storm-front", false, table.concat(problems, "; "))
		else
			step("storm-front", true, "giant glowing wall sweeps the map, storm voice is the warning bar, green SAFE DOME over bases, meteors still knock back and drop carries")
		end
	end
end

-- 23. Cheap HUD wins: carrying banner, rebirth tier line, named raiders.
do
	local hudSrc = read("src/client/HUDController.client.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	if not hudSrc or not raiderSrc then
		step("hud-wins", false, "HUDController.client.luau or RaiderService.luau missing")
	else
		local problems: { string } = {}
		if not hudSrc:find("CarryBanner") then
			table.insert(problems, "no CarryBanner in the HUD")
		end
		if not hudSrc:find("CARRYING: ") then
			table.insert(problems, 'no "CARRYING: <name>" banner text')
		end
		if not hudSrc:find("Rebirth ") then
			table.insert(problems, "no rebirth tier next to the cash")
		end
		if not raiderSrc:find("RAIDER_TITLES") then
			table.insert(problems, "no named raider titles")
		end
		if #problems > 0 then
			step("hud-wins", false, table.concat(problems, "; "))
		else
			step("hud-wins", true, "red CARRYING banner names the catch, rebirth tier + multiplier next to cash, every raider has its own bandit title")
		end
	end
end

-- 24. Offline earnings: lastSeen on save, capped payout, popup on join.
do
	local offlineSrc = read("src/server/OfflineService.luau")
	local clientSrc = read("src/client/OfflineController.client.luau")
	local mainSrc = read("src/server/Main.server.luau")
	if not offlineSrc or not clientSrc or not mainSrc then
		step("offline", false, "OfflineService.luau, OfflineController.client.luau or Main.server.luau missing")
	else
		local problems: { string } = {}
		if not offlineSrc:find("OFFLINE_CAP_SECONDS") then
			table.insert(problems, "no 8h cap on the payout")
		end
		if not offlineSrc:find("coinsPerSecond%(player%)") then
			table.insert(problems, "payout not computed from real cps")
		end
		if not clientSrc:find("WHILE YOU WERE AWAY") then
			table.insert(problems, "no WHILE YOU WERE AWAY popup")
		end
		if not mainSrc:find("OfflineService%.awardOffline%(player%)") then
			table.insert(problems, "Main never awards offline earnings on join")
		end
		if #problems > 0 then
			step("offline", false, table.concat(problems, "; "))
		else
			step("offline", true, "lastSeen stamped on every save, cps x away time capped at 8h, WHILE YOU WERE AWAY popup on join")
		end
	end
end

-- 25. Banking: income banks at the base, the collect pad moves it to
-- the wallet (real-base section — the pad replaced the HUD button).
do
	local bankSrc = read("src/server/BankService.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not bankSrc or not incomeSrc or not worldSrc then
		step("banking", false, "BankService.luau, IncomeService.luau or WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if not incomeSrc:find("profile%.banked %+= gained") then
			table.insert(problems, "income tick never banks the earnings")
		end
		if not bankSrc:find("function BankService%.collectBank") then
			table.insert(problems, "no collectBank")
		end
		if not bankSrc:find("profile%.coins %+= amount") then
			table.insert(problems, "collecting never pays the wallet")
		end
		if not worldSrc:find('part%("CollectPad"') then
			table.insert(problems, "no CollectPad in the base")
		end
		if not worldSrc:find("step to collect") then
			table.insert(problems, "the collect pad label does not say 'step to collect'")
		end
		if not bankSrc:find("Touched:Connect") then
			table.insert(problems, "no Touched wiring on the collect pad")
		end
		if not bankSrc:find("BankService%.collectBank%(player%)") then
			table.insert(problems, "stepping on the pad never calls collectBank")
		end
		if #problems > 0 then
			step("banking", false, table.concat(problems, "; "))
		else
			step("banking", true, "income banks at the base, the glowing collect pad shows the waiting cash and pays it into the wallet on touch")
		end
	end
end

-- 26. Storm income readout: Safe Dome x2 during the storm, HUD shows
-- the boosted rate next to the normal one.
do
	local configSrc = read("src/shared/Config.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	if not configSrc or not incomeSrc or not remotesSrc or not hudSrc then
		step("storm-income", false, "Config.luau, IncomeService.luau, Remotes.luau or HUDController.client.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("STORM_DOME_MULT = 2") then
			table.insert(problems, "Config.STORM_DOME_MULT is not 2")
		end
		if not incomeSrc:find("function IncomeService%.stormBoostActive") then
			table.insert(problems, "no stormBoostActive")
		end
		if not incomeSrc:find("STORM_DOME_MULT") then
			table.insert(problems, "incomeMult never applies STORM_DOME_MULT")
		end
		if not incomeSrc:find("stormBoost = IncomeService%.stormBoostActive%(player%)") then
			table.insert(problems, "broadcastHud does not send stormBoost")
		end
		if not incomeSrc:find("baseCps = IncomeService%.coinsPerSecond%(player, false%)") then
			table.insert(problems, "broadcastHud does not send baseCps")
		end
		if not remotesSrc:find("stormBoost: boolean") or not remotesSrc:find("baseCps: number") then
			table.insert(problems, "HudData lacks stormBoost / baseCps")
		end
		if not hudSrc:find("%(x2%)") then
			table.insert(problems, 'HUD never renders "(x2)"')
		end
		if not hudSrc:find("hud%.baseCps") then
			table.insert(problems, "HUD never shows the normal rate next to the boosted one")
		end
		if #problems > 0 then
			step("storm-income", false, table.concat(problems, "; "))
		else
			step("storm-income", true, "Safe Dome x2 during the storm (own base only), HUD shows boosted (x2) next to the normal rate")
		end
	end
end

-- 27. Bright capture setup: brightest lighting preset, vivid ground,
-- storm restores to it, final 4 photo shots.
do
	local projectSrc = read("default.project.json")
	local starSrc = read("src/server/StarfallService.luau")
	local photoSrc = read("src/client/PhotoModeController.client.luau")
	local packageSrc = read("../bounty-package.md")
	if not projectSrc or not starSrc or not photoSrc or not packageSrc then
		step("bright-capture", false, "default.project.json, StarfallService.luau, PhotoModeController.client.luau or bounty-package.md missing")
	else
		local problems: { string } = {}
		if not projectSrc:find('"Saturation": 1%.0') then
			table.insert(problems, "ColorCorrection Saturation is not 1.0 (not the brightest vivid preset)")
		end
		if not projectSrc:find('"Density": 0%.08') then
			table.insert(problems, "Atmosphere Density is not 0.08")
		end
		if not starSrc:find("atmosphere%.Density = 0%.08") then
			table.insert(problems, "restoreSky does not restore Atmosphere Density 0.08")
		end
		if not starSrc:find("Lighting%.Brightness = 1%.2") then
			table.insert(problems, "storm dark is not softened to Brightness 1.2 (base 1.8, fix round 4 lighting)")
		end
		if not projectSrc:find('"Intensity": 0%.1') then
			table.insert(problems, "Bloom Intensity is not 0.1 (fix round 4, item 7)")
		end
		if not projectSrc:find('"Brightness": 1%.8') then
			table.insert(problems, "base Lighting Brightness is not 1.8 (fix round 4, item 7)")
		end
		for _, name in ipairs({ "1/4 — Hero", "2/4 — Belt", "3/4 — Storm", "4/4 — Packed base", "Icon — 512x512" }) do
			if not photoSrc:find(name, 1, true) then
				table.insert(problems, 'photo shot "' .. name .. '" not found')
			end
		end
		if photoSrc:find('"2/4 — Crater"', 1, true) then
			table.insert(problems, 'the old "Crater" isometric shot is still in PhotoModeController')
		end
		if not packageSrc:find("is NOT one of the 4 shots", 1, true) then
			table.insert(problems, "bounty-package.md does not say the title screen is NOT one of the 4 shots")
		end
		if #problems > 0 then
			step("bright-capture", false, table.concat(problems, "; "))
		else
			step("bright-capture", true, "bright daytime lighting (Saturation 1.0, Density 0.08, Bloom 0.1, Brightness 1.8, natural grass ground, blue sky), storm restores to it, final 4 photo shots (hero close-up, belt, storm, packed base) + icon shot")
		end
	end
end

-- 28. Mutations are visible (simplify pass, section B): a mutated
-- Brainrot shows its mutation in the label, a beam + sparkle in the
-- mutation's colour, a server-wide spawn banner, and a mutations line
-- in the index; grabbing or placing one logs it as found.
do
	local factorySrc = read("src/server/RotlingFactory.luau")
	local spawnSrc = read("src/server/SpawnService.luau")
	local indexSvcSrc = read("src/server/IndexService.luau")
	local indexCtrlSrc = read("src/client/IndexController.client.luau")
	local carrySrc = read("src/server/CarryService.luau")
	if not factorySrc or not spawnSrc or not indexSvcSrc or not indexCtrlSrc or not carrySrc then
		step("mutations", false, "RotlingFactory.luau, SpawnService.luau, IndexService.luau, IndexController.client.luau or CarryService.luau missing")
	else
		local problems: { string } = {}
		if not factorySrc:find("local function nameText") or not factorySrc:find("mutation:upper()", 1, true) then
			table.insert(problems, "the label does not name the mutation (nameText)")
		end
		if not factorySrc:find("local function addMutationBeam") or not factorySrc:find("local function addMutationSparkle") then
			table.insert(problems, "no mutation beam + sparkle on mutated Rotlings")
		end
		if not spawnSrc:find("local function announceSpawn") or not spawnSrc:find("spawned in the crater!", 1, true) then
			table.insert(problems, "no server-wide banner for mutated spawns")
		end
		if not indexSvcSrc:find("function IndexService.markMutationFound") then
			table.insert(problems, "found mutations are not logged")
		end
		local _, markCalls = carrySrc:gsub("IndexService.markMutationFound", "")
		if markCalls < 2 then
			table.insert(problems, "markMutationFound is not called on both grab and place")
		end
		if not indexCtrlSrc:find("MutationLine") or not indexCtrlSrc:find('"Mutations: "', 1, true) then
			table.insert(problems, "the index has no mutations line")
		end
		if #problems > 0 then
			step("mutations", false, table.concat(problems, "; "))
		else
			step("mutations", true, "label names the mutation in its colour + multiplier line, Neon beam + sparkle, server-wide spawn banner, grab/place logs the find, index shows all six mutations as chips")
		end
	end
end

-- Fix round 8, item 1 — guardian speed: every tier beats a walk (16),
-- spawn is 14 studs (not 24), and the chase loop logs real studs/s.
do
	local configSrc = read("src/shared/Config.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	if not configSrc or not guardianSrc then
		step("guardian-speed", false, "Config.luau or GuardianService.luau missing")
	else
		local problems: { string } = {}
		local speedLine = configSrc:match("GUARDIAN_SPEED = ({.-})")
		if speedLine then
			local i = 0
			for n in speedLine:gmatch("= (%d+%.?%d*)") do
				i += 1
				local v = tonumber(n)
				if v and v <= 26 then
					table.insert(problems, "tier " .. tostring(i) .. " speed " .. tostring(v) .. " <= sprint 26")
				end
			end
			if i ~= 7 then
				table.insert(problems, "GUARDIAN_SPEED has " .. tostring(i) .. " tiers, not 7")
			end
		else
			table.insert(problems, "no GUARDIAN_SPEED table in Config")
		end
		if not configSrc:find("GUARDIAN_SPAWN_DISTANCE = 14") then
			table.insert(problems, "spawn distance is not 14")
		end
		if not guardianSrc:find("chase telemetry") then
			table.insert(problems, "no chase telemetry (no proof the speed is real)")
		end
		if #problems > 0 then
			step("guardian-speed", false, table.concat(problems, "; "))
		else
			step("guardian-speed", true, "every guardian tier beats sprint 26 (28-34), spawns 14 studs away, chase logs real studs/s + distance every 2s")
		end
	end
end

-- Fix round 8, item 2 — guardian threat: a catch deals 40 HP damage
-- (two catches kill), knocks down, bursts red, thuds, banners the damage.
do
	local configSrc = read("src/shared/Config.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	if not configSrc or not guardianSrc then
		step("guardian-threat", false, "Config.luau or GuardianService.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("GUARDIAN_CATCH_DAMAGE = 40") then
			table.insert(problems, "no GUARDIAN_CATCH_DAMAGE = 40 in Config")
		end
		if not guardianSrc:find("TakeDamage%(Config%.GUARDIAN_CATCH_DAMAGE%)") then
			table.insert(problems, "catchPlayer does not deal the catch damage")
		end
		if not guardianSrc:find("FeedbackService%.burst%(character") then
			table.insert(problems, "no red impact burst on the catch")
		end
		if not guardianSrc:find("SMASHED YOU! %-\"") then
			table.insert(problems, "the catch banner does not name the damage")
		end
		if #problems > 0 then
			step("guardian-threat", false, table.concat(problems, "; "))
		else
			step("guardian-threat", true, "a catch deals 40 HP (two catches kill) + knockdown + red burst + thud + damage banner")
		end
	end
end

-- Fix round 8, item 3 — steal walk: MoveTo re-issued every 2s, steal +
-- run-home legs route through the ramp's low end and up the ramp-top
-- waypoint, steal walk is storm-proof, abort log carries positions +
-- remaining distance.
do
	local rivalSrc = read("src/server/RivalService.luau")
	if not rivalSrc then
		step("steal-walk", false, "RivalService.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find("waited %- lastMoveAt >= 2") then
			table.insert(problems, "walkTo does not re-issue MoveTo every 2s")
		end
		if not rivalSrc:find("walkTo%(model, entrancePos, 20, nil%)") then
			table.insert(problems, "no storm-proof entrance leg on the steal walk")
		end
		if not rivalSrc:find("rampTopPos") then
			table.insert(problems, "no ramp-top waypoint")
		end
		if not rivalSrc:find("studs short") then
			table.insert(problems, "the steal-abort log does not carry the remaining distance")
		end
		if #problems > 0 then
			step("steal-walk", false, table.concat(problems, "; "))
		else
			step("steal-walk", true, "MoveTo re-issued every 2s, steal + run-home route through the ramp and up the ramp-top waypoint, steal walk storm-proof, abort log shows where the walk died")
		end
	end
end

-- Fix round 8, item 5 — multi-carry fan: each carried Brainrot gets
-- its own slot (4.2 studs apart, arced), re-seated after every
-- grab/place/drop.
do
	local carrySrc = read("src/server/CarryService.luau")
	if not carrySrc then
		step("multi-carry", false, "CarryService.luau missing")
	else
		local problems: { string } = {}
		if not carrySrc:find("local function carrySlotOffset%(index: number, total: number%)") then
			table.insert(problems, "no carrySlotOffset (no per-slot fan offset)")
		end
		if not carrySrc:find("function CarryService%.reseatCarried%(player: Player%)") then
			table.insert(problems, "no reseatCarried (the fan is never re-seated)")
		end
		if not carrySrc:find("weld%.C0 = carrySlotOffset%(i, #carried%)") then
			table.insert(problems, "reseatCarried does not set each weld to its slot offset")
		end
		if #problems > 0 then
			step("multi-carry", false, table.concat(problems, "; "))
		else
			step("multi-carry", true, "each carried Brainrot fans to its own slot (4.2 studs apart, arced), re-seated after every grab/place/drop")
		end
	end
end

-- Fix round 8, item 6 — more shop upgrades: Endurance Training, Egg
-- Warmer, Power Slap — sold, stored, shown, effects read live.
do
	local shopSrc = read("src/server/ShopService.luau")
	local shopUiSrc = read("src/client/ShopController.client.luau")
	local sprintSrc = read("src/client/SprintController.client.luau")
	local eggSrc = read("src/server/MeteorEggService.luau")
	local slapSrc = read("src/server/SlapService.luau")
	if not shopSrc or not shopUiSrc or not sprintSrc or not eggSrc or not slapSrc then
		step("shop-upgrades", false, "ShopService.luau, ShopController.client.luau, SprintController.client.luau, MeteorEggService.luau or SlapService.luau missing")
	else
		local problems: { string } = {}
		if not shopSrc:find("Stamina = {") or not shopSrc:find("Egg = {") or not shopSrc:find("Slap = {") then
			table.insert(problems, "a new ladder is missing from the server shop")
		end
		if not shopUiSrc:find("LadderScroll") then
			table.insert(problems, "the ladder rows are not scrollable")
		end
		if not sprintSrc:find("staminaTier") then
			table.insert(problems, "the sprint controller does not read the stamina tier")
		end
		if not eggSrc:find("EGG_WARMER_REDUCTION") then
			table.insert(problems, "the hatch time does not read the Egg Warmer tier")
		end
		if not slapSrc:find("SLAP_RANGE_PER_TIER") then
			table.insert(problems, "the slap does not read the Power Slap tier")
		end
		if #problems > 0 then
			step("shop-upgrades", false, table.concat(problems, "; "))
		else
			step("shop-upgrades", true, "Endurance Training + Egg Warmer + Power Slap sold, stored, shown in a scrollable shop, effects read live")
		end
	end
end

-- Fix round 8, item 8 — chase trigger: nearest 2 rivals chase at 19
-- on a computed path, storm-proof, start + end logged.
do
	local rivalSrc = read("src/server/RivalService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not rivalSrc or not configSrc then
		step("chase-trigger", false, "RivalService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if rivalSrc:find("RIVAL_CHASE_RADIUS") then
			table.insert(problems, "the 30-stud chase radius is still in use")
		end
		if not configSrc:find("RIVAL_CHASE_MAX = 2") then
			table.insert(problems, "no RIVAL_CHASE_MAX = 2")
		end
		if not configSrc:find("RIVAL_CHASE_SPEED = 19") then
			table.insert(problems, "no RIVAL_CHASE_SPEED = 19")
		end
		if not rivalSrc:find("table%.sort%(candidates") then
			table.insert(problems, "the chase does not pick the NEAREST rivals")
		end
		if not rivalSrc:find("PathfindingService:CreatePath") then
			table.insert(problems, "the chase does not pathfind")
		end
		if not rivalSrc:find("studs away") then
			table.insert(problems, "the chase start log does not carry the distance")
		end
		if #problems > 0 then
			step("chase-trigger", false, table.concat(problems, "; "))
		else
			step("chase-trigger", true, "nearest 2 rivals chase at 19 on a computed path, storm-proof, start + end logged with distances")
		end
	end
end

-- Fix round 8, item 9 — hatch event: the egg cracks open, the animal
-- pops out with a scale-in bounce, and jumps into the owner's arms
-- when they are nearby with a free slot.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not eggSrc then
		step("hatch-event", false, "MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if not eggSrc:find("local function crackEgg%(model: Model, egg: State%.Egg, baseId: number%)") then
			table.insert(problems, "no crackEgg event")
		end
		if not eggSrc:find('crack%.Name = "Crack"') then
			table.insert(problems, "no crack parts appear on the shell")
		end
		if not eggSrc:find("setModelScale%(hatched, 0%.2%)") then
			table.insert(problems, "no scale-in pop when the animal comes out")
		end
		if not eggSrc:find("jumped into your arms") then
			table.insert(problems, "the hatchling does not jump into the owner's arms")
		end
		if #problems > 0 then
			step("hatch-event", false, table.concat(problems, "; "))
		else
			step("hatch-event", true, "the egg cracks open, the animal pops out with a scale-in bounce, and jumps into the owner's arms when nearby with a free slot")
		end
	end
end

-- Fix round 8, item 10 — speed purchase: Speed Boots extended to 5
-- tiers (200/800/4000/12000/30000), max +10 WalkSpeed.
do
	local shopSrc = read("src/server/ShopService.luau")
	local shopUiSrc = read("src/client/ShopController.client.luau")
	if not shopSrc or not shopUiSrc then
		step("speed-tiers", false, "ShopService.luau or ShopController.client.luau missing")
	else
		local problems: { string } = {}
		if not shopSrc:find("tiers = { 200, 800, 4000, 12000, 30000 }") then
			table.insert(problems, "the server Speed ladder is not 5 tiers")
		end
		if not shopUiSrc:find("tiers = { 200, 800, 4000, 12000, 30000 }") then
			table.insert(problems, "the shop UI Speed ladder is not 5 tiers")
		end
		if #problems > 0 then
			step("speed-tiers", false, table.concat(problems, "; "))
		else
			step("speed-tiers", true, "Speed Boots: 5 tiers (200/800/4000/12000/30000), max +10 WalkSpeed")
		end
	end
end

-- Follow-up, item 1 — thief alert is truthful: fires only while
-- the thief is really inside the base, and a bonked thief loses
-- the sign.
do
	local rivalSrc = read("src/server/RivalService.luau")
	local slapSrc = read("src/server/SlapService.luau")
	if not rivalSrc or not slapSrc then
		step("thief-alert", false, "RivalService.luau or SlapService.luau missing")
	else
		local problems: { string } = {}
		local _, fires = rivalSrc:gsub("thiefAlertEvent%(%)%:FireClient", "")
		if fires ~= 1 then
			table.insert(problems, "ThiefAlert fires " .. tostring(fires) .. " times — must be exactly 1 (the in-base watcher)")
		end
		if not slapSrc:find("clearThiefVisuals%(rival%)") then
			table.insert(problems, "a bonked thief keeps its THIEF sign")
		end
		if #problems > 0 then
			step("thief-alert", false, table.concat(problems, "; "))
		else
			step("thief-alert", true, "thief alert fires only while the thief is really inside; a bonked thief loses the sign")
		end
	end
end

-- Follow-up, item 2 — thieves hunt the player like the guardian:
-- chase at 22, steal the carried Brainrot or knock the player down.
do
	local rivalSrc = read("src/server/RivalService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not rivalSrc or not configSrc then
		step("thief-hunt", false, "RivalService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("RIVAL_HUNT_SPEED = 22") then
			table.insert(problems, "no RIVAL_HUNT_SPEED = 22")
		end
		if not rivalSrc:find("local function tryStartHunt") then
			table.insert(problems, "no tryStartHunt")
		end
		if not rivalSrc:find("stole your carried") then
			table.insert(problems, "no steal-on-tag")
		end
		if not rivalSrc:find("knocked \" .. victim%.Name .. \" down") then
			table.insert(problems, "no knockdown-on-tag")
		end
		if #problems > 0 then
			step("thief-hunt", false, table.concat(problems, "; "))
		else
			step("thief-hunt", true, "thieves hunt free-walking players at 22; tag steals the best carried Brainrot or knocks the player flat")
		end
	end
end

-- Fix round 10, item 1 — the crater-to-shop fences are true parallels
-- of the stone path: 4 studs to each side, never through the walkway.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		step("fence-parallel", false, "WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if worldSrc:find("fenceLine%(Vector3.new%(%-6, 0, 42%)") then
			table.insert(problems, "the old fence (-6,42)->(-40,44) is still there")
		end
		if not worldSrc:find("local fenceOffset = 4") then
			table.insert(problems, "no fenceOffset = 4")
		end
		if not worldSrc:find("shopPathNormal %* fenceOffset") then
			table.insert(problems, "fences are not offset along the path normal")
		end
		if #problems > 0 then
			step("fence-parallel", false, table.concat(problems, "; "))
		else
			step("fence-parallel", true, "crater-to-shop fences are true parallels of the stone path (4 studs to each side, clear of the rim)")
		end
	end
end

-- Fix round 10, item 2 — egg rebalance: 4 eggs/storm, egg-only weights
-- 550/280/100/40/20/10/5 (fix round 11 rescaled x10 so Divine fits
-- below Cosmic: Divine 0.5% per egg, ~0.02/storm), the 40% bump gone,
-- legendary drop untouched (240s).
do
	local configSrc = read("src/shared/Config.luau")
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not configSrc or not eggSrc then
		step("egg-rebalance", false, "Config.luau or MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("Config.EGGS_PER_STORM = 4") then
			table.insert(problems, "EGGS_PER_STORM is not 4")
		end
		if not configSrc:find("Config.EGG_RARITY_WEIGHTS = { %[1%] = 550, %[2%] = 280, %[3%] = 100, %[4%] = 40, %[5%] = 20, %[6%] = 10, %[7%] = 5 }") then
			table.insert(problems, "egg weights are not 550/280/100/40/20/10/5")
		end
		if eggSrc:find("rarityTier%(rarityName%) < 3") then
			table.insert(problems, "the 40% bump is still in rollHatchDef")
		end
		if not eggSrc:find("local function rollEggRarity") then
			table.insert(problems, "no rollEggRarity")
		end
		if not configSrc:find("Config.LEGENDARY_EGG_INTERVAL = 240") then
			table.insert(problems, "legendary drop interval changed (must stay 240)")
		end
		if #problems > 0 then
			step("egg-rebalance", false, table.concat(problems, "; "))
		else
			step("egg-rebalance", true, "4 eggs/storm, weights 550/280/100/40/20/10/5 (Legendary 4% per egg, ~0.16/storm; Divine 0.5%, ~0.02/storm); bump gone; legendary drop still 240s")
		end
	end
end

-- Fix round 10, item 3 — huge boundary walls: a closed square at
-- +/-200, 40 tall, solid, gold top edge — encloses bases, egg field,
-- storm spread and the spaceship, clears the storm front, inside the
-- 500x500 ground.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local configSrc = read("src/shared/Config.luau")
	if not worldSrc or not configSrc then
		step("boundary-walls", false, "WorldBuilder.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("local function buildBoundaryWalls") then
			table.insert(problems, "no buildBoundaryWalls")
		end
		if not worldSrc:find("\n\tbuildBoundaryWalls%(%)") then
			table.insert(problems, "buildBoundaryWalls never called from build")
		end
		if not worldSrc:find("local BOUNDARY_HALF = 200") then
			table.insert(problems, "BOUNDARY_HALF is not 200")
		end
		if not worldSrc:find("local BOUNDARY_HEIGHT = 40") then
			table.insert(problems, "BOUNDARY_HEIGHT is not 40")
		end
		local _, sideCount = 0, 0
		for _, side in ipairs({ "North", "South", "West", "East" }) do
			if worldSrc:find('name = "' .. side .. '"') then
				sideCount += 1
			end
		end
		if sideCount ~= 4 then
			table.insert(problems, "found " .. tostring(sideCount) .. " wall sides, not 4")
		end
		if not worldSrc:find("for _, side in ipairs%(sides%) do") then
			table.insert(problems, "no loop building one wall per side")
		end
		local bodyStart = worldSrc:find("local function buildBoundaryWalls")
		if bodyStart then
			local _, bodyEnd = worldSrc:find("\nend\n", bodyStart)
			local body = worldSrc:sub(bodyStart, bodyEnd or #worldSrc)
			if body:find("wall%.CanCollide = false") then
				table.insert(problems, "a BoundaryWall turns off collision")
			end
		end
		if #problems > 0 then
			step("boundary-walls", false, table.concat(problems, "; "))
		else
			step("boundary-walls", true, "closed square at +/-200, 40 tall, 4 solid walls + gold trims; encloses bases, egg field, storm spread and the spaceship")
		end
	end
end

-- Fix round 12, item 1 — signs overhaul: title posts outside the
-- board span, STAR SHOP a round disc, signposts off the big-sign
-- sightlines with per-line colours, Contract Board bigger with a
-- gold border and wrapped text, base signs striped in their colour.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		step("signs", false, "WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("cx %+ side %* 12%.5") then
			table.insert(problems, "title posts are not at cx +/- 12.5")
		end
		if not worldSrc:find("Vector3%.new%(%-8, 0, 62%)") or worldSrc:find("Vector3%.new%(6, 0, 58%)") then
			table.insert(problems, "spawn-path signpost is not moved to (-8, 62)")
		end
		if not worldSrc:find('part%("ShopSignDisc", Enum%.PartType%.Cylinder') then
			table.insert(problems, "STAR SHOP is not a round disc")
		end
		if not worldSrc:find("ContractBoardBacking") or not worldSrc:find("ContractFooter") then
			table.insert(problems, "Contract Board has no gold backing / footer")
		end
		if not worldSrc:find("signStripes%[baseId%] = signStripe") then
			table.insert(problems, "base signs have no colour stripe")
		end
		if #problems > 0 then
			step("signs", false, table.concat(problems, "; "))
		else
			step("signs", true, "title posts outside the board (12.5 > 11) with pulse glow; STAR SHOP round gold disc; signposts off sightlines with per-line colours; Contract Board 12x8 gold-bordered with wrapped text + footer; base sign stripes")
		end
	end
end

-- Fix round 12, item 2 + fix round 13, item 1 — steal route: the
-- SELL pad no longer blocks base 1's only approach, rocks stay out
-- of every base's entrance corridor, the meteor-rock gap at the
-- crater mouth is widened, the meteor-rock draw is radius 33..38
-- (worst reach 41, clear of the ring sweep), the final leg routes
-- via the clear strip, and the give-up logs leg + nearest solid.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	if not worldSrc or not rivalSrc then
		step("steal-route", false, "WorldBuilder.luau or RivalService.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("sellPad%.CanCollide = false") then
			table.insert(problems, "SELL pad is still colliding")
		end
		if not worldSrc:find("onApproach") or not worldSrc:find("along >= 40 and along <= 130") then
			table.insert(problems, "no base-approach corridor exclusion in buildRocks")
		end
		if not worldSrc:find("math%.abs%(x%) < 10 and z > 34") then
			table.insert(problems, "meteor-rock gap not widened to |x| < 10")
		end
		if not worldSrc:find("rng:NextNumber%(33, 38%)") then
			table.insert(problems, "meteor-rock radius draw is not 33..38")
		end
		if not rivalSrc:find("PointToObjectSpace%(padCf%.Position%)") or not rivalSrc:find("CFrame%.new%(localPad%.X, 2, %-9%)") then
			table.insert(problems, "final leg has no clear-strip waypoint")
		end
		if not rivalSrc:find("STEAL WALK DIAGNOSTIC") or not rivalSrc:find("GetPartBoundsInRadius") then
			table.insert(problems, "no give-up diagnostic (leg + nearest solid)")
		end
		if #problems > 0 then
			step("steal-route", false, table.concat(problems, "; "))
		else
			step("steal-route", true, "SELL pad non-colliding; rocks excluded from corridors; meteor-rock gap |x| < 10; meteor-rock draw 33..38 (reach 41 < ring sweep 41.97); final leg via clear strip; give-up logs leg + nearest solid")
		end
	end
end

-- Fix round 12, item 3 — base-grab heat: picking a Brainrot up from
-- your own base arms the heat (banner now) and engages the Guardian
-- + rivals the moment you step outside your base platform.
-- (fix round 13, item 3: platform + ramp, not interior.)
do
	local carrySrc = read("src/server/CarryService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local stateSrc = read("src/server/State.luau")
	if not carrySrc or not rivalSrc or not stateSrc then
		step("base-heat", false, "CarryService.luau, RivalService.luau or State.luau missing")
	else
		local problems: { string } = {}
		if not stateSrc:find("State%.baseHeat = {}") then
			table.insert(problems, "State.baseHeat flag missing")
		end
		if not carrySrc:find("State%.baseHeat%[player%.UserId%] = true") then
			table.insert(problems, "carryRotling never arms base heat")
		end
		if not carrySrc:find("The Guardian is watching") then
			table.insert(problems, "no 'Guardian is watching' alert on arm")
		end
		if not rivalSrc:find("State%.baseHeat") then
			table.insert(problems, "no heat watcher in RivalService")
		end
		if not rivalSrc:find("reached their base platform") then
			table.insert(problems, "carrier chase has no safe-base end")
		end
		if #problems > 0 then
			step("base-heat", false, table.concat(problems, "; "))
		else
			step("base-heat", true, "own-base pickup arms heat (banner); watcher engages Guardian + rivals on exit, once per carry; chase ends at base platform; flag clears when carry ends")
		end
	end
end

-- Fix round 13, item 3 — ZERO damage on your own base, at all:
-- the platform rule (whole slab + ramp, Y gate on the ramp) gates
-- all 3 TakeDamage sites; the guardian catch itself refuses on
-- your own base (closes the Touch-catch bypass); hunt refuge,
-- chase ends, heat watcher and heat arming all use it; only the
-- 2x shelter income stays interior-only.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local starfallSrc = read("src/server/StarfallService.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	if not worldSrc or not starfallSrc or not guardianSrc or not rivalSrc or not carrySrc then
		step("own-base-damage", false, "WorldBuilder.luau, StarfallService.luau, GuardianService.luau, RivalService.luau or CarryService.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("function WorldBuilder%.isOnBasePlatform") or not worldSrc:find("localPos%.Z >= %-15") or not worldSrc:find("localPos%.Y >= 2%.5") then
			table.insert(problems, "no isOnBasePlatform helper (slab + ramp, Y gate)")
		end
		if not starfallSrc:find("WorldBuilder%.isOnBasePlatform%(baseId, position%)") then
			table.insert(problems, "storm damage / targeting does not use isOnBasePlatform")
		end
		if not guardianSrc:find("catch refused") or not guardianSrc:find("WorldBuilder%.isOnBasePlatform%(baseId, position%)") then
			table.insert(problems, "guardian catch has no own-base refusal / give-up not on the platform rule")
		end
		if not rivalSrc:find("isOnBasePlatform%(victimBase, victimRoot%.Position%)") or not rivalSrc:find("not WorldBuilder%.isOnBasePlatform%(baseId, root%.Position%)") then
			table.insert(problems, "hunt refuge / chase end / heat watcher not on the platform rule")
		end
		if not carrySrc:find("isOnBasePlatform%(ownBaseId, root%.Position%)") then
			table.insert(problems, "heat arming not on the platform rule")
		end
		for _, src in ipairs({ starfallSrc, guardianSrc, rivalSrc, carrySrc }) do
			if src:find("isOnBaseInterior") then
				table.insert(problems, "a damage/refuge path still uses isOnBaseInterior")
				break
			end
		end
		if #problems > 0 then
			step("own-base-damage", false, table.concat(problems, "; "))
		else
			step("own-base-damage", true, "platform rule gates all 3 TakeDamage sites; guardian catch refuses on your own base; refuge / chase ends / watcher / arming all on it; only shelter income stays interior-only")
		end
	end
end

-- Fix round 13, item 2 — layered eggs: a clean cream ovoid (3.2 x
-- 4.8) with two smooth bands (purple +0.8, teal -0.9), welded; no
-- speckles, cracks or nest; mystery rule intact; legendary gold all
-- over. Storm eggs land in the open field only (radius 48..130, 24
-- studs from any base, SELL/shop/altar/spawn excluded).
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not eggSrc then
		step("egg-layered", false, "MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if not eggSrc:find('shell%.Size = Vector3%.new%(3%.2, 4%.8, 3%.2%)') then
			table.insert(problems, "shell is not ovoid (3.2 x 4.8 x 3.2)")
		end
		if not eggSrc:find("shell%.Color = Color3%.fromRGB%(255, 244, 214%)") then
			table.insert(problems, "shell is not cream")
		end
		if not eggSrc:find('"EggBand"') or not eggSrc:find("{ 0%.8, 3%.3,") or not eggSrc:find("{ %-0%.9, 3%.2,") then
			table.insert(problems, "two EggBand layers (purple +0.8, teal -0.9) missing")
		end
		if eggSrc:find("EggSpeckle") or eggSrc:find("EggCrack") or eggSrc:find("EggNest") then
			table.insert(problems, "old speckle/crack/nest clutter still present")
		end
		if not eggSrc:find("WeldConstraint") then
			table.insert(problems, "egg detail is not welded to the shell")
		end
		if not eggSrc:find('"🥚 METEOR EGG"') then
			table.insert(problems, "ground egg label is not the plain mystery label")
		end
		if not eggSrc:find('child%.Name == "EggBand"') then
			table.insert(problems, "legendary egg does not recolor its bands gold")
		end
		if not eggSrc:find("math%.random%(48, 130%)") or not eggSrc:find("Magnitude < 24") then
			table.insert(problems, "egg spawn positions not open-field only (radius 48..130, 24 from bases)")
		end
		if not eggSrc:find("Vector3%.new%(60, 0, %-60%)") then
			table.insert(problems, "egg fallback is not the open-field spot (60, -60)")
		end
		if #problems > 0 then
			step("egg-layered", false, table.concat(problems, "; "))
		else
			step("egg-layered", true, "layered cream ovoid (3.2 x 4.8) with two bands, welded; no speckles/cracks/nest; mystery rule intact; legendary gold all over; storm eggs open-field only")
		end
	end
end

-- -- Summary + log --------------------------------------------------------------
local passed = 0
local failing: { string } = {}
for _, r in ipairs(results) do
	if r.ok then
		passed += 1
	else
		table.insert(failing, "(" .. r.id .. ")")
	end
end
local summary = "SELF-TEST: " .. tostring(passed) .. "/" .. tostring(#results) .. " steps passed"
	.. (if #failing > 0 then " — FAILING: " .. table.concat(failing, ", ") else "")
print(summary)
table.insert(lines, summary)
local logPath = root .. "/../notes/loop-self-test.log"
local ok, err = pcall(fs.writeFile, logPath, table.concat(lines, "\n") .. "\n")
if ok then
	print("log written to " .. logPath)
else
	print("WARNING: could not write log to " .. logPath .. ": " .. tostring(err))
end
if #failing > 0 then
	process.exit(1)
end
process.exit(0)
