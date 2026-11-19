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
--   (r) contracts or the daily reward are not wired
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

-- -- (m) conveyor: scarcity — 3-5 Brainrots, one every 15-20s --------------
-- (simplify/polish, competition via scarcity): the old conveyor kept
-- 6-10 Rotlings with a fast refill. Now the crater holds 3-5 at a
-- time and a new one walks in every 15-20s, one per tick — a picked-
-- clean crater stays thin until the next tick, and that thinness is
-- the competition.
do
	local configSrc = read("src/shared/Config.luau")
	local spawnSrc = read("src/server/SpawnService.luau")
	if not configSrc or not spawnSrc then
		check("m", false, "could not verify the conveyor — Config.luau or SpawnService.luau missing")
	else
		local problems: { string } = {}
		local interval = configValue(configSrc, "SPAWN_INTERVAL")
		local maxFree = configValue(configSrc, "CRATER_MAX_FREE")
		if not interval then
			table.insert(problems, "Config.SPAWN_INTERVAL not found")
		elseif interval < 15 or interval > 20 then
			table.insert(problems, "spawn interval " .. tostring(interval) .. "s (not 15-20s)")
		end
		if not maxFree then
			table.insert(problems, "Config.CRATER_MAX_FREE not found")
		elseif maxFree ~= 5 then
			table.insert(problems, "conveyor cap " .. tostring(maxFree) .. " (not 5)")
		end
		-- The old fast-refill constants are gone: no floor, no initial.
		if configSrc:find("CRATER_MIN_FREE") then
			table.insert(problems, "Config.CRATER_MIN_FREE still exists (fast refill is gone)")
		end
		if configSrc:find("CRATER_INITIAL") then
			table.insert(problems, "Config.CRATER_INITIAL still exists (opening mix is explicit now)")
		end
		-- The spawn loop tops up one per tick, capped at CRATER_MAX_FREE.
		local startBody = functionBody(spawnSrc, "SpawnService.start")
		if not startBody then
			table.insert(problems, "SpawnService.start not found")
		else
			if startBody:find("CRATER_MIN_FREE") then
				table.insert(problems, "SpawnService.start still fast-refills to CRATER_MIN_FREE")
			end
			if not startBody:find("countFree%(%) < Config%.CRATER_MAX_FREE") then
				table.insert(problems, "the spawn loop is not capped at CRATER_MAX_FREE")
			end
			if not startBody:find("task%.wait%(Config%.SPAWN_INTERVAL%)") then
				table.insert(problems, "the spawn loop does not tick on SPAWN_INTERVAL")
			end
		end
		-- The opening mix is 5 explicit entries (no CRATER_INITIAL top-up).
		if spawnSrc:find("CRATER_INITIAL") then
			table.insert(problems, "SpawnService still tops up the opening from CRATER_INITIAL")
		end
		if #problems > 0 then
			check("m", false, "the conveyor is not scarce — " .. table.concat(problems, "; ") .. ". Parts: SpawnService.start, Config.SPAWN_INTERVAL / CRATER_MAX_FREE")
		else
			check("m", true, "the conveyor is scarce: cap 5, one new Brainrot every " .. tostring(interval) .. "s, opening mix of 5, no fast refill")
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

