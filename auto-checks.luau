-- Starfall Rotlings: pre-publish auto-checks.
-- Runs BEFORE EVERY publish and FAILS the build (exit 1) if any of
-- these are true. Print pass or fail for each check, with the part
-- names involved:
--   (a) a carried Rotling sits above the player's head instead of in
--       front or in hand
--   (b) the base sign overlaps any name tag
--   (c) a name tag overlaps the HUD buttons or the top bar
--   (d) crater Rotlings are smaller than the agreed minimum size (1.5x)
--   (e) the spawn platform is a flat cyan block with no texture
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
-- prove the structural conditions that cause each overlap/size fault
-- (one stacked sign billboard, tags hidden while carried, bounded
-- MaxDistance, the 1.5x spawn scale, the spawn slab's material and
-- colour). True screen-space overlap — a sign and a tag landing on
-- the same pixels from some camera angle — can only be judged from a
-- running game, which is what photo mode is for (P or /photo).
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

-- The weld offset that carries a Rotling: split "0, Config.CARRY_HEIGHT, 0"
-- into numbers, resolving Config.CARRY_HEIGHT from Config.luau.
local function parseOffset(source: string, carryHeight: number?): { number }?
	local raw = source:match("weld%.C0%s*=%s*CFrame%.new%(([^)]+)%)")
	if not raw then
		return nil
	end
	local out: { number } = {}
	for part in raw:gmatch("[^,]+") do
		part = part:gsub("^%s+", ""):gsub("%s+$", "")
		if part == "Config.CARRY_HEIGHT" then
			if not carryHeight then
				return nil
			end
			table.insert(out, carryHeight)
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

-- -- (a) carried Rotling above the head --------------------------------------
do
	local configSrc = read("src/shared/Config.luau")
	local carryHeight = nil
	if configSrc then
		carryHeight = num(configSrc:match("CARRY_HEIGHT%s*=%s*([%d%.]+)"))
	end
	local carrySrc = read("src/server/CarryService.luau")
	local stealSrc = read("src/server/StealService.luau")
	local off1 = if carrySrc then parseOffset(carrySrc, carryHeight) else nil
	local off2 = if stealSrc then parseOffset(stealSrc, carryHeight) else nil
	if not carryHeight or not off1 or not off2 then
		check("a", false, "could not verify the carry weld — CarryWeld C0 or Config.CARRY_HEIGHT not found in CarryService.luau / StealService.luau / Config.luau")
	elseif (math.abs(off1[1]) < 0.5 and math.abs(off1[3]) < 0.5 and off1[2] >= 1.5)
		or (math.abs(off2[1]) < 0.5 and math.abs(off2[3]) < 0.5 and off2[2] >= 1.5) then
		check("a", false, "carried Rotling sits above the player's head — CarryWeld C0 = (0, "
			.. tostring(carryHeight) .. ", 0) in CarryService.weldToPlayer and StealService.trySteal; Config.CARRY_HEIGHT = "
			.. tostring(carryHeight) .. "; CarryBubble rides at the same offset. Expected: a forward (Z) offset in front of the player, or hand height.")
	else
		check("a", true, "carried Rotling rides in front or in hand — CarryWeld C0 = ("
			.. table.concat(off1, ", ") .. ") in CarryService.weldToPlayer, (" .. table.concat(off2, ", ") .. ") in StealService.trySteal")
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
