-- Daily login streak, session playtime gifts, promo codes, invite rewards,
-- settings and tutorial progress.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rewards = require(Shared.Rewards)
local Biomes = require(Shared.Biomes)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local BaseService = require(script.Parent.BaseService)
local PlayerService = require(script.Parent.PlayerService)
local Sync = require(script.Parent.Sync)

local RewardsService = {}

local sessionStart = {}
local giftsClaimed = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Highest biome the player's current speed can escape.
function RewardsService.bestBiome(player: Player): number
	local speed = PlayerService.baseSpeed(player)
	local best = 1
	for i, b in ipairs(Biomes.List) do
		if speed >= b.speed then
			best = i
		end
	end
	return best
end

local function give(player: Player, spec, label: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local parts = {}
	local cash = Rewards.cash(spec, BaseService.income(player))
	if cash > 0 then
		Economy.addCash(player, cash, false)
		table.insert(parts, Format.cash(cash))
	end
	local biome = RewardsService.bestBiome(player)
	for _, rarity in ipairs(spec.eggs or {}) do
		-- make sure the rarity exists in that biome's egg pool
		local b = biome
		while b > 1 and not Biomes.List[b].eggs[rarity] do
			b -= 1
		end
		if not Biomes.List[b].eggs[rarity] then
			b = math.min(#Biomes.List, biome + 1)
		end
		if BaseService.placeEgg(player, { b = b, r = rarity }) then
			table.insert(parts, rarity .. " Egg")
		else
			local extra = Rewards.cash({ cashSec = 300, min = 1000 }, BaseService.income(player))
			Economy.addCash(player, extra, false)
			table.insert(parts, Format.cash(extra) .. " (base full)")
		end
	end
	if spec.boost then
		local t = os.time()
		for key, seconds in pairs(spec.boost) do
			profile.data.boosts[key] = math.max(profile.data.boosts[key] or 0, t) + seconds
			table.insert(parts, (key == "luck" and "2x Luck " or "2x Cash ") .. Format.duration(seconds))
		end
		Sync.set(player, "boosts", profile.data.boosts)
		if spec.boost.cash then
			BaseService.rebase(player)
		end
	end
	Sync.notify(player, label .. table.concat(parts, " + "), "good")
end
RewardsService.give = give

function RewardsService.dailyStatus(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local d = profile.data.daily
	local t = today()
	local canClaim = d.last < t
	local streak = d.streak
	if canClaim and d.last < t - 1 then
		streak = 0
	end
	return { canClaim = canClaim, streak = streak, nextDay = (streak % Rewards.DailyCycle) + 1, resetsIn = (t + 1) * 86400 - os.time() }
end

function RewardsService.claimDaily(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	local d = profile.data.daily
	local t = today()
	if d.last >= t then
		return false, "Come back tomorrow!"
	end
	if d.last < t - 1 then
		d.streak = 0
	end
	d.streak += 1
	d.last = t
	local day = ((d.streak - 1) % Rewards.DailyCycle) + 1
	give(player, Rewards.Daily[day], string.format("🎁 Day %d: ", day))
	Sync.set(player, "daily", d)
	return true, day
end

function RewardsService.claimGift(player: Player, index: number)
	local need = Rewards.GiftTimes[index]
	local start = sessionStart[player]
	if not need or not start then
		return false
	end
	giftsClaimed[player] = giftsClaimed[player] or {}
	if giftsClaimed[player][index] then
		return false, "Already claimed!"
	end
	if os.time() - start < need then
		return false, "Not ready yet!"
	end
	giftsClaimed[player][index] = true
	give(player, Rewards.Gifts[index], "⏰ Gift: ")
	return true
end

function RewardsService.redeem(player: Player, code: string)
	local profile = DataService.get(player)
	if not profile or type(code) ~= "string" then
		return false, "Try again"
	end
	code = string.upper((code:gsub("%s", ""))):sub(1, 30)
	local spec = Rewards.Codes[code]
	if not spec then
		return false, "That code doesn't exist (yet!)"
	end
	if profile.data.codes[code] then
		return false, "You already used this code!"
	end
	profile.data.codes[code] = true
	Sync.set(player, "codes", profile.data.codes)
	give(player, spec, "🎉 Code redeemed: ")
	return true
end

function RewardsService.start()
	Net.func("DailyStatus").OnServerInvoke = function(player)
		return RewardsService.dailyStatus(player)
	end
	Net.func("ClaimDaily").OnServerInvoke = function(player)
		return RewardsService.claimDaily(player)
	end
	Net.func("GiftStatus").OnServerInvoke = function(player)
		local start = sessionStart[player] or os.time()
		return { elapsed = os.time() - start, claimed = giftsClaimed[player] or {} }
	end
	Net.func("ClaimGift").OnServerInvoke = function(player, index)
		return RewardsService.claimGift(player, tonumber(index) or 0)
	end
	Net.func("Redeem").OnServerInvoke = function(player, code)
		return RewardsService.redeem(player, code)
	end
	Net.func("SetTutorial").OnServerInvoke = function(player, step)
		local profile = DataService.get(player)
		if profile and type(step) == "number" and step > profile.data.tutorial and (step <= 20 or step == 99) then
			profile.data.tutorial = math.floor(step)
			Sync.set(player, "tutorial", profile.data.tutorial)
		end
		return true
	end
	Net.func("SaveSettings").OnServerInvoke = function(player, settings)
		local profile = DataService.get(player)
		if profile and type(settings) == "table" then
			for _, k in ipairs({ "music", "sfx" }) do
				local v = tonumber(settings[k])
				if v then
					profile.data.settings[k] = math.clamp(v, 0, 1)
				end
			end
		end
		return true
	end
	Net.func("FavPrompted").OnServerInvoke = function(player)
		local profile = DataService.get(player)
		if profile and not profile.data.favPrompted then
			profile.data.favPrompted = true
			return true
		end
		return false
	end

	DataService.Loaded:Connect(function(player, profile)
		sessionStart[player] = os.time()
		player:SetAttribute("SessionStart", sessionStart[player])
		-- brand-new players start with a free egg already incubating
		if profile.data.stats.joins <= 1 and not profile.data.starterEgg then
			profile.data.starterEgg = true
			task.delay(2, function()
				if player.Parent then
					BaseService.placeEgg(player, { b = 1, r = "Uncommon", ready = workspace:GetServerTimeNow() + 6 })
				end
			end)
		end
		-- invite rewards: whoever invited this player gets a gift (once per friend)
		local ok, join = pcall(player.GetJoinData, player)
		local referrerId = ok and join and join.ReferredByPlayerId
		if referrerId and referrerId ~= 0 and referrerId ~= player.UserId then
			local referrer = Players:GetPlayerByUserId(referrerId)
			local rp = referrer and DataService.get(referrer)
			if rp then
				rp.data.referrals = rp.data.referrals or {}
				if not rp.data.referrals[tostring(player.UserId)] then
					rp.data.referrals[tostring(player.UserId)] = true
					give(referrer, { cashSec = 600, min = 2000, eggs = { "Epic" } }, "👥 " .. player.DisplayName .. " joined from your invite! ")
				end
			end
			if not profile.data.referredBy then
				profile.data.referredBy = referrerId
				task.delay(3, function()
					if player.Parent then
						give(player, { cash = 500, eggs = { "Rare" } }, "👋 Welcome gift for joining a friend: ")
					end
				end)
			end
		end
	end)
	DataService.Releasing:Connect(function(player, profile)
		if sessionStart[player] then
			sessionStart[player] = os.time()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			sessionStart[player] = nil
			giftsClaimed[player] = nil
		end)
	end)
end

function RewardsService.sessionSeconds(player: Player): number
	return sessionStart[player] and (os.time() - sessionStart[player]) or 0
end

return RewardsService
