-- Dragon income math, shared so the UI shows exactly what the server pays.
-- A dragon record is { sp = speciesId, sz = sizeId, mut = mutationId? }.
local Shared = script.Parent
local Species = require(Shared.Species)
local Traits = require(Shared.Traits)
local Config = require(Shared.Config)

local Value = {}

-- Income per second before the owner's multipliers.
function Value.baseCps(d): number
	local sp = Species.get(d.sp)
	if not sp then
		return 0
	end
	local mut = Traits.mutation(d.mut)
	return sp.cps * Traits.size(d.sz).mult * (mut and mut.mult or 1)
end

-- Owner multiplier from rebirths, passes and boosts.
-- passes: { [key] = true }; boosts: { [key] = expiresAt }
function Value.ownerMult(rebirths: number, passes, boosts, now: number?): number
	local m = 1 + (rebirths or 0) * Config.RebirthIncome
	if passes then
		if passes.DoubleCash then
			m *= 2
		end
		if passes.VIP then
			m *= 1.25
		end
	end
	if boosts and boosts.cash and boosts.cash > (now or os.time()) then
		m *= 2
	end
	return m
end

function Value.cps(d, ownerMult: number?): number
	return Value.baseCps(d) * (ownerMult or 1)
end

function Value.sellPrice(d, ownerMult: number?): number
	return math.floor(Value.cps(d, ownerMult) * Config.SellSeconds)
end

-- "Golden Huge Sprout Drake"
function Value.label(d): string
	local sp = Species.get(d.sp)
	local parts = {}
	local mut = Traits.mutation(d.mut)
	if mut then
		table.insert(parts, mut.name)
	end
	local size = Traits.size(d.sz)
	if size.name ~= "" then
		table.insert(parts, size.name)
	end
	table.insert(parts, sp and sp.name or "???")
	return table.concat(parts, " ")
end

-- Index key for a species + mutation combo ("sprout" / "sprout:gold").
function Value.indexKey(d): string
	return d.mut and (d.sp .. ":" .. d.mut) or d.sp
end

return Value
