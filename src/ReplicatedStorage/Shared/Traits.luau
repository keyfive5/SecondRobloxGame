-- Rolled when an egg hatches: a size and (rarely) a mutation. Both multiply income.
local Traits = {}

Traits.Sizes = {
	{ id = "tiny", name = "Tiny", mult = 0.75, scale = 0.8, weight = 12 },
	{ id = "normal", name = "", mult = 1, scale = 1, weight = 62 },
	{ id = "big", name = "Big", mult = 1.5, scale = 1.25, weight = 18 },
	{ id = "huge", name = "Huge", mult = 2.5, scale = 1.6, weight = 6.5 },
	{ id = "giant", name = "Giant", mult = 5, scale = 2.1, weight = 1.5 },
}

-- `chance` is per hatch (percent). Event-only mutations have chance 0 and only
-- appear during their server event.
Traits.Mutations = {
	{ id = "gold", name = "Golden", mult = 2, chance = 4, color = Color3.fromRGB(255, 200, 40) },
	{ id = "diamond", name = "Diamond", mult = 3, chance = 1.5, color = Color3.fromRGB(150, 230, 255) },
	{ id = "rainbow", name = "Rainbow", mult = 5, chance = 0.5, color = Color3.fromRGB(255, 120, 200) },
	{ id = "lava", name = "Lava", mult = 4, chance = 0, color = Color3.fromRGB(255, 110, 30) },
	{ id = "frozen", name = "Frozen", mult = 3, chance = 0, color = Color3.fromRGB(170, 230, 255) },
	{ id = "blood", name = "Blood Moon", mult = 6, chance = 0, color = Color3.fromRGB(220, 30, 50) },
	{ id = "galaxy", name = "Galaxy", mult = 10, chance = 0.15, color = Color3.fromRGB(140, 90, 255) },
}

Traits.SizeById = {}
for _, s in ipairs(Traits.Sizes) do
	Traits.SizeById[s.id] = s
end
Traits.MutById = {}
for _, m in ipairs(Traits.Mutations) do
	Traits.MutById[m.id] = m
end

function Traits.size(id: string?)
	return Traits.SizeById[id or "normal"] or Traits.SizeById.normal
end

function Traits.mutation(id: string?)
	return id and Traits.MutById[id] or nil
end

-- luckMult scales every mutation chance (passes, potions, events).
-- eventMut: id of a mutation the current server event can give, with its chance.
function Traits.roll(rng: Random, luckMult: number?, eventMut: string?, eventChance: number?, sizeLuck: number?)
	luckMult = luckMult or 1
	sizeLuck = sizeLuck or 1
	-- size: luck shifts weight away from tiny/normal toward the big sizes
	local total = 0
	local weights = {}
	for i, s in ipairs(Traits.Sizes) do
		local w = s.weight
		if i >= 3 then
			w *= sizeLuck
		end
		weights[i] = w
		total += w
	end
	local pick = rng:NextNumber() * total
	local size = "normal"
	for i, s in ipairs(Traits.Sizes) do
		pick -= weights[i]
		if pick <= 0 then
			size = s.id
			break
		end
	end
	-- mutation: rarest first so a lucky roll lands on the best one
	local mut = nil
	if eventMut and eventChance and rng:NextNumber() * 100 < eventChance * luckMult then
		mut = eventMut
	else
		for i = #Traits.Mutations, 1, -1 do
			local m = Traits.Mutations[i]
			if m.chance > 0 and rng:NextNumber() * 100 < m.chance * luckMult then
				mut = m.id
				break
			end
		end
	end
	return size, mut
end

return Traits
