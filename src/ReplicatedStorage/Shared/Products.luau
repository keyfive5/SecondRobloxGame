-- Robux products (created on the Creator Hub for universe 10769557581).
-- Anything left at id 0 is hidden from the store automatically.
local Products = {}

Products.Passes = {
	{ key = "DoubleCash", id = 2005557713, price = 449, icon = "💰", name = "2x Cash", desc = "Every dragon earns double, forever." },
	{ key = "VIP", id = 2004927687, price = 299, icon = "👑", name = "VIP", desc = "+25% cash, 8h offline income, VIP chat tag & golden name." },
	{ key = "AutoCollect", id = 2005587648, price = 199, icon = "🧲", name = "Auto Collect", desc = "Cash from your dragons goes straight to your wallet." },
	{ key = "Lucky", id = 2006127644, price = 299, icon = "🍀", name = "Lucky Hatcher", desc = "2x mutation chance and bigger dragons when eggs hatch." },
	{ key = "FastHatch", id = 2005095577, price = 149, icon = "⏩", name = "Fast Hatch", desc = "Eggs hatch twice as fast." },
	{ key = "MegaBase", id = 2006721594, price = 249, icon = "🏰", name = "Mega Base", desc = "+4 dragon pads in your base." },
	{ key = "SuperLock", id = 2007003730, price = 179, icon = "🔒", name = "Super Lock", desc = "Locks last 2 minutes and you can lock from anywhere." },
	{ key = "SpeedBoost", id = 2005905693, price = 249, icon = "👟", name = "Speed Boots", desc = "+25% walk speed. Outrun every guardian." },
}

-- kind: cash | hatch | lock | boost | serverluck | event | egg | speed
Products.Dev = {
	{ key = "Cash1", id = 3716788604, price = 29, icon = "💵", name = "Wad of Cash", kind = "cash", seconds = 600, min = 500 },
	{ key = "Cash2", id = 3716788647, price = 99, icon = "💰", name = "Bag of Cash", kind = "cash", seconds = 2700, min = 3000 },
	{ key = "Cash3", id = 3716788651, price = 299, icon = "💎", name = "Vault of Cash", kind = "cash", seconds = 10800, min = 15000 },
	{ key = "Cash4", id = 3716788663, price = 999, icon = "👑", name = "Dragon Hoard", kind = "cash", seconds = 43200, min = 75000 },
	{ key = "HatchNow", id = 3716788675, price = 19, icon = "🐣", name = "Hatch Now", kind = "hatch" },
	{ key = "LockBase", id = 3716788681, price = 39, icon = "🔒", name = "5-Minute Lock", kind = "lock", seconds = 300 },
	{ key = "CashBoost", id = 3716788688, price = 49, icon = "💸", name = "2x Cash (15 min)", kind = "boost", boost = "cash", seconds = 900 },
	{ key = "LuckBoost", id = 3716788698, price = 49, icon = "🔮", name = "2x Luck (15 min)", kind = "boost", boost = "luck", seconds = 900 },
	{ key = "AdLuck", id = 3716788712, price = 19, icon = "🍀", name = "Lucky Hatch (10 min)", kind = "boost", boost = "luck", seconds = 600, ad = true },
	{ key = "ServerLuck", id = 3716788720, price = 199, icon = "🌈", name = "Server Luck (15 min)", kind = "serverluck", seconds = 900 },
	{ key = "Speed10", id = 3716788735, price = 39, icon = "⚡", name = "+10 Speed", kind = "speed", amount = 10 },
	{ key = "Event_golden", id = 3716788744, price = 149, icon = "🌟", name = "Golden Hour", kind = "event", event = "golden" },
	{ key = "Event_meteor", id = 3716788760, price = 199, icon = "☄️", name = "Meteor Shower", kind = "event", event = "meteor" },
	{ key = "Event_bloodmoon", id = 3716788769, price = 249, icon = "🌑", name = "Blood Moon", kind = "event", event = "bloodmoon" },
	{ key = "Event_secret", id = 3716788779, price = 399, icon = "❓", name = "Secret Egg", kind = "event", event = "secret" },
	-- Buy a nest egg safely (skips the chase). One product per rarity tier; the
	-- server remembers which egg was clicked.
	{ key = "Egg_Common", id = 3716788789, price = 9, kind = "egg", rarity = "Common" },
	{ key = "Egg_Uncommon", id = 3716788796, price = 19, kind = "egg", rarity = "Uncommon" },
	{ key = "Egg_Rare", id = 3716788809, price = 39, kind = "egg", rarity = "Rare" },
	{ key = "Egg_Epic", id = 3716788821, price = 79, kind = "egg", rarity = "Epic" },
	{ key = "Egg_Legendary", id = 3716788835, price = 149, kind = "egg", rarity = "Legendary" },
	{ key = "Egg_Mythic", id = 3716788842, price = 299, kind = "egg", rarity = "Mythic" },
	{ key = "Egg_Secret", id = 3716788852, price = 699, kind = "egg", rarity = "Secret" },
}

Products.PassByKey = {}
Products.PassById = {}
for _, p in ipairs(Products.Passes) do
	Products.PassByKey[p.key] = p
	if p.id ~= 0 then
		Products.PassById[p.id] = p
	end
end

Products.DevByKey = {}
Products.DevById = {}
for _, p in ipairs(Products.Dev) do
	Products.DevByKey[p.key] = p
	if p.id ~= 0 then
		Products.DevById[p.id] = p
	end
end

function Products.devId(key: string): number
	local p = Products.DevByKey[key]
	return p and p.id or 0
end

function Products.passId(key: string): number
	local p = Products.PassByKey[key]
	return p and p.id or 0
end

function Products.eggProduct(rarity: string)
	return Products.DevByKey["Egg_" .. rarity]
end

-- Cash packs scale with income so they stay worth buying.
function Products.cashAmount(product, incomePerSec: number): number
	return math.max(product.min or 0, math.floor((incomePerSec or 0) * (product.seconds or 600)))
end

return Products
