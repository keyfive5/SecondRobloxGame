-- Daily streak + playtime gift tables (shared so the UI can preview rewards).
-- cashSec pays that many seconds of the player's income (at least `min`).
-- eggs = { rarity, ... } hatch from the best biome the player can reach.
local Rewards = {}

Rewards.DailyCycle = 7
Rewards.Daily = {
	{ cashSec = 120, min = 200, eggs = { "Uncommon" } },
	{ cashSec = 240, min = 400, eggs = { "Rare" } },
	{ cashSec = 360, min = 700, boost = { luck = 900 } },
	{ cashSec = 480, min = 1000, eggs = { "Rare", "Rare" } },
	{ cashSec = 600, min = 1500, eggs = { "Epic" } },
	{ cashSec = 900, min = 2500, boost = { cash = 900 } },
	{ cashSec = 1800, min = 5000, eggs = { "Legendary" } },
}

Rewards.GiftTimes = { 300, 900, 1800, 3600 }
Rewards.Gifts = {
	{ cashSec = 60, min = 100 },
	{ cashSec = 150, min = 300, eggs = { "Rare" } },
	{ cashSec = 300, min = 800, boost = { luck = 600 } },
	{ cashSec = 600, min = 2000, eggs = { "Epic" } },
}

-- Promo codes (case-insensitive). Drop new ones on TikTok / YouTube.
Rewards.Codes = {
	RELEASE = { cash = 2500, eggs = { "Rare" } },
	DRAGONS = { eggs = { "Epic" } },
	RUNFAST = { boost = { luck = 1800 } },
	THANKYOU = { cashSec = 600, min = 5000 },
}

function Rewards.cash(spec, income: number): number
	if spec.cash then
		return spec.cash
	end
	if not spec.cashSec then
		return 0
	end
	return math.max(spec.min or 0, math.floor((income or 0) * spec.cashSec))
end

-- Short human description for UI previews.
function Rewards.describe(spec): string
	local parts = {}
	if spec.cash or spec.cashSec then
		table.insert(parts, spec.cash and ("$" .. spec.cash) or "💰 Cash")
	end
	for _, r in ipairs(spec.eggs or {}) do
		table.insert(parts, "🥚 " .. r)
	end
	if spec.boost then
		if spec.boost.luck then
			table.insert(parts, "🔮 2x Luck")
		end
		if spec.boost.cash then
			table.insert(parts, "💸 2x Cash")
		end
	end
	return table.concat(parts, " + ")
end

return Rewards
