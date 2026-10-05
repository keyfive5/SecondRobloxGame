-- Every dragon in the game. `biome` is where its egg is found (0 = Secret Eggs only).
-- `look` drives DragonBuilder: colors, horn style, accessories and effects.
-- Income per second (cps) = rarity base x 4^(biome - 1), unless set explicitly.
local Species = {}

local RARITY_BASE = { Common = 2, Uncommon = 5, Rare = 12, Epic = 30, Legendary = 75, Mythic = 190, Secret = 500 }

local rgb = Color3.fromRGB

Species.List = {
	-- Sunny Meadow
	{ id = "sprout", name = "Sprout Drake", rarity = "Common", biome = 1,
		look = { body = rgb(120, 205, 95), belly = rgb(236, 245, 170), accent = rgb(80, 150, 60), wing = rgb(170, 230, 120), eye = rgb(60, 130, 40), horn = "nub", extras = { "leaf" } } },
	{ id = "clover", name = "Clover Dragon", rarity = "Uncommon", biome = 1,
		look = { body = rgb(80, 200, 150), belly = rgb(220, 255, 220), accent = rgb(40, 140, 90), wing = rgb(130, 235, 180), eye = rgb(30, 120, 70), horn = "curved", extras = { "clover" } } },
	{ id = "bumble", name = "Bumble Dragon", rarity = "Rare", biome = 1,
		look = { body = rgb(255, 205, 40), belly = rgb(255, 240, 160), accent = rgb(40, 32, 30), wing = rgb(200, 235, 255), wingAlpha = 0.35, eye = rgb(60, 40, 20), horn = "none", extras = { "bee" } } },
	{ id = "blossom", name = "Blossom Dragon", rarity = "Epic", biome = 1,
		look = { body = rgb(255, 160, 200), belly = rgb(255, 235, 245), accent = rgb(230, 90, 150), wing = rgb(255, 205, 225), eye = rgb(200, 60, 120), horn = "curved", extras = { "flower" }, fx = "petals" } },
	{ id = "unicorn", name = "Unicorn Dragon", rarity = "Legendary", biome = 1,
		look = { body = rgb(250, 250, 255), belly = rgb(255, 230, 250), accent = rgb(255, 200, 60), wing = rgb(200, 170, 255), eye = rgb(140, 90, 255), horn = "unihorn", extras = { "mane" }, fx = "sparkle", rainbowWings = true } },

	-- Sandy Dunes
	{ id = "sandy", name = "Sandy Drake", rarity = "Common", biome = 2,
		look = { body = rgb(222, 180, 110), belly = rgb(250, 230, 180), accent = rgb(170, 120, 60), wing = rgb(240, 200, 140), eye = rgb(120, 80, 30), horn = "nub" } },
	{ id = "cactus", name = "Cactus Dragon", rarity = "Uncommon", biome = 2,
		look = { body = rgb(80, 160, 80), belly = rgb(170, 220, 130), accent = rgb(250, 245, 220), wing = rgb(110, 190, 100), eye = rgb(40, 90, 40), horn = "none", extras = { "cactus" } } },
	{ id = "scarab", name = "Scarab Dragon", rarity = "Rare", biome = 2,
		look = { body = rgb(30, 150, 160), belly = rgb(110, 220, 210), accent = rgb(255, 200, 60), wing = rgb(40, 110, 140), eye = rgb(255, 210, 60), horn = "long", bodyMat = "Foil", extras = { "gem" } } },
	{ id = "mummy", name = "Mummy Dragon", rarity = "Epic", biome = 2,
		look = { body = rgb(235, 225, 200), belly = rgb(250, 245, 230), accent = rgb(150, 130, 100), wing = rgb(180, 165, 135), eye = rgb(80, 220, 120), horn = "curved", extras = { "bandage" }, glowEyes = true } },
	{ id = "pharaoh", name = "Pharaoh Dragon", rarity = "Legendary", biome = 2,
		look = { body = rgb(255, 196, 50), belly = rgb(255, 235, 150), accent = rgb(30, 70, 170), wing = rgb(255, 215, 100), eye = rgb(30, 80, 200), horn = "none", bodyMat = "Foil", extras = { "nemes", "collar" }, fx = "sparkle" } },

	-- Frostpeak
	{ id = "snowball", name = "Snowball Drake", rarity = "Common", biome = 3,
		look = { body = rgb(245, 250, 255), belly = rgb(215, 235, 255), accent = rgb(150, 190, 230), wing = rgb(200, 225, 250), eye = rgb(60, 120, 200), horn = "nub", extras = { "earmuffs" } } },
	{ id = "penguin", name = "Penguin Dragon", rarity = "Uncommon", biome = 3,
		look = { body = rgb(40, 45, 60), belly = rgb(250, 250, 255), accent = rgb(255, 160, 40), wing = rgb(60, 70, 90), eye = rgb(30, 30, 40), horn = "none", extras = { "scarf" } } },
	{ id = "icicle", name = "Icicle Dragon", rarity = "Rare", biome = 3,
		look = { body = rgb(150, 215, 255), belly = rgb(225, 245, 255), accent = rgb(200, 240, 255), wing = rgb(170, 225, 255), wingAlpha = 0.25, eye = rgb(30, 110, 220), horn = "long", extras = { "icecrystals" }, fx = "snow" } },
	{ id = "yeti", name = "Yeti Dragon", rarity = "Epic", biome = 3,
		look = { body = rgb(235, 240, 248), belly = rgb(170, 200, 230), accent = rgb(110, 150, 200), wing = rgb(190, 210, 235), eye = rgb(40, 90, 170), horn = "curved", extras = { "fluffy" }, fx = "snow" } },
	{ id = "aurora", name = "Aurora Dragon", rarity = "Legendary", biome = 3,
		look = { body = rgb(70, 220, 200), belly = rgb(200, 255, 240), accent = rgb(170, 110, 255), wing = rgb(110, 255, 200), wingNeon = true, eye = rgb(140, 80, 255), horn = "long", extras = { "auroraTrail" }, fx = "sparkle" } },

	-- Magma Mountain
	{ id = "ember", name = "Ember Drake", rarity = "Uncommon", biome = 4,
		look = { body = rgb(240, 100, 50), belly = rgb(255, 210, 120), accent = rgb(150, 40, 30), wing = rgb(255, 150, 70), eye = rgb(255, 220, 60), horn = "curved", fx = "embers" } },
	{ id = "magma", name = "Magma Dragon", rarity = "Rare", biome = 4,
		look = { body = rgb(55, 40, 40), belly = rgb(255, 120, 30), accent = rgb(255, 140, 30), wing = rgb(90, 50, 45), eye = rgb(255, 160, 30), horn = "long", extras = { "lavaspots" }, fx = "embers", glowBelly = true } },
	{ id = "obsidian", name = "Obsidian Dragon", rarity = "Epic", biome = 4,
		look = { body = rgb(30, 25, 40), belly = rgb(90, 60, 130), accent = rgb(170, 100, 255), wing = rgb(60, 40, 90), eye = rgb(190, 120, 255), horn = "long", bodyMat = "Glass", extras = { "crystals" }, glowEyes = true } },
	{ id = "phoenix", name = "Phoenix Dragon", rarity = "Legendary", biome = 4,
		look = { body = rgb(255, 120, 30), belly = rgb(255, 225, 90), accent = rgb(255, 60, 30), wing = rgb(255, 170, 40), wingNeon = true, eye = rgb(255, 240, 120), horn = "none", extras = { "crest" }, fx = "fire" } },
	{ id = "blaze", name = "Blaze Emperor", rarity = "Mythic", biome = 4,
		look = { body = rgb(180, 20, 30), belly = rgb(255, 170, 40), accent = rgb(255, 210, 60), wing = rgb(255, 80, 30), wingNeon = true, eye = rgb(255, 230, 80), horn = "long", extras = { "crown" }, fx = "fire", glowEyes = true } },

	-- Thunder Cliffs
	{ id = "cloud", name = "Cloud Drake", rarity = "Rare", biome = 5,
		look = { body = rgb(210, 225, 245), belly = rgb(250, 252, 255), accent = rgb(150, 170, 210), wing = rgb(235, 242, 255), eye = rgb(90, 130, 220), horn = "nub", extras = { "cloudpuffs" } } },
	{ id = "thunder", name = "Thunder Dragon", rarity = "Epic", biome = 5,
		look = { body = rgb(255, 220, 50), belly = rgb(255, 250, 200), accent = rgb(60, 60, 80), wing = rgb(255, 235, 120), eye = rgb(80, 120, 255), horn = "bolt", fx = "sparks" } },
	{ id = "storm", name = "Storm Dragon", rarity = "Legendary", biome = 5,
		look = { body = rgb(40, 60, 130), belly = rgb(120, 170, 255), accent = rgb(140, 220, 255), wing = rgb(60, 90, 170), eye = rgb(150, 230, 255), horn = "bolt", fx = "sparks", glowEyes = true } },
	{ id = "tempest", name = "Tempest Dragon", rarity = "Mythic", biome = 5,
		look = { body = rgb(110, 60, 200), belly = rgb(200, 170, 255), accent = rgb(250, 240, 120), wing = rgb(140, 100, 240), wingNeon = true, eye = rgb(255, 250, 150), horn = "bolt", extras = { "stormcloud" }, fx = "sparks", glowEyes = true } },

	-- Crystal Caverns
	{ id = "quartz", name = "Quartz Dragon", rarity = "Rare", biome = 6,
		look = { body = rgb(240, 225, 240), belly = rgb(255, 245, 255), accent = rgb(255, 180, 230), wing = rgb(255, 210, 240), wingAlpha = 0.3, eye = rgb(220, 90, 170), horn = "crystal", extras = { "crystals" } } },
	{ id = "amethyst", name = "Amethyst Dragon", rarity = "Epic", biome = 6,
		look = { body = rgb(150, 80, 220), belly = rgb(220, 180, 255), accent = rgb(200, 140, 255), wing = rgb(170, 110, 240), wingAlpha = 0.2, eye = rgb(250, 220, 255), horn = "crystal", bodyMat = "Glass", extras = { "crystals" }, fx = "sparkle" } },
	{ id = "emerald", name = "Emerald Dragon", rarity = "Legendary", biome = 6,
		look = { body = rgb(30, 190, 110), belly = rgb(170, 255, 200), accent = rgb(120, 255, 180), wing = rgb(60, 220, 140), wingAlpha = 0.2, eye = rgb(220, 255, 230), horn = "crystal", bodyMat = "Glass", extras = { "crystals", "gem" }, fx = "sparkle" } },
	{ id = "prism", name = "Prism Dragon", rarity = "Mythic", biome = 6,
		look = { body = rgb(255, 255, 255), belly = rgb(255, 255, 255), accent = rgb(255, 255, 255), wing = rgb(255, 255, 255), wingAlpha = 0.15, eye = rgb(80, 60, 200), horn = "crystal", bodyMat = "Glass", extras = { "crystals" }, fx = "sparkle", prism = true } },

	-- Shadow Realm
	{ id = "ghost", name = "Ghost Dragon", rarity = "Epic", biome = 7,
		look = { body = rgb(230, 240, 255), belly = rgb(255, 255, 255), accent = rgb(170, 200, 255), wing = rgb(220, 235, 255), eye = rgb(60, 80, 160), horn = "curved", ghost = true, fx = "wisps" } },
	{ id = "shadow", name = "Shadow Dragon", rarity = "Legendary", biome = 7,
		look = { body = rgb(25, 20, 35), belly = rgb(70, 40, 110), accent = rgb(160, 80, 255), wing = rgb(45, 30, 70), eye = rgb(190, 110, 255), horn = "long", fx = "smoke", glowEyes = true } },
	{ id = "nightmare", name = "Nightmare Dragon", rarity = "Mythic", biome = 7,
		look = { body = rgb(20, 15, 20), belly = rgb(120, 20, 40), accent = rgb(255, 40, 70), wing = rgb(60, 15, 25), wingNeon = false, eye = rgb(255, 40, 60), horn = "long", extras = { "spikesRed" }, fx = "smoke", glowEyes = true } },

	-- Starfall Summit
	{ id = "star", name = "Star Dragon", rarity = "Epic", biome = 8,
		look = { body = rgb(40, 60, 150), belly = rgb(140, 180, 255), accent = rgb(255, 230, 90), wing = rgb(70, 90, 190), eye = rgb(255, 240, 140), horn = "curved", extras = { "starTip" }, fx = "stars" } },
	{ id = "nebula", name = "Nebula Dragon", rarity = "Legendary", biome = 8,
		look = { body = rgb(200, 80, 220), belly = rgb(255, 180, 240), accent = rgb(110, 200, 255), wing = rgb(140, 90, 255), wingNeon = true, eye = rgb(130, 230, 255), horn = "long", fx = "nebula" } },
	{ id = "cosmic", name = "Cosmic Dragon", rarity = "Mythic", biome = 8,
		look = { body = rgb(20, 20, 60), belly = rgb(90, 70, 200), accent = rgb(120, 230, 255), wing = rgb(40, 30, 110), wingNeon = true, eye = rgb(150, 240, 255), horn = "long", extras = { "orbit" }, fx = "stars", glowEyes = true } },

	-- Secret Eggs (any biome, announced server-wide)
	{ id = "pizza", name = "Pizza Dragon", rarity = "Secret", biome = 0, cps = 5e6,
		look = { body = rgb(250, 200, 80), belly = rgb(255, 230, 140), accent = rgb(200, 40, 30), wing = rgb(230, 150, 60), eye = rgb(60, 40, 20), horn = "nub", extras = { "pepperoni", "chefhat" } } },
	{ id = "disco", name = "Disco Dragon", rarity = "Secret", biome = 0, cps = 12e6,
		look = { body = rgb(255, 80, 200), belly = rgb(255, 200, 250), accent = rgb(80, 220, 255), wing = rgb(255, 255, 255), eye = rgb(30, 30, 30), horn = "curved", extras = { "sunglasses", "discoball" }, fx = "disco", prism = true } },
	{ id = "void", name = "Void Dragon", rarity = "Secret", biome = 0, cps = 30e6,
		look = { body = rgb(10, 10, 14), belly = rgb(30, 20, 50), accent = rgb(255, 255, 255), wing = rgb(15, 10, 25), eye = rgb(255, 255, 255), horn = "long", extras = { "voidhalo" }, fx = "void", glowEyes = true } },
	{ id = "galaxy_emperor", name = "Galaxy Emperor", rarity = "Secret", biome = 0, cps = 80e6,
		look = { body = rgb(60, 30, 140), belly = rgb(180, 140, 255), accent = rgb(255, 215, 80), wing = rgb(90, 50, 200), wingNeon = true, eye = rgb(255, 230, 120), horn = "long", extras = { "crown", "cape", "orbit" }, fx = "stars", glowEyes = true } },
}

Species.ById = {}
Species.ByBiome = {} -- [biome] = { [rarity] = { species... } }
for i, sp in ipairs(Species.List) do
	sp.order = i
	if not sp.cps then
		sp.cps = RARITY_BASE[sp.rarity] * 4 ^ math.max(sp.biome - 1, 0)
	end
	Species.ById[sp.id] = sp
	local b = Species.ByBiome[sp.biome] or {}
	Species.ByBiome[sp.biome] = b
	b[sp.rarity] = b[sp.rarity] or {}
	table.insert(b[sp.rarity], sp)
end

function Species.get(id: string)
	return Species.ById[id]
end

-- Species an egg of this biome + rarity can hatch into.
function Species.pool(biome: number, rarity: string)
	local b = Species.ByBiome[biome]
	return b and b[rarity] or {}
end

Species.Secrets = Species.ByBiome[0] and Species.ByBiome[0].Secret or {}
Species.SecretWeights = { pizza = 50, disco = 30, void = 15, galaxy_emperor = 5 }

return Species
