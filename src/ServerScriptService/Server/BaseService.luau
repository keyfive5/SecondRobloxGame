-- Bases: slot assignment, pads (eggs incubating, dragons earning), collecting,
-- hatching, selling, locking and offline income.
--
-- Each pad record lives in the owner's save under data.pads["n"]:
--   egg:    { k = "egg", b = biome, r = rarity, ready = unix }
--   dragon: { k = "dragon", sp, sz, mut, s = stored cash at t, t = unix, c = cash/sec }
-- Stored cash grows as s + c * (now - t), so nothing ticks per second; clients
-- compute the same number from the replicated record.
-- Replication: ReplicatedStorage.BaseData.Base_i (attributes + StringValues P1..P20).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Species = require(Shared.Species)
local Traits = require(Shared.Traits)
local Value = require(Shared.Value)
local Rarity = require(Shared.Rarity)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Sync = require(script.Parent.Sync)
local WorldState = require(script.Parent.WorldState)
local Signals = require(script.Parent.Signals)

local BaseService = {}

local slotOwner = {} :: { [number]: Player }
local slotOf = {} :: { [Player]: number }
local cachedMult = {} :: { [Player]: number }
local joinedAt = {} :: { [Player]: number }
local stealing = {} -- [slot] = { [pad] = thief }
local folders = {} -- [slot] = Folder
local fxEvent = Net.event("BaseFx")
local rng = Random.new()

local assigned = Instance.new("BindableEvent")
BaseService.Assigned = assigned.Event -- (player, slot)
local incomeChanged = Instance.new("BindableEvent")
BaseService.IncomeChanged = incomeChanged.Event -- (player, income)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function hasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end
BaseService.hasPass = hasPass

local function dataOf(player: Player)
	local p = DataService.get(player)
	return p and p.data
end

function BaseService.slot(player: Player): number?
	return slotOf[player]
end

function BaseService.ownerOf(slot: number): Player?
	return slotOwner[slot]
end

function BaseService.padCount(player: Player): number
	local data = dataOf(player)
	if not data then
		return 0
	end
	local n = Config.StartPads + math.min(data.padUp, Config.MaxPadUpgrades)
	if hasPass(player, "MegaBase") then
		n += Config.PassPads
	end
	return math.min(n, Layout.MaxPads)
end

function BaseService.ownerMult(player: Player): number
	local data = dataOf(player)
	if not data then
		return 1
	end
	return Value.ownerMult(data.rebirths, { DoubleCash = hasPass(player, "DoubleCash"), VIP = hasPass(player, "VIP") }, data.boosts, os.time())
end

local function stored(rec, t: number): number
	if rec.k ~= "dragon" then
		return 0
	end
	return (rec.s or 0) + (rec.c or 0) * math.max(0, t - (rec.t or t))
end
BaseService.stored = stored

---------------------------------------------------------------------------
-- Replication
---------------------------------------------------------------------------
local root = Instance.new("Folder")
root.Name = "BaseData"
for slot = 1, Layout.BaseCount do
	local f = Instance.new("Folder")
	f.Name = "Base_" .. slot
	f:SetAttribute("Slot", slot)
	for n = 1, Layout.MaxPads do
		local v = Instance.new("StringValue")
		v.Name = "P" .. n
		v.Parent = f
	end
	f.Parent = root
	folders[slot] = f
end
root.Parent = ReplicatedStorage

local function encode(rec): string
	if not rec then
		return ""
	end
	return HttpService:JSONEncode(rec)
end

local function replicatePad(player: Player, n: number)
	local slot = slotOf[player]
	local data = dataOf(player)
	if not slot or not data then
		return
	end
	folders[slot]["P" .. n].Value = encode(data.pads[tostring(n)])
end
BaseService.replicatePad = replicatePad

function BaseService.income(player: Player): number
	local data = dataOf(player)
	if not data then
		return 0
	end
	local total = 0
	for _, rec in pairs(data.pads) do
		if rec.k == "dragon" then
			total += rec.c or 0
		end
	end
	return total
end

local function updateIncome(player: Player)
	local slot = slotOf[player]
	local income = BaseService.income(player)
	if slot then
		folders[slot]:SetAttribute("Income", income)
	end
	player:SetAttribute("Income", income)
	local data = dataOf(player)
	if data and income > (data.stats.bestCps or 0) then
		data.stats.bestCps = income
	end
	incomeChanged:Fire(player, income)
