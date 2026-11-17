--!strict
-- Starfall Rotlings: the cast.
-- Twelve original creatures, each with its own silhouette, colours and
-- accessory, built from Parts by RotlingFactory. Nothing here is borrowed
-- from any other game: these names, shapes and jokes are ours. Every name
-- was checked against the Italian brainrot roster (Tralalero, Tung Tung
-- Sahur, Cappuccino Assassino and the rest) and appears on none of it.
--
-- Item 1 (models): every Rotling has a UNIQUE silhouette key (no two
-- share one), 2-3 signature features built from Parts, and a primary
-- body colour that IS its rarity tier colour, taken verbatim from
-- RarityConfig — Commons are rarity blue, Rares rarity green, Epics
-- rarity purple, Legendary rarity gold, Mythic rarity pink, Cosmic
-- rarity cyan. The belly is a lighter tint of the same tier colour.
-- Prices, spawn rates, rarities and cps are untouched: this file only
-- describes how each Rotling LOOKS.

local RarityConfig = require(script.Parent.RarityConfig)
local MutationConfig = require(script.Parent.MutationConfig)

export type RotlingDef = {
	id: string,
	name: string,
	rarity: string,
	flavor: string,
	body: string, -- "ball" | "block" | "tall" | "wide" (legacy fallback; RotlingFactory builds from silhouette)
	silhouette: string, -- unique per Rotling: "chunky-round" | "flat-puddle" | "long-wavy" | "chunky-cube" | "tall-capsule" | "boxy-ghost" | "tall-sock" | "round-bounce" | "root-round" | "blob-dome" | "wide-couch" | "bear"
	bodyColor: Color3, -- MUST equal the RarityConfig colour of `rarity` (checked by auto-check (ai))
	bellyColor: Color3, -- lighter tint of the same tier colour
	accessory: string, -- "horns" | "hat" | "antenna" | "crown" | "headphones" | "cape" | "star" | "none"
	features: { string }, -- 2-3 signature built-from-parts features (checked by auto-check (aj))
	size: number, -- body height in studs
	cpsMult: number, -- per-creature flavour multiplier on rarity cps
}

local RotlingCatalog = {}

