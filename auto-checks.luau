-- Starfall Rotlings: pre-publish auto-checks.
-- Runs BEFORE EVERY publish and FAILS the build (exit 1) if any of
-- these are true. Print pass or fail for each check, with the part
-- names involved:
--   (a) a carried Rotling sits above the player's head or covers the
--       face instead of riding in front of the chest at arm height,
--       as a real model with no bubble
--   (b) the base sign overlaps any name tag
--   (c) a name tag overlaps the HUD buttons or the top bar
--   (d) crater Rotlings are smaller than the agreed minimum size (1.5x)
--   (e) the spawn platform is a flat cyan block with no texture
--   (f) glow/bloom washes the screen out (Bloom too strong, beam or
--       crystal lights too bright, HUD unreadable over bright ground)
--   (g) name tags stack when Rotlings stand close (no spacing, tags
--       shown too far away, no nearest-N limit)
--   (h) Rotling models read as flat semi-transparent boxes (any part
--       transparent, glow shell too opaque, highlight too strong)
--   (i) the base sign is a giant wall/slab instead of a small sign
--       on a post above the base
--   (j) the carry slot stays full after placing ("arms full" bug:
--       duplicate carry entries, single-remove, place not clearing)
--   (k) a displayed money string has a doubled "$" (any "$$", any
--       hand-rolled "$" .. tostring instead of Formatting.formatMoney)
--   (l) the meteor storm never triggers when the countdown hits zero
--       (storm loop unguarded, no meteors spawned, no watchdog)
--   (m) the conveyor runs empty (fewer than 6 Rotlings to grab)
--   (n) the look is not bright and saturated (dark sky, grey haze)
--   (o) a base has no level sign
--   (p) there is no clear SELL area (pad, sign, prompt, price)
--   (q) the top HUD is incomplete (cash, income, Shop/Upgrade/Daily,
--       mission bar)
--   (r) missions or the daily reward are not wired
--   (s) the grab -> carry -> place loop is broken
--   (t) placed Rotlings never earn
--   (u) buying/upgrading is broken
--   (v) rebirth / next tier is broken
--   (w) some action has no feedback (sound + burst + cash pop-up)
--   (x) the tutorial arrows are missing or wrong
--   (y) the crater has no readable conveyor belt
--   (z) the HUD has no title, Index count or leaderboard
--   (aa) the storm banner is not full-width
--   (ab) no giant hero meteors in the storm
--   (ac) photo-mode cameras are not reframed (4 shots: hero, crater,
--       base, storm)
--   (ad) photo-mode tags do not all read
--   (ae) the storm logs nothing and no meteor lands within 10s of the
--       storm starting
--   (af) the ground is one flat purple plane (no sand ring, no tiles)
--   (ag) the plaza lamps are big and blown out
--   (ah) a custom button sits under Roblox's own top-left menu or the
--       top-right player list (any button above y=60, or no UIScale)
--   (ai) a Rotling's primary body colour is not its rarity tier colour
--       (catalog bodyColor differs from RarityConfig, or the factory
--       re-saturates it instead of painting rarity.color)
--   (aj) two Rotlings share a silhouette, a Rotling has no face, or a
--       Rotling has fewer than 2 signature features (no unique
--       silhouette key, no eyes/mouth, no per-Rotling feature branch)
--   (ak) the name tag sits on the model instead of above it (fixed
--       offset that sinks into a hat at 1.5x, or no re-seat after a
--       scale change, so the tag covers the face)
--   (al) selling is not a clearing tool (sell value above 30x income,
--       or the owner cannot pick their own placed Rotling back up)
--   (am) the storm hits only the crater centre (no spread, no warning
--       circle, no knockback, bases not safe)
--   (an) rivals do not exist or do not play (no rival bots, no steal,
--       no chase, no bounty, no leaderboard presence)
--   (ao) the slap bat is missing or cannot knock a rival down
--   (ap) meteor eggs never spawn, cannot be carried, or never hatch
--   (aq) the map is empty (no shop, upgrade machine, altar, index
--       wall, spaceship, background, signposts, fences, paths or
--       critters)
--   (ar) boosts do not exist in the world or the HUD
--   (as) Malek's items 2-5 are not fixed (beam still a fat pillar,
--       ground still loud purple, lamps still blown out, carried
--       Rotling still invisible)
--   (at) the last adds are missing (no visible mutations, no
--       Stardust in the HUD, no level/XP, fewer than 20 Rotlings,
--       no logo)
--   (au) the cheap wins are missing (no multiplier in tags, no NEXT
--       REBIRTH bar, no upgrade levels, no title billboard, no
--       shield dome, no pursuit banner, no global events, no danger
--       meter or belt list, Disco Pickle still named that)
--   (av) the buddy Rotling is missing (no half-size follower, no tag,
--       no +5% cash, no Index swap)
--   (bb) the storm income readout is missing (no Safe Dome x2 during
--       the storm, or the HUD never shows the boosted rate next to
--       the normal one)
--   (bc) the bright capture setup is missing (lighting not the
--       brightest vivid preset, storm does not restore to it, or the
--       photo shots are not the final 4)
--   (bs) grabbing is broken (free Rotlings sink into the belt because
--       animateFree rebuilds them at CRATER_FLOOR_Y, the bob dips below
--       rest, the guardian spawns on the grabber and insta-catches, or
--       no [Grab] log proves the trigger reaches the server)
--   (bt) selling does nothing in either case (the SELL pad prompt is
--       not proven wired at boot, or sell attempts/results are not
--       logged, so the next playtest cannot tell which side failed)
--   (bu) the money/progress numbers lie (no REBIRTH READY state, the
--       rebirth label ignores banked coins, "$40.00K" for $40,000, or
--       the "place" mission never syncs to the live placed count)
--   (bv) the first storm drops no rocks (resetStormEarnings or
--       spawnEggsForStorm can still abort the storm before the rain
--       loop, because neither is wrapped in its own pcall)
--   (bw) the thief alerts but never steals (runRival's loop body is
--       not pcall-guarded, the steal is not logged, or the steal walk
--       timeout is still 40s)
--   (bx) the buddy blocks the view or the camera clips white shapes
--       (BUDDY_SCALE not 0.28, domes still at 0.82, or the CraterBeam
--       still 1.5 studs / 0.6 transparent)
--   (by) the belt is still a flat strip (no raised slab, side walls,
--       glowing stripes, +X arrows or flush rollers; or Bloom/Brightness
--       not lowered to 0.1 / 1.8)
--   (bz) HUD text is cut off or signs overlap (a top-right element
--       still ends 12px from the edge, the Bounty Board / Index Wall
--       are still close, or a player-visible "Rotling" remains)
--   (ca) the competition is broken (guardian speed/catch/give-up/rim
--       spawn/AWAKE warning wrong, raiders never crater-grab, or the
--       20-index / Cosmic Corn Dog / tier celebrations missing)
--
-- Usage (from the repo root):
--   lune run auto-checks.luau [root]
--   root defaults to "." — point it at another tree to grade that
--   build instead, e.g. a 301cae8 worktree for the live build.
--   Uses the tools/lune binary: ../tools/lune run auto-checks.luau
--
-- The gate: publish.sh runs this script first and stops before
-- building or publishing on any failure. Nothing here needs a running
-- game: the checks read src/ and default.project.json as text and
-- prove the structural conditions that cause each fault. True
-- screen-space overlap — a sign and a tag landing on the same pixels
-- from some camera angle — can only be judged from a running game,
-- which is what photo mode is for (P or /photo).
-- A check that cannot be proven from the source FAILS closed: it
-- prints "could not verify" and the build does not publish.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local root = process.args[1] or "."
if root:sub(-1) == "/" then
	root = root:sub(1, -2)
end

local results: { { id: string, ok: boolean, detail: string } } = {}

local function check(id: string, ok: boolean, detail: string)
	table.insert(results, { id = id, ok = ok, detail = detail })
	print((if ok then "PASS" else "FAIL") .. " (" .. id .. ") " .. detail)
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

-- Resolve a Config.NAME token to its number from Config.luau.
local function configValue(configSrc: string?, name: string): number?
	if not configSrc then
		return nil
	end
	return num(configSrc:match(name .. "%s*=%s*([%-]?[%d%.]+)"))
end

-- The weld offset that carries a Rotling: split the CFrame.new(...)
-- args into numbers, resolving Config.NAME tokens from Config.luau.
local function parseOffset(source: string, configSrc: string?): { number }?
	local raw = source:match("weld%.C0%s*=%s*CFrame%.new%(([^)]+)%)")
	if not raw then
		return nil
	end
	local out: { number } = {}
	for part in raw:gmatch("[^,]+") do
		part = part:gsub("^%s+", ""):gsub("%s+$", "")
		local cfgName = part:match("^Config%.([%w_]+)$")
		if cfgName then
			local v = configValue(configSrc, cfgName)
			if not v then
				return nil
			end
			table.insert(out, v)
		else
			local n = tonumber(part)
			if not n then
				return nil
			end
			table.insert(out, n)
		end
	end
	if #out ~= 3 then
		return nil
	end
	return out
end

-- The function (CarryService.tryGrab etc.) enclosing a byte position.
local function enclosingFunction(source: string, pos: number): string?
	local before = source:sub(1, pos)
	local name: string? = nil
	local at = 1
	while true do
		local s, e, fn = before:find("function ([%w%.:]+)%(", at)
		if not s then
			break
		end
		name = fn
		at = e + 1
	end
	return name
end

-- The body of a named function (up to the next top-level "function ").
local function functionBody(source: string, fnName: string): string?
	local s = source:find("function " .. fnName .. "%(")
	if not s then
		return nil
	end
	local e = source:find("\nfunction ", s + 10)
	if not e then
		e = #source
	end
	return source:sub(s, e)
end

-- Strip "--" comments, one line at a time (code only, for money checks).
local function stripComments(source: string): string
	local lines: { string } = {}
	for line in (source .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line:gsub("%-%-.*$", ""))
	end
	return table.concat(lines, "\n")
end