end
BaseService.updateIncome = updateIncome

local function replicateAll(player: Player)
	local slot = slotOf[player]
	if not slot then
		return
	end
	local f = folders[slot]
	f:SetAttribute("Pads", BaseService.padCount(player))
	f:SetAttribute("Mult", cachedMult[player] or 1)
	for n = 1, Layout.MaxPads do
		replicatePad(player, n)
	end
	updateIncome(player)
end
BaseService.replicateAll = replicateAll

local function setSign(slot: number, text: string)
	local base = workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild("Base_" .. slot)
	local sign = base and base:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChild("OwnerLabel")
	if label then
		label.Text = text
	end
end

---------------------------------------------------------------------------
-- Multipliers: recompute every dragon's rate when the owner's multiplier changes.
---------------------------------------------------------------------------
function BaseService.rebase(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	local mult = BaseService.ownerMult(player)
	local t = now()
	for _, rec in pairs(data.pads) do
		if rec.k == "dragon" then
			rec.s = stored(rec, t)
			rec.t = t
			rec.c = Value.cps(rec, mult)
		end
	end
	cachedMult[player] = mult
	replicateAll(player)
end

---------------------------------------------------------------------------
-- Pads
---------------------------------------------------------------------------
function BaseService.getPad(player: Player, n: number)
	local data = dataOf(player)
	return data and data.pads[tostring(n)]
end

function BaseService.isStealing(slot: number, n: number): Player?
	return stealing[slot] and stealing[slot][n]
end

-- First empty pad (not counting pads being stolen from).
function BaseService.freePad(player: Player): number?
	local data = dataOf(player)
	if not data then
		return nil
	end
	for n = 1, BaseService.padCount(player) do
		if not data.pads[tostring(n)] then
			return n
		end
	end
	return nil
end

function BaseService.freeCount(player: Player): number
	local data = dataOf(player)
	if not data then
		return 0
	end
	local c = 0
	for n = 1, BaseService.padCount(player) do
		if not data.pads[tostring(n)] then
			c += 1
		end
	end
	return c
end

function BaseService.hatchSeconds(player: Player, rarity: string): number
	local t = Config.HatchTime[rarity] or 10
	if hasPass(player, "FastHatch") then
		t *= 0.5
	end
	return t
end

-- egg = { b = biome (0 = secret), r = rarity, ready = optional unix }
function BaseService.placeEgg(player: Player, egg, n: number?): number?
	local data = dataOf(player)
	n = n or BaseService.freePad(player)
	if not data or not n then
		return nil
	end
	local rec = { k = "egg", b = egg.b, r = egg.r, ready = egg.ready or (now() + BaseService.hatchSeconds(player, egg.r)) }
	data.pads[tostring(n)] = rec
	replicatePad(player, n)
	fxEvent:FireAllClients(slotOf[player], n, "place")
	return n
end

-- d = { sp, sz, mut }
function BaseService.placeDragon(player: Player, d, n: number?): number?
	local data = dataOf(player)
	n = n or BaseService.freePad(player)
	if not data or not n then
		return nil
	end
	local mult = cachedMult[player] or BaseService.ownerMult(player)
	local rec = { k = "dragon", sp = d.sp, sz = d.sz or "normal", mut = d.mut, s = 0, t = now(), c = Value.cps(d, mult) }
	data.pads[tostring(n)] = rec
	local key = Value.indexKey(rec)
	local isNew = not data.index[key]
	if isNew then
		data.index[key] = true
		if not data.index[rec.sp] then
			data.index[rec.sp] = true
		end
		Sync.set(player, "index", data.index)
	end
	replicatePad(player, n)
	updateIncome(player)
	return n, isNew
end

-- Remove and return a pad's record (selling, stealing).
function BaseService.takePad(player: Player, n: number)
	local data = dataOf(player)
	if not data then
		return nil
	end
	local rec = data.pads[tostring(n)]
	data.pads[tostring(n)] = nil
	replicatePad(player, n)
	updateIncome(player)
	return rec
end

function BaseService.collect(player: Player, n: number): number
	local data = dataOf(player)
	local rec = data and data.pads[tostring(n)]
	if not rec or rec.k ~= "dragon" then
		return 0
	end
	local slot = slotOf[player]
	if slot and stealing[slot] and stealing[slot][n] then
		return 0
	end
	local t = now()
	local amount = math.floor(stored(rec, t))
	if amount < 1 then
		return 0
	end
	rec.s = stored(rec, t) - amount
	rec.t = t
	Economy.addCash(player, amount)
	replicatePad(player, n)
	fxEvent:FireClient(player, slot, n, "collect", amount)
	Signals.progress(player, "collect", amount)
	return amount
end

function BaseService.collectAll(player: Player): number
	local total = 0
	for n = 1, Layout.MaxPads do
		total += BaseService.collect(player, n)
	end
	return total
end

-- Roll the dragon an egg hatches into.
local function rollDragon(player: Player, rec)
	local data = dataOf(player)
	local pool
	if rec.b == 0 or rec.r == "Secret" then
		pool = {}
		for _, sp in ipairs(Species.Secrets) do
			table.insert(pool, { sp = sp, w = Species.SecretWeights[sp.id] or 1 })
		end
	else
		pool = {}
		for _, sp in ipairs(Species.pool(rec.b, rec.r)) do
			table.insert(pool, { sp = sp, w = 1 })
		end
	end
	if #pool == 0 then
		-- shouldn't happen: fall back to any species of that rarity
		for _, sp in ipairs(Species.List) do
			if sp.rarity == rec.r then
				table.insert(pool, { sp = sp, w = 1 })
			end
		end
	end
	local total = 0
	for _, e in ipairs(pool) do
		total += e.w
	end
	local pick = rng:NextNumber() * total
	local chosen = pool[1].sp
	for _, e in ipairs(pool) do
		pick -= e.w
		if pick <= 0 then
			chosen = e.sp
			break
		end
	end
	local luck = 1
	local sizeLuck = 1
	if hasPass(player, "Lucky") then
		luck *= 2
		sizeLuck *= 1.6
	end
	if data.boosts.luck and data.boosts.luck > os.time() then
		luck *= 2
		sizeLuck *= 1.3
	end
	luck *= WorldState.serverLuck()
	local evMut, evChance = WorldState.eventMutation()
	local size, mut = Traits.roll(rng, luck, evMut, evChance, sizeLuck)
	return { sp = chosen.id, sz = size, mut = mut }
end

function BaseService.hatch(player: Player, n: number, force: boolean?): boolean
	local data = dataOf(player)
	local rec = data and data.pads[tostring(n)]
	if not rec or rec.k ~= "egg" then
		return false
	end
	local slot = slotOf[player]
	if slot and stealing[slot] and stealing[slot][n] then
		return false
	end
	if not force and now() < (rec.ready or 0) - 0.5 then
		return false
	end
	local d = rollDragon(player, rec)
	local _, isNew = BaseService.placeDragon(player, d, n)
	data.stats.hatched += 1
	Sync.set(player, "stats", data.stats)
	local sp = Species.get(d.sp)
	fxEvent:FireAllClients(slot, n, "hatch", d)
	Signals.progress(player, "hatch", 1)
	local label = Value.label(d)
	local rank = Rarity.rank(sp.rarity)
	if rank >= Rarity.rank("Legendary") or (d.mut and Traits.mutation(d.mut).mult >= 5) or d.sz == "giant" then
		Sync.notifyAll(string.format("🐉 %s hatched a %s!", player.DisplayName, label), "rare")
		Signals.progress(player, "rare", 1)
	else
		Sync.notify(player, string.format("🐣 Hatched a %s! (%s)", label, Format.rate(Value.cps(d, cachedMult[player]))), isNew and "rare" or "good")
	end
	if sp.rarity == "Secret" then
		data.stats.secrets = (data.stats.secrets or 0) + 1
	end
	if isNew then
		Sync.notify(player, "📖 New dragon added to your Index!", "info")
	end
	return true
end

function BaseService.hatchAll(player: Player): number
	local c = 0
	for n = 1, Layout.MaxPads do
		local rec = BaseService.getPad(player, n)
		if rec and rec.k == "egg" and now() >= (rec.ready or 0) - 0.5 then
			if BaseService.hatch(player, n) then
				c += 1
			end
		end
	end
	return c
end

function BaseService.sell(player: Player, n: number): number?
	local data = dataOf(player)
	local rec = data and data.pads[tostring(n)]
	if not rec then
		return nil
	end
	local slot = slotOf[player]
	if slot and stealing[slot] and stealing[slot][n] then
		return nil
	end
	local price
	if rec.k == "dragon" then
		BaseService.collect(player, n)
		price = Value.sellPrice(rec, cachedMult[player])
	else
		-- unhatched eggs sell for a little (frees the pad)
		price = math.floor((Species.pool(rec.b, rec.r)[1] and Species.pool(rec.b, rec.r)[1].cps or 1) * 10)
	end
	BaseService.takePad(player, n)
	Economy.addCash(player, price)
	fxEvent:FireAllClients(slot, n, "sell")
	Signals.progress(player, "sell", 1)
	return price
end

---------------------------------------------------------------------------
-- Stealing bookkeeping (CarryService drives the actual carry)
---------------------------------------------------------------------------
function BaseService.markStealing(slot: number, n: number, thief: Player?)
	stealing[slot] = stealing[slot] or {}
	stealing[slot][n] = thief
	folders[slot]:SetAttribute("S" .. n, thief and thief.DisplayName or nil)
end

function BaseService.shielded(player: Player): boolean
	return (joinedAt[player] or 0) + Config.NewPlayerShield > os.time()
end

---------------------------------------------------------------------------
-- Locking
---------------------------------------------------------------------------
local function laserOf(slot: number): BasePart?
	local base = workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild("Base_" .. slot)
	return base and base:FindFirstChild("Laser")
end

function BaseService.lockedUntil(slot: number): number
	return folders[slot]:GetAttribute("LockUntil") or 0
end

function BaseService.isLocked(slot: number): boolean
	return BaseService.lockedUntil(slot) > now()
end

function BaseService.lock(player: Player, seconds: number?): boolean
	local slot = slotOf[player]
	if not slot then
		return false
	end
	seconds = seconds or (hasPass(player, "SuperLock") and Config.LockPassSeconds or Config.LockSeconds)
	local untilT = math.max(BaseService.lockedUntil(slot), now() + seconds)
	folders[slot]:SetAttribute("LockUntil", untilT)
	local laser = laserOf(slot)
	if laser then
		laser.Transparency = 0.45
		laser.CanCollide = true
	end
	fxEvent:FireAllClients(slot, 0, "lock")
	return true
end

local function refreshLasers()
	for slot = 1, Layout.BaseCount do
		local laser = laserOf(slot)
		if laser and laser.CanCollide and not BaseService.isLocked(slot) then
			laser.Transparency = 1
			laser.CanCollide = false
			fxEvent:FireAllClients(slot, 0, "unlock")
		end
	end
end

---------------------------------------------------------------------------
-- Assignment / release
---------------------------------------------------------------------------
local function assign(player: Player, profile)
	local slot
	for i = 1, Layout.BaseCount do
		if not slotOwner[i] then
			slot = i
			break
		end
	end
	if not slot then
		warn("[BaseService] no free base for", player.Name)
		return
	end
	slotOwner[slot] = player
	slotOf[player] = slot
	joinedAt[player] = os.time()
	player:SetAttribute("BaseSlot", slot)
	local f = folders[slot]
	f:SetAttribute("Owner", player.UserId)
	f:SetAttribute("OwnerName", player.DisplayName)
	f:SetAttribute("LockUntil", 0)
	f:SetAttribute("ShieldUntil", os.time() + Config.NewPlayerShield)
	setSign(slot, string.upper(player.DisplayName) .. "'S BASE")

	-- Offline income: credit each dragon's pad with time away (capped, reduced rate).
	local data = profile.data
	local mult = BaseService.ownerMult(player)
	cachedMult[player] = mult
	local t = now()
	local cap = hasPass(player, "VIP") and Config.OfflineCapVIP or Config.OfflineCap
	local offlineTotal = 0
	for _, rec in pairs(data.pads) do
		if rec.k == "dragon" then
			local away = math.clamp(t - (rec.t or t), 0, cap)
			local c = Value.cps(rec, mult)
			-- rec.s already holds everything earned up to the last save (see freeze)
			rec.s = (rec.s or 0) + c * away * Config.OfflineRate
			offlineTotal += c * away * Config.OfflineRate
			rec.t = t
			rec.c = c
		end
	end
	replicateAll(player)
	if offlineTotal >= 1 and data.stats.joins > 1 then
		task.delay(4, function()
			if player.Parent then
				Sync.notify(player, string.format("💤 Your dragons earned %s while you were away! Walk over the green plates to collect.", Format.cash(offlineTotal)), "good")
			end
		end)
	end
	assigned:Fire(player, slot)
end

local function release(player: Player)
	local slot = slotOf[player]
	if not slot then
		return
	end
	slotOwner[slot] = nil
	slotOf[player] = nil
	cachedMult[player] = nil
	joinedAt[player] = nil
	stealing[slot] = nil
	local f = folders[slot]
	for _, attr in ipairs({ "Owner", "OwnerName", "LockUntil", "ShieldUntil", "Income", "Pads", "Mult" }) do
		f:SetAttribute(attr, nil)
	end
	for n = 1, Layout.MaxPads do
		f["P" .. n].Value = ""
		f:SetAttribute("S" .. n, nil)
	end
	local laser = laserOf(slot)
	if laser then
		laser.Transparency = 1
		laser.CanCollide = false
	end
	setSign(slot, "EMPTY BASE")
end

-- Before the final save: bank each dragon's stored cash at the current time so
-- offline time is measured from when they left.
local function freeze(player: Player, profile)
	local t = now()
	for _, rec in pairs(profile.data.pads) do
		if rec.k == "dragon" then
			rec.s = stored(rec, t)
			rec.t = t
		end
	end
end

function BaseService.basePosition(player: Player): CFrame?
	local slot = slotOf[player]
	return slot and Layout.baseCFrame(slot) or nil
end

function BaseService.start()
	DataService.Loaded:Connect(function(player, profile)
		assign(player, profile)
	end)
	DataService.Releasing:Connect(function(player, profile)
		freeze(player, profile)
		release(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if slotOf[player] and not DataService.get(player) then
			release(player)
		end
	end)

	-- Collect plates (owner only).
	local bases = workspace:WaitForChild("Bases")
	for slot = 1, Layout.BaseCount do
		local base = bases:WaitForChild("Base_" .. slot)
		for n = 1, Layout.MaxPads do
			local plate = base:FindFirstChild("Plate_" .. n)
			if plate then
				plate.Touched:Connect(function(hit)
					local char = hit.Parent
					local player = char and Players:GetPlayerFromCharacter(char)
					if player and slotOf[player] == slot then
						BaseService.collect(player, n)
					end
				end)
			end
		end
		local btn = base:FindFirstChild("LockButton")
		local prompt = btn and btn:FindFirstChild("LockPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				if slotOf[player] == slot then
					BaseService.lock(player)
					Sync.notify(player, "🔒 Base locked! Thieves can't get in for now.", "good")
				else
					Sync.notify(player, "That's not your base!", "bad")
				end
			end)
		end
	end

	-- Once a second: lasers, multiplier changes (boost expiry), auto-collect.
	task.spawn(function()
		while true do
			task.wait(1)
			refreshLasers()
			for player in pairs(slotOf) do
				local mult = BaseService.ownerMult(player)
				if math.abs(mult - (cachedMult[player] or 0)) > 1e-6 then
					BaseService.rebase(player)
				end
				if hasPass(player, "AutoCollect") then
					BaseService.collectAll(player)
				end
			end
		end
	end)

	-- Client requests
	Net.event("Collect").OnServerEvent:Connect(function(player, n)
		if type(n) == "number" then
			BaseService.collect(player, n)
		end
	end)
	Net.func("Hatch").OnServerInvoke = function(player, n)
		if n == "all" then
			return BaseService.hatchAll(player)
		end
		if type(n) ~= "number" then
			return false
		end
		return BaseService.hatch(player, n)
	end
	Net.func("SellPad").OnServerInvoke = function(player, n)
		if type(n) ~= "number" then
			return nil
		end
		local price = BaseService.sell(player, n)
		if price then
			Sync.notify(player, "💰 Sold for " .. Format.cash(price), "good")
		end
		return price
	end
	Net.func("LockRemote").OnServerInvoke = function(player)
		if not hasPass(player, "SuperLock") then
			return false
		end
		return BaseService.lock(player)
	end
end

return BaseService