RotlingCatalog.DEFS = {
	{
		id = "wombat",
		name = "Wobble Wombat",
		rarity = "Common",
		flavor = "Wobbles everywhere. Earns slowly, judges silently.",
		body = "block",
		silhouette = "chunky-round",
		bodyColor = Color3.fromRGB(110, 200, 255),
		bellyColor = Color3.fromRGB(170, 225, 255),
		accessory = "none",
		features = { "big round ears", "snout with nose", "stubby tail" },
		size = 3.2,
		cpsMult = 1,
	},
	{
		id = "puddles",
		name = "Sir Puddles",
		rarity = "Common",
		flavor = "A puddle that achieved knighthood. Very damp, very polite.",
		body = "wide",
		silhouette = "flat-puddle",
		bodyColor = Color3.fromRGB(110, 200, 255),
		bellyColor = Color3.fromRGB(170, 225, 255),
		accessory = "none",
		features = { "knight helmet with plume", "rim droplets", "splash spikes" },
		size = 2.2,
		cpsMult = 1,
	},
	{
		id = "noodle",
		name = "Noodle Ned",
		rarity = "Common",
		flavor = "One long noodle. Stands up. Nobody knows how.",
		body = "tall",
		silhouette = "long-wavy",
		bodyColor = Color3.fromRGB(110, 200, 255),
		bellyColor = Color3.fromRGB(170, 225, 255),
		accessory = "hat",
		features = { "wavy side segments", "chef hat", "noodle curl" },
		size = 4.6,
		cpsMult = 1,
	},
	{
		id = "crumb",
		name = "Captain Crumb",
		rarity = "Rare",
		flavor = "Fell off a biscuit, became a captain. The sea fears him.",
		body = "block",
		silhouette = "chunky-cube",
		bodyColor = Color3.fromRGB(80, 220, 100),
		bellyColor = Color3.fromRGB(150, 240, 165),
		accessory = "hat",
		features = { "captain hat", "crumb dots", "sailor collar" },
		size = 3.4,
		cpsMult = 1.1,
	},
	{
		id = "pickle",
		name = "Disco Pickle",
		rarity = "Rare",
		flavor = "Brings the party. The party is just him, dancing.",
		body = "tall",
		silhouette = "tall-capsule",
		bodyColor = Color3.fromRGB(80, 220, 100),
		bellyColor = Color3.fromRGB(150, 240, 165),
		accessory = "headphones",
		features = { "mirror-ball on a stem", "rounded capsule cap", "pickle dots" },
		size = 4.4,
		cpsMult = 1.1,
	},
	{
		id = "toaster",
		name = "Toaster Ghost",
		rarity = "Rare",
		flavor = "Haunts breakfast. Pops up when you least expect it.",
		body = "ball",
		silhouette = "boxy-ghost",
		bodyColor = Color3.fromRGB(80, 220, 100),
		bellyColor = Color3.fromRGB(150, 240, 165),
		accessory = "antenna",
		features = { "toast slot with popping toast", "front dial", "scalloped ghost hem" },
		size = 3.6,
		cpsMult = 1.1,
	},
	{
		id = "socks",
		name = "Sir Reginald Socks",
		rarity = "Epic",
		flavor = "A sock of noble birth. Smells of lavender and old money.",
		body = "tall",
		silhouette = "tall-sock",
		bodyColor = Color3.fromRGB(180, 90, 255),
		bellyColor = Color3.fromRGB(215, 165, 255),
		accessory = "crown",
		features = { "folded cuff", "gold monocle ring", "toe cap" },
		size = 4.8,
		cpsMult = 1.2,
	},
	{
		id = "quokka",
		name = "Quantum Quokka",
		rarity = "Epic",
		flavor = "Smiles in two places at once. Physics gave up.",
		body = "ball",
		silhouette = "round-bounce",
		bodyColor = Color3.fromRGB(180, 90, 255),
		bellyColor = Color3.fromRGB(215, 165, 255),
		accessory = "antenna",
		features = { "orbit ring with planet", "round ears", "big smile with tongue" },
		size = 3.8,
		cpsMult = 1.2,
	},
	{
		id = "turnip",
		name = "DJ Turnip",
		rarity = "Epic",
		flavor = "Drops beats, grows roots. The turnip table never stops.",
		body = "wide",
		silhouette = "root-round",
		bodyColor = Color3.fromRGB(180, 90, 255),
		bellyColor = Color3.fromRGB(215, 165, 255),
		accessory = "headphones",
		features = { "leafy top", "root tail", "rosy cheeks" },
		size = 3.4,
		cpsMult = 1.2,
	},
	{
		id = "bloop",
		name = "Baron von Bloop",
		rarity = "Legendary",
		flavor = "A bloop of ancient lineage. Blooped at kings. Kings blooped back.",
		body = "ball",
		silhouette = "blob-dome",
		bodyColor = Color3.fromRGB(255, 200, 40),
		bellyColor = Color3.fromRGB(255, 228, 130),
		accessory = "crown",
		features = { "crown", "bow tie", "gold drips" },
		size = 4.4,
		cpsMult = 1.3,
	},
	{
		id = "couch",
		name = "Emperor Couch Potato",
		rarity = "Mythic",
		flavor = "Has not moved since 2019. Rules an empire of cushions.",
		body = "wide",
		silhouette = "wide-couch",
		bodyColor = Color3.fromRGB(255, 80, 140),
		bellyColor = Color3.fromRGB(255, 165, 195),
		accessory = "cape",
		features = { "couch backrest and armrests", "emperor crown", "TV remote" },
		size = 4.0,
		cpsMult = 1.5,
	},
	{
		id = "gummy",
		name = "Galactic Gummy Bear",
		rarity = "Cosmic",
		flavor = "Fell from orbit, tastes of stardust and sugar.",
		body = "ball",
		silhouette = "bear",
		bodyColor = Color3.fromRGB(60, 220, 255),
		bellyColor = Color3.fromRGB(150, 240, 255),
		accessory = "star",
		features = { "bear ears", "snout", "star belly" },
		size = 4.6,
		cpsMult = 1.5,
	},
} :: { RotlingDef }

function RotlingCatalog.getDef(id: string): RotlingDef?
	for _, def in ipairs(RotlingCatalog.DEFS) do
		if def.id == id then
			return def
		end
	end
	return nil
end

function RotlingCatalog.defsOfRarity(rarity: string): { RotlingDef }
	local out = {}
	for _, def in ipairs(RotlingCatalog.DEFS) do
		if def.rarity == rarity then
			table.insert(out, def)
		end
	end
	return out
end

-- Pick a random creature of the rolled rarity.
function RotlingCatalog.rollDef(): RotlingDef
	local rarity = RarityConfig.rollRarity()
	local pool = RotlingCatalog.defsOfRarity(rarity)
	return pool[math.random(1, #pool)]
end

-- Coins per second for one placed Rotling before player multipliers.
function RotlingCatalog.baseCps(def: RotlingDef, mutation: string?): number
	local rarity = RarityConfig.rarityByName(def.rarity)
	local cps = rarity.cps * def.cpsMult
	cps *= MutationConfig.mutationMult(mutation)
	return cps
end

return RotlingCatalog
