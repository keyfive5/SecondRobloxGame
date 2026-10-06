-- Daily quests: progress comes from Signals.progress, rewards via RewardsService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Quests)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local RewardsService = require(script.Parent.RewardsService)
local Signals = require(script.Parent.Signals)
local Sync = require(script.Parent.Sync)

local QuestService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Make sure the player's quest list is for today.
local function ensure(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local q = profile.data.quests
	local d = today()
	if q.day ~= d then
		q.day = d
		q.bonus = false
		q.list = {}
		local income = BaseService.income(player)
		for _, id in ipairs(Quests.forDay(d)) do
			local def = Quests.ById[id]
			local need = def.need
			if def.cashGoal then
				need = math.max(200, math.floor(income * def.need))
			end
			table.insert(q.list, { id = id, need = need, have = 0, claimed = false })
		end
		Sync.set(player, "quests", q)
	end
	return q
end

function QuestService.claim(player: Player, index: number)
	local q = ensure(player)
	local entry = q and q.list[index]
	if not entry or entry.claimed or entry.have < entry.need then
		return false
	end
	entry.claimed = true
	RewardsService.give(player, Quests.ById[entry.id].reward, "📜 Quest complete: ")
	Sync.set(player, "quests", q)
	return true
end

function QuestService.claimBonus(player: Player)
	local q = ensure(player)
	if not q or q.bonus then
		return false
	end
	for _, e in ipairs(q.list) do
		if not e.claimed then
			return false
		end
	end
	q.bonus = true
	RewardsService.give(player, Quests.Bonus, "🏆 All quests done! ")
	Sync.set(player, "quests", q)
	return true
end

function QuestService.start()
	Signals.Progress:Connect(function(player, kind, amount)
		local q = ensure(player)
		if not q then
			return
		end
		local changed = false
		for _, e in ipairs(q.list) do
			local def = Quests.ById[e.id]
			if def and def.kind == kind and e.have < e.need then
				local before = e.have
				e.have = math.min(e.need, e.have + amount)
				changed = true
				if before < e.need and e.have >= e.need then
					Sync.notify(player, "📜 Quest ready to claim! Open Quests.", "good")
				end
			end
		end
		if changed then
			Sync.set(player, "quests", q)
		end
	end)
	DataService.Loaded:Connect(function(player)
		ensure(player)
	end)
	Net.func("ClaimQuest").OnServerInvoke = function(player, index)
		if index == "bonus" then
			return QuestService.claimBonus(player)
		end
		return QuestService.claim(player, tonumber(index) or 0)
	end
	-- roll quests over at midnight UTC for players who stay online
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pairs(DataService.Profiles) do
				ensure(player)
			end
		end
	end)
end

return QuestService
