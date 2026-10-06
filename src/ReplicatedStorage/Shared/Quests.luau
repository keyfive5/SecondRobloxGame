-- Daily quest pool. Three are picked per day (same for everyone that day), plus a
-- bonus for finishing all three. `need` is scaled by the player's progress on the
-- server when it's a cash goal.
local Quests = {}

Quests.Pool = {
	{ id = "eggs5", kind = "egg", need = 5, text = "Bring home %d eggs", reward = { cashSec = 300, min = 500 } },
	{ id = "eggs10", kind = "egg", need = 10, text = "Bring home %d eggs", reward = { cashSec = 600, min = 1500, eggs = { "Rare" } } },
	{ id = "hatch6", kind = "hatch", need = 6, text = "Hatch %d eggs", reward = { cashSec = 400, min = 800 } },
	{ id = "hatch12", kind = "hatch", need = 12, text = "Hatch %d eggs", reward = { cashSec = 700, min = 2000, eggs = { "Epic" } } },
	{ id = "collect", kind = "collect", need = 900, cashGoal = true, text = "Collect %s from your dragons", reward = { cashSec = 500, min = 1000 } },
	{ id = "speed3", kind = "speed", need = 3, text = "Buy %d speed upgrades", reward = { boost = { luck = 900 } } },
	{ id = "steal1", kind = "steal", need = 1, text = "Steal %d dragon or egg from another base", reward = { cashSec = 900, min = 3000, eggs = { "Epic" } }, weight = 0.6 },
	{ id = "sell3", kind = "sell", need = 3, text = "Sell %d dragons", reward = { cashSec = 300, min = 500 } },
}

Quests.Bonus = { cashSec = 1200, min = 5000, eggs = { "Legendary" } }

Quests.ById = {}
for _, q in ipairs(Quests.Pool) do
	Quests.ById[q.id] = q
end

-- Deterministic daily pick so everyone shares the same quests each day.
function Quests.forDay(day: number): { string }
	local rng = Random.new(day * 7919)
	local pool = table.clone(Quests.Pool)
	local out = {}
	while #out < 3 and #pool > 0 do
		local total = 0
		for _, q in ipairs(pool) do
			total += q.weight or 1
		end
		local pick = rng:NextNumber() * total
		for i, q in ipairs(pool) do
			pick -= q.weight or 1
			if pick <= 0 then
				-- one quest per kind
				local dupe = false
				for _, id in ipairs(out) do
					if Quests.ById[id].kind == q.kind then
						dupe = true
					end
				end
				if not dupe then
					table.insert(out, q.id)
				end
				table.remove(pool, i)
				break
			end
		end
	end
	return out
end

return Quests
