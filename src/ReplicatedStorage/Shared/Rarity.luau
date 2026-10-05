-- Rarity tiers: display colors and ordering.
local Rarity = {}

Rarity.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarity.Info = {
	Common = { color = Color3.fromRGB(196, 202, 214), rank = 1 },
	Uncommon = { color = Color3.fromRGB(96, 222, 110), rank = 2 },
	Rare = { color = Color3.fromRGB(70, 160, 255), rank = 3 },
	Epic = { color = Color3.fromRGB(184, 98, 255), rank = 4 },
	Legendary = { color = Color3.fromRGB(255, 188, 40), rank = 5 },
	Mythic = { color = Color3.fromRGB(255, 70, 130), rank = 6 },
	Secret = { color = Color3.fromRGB(20, 20, 26), rank = 7, rainbow = true },
}

function Rarity.color(r: string): Color3
	local i = Rarity.Info[r]
	return i and i.color or Color3.new(1, 1, 1)
end

function Rarity.rank(r: string): number
	local i = Rarity.Info[r]
	return i and i.rank or 0
end

-- Rich-text hex for a rarity name.
function Rarity.hex(r: string): string
	if r == "Secret" then
		return "#ffffff"
	end
	return "#" .. Rarity.color(r):ToHex()
end

return Rarity
