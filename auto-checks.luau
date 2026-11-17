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
		-- The billboard itself is bounded to the same 25 studs.
		local billDist = num(factorySrc:match("billboard%.MaxDistance%s*=%s*(%d+)"))
		if not billDist then
			table.insert(problems, "RotlingLabel MaxDistance not found in RotlingFactory.luau")
		elseif billDist > 25 then
			table.insert(problems, "RotlingLabel MaxDistance " .. tostring(billDist) .. " (over 25)")
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
		if not worldSrc:find('sellPrompt%.ActionText = "Sell Rotling"') then
			table.insert(problems, 'no "Sell Rotling" prompt on the SELL pad')
		end
		if not sellSrc:find("function SellService.sellCarried") then
			table.insert(problems, "SellService.sellCarried not found")
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
			check("p", true, "clear SELL area — gold SellPad on the spawn path with a 💰 SELL sign and E prompt, server-priced at baseCps x " .. tostring(configValue(read("src/shared/Config.luau"), "SELL_MULT") or 60))
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
