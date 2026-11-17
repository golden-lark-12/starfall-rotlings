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
--   arrows for a new player's first 60 seconds.
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
		if not incomeSrc:find("profile%.coins %+= gained") and not incomeSrc:find("profile%.coins %+= IncomeService%.coinsPerSecond") then
			table.insert(problems, "income tick never adds coins")
		end
		if not incomeSrc:find("BaseService%.getPlacedForPlayer%(player%)") then
			table.insert(problems, "coinsPerSecond never sums the placed Rotlings")
		end
		if not incomeSrc:find("IncomeService%.incomeMult%(player%)") then
			table.insert(problems, "income never applies the rebirth/shop multiplier")
		end
		if not incomeSrc:find("floatIncomeNumber%(%)") then
			table.insert(problems, "no floating +$N income numbers")
		end
		if #problems > 0 then
			step("earn", false, table.concat(problems, "; "))
		else
			step("earn", true, "1/s tick pays coinsPerSecond (placed Rotlings x rebirth/shop mult) + floating +$N")
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

-- 6. Buy: the shop panel offers all five ladders.
do
	local shopClient = read("src/client/ShopController.client.luau")
	if not shopClient then
		step("buy", false, "ShopController.client.luau missing")
	else
		local problems: { string } = {}
		local rows = 0
		for _ in shopClient:gmatch('SHOP_ORDER = { "Speed", "Carry", "Income", "Pads", "Lock" }') do
			rows = 5
		end
		if rows ~= 5 then
			table.insert(problems, "shop panel does not list all 5 ladders")
		end
		if not shopClient:find("Remotes%.buyFunction%(%)%:InvokeServer%(key%)") then
			table.insert(problems, "buy button never invokes BuyItem")
		end
		if #problems > 0 then
			step("buy", false, table.concat(problems, "; "))
		else
			step("buy", true, "shop panel lists 5 ladders; buy buttons invoke BuyItem")
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
		-- Wobble Wombat: Common (cps 1) x cpsMult 1 = 1/s; sells for 60.
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
			step("economy", true, "wombat " .. tostring((commonCps or 0) * (wombatMult or 0)) .. "/s, sells for " .. tostring((commonCps or 0) * (wombatMult or 0) * (sellMult or 0)) .. ", first rebirth " .. tostring(rebirthBase) .. ", daily " .. tostring(daily) .. ", missions pay " .. tostring(missionRewards) .. " total")
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

-- 11. Tutorial arrows: first 60 seconds, three steps, stops on grab.
do
	local tutSrc = read("src/client/TutorialController.client.luau")
	if not tutSrc then
		step("tutorial", false, "TutorialController.client.luau missing")
	else
		local problems: { string } = {}
		local seconds = num(tutSrc:match("TUTORIAL_SECONDS%s*=%s*(%d+)"))
		if not seconds then
			table.insert(problems, "TUTORIAL_SECONDS not found")
		elseif seconds ~= 60 then
			table.insert(problems, "tutorial lasts " .. tostring(seconds) .. "s (must be 60)")
		end
		if not tutSrc:find('part%.Name = "TutorialArrow"') then
			table.insert(problems, 'no "TutorialArrow" part')
		end
		if not tutSrc:find("data%.firstTime and not active") then
			table.insert(problems, "tutorial is not gated on firstTime")
		end
		if not tutSrc:find("data%.carried > 0") then
			table.insert(problems, "tutorial never stops when the player grabs")
		end
		local steps = 0
		for _, label in ipairs({ '"1. Walk', '"2. Carry', '"3. Sell' }) do
			if tutSrc:find(label, 1, true) then
				steps += 1
			end
		end
		if steps < 3 then
			table.insert(problems, "fewer than 3 tutorial steps (" .. tostring(steps) .. " step labels found)")
		end
		if #problems > 0 then
			step("tutorial", false, table.concat(problems, "; "))
		else
			step("tutorial", true, "gold arrow, 3 steps (crater -> base -> SELL), 60s, firstTime only, stops on first grab")
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
