-- Cash in and out. Every change goes through here so leaderstats, the client
-- mirror and lifetime stats stay in sync.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Sync = require(script.Parent.Sync)

local Economy = {}

local changed = Instance.new("BindableEvent")
Economy.CashChanged = changed.Event -- (player, cash, delta)

local function leaderstat(player: Player, name: string, value: number)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	if v then
		v.Value = value
	end
end
Economy.leaderstat = leaderstat

function Economy.cash(player: Player): number
	local profile = DataService.get(player)
	return profile and profile.data.cash or 0
end

-- earned = counts toward lifetime earnings and quests (not refunds/admin grants)
function Economy.addCash(player: Player, amount: number, earned: boolean?)
	local profile = DataService.get(player)
	if not profile or amount == 0 then
		return
	end
	local data = profile.data
	data.cash = math.max(0, data.cash + amount)
	if amount > 0 and earned ~= false then
		data.stats.earned += amount
	end
	leaderstat(player, "Cash", data.cash)
	Sync.set(player, "cash", data.cash)
	changed:Fire(player, data.cash, amount)
end

-- Returns true and deducts if the player can afford it.
function Economy.spend(player: Player, amount: number): boolean
	local profile = DataService.get(player)
	if not profile or amount < 0 or profile.data.cash < amount then
		return false
	end
	profile.data.cash -= amount
	leaderstat(player, "Cash", profile.data.cash)
	Sync.set(player, "cash", profile.data.cash)
	changed:Fire(player, profile.data.cash, -amount)
	return true
end

return Economy