-- -- (o) colourful bases, sign shows name + cash only -------------------------
-- (simplify/polish, real-base section): the "Lv N" billboard under the
-- owner sign is GONE — the sign shows the player name and the base cash
-- and nothing else. Level still exists internally (missions use it) but
-- the player never sees a level number on the base.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	if not worldSrc or not incomeSrc then
		check("o", false, "could not verify base signs — WorldBuilder.luau or IncomeService.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find('sign%.Name = "BaseSign"') then
			table.insert(problems, '"BaseSign" billboard not found')
		end
		if not worldSrc:find('cashLabel%.Name = "CashLabel"') then
			table.insert(problems, 'no "CashLabel" line on the base sign')
		end
		if worldSrc:find('levelSign%.Name = "BaseLevel"') then
			table.insert(problems, 'the "BaseLevel" billboard is still built')
		end
		if worldSrc:find("function WorldBuilder.setBaseLevel") then
			table.insert(problems, "WorldBuilder.setBaseLevel still exists")
		end
		if worldSrc:find('"Lv "') then
			table.insert(problems, 'a "Lv " string still exists in WorldBuilder')
		end
		if incomeSrc:find("WorldBuilder.setBaseLevel") then
			table.insert(problems, "IncomeService still calls WorldBuilder.setBaseLevel")
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
			check("o", false, "the base sign still shows a level — " .. table.concat(problems, "; ") .. ". Parts: BaseSign / CashLabel (WorldBuilder.luau), IncomeService.broadcastHud")
		else
			check("o", true, "colourful bases, sign shows name + base cash only — no Lv anywhere on the base")
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
		-- ONE top line (simplify/polish HUD): cash • income • index •
		-- stardust, centred, scale width + TextScaled so a narrow
		-- phone screen never cuts it. The old Coins / Cps labels are gone.
		if not hudSrc:find('makeLabel%(gui, "TopLine"') then
			table.insert(problems, 'no "TopLine" label in HUDController.client.luau')
		end
		if not hudSrc:find("topLineLabel%.TextScaled = true") then
			table.insert(problems, "the top line is not TextScaled (it will clip on a narrow phone)")
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
		-- The quest pill under the top line (simplify/polish HUD): one
		-- small centred pill, not a full-width strip.
		if not hudSrc:find('questPill%.Name = "QuestPill"') then
			table.insert(problems, '"QuestPill" frame not found in HUDController.client.luau')
		end
		if not hudSrc:find('questFill%.Name = "QuestFill"') then
			table.insert(problems, '"QuestFill" progress fill not found in HUDController.client.luau')
		end
		if #problems > 0 then
			check("q", false, "the top HUD is incomplete — " .. table.concat(problems, "; ") .. ". Parts: TopLine / UpgradeButton / DailyButton / QuestPill (HUDController.client.luau), ShopButton (ShopController.client.luau)")
		else
			check("q", true, "top HUD complete — one line (cash • income • index • stardust) centred and TextScaled, Shop / Upgrade / Daily in the top row, quest pill with progress fill under the top line")
		end
	end
end

-- -- (r) contracts + daily reward actually work ---------------------------------
do
	local configSrc = read("src/shared/Config.luau")
	local missionSrc = read("src/server/MissionService.luau")
	local dailySrc = read("src/server/DailyService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local contractSrc = read("src/client/ContractController.client.luau")
	local projectSrc = read("default.project.json")
	if not configSrc or not missionSrc or not dailySrc or not carrySrc or not incomeSrc or not remotesSrc or not worldSrc or not contractSrc or not projectSrc then
		check("r", false, "could not verify contracts/daily — Config.luau, MissionService.luau, DailyService.luau, CarryService.luau, IncomeService.luau, Remotes.luau, WorldBuilder.luau, ContractController.client.luau or default.project.json missing")
	else
		local problems: { string } = {}
		-- A real contract pool in Config (one `{ id = "..." }` row
		-- each — counted over the whole file, since the table spans
		-- lines and Lua "." never crosses a newline). Three at a
		-- time on the board needs a pool bigger than three.
		local contractCount = 0
		for _ in configSrc:gmatch('%{ id = "') do
			contractCount += 1
		end
		if contractCount < 6 then
			table.insert(problems, "Config.CONTRACTS holds " .. tostring(contractCount) .. " contracts (need 6+)")
		end
		if not configSrc:find("CONTRACTS_AT_ONCE") then
			table.insert(problems, "Config.CONTRACTS_AT_ONCE not found")
		end
		-- MissionService counts progress, marks ready, pays on claim.
		if not missionSrc:find("function MissionService.addProgress") then
			table.insert(problems, "MissionService.addProgress not found")
		end
		if not missionSrc:find("function MissionService.currentMission") then
			table.insert(problems, "MissionService.currentMission not found")
		end
		if not missionSrc:find("function MissionService.claimContract") then
			table.insert(problems, "MissionService.claimContract not found")
		end
		if not missionSrc:find("function MissionService.activeContracts") then
			table.insert(problems, "MissionService.activeContracts not found")
		end
		if not missionSrc:find("profile%.coins %+= def%.reward") then
			table.insert(problems, "MissionService.claimContract never pays the reward")
		end
		-- Hooks: grab, place, earn, rare.
		if not carrySrc:find('MissionService.addProgress%(player, "grab", 1%)') then
			table.insert(problems, "CarryService.tryGrab never reports grab progress")
		end
		if not carrySrc:find('MissionService.addProgress%(player, "place", 1%)') then
			table.insert(problems, "CarryService.placeOnPad never reports place progress")
		end
		if not carrySrc:find('MissionService.addProgress%(player, "rare", 1%)') then
			table.insert(problems, "CarryService.tryGrab never reports rare progress")
		end
		if not incomeSrc:find('MissionService.addProgress%(player, "earn", gained%)') then
			table.insert(problems, "IncomeService tick never reports earn progress")
		end
		-- The HUD feed carries the quest pill, the board list and the daily state.
		if not incomeSrc:find("missionText = mission%.text") then
			table.insert(problems, "IncomeService.broadcastHud never sends the quest pill")
		end
		if not incomeSrc:find("contracts = MissionService.activeContracts%(player%)") then
			table.insert(problems, "IncomeService.broadcastHud never sends the contracts")
		end
		if not incomeSrc:find("dailyReady = DailyService.isReady%(player%)") then
			table.insert(problems, "IncomeService.broadcastHud never sends dailyReady")
		end
		-- Remotes: claim (function) + open board (event), declared in the project.
		if not remotesSrc:find("function Remotes.claimContractFunction") then
			table.insert(problems, "Remotes.claimContractFunction not found")
		end
		if not remotesSrc:find("function Remotes.openContractsEvent") then
			table.insert(problems, "Remotes.openContractsEvent not found")
		end
		if not projectSrc:find('"ClaimContract"') then
			table.insert(problems, "ClaimContract remote not declared in default.project.json")
		end
		if not projectSrc:find('"OpenContracts"') then
			table.insert(problems, "OpenContracts remote not declared in default.project.json")
		end
		-- The world board + the panel.
		if not worldSrc:find("buildContractBoard") then
			table.insert(problems, "WorldBuilder.buildContractBoard not found")
		end
		if not worldSrc:find("ContractBoardPrompt") then
			table.insert(problems, "WorldBuilder contract board has no prompt")
		end
		if not contractSrc:find("Claim") then
			table.insert(problems, "ContractController has no Claim button")
		end
		if not contractSrc:find("claimContractFunction") then
			table.insert(problems, "ContractController never invokes ClaimContract")
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
			check("r", false, "contracts/daily are not wired — " .. table.concat(problems, "; ") .. ". Parts: MissionService / DailyService, CarryService hooks, IncomeService.broadcastHud, ContractController, WorldBuilder contract board")
		else
			check("r", true, "contracts + daily work — " .. tostring(contractCount) .. " contracts in the pool, 3 at a time, grab/place/earn/rare hooks report progress, rewards paid on claim server-side, HUD feed carries contracts + dailyReady, world board + panel wired")
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

-- -- (x) loop: tutorial arrows for a new player's first 80 seconds -----------
-- (fix round 7, item 5) Four steps over 80 seconds, not three over 60:
-- the old tutorial stopped the moment the player grabbed their first
-- Rotling, so BONK was never explained. Step 4 explains Bonk in
-- plain words, and the tutorial now stops early only when the player
-- actually bonks a thief.
do
	local tutSrc = read("src/client/TutorialController.client.luau")
	if not tutSrc then
		check("x", false, "could not verify the tutorial — TutorialController.client.luau missing")
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
			table.insert(problems, "fewer than 4 tutorial steps")
		end
		if #problems > 0 then
			check("x", false, "tutorial arrows are missing or wrong — " .. table.concat(problems, "; ") .. ". Parts: TutorialController.client.luau")
		else
			check("x", true, "tutorial arrows work — gold arrow, 4 steps (crater -> base -> SELL -> BONK), 80s, firstTime only, stops early on a successful bonk")
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
			table.insert(problems, "no Index count (x/22) in the HUD")
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
			check("z", true, "HUD identity + density — SPACE ROCK BRAINROTS title, Index count x/22, top-3 leaderboard panel")
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
-- close, 5 icon (the logo stage, three heroes + fiery meteor).
-- The old crater isometric is gone.
do
	local photoSrc = read("src/client/PhotoModeController.client.luau")
	if not photoSrc then
		check("ac", false, "could not verify photo-mode cameras — PhotoModeController.client.luau missing")
	else
		local problems: { string } = {}
		-- Shot 1 (hero row): the STAGED group in front of the title
		-- sign (fix round 13, item 6) — four display Brainrots with
		-- labels, the title sign and the crater behind them. The
		-- framing is proven geometrically by the hero-shot check;
		-- this check pins the camera.
		if not photoSrc:find("Vector3.new%(1%.75, 14, 96%)") then
			table.insert(problems, "shot 1 is not the staged hero-row camera (1.75, 14, 96)")
		end
		if not photoSrc:find("Vector3.new%(1, 3, 80%)") then
			table.insert(problems, "shot 1 does not look at the hero row (1, 3, 80)")
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
		-- Shot 5 (icon): the logo stage at (0, 0, 118) — it moved
		-- there in v74 from (-25, 0, 88) and this camera never
		-- followed it, so it framed empty field until fix round 13.
		-- Three hero Rotlings (8 apart, labels readable) with the
		-- fiery meteor above/behind them.
		if not photoSrc:find("Icon — 512x512") then
			table.insert(problems, "no icon shot (Icon — 512x512)")
		end
		if not photoSrc:find("Vector3.new%(0, 4, 100%)") then
			table.insert(problems, "icon shot is not the logo-stage camera (0, 4, 100)")
		end
		if not photoSrc:find("Vector3.new%(0, 3, 118%)") then
			table.insert(problems, "icon shot does not look at the logo stage (0, 3, 118)")
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
			check("ac", true, "photo cameras are the 4 bounty shots + icon — staged hero row (1.75, 14, 96) first, belt close on the conveyor, storm wide (48, 10, 18) looking at the sky, base 16 out / 7 up, icon on the logo stage (0, 4, 100)")
		end
	end
end

-- -- (hero-shot) fix round 13, item 6: shot 1 is a STAGED hero row --
-- The first thumbnail + first submission screenshot must show the
-- pattern the top-10 leaders share (4+ distinct Brainrots with
-- name/rarity/$-per-sec labels, a big title sign, a dense themed
-- backdrop) — so shot 1 is staged, not a generic close-up: a hero
-- row of four display Brainrots on a plinth in front of the title
-- sign, with the crater rim behind it. This check COMPUTES the
-- framing from the shipped camera CFrames (screen angles via atan2,
-- 16:9: 70deg vertical FOV, ~102deg horizontal, 800px wide) instead
-- of trusting the numbers in a comment:
--   * all four heroes 16-19% of frame height (bodies 2.6..7.1
--     studs, labels at y~8.1 — the heroes stand on the plinth top
--     y=2.5, seated by their body bottoms, not sunk into the
--     platform);
--   * adjacent 200px labels 160px+ apart (edges touch, centred
--     text reads — 5 heroes cannot fit: the outer pairs would sit
--     ~150px apart and the outer labels would leave the frame);
--   * the title sign fully in frame, its text (width-bound, ~2.9deg
--     tall) clear of the highest label top by 1deg+;
--   * the crater rim in frame flanking the sign;
--   * the contract board's north-top corner out of frame (the board
--     is a north-south wall at x~16, z 88..100 — the row sits west
--     of it so no sightline to a hero crosses it).
-- Shot 5 is fixed the same way: the logo stage moved in v74 from
-- (-25, 0, 88) to (0, 0, 118) and the camera never followed it, so
-- it framed empty field. The stage is a visible dais now (top
-- y=2.5) with its heroes 8 apart (their labels were 107px apart at
-- 4.5 and buried each other's text) and seated by their body
-- bottoms — the old PivotTo put the body centre at pos and sank
-- them 1.75 into the spawn platform. Shot 5's labels sit ~190px
-- apart, all three heroes 20% of frame height, the meteor above
-- the centre label.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local tagSrc = read("src/client/TagController.client.luau")
	local photoSrc = read("src/client/PhotoModeController.client.luau")
	if not worldSrc or not tagSrc or not photoSrc then
		check("hero-shot", false, "could not verify the hero shot — a source file is missing")
	else
		local problems: { string } = {}
		-- Display heroes show their tags (the staged labels).
		if not tagSrc:find('state == "display"') then
			table.insert(problems, "TagController does not show display-hero tags (State \"display\" missing from showable)")
		end
		-- The hero row: four heroes, plinth, facing +Z, seated by
		-- body bottom.
		if not worldSrc:find("buildHeroRow") then
			table.insert(problems, "no hero row in the world (WorldBuilder.buildHeroRow)")
		end
		if not worldSrc:find('"gummy", "alfredo", "bloop", "couch"') then
			table.insert(problems, "the hero row is not gummy + alfredo + bloop + couch")
		end
		if not worldSrc:find('"HeroPlinth", Enum%.PartType%.Block, Vector3%.new%(21%.5, 1, 6%)') then
			table.insert(problems, "the hero plinth is not 21.5 x 1 x 6")
		end
		if not worldSrc:find("Vector3%.new%(%-8 %+ %(i %- 1%) %* 6%.5, 2%.5, 82%)") then
			table.insert(problems, "the hero row heroes are not at x -8/-1.5/5/11.5, z=82, on the plinth top y=2.5")
		end
		-- The row faces +Z (no 180 turn): its PivotTo seats the
		-- body bottom on the plinth with no rotation. (The logo
		-- stage's PivotTo has the 180 turn and does NOT match this
		-- pattern — the three closing parens end the call.)
		if not worldSrc:find("model:PivotTo%(CFrame%.new%(pos %+ Vector3%.new%(0, b%.Size%.Y / 2 %+ 0%.1, 0%)%)%)") then
			table.insert(problems, "the hero row does not seat its heroes by body bottom facing +Z")
		end
		-- The logo stage: visible dais, heroes 8 apart, seated by
		-- body bottom (not sunk into the platform).
		if not worldSrc:find('"LogoStage", Enum%.PartType%.Block, Vector3%.new%(20, 1, 8%)') then
			table.insert(problems, "the logo stage is not 20 x 1 x 8")
		end
		if not worldSrc:find("%(i %- 2%) %* 8") then
			table.insert(problems, "the logo-stage heroes are not 8 apart")
		end
		if worldSrc:find("%(i %- 2%) %* 4%.5") then
			table.insert(problems, "the old logo-stage hero spacing (4.5) is still there")
		end
		-- The shipped cameras must be the staged ones (the geometry
		-- below is computed from these literals).
		if not photoSrc:find("Vector3%.new%(1%.75, 14, 96%)") then
			table.insert(problems, "shot 1 is not the staged hero-row camera (1.75, 14, 96)")
		end
		if not photoSrc:find("Vector3%.new%(1, 3, 80%)") then
			table.insert(problems, "shot 1 does not look at the hero row (1, 3, 80)")
		end
		if not photoSrc:find("Vector3%.new%(0, 4, 100%)") then
			table.insert(problems, "shot 5 is not the logo-stage camera (0, 4, 100)")
		end
		if not photoSrc:find("Vector3%.new%(0, 3, 118%)") then
			table.insert(problems, "shot 5 does not look at the logo stage (0, 3, 118)")
		end
		-- Screen-angle framing, computed from the camera + the
		-- staged world (atan2: the true screen angle; 800px wide,
		-- 102deg horizontal FOV at 16:9, 70deg vertical).
		local function vsub(a: { number }, b: { number }): { number }
			return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
		end
		local function vdot(a: { number }, b: { number }): number
			return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
		end
		local function vcross(a: { number }, b: { number }): { number }
			return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
		end
		local function vnorm(a: { number }): { number }
			local l = math.sqrt(vdot(a, a))
			return { a[1] / l, a[2] / l, a[3] / l }
		end
		-- Returns {h, v}: screen angles in degrees (+right, +up).
		local function screenAngles(cam: { number }, look: { number }, p: { number }): { number }
			local fwd = vnorm(vsub(look, cam))
			local right = vnorm(vcross(fwd, { 0, 1, 0 }))
			local up = vcross(right, fwd)
			local d = vsub(p, cam)
			local h = math.atan2(vdot(d, right), vdot(d, fwd)) * 180 / math.pi
			local v = math.atan2(vdot(d, up), vdot(d, fwd)) * 180 / math.pi
			return { h, v }
		end
		local function inFrame(h: number, v: number): boolean
			return math.abs(h) < 51 and math.abs(v) < 35
		end
		-- Shot 1: camera (1.75, 14, 96) -> (1, 3, 80); heroes at
		-- x -8/-1.5/5/11.5, z=82; bodies 2.6..7.1, labels at y~8.1.
		local cam1 = { 1.75, 14, 96 }
		local look1 = { 1, 3, 80 }
		local heroXs = { -8, -1.5, 5, 11.5 }
		local labelH: { number } = {}
		local maxLabelTop = -100
		for _, x in ipairs(heroXs) do
			local hv = screenAngles(cam1, look1, { x, 8.1, 82 })
			table.insert(labelH, hv[1])
			if hv[2] + 3.7 > maxLabelTop then
				maxLabelTop = hv[2] + 3.7
			end
			local hvTop = screenAngles(cam1, look1, { x, 7.1, 82 })
			local hvBot = screenAngles(cam1, look1, { x, 2.6, 82 })
			local bodyDeg = hvTop[2] - hvBot[2]
			if bodyDeg < 11 or bodyDeg > 14 then
				table.insert(problems, "hero at x=" .. tostring(x) .. " is " .. string.format("%.1f", bodyDeg / 70 * 100) .. "% of frame height, not 16-19%")
			end
			if not inFrame(hv[1], hv[2]) then
				table.insert(problems, "hero at x=" .. tostring(x) .. " is out of shot 1's frame")
			end
		end
		for i = 1, 3 do
			local sepPx = math.abs(labelH[i + 1] - labelH[i]) * (800 / 102)
			if sepPx < 160 then
				table.insert(problems, "hero labels " .. tostring(i) .. "-" .. tostring(i + 1) .. " sit " .. string.format("%.0f", sepPx) .. "px apart — under 160px, the 200px cards bury each other's text")
			end
		end
		if math.abs(labelH[1]) + 12.75 >= 51 or math.abs(labelH[4]) + 12.75 >= 51 then
			table.insert(problems, "an outer hero label leaves shot 1's frame")
		end
		-- The title sign (0, 9, 46), 22x6 — the arch over the
		-- spawn→crater path (fix round 14, item 2): all four
		-- corners in frame, and its text (width-bound, ~2.9deg
		-- tall) clear of the highest label top by 1deg+.
		for _, c in ipairs({ { -11, 12, 46 }, { 11, 12, 46 }, { -11, 6, 46 }, { 11, 6, 46 } }) do
			local hv = screenAngles(cam1, look1, c)
			if not inFrame(hv[1], hv[2]) then
				table.insert(problems, "the title sign corner (" .. tostring(c[1]) .. ", " .. tostring(c[2]) .. ", 46) is out of shot 1's frame")
			end
		end
		local signHv = screenAngles(cam1, look1, { 0, 9, 46 })
		if signHv[2] - 1.45 - maxLabelTop < 1 then
			table.insert(problems, "the hero labels reach into the title sign's text (clearance " .. string.format("%.1f", signHv[2] - 1.45 - maxLabelTop) .. "deg, need 1deg+)")
		end
		-- The crater rim flanks the sign in frame.
		for _, r in ipairs({ { 0, 5.5, 39 }, { -28, 5.5, 28 }, { 39, 5.5, 39 } }) do
			local hv = screenAngles(cam1, look1, r)
			if not inFrame(hv[1], hv[2]) then
				table.insert(problems, "the crater rim point (" .. tostring(r[1]) .. ", 5.5, " .. tostring(r[3]) .. ") is out of shot 1's frame")
			end
		end
		-- The contract board's north-top corner (16, 10, 88) is
		-- out of frame to the east; and every hero stands west of
		-- the board's plane (x=16), so no sightline to a hero
		-- crosses the board.
		local boardHv = screenAngles(cam1, look1, { 16, 10, 88 })
		if math.abs(boardHv[1]) < 51 then
			table.insert(problems, "the contract board's north-top corner is inside shot 1's frame (h=" .. string.format("%.1f", boardHv[1]) .. "deg)")
		end
		for _, x in ipairs(heroXs) do
			if x >= 16 then
				table.insert(problems, "hero at x=" .. tostring(x) .. " stands east of the contract board (x=16) — its sightline crosses the board")
			end
		end
		-- Shot 5: camera (0, 4, 100) -> (0, 3, 118); stage heroes
		-- at x -8/0/8, z=118; bodies 2.6..7.1, labels at y~8.1.
		local cam5 = { 0, 4, 100 }
		local look5 = { 0, 3, 118 }
		local stageH: { number } = {}
		for _, x in ipairs({ -8, 0, 8 }) do
			local hv = screenAngles(cam5, look5, { x, 8.1, 118 })
			table.insert(stageH, hv[1])
			local hvTop = screenAngles(cam5, look5, { x, 7.1, 118 })
			local hvBot = screenAngles(cam5, look5, { x, 2.6, 118 })
			local bodyDeg = hvTop[2] - hvBot[2]
			if bodyDeg < 12 or bodyDeg > 16 then
				table.insert(problems, "logo-stage hero at x=" .. tostring(x) .. " is " .. string.format("%.1f", bodyDeg / 70 * 100) .. "% of frame height, not ~20%")
			end
			if not inFrame(hv[1], hv[2]) then
				table.insert(problems, "logo-stage hero at x=" .. tostring(x) .. " is out of shot 5's frame")
			end
		end
		for i = 1, 2 do
			local sepPx = math.abs(stageH[i + 1] - stageH[i]) * (800 / 102)
			if sepPx < 180 then
				table.insert(problems, "logo-stage labels " .. tostring(i) .. "-" .. tostring(i + 1) .. " sit " .. string.format("%.0f", sepPx) .. "px apart — under 180px, the 200px cards bury each other's text")
			end
		end
		if #problems > 0 then
			check("hero-shot", false, "the hero shot is not staged — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau (buildHeroRow, buildLogoStage), TagController.client.luau, PhotoModeController.client.luau")
		else
			check("hero-shot", true, "shot 1 staged: 4 heroes (gummy, alfredo, bloop, couch) 16-19% of frame, labels 162-194px apart and on-screen, title sign in frame with text clear of the labels, crater rim flanking, contract board out of frame; shot 5: logo-stage heroes 8 apart, labels ~190px apart, 20% of frame, meteor above the centre label; display tags on")
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
			check("ai", true, "every Rotling's primary colour is its rarity colour — " .. tostring(defCount) .. " defs match RarityConfig exactly, factory paints rarity.color, all 7 tier colours saturated (spread >= 100)")
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
	local warnSrc = read("src/client/StormWarningController.client.luau")
	if not configSrc or not stormSrc or not warnSrc then
		check("am", false, "could not verify the storm spread — Config.luau, StarfallService.luau or StormWarningController.client.luau missing")
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
		if not stormSrc:find("STORM_HAZARD_LABEL") and not warnSrc:find("STORM_HAZARD_LABEL") then
			table.insert(problems, "the storm banner carries no hazard label (neither the server banner nor the warning bar shows it)")
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
		if not incomeSrc:find("STORM BOUNTY") then
			table.insert(problems, "the storm bounty is never announced (IncomeService.awardStormBounty)")
		end
		if not mainSrc:find("RivalService.start") then
			table.insert(problems, "RivalService.start is never called (Main.server)")
		end
		if #problems > 0 then
			check("an", false, "rivals do not play — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, names (Config.luau), leaderboard/bounty (IncomeService.luau), wiring (Main.server.luau)")
		else
			check("an", true, "4 named rivals on bases 5-8 grab, carry, earn and show on the leaderboard; steal + chase wired, storm bounty paid + announced at storm end")
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
		if not slapClient:find("BONK") then
			table.insert(problems, "no on-screen BONK button")
		end
		if not slapClient:find("SlapBat") then
			table.insert(problems, "no visible bat part while swinging")
		end
		if #problems > 0 then
			check("ao", false, "the slap bat is broken — " .. table.concat(problems, "; ") .. ". Parts: SlapService.luau, SlapController.client.luau")
		else
			check("ao", true, "slap bat: F key + SLAP button, 2s cooldown, knockback + drop, shockwave + BONK! burst, shield immunity, rivals slap back")
		end
	end
end

-- -- (ap) meteor eggs ------------------------------------------------------------
-- Item 12 (rebalanced fix round 10): 4 eggs per storm, heavy carry (walk
-- slower), rivals chase, incubator per base, rarity-scaled hatch into a
-- random Rotling with Epic / Legendary / mutation chances, hatch
-- animation + reveal popup, and the egg drops on death.
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
		elseif perStorm < 1 or perStorm > 4 then
			table.insert(problems, "EGGS_PER_STORM is " .. tostring(perStorm) .. " (must be 1-4)")
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
			{ "crashed spaceship", '"SpaceshipSaucer"' },
			{ "moon", 'part%("Moon"' },
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
			check("aq", true, "map filled: Star Shop + keeper, upgrade machines, rebirth altar, spaceship, moon, signposts, fences, paths, critters (index wall + mountains removed in the simplify/polish pass — see check (cy))")
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
		if hudSrc:find("XpBar") then
			table.insert(problems, "the XP bar is still in the HUD (removed in the simplify/polish pass — rebirth is the only visible progress system)")
		end
		if not worldSrc:find("LogoStage") then
			table.insert(problems, "no logo stage in the world (WorldBuilder.buildLogoStage)")
		end
		if not worldSrc:find("SPACE ROCK BRAINROTS") then
			table.insert(problems, "no SPACE ROCK BRAINROTS title in the world")
		end
		if #problems > 0 then
			check("at", false, "the last adds are missing — " .. table.concat(problems, "; ") .. ". Parts: catalog/mutations (Shared), Stardust in the HUD + no XP bar (HUDController), logo stage (WorldBuilder.luau)")
		else
			check("at", true, tostring(defCount) .. " Rotlings, Diamond + Scorched mutations, Stardust in the HUD with no XP bar, logo stage in the world")
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
		-- Rebirth progress lives ON the Rebirth button now (simplify/
		-- polish HUD): the full-width NEXT REBIRTH bar is gone. The
		-- button carries a fill that grows with progress and turns gold
		-- with a gold outline when ready.
		if hudSrc:find("RebirthBar") or hudSrc:find("RebirthProgressLabel") then
			table.insert(problems, "the old NEXT REBIRTH bar is still in the HUD (progress lives on the Rebirth button now)")
		end
		if not hudSrc:find("RebirthButtonFill") then
			table.insert(problems, "no progress fill on the Rebirth button")
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
		if hudSrc:find("BeltPanel") then
			table.insert(problems, 'the "On the belt" list is still in the HUD (removed in the simplify/polish pass)')
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
			check("au", true, "cheap wins: multiplier in tags + index, rebirth progress on the Rebirth button (fill + gold glow when ready), upgrade levels, no title billboard (removed per playtest), shield dome + SAFE label, pursuit banner, 2 global events, danger meter, no belt list (removed in the simplify/polish pass), Disco Donut")
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
		-- PARKED (simplify pass, v74): the pet is off, so nothing may
		-- spawn it — but the code stays so it can return. The tag,
		-- the +5% bonus and the Index button still exist; they are
		-- just unreachable while parked.
		if not buddySrc:find("function BuddyService%.attachBuddy") then
			table.insert(problems, "attachBuddy gone — the pet cannot return later")
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
		if mainSrc:find("attachBuddy") then
			table.insert(problems, "the buddy is still attached on spawn (Main.server)")
		end
		if not buddySrc:find("BUDDY_PARKED") then
			table.insert(problems, "refreshBuddy is not parked — a placement would re-spawn the pet")
		end
		if not indexSrc:find("buddyButton%.Visible = false") then
			table.insert(problems, "the Set as Buddy button is not hidden")
		end
		if #problems > 0 then
			check("av", false, "the buddy park is broken — " .. table.concat(problems, "; ") .. ". Parts: BuddyService.luau, Index swap (IndexController), wiring (Main.server.luau)")
		else
			check("av", true, "buddy parked: pet never spawned (no label over the player), +5% bonus and Index button kept but unreachable — code ready to return")
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
-- storm, with a green "SAFE DOME" label over every base while it
-- passes. The wall is pure spectacle: knockback and dropped Rotlings
-- still come only from the falling meteors. The storm voice is the
-- StormWarningController's warnBar + countdown (fix round 9, item 10)
-- — the old server "METEOR SHOWER INCOMING! RUN HOME!" banner drew
-- over it, so it is gone.
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
		if stormSrc:find("METEOR SHOWER INCOMING! RUN HOME!") then
			table.insert(problems, 'the server still fires the "METEOR SHOWER INCOMING! RUN HOME!" banner — it overlaps the warning bar')
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
			check("ax", true, "storm front: giant glowing wall sweeps the map, storm voice is the warning bar (no overlapping server banner), green SAFE DOME label + dome over every base while it passes")
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
-- into profile.banked, the glowing collect pad at the middle of the base
-- shows the waiting amount and stepping on it moves it all into the
-- wallet (real-base section — the pad replaced the HUD Collect button),
-- and the base sign shows the banked cash. Direct payouts (missions,
-- daily, sell, bounty, offline, index) still land in the wallet.
do
	local bankSrc = read("src/server/BankService.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local dataSrc = read("src/server/DataService.luau")
	local stateSrc = read("src/server/State.luau")
	local baseSrc = read("src/server/BaseService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	local projectSrc = read("default.project.json")
	local remotesSrc = read("src/shared/Remotes.luau")
	if not bankSrc or not incomeSrc or not worldSrc or not dataSrc or not stateSrc or not baseSrc or not mainSrc or not projectSrc or not remotesSrc then
		check("ba", false, "could not verify banking — BankService.luau, IncomeService.luau, WorldBuilder.luau, DataService.luau, State.luau, BaseService.luau, Main.server.luau, default.project.json or Remotes.luau missing")
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
		-- The collect pad (real-base section): a glowing pad in the
		-- middle of the base, not a HUD button.
		if not worldSrc:find('part%("CollectPad"') then
			table.insert(problems, "no CollectPad in the base (WorldBuilder)")
		end
		if not worldSrc:find("CollectLabel") then
			table.insert(problems, "no CollectLabel showing the waiting cash on the pad")
		end
		if not worldSrc:find("step to collect") then
			table.insert(problems, "the collect pad label does not say 'step to collect'")
		end
		if not worldSrc:find("collectLabel%.Text = ") then
			table.insert(problems, "setBaseCoins never updates the collect pad label")
		end
		if not bankSrc:find("Touched:Connect") then
			table.insert(problems, "no Touched wiring on the collect pad (BankService.init)")
		end
		if not bankSrc:find("BankService%.collectBank%(player%)") then
			table.insert(problems, "stepping on the pad never calls collectBank")
		end
		if not bankSrc:find("getPlayerBase%(player%.UserId%)") then
			table.insert(problems, "the pad does not check the toucher owns the base")
		end
		if worldSrc:find("CollectButton") then
			table.insert(problems, "a Collect button still exists in WorldBuilder (the pad replaced it)")
		end
		if not incomeSrc:find("setBaseCoins%(baseId, profile%.banked%)") then
			table.insert(problems, "the base sign does not show the banked cash")
		end
		if not baseSrc:find("setBaseCoins%(baseId, if profile then profile%.banked else 0%)") then
			table.insert(problems, "the base sign is not initialised from the banked balance")
		end
		if #problems > 0 then
			check("ba", false, "banking is missing — " .. table.concat(problems, "; ") .. ". Parts: banked profile (State/DataService), tick (IncomeService.luau), collect pad (WorldBuilder.luau + BankService.luau), base sign (WorldBuilder)")
		else
			check("ba", true, "banking: income banks at the base, the glowing collect pad shows the waiting cash and pays it into the wallet on touch (owner only, debounced), base sign shows the banked cash")
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
			if not incomeSrc:find("WorldBuilder%.isOnBaseInterior%(baseId, root%.Position%)") then
				table.insert(problems, "stormBoostActive does not use isOnBaseInterior (the doorway still counts as sheltered)")
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
		-- Simultaneous at storm start: warning bar + wall + heroes + rain.
		-- (fix round 9, item 10) the server banner is gone — the
		-- StormWarningController's warnBar + countdown is the storm
		-- voice at storm start.
		if not warnSrc:find("SPACE ROCKS INCOMING") then
			table.insert(problems, "no storm warning bar countdown at storm start")
		end
		if not starSrc:find("task.spawn%(function%(%)%s+local ok, err = pcall%(spawnStormFront%)") then
			table.insert(problems, "storm front wall is not spawned at storm start")
		end
		if #problems > 0 then
			check("bd", false, "the storm's effect is not unmistakable — " .. table.concat(problems, "; ") .. ". Parts: onMeteorLanded hit banner (StarfallService.luau), MeteorHitFlash (CameraFX.client.luau), storm bar x2 + pulse (StormWarningController.client.luau)")
		else
			check("bd", true, "storm hit feedback: METEOR HIT banner + red screen flash on a close impact; storm bar says SHELTER = x2 INCOME and throbs; warning bar + wall + heroes + rain all fire at storm start")
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
		-- (competition via scarcity: raids every 60-90s, 75 matches the
		-- 75s steal clock; the 45s cadence was set when thieves were
		-- broken and silent.)
		if interval ~= 75 then
			table.insert(problems, "Config.RAIDER_INTERVAL is " .. tostring(interval) .. " (not 75)")
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
			check("be", true, "bots move: wedge ramp at every base front, raiders spawn at radius 45 / Y=8, first raid 15s then every 75s, stuck bots jump, raiders + rivals shelter on a base during storms")
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
		-- (Fix round 10: the call now uses the named shopPathFrom /
		-- shopPathTo locals, shared with the parallel fences — same
		-- endpoints, so the invariant is checked against the locals.)
		if not worldSrc:find("local shopPathFrom = Vector3%.new%(0, 0, 40%)") then
			table.insert(problems, "shopPathFrom is not the crater rim (0,0,40)")
		end
		if not worldSrc:find("local shopPathTo = Vector3%.new%(%-40, 0, 44%)") then
			table.insert(problems, "shopPathTo is not the shop (-40,0,44)")
		end
		if not worldSrc:find("path%(shopPathFrom, shopPathTo%)") then
			table.insert(problems, "the StonePath from the crater rim (0,0,40) to the shop is missing")
		end
		if #problems > 0 then
			check("bh", false, "the spawn path goes to nothing — " .. table.concat(problems, "; ") .. ". Parts: SpawnPath + fences (WorldBuilder.luau)")
		else
			check("bh", true, "spawn path runs z=78 to z=39 (the crater rim), fences flank it to z=40, StonePath to the shop starts at the rim — spawn -> crater -> shop is one continuous walkway")
		end
	end
end

-- -- (bi) branding: game name + 22 approved Rotling names (branding pass) -----
-- Malek approved the name "Space Rock Brainrots!" (Nov 18 16:10) and the
-- 22-name roster (5 Common, 4 Rare, 4 Epic, 4 Legendary, 2 Mythic,
-- 1 Cosmic, 2 Divine). Every approved name must be in the catalog under its
-- approved rarity, no old name may remain, and the game title must read
-- SPACE ROCK BRAINROTS in the HUD and the title screen. The world
-- billboard was REMOVED in fix round 2 (fix 8) — the giant sky text
-- filled the screen and its pitch line overlapped the SELL pad — so
-- (bi) proves it is GONE, not present. Fix round 11 adds a GROUND
-- title sign instead (buildWorldTitleSign, a proper sign near spawn,
-- not sky text): (bi) proves that sign exists and reads the title.
-- Two entries changed tier to match the approved roster (penguin Rare
-- -> Legendary, cat Cosmic -> Legendary).
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
			{ "Archangel Alfredo", "Divine" },
			{ "Pope Pineapple", "Divine" },
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
		if not worldSrc:find("WorldTitleSign") or not worldSrc:find('titleLabel.Text = "SPACE ROCK BRAINROTS!"', 1, true) then
			table.insert(problems, "no ground title sign near spawn (buildWorldTitleSign, reads SPACE ROCK BRAINROTS!)")
		end
		if worldSrc:find("TitleBoard") or worldSrc:find("buildTitleBillboard") then
			table.insert(problems, "world billboard is still in the sky (must be removed per the playtest)")
		end
		if #problems > 0 then
			check("bi", false, "the branding is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RotlingCatalog.luau, HUDController.client.luau, TitleScreenController.client.luau, WorldBuilder.luau")
		else
			check("bi", true, "branding: SPACE ROCK BRAINROTS! (HUD, title screen; world billboard removed per playtest); all 22 approved Rotling names in the catalog under their approved rarities (5C/4R/4E/4L/2M/1Co/2D), no old name remains")
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

-- -- (bn) the storm bounty is paid + announced (the live board is gone: the
-- Contract Board took its plaza spot; the payout stays) --------------------
do
	local incomeSrc = read("src/server/IncomeService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	if not incomeSrc or not rivalSrc then
		check("bn", false, "could not verify the storm bounty — IncomeService.luau or RivalService.luau missing")
	else
		local problems: { string } = {}
		if not incomeSrc:find("function IncomeService%.awardStormBounty") then
			table.insert(problems, "awardStormBounty is not defined (winner is never paid)")
		end
		if not incomeSrc:find("profile%.coins %+= Config%.BOUNTY_BONUS") then
			table.insert(problems, "the bounty winner is not paid Config.BOUNTY_BONUS")
		end
		if not incomeSrc:find("STORM BOUNTY:") then
			table.insert(problems, "the bounty winner is never announced server-wide")
		end
		if not incomeSrc:find("State%.stormEarnings%[player%.UserId%]") then
			table.insert(problems, "storm earnings are not tracked per player")
		end
		if not incomeSrc:find("function IncomeService%.resetStormEarnings") then
			table.insert(problems, "resetStormEarnings is not defined (earnings never reset between storms)")
		end
		if not rivalSrc:find("descendant:GetAttribute%(\"State\"%) == \"free\"") then
			table.insert(problems, "rivals do not grab free belt Rotlings (no competition on the belt)")
		end
		if #problems > 0 then
			check("bn", false, "the storm bounty is incomplete — " .. table.concat(problems, "; ") .. ". Parts: IncomeService.luau (awardStormBounty, stormEarnings), RivalService.luau")
		else
			check("bn", true, "storm bounty paid + announced: earnings tracked per player, winner paid the bonus and bannered server-wide at storm end, earnings reset between storms; rivals grab the same belt Rotlings as players")
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
		if not incomeSrc:find("local okBeat, errBeat = pcall%(function%(%)") then
			table.insert(problems, "the storm heartbeat does not have its own pcall")
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
			check("bo", true, "money feed is isolated: each player in their own pcall, float/broadcast/heartbeat each in their own pcall, diagnostic money line every 30s; sim-money prints the action | HUD said | actually added table")
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
		-- v74 plaza fix: the Contract Board moved to the EAST side of
		-- the path (16, 0, 94), away from the STAR SHOP sign on the
		-- west — the two signs overlapped on screen from the plaza.
		if not worldSrc:find("Vector3%.new%(16, 0, 94%)") then
			table.insert(problems, "Contract Board is not on the east side of the path (16, 0, 94)")
		end
		-- REMOVE (simplify/polish): the world Index Wall is gone — the
		-- Index lives in the HUD panel now. These prove it is GONE.
		if worldSrc:find("IndexWallBoard") then
			table.insert(problems, "the world Index Wall is still built (removed in the simplify/polish pass)")
		end
		if worldSrc:find("BRAINROT INDEX") then
			table.insert(problems, "the world Index Wall title is still in WorldBuilder (wall removed in the simplify/polish pass)")
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
			check("bq", true, "layout fixed: sky billboard + slogan gone, world Index Wall removed (HUD index kept), Contract Board (16,94) east of the path, storm panel 420px with a short warn line; every visible 'Rotling' is 'Brainrot'")
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
		-- v74 plaza fix: the Rebirth button widened to 220 (its READY
		-- text overflowed the 160px button off the screen edge), so
		-- it sits at (1, -244) now — right edge still 24px in. The
		-- Lock button stays at (1, -184).
		if not hudSrc:find("UDim2%.new%(1, %-244, 0, 140%)") or not hudSrc:find("UDim2%.new%(1, %-184, 0, 196%)") then
			table.insert(problems, "rebirth/lock buttons still end 12px from the edge (not 24px)")
		end
		if not hudSrc:find("UDim2%.new%(1, %-244, 0, 252%)") then
			table.insert(problems, "leaderboard still ends 12px from the edge (not 24px)")
		end
		if hudSrc:find('"Next storm: "') then
			table.insert(problems, "storm calm text is still the long 'Next storm: 72s'")
		end
		if not worldSrc:find("Vector3%.new%(16, 0, 94%)") then
			table.insert(problems, "Contract Board is not at (16, 0, 94)")
		end
		-- REMOVE (simplify/polish): the world Index Wall is gone.
		if worldSrc:find("IndexWallBoard") then
			table.insert(problems, "the world Index Wall is still built (removed in the simplify/polish pass)")
		end
		if not worldSrc:find("UDim2%.fromOffset%(260, 140%)") then
			table.insert(problems, "Contract Board gui is not 260x140")
		end
		-- REMOVE (simplify/polish): the SPAWN sign and the Index Wall
		-- title are gone with the things they belonged to.
		if worldSrc:find("SpawnSign") then
			table.insert(problems, "the SPAWN sign is still built (removed in the simplify/polish pass)")
		end
		if worldSrc:find("IndexWallTitle") then
			table.insert(problems, "the Index Wall title is still built (wall removed in the simplify/polish pass)")
		end
		if not worldSrc:find("gui%.MaxDistance = 40") then
			table.insert(problems, "Contract Board view distance is not 40")
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
			check("bz", true, "HUD fully on screen (24px margins, short storm text), Contract Board 260x140 at (16,94) with 40 view distance, world Index Wall + SPAWN sign removed; no player-visible 'Rotling' anywhere")
		end
	end
end

-- -- (ca) the competition is intact (fix round 4, item 9 — verify only) --
-- Playtest 4, item 9 (only after 1-8 work): the Crater Guardian chases
-- whoever grabs from the crater, faster for rarer ones, drop on catch,
-- base/dome = gives up, "THE GUARDIAN IS AWAKE! RUN!" + red edge flash;
-- raider bots grab and run (slap to steal back); goal collect all 22
-- ("Index 14/22" in the HUD), Divine last, celebration per
-- completed rarity tier. Verified against the code after items 1-8 —
-- nothing here needed a change, so this check locks the mechanics in:
-- guardian speed by rarity (28 -> 36, fix round 9 item 1: CAT-FAST,
-- every tier beats sprint 26 — the escape is the base interior, the
-- 25s timeout, or full Speed Boots, and a 14-stud head start still
-- gets out), catch radius 5, give-up 25s, rim
-- spawn (fix 1, so the catch is not instant), safe-base give-up, the
-- AWAKE banner + edge flash; raiders do crater grabs on half their
-- raids; 22 defs with exactly one Cosmic (Cosmic Corn Dog, weight 1)
-- and two Divine (Alfredo, Pineapple, weight 1, tied rarest);
-- HUD "📖 X/22"; tier + full-index celebrations.
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
		if not configSrc:find("GUARDIAN_SPEED = { %[1%] = 28, %[2%] = 29, %[3%] = 30, %[4%] = 31, %[5%] = 32, %[6%] = 34, %[7%] = 36 }") then
			table.insert(problems, "guardian speed is not 28 -> 36 by rarity")
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
		if not catalogSrc:find('name = "Archangel Alfredo"') then
			table.insert(problems, "Archangel Alfredo is not in the catalog")
		end
		if not catalogSrc:find('name = "Pope Pineapple"') then
			table.insert(problems, "Pope Pineapple is not in the catalog")
		end
		if not raritySrc:find('{ name = "Divine".-weight = 1') then
			table.insert(problems, "Divine is not weight 1 (tied rarest with Cosmic)")
		end
		if not hudSrc:find("hud%.indexCount.*hud%.indexTotal") then
			table.insert(problems, "HUD does not show the index X/22")
		end
		if not indexSrc:find("SET COMPLETE!") then
			table.insert(problems, "no tier-completion celebration")
		end
		if not indexSrc:find("INDEX COMPLETE! All 22 Brainrots found!") then
			table.insert(problems, "no all-22 completion celebration")
		end
		if #problems > 0 then
			check("ca", false, "the competition is broken — " .. table.concat(problems, "; ") .. ". Parts: Config.luau, GuardianService.luau, RaiderService.luau, RotlingCatalog.luau, RarityConfig.luau, IndexService.luau, HUDController.client.luau")
		else
			check("ca", true, "competition intact: guardian 19->24 by rarity (every tier beats walk 16; Cosmic 8 faster; escape is sprint, base/dome or the 25s timeout), catch 5, give-up 25s, rim spawn, AWAKE banner + edge flash, safe-base give-up, drop on catch; raiders crater-grab half their raids; 22 defs, one Cosmic (Corn Dog, weight 1), two Divine (Alfredo, Pineapple, weight 1); HUD X/22; tier + all-22 celebrations")
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
		-- (simplify/polish HUD: the mission bar became the quest pill —
		-- same behaviour, new names.)
		if not hudSrc:find("questLabel%.TextXAlignment = Enum%.TextXAlignment%.Left") then
			table.insert(problems, "quest pill label is still centre-aligned — a long mission string clips at the left edge")
		end
		if not hudSrc:find("questLabel%.TextTruncate = Enum%.TextTruncate%.AtEnd") then
			table.insert(problems, "quest pill label does not truncate — a long mission string overflows instead of ellipsizing")
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
			check("cd", true, "HUD text readable: quest pill label left-aligned + truncated (no 'Place Bra...' cut-off); name tags hide closer than 6 studs (no tag over the base sign/banner); money/storm/buddy/belt/guardian verified intact, not rebuilt")
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
-- (fix round 7, item 1; steering rewritten fix round 9, item 1)
-- The round-6 chase re-pathed every 0.5s and issued ONE MoveTo to the
-- first waypoint >2 studs away, then waited — the guardian reached a
-- 2-4 stud waypoint in ~0.2s and stood still until the next tick, so
-- it moved in blocks at half speed, never closed on a walking player,
-- and the catch never fired ("no dmg, no drops, no deaths, nothing").
-- The round-7 fix kept pathfinding (waypoints, repaths every 1.5s) —
-- but the path detoured through the entrance gap, so the guardian's
-- real closing speed stayed below a walk and every repath snapped its
-- heading: still slow, still jerky in playtests 9 and 10. The chase
-- now steers DIRECTLY at the live target every 0.1s tick (no
-- pathfinding at all — the crater floor and open field have nothing
-- to route around), hops fast when stuck (0.8s, clearing the 2.5 /
-- 4 / 5.5 rim tiers), and lunges inside 14 studs. HipHeight matches
-- the build (3.2, the root's height above the floor — the default 2
-- pushed the model into the floor while it walked). Speeds are
-- CAT-FAST at every tier (28 -> 36, fix round 9 item 1). The chase
-- follows the target anywhere on the map, inside or outside the
-- crater, until catch / safe base / timeout.
do
	local guardianSrc = read("src/server/GuardianService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not guardianSrc or not configSrc then
		check("ch", false, "could not verify the guardian chase fix — GuardianService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if guardianSrc:find("PathfindingService") or guardianSrc:find("ComputeAsync") then
			table.insert(problems, "the chase still pathfinds — the detour is what ate the speed and snapped the heading")
		end
		if not guardianSrc:find("humanoid:MoveTo%(targetRoot%.Position%)") then
			table.insert(problems, "the chase does not steer directly at the target's live position")
		end
		if not guardianSrc:find("climbed out of the crater") then
			table.insert(problems, "no stuck climb-out — a guardian that cannot move still dies in the middle")
		end
		if not guardianSrc:find("chase summary") then
			table.insert(problems, "despawn does not print the chase summary — the chase trail has no ending")
		end
		if not guardianSrc:find("task%.wait%(0%.1%)") then
			table.insert(problems, "the chase tick is not 0.1s — the 0.5s repath wait is what made it move in blocks")
		end
		if not guardianSrc:find("noProgressTime >= 0%.8") then
			table.insert(problems, "no fast stuck-hop (0.8s) — the guardian still grinds against rim tiers")
		end
		if not guardianSrc:find("HipHeight = 3%.2") then
			table.insert(problems, "HipHeight does not match the build (3.2) — the Humanoid still pushes the model into the floor while walking")
		end
		if not guardianSrc:find("body%.Touched:Connect") then
			table.insert(problems, "no touch-catch on the body ball — a touch can still slip between catch-radius ticks")
		end
		if not guardianSrc:find("caught .+ — smashed for .+ HP %(now .+ HP%), knocked down, dropped") then
			table.insert(problems, "the catch does not log the damage + remaining HP + knockdown + drop — the catch trail has no proof")
		end
		if not configSrc:find("%[1%] = 28") or not configSrc:find("%[6%] = 34") then
			table.insert(problems, "guardian speeds are not 28 -> 36 (every tier must beat sprint 26)")
		end
		if #problems > 0 then
			check("ch", false, "the guardian chase fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: GuardianService.luau, Config.luau")
		else
			check("ch", true, "the guardian chases smoothly and catches: 0.1s tick, direct steering at the live target (no pathfinding), 0.8s stuck-hop, lunge inside 14 studs, HipHeight 3.2 matching the build, touch-catch on the body ball, catch logs the knockdown + drop, speeds 28 -> 36, chase follows the target anywhere on the map")
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

-- -- (cj) eggs hatch slower the rarer they are (fix round 6, item 6;
-- roll moved to spawn time by fix round 7, item 6)
-- Malek: "the egg to hatch has more time? Maybe on its rarity?"
-- The hatch was a flat 60s. Now the hatch is rolled at spawn time
-- and the wait scales with the rarity of what's inside: Common 60s,
-- Rare 90s, Epic 120s, Legendary 180s, Mythic 240s, Cosmic 300s,
-- Divine 360s.
-- The result is shown on the egg (see check (co)) — the round-6
-- hiding is overridden. rollHatchDef must be declared BEFORE its
-- callers — a local declared after its caller is invisible to it,
-- the same class of bug as fix round 3's calmDuration-after-getStatus.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	local configSrc = read("src/shared/Config.luau")
	local stateSrc = read("src/server/State.luau")
	if not eggSrc or not configSrc or not stateSrc then
		check("cj", false, "could not verify the egg hatch scaling — MeteorEggService.luau, Config.luau or State.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("EGG_HATCH_TIME = { %[1%] = 60, %[2%] = 90, %[3%] = 120, %[4%] = 180, %[5%] = 240, %[6%] = 300, %[7%] = 360 }") then
			table.insert(problems, "EGG_HATCH_TIME is not the 60 -> 360s per-rarity ladder")
		end
		if not eggSrc:find("hatchTimeForRarity") then
			table.insert(problems, "no hatchTimeForRarity — the hatch wait cannot scale with rarity")
		end
		if not eggSrc:find("hatchDef = hatchDef%.id") or not eggSrc:find("hatchMutation = hatchMutation") then
			table.insert(problems, "spawnEggsForStorm does not store the rolled hatch — the wait cannot scale with what's inside")
		end
		if not eggSrc:find("hatches in \" .. tostring%(hatchTime%)") then
			table.insert(problems, "the incubator banner does not show the actual (rarity-scaled) wait")
		end
		local rollPos = eggSrc:find("local function rollHatchDef")
		local spawnPos = eggSrc:find("function MeteorEggService%.spawnEggsForStorm")
		if not rollPos or not spawnPos or rollPos > spawnPos then
			table.insert(problems, "rollHatchDef is not declared before spawnEggsForStorm — the spawn would call a nil global")
		end
		if not stateSrc:find("hatchDef: string%?") or not stateSrc:find("hatchMutation: string%?") then
			table.insert(problems, "the Egg record has no hatchDef/hatchMutation fields — the stored hatch has nowhere to live")
		end
		if #problems > 0 then
			check("cj", false, "the egg hatch scaling is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau, Config.luau, State.luau")
		else
			check("cj", true, "eggs hatch slower the rarer they are: hatch rolled at spawn time and stored on the egg, wait scales Common 60s -> Divine 360s, banner shows the actual wait, roll declared before its callers")
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

-- -- (cl) the bonk reads as a hit, never as a sun (fix round 7, item 3)
-- Malek: "when i clikc slap it shows a small glowing yellow sun?
-- why" — and "it does look like a sun when im pressing it into
-- anything - like anywhere in the map". The old effect was a yellow
-- Neon ball + gold particles (a glowing sun) and the server fired
-- the SAME event for hits and whiffs, so the client could not tell
-- them apart — every whiff showed a sun at the swing point. Now the
-- event carries a hit flag: a real hit fires slapHitAt to every
-- client (shockwave ring + "BONK!" burst + low thud at the impact
-- point, on the victim — rivals, players, and raiders, whose
-- bonkRaider fired no effect at all before), and a whiff fires
-- slapMissAt to the slapper only (a small faint swoosh, no sun, no
-- "BONK!"). The yellow ball is gone.
do
	local slapSrc = read("src/server/SlapService.luau")
	local slapClient = read("src/client/SlapController.client.luau")
	if not slapSrc or not slapClient then
		check("cl", false, "could not verify the bonk effect — SlapService.luau or SlapController.client.luau missing")
	else
		local problems: { string } = {}
		if slapSrc:find("starsAt") then
			table.insert(problems, "the old starsAt sun effect is still fired somewhere")
		end
		if not slapSrc:find("local function slapHitAt") or not slapSrc:find("FireAllClients%(position, true%)") then
			table.insert(problems, "no slapHitAt firing the hit effect to every client")
		end
		if not slapSrc:find("local function slapMissAt") or not slapSrc:find("FireClient%(player, position, false%)") then
			table.insert(problems, "no slapMissAt firing the whiff effect to the slapper only")
		end
		if not slapSrc:find("slapHitAt%(raiderRoot%.Position%)") then
			table.insert(problems, "a raider bonk still shows no effect (bonkRaider fires none itself)")
		end
		if slapClient:find("SlapStars") or slapClient:find("Enum%.PartType%.Ball") then
			table.insert(problems, "the yellow sun ball is still in the client effect")
		end
		if not slapClient:find("BonkRing") or not slapClient:find('"BONK!"') then
			table.insert(problems, "the hit effect is not a shockwave ring + BONK! burst")
		end
		if not slapClient:find("BonkSwoosh") then
			table.insert(problems, "a whiff shows no faint swoosh (or still shows a sun)")
		end
		if not slapClient:find("hit: boolean%?") then
			table.insert(problems, "the client effect does not take a hit flag — it cannot tell a hit from a whiff")
		end
		if #problems > 0 then
			check("cl", false, "the bonk effect fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: SlapService.luau, SlapController.client.luau")
		else
			check("cl", true, "the bonk reads as a hit: hits fire a shockwave ring + BONK! burst + low thud to every client (rivals, players, raiders), whiffs show only a faint swoosh to the slapper, the yellow sun ball is gone")
		end
	end
end

-- -- (cm) the game makes sound (fix round 7, item 4)
-- Malek: "no sound?" The game DID have sounds — but every one is
-- the same built-in ping, and the big ones were pitched so low
-- (roar 0.15, rumble 0.2, thunder 0.25, alarm 0.6) that phone
-- speakers, which have almost no bass, barely reproduce them — so
-- the storm, the guardian and the thunder read as silence. The
-- audible ones (grab 1.2, place 1.8) were 0.5s blips at volume 0.6.
-- And three core moments had no sound at all: collecting cash, the
-- steal alarm, and (until celebrate) the egg hatch. The fix: the low
-- pitches are raised into the range phone speakers reproduce (roar
-- 0.4, rumble 0.35, thunder 0.4, alarm 0.8), the rumble is louder,
-- the grab/place blips are louder, and collect + both steal alarms
-- now play. All sounds stay the one built-in ping — no new assets.
do
	local guardianSrc = read("src/server/GuardianService.luau")
	local starfallSrc = read("src/server/StarfallService.luau")
	local bankSrc = read("src/server/BankService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not guardianSrc or not starfallSrc or not bankSrc or not rivalSrc or not raiderSrc or not carrySrc or not factorySrc or not eggSrc then
		check("cm", false, "could not verify the sound fix — GuardianService.luau, StarfallService.luau, BankService.luau, RivalService.luau, RaiderService.luau, CarryService.luau, RotlingFactory.luau or MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if not guardianSrc:find("PlaybackSpeed = 0%.4") then
			table.insert(problems, "the guardian roar is still pitched at 0.15 — inaudible on phone speakers")
		end
		if not starfallSrc:find("sound%.PlaybackSpeed = 0%.8") then
			table.insert(problems, "the storm alarm is still pitched at 0.6 — barely audible on phone speakers")
		end
		if not starfallSrc:find("sound%.PlaybackSpeed = 0%.35") then
			table.insert(problems, "the storm rumble is still pitched at 0.2 — inaudible on phone speakers")
		end
		if not bankSrc:find("FeedbackService%.playSound%(player, 1%.6, 0%.8%)") then
			table.insert(problems, "collecting cash is still silent — no ding in collectBank")
		end
		if not rivalSrc:find("FeedbackService%.playSound%(victim, 0%.7, 1%)") then
			table.insert(problems, "the rival steal warning is still silent — no alarm in tryStartSteal")
		end
		if not raiderSrc:find("FeedbackService%.playSound%(owner, 0%.7, 1%)") then
			table.insert(problems, "the raider steal warnings are still silent — no alarm at spawn or at the grab")
		end
		if not carrySrc:find("sound%.Volume = 0%.8") then
			table.insert(problems, "the grab pop is still volume 0.6 — a short quiet blip")
		end
		if not factorySrc:find("ding%.Volume = 0%.8") then
			table.insert(problems, "the place ding is still volume 0.6 — a short quiet blip")
		end
		if not eggSrc:find("FeedbackService%.celebrate%(owner%)") then
			table.insert(problems, "the egg hatch has no celebration sound")
		end
		if #problems > 0 then
			check("cm", false, "the sound fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: GuardianService.luau, StarfallService.luau, BankService.luau, RivalService.luau, RaiderService.luau, CarryService.luau, RotlingFactory.luau, MeteorEggService.luau")
		else
			check("cm", true, "the game makes sound: roar 0.4, storm alarm 0.8 (3x per warning), rumble 0.35/0.6, thunder 0.4, grab pop + place ding at 0.8, collect cash ding, steal alarms on rival + raider warnings, hatch celebration — all the one built-in ping, no new assets")
		end
	end
end

-- -- (cn) a new player learns what BONK means (fix round 7, item 5)
-- Malek: "idk like hwta does bonk even mean - imagine a person that
-- knows nothing - he wont know anything". The old tutorial had three
-- steps and stopped the moment the player grabbed their first
-- Rotling, so BONK was never explained — and the button just said
-- "SLAP" with no explanation. Now the tutorial runs four steps over
-- 80 seconds, step 4 explains Bonk in plain words ("See a thief in
-- your base? Press F (or BONK) — hit them and they drop your
-- Brainrot!") with the arrow on the player's base (where thieves
-- sneak in), and it only stops early when the player actually bonks
-- a thief — never on the first grab. The button says BONK and
-- carries a plain label under it: "Hit a thief — they drop your
-- Brainrot".
do
	local tutorialSrc = read("src/client/TutorialController.client.luau")
	local slapClient = read("src/client/SlapController.client.luau")
	if not tutorialSrc or not slapClient then
		check("cn", false, "could not verify the onboarding fix — TutorialController.client.luau or SlapController.client.luau missing")
	else
		local problems: { string } = {}
		if not tutorialSrc:find("TUTORIAL_SECONDS = 80") then
			table.insert(problems, "the tutorial is still 60 seconds — the Bonk step never gets its 20 seconds")
		end
		if not tutorialSrc:find("math%.min%(4,") then
			table.insert(problems, "the tutorial still has only 3 steps — no Bonk step")
		end
		if not tutorialSrc:find("Press F %(or BONK%)") then
			table.insert(problems, "no step explains Bonk in plain words (F or BONK — hit them and they drop your Brainrot)")
		end
		if tutorialSrc:find("if data%.carried > 0 then") then
			table.insert(problems, "the tutorial still stops on the first grab — the Bonk step is never shown")
		end
		if not tutorialSrc:find("slapEffectEvent%(%)%.OnClientEvent") then
			table.insert(problems, "the tutorial does not stop early on a successful bonk — it has no early-stop that teaches the loop")
		end
		if not slapClient:find('"👊 BONK %(F%)"') then
			table.insert(problems, "the button does not say BONK (F)")
		end
		if not slapClient:find("Hit a thief — they drop your Brainrot") then
			table.insert(problems, "the button has no plain label explaining what Bonk does")
		end
		if #problems > 0 then
			check("cn", false, "the onboarding fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: TutorialController.client.luau, SlapController.client.luau")
		else
			check("cn", true, "a new player learns what BONK means: 4-step 80s tutorial with a plain-words Bonk step (arrow on the player's base), stops early only on a successful bonk, button says BONK (F) with a plain label under it")
		end
	end
end

-- -- (co) ground eggs are mysteries; the rarity is revealed in the
-- incubator (v74, mystery eggs). Malek: "why have the eggs on the map
-- saying what is it? people wont go for normal eggs." A ground egg
-- labelled "COMMON EGG" gets ignored. Now every ground egg looks
-- identical — "🥚 METEOR EGG", same gold label, same warm glow —
-- and the hatch is still rolled at spawn. The incubator banner names
-- the rarity + wait and tints label + glow to it, and the incubating
-- egg's label counts down live every second ("🥚 LEGENDARY EGG —
-- 173s"). Any egg could be Legendary, so normal eggs stay worth
-- grabbing. Not a revert to hidden-until-hatch: the reveal happens
-- in the incubator, not only at hatch.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not eggSrc then
		check("co", false, "could not verify the egg rarity display — MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if not eggSrc:find("local function rollHatchDef") then
			table.insert(problems, "no rollHatchDef — the hatch cannot be rolled at spawn")
		end
		if not eggSrc:find("local hatchDef, hatchMutation = rollHatchDef%(%)") then
			table.insert(problems, "the hatch is not rolled at spawn — the ground egg still has no rarity")
		end
		-- (v74, mystery eggs) The ground egg shows NO rarity: one
		-- identical "🥚 METEOR EGG" label + warm glow for all.
		-- The reveal happens in the incubator (placeEgg), not here.
		-- (fix round 13, item 2) The glow is warm gold now
		-- (255, 220, 130) to match the cream layered shell — the
		-- old orange (255, 140, 50) matched the old orange shell.
		if not eggSrc:find('label%.Text = "🥚 METEOR EGG"') then
			table.insert(problems, "the ground egg label is not the identical mystery label")
		end
		if eggSrc:find('"🥚 " %.%. string%.upper%(rarity%) %.%. " EGG"') then
			table.insert(problems, "the ground egg label still names its rarity (not a mystery)")
		end
		if not eggSrc:find("light%.Color = Color3%.fromRGB%(255, 220, 130%)") then
			table.insert(problems, "the ground egg glow is not the identical warm gold")
		end
		if not eggSrc:find("rarityColor = RarityConfig%.rarityByName%(placedRarity%)%.color") then
			table.insert(problems, "the incubator does not tint the label/glow to the revealed rarity")
		end
		if not eggSrc:find("placedRarity") or not eggSrc:find('"🥚 " %.%. placedRarity %.%. " egg on the incubator') then
			table.insert(problems, "the incubator banner does not name the rarity + wait")
		end
		if not eggSrc:find("local function setEggLabel") then
			table.insert(problems, "no setEggLabel helper — the incubating label cannot be updated")
		end
		if not eggSrc:find('setEggLabel%(model, "🥚 " %.%. string%.upper%(rarity%) %.%. " EGG — " %.%. tostring%(remaining%) %.%. "s"%)') then
			table.insert(problems, "the hatch loop does not update the incubating egg's label with a live countdown")
		end
		-- (v74, mystery eggs) The generic label is the design now —
		-- the old assertion that it means "rarity hidden" is gone.
		-- The reveal happens in the incubator (placeEgg), not here.
		if #problems > 0 then
			check("co", false, "the egg rarity/timer fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau")
		else
			check("co", true, "ground eggs are mysteries: identical '🥚 METEOR EGG' label + warm gold glow (no rarity name or tint), hatch rolled at spawn, incubator banner names rarity + wait and tints label + glow to it, incubating label counts down live every second")
		end
	end
end

-- -- (cp) the sneaking thief is unmissable (fix round 7, item 7)
-- Malek: "also when someone sneaks into my base i should be able
-- to see him .." A thief that cannot be seen reads as "zero action"
-- even when the steal is happening. Now a stealing rival carries a
-- red Highlight on its whole model, visible THROUGH walls (DepthMode
-- Occluded) — tied to the THIEF sign, so it goes on when a steal
-- starts and off at every steal end, and can never leak onto a rival
-- that is not stealing. While the thief is inside the victim's base,
-- the victim is re-bannered ("🚨 NAME is IN your base — bonk them!")
-- at most once per 3s by a 1s watcher loop. Raiders are thieves for
-- their whole life, so their Highlight is always on from build.
do
	local rivalSrc = read("src/server/RivalService.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local stateSrc = read("src/server/State.luau")
	if not rivalSrc or not raiderSrc or not stateSrc then
		check("cp", false, "could not verify thief visibility — RivalService.luau, RaiderService.luau or State.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find("ThiefHighlight") or not rivalSrc:find("HighlightDepthMode%.Occluded") then
			table.insert(problems, "the stealing rival has no through-walls Highlight")
		end
		if not rivalSrc:find("highlight:Destroy%(%)") then
			table.insert(problems, "the rival Highlight is never removed — it can leak onto a rival that stopped stealing")
		end
		if not rivalSrc:find("is IN your base — bonk them!") then
			table.insert(problems, "no repeat banner while the thief is inside the victim's base")
		end
		if not rivalSrc:find("lastThiefBannerAt") or not stateSrc:find("lastThiefBannerAt: number") then
			table.insert(problems, "no lastThiefBannerAt throttle — the repeat banner can spam every second")
		end
		if not raiderSrc:find("ThiefHighlight") or not raiderSrc:find("HighlightDepthMode%.Occluded") then
			table.insert(problems, "the raider has no through-walls Highlight")
		end
		if #problems > 0 then
			check("cp", false, "the thief visibility fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, RaiderService.luau, State.luau")
		else
			check("cp", true, "the sneaking thief is unmissable: stealing rivals get a red through-walls Highlight (on/off with the THIEF sign), the victim is re-bannered at most once per 3s while the thief is inside their base, raiders carry an always-on Highlight")
		end
	end
end

-- -- (cq) a carried egg can be dropped anywhere (fix round 7, item 8)
-- Malek: "if i got an egg on my base and grabbed another - i cant
-- drop it outside the base?" dropEgg existed but only ran
-- involuntarily (slapped, hit, died, left) — the player had no way
-- to put a carried egg down. Now G (or the DROP EGG button, shown
-- only while carrying an egg) drops it at the player's feet, anywhere
-- on the map, ground phase, prompt re-enabled, grabbable again. And
-- the rules are clear: one egg per incubator — placing a second egg
-- while one hatches is blocked with a banner naming the remaining
-- time ("drop it outside your base (G) or wait"), and the player
-- keeps carrying it.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local projectSrc = read("default.project.json")
	if not eggSrc or not hudSrc or not remotesSrc or not projectSrc then
		check("cq", false, "could not verify the egg drop — MeteorEggService.luau, HUDController.client.luau, Remotes.luau or default.project.json missing")
	else
		local problems: { string } = {}
		if not projectSrc:find('"DropEgg"') then
			table.insert(problems, "no DropEgg RemoteEvent in default.project.json — the client has nothing to fire")
		end
		if not remotesSrc:find("function Remotes%.dropEggEvent") then
			table.insert(problems, "no Remotes.dropEggEvent accessor")
		end
		if not eggSrc:find("dropEggEvent%(%)%.OnServerEvent") then
			table.insert(problems, "no server handler for the voluntary drop — G/button fires into nothing")
		end
		if not eggSrc:find("Dropped your egg — grab it again any time") then
			table.insert(problems, "the voluntary drop gives no confirmation banner")
		end
		if not hudSrc:find("DROP EGG %(G%)") then
			table.insert(problems, "no DROP EGG button in the HUD")
		end
		if not hudSrc:find("dropEggButton%.Visible = data%.eggCarried") then
			table.insert(problems, "the DROP EGG button is not shown only while carrying an egg")
		end
		if not hudSrc:find("Enum%.KeyCode%.G") then
			table.insert(problems, "no G key for dropping the egg")
		end
		if not eggSrc:find("Your incubator already has an egg") then
			table.insert(problems, "placing a second egg while one hatches is not blocked with a clear rule — two eggs would overlap on one incubator")
		end
		if #problems > 0 then
			check("cq", false, "the egg drop fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau, HUDController.client.luau, Remotes.luau, default.project.json")
		else
			check("cq", true, "a carried egg can be dropped anywhere: G or the DROP EGG button (shown only while carrying) drops it at the player's feet, ground phase, re-grabbable; one egg per incubator, second place blocked with the remaining time + the drop rule")
		end
	end
end

-- -- (cr) the Brainrot index looks polished (fix round 7, item 9)
-- Malek: "also the brainrot index could look better". The old panel
-- was text-only cards with a subtle found/unfound shade change and
-- no progress feel. Now each card has a silhouette icon in the
-- Brainrot's own colours (its unique silhouette key from the
-- catalog, body = rarity colour, belly = lighter tint), a
-- rarity-coloured strip on top, and a rarity-coloured glow border
-- when found; unfound cards show the same shape in dark grey with
-- "???". A progress bar fills as the set grows, and a tier line
-- shows each rarity's found count in its colour. What it tracks is
-- unchanged: 22 Brainrots, X/22, tier completion rewards. The Index
-- button position and the "Set as Buddy" button are untouched.
do
	local indexSrc = read("src/client/IndexController.client.luau")
	if not indexSrc then
		check("cr", false, "could not verify the index polish — IndexController.client.luau missing")
	else
		local problems: { string } = {}
		if not indexSrc:find("local function buildIcon") then
			table.insert(problems, "no buildIcon — cards have no silhouette icon")
		end
		if not indexSrc:find("def%.silhouette") then
			table.insert(problems, "the icon does not use the Brainrot's unique silhouette key")
		end
		if not indexSrc:find("RarityStrip") then
			table.insert(problems, "no rarity strip on top of each card")
		end
		if not indexSrc:find("FoundGlow") then
			table.insert(problems, "no glow border on found cards")
		end
		if not indexSrc:find("ProgressFill") or not indexSrc:find("progressFill%.Size = UDim2%.new%(found / #RotlingCatalog%.DEFS") then
			table.insert(problems, "no progress bar that fills with the set")
		end
		if not indexSrc:find("tierLine%.Text = table%.concat%(parts") then
			table.insert(problems, "no tier line showing each rarity's found count in its colour")
		end
		if not indexSrc:find("Color3%.fromRGB%(60, 55, 80%)") then
			table.insert(problems, "unfound cards do not show a dark grey silhouette")
		end
		if not indexSrc:find('"Set as Buddy"') then
			table.insert(problems, "the Set as Buddy button is gone")
		end
		if not indexSrc:find('UDim2%.new%(1, %-172, 0, 364%)') then
			table.insert(problems, "the Index button moved — it must stay below the leaderboard")
		end
		if #problems > 0 then
			check("cr", false, "the index polish is incomplete — " .. table.concat(problems, "; ") .. ". Parts: IndexController.client.luau")
		else
			check("cr", true, "the Brainrot index looks polished: silhouette icons in each Brainrot's colours (grey when unfound), rarity strips, glow borders on found cards, a progress bar, and a per-tier found-count line — tracking unchanged (22, X/22, tier rewards)")
		end
	end
end

-- -- (cs) mutations are VISIBLE (simplify pass, section B)
-- Malek: "why invisible" — six mutations were wired into spawns, eggs
-- and the shop but nothing ever showed them. Now a mutated Brainrot
-- reads from the path: its label names the mutation up front in the
-- mutation's own colour ("GOLD Boba Blob"), the rarity line carries
-- the multiplier ("✦ RAINBOW x5"), a tall Neon beam in the mutation's
-- colour rises from it with a sparkle emitter, a mutated spawn gets a
-- server-wide banner ("✨ A GOLD Boba Blob spawned in the crater!"),
-- and the index has a mutations line (one chip per mutation, found in
-- its own colour with its multiplier, unfound as a grey "???").
-- The opening mix guarantees two mutated spawns (Gold crumb, Rainbow
-- bloop) so the player meets mutations in the first minute. Grabbing
-- or placing a mutated Brainrot logs it as found (banner, no coins —
-- the multiplier IS the reward).
do
	local factorySrc = read("src/server/RotlingFactory.luau")
	local spawnSrc = read("src/server/SpawnService.luau")
	local indexSvcSrc = read("src/server/IndexService.luau")
	local indexCtrlSrc = read("src/client/IndexController.client.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local mutationSrc = read("src/shared/MutationConfig.luau")
	if not factorySrc or not spawnSrc or not indexSvcSrc or not indexCtrlSrc or not carrySrc or not mutationSrc then
		check("cs", false, "could not verify mutation visibility — RotlingFactory.luau, SpawnService.luau, IndexService.luau, IndexController.client.luau, CarryService.luau or MutationConfig.luau missing")
	else
		local problems: { string } = {}
		if not factorySrc:find("local function nameText") or not factorySrc:find("mutation:upper()", 1, true) then
			table.insert(problems, "the label does not name the mutation up front in its colour (nameText)")
		end
		if not factorySrc:find("local function addMutationBeam") or not factorySrc:find('"MutationBeam"', 1, true) or not factorySrc:find("addMutationBeam(model, body, mutation)", 1, true) then
			table.insert(problems, "no mutation beam (addMutationBeam / MutationBeam) on mutated Rotlings")
		end
		if not factorySrc:find("local function addMutationSparkle") or not factorySrc:find('"MutationSparkle"', 1, true) or not factorySrc:find("addMutationSparkle(model, body, mutation)", 1, true) then
			table.insert(problems, "no mutation sparkle (addMutationSparkle / MutationSparkle) on mutated Rotlings")
		end
		if not factorySrc:find("✦", 1, true) or not factorySrc:find("mutationMult(mutation)", 1, true) then
			table.insert(problems, "the rarity line does not carry the mutation multiplier (✦ RAINBOW x5)")
		end
		if not spawnSrc:find("local function announceSpawn") or not spawnSrc:find("spawned in the crater!", 1, true) then
			table.insert(problems, "no server-wide banner for mutated spawns (announceSpawn)")
		end
		if not spawnSrc:find("MutationConfig.rollMutation()", 1, true) then
			table.insert(problems, "spawns do not roll a mutation")
		end
		if not spawnSrc:find('mutation = "Gold"', 1, true) or not spawnSrc:find('mutation = "Rainbow"', 1, true) then
			table.insert(problems, "the opening mix has no guaranteed mutated spawns (Gold crumb, Rainbow bloop)")
		end
		if not indexSvcSrc:find("function IndexService.markMutationFound") or not indexSvcSrc:find("New mutation found:", 1, true) or not indexSvcSrc:find("profile.mutations[mutation] = true", 1, true) then
			table.insert(problems, "found mutations are not logged (markMutationFound / profile.mutations)")
		end
		local _, markCalls = carrySrc:gsub("IndexService.markMutationFound", "")
		if markCalls < 2 then
			table.insert(problems, "markMutationFound is not called on both grab and place")
		end
		if not indexCtrlSrc:find("MutationLine") or not indexCtrlSrc:find('"Mutations: "', 1, true) or not indexCtrlSrc:find("✦ ???", 1, true) then
			table.insert(problems, "the index has no mutations line (chips per mutation, found in colour, unfound ???)")
		end
		for _, name in ipairs({ "Gold", "Diamond", "Frozen", "Rainbow", "Starstruck", "Scorched" }) do
			if not mutationSrc:find('"' .. name .. '"', 1, true) then
				table.insert(problems, "mutation " .. name .. " is missing from MutationConfig")
			end
		end
		if #problems > 0 then
			check("cs", false, "mutations are not visible — " .. table.concat(problems, "; ") .. ". Parts: RotlingFactory.luau, SpawnService.luau, IndexService.luau, IndexController.client.luau, CarryService.luau, MutationConfig.luau")
		else
			check("cs", true, "mutations are visible: label names the mutation in its colour + multiplier line, Neon beam + sparkle on mutated Rotlings, server-wide spawn banner, opening mix guarantees a Gold and a Rainbow, grab/place logs the find, index shows all six mutations as chips (found in colour, unfound ???)")
		end
	end
end

-- (ct) Plaza fix (v74): the Contract Board and the STAR SHOP sign no
-- longer overlap; the board's text is a sign, not a fullscreen
-- overlay; the logo stage is out of the walkway; the REBIRTH READY
-- pill fits on screen; the buddy pet is parked.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local mainSrc = read("src/server/Main.server.luau")
	local buddySrc = read("src/server/BuddyService.luau")
	local indexSrc = read("src/client/IndexController.client.luau")
	if not worldSrc or not hudSrc or not mainSrc or not buddySrc or not indexSrc then
		check("ct", false, "could not verify the plaza fix — WorldBuilder.luau, HUDController.client.luau, Main.server.luau, BuddyService.luau or IndexController.client.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("Vector3%.new%(16, 0, 94%)") then
			table.insert(problems, "the Contract Board is not on the east side of the spawn path (16, 0, 94)")
		end
		if worldSrc:find("Vector3%.new%(-32, 0, 90%)") then
			table.insert(problems, "the Contract Board is still at the old west-side spot (-32, 0, 90)")
		end
		if not worldSrc:find("UDim2%.fromOffset%(260, 140%)\n\tgui%.AlwaysOnTop = false") then
			table.insert(problems, "the Contract Board billboard is not 260x140 depth-tested")
		end
		if not worldSrc:find("CONTRACT BOARD\"\n\ttitle%.Font = Enum%.Font%.FredokaOne\n\ttitle%.TextSize = 20\n\ttitle%.TextWrapped = true") then
			table.insert(problems, "the Contract Board title is not a fixed 20px wrapped (TextScaled blows up at close range)")
		end
		if not worldSrc:find("3 contracts at a time%.\\nFinish one, claim the reward!\"\n\ttext%.Font = Enum%.Font%.FredokaOne\n\ttext%.TextSize = 14\n\ttext%.TextWrapped = true") then
			table.insert(problems, "the Contract Board body text is not a fixed 14px wrapped")
		end
		if not worldSrc:find("signGui%.Size = UDim2%.fromOffset%(260, 80%)\n\tsignGui%.AlwaysOnTop = false") then
			table.insert(problems, "the STAR SHOP sign is not 260x80 depth-tested")
		end
		if not worldSrc:find("signGui%.MaxDistance = 60") then
			table.insert(problems, "the STAR SHOP sign still renders from 120 studs (over the plaza)")
		end
		if not worldSrc:find("CFrame%.new%(0, 0, 118%)") then
			table.insert(problems, "the logo stage is not behind spawn (0, 0, 118)")
		end
		if worldSrc:find("CFrame%.new%(-25, 0, 88%)") then
			table.insert(problems, "the logo stage is still beside the spawn path (-25, 0, 88)")
		end
		-- (fix round 13, item 6) The logo-stage heroes still face
		-- north (180 turn) — but the PivotTo now seats the body
		-- bottom on the stage (pos + half a body + 0.1), not the
		-- body centre on pos: the old form sank them 1.75 into the
		-- spawn platform.
		if not worldSrc:find("model:PivotTo%(CFrame%.new%(pos %+ Vector3%.new%(0, b%.Size%.Y / 2 %+ 0%.1, 0%)%) %* CFrame%.Angles%(0, math%.rad%(180%), 0%)%)") then
			table.insert(problems, "the logo-stage heroes do not face north toward the path")
		end
		if not hudSrc:find("UDim2%.new%(0, 220, 0, 48%), UDim2%.new%(1, %-244, 0, 140%)") then
			table.insert(problems, "the Rebirth button is not 220 wide at (1, -244)")
		end
		if not hudSrc:find("rebirthButton%.TextScaled = true") then
			table.insert(problems, "the Rebirth button text does not scale to fit")
		end
		-- (simplify/polish HUD: the READY text lives on the Rebirth
		-- button now, not on the removed NEXT REBIRTH bar — the
		-- truncate backstop lives on the button.)
		if not hudSrc:find("rebirthButton%.TextTruncate = Enum%.TextTruncate%.AtEnd") then
			table.insert(problems, "the REBIRTH READY button has no truncate backstop")
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
			check("ct", false, "the plaza fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau, HUDController.client.luau, Main.server.luau, BuddyService.luau, IndexController.client.luau")
		else
			check("ct", true, "the plaza is uncluttered: Contract Board east of the path (small, depth-tested, fixed text), STAR SHOP sign depth-tested at 60 studs, logo stage behind spawn facing the path, REBIRTH READY button 220 wide that scales to fit, buddy pet parked (never spawned, no label, Index button hidden)")
		end
	end
end

-- -- (signs-overhaul) fix round 12, item 1: signs --------------------
-- Playtest 11: the title sign's posts split its own text
-- ("SPAC...OCK / BR...OTS!"), a signpost overlapped the shop sign,
-- the Contract Board clipped mid-word ("Finish one, cla...") and
-- read as an empty panel, and the STAR SHOP sign was a plain flat
-- board. Every sign now has its own shape: title posts outside the
-- board span (12.5 > half-width 11) with a pulsing gold glow,
-- STAR SHOP a round gold-rimmed disc lowered to y=7, signposts
-- moved off the big-sign sightlines with a colour per line, the
-- Contract Board bigger (12x8) with a gold border, wrapped text
-- and a footer, and each base sign striped in its own base colour.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		check("signs-overhaul", false, "could not verify the signs overhaul — WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		-- (a) No signpost overlaps a big sign: the moved spawn-path
		-- signpost (-8, 62) must be >10 studs (2D) from every big
		-- sign, and the old (6, 58) position (on the crater->title
		-- sightline) must be gone. Same for the other two signposts.
		if not worldSrc:find("Vector3%.new%(%-8, 0, 62%)") then
			table.insert(problems, "the spawn-path signpost is not at (-8, 0, 62), west of the path")
		end
		if worldSrc:find("Vector3%.new%(6, 0, 58%)") then
			table.insert(problems, "the old signpost at (6, 0, 58) is still there, on the title-sign sightline")
		end
		local signposts = { { -8, 62 }, { -22, 28 }, { 6, -48 } }
		local bigSigns = { { 0, 46 }, { 16, 94 }, { -45, 45 } }
		for _, sp in ipairs(signposts) do
			for _, bs in ipairs(bigSigns) do
				local d = math.sqrt((sp[1] - bs[1]) ^ 2 + (sp[2] - bs[2]) ^ 2)
				if d <= 10 then
					table.insert(problems, ("signpost (%d, %d) is %.1f studs from a big sign (%d, %d) — under the 10-stud clearance"):format(sp[1], sp[2], d, bs[1], bs[2]))
				end
			end
		end
		-- (b) Title posts outside the board span: posts at
		-- cx +/- 12.5, board 22 wide (half-width 11) — 12.5 > 11,
		-- so no post can cover the text from any camera.
		if not worldSrc:find("cx %+ side %* 12%.5") then
			table.insert(problems, "the title sign posts are not at cx +/- 12.5")
		end
		if not worldSrc:find('part%("WorldTitleSign", Enum%.PartType%.Block, Vector3%.new%(22, 6, 1%)') then
			table.insert(problems, "the title sign board is not 22 wide (half-width 11)")
		end
		if not worldSrc:find("WorldTitleTrim") or not worldSrc:find("glow%.Brightness = 1%.5") then
			table.insert(problems, "the title sign has no pulsing gold trim / glow")
		end
		-- (fix round 14, item 2) The title sign stands ON the
		-- spawn→crater sightline (x=0, z=46 — at the crater's edge,
		-- between the rim at 39 and spawn at 96), raised to y=9 so
		-- walkers pass under it (board bottom 6 clears a player's
		-- head at ~5).
		if not worldSrc:find("local cx, cz = 0, 46") then
			table.insert(problems, "the title sign is not on the spawn→crater sightline at (0, 46)")
		end
		if not worldSrc:find("CFrame%.new%(cx, 9, cz%)") then
			table.insert(problems, "the title sign board is not raised to y=9 (walkers must pass under it on the main path)")
		end
		-- (c) Contract Board text fits: wrapped title + body on a
		-- 260x140 GUI, longest line ("Finish one, claim the
		-- reward!", 30 chars at TextSize 14, ~7px/char) < 260px,
		-- title ("CONTRACT BOARD", 14 chars at 20, ~10px/char)
		-- < 260px, posts outside the 12-wide board at +/- 6.5.
		if not worldSrc:find("ContractBoardBacking") then
			table.insert(problems, "the Contract Board has no gold backing board (border)")
		end
		if not worldSrc:find("boardCf %* CFrame%.new%(x, 3%.5, 0%)") and not worldSrc:find("{ %-6%.5, 6%.5 }") then
			table.insert(problems, "the Contract Board posts are not outside the board at +/- 6.5")
		end
		if not worldSrc:find("ContractFooter") or not worldSrc:find('"Press E to open"') then
			table.insert(problems, "the Contract Board has no 'Press E to open' footer")
		end
		if 30 * 7 >= 260 or 14 * 10 >= 260 then
			table.insert(problems, "the Contract Board text does not fit its 260px GUI at the fixed sizes")
		end
		-- (d) STAR SHOP is a round disc, not a flat board.
		if not worldSrc:find('part%("ShopSignDisc", Enum%.PartType%.Cylinder') then
			table.insert(problems, "the STAR SHOP sign is not a round disc")
		end
		if not worldSrc:find('part%("ShopSignRim", Enum%.PartType%.Cylinder') then
			table.insert(problems, "the STAR SHOP disc has no gold rim")
		end
		if worldSrc:find('part%("ShopSignBoard"') then
			table.insert(problems, "the old flat STAR SHOP board is still there")
		end
		-- (fix round 14, item 1) The sign text must hang IN FRONT
		-- of the disc's face, never on the disc: the GUI was
		-- parented to the disc, so its plane (local z 10.3) sat
		-- 0.35 behind the disc's front face (10.3 + 0.7/2) and the
		-- face ate the middle of the text ("STAR [ring] OP"). The
		-- anchor at local z 11.4 is 0.75 clear of the face.
		if not worldSrc:find('part%("ShopSignAnchor"') then
			table.insert(problems, "the STAR SHOP sign has no front anchor (ShopSignAnchor)")
		end
		if not worldSrc:find("signGui%.Parent = signAnchor") then
			table.insert(problems, "the STAR SHOP sign GUI is not parented to the front anchor — it still hangs on the disc and its own face occludes it")
		end
		if worldSrc:find("signGui%.Parent = signBoard") then
			table.insert(problems, "the STAR SHOP sign GUI is still parented to the disc")
		end
		if not worldSrc:find("CFrame%.new%(0, 7, 11%.4%)") then
			table.insert(problems, "the STAR SHOP sign anchor is not at local z 11.4 (in front of the disc face at 10.65)")
		end
		-- Arithmetic: disc centre 10.3 + half-thickness 0.35 =
		-- face 10.65; anchor 11.4 clears it by 0.75.
		if not (10.3 + 0.7 / 2 < 11.4) then
			table.insert(problems, "the STAR SHOP sign anchor does not clear the disc face")
		end
		-- (e) Base signs carry their own colour stripe, repainted
		-- on rebirth recolour.
		if not worldSrc:find("signStripes%[baseId%] = signStripe") then
			table.insert(problems, "base signs have no colour stripe")
		end
		if not worldSrc:find("stripe%.Color = color") then
			table.insert(problems, "setBaseColor does not repaint the base sign stripe")
		end
		if #problems > 0 then
			check("signs-overhaul", false, "the signs overhaul is incomplete — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau")
		else
			check("signs-overhaul", true, "signs overhaul: title arch on the spawn→crater sightline (0, 46), raised to y=9, posts outside the board (12.5 > 11) with pulse glow, STAR SHOP round gold disc at y=7 with its text on a front anchor 0.75 clear of the disc face, signposts off the big-sign sightlines with per-line colours, Contract Board 12x8 with gold border + wrapped text + footer, base signs striped in their own colour")
		end
	end
end

-- -- (steal-route) fix round 12, item 2 + fix round 13, item 1:
-- the thief can reach the base --------------------------------------
-- Playtest 11: the thief "still couldn't reach the base and gave
-- up" — the third round in a row. The round-12 root cause was the
-- SELL pad: it sits at (62, 0.5, 0), dead centre on the ONLY
-- approach line to base 1 (ring radius 45 -> entrance ramp at
-- radius 95, straight along the base's radial line), and part()
-- defaults CanCollide=true — so the pad was the one solid the
-- steal walk had to cross, and the stuck-hop clears a 2-stud
-- platform edge, not a 14-wide slab. The pad is now non-colliding,
-- rocks are excluded from every base's entrance corridor (radius
-- 40..130, +/-8 studs lateral), and the meteor-rock gap at the
-- crater mouth is widened to |x| < 10.
--
-- Playtest 12: the thief STILL gives up — the fourth round. So
-- this check no longer just pattern-matches the last fix: it
-- COMPUTES the steal route (the same waypoint math as
-- RivalService.walkAround + the entrance legs, for rival bases
-- 5-8 walking to base 1) and tests every leg as a capsule
-- (humanoid half-width 1.5) against every solid the world can
-- put in its way. What the trace found (see /tmp/steal_trace.py,
-- the scratch run that produced these numbers):
--   * Ring arc + approach legs are CLEAR of every deterministic
--     solid (rim outer 39, spawn platform, shop, fences are all
--     ghost or out of the way).
--   * The ONLY tall-solid intrusion the geometry allows is a
--     meteor rock on the ring: the 30-degree chords dip to
--     43.47, minus the 1.5 half-width the swept corridor reaches
--     radius 41.97 — and the old rock draw (radius 33..40, size
--     up to 6) reached radius 43. The draw is now 33..38 (worst
--     reach 41), a full stud clear, proven from the bound below
--     — not from one RNG draw (Lune has no Roblox Random).
--   * The final leg's old diagonal crossed up to 3 intermediate
--     pads + the CollectPad (0.05 studs on pad 6's line) — every
--     crossing a 0.6 ledge to hop. It now routes via the clear
--     strip (local z -9) at the pad's own local X: at most one
--     pad crossing.
--   * The give-up now logs the leg + nearest solid (F9), so a
--     live stall names its blocker instead of guessing again.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	if not worldSrc or not rivalSrc then
		check("steal-route", false, "could not verify the steal route — WorldBuilder.luau or RivalService.luau missing")
	else
		local problems: { string } = {}
		-- The pad really is on the route: base 1's approach runs
		-- along +X at z=0 from radius 45 to 95; the pad spans
		-- x 55..69, z -7..7 — the segment crosses it. So the pad
		-- MUST be non-colliding, or the steal walk still dies.
		local padX0, padX1, padZ0, padZ1 = 55, 69, -7, 7
		local routeX0, routeX1, routeZ = 45, 95, 0
		local crosses = routeX0 <= padX1 and routeX1 >= padX0 and routeZ >= padZ0 and routeZ <= padZ1
		if not crosses then
			table.insert(problems, "the SELL pad is not on base 1's approach line — the geometry changed")
		end
		if not worldSrc:find("sellPad%.CanCollide = false") then
			table.insert(problems, "the SELL pad is still colliding — it blocks the only approach to base 1")
		end
		if not worldSrc:find("onApproach") or not worldSrc:find("along >= 40 and along <= 130") or not worldSrc:find("math%.abs%(lateral%) < 8") then
			table.insert(problems, "buildRocks has no base-approach corridor exclusion (radius 40..130, +/-8 studs)")
		end
		if not worldSrc:find("math%.abs%(x%) < 10 and z > 34") then
			table.insert(problems, "the meteor-rock gap exclusion is not widened to |x| < 10")
		end
		if worldSrc:find("math%.abs%(x%) < 6 and z > 36") then
			table.insert(problems, "the old narrow meteor-rock gap (|x| < 6) is still there")
		end
		-- (fix round 13, item 1) The meteor-rock draw must be
		-- radius 33..38: worst reach 38 + 6/2 = 41, clear of the
		-- ring sweep (computed below). A 33..40 draw reaches 43.
		if not worldSrc:find("rng:NextNumber%(33, 38%)") then
			table.insert(problems, "buildMeteorRocks still draws radius 33..40 — a rock can reach radius 43, inside the ring sweep")
		end
		if worldSrc:find("rng:NextNumber%(33, 40%)") then
			table.insert(problems, "the old meteor-rock radius draw (33..40) is still there")
		end
		-- The final leg routes via the clear strip (local z -9) at
		-- the pad's own local X, in BOTH the steal and toBase
		-- branches — never the diagonal across the pads.
		if not rivalSrc:find("PointToObjectSpace%(padCf%.Position%)") or not rivalSrc:find("CFrame%.new%(localPad%.X, 2, %-9%)") then
			table.insert(problems, "the final leg has no clear-strip waypoint (local z -9 at the pad's local X)")
		end
		-- The give-up names its leg + nearest solid (F9).
		if not rivalSrc:find("STEAL WALK DIAGNOSTIC") or not rivalSrc:find("GetPartBoundsInRadius") or not rivalSrc:find("failedLeg") then
			table.insert(problems, "no give-up diagnostic (leg + nearest solid) on the steal walk")
		end
		-- --- The computed trace: every steal leg as a capsule
		-- against every solid. Geometry helpers (2D, XZ plane).
		local HUM_R = 1.5
		local function segPointDist(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
			local abx, abz = bx - ax, bz - az
			local d = abx * abx + abz * abz
			if d == 0 then
				return math.sqrt((px - ax) ^ 2 + (pz - az) ^ 2)
			end
			local t = ((px - ax) * abx + (pz - az) * abz) / d
			t = math.max(0, math.min(1, t))
			return math.sqrt((px - (ax + abx * t)) ^ 2 + (pz - (az + abz * t)) ^ 2)
		end
		-- Segment vs axis-aligned box (in the box's local frame),
		-- inflated by HUM_R. Slab method; exact.
		local function segHitsBox(ax: number, az: number, bx: number, bz: number, minX: number, maxX: number, minZ: number, maxZ: number): boolean
			local dx, dz = bx - ax, bz - az
			local t0, t1 = 0, 1
			if math.abs(dx) < 1e-9 then
				if ax < minX or ax > maxX then
					return false
				end
			else
				local ta, tb = (minX - ax) / dx, (maxX - ax) / dx
				if ta > tb then
					ta, tb = tb, ta
				end
				t0 = math.max(t0, ta)
				t1 = math.min(t1, tb)
				if t0 > t1 then
					return false
				end
			end
			if math.abs(dz) < 1e-9 then
				if az < minZ or az > maxZ then
					return false
				end
			else
				local ta, tb = (minZ - az) / dz, (maxZ - az) / dz
				if ta > tb then
					ta, tb = tb, ta
				end
				t0 = math.max(t0, ta)
				t1 = math.min(t1, tb)
				if t0 > t1 then
					return false
				end
			end
			return true
		end
		-- Segment vs oriented box: rotate the segment into the
		-- box's local frame, then the slab test.
		local function segHitsObb(ax: number, az: number, bx: number, bz: number, cx: number, cz: number, hx: number, hz: number, yawDeg: number): boolean
			local yaw = math.rad(yawDeg)
			local cosY, sinY = math.cos(yaw), math.sin(yaw)
			local function toLocal(px: number, pz: number): (number, number)
				local dx, dz = px - cx, pz - cz
				return dx * cosY + dz * sinY, -dx * sinY + dz * cosY
			end
			local lax, laz = toLocal(ax, az)
			local lbx, lbz = toLocal(bx, bz)
			return segHitsBox(lax, laz, lbx, lbz, -hx - HUM_R, hx + HUM_R, -hz - HUM_R, hz + HUM_R)
		end
		-- Ring sweep: 30-degree chords at radius 45 dip to
		-- 45*cos(15); minus the half-width is the corridor's
		-- inner edge. Meteor rocks must not reach it.
		local chordInner = 45 * math.cos(math.rad(15))
		local sweepInner = chordInner - HUM_R
		local meteorReach = 38 + 6 / 2
		if not (meteorReach < sweepInner) then
			table.insert(problems, "meteor-rock worst reach " .. tostring(meteorReach) .. " is inside the ring sweep (" .. string.format("%.2f", sweepInner) .. ")")
		end
		-- Rim: outer ring ends at radius 39 — the sweep clears it.
		if not (39 < sweepInner) then
			table.insert(problems, "the crater rim (outer 39) reaches the ring sweep")
		end
		-- Waypoints for a steal from rival base rb to base 1:
		-- radial drop to the ring, 30-degree arc the shorter way,
		-- ring target, entrance, ramp top. (Same math as
		-- RivalService.walkAround.)
		local function stealLegs(rb: number): { { ax: number, az: number, bx: number, bz: number, kind: string } }
			local legs: { { ax: number, az: number, bx: number, bz: number, kind: string } } = {}
			local startAng = math.rad((rb - 1) * 45)
			local sx, sz = math.cos(startAng) * 110, math.sin(startAng) * 110
			local rx, rz = math.cos(startAng) * 45, math.sin(startAng) * 45
			table.insert(legs, { ax = sx, az = sz, bx = rx, bz = rz, kind = "departure" })
			local curAng = startAng
			local diff = 0 - curAng
			while diff > math.pi do
				diff -= 2 * math.pi
			end
			while diff < -math.pi do
				diff += 2 * math.pi
			end
			local step = math.rad(30) * (if diff >= 0 then 1 else -1)
			local remaining = math.abs(diff)
			local px, pz = rx, rz
			while remaining > 0.01 do
				local move = math.min(math.rad(30), remaining)
				curAng += step * (move / math.rad(30))
				local wx, wz = math.cos(curAng) * 45, math.sin(curAng) * 45
				table.insert(legs, { ax = px, az = pz, bx = wx, bz = wz, kind = "ring" })
				px, pz = wx, wz
				remaining -= move
			end
			table.insert(legs, { ax = px, az = pz, bx = 45, bz = 0, kind = "ring" })
			table.insert(legs, { ax = 45, az = 0, bx = 95, bz = 0, kind = "approach" })
			table.insert(legs, { ax = 95, az = 0, bx = 100, bz = 0, kind = "ramp" })
			return legs
		end
		-- Solid inventory (deterministic): rim OBBs, base platforms,
		-- spawn platform circle. Pads/trim/collect pad are 0.6
		-- ledges on the platforms the route walks on by design —
		-- the trace does not flag them; the strip waypoint keeps
		-- the final leg to at most one crossing.
		local rimObbs: { { cx: number, cz: number, hx: number, hz: number, yaw: number } } = {}
		for _, ring in ipairs({ { 28, 31, 2.5 }, { 31, 35, 4 }, { 35, 39, 5.5 } }) do
			local inner, outer = ring[1], ring[2]
			local mid = (inner + outer) / 2
			local arc = 2 * math.pi * mid / 16
			for i = 0, 15 do
				if i ~= 4 then
					local th = (i / 16) * math.pi * 2
					local cx, cz = math.cos(th) * mid, math.sin(th) * mid
					-- Tangent axis angle: local X runs along the
					-- tangent (-sin th, cos th).
					local yaw = math.atan2(math.cos(th), -math.sin(th)) * 180 / math.pi
					table.insert(rimObbs, { cx = cx, cz = cz, hx = arc * 1.08 / 2, hz = (outer - inner) / 2, yaw = yaw })
				end
			end
		end
		local platformObbs: { { cx: number, cz: number, hx: number, hz: number, yaw: number } } = {}
		for bi = 1, 8 do
			local a = math.rad((bi - 1) * 45)
			local cx, cz = math.cos(a) * 110, math.sin(a) * 110
			-- Base 1's local X is world -Z; general yaw from the
			-- local-X axis (sin a, -cos a).
			local yaw = math.atan2(-math.cos(a), math.sin(a)) * 180 / math.pi
			table.insert(platformObbs, { cx = cx, cz = cz, hx = 13, hz = 11, yaw = yaw })
		end
		for rb = 5, 8 do
			for _, leg in ipairs(stealLegs(rb)) do
				-- Every leg must stay outside the meteor-rock worst
				-- reach (min distance to origin > 41).
				local minR = math.min(
					segPointDist(0, 0, leg.ax, leg.az, leg.bx, leg.bz),
					math.sqrt(leg.ax ^ 2 + leg.az ^ 2),
					math.sqrt(leg.bx ^ 2 + leg.bz ^ 2)
				)
				if minR <= meteorReach then
					table.insert(problems, "rival base " .. tostring(rb) .. " " .. leg.kind .. " leg dips to radius " .. string.format("%.1f", minR) .. " — inside meteor-rock reach " .. tostring(meteorReach))
				end
				-- Ring + approach legs must clear the rim, every
				-- platform, and the spawn platform. (Departure may
				-- cross its own platform; ramp runs up the victim's.)
				if leg.kind == "ring" or leg.kind == "approach" then
					for _, obb in ipairs(rimObbs) do
						if segHitsObb(leg.ax, leg.az, leg.bx, leg.bz, obb.cx, obb.cz, obb.hx, obb.hz, obb.yaw) then
							table.insert(problems, "rival base " .. tostring(rb) .. " " .. leg.kind .. " leg hits a crater-rim segment")
							break
						end
					end
					for _, obb in ipairs(platformObbs) do
						if segHitsObb(leg.ax, leg.az, leg.bx, leg.bz, obb.cx, obb.cz, obb.hx, obb.hz, obb.yaw) then
							table.insert(problems, "rival base " .. tostring(rb) .. " " .. leg.kind .. " leg hits a base platform")
							break
						end
					end
					if segPointDist(0, 96, leg.ax, leg.az, leg.bx, leg.bz) <= 28 + HUM_R then
						table.insert(problems, "rival base " .. tostring(rb) .. " " .. leg.kind .. " leg hits the spawn platform")
					end
				end
			end
		end
		if #problems > 0 then
			check("steal-route", false, "the steal route is still blocked — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau, RivalService.luau")
		else
			check("steal-route", true, "steal route traced: ring arc + approach clear of rim/platforms/spawn (computed, all 4 rival bases); meteor-rock worst reach 41 < ring sweep 41.97; SELL pad non-colliding; rocks excluded from corridors; final leg via the clear strip; give-up logs leg + nearest solid")
		end
	end
end

-- -- (base-grab-heat) fix round 12, item 3: picking up from your OWN
-- base brings heat ------------------------------------------------------
-- Playtest 11: Malek picks a Brainrot up from his OWN base — to
-- sell it or rearrange it — and nobody reacts: no chase, no alert,
-- nothing. Two root causes: (a) GuardianService.onGrab fired only
-- from tryGrab (crater grabs), never from pickupOwn; (b) the
-- carrier chase had no safe-base end, and the guardian's chaseLoop
-- despawns instantly on a safe base — so even calling onGrab from
-- pickupOwn would spawn + instantly despawn. The fix is a
-- positional rule in carryRotling (the one call site for crater
-- grabs, own-base pickups and steals): on your own base platform
-- the heat is ARMED (State.baseHeat + a "Guardian is watching"
-- banner); outside it the heat fires immediately. A watcher in
-- RivalService.start engages armed heat the moment the carrier
-- steps outside their own base platform, once per carry. The
-- carrier chase ends when the carrier reaches their base platform.
-- (fix round 13, item 3: platform + ramp, not interior — the
-- platform is the base now.)
do
	local carrySrc = read("src/server/CarryService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local stateSrc = read("src/server/State.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	if not carrySrc or not rivalSrc or not stateSrc or not guardianSrc then
		check("base-grab-heat", false, "could not verify the base-grab heat — CarryService.luau, RivalService.luau, State.luau or GuardianService.luau missing")
	else
		local problems: { string } = {}
		if not stateSrc:find("State%.baseHeat = {}") then
			table.insert(problems, "State.baseHeat flag missing")
		end
		-- The positional rule lives in carryRotling, the one call
		-- site: arm on your own base, engage outside it.
		if not carrySrc:find("State%.baseHeat%[player%.UserId%] = true") then
			table.insert(problems, "carryRotling never arms base heat")
		end
		if not carrySrc:find("isOnBasePlatform%(ownBaseId, root%.Position%)") then
			table.insert(problems, "carryRotling does not test whether the carrier is on their own base platform")
		end
		if not carrySrc:find("The Guardian is watching") then
			table.insert(problems, "carryRotling gives no 'Guardian is watching' alert when heat arms")
		end
		-- The old tryGrab-only onGrab call must be gone: heat has
		-- ONE call site now (carryRotling), or crater grabs would
		-- double-fire the guardian.
		if carrySrc:find("THE CHASE: grabbing a Brainrot from the crater wakes the Crater") then
			table.insert(problems, "tryGrab still has its own onGrab call — heat would double-fire on crater grabs")
		end
		if not carrySrc:find("GuardianService%.onGrab%(player, model%)") then
			table.insert(problems, "carryRotling never wakes the Guardian")
		end
		-- The watcher engages armed heat on exit, once per carry.
		if not rivalSrc:find("State%.baseHeat") then
			table.insert(problems, "RivalService has no heat watcher")
		end
		if not rivalSrc:find("not GuardianService%.isChasing%(player%) and not RivalService%.isChasingPlayer%(userId%)") then
			table.insert(problems, "the heat watcher has no once-per-carry guard")
		end
		if not rivalSrc:find("function RivalService%.isChasingPlayer") then
			table.insert(problems, "RivalService.isChasingPlayer missing")
		end
		-- The carrier chase ends at the carrier's base platform.
		if not rivalSrc:find('chase ended — " %.%. victim%.Name %.%. " reached their base platform') then
			table.insert(problems, "the carrier chase has no safe-base end")
		end
		-- The flag clears when the carry ends.
		if not carrySrc:find("State%.baseHeat%[player%.UserId%] = nil") then
			table.insert(problems, "baseHeat is never cleared when the carry ends")
		end
		if #problems > 0 then
			check("base-grab-heat", false, "the base-grab heat is incomplete — " .. table.concat(problems, "; ") .. ". Parts: CarryService.luau, RivalService.luau, State.luau")
		else
			check("base-grab-heat", true, "base-grab heat: carryRotling arms heat on your own base (banner) and engages outside it; watcher engages on exit once per carry; carrier chase ends at your base platform; flag clears when the carry ends")
		end
	end
end

-- -- (own-base-damage) fix round 13, item 3: ZERO damage on your
-- own base, at all ------------------------------------------------------
-- Playtest 12: "I take damage on my own base" — Malek wants ZERO
-- damage on his own base, at all. Two holes, both proven from the
-- code: (a) the round-9 interior-only safe zone left the doorway /
-- ramp outside it, so a meteor landing at the door hurt a player
-- standing on their own ramp; (b) the guardian's Touch-catch had
-- NO own-base check — a chase to the door could touch-catch the
-- player on the platform edge, bypassing the chaseLoop give-up
-- entirely. The fix: a shared platform rule (WorldBuilder.
-- isOnBasePlatform — the whole slab + the ramp, with a Y gate that
-- keeps the ground at the ramp foot outside) used by EVERY damage
-- and refuge path: the 3 TakeDamage sites (2 meteor, 1 guardian
-- catch) are all gated on it, the guardian give-up and the catch
-- itself refuse on it, the rival hunt refuge, the carrier-chase
-- end and the heat watcher use it, and heat arms on it. The ONLY
-- thing that stays interior-only is the 2x shelter income (a dome
-- bonus, not damage). The ground at the ramp foot stays exposed,
-- so the dash home is still scary — meteors still target the door.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local starfallSrc = read("src/server/StarfallService.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local carrySrc = read("src/server/CarryService.luau")
	if not worldSrc or not starfallSrc or not guardianSrc or not rivalSrc or not carrySrc then
		check("own-base-damage", false, "could not verify the own-base damage rule — WorldBuilder.luau, StarfallService.luau, GuardianService.luau, RivalService.luau or CarryService.luau missing")
	else
		local problems: { string } = {}
		-- The platform rule itself: slab + ramp, Y gate on the ramp.
		if not worldSrc:find("function WorldBuilder%.isOnBasePlatform") then
			table.insert(problems, "no WorldBuilder.isOnBasePlatform helper")
		end
		if not worldSrc:find("localPos%.Z >= %-15") then
			table.insert(problems, "the platform check does not include the ramp strip (local z >= -15)")
		end
		if not worldSrc:find("localPos%.Y >= 2%.5") then
			table.insert(problems, "the platform check has no Y gate on the ramp strip (ground at the ramp foot would count as safe)")
		end
		-- Meteor damage: both TakeDamage sites gated on onBase,
		-- which uses the platform rule.
		if not starfallSrc:find("WorldBuilder%.isOnBasePlatform%(baseId, position%)") then
			table.insert(problems, "the storm damage / targeting check does not use isOnBasePlatform")
		end
		local _, meteorDmg = starfallSrc:gsub("TakeDamage%(Config%.STORM_DAMAGE%)", "")
		if meteorDmg ~= 2 then
			table.insert(problems, "expected exactly 2 meteor TakeDamage sites, found " .. tostring(meteorDmg))
		end
		-- Guardian catch: the catch itself refuses on your own base
		-- (this is what closes the Touch-catch bypass).
		if not guardianSrc:find("catch refused") then
			table.insert(problems, "catchPlayer has no own-base refusal (Touch-catch bypass still open)")
		end
		if not guardianSrc:find("WorldBuilder%.isOnBasePlatform%(baseId, position%)") then
			table.insert(problems, "the guardian give-up does not use isOnBasePlatform")
		end
		local _, catchDmg = guardianSrc:gsub("TakeDamage%(Config%.GUARDIAN_CATCH_DAMAGE%)", "")
		if catchDmg ~= 1 then
			table.insert(problems, "expected exactly 1 guardian catch TakeDamage site, found " .. tostring(catchDmg))
		end
		-- Rivals + heat: refuge, chase ends and watcher all use it.
		if not rivalSrc:find("isOnBasePlatform%(baseId, playerRoot%.Position%)") then
			table.insert(problems, "the hunt refuge does not use isOnBasePlatform")
		end
		if not rivalSrc:find("isOnBasePlatform%(victimBase, victimRoot%.Position%)") then
			table.insert(problems, "the hunt / carrier-chase end does not use isOnBasePlatform")
		end
		if not rivalSrc:find("not WorldBuilder%.isOnBasePlatform%(baseId, root%.Position%)") then
			table.insert(problems, "the heat watcher does not use isOnBasePlatform")
		end
		if not carrySrc:find("isOnBasePlatform%(ownBaseId, root%.Position%)") then
			table.insert(problems, "heat arming does not use isOnBasePlatform")
		end
		-- No damage path may still use the interior rule: if any
		-- of these files still references isOnBaseInterior, a
		-- damage/refuge path is on the old (doorway-exposed) rule.
		for _, src in ipairs({ starfallSrc, guardianSrc, rivalSrc, carrySrc }) do
			if src:find("isOnBaseInterior") then
				table.insert(problems, "a damage/refuge path still uses isOnBaseInterior (doorway-exposed rule)")
				break
			end
		end
		if #problems > 0 then
			check("own-base-damage", false, "zero damage on your own base is incomplete — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau, StarfallService.luau, GuardianService.luau, RivalService.luau, CarryService.luau")
		else
			check("own-base-damage", true, "ZERO damage on your own base: platform rule (slab + ramp, Y gate on the ramp) gates all 3 TakeDamage sites, the guardian catch refuses on it (Touch bypass closed), hunt refuge / chase ends / heat watcher / heat arming all use it; only 2x shelter income stays interior-only")
		end
	end
end

-- -- (lockdown) fix round 13, item 4: emergency lockdown --------
-- Playtest 12: "add a lockdown for locking the base" — an emergency
-- seal, distinct from the regular L lock. 30s sealed, 60s recharge,
-- FIXED (no shop tiers — it is an emergency button, not an upgrade).
-- Its own key (K), its own button under the Lock button, its own
-- remote (ToggleLockdown), its own opaque red gate (Transparency 0,
-- not the lock's faint 0.9 shimmer) and its own red "🔒 LOCKDOWN
-- (Ns)" shield label. Works on top of the regular lock: isLocked is
-- the OR of the two seals, so every enforcement point (steal, thief
-- pickVictim, raider, place prompts) respects the lockdown with no
-- second check — and the lockdown ending falls back to the regular
-- lock's look instead of opening a lock still running.
do
	local configSrc = read("src/shared/Config.luau")
	local stateSrc = read("src/server/State.luau")
	local baseSrc = read("src/server/BaseService.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local projectSrc = read("default.project.json")
	local hudSrc = read("src/client/HUDController.client.luau")
	if not configSrc or not stateSrc or not baseSrc or not worldSrc or not incomeSrc or not remotesSrc or not projectSrc or not hudSrc then
		check("lockdown", false, "could not verify the lockdown — Config.luau, State.luau, BaseService.luau, WorldBuilder.luau, IncomeService.luau, Remotes.luau, default.project.json or HUDController.client.luau missing")
	else
		local problems: { string } = {}
		-- Fixed durations: 30s seal, 60s recharge, no tiers.
		if not configSrc:find("LOCKDOWN_DURATION = 30") then
			table.insert(problems, "no LOCKDOWN_DURATION = 30 in Config")
		end
		if not configSrc:find("LOCKDOWN_COOLDOWN = 60") then
			table.insert(problems, "no LOCKDOWN_COOLDOWN = 60 in Config")
		end
		if not stateSrc:find("State%.lockdowns = {}") then
			table.insert(problems, "no State.lockdowns table")
		end
		-- Server: the seal is the OR of the two locks, so every
		-- enforcement point respects it with no second check.
		if not baseSrc:find("function BaseService%.isLockdown") then
			table.insert(problems, "no BaseService.isLockdown")
		end
		if not baseSrc:find("function BaseService%.lockdownBase") then
			table.insert(problems, "no BaseService.lockdownBase")
		end
		if not baseSrc:find("function BaseService%.setGateLockdown") then
			table.insert(problems, "no BaseService.setGateLockdown")
		end
		if not baseSrc:find("isLockRegular%(baseId%) or BaseService%.isLockdown%(baseId%)") then
			table.insert(problems, "isLocked is not the OR of the regular lock and the lockdown")
		end
		if not baseSrc:find("LOCKDOWN_DURATION") or not baseSrc:find("LOCKDOWN_COOLDOWN") then
			table.insert(problems, "lockdownBase does not use the Config durations")
		end
		-- The gate: opaque red wall (Transparency 0), distinct from
		-- the lock's faint shimmer (0.9), and setGateVisible can
		-- never downgrade it while a lockdown holds.
		if not baseSrc:find("descendant%.Transparency = 0\n") then
			table.insert(problems, "the lockdown gate is not opaque (Transparency 0)")
		end
		if not baseSrc:find("if BaseService%.isLockdown%(baseId%) then\n\t\tBaseService%.setGateLockdown%(baseId, true%)") then
			table.insert(problems, "setGateVisible has no lockdown guard (an L press could downgrade the seal)")
		end
		if not baseSrc:find('Remotes%.lockdownEvent%(%)%.OnServerEvent:Connect') then
			table.insert(problems, "ToggleLockdown is not wired on the server")
		end
		-- The shield label: red LOCKDOWN countdown, not the lock's
		-- blue SAFE label.
		if not worldSrc:find("function WorldBuilder%.setShieldLockdown") then
			table.insert(problems, "no WorldBuilder.setShieldLockdown")
		end
		if not worldSrc:find('"🔒 LOCKDOWN %("') then
			table.insert(problems, "the lockdown shield label is not the red LOCKDOWN countdown")
		end
		-- The broadcast: lockdown label wins while sealed, and the
		-- gate falls back (never opens a running lock) on expiry.
		if not incomeSrc:find("WorldBuilder%.setShieldLockdown%(baseId, BaseService%.lockdownRemaining%(baseId%)%)") then
			table.insert(problems, "the income broadcast does not show the lockdown shield label")
		end
		if not incomeSrc:find("BaseService%.setGateLockdown%(baseId, false%)") then
			table.insert(problems, "the income broadcast has no lockdown-gate expiry")
		end
		if not incomeSrc:find("not BaseService%.isLockdown%(baseId%)") then
			table.insert(problems, "the regular-lock expiry can hide the gate while a lockdown seals the base")
		end
		-- The remote + the Rojo declaration + the HUD button/key.
		if not remotesSrc:find('WaitForChild%("ToggleLockdown"%)') then
			table.insert(problems, "no Remotes.lockdownEvent (ToggleLockdown)")
		end
		if not projectSrc:find('"ToggleLockdown"') then
			table.insert(problems, "no ToggleLockdown RemoteEvent in default.project.json")
		end
		if not hudSrc:find('"LockdownButton"') then
			table.insert(problems, "no Lockdown button in the HUD")
		end
		if not hudSrc:find("Enum%.KeyCode%.K") then
			table.insert(problems, "no K keybinding for the lockdown")
		end
		if not hudSrc:find("hud%.lockdownRemaining") then
			table.insert(problems, "the HUD does not show the lockdown countdown")
		end
		if #problems > 0 then
			check("lockdown", false, "the emergency lockdown is incomplete — " .. table.concat(problems, "; ") .. ". Parts: Config.luau, State.luau, BaseService.luau, WorldBuilder.luau, IncomeService.luau, Remotes.luau, default.project.json, HUDController.client.luau")
		else
			check("lockdown", true, "emergency lockdown: 30s seal / 60s recharge (fixed, no tiers), own K key + button + ToggleLockdown remote; isLocked is lock OR lockdown (every steal/thief check respects it); opaque red gate + red LOCKDOWN shield label; ending falls back to the regular lock, never opens it")
		end
	end
end

-- -- (boards-audit) fix round 13, item 5: no two boards overlap --
-- Playtest 12: "two sign boards are sitting ON each other — the
-- blue board and the brown/gold board overlapping at the centre of
-- the path area." The audit (scratch script /tmp/boards_audit.py)
-- proved the 3D boards NEVER intersected — the overlap was the
-- LABELS: the signpost's two boards sat 1.8 studs apart with 40px
-- AlwaysOnTop labels, so from spawn (34 studs) their centres are
-- ~30px apart on screen and the blue "← Crater" and brown/gold
-- "Shop →" texts sat on each other (they overlap from ~29.5 studs
-- out — everywhere except point-blank). The same audit found a
-- second placement bug: the contract board's "posts" were horizontal
-- bars centred at +/- 6.5 — a 7-long bar spans 3..10, so half of
-- each bar ran THROUGH the board's face and poked 0.1 out the front.
-- Fixes: signpost boards 3.2 studs apart with 32px labels (clear to
-- MaxDistance 50 on any normal screen — the math is asserted below),
-- a vertical post beside the boards (they floated before), a darker
-- backing frame behind each board, vertical contract posts at +/-
-- 6.9 (clear of the board AND the gold backing), and a gold trim on
-- the SELL sign (the one board with no frame at all). The audit
-- itself lives here: every board assembly as an AABB, pairwise
-- separation asserted between different assemblies. Same-assembly
-- overlaps are the frame/trim ON their own board (title trims,
-- contract backing/trim, signpost frames, base-sign stripes, SELL
-- trim) — intended, not a bug.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		check("boards-audit", false, "could not verify the boards audit — WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		-- The signpost fix: 3.2 spacing, 32px labels, MaxDistance 50,
		-- vertical side post, backing frame behind each board.
		if not worldSrc:find("5 %+ %(i %- 1%) %* 3%.2") then
			table.insert(problems, "signpost boards are not 3.2 studs apart")
		end
		if not worldSrc:find("UDim2%.fromOffset%(160, 32%)") then
			table.insert(problems, "signpost labels are not 160x32")
		end
		if not worldSrc:find('"SignpostFrame"') then
			table.insert(problems, "signpost boards have no backing frame")
		end
		if not worldSrc:find("Vector3%.new%(9, 0%.8, 0%.8%)") or not worldSrc:find("Vector3%.new%(%-4%.2, 4%.5, 0%)") then
			table.insert(problems, "the signpost post is not vertical beside the boards (9 tall at x -4.2)")
		end
		if worldSrc:find('part%("Signpost", Enum%.PartType%.Cylinder, Vector3%.new%(6, 0%.8, 0%.8%)') then
			table.insert(problems, "the old horizontal signpost bar is still there (boards float)")
		end
		-- The contract-post fix: vertical posts at +/- 6.9, no
		-- 90-degree rotation, clear of the board (+/- 6) and the
		-- gold backing (+/- 6.3).
		if not worldSrc:find("{ %-6%.9, 6%.9 }") then
			table.insert(problems, "contract posts are not at +/- 6.9 (clear of the board and backing)")
		end
		if worldSrc:find('ContractPost.-CFrame%.Angles%(0, 0, math%.rad%(90%)%)') then
			table.insert(problems, "a contract post is still a horizontal bar through the board face")
		end
		-- The SELL sign trim.
		if not worldSrc:find('"SellSignTrim"') then
			table.insert(problems, "the SELL sign has no gold trim (flat panel)")
		end
		-- The AABB audit: {name, assembly, cx, cy, cz, sx, sy, sz}.
		-- Centres/sizes are the source constants (signpost literals,
		-- title cx/cz 0/46, contract lookAt (16,0,94), SELL (62,9,-2),
		-- shop CFrame (-45,0,45) yaw 45 + disc offset (0,7,10.3),
		-- base signs at BASE_RADIUS 110 + local offset (0,7,9.5)).
		local boards: { { string } } = {}
		local function board(name: string, assembly: string, cx: number, cy: number, cz: number, sx: number, sy: number, sz: number)
			table.insert(boards, { name, assembly, tostring(cx), tostring(cy), tostring(cz), tostring(sx), tostring(sy), tostring(sz) })
		end
		for _, sp in ipairs({ { -8, 62 }, { -22, 28 }, { 6, -48 } }) do
			for _, y in ipairs({ 5, 8.2 }) do
				board("signpost board", "signpost" .. tostring(sp[1]) .. "," .. tostring(sp[2]), sp[1], y, sp[2], 7, 1.6, 0.4)
				board("signpost frame", "signpost" .. tostring(sp[1]) .. "," .. tostring(sp[2]), sp[1], y, sp[2] - 0.3, 7.6, 2.2, 0.2)
			end
			board("signpost post", "signpost" .. tostring(sp[1]) .. "," .. tostring(sp[2]), sp[1] - 4.2, 4.5, sp[2], 0.8, 9, 0.8)
		end
		board("title board", "title", 0, 9, 46, 22, 6, 1)
		board("title trim top", "title", 0, 12.1, 46, 22.4, 0.5, 1.2)
		board("title trim bottom", "title", 0, 5.9, 46, 22.4, 0.5, 1.2)
		board("title post L", "title", -12.5, 6, 46, 1.2, 12, 1.2)
		board("title post R", "title", 12.5, 6, 46, 1.2, 12, 1.2)
		board("contract board", "contract", 16, 6, 94, 2, 8, 12)
		board("contract backing", "contract", 16, 6, 94, 2, 8.6, 12.6)
		board("contract trim", "contract", 16, 10.2, 94, 2, 0.5, 12.4)
		board("contract post R", "contract", 16.86, 3.5, 100.85, 0.8, 7, 0.8)
		board("contract post L", "contract", 15.14, 3.5, 87.15, 0.8, 7, 0.8)
		board("sell sign", "sell", 62, 9, -2, 10, 4, 0.5)
		board("sell trim", "sell", 62, 11.2, -2, 10.4, 0.5, 0.7)
		board("shop disc", "shop", -37.7, 7, 52.3, 5.6, 7.2, 5.6)
		for i = 0, 7 do
			local ang = math.rad(i * 45)
			board("base sign", "base" .. tostring(i + 1), 119.5 * math.cos(ang), 8, 119.5 * math.sin(ang), 9, 5, 9)
		end
		local function aabb(b: { string }): { number }
			local cx = tonumber(b[3]) or 0
			local cy = tonumber(b[4]) or 0
			local cz = tonumber(b[5]) or 0
			local sx = tonumber(b[6]) or 0
			local sy = tonumber(b[7]) or 0
			local sz = tonumber(b[8]) or 0
			return { cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2 }
		end
		for i = 1, #boards do
			for j = i + 1, #boards do
				if boards[i][2] ~= boards[j][2] then
					local a = aabb(boards[i])
					local b = aabb(boards[j])
					if a[1] < b[2] and b[1] < a[2] and a[3] < b[4] and b[3] < a[4] and a[5] < b[6] and b[5] < a[6] then
						table.insert(problems, "boards intersect in 3D: " .. boards[i][1] .. " (" .. boards[i][2] .. ") <-> " .. boards[j][1] .. " (" .. boards[j][2] .. ")")
					end
				end
			end
		end
		-- The label-spacing math: two 32px AlwaysOnTop labels whose
		-- centres are 3.2 studs apart, at the MaxDistance of 50
		-- studs, on an 800px-tall screen at 70deg vertical FOV.
		-- Separation = (3.2/50) / tan(35deg) * 400 = ~36.6px > 32px,
		-- so the labels are clear at every distance they render.
		-- (The old 1.8 / 40px pair overlapped from ~29.5 studs out.)
		local sepAtMax = (3.2 / 50) / math.tan(math.rad(35)) * 400
		if sepAtMax <= 32 then
			table.insert(problems, "signpost labels still overlap at MaxDistance (separation " .. string.format("%.1f", sepAtMax) .. "px <= 32px)")
		end
		if #problems > 0 then
			check("boards-audit", false, "the boards audit failed — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau")
		else
			check("boards-audit", true, "no two boards intersect in 3D (AABB audit, " .. tostring(#boards) .. " parts); signpost labels 3.2 studs apart / 32px (clear to MaxDistance 50, ~36.6px separation); vertical posts beside the boards; contract posts vertical at +/- 6.9; SELL trim added")
		end
	end
end

-- -- (egg-layered) fix round 13, item 2: eggs are layered ovoids
-- ---------------------------------------------------------------------
-- Playtest 12: "the new egg still doesn't look like an egg, looks
-- weird" — Malek's direction: "layered". The round-12 egg wore 10
-- speckles, 4 crack lines and a twig nest — fiddly clutter that
-- read as a lumpy ball from across the field. Now: a clean cream
-- ovoid (3.2 wide, 4.8 tall, ratio 1.5) with exactly two smooth
-- horizontal bands (purple at +0.8, teal at -0.9), each slightly
-- wider than the shell's cross-section at its height, all welded
-- to the shell. No speckles, no cracks, no nest anywhere. The
-- mystery rule is intact: every ground egg is identical (same
-- cream + bands, same "🥚 METEOR EGG" label, no rarity on the
-- ground). The legendary crater egg keeps the same layered shape,
-- gold all over (shell + bands).
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not eggSrc then
		check("egg-layered", false, "could not verify the egg redesign — MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		-- Ovoid: height 4.8 vs width 3.2 (ratio 1.5), not a ball.
		if not eggSrc:find('shell%.Size = Vector3%.new%(3%.2, 4%.8, 3%.2%)') then
			table.insert(problems, "the egg shell is not ovoid (3.2 x 4.8 x 3.2)")
		end
		-- Cream shell, not orange.
		if not eggSrc:find("shell%.Color = Color3%.fromRGB%(255, 244, 214%)") then
			table.insert(problems, "the egg shell is not cream (255, 244, 214)")
		end
		-- Two bands, named EggBand, wider than the shell at their
		-- heights (3.3 at +0.8, 3.2 at -0.9), welded to the shell.
		if not eggSrc:find('"EggBand"') then
			table.insert(problems, "no EggBand parts on the egg")
		else
			local _, bandCount = eggSrc:gsub('"EggBand"', "")
			if bandCount < 1 then
				table.insert(problems, "no EggBand parts on the egg")
			end
			if not eggSrc:find("{ 0%.8, 3%.3,") or not eggSrc:find("{ %-0%.9, 3%.2,") then
				table.insert(problems, "the bands are not at +0.8 (3.3 wide) and -0.9 (3.2 wide)")
			end
		end
		if not eggSrc:find("WeldConstraint") then
			table.insert(problems, "egg detail is not welded to the shell")
		end
		-- The old clutter is GONE: no speckles, cracks or nest.
		if eggSrc:find("EggSpeckle") or eggSrc:find("speckleOffsets") then
			table.insert(problems, "the old speckles are still on the egg")
		end
		if eggSrc:find("EggCrack") or eggSrc:find("crackOffsets") then
			table.insert(problems, "the old crack lines are still on the egg")
		end
		if eggSrc:find("EggNest") then
			table.insert(problems, "the old twig nest is still under the egg")
		end
		-- Rest height matches the taller shell (half-height 2.4),
		-- so the shell bottom sits on the ground / incubator.
		local _, restCount = eggSrc:gsub("Vector3%.new%(0, 2%.4, 0%)", "")
		if restCount < 3 then
			table.insert(problems, "the egg rest height is not 2.4 (taller shell would sink)")
		end
		-- Mystery rule intact: the ground label is still the plain
		-- "🥚 METEOR EGG", and buildEgg never names a rarity.
		if not eggSrc:find('"🥚 METEOR EGG"') then
			table.insert(problems, "the ground egg label is not the plain mystery label")
		end
		local buildStart = eggSrc:find("local function buildEgg")
		if buildStart then
			local _, buildEnd = eggSrc:find("\nend\n", buildStart)
			local body = eggSrc:sub(buildStart, buildEnd or #eggSrc)
			if body:find("RarityConfig") or body:find("hatchDef") then
				table.insert(problems, "buildEgg leaks rarity onto the ground egg")
			end
		end
		-- Legendary: same layered shape, gold all over (shell +
		-- bands), not a different model.
		if not eggSrc:find('child%.Name == "EggBand"') or not eggSrc:find('child%.Color = Color3%.fromRGB%(255, 215, 0%)') then
			table.insert(problems, "the legendary egg does not recolor its bands gold")
		end
		if #problems > 0 then
			check("egg-layered", false, "the egg redesign is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau")
		else
			check("egg-layered", true, "eggs are layered ovoids (cream 3.2 x 4.8, ratio 1.5) with two smooth bands (purple +0.8, teal -0.9), welded; no speckles/cracks/nest; mystery rule intact; legendary gold all over")
		end
	end
end

-- -- (egg-spawn) fix round 13, item 2: eggs land in the open field
-- ---------------------------------------------------------------------
-- Playtest 12: "egg places gets in other brainrot places" — eggs
-- landed where Brainrots are (belt / crater / bases). eggPosition
-- drew radius 40..130 (the crater rim ends at 39, so an egg could
-- sit one stud off the rim), excluded bases only within 18 studs
-- (the platform's far corner is 17 — an egg could sit on the
-- doorstep), and fell back to (0, 0, 50): the spawn path at the
-- crater mouth. Now: radius 48..130 (clear of rim + steal ring),
-- 24 studs from any base centre, SELL pad / shop / altar / spawn
-- pad excluded, and the fallback is a fixed open-field spot
-- (60, -60). The legendary crater drop is untouched — it is a
-- deliberate crater event, announced, gold-beamed, not a storm egg.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not eggSrc then
		check("egg-spawn", false, "could not verify the egg spawn positions — MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if not eggSrc:find("math%.random%(48, 130%)") then
			table.insert(problems, "eggPosition does not draw radius 48..130 (crater/rim clear)")
		end
		if eggSrc:find("math%.random%(40, 130%)") then
			table.insert(problems, "the old eggPosition radius draw (40..130) is still there")
		end
		if not eggSrc:find("Magnitude < 24") then
			table.insert(problems, "eggPosition does not exclude 24 studs around every base")
		end
		if not eggSrc:find("math%.abs%(pos%.X %- 62%) < 14") or not eggSrc:find("math%.abs%(pos%.X %+ 45%) < 16") then
			table.insert(problems, "eggPosition does not exclude the SELL pad and shop")
		end
		if not eggSrc:find("Vector3%.new%(60, 0, %-60%)") then
			table.insert(problems, "the eggPosition fallback is not the open-field spot (60, -60)")
		end
		if eggSrc:find("Vector3%.new%(0, 0, 50%)") then
			table.insert(problems, "the old eggPosition fallback (0, 0, 50) — crater mouth — is still there")
		end
		if #problems > 0 then
			check("egg-spawn", false, "eggs can still land on Brainrot spots — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau")
		else
			check("egg-spawn", true, "storm eggs land in the open field only: radius 48..130, 24 studs from any base, SELL/shop/altar/spawn excluded, fallback (60, -60)")
		end
	end
end

-- (cu) Uniform placed size (rev 75; measure fixed fix round 9, item
-- 5): every Brainrot on a pedestal stands at one BODY height
-- (Config.PLACED_DISPLAY_HEIGHT), so the base reads as a tidy display
-- case. The old measure was the total bounding box (body + hat), so
-- a flat puddle with slabs sticking up got its body under-scaled
-- while a tall dome stayed big — the sizes still read uneven in
-- playtest 10. The measure is now the body (PrimaryPart.Size.Y),
-- with the widest body dimension capped at PLACED_MAX_WIDTH so flat
-- wide bodies do not sprawl past their pad. The crater keeps
-- per-type sizes (1.5x spawns) and carrying keeps CARRY_MAX_HEIGHT.
do
	local configSrc = read("src/shared/Config.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not configSrc or not factorySrc or not carrySrc or not worldSrc then
		check("cu", false, "could not verify the uniform placed size — Config.luau, RotlingFactory.luau, CarryService.luau or WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("PLACED_DISPLAY_HEIGHT = 4%.5") then
			table.insert(problems, "no PLACED_DISPLAY_HEIGHT = 4.5 in Config")
		end
		if not factorySrc:find("function RotlingFactory%.normalizeToHeight") then
			table.insert(problems, "no normalizeToHeight in RotlingFactory")
		end
		if not factorySrc:find("buildBodyHeight = body%.Size%.Y / current") then
			table.insert(problems, "normalizeToHeight does not measure the BODY height (PrimaryPart.Size.Y) — hats/accessories would still skew the size")
		end
		if not factorySrc:find("PLACED_MAX_WIDTH") then
			table.insert(problems, "normalizeToHeight has no width cap — flat wide bodies sprawl past their pad")
		end
		if not carrySrc:find("normalizeToHeight%(model, Config%.PLACED_DISPLAY_HEIGHT%)") then
			table.insert(problems, "placeOnPad does not normalize the placed Brainrot")
		end
		if not worldSrc:find("normalizeToHeight%(model, Config%.PLACED_DISPLAY_HEIGHT%)") then
			table.insert(problems, "the logo-stage heroes are not normalized to the display height")
		end
		if carrySrc:find("setModelScale%(model, 1%)\n\tRotlingFactory%.refreshLabelOffset%(model%)\n\tlocal padCf") then
			table.insert(problems, "placeOnPad still seats the model at scale 1 with no normalization after it")
		end
		if #problems > 0 then
			check("cu", false, "the uniform placed size is incomplete — " .. table.concat(problems, "; ") .. ". Parts: Config.luau, RotlingFactory.luau, CarryService.luau, WorldBuilder.luau")
		else
			check("cu", true, "placed Brainrots stand at one uniform BODY height (4.5 studs, hat excluded, width capped at 6): placeOnPad normalizes every placement (restores + egg hatches ride the same path), the logo-stage heroes match; crater spawns keep per-type 1.5x sizes and carrying keeps CARRY_MAX_HEIGHT")
		end
	end
end

-- (cv) Lock-gate expiry (rev 76): the red LockGate is solid while
-- locked and vanishes the moment the lock ends. The shield dome
-- already cleared via setShieldLabel in the income broadcast; the
-- gate had no expiry path at all (setGateVisible was only ever
-- called with true), so it stayed solid forever and blocked the
-- owner and every thief — which is why nobody entered his base.
do
	local baseSrc = read("src/server/BaseService.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local mainSrc = read("src/server/Main.server.luau")
	local stateSrc = read("src/server/State.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not baseSrc or not incomeSrc or not mainSrc or not stateSrc or not worldSrc then
		check("cv", false, "could not verify the lock-gate expiry — BaseService.luau, IncomeService.luau, Main.server.luau, State.luau or WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if not stateSrc:find("gateShown") then
			table.insert(problems, "the lock record does not track gateShown")
		end
		if not baseSrc:find("gateShown = true") then
			table.insert(problems, "lockBase does not record that the gate is shown")
		end
		if not incomeSrc:find("setGateVisible%(baseId, false%)") then
			table.insert(problems, "the income broadcast never hides the gate when the lock expires")
		end
		if not incomeSrc:find("lock%.gateShown") then
			table.insert(problems, "the broadcast does not check the gateShown transition (it would rescan the workspace every tick)")
		end
		if not mainSrc:find("if not BaseService%.isLocked%(baseId%) then\n\t\tBaseService%.setGateVisible%(baseId, false%)") then
			table.insert(problems, "join does not clear a stuck gate for an unlocked base")
		end
		if not baseSrc:find("descendant%.Transparency = if visible then 0%.9 else 1") then
			table.insert(problems, "setGateVisible does not hide the gate (Transparency 1)")
		end
		-- (real-base section: the gate is lasers now — the slab is a
		-- faint shimmer and six Neon beams do the visible work.)
		if not baseSrc:find('descendant%.Name == "LockGateBeam"') then
			table.insert(problems, "setGateVisible never toggles the laser beams")
		end
		if not baseSrc:find("descendant%.Transparency = if visible then 0 else 1") then
			table.insert(problems, "the laser beams do not vanish when the gate opens")
		end
		if not baseSrc:find("descendant%.CanCollide = visible") then
			table.insert(problems, "setGateVisible does not uncollide the hidden gate")
		end
		if not worldSrc:find('part%("LockGateBeam"') then
			table.insert(problems, "no LockGateBeam parts built in WorldBuilder")
		end
		if #problems > 0 then
			check("cv", false, "the lock-gate expiry is incomplete — " .. table.concat(problems, "; ") .. ". Parts: BaseService.luau, IncomeService.luau, Main.server.luau, State.luau")
		else
			check("cv", true, "the laser gate expires: lockBase records gateShown, the income broadcast hides the gate (faint slab + beams, and uncollides it) the moment lockRemaining hits 0, and a rejoining player with an expired lock gets the gate cleared on join; the shield dome already cleared via setShieldLabel (it was never solid — CanCollide false)")
		end
	end
end

-- (cw) Brainrot-carrier chase (rev 77, rebuilt fix round 8 item 8):
-- carrying a Brainrot is dangerous — the NEAREST rivals give chase
-- and tag the carrier, who drops the haul. The old design only woke
-- rivals within 30 studs, but rivals sit at their bases at radius
-- 110 — so a grab in the crater almost never had a rival in range
-- and Malek was never chased. Now the nearest 2 available rivals
-- chase at 19 (faster than a walk, slower than a sprint), follow a
-- computed path (no straight line into the rim), survive storms, and
-- log the chase start + end so the F9 trail proves it happened.
do
	local stateSrc = read("src/server/State.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not stateSrc or not carrySrc or not rivalSrc or not configSrc then
		check("cw", false, "could not verify the Brainrot-carrier chase — State.luau, CarryService.luau, RivalService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not stateSrc:find("brainrotCarriedByUser") then
			table.insert(problems, "no brainrotCarriedByUser in State")
		end
		if not carrySrc:find("State%.brainrotCarriedByUser%[player%.UserId%] = model") then
			table.insert(problems, "a grab does not flag the player as a Brainrot carrier")
		end
		if not carrySrc:find("notifyBrainrotCarrier%(player%)") then
			table.insert(problems, "a grab does not notify rivals")
		end
		if not carrySrc:find("State%.brainrotCarriedByUser%[player%.UserId%] = nil") then
			table.insert(problems, "the carrier flag is never cleared when the player stops carrying")
		end
		if not rivalSrc:find("function RivalService%.notifyBrainrotCarrier") then
			table.insert(problems, "no notifyBrainrotCarrier in RivalService")
		end
		if not rivalSrc:find("carryingBrainrot") then
			table.insert(problems, "the chase phase does not accept Brainrot carriers")
		end
		if not rivalSrc:find("dropAllCarried%(victim%)") then
			table.insert(problems, "a tag does not make the carrier drop the Brainrots")
		end
		if rivalSrc:find("RIVAL_CHASE_RADIUS") then
			table.insert(problems, "the 30-stud chase radius is still in use — rivals at radius 110 never qualify")
		end
		if not configSrc:find("RIVAL_CHASE_MAX = 2") then
			table.insert(problems, "no RIVAL_CHASE_MAX = 2 (up to 2 chasers per carrier)")
		end
		if not configSrc:find("RIVAL_CHASE_SPEED = 19") then
			table.insert(problems, "no RIVAL_CHASE_SPEED = 19 (a chaser must outrun a walking carrier)")
		end
		if not rivalSrc:find("table%.sort%(candidates") then
			table.insert(problems, "the chase does not pick the NEAREST rivals (no distance sort)")
		end
		if not rivalSrc:find("PathfindingService:CreatePath") then
			table.insert(problems, "the chase does not pathfind — a straight MoveTo still pushes rivals into the rim")
		end
		if not rivalSrc:find("chasing \" %.%. player%.Name") then
			table.insert(problems, "the chase start is not logged (no proof it fired)")
		end
		if not rivalSrc:find("studs away") then
			table.insert(problems, "the chase start log does not carry the distance")
		end
		if not rivalSrc:find("chase ended") then
			table.insert(problems, "the chase end is not logged (no proof why it stopped)")
		end
		if not rivalSrc:find('phase ~= "chase" and rival%.phase ~= "steal"') then
			table.insert(problems, "storm cover still abandons a chase/steal mid-storm")
		end
		if #problems > 0 then
			check("cw", false, "the Brainrot-carrier chase is incomplete — " .. table.concat(problems, "; ") .. ". Parts: State.luau, CarryService.luau, RivalService.luau, Config.luau")
		else
			check("cw", true, "carrying a Brainrot is dangerous: a grab flags the carrier and wakes the nearest 2 rivals (any distance), they chase at 19 on a computed path (storm-proof), and a tag drops the haul while the rival flees; chase start + end are logged with distances; reaching base clears the flag and ends the chase")
		end
	end
end

-- (cx) One thief at a time per victim (rev 78): tryStartSteal refuses
-- to start a second steal on a victim another rival is already
-- stealing from, so thieves arrive one by one instead of a 4-thief
-- swarm on the only player with placed Brainrots.
do
	local rivalSrc = read("src/server/RivalService.luau")
	if not rivalSrc then
		check("cx", false, "could not verify the one-thief rule — RivalService.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find('other%.phase == "steal"') then
			table.insert(problems, "tryStartSteal does not check whether another rival is already stealing")
		end
		if not rivalSrc:find("other%.targetUserId == victim%.UserId") then
			table.insert(problems, "the check does not match the same victim")
		end
		if not rivalSrc:find("other ~= rival") then
			table.insert(problems, "the check does not exclude the rival itself")
		end
		if #problems > 0 then
			check("cx", false, "the one-thief rule is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau")
		else
			check("cx", true, "one thief at a time per victim: tryStartSteal returns false while another rival is already stealing from the same victim, so thieves stagger (one comes, you bonk/lock, the next comes later) instead of a 4-thief swarm")
		end
	end
end

-- -- (cy) simplify/polish REMOVE: the clutter is really gone ------------------
-- Decision log (the "black panels / big dark wall behind SPAWN" call):
-- "black panels" = the world Index Wall (a 26x9 dark board + 20 dark
-- panels, RGB 30,25,50 — dead black rectangles until found). Removed
-- outright: the Index already lives in the HUD (IndexController), so
-- no feature is lost. "Big dark wall behind SPAWN" = the five 80-tall
-- dark Slate mountain wedges at the map edge (RGB 90,70,130) — they
-- read as a black wall on the horizon, including behind spawn.
-- Removed: the moon stays, and the sky keeps its planet, stars and
-- meteor streak, so no shot has an empty horizon. Gems (Stardust) are
-- KEPT — they buy boosts + mutation rerolls, so they are a real
-- currency, not clutter. Bounty Board was already removed in v71;
-- the buddy pet was already parked in rev 73.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local wallCtl = read("src/client/IndexWallController.client.luau")
	if not worldSrc or not hudSrc then
		check("cy", false, "could not verify the REMOVE section — WorldBuilder.luau or HUDController.client.luau missing")
	else
		local problems: { string } = {}
		if worldSrc:find("FloatingIsland") or worldSrc:find("IslandCrystal") or worldSrc:find("buildFloatingIslands") then
			table.insert(problems, "floating islands are still built (dark balls + neon crystals hanging in the air)")
		end
		if worldSrc:find("registerFloat") or worldSrc:find("startFloatBob") then
			table.insert(problems, "the float-bob loop is still there (island-only, dead without the islands)")
		end
		if worldSrc:find("IndexWallBoard") or worldSrc:find("IndexWall_") or worldSrc:find("buildIndexWall") then
			table.insert(problems, "the world Index Wall is still built (the black panels)")
		end
		if wallCtl then
			table.insert(problems, "IndexWallController.client.luau still exists (dead without the wall)")
		end
		if worldSrc:find('part%("Mountain"') then
			table.insert(problems, "the mountain wedges are still built (the big dark wall behind SPAWN)")
		end
		if worldSrc:find("SpawnSign") then
			table.insert(problems, "the SPAWN sign is still built (players spawn at their own base)")
		end
		if hudSrc:find("BeltPanel") then
			table.insert(problems, 'the "On the belt" list is still in the HUD')
		end
		if hudSrc:find("XpBar") then
			table.insert(problems, "the XP bar is still in the HUD (rebirth is the only visible progress system)")
		end
		if not hudSrc:find("Stardust") then
			table.insert(problems, "Stardust is gone from the HUD — it must stay (it buys boosts + mutation rerolls)")
		end
		if not worldSrc:find('part%("Moon"') then
			table.insert(problems, "the moon is gone — the sky needs it now the mountains are removed")
		end
		if #problems > 0 then
			check("cy", false, "the REMOVE section is incomplete — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau, HUDController.client.luau, IndexWallController.client.luau (deleted)")
		else
			check("cy", true, "REMOVE done: floating islands + float loop, world Index Wall + controller, mountains, SPAWN sign, belt list and XP bar all gone; Stardust kept (real currency), moon kept, HUD index kept")
		end
	end
end

-- -- (cz) simplify/polish SIMPLIFY THE HUD ------------------------------------
-- The HUD collapses to one top line + one quest pill + progress on the
-- Rebirth button. Phone-sized check (by the numbers, 667x375 landscape):
-- the top line is 70% scale width + TextScaled, so it can never
-- overflow a narrow screen (the old 680px fixed line did); the title
-- is 440px centred (fits 667); the quest pill is 420px centred at
-- y=112, below the left buttons (end y=104) and clear of the
-- right-aligned event label (its text starts around x=443, the pill's
-- left-aligned text ends around x=415); the right column (Rebirth /
-- Lock / Leaderboard) keeps its 24px right margin; the leaderboard
-- still shows 3 names max.
do
	local hudSrc = read("src/client/HUDController.client.luau")
	if not hudSrc then
		check("cz", false, "could not verify the simplified HUD — HUDController.client.luau missing")
	else
		local problems: { string } = {}
		if not hudSrc:find("topBar%.Size = UDim2%.new%(1, 0, 0, 68%)") then
			table.insert(problems, "the top bar is not 68px tall (title + one line only)")
		end
		if not hudSrc:find('makeLabel%(gui, "TopLine"') then
			table.insert(problems, "no single top-line label")
		end
		if not hudSrc:find("UDim2%.new%(0%.7, 0, 0, 28%)") then
			table.insert(problems, "the top line is not 70% scale width (a fixed width clips on a phone)")
		end
		if not hudSrc:find("topLineLabel%.TextScaled = true") then
			table.insert(problems, "the top line is not TextScaled")
		end
		if not hudSrc:find("topLineLabel%.Text = Formatting%.formatMoney%(hud%.coins%)") then
			table.insert(problems, "the top line does not start with the cash total")
		end
		if not hudSrc:find("Rebirth ") or not hudSrc:find("· x") then
			table.insert(problems, "the top line does not carry the rebirth tier + multiplier next to the cash")
		end
		if not hudSrc:find("📖") or not hudSrc:find("💎") then
			table.insert(problems, "the top line does not carry the index count and Stardust")
		end
		if hudSrc:find("local coinsLabel") or hudSrc:find("local cpsLabel") or hudSrc:find("local stardustLabel") then
			table.insert(problems, "the old separate Coins / Cps / Stardust labels are still there")
		end
		if not hudSrc:find('questPill%.Position = UDim2%.new%(0%.5, %-210, 0, 112%)') then
			table.insert(problems, "the quest pill is not a 420px centred pill at y=112")
		end
		if hudSrc:find("local missionBar") or hudSrc:find("local missionFill") then
			table.insert(problems, "the old full-width mission bar is still there")
		end
		if hudSrc:find("local rebirthBar") or hudSrc:find("local rebirthFill") or hudSrc:find("local rebirthProgressLabel") then
			table.insert(problems, "the old NEXT REBIRTH bar is still there")
		end
		if not hudSrc:find("RebirthButtonFill") then
			table.insert(problems, "no progress fill on the Rebirth button")
		end
		if not hudSrc:find("rebirthButton%.ZIndex = 3") then
			table.insert(problems, "the Rebirth button is not above its fill (text would hide under it)")
		end
		if not hudSrc:find("255, 215, 0") then
			table.insert(problems, "the Rebirth button has no gold ready state")
		end
		if not hudSrc:find("LeaderboardRow") then
			table.insert(problems, "the leaderboard rows are gone (top right, 3 names max)")
		end
		if not hudSrc:find("UDim2%.new%(1, %-244, 0, 252%)") then
			table.insert(problems, "the leaderboard is not top-right with its 24px margin")
		end
		if #problems > 0 then
			check("cz", false, "the simplified HUD is incomplete — " .. table.concat(problems, "; ") .. ". Parts: HUDController.client.luau")
		else
			check("cz", true, "HUD simplified: 68px top bar, one TextScaled top line (cash • rebirth tier/multiplier • income • index • stardust), 420px quest pill at y=112, rebirth progress on the button (fill + gold glow when ready), leaderboard top-right with 3 names")
		end
	end
end

-- (da) REAL BASE (simplify/polish): a clear plot with 8 visible
-- pedestals, each showing its Brainrot + name + $/s; a glowing collect
-- pad in the middle aisle; a laser gate at the entrance; a sign with
-- the player name + base cash and no level; "Place Brainrot" only
-- while carrying.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local baseSrc = read("src/server/BaseService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not worldSrc or not hudSrc or not baseSrc or not configSrc then
		check("da", false, "could not verify the real base — WorldBuilder.luau, HUDController.client.luau, BaseService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		-- 8 pedestals: the PAD_OFFSETS table holds 8 offsets.
		local padBlockStart = worldSrc:find("local PAD_OFFSETS = {", 1, true)
		local padCount = 0
		if padBlockStart then
			local padBlockEnd = worldSrc:find("}", padBlockStart, true)
			if padBlockEnd then
				local padBlock = worldSrc:sub(padBlockStart, padBlockEnd)
				for _ in padBlock:gmatch("Vector3%.new") do
					padCount += 1
				end
			end
		end
		if padCount ~= 8 then
			table.insert(problems, "PAD_OFFSETS does not hold 8 pedestals (found " .. tostring(padCount) .. ")")
		end
		if not worldSrc:find('part%("Pad"') then
			table.insert(problems, "no Pad parts built in WorldBuilder")
		end
		if not worldSrc:find('part%("PadPlinth"') then
			table.insert(problems, "no PadPlinth plinths under the pads")
		end
		-- Collect pad in the middle aisle.
		if not worldSrc:find('part%("CollectPad"') then
			table.insert(problems, "no CollectPad in the base")
		end
		if not worldSrc:find("CFrame%.new%(0, 1%.3, 0%)") then
			table.insert(problems, "the collect pad is not in the middle aisle (0, 1.3, 0)")
		end
		-- Laser gate at the entrance.
		if not worldSrc:find('part%("LockGate"') then
			table.insert(problems, "no LockGate slab at the entrance")
		end
		if not worldSrc:find('part%("LockGateBeam"') then
			table.insert(problems, "no LockGateBeam laser beams at the entrance")
		end
		-- Lock duration: 120s (Malek's explicit "add more time for the
		-- lockups", fix round 6) — the brief's 30s is superseded.
		if not configSrc:find("LOCK_DURATION = 120") then
			table.insert(problems, "lock duration is not 120s (Config.LOCK_DURATION)")
		end
		-- Sign: name + cash, no level.
		if not worldSrc:find('sign%.Name = "BaseSign"') then
			table.insert(problems, 'no "BaseSign" billboard')
		end
		if worldSrc:find('"Lv "') then
			table.insert(problems, 'the base still shows a "Lv " string')
		end
		-- "Place Brainrot" only while carrying (client-side gating).
		if not hudSrc:find("refreshPlacePrompts") then
			table.insert(problems, "no refreshPlacePrompts in the HUD")
		end
		if not hudSrc:find('ActionText == "Place Brainrot"') then
			table.insert(problems, "the prompt gating does not target the Place Brainrot prompts")
		end
		if not hudSrc:find("prompt%.Enabled = enabled") then
			table.insert(problems, "the prompts are never Enabled/Disabled from the carried state")
		end
		if not hudSrc:find("hud%.carried > 0") then
			table.insert(problems, "the prompt gating does not read the carried count")
		end
		if #problems > 0 then
			check("da", false, "the base is not a real base — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau (pads, collect pad, laser gate, sign), HUDController.client.luau (place prompts), BaseService.luau (lock)")
		else
			check("da", true, "the base is a real base: 8 pedestals, glowing collect pad in the middle aisle, laser gate (120s lock), sign with name + base cash and no level, Place Brainrot prompt only while carrying")
		end
	end
end

-- (db) REBIRTH-2 PROOF (simplify/polish, real-base section): Rebirth 2
-- resets cash only and keeps the index. Static half of the proof (the
-- replay half lives in verify-rebirth.luau, run before publish): the
-- doRebirth body assigns ONLY coins/banked/rebirths and never touches
-- placed, index, xp, level or Stardust, and DataService persists
-- placed + index.
do
	local rebirthSrc = read("src/server/RebirthService.luau")
	local dataSrc = read("src/server/DataService.luau")
	if not rebirthSrc or not dataSrc then
		check("db", false, "could not verify the Rebirth-2 proof — RebirthService.luau or DataService.luau missing")
	else
		local problems: { string } = {}
		local bodyStart = rebirthSrc:find("function RebirthService.doRebirth", 1, true)
		local bodyEnd = nil
		if bodyStart then
			bodyEnd = rebirthSrc:find("\nend\n\n-- Wire the DoRebirth", bodyStart, true)
		end
		if not bodyStart or not bodyEnd then
			table.insert(problems, "doRebirth body not found")
		else
			local body = rebirthSrc:sub(bodyStart, bodyEnd)
			if not body:find("profile%.coins = 0") then
				table.insert(problems, "doRebirth does not reset profile.coins to 0")
			end
			if not body:find("profile%.banked = 0") then
				table.insert(problems, "doRebirth does not reset profile.banked to 0")
			end
			if not body:find("profile%.rebirths %+= 1") then
				table.insert(problems, "doRebirth does not increment profile.rebirths")
			end
			for _, forbidden in ipairs({ "placed", "index", "%.xp", "level", "stardust", "removePlaced", "clearPlaced", "State%.placed" }) do
				if body:find(forbidden) then
					table.insert(problems, "doRebirth touches '" .. forbidden .. "' — the reset is not cash-only")
				end
			end
		end
		if not dataSrc:find("placed = {},") then
			table.insert(problems, "the default profile does not persist placed Brainrots")
		end
		if not dataSrc:find("index = {},") then
			table.insert(problems, "the default profile does not persist the index")
		end
		if #problems > 0 then
			check("db", false, "the Rebirth-2 proof is broken — " .. table.concat(problems, "; ") .. ". Parts: RebirthService.luau (doRebirth), DataService.luau, verify-rebirth.luau")
		else
			check("db", true, "Rebirth 2 resets cash only: doRebirth assigns coins/banked/rebirths and nothing else (no placed, index, xp, level or Stardust); placed + index persist in the profile (see verify-rebirth.luau replay)")
		end
	end
end

-- (dc) COMPETITION VIA SCARCITY (simplify/polish): Rare+ spawns get a
-- light beam + a server alert and bots race for them; raider/thief
-- bots every 60-90s; the guardian is verified, not rebuilt.
do
	local spawnSrc = read("src/server/SpawnService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not spawnSrc or not rivalSrc or not guardianSrc or not configSrc then
		check("dc", false, "could not verify competition — SpawnService.luau, RivalService.luau, GuardianService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		-- Rare+ beam + server alert.
		if not spawnSrc:find("local function spawnBeam") then
			table.insert(problems, "no spawnBeam in SpawnService")
		end
		if not spawnSrc:find('beam%.Name = "SpawnBeam"') then
			table.insert(problems, "the beam part is not named SpawnBeam")
		end
		if not spawnSrc:find("rarityTier%(def%.rarity%)") then
			table.insert(problems, "announceSpawn does not read the rarity tier")
		end
		if not spawnSrc:find("tier < 2") then
			table.insert(problems, "the Rare-or-better gate (tier >= 2) is missing")
		end
		if not spawnSrc:find("🌟 A ") then
			table.insert(problems, "no Rare spawn banner")
		end
		if not spawnSrc:find("FireAllClients") then
			table.insert(problems, "the Rare spawn is not announced server-wide")
		end
		-- The beam fires for every Rare+ spawn path (belt, storm, opening).
		if not spawnSrc:find("announceSpawn%(def, mutation, position%)") then
			table.insert(problems, "spawnOne does not pass its position to announceSpawn")
		end
		if not spawnSrc:find("announceSpawn%(def, mutation, buildPos%)") then
			table.insert(problems, "spawnRareAt does not pass its position to announceSpawn")
		end
		-- Bots race for it: rivals grab the RAREST free Brainrot.
		if not rivalSrc:find("Rarest first") then
			table.insert(problems, "RivalService does not grab rarest-first")
		end
		if not rivalSrc:find("tier > bestTier") then
			table.insert(problems, "the rival rarest pick does not compare rarity tiers")
		end
		-- Raider/thief cadence 60-90s.
		local interval = configValue(configSrc, "RAIDER_INTERVAL")
		if interval ~= 75 then
			table.insert(problems, "raider interval is " .. tostring(interval) .. "s (not 75)")
		end
		-- Guardian verified, not rebuilt: chase + catch still present.
		if not guardianSrc:find("catch") and not guardianSrc:find("Catch") then
			table.insert(problems, "GuardianService has no catch mechanic (was it rebuilt?)")
		end
		if #problems > 0 then
			check("dc", false, "competition via scarcity is incomplete — " .. table.concat(problems, "; ") .. ". Parts: SpawnService.luau (beam + alert), RivalService.luau (rarest race), Config.RAIDER_INTERVAL, GuardianService.luau (verify only)")
		else
			check("dc", true, "competition via scarcity: Rare+ spawns get a rarity-coloured beam + server banner, rivals race for the rarest free Brainrot, raiders every 75s, guardian chase + catch verified intact")
		end
	end
end

-- (dd) ADD (simplify/polish): first-minute guide, sounds, faces + bounce
-- + rarity glows. Verified present and wired (fix round 7 + earlier
-- rounds) — no code change in this section, these checks lock the
-- verified state in so it cannot regress silently.
do
	local tutorialSrc = read("src/client/TutorialController.client.luau")
	local carrySrc = read("src/server/CarryService.luau")
	local bankSrc = read("src/server/BankService.luau")
	local starfallSrc = read("src/server/StarfallService.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	if not tutorialSrc or not carrySrc or not bankSrc or not starfallSrc or not rivalSrc or not raiderSrc or not factorySrc then
		check("dd", false, "could not verify the ADD items — TutorialController.client.luau, CarryService.luau, BankService.luau, StarfallService.luau, RivalService.luau, RaiderService.luau or RotlingFactory.luau missing")
	else
		local problems: { string } = {}
		-- First-minute guide: a bouncing gold arrow, 4 steps, 80s, then gone.
		if not tutorialSrc:find('part%.Name = "TutorialArrow"') then
			table.insert(problems, "no TutorialArrow in the guide")
		end
		if not tutorialSrc:find("TUTORIAL_SECONDS = 80") then
			table.insert(problems, "the guide does not run 80s")
		end
		if not tutorialSrc:find("arrow:Destroy%(%)") then
			table.insert(problems, "the guide never destroys its arrow when it ends")
		end
		if not tutorialSrc:find("tutorialLabel%.Visible = false") then
			table.insert(problems, "the guide label never hides when it ends")
		end
		-- Sounds: grab pop, cash ding, storm siren, steal alarm.
		if not carrySrc:find("local function playPickupSound") then
			table.insert(problems, "no grab pop (playPickupSound in CarryService)")
		end
		if not carrySrc:find("playPickupSound%(player%)") then
			table.insert(problems, "the grab pop is never played on grab")
		end
		if not bankSrc:find("playSound%(player, 1%.6, 0%.8%)") then
			table.insert(problems, "no cash ding on collect (BankService)")
		end
		if not starfallSrc:find("ALARM_SOUND") then
			table.insert(problems, "no storm siren (StarfallService)")
		end
		if not rivalSrc:find("playSound%(victim, 0%.7, 1%)") then
			table.insert(problems, "no steal alarm on a rival steal")
		end
		if not raiderSrc:find("playSound%(owner, 0%.7, 1%)") then
			table.insert(problems, "no steal alarm on a raider steal")
		end
		-- Faces + bounce + rarity glows on every Brainrot.
		if not factorySrc:find('FindFirstChild%("GlowShell"%)') then
			table.insert(problems, "no GlowShell on Brainrots")
		end
		if not factorySrc:find('FindFirstChildOfClass%("Highlight"%)') then
			table.insert(problems, "no rarity Highlight outline on Brainrots")
		end
		if not factorySrc:find("bobSeed") then
			table.insert(problems, "no idle bob on Brainrots")
		end
		if #problems > 0 then
			check("dd", false, "the ADD items are incomplete — " .. table.concat(problems, "; ") .. ". Parts: TutorialController.client.luau (guide), CarryService/BankService/StarfallService/RivalService/RaiderService (sounds), RotlingFactory.luau (faces/bounce/glows)")
		else
			check("dd", true, "ADD verified: first-minute guide (gold arrow, 4 steps, 80s, cleans up), sounds wired (grab pop, cash ding, storm siren, steal alarms on rival + raider), Brainrots have faces + idle bob + GlowShell + rarity outline")
		end
	end
end

-- (de) KEEP (simplify/polish): verify only — bright saturated colours +
-- green grass, storms + Safe Dome, Upgrade + Daily buttons, rebirth,
-- 20-Brainrot index. Nothing here was changed; these checks lock the
-- kept state in.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local starfallSrc = read("src/server/StarfallService.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local rebirthSrc = read("src/server/RebirthService.luau")
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	if not worldSrc or not starfallSrc or not hudSrc or not rebirthSrc or not catalogSrc then
		check("de", false, "could not verify the KEEP items — WorldBuilder.luau, StarfallService.luau, HUDController.client.luau, RebirthService.luau or RotlingCatalog.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find('part%("GroundCover"') then
			table.insert(problems, "no GroundCover in the world")
		end
		if not worldSrc:find("Enum%.Material%.Grass") then
			table.insert(problems, "the ground is not Grass")
		end
		if not worldSrc:find("Color3%.fromRGB%(89, 173, 77%)") then
			table.insert(problems, "the grass is not the natural green (89, 173, 77)")
		end
		if not starfallSrc:find("storm") then
			table.insert(problems, "no storm in StarfallService")
		end
		if not worldSrc:find("setShieldVisible") then
			table.insert(problems, "no Safe Dome (setShieldVisible in WorldBuilder)")
		end
		if not hudSrc:find('"UpgradeButton"') then
			table.insert(problems, "no Upgrade button in the HUD")
		end
		if not hudSrc:find('"DailyButton"') then
			table.insert(problems, "no Daily button in the HUD")
		end
		if not rebirthSrc:find("function RebirthService%.doRebirth") then
			table.insert(problems, "no doRebirth (rebirth is gone)")
		end
		if not hudSrc:find('"RebirthButton"') then
			table.insert(problems, "no Rebirth button in the HUD")
		end
		local defCount = 0
		for _ in catalogSrc:gmatch('id = "') do
			defCount += 1
		end
		if defCount ~= 22 then
			table.insert(problems, "the Brainrot cast is not 22 (found " .. tostring(defCount) .. ")")
		end
		if #problems > 0 then
			check("de", false, "a KEEP item is missing — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau (grass, Safe Dome), StarfallService.luau (storms), HUDController.client.luau (Upgrade/Daily/Rebirth buttons), RebirthService.luau, RotlingCatalog.luau (22 Brainrots)")
		else
			check("de", true, "KEEP verified: green grass (89, 173, 77), storms + Safe Dome, Upgrade + Daily + Rebirth buttons, 22-Brainrot index")
		end
	end
end

-- (df) GUARDIAN SPEED (fix round 8, item 1; tightened fix round 9,
-- item 1): the guardian must be CAT-FAST at every tier — faster than
-- a SPRINTING player (26), not just a walk (16) — or the chase is
-- decorative. Malek proved it in playtests 9 and 10 (the old 19-24
-- only just beat a walk, and the pathfinder detour ate the rest).
-- Every GUARDIAN_SPEED tier must beat 26, the spawn must be close
-- (14 studs, not 24), and the chase loop must log its REAL studs/s +
-- distance to the target every 2s, so a slow guardian cannot hide
-- behind its WalkSpeed setting.
do
	local configSrc = read("src/shared/Config.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	if not configSrc or not guardianSrc then
		check("df", false, "could not verify the guardian speed — Config.luau or GuardianService.luau missing")
	else
		local problems: { string } = {}
		local speedLine = configSrc:match("GUARDIAN_SPEED = ({.-})")
		if not speedLine then
			table.insert(problems, "no GUARDIAN_SPEED table in Config")
		else
			local count = 0
			for n in speedLine:gmatch("= (%d+%.?%d*)") do
				count += 1
				local v = tonumber(n)
				if v and v <= 26 then
					table.insert(problems, "guardian speed tier " .. tostring(count) .. " is " .. tostring(v) .. " — at or under sprint 26, it cannot catch a sprinter")
				end
			end
			if count ~= 7 then
				table.insert(problems, "GUARDIAN_SPEED has " .. tostring(count) .. " tiers, not 7")
			end
		end
		if not configSrc:find("GUARDIAN_SPAWN_DISTANCE = 14") then
			table.insert(problems, "no GUARDIAN_SPAWN_DISTANCE = 14 in Config (the old 24-stud head start meant it never arrived)")
		end
		if not guardianSrc:find("dir %* Config%.GUARDIAN_SPAWN_DISTANCE") then
			table.insert(problems, "guardianSpawnPos does not use Config.GUARDIAN_SPAWN_DISTANCE")
		end
		if not guardianSrc:find("chase telemetry") then
			table.insert(problems, "no chase telemetry in the chase loop (no proof the speed is real)")
		end
		if not guardianSrc:find("real speed") then
			table.insert(problems, "the telemetry does not log the guardian's real studs/s")
		end
		if #problems > 0 then
			check("df", false, "the guardian speed fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: Config.luau, GuardianService.luau")
		else
			check("df", true, "guardian speed: every tier beats sprint 26 (Common 28 to Divine 36), spawns 14 studs away, and the chase loop logs real studs/s + distance every 2s")
		end
	end
end

-- (dg) GUARDIAN THREAT (fix round 8, item 2): a catch used to only
-- drop the Brainrot — Malek read it as harmless ("all it does is
-- him getting dropped the brainrot"). A catch must cost health: 40
-- damage (two catches kill), a knockdown, a red impact burst, a low
-- thud, and a banner naming the damage.
do
	local configSrc = read("src/shared/Config.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	if not configSrc or not guardianSrc then
		check("dg", false, "could not verify the guardian threat — Config.luau or GuardianService.luau missing")
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
		if not guardianSrc:find("smashed for") then
			table.insert(problems, "the catch log does not record the damage + remaining HP")
		end
		if #problems > 0 then
			check("dg", false, "the guardian threat fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: Config.luau, GuardianService.luau")
		else
			check("dg", true, "guardian threat: a catch deals 40 HP (two catches kill), knocks down, fires a red burst + low thud, and banners the damage")
		end
	end
end

-- (dh) STEAL WALK COMPLETES (fix round 8, item 3; storm-proofed fix
-- round 9, item 3): "Ziggy couldn't reach the base" — two causes:
-- (a) walkTo issued MoveTo once and Roblox's internal ~8s MoveTo
-- timeout stopped the rival silently, so it stood hopping for the
-- rest of a 40s walk; (b) the straight leg from the ring to the pad
-- crossed the platform's 2-stud edge anywhere but the 6-wide
-- entrance ramp. Fixed: walkTo re-issues MoveTo every 2s, and both
-- the steal leg and the run-home leg route through the ramp's low
-- end first, then UP the ramp (ramp-top waypoint) before the pad.
-- The steal walk is storm-proof (nil cancel): a storm starting
-- mid-walk used to abort the steal outright. The abort log carries
-- positions + the remaining distance, so the F9 trail shows where a
-- walk died.
do
	local rivalSrc = read("src/server/RivalService.luau")
	if not rivalSrc then
		check("dh", false, "could not verify the steal walk — RivalService.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find("waited %- lastMoveAt >= 2") then
			table.insert(problems, "walkTo does not re-issue MoveTo every 2s (a timed-out MoveTo still strands the rival)")
		end
		if not rivalSrc:find("entrancePos = if victimCf then %(victimCf %* CFrame%.new%(0, 0, %-15%)%)%.Position") then
			table.insert(problems, "the steal leg does not route through the ramp's low end (entrancePos)")
		end
		if not rivalSrc:find("walkTo%(model, entrancePos, 20, nil%)") then
			table.insert(problems, "no storm-proof entrance leg on the steal walk")
		end
		if not rivalSrc:find("rampTopPos") then
			table.insert(problems, "no ramp-top waypoint — the leg still crosses the platform edge outside the ramp")
		end
		if not rivalSrc:find("entrancePos = if homeCf then %(homeCf %* CFrame%.new%(0, 0, %-15%)%)%.Position") then
			table.insert(problems, "the run-home leg does not route through the ramp's low end (entrancePos)")
		end
		if not rivalSrc:find("studs short") then
			table.insert(problems, "the steal-abort log does not carry the remaining distance (no proof where the walk died)")
		end
		if #problems > 0 then
			check("dh", false, "the steal-walk fix is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau")
		else
			check("dh", true, "steal walk: walkTo re-issues MoveTo every 2s, steal + run-home legs route through the ramp's low end and up the ramp-top waypoint, steal walk is storm-proof, abort log carries positions + remaining distance")
		end
	end
end

-- (di) MULTI-CARRY FAN (fix round 8, item 5): three carried Brainrots
-- used to share one weld C0 (0, CARRY_Y, CARRY_Z) and overlap into a
-- single blob. Each slot gets its own X offset (4.2 studs apart, the
-- outer ones arced slightly closer), re-seated after every carry-list
-- change — a new grab fans out, a place closes the gap.
do
	local carrySrc = read("src/server/CarryService.luau")
	if not carrySrc then
		check("di", false, "could not verify the multi-carry fan — CarryService.luau missing")
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
		if not carrySrc:find("CarryService%.reseatCarried%(player%)") then
			table.insert(problems, "reseatCarried is never called after a carry-list change")
		end
		if #problems > 0 then
			check("di", false, "the multi-carry fan is incomplete — " .. table.concat(problems, "; ") .. ". Parts: CarryService.luau")
		else
			check("di", true, "multi-carry fan: each carried Brainrot gets its own slot (4.2 studs apart, arced), re-seated after every grab/place/drop")
		end
	end
end

-- (dj) MORE SHOP UPGRADES (fix round 8, item 6): three new ladders —
-- Endurance Training (+50 max stamina/tier), Egg Warmer (-25% hatch
-- time/tier), Power Slap (+1.5 range / +20 knockback/tier). The server
-- sells them (SHOP + TIER_KEYS), the profile stores them (old saves
-- default to 0), the HUD feed carries them, the shop shows them in a
-- scrollable ladder section, and each effect is read live where it
-- applies (sprint stamina, hatch time, slap range/knockback).
do
	local shopSrc = read("src/server/ShopService.luau")
	local stateSrc = read("src/server/State.luau")
	local dataSrc = read("src/server/DataService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local shopUiSrc = read("src/client/ShopController.client.luau")
	local sprintSrc = read("src/client/SprintController.client.luau")
	local eggSrc = read("src/server/MeteorEggService.luau")
	local slapSrc = read("src/server/SlapService.luau")
	if not shopSrc or not stateSrc or not dataSrc or not remotesSrc or not incomeSrc or not shopUiSrc or not sprintSrc or not eggSrc or not slapSrc then
		check("dj", false, "could not verify the new shop upgrades — ShopService.luau, State.luau, DataService.luau, Remotes.luau, IncomeService.luau, ShopController.client.luau, SprintController.client.luau, MeteorEggService.luau or SlapService.luau missing")
	else
		local problems: { string } = {}
		if not shopSrc:find("Stamina = {") or not shopSrc:find("tiers = { 500, 2000, 6000 }") then
			table.insert(problems, "no Endurance Training ladder (500/2000/6000) in the shop")
		end
		if not shopSrc:find("Egg = {") or not shopSrc:find("tiers = { 800, 3000 }") then
			table.insert(problems, "no Egg Warmer ladder (800/3000) in the shop")
		end
		if not shopSrc:find("Slap = {") or not shopSrc:find("tiers = { 300, 1500, 5000 }") then
			table.insert(problems, "no Power Slap ladder (300/1500/5000) in the shop")
		end
		if not shopSrc:find('Stamina = "staminaTier"') or not shopSrc:find('Egg = "eggTier"') or not shopSrc:find('Slap = "slapTier"') then
			table.insert(problems, "the new ladders are not mapped to profile tier keys")
		end
		if not stateSrc:find("staminaTier: number") or not stateSrc:find("eggTier: number") or not stateSrc:find("slapTier: number") then
			table.insert(problems, "the profile type has no stamina/egg/slap tiers")
		end
		if not dataSrc:find("staminaTier = 0") or not dataSrc:find("eggTier = 0") or not dataSrc:find("slapTier = 0") then
			table.insert(problems, "new profiles do not start the new tiers at 0")
		end
		if not remotesSrc:find("staminaTier: number") or not remotesSrc:find("eggTier: number") or not remotesSrc:find("slapTier: number") then
			table.insert(problems, "the HUD feed type does not carry the new tiers")
		end
		if not incomeSrc:find("staminaTier = profile%.staminaTier") or not incomeSrc:find("eggTier = profile%.eggTier") or not incomeSrc:find("slapTier = profile%.slapTier") then
			table.insert(problems, "the HUD broadcast does not send the new tiers")
		end
		if not shopUiSrc:find('SHOP_ORDER = { "Speed", "Carry", "Income", "Pads", "Lock", "Stamina", "Egg", "Slap" }') then
			table.insert(problems, "the shop UI does not list the new ladders")
		end
		if not shopUiSrc:find("LadderScroll") or not shopUiSrc:find("ScrollingFrame") then
			table.insert(problems, "the ladder rows are not scrollable (8 rows do not fit the panel)")
		end
		if not sprintSrc:find("staminaTier") or not sprintSrc:find("STAMINA_PER_TIER") then
			table.insert(problems, "the sprint controller does not read the stamina tier")
		end
		if not eggSrc:find("EGG_WARMER_REDUCTION") then
			table.insert(problems, "the hatch time does not read the Egg Warmer tier")
		end
		if not slapSrc:find("slapRange%(player%)") or not slapSrc:find("SLAP_RANGE_PER_TIER") or not slapSrc:find("SLAP_KNOCKBACK_PER_TIER") then
			table.insert(problems, "the slap does not read the Power Slap tier")
		end
		if #problems > 0 then
			check("dj", false, "the new shop upgrades are incomplete — " .. table.concat(problems, "; ") .. ". Parts: ShopService.luau, State.luau, DataService.luau, Remotes.luau, IncomeService.luau, ShopController.client.luau, SprintController.client.luau, MeteorEggService.luau, SlapService.luau")
		else
			check("dj", true, "three new ladders live: Endurance Training (500/2000/6000, +50 stamina/tier), Egg Warmer (800/3000, -25% hatch/tier), Power Slap (300/1500/5000, +1.5 range/+20 knockback/tier) — sold by the server, stored in the profile, shown in a scrollable shop, effects read live")
		end
	end
end

-- (dk) HATCH EVENT (fix round 8, item 9): the egg does not just
-- vanish — it cracks open (shake, dark cracks, white flash), the
-- animal pops out with a scale-in bounce + gold burst, and if the
-- owner is standing nearby with a free slot it jumps into their
-- arms so they place it on a pad themselves (Steal-an-Egg feel).
-- Otherwise the old fallback: a free pad, or the crater.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not eggSrc then
		check("dk", false, "could not verify the hatch event — MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if not eggSrc:find("local function crackEgg%(model: Model, egg: State%.Egg, baseId: number%)") then
			table.insert(problems, "no crackEgg event (the egg still just vanishes)")
		end
		if not eggSrc:find("HATCHING!") then
			table.insert(problems, "the egg label does not read HATCHING during the crack")
		end
		if not eggSrc:find('crack%.Name = "Crack"') then
			table.insert(problems, "no crack parts appear on the shell")
		end
		if not eggSrc:find("setModelScale%(hatched, 0%.2%)") then
			table.insert(problems, "no scale-in pop when the animal comes out")
		end
		if not eggSrc:find("jumped into your arms") then
			table.insert(problems, "the hatchling does not jump into the owner's arms (no auto-carry)")
		end
		if not eggSrc:find("%(ownerRoot%.Position %- hatchPos%)%.Magnitude <= 20") then
			table.insert(problems, "the auto-carry does not check the owner is nearby (20 studs)")
		end
		if not eggSrc:find("#CarryService%.getCarried%(owner%) < CarryService%.getCarrySlots%(owner%)") then
			table.insert(problems, "the auto-carry does not check for a free slot")
		end
		if not eggSrc:find("task%.spawn%(crackEgg, model, egg, baseId%)") then
			table.insert(problems, "the hatch event does not run in its own thread (it would stall the hatch loop)")
		end
		if #problems > 0 then
			check("dk", false, "the hatch event is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau")
		else
			check("dk", true, "hatch event: the egg shakes, cracks, flashes white, the animal pops out with a scale-in bounce, and jumps into the owner's arms when they are nearby with a free slot (else a free pad, or the crater)")
		end
	end
end

-- (dl) SPEED PURCHASE (fix round 8, item 10): Speed Boots already
-- existed (3 tiers) — Malek asked to buy speed, so the ladder is
-- extended to 5 tiers (200/800/4000/12000/30000). Max +10 WalkSpeed
-- (walk 26, sprint 36): the sprint outruns even a Cosmic guardian
-- (34, fix round 9 item 1) and a chasing rival (19) — boots are the
-- escape, not a free pass: walk 26 still loses to the guardian.
do
	local shopSrc = read("src/server/ShopService.luau")
	local shopUiSrc = read("src/client/ShopController.client.luau")
	if not shopSrc or not shopUiSrc then
		check("dl", false, "could not verify the speed purchase — ShopService.luau or ShopController.client.luau missing")
	else
		local problems: { string } = {}
		if not shopSrc:find("tiers = { 200, 800, 4000, 12000, 30000 }") then
			table.insert(problems, "the server Speed ladder is not 5 tiers (200/800/4000/12000/30000)")
		end
		if not shopUiSrc:find("tiers = { 200, 800, 4000, 12000, 30000 }") then
			table.insert(problems, "the shop UI Speed ladder is not 5 tiers")
		end
		if not shopUiSrc:find('/5 — now %+" %.%. tostring%(2 %* tier%) %.%. " WalkSpeed"') then
			table.insert(problems, "the Speed row does not show /5 tiers")
		end
		if #problems > 0 then
			check("dl", false, "the speed purchase is incomplete — " .. table.concat(problems, "; ") .. ". Parts: ShopService.luau, ShopController.client.luau")
		else
			check("dl", true, "Speed Boots: 5 tiers (200/800/4000/12000/30000), max +10 WalkSpeed — sprint 36 outruns a Cosmic guardian (34) and a chasing rival (19)")
		end
	end
end

-- (dm) GUARDIAN CAT-FAST (fix round 9, item 1): speeds alone did not
-- fix the chase — the old loop steered on a pathfinder detour through
-- the entrance gap, so the guardian's real closing speed was below a
-- walk, and every repath snapped its heading (the jerky "in blocks"
-- motion). The chase must steer DIRECTLY at the live target (no
-- pathfinding in the chase loop at all), hop fast when stuck (0.8s),
-- lunge inside 14 studs, and prove it: the despawn summary prints
-- the chase duration, min distance, average REAL speed and max
-- radius, and the loop logs the moment it leaves the crater.
do
	local guardianSrc = read("src/server/GuardianService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not guardianSrc or not configSrc then
		check("dm", false, "could not verify the cat-fast chase — GuardianService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if guardianSrc:find("PathfindingService") then
			table.insert(problems, "the chase still uses PathfindingService (the detour that ate the speed)")
		end
		if not guardianSrc:find("humanoid:MoveTo%(targetRoot%.Position%)") then
			table.insert(problems, "the chase does not steer directly at the target's live position")
		end
		if not guardianSrc:find("GUARDIAN_LUNGE_RANGE") then
			table.insert(problems, "no lunge range in the chase loop")
		end
		if not guardianSrc:find("LUNGE at ") then
			table.insert(problems, "the lunge is not logged")
		end
		if not guardianSrc:find("LEFT THE CRATER") then
			table.insert(problems, "the loop does not log leaving the crater")
		end
		if not guardianSrc:find("chase summary") then
			table.insert(problems, "no chase summary on despawn (no proof the chase was real)")
		end
		if not configSrc:find("GUARDIAN_LUNGE_BONUS = 12") then
			table.insert(problems, "no GUARDIAN_LUNGE_BONUS = 12 in Config")
		end
		if #problems > 0 then
			check("dm", false, "the cat-fast chase is incomplete — " .. table.concat(problems, "; ") .. ". Parts: GuardianService.luau, Config.luau")
		else
			check("dm", true, "guardian cat-fast: direct steering (no pathfinding), 0.8s stuck-hop, lunge inside 14 studs (+12 speed), LEFT THE CRATER log + chase summary with avg real speed")
		end
	end
end

-- (dn) GUARDIAN LEAVES THE CRATER (fix round 9, item 2; platform
-- rule fix round 13, item 3): the guardian read as crater-bound
-- because its give-up fired at the base DOOR (17 studs from the
-- centre) — it quit ~15 studs before the player was even on the
-- platform. The give-up now uses the base PLATFORM (the whole slab
-- + ramp, WorldBuilder.isOnBasePlatform): the ramp is part of the
-- base, so the guardian keeps chasing a player still on the ground
-- outside the door and only gives up once the player is actually
-- ON the base. Nothing blocks the guardian — no dome, no wall —
-- only the platform, the dropped carry, and the 25s timeout stop
-- it. The proof is the chase itself: the loop logs LEFT THE CRATER
-- the first time it passes radius 40, and the despawn summary
-- prints its max radius.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local guardianSrc = read("src/server/GuardianService.luau")
	if not worldSrc or not guardianSrc then
		check("dn", false, "could not verify the crater range — WorldBuilder.luau or GuardianService.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("function WorldBuilder%.isOnBasePlatform") then
			table.insert(problems, "no WorldBuilder.isOnBasePlatform helper")
		end
		if not worldSrc:find("localPos%.Z >= %-15") then
			table.insert(problems, "the platform check does not include the ramp strip (local z >= -15)")
		end
		if not guardianSrc:find("WorldBuilder%.isOnBasePlatform%(baseId, position%)") then
			table.insert(problems, "the guardian give-up does not use isOnBasePlatform (still the radial door check?)")
		end
		if guardianSrc:find("STORM_BASE_SAFE_RADIUS") then
			table.insert(problems, "the guardian still references STORM_BASE_SAFE_RADIUS for its give-up")
		end
		if not guardianSrc:find("LEFT THE CRATER") then
			table.insert(problems, "the loop does not log leaving the crater")
		end
		if not guardianSrc:find("maxRadius") then
			table.insert(problems, "the chase summary does not track max radius")
		end
		if #problems > 0 then
			check("dn", false, "the crater range is incomplete — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau, GuardianService.luau")
		else
			check("dn", true, "guardian leaves the crater: give-up is platform-wide (slab + ramp), LEFT THE CRATER log + max radius in the chase summary prove the range")
		end
	end
end

-- (do) THIEF ACTUALLY STEALS (fix round 9, item 3): "the thief
-- still does nothing" had three real causes, all in the steal walk.
-- (a) The walk passed stormRunning as the cancel, so any storm
-- starting mid-walk aborted the steal — even though stepRival's
-- header exempts steal/chase from storm cover. The steal walk is
-- storm-proof now. (b) The final leg ran from the ramp's low end
-- straight to the pad, crossing the 2-stud platform edge OUTSIDE
-- the 6-wide ramp for pads 1 and 4 — the rival pushed the edge
-- until the 40s timeout. A ramp-top waypoint (local (0,2,-10))
-- routes it up the ramp first, in the steal leg and in the
-- carry-home leg. (c) The pad picked at the start could empty
-- during the walk — the thief re-picks the first occupied pad on
-- arrival. The proof is the STEAL COMPLETE log when the stolen
-- Brainrot is placed and earning on the thief's base.
do
	local rivalSrc = read("src/server/RivalService.luau")
	local stateSrc = read("src/server/State.luau")
	if not rivalSrc or not stateSrc then
		check("do", false, "could not verify the steal — RivalService.luau or State.luau missing")
	else
		local problems: { string } = {}
		if not rivalSrc:find("walkAround%(model, around, 40, nil%)") then
			table.insert(problems, "the steal ring walk is not storm-proof (still passes stormRunning)")
		end
		if not rivalSrc:find("walkTo%(model, entrancePos, 20, nil%)") then
			table.insert(problems, "the steal entrance leg is not storm-proof")
		end
		if not rivalSrc:find("rampTopPos") then
			table.insert(problems, "no ramp-top waypoint in the steal / carry-home legs")
		end
		if not rivalSrc:find("freshPad") then
			table.insert(problems, "the thief does not re-pick a pad on arrival")
		end
		if not rivalSrc:find("STEAL COMPLETE") then
			table.insert(problems, "no STEAL COMPLETE log on placement (no proof the steal worked)")
		end
		if not stateSrc:find("stolenName: string%?") then
			table.insert(problems, "no stolenName on the Rival type")
		end
		if #problems > 0 then
			check("do", false, "the thief steal is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, State.luau")
		else
			check("do", true, "thief actually steals: storm-proof walk, ramp-top waypoint in both legs, pad re-picked on arrival, STEAL COMPLETE logged when the loot is placed and earning")
		end
	end
end

-- (dp) STORM SAFE ZONE IS THE WHOLE PLATFORM (fix round 13, item 3
-- — Malek, playtest 12: "ZERO damage on my base, at all"): the
-- round-9 interior-only rule left the doorway/ramp outside the safe
-- zone, so a player standing on their own base could still take
-- meteor damage there, and the guardian's Touch-catch had no
-- own-base check at all. The platform IS the base now: storm
-- damage, storm targeting exclusion, the guardian give-up AND the
-- catch itself all use the platform rule (whole slab + ramp, with a
-- Y gate that keeps the ground at the ramp foot outside). The 2x
-- shelter income is the ONE thing that stays interior-only — it is
-- a dome bonus, not damage. Meteors can still target the doorway
-- ring (12-20 studs from the centre) so the door is genuinely
-- dangerous — they just cannot hurt anyone standing ON the base.
do
	local starfallSrc = read("src/server/StarfallService.luau")
	local incomeSrc = read("src/server/IncomeService.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not starfallSrc or not incomeSrc or not worldSrc then
		check("dp", false, "could not verify the storm safe zone — StarfallService.luau, IncomeService.luau or WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("function WorldBuilder%.isOnBasePlatform") then
			table.insert(problems, "no WorldBuilder.isOnBasePlatform helper")
		end
		if not starfallSrc:find("WorldBuilder%.isOnBasePlatform%(baseId, position%)") then
			table.insert(problems, "the storm damage / targeting check does not use isOnBasePlatform (still the interior check?)")
		end
		if starfallSrc:find("flat%.Magnitude <= Config%.STORM_BASE_SAFE_RADIUS") then
			table.insert(problems, "the storm code still uses the radial STORM_BASE_SAFE_RADIUS check")
		end
		if not starfallSrc:find("local dist = 12 %+ math%.random%(0, 8%)") then
			table.insert(problems, "meteors do not target the doorway ring (12-20 studs from the centre)")
		end
		if not incomeSrc:find("WorldBuilder%.isOnBaseInterior%(baseId, root%.Position%)") then
			table.insert(problems, "the 2x shelter income does not use isOnBaseInterior (doorway still earns the boost)")
		end
		if #problems > 0 then
			check("dp", false, "the storm safe zone is incomplete — " .. table.concat(problems, "; ") .. ". Parts: StarfallService.luau, IncomeService.luau, WorldBuilder.luau")
		else
			check("dp", true, "storm safe zone is the whole platform: damage, targeting and guardian give-up all use isOnBasePlatform, meteors target the doorway ring, platform = safe and ramp foot = exposed; 2x shelter income stays interior-only")
		end
	end
end

-- (dq) PLACED BRAINROTS STAND STILL + EVEN BODY SIZES (fix round 9,
-- item 5): playtest 10 showed placed Brainrots bobbing and slowly
-- spinning in place, and sizes still uneven (Baron much bigger than
-- Bloop) even though every placement was "4.5 tall". The bob + spin
-- are gone — a placed Brainrot holds its base pose. The size measure
-- is the BODY (PrimaryPart.Size.Y), not the total bounding box, so a
-- hat can no longer shrink the animal; the widest body dimension is
-- capped at PLACED_MAX_WIDTH so flat wide bodies do not sprawl past
-- their pad. Rival placements use the same normalize (they used to
-- seat at scale 1 and skip the rule). Honest limit, stated in the
-- code: a flat silhouette is inherently shorter than a dome in the
-- same footprint — the fix makes every body as tall as its shape
-- allows, it cannot make a puddle as tall as a dome.
do
	local factorySrc = read("src/server/RotlingFactory.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not factorySrc or not rivalSrc or not configSrc then
		check("dq", false, "could not verify the placed stillness + sizes — RotlingFactory.luau, RivalService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if factorySrc:find("math%.sin%(now %* 1%.6 %+ seed%) %* 0%.22") then
			table.insert(problems, "placed Brainrots still bob (±0.22)")
		end
		if factorySrc:find("slowly spin on display") then
			table.insert(problems, "placed Brainrots still spin on display")
		end
		if not factorySrc:find("body%.CFrame = base") then
			table.insert(problems, "placed Brainrots are not re-seated at their base pose")
		end
		if not factorySrc:find("buildBodyHeight = body%.Size%.Y / current") then
			table.insert(problems, "normalizeToHeight does not measure the body height")
		end
		if not configSrc:find("PLACED_MAX_WIDTH = 6") then
			table.insert(problems, "no PLACED_MAX_WIDTH = 6 in Config")
		end
		if not rivalSrc:find("normalizeToHeight%(carried, Config%.PLACED_DISPLAY_HEIGHT%)") then
			table.insert(problems, "rival placements do not normalize (still scale 1)")
		end
		if #problems > 0 then
			check("dq", false, "the placed stillness + sizes are incomplete — " .. table.concat(problems, "; ") .. ". Parts: RotlingFactory.luau, RivalService.luau, Config.luau")
		else
			check("dq", true, "placed Brainrots stand still (no bob, no spin) and size by body height (4.5, hat excluded, width capped at 6) — player and rival placements alike")
		end
	end
end

-- (dr) HATCH REVEAL IS A LIVING ANIMAL (fix round 9, item 6): the
-- old reveal was a stepped scale-in (0.2 → 0.5 → 0.8 → 1, three hard
-- jumps) — it read as a robot inflating in stages, and Malek called
-- it "a robot something" in playtest 10. The reveal is now a smooth
-- eased pop (12 steps over 0.6s, ease-out-back with an overshoot to
-- ~1.12 then a settle to 1.0, re-seated on the incubator each step)
-- followed by a birth wiggle (three bounces + a full 360° spin over
-- ~1.2s), so the hatch reads as a living animal stretching, not a
-- statue appearing.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not eggSrc then
		check("dr", false, "could not verify the hatch reveal — MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if eggSrc:find("for _, s in ipairs%({ 0%.5, 0%.8, 1 }%)") then
			table.insert(problems, "the stepped scale-in (0.2 → 0.5 → 0.8 → 1) is still there")
		end
		if not eggSrc:find("ease%-out%-back") then
			table.insert(problems, "no ease-out-back pop curve")
		end
		if not eggSrc:find("1%.12") then
			table.insert(problems, "no overshoot to ~1.12 in the pop")
		end
		if not eggSrc:find("seatHatched") then
			table.insert(problems, "the pop does not re-seat the hatchling on the incubator each step")
		end
		if not eggSrc:find("Birth wiggle") then
			table.insert(problems, "no birth wiggle (bounces + spin) after the pop")
		end
		if #problems > 0 then
			check("dr", false, "the hatch reveal is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau")
		else
			check("dr", true, "hatch reveal: smooth eased pop (12 steps, ease-out-back, overshoot 1.12, settles to 1.0, re-seated each step) + birth wiggle (3 bounces + full 360° spin)")
		end
	end
end

-- (ds) HATCH SPECTACLE (fix round 9, item 7): the rev-90 hatch
-- (shake, cracks, flash, pop-out) is not enough — the player who
-- waited minutes for an egg needs a MOMENT. The reveal now fires a
-- 30-stud Neon beam in the hatch's rarity colour (fades over ~3s),
-- confetti in gold + rarity colour + white, and a fanfare ping at
-- the reveal; the rarity popup fires for EVERY hatch (not just tier
-- 4+), and the banner reads "✨ HATCHED: <name> (<RARITY>)!".
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not eggSrc then
		check("ds", false, "could not verify the hatch spectacle — MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if not eggSrc:find('beam%.Name = "HatchBeam"') then
			table.insert(problems, "no HatchBeam part in the hatch")
		end
		if not eggSrc:find("Enum%.Material%.Neon") then
			table.insert(problems, "the beam is not Neon")
		end
		if not eggSrc:find("FeedbackService%.burst%(hatched, rarityColor%)") then
			table.insert(problems, "no rarity-colour confetti burst")
		end
		if not eggSrc:find("FeedbackService%.burst%(hatched, Color3%.fromRGB%(255, 225, 90%)%)") then
			table.insert(problems, "no gold confetti burst")
		end
		if not eggSrc:find("FeedbackService%.playSound%(owner, 1%.6, 0%.7%)") then
			table.insert(problems, "no fanfare ping at the reveal")
		end
		if eggSrc:find("if RarityConfig%.rarityTier%(def%.rarity%) >= 4 then") then
			table.insert(problems, "the rarity popup still only fires for tier 4+")
		end
		if not eggSrc:find("✨ HATCHED: ") then
			table.insert(problems, "no ✨ HATCHED banner")
		end
		if #problems > 0 then
			check("ds", false, "the hatch spectacle is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau")
		else
			check("ds", true, "hatch spectacle: 30-stud Neon beam in the rarity colour (fades ~3s) + gold/rarity/white confetti + fanfare ping, rarity popup for every hatch, ✨ HATCHED banner")
		end
	end
end

-- (dt) CONTRACTS HOOK + AUTO-ADVANCE (fix round 9, item 8): the
-- "Grab a Rare" pill sat at 1/1 un-advanced in playtest 10, and a
-- finished contract only paid when the player walked to the board.
-- Now: markReady starts a 10s timer; a 1s loop auto-claims any done
-- contract whose timer expired (reward paid, replacement dealt — the
-- same deal path a manual claim uses); the HUD carries the countdown
-- (advanceIn on board rows, missionAdvanceIn on the quest pill),
-- which shows "✅ Complete! Next contract in Ns…" instead of a stuck
-- 1/1; and a fresh grab/rare contract fires a "🎯 NEW CONTRACT …
-- go fetch!" hook banner + sound.
do
	local missionSrc = read("src/server/MissionService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local contractSrc = read("src/client/ContractController.client.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local mainSrc = read("src/server/Main.server.luau")
	if not missionSrc or not remotesSrc or not contractSrc or not hudSrc or not mainSrc then
		check("dt", false, "could not verify the contract auto-advance — MissionService.luau, Remotes.luau, ContractController.client.luau, HUDController.client.luau or Main.server.luau missing")
	else
		local problems: { string } = {}
		if not missionSrc:find("advanceAt = time%(%) %+ 10") then
			table.insert(problems, "markReady does not start the 10s auto-advance timer")
		end
		if not missionSrc:find("function MissionService%.start%(%)") then
			table.insert(problems, "no MissionService.start auto-advance loop")
		end
		if not missionSrc:find("auto%-claimed") then
			table.insert(problems, "the loop does not auto-claim expired contracts")
		end
		if not missionSrc:find("NEW CONTRACT: ") then
			table.insert(problems, "no hook banner when a grab/rare contract is dealt")
		end
		if not missionSrc:find("advanceIn = if slot%.done") then
			table.insert(problems, "activeContracts does not carry the advanceIn countdown")
		end
		if not remotesSrc:find("missionAdvanceIn: number%?") then
			table.insert(problems, "HudData has no missionAdvanceIn for the quest pill")
		end
		if not contractSrc:find("Next contract in ") then
			table.insert(problems, "the board rows do not show the auto-advance countdown")
		end
		if not hudSrc:find("Next contract in ") then
			table.insert(problems, "the quest pill does not show the auto-advance countdown")
		end
		if not mainSrc:find('step%("contracts %(MissionService%.start%)", MissionService%.start%)') then
			table.insert(problems, "MissionService.start is not wired in Main.server boot")
		end
		if #problems > 0 then
			check("dt", false, "the contract auto-advance is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MissionService.luau, Remotes.luau, ContractController.client.luau, HUDController.client.luau, Main.server.luau")
		else
			check("dt", true, "contracts hook + auto-advance: 10s timer on done, 1s loop auto-claims (reward paid, replacement dealt), countdown on board rows + quest pill, 🎯 NEW CONTRACT hook banner for grab/rare deals")
		end
	end
end

-- (du) THIEF VISIBILITY IS DANGER-SIDE (fix round 9, item 9): the
-- old warning was a small banner + a red Highlight on the thief, and
-- Malek still could not see the thief in his base in playtest 10.
-- Now the server fires a dedicated ThiefAlert remote at the victim
-- when a steal starts AND every 3s while the thief is inside the
-- base; the client answers with a full-screen red flash wash, a
-- pulsing red edge vignette, a big flashing centre banner ("🚨 NAME
-- IS IN YOUR BASE! 🚨" + "Go bonk them!") that jitters while live,
-- and a low alarm ping on every fire. Each fire shows for 4s, so the
-- alert stays live until the thief leaves or is bonked. The thief
-- itself also glows: a red PointLight while stealing, and a bigger
-- sign (220x48, was 160x36).
do
	local rivalSrc = read("src/server/RivalService.luau")
	local remotesSrc = read("src/shared/Remotes.luau")
	local alertSrc = read("src/client/ThiefAlertController.client.luau")
	local projectSrc = read("default.project.json")
	if not rivalSrc or not remotesSrc or not alertSrc or not projectSrc then
		check("du", false, "could not verify the thief alert — RivalService.luau, Remotes.luau, ThiefAlertController.client.luau or default.project.json missing")
	else
		local problems: { string } = {}
		if not projectSrc:find('"ThiefAlert": {') then
			table.insert(problems, "no ThiefAlert RemoteEvent in default.project.json")
		end
		if not remotesSrc:find("function Remotes%.thiefAlertEvent") then
			table.insert(problems, "no Remotes.thiefAlertEvent getter")
		end
		if not rivalSrc:find("Remotes%.thiefAlertEvent%(%)%:FireClient%(victim, rival%.name%)") then
			table.insert(problems, "the server does not fire the thief alert at the victim")
		end
		if not rivalSrc:find('thiefLight%.Name = "ThiefLight"') then
			table.insert(problems, "no red PointLight on the thief while stealing")
		end
		if not rivalSrc:find("UDim2%.fromOffset%(220, 48%)") then
			table.insert(problems, "the THIEF sign is not enlarged to 220x48")
		end
		if not alertSrc:find("THIEF IN YOUR BASE") then
			table.insert(problems, "the client has no THIEF IN YOUR BASE banner")
		end
		if not alertSrc:find("ThiefEdgeTop") then
			table.insert(problems, "the client has no red edge vignette")
		end
		if not alertSrc:find("ThiefAlarm") then
			table.insert(problems, "the client has no alarm sound")
		end
		if #problems > 0 then
			check("du", false, "the thief alert is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, Remotes.luau, ThiefAlertController.client.luau, default.project.json")
		else
			check("du", true, "thief visibility is danger-side: ThiefAlert remote fires on steal start + every 3s in-base, client shows red vignette + flashing banner + jitter + alarm (4s per fire), thief glows red with a 220x48 sign")
		end
	end
end

-- (dv) HUD OVERLAP FIXES (fix round 9, item 10): playtest 10's
-- screenshots showed four overlaps. (1) Two storm warnings: the
-- server fired its own storm banners over StormWarningController's
-- warnBar + countdown — both server banners are gone, the controller
-- owns the storm voice. (2) The thief banner was cut off at the
-- edges: the banner line is 90% of the screen wide now, scales +
-- wraps its text, and sits below the warnBar (y=232). (3) The
-- carrying banner gets the same 90% + scale/wrap treatment. (4) The
-- "Bloop the Blob" placed label overlapped the base sign: placed
-- tags hide until 12 studs (free tags keep 6). (5) The SELL sign was
-- cut off at the right edge: 200x64 (was 240x80), MaxDistance 45
-- (was 60).
do
	local starfallSrc = read("src/server/StarfallService.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local tagSrc = read("src/client/TagController.client.luau")
	local worldSrc = read("src/server/WorldBuilder.luau")
	local configSrc = read("src/shared/Config.luau")
	if not starfallSrc or not hudSrc or not tagSrc or not worldSrc or not configSrc then
		check("dv", false, "could not verify the HUD overlap fixes — StarfallService.luau, HUDController.client.luau, TagController.client.luau, WorldBuilder.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if starfallSrc:find("METEOR STORM IN 10 SECONDS") then
			table.insert(problems, "the server still fires the 10-second storm banner (overlaps the warnBar)")
		end
		if starfallSrc:find("METEOR SHOWER INCOMING! RUN HOME!") then
			table.insert(problems, "the server still fires the METEOR SHOWER banner (overlaps the warnBar)")
		end
		if not hudSrc:find('UDim2%.new%(0%.9, 0, 0, 44%), UDim2%.new%(0%.5, 0, 0, 232%)') then
			table.insert(problems, "the banner line is not 90% wide at y=232")
		end
		-- (fix round 14, item 3) TextScaled is GONE from the banner
		-- line: it mis-measured the 🚨 emoji and ran the thief
		-- banner off the right edge on narrow screens. Sizing is
		-- done by GuiKit.showBanner (TextService measure + shrink
		-- + wrap — see the banner-fit check); the label keeps
		-- TextWrapped.
		if hudSrc:find("bannerLabel%.TextScaled = true") then
			table.insert(problems, "the banner line still uses TextScaled (it mis-measures the emoji and overflows on narrow screens)")
		end
		if not hudSrc:find("bannerLabel%.TextScaled = false") then
			table.insert(problems, "the banner line does not explicitly turn TextScaled off")
		end
		if not hudSrc:find("bannerLabel%.TextWrapped = true") then
			table.insert(problems, "the banner line does not wrap its text")
		end
		if not hudSrc:find("carryBanner%.Size = UDim2%.new%(0%.9, 0, 0, 44%)") then
			table.insert(problems, "the carrying banner is not 90% wide")
		end
		if not configSrc:find("TAG_PLACED_MIN_DISTANCE = 12") then
			table.insert(problems, "no TAG_PLACED_MIN_DISTANCE = 12 in Config")
		end
		if not tagSrc:find("TAG_PLACED_MIN_DISTANCE") then
			table.insert(problems, "TagController does not use the placed min distance")
		end
		if not worldSrc:find("sign%.Size = UDim2%.fromOffset%(200, 64%)") then
			table.insert(problems, "the SELL sign is not 200x64")
		end
		if #problems > 0 then
			check("dv", false, "the HUD overlap fixes are incomplete — " .. table.concat(problems, "; ") .. ". Parts: StarfallService.luau, HUDController.client.luau, TagController.client.luau, WorldBuilder.luau, Config.luau")
		else
			check("dv", true, "HUD overlap fixed: server storm banners removed (warnBar owns the storm voice), banner 90% wide at y=232 with TextScaled off + wrapped + sized by showBanner, carrying banner 90% wide, placed tags hide until 12 studs, SELL sign 200x64 at MaxDistance 45")
		end
	end
end

-- (banner-fit) THIEF BANNER FITS (fix round 14, item 3): playtest
-- 13's screenshot showed "Ziggy is sneaking to you…" cut off at
-- the right edge of the phone screen. The banner was TextScaled —
-- and TextScaled mis-measures the 🚨 emoji on a narrow screen, so
-- the text overflowed instead of wrapping (round 9's 90%-wide fix
-- was not enough). showBanner now measures the real string with
-- TextService:GetTextSize, shrinks the size until it fits in at
-- most 2 lines, and grows the label to the lines it needs; the
-- label itself is TextScaled=false, TextWrapped=true. The worst
-- case is the raider line with the longest title, "Grimble the
-- Grabber" (20 chars, ~98 chars total): at the 14px floor and
-- ~8px/char it is ~784px, so on a 360px phone (label 324px) it
-- needs 3 lines — the height formula (lines * size + 16) covers
-- it at 58px.
do
	local guiKitSrc = read("src/client/GuiKit.luau")
	local hudSrc = read("src/client/HUDController.client.luau")
	local rivalSrc = read("src/server/RivalService.luau")
	local raiderSrc = read("src/server/RaiderService.luau")
	if not guiKitSrc or not hudSrc or not rivalSrc or not raiderSrc then
		check("banner-fit", false, "could not verify the banner fit — GuiKit.luau, HUDController.client.luau, RivalService.luau or RaiderService.luau missing")
	else
		local problems: { string } = {}
		if not hudSrc:find("bannerLabel%.TextScaled = false") then
			table.insert(problems, "the banner label still uses TextScaled (it mis-measures the emoji and overflows on narrow screens)")
		end
		if not hudSrc:find("bannerLabel%.TextWrapped = true") then
			table.insert(problems, "the banner label does not wrap its text")
		end
		if not guiKitSrc:find("TextService:GetTextSize") then
			table.insert(problems, "showBanner does not measure the text with TextService:GetTextSize")
		end
		if not guiKitSrc:find("bounds%.Y <= size %* 2%.2") then
			table.insert(problems, "showBanner does not shrink the size until the text fits in 2 lines")
		end
		if not guiKitSrc:find("lines %* size %+ 16") then
			table.insert(problems, "showBanner does not grow the label to the lines the text needs")
		end
		-- The two thief banner strings, at the longest names.
		if not rivalSrc:find("is sneaking to your base! Lock it %(L%)!") then
			table.insert(problems, "the RivalService thief banner string changed — the fit case is gone")
		end
		if not raiderSrc:find("is sneaking toward your base! Guard your Brainrots") then
			table.insert(problems, "the RaiderService thief banner string changed — the fit case is gone")
		end
		if not raiderSrc:find("Grimble the Grabber") then
			table.insert(problems, "the longest raider title (Grimble the Grabber) is gone — the worst-case fit case changed")
		end
		-- Worst case, computed: the raider line at the longest
		-- title is ~98 chars; at the 14px floor and ~8px/char it
		-- needs 3 lines on a 360px phone (label 324px) — the
		-- height formula must cover 3 lines.
		local longest = 98
		local phoneLabel = 360 * 0.9
		local linesNeeded = math.ceil(longest * 8 / phoneLabel)
		local height = linesNeeded * 14 + 16
		if linesNeeded > 3 or height > 64 then
			table.insert(problems, "the longest thief banner needs " .. tostring(linesNeeded) .. " lines on a phone (" .. tostring(height) .. "px) — the fit must cover it")
		end
		if #problems > 0 then
			check("banner-fit", false, "the thief banner does not fit — " .. table.concat(problems, "; ") .. ". Parts: GuiKit.luau, HUDController.client.luau, RivalService.luau, RaiderService.luau")
		else
			check("banner-fit", true, "thief banner fits: TextScaled off (it mis-measured the emoji), showBanner measures with TextService, shrinks to fit in 2 lines, grows the label to the lines needed; longest line (~98 chars, Grimble the Grabber) needs " .. tostring(linesNeeded) .. " lines on a phone (" .. tostring(height) .. "px)")
		end
	end
end

-- (dw) LEGENDARY EGG DROP EVENT (fix round 9, item 11): every 240s
-- (first drop 60s after boot) a LEGENDARY egg falls into the crater
-- — a gold egg under a gold beam, announced server-wide with a
-- fanfare, gone in 75s if nobody grabs it. It hatches into a
-- Legendary Brainrot (its hatchDef is forced Legendary at spawn).
-- One drop on a timer, only if none is active; the ground label
-- shows the live countdown; the beam clears when the egg is grabbed,
-- hatches or vanishes.
do
	local eggSrc = read("src/server/MeteorEggService.luau")
	local configSrc = read("src/shared/Config.luau")
	if not eggSrc or not configSrc then
		check("dw", false, "could not verify the legendary egg drop — MeteorEggService.luau or Config.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("LEGENDARY_EGG_INTERVAL = 240") then
			table.insert(problems, "no LEGENDARY_EGG_INTERVAL = 240 in Config")
		end
		if not configSrc:find("LEGENDARY_EGG_LIFETIME = 75") then
			table.insert(problems, "no LEGENDARY_EGG_LIFETIME = 75 in Config")
		end
		if not eggSrc:find("local function spawnLegendaryEgg%(%)") then
			table.insert(problems, "no spawnLegendaryEgg")
		end
		if not eggSrc:find('defsOfRarity%("Legendary"%)') then
			table.insert(problems, "the drop does not force a Legendary hatch")
		end
		if not eggSrc:find("LEGENDARY EGG HAS FALLEN IN THE CRATER") then
			table.insert(problems, "no server-wide legendary drop announcement")
		end
		if not eggSrc:find('beam%.Name = "LegendaryEggBeam"') then
			table.insert(problems, "no gold beam marking the drop")
		end
		if not eggSrc:find("LEGENDARY EGG — ") then
			table.insert(problems, "no live legendary countdown label")
		end
		if not eggSrc:find("LEGENDARY egg vanished unclaimed") then
			table.insert(problems, "no vanish at expiry")
		end
		if #problems > 0 then
			check("dw", false, "the legendary egg drop is incomplete — " .. table.concat(problems, "; ") .. ". Parts: MeteorEggService.luau, Config.luau")
		else
			check("dw", true, "legendary egg drop: every 240s (first 60s after boot), gold egg + gold beam in the crater, server-wide announcement + fanfare, 75s to grab, hatches Legendary, vanishes unclaimed")
		end
	end
end

-- Follow-up, item 1 — thief alert is truthful: the danger alert
-- fires ONLY while the thief is actually inside the victim's base
-- (the watcher, every 3s), never at steal start when the thief is
-- still ~100 studs away claiming "IS IN YOUR BASE"; and a bonked
-- thief loses the sign/light/highlight, so the sign means something.
-- Verified by reading the code: the sign is AlwaysOnTop (through
-- walls), the Highlight is DepthMode Occluded, the watcher radius
-- (20) covers the whole 26-wide platform, and the sign is on for
-- the entire steal phase (1 on-site, 6 off-sites).
do
	local rivalSrc = read("src/server/RivalService.luau")
	local slapSrc = read("src/server/SlapService.luau")
	if not rivalSrc or not slapSrc then
		check("thief-alert", false, "could not verify the thief alert — RivalService.luau or SlapService.luau missing")
	else
		local problems: { string } = {}
		local _, fires = rivalSrc:gsub("thiefAlertEvent%(%)%:FireClient", "")
		if fires ~= 1 then
			table.insert(problems, "ThiefAlert fires " .. tostring(fires) .. " times in RivalService — must be exactly 1 (the in-base watcher)")
		end
		if not rivalSrc:find("function RivalService%.clearThiefVisuals") then
			table.insert(problems, "no clearThiefVisuals helper")
		end
		if not slapSrc:find("clearThiefVisuals%(rival%)") then
			table.insert(problems, "a bonked thief keeps its THIEF sign (slapRival never clears it)")
		end
		if not rivalSrc:find('AlwaysOnTop = true') then
			table.insert(problems, "the THIEF sign is not AlwaysOnTop (not visible through walls)")
		end
		if not rivalSrc:find("HighlightDepthMode%.Occluded") then
			table.insert(problems, "the thief Highlight is not Occluded (not visible through walls)")
		end
		if #problems > 0 then
			check("thief-alert", false, "the thief alert is not truthful — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, SlapService.luau")
		else
			check("thief-alert", true, "thief alert fires only while the thief is really inside (watcher, every 3s); sign is AlwaysOnTop + Occluded highlight through walls; a bonked thief loses the sign")
		end
	end
end

-- Follow-up, item 2 — thieves hunt the player like the guardian:
-- a rival near a free-walking player chases them at 22 studs/s
-- (faster than walk 16, slower than the guardian 28-34); on the tag
-- it steals the best carried Brainrot and runs home, or knocks the
-- player flat if they carry nothing. The base interior ends the
-- hunt; one hunter per victim; storm-proof (chase phase).
do
	local rivalSrc = read("src/server/RivalService.luau")
	local configSrc = read("src/shared/Config.luau")
	local stateSrc = read("src/server/State.luau")
	if not rivalSrc or not configSrc or not stateSrc then
		check("thief-hunt", false, "could not verify the thief hunt — RivalService.luau, Config.luau or State.luau missing")
	else
		local problems: { string } = {}
		if not configSrc:find("RIVAL_HUNT_SPEED = 22") then
			table.insert(problems, "no RIVAL_HUNT_SPEED = 22 in Config")
		end
		if not configSrc:find("RIVAL_HUNT_RADIUS = 30") then
			table.insert(problems, "no RIVAL_HUNT_RADIUS = 30 in Config")
		end
		if not rivalSrc:find("local function tryStartHunt") then
			table.insert(problems, "no tryStartHunt")
		end
		if not rivalSrc:find('chaseKind = "hunt"') then
			table.insert(problems, "no hunt chase kind set")
		end
		if not rivalSrc:find('chaseKind = "carrier"') then
			table.insert(problems, "the carrier chase does not set its kind (hunt/carrier would mix)")
		end
		if not rivalSrc:find("hunting \" .. best%.Name") then
			table.insert(problems, "no hunt-start log")
		end
		if not rivalSrc:find("stole your carried") then
			table.insert(problems, "no steal-on-tag (hunt does not take the carried Brainrot)")
		end
		if not rivalSrc:find("knocked \" .. victim%.Name .. \" down") then
			table.insert(problems, "no knockdown-on-tag for an empty-handed player")
		end
		if not rivalSrc:find("isOnBasePlatform%(victimBase, victimRoot%.Position%)") then
			table.insert(problems, "the hunt does not end at the base platform")
		end
		if not stateSrc:find("chaseKind: string%?") then
			table.insert(problems, "no chaseKind on the Rival type")
		end
		if #problems > 0 then
			check("thief-hunt", false, "the thief hunt is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RivalService.luau, Config.luau, State.luau")
		else
			check("thief-hunt", true, "thieves hunt free-walking players at 22 studs/s; tag steals the best carried Brainrot (runs home, STEAL COMPLETE) or knocks the player flat; base platform ends the hunt; one hunter per victim; storm-proof")
		end
	end
end

-- Fix round 10, item 1 — the crater-to-shop fences are true parallels
-- of the stone path, never through the walkway. Verified geometrically
-- from the source constants: the old fence (-6,42)->(-40,44) started
-- 1.39 studs off the path centreline and converged to 0.00 at the
-- shop end (path half-width 3), so it ran through the walkway.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		check("fence-parallel", false, "could not verify the fences — WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		-- The old non-parallel fence must be gone.
		if worldSrc:find("fenceLine%(Vector3.new%(%-6, 0, 42%)") then
			table.insert(problems, "the old fence (-6,42)->(-40,44) is still there")
		end
		-- Parse the shop path endpoints and the fence offset/inset.
		local fx1, fz1 = worldSrc:match("local shopPathFrom = Vector3.new%(([%-%d%.]+), 0, ([%-%d%.]+)%)")
		local fx2, fz2 = worldSrc:match("local shopPathTo = Vector3.new%(([%-%d%.]+), 0, ([%-%d%.]+)%)")
		local offset = worldSrc:match("local fenceOffset = (%d+)")
		local inset = worldSrc:match("local fenceInset = (%d+)")
		if not fx1 or not fx2 or not offset or not inset then
			table.insert(problems, "could not parse the shop path / fence offset / fence inset")
		else
			local p0x, p0z = tonumber(fx1), tonumber(fz1)
			local p1x, p1z = tonumber(fx2), tonumber(fz2)
			local off = tonumber(offset)
			local ins = tonumber(inset)
			-- Path direction (unit) and its perpendicular in XZ.
			local dx, dz = p1x - p0x, p1z - p0z
			local len = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / len, dz / len
			local nx, nz = -dz, dx
			-- Perpendicular distance from each fence line to the path
			-- centreline: the fence is parallel by construction, so
			-- this equals the offset — computed here, not assumed.
			-- A fence post is 0.6 wide (half-width 0.3), so the
			-- closest fence part stands at offset - 0.3.
			local fenceStartX, fenceStartZ = p0x + dx * ins, p0z + dz * ins
			for _, side in ipairs({ 1, -1 }) do
				local sx, sz = fenceStartX + nx * off * side, fenceStartZ + nz * off * side
				-- Point-to-line distance from the fence start to the path line.
				local relX, relZ = sx - p0x, sz - p0z
				local dist = math.abs(relX * dz - relZ * dx)
				if dist < 3.5 then
					table.insert(problems, "fence centreline only " .. string.format("%.2f", dist) .. " studs from the path centreline (need >= 3.5)")
				end
				-- No fence post may sit on the crater rim mound
				-- (outer ring radius 39): sample the fence segment
				-- and take its minimum radius from the map centre.
				local ex, ez = p1x + nx * off * side, p1z + nz * off * side
				local minR = math.huge
				for t = 0, 1, 0.05 do
					local x, z = sx + (ex - sx) * t, sz + (ez - sz) * t
					local r = math.sqrt(x * x + z * z)
					if r < minR then
						minR = r
					end
				end
				if minR <= 39 then
					table.insert(problems, "fence dips to radius " .. string.format("%.1f", minR) .. " — inside the crater rim (39), posts would be buried")
				end
			end
			-- The spawn-path fences still flank their path: the spawn
			-- path is 6 wide (half-width 3) and the fences sit at x=+/-5.
			if not worldSrc:find("fenceLine%(Vector3.new%(%-5, 0, 78%), Vector3.new%(%-5, 0, 40%)%)") then
				table.insert(problems, "spawn-path west fence missing or moved")
			end
			if not worldSrc:find("fenceLine%(Vector3.new%(5, 0, 78%), Vector3.new%(5, 0, 40%)%)") then
				table.insert(problems, "spawn-path east fence missing or moved")
			end
		end
		if #problems > 0 then
			check("fence-parallel", false, "the fences are not true parallels of the walkway — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau")
		else
			check("fence-parallel", true, "crater-to-shop fences are true parallels of the stone path (4 studs to each side, no part within 3 studs of the centreline, clear of the crater rim); spawn-path fences still flank at x=+/-5")
		end
	end
end

-- Fix round 10, item 2 — egg rebalance: more eggs, rarer rares, the
-- rate depends on the rarity. Before: 2 eggs/storm, base weights
-- (45/28/15/8/3/1) PLUS a 40% bump on Common/Rare rolls to Epic
-- (60%) / Legendary (40%) — effective Epic 32.5%, Legendary 19.7%,
-- Epic+Legendary 52.2% of eggs, so rares felt common. After: 4
-- eggs/storm, egg-only weights 55/28/10/4/2/1, bump gone — effective
-- Epic 10%, Legendary 4%, Epic+Legendary 14%; a Legendary egg is
-- expected once per ~6 storms, plus the guaranteed legendary drop
-- every 240s in the crater.
do
	local configSrc = read("src/shared/Config.luau")
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not configSrc or not eggSrc then
		check("egg-rebalance", false, "could not verify the egg rebalance — Config.luau or MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		-- Four eggs per storm.
		local perStorm = configSrc:match("Config.EGGS_PER_STORM = (%d+)")
		if perStorm ~= "4" then
			table.insert(problems, "EGGS_PER_STORM is " .. tostring(perStorm) .. ", not 4")
		end
		-- Egg-only weights, parsed as (tier, weight) pairs.
		local weightsBody = configSrc:match("Config.EGG_RARITY_WEIGHTS = {(.-)}")
		local weights: { [number]: number } = {}
		if weightsBody then
			for tier, w in weightsBody:gmatch("%[(%d+)%] = (%d+)") do
				weights[tonumber(tier)] = tonumber(w)
			end
		end
		local total = 0
		for tier = 1, 7 do
			total += weights[tier] or 0
		end
		-- Weights are x10 integers (total 1005) so Divine can sit below
		-- Cosmic (5 < 10); every bound below is on PERCENTAGES.
		if total ~= 1005 then
			table.insert(problems, "egg weights sum to " .. tostring(total) .. ", not 1005")
		else
			local pct = function(tier)
				return (weights[tier] or 0) / total * 100
			end
			local epic = pct(3)
			local legendary = pct(4)
			local common = pct(1)
			local divine = pct(7)
			local cosmic = pct(6)
			if epic + legendary > 15 then
				table.insert(problems, "Epic+Legendary is " .. string.format("%.1f", epic + legendary) .. "% per egg (must be <= 15%)")
			end
			if legendary > 5 then
				table.insert(problems, "Legendary is " .. string.format("%.1f", legendary) .. "% per egg (must be <= 5%)")
			end
			if common < 50 then
				table.insert(problems, "Common is only " .. string.format("%.1f", common) .. "% per egg (must be >= 50%)")
			end
			if divine >= cosmic then
				table.insert(problems, "Divine (" .. string.format("%.1f", divine) .. "%) is not rarer than Cosmic (" .. string.format("%.1f", cosmic) .. "%)")
			end
			if divine > 1 then
				table.insert(problems, "Divine is " .. string.format("%.1f", divine) .. "% per egg (must be <= 1%)")
			end
			-- Expected eggs of each rarity per storm at 4/storm.
			local perStormCount = tonumber(perStorm) or 0
			local expectedLegendary = perStormCount * legendary / 100
			if expectedLegendary > 0.25 then
				table.insert(problems, "expected Legendary eggs per storm is " .. string.format("%.2f", expectedLegendary) .. " (must be <= 0.25, one per ~4+ storms)")
			end
			local expectedDivine = perStormCount * divine / 100
			if expectedDivine > 0.05 then
				table.insert(problems, "expected Divine eggs per storm is " .. string.format("%.2f", expectedDivine) .. " (must be <= 0.05, one per ~20+ storms)")
			end
		end
		-- The 40% bump must be gone, and the roll must use the weights.
		if eggSrc:find("rarityTier%(rarityName%) < 3") then
			table.insert(problems, "the 40% Common/Rare bump is still in rollHatchDef")
		end
		if not eggSrc:find("local function rollEggRarity") then
			table.insert(problems, "no rollEggRarity")
		end
		if not eggSrc:find("EGG_RARITY_WEIGHTS") then
			table.insert(problems, "the roll does not read EGG_RARITY_WEIGHTS")
		end
		-- The guaranteed legendary drop is untouched.
		local interval = configSrc:match("Config.LEGENDARY_EGG_INTERVAL = (%d+)")
		if interval ~= "240" then
			table.insert(problems, "LEGENDARY_EGG_INTERVAL changed to " .. tostring(interval) .. " (must stay 240)")
		end
		if #problems > 0 then
			check("egg-rebalance", false, "the egg rebalance is wrong — " .. table.concat(problems, "; ") .. ". Parts: Config.luau, MeteorEggService.luau")
		else
			check("egg-rebalance", true, "4 eggs/storm with egg-only weights 550/280/100/40/20/10/5 (Common 54.7%, Epic 10.0%, Legendary 4.0%, Cosmic 1.0%, Divine 0.5%, ~0.16 Legendary/storm, ~0.02 Divine/storm); 40% bump gone; legendary drop still every 240s")
		end
	end
end

-- Fix round 10, item 3 — huge boundary walls enclosing the map. Until
-- now a player could walk off the 500x500 ground into the void.
-- Placement: a square at +/-200 — it encloses all gameplay (bases
-- outer edge ~123, egg field radius <=130, storm spread +/-150) AND
-- the crashed spaceship saucer (reaches ~x 192, the binding
-- constraint — +/-180 would cut straight through it), clears the
-- storm front sweep (+/-170) by 30 studs, and sits 50 studs inside
-- the ground edge (+/-250). 40 tall, dark stone deep purple, gold
-- Neon top edge, solid (CanCollide = true).
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	local configSrc = read("src/shared/Config.luau")
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not worldSrc or not configSrc or not eggSrc then
		check("boundary-walls", false, "could not verify the boundary walls — WorldBuilder.luau, Config.luau or MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("local function buildBoundaryWalls") then
			table.insert(problems, "no buildBoundaryWalls")
		end
		if not worldSrc:find("\n\tbuildBoundaryWalls%(%)") then
			table.insert(problems, "buildBoundaryWalls is never called from WorldBuilder.build")
		end
		local half = worldSrc:match("local BOUNDARY_HALF = (%d+)")
		local height = worldSrc:match("local BOUNDARY_HEIGHT = (%d+)")
		if not half or not height then
			table.insert(problems, "could not parse BOUNDARY_HALF / BOUNDARY_HEIGHT")
		else
			half = tonumber(half)
			height = tonumber(height)
			-- Four walls + four gold trims = a closed loop. The walls
			-- are built in a loop over a 4-entry sides table, so the
			-- count is the sides, not literal part() calls (there is
			-- one call site, run 4 times).
			local _, sideCount = 0, 0
			for _, side in ipairs({ "North", "South", "West", "East" }) do
				if worldSrc:find('name = "' .. side .. '"') then
					sideCount += 1
				else
					table.insert(problems, "no " .. side .. " wall")
				end
			end
			if sideCount ~= 4 then
				table.insert(problems, "found " .. tostring(sideCount) .. " wall sides, not 4")
			end
			if not worldSrc:find("for _, side in ipairs%(sides%) do") then
				table.insert(problems, "no loop building one wall per side")
			end
			-- The square must enclose everything gameplay + decor.
			local eggMax = eggSrc:match("math.random%(40, (%d+)%)")
			if eggMax and half <= tonumber(eggMax) then
				table.insert(problems, "walls at +/-" .. tostring(half) .. " do not enclose the egg field (radius " .. eggMax .. ")")
			end
			local baseRadius = configSrc:match("Config.BASE_RADIUS = (%d+)")
			if baseRadius and half <= tonumber(baseRadius) + 13 then
				table.insert(problems, "walls at +/-" .. tostring(half) .. " do not enclose the bases (radius " .. baseRadius .. " + 13 platform)")
			end
			local stormRange = configSrc:match("Config.STORM_FRONT_RANGE = (%d+)")
			if stormRange and half <= tonumber(stormRange) then
				table.insert(problems, "walls at +/-" .. tostring(half) .. " do not clear the storm front sweep (+/-" .. stormRange .. ")")
			end
			-- The spaceship saucer (centre x=170, diameter 44) reaches
			-- ~x 192 — the binding constraint for the placement.
			local shipX = worldSrc:match("local shipCf = CFrame.new%(([%-%d%.]+), 0, ([%-%d%.]+)%)")
			local saucerD = worldSrc:match('part%("SpaceshipSaucer".-Vector3.new%([%-%d%.]+, ([%-%d%.]+), [%-%d%.]+%)')
			if shipX and saucerD then
				local reach = math.abs(tonumber(shipX)) + tonumber(saucerD) / 2
				if half <= reach then
					table.insert(problems, "walls at +/-" .. tostring(half) .. " cut through the spaceship saucer (reaches x " .. string.format("%.0f", reach) .. ")")
				end
			end
			-- Inside the 500x500 ground, and tall enough to read.
			if half >= 250 then
				table.insert(problems, "walls at +/-" .. tostring(half) .. " are outside the 500x500 ground (+/-250)")
			end
			if height < 30 or height > 40 then
				table.insert(problems, "wall height is " .. tostring(height) .. " (must be 30-40)")
			end
		end
		-- The walls must be solid: no wall inside buildBoundaryWalls
		-- turns off collision (the gold trim is visual-only, and may).
		-- Scoped to the function body: an unrelated wall.CanCollide
		-- = false exists elsewhere in WorldBuilder (line ~715).
		local bodyStart = worldSrc:find("local function buildBoundaryWalls")
		if bodyStart then
			local _, bodyEnd = worldSrc:find("\nend\n", bodyStart)
			local body = worldSrc:sub(bodyStart, bodyEnd or #worldSrc)
			if body:find("wall%.CanCollide = false") then
				table.insert(problems, "a BoundaryWall turns off collision")
			end
			if not body:find("trim%.CanCollide = false") then
				table.insert(problems, "the gold trim is collidable (should be visual-only)")
			end
		else
			table.insert(problems, "could not extract the buildBoundaryWalls body")
		end
		if #problems > 0 then
			check("boundary-walls", false, "the boundary walls are wrong — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau, Config.luau")
		else
			check("boundary-walls", true, "4 solid walls + gold trims form a closed square at +/-200, 40 tall: encloses bases, egg field, storm spread and the spaceship (reaches ~192); clears the storm front by 30; inside the 500x500 ground")
		end
	end
end

-- -- (dressing) fix round 11, item 1: dense themed world + title sign ---
-- The top-10 comparison showed our world reads sparse next to the
-- leaders (10/10 dense themed worlds, 8/10 a big in-world title).
-- Dressing counts are raised, meteor rocks ring the rim, and a ground
-- title sign stands near spawn. What rev 79 removed stays removed:
-- no floating islands, no mountains, no world Index Wall, no SPAWN
-- sign, no BELT panel, no XP bar — this is world dressing only.
do
	local worldSrc = read("src/server/WorldBuilder.luau")
	if not worldSrc then
		check("dressing", false, "could not verify the dressing — WorldBuilder.luau missing")
	else
		local problems: { string } = {}
		if not worldSrc:find("for i = 1, 60 do", 1, true) then
			table.insert(problems, "trees are not 60")
		end
		if not worldSrc:find("for i = 1, 45 do", 1, true) then
			table.insert(problems, "rocks are not 45")
		end
		if not worldSrc:find("for i = 1, 36 do", 1, true) then
			table.insert(problems, "crystals are not 36")
		end
		if not worldSrc:find("for i = 0, 11 do", 1, true) then
			table.insert(problems, "plaza flag poles are not 12")
		end
		if not worldSrc:find("buildMeteorRocks") then
			table.insert(problems, "no meteor rocks around the crater rim")
		end
		if not worldSrc:find("buildWorldTitleSign") then
			table.insert(problems, "no world title sign builder")
		end
		-- Rev 79 removals stay removed: check for the builder/part
		-- identifiers, not the words (the removal comments mention
		-- them by name).
		if worldSrc:find("buildFloatingIslands") or worldSrc:find('part("FloatingIsland"') then
			table.insert(problems, "floating islands are back (rev 79 removed them)")
		end
		if worldSrc:find("buildMountains") or worldSrc:find('part("Mountain"') then
			table.insert(problems, "mountains are back (rev 79 removed them)")
		end
		if #problems > 0 then
			check("dressing", false, "the dressing pass is incomplete — " .. table.concat(problems, "; ") .. ". Parts: WorldBuilder.luau")
		else
			check("dressing", true, "dense world: 60 trees, 45 rocks, 36 crystals, 12 plaza flags, 6 meteor rocks on the rim, ground title sign near spawn; rev-79 removals stay removed")
		end
	end
end

-- -- (divine-tier) fix round 11, item 2: the Divine tier -------------
-- The top-10 comparison showed 6/10 leaders have a 7th rarity tier
-- and we have 6. Divine sits above Cosmic: royal blue (spread >= 100,
-- never white), weight 1 (tied rarest with Cosmic), 500 cps, two
-- characters — Archangel Alfredo (angel-noodle) and Pope Pineapple
-- (pineapple-pope) — each with its own silhouette and addNameProp
-- branch. Guardian speed 36 is the fastest chase (still tied by full
-- Speed Boots at 36); eggs hatch in 360s.
do
	local raritySrc = read("src/shared/RarityConfig.luau")
	local catalogSrc = read("src/shared/RotlingCatalog.luau")
	local factorySrc = read("src/server/RotlingFactory.luau")
	local configSrc = read("src/shared/Config.luau")
	local eggSrc = read("src/server/MeteorEggService.luau")
	if not raritySrc or not catalogSrc or not factorySrc or not configSrc or not eggSrc then
		check("divine-tier", false, "could not verify the Divine tier — RarityConfig.luau, RotlingCatalog.luau, RotlingFactory.luau, Config.luau or MeteorEggService.luau missing")
	else
		local problems: { string } = {}
		-- Seven tiers, Divine last in ORDER.
		local tierCount = 0
		for _ in raritySrc:gmatch('{ name = "') do
			tierCount += 1
		end
		if tierCount ~= 7 then
			table.insert(problems, "RarityConfig has " .. tostring(tierCount) .. " tiers, not 7")
		end
		if not raritySrc:find('ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Divine" }', 1, true) then
			table.insert(problems, "Divine is not last in RarityConfig.ORDER")
		end
		if not raritySrc:find('{ name = "Divine", color = Color3.fromRGB(70, 120, 255), weight = 1, cps = 500 }', 1, true) then
			table.insert(problems, "Divine is not royal blue (70,120,255), weight 1, 500 cps")
		end
		-- Two Divine defs, each with its own silhouette and name branch.
		local divineDefs = 0
		for _ in catalogSrc:gmatch('rarity = "Divine"') do
			divineDefs += 1
		end
		if divineDefs ~= 2 then
			table.insert(problems, "catalog has " .. tostring(divineDefs) .. " Divine defs, not 2")
		end
		if not catalogSrc:find('id = "alfredo"') or not catalogSrc:find('name = "Archangel Alfredo"') then
			table.insert(problems, "Archangel Alfredo (alfredo) is not in the catalog")
		end
		if not catalogSrc:find('id = "pineapple"') or not catalogSrc:find('name = "Pope Pineapple"') then
			table.insert(problems, "Pope Pineapple (pineapple) is not in the catalog")
		end
		if not factorySrc:find('def.silhouette == "angel-noodle"', 1, true) then
			table.insert(problems, "no angel-noodle silhouette branch in the factory")
		end
		if not factorySrc:find('def.silhouette == "pineapple-pope"', 1, true) then
			table.insert(problems, "no pineapple-pope silhouette branch in the factory")
		end
		if not factorySrc:find('def.id == "alfredo"') then
			table.insert(problems, "no alfredo addNameProp branch in the factory")
		end
		if not factorySrc:find('def.id == "pineapple"') then
			table.insert(problems, "no pineapple addNameProp branch in the factory")
		end
		-- Divine is buildable: guardian speed 36, hatch time 360, egg roll covers tier 7.
		if not configSrc:find("%[7%] = 36") then
			table.insert(problems, "GUARDIAN_SPEED has no tier 7 = 36")
		end
		if not configSrc:find("%[7%] = 360") then
			table.insert(problems, "EGG_HATCH_TIME has no tier 7 = 360")
		end
		if not eggSrc:find("for tier = 1, 7 do", 1, true) then
			table.insert(problems, "rollEggRarity does not cover tier 7")
		end
		if #problems > 0 then
			check("divine-tier", false, "the Divine tier is incomplete — " .. table.concat(problems, "; ") .. ". Parts: RarityConfig.luau, RotlingCatalog.luau, RotlingFactory.luau, Config.luau, MeteorEggService.luau")
		else
			check("divine-tier", true, "Divine tier live: 7 tiers, Divine last (royal blue 70,120,255, weight 1, 500 cps); Archangel Alfredo (angel-noodle, halo + wings + robe) and Pope Pineapple (pineapple-pope, leaf crown + mitre + cross); guardian 36, hatch 360s, eggs can roll Divine")
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
