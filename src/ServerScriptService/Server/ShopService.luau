-- Cash purchases: speed upgrades, extra pads, gear, rebirths.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Gear = require(Shared.Gear)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local PlayerService = require(script.Parent.PlayerService)
local ToolService = require(script.Parent.ToolService)
local Sync = require(script.Parent.Sync)
local Signals = require(script.Parent.Signals)

local ShopService = {}

local function dataOf(player: Player)
	local p = DataService.get(player)
	return p and p.data
end

function ShopService.buySpeed(player: Player, count): number
	local data = dataOf(player)
	if not data then
		return 0
	end
	local want = count == "max" and Config.MaxSpeedLevel or math.clamp(math.floor(tonumber(count) or 1), 1, 100)
	local bought = 0
	while bought < want and data.speedLv < Config.MaxSpeedLevel do
		local cost = Config.speedCost(Config.BaseSpeed + data.speedLv)
		if not Economy.spend(player, cost) then
			break
		end
		data.speedLv += 1
		bought += 1
	end
	if bought > 0 then
		Sync.set(player, "speedLv", data.speedLv)
		PlayerService.refreshSpeed(player)
		Signals.progress(player, "speed", bought)
	end
	return bought
end

function ShopService.addSpeedLevels(player: Player, n: number)
	local data = dataOf(player)
	if not data then
		return
	end
	data.speedLv = math.min(Config.MaxSpeedLevel, data.speedLv + n)
	Sync.set(player, "speedLv", data.speedLv)
	PlayerService.refreshSpeed(player)
end

function ShopService.buyPad(player: Player): boolean
	local data = dataOf(player)
	if not data or data.padUp >= Config.MaxPadUpgrades then
		return false
	end
	if not Economy.spend(player, Config.PadUpgradeCost(data.padUp)) then
		return false
	end
	data.padUp += 1
	Sync.set(player, "padUp", data.padUp)
	BaseService.replicateAll(player)
	Sync.notify(player, "🏰 New dragon pad unlocked!", "good")
	return true
end

function ShopService.buyGear(player: Player, kind: string, id: string): boolean
	local data = dataOf(player)
	if not data then
		return false
	end
	if kind == "slap" then
		local tier = Gear.SlapById[id]
		local cur = Gear.slap(data.gear.slap)
		if not tier or tier.tier <= cur.tier then
			return false
		end
		if not Economy.spend(player, tier.price) then
			return false
		end
		data.gear.slap = id
	elseif kind == "item" then
		local item = Gear.item(id)
		if not item or data.gear.items[id] then
			return false
		end
		if not Economy.spend(player, item.price) then
			return false
		end
		data.gear.items[id] = true
	else
		return false
	end
	Sync.set(player, "gear", data.gear)
	ToolService.giveTools(player)
	Sync.notify(player, "🛠️ New gear! Check your hotbar.", "good")
	return true
end

function ShopService.rebirth(player: Player): boolean
	local data = dataOf(player)
	if not data or data.rebirths >= Config.MaxRebirths then
		return false
	end
	local cost = Config.rebirthCost(data.rebirths)
	if data.cash < cost then
		return false
	end
	if CarryService.get(player) then
		CarryService.drop(player, "died")
	end
	-- thieves currently robbing this base lose the loot
	for thief, c in pairs(CarryService.all()) do
		if c.source.type == "base" and c.source.slot == BaseService.slot(player) then
			CarryService.drop(thief, "ownerLeft")
		end
	end
	data.cash = 0
	data.speedLv = 0
	data.padUp = 0
	data.pads = {}
	data.rebirths += 1
	data.stats.rebirthsTotal = (data.stats.rebirthsTotal or 0) + 1
	Economy.addCash(player, 0)
	Economy.leaderstat(player, "Cash", 0)
	Economy.leaderstat(player, "Rebirths", data.rebirths)
	Sync.set(player, "cash", 0)
	Sync.set(player, "speedLv", 0)
	Sync.set(player, "padUp", 0)
	Sync.set(player, "rebirths", data.rebirths)
	BaseService.rebase(player)
	PlayerService.refreshSpeed(player)
	Sync.notifyAll(string.format("🌀 %s reached Rebirth %d!", player.DisplayName, data.rebirths), "rare")
	-- a free starter egg so the base isn't empty
	BaseService.placeEgg(player, { b = 1, r = "Rare", ready = workspace:GetServerTimeNow() + 3 })
	return true
end

function ShopService.start()
	Net.func("BuySpeed").OnServerInvoke = function(player, count)
		return ShopService.buySpeed(player, count)
	end
	Net.func("BuyPad").OnServerInvoke = function(player)
		return ShopService.buyPad(player)
	end
	Net.func("BuyGear").OnServerInvoke = function(player, kind, id)
		if type(kind) ~= "string" or type(id) ~= "string" then
			return false
		end
		return ShopService.buyGear(player, kind, id)
	end
	Net.func("Rebirth").OnServerInvoke = function(player)
		return ShopService.rebirth(player)
	end
end

return ShopService