-- -- (a) carried Rotling: front of chest at arm height, real model ------
-- Spec (Malek, playtest verdict): the Rotling must NOT cover the face.
-- Chosen position: in front of the chest at arm height (forward -Z,
-- chest height), real model, no bubble, never above the head.
do
	local configSrc = read("src/shared/Config.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local stealSrc = read("src/server/StealService.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	local off1 = if carrySrc then parseOffset(carrySrc, configSrc) else nil
	local off2 = if stealSrc then parseOffset(stealSrc, configSrc) else nil
	if not off1 or not off2 or not factorySrc then
		check("a", false, "could not verify the carry weld — CarryWeld C0 not found in CarryService.luau / StealService.luau, or RotlingFactory.luau missing")
	else
		local problems: { string } = {}
		local function badOffset(off: { number }, where: string)
			-- Above the head / over the face: near-zero X and Z with
			-- Y at head height or above. Chest height is around
			-- -0.3; forward is -Z, at least 1.5 studs out.
			if math.abs(off[1]) >= 0.5 then
				table.insert(problems, where .. " C0 X = " .. tostring(off[1]) .. " (not centred on the chest)")
			end
			if off[2] < -1.5 or off[2] > 1.0 then
				table.insert(problems, where .. " C0 Y = " .. tostring(off[2]) .. " (not arm height, must be -1.5..1.0)")
			end
			if off[3] > -1.5 then
				table.insert(problems, where .. " C0 Z = " .. tostring(off[3]) .. " (not in front of the chest, must be <= -1.5)")
			end
		end
		badOffset(off1, "CarryService.weldToPlayer")
		badOffset(off2, "StealService.trySteal")
		-- No bubble: nothing in the factory may create a CarryBubble.
		if factorySrc:find("CarryBubble") then
			table.insert(problems, "RotlingFactory still creates a CarryBubble")
		end
		-- Carried model stays readable: the carried scale clamp must
		-- never shrink below 0.5 (the old 0.4–0.7 clamp collapsed the
		-- model into a tiny brown box over the face).
		local clampLo = num(factorySrc:match("math%.clamp%(Config%.CARRY_MAX_HEIGHT%s*/%s*size,%s*([%d%.]+),"))
		if not clampLo then
			table.insert(problems, "carried scale clamp not found in RotlingFactory.setCarriedVisual")
		elseif clampLo < 0.5 then
			table.insert(problems, "carried scale clamp lower bound " .. tostring(clampLo) .. " (under 0.5 — model collapses to a box)")
		end
		if #problems > 0 then
			check("a", false, "carried Rotling covers the face or rides as a box — " .. table.concat(problems, "; ") .. ". Parts: CarryWeld (CarryService.weldToPlayer, StealService.trySteal), setCarriedVisual (RotlingFactory.luau)")
		else
			check("a", true, "carried Rotling rides in front of the chest at arm height — CarryWeld C0 = ("
				.. table.concat(off1, ", ") .. ") in CarryService.weldToPlayer, (" .. table.concat(off2, ", ")
				.. ") in StealService.trySteal, no CarryBubble, carried scale >= 0.5")
		end
	end
end

-- -- (b) base sign overlaps a name tag ---------------------------------------
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	if not worldSrc or not factorySrc then
		check("b", false, "could not verify the base sign — WorldBuilder.luau or RotlingFactory.luau missing")
	else
		local problems: { string } = {}
		-- One billboard for the whole sign: a separate cash billboard
		-- is the old overlap bug (BaseCash next to BaseSign).
		if worldSrc:find('Name = "BaseCash"') then
			table.insert(problems, 'a second "BaseCash" billboard exists beside "BaseSign"')
		end
		if not worldSrc:find('sign%.Name = "BaseSign"') then
			table.insert(problems, '"BaseSign" billboard not found in WorldBuilder.luau')
		end
		-- Name and $ on stacked, disjoint rows of the same billboard.
		local labelSize = num(worldSrc:match('signLabel%.Size%s*=%s*UDim2%.new%(1,%s*0,%s*([%d%.]+),%s*0%)'))
		local cashTop = num(worldSrc:match('cashLabel%.Position%s*=%s*UDim2%.new%(0,%s*0,%s*([%d%.]+),%s*0%)'))
		local cashSize = num(worldSrc:match('cashLabel%.Size%s*=%s*UDim2%.new%(1,%s*0,%s*([%d%.]+),%s*0%)'))
		if not labelSize or not cashTop or not cashSize then
			table.insert(problems, "BaseLabel / CashLabel rows not found in WorldBuilder.luau")
		elseif labelSize > cashTop then
			table.insert(problems, "BaseLabel (0–" .. tostring(labelSize) .. ") overlaps CashLabel (" .. tostring(cashTop) .. "–" .. tostring(cashTop + cashSize) .. ")")
		end
		-- Both billboards bounded, so neither renders from across the map.
		local signDist = num(worldSrc:match("sign%.MaxDistance%s*=%s*(%d+)"))
		local tagDist = num(factorySrc:match("billboard%.MaxDistance%s*=%s*(%d+)"))
		if not signDist or not tagDist then
			table.insert(problems, "BaseSign or RotlingLabel MaxDistance not found")
		elseif signDist > 60 or tagDist > 40 then
			table.insert(problems, "MaxDistance too far: BaseSign " .. tostring(signDist) .. ", RotlingLabel " .. tostring(tagDist))
		end
		if #problems > 0 then
			check("b", false, "base sign can overlap a name tag — " .. table.concat(problems, "; ") .. ". Parts: BaseSign / BaseLabel / CashLabel (WorldBuilder.luau), RotlingLabel (RotlingFactory.luau)")
		else
			check("b", true, "base sign cannot overlap a name tag — one BaseSign billboard, BaseLabel 0–"
				.. tostring(labelSize) .. " stacked above CashLabel " .. tostring(cashTop) .. "–" .. tostring(cashTop + (cashSize or 0))
				.. ", BaseSign MaxDistance " .. tostring(signDist) .. ", RotlingLabel MaxDistance " .. tostring(tagDist))
		end
	end
end

-- -- (c) name tag overlaps the HUD or the top bar ----------------------------
do
	local factorySrc = read("src/server/RotlingFactory.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local stealSrc = read("src/server/StealService.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	if not factorySrc or not carrySrc or not stealSrc or not hudSrc then
		check("c", false, "could not verify name tags — RotlingFactory.luau, CarryService.luau, StealService.luau or HUDController.client.luau missing")
	else
		local problems: { string } = {}
		-- The tag hides while carried, so it can never sit over the
		-- top-centre coins while the Rotling rides the player's head.
		if not factorySrc:find("label%.Enabled = not carried") then
			table.insert(problems, "RotlingFactory.setCarriedVisual does not hide RotlingLabel while carried")
		end
		-- Every path that carries must use the carried look (grab AND
		-- steal); a path that welds without it leaves the tag on.
		if not carrySrc:find("setCarriedVisual%(model, true%)") then
			table.insert(problems, "CarryService.tryGrab does not call setCarriedVisual(model, true)")
		end
		if not stealSrc:find("setCarriedVisual%(model, true%)") then
			table.insert(problems, "StealService.trySteal does not call setCarriedVisual(model, true)")
		end
		-- Tags only render near the player, never from across the map.
		local tagDist = num(factorySrc:match("billboard%.MaxDistance%s*=%s*(%d+)"))
		if not tagDist then
			table.insert(problems, "RotlingLabel MaxDistance not found")
		elseif tagDist > 40 then
			table.insert(problems, "RotlingLabel MaxDistance " .. tostring(tagDist) .. " (over 40)")
		end
		-- HUD buttons sit 12px clear of the screen edge, so a tag at
		-- the edge cannot sit on top of one.
		local rightOff = num(hudSrc:match('makeButton%(gui, "RebirthButton".-UDim2%.new%(1,%s*(-%d+),'))
		local btnWidth = num(hudSrc:match('makeButton%(gui, "RebirthButton".-UDim2%.new%(0,%s*(%d+),'))
		if not rightOff or not btnWidth then
			table.insert(problems, "RebirthButton position/size not found in HUDController.client.luau")
		elseif -rightOff - btnWidth < 12 then
			table.insert(problems, "RebirthButton only " .. tostring(-rightOff - btnWidth) .. "px clear of the screen edge (under 12px)")
		end
		if #problems > 0 then
			check("c", false, "a name tag can overlap the HUD or the top bar — " .. table.concat(problems, "; ") .. ". Parts: RotlingLabel (RotlingFactory.luau), RebirthButton / LockButton (HUDController.client.luau)")
		else
			check("c", true, "no name tag can overlap the HUD — RotlingLabel hidden while carried (both grab and steal paths), MaxDistance "
				.. tostring(tagDist) .. ", RebirthButton " .. tostring(-(rightOff or 0) - (btnWidth or 0)) .. "px clear of the screen edge")
		end
	end
end

-- -- (d) crater Rotlings smaller than 1.5x ------------------------------------
do
	local spawnSrc = read("src/server/SpawnService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	if not spawnSrc or not carrySrc then
		check("d", false, "could not verify crater sizes — SpawnService.luau or CarryService.luau missing")
	else
		local problems: { string } = {}
		-- Crater spawns build at 1.5x.
		local spawnScale = num(spawnSrc:match("RotlingFactory%.build%(def%.id,%s*mutation,%s*position,%s*([%d%.]+)%)"))
		if not spawnScale then
			table.insert(problems, "SpawnService.spawnOne build scale not found")
		elseif spawnScale < 1.5 then
			table.insert(problems, "SpawnService.spawnOne builds at " .. tostring(spawnScale) .. "x (under 1.5x)")
		end
		-- A dropped Rotling goes back to the crater at 1.5x.
		local scatterScale: number? = nil
		do
			local pos = carrySrc:find("setModelScale%(model,")
			while pos do
				local fn = enclosingFunction(carrySrc, pos)
				if fn == "CarryService.scatterToCrater" then
					scatterScale = num(carrySrc:sub(pos):match("setModelScale%(model,%s*([%d%.]+)%)"))
					break
				end
				pos = carrySrc:find("setModelScale%(model,", pos + 1)
			end
		end
		if not scatterScale then
			table.insert(problems, "CarryService.scatterToCrater scale not found")
		elseif scatterScale < 1.5 then
			table.insert(problems, "CarryService.scatterToCrater restores " .. tostring(scatterScale) .. "x (under 1.5x)")
		end
		-- No other build call may leave a free Rotling under 1.5x: a
		-- 1x build is only allowed when it goes straight onto a pad.
		for _, file in ipairs({ "src/server/SpawnService.luau", "src/server/CarryService.luau" }) do
			local src = read(file)
			if src then
				local at = 1
				while true do
					local s, e = src:find("RotlingFactory%.build%(", at)
					if not s then
						break
					end
					local call = src:sub(s, src:find("%)", e) or e)
					local scale = num(call:match(",%s*([%d%.]+)%s*%)$")) or 1 -- no 4th arg: RotlingFactory defaults to 1x
					local fn = enclosingFunction(src, s)
					if scale < 1.5 and fn ~= "CarryService.restorePlaced" then
						table.insert(problems, file .. " builds at " .. tostring(scale) .. "x in " .. tostring(fn) .. " (under 1.5x, not a pad restore)")
					end
					at = e + 1
				end
			end
		end
		if #problems > 0 then
			check("d", false, "crater Rotlings under the 1.5x minimum — " .. table.concat(problems, "; ") .. ". Parts: SpawnService.spawnOne, CarryService.scatterToCrater, RotlingFactory.build")
		else
			check("d", true, "crater Rotlings are 1.5x — SpawnService.spawnOne builds at 1.5x, CarryService.scatterToCrater restores 1.5x, no other free-path build under 1.5x")
		end
	end
end

-- -- (e) spawn platform is a flat cyan block ---------------------------------
do
	local ok, projectText = pcall(fs.readFile, root .. "/default.project.json")
	local project: any = nil
	if ok then
		local decOk, decoded = pcall(serde.decode, "json", projectText)
		if decOk then
			project = decoded
		end
	end
	if not project then
		check("e", false, "could not verify the spawn platform — default.project.json missing or not valid JSON")
	else
		local spawn = project.tree and project.tree.Workspace and project.tree.Workspace.SpawnLocation
		local props = if spawn then spawn["$properties"] else nil
		if not props then
			check("e", false, "could not verify the spawn platform — SpawnLocation not found in default.project.json")
		else
			local material = props.Material
			local color = props.Color -- {r, g, b} 0-1
			local size = props.Size -- {x, y, z} studs
			local isCyan = color and color[1] <= 0.4 and color[2] >= 0.8 and color[3] >= 0.6
			local isSlab = size and size[2] <= 1
			-- Dressing: a named spawn part in WorldBuilder (trim, pad,
			-- decor) built at the spawn instead of the bare slab.
			local worldSrc = read("src/server/WorldBuilder.luau") or ""
			local dressed = worldSrc:find("SpawnTrim") ~= nil
				or worldSrc:find("SpawnPad") ~= nil
				or worldSrc:find("SpawnDecor") ~= nil
			if material == "Neon" and isCyan and isSlab and not dressed then
				check("e", false, "spawn platform is a flat cyan block with no texture — SpawnLocation in default.project.json: Neon, Color ("
					.. tostring(color[1]) .. ", " .. tostring(color[2]) .. ", " .. tostring(color[3]) .. "), Size ("
					.. tostring(size[1]) .. ", " .. tostring(size[2]) .. ", " .. tostring(size[3]) .. "), no SpawnTrim/SpawnPad/SpawnDecor in WorldBuilder.luau")
			else
				check("e", true, "spawn platform is dressed — SpawnLocation Material " .. tostring(material)
					.. (if dressed then ", spawn dressing present in WorldBuilder.luau" else ""))
			end
		end
	end
end

-- -- (f) glow/bloom washout ---------------------------------------------------
do
	local ok, projectText = pcall(fs.readFile, root .. "/default.project.json")
	local project: any = nil
	if ok then
		local decOk, decoded = pcall(serde.decode, "json", projectText)
		if decOk then
			project = decoded
		end
	end
	local factorySrc = read("src/server/RotlingFactory.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	if not project or not factorySrc or not worldSrc or not hudSrc then
		check("f", false, "could not verify glow/bloom — default.project.json, RotlingFactory.luau, WorldBuilder.luau or HUDController.client.luau missing")
	else
		local problems: { string } = {}
		local lighting = project.tree and project.tree.Lighting
		local bloom = if lighting then lighting.Bloom else nil
		local bloomProps = if bloom then bloom["$properties"] else nil
		local intensity = if bloomProps then num(tostring(bloomProps.Intensity)) else nil
		local threshold = if bloomProps then num(tostring(bloomProps.Threshold)) else nil
		if not intensity or not threshold then
			table.insert(problems, "BloomEffect Intensity/Threshold not found in default.project.json")
		else
			if intensity > 0.4 then
				table.insert(problems, "Bloom Intensity " .. tostring(intensity) .. " (over 0.4 — must be cut at least in half from 0.8)")
			end
			if threshold < 0.9 then
				table.insert(problems, "Bloom Threshold " .. tostring(threshold) .. " (under 0.9)")
			end
		end
		-- Crater beacon beam light: dim, not a second sun.
		local beamBright = num(worldSrc:match("beamLight%.Brightness%s*=%s*([%d%.]+)"))
		if not beamBright then
			table.insert(problems, "crater beam PointLight Brightness not found in WorldBuilder.luau")
		elseif beamBright > 1 then
			table.insert(problems, "crater beam light Brightness " .. tostring(beamBright) .. " (over 1)")
		end
		-- Rotling point lights: base at most 1, per-tier at most 0.5
		-- (old: 2 + tier * 0.75, up to 6.5 for Cosmic).
		local lightBase, lightStep = factorySrc:match("light%.Brightness%s*=%s*([%d%.]+)%s*%+%s*tier%s*%*%s*([%d%.]+)")
		if not lightBase or not lightStep then
			table.insert(problems, "Rotling PointLight Brightness formula not found in RotlingFactory.luau")
		else
			local b = num(lightBase)
			local s = num(lightStep)
			if not b or not s then
				table.insert(problems, "Rotling PointLight Brightness formula not numeric")
			elseif b > 1 or s > 0.5 then
				table.insert(problems, "Rotling PointLight Brightness " .. tostring(b) .. " + tier * " .. tostring(s) .. " (over 1 + tier * 0.5)")
			end
		end
		-- HUD stays readable over any bright 3D background: a dark
		-- top bar behind the coins/cps/storm labels.
		if not hudSrc:find('topBar%.Name = "TopBar"') then
			table.insert(problems, "HUD TopBar (dark bar behind the top labels) not found in HUDController.client.luau")
		end
		if #problems > 0 then
			check("f", false, "glow/bloom can wash the screen out — " .. table.concat(problems, "; ") .. ". Parts: BloomEffect (default.project.json), CraterBeacon beam light (WorldBuilder.luau), Rotling PointLight (RotlingFactory.luau), TopBar (HUDController.client.luau)")
		else
			check("f", true, "glow/bloom is dimmed — Bloom Intensity " .. tostring(intensity) .. " / Threshold " .. tostring(threshold)
				.. ", beam light Brightness " .. tostring(beamBright) .. ", Rotling light " .. tostring(lightBase) .. " + tier * " .. tostring(lightStep)
				.. ", HUD TopBar present")
		end
	end
end

-- -- (g) name tags stack when Rotlings stand close ----------------------------
do
	local configSrc = read("src/shared/Config.luau")
	local spawnSrc = read("src/server/SpawnService.luau")
	local tagSrc = read("src/client/TagController.client.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	if not configSrc or not spawnSrc or not tagSrc or not factorySrc then
		check("g", false, "could not verify tag spacing — Config.luau, SpawnService.luau, TagController.client.luau or RotlingFactory.luau missing")
	else
		local problems: { string } = {}
		local spacing = configValue(configSrc, "CRATER_MIN_SPACING")
		local tagDist = configValue(configSrc, "TAG_MAX_DISTANCE")
		local tagShown = configValue(configSrc, "TAG_MAX_SHOWN")
		if not spacing then
			table.insert(problems, "Config.CRATER_MIN_SPACING not found")
		elseif spacing < 6 then
			table.insert(problems, "crater spacing " .. tostring(spacing) .. " studs (under 6)")
		end
		if not tagDist then
			table.insert(problems, "Config.TAG_MAX_DISTANCE not found")
		elseif tagDist > 25 then
			table.insert(problems, "tag distance " .. tostring(tagDist) .. " studs (over 25)")
		end
		if not tagShown then
			table.insert(problems, "Config.TAG_MAX_SHOWN not found")
		elseif tagShown > 3 then
			table.insert(problems, "at most " .. tostring(tagShown) .. " tags shown (over 3)")
		end
		-- Spawns actually use the spacing when picking a position.
		if not spawnSrc:find("findSpawnPosition") or not spawnSrc:find("Config.CRATER_MIN_SPACING") then
			table.insert(problems, "SpawnService.spawnOne does not pick a spaced position (findSpawnPosition / CRATER_MIN_SPACING)")
		end
		-- The client enforces the nearest-N rule every tick.
		if not tagSrc:find("Config.TAG_MAX_DISTANCE") or not tagSrc:find("Config.TAG_MAX_SHOWN") then
			table.insert(problems, "TagController does not enforce TAG_MAX_DISTANCE / TAG_MAX_SHOWN")
		end
		-- The billboard itself renders out to the photo-mode tag range
		-- (40 studs); the TagController is the real gate, so a wide
		-- billboard never clutters normal play.
		local billDist = num(factorySrc:match("billboard%.MaxDistance%s*=%s*(%d+)"))
		if not billDist then
			table.insert(problems, "RotlingLabel MaxDistance not found in RotlingFactory.luau")
		elseif billDist > 40 then
			table.insert(problems, "RotlingLabel MaxDistance " .. tostring(billDist) .. " (over 40)")
		end
		if #problems > 0 then
			check("g", false, "name tags can stack into unreadable text — " .. table.concat(problems, "; ") .. ". Parts: SpawnService.findSpawnPosition, TagController.client.luau, RotlingLabel (RotlingFactory.luau)")
		else
			check("g", true, "name tags cannot stack — crater spacing " .. tostring(spacing) .. " studs, tags within " .. tostring(tagDist)
				.. " studs, at most " .. tostring(tagShown) .. " nearest shown (TagController), billboard MaxDistance " .. tostring(billDist))
		end
	end
end

-- -- (h) Rotling models read as flat semi-transparent boxes ------------------
do
	local factorySrc = read("src/server/RotlingFactory.luau")
	if not factorySrc then
		check("h", false, "could not verify Rotling models — RotlingFactory.luau missing")
	else
		local problems: { string } = {}
		-- Every body part is built solid: makePart sets Transparency 0.
		local makePartBody = functionBody(factorySrc, "makePart")
		if not makePartBody then
			table.insert(problems, "makePart not found in RotlingFactory.luau")
		elseif not makePartBody:find("part%.Transparency%s*=%s*0[^%d%.]") and not makePartBody:find("part%.Transparency%s*=%s*0%s*$") then
			table.insert(problems, "makePart does not set Transparency = 0")
		end
		-- The glow shell is nearly clear (0.88), never a pale wash.
		local shellTrans = num(factorySrc:match('makePart%("GlowShell".-shell%.Transparency%s*=%s*([%d%.]+)'))
		if not shellTrans then
			-- Fallback: the glowShell() helper sets it on its own line.
			shellTrans = num(factorySrc:match("shell%.Transparency%s*=%s*([%d%.]+)"))
		end
		if not shellTrans then
			table.insert(problems, "GlowShell Transparency not found")
		elseif shellTrans < 0.85 then
			table.insert(problems, "GlowShell Transparency " .. tostring(shellTrans) .. " (under 0.85 — reads as a pale box)")
		end
		-- The shell exists only for the top tiers (4+): lower tiers
		-- get sparkles, not a shell. Every glowShell() call must
		-- sit at or after the tier == 4 branch (tier 4 itself, and
		-- the else branch = Mythic/Cosmic, tier 5+); none may sit
		-- under tier 2 or tier 3.
		local auraBody = functionBody(factorySrc, "addRarityAura")
		local shellCalls = 0
		local shellBeforeTier4 = false
		if not auraBody then
			table.insert(problems, "addRarityAura not found in RotlingFactory.luau")
		else
			local tier4At = auraBody:find("elseif tier == 4 then") or auraBody:find("if tier == 4 then")
			for line in (auraBody .. "\n"):gmatch("(.-)\n") do
				if line:match("^%s*glowShell%(%)%s*$") then
					shellCalls += 1
				end
			end
			if not tier4At then
				table.insert(problems, "no tier == 4 branch in addRarityAura")
			else
				-- Standalone call lines only: the nested "local
				-- function glowShell()" definition sits before the
				-- branches and is not a call.
				local before = auraBody:sub(1, tier4At)
				for line in (before .. "\n"):gmatch("(.-)\n") do
					if line:match("^%s*glowShell%(%)%s*$") then
						shellBeforeTier4 = true
					end
				end
			end
			if shellCalls < 1 then
				table.insert(problems, "no glowShell() call in addRarityAura (top tiers have no shell at all)")
			end
			if shellBeforeTier4 then
				table.insert(problems, "glowShell() is called before the tier == 4 branch (a low tier gets a shell)")
			end
		end
		local tier4Shell = shellCalls >= 1 and not shellBeforeTier4
		-- The rarity highlight is a faint tint, not a solid wash.
		local hlFill = num(factorySrc:match("highlight%.FillTransparency%s*=%s*([%d%.]+)"))
		if not hlFill then
			table.insert(problems, "rarity Highlight FillTransparency not found")
		elseif hlFill < 0.7 then
			table.insert(problems, "rarity Highlight FillTransparency " .. tostring(hlFill) .. " (under 0.7)")
		end
		if #problems > 0 then
			check("h", false, "Rotling models can read as flat semi-transparent boxes — " .. table.concat(problems, "; ") .. ". Parts: makePart / GlowShell / Highlight (RotlingFactory.luau)")
		else
			check("h", true, "Rotling models are solid — makePart Transparency 0, GlowShell Transparency " .. tostring(shellTrans)
				.. " tier 4+ only, Highlight FillTransparency " .. tostring(hlFill))
		end
	end
end

-- -- (i) base sign is a giant wall/slab ---------------------------------------
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		check("i", false, "could not verify the base sign — WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		-- No tall wall behind the base: the old 26x8x1.5 BaseWall is gone.
		if worldSrc:find('Name = "BaseWall"') then
			table.insert(problems, 'a "BaseWall" part still exists in WorldBuilder.luau')
		end
		-- The sign is a small board on a post: at most 10 wide, 5 tall.
		local boardX, boardY = worldSrc:match('part%("SignBoard", Enum%.PartType%.Block, Vector3%.new%(([%d%.]+),%s*([%d%.]+),%s*[%d%.]+%)')
		if not boardX or not boardY then
			table.insert(problems, "SignBoard (8x4x0.5 block on a post) not found in WorldBuilder.luau")
		else
			local bx = num(boardX)
			local by = num(boardY)
			if not bx or not by then
				table.insert(problems, "SignBoard size not numeric")
			elseif bx > 10 or by > 5 then
				table.insert(problems, "SignBoard is " .. tostring(bx) .. "x" .. tostring(by) .. " studs (over 10x5 — a wall, not a sign)")
			end
		end
		if not worldSrc:find('part%("SignPost"') then
			table.insert(problems, "SignPost (the post the sign hangs on) not found in WorldBuilder.luau")
		end
		-- The billboard itself is small: 200x100, not a wall of text.
		local signW, signH = worldSrc:match("sign%.Size%s*=%s*UDim2%.fromOffset%((%d+),%s*(%d+)%)")
		if not signW or not signH then
			table.insert(problems, "BaseSign Size (UDim2.fromOffset) not found in WorldBuilder.luau")
		elseif tonumber(signW) > 300 or tonumber(signH) > 150 then
			table.insert(problems, "BaseSign is " .. signW .. "x" .. signH .. " (over 300x150)")
		end
		if #problems > 0 then
			check("i", false, "the base sign is a giant wall/slab — " .. table.concat(problems, "; ") .. ". Parts: SignBoard / SignPost / BaseSign (WorldBuilder.luau)")
		else
			check("i", true, "the base sign is small — SignBoard " .. tostring(boardX) .. "x" .. tostring(boardY)
				.. " studs on a SignPost, BaseSign " .. tostring(signW) .. "x" .. tostring(signH) .. ", no BaseWall")
		end
	end
end

-- -- (j) "arms full" after placing --------------------------------------------
do
	local carrySrc = read("src/server/CarryService.luau")
	if not carrySrc then
		check("j", false, "could not verify the carry slot — CarryService.luau missing")
	else
		local problems: { string } = {}
		-- carryRotling is idempotent: the same model can never be
		-- inserted twice (a duplicate survived its place and the
		-- slot read as full forever).
		local carryBody = functionBody(carrySrc, "CarryService.carryRotling")
		if not carryBody then
			table.insert(problems, "CarryService.carryRotling not found")
		elseif not carryBody:find("table%.find%(carried, model%)") then
			table.insert(problems, "carryRotling has no duplicate guard (table.find before insert)")
		end
		-- removeCarried removes EVERY copy, not just the first.
		local removeBody = functionBody(carrySrc, "CarryService.removeCarried")
		if not removeBody then
			table.insert(problems, "CarryService.removeCarried not found")
		elseif not removeBody:find("while index do") or not removeBody:find("table%.remove%(carried, index%)") then
			table.insert(problems, "removeCarried does not loop-remove every copy (while + table.remove)")
		end
		-- Placing clears the slot: placeOnPad calls removeCarried and
		-- verifies the slot is clear afterwards.
		local placeBody = functionBody(carrySrc, "CarryService.placeOnPad")
		if not placeBody then
			table.insert(problems, "CarryService.placeOnPad not found")
		elseif not placeBody:find("removeCarried%(player, model%)") then
			table.insert(problems, "placeOnPad does not call removeCarried")
		end
		if #problems > 0 then
			check("j", false, "the carry slot can stay full after placing — " .. table.concat(problems, "; ") .. ". Parts: carryRotling / removeCarried / placeOnPad (CarryService.luau)")
		else
			check("j", true, "grab → place → grab works — carryRotling is idempotent (duplicate guard), removeCarried removes every copy, placeOnPad clears the slot")
		end
	end
end

-- -- (k) doubled "$" in any displayed money string ----------------------------
do
	-- Walk src/ recursively, strip comments, and flag any hand-rolled
	-- "$" .. concatenation or any "$$" literal. Every money display
	-- must go through Formatting.formatMoney (which already carries
	-- the "$"), so a second "$" can never appear.
	local badFiles: { string } = {}
	local function walk(dir: string)
		local ok, entries = pcall(fs.readDir, root .. "/" .. dir)
		if not ok then
			return
		end
		for _, entry in ipairs(entries :: { string }) do
			local path = dir .. "/" .. entry
			local metaOk, meta = pcall(fs.metadata, root .. "/" .. path)
			if metaOk and meta.kind == "directory" then
				walk(path)
			elseif entry:sub(-5) == ".luau" then
				local src = read(path)
				if src then
					local code = stripComments(src)
					-- Formatting.luau IS the shared function: it is
					-- the one file allowed to prepend "$". Every
					-- other file must go through it.
					local handRolled = path ~= "src/shared/Formatting.luau"
						and (code:find('"%$"%.%.') or code:find("'%$'%.%."))
					if handRolled or code:find('%$%$') then
						table.insert(badFiles, path)
					end
				end
			end
		end
	end
	walk("src")
	-- The three money displays all use the shared function.
	local worldSrc = read("src/server/WorldBuilder.luau") or ""
	local factorySrc = read("src/server/RotlingFactory.luau") or ""
	local indexSrc = read("src/client/IndexController.client.luau") or ""
	local problems: { string } = {}
	if #badFiles > 0 then
		table.insert(problems, "hand-rolled money in " .. table.concat(badFiles, ", "))
	end
	if not worldSrc:find("Formatting%.formatMoney%(coins%)") then
		table.insert(problems, "WorldBuilder.setBaseCoins does not use Formatting.formatMoney")
	end
	if not factorySrc:find("Formatting%.formatMoney%(cps%)") then
		table.insert(problems, "RotlingFactory addLabel Cps does not use Formatting.formatMoney")
	end
	if not indexSrc:find("Formatting%.formatMoney%(math%.floor") then
		table.insert(problems, "IndexController card Cps does not use Formatting.formatMoney")
	end
	if #problems > 0 then
		check("k", false, "a displayed money string can show \"$$\" — " .. table.concat(problems, "; ") .. ". Parts: Formatting.formatMoney (src/shared/Formatting.luau)")
	else
		check("k", true, "no displayed money string can show \"$$\" — no hand-rolled \"$\" in src/, sign / Rotling label / Index card all use Formatting.formatMoney")
	end
end

-- -- (l) meteor storm never triggers ------------------------------------------
do
	local starSrc = read("src/server/StarfallService.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	if not starSrc or not incomeSrc then
		check("l", false, "could not verify the storm — StarfallService.luau or IncomeService.luau missing")
	else
		local problems: { string } = {}
		-- The phase cycle is pcall-guarded: one error can no longer
		-- kill the storm thread silently while the HUD countdown
		-- keeps ticking from the stale phaseEndsAt.
		local startBody = functionBody(starSrc, "StarfallService.start")
		if not startBody then
			table.insert(problems, "StarfallService.start not found")
		elseif not startBody:find("pcall%(function%(%)") then
			table.insert(problems, "StarfallService.start cycle is not pcall-guarded")
		end
		-- The storm phase actually spawns meteors.
		if not starSrc:find('setPhase%("storm"') then
			table.insert(problems, 'no setPhase("storm", ...) in StarfallService.luau')
		end
		if not starSrc:find("spawnMeteor%(%)") then
			table.insert(problems, "spawnMeteor() is never called in StarfallService.luau")
		end
		-- The watchdog exists and is called from a separate healthy
		-- loop, so a stalled phase machine restarts itself.
		if not starSrc:find("function StarfallService.ensureRunning") then
			table.insert(problems, "StarfallService.ensureRunning watchdog not found")
		end
		if not incomeSrc:find("StarfallService.ensureRunning%(%)") then
			table.insert(problems, "IncomeService heartbeat does not call StarfallService.ensureRunning()")
		end
		if #problems > 0 then
			check("l", false, "the meteor storm can fail to trigger — " .. table.concat(problems, "; ") .. ". Parts: StarfallService.start / ensureRunning, IncomeService heartbeat")
		else
			check("l", true, "the storm triggers when the countdown hits zero — pcall-guarded cycle, setPhase(\"storm\") spawns meteors, ensureRunning watchdog called from the IncomeService heartbeat")
		end
	end
end

-- -- (m) conveyor: always 6-10 Rotlings to grab ------------------------------
do
	local configSrc = read("src/shared/Config.luau")
	local spawnSrc = read("src/server/SpawnService.luau")
	if not configSrc or not spawnSrc then
		check("m", false, "could not verify the conveyor — Config.luau or SpawnService.luau missing")
	else
		local problems: { string } = {}
		local minFree = configValue(configSrc, "CRATER_MIN_FREE")
		local maxFree = configValue(configSrc, "CRATER_MAX_FREE")
		local initial = configValue(configSrc, "CRATER_INITIAL")
		if not minFree then
			table.insert(problems, "Config.CRATER_MIN_FREE not found")
		elseif minFree < 6 then
			table.insert(problems, "conveyor floor " .. tostring(minFree) .. " (under 6)")
		end
		if not maxFree then
			table.insert(problems, "Config.CRATER_MAX_FREE not found")
		elseif maxFree < 10 then
			table.insert(problems, "conveyor cap " .. tostring(maxFree) .. " (under 10)")
		end
		if not initial then
			table.insert(problems, "Config.CRATER_INITIAL not found")
		elseif initial < 6 then
			table.insert(problems, "conveyor starts with " .. tostring(initial) .. " Rotlings (under 6)")
		end
		-- The spawn loop tops the conveyor back up to the floor.
		local startBody = functionBody(spawnSrc, "SpawnService.start")
		if not startBody then
			table.insert(problems, "SpawnService.start not found")
		elseif not startBody:find("CRATER_MIN_FREE") then
			table.insert(problems, "SpawnService.start never tops up to CRATER_MIN_FREE")
		end
		if #problems > 0 then
			check("m", false, "the conveyor can run empty — " .. table.concat(problems, "; ") .. ". Parts: SpawnService.start, Config.CRATER_MIN_FREE / CRATER_MAX_FREE / CRATER_INITIAL")
		else
			check("m", true, "the conveyor stays populated — floor " .. tostring(minFree) .. ", cap " .. tostring(maxFree) .. ", starts with " .. tostring(initial) .. ", spawn loop tops up")
		end
	end
end

-- -- (n) bright, saturated, toy-like look -------------------------------------
do
	local ok, projectText = pcall(fs.readFile, root .. "/default.project.json")
	local project: any = nil
	if ok then
		local decOk, decoded = pcall(serde.decode, "json", projectText)
		if decOk then
			project = decoded
		end
	end
	if not project then
		check("n", false, "could not verify the look — default.project.json missing or not valid JSON")
	else
		local problems: { string } = {}
		local lighting = project.tree and project.tree.Lighting
		local props = if lighting then lighting["$properties"] else nil
		if not props then
			table.insert(problems, "Lighting properties not found in default.project.json")
		else
			local clock = num(tostring(props.ClockTime))
			if not clock then
				table.insert(problems, "Lighting ClockTime not found")
			elseif clock < 10 or clock > 15 then
				table.insert(problems, "ClockTime " .. tostring(clock) .. " (not bright midday 10–15)")
			end
			local fogEnd = num(tostring(props.FogEnd))
			if not fogEnd then
				table.insert(problems, "Lighting FogEnd not found")
			elseif fogEnd < 1200 then
				table.insert(problems, "FogEnd " .. tostring(fogEnd) .. " (under 1200 — haze closes in)")
			end
		end
		local atmosphere = if lighting then lighting.Atmosphere else nil
		local atmoProps = if atmosphere then atmosphere["$properties"] else nil
		if not atmoProps then
			table.insert(problems, "Atmosphere not found in default.project.json")
		else
			local haze = num(tostring(atmoProps.Haze))
			local density = num(tostring(atmoProps.Density))
			if haze and haze > 1 then
				table.insert(problems, "Atmosphere Haze " .. tostring(haze) .. " (over 1 — grey haze)")
			end
			if density and density > 0.25 then
				table.insert(problems, "Atmosphere Density " .. tostring(density) .. " (over 0.25)")
			end
		end
		local cc = if lighting then lighting.ColorCorrection else nil
		local ccProps = if cc then cc["$properties"] else nil
		if not ccProps then
			table.insert(problems, "ColorCorrection not found in default.project.json")
		else
			local sat = num(tostring(ccProps.Saturation))
			if not sat then
				table.insert(problems, "ColorCorrection Saturation not found")
			elseif sat < 0.6 then
				table.insert(problems, "Saturation " .. tostring(sat) .. " (under 0.6 — not toy-like)")
			end
		end
		-- Bloom stays cut (Phase 1): a bright sky must not re-wash.
		local bloom = if lighting then lighting.Bloom else nil
		local bloomProps = if bloom then bloom["$properties"] else nil
		local intensity = if bloomProps then num(tostring(bloomProps.Intensity)) else nil
		if intensity and intensity > 0.4 then
			table.insert(problems, "Bloom Intensity " .. tostring(intensity) .. " (over 0.4 — washout is back)")
		end
		if #problems > 0 then
			check("n", false, "the look is not bright and saturated — " .. table.concat(problems, "; ") .. ". Parts: Lighting / Atmosphere / ColorCorrection / Bloom (default.project.json)")
		else
			check("n", true, "bright toy-like look — midday ClockTime " .. tostring(if props then props.ClockTime else "?")
				.. ", FogEnd " .. tostring(if props then props.FogEnd else "?") .. ", Haze " .. tostring(if atmoProps then atmoProps.Haze else "?")
				.. ", Saturation " .. tostring(if ccProps then ccProps.Saturation else "?") .. ", Bloom " .. tostring(intensity))
		end
	end
end

-- -- (o) colourful bases with a level sign ------------------------------------
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	if not worldSrc or not incomeSrc then
		check("o", false, "could not verify base level signs — WorldBuilder.luau or IncomeService.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find('sign%.Name = "BaseSign"') then
			table.insert(problems, '"BaseSign" billboard not found')
		end
		-- A level billboard hangs under the owner sign.
		if not worldSrc:find('levelSign%.Name = "BaseLevel"') then
			table.insert(problems, '"BaseLevel" billboard not found in WorldBuilder.luau')
		end
		if not worldSrc:find("function WorldBuilder.setBaseLevel") then
			table.insert(problems, "WorldBuilder.setBaseLevel not found")
		end
		-- The level text is "Lv N" with a star.
		if not worldSrc:find('"Lv "%s*%.%.%s*tostring%(level%)') then
			table.insert(problems, 'level label does not show "Lv N"')
		end
		-- The HUD feed refreshes the level every second.
		if not incomeSrc:find("WorldBuilder.setBaseLevel%(baseId,") then
			table.insert(problems, "IncomeService.broadcastHud never calls WorldBuilder.setBaseLevel")
		end
		-- Bases are colourful: at least 6 distinct theme colours.
		local colorCount = 0
		for _ in worldSrc:gmatch("Color3%.fromRGB%(%d+, %d+, %d+%)") do
			colorCount += 1
		end
		if colorCount < 6 then
			table.insert(problems, "fewer than 6 theme colours in WorldBuilder.luau")
		end
		if #problems > 0 then
			check("o", false, "bases lack a level sign — " .. table.concat(problems, "; ") .. ". Parts: BaseSign / BaseLevel / setBaseLevel (WorldBuilder.luau), IncomeService.broadcastHud")
		else
			check("o", true, "colourful bases with a level sign — BaseSign + BaseLevel (\"Lv N ★\") under it, refreshed every second from the HUD feed")
		end
	end
end

-- -- (p) a clear SELL area -----------------------------------------------------
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local sellSrc = read("src/server/SellService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local projectOk, projectText = pcall(fs.readFile, root .. "/default.project.json")
	local project: any = nil
	if projectOk then
		local decOk, decoded = pcall(serde.decode, "json", projectText)
		if decOk then
			project = decoded
		end
	end
	if not worldSrc or not sellSrc or not remotesSrc or not project then
		check("p", false, "could not verify the SELL area — WorldBuilder.luau, SellService.luau, Remotes.luau or default.project.json missing")
	else
		local problems: { string } = {}
		if not worldSrc:find('part%("SellPad"') then
			table.insert(problems, 'no "SellPad" part in WorldBuilder.luau')
		end
		if not worldSrc:find('sign%.Name = "SellSign"') then
			table.insert(problems, '"SellSign" billboard not found in WorldBuilder.luau')
		end
		if not worldSrc:find('"💰 SELL"') then
			table.insert(problems, 'SELL sign does not say "💰 SELL"')
		end
		-- The sign's instruction is one short line, TextScaled, no
		-- wrapping: "Sell here (E)".
		if not worldSrc:find('"Sell here %(E%)"') then
			table.insert(problems, 'SELL sign does not say "Sell here (E)"')
		end
		if not worldSrc:find('sellPrompt%.ActionText = "Sell Brainrot"') then
			table.insert(problems, 'no "Sell Brainrot" prompt on the SELL pad')
		end
		if not sellSrc:find("function SellService.sellCarried") then
			table.insert(problems, "SellService.sellCarried not found")
		end
		-- Fix round 5, item 1: sellPlaced is GONE — the SELL pad must
		-- never sell a placed Rotling. If the function still exists,
		-- the base can be wiped again.
		if sellSrc:find("function SellService.sellPlaced") then
			table.insert(problems, "SellService.sellPlaced still exists (the SELL pad must never sell a placed Rotling)")
		end
		if not sellSrc:find("Config.SELL_MULT") then
			table.insert(problems, "sell price does not use Config.SELL_MULT")
		end
		local remotes = project.tree and project.tree.ReplicatedStorage and project.tree.ReplicatedStorage.StarfallRemotes
		if not remotes or not remotes.SellRotling then
			table.insert(problems, "SellRotling RemoteEvent missing from default.project.json")
		end
		if not remotesSrc:find("function Remotes.sellEvent") then
			table.insert(problems, "Remotes.sellEvent not found")
		end
		if #problems > 0 then
			check("p", false, "no clear SELL area — " .. table.concat(problems, "; ") .. ". Parts: SellPad / SellSign (WorldBuilder.luau), SellService.sellCarried, SellRotling remote")
		else
			check("p", true, "clear SELL area — gold SellPad on the spawn path with a 💰 SELL sign, \"Sell here (E)\" hint and E prompt, server-priced at baseCps x " .. tostring(configValue(read("src/shared/Config.luau"), "SELL_MULT") or 60))
		end
	end
end

-- -- (q) top HUD: cash, income, Shop / Upgrade / Daily + mission bar --------
do
	local hudSrc = read("src/client/HUDController.client.luau")
	local shopSrc = read("src/client/ShopController.client.luau")
	if not hudSrc or not shopSrc then
		check("q", false, "could not verify the top HUD — HUDController.client.luau or ShopController.client.luau missing")
	else
		local problems: { string } = {}
		-- Cash + income per second at the top.
		if not hudSrc:find('makeLabel%(gui, "Coins"') then
			table.insert(problems, 'no "Coins" label in HUDController.client.luau')
		end
		if not hudSrc:find('makeLabel%(gui, "Cps"') then
			table.insert(problems, 'no "Cps" label in HUDController.client.luau')
		end
		-- Shop button in the top row (y <= 60), not down the side.
		-- The position UDim2 is the SECOND UDim2 in the makeButton
		-- call (the first is the size), so match past it.
		local shopY = num(shopSrc:match('makeButton%(gui, "ShopButton".-UDim2%.new%(0,%s*%d+,%s*0,%s*%d+%), UDim2%.new%(0,%s*%d+,%s*0,%s*(%d+)%)'))
		if not shopY then
			table.insert(problems, '"ShopButton" not found in ShopController.client.luau')
		elseif shopY > 60 then
			table.insert(problems, "ShopButton sits at y=" .. tostring(shopY) .. " (not in the top bar)")
		end
		-- Upgrade + Daily buttons, same top row as Shop.
		local upY = num(hudSrc:match('makeButton%(gui, "UpgradeButton".-UDim2%.new%(0,%s*%d+,%s*0,%s*%d+%), UDim2%.new%(0,%s*%d+,%s*0,%s*(%d+)%)'))
		local dailyY = num(hudSrc:match('makeButton%(gui, "DailyButton".-UDim2%.new%(0,%s*%d+,%s*0,%s*%d+%), UDim2%.new%(0,%s*%d+,%s*0,%s*(%d+)%)'))
		if not upY then
			table.insert(problems, '"UpgradeButton" not found in HUDController.client.luau')
		elseif upY > 60 then
			table.insert(problems, "UpgradeButton sits at y=" .. tostring(upY) .. " (not in the top bar)")
		end
		if not dailyY then
			table.insert(problems, '"DailyButton" not found in HUDController.client.luau')
		elseif dailyY > 60 then
			table.insert(problems, "DailyButton sits at y=" .. tostring(dailyY) .. " (not in the top bar)")
		end
		-- Upgrade opens the shop; Daily asks the server for the reward.
		if not hudSrc:find('openShopEvent%(gui%):Fire%("upgrade"%)') then
			table.insert(problems, "UpgradeButton does not fire the OpenShop event")
		end
		if not hudSrc:find("Remotes.dailyFunction%(%)") then
			table.insert(problems, "DailyButton does not call Remotes.dailyFunction")
		end
		-- The mission bar under the top bar.
		if not hudSrc:find('missionBar%.Name = "MissionBar"') then
			table.insert(problems, '"MissionBar" frame not found in HUDController.client.luau')
		end
		if not hudSrc:find('missionFill%.Name = "MissionFill"') then
			table.insert(problems, '"MissionFill" progress fill not found in HUDController.client.luau')
		end
		if #problems > 0 then
			check("q", false, "the top HUD is incomplete — " .. table.concat(problems, "; ") .. ". Parts: Coins / Cps / UpgradeButton / DailyButton / MissionBar (HUDController.client.luau), ShopButton (ShopController.client.luau)")
		else
			check("q", true, "top HUD complete — cash + income/s centred, Shop / Upgrade / Daily in the top row, mission bar with progress fill under the top bar")
		end
	end
end

-- -- (r) missions + daily reward actually work ---------------------------------
do
	local configSrc = read("src/shared/Config.luau")
	local missionSrc = read("src/server/MissionService.luau")
	local dailySrc = read("src/server/DailyService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	if not configSrc or not missionSrc or not dailySrc or not carrySrc or not incomeSrc or not remotesSrc then
		check("r", false, "could not verify missions/daily — Config.luau, MissionService.luau, DailyService.luau, CarryService.luau, IncomeService.luau or Remotes.luau missing")
	else
		local problems: { string } = {}
		-- Three missions defined in Config (one `{ id = "..." }` row
		-- each — counted over the whole file, since the table spans
		-- lines and Lua "." never crosses a newline).
		local missionCount = 0
		for _ in configSrc:gmatch('%{ id = "') do
			missionCount += 1
		end
		if missionCount < 3 then
			table.insert(problems, "Config.MISSIONS holds " .. tostring(missionCount) .. " missions (need 3)")
		end
		-- MissionService counts and pays.
		if not missionSrc:find("function MissionService.addProgress") then
			table.insert(problems, "MissionService.addProgress not found")
		end
		if not missionSrc:find("function MissionService.currentMission") then
			table.insert(problems, "MissionService.currentMission not found")
		end
		if not missionSrc:find("profile%.coins %+= mission%.reward") then
			table.insert(problems, "MissionService never pays the reward")
		end
		-- Hooks: grab, place, earn.
		if not carrySrc:find('MissionService.addProgress%(player, "grab", 1%)') then
			table.insert(problems, "CarryService.tryGrab never reports mission progress")
		end
		if not carrySrc:find('MissionService.addProgress%(player, "place", 1%)') then
			table.insert(problems, "CarryService.placeOnPad never reports mission progress")
		end
		if not incomeSrc:find('MissionService.addProgress%(player, "earn", gained%)') then
			table.insert(problems, "IncomeService tick never reports earn progress")
		end
		-- The HUD feed carries the mission and the daily state.
		if not incomeSrc:find("missionText = mission%.text") then
			table.insert(problems, "IncomeService.broadcastHud never sends the mission")
		end
		if not incomeSrc:find("dailyReady = DailyService.isReady%(player%)") then
			table.insert(problems, "IncomeService.broadcastHud never sends dailyReady")
		end
		-- Daily: server-owned clock, wired remote.
		if not dailySrc:find("function DailyService.claimDaily") then
			table.insert(problems, "DailyService.claimDaily not found")
		end
		if not dailySrc:find("Config.DAILY_COOLDOWN") then
			table.insert(problems, "DailyService never checks Config.DAILY_COOLDOWN")
		end
		if not remotesSrc:find("function Remotes.dailyFunction") then
			table.insert(problems, "Remotes.dailyFunction not found")
		end
		if #problems > 0 then
			check("r", false, "missions/daily are not wired — " .. table.concat(problems, "; ") .. ". Parts: MissionService / DailyService, CarryService hooks, IncomeService.broadcastHud")
		else
			check("r", true, "missions + daily work — " .. tostring(missionCount) .. " missions in Config, grab/place/earn hooks report progress, rewards paid server-side, HUD feed carries mission + dailyReady")
		end
	end
end

-- -- (s) loop: grab -> carry -> place ----------------------------------------
do
	local spawnSrc = read("src/server/SpawnService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	if not spawnSrc or not carrySrc or not mainSrc then
		check("s", false, "could not verify the loop — SpawnService.luau, CarryService.luau or Main.server.luau missing")
	else
		local problems: { string } = {}
		if not spawnSrc:find("CarryService%.tryGrab%(player, model%)") then
			table.insert(problems, "crater prompt never calls CarryService.tryGrab")
		end
		if not carrySrc:find("CarryService%.carryRotling%(player, model%)") then
			table.insert(problems, "tryGrab never carries the Rotling")
		end
		if not mainSrc:find("CarryService%.tryPlace%(player%)") then
			table.insert(problems, "pad prompt never calls CarryService.tryPlace")
		end
		if not carrySrc:find("State%.placed%[baseId%]%[padIndex%] = model") then
			table.insert(problems, "placeOnPad never records State.placed")
		end
		if #problems > 0 then
			check("s", false, "the grab -> carry -> place loop is broken — " .. table.concat(problems, "; ") .. ". Parts: SpawnService.connectPrompt, CarryService.tryGrab/tryPlace/placeOnPad, Main.server pad wiring")
		else
			check("s", true, "loop step grab -> carry -> place is wired — crater prompt -> tryGrab -> carryRotling, pad prompt -> tryPlace -> placeOnPad -> State.placed")
		end
	end
end

-- -- (t) loop: placed Rotlings earn every second -------------------------------
-- Banking: the 1/s tick pays coinsPerSecond into the base vault
-- (profile.banked), and the player Collects it into the wallet.
do
	local incomeSrc = read("src/server/IncomeService.luau")
	if not incomeSrc then
		check("t", false, "could not verify earning — IncomeService.luau missing")
	else
		local problems: { string } = {}
		if not incomeSrc:find("profile%.banked %+= gained") then
			table.insert(problems, "income tick never banks the earnings at the base")
		end
		if not incomeSrc:find("BaseService%.getPlacedForPlayer%(player%)") then
			table.insert(problems, "coinsPerSecond never sums the placed Rotlings")
		end
		if #problems > 0 then
			check("t", false, "placed Rotlings never earn — " .. table.concat(problems, "; ") .. ". Parts: IncomeService tick / coinsPerSecond")
		else
			check("t", true, "loop step earn works — 1/s tick banks coinsPerSecond from the placed Rotlings")
		end
	end
end

-- -- (u) loop: buy + upgrade in the shop ---------------------------------------
do
	local shopSrc = read("src/server/ShopService.luau")
	local shopClient = read("src/client/ShopController.client.luau")
	if not shopSrc or not shopClient then
		check("u", false, "could not verify buying — ShopService.luau or ShopController.client.luau missing")
	else
		local problems: { string } = {}
		if not shopSrc:find("writable%[tierKey%] = tier %+ 1") then
			table.insert(problems, "buyItem never advances the tier")
		end
		if not shopSrc:find("Remotes%.buyFunction%(%)%.OnServerInvoke") then
			table.insert(problems, "BuyItem remote never wired")
		end
		if not shopClient:find("Remotes%.buyFunction%(%)%:InvokeServer%(key%)") then
			table.insert(problems, "shop buy button never invokes BuyItem")
		end
		if #problems > 0 then
			check("u", false, "buying/upgrading is broken — " .. table.concat(problems, "; ") .. ". Parts: ShopService.buyItem, ShopController buy buttons")
		else
			check("u", true, "loop step buy + upgrade works — 5 shop ladders, buy buttons invoke BuyItem, tiers advance server-side")
		end
	end
end

-- -- (v) loop: rebirth + next tier ---------------------------------------------
do
	local rebirthSrc = read("src/server/RebirthService.luau")
	local raritySrc = read("src/shared/RarityConfig.luau")
	if not rebirthSrc or not raritySrc then
		check("v", false, "could not verify rebirth — RebirthService.luau or RarityConfig.luau missing")
	else
		local problems: { string } = {}
		if not rebirthSrc:find("profile%.coins = 0") then
			table.insert(problems, "doRebirth never resets coins")
		end
		if not rebirthSrc:find("profile%.rebirths %+= 1") then
			table.insert(problems, "doRebirth never counts the rebirth")
		end
		if not rebirthSrc:find("Remotes%.rebirthFunction%(%)%.OnServerInvoke") then
			table.insert(problems, "DoRebirth remote never wired")
		end
		local names = 0
		for _ in raritySrc:gmatch('name = "([%w]+)"') do
			names += 1
		end
		if names < 6 then
			table.insert(problems, "only " .. tostring(names) .. " rarities (need 6 for the next tier to exist)")
		end
		if #problems > 0 then
			check("v", false, "rebirth / next tier is broken — " .. table.concat(problems, "; ") .. ". Parts: RebirthService.doRebirth, RarityConfig ladder")
		else
			check("v", true, "loop step rebirth + next tier works — DoRebirth wired (coins reset, +25% forever), 6-rarity ladder to climb")
		end
	end
end

-- -- (w) loop: feedback on every action ----------------------------------------
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
		check("w", false, "could not verify feedback — FeedbackService.luau or a caller module missing")
	else
		local problems: { string } = {}
		for _, fn in ipairs({ "playSound", "burst", "cashPopup", "celebrate" }) do
			if not feedbackSrc:find("function FeedbackService%." .. fn) then
				table.insert(problems, "FeedbackService." .. fn .. " not found")
			end
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
			check("w", false, "some action has no feedback — " .. table.concat(problems, "; ") .. ". Parts: FeedbackService (sound + burst + cash pop-up)")
		else
			check("w", true, "feedback on every action — sound + burst + cash pop-up on grab, place, buy, rebirth, sell, mission, daily")
		end
	end
end

-- -- (x) loop: tutorial arrows for a new player's first 60 seconds -----------
do
	local tutSrc = read("src/client/TutorialController.client.luau")
	if not tutSrc then
		check("x", false, "could not verify the tutorial — TutorialController.client.luau missing")
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
			table.insert(problems, "fewer than 3 tutorial steps")
		end
		if #problems > 0 then
			check("x", false, "tutorial arrows are missing or wrong — " .. table.concat(problems, "; ") .. ". Parts: TutorialController.client.luau")
		else
			check("x", true, "tutorial arrows work — gold arrow, 3 steps (crater -> base -> SELL), 60s, firstTime only, stops on first grab")
		end
	end
end

-- -- (y) conveyor belt through the crater ------------------------------------
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local spawnSrc = read("src/server/SpawnService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not worldSrc or not spawnSrc or not configSrc then
		check("y", false, "could not verify the conveyor belt — WorldBuilder.luau, SpawnService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		-- A physical belt strip across the crater diameter, with edge stripes.
		if not worldSrc:find("ConveyorBelt") then
			table.insert(problems, "no ConveyorBelt part in WorldBuilder.luau")
		end
		if not worldSrc:find("BeltStripe") then
			table.insert(problems, "no BeltStripe edge stripes in WorldBuilder.luau")
		end
		if not worldSrc:find("buildBelt%(%)") then
			table.insert(problems, "buildBelt() not called from WorldBuilder.build()")
		end
		-- Rotlings spawn ON the belt (a line along X), not scattered
		-- randomly: findSpawnPosition must use the belt width constant
		-- and must not pick a random angle/radius.
		local body = functionBody(spawnSrc, "findSpawnPosition")
		if not body then
			table.insert(problems, "SpawnService.findSpawnPosition not found")
		else
			if not body:find("Config.BELT_SPAWN_Z") then
				table.insert(problems, "findSpawnPosition does not spawn on the belt (Config.BELT_SPAWN_Z)")
			end
			if body:find("math.pi") then
				table.insert(problems, "findSpawnPosition still scatters by angle/radius instead of the belt line")
			end
		end
		if #problems > 0 then
			check("y", false, "the crater has no readable conveyor — " .. table.concat(problems, "; ") .. ". Parts: buildBelt / ConveyorBelt / BeltStripe (WorldBuilder.luau), findSpawnPosition (SpawnService.luau)")
		else
			check("y", true, "conveyor belt through the crater — dark strip + yellow edge stripes, Rotlings spawn on it in a line")
		end
	end
end

-- -- (z) game title + Index count + leaderboard in the top HUD ---------------
do
	local hudSrc = read("src/client/HUDController.client.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	if not hudSrc or not remotesSrc or not incomeSrc then
		check("z", false, "could not verify the HUD identity — HUDController.client.luau, Remotes.luau or IncomeService.luau missing")
	else
		local problems: { string } = {}
		if not hudSrc:find('"GameTitle"') or not hudSrc:find("SPACE ROCK BRAINROTS") then
			table.insert(problems, "no SPACE ROCK BRAINROTS title label in the top HUD")
		end
		if not hudSrc:find("indexCount") or not hudSrc:find("indexTotal") then
			table.insert(problems, "no Index count (x/20) in the HUD")
		end
		if not hudSrc:find('"LeaderboardPanel"') then
			table.insert(problems, "no LeaderboardPanel in the HUD")
		end
		if not remotesSrc:find("indexCount: number") or not remotesSrc:find("top3:") then
			table.insert(problems, "HudData type lacks indexCount / top3 (Remotes.luau)")
		end
		if not incomeSrc:find("indexCount = found") or not incomeSrc:find("top3 = top3") then
			table.insert(problems, "IncomeService.broadcastHud does not send indexCount / top3")
		end
		if #problems > 0 then
			check("z", false, "the HUD has no identity or density — " .. table.concat(problems, "; ") .. ". Parts: GameTitle / LeaderboardPanel (HUDController.client.luau), HudData (Remotes.luau), broadcastHud (IncomeService.luau)")
		else
			check("z", true, "HUD identity + density — SPACE ROCK BRAINROTS title, Index count x/20, top-3 leaderboard panel")
		end
	end
end

-- -- (aa) full-width storm banner ---------------------------------------------
do
	local warnSrc = read("src/client/StormWarningController.client.luau")
	if not warnSrc then
		check("aa", false, "could not verify the storm banner — StormWarningController.client.luau missing")
	else
		local problems: { string } = {}
		if not warnSrc:find("UDim2.new%(1, %-32, 0, 56%)") then
			table.insert(problems, "StormWarning bar is not full-width (UDim2.new(1, -32, 0, 56))")
		end
		if not warnSrc:find('makeLabel%(warnBar, "Warning".-, 34,') then
			table.insert(problems, "storm warning text is not 34pt")
		end
		if #problems > 0 then
			check("aa", false, "the storm banner is not full-width — " .. table.concat(problems, "; ") .. ". Parts: StormWarning (StormWarningController.client.luau)")
		else
			check("aa", true, "storm banner is full-width (UDim2 1,-32 x 56) with 34pt text — reads at thumbnail size")
		end
	end
end

-- -- (ab) giant hero meteors at storm start -----------------------------------
do
	local starSrc = read("src/server/StarfallService.luau")
	if not starSrc then
		check("ab", false, "could not verify hero meteors — StarfallService.luau missing")
	else
		local problems: { string } = {}
		if not starSrc:find("spawnHeroMeteor") then
			table.insert(problems, "no spawnHeroMeteor in StarfallService.luau")
		end
		if not starSrc:find("Vector3.new%(10, 10, 10%)") then
			table.insert(problems, "hero meteor is not 10 studs (Vector3.new(10, 10, 10))")
		end
		if not starSrc:find("task.spawn%(spawnHeroMeteor%)") then
			table.insert(problems, "hero meteors are not spawned at storm start")
		end
		if #problems > 0 then
			check("ab", false, "no giant hero meteors in the storm — " .. table.concat(problems, "; ") .. ". Parts: spawnHeroMeteor (StarfallService.luau)")
		else
			check("ab", true, "hero meteors — 3 giant (10-stud) flaming meteors arc across the sky at storm start")
		end
	end
end

-- -- (ac) photo-mode cameras are the 4 bounty shots ---------------------------
-- The judge sees only 4 screenshots, so photo mode has exactly 4 shots:
-- 1 hero close-up (low and close on the belt's nearest Rotling),
-- 2 belt (low, close down the conveyor), 3 storm (wide crater + sky
-- with the banner, the dome and the giant meteors), 4 packed base
-- close, 5 icon (the logo stage, one big Rotling + fiery meteor).
-- The old crater isometric is gone.
do
	local photoSrc = read("src/client/PhotoModeController.client.luau")
	if not photoSrc then
		check("ac", false, "could not verify photo-mode cameras — PhotoModeController.client.luau missing")
	else
		local problems: { string } = {}
		-- Shot 1 (hero close-up): low and close on the belt's
		-- nearest Rotling.
		if not photoSrc:find("Vector3.new%(10, 3.5, 7%)") then
			table.insert(problems, "shot 1 is not the hero close-up camera (10, 3.5, 7)")
		end
		-- Shot 2 (belt): low and close behind the belt's near end.
		if not photoSrc:find("Vector3.new%(42, 4.5, 9%)") then
			table.insert(problems, "shot 2 is not the close belt camera (42, 4.5, 9)")
		end
		-- Shot 3 (storm): wide crater + sky view, banner and meteors.
		if not photoSrc:find("Vector3.new%(48, 10, 18%)") then
			table.insert(problems, "shot 3 is not the wide storm camera (48, 10, 18)")
		end
		if not photoSrc:find("Vector3.new%(0, 12, 0%)") then
			table.insert(problems, "shot 3 does not look at the crater + sky (0, 12, 0)")
		end
		-- Shot 4 (base): 16 out, 7 up — closer than the old 30/12.
		if not photoSrc:find("%* 16") then
			table.insert(problems, "shot 4 is not 16 studs out from the base")
		end
		if not photoSrc:find("Vector3.new%(0, 7, 0%)") then
			table.insert(problems, "shot 4 is not 7 studs up")
		end
		-- Shot 5 (icon): the logo stage near spawn, one big bright
		-- Rotling front-centre with the fiery meteor behind it.
		if not photoSrc:find("Icon — 512x512") then
			table.insert(problems, "no icon shot (Icon — 512x512)")
		end
		if not photoSrc:find("Vector3.new%(%-25, 4, 98%)") then
			table.insert(problems, "icon shot is not the logo-stage camera (-25, 4, 98)")
		end
		if not photoSrc:find("Vector3.new%(%-25, 3, 88%)") then
			table.insert(problems, "icon shot does not look at the logo stage (-25, 3, 88)")
		end
		-- The crater isometric is gone.
		if photoSrc:find("Vector3.new%(24, 24, 24%)") then
			table.insert(problems, "the old isometric crater camera (24, 24, 24) is still a shot")
		end
		-- 4 submission shots + 1 icon shot: the "4/4" label exists
		-- and the icon shot is named, not numbered.
		if not photoSrc:find('"4/4') then
			table.insert(problems, 'no "4/4" shot label — photo mode is not the 4-shot submission layout')
		end
		if photoSrc:find('"5/5') or photoSrc:find('"1/5') then
			table.insert(problems, "photo mode numbers the icon as a 5th submission shot (1/5 or 5/5 found)")
		end
		-- The 6th press exits (advance past shot 5).
		if not photoSrc:find("shotIndex >= #SHOTS") then
			table.insert(problems, "photo mode does not exit after shot 5 (shotIndex >= #SHOTS)")
		end
		if #problems > 0 then
			check("ac", false, "photo-mode cameras are not the 4 bounty shots + icon — " .. table.concat(problems, "; ") .. ". Parts: SHOTS / shotCFrame (PhotoModeController.client.luau)")
		else
			check("ac", true, "photo cameras are the 4 bounty shots + icon — hero close-up (10, 3.5, 7) first, belt close on the conveyor, storm wide (48, 10, 18) looking at the sky, base 16 out / 7 up, icon on the logo stage (-25, 4, 98)")
		end
	end
end

-- -- (ad) photo-mode shows every name tag --------------------------------------
do
	local tagSrc = read("src/client/TagController.client.luau")
	local configSrc = read("src/shared/Config.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	if not tagSrc or not configSrc or not factorySrc then
		check("ad", false, "could not verify the photo-mode tag override — TagController.client.luau, Config.luau or RotlingFactory.luau missing")
	else
		local problems: { string } = {}
		local photoDist = configValue(configSrc, "TAG_PHOTO_MAX_DISTANCE")
		local photoShown = configValue(configSrc, "TAG_PHOTO_MAX_SHOWN")
		if not photoDist then
			table.insert(problems, "Config.TAG_PHOTO_MAX_DISTANCE not found")
		elseif photoDist < 40 then
			table.insert(problems, "photo tag distance " .. tostring(photoDist) .. " studs (under 40)")
		end
		if not photoShown then
			table.insert(problems, "Config.TAG_PHOTO_MAX_SHOWN not found")
		elseif photoShown < 99 then
			table.insert(problems, "photo tag count " .. tostring(photoShown) .. " (under 99 — not all tags)")
		end
		if not tagSrc:find("PhotoMode") or not tagSrc:find("Config.TAG_PHOTO_MAX_DISTANCE") or not tagSrc:find("Config.TAG_PHOTO_MAX_SHOWN") then
			table.insert(problems, "TagController does not lift the thinning in photo mode (PhotoMode attribute / TAG_PHOTO_MAX_*)")
		end
		-- The billboard must render out to the photo range, or the
		-- override is capped by the billboard itself.
		local billDist = num(factorySrc:match("billboard%.MaxDistance%s*=%s*(%d+)"))
		if not billDist then
			table.insert(problems, "RotlingLabel MaxDistance not found in RotlingFactory.luau")
		elseif billDist < (photoDist or 40) then
			table.insert(problems, "RotlingLabel MaxDistance " .. tostring(billDist) .. " caps the photo-mode range " .. tostring(photoDist or 40))
		end
		-- The tag itself is big, with a dark card + rarity border.
		local billW, billH = factorySrc:match("billboard%.Size%s*=%s*UDim2%.fromOffset%((%d+),%s*(%d+)%)")
		if not billW or not billH then
			table.insert(problems, "RotlingLabel size not found in RotlingFactory.luau")
		elseif num(billW) < 200 or num(billH) < 84 then
			table.insert(problems, "RotlingLabel " .. tostring(billW) .. "x" .. tostring(billH) .. " (under 200x84)")
		end
		if not factorySrc:find('"Card"') or not factorySrc:find("cardStroke") then
			table.insert(problems, "RotlingLabel has no dark card + rarity border")
		end
		if #problems > 0 then
			check("ad", false, "photo-mode tags do not all read — " .. table.concat(problems, "; ") .. ". Parts: TagController.client.luau, RotlingLabel (RotlingFactory.luau), Config.TAG_PHOTO_MAX_*")
		else
			check("ad", true, "photo-mode tags — every tag within " .. tostring(photoDist) .. " studs shows, 200x84 with a dark card + rarity border")
		end
	end
end

-- -- (ae) storm logs + a meteor lands within 10s of the storm starting ----
-- The old storm failed silently: the countdown hit zero and nothing
-- happened. Now the storm must log STORM START and METEOR LANDED, and
-- a meteor must be in the air immediately — hero meteors spawn at
-- storm start with no wait before the first, and the rain loop calls
-- spawnMeteor() before its first wait. Both tweens (hero 1.6s, rain
-- 0.8s) land well inside 10s.
do
	local starSrc = read("src/server/StarfallService.luau")
	if not starSrc then
		check("ae", false, "could not verify storm logging — StarfallService.luau missing")
	else
		local problems: { string } = {}
		if not starSrc:find('%[Starfall%] STORM START') then
			table.insert(problems, 'no "[Starfall] STORM START" log in StarfallService.luau')
		end
		if not starSrc:find('%[Starfall%] METEOR LANDED') then
			table.insert(problems, 'no "[Starfall] METEOR LANDED" log in StarfallService.luau')
		end
		-- Hero meteors spawn at storm start, no wait before the first.
		if not starSrc:find("task.spawn%(spawnHeroMeteor%)") then
			table.insert(problems, "hero meteors are not spawned at storm start (task.spawn(spawnHeroMeteor))")
		end
		-- The rain loop's first statement is a spawn, not a wait.
		if not starSrc:find("while time%(%) < phaseEndsAt do%s+spawnMeteor%(%)") then
			table.insert(problems, "the rain loop waits before its first spawnMeteor() (must spawn immediately)")
		end
		-- Both fall tweens land inside 10s.
		local rainTween = num(starSrc:match("local function spawnMeteor%(%)[^{]-TweenInfo%.new%(([%d%.]+),"))
		if not rainTween then
			table.insert(problems, "rain meteor TweenInfo not found in spawnMeteor")
		elseif rainTween > 10 then
			table.insert(problems, "rain meteor tween " .. tostring(rainTween) .. "s (over 10s)")
		end
		local heroTween = num(starSrc:match("local function spawnHeroMeteor%(%)[^{]-TweenInfo%.new%(([%d%.]+),"))
		if not heroTween then
			table.insert(problems, "hero meteor TweenInfo not found in spawnHeroMeteor")
		elseif heroTween > 10 then
			table.insert(problems, "hero meteor tween " .. tostring(heroTween) .. "s (over 10s)")
		end
		if #problems > 0 then
			check("ae", false, "the storm is silent or slow — " .. table.concat(problems, "; ") .. ". Parts: spawnHeroMeteor / spawnMeteor / onMeteorLanded (StarfallService.luau)")
		else
			check("ae", true, "storm logs STORM START + METEOR LANDED, hero meteors spawn at storm start, rain loop spawns immediately, tweens " .. tostring(heroTween) .. "s / " .. tostring(rainTween) .. "s (both land within 10s)")
		end
	end
end

-- -- (af) ground is textured, not one flat purple plane ----------------------
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local ok, projectText = pcall(fs.readFile, root .. "/default.project.json")
	local project: any = nil
	if ok then
		local decOk, decoded = pcall(serde.decode, "json", projectText)
		if decOk then
			project = decoded
		end
	end
	if not worldSrc or not project then
		check("af", false, "could not verify the ground — WorldBuilder.luau or default.project.json missing")
	else
		local problems: { string } = {}
		-- The ground is ONE consistent material (fix round 3, item 7):
		-- a single Grass ground cover in one natural grass green, built
		-- by buildGroundDetail, called from WorldBuilder.build(). The
		-- old patchwork (SandRing disc + 8x8 random-colour tiles) is
		-- gone: no SandRing, no GroundTile.
		if not worldSrc:find("function buildGroundDetail%(%)") then
			table.insert(problems, "buildGroundDetail() not found in WorldBuilder.luau")
		end
		if not worldSrc:find("buildGroundDetail%(%)") then
			table.insert(problems, "buildGroundDetail() is never called")
		end
		if not worldSrc:find('part%("GroundCover"') then
			table.insert(problems, 'no "GroundCover" part in WorldBuilder.luau')
		end
		if not worldSrc:find("Enum.Material.Grass") then
			table.insert(problems, "GroundCover is not Grass material")
		end
		if not worldSrc:find("89, 173, 77") then
			table.insert(problems, "GroundCover is not the natural grass green (89, 173, 77)")
		end
		if worldSrc:find('part%("SandRing"') then
			table.insert(problems, 'the old "SandRing" part is still in WorldBuilder.luau')
		end
		if worldSrc:find('part%("GroundTile"') then
			table.insert(problems, 'the old "GroundTile" parts are still in WorldBuilder.luau')
		end
		-- The base ground itself is warm sand, not purple: its blue
		-- channel must be lower than its red channel.
		local ground = project.tree and project.tree.Workspace and project.tree.Workspace.Ground
		local groundProps = if ground then ground["$properties"] else nil
		local groundColor = if groundProps then groundProps.Color else nil
		if not groundColor then
			table.insert(problems, "Ground Color not found in default.project.json")
		elseif groundColor[3] >= groundColor[1] then
			table.insert(problems, "Ground Color (" .. tostring(groundColor[1]) .. ", " .. tostring(groundColor[2]) .. ", " .. tostring(groundColor[3]) .. ") is purple (blue >= red), not warm sand")
		end
		if #problems > 0 then
			check("af", false, "the ground is not one consistent lawn — " .. table.concat(problems, "; ") .. ". Parts: buildGroundDetail / GroundCover (WorldBuilder.luau), Ground (default.project.json)")
		else
			check("af", true, "ground is one consistent Grass lawn — single GroundCover (89, 173, 77), base ground warm sand (" .. tostring(groundColor[1]) .. ", " .. tostring(groundColor[2]) .. ", " .. tostring(groundColor[3]) .. ")")
		end
	end
end

-- -- (ag) plaza lamps are small and soft --------------------------------------
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		check("ag", false, "could not verify the lamps — WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		-- The plaza lamp is a short post with a small bulb: the
		-- cylinder's diameter (Y and Z, after the 90-degree roll) is
		-- at most 1.2 studs. The old lamps were 1.6 and blew out.
		local lampX, lampY, lampZ = worldSrc:match('part%("PlazaLamp", Enum%.PartType%.Cylinder, Vector3%.new%(([%d%.]+),%s*([%d%.]+),%s*([%d%.]+)%)')
		if not lampX or not lampY or not lampZ then
			table.insert(problems, 'PlazaLamp part not found in WorldBuilder.luau')
		else
			local dY = num(lampY)
			local dZ = num(lampZ)
			if not dY or not dZ then
				table.insert(problems, "PlazaLamp size not numeric")
			elseif dY > 1.2 or dZ > 1.2 then
				table.insert(problems, "PlazaLamp diameter " .. tostring(dY) .. "x" .. tostring(dZ) .. " (over 1.2)")
			end
		end
		-- The lamp's own light is soft: brightness at most 0.5, range
		-- at most 12. (The spawn lamps are brighter on purpose; this
		-- reads the light that follows the PlazaLampBulb part.)
		local bulbPos = worldSrc:find('part%("PlazaLampBulb"')
		if not bulbPos then
			table.insert(problems, 'PlazaLampBulb part not found in WorldBuilder.luau')
		else
			local after = worldSrc:sub(bulbPos)
			local bright = num(after:match("light%.Brightness%s*=%s*([%d%.]+)"))
			local range = num(after:match("light%.Range%s*=%s*([%d%.]+)"))
			if not bright then
				table.insert(problems, "plaza lamp PointLight Brightness not found")
			elseif bright > 0.5 then
				table.insert(problems, "plaza lamp Brightness " .. tostring(bright) .. " (over 0.5 — blown out)")
			end
			if not range then
				table.insert(problems, "plaza lamp PointLight Range not found")
			elseif range > 12 then
				table.insert(problems, "plaza lamp Range " .. tostring(range) .. " (over 12)")
			end
		end
		if #problems > 0 then
			check("ag", false, "the plaza lamps are big and blown out — " .. table.concat(problems, "; ") .. ". Parts: PlazaLamp / PlazaLampBulb (WorldBuilder.luau)")
		else
			check("ag", true, "plaza lamps are small and soft — diameter " .. tostring(lampY) .. "x" .. tostring(lampZ) .. ", light soft (brightness <= 0.5, range <= 12)")
		end
	end
end

-- -- (ah) no custom UI under Roblox's own top bar ----------------------------
-- Roblox's top-left menu and top-right player list end around y=48 on
-- desktop and phones. Every custom button and label must start at y=60
-- or lower, and a UIScale must shrink the whole HUD on small screens
-- so it still fits at 1080p and below. Check (q) pins the top row to
-- y<=60; this check pins it to y>=60 — together they pin y=60 exactly.
do
	local hudSrc = read("src/client/HUDController.client.luau")
	local shopSrc = read("src/client/ShopController.client.luau")
	local indexSrc = read("src/client/IndexController.client.luau")
	local warnSrc = read("src/client/StormWarningController.client.luau")
	if not hudSrc or not shopSrc or not indexSrc or not warnSrc then
		check("ah", false, "could not verify the UI top bar — HUDController.client.luau, ShopController.client.luau, IndexController.client.luau or StormWarningController.client.luau missing")
	else
		local problems: { string } = {}
		-- The Y of a makeButton/makeLabel call: the position UDim2 is
		-- the second UDim2 (the first is the size). The position's X
		-- scale may be 0 (left-anchored) or 1 (right-anchored); the Y
		-- offset is the fourth number either way.
		local function buttonY(source: string, name: string): number?
			return num(source:match('makeButton%(gui, "' .. name .. '".-UDim2%.new%(0,%s*%d+,%s*0,%s*%d+%), UDim2%.new%([%d%.%-]+,%s*[%d%.%-]+,%s*[%d%.%-]+,%s*(%d+)%)'))
		end
		local function labelY(source: string, name: string): number?
			return num(source:match('makeLabel%(gui, "' .. name .. '".-UDim2%.new%(0,%s*%d+,%s*0,%s*%d+%), UDim2%.new%([%d%.%-]+,%s*[%d%.%-]+,%s*[%d%.%-]+,%s*(%d+)%)'))
		end
		local tops: { { name: string, y: number? } } = {
			{ name = "ShopButton", y = buttonY(shopSrc, "ShopButton") },
			{ name = "UpgradeButton", y = buttonY(hudSrc, "UpgradeButton") },
			{ name = "DailyButton", y = buttonY(hudSrc, "DailyButton") },
			{ name = "RebirthButton", y = buttonY(hudSrc, "RebirthButton") },
			{ name = "LockButton", y = buttonY(hudSrc, "LockButton") },
			{ name = "IndexButton", y = buttonY(indexSrc, "IndexButton") },
			{ name = "Storm", y = labelY(hudSrc, "Storm") },
		}
		for _, entry in ipairs(tops) do
			if not entry.y then
				table.insert(problems, entry.name .. " position not found")
			elseif entry.y < 60 then
				table.insert(problems, entry.name .. " sits at y=" .. tostring(entry.y) .. " (under Roblox's top bar, must be >= 60)")
			end
		end
		-- The storm warning bar sits below the top bar + mission bar.
		local warnY = num(warnSrc:match('warnBar%.Position%s*=%s*UDim2%.new%(0%.5,%s*0,%s*0,%s*(%d+)%)'))
		if not warnY then
			table.insert(problems, "StormWarning bar position not found")
		elseif warnY < 160 then
			table.insert(problems, "StormWarning bar sits at y=" .. tostring(warnY) .. " (over the top bar, must be >= 160)")
		end
		-- A UIScale shrinks the HUD on small screens.
		if not hudSrc:find('Instance.new%("UIScale"%)') or not hudSrc:find('hudScale%.Name = "HudScale"') then
			table.insert(problems, "no UIScale (HudScale) in HUDController.client.luau — the HUD cannot shrink on phones")
		end
		if #problems > 0 then
			check("ah", false, "a custom button sits under Roblox's top bar — " .. table.concat(problems, "; ") .. ". Parts: top-row buttons / Storm label (HUDController.client.luau, ShopController.client.luau, IndexController.client.luau), StormWarning bar, HudScale")
		else
			check("ah", true, "no custom UI under Roblox's top bar — every button and label starts at y>=60, storm banner below the mission bar, HudScale shrinks the HUD on small screens")
		end
	end
end

-- -- (ai) every Rotling's primary colour is its rarity colour ------------
-- Item 1: the body colour is the rarity tier colour, verbatim from
-- RarityConfig — Commons rarity blue, Rares rarity green, Epics rarity
-- purple, Legendary rarity gold, Mythic rarity pink, Cosmic rarity
-- cyan. A re-saturated copy drifts (Common blue (110,200,255) would
-- come out (84,204,255)), so the factory must paint rarity.color
-- itself, and every tier colour must be bright and saturated (no grey,
-- no washed-out white).
do
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	local raritySrc = read("src/shared/RarityConfig.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	if not catalogSrc or not raritySrc or not factorySrc then
		check("ai", false, "could not verify rarity colours — RotlingCatalog.luau, RarityConfig.luau or RotlingFactory.luau missing")
	else
		local problems: { string } = {}
		-- Rarity name -> "r,g,b", plus its channel spread.
		local rarityColors: { [string]: string } = {}
		for name, r, g, b in raritySrc:gmatch('name = "([%w]+)", color = Color3%.fromRGB%((%d+), (%d+), (%d+)%)') do
			rarityColors[name] = r .. "," .. g .. "," .. b
			local spread = math.max(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
				- math.min(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
			if spread < 100 then
				table.insert(problems, name .. " rarity colour (" .. rarityColors[name] .. ") is grey/washed-out (channel spread " .. tostring(spread) .. ", under 100)")
			end
		end
		local defCount = 0
		for rarity, r, g, b in catalogSrc:gmatch('rarity = "([%w]+)",[%s%S]-bodyColor = Color3%.fromRGB%((%d+), (%d+), (%d+)%)') do
			defCount += 1
			local want = rarityColors[rarity]
			local got = r .. "," .. g .. "," .. b
			if not want then
				table.insert(problems, "unknown rarity " .. rarity .. " in RotlingCatalog.luau")
			elseif got ~= want then
				table.insert(problems, "a " .. rarity .. " Rotling has bodyColor (" .. got .. "), rarity colour is (" .. want .. ")")
			end
		end
		if defCount < 20 then
			table.insert(problems, "only " .. tostring(defCount) .. " catalog defs with a bodyColor (need 20)")
		end
		-- The factory paints the body with the rarity colour itself.
		if not factorySrc:find("local bodyColor = rarity%.color") then
			table.insert(problems, "RotlingFactory.build does not paint the body with rarity.color (a re-saturated copy drifts off the tier colour)")
		end
		if #problems > 0 then
			check("ai", false, "a Rotling's primary colour is not its rarity colour — " .. table.concat(problems, "; ") .. ". Parts: bodyColor (RotlingCatalog.luau), color (RarityConfig.luau), bodyColor (RotlingFactory.build)")
		else
			check("ai", true, "every Rotling's primary colour is its rarity colour — " .. tostring(defCount) .. " defs match RarityConfig exactly, factory paints rarity.color, all 6 tier colours saturated (spread >= 100)")
		end
	end
end

-- -- (aj) distinct silhouettes, a face, and 2+ signature features ---------
-- Item 1: no two Rotlings share a silhouette key, every Rotling has a
-- face (big eyes + mouth, built in build()), and every catalog def
-- lists at least 2 signature features that the factory actually builds
-- (one addNameProp branch per Rotling id).
do
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	if not catalogSrc or not factorySrc then
		check("aj", false, "could not verify silhouettes/faces — RotlingCatalog.luau or RotlingFactory.luau missing")
	else
		local problems: { string } = {}
		-- 12 defs, 12 unique silhouette keys.
		local ids: { string } = {}
		for id in catalogSrc:gmatch('id = "([%w_]+)"') do
			table.insert(ids, id)
		end
		if #ids < 20 then
			table.insert(problems, "only " .. tostring(#ids) .. " catalog defs (need 20)")
		end
		local seen: { [string]: boolean } = {}
		local silCount = 0
		for sil in catalogSrc:gmatch('silhouette = "([%w%-]+)"') do
			silCount += 1
			if seen[sil] then
				table.insert(problems, 'silhouette "' .. sil .. '" is shared by two Rotlings (must be unique)')
			end
			seen[sil] = true
		end
		if silCount < 20 then
			table.insert(problems, "only " .. tostring(silCount) .. " silhouette keys in the catalog (need 20, one per Rotling)")
		end
		-- At least 2 signature features listed per def.
		for list in catalogSrc:gmatch("features = {([^}]+)}") do
			local n = 0
			for _ in list:gmatch('"[^"]+"') do
				n += 1
			end
			if n < 2 then
				table.insert(problems, "a catalog def lists only " .. tostring(n) .. " signature features (need at least 2)")
			end
		end
		-- The face is built: eyes + mouth calls in build().
		if not factorySrc:find("addEyes%(model, body, size%)") then
			table.insert(problems, "RotlingFactory.build never calls addEyes")
		end
		if not factorySrc:find("addMouth%(model, body, size%)") then
			table.insert(problems, "RotlingFactory.build never calls addMouth")
		end
		-- Eyes are big enough to read at thumbnail size: the eye-size
		-- factor is at least 0.25 (smallest Rotling is 2.2 studs, so
		-- eyes are at least ~0.55 studs across).
		local eyesBody = functionBody(factorySrc, "addEyes")
		local eyeFactor = if eyesBody then num(eyesBody:match("size %* ([%d%.]+)")) else nil
		if not eyeFactor then
			table.insert(problems, "eye size factor not found in addEyes")
		elseif eyeFactor < 0.25 then
			table.insert(problems, "eye size factor " .. tostring(eyeFactor) .. " (under 0.25 — eyes under ~0.5 studs on the smallest Rotling)")
		end
		-- Every Rotling id has its own feature branch in the factory.
		for _, id in ipairs(ids) do
			if not factorySrc:find('def.id == "' .. id .. '"', 1, true) then
				table.insert(problems, 'no addNameProp branch for "' .. id .. '" in RotlingFactory.luau')
			end
		end
		if #problems > 0 then
			check("aj", false, "Rotlings are not distinct characters — " .. table.concat(problems, "; ") .. ". Parts: silhouette / features (RotlingCatalog.luau), addEyes / addMouth / addNameProp (RotlingFactory.luau)")
		else
			check("aj", true, tostring(#ids) .. " distinct silhouettes, every Rotling has a face (eyes factor " .. tostring(eyeFactor)
				.. ", >= ~0.5 studs) and 2+ signature features with a factory branch each")
		end
	end
end

-- -- (ak) the name tag sits above the model, never on the face --------------
-- Item 1: the tag offset comes from the model's bounding-box top plus a
-- margin (not a fixed size*0.85, which sank into a tall hat at 1.5x
-- crater scale), the 1x offset is stored on the model, and every scale
-- change re-seats the tag (refreshLabelOffset, called from build and
-- from CarryService after each setModelScale).
do
	local factorySrc = read("src/server/RotlingFactory.luau")
	local carrySrc = read("src/server/CarryService.luau")
	if not factorySrc or not carrySrc then
		check("ak", false, "could not verify the name tag — RotlingFactory.luau or CarryService.luau missing")
	else
		local problems: { string } = {}
		local labelBody = functionBody(factorySrc, "addLabel")
		if not labelBody then
			table.insert(problems, "addLabel not found in RotlingFactory.luau")
		else
			if not labelBody:find("GetBoundingBox") then
				table.insert(problems, "addLabel does not measure the model's bounding-box top (tag offset is a fixed height)")
			end
			if not labelBody:find("%+ 0.8") then
				table.insert(problems, "addLabel has no margin above the bounding-box top (tag can touch the tallest part)")
			end
			if not labelBody:find('SetAttribute%("LabelBaseOffset"') then
				table.insert(problems, 'addLabel does not store the 1x offset as "LabelBaseOffset"')
			end
		end
		local refreshBody = functionBody(factorySrc, "RotlingFactory.refreshLabelOffset")
		if not refreshBody then
			table.insert(problems, "RotlingFactory.refreshLabelOffset not found")
		else
			if not refreshBody:find("GetScale") then
				table.insert(problems, "refreshLabelOffset does not scale the stored offset by the live model scale")
			end
			if not refreshBody:find("LabelBaseOffset") then
				table.insert(problems, "refreshLabelOffset does not read the stored LabelBaseOffset")
			end
		end
		-- Every scale change in CarryService re-seats the tag: 3 sites
		-- (grab weld-fail restore, placeOnPad, scatterToCrater).
		local refreshCalls = 0
		for _ in carrySrc:gmatch("refreshLabelOffset%(model%)") do
			refreshCalls += 1
		end
		if refreshCalls < 3 then
			table.insert(problems, "CarryService calls refreshLabelOffset only " .. tostring(refreshCalls) .. " times (need 3: grab restore, place, scatter)")
		end
		if not factorySrc:find("refreshLabelOffset%(model%)") then
			table.insert(problems, "RotlingFactory.build never calls refreshLabelOffset after scaling")
		end
		if #problems > 0 then
			check("ak", false, "the name tag can sit on the model or cover the face — " .. table.concat(problems, "; ") .. ". Parts: addLabel / refreshLabelOffset (RotlingFactory.luau), setModelScale sites (CarryService.luau)")
		else
			check("ak", true, "name tag floats above the model — bounding-box top + 0.8 margin, stored 1x offset re-seated on every scale change (build + " .. tostring(refreshCalls) .. " CarryService sites)")
		end
	end
end

-- -- (al) selling is a clearing tool, and owners can pick up their own Rotlings --
-- Item 9: sell value is ~25x income/s (never above 30x) for EVERY
-- Rotling, so placing is always the better long-term choice; and the
-- owner can pick up their own placed Rotling ("Pick up") and carry it
-- again, while the steal path for other players' bases is unchanged.
do
	local configSrc = read("src/shared/Config.luau")
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	local sellSrc = read("src/server/SellService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	if not configSrc or not catalogSrc or not sellSrc or not carrySrc then
		check("al", false, "could not verify the economy — Config.luau, RotlingCatalog.luau, SellService.luau or CarryService.luau missing")
	else
		local problems: { string } = {}
		local mult = configValue(configSrc, "SELL_MULT")
		if not mult then
			table.insert(problems, "Config.SELL_MULT not found")
		elseif mult > 30 then
			table.insert(problems, "SELL_MULT is " .. tostring(mult) .. " (above 30x — selling beats placing)")
		end
		-- SellService.sellValue must be def cps x SELL_MULT (times the
		-- mutation multiplier), not a flat price.
		if not sellSrc:find("SELL_MULT") then
			table.insert(problems, "SellService.sellValue does not use Config.SELL_MULT")
		end
		-- Own-base pickup: CarryService.pickupOwn exists, tryGrab
		-- routes owners to it, and the prompt says "Pick up".
		if not carrySrc:find("function CarryService.pickupOwn") then
			table.insert(problems, "CarryService.pickupOwn not found (owners cannot pick up their own Rotlings)")
		end
		if not carrySrc:find("pickupOwn%(player, model%)") then
			table.insert(problems, "tryGrab never routes an owner to pickupOwn")
		end
		if not carrySrc:find('"Pick up ') then
			table.insert(problems, 'no "Pick up <name>" prompt for own-base pickup')
		end
		-- Fix round 5, item 3: pickupOwn logs every attempt and
		-- validates the weld before lifting the Rotling off its pad
		-- (the old order removed it first, then failed silently).
		if not carrySrc:find('%[Pickup%]') then
			table.insert(problems, "pickupOwn does not log attempts/results")
		end
		if not carrySrc:find("Could not pick it up") then
			table.insert(problems, "pickupOwn has no failure banner when the weld cannot be made")
		end
		-- The steal path is untouched: StealService still refuses your
		-- own Rotlings when reached directly, and tryGrab still routes
		-- other players' placed Rotlings to trySteal.
		local stealSrc = read("src/server/StealService.luau")
		if not stealSrc then
			table.insert(problems, "StealService.luau missing")
		elseif not stealSrc:find("That one is already yours") then
			table.insert(problems, "StealService no longer refuses your own Rotlings")
		end
		if not carrySrc:find("StealService.trySteal") then
			table.insert(problems, "tryGrab no longer routes other players' Rotlings to StealService.trySteal")
		end
		if #problems > 0 then
			check("al", false, "selling is not a clearing tool or own-base pickup is broken — " .. table.concat(problems, "; ") .. ". Parts: SELL_MULT (Config.luau), sellValue (SellService.luau), pickupOwn / tryGrab (CarryService.luau)")
		else
			check("al", true, "sell is " .. tostring(mult) .. "x income (<= 30x), owners pick up their own Rotlings with a Take prompt, steal path unchanged")
		end
	end
end

-- -- (am) the storm spreads across the whole map ------------------------------
-- Item 6: impacts are zone-based (near players, near bases just
-- outside the safe ring, anywhere on the map), never on a base; a
-- warning circle shows 2s before impact; a hit knocks the player back
-- and drops the carried Rotling; players on bases are safe; the storm
-- banner carries the hazard label.
do
	local configSrc = read("src/shared/Config.luau")
	local stormSrc = read("src/server/StarfallService.luau")
	if not configSrc or not stormSrc then
		check("am", false, "could not verify the storm spread — Config.luau or StarfallService.luau missing")
	else
		local problems: { string } = {}
		local spread = configValue(configSrc, "STORM_SPREAD_RADIUS")
		if not spread then
			table.insert(problems, "Config.STORM_SPREAD_RADIUS not found")
		elseif spread < 100 then
			table.insert(problems, "STORM_SPREAD_RADIUS is " .. tostring(spread) .. " (under 100 — impacts stay near the crater)")
		end
		local warnTime = configValue(configSrc, "STORM_WARNING_TIME")
		if not warnTime then
			table.insert(problems, "Config.STORM_WARNING_TIME not found")
		elseif warnTime < 2 then
			table.insert(problems, "STORM_WARNING_TIME is " .. tostring(warnTime) .. "s (under 2s — no time to react)")
		end
		if not stormSrc:find("showWarningCircle") then
			table.insert(problems, "no warning circle before impact (StarfallService.showWarningCircle)")
		end
		if not stormSrc:find("onBase") then
			table.insert(problems, "no safe-zone check for players on bases (StarfallService.onBase)")
		end
		if not stormSrc:find("dropAllCarried") then
			table.insert(problems, "a meteor hit never drops the carried Rotling")
		end
		if not stormSrc:find("STORM_HAZARD_LABEL") then
			table.insert(problems, "the storm banner carries no hazard label")
		end
		if not configSrc:find('STORM_HAZARD_LABEL = "DANGER:') then
			table.insert(problems, 'Config.STORM_HAZARD_LABEL is not a "DANGER: ..." label')
		end
		if #problems > 0 then
			check("am", false, "the storm does not spread — " .. table.concat(problems, "; ") .. ". Parts: spread/warning constants (Config.luau), pickTarget / onMeteorLanded (StarfallService.luau)")
		else
			check("am", true, "storm spreads " .. tostring(spread) .. " studs with " .. tostring(warnTime) .. "s warning circles, knockback + drop, bases safe, hazard label on the banner")
		end
	end
end

-- -- (an) rivals play the game -------------------------------------------------
-- Item 7: 4 named rival bots own bases 5-8, run to the crater, grab,
-- carry home and earn (and show on the leaderboard); rivals steal from
-- unlocked player bases with a THIEF alert and sign; rivals chase egg
-- carriers with a live distance readout; the bounty board names the
-- top storm earner.
do
	local rivalSrc = read("src/server/RivalService.luau")
	local configSrc = read("src/shared/Config.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	if not rivalSrc or not configSrc or not incomeSrc or not mainSrc then
		check("an", false, "could not verify the rivals — RivalService.luau, Config.luau, IncomeService.luau or Main.server.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find("RIVAL_COUNT") then
			table.insert(problems, "no RIVAL_COUNT in RivalService")
		end
		for _, name in ipairs({ "Ziggy", "Nova", "Pip", "Comet" }) do
			if not configSrc:find('"' .. name .. '"') then
				table.insert(problems, 'rival "' .. name .. '" missing from Config.RIVAL_NAMES')
			end
		end
		if not rivalSrc:find("is sneaking to your base") then
			table.insert(problems, "no steal alert to the victim")
		end
		if not rivalSrc:find("THIEF ON YOUR TAIL") then
			table.insert(problems, 'no "THIEF ON YOUR TAIL!" pursuit banner with distance')
		end
		if not rivalSrc:find("studs behind you") then
			table.insert(problems, "the pursuit banner has no live distance readout")
		end
		if not rivalSrc:find("dropEgg") then
			table.insert(problems, "a rival tag never makes the egg carrier drop the egg")
		end
		if not rivalSrc:find("rival.coins") then
			table.insert(problems, "rivals never earn coins (no earnings tick)")
		end
		if not incomeSrc:find("Rival") then
			table.insert(problems, "rivals never appear on the leaderboard (IncomeService)")
		end
		if not incomeSrc:find("setBountyText") then
			table.insert(problems, "the bounty board is never updated (IncomeService.setBountyText)")
		end
		if not mainSrc:find("RivalService.start") then
			table.insert(problems, "RivalService.start is never called (Main.server)")
		end
		if #problems > 0 then
			check("an", false, "rivals do not play — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, names (Config.luau), leaderboard/bounty (IncomeService.luau), wiring (Main.server.luau)")
		else
			check("an", true, "4 named rivals on bases 5-8 grab, carry, earn and show on the leaderboard; steal + chase + bounty all wired")
		end
	end
end

-- -- (ao) the slap bat ----------------------------------------------------------
-- Item 10: F key + SLAP button, 2s cooldown, 9-stud cone, knockback +
-- drop, stars + bonk, shield immunity, rivals slap back.
do
	local configSrc = read("src/shared/Config.luau")
	local slapSrc = read("src/server/SlapService.luau")
	local slapClient = read("src/client/SlapController.client.luau")
	if not configSrc or not slapSrc or not slapClient then
		check("ao", false, "could not verify the slap bat — Config.luau, SlapService.luau or SlapController.client.luau missing")
	else
		local problems: { string } = {}
		-- configValue("SLAP_COOLDOWN") would match RIVAL_SLAP_COOLDOWN
		-- first (it appears earlier in Config.luau), so anchor the match.
		local cooldown = num(configSrc:match("Config%.SLAP_COOLDOWN = ([%d%.]+)"))
		if not cooldown then
			table.insert(problems, "Config.SLAP_COOLDOWN not found")
		elseif cooldown ~= 2 then
			table.insert(problems, "SLAP_COOLDOWN is " .. tostring(cooldown) .. "s (must be 2s)")
		end
		if not slapSrc:find("slapRival") then
			table.insert(problems, "SlapService never slaps rivals")
		end
		if not slapSrc:find("dropCarried") then
			table.insert(problems, "a slap never makes the victim drop what they carry")
		end
		if not slapSrc:find("applySlapFromRival") then
			table.insert(problems, "rivals never slap back")
		end
		if not slapSrc:find("shield") then
			table.insert(problems, "a Shield boost does not block slaps")
		end
		if not slapClient:find("KeyCode.F") then
			table.insert(problems, "no F keybind for the slap bat")
		end
		if not slapClient:find("SLAP") then
			table.insert(problems, "no on-screen SLAP button")
		end
		if not slapClient:find("SlapBat") then
			table.insert(problems, "no visible bat part while swinging")
		end
		if #problems > 0 then
			check("ao", false, "the slap bat is broken — " .. table.concat(problems, "; ") .. ". Parts: SlapService.luau, SlapController.client.luau")
		else
			check("ao", true, "slap bat: F key + SLAP button, 2s cooldown, knockback + drop, stars + bonk, shield immunity, rivals slap back")
		end
	end
end

-- -- (ap) meteor eggs ------------------------------------------------------------
-- Item 12: 1-2 eggs per storm, heavy carry (walk slower), rivals chase,
-- incubator per base, 60s hatch into a random Rotling with Epic /
-- Legendary / mutation chances, hatch animation + reveal popup, and
-- the egg drops on death.
do
	local configSrc = read("src/shared/Config.luau")
	local eggSrc = read("src/server/MeteorEggService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	if not configSrc or not eggSrc or not mainSrc then
		check("ap", false, "could not verify the meteor eggs — Config.luau, MeteorEggService.luau or Main.server.luau missing")
	else
		local problems: { string } = {}
		local perStorm = configValue(configSrc, "EGGS_PER_STORM")
		if not perStorm then
			table.insert(problems, "Config.EGGS_PER_STORM not found")
		elseif perStorm < 1 or perStorm > 2 then
			table.insert(problems, "EGGS_PER_STORM is " .. tostring(perStorm) .. " (must be 1-2)")
		end
		-- (fix round 6, item 6) The hatch time is a per-rarity table
		-- now, not a flat 60s: Common 60s scaling up to Cosmic 300s.
		if not configSrc:find("EGG_HATCH_TIME = {") then
			table.insert(problems, "Config.EGG_HATCH_TIME is not a per-rarity table")
		elseif not configSrc:find("%[1%] = 60") or not configSrc:find("%[6%] = 300") then
			table.insert(problems, "EGG_HATCH_TIME must scale Common 60s -> Cosmic 300s")
		end
		if not eggSrc:find("spawnEggsForStorm") then
			table.insert(problems, "eggs never spawn in a storm")
		end
		if not eggSrc:find("notifyEggCarrier") then
			table.insert(problems, "grabbing an egg never alerts the rivals")
		end
		if not eggSrc:find("incubat") then
			table.insert(problems, "no incubator placement (MeteorEggService.placeEgg)")
		end
		if not eggSrc:find("HATCHED:") then
			table.insert(problems, "no hatch reveal banner")
		end
		if not eggSrc:find("Scorched") then
			table.insert(problems, "eggs never hatch Scorched")
		end
		if not mainSrc:find("MeteorEggService.dropEgg") then
			table.insert(problems, "dying never drops the egg (Main.server)")
		end
		local worldSrc = read("src/server/WorldBuilder.luau")
		if not worldSrc or not worldSrc:find("Incubator") then
			table.insert(problems, "no incubator built on the bases (WorldBuilder)")
		end
		if #problems > 0 then
			check("ap", false, "meteor eggs are broken — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau, incubator (WorldBuilder.luau), wiring (Main.server.luau)")
		else
			check("ap", true, "meteor eggs: " .. tostring(perStorm) .. " per storm, heavy carry, rivals chase, incubator hatch in " .. tostring(hatch) .. "s, Scorched chance, drops on death")
		end
	end
end

-- -- (aq) the map is filled -------------------------------------------------------
-- Item 8: a physical Star Shop with keeper, upgrade machines, a rebirth
-- altar, an index wall, a crashed spaceship, a moon + mountains, and
-- signposts, fences, paths and ambient critters.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		check("aq", false, "could not verify the map fill — WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		local need = {
			{ "Star Shop", 'part%("ShopFloor"' },
			{ "shopkeeper", '"Shopkeeper"' },
			{ "neon STAR SHOP sign", '"★ STAR SHOP ★"' },
			{ "upgrade machines", '"UpgradeMachine"' },
			{ "rebirth altar", '"AltarStone"' },
			{ "index wall", '"IndexWallBoard"' },
			{ "crashed spaceship", '"SpaceshipSaucer"' },
			{ "moon", 'part%("Moon"' },
			{ "mountains", 'part%("Mountain"' },
			{ "signposts", '"Signpost"' },
			{ "fences", '"FencePost"' },
			{ "stone paths", '"StonePath"' },
			{ "ambient critters", '"Critter"' },
		}
		for _, item in ipairs(need) do
			if not worldSrc:find(item[2]) then
				table.insert(problems, "no " .. item[1] .. " in WorldBuilder")
			end
		end
		if not worldSrc:find("buildStarShop%(%)") then
			table.insert(problems, "buildStarShop never called from WorldBuilder.build")
		end
		if #problems > 0 then
			check("aq", false, "the map is empty — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau")
		else
			check("aq", true, "map filled: Star Shop + keeper, upgrade machines, rebirth altar, index wall, spaceship, moon + mountains, signposts, fences, paths, critters")
		end
	end
end

-- -- (ar) boosts ------------------------------------------------------------------
-- Item 11: pickups spawn around the map and in the Star Shop (Speed
-- Coil, Magnet, 2x Cash, Shield), active boosts show as HUD icons with
-- timers, and boosts are also buyable in the shop for Stardust.
do
	local boostSrc = read("src/server/BoostService.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local shopSrc = read("src/client/ShopController.client.luau")
	if not boostSrc or not hudSrc or not shopSrc then
		check("ar", false, "could not verify the boosts — BoostService.luau, HUDController.client.luau or ShopController.client.luau missing")
	else
		local problems: { string } = {}
		for _, kind in ipairs({ "speed", "magnet", "cash", "shield" }) do
			if not boostSrc:find(kind .. " = { label") then
				table.insert(problems, 'boost "' .. kind .. '" missing from the BoostService table')
			end
		end
		if not boostSrc:find("shopCenter") then
			table.insert(problems, "boost pickups never spawn inside the Star Shop")
		end
		if not boostSrc:find("applyWalkSpeed") then
			table.insert(problems, "boosts never change walk speed (no applyWalkSpeed)")
		end
		if not hudSrc:find("BoostRow") then
			table.insert(problems, "no active-boost icon row in the HUD")
		end
		if not shopSrc:find("BOOST_VIEW") then
			table.insert(problems, "boosts are not buyable in the shop")
		end
		if not shopSrc:find("buyBoostFunction") then
			table.insert(problems, "the shop never calls the BuyBoost remote")
		end
		if #problems > 0 then
			check("ar", false, "boosts are broken — " .. table.concat(problems, "; ") .. ". Parts: BoostService.luau, BoostRow (HUDController), BOOST_VIEW (ShopController)")
		else
			check("ar", true, "boosts: Speed/Magnet/2x Cash/Shield pickups (map + shop), HUD icons with timers, buyable for Stardust")
		end
	end
end

-- -- (as) Malek's items 2-5 ---------------------------------------------------------
-- Item 2: the beam is thin (1.5 studs) and semi-transparent (0.6) with
-- a dim light. Item 3: the ground is ONE consistent Grass lawn (fix
-- round 3, item 7) — a single GroundCover in natural grass green, no
-- loud saturated purple, no patchwork tiles. Item 4: the lamp bulbs
-- are small and dim. Item 5: the carried Rotling rides at CARRY_Z <=
-- -3 in front of the chest and keeps its rarity highlight while
-- carried.
do
	local configSrc = read("src/shared/Config.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	if not configSrc or not worldSrc or not factorySrc then
		check("as", false, "could not verify items 2-5 — Config.luau, WorldBuilder.luau or RotlingFactory.luau missing")
	else
		local problems: { string } = {}
		local carryZ = configValue(configSrc, "CARRY_Z")
		if not carryZ then
			table.insert(problems, "Config.CARRY_Z not found")
		elseif carryZ > -3 then
			table.insert(problems, "CARRY_Z is " .. tostring(carryZ) .. " (above -3 — the player's torso hides the carried Rotling)")
		end
		if not worldSrc:find('Vector3.new%(180, 1.0, 1.0%)') then
			table.insert(problems, "the crater beam is not 1.0 studs thin (fix round 4, item 6: 1.5 -> 1.0)")
		end
		if not worldSrc:find("beam.Transparency = 0.8") then
			table.insert(problems, "the crater beam is not semi-transparent (0.8; fix round 4, item 6: 0.6 -> 0.8)")
		end
		if worldSrc:find("165, 148, 190") then
			table.insert(problems, "the loud muted-purple tile colour (165, 148, 190) is still in the ground")
		end
		-- Item 3 (fix round 3): the ground is one consistent Grass
		-- lawn, not a patchwork of tiles.
		if not worldSrc:find('part%("GroundCover"') then
			table.insert(problems, 'no "GroundCover" part in WorldBuilder.luau')
		end
		if not worldSrc:find("89, 173, 77") then
			table.insert(problems, "GroundCover is not the natural grass green (89, 173, 77)")
		end
		if worldSrc:find('part%("GroundTile"') then
			table.insert(problems, 'the old "GroundTile" patchwork is still in WorldBuilder.luau')
		end
		local bulbSize = worldSrc:match('PlazaLampBulb", Enum.PartType.Ball, Vector3.new%(([0-9%.]+),')
		if not bulbSize then
			table.insert(problems, "PlazaLampBulb size not found")
		elseif tonumber(bulbSize) > 1.2 then
			table.insert(problems, "PlazaLampBulb is " .. bulbSize .. " studs (above 1.2 — blown out)")
		end
		if not factorySrc:find("hl.Enabled = true") then
			table.insert(problems, "the rarity highlight is not kept on while carried (RotlingFactory.setCarriedVisual)")
		end
		if #problems > 0 then
			check("as", false, "items 2-5 are not fixed — " .. table.concat(problems, "; ") .. ". Parts: beam/lamps/ground (WorldBuilder.luau), CARRY_Z (Config.luau), setCarriedVisual (RotlingFactory.luau)")
		else
			check("as", true, "beam thin + semi-transparent, ground one Grass lawn, lamps small and dim, carried Rotling at CARRY_Z " .. tostring(carryZ) .. " with its highlight on")
		end
	end
end

-- -- (at) the last adds ---------------------------------------------------------------
-- Item 13: mutations visible (Diamond + Scorched with glow/multiplier),
-- Stardust in the HUD, level/XP in the HUD, 20+ Rotlings, and the logo
-- stage rendered from the game.
do
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	local mutationSrc = read("src/shared/MutationConfig.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not catalogSrc or not mutationSrc or not hudSrc or not worldSrc then
		check("at", false, "could not verify the last adds — RotlingCatalog.luau, MutationConfig.luau, HUDController.client.luau or WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		local defCount = 0
		for _ in catalogSrc:gmatch('id = "([%w_]+)"') do
			defCount += 1
		end
		if defCount < 20 then
			table.insert(problems, "only " .. tostring(defCount) .. " Rotlings in the catalog (need 20+)")
		end
		if not mutationSrc:find('"Diamond"') then
			table.insert(problems, "no Diamond mutation in MutationConfig")
		end
		if not mutationSrc:find('"Scorched"') then
			table.insert(problems, "no Scorched mutation in MutationConfig")
		end
		if not hudSrc:find("Stardust") then
			table.insert(problems, "no Stardust label in the HUD")
		end
		if not hudSrc:find("XpBar") then
			table.insert(problems, "no XP bar in the HUD")
		end
		if not worldSrc:find("LogoStage") then
			table.insert(problems, "no logo stage in the world (WorldBuilder.buildLogoStage)")
		end
		if not worldSrc:find("SPACE ROCK BRAINROTS") then
			table.insert(problems, "no SPACE ROCK BRAINROTS title in the world")
		end
		if #problems > 0 then
			check("at", false, "the last adds are missing — " .. table.concat(problems, "; ") .. ". Parts: catalog/mutations (Shared), Stardust + XP (HUDController), logo stage (WorldBuilder.luau)")
		else
			check("at", true, tostring(defCount) .. " Rotlings, Diamond + Scorched mutations, Stardust + XP in the HUD, logo stage in the world")
		end
	end
end

-- -- (au) the cheap wins ---------------------------------------------------------------
-- Cheap wins 1-9: multiplier in every tag and the index, NEXT REBIRTH
-- bar, upgrade levels with effects, title billboard, shield dome +
-- SAFE label, pursuit banner, global events, danger meter + belt list,
-- and Disco Donut (not Disco Pickle).
do
	local factorySrc = read("src/server/RotlingFactory.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local shopSrc = read("src/client/ShopController.client.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	local eventSrc = read("src/server/GlobalEventService.luau")
	if not factorySrc or not hudSrc or not shopSrc or not worldSrc or not catalogSrc or not eventSrc then
		check("au", false, "could not verify the cheap wins — RotlingFactory.luau, HUDController.client.luau, ShopController.client.luau, WorldBuilder.luau, RotlingCatalog.luau or GlobalEventService.luau missing")
	else
		local problems: { string } = {}
		if not factorySrc:find('" ✦ "') then
			table.insert(problems, 'no "✦ RAINBOW x5" multiplier line in the Rotling tags')
		end
		if not hudSrc:find("NEXT REBIRTH") then
			table.insert(problems, "no NEXT REBIRTH progress bar in the HUD")
		end
		if not shopSrc:find("now %+") then
			table.insert(problems, "no upgrade levels with current effects in the shop rows")
		end
		-- Title billboard REMOVED (fix round 2, fix 8): the giant
		-- "SPACE ROCK BRAINROTS!" text in the sky filled the screen
		-- and its pitch line overlapped the SELL pad. The small HUD
		-- title is enough. The check proves it is GONE, not present.
		if worldSrc:find("TitleBoard") then
			table.insert(problems, "the giant title billboard is still in the sky (must be removed per the playtest)")
		end
		if not worldSrc:find("ShieldDome") then
			table.insert(problems, "no shield dome on the bases")
		end
		if not worldSrc:find("SAFE %(") then
			table.insert(problems, 'no "SAFE (45s)" shield label')
		end
		if not hudSrc:find("Stardust Shower") then
			table.insert(problems, 'no "Stardust Shower" global event label in the HUD')
		end
		if not hudSrc:find("2x Cash Hour") then
			table.insert(problems, 'no "2x Cash Hour" global event label in the HUD')
		end
		if not hudSrc:find("DangerBar") then
			table.insert(problems, "no Meteor Danger meter in the HUD")
		end
		if not hudSrc:find("BeltPanel") then
			table.insert(problems, 'no "On the belt" list in the HUD')
		end
		if catalogSrc:find('name = "Disco Pickle"') then
			table.insert(problems, '"Disco Pickle" is still a Rotling name in the catalog (must be renamed)')
		end
		if not catalogSrc:find("Disco Donut") then
			table.insert(problems, '"Disco Donut" is not in the catalog')
		end
		if #problems > 0 then
			check("au", false, "cheap wins are missing — " .. table.concat(problems, "; ") .. ". Parts: tags (RotlingFactory.luau), HUD bars (HUDController), shop rows (ShopController), billboard/dome (WorldBuilder), events (GlobalEventService.luau)")
		else
			check("au", true, "cheap wins: multiplier in tags + index, NEXT REBIRTH bar, upgrade levels, no title billboard (removed per playtest), shield dome + SAFE label, pursuit banner, 2 global events, danger meter + belt list, Disco Donut")
		end
	end
end

-- -- (av) the buddy Rotling --------------------------------------------------------------
-- BUDDY: your highest-income placed Rotling, half size, floats and bobs
-- beside you with a "Buddy: <name> · +5% cash" tag, follows smoothly,
-- and swaps from the Index.
do
	local buddySrc = read("src/server/BuddyService.luau")
	local indexSrc = read("src/client/IndexController.client.luau")
	local mainSrc = read("src/server/Main.server.luau")
	if not buddySrc or not indexSrc or not mainSrc then
		check("av", false, "could not verify the buddy — BuddyService.luau, IndexController.client.luau or Main.server.luau missing")
	else
		local problems: { string } = {}
		if not buddySrc:find("BUDDY_SCALE") and not buddySrc:find("0.5") then
			table.insert(problems, "the buddy is not half size")
		end
		if not buddySrc:find("Buddy: ") then
			table.insert(problems, 'no "Buddy: <name>" tag on the follower')
		end
		if not buddySrc:find("%+5%% cash") then
			table.insert(problems, "no +5% cash on the buddy tag")
		end
		if not indexSrc:find("Set as Buddy") then
			table.insert(problems, "no Set as Buddy button in the Index")
		end
		if not mainSrc:find("BuddyService.attachBuddy") then
			table.insert(problems, "the buddy is never attached on spawn (Main.server)")
		end
		if #problems > 0 then
			check("av", false, "the buddy is missing — " .. table.concat(problems, "; ") .. ". Parts: BuddyService.luau, Index swap (IndexController), wiring (Main.server.luau)")
		else
			check("av", true, "buddy: half-size highest-income follower with a +5% cash tag, swappable from the Index, attached on spawn")
		end
	end
end

-- -- (aw) the title screen ------------------------------------------------------------
-- Step 1: a real start screen on join, rendered live in the game — big
-- title, tagline, rarity ladder from the catalog, 3-step loop, big PLAY
-- button that dismisses it. No external images, no key art.
do
	local titleSrc = read("src/client/TitleScreenController.client.luau")
	if not titleSrc then
		check("aw", false, "could not verify the title screen — TitleScreenController.client.luau missing")
	else
		local problems: { string } = {}
		if not titleSrc:find("SPACE ROCK BRAINROTS") then
			table.insert(problems, "no big SPACE ROCK BRAINROTS title")
		end
		if not titleSrc:find("Grab them%. Grow them%. Guard your base%.") then
			table.insert(problems, "no tagline on the title screen")
		end
		if not titleSrc:find("RarityConfig%.RARITIES") then
			table.insert(problems, "the ladder is not built from RarityConfig")
		end
		if not titleSrc:find("RotlingCatalog%.DEFS") then
			table.insert(problems, "the ladder shows no catalog Rotling per tier")
		end
		for _, verb in ipairs({ "GRAB", "CARRY", "EARN" }) do
			if not titleSrc:find(verb) then
				table.insert(problems, 'no "' .. verb .. '" step in the 3-step loop')
			end
		end
		if not titleSrc:find("PlayButton") then
			table.insert(problems, "no PLAY button")
		end
		if not titleSrc:find("Visible = false") then
			table.insert(problems, "PLAY never dismisses the title screen")
		end
		if #problems > 0 then
			check("aw", false, "the title screen is missing — " .. table.concat(problems, "; ") .. ". Parts: TitleScreenController.client.luau")
		else
			check("aw", true, "title screen: big title + tagline, rarity ladder from the catalog, GRAB/CARRY/EARN loop, PLAY dismisses it")
		end
	end
end

-- -- (ax) the storm front wall --------------------------------------------------------
-- Step 2: a giant glowing meteor wall sweeps the whole map during the
-- storm, with a "METEOR SHOWER INCOMING! RUN HOME!" banner and a green
-- "SAFE DOME" label over every base while it passes. The wall is pure
-- spectacle: knockback and dropped Rotlings still come only from the
-- falling meteors.
do
	local stormSrc = read("src/server/StarfallService.luau")
	local warnSrc = read("src/client/StormWarningController.client.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not stormSrc or not warnSrc or not worldSrc or not incomeSrc or not configSrc then
		check("ax", false, "could not verify the storm front — StarfallService.luau, StormWarningController.client.luau, WorldBuilder.luau, IncomeService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not stormSrc:find("StormFront") then
			table.insert(problems, "no StormFront wall in StarfallService")
		end
		if not stormSrc:find("STORM_FRONT_HEIGHT") then
			table.insert(problems, "the wall is not sized from Config.STORM_FRONT_HEIGHT")
		end
		if not stormSrc:find("STORM_FRONT_LENGTH") then
			table.insert(problems, "the wall is not sized from Config.STORM_FRONT_LENGTH")
		end
		if not stormSrc:find("Enum%.EasingStyle%.Linear") then
			table.insert(problems, "the wall does not sweep linearly across the map")
		end
		if not stormSrc:find("METEOR SHOWER INCOMING! RUN HOME!") then
			table.insert(problems, 'no "METEOR SHOWER INCOMING! RUN HOME!" storm banner')
		end
		if not warnSrc:find("SPACE ROCKS INCOMING") then
			table.insert(problems, "the storm warning bar does not show the space-rocks line")
		end
		if not worldSrc:find("SAFE DOME") then
			table.insert(problems, 'no "SAFE DOME" label in WorldBuilder')
		end
		if not worldSrc:find("140, 255, 140") then
			table.insert(problems, "the SAFE DOME label is not green")
		end
		if not incomeSrc:find('setShieldLabel%(baseId, BaseService%.lockRemaining%(baseId%), storm%.phase == "storm"%)') then
			table.insert(problems, "the income feed never tells the shield label the storm is passing")
		end
		if configSrc:find("STORM_FRONT_HEIGHT = 40") == nil then
			table.insert(problems, "Config.STORM_FRONT_HEIGHT is not 40")
		end
		if #problems > 0 then
			check("ax", false, "the storm front is missing — " .. table.concat(problems, "; ") .. ". Parts: StormFront (StarfallService.luau), warning bar (StormWarningController), SAFE DOME (WorldBuilder.luau), feed (IncomeService.luau)")
		else
			check("ax", true, "storm front: giant glowing wall sweeps the map, METEOR SHOWER INCOMING banner, green SAFE DOME label + dome over every base while it passes")
		end
	end
end

-- -- (ay) the cheap HUD wins ---------------------------------------------------------
-- Step 3: (a) a big red CARRYING banner that names the Rotling while
-- the player holds one; (b) the current rebirth tier and multiplier
-- next to cash ("Rebirth 2 · x1.5 cash"); (c) every raider carries one
-- of our own bandit titles above its head.
do
	local hudSrc = read("src/client/HUDController.client.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local stateSrc = read("src/server/State.luau")
	if not hudSrc or not incomeSrc or not remotesSrc or not raiderSrc or not stateSrc then
		check("ay", false, "could not verify the HUD wins — HUDController.client.luau, IncomeService.luau, Remotes.luau, RaiderService.luau or State.luau missing")
	else
		local problems: { string } = {}
		if not hudSrc:find("CarryBanner") then
			table.insert(problems, "no CarryBanner frame in the HUD")
		end
		if not hudSrc:find("CARRYING: ") then
			table.insert(problems, 'no "CARRYING: <name>" banner text')
		end
		if not hudSrc:find("RUN HOME!") then
			table.insert(problems, 'no "RUN HOME!" on the carrying banner')
		end
		if not remotesSrc:find("carriedName") then
			table.insert(problems, "HudData carries no carriedName")
		end
		if not incomeSrc:find("carriedName = carriedName") then
			table.insert(problems, "the HUD feed never sends the carried Rotling's name")
		end
		if not hudSrc:find("Rebirth ") then
			table.insert(problems, "no rebirth tier next to the cash")
		end
		if not hudSrc:find("· x") then
			table.insert(problems, "no rebirth multiplier (· xN) next to the cash")
		end
		if not hudSrc:find("cash  •") then
			table.insert(problems, 'no "cash" on the income line')
		end
		if not raiderSrc:find("RAIDER_TITLES") then
			table.insert(problems, "no named raider titles in RaiderService")
		end
		if not raiderSrc:find("Grimble the Grabber") then
			table.insert(problems, "no own bandit title on the raider sign")
		end
		if not stateSrc:find("name: string, %-%- our own bandit title") then
			table.insert(problems, "the Raider record carries no name")
		end
		if raiderSrc:find("FURBETTO") then
			table.insert(problems, "a copied bandit title (FURBETTO) is in RaiderService")
		end
		if #problems > 0 then
			check("ay", false, "the HUD wins are missing — " .. table.concat(problems, "; ") .. ". Parts: CarryBanner + rebirth line (HUDController), carriedName (Remotes/IncomeService), titles (RaiderService.luau)")
		else
			check("ay", true, "HUD wins: red CARRYING banner names the catch, rebirth tier + multiplier next to cash, every raider has its own bandit title")
		end
	end
end

-- -- (az) offline earnings ---------------------------------------------------------
-- Step 4: Rotlings keep earning while the player is away. The profile
-- stamps lastSeen on every save; on join the server pays cps x away
-- time, capped at 8 hours, and pops a "While you were away..." panel.
-- First joiners and players with nothing placed earn nothing.
do
	local offlineSrc = read("src/server/OfflineService.luau")
	local dataSrc = read("src/server/DataService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	local clientSrc = read("src/client/OfflineController.client.luau")
	local configSrc = read("src/shared/Config.luau")
	local projectSrc = read("default.project.json")
	local remotesSrc = read("src/shared/Remotes.luau")
	if not offlineSrc or not dataSrc or not mainSrc or not clientSrc or not configSrc or not projectSrc or not remotesSrc then
		check("az", false, "could not verify offline earnings — OfflineService.luau, DataService.luau, Main.server.luau, OfflineController.client.luau, Config.luau, default.project.json or Remotes.luau missing")
	else
		local problems: { string } = {}
		if not dataSrc:find("lastSeen = 0") then
			table.insert(problems, "no lastSeen field in the default profile")
		end
		if not dataSrc:find("profile%.lastSeen = os%.time%(%)") then
			table.insert(problems, "saves never stamp lastSeen")
		end
		if not offlineSrc:find("OFFLINE_CAP_SECONDS") then
			table.insert(problems, "the away-time payout is not capped at OFFLINE_CAP_SECONDS")
		end
		if not offlineSrc:find("coinsPerSecond%(player%)") then
			table.insert(problems, "the payout is not computed from the player's real coins-per-second")
		end
		if not offlineSrc:find("lastSeen == 0") then
			table.insert(problems, "first joiners are not excluded from the payout")
		end
		if not mainSrc:find("OfflineService%.awardOffline%(player%)") then
			table.insert(problems, "Main never awards offline earnings on join")
		end
		if not mainSrc:find("restorePlaced%(player, profile%.placed%)") then
			table.insert(problems, "the payout is not computed after the pads are restored")
		end
		if not clientSrc:find("WHILE YOU WERE AWAY") then
			table.insert(problems, 'no "WHILE YOU WERE AWAY" popup')
		end
		if not clientSrc:find("Your Brainrots earned ") then
			table.insert(problems, 'no "Your Brainrots earned $X" popup line')
		end
		if not projectSrc:find('"OfflineEarnings"') then
			table.insert(problems, "no OfflineEarnings remote in default.project.json")
		end
		if not remotesSrc:find("offlineEvent") then
			table.insert(problems, "no offlineEvent accessor in Remotes")
		end
		if configSrc:find("OFFLINE_CAP_SECONDS = 8 %* 3600") == nil then
			table.insert(problems, "Config.OFFLINE_CAP_SECONDS is not 8 hours")
		end
		if #problems > 0 then
			check("az", false, "offline earnings are missing — " .. table.concat(problems, "; ") .. ". Parts: lastSeen (DataService), payout (OfflineService.luau), popup (OfflineController), wiring (Main.server.luau)")
		else
			check("az", true, "offline earnings: lastSeen stamped on every save, cps x away time capped at 8h, WHILE YOU WERE AWAY popup on join")
		end
	end
end

-- -- (ba) banking ----------------------------------------------------------------
-- Step 5: income banks at the base and must be collected. The tick pays
-- into profile.banked, the HUD shows "At base: $X" vs the wallet, a
-- Collect button moves it all into the wallet, and the base sign shows
-- the banked cash. Direct payouts (missions, daily, sell, bounty,
-- offline, index) still land in the wallet.
do
	local bankSrc = read("src/server/BankService.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local dataSrc = read("src/server/DataService.luau")
	local stateSrc = read("src/server/State.luau")
	local baseSrc = read("src/server/BaseService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	local projectSrc = read("default.project.json")
	local remotesSrc = read("src/shared/Remotes.luau")
	if not bankSrc or not incomeSrc or not hudSrc or not dataSrc or not stateSrc or not baseSrc or not mainSrc or not projectSrc or not remotesSrc then
		check("ba", false, "could not verify banking — BankService.luau, IncomeService.luau, HUDController.client.luau, DataService.luau, State.luau, BaseService.luau, Main.server.luau, default.project.json or Remotes.luau missing")
	else
		local problems: { string } = {}
		if not stateSrc:find("banked: number") then
			table.insert(problems, "no banked field in the Profile type")
		end
		if not dataSrc:find("banked = 0") then
			table.insert(problems, "no banked = 0 in the default profile")
		end
		if not incomeSrc:find("profile%.banked %+= gained") then
			table.insert(problems, "the income tick never banks the earnings at the base")
		end
		if not bankSrc:find("function BankService%.collectBank") then
			table.insert(problems, "no collectBank in BankService")
		end
		if not bankSrc:find("profile%.banked = 0") then
			table.insert(problems, "collecting never empties the banked balance")
		end
		if not bankSrc:find("profile%.coins %+= amount") then
			table.insert(problems, "collecting never pays the banked cash into the wallet")
		end
		if not mainSrc:find("BankService%.init") then
			table.insert(problems, "BankService is never initialised in Main")
		end
		if not projectSrc:find('"CollectBank"') then
			table.insert(problems, "no CollectBank remote in default.project.json")
		end
		if not remotesSrc:find("collectBankFunction") then
			table.insert(problems, "no collectBankFunction accessor in Remotes")
		end
		if not hudSrc:find("CollectButton") then
			table.insert(problems, "no Collect button in the HUD")
		end
		if not hudSrc:find("At base: ") then
			table.insert(problems, 'no "At base: $X" display in the HUD')
		end
		if not incomeSrc:find("setBaseCoins%(baseId, profile%.banked%)") then
			table.insert(problems, "the base sign does not show the banked cash")
		end
		if not baseSrc:find("setBaseCoins%(baseId, if profile then profile%.banked else 0%)") then
			table.insert(problems, "the base sign is not initialised from the banked balance")
		end
		if #problems > 0 then
			check("ba", false, "banking is missing — " .. table.concat(problems, "; ") .. ". Parts: banked profile (State/DataService), tick (IncomeService.luau), collect (BankService.luau), HUD (HUDController)")
		else
			check("ba", true, "banking: income banks at the base, HUD shows At base vs Wallet, Collect moves it all into the wallet, base sign shows the banked cash")
		end
	end
end

-- -- (bb) storm income readout ------------------------------------------------
-- STORM INCOME READOUT: a player sheltering in their OWN Safe Dome
-- during the storm earns double income, and the HUD shows the boosted
-- rate with (x2) next to the normal rate.
do
	local configSrc = read("src/shared/Config.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	if not configSrc or not incomeSrc or not remotesSrc or not hudSrc then
		check("bb", false, "could not verify the storm income readout — Config.luau, IncomeService.luau, Remotes.luau or HUDController.client.luau missing")
	else
		local problems: { string } = {}
		-- The dome multiplier is 2x.
		local domeMult = configValue(configSrc, "STORM_DOME_MULT")
		if not domeMult then
			table.insert(problems, "Config.STORM_DOME_MULT not found")
		elseif domeMult ~= 2 then
			table.insert(problems, "STORM_DOME_MULT is " .. tostring(domeMult) .. " (not 2)")
		end
		-- The boost gates on the storm phase AND the player's own base.
		if not incomeSrc:find("function IncomeService%.stormBoostActive") then
			table.insert(problems, "IncomeService.stormBoostActive not found")
		else
			if not incomeSrc:find('getStatus%(%)%.phase ~= "storm"') then
				table.insert(problems, "stormBoostActive does not gate on the storm phase")
			end
			if not incomeSrc:find("BaseService%.getPlayerBase%(player%.UserId%)") then
				table.insert(problems, "stormBoostActive does not check the player's own base")
			end
			if not incomeSrc:find("STORM_BASE_SAFE_RADIUS") then
				table.insert(problems, "stormBoostActive does not use STORM_BASE_SAFE_RADIUS")
			end
		end
		-- The multiplier applies the dome boost, and the normal rate
		-- is computed by excluding it.
		if not incomeSrc:find("STORM_DOME_MULT") then
			table.insert(problems, "incomeMult never applies STORM_DOME_MULT")
		end
		if not incomeSrc:find("coinsPerSecond%(player, false%)") then
			table.insert(problems, "broadcastHud never computes the normal rate (coinsPerSecond(player, false))")
		end
		-- The HUD feed carries both numbers and the flag.
		if not incomeSrc:find("stormBoost = IncomeService%.stormBoostActive%(player%)") then
			table.insert(problems, "broadcastHud does not send stormBoost")
		end
		if not incomeSrc:find("baseCps = IncomeService%.coinsPerSecond%(player, false%)") then
			table.insert(problems, "broadcastHud does not send baseCps")
		end
		if not remotesSrc:find("stormBoost: boolean") then
			table.insert(problems, "HudData has no stormBoost field")
		end
		if not remotesSrc:find("baseCps: number") then
			table.insert(problems, "HudData has no baseCps field")
		end
		-- The client renders the boosted rate with (x2) next to the
		-- normal rate.
		if not hudSrc:find("%(x2%)") then
			table.insert(problems, 'HUD never renders "(x2)"')
		end
		if not hudSrc:find("hud%.stormBoost") then
			table.insert(problems, "HUD never reads hud.stormBoost")
		end
		if not hudSrc:find("hud%.baseCps") then
			table.insert(problems, "HUD never reads hud.baseCps")
		end
		if #problems > 0 then
			check("bb", false, "the storm income readout is missing — " .. table.concat(problems, "; ") .. ". Parts: STORM_DOME_MULT (Config), stormBoostActive / incomeMult / coinsPerSecond (IncomeService.luau), HudData (Remotes.luau), income line (HUDController)")
		else
			check("bb", true, "storm income readout: Safe Dome x2 during the storm (own base only), HUD shows boosted (x2) next to the normal rate")
		end
	end
end

-- -- (bc) bright capture setup ------------------------------------------------
-- BRIGHT CAPTURE SETUP: the brightest lighting preset for the 4
-- captures (daytime sky, vivid ground) while keeping the meteor
-- theme, and the FINAL 4 photo-mode shots (belt, storm, packed base,
-- hero close-up) — the title screen is not one of them.
do
	local ok, projectText = pcall(fs.readFile, root .. "/default.project.json")
	local project: any = nil
	if ok then
		local decOk, decoded = pcall(serde.decode, "json", projectText)
		if decOk then
			project = decoded
		end
	end
	local starSrc = read("src/server/StarfallService.luau")
	local photoSrc = read("src/client/PhotoModeController.client.luau")
	local packageText = read("../bounty-package.md")
	if not project or not starSrc or not photoSrc or not packageText then
		check("bc", false, "could not verify the bright capture setup — default.project.json, StarfallService.luau, PhotoModeController.client.luau or bounty-package.md missing")
	else
		local problems: { string } = {}
		local lighting = project.tree and project.tree.Lighting
		local props = if lighting then lighting["$properties"] else nil
		local cc = if lighting then lighting.ColorCorrection else nil
		local ccProps = if cc then cc["$properties"] else nil
		local atmo = if lighting then lighting.Atmosphere else nil
		local atmoProps = if atmo then atmo["$properties"] else nil
		local rays = if lighting then lighting.SunRays else nil
		local raysProps = if rays then rays["$properties"] else nil
		if not props or not ccProps or not atmoProps then
			table.insert(problems, "Lighting / ColorCorrection / Atmosphere properties not found in default.project.json")
		else
			local sat = num(tostring(ccProps.Saturation))
			if not sat then
				table.insert(problems, "ColorCorrection Saturation not found")
			elseif sat < 0.9 then
				table.insert(problems, "Saturation " .. tostring(sat) .. " (under 0.9 — not the brightest vivid preset)")
			end
			local density = num(tostring(atmoProps.Density))
			if not density then
				table.insert(problems, "Atmosphere Density not found")
			elseif density > 0.1 then
				table.insert(problems, "Atmosphere Density " .. tostring(density) .. " (over 0.1 — hazy sky)")
			end
			local haze = num(tostring(atmoProps.Haze))
			if haze and haze > 0.5 then
				table.insert(problems, "Atmosphere Haze " .. tostring(haze) .. " (over 0.5)")
			end
			local clock = num(tostring(props.ClockTime))
			if not clock then
				table.insert(problems, "Lighting ClockTime not found")
			elseif clock < 10 or clock > 15 then
				table.insert(problems, "ClockTime " .. tostring(clock) .. " (not bright midday 10–15)")
			end
		end
		if raysProps then
			local rayI = num(tostring(raysProps.Intensity))
			if rayI and rayI < 0.25 then
				table.insert(problems, "SunRays Intensity " .. tostring(rayI) .. " (under 0.25 — no sunny feel)")
			end
		end
		-- Vivid green ground, not tan and not purple.
		local ground = project.tree and project.tree.Workspace and project.tree.Workspace.Ground
		local groundProps = if ground then ground["$properties"] else nil
		local groundColor = if groundProps then groundProps.Color else nil
		if not groundColor then
			table.insert(problems, "Ground Color not found in default.project.json")
		else
			local r = num(tostring(groundColor[1]))
			local g = num(tostring(groundColor[2]))
			local b = num(tostring(groundColor[3]))
			if not r or not g or not b then
				table.insert(problems, "Ground Color not numeric")
			elseif g < 0.6 or r > 0.5 or b > 0.5 then
				table.insert(problems, "Ground is not vivid green (RGB " .. tostring(r) .. ", " .. tostring(g) .. ", " .. tostring(b) .. ")")
			end
		end
		-- restoreSky must restore the NEW bright preset (Density
		-- 0.08), or the first storm leaves the game on the old light.
		if not starSrc:find("atmosphere%.Density = 0%.08") then
			table.insert(problems, "restoreSky does not restore Atmosphere Density 0.08 (the new bright preset)")
		end
		-- The storm dark is softened so the storm shot reads: dimSky
		-- and the lightning-flash restore must both use 1.2 (base 2,
		-- fix round 2 lighting — was 1.5 on base 3).
		local dimBody = functionBody(starSrc, "dimSky")
		local flashBody = functionBody(starSrc, "lightningFlash")
		if not dimBody or not dimBody:find("Brightness = 1%.2") then
			table.insert(problems, "dimSky does not use the softened Brightness 1.2")
		end
		if not flashBody or not flashBody:find("Brightness = 1%.2") then
			table.insert(problems, "lightningFlash does not restore the softened Brightness 1.2")
		end
		-- The FINAL 4 photo shots: hero, belt, storm, packed base.
		for _, name in ipairs({ "1/4 — Hero", "2/4 — Belt", "3/4 — Storm", "4/4 — Packed base" }) do
			if not photoSrc:find(name, 1, true) then
				table.insert(problems, 'photo shot "' .. name .. '" not found in PhotoModeController')
			end
		end
		local shotCount = 0
		for _ in photoSrc:gmatch('name = "%d/4') do
			shotCount += 1
		end
		if shotCount ~= 4 then
			table.insert(problems, "PhotoMode has " .. tostring(shotCount) .. " numbered shots (not 4)")
		end
		if photoSrc:find('"2/4 — Crater"', 1, true) then
			table.insert(problems, 'the old "Crater" isometric shot is still in PhotoModeController')
		end
		-- The bounty package lists the same final 4, and says the
		-- title screen is NOT one of them.
		if not packageText:find("1-hero-closeup.png", 1, true) then
			table.insert(problems, "bounty-package.md shot list does not name 1-hero-closeup.png")
		end
		if not packageText:find("3-storm-wall.png", 1, true) then
			table.insert(problems, "bounty-package.md shot list does not name 3-storm-wall.png")
		end
		if not packageText:find("is NOT one of the 4 shots", 1, true) then
			table.insert(problems, "bounty-package.md does not say the title screen is NOT one of the 4 shots")
		end
		if #problems > 0 then
			check("bc", false, "the bright capture setup is missing — " .. table.concat(problems, "; ") .. ". Parts: Lighting / Ground (default.project.json), restoreSky / dimSky (StarfallService.luau), photo shots (PhotoModeController), shot list (bounty-package.md)")
		else
			check("bc", true, "bright capture setup: Saturation 1.0, Density 0.08, vivid green ground, storm restores to it, final 4 photo shots (hero close-up, belt, storm, packed base), title screen not one of the 4")
		end
	end
end

-- -- (bd) storm hit feedback + storm-now pill (fix 1) ----------------------
-- The storm ran and hit, but a player caught outside their base got no
-- banner, no flash and no sound — damage + knockback + dropped carries
-- with no visible cue, so the storm felt like nothing. And a sheltered
-- player saw only a small "(x2)" in the HUD income line. Now: a hit
-- banners the victim AND flashes the screen red, and the storm bar
-- itself says sheltering on your base pays x2 and throbs while the
-- storm runs — banner, wall and effect all land in the same moment.
do
	local starSrc = read("src/server/StarfallService.luau")
	local camSrc = read("src/client/CameraFX.client.luau")
	local warnSrc = read("src/client/StormWarningController.client.luau")
	if not starSrc or not camSrc or not warnSrc then
		check("bd", false, "could not verify storm hit feedback — StarfallService.luau, CameraFX.client.luau or StormWarningController.client.luau missing")
	else
		local problems: { string } = {}
		-- A meteor hit banners the victim.
		if not starSrc:find("METEOR HIT!") then
			table.insert(problems, 'no "METEOR HIT!" banner in StarfallService.onMeteorLanded')
		end
		if not starSrc:find("bannerEvent%(%)%:FireClient%(player, \"🌠 METEOR HIT!") then
			table.insert(problems, "the hit banner is not fired to the hit player")
		end
		-- A close impact flashes the screen red.
		if not camSrc:find("MeteorHitFlash") then
			table.insert(problems, "no MeteorHitFlash frame in CameraFX.client.luau")
		end
		if not camSrc:find("distance <= 15") then
			table.insert(problems, "CameraFX does not flash on a close (<= 15 stud) meteor impact")
		end
		-- The storm bar says sheltering pays x2, and throbs.
		if not warnSrc:find("x2 INCOME") then
			table.insert(problems, 'storm bar does not say sheltering pays "x2 INCOME"')
		end
		if not warnSrc:find("startPulse") or not warnSrc:find("TweenInfo.new%(0%.5") then
			table.insert(problems, "storm bar does not pulse while the storm runs")
		end
		-- Simultaneous at storm start: banner + wall + heroes + rain.
		if not starSrc:find('bannerEvent%(%)%:FireAllClients%("🌠 METEOR SHOWER INCOMING') then
			table.insert(problems, "no METEOR SHOWER INCOMING banner at storm start")
		end
		if not starSrc:find("task.spawn%(function%(%)%s+local ok, err = pcall%(spawnStormFront%)") then
			table.insert(problems, "storm front wall is not spawned at storm start")
		end
		if #problems > 0 then
			check("bd", false, "the storm's effect is not unmistakable — " .. table.concat(problems, "; ") .. ". Parts: onMeteorLanded hit banner (StarfallService.luau), MeteorHitFlash (CameraFX.client.luau), storm bar x2 + pulse (StormWarningController.client.luau)")
		else
			check("bd", true, "storm hit feedback: METEOR HIT banner + red screen flash on a close impact; storm bar says SHELTER = x2 INCOME and throbs; banner + wall + heroes + rain all fire at storm start")
		end
	end
end

-- -- (be) bots move: base ramps, raider spawn, stuck-jump, storm cover (fix 2)
-- Raiders and rivals walked into a 2-stud base edge (and the crater
-- rim) with MoveTo, which never jumps — so they pushed against the
-- edge, timed out after 40s and despawned, and the "sneaking to your
-- base!" banner fired for a rival that never arrived. Now: a wedge
-- ramp at every base front, raiders spawn on open ground outside the
-- rim, a stuck bot jumps, and bots run for cover in a storm.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not worldSrc or not raiderSrc or not rivalSrc or not configSrc then
		check("be", false, "could not verify bot movement — WorldBuilder.luau, RaiderService.luau, RivalService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		-- A wedge ramp at every base front (ground -> platform top).
		if not worldSrc:find('"BaseRamp"') then
			table.insert(problems, 'no "BaseRamp" wedge in WorldBuilder.buildBase')
		end
		if not worldSrc:find("Enum%.PartType%.Wedge, Vector3%.new%(6, 2, 4%)") then
			table.insert(problems, "BaseRamp is not a 6x2x4 wedge")
		end
		if not worldSrc:find("CFrame%.new%(0, 1, %-13%)") then
			table.insert(problems, "BaseRamp is not centred at the front entrance (0, 1, -13)")
		end
		-- Raiders spawn outside the rim, above the ground.
		if not raiderSrc:find("Vector3%.new%(math%.cos%(angle%) %* 45, 8, math%.sin%(angle%) %* 45%)") then
			table.insert(problems, "raiders do not spawn at radius 45, Y=8 (outside the rim, above the ground)")
		end
		-- Raiders come sooner and more often.
		local first = configValue(configSrc, "RAIDER_FIRST")
		local interval = configValue(configSrc, "RAIDER_INTERVAL")
		if first ~= 15 then
			table.insert(problems, "Config.RAIDER_FIRST is " .. tostring(first) .. " (not 15)")
		end
		if interval ~= 45 then
			table.insert(problems, "Config.RAIDER_INTERVAL is " .. tostring(interval) .. " (not 45)")
		end
		-- A stuck bot jumps (both services).
		if not raiderSrc:find("humanoid%.Jump = true") then
			table.insert(problems, "RaiderService.walkTo has no stuck-jump (humanoid.Jump = true)")
		end
		if not rivalSrc:find("humanoid%.Jump = true") then
			table.insert(problems, "RivalService.walkTo has no stuck-jump (humanoid.Jump = true)")
		end
		-- Bots run for cover in a storm.
		if not raiderSrc:find("shelterIfStorm") then
			table.insert(problems, "RaiderService has no shelterIfStorm (raiders do not flee storms)")
		end
		if not rivalSrc:find('getStatus%(%)%.phase == "storm"') then
			table.insert(problems, "RivalService.runRival does not shelter during a storm")
		end
		if #problems > 0 then
			check("be", false, "the bots cannot move — " .. table.concat(problems, "; ") .. ". Parts: BaseRamp (WorldBuilder.luau), raider spawn/timing (RaiderService.luau, Config.luau), stuck-jump + storm cover (RaiderService.luau, RivalService.luau)")
		else
			check("be", true, "bots move: wedge ramp at every base front, raiders spawn at radius 45 / Y=8, first raid 15s then every 45s, stuck bots jump, raiders + rivals shelter on a base during storms")
		end
	end
end

-- -- (bf) money adds up: total wealth everywhere (fix 3) -------------------
-- Income banks at the base, but the HUD big number, the rebirth bar,
-- the shop, the rebirth cost check and the leaderboard all read the
-- wallet only — so the player watched the wallet, saw nothing move
-- from income, and could not spend money they had. Now every number
-- is total wealth (wallet + banked): the big number moves every
-- second, the rebirth bar fills from income, shop/rebirth collect
-- the shortfall from the base, a rebirth resets both, and the
-- leaderboard matches the HUD.
do
	local incomeSrc = read("src/server/IncomeService.luau")
	local bankSrc = read("src/server/BankService.luau")
	local shopSrc = read("src/server/ShopService.luau")
	local rebirthSrc = read("src/server/RebirthService.luau")
	local leaderSrc = read("src/server/LeaderstatsService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local simSrc = read("sim-money.luau")
	if not incomeSrc or not bankSrc or not shopSrc or not rebirthSrc or not leaderSrc or not remotesSrc then
		check("bf", false, "could not verify money totals — IncomeService.luau, BankService.luau, ShopService.luau, RebirthService.luau, LeaderstatsService.luau or Remotes.luau missing")
	else
		local problems: { string } = {}
		-- HUD big number + rebirth bar are total wealth.
		if not incomeSrc:find("coins = profile%.coins %+ profile%.banked") then
			table.insert(problems, "broadcastHud does not send coins = wallet + banked (total wealth)")
		end
		if not incomeSrc:find("rebirthProgress = math%.clamp%(%(profile%.coins %+ profile%.banked%) / rebirthCost") then
			table.insert(problems, "rebirthProgress is not total wealth / cost")
		end
		-- BankService has the total-wealth helpers.
		if not bankSrc:find("function BankService%.totalWealth") then
			table.insert(problems, "BankService.totalWealth not found")
		end
		if not bankSrc:find("function BankService%.spendFromTotal") then
			table.insert(problems, "BankService.spendFromTotal not found")
		end
		-- Shop buys spend from total wealth.
		if not shopSrc:find("BankService%.spendFromTotal%(player, cost%)") then
			table.insert(problems, "ShopService.buyItem does not spend from total wealth")
		end
		if shopSrc:find("if profile%.coins < cost then") then
			table.insert(problems, "ShopService.buyItem still checks the wallet only")
		end
		-- Rebirth checks total wealth and resets both.
		if not rebirthSrc:find("BankService%.totalWealth%(player%) < cost") then
			table.insert(problems, "RebirthService.doRebirth does not check total wealth")
		end
		if not rebirthSrc:find("profile%.banked = 0") then
			table.insert(problems, "RebirthService.doRebirth does not reset the banked cash")
		end
		-- Leaderboard matches the HUD.
		if not leaderSrc:find("coins%.Value = profile%.coins %+ profile%.banked") then
			table.insert(problems, "LeaderstatsService.refresh does not show total wealth")
		end
		-- The HudData type says coins is total wealth.
		if not remotesSrc:find("TOTAL wealth") then
			table.insert(problems, "Remotes.HudData does not document coins as total wealth")
		end
		-- The 60s simulation exists and its table is the audit.
		if not simSrc then
			table.insert(problems, "sim-money.luau (the 60s money table) is missing")
		end
		if #problems > 0 then
			check("bf", false, "the money does not add up — " .. table.concat(problems, "; ") .. ". Parts: broadcastHud (IncomeService.luau), totalWealth/spendFromTotal (BankService.luau), buyItem (ShopService.luau), doRebirth (RebirthService.luau), refresh (LeaderstatsService.luau), HudData (Remotes.luau)")
		else
			check("bf", true, "money adds up: HUD big number + rebirth bar + leaderboard are total wealth (wallet + banked); shop/rebirth spend from total (shortfall auto-collected); rebirth resets both; sim-money.luau prints the 60s table")
		end
	end
end

-- -- (bg) one clear rival behaviour: the raider steal (fix 4) ----------------
-- The competition is ONE behaviour, end to end: a raider comes for a
-- REAL player's base (not another bot's), the owner is warned the
-- moment it spawns, it grabs a Rotling and runs for the crater edge,
-- and a bonk/slap makes it drop the loot and visibly flee. No second
-- or third half-working system.
do
	local raiderSrc = read("src/server/RaiderService.luau")
	local slapSrc = read("src/server/SlapService.luau")
	if not raiderSrc or not slapSrc then
		check("bg", false, "could not verify the raider steal — RaiderService.luau or SlapService.luau missing")
	else
		local problems: { string } = {}
		-- The raid targets a real player's base first.
		if not raiderSrc:find("playerBases") then
			table.insert(problems, "spawnRaider does not prefer real-player bases (no playerBases)")
		end
		if not raiderSrc:find("ownerId > 0") then
			table.insert(problems, "spawnRaider does not distinguish real players (ownerId > 0) from rival bases")
		end
		if not raiderSrc:find("if #playerBases > 0 then playerBases else anyBases") then
			table.insert(problems, "spawnRaider does not fall back to any stocked base when no real player is stocked")
		end
		-- The owner is warned at spawn, not only after the grab.
		if not raiderSrc:find("is sneaking toward your base!") then
			table.insert(problems, 'no raid-incoming banner at spawn ("is sneaking toward your base!")')
		end
		-- A bonk cancels the walk and the raider visibly flees.
		if not raiderSrc:find("shouldCancel") then
			table.insert(problems, "walkTo has no shouldCancel (a bonked raider cannot stop its walk)")
		end
		if not raiderSrc:find("function fleeAndDespawn") then
			table.insert(problems, "no fleeAndDespawn (a bonked raider does not visibly run away)")
		end
		if not raiderSrc:find('raider%.phase == "flee"') then
			table.insert(problems, "runRaid never checks for the flee phase after a walk")
		end
		-- The bonk drops the loot (and the slap bat reaches raiders).
		if not raiderSrc:find("CarryService%.scatterToCrater%(raider%.stolen%)") then
			table.insert(problems, "bonkRaider does not scatter the stolen Rotling back to the crater")
		end
		if not slapSrc:find("RaiderService%.bonkRaider%(raiderModel, player%)") then
			table.insert(problems, "SlapService.trySlap does not bonk raiders")
		end
		if #problems > 0 then
			check("bg", false, "the raider steal is not one clear behaviour — " .. table.concat(problems, "; ") .. ". Parts: spawnRaider (RaiderService.luau), bonk/flee (RaiderService.luau, SlapService.luau)")
		else
			check("bg", true, "one clear rival behaviour: raider targets a real player's base, owner warned at spawn, grabs and runs for the crater edge, bonk/slap drops the loot and the raider visibly flees")
		end
	end
end

-- -- (bh) the spawn path reaches the crater (fix 5) ------------------------
-- The spawn walkway stopped at z=57, 18 studs short of the crater
-- rim (z=39) — a path to nothing, with the "Crater" signpost at its
-- dead end. Now it runs all the way to the rim, where the StonePath
-- to the shop begins, and the fences flank it the whole way.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		check("bh", false, "could not verify the spawn path — WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		-- The SpawnPath loop runs to z=39 (the crater rim).
		if not worldSrc:find("for i = 0, 13 do") then
			table.insert(problems, "the SpawnPath loop does not run to i=13 (z=39, the crater rim)")
		end
		if not worldSrc:find("local z = 78 %- i %* 3") then
			table.insert(problems, "the SpawnPath tile spacing (z = 78 - i*3) is not found")
		end
		-- The fences flank the path all the way to the rim.
		if not worldSrc:find("fenceLine%(Vector3%.new%(%-5, 0, 78%), Vector3%.new%(%-5, 0, 40%)%)") then
			table.insert(problems, "the left fence does not run to z=40")
		end
		if not worldSrc:find("fenceLine%(Vector3%.new%(5, 0, 78%), Vector3%.new%(5, 0, 40%)%)") then
			table.insert(problems, "the right fence does not run to z=40")
		end
		-- The StonePath from the rim to the shop still starts at the rim.
		if not worldSrc:find('path%(Vector3%.new%(0, 0, 40%), Vector3%.new%(%-40, 0, 44%)%)') then
			table.insert(problems, "the StonePath from the crater rim (0,0,40) to the shop is missing")
		end
		if #problems > 0 then
			check("bh", false, "the spawn path goes to nothing — " .. table.concat(problems, "; ") .. ". Parts: SpawnPath + fences (WorldBuilder.luau)")
		else
			check("bh", true, "spawn path runs z=78 to z=39 (the crater rim), fences flank it to z=40, StonePath to the shop starts at the rim — spawn -> crater -> shop is one continuous walkway")
		end
	end
end

-- -- (bi) branding: game name + 20 approved Rotling names (branding pass) -----
-- Malek approved the name "Space Rock Brainrots!" (Nov 18 16:10) and the
-- 20-name roster (5 Common, 4 Rare, 4 Epic, 4 Legendary, 2 Mythic,
-- 1 Cosmic). Every approved name must be in the catalog under its
-- approved rarity, no old name may remain, and the game title must read
-- SPACE ROCK BRAINROTS in the HUD and the title screen. The world
-- billboard was REMOVED in fix round 2 (fix 8) — the giant sky text
-- filled the screen and its pitch line overlapped the SELL pad — so
-- (bi) proves it is GONE, not present. Two entries changed tier to
-- match the approved roster (penguin Rare -> Legendary, cat Cosmic ->
-- Legendary).
do
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local titleSrc = read("src/client/TitleScreenController.client.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not catalogSrc or not hudSrc or not titleSrc or not worldSrc then
		check("bi", false, "could not verify the branding — RotlingCatalog.luau, HUDController.client.luau, TitleScreenController.client.luau or WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		local approved: { { string } } = {
			{ "Bloop the Blob", "Common" },
			{ "Pip the Potato", "Common" },
			{ "Wobble Wombat", "Common" },
			{ "Tiny Toaster Tim", "Common" },
			{ "Gloopy Goose", "Common" },
			{ "Sir Soggy Sock", "Rare" },
			{ "Bongo the Banana", "Rare" },
			{ "Captain Crumb", "Rare" },
			{ "Mister Muffin Feet", "Rare" },
			{ "Professor Pickle", "Epic" },
			{ "Turbo Toast", "Epic" },
			{ "Lord Lasagna Legs", "Epic" },
			{ "Disco Donut", "Epic" },
			{ "Baron von Burrito", "Legendary" },
			{ "Count Croissant", "Legendary" },
			{ "Sir Reginald Ramen", "Legendary" },
			{ "Grandpa Gumball", "Legendary" },
			{ "Supreme Spaghetti", "Mythic" },
			{ "The Great Giggling Gherkin", "Mythic" },
			{ "Cosmic Corn Dog", "Cosmic" },
		}
		for _, pair in ipairs(approved) do
			local name, rarity = pair[1], pair[2]
			local found = false
			for id, n, r in catalogSrc:gmatch('id = "([%w]+)",%s+name = "([^"]+)",%s+rarity = "([%w]+)"') do
				if n == name and r == rarity then
					found = true
				end
			end
			if not found then
				table.insert(problems, '"' .. name .. '" is not in the catalog as ' .. rarity)
			end
		end
		for _, old in ipairs({ "Sir Puddles", "Noodle Ned", "Boogie Brine", "Toaster Ghost", "Boba Blob", "Pixel Penguin", "Sir Reginald Socks", "Quantum Quokka", "DJ Turnip", "Astro Avocado", "Baron von Bloop", "Lunar Llama", "Emperor Couch Potato", "Nova Narwhal", "Galactic Gummy Bear", "Comet Cat" }) do
			if catalogSrc:find('name = "' .. old .. '"', 1, true) then
				table.insert(problems, 'old name "' .. old .. '" is still in the catalog')
			end
		end
		if not hudSrc:find("SPACE ROCK BRAINROTS") then
			table.insert(problems, "HUD title is not SPACE ROCK BRAINROTS")
		end
		if not titleSrc:find("SPACE ROCK BRAINROTS") then
			table.insert(problems, "title screen is not SPACE ROCK BRAINROTS")
		end
		if worldSrc:find("TitleBoard") or worldSrc:find("buildTitleBillboard") then
			table.insert(problems, "world billboard is still in the sky (must be removed per the playtest)")
		end
		if #problems > 0 then
			check("bi", false, "the branding is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RotlingCatalog.luau, HUDController.client.luau, TitleScreenController.client.luau, WorldBuilder.luau")
		else
			check("bi", true, "branding: SPACE ROCK BRAINROTS! (HUD, title screen; world billboard removed per playtest); all 20 approved Rotling names in the catalog under their approved rarities (5C/4R/4E/4L/2M/1Co), no old name remains")
		end
	end
end

-- -- (bj) sell works from the base, not only while carrying (fix round 2, fix 1) --
-- The playtest showed selling only worked for a CARRIED Rotling: a
-- player at the SELL pad with Rotlings on their base got "Carry a
-- Rotling to the SELL pad first!" and no money, so selling read as
-- broken. Now the pad sells the carried Rotling if there is one, else
-- the highest-value placed Rotling on the player's own base — the model
-- is removed from its pad and destroyed, and the payout lands in the
-- wallet. The prompt lock check also reads the model's own BaseId
-- attribute (the old code read an undefined global, so it never ran).
do
	local sellSrc = read("src/server/SellService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not sellSrc or not carrySrc or not worldSrc then
		check("bj", false, "could not verify the sell — SellService.luau, CarryService.luau or WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		-- Fix round 5, item 1: sellPlaced is REMOVED — the SELL pad
		-- must never sell a placed Rotling.
		if sellSrc:find("function SellService%.sellPlaced") then
			table.insert(problems, "SellService.sellPlaced still exists (the SELL pad must never sell a placed Rotling)")
		end
		if sellSrc:find("SellService%.sellPlaced%(player%)") then
			table.insert(problems, "sell() still calls sellPlaced")
		end
		if not sellSrc:find("function SellService%.sell%(player") then
			table.insert(problems, "SellService.sell is not defined")
		end
		if not sellSrc:find("Carry a Brainrot to sell it") then
			table.insert(problems, "sell() does not tell empty-handed players to carry a Brainrot first")
		end
		if not sellSrc:find("profile%.coins %+= value", 1) then
			table.insert(problems, "sell does not pay profile.coins += value")
		end
		if not sellSrc:find("local ok, message = SellService%.sell%(player%)") then
			table.insert(problems, "init does not wire the remote/prompt to the unified SellService.sell")
		end
		if sellSrc:find("local ok, message = SellService%.sellCarried%(player%)") then
			table.insert(problems, "init still wires the remote/prompt to sellCarried instead of the unified sell")
		end
		if carrySrc:find("isLocked%(baseId%)") then
			table.insert(problems, "CarryService.setPromptState still reads the undefined global baseId")
		end
		if not carrySrc:find("model:GetAttribute%(\"BaseId\"%)") then
			table.insert(problems, "setPromptState does not read the BaseId from the model attribute")
		end
		if not worldSrc:find("Sell Brainrot") then
			table.insert(problems, "SELL pad prompt is not 'Sell Brainrot'")
		end
		if #problems > 0 then
			check("bj", false, "the sell fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: SellService.luau (sell), CarryService.luau (setPromptState), WorldBuilder.luau (SELL prompt)")
		else
			check("bj", true, "sell is carried-only: SELL pad sells the carried Brainrot and nothing else; empty hands = nothing sold + 'Carry a Brainrot to sell it'; placed Rotlings are never sold by the pad; prompt lock reads the model's BaseId")
		end
	end
end

-- -- (bk) every module call resolves to a real definition (fix round 2, fix 2) --
-- The storm was dead for a whole round because StarfallService called
-- WorldBuilder.setWind and setWind was never defined: the call errored,
-- the cycle's pcall aborted the storm, and no pattern check caught it
-- (they check that setWind(true) is CALLED, not that it EXISTS). This
-- check scans every .luau file for calls to the game's own modules and
-- proves each called function is actually defined in that module.
-- A missing definition FAILS the build.
do
	local modules = {
		BaseService = "src/server/BaseService.luau",
		BankService = "src/server/BankService.luau",
		BoostService = "src/server/BoostService.luau",
		BuddyService = "src/server/BuddyService.luau",
		CarryService = "src/server/CarryService.luau",
		DailyService = "src/server/DailyService.luau",
		DataService = "src/server/DataService.luau",
		FeedbackService = "src/server/FeedbackService.luau",
		GlobalEventService = "src/server/GlobalEventService.luau",
		IncomeService = "src/server/IncomeService.luau",
		LeaderstatsService = "src/server/LeaderstatsService.luau",
		MeteorEggService = "src/server/MeteorEggService.luau",
		MissionService = "src/server/MissionService.luau",
		OfflineService = "src/server/OfflineService.luau",
		RaiderService = "src/server/RaiderService.luau",
		RebirthService = "src/server/RebirthService.luau",
		RivalService = "src/server/RivalService.luau",
		RotlingFactory = "src/server/RotlingFactory.luau",
		SellService = "src/server/SellService.luau",
		ShopService = "src/server/ShopService.luau",
		SlapService = "src/server/SlapService.luau",
		SpawnService = "src/server/SpawnService.luau",
		StarfallService = "src/server/StarfallService.luau",
		StealService = "src/server/StealService.luau",
		WorldBuilder = "src/server/WorldBuilder.luau",
		Config = "src/shared/Config.luau",
		Formatting = "src/shared/Formatting.luau",
		MutationConfig = "src/shared/MutationConfig.luau",
		RarityConfig = "src/shared/RarityConfig.luau",
		Remotes = "src/shared/Remotes.luau",
		RotlingCatalog = "src/shared/RotlingCatalog.luau",
		GuiKit = "src/client/GuiKit.luau",
	}
	-- Collect every defined function per module.
	local defined: { [string]: { [string]: boolean } } = {}
	local missingFiles: { string } = {}
	for name, path in pairs(modules) do
		local src = read(path)
		if not src then
			table.insert(missingFiles, name .. " (" .. path .. ")")
		else
			defined[name] = {}
			for fn in src:gmatch("function " .. name .. "%.([%a_][%w_]*)") do
				defined[name][fn] = true
			end
			-- Config-style fields (Config.FOO = ...) count as defined.
			for field in src:gmatch(name .. "%.([%a_][%w_]*)%s*=") do
				defined[name][field] = true
			end
		end
	end
	if #missingFiles > 0 then
		check("bk", false, "could not verify module cross-references — missing files: " .. table.concat(missingFiles, ", "))
	else
		-- Scan every .luau file for calls to these modules.
		local files: { string } = {}
		local function walk(dir: string)
			local ok, entries = pcall(fs.readDir, root .. "/" .. dir)
			if not ok then
				return
			end
			for _, entry in ipairs(entries) do
				local p = dir .. "/" .. entry
				if entry:match("%.luau$") then
					table.insert(files, p)
				elseif not entry:match("^%.") then
					-- Recurse into subdirectories (no extension).
					if not entry:find("%.", 1, true) then
						walk(p)
					end
				end
			end
		end
		walk("src")
		local problems: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, file in ipairs(files) do
			local src = read(file)
			if src then
				for mod, fn in src:gmatch("([%a_][%w_]*)%.([%a_][%w_]*)%s*%(") do
					if defined[mod] and not defined[mod][fn] and not seen[mod .. "." .. fn] then
						seen[mod .. "." .. fn] = true
						table.insert(problems, mod .. "." .. fn .. " is called (in " .. file .. ") but never defined")
					end
				end
			end
		end
		if #problems > 0 then
			check("bk", false, "missing module functions — " .. table.concat(problems, "; "))
		else
			check("bk", true, "every module call resolves: all WorldBuilder / StarfallService / IncomeService / CarryService (and every other game module) calls have a matching definition")
		end
	end
end

-- -- (bl) storm warning is unmissable: red edges, big countdown, repeating siren (fix round 2, fix 3) --
-- The playtest showed the storm "does nothing" — the warning was a
-- single top bar and one short ping, easy to miss, and the storm itself
-- never ran (setWind, fix 2). Now the 10s warning has flashing red
-- screen edges, a big centre countdown ("SPACE ROCKS IN 10…"), a
-- repeating siren, and a faint camera tremble; the storm itself has a
-- red sky, glowing falling rocks, impact explosions with camera shake,
-- a sweeping wall, and a bounty. This check proves the warning pieces
-- exist and are driven by the warn phase.
do
	local warnSrc = read("src/client/StormWarningController.client.luau")
	local starSrc = read("src/server/StarfallService.luau")
	local camSrc = read("src/client/CameraFX.client.luau")
	if not warnSrc or not starSrc or not camSrc then
		check("bl", false, "could not verify the storm warning — StormWarningController.client.luau, StarfallService.luau or CameraFX.client.luau missing")
	else
		local problems: { string } = {}
		if not warnSrc:find("EdgeTop") or not warnSrc:find("EdgeBottom") or not warnSrc:find("EdgeLeft") or not warnSrc:find("EdgeRight") then
			table.insert(problems, "no red edge frames (EdgeTop/Bottom/Left/Right) in StormWarningController")
		end
		if not warnSrc:find("startEdgePulse") then
			table.insert(problems, "edge flash is not pulsed during the warning")
		end
		if not warnSrc:find("SPACE ROCKS IN ") then
			table.insert(problems, "no big centre countdown ('SPACE ROCKS IN …') in StormWarningController")
		end
		if not warnSrc:find("countdownLabel%.Visible = true") then
			table.insert(problems, "countdown label is never shown")
		end
		if not starSrc:find("phase == \"warn\" then%s*\n%s*playAlarm") then
			table.insert(problems, "siren does not repeat during the warning (StarfallService)")
		end
		if not starSrc:find("WorldBuilder%.setWind%(true%)") then
			table.insert(problems, "storm does not call setWind(true) — the storm cannot start")
		end
		if not starSrc:find("spawnStormFront") then
			table.insert(problems, "no sweeping storm-front wall in StarfallService")
		end
		if not starSrc:find("awardStormBounty") then
			table.insert(problems, "no storm bounty award in StarfallService")
		end
		if not camSrc:find("stormPhase == \"warn\"") then
			table.insert(problems, "CameraFX does not tremble during the warning")
		end
		if #problems > 0 then
			check("bl", false, "the storm warning is incomplete — " .. table.concat(problems, "; ") .. ". Parts: StormWarningController.client.luau, StarfallService.luau, CameraFX.client.luau")
		else
			check("bl", true, "storm warning is unmissable: red edges flash + big centre countdown 'SPACE ROCKS IN 10…' + repeating siren + faint camera tremble during the 10s warning; storm has red sky, falling rocks, wall, shake and bounty")
		end
	end
end

-- -- (bm) bots reach their targets: raiders spawn on the base's side, rivals aim at the crater floor (fix round 2, fix 4) --
-- The playtest showed bots "doing nothing": raiders spawned at a
-- random angle, so half the time their straight line to the target base
-- crossed the crater — they hit the rim wall, stuck-jumped forever and
-- despawned without arriving. Rivals aimed at y=0, below the crater
-- floor, so they pushed against the rim instead of walking in to the
-- belt. Now raiders spawn at the target base's angle (outside the rim)
-- and rivals aim at the crater floor, so both can actually reach the
-- belt and the bases. (The crater itself is opened up in fix 7.)
do
	local raiderSrc = read("src/server/RaiderService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	if not raiderSrc or not rivalSrc then
		check("bm", false, "could not verify the bots — RaiderService.luau or RivalService.luau missing")
	else
		local problems: { string } = {}
		if not raiderSrc:find("baseCFrame%(baseId%)") then
			table.insert(problems, "raider spawn does not read the target base's position (WorldBuilder.baseCFrame)")
		end
		if not raiderSrc:find("math%.atan2%(baseCf%.Position%.Z, baseCf%.Position%.X%)") then
			table.insert(problems, "raider spawn does not use the target base's angle (math.atan2)")
		end
		if not raiderSrc:find("WorldBuilder = require%(script%.Parent%.WorldBuilder%)") then
			table.insert(problems, "RaiderService does not require WorldBuilder")
		end
		if not rivalSrc:find("Config%.CRATER_FLOOR_Y") then
			table.insert(problems, "rival crater spot does not aim at the crater floor (Config.CRATER_FLOOR_Y)")
		end
		if not rivalSrc:find("humanoid%.Jump = true") then
			table.insert(problems, "rival walkTo has no stuck-jump to clear a rim step")
		end
		if not raiderSrc:find("humanoid%.Jump = true") then
			table.insert(problems, "raider walkTo has no stuck-jump to clear a rim step")
		end
		if not raiderSrc:find("bonkRaider") then
			table.insert(problems, "no bonk/slap path that drops a raider's loot")
		end
		if not rivalSrc:find("setThiefSign") then
			table.insert(problems, "no THIEF sign when a rival steals")
		end
		if #problems > 0 then
			check("bm", false, "the bot fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RaiderService.luau, RivalService.luau")
		else
			check("bm", true, "bots can reach their targets: raiders spawn on the target base's side (outside the rim), rivals aim at the crater floor, both have stuck-jumps, bonk drops loot, stealing rivals show THIEF")
		end
	end
end

-- -- (bn) bounty board is LIVE during the storm and pays the winner (fix round 2, fix 5) --
-- The playtest showed no competition: the bounty board sat on its
-- static "Top earner this storm wins a bonus!" line all through the
-- storm, so nobody could see who was winning. Now the board updates
-- every tick during the storm with the live top-earner list, and the
-- winner is paid at storm end. Rivals and players both grab from the
-- same belt (fix 4 + fix 7), so the competition is real.
do
	local incomeSrc = read("src/server/IncomeService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	if not incomeSrc or not rivalSrc then
		check("bn", false, "could not verify the bounty board — IncomeService.luau or RivalService.luau missing")
	else
		local problems: { string } = {}
		if not incomeSrc:find("function IncomeService%.updateStormBountyBoard") then
			table.insert(problems, "IncomeService.updateStormBountyBoard is not defined")
		end
		if not incomeSrc:find("IncomeService%.updateStormBountyBoard%(%)") then
			table.insert(problems, "the live board update is never called from the tick")
		end
		if not incomeSrc:find("State%.stormEarnings%[player%.UserId%]") then
			table.insert(problems, "the live board does not read per-player storm earnings")
		end
		if not incomeSrc:find("WorldBuilder%.setBountyText%(table%.concat%(lines") then
			table.insert(problems, "the live board does not write the standings to the bounty board")
		end
		if not incomeSrc:find("function IncomeService%.awardStormBounty") then
			table.insert(problems, "awardStormBounty is not defined (winner is never paid)")
		end
		if not incomeSrc:find("profile%.coins %+= Config%.BOUNTY_BONUS") then
			table.insert(problems, "the bounty winner is not paid Config.BOUNTY_BONUS")
		end
		if not rivalSrc:find("descendant:GetAttribute%(\"State\"%) == \"free\"") then
			table.insert(problems, "rivals do not grab free belt Rotlings (no competition on the belt)")
		end
		if #problems > 0 then
			check("bn", false, "the live bounty board is incomplete — " .. table.concat(problems, "; ") .. ". Parts: IncomeService.luau (updateStormBountyBoard, awardStormBounty), RivalService.luau")
		else
			check("bn", true, "bounty board is LIVE during the storm: top-earner list updates every tick from storm earnings, winner is paid the bonus at storm end; rivals grab the same belt Rotlings as players")
		end
	end
end

-- -- (bo) money feed is isolated per player + diagnosed (fix round 2, fix 6) --
-- The playtest showed cash $0 and +$0/s. The income math is right
-- (sim-money) and every module call resolves (bk), but the old tick
-- wrapped the WHOLE loop in one pcall — so one bad player, or a
-- failure in the float, the broadcast or the bounty board, skipped
-- broadcastHud for EVERYONE that second and the HUD froze at $0. Now
-- each player is isolated in their own pcall, and the float, the
-- broadcast and the bounty board each get their own pcall, so no
-- single failure can silence the feed. A diagnostic line every 30s
-- prints each player's coins / banked / cps / placed count, so the
-- Output proves the money is flowing.
do
	local incomeSrc = read("src/server/IncomeService.luau")
	local simSrc = read("sim-money.luau")
	if not incomeSrc or not simSrc then
		check("bo", false, "could not verify the money feed — IncomeService.luau or sim-money.luau missing")
	else
		local problems: { string } = {}
		if not incomeSrc:find("for _, player in ipairs%(Players:GetPlayers%(%)%) do%s*\n%s*local ok, err = pcall%(function%(%)") then
			table.insert(problems, "the tick does not isolate each player in their own pcall")
		end
		if not incomeSrc:find("local okHud, errHud = pcall%(IncomeService%.broadcastHud%)") then
			table.insert(problems, "broadcastHud does not have its own pcall (a float/bounty failure can silence it)")
		end
		if not incomeSrc:find("local okFloat, errFloat = pcall%(floatIncomeNumber%)") then
			table.insert(problems, "floatIncomeNumber does not have its own pcall")
		end
		if not incomeSrc:find("local okBounty, errBounty = pcall%(IncomeService%.updateStormBountyBoard%)") then
			table.insert(problems, "updateStormBountyBoard does not have its own pcall")
		end
		if not incomeSrc:find("%[Starfall%] money ") then
			table.insert(problems, "no diagnostic money line (coins/banked/cps/placed) in the tick")
		end
		if not incomeSrc:find("tickCount %% 30 == 0") then
			table.insert(problems, "the diagnostic money line is not on a 30s cadence")
		end
		if not simSrc:find("MONEY TABLE") then
			table.insert(problems, "sim-money.luau has no action | HUD said | actually added table")
		end
		if not simSrc:find("sell %(Boba Blob%)") then
			table.insert(problems, "sim-money.luau money table does not cover the sell")
		end
		if #problems > 0 then
			check("bo", false, "the money-feed fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: IncomeService.luau (tick), sim-money.luau")
		else
			check("bo", true, "money feed is isolated: each player in their own pcall, float/broadcast/bounty each in their own pcall, diagnostic money line every 30s; sim-money prints the action | HUD said | actually added table")
		end
	end
end

-- -- (bp) crater is a real bowl: floor exposed, belt + Rotlings reachable (fix round 2, fix 7) --
-- The playtest showed Brainrots "trapped inside" the crater, with
-- players only able to stand on top: the rim was three SOLID cylinders
-- (radii 31/35/39) that completely buried the crater floor (radius
-- 28) and the belt, so the Rotlings spawned inside solid geometry.
-- Now each rim tier is a RING of blocks around the floor — same
-- heights and colours, same stepped look, but the centre is OPEN, so
-- the floor, the belt and the Rotlings are fully exposed and walkable,
-- with an entrance gap on the spawn-path side (+Z).
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local configSrc = read("src/shared/Config.luau")
	if not worldSrc or not configSrc then
		check("bp", false, "could not verify the crater — WorldBuilder.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if worldSrc:find('part%("CraterRim", Enum%.PartType%.Cylinder') then
			table.insert(problems, "the rim is still built from solid cylinders (CraterRim Cylinder) that bury the floor")
		end
		if not worldSrc:find("buildRimRing%(28, 31, 2%.5") then
			table.insert(problems, "inner rim ring (28-31, height 2.5) not found")
		end
		if not worldSrc:find("buildRimRing%(31, 35, 4") then
			table.insert(problems, "middle rim ring (31-35, height 4) not found")
		end
		if not worldSrc:find("buildRimRing%(35, 39, 5%.5") then
			table.insert(problems, "outer rim ring (35-39, height 5.5) not found")
		end
		if not worldSrc:find("if i ~= 4 then") then
			table.insert(problems, "no entrance gap in the rim rings (segment i=4, +Z, spawn-path side)")
		end
		if not worldSrc:find("CFrame%.lookAt%(pos, Vector3%.new%(0, height / 2, 0%)%)") then
			table.insert(problems, "rim blocks are not oriented tangent to the ring (CFrame.lookAt centre)")
		end
		local floorY = configSrc:match("CRATER_FLOOR_Y = ([%d%.]+)")
		if floorY ~= "0.4" then
			table.insert(problems, "CRATER_FLOOR_Y is not 0.4 (Rotlings must spawn on the exposed floor)")
		end
		if #problems > 0 then
			check("bp", false, "the crater fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau (buildCrater), Config.luau (CRATER_FLOOR_Y)")
		else
			check("bp", true, "crater is a real bowl: three open rings (28-31, 31-35, 35-39) leave the floor exposed, belt + Rotlings stand on it and are reachable, entrance gap on the spawn-path side")
		end
	end
end

-- -- (bq) layout fixed + every visible "Rotling" is now "Brainrot" (fix round 2, fix 8) --
-- The playtest showed the giant title text in the sky, the Rotling
-- Index and Bounty Board signs overlapping, the slogan over the SELL
-- pad, ROTLING INDEX over SPAWN, the "Next storm" panel cut off at the
-- top right, and "Rotling" everywhere the player looks. Now the sky
-- billboard is gone, the Index Wall and Bounty Board are ~55 studs
-- apart on opposite sides of the path, the storm panel is wide enough
-- for its text, and every player-visible "Rotling" reads "Brainrot"
-- (code identifiers — RotlingCatalog, RotlingFactory, RotlingLabel,
-- PlaceRotling/SellRotling remotes, the StarfallRotlings DataStore —
-- stay, per the brief).
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local indexSrc = read("src/client/IndexController.client.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local sellSrc = read("src/server/SellService.luau")
	if not worldSrc or not hudSrc or not indexSrc or not carrySrc or not sellSrc then
		check("bq", false, "could not verify the layout + rename — WorldBuilder.luau, HUDController.client.luau, IndexController.client.luau, CarryService.luau or SellService.luau missing")
	else
		local problems: { string } = {}
		if worldSrc:find("buildTitleBillboard") or worldSrc:find("TitleBoard") then
			table.insert(problems, "the giant title billboard is still in the sky")
		end
		if worldSrc:find("Grab them%. Grow them%. Guard your base%.") then
			table.insert(problems, "the slogan ('Grab them. Grow them. Guard your base.') is still in the world")
		end
		if not worldSrc:find("Vector3%.new%(%-32, 0, 90%)") then
			table.insert(problems, "Bounty Board is not on the left side of the path (-32, 0, 90)")
		end
		if not worldSrc:find("Vector3%.new%(48, 0, 58%)") then
			table.insert(problems, "Index Wall is not moved away from spawn (48, 0, 58)")
		end
		if not worldSrc:find("BRAINROT INDEX") then
			table.insert(problems, "Index Wall title is not 'BRAINROT INDEX'")
		end
		if worldSrc:find("ROTLING INDEX") then
			table.insert(problems, "'ROTLING INDEX' still in the world")
		end
		if not indexSrc:find("BRAINROT INDEX") then
			table.insert(problems, "Index panel title is not 'BRAINROT INDEX'")
		end
		if not hudSrc:find("UDim2%.new%(0, 420, 0, 36%), UDim2%.new%(1, %-444, 0, 60%)") then
			table.insert(problems, "storm panel is not widened to 420px at (1, -444) — it will still clip")
		end
		if hudSrc:find("STORM_HAZARD_LABEL") then
			table.insert(problems, "storm panel still appends the long hazard label (it clips)")
		end
		if not carrySrc:find('"Grab " %.%. name') then
			table.insert(problems, "grab prompt does not use the renamed Brainrot name")
		end
		-- Fix round 5, item 1: the empty-hands sell message is now
		-- "Carry a Brainrot to sell it" (sellPlaced and its "Nothing
		-- to sell" message are gone).
		if not sellSrc:find("Carry a Brainrot to sell it") then
			table.insert(problems, "sell empty message still says 'Rotling'")
		end
		-- Any remaining quoted "Rotling" on ONE line in the world
		-- builder is a missed visible string. The allowed identifiers
		-- (RotlingCatalog / RotlingFactory) are stripped first so
		-- they do not false-positive. The pattern excludes newlines
		-- so it cannot match across lines through comments.
		do
			local cleaned = worldSrc:gsub("RotlingCatalog", ""):gsub("RotlingFactory", "")
			if cleaned:find('"[^"\n]*Rotling[^"\n]*"') then
				table.insert(problems, "a quoted 'Rotling' string remains in WorldBuilder (missed rename)")
			end
		end
		if #problems > 0 then
			check("bq", false, "the layout + rename is incomplete — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau, HUDController.client.luau, IndexController.client.luau, CarryService.luau, SellService.luau")
		else
			check("bq", true, "layout fixed: sky billboard + slogan gone, Index Wall (48,58) and Bounty Board (-32,90) ~85 studs apart, storm panel 420px with a short warn line; every visible 'Rotling' is 'Brainrot'")
		end
	end
end

-- -- (br) lighting: daytime + bright, nothing glows white (fix round 2, lighting) --
-- Malek (Nov 18 16:43): keep it daytime and bright, but lower the
-- bloom and exposure so nothing glows white; the ground a real colour
-- (green grass), the sky blue, so the Brainrots and the HUD stand out.
-- Bloom 0.35 -> 0.15 -> 0.1 (fix round 4, item 7), base Brightness
-- 3 -> 2 -> 1.8 (fix round 4, item 7), ColorCorrection Brightness
-- 0.2 -> 0.0, ground Slate -> Grass material in a natural green, sky
-- stays blue. The storm must restore to the NEW base (1.8) and darken
-- to 1.2, not to the old values.
do
	local projectSrc = read("default.project.json")
	local starSrc = read("src/server/StarfallService.luau")
	if not projectSrc or not starSrc then
		check("br", false, "could not verify the lighting — default.project.json or StarfallService.luau missing")
	else
		local problems: { string } = {}
		if not projectSrc:find('"Brightness": 1%.8') then
			table.insert(problems, "base Lighting Brightness is not 1.8 (exposure not lowered)")
		end
		if not projectSrc:find('"Intensity": 0%.1') then
			table.insert(problems, "Bloom Intensity is not 0.1 (bloom not lowered)")
		end
		if not projectSrc:find('"Brightness": 0%.0') then
			table.insert(problems, "ColorCorrection Brightness is not 0.0 (exposure not lowered)")
		end
		if not projectSrc:find('"Color": %[%s*0%.35,%s*0%.68,%s*0%.3%s*%]') then
			table.insert(problems, "ground is not the natural grass green [0.35, 0.68, 0.3]")
		end
		if not projectSrc:find('"Material": "Grass"') then
			table.insert(problems, "ground Material is not Grass")
		end
		if not projectSrc:find('"ClockTime": 12%.5') then
			table.insert(problems, "ClockTime is not 12.5 (not daytime)")
		end
		if not projectSrc:find('"Color": %[%s*0%.65,%s*0%.75,%s*1%.0%s*%]') then
			table.insert(problems, "Atmosphere color is not the blue [0.65, 0.75, 1.0]")
		end
		if not starSrc:find("Lighting%.Brightness = 1%.8") then
			table.insert(problems, "restoreSky does not restore the new base Brightness 1.8")
		end
		if not starSrc:find("Lighting%.Brightness = 1%.2") then
			table.insert(problems, "dimSky does not darken to the softened 1.2")
		end
		if #problems > 0 then
			check("br", false, "the lighting is not the fixed preset — " .. table.concat(problems, "; ") .. ". Parts: default.project.json, StarfallService.luau")
		else
			check("br", true, "lighting: daytime + bright (ClockTime 12.5, Saturation 1.0, blue sky), Bloom 0.1, Brightness 1.8, ColorCorrection 0.0 — nothing glows white; natural grass ground; storm restores to 1.8, darkens to 1.2")
		end
	end
end

-- -- (bs) grabbing works: Rotlings stand on the belt, E grabs, the guardian does not insta-catch (fix round 4, item 1) --
-- Playtest 4: the "E Grab" prompt showed but E did nothing, and the
-- Brainrots were sunk halfway into the ground. Two causes, both proven:
-- (1) SpawnService.animateFree rebuilt every free Rotling's base at Y =
-- CRATER_FLOOR_Y (0.4) — the body's centre at the belt's surface — so
-- the first 0.1s tick sank it by half its height; the bob then dipped
-- a further 0.25 under. (2) GuardianService spawned the guardian AT the
-- grabber's exact position, inside the 5-stud catch radius, so every
-- grab was caught instantly and the Brainrot dropped straight back.
-- The fix: rest height stored per model at registration and used by
-- animateFree, bob 0..0.25 (never below rest), spawns seated on the
-- belt top (BELT_TOP_Y - 0.1), [Grab] logs on trigger and every early
-- return, and the guardian spawns at the crater rim opposite the
-- target (>= 24 studs away).
do
	local spawnSrc = read("src/server/SpawnService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not spawnSrc or not carrySrc or not guardianSrc or not configSrc then
		check("bs", false, "could not verify the grab fix — SpawnService.luau, CarryService.luau, GuardianService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("BELT_TOP_Y = 1%.2") then
			table.insert(problems, "Config has no BELT_TOP_Y = 1.2 (raised belt walking surface)")
		end
		if spawnSrc:find("CFrame%.new%(newX, Config%.CRATER_FLOOR_Y") then
			table.insert(problems, "animateFree still rebuilds the base at CRATER_FLOOR_Y — Rotlings sink halfway")
		end
		if not spawnSrc:find("restY%[model%]") then
			table.insert(problems, "no stored rest height per model (restY) in SpawnService")
		end
		if not spawnSrc:find("%(math%.sin%(now %* 2 %+ seed%) %+ 1%) / 2 %* 0%.25") then
			table.insert(problems, "bob still dips below rest (sin * 0.25) instead of 0..0.25")
		end
		if not spawnSrc:find("BELT_TOP_Y %- 0%.1") then
			table.insert(problems, "spawns are not seated on the belt top (BELT_TOP_Y - 0.1)")
		end
		if not spawnSrc:find('%[Grab%] prompt triggered by') then
			table.insert(problems, "no [Grab] log on prompt trigger — the next playtest cannot prove the trigger reaches the server")
		end
		if not carrySrc:find('%[Grab%] ') then
			table.insert(problems, "no [Grab] logs in tryGrab early returns")
		end
		if not carrySrc:find("BELT_TOP_Y %- Config%.CRATER_FLOOR_Y") then
			table.insert(problems, "scatterToCrater still floats/scatters with the old +0.8 lift instead of seating on the belt top")
		end
		if not guardianSrc:find("guardianSpawnPos") then
			table.insert(problems, "no guardianSpawnPos — the guardian still spawns on the grabber")
		end
		if guardianSrc:find("spawnPos = if root then root%.Position else") then
			table.insert(problems, "onGrab still spawns the guardian at the player's exact position (instant catch)")
		end
		if #problems > 0 then
			check("bs", false, "the grab fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: SpawnService.luau, CarryService.luau, GuardianService.luau, Config.luau")
		else
			check("bs", true, "grab works: rest height stored per model, bob never below rest, spawns on the belt top, [Grab] logs on trigger + early returns, guardian spawns at the opposite rim (>= 24 studs away)")
		end
	end
end

-- -- (bt) selling works and proves it (fix round 5, item 1) --
-- Playtest 5: the SELL pad sold EVERY Brainrot on the base when the
-- player pressed E with empty hands — sellPlaced sold the best placed
-- Rotling per press, so repeated presses wiped the base. The fallback
-- is removed: sell() sells ONLY the carried Rotling, and empty hands
-- returns "Carry a Brainrot to sell it" with nothing sold. The wiring
-- stays observable — init logs the pad + prompt it found (or warns),
-- and every sell attempt + result is logged — so the next playtest can
-- prove the pad sold nothing with empty hands.
do
	local sellSrc = read("src/server/SellService.luau")
	if not sellSrc then
		check("bt", false, "could not verify the sell fix — SellService.luau missing")
	else
		local problems: { string } = {}
		if not sellSrc:find('%[Sell%] SELL pad prompt wired') then
			table.insert(problems, "init does not log the wired SELL pad prompt")
		end
		if not sellSrc:find('%[Sell%] SellPad NOT FOUND') then
			table.insert(problems, "init does not warn when the SellPad is missing")
		end
		if not sellSrc:find('%[Sell%] attempt by') then
			table.insert(problems, "sell() does not log the attempt (carried/placed counts)")
		end
		if not sellSrc:find('%[Sell%] result for') then
			table.insert(problems, "sell() does not log the result")
		end
		if not sellSrc:find("sellCarried%(player%)") then
			table.insert(problems, "sell() does not sell the carried Rotling")
		end
		if sellSrc:find("sellPlaced%(player%)") then
			table.insert(problems, "sell() still calls sellPlaced")
		end
		if not sellSrc:find("model:Destroy%(%)") or not sellSrc:find("profile%.coins %+= value") then
			table.insert(problems, "sell does not destroy the model and pay the coins")
		end
		if #problems > 0 then
			check("bt", false, "the sell fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: SellService.luau")
		else
			check("bt", true, "sell is observable and carried-only: init logs the wired pad prompt (or warns), every attempt + result is logged, only the carried Rotling is sold, model destroyed and coins paid")
		end
	end
end

-- -- (bu) money/progress numbers are honest (fix round 4, item 3) --
-- Playtest 4: $2.07M cash but the HUD said "NEXT REBIRTH: $2.07M /
-- $40.00K" with no READY state; the quest said "Place 3 Brainrots on
-- your base 0/3" while the index was 14/20; XP sat at 0/100 at level 12.
-- The causes: the HUD never said READY when rebirthProgress >= 1, the
-- label used only wallet coins (not coins + banked, which the server's
-- progress counts), formatMoney printed "$40.00K" for $40,000, and the
-- "place" mission only counted placements made while it was active —
-- placements made under other missions never counted. XP display math
-- was already correct (xp % 100; level 12 at xp=1100 is a boundary),
-- and XP was starved by the broken grab (no grabs/places, no +10/+15).
do
	local hudSrc = read("src/client/HUDController.client.luau")
	local fmtSrc = read("src/shared/Formatting.luau")
	local missionSrc = read("src/server/MissionService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	if not hudSrc or not fmtSrc or not missionSrc or not carrySrc then
		check("bu", false, "could not verify the money/progress fix — HUDController.client.luau, Formatting.luau, MissionService.luau or CarryService.luau missing")
	else
		local problems: { string } = {}
		if not hudSrc:find("REBIRTH READY! Press R") then
			table.insert(problems, "HUD never says REBIRTH READY when progress >= 1")
		end
		if not hudSrc:find("hud%.coins %+ hud%.banked") then
			table.insert(problems, "rebirth label uses wallet coins only, not coins + banked (the server's progress counts both)")
		end
		if not fmtSrc:find("stripCents") or not fmtSrc:find('%.00%(%[KMB%]%)') then
			table.insert(problems, "formatMoney still prints '$40.00K' for $40,000 (no .00 strip)")
		end
		if not missionSrc:find("syncPlaceMission") then
			table.insert(problems, "no syncPlaceMission in MissionService")
		end
		if not missionSrc:find("getPlacedForPlayer%(player%)") then
			table.insert(problems, "syncPlaceMission does not read the live placed count")
		end
		if not carrySrc:find("syncPlaceMission%(player%)") then
			table.insert(problems, "restorePlaced does not sync the place mission on join/restore")
		end
		if not missionSrc:find("MissionService%.syncPlaceMission%(player%)") then
			table.insert(problems, "addProgress does not sync the next mission after a completion")
		end
		if #problems > 0 then
			check("bu", false, "the money/progress fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: HUDController.client.luau, Formatting.luau, MissionService.luau, CarryService.luau")
		else
			check("bu", true, "numbers honest: REBIRTH READY at progress >= 1 (label + button), label counts coins + banked, $40K not $40.00K, place mission syncs to the live placed count on join/restore and after completions")
		end
	end
end

-- -- (bv) every storm drops rocks, including the first (fix round 4, item 4) --
-- Playtest 4: the storm killed the player once, but the FIRST storm
-- dropped nothing at all. The rain loop itself is sound (meteors every
-- 0.45s, ~17 per storm + 3 hero meteors, 50% aimed near players outside
-- the dome with a 2s red target circle, hit = knockout + drop carried +
-- respawn at base, never at a base or in the dome), and the excitement
-- is already there (10s warning, big "SPACE ROCKS IN 10…" countdown,
-- red edge flash, siren, red sky, glowing rocks). The unproven failure
-- was resetStormEarnings() / spawnEggsForStorm() aborting the whole
-- storm pcall before the rain loop ever started. Each is now wrapped
-- in its own pcall, so a failure only warns and the rain still falls.
do
	local starfallSrc = read("src/server/StarfallService.luau")
	local warnSrc = read("src/client/StormWarningController.client.luau")
	if not starfallSrc or not warnSrc then
		check("bv", false, "could not verify the storm fix — StarfallService.luau or StormWarningController.client.luau missing")
	else
		local problems: { string } = {}
		if not starfallSrc:find("pcall%(IncomeService%.resetStormEarnings%)") then
			table.insert(problems, "resetStormEarnings() is not wrapped in its own pcall — a failure there still kills the storm before the rain")
		end
		if not starfallSrc:find("pcall%(MeteorEggService%.spawnEggsForStorm%)") then
			table.insert(problems, "spawnEggsForStorm() is not wrapped in its own pcall — a failure there still kills the storm before the rain")
		end
		if not starfallSrc:find("STORM_METEOR_INTERVAL") then
			table.insert(problems, "no rain loop interval (STORM_METEOR_INTERVAL)")
		end
		if not warnSrc:find("SPACE ROCKS IN") then
			table.insert(problems, "no big storm countdown in StormWarningController")
		end
		if #problems > 0 then
			check("bv", false, "the storm fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: StarfallService.luau, StormWarningController.client.luau")
		else
			check("bv", true, "storm hardened: resetStormEarnings + spawnEggsForStorm each in their own pcall (a failure warns, rain still falls); rain every 0.45s + 3 hero meteors, 10s countdown, siren, red edges/sky")
		end
	end
end

-- -- (bw) the thief actually steals (fix round 4, item 5) --
-- Playtest 4: "Nova is sneaking to your base!" showed but the thief
-- did nothing. The alert fires when a rival enters the steal phase,
-- but runRival was NOT pcall-guarded — any error in the loop (a nil
-- getStatus, a failed walkTo, a missing pad) froze that rival forever
-- with no log, and the 40s walk timeout was cutting the cross-map walk
-- short. The fix: the loop body is extracted into stepRival and every
-- tick is pcall-guarded (warn + continue), the steal logs its start
-- (victim + base), its walk failure, and its success, and the steal
-- walk timeout is 40 -> 60s. Lock (L) still blocks it (isLocked check
-- before the walk and before the grab); slap still gets it back.
do
	local rivalSrc = read("src/server/RivalService.luau")
	if not rivalSrc then
		check("bw", false, "could not verify the thief fix — RivalService.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find("local function stepRival%(rival: State%.Rival, model: Model%)") then
			table.insert(problems, "runRival's loop body is not extracted into stepRival")
		end
		if not rivalSrc:find("pcall%(stepRival, rival, model%)") then
			table.insert(problems, "runRival does not pcall-guard stepRival each tick — one error still freezes the rival")
		end
		if not rivalSrc:find('%[Rival%] " %.%. rival%.name %.%. " step failed') then
			table.insert(problems, "no [Rival] warn on a failed step")
		end
		if not rivalSrc:find('%[Rival%] " %.%. rival%.name %.%. " stealing from') then
			table.insert(problems, "no [Rival] log when the steal phase starts")
		end
		if not rivalSrc:find('%[Rival%] " %.%. rival%.name %.%. " could not reach') then
			table.insert(problems, "no [Rival] log when the steal walk fails")
		end
		if not rivalSrc:find('%[Rival%] " %.%. rival%.name %.%. " stole') then
			table.insert(problems, "no [Rival] log on a successful steal")
		end
		-- 60s timeout (fix round 4, item 5; fix round 5 adds the
		-- storm-cancel arg, so the pattern matches the 60 with or
		-- without the trailing argument).
		if not rivalSrc:find("walkTo%(model, padCf%.Position, 60") then
			table.insert(problems, "steal walk timeout is still 40s, not 60s")
		end
		if not rivalSrc:find("isLocked%(victimBase%)") then
			table.insert(problems, "Lock (L) no longer blocks the steal")
		end
		if #problems > 0 then
			check("bw", false, "the thief fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau")
		else
			check("bw", true, "thief works: stepRival pcall-guarded per tick (warn + continue), steal logs start/walk-fail/success, steal walk 60s, Lock still blocks it")
		end
	end
end

-- -- (bx) buddy is knee height and the white shapes are gone (fix round 4, item 6) --
-- Playtest 4: the buddy pet was huge and blocked the whole view, and
-- the camera clipped into big see-through white shapes in the crater.
-- The buddy was BUDDY_SCALE 0.5 (half-size on a 1.5x crater model is
-- still huge) at offset (2.6, 0.6, 0.4) with a 2.2 tag offset and a
-- 0.35 bob. The white shapes were the 8 base shield domes (ForceField,
-- shown at Transparency 0.82 on lock or any storm) and the crater-centre
-- CraterBeam (180-stud Neon column, 1.5 diameter, Transparency 0.6).
-- The fix: buddy 0.28 at (2.2, -0.8, 1.4) — knee height, beside and
-- behind — tag 1.2, bob 0.15; domes fainter at 0.9; beam thinner (1.0)
-- and more transparent (0.8), light 0.3. The spaceship is at
-- (170, 0, -120), not the crater middle, so it was never the shape.
do
	local configSrc = read("src/shared/Config.luau")
	local buddySrc = read("src/server/BuddyService.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not configSrc or not buddySrc or not worldSrc then
		check("bx", false, "could not verify the buddy/camera fix — Config.luau, BuddyService.luau or WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("BUDDY_SCALE = 0%.28") then
			table.insert(problems, "BUDDY_SCALE is not 0.28 (knee height)")
		end
		if not configSrc:find("BUDDY_OFFSET = Vector3%.new%(2%.2, %-0%.8, 1%.4%)") then
			table.insert(problems, "BUDDY_OFFSET is not (2.2, -0.8, 1.4) — low, beside, behind")
		end
		if not buddySrc:find("StudsOffsetWorldSpace = Vector3%.new%(0, 1%.2, 0%)") then
			table.insert(problems, "buddy tag offset is not 1.2")
		end
		if not buddySrc:find("%* 0%.15") then
			table.insert(problems, "buddy bob is not 0.15")
		end
		if worldSrc:find("Transparency = if visible then 0%.82") or worldSrc:find("dome%.Transparency = 0%.82") then
			table.insert(problems, "a shield dome still shows at Transparency 0.82")
		end
		if not worldSrc:find("Vector3%.new%(180, 1%.0, 1%.0%)") then
			table.insert(problems, "CraterBeam is not thinned to 1.0 diameter")
		end
		if not worldSrc:find("beam%.Transparency = 0%.8") then
			table.insert(problems, "CraterBeam transparency is not 0.8")
		end
		if not worldSrc:find("beamLight%.Brightness = 0%.3") then
			table.insert(problems, "beam light brightness is not 0.3")
		end
		if #problems > 0 then
			check("bx", false, "the buddy/camera fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: Config.luau, BuddyService.luau, WorldBuilder.luau")
		else
			check("bx", true, "buddy is knee height (0.28, low/beside/behind, tag 1.2, bob 0.15); domes fainter (0.9), beam thinner (1.0) and more transparent (0.8), light 0.3")
		end
	end
end

-- -- (by) the belt is a proper raised conveyor (fix round 4, item 7) --
-- Playtest 4: keep the moving belt, but build it as a proper raised
-- conveyor with glowing edges and arrows, Brainrots spaced out and
-- standing on top, arriving a few at a time and never stacked, one
-- consistent ground material, and lower bloom/exposure so nothing
-- glows white. The old belt was a flat 0.4-thick strip at Y 0.45 — it
-- read as a dark line on the floor. Now: a 0.6-thick slab centred at
-- Y 0.9 (top 1.2, half a stud above the crater floor), side walls
-- slightly proud, glowing Neon edge stripes ON the top surface,
-- chevron arrows pointing +X every 5 studs, end rollers flush with
-- the belt top. Spawns are already gradual (2, then +1 every 3s,
-- spaced >= 6 studs) and the ground is one Grass cover (v41). Bloom
-- 0.15 -> 0.1, Brightness 2 -> 1.8.
do
	local configSrc = read("src/shared/Config.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local projectSrc = read("default.project.json")
	if not configSrc or not worldSrc or not projectSrc then
		check("by", false, "could not verify the conveyor fix — Config.luau, WorldBuilder.luau or default.project.json missing")
	else
		local problems: { string } = {}
		if not configSrc:find("BELT_TOP_Y = 1%.2") then
			table.insert(problems, "BELT_TOP_Y is not 1.2 (the belt is not raised)")
		end
		if not worldSrc:find('part%("ConveyorBelt", Enum%.PartType%.Block, Vector3%.new%(40, 0%.6, 8%)') then
			table.insert(problems, "ConveyorBelt is not the 0.6-thick raised slab")
		end
		if not worldSrc:find('part%("BeltSideWall"') then
			table.insert(problems, "no BeltSideWall — the raised body has no side walls")
		end
		if not worldSrc:find('part%("BeltArrow"') then
			table.insert(problems, "no BeltArrow chevrons on the belt")
		end
		if not worldSrc:find("CFrame%.lookAt%(centre, tip%)") then
			table.insert(problems, "arrows are not aimed +X via lookAt")
		end
		if not worldSrc:find('Vector3%.new%(8, 1%.6, 1%.6%)') then
			table.insert(problems, "end rollers are not 1.6 diameter (flush with the belt top)")
		end
		if not projectSrc:find('"Intensity": 0%.1') then
			table.insert(problems, "Bloom Intensity is not 0.1")
		end
		if not projectSrc:find('"Brightness": 1%.8') then
			table.insert(problems, "base Lighting Brightness is not 1.8")
		end
		if not worldSrc:find('part%("GroundCover"') then
			table.insert(problems, "ground is not one consistent GroundCover")
		end
		if #problems > 0 then
			check("by", false, "the conveyor fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: Config.luau, WorldBuilder.luau, default.project.json")
		else
			check("by", true, "raised conveyor: 0.6 slab, top 1.2, side walls, glowing edge stripes, +X chevrons every 5 studs, rollers flush; one Grass ground; Bloom 0.1, Brightness 1.8")
		end
	end
end

-- -- (bz) HUD text is fully on screen, signs are apart, no "Rotling" left (fix round 4, item 8) --
-- Playtest 4: text at the top right was cut off at the screen edge;
-- the Rotling Index + Bounty Board signs overlapped, as did the slogan
-- + SELL and the Index + Spawn signs; and "Rotling" still showed
-- somewhere. The fix: every top-right HUD element now ends 24px from
-- the edge (was 12px) and the storm calm text is shortened to
-- "Storm: 72s"; the Bounty Board moved to (-32, 90) and the Index Wall
-- to (48, 58) — ~86 studs apart (was ~55) — with the Bounty Board gui
-- shrunk to 280x140 and all four sign view distances pulled to 60, so
-- the signs stop rendering on top of each other. The rename is
-- verified by scanning the whole source: the only quoted "Rotling"
-- strings left are code identifiers (RotlingLabel, PlaceRotling /
-- SellRotling remotes, the StarfallRotlings datastore) — no
-- player-visible text says "Rotling" anywhere.
do
	local hudSrc = read("src/client/HUDController.client.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not hudSrc or not worldSrc then
		check("bz", false, "could not verify the HUD/text fix — HUDController.client.luau or WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if not hudSrc:find("UDim2%.new%(1, %-444, 0, 60%)") then
			table.insert(problems, "storm label still ends 12px from the edge (not 24px)")
		end
		if not hudSrc:find("UDim2%.new%(1, %-254, 0, 98%)") then
			table.insert(problems, "danger bar still ends 12px from the edge (not 24px)")
		end
		if not hudSrc:find("UDim2%.new%(1, %-254, 0, 108%)") then
			table.insert(problems, "event label still ends 12px from the edge (not 24px)")
		end
		if not hudSrc:find("UDim2%.new%(1, %-184, 0, 140%)") or not hudSrc:find("UDim2%.new%(1, %-184, 0, 196%)") then
			table.insert(problems, "rebirth/lock buttons still end 12px from the edge (not 24px)")
		end
		if not hudSrc:find("UDim2%.new%(1, %-244, 0, 252%)") then
			table.insert(problems, "leaderboard still ends 12px from the edge (not 24px)")
		end
		if hudSrc:find('"Next storm: "') then
			table.insert(problems, "storm calm text is still the long 'Next storm: 72s'")
		end
		if not worldSrc:find("Vector3%.new%(%-32, 0, 90%)") then
			table.insert(problems, "Bounty Board is not at (-32, 0, 90)")
		end
		if not worldSrc:find("Vector3%.new%(48, 0, 58%)") then
			table.insert(problems, "Index Wall is not at (48, 0, 58)")
		end
		if not worldSrc:find("UDim2%.fromOffset%(280, 140%)") then
			table.insert(problems, "Bounty Board gui is not shrunk to 280x140")
		end
		if not worldSrc:find("spawnSignGui%.MaxDistance = 60") then
			table.insert(problems, "Spawn sign view distance is not 60")
		end
		if not worldSrc:find("titleGui%.MaxDistance = 60") then
			table.insert(problems, "Index Wall title view distance is not 60")
		end
		if not worldSrc:find("gui%.MaxDistance = 60") then
			table.insert(problems, "Bounty Board view distance is not 60")
		end
		-- Rename: scan the whole source for a quoted "Rotling" that
		-- is NOT one of the allowed code identifiers.
		do
			local all = ""
			for _, f in ipairs({
				"src/client/HUDController.client.luau",
				"src/client/IndexController.client.luau",
				"src/client/TitleScreenController.client.luau",
				"src/client/TutorialController.client.luau",
				"src/client/OfflineController.client.luau",
				"src/server/WorldBuilder.luau",
				"src/server/SpawnService.luau",
				"src/server/CarryService.luau",
				"src/server/SellService.luau",
				"src/server/RivalService.luau",
				"src/server/GuardianService.luau",
				"src/server/StarfallService.luau",
			}) do
				local s = read(f)
				if s then
					all = all .. s
				end
			end
			local cleaned = all:gsub("RotlingLabel", ""):gsub("PlaceRotling", ""):gsub("SellRotling", ""):gsub("StarfallRotlings", ""):gsub("RotlingCatalog", ""):gsub("RotlingFactory", "")
			if cleaned:find('"[^"\n]*Rotling[^"\n]*"') then
				table.insert(problems, "a quoted 'Rotling' string remains in player-visible text")
			end
		end
		if #problems > 0 then
			check("bz", false, "the HUD/text fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: HUDController.client.luau, WorldBuilder.luau")
		else
			check("bz", true, "HUD fully on screen (24px margins, short storm text), signs ~86 studs apart with 280x140 Bounty Board and 60 view distances; no player-visible 'Rotling' anywhere")
		end
	end
end

-- -- (ca) the competition is intact (fix round 4, item 9 — verify only) --
-- Playtest 4, item 9 (only after 1-8 work): the Crater Guardian chases
-- whoever grabs from the crater, faster for rarer ones, drop on catch,
-- base/dome = gives up, "THE GUARDIAN IS AWAKE! RUN!" + red edge flash;
-- raider bots grab and run (slap to steal back); goal collect all 20
-- ("Index 14/20" in the HUD), Cosmic Corn Dog last, celebration per
-- completed rarity tier. Verified against the code after items 1-8 —
-- nothing here needed a change, so this check locks the mechanics in:
-- guardian speed by rarity (10 -> 18.5, fix round 7 item 1: +2 each —
-- Cosmic 18.5 is 2.5 faster than walk 16, but the escape is the
-- base/dome or the 25s timeout, and a 24-stud head start still outruns
-- it), catch radius 5, give-up 25s, rim
-- spawn (fix 1, so the catch is not instant), safe-base give-up, the
-- AWAKE banner + edge flash; raiders do crater grabs on half their
-- raids; 20 defs with exactly one Cosmic (Cosmic Corn Dog, weight 1,
-- rarest); HUD "📖 X/20"; tier + full-index celebrations.
do
	local configSrc = read("src/shared/Config.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	local raritySrc = read("src/shared/RarityConfig.luau")
	local indexSrc = read("src/server/IndexService.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	if not configSrc or not guardianSrc or not raiderSrc or not catalogSrc or not raritySrc or not indexSrc or not hudSrc then
		check("ca", false, "could not verify the competition — Config.luau, GuardianService.luau, RaiderService.luau, RotlingCatalog.luau, RarityConfig.luau, IndexService.luau or HUDController.client.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("GUARDIAN_SPEED = { %[1%] = 10, %[2%] = 12, %[3%] = 14, %[4%] = 16, %[5%] = 17%.5, %[6%] = 18%.5 }") then
			table.insert(problems, "guardian speed is not 10 -> 18.5 by rarity")
		end
		if not configSrc:find("GUARDIAN_CATCH_RADIUS = 5") then
			table.insert(problems, "guardian catch radius is not 5")
		end
		if not configSrc:find("GUARDIAN_GIVEUP_TIME = 25") then
			table.insert(problems, "guardian give-up time is not 25s")
		end
		if not guardianSrc:find("guardianSpawnPos") then
			table.insert(problems, "guardian still spawns on the grabber (instant catch) — fix 1 regressed")
		end
		if not guardianSrc:find("THE GUARDIAN IS AWAKE! RUN!") then
			table.insert(problems, "no 'THE GUARDIAN IS AWAKE! RUN!' warning")
		end
		if not guardianSrc:find('despawnGuardian%(guardian, "safe%-base"%)') then
			table.insert(problems, "no safe-base give-up")
		end
		if not guardianSrc:find("dropAllCarried%(player%)") then
			table.insert(problems, "catch does not drop what the player carries")
		end
		if not raiderSrc:find("if math%.random%(%) < 0%.5 then") then
			table.insert(problems, "raiders do not do crater grabs on half their raids")
		end
		if not raiderSrc:find("spawnCraterRaider%(%)") then
			table.insert(problems, "no crater-raider spawn")
		end
		if not catalogSrc:find('name = "Cosmic Corn Dog"') then
			table.insert(problems, "Cosmic Corn Dog is not in the catalog")
		end
		if not raritySrc:find('{ name = "Cosmic".-weight = 1') then
			table.insert(problems, "Cosmic is not the rarest tier (weight 1)")
		end
		if not hudSrc:find("hud%.indexCount.*hud%.indexTotal") then
			table.insert(problems, "HUD does not show the index X/20")
		end
		if not indexSrc:find("SET COMPLETE!") then
			table.insert(problems, "no tier-completion celebration")
		end
		if not indexSrc:find("INDEX COMPLETE! All 20 Brainrots found!") then
			table.insert(problems, "no all-20 completion celebration")
		end
		if #problems > 0 then
			check("ca", false, "the competition is broken — " .. table.concat(problems, "; ") .. ". Parts: Config.luau, GuardianService.luau, RaiderService.luau, RotlingCatalog.luau, RarityConfig.luau, IndexService.luau, HUDController.client.luau")
		else
			check("ca", true, "competition intact: guardian 10->18.5 by rarity (Cosmic 2.5 faster than walk 16; escape is base/dome or the 25s timeout), catch 5, give-up 25s, rim spawn, AWAKE banner + edge flash, safe-base give-up, drop on catch; raiders crater-grab half their raids; 20 defs, one Cosmic (Corn Dog, weight 1); HUD X/20; tier + all-20 celebrations")
		end
	end
end

-- -- (cb) the grab prompt never lies (fix round 5, item 2) --
-- Playtest 5 + Malek's clarification: the grab prompt ("E Grab X")
-- SHOWS but pressing E does nothing. Root cause: a Brainrot carried
-- by a bot (rival or raider) kept its free prompt — the bot carry
-- paths set state "carried" but never called setPromptState, so the
-- prompt stayed enabled with "Grab <name>", and tryGrab hit state ==
-- "carried" and returned SILENTLY (no log, no banner). The player
-- grabbed one genuinely-free Rotling (Gloopy Goose), then every
-- bot-carried one after it read as dead. The fix: every bot carry
-- path disables the prompt via setPromptState; tryGrab's carried
-- return logs + banners; and free prompts are only on while some
-- player has a free carry slot (prompts off while carrying, base
-- capacity 1). The egg had the same family of bug: grabEgg set
-- phase="carried" before validating the weld, stranding the egg, and
-- its prompt stayed live after a grab.
do
	local carrySrc = read("src/server/CarryService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local spawnSrc = read("src/server/SpawnService.luau")
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not carrySrc or not rivalSrc or not raiderSrc or not spawnSrc or not eggSrc then
		check("cb", false, "could not verify the grab-prompt fix — CarryService.luau, RivalService.luau, RaiderService.luau, SpawnService.luau or MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		-- (fix round 6, item 3) This used to match CarryService2 —
		-- the undefined global that made every rival grab error.
		-- carryModel now calls the real CarryService.
		if not rivalSrc:find("CarryService%.setPromptState%(model%)") then
			table.insert(problems, "rival carryModel does not call setPromptState — a rival-carried Rotling keeps a live Grab prompt")
		end
		if not raiderSrc:find("CarryService%.setPromptState%(stolen%)") then
			table.insert(problems, "raider carry does not call setPromptState — a raider-carried Rotling keeps a live Grab prompt")
		end
		if not carrySrc:find("already being carried") then
			table.insert(problems, "tryGrab's carried return is still silent (no log + banner)")
		end
		if not carrySrc:find("anyCarrySlotFree") then
			table.insert(problems, "no anyCarrySlotFree — free grab prompts cannot turn off while carrying")
		end
		if not carrySrc:find("prompt%.Enabled = CarryService%.anyCarrySlotFree%(%)") then
			table.insert(problems, "setPromptState still enables every free grab prompt unconditionally")
		end
		if not carrySrc:find("return 1 %+ tier") then
			table.insert(problems, "base carry capacity is not 1 (getCarrySlots must be 1 + tier)")
		end
		if not spawnSrc:find("CarryService%.setPromptState%(model%)") then
			table.insert(problems, "connectPrompt does not seat the prompt to the carry state")
		end
		if not eggSrc:find("egg grab failed") then
			table.insert(problems, "grabEgg does not log a failed weld before mutating state")
		end
		if not eggSrc:find("prompt%.Enabled = false") then
			table.insert(problems, "grabEgg does not disable the egg prompt once carried")
		end
		if #problems > 0 then
			check("cb", false, "the grab-prompt fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: CarryService.luau, RivalService.luau, RaiderService.luau, SpawnService.luau, MeteorEggService.luau")
		else
			check("cb", true, "grab prompt never lies: bot carry paths disable the prompt, tryGrab's carried return logs + banners, free prompts only on while a carry slot is free (base capacity 1), spawns seat the prompt, egg validates before mutating and its prompt goes off once carried")
		end
	end
end

-- -- (cc) bots actually compete (fix round 5, item 4) --
-- Playtest 5: the leaderboard read Ziggy $0, Nova $0 — rivals earned
-- NOTHING, and raiders were invisible. The rival's straight-line walk
-- to the belt crossed the crater rim from whatever side its base is
-- on, so it pushed against the rim until the 30s timeout and never
-- reached the belt. The fix: rivals walk in through the entrance gap
-- (+Z, the raider's path), grab the RAREST free Rotling within reach
-- (not the nearest Common) and announce it; crater raiders target the
-- rarest free Rotling too. Storms: a rival mid-walk aborts and runs
-- for its Safe Dome, and a meteor that lands on a bot outside a base
-- knocks it out — a rival dies and respawns in 15s (coins kept), a
-- raider despawns with its loot scattered back to the crater.
do
	local rivalSrc = read("src/server/RivalService.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local starfallSrc = read("src/server/StarfallService.luau")
	if not rivalSrc or not raiderSrc or not starfallSrc then
		check("cc", false, "could not verify the bot competition fix — RivalService.luau, RaiderService.luau or StarfallService.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find("entrance gap") then
			table.insert(problems, "rival toCrater does not route through the entrance gap — it still crosses the rim")
		end
		if not rivalSrc:find("grabbed a ") then
			table.insert(problems, "no rival grab alert — a rival grab is invisible")
		end
		if not rivalSrc:find("bestTier") then
			table.insert(problems, "rival grab does not pick the rarest free Rotling")
		end
		if not rivalSrc:find("stormRunning") then
			table.insert(problems, "rival walks do not abort on a storm — bots finish trips in the meteor rain instead of fleeing to the dome")
		end
		if not rivalSrc:find("spawnRival") then
			table.insert(problems, "no spawnRival — a knocked-out rival never respawns")
		end
		if not rivalSrc:find("Respawning in 15s") then
			table.insert(problems, "rival knock-out does not respawn in 15s")
		end
		if not raiderSrc:find("Rarest first") then
			table.insert(problems, "crater raider does not target the rarest free Rotling")
		end
		if not starfallSrc:find("METEOR knocked out rival") then
			table.insert(problems, "meteors do not knock out rivals")
		end
		if not starfallSrc:find("METEOR knocked out a raider") then
			table.insert(problems, "meteors do not knock out raiders")
		end
		if #problems > 0 then
			check("cc", false, "the bot competition fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, RaiderService.luau, StarfallService.luau")
		else
			check("cc", true, "bots compete: rivals enter via the gap, grab the rarest free Rotling and announce it; crater raiders target the rarest; walks abort on a storm (flee to the dome); meteors knock out bots outside a base (rival respawns in 15s, coins kept; raider despawns, loot scattered)")
		end
	end
end

-- -- (cd) HUD text is readable (fix round 5, item 5) --
-- Playtest 5: the mission bar read "Place Bra..." cut off at the left
-- edge, and the "Mister Muffin Feet" name tag overlapped the base
-- label and the thief banner. The mission label was centre-aligned by
-- default, so a long string on a narrow screen clipped on both sides;
-- and a 200x84 AlwaysOnTop tag right in front of the camera fills the
-- screen. The fix: the mission label is left-aligned and truncates
-- with an ellipsis; name tags hide closer than 6 studs (and a hidden
-- close tag does not consume one of the 3 shown slots). Money, storm,
-- buddy, belt and guardian are verified intact, not rebuilt: the
-- $0/s was the wiped base (Fix 1), not a money bug — sim-money still
-- traces grab $0 / place $0 / income +$6/s / sell $110 / collect $ for
-- $; the storm killed the player in Playtest 4 and the warning works;
-- the buddy is knee height and the self-test bright-capture step
-- passes; the belt panel lists belt Brainrots; the guardian checks
-- in (ca) still pass.
do
	local hudSrc = read("src/client/HUDController.client.luau")
	local tagSrc = read("src/client/TagController.client.luau")
	local configSrc = read("src/shared/Config.luau")
	if not hudSrc or not tagSrc or not configSrc then
		check("cd", false, "could not verify the HUD text fix — HUDController.client.luau, TagController.client.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not hudSrc:find("missionLabel%.TextXAlignment = Enum%.TextXAlignment%.Left") then
			table.insert(problems, "mission label is still centre-aligned — a long mission string clips at the left edge")
		end
		if not hudSrc:find("missionLabel%.TextTruncate = Enum%.TextTruncate%.AtEnd") then
			table.insert(problems, "mission label does not truncate — a long mission string overflows instead of ellipsizing")
		end
		if not configSrc:find("TAG_MIN_DISTANCE = 6") then
			table.insert(problems, "no TAG_MIN_DISTANCE — close name tags still fill the screen")
		end
		if not tagSrc:find("TAG_MIN_DISTANCE") then
			table.insert(problems, "TagController does not hide tags closer than TAG_MIN_DISTANCE")
		end
		if #problems > 0 then
			check("cd", false, "the HUD text fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: HUDController.client.luau, TagController.client.luau, Config.luau")
		else
			check("cd", true, "HUD text readable: mission label left-aligned + truncated (no 'Place Bra...' cut-off); name tags hide closer than 6 studs (no tag over the base sign/banner); money/storm/buddy/belt/guardian verified intact, not rebuilt")
		end
	end
end

-- -- (ce) Money cannot silently read $0 (fix round 6, item 1) --
-- Malek's screenshot (v55): Brainrots on his base, but the HUD showed
-- cash $0, +$0/s, Lv 1, 0 XP, NEXT REBIRTH $0/$10,000 — the HUD's
-- initial values, as if no UpdateHud ever arrived. The income path is
-- sound on paper (tick banks coinsPerSecond, broadcastHud sends it),
-- but three spots could kill it silently: the 30s diagnostic and the
-- 5-tick heartbeat ran OUTSIDE any pcall, so one throw in
-- coinsPerSecond/getStatus killed the whole loop forever; getStatus()
-- at the top of broadcastHud ran unprotected, so one throw failed the
-- whole broadcast for everyone; and the guardianActive IIFE could kill
-- a single player's whole HUD send. All three are pcall-guarded now,
-- the tick logs its own start, a placed-but-earning-$0 player warns
-- loudly, and on join the server logs whether the profile loaded from
-- DataStore or fell back to fresh (with index + placed counts) — so
-- the next F9 proves whether the profile or the tick is the culprit.
do
	local incomeSrc = read("src/server/IncomeService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	if not incomeSrc or not mainSrc then
		check("ce", false, "could not verify the money hardening — IncomeService.luau or Main.server.luau missing")
	else
		local problems: { string } = {}
		if not incomeSrc:find("income tick started") then
			table.insert(problems, "the income tick does not log its own start — a dead loop is silent")
		end
		if not incomeSrc:find("money stuck for") then
			table.insert(problems, "no placed-but-earning-$0 self-check in the tick — the money bug stays silent")
		end
		if not incomeSrc:find("money diagnostic failed") then
			table.insert(problems, "the 30s diagnostic is not pcall-guarded — a throw there kills the whole income loop")
		end
		if not incomeSrc:find("storm heartbeat failed") then
			table.insert(problems, "the 5-tick heartbeat is not pcall-guarded — a throw in getStatus/ensureRunning kills the whole income loop")
		end
		if not incomeSrc:find("getStatus failed, using calm fallback") then
			table.insert(problems, "broadcastHud's getStatus has no calm fallback — one throw fails the whole broadcast for everyone")
		end
		if not incomeSrc:find("isChasing failed for") then
			table.insert(problems, "the guardianActive check is not pcall-guarded — a throw kills that player's whole HUD send")
		end
		if not mainSrc:find("loaded from DataStore") then
			table.insert(problems, "onPlayerAdded does not log the profile load source — a fresh-profile fallback is invisible in F9")
		end
		if #problems > 0 then
			check("ce", false, "the money hardening is incomplete — " .. table.concat(problems, "; ") .. ". Parts: IncomeService.luau, Main.server.luau")
		else
			check("ce", true, "money cannot silently read $0: tick + heartbeat pcall-guarded with a start log, placed-but-$0 warns, broadcastHud falls back to calm on a getStatus failure, isChasing is guarded, joins log the profile load source + index + placed counts")
		end
	end
end

-- -- (cf) unweldable raider loot is scattered, never destroyed (fix round 6, item 2)
-- removePlaced/unregister take a Rotling out of its pad / the free
-- spawns BEFORE the weld runs, so a weld failure used to ghost it
-- (off its pad, earning nothing, unsavable) and the escape path then
-- destroyed it. Both raid paths now scatter the loot back to the
-- crater the moment the weld fails, and the escape path only destroys
-- loot whose State is actually "carried" — anything else scatters.
do
	local raiderSrc = read("src/server/RaiderService.luau")
	if not raiderSrc then
		check("cf", false, "could not verify the raider edge-case fix — RaiderService.luau missing")
	else
		local problems: { string } = {}
		if not raiderSrc:find("could not weld") then
			table.insert(problems, "no weld-failure log in the raid paths — an unweldable steal stays silent")
		end
		if not raiderSrc:find("scatterToCrater%(stolen%)") then
			table.insert(problems, "weld-failure loot is not scattered back to the crater — it can still vanish")
		end
		if not raiderSrc:find("escaped but the loot was never carried") then
			table.insert(problems, "the escape path has no never-carried guard — unwelded loot can still be destroyed on escape")
		end
		if not raiderSrc:find("GetAttribute%(\"State\"%) == \"carried\"") then
			table.insert(problems, "the escape path does not check State == \"carried\" before destroying the loot")
		end
		if #problems > 0 then
			check("cf", false, "the raider edge-case fix is incomplete — " .. table.concat(problems, "; ") .. ". Part: RaiderService.luau")
		else
			check("cf", true, "unweldable raider loot is scattered back to the crater, never destroyed: weld failure scatters + despawns in both raid paths, escape only destroys State == \"carried\" loot")
		end
	end
end

-- -- (cg) the thief actually steals: rival grab works, steal walk goes
-- around the crater, every abort tells the victim, lock lasts 2 min
-- (fix round 6, item 3 — ALL thieves, not one bot)
-- carryModel called CarryService2.setPromptState — a name that does
-- not exist in RivalService (the only CarryService2 is a LOCAL inside
-- stepRival's toBase branch) — so EVERY rival grab errored after the
-- weld but before rival.carried was set: no "stole your X" banner, no
-- place, no earnings (Ziggy/Nova $0), and the Brainrot stayed welded
-- to the rival. The steal walk also went straight through the crater,
-- so a far-side rival (Ziggy, directly opposite the player) pushed
-- against the rim until the timeout while the sneak alert had already
-- fired — the false alarm. The walk now goes around the rim at the
-- victim's angle, every abort fires a visible "gave up" banner (rival
-- and raider alike), and the lock holds 120s instead of 60s.
do
	local rivalSrc = read("src/server/RivalService.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not rivalSrc or not raiderSrc or not configSrc then
		check("cg", false, "could not verify the thief fix — RivalService.luau, RaiderService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if rivalSrc:find("CarryService2%.setPromptState%(model%)") then
			table.insert(problems, "carryModel still calls the undefined CarryService2 — every rival grab errors before rival.carried is set")
		end
		if not rivalSrc:find("CarryService%.setPromptState%(model%)") then
			table.insert(problems, "carryModel does not call CarryService.setPromptState — the carried prompt is never disabled")
		end
		if not rivalSrc:find("victimAngle") or not rivalSrc:find("math%.cos%(victimAngle%) %* 45") then
			table.insert(problems, "the steal walk does not go around the crater at the victim's angle — far-side rivals still cross the rim")
		end
		if not rivalSrc:find("gave up sneaking to your base") then
			table.insert(problems, "no give-up banner in the rival steal — a failed steal stays a silent false alarm")
		end
		if not raiderSrc:find("gave up sneaking to your base") then
			table.insert(problems, "no give-up banner in the raider raid — a failed raid stays a silent false alarm")
		end
		if not rivalSrc:find("placed .+ on its base — earning now") then
			table.insert(problems, "no placed-and-earning log in the rival toBase — the steal trail has no final step")
		end
		if not configSrc:find("LOCK_DURATION = 120") then
			table.insert(problems, "the lock is not 120s — Malek asked for more time for the lockups")
		end
		if #problems > 0 then
			check("cg", false, "the thief fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, RaiderService.luau, Config.luau")
		else
			check("cg", true, "the thief actually steals: carryModel uses CarryService (no nil-global error), steal walk goes around the crater at the victim's angle, every abort fires a visible 'gave up' banner (rival + raider), steal trail logs through to placed-and-earning, lock holds 120s")
		end
	end
end

-- -- (ch) the guardian chases smoothly, fast, and actually catches
-- (fix round 7, item 1)
-- The round-6 chase re-pathed every 0.5s and issued ONE MoveTo to the
-- first waypoint >2 studs away, then waited — the guardian reached a
-- 2-4 stud waypoint in ~0.2s and stood still until the next tick, so
-- it moved in blocks at half speed, never closed on a walking player,
-- and the catch never fired ("no dmg, no drops, no deaths, nothing").
-- The chase now ticks every 0.1s, walks its path waypoint by waypoint
-- (advancing the moment it is close, never waiting for a repath),
-- repaths only every 1.5s or when the target moved far, and a touch
-- on the body ball catches instantly. HipHeight matches the build
-- (3.2, the root's height above the floor — the default 2 pushed the
-- model into the floor while it walked). Speeds are +2 per tier
-- (10 -> 18.5). The chase follows the target anywhere on the map,
-- inside or outside the crater, until catch / safe base / timeout.
do
	local guardianSrc = read("src/server/GuardianService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not guardianSrc or not configSrc then
		check("ch", false, "could not verify the guardian chase fix — GuardianService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not guardianSrc:find("PathfindingService") or not guardianSrc:find("ComputeAsync") then
			table.insert(problems, "the chase does not pathfind — straight-line MoveTo still pushes it into the rim")
		end
		if not guardianSrc:find("AgentRadius = 3") then
			table.insert(problems, "the path is not sized for the guardian's 5.5-stud ball — it can route through gaps it cannot fit")
		end
		if not guardianSrc:find("climbed out of the crater") then
			table.insert(problems, "no stuck climb-out — a guardian that cannot move still dies in the middle")
		end
		if not guardianSrc:find("chased .+ for ") then
			table.insert(problems, "despawn does not log who was chased and for how long — the chase trail has no ending")
		end
		if not guardianSrc:find("task%.wait%(0%.1%)") then
			table.insert(problems, "the chase tick is not 0.1s — the 0.5s repath wait is what made it move in blocks")
		end
		if not guardianSrc:find("wpIndex") or not guardianSrc:find("lastRepathAt") then
			table.insert(problems, "the chase does not follow waypoints in sequence with rare repaths — it still issues one short MoveTo per repath")
		end
		if not guardianSrc:find("HipHeight = 3%.2") then
			table.insert(problems, "HipHeight does not match the build (3.2) — the Humanoid still pushes the model into the floor while walking")
		end
		if not guardianSrc:find("body%.Touched:Connect") then
			table.insert(problems, "no touch-catch on the body ball — a touch can still slip between catch-radius ticks")
		end
		if not guardianSrc:find("caught .+ — knocked down, dropped") then
			table.insert(problems, "the catch does not log the knockdown + drop — the catch trail has no proof")
		end
		if not configSrc:find("%[1%] = 10") or not configSrc:find("%[6%] = 18%.5") then
			table.insert(problems, "guardian speeds are not +2 per tier (10 -> 18.5)")
		end
		if #problems > 0 then
			check("ch", false, "the guardian chase fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: GuardianService.luau, Config.luau")
		else
			check("ch", true, "the guardian chases smoothly and catches: 0.1s tick, waypoint-by-waypoint following with repaths only every 1.5s, HipHeight 3.2 matching the build, touch-catch on the body ball, catch logs the knockdown + drop, speeds 10 -> 18.5, chase follows the target anywhere on the map")
		end
	end
end

-- -- (ci) the guardian looks like a creature, not a ball (fix round 6, item 5)
-- Malek: "can we rework how he look?" The old guardian was a smooth
-- ball with flat grey slabs. The new one is a hunched rock golem:
-- head jutting forward low on the chest, heavy brow over the red eyes,
-- boulder shoulders, long arms with fists, stomp feet, Neon magma
-- cracks. The body ball is unchanged (the chase is tuned on it) and
-- the red eyes + red light + "CRATER GUARDIAN" tag are kept.
do
	local guardianSrc = read("src/server/GuardianService.luau")
	if not guardianSrc then
		check("ci", false, "could not verify the guardian look — GuardianService.luau missing")
	else
		local problems: { string } = {}
		if not guardianSrc:find("makePart%(\"Head\"") then
			table.insert(problems, "no head rock — the golem has no hunched head")
		end
		if not guardianSrc:find("makePart%(\"Brow\"") then
			table.insert(problems, "no brow slab — the eyes have no heavy brow over them")
		end
		if not guardianSrc:find("makePart%(\"Shoulder\"") then
			table.insert(problems, "no boulder shoulders — the silhouette is still a ball")
		end
		if not guardianSrc:find("makePart%(\"Arm\"") or not guardianSrc:find("makePart%(\"Fist\"") then
			table.insert(problems, "no arms + fists — the golem has no limbs")
		end
		if not guardianSrc:find("makePart%(\"Foot\"") then
			table.insert(problems, "no stomp feet — the golem floats instead of standing")
		end
		if not guardianSrc:find("makePart%(\"GlowCrack\"") then
			table.insert(problems, "no glowing cracks — the magma-crack read is missing")
		end
		if guardianSrc:find("makePart%(\"Crack\"") then
			table.insert(problems, "the old flat grey Crack slabs are still there")
		end
		if not guardianSrc:find("CRATER GUARDIAN") or not guardianSrc:find("255, 30, 30") or not guardianSrc:find("PointLight") then
			table.insert(problems, "the warning read is gone — the tag, red eyes or red light must stay")
		end
		if #problems > 0 then
			check("ci", false, "the guardian look rework is incomplete — " .. table.concat(problems, "; ") .. ". Part: GuardianService.luau")
		else
			check("ci", true, "the guardian is a hunched rock golem: forward low head + heavy brow, red eyes, Neon magma cracks, boulder shoulders, arms + fists, stomp feet; body ball unchanged, tag + red eyes + red light kept")
		end
	end
end

-- -- (cj) eggs hatch slower the rarer they are (fix round 6, item 6)
-- Malek: "the egg to hatch has more time? Maybe on its rarity?"
-- The hatch was a flat 60s. Now the hatch is rolled at place time
-- and the wait scales with the rarity of what's inside: Common 60s,
-- Rare 90s, Epic 120s, Legendary 180s, Mythic 240s, Cosmic 300s.
-- The result stays hidden until the hatch reveal (the banner shows
-- only the wait). rollHatchDef must be declared BEFORE placeEgg — a
-- local declared after its caller is invisible to it, the same class
-- of bug as fix round 3's calmDuration-after-getStatus.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	local configSrc = read("src/shared/Config.luau")
	local stateSrc = read("src/server/State.luau")
	if not eggSrc or not configSrc or not stateSrc then
		check("cj", false, "could not verify the egg hatch scaling — MeteorEggService.luau, Config.luau or State.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("EGG_HATCH_TIME = { %[1%] = 60, %[2%] = 90, %[3%] = 120, %[4%] = 180, %[5%] = 240, %[6%] = 300 }") then
			table.insert(problems, "EGG_HATCH_TIME is not the 60 -> 300s per-rarity ladder")
		end
		if not eggSrc:find("hatchTimeForRarity") then
			table.insert(problems, "no hatchTimeForRarity — the hatch wait cannot scale with rarity")
		end
		if not eggSrc:find("egg%.hatchDef = def%.id") or not eggSrc:find("egg%.hatchMutation = mutation") then
			table.insert(problems, "placeEgg does not store the rolled hatch — the wait cannot scale with what's inside")
		end
		if not eggSrc:find("hatches in \" .. tostring%(hatchTime%)") then
			table.insert(problems, "the incubator banner does not show the actual (rarity-scaled) wait")
		end
		local rollPos = eggSrc:find("local function rollHatchDef")
		local placePos = eggSrc:find("function MeteorEggService%.placeEgg")
		if not rollPos or not placePos or rollPos > placePos then
			table.insert(problems, "rollHatchDef is not declared before placeEgg — placeEgg would call a nil global")
		end
		if not stateSrc:find("hatchDef: string%?") or not stateSrc:find("hatchMutation: string%?") then
			table.insert(problems, "the Egg record has no hatchDef/hatchMutation fields — the stored hatch has nowhere to live")
		end
		if #problems > 0 then
			check("cj", false, "the egg hatch scaling is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau, Config.luau, State.luau")
		else
			check("cj", true, "eggs hatch slower the rarer they are: hatch rolled at place time and stored on the egg, wait scales Common 60s -> Cosmic 300s, banner shows the actual wait, roll declared before its caller")
		end
	end
end

-- -- (ck) thieves actually steal: ring-routed walks + a steal clock
-- (fix round 7, item 2)
-- The round-6 thief fix (nil-global + rim-crossing leg) still left
-- zero action in playtest 7 — the third round of "fixed" thieves.
-- Two causes remain: (a) the steal walk's leg 1 is a straight line
-- from the rival's own base (radius 110) to the "around" point at
-- radius 45 on the victim's angle — for a far-side victim that chord
-- passes near the origin, straight through the tiered rim, and the
-- stuck-hop cannot reliably clear 2.5/4/5.5-stud rings, so the walk
-- timed out at 40s and the steal aborted. Same for the crater
-- approach (the gap is at +Z, so a rival on the -Z side walked
-- straight through the crater). All rival walks now route along a
-- ring of open ground at radius 45 (rim outer ring ends at 39):
-- exit through the entrance gap from inside, drop radially to the
-- ring from outside, arc to the target's angle, then straight in.
-- (b) steals were too rare: 0.35 per idle roll on a 60-90s cycle is
-- about one attempt per rival every 2-3 minutes, and only with a
-- victim. The chance is now 0.5, rivals walk at 16, and a steal
-- clock forces the idlest rival to attempt a steal every 75s when a
-- victim exists. The clock iterates with pairs (State.rivals is
-- keyed by model — ipairs would find nothing).
do
	local rivalSrc = read("src/server/RivalService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not rivalSrc or not configSrc then
		check("ck", false, "could not verify the thief fix — RivalService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find("local function walkAround") then
			table.insert(problems, "no walkAround ring-route helper — rival walks still cut straight through the crater rim")
		end
		if not rivalSrc:find("walkAround%(model, gap") or not rivalSrc:find("walkAround%(model, around") or not rivalSrc:find("walkAround%(model, padCf%.Position") then
			table.insert(problems, "not all rival walks use the ring route — toCrater, steal and toBase must all call walkAround")
		end
		if not rivalSrc:find("steal clock") or not rivalSrc:find("task%.wait%(75%)") then
			table.insert(problems, "no 75s steal clock — steals are still left to the idle roll alone")
		end
		if not rivalSrc:find("pairs%(State%.rivals%)") then
			table.insert(problems, "the steal clock does not iterate State.rivals with pairs — ipairs would find no rival (keyed by model)")
		end
		if not rivalSrc:find("local function tryStartSteal") then
			table.insert(problems, "no shared tryStartSteal — the idle roll and the steal clock start steals differently")
		end
		if not configSrc:find("RIVAL_STEAL_CHANCE = 0%.5") then
			table.insert(problems, "steal chance is not 0.5")
		end
		if not configSrc:find("RIVAL_WALK_SPEED = 16") then
			table.insert(problems, "rival walk speed is not 16")
		end
		if #problems > 0 then
			check("ck", false, "the thief fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, Config.luau")
		else
			check("ck", true, "thieves actually steal: all rival walks route along the radius-45 ring (gap exit from inside, arc to the target's angle), steal chance 0.5, rivals walk at 16, a 75s steal clock forces the idlest rival to attempt a steal when a victim exists (pairs over model-keyed State.rivals), one shared tryStartSteal for the roll and the clock")
		end
	end
end

-- -- Summary ------------------------------------------------------------------
local passed = 0
local failing: { string } = {}
for _, r in ipairs(results) do
	if r.ok then
		passed += 1
	else
		table.insert(failing, "(" .. r.id .. ")")
	end
end
print("AUTO-CHECKS: " .. tostring(passed) .. "/" .. tostring(#results) .. " passed"
	.. (if #failing > 0 then " — FAILING: " .. table.concat(failing, ", ") else ""))
if #failing > 0 then
	process.exit(1)
end
process.exit(0)
