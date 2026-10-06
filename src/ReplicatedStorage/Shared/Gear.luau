-- Tools sold in the Gear Shop. Slaps replace each other (you always hold your
-- best one); everything else is a permanent tool with a cooldown.
local Gear = {}

Gear.Slaps = {
	{ id = "slap", name = "Slap Hand", icon = "✋", price = 0, power = 55, range = 9, color = Color3.fromRGB(255, 220, 190) },
	{ id = "iron", name = "Iron Fist", icon = "🥊", price = 6000, power = 75, range = 10, color = Color3.fromRGB(160, 165, 175) },
	{ id = "golden", name = "Golden Glove", icon = "🧤", price = 400000, power = 100, range = 11, color = Color3.fromRGB(255, 200, 40) },
	{ id = "diamond", name = "Diamond Slapper", icon = "💎", price = 40e6, power = 130, range = 12.5, color = Color3.fromRGB(140, 230, 255) },
	{ id = "galaxy", name = "Galaxy Gauntlet", icon = "🌌", price = 4e9, power = 170, range = 14, color = Color3.fromRGB(150, 90, 255) },
}

Gear.Items = {
	{ id = "speedcoil", name = "Speed Coil", icon = "🌀", price = 25000, desc = "+12 speed while held.", cooldown = 0 },
	{ id = "gravity", name = "Gravity Coil", icon = "🎈", price = 90000, desc = "Moon jumps while held. Bounce over hills and away from thieves!", cooldown = 0 },
	{ id = "trap", name = "Bear Trap", icon = "🪤", price = 300000, desc = "Place a trap. Thieves who step on it are stuck for 3s and drop what they carry.", cooldown = 30 },
	{ id = "net", name = "Net Launcher", icon = "🕸️", price = 3e6, desc = "Fire a net that freezes a player for 2.5s.", cooldown = 12 },
	{ id = "cloak", name = "Invisibility Cloak", icon = "👻", price = 25e6, desc = "Turn invisible for 8s. Guardians lose track of you!", cooldown = 45 },
}

Gear.SlapById = {}
for i, s in ipairs(Gear.Slaps) do
	s.tier = i
	Gear.SlapById[s.id] = s
end
Gear.ItemById = {}
for _, it in ipairs(Gear.Items) do
	Gear.ItemById[it.id] = it
end

function Gear.slap(id: string?)
	return Gear.SlapById[id or "slap"] or Gear.Slaps[1]
end

function Gear.item(id: string)
	return Gear.ItemById[id]
end

return Gear
