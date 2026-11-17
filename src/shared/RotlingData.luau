-- Starfall Rotlings: the cast.
-- Twelve original creatures, each with its own silhouette, colours and
-- accessory, built from Parts by RotlingFactory. Nothing here is borrowed
-- from any other game: these names, shapes and jokes are ours.

local Config = require(script.Parent.Config)

export type RotlingDef = {
	id: string,
	name: string,
	rarity: string,
	flavor: string,
	body: string, -- "ball" | "block" | "tall" | "wide"
	bodyColor: Color3,
	bellyColor: Color3,
	accessory: string, -- "horns" | "hat" | "antenna" | "crown" | "headphones" | "cape" | "star" | "none"
	size: number, -- body height in studs
	cpsMult: number, -- per-creature flavour multiplier on rarity cps
}

local RotlingData = {}

RotlingData.DEFS = {
	{
		id = "wombat",
		name = "Wobble Wombat",
		rarity = "Common",
		flavor = "Wobbles everywhere. Earns slowly, judges silently.",
		body = "block",
		bodyColor = Color3.fromRGB(150, 110, 70),
		bellyColor = Color3.fromRGB(220, 190, 150),
		accessory = "none",
		size = 3.2,
		cpsMult = 1,
	},
	{
		id = "puddles",
		name = "Sir Puddles",
		rarity = "Common",
		flavor = "A puddle that achieved knighthood. Very damp, very polite.",
		body = "wide",
		bodyColor = Color3.fromRGB(70, 140, 230),
		bellyColor = Color3.fromRGB(160, 210, 255),
		accessory = "none",
		size = 2.2,
		cpsMult = 1,
	},
	{
		id = "noodle",
		name = "Noodle Ned",
		rarity = "Common",
		flavor = "One long noodle. Stands up. Nobody knows how.",
		body = "tall",
		bodyColor = Color3.fromRGB(255, 220, 90),
		bellyColor = Color3.fromRGB(255, 240, 170),
		accessory = "hat",
		size = 4.6,
		cpsMult = 1,
	},
	{
		id = "crumb",
		name = "Captain Crumb",
		rarity = "Rare",
		flavor = "Fell off a biscuit, became a captain. The sea fears him.",
		body = "block",
		bodyColor = Color3.fromRGB(200, 150, 80),
		bellyColor = Color3.fromRGB(240, 210, 140),
		accessory = "hat",
		size = 3.4,
		cpsMult = 1.1,
	},
	{
		id = "pickle",
		name = "Disco Pickle",
		rarity = "Rare",
		flavor = "Brings the party. The party is just him, dancing.",
		body = "tall",
		bodyColor = Color3.fromRGB(90, 200, 70),
		bellyColor = Color3.fromRGB(170, 235, 130),
		accessory = "headphones",
		size = 4.4,
		cpsMult = 1.1,
	},
	{
		id = "toaster",
		name = "Toaster Ghost",
		rarity = "Rare",
		flavor = "Haunts breakfast. Pops up when you least expect it.",
		body = "ball",
		bodyColor = Color3.fromRGB(235, 235, 245),
		bellyColor = Color3.fromRGB(200, 200, 220),
		accessory = "antenna",
		size = 3.6,
		cpsMult = 1.1,
	},
	{
		id = "socks",
		name = "Sir Reginald Socks",
		rarity = "Epic",
		flavor = "A sock of noble birth. Smells of lavender and old money.",
		body = "tall",
		bodyColor = Color3.fromRGB(140, 90, 200),
		bellyColor = Color3.fromRGB(200, 160, 240),
		accessory = "crown",
		size = 4.8,
		cpsMult = 1.2,
	},
	{
		id = "quokka",
		name = "Quantum Quokka",
		rarity = "Epic",
		flavor = "Smiles in two places at once. Physics gave up.",
		body = "ball",
		bodyColor = Color3.fromRGB(170, 110, 220),
		bellyColor = Color3.fromRGB(220, 190, 250),
		accessory = "antenna",
		size = 3.8,
		cpsMult = 1.2,
	},
	{
		id = "turnip",
		name = "DJ Turnip",
		rarity = "Epic",
		flavor = "Drops beats, grows roots. The turnip table never stops.",
		body = "wide",
		bodyColor = Color3.fromRGB(190, 120, 230),
		bellyColor = Color3.fromRGB(230, 190, 255),
		accessory = "headphones",
		size = 3.4,
		cpsMult = 1.2,
	},
	{
		id = "bloop",
		name = "Baron von Bloop",
		rarity = "Legendary",
		flavor = "A bloop of ancient lineage. Blooped at kings. Kings blooped back.",
		body = "ball",
		bodyColor = Color3.fromRGB(255, 200, 60),
		bellyColor = Color3.fromRGB(255, 230, 140),
		accessory = "crown",
		size = 4.4,
		cpsMult = 1.3,
	},
	{
		id = "couch",
		name = "Emperor Couch Potato",
		rarity = "Mythic",
		flavor = "Has not moved since 2019. Rules an empire of cushions.",
		body = "wide",
		bodyColor = Color3.fromRGB(255, 110, 150),
		bellyColor = Color3.fromRGB(255, 180, 200),
		accessory = "cape",
		size = 4.0,
		cpsMult = 1.5,
	},
	{
		id = "gummy",
		name = "Galactic Gummy Bear",
		rarity = "Cosmic",
		flavor = "Fell from orbit, tastes of stardust and sugar.",
		body = "ball",
		bodyColor = Color3.fromRGB(70, 220, 255),
		bellyColor = Color3.fromRGB(170, 240, 255),
		accessory = "star",
		size = 4.6,
		cpsMult = 1.5,
	},
}

function RotlingData.getDef(id: string): RotlingDef?
	for _, def in ipairs(RotlingData.DEFS) do
		if def.id == id then
			return def
		end
	end
	return nil
end

function RotlingData.defsOfRarity(rarity: string): { RotlingDef }
	local out = {}
	for _, def in ipairs(RotlingData.DEFS) do
		if def.rarity == rarity then
			table.insert(out, def)
		end
	end
	return out
end

-- Pick a random creature of the rolled rarity.
function RotlingData.rollDef(): RotlingDef
	local rarity = Config.rollRarity()
	local pool = RotlingData.defsOfRarity(rarity)
	return pool[math.random(1, #pool)]
end

-- Coins per second for one placed Rotling before player multipliers.
function RotlingData.baseCps(def: RotlingDef, mutation: string?): number
	local rarity = Config.rarityByName(def.rarity)
	local cps = rarity.cps * def.cpsMult
	local mut = Config.mutationByName(mutation)
	if mut then
		cps *= mut.mult
	end
	return cps
end

return RotlingData
