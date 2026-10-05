-- The eight biomes along the Dragon Path, nearest first. Each has a nest guarded by
-- a giant dragon; `speed` is the walk speed you need to escape its guardian.
local Biomes = {}

Biomes.List = {
	{
		id = "meadow", name = "Sunny Meadow", guardian = "Mossback", speed = 20,
		egg = { base = Color3.fromRGB(165, 225, 120), spot = Color3.fromRGB(255, 245, 170) },
		color = Color3.fromRGB(110, 200, 90), sky = Color3.fromRGB(150, 210, 255),
		eggs = { Common = 60, Uncommon = 28, Rare = 9, Epic = 2.6, Legendary = 0.4 },
	},
	{
		id = "dunes", name = "Sandy Dunes", guardian = "Dune King", speed = 30,
		egg = { base = Color3.fromRGB(245, 215, 160), spot = Color3.fromRGB(200, 140, 80) },
		color = Color3.fromRGB(236, 196, 120), sky = Color3.fromRGB(255, 214, 150),
		eggs = { Common = 56, Uncommon = 29, Rare = 11, Epic = 3.4, Legendary = 0.6 },
	},
	{
		id = "frost", name = "Frostpeak", guardian = "Glacius", speed = 42,
		egg = { base = Color3.fromRGB(230, 245, 255), spot = Color3.fromRGB(130, 195, 255) },
		color = Color3.fromRGB(210, 236, 255), sky = Color3.fromRGB(180, 215, 245),
		eggs = { Common = 52, Uncommon = 30, Rare = 13, Epic = 4.2, Legendary = 0.8 },
	},
	{
		id = "volcano", name = "Magma Mountain", guardian = "Infernus", speed = 56,
		egg = { base = Color3.fromRGB(70, 50, 50), spot = Color3.fromRGB(255, 120, 40), spotNeon = true },
		color = Color3.fromRGB(70, 52, 50), sky = Color3.fromRGB(255, 130, 80),
		eggs = { Uncommon = 58, Rare = 29, Epic = 10, Legendary = 2.6, Mythic = 0.4 },
	},
	{
		id = "thunder", name = "Thunder Cliffs", guardian = "Voltaris", speed = 72,
		egg = { base = Color3.fromRGB(150, 160, 200), spot = Color3.fromRGB(255, 230, 80), spotNeon = true },
		color = Color3.fromRGB(120, 130, 160), sky = Color3.fromRGB(120, 130, 175),
		eggs = { Rare = 62, Epic = 28, Legendary = 8.5, Mythic = 1.5 },
	},
	{
		id = "crystal", name = "Crystal Caverns", guardian = "Prismara", speed = 90,
		egg = { base = Color3.fromRGB(190, 150, 245), spot = Color3.fromRGB(240, 220, 255), mat = "Glass" },
		color = Color3.fromRGB(150, 110, 220), sky = Color3.fromRGB(170, 140, 255),
		eggs = { Rare = 52, Epic = 33, Legendary = 12, Mythic = 3 },
	},
	{
		id = "shadow", name = "Shadow Realm", guardian = "Umbra", speed = 110,
		egg = { base = Color3.fromRGB(45, 35, 65), spot = Color3.fromRGB(170, 90, 255), spotNeon = true },
		color = Color3.fromRGB(45, 30, 70), sky = Color3.fromRGB(70, 40, 110),
		eggs = { Epic = 60, Legendary = 31, Mythic = 9 },
	},
	{
		id = "starfall", name = "Starfall Summit", guardian = "Astralis", speed = 135,
		egg = { base = Color3.fromRGB(35, 40, 100), spot = Color3.fromRGB(255, 240, 160), spotNeon = true },
		color = Color3.fromRGB(40, 50, 110), sky = Color3.fromRGB(30, 30, 80),
		eggs = { Epic = 52, Legendary = 35, Mythic = 13 },
	},
}

Biomes.ById = {}
for i, b in ipairs(Biomes.List) do
	b.index = i
	Biomes.ById[b.id] = b
end

function Biomes.get(id: string)
	return Biomes.ById[id]
end

return Biomes
