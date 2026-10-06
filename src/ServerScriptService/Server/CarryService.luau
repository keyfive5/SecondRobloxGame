-- Everything a player carries over their head: an egg grabbed from a nest (or off
-- the ground), or an egg/dragon being stolen from someone's base.
--
-- Stolen items never leave the victim's save until the thief makes it home: the
-- pad is only marked as "being stolen". If the thief is slapped, dies or the
-- victim leaves, the mark is cleared and nothing is lost or duplicated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Species = require(Shared.Species)
local Traits = require(Shared.Traits)
local Value = require(Shared.Value)
local Rarity = require(Shared.Rarity)
local Net = require(Shared.Net)
local DragonBuilder = require(Shared.Visuals.DragonBuilder)
local EggBuilder = require(Shared.Visuals.EggBuilder)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local Sync = require(script.Parent.Sync)
local Signals = require(script.Parent.Signals)

local CarryService = {}

-- [player] = { kind = "egg" | "dragon", b?, r?, rec?, source = { type = "nest" | "ground" | "base", ... }, model }
local carrying = {}

local changed = Instance.new("BindableEvent")
CarryService.Changed = changed.Event -- (player) carry state changed (speed, UI)
local dropped = Instance.new("BindableEvent")
CarryService.Dropped = dropped.Event -- (player, carry, reason, position)
local delivered = Instance.new("BindableEvent")
CarryService.Delivered = delivered.Event -- (player, carry, pad)

local alarmEvent = Net.event("Alarm")

function CarryService.get(player: Player)
	return carrying[player]
end

function CarryService.all()
	return carrying
end

local function label(c): string
	if c.kind == "dragon" and c.rec then
		return Value.label(c.rec)
	end
	local r = c.r or (c.rec and c.rec.r) or "Common"
	return (r == "Secret" and "Secret" or r) .. " Egg"
end
CarryService.label = label

local function quietModel(model: Model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
end

local function attachVisual(player: Player, c)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local model, primary
	local origin = hrp.CFrame
	if c.kind == "dragon" then
		local rec = c.rec
		local sp = Species.get(rec.sp)
		model = DragonBuilder.build(sp.look, origin, { scale = 0.55 * Traits.size(rec.sz).scale, mutation = rec.mut, anchored = false })
		primary = model.PrimaryPart
	else
		local b = c.b or (c.rec and c.rec.b) or 1
		local r = c.r or (c.rec and c.rec.r) or "Common"
		model = EggBuilder.build(b, r, origin, { scale = 1.15, anchored = false })
		primary = model.PrimaryPart
	end
	model.Name = "CarriedItem"
	quietModel(model)
	local w = Instance.new("Weld")
	w.Part0 = hrp
	w.Part1 = primary
	local lift = c.kind == "dragon" and 2.9 or 4.1
	w.C0 = CFrame.new(0, lift, 0.4) * CFrame.Angles(0, math.pi, 0)
	w.Parent = primary
	model.Parent = char
	c.model = model
end

local function clear(player: Player, c)
	if c.model then
		c.model:Destroy()
		c.model = nil
	end
	carrying[player] = nil
	player:SetAttribute("Carrying", nil)
	player:SetAttribute("CarryBiome", nil)
	player:SetAttribute("CarryRarity", nil)
	changed:Fire(player)
end

-- item: { kind = "egg", b, r } or { kind = "dragon"|"egg", rec } with source.type == "base"
function CarryService.start(player: Player, item, source): boolean
	if carrying[player] then
		return false
	end
	local c = { kind = item.kind, b = item.b, r = item.r, rec = item.rec, source = source, startedAt = os.clock() }
	carrying[player] = c
	attachVisual(player, c)
	player:SetAttribute("Carrying", label(c))
	if source.type ~= "base" then
		player:SetAttribute("CarryBiome", c.b)
	end
	player:SetAttribute("CarryRarity", c.r or (c.rec and (c.rec.r or Species.get(c.rec.sp).rarity)))
	changed:Fire(player)
	return true
end

-- reason: "slap" | "guardian" | "died" | "left" | "ownerLeft" | "trap" | "net"
function CarryService.drop(player: Player, reason: string, position: Vector3?)
	local c = carrying[player]
	if not c then
		return
	end
	if not position then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		position = hrp and hrp.Position or nil
	end
	clear(player, c)
	if c.source.type == "base" then
		local src = c.source
		BaseService.markStealing(src.slot, src.pad, nil)
		local victim = BaseService.ownerOf(src.slot)
		if victim and reason ~= "ownerLeft" then
			Sync.notify(victim, string.format("🛡️ Your %s is back home!", label(c)), "good")
		end
		if reason ~= "ownerLeft" then
			Sync.notify(player, string.format("😵 You dropped the %s!", label(c)), "bad")
		end
	elseif reason == "guardian" then
		Sync.notify(player, "🐉 The guardian took its egg back!", "bad")
	elseif reason == "slap" or reason == "trap" or reason == "net" then
		Sync.notify(player, "😵 You dropped your egg!", "bad")
	end
	dropped:Fire(player, c, reason, position)
end

function CarryService.deliver(player: Player)
	local c = carrying[player]
	if not c then
		return
	end
	local data = DataService.get(player) and DataService.get(player).data
	if not data then
		return
	end
	local pad = BaseService.freePad(player)
	if not pad then
		-- base filled up while carrying: keep holding until a pad frees up
		if not c.fullWarned then
			c.fullWarned = true
			Sync.notify(player, "🏰 Your base is full! Sell a dragon to make room.", "bad")
		end
		return
	end
	if c.source.type == "base" then
		local src = c.source
		local victim = BaseService.ownerOf(src.slot)
		if not victim or victim == player then
			CarryService.drop(player, "ownerLeft")
			return
		end
		local rec = BaseService.takePad(victim, src.pad)
		BaseService.markStealing(src.slot, src.pad, nil)
		clear(player, c)
		if not rec then
			return
		end
		if rec.k == "dragon" then
			BaseService.placeDragon(player, { sp = rec.sp, sz = rec.sz, mut = rec.mut }, pad)
		else
			BaseService.placeEgg(player, { b = rec.b, r = rec.r, ready = rec.ready }, pad)
		end
		data.stats.steals += 1
		Sync.set(player, "stats", data.stats)
		local vdata = DataService.get(victim) and DataService.get(victim).data
		if vdata then
			vdata.stats.robbed += 1
		end
		local name = rec.k == "dragon" and Value.label(rec) or ((rec.r or "") .. " Egg")
		Sync.notify(player, string.format("🦹 You stole %s's %s!", victim.DisplayName, name), "rare")
		Sync.notify(victim, string.format("😭 %s stole your %s!", player.DisplayName, name), "steal")
		Signals.progress(player, "steal", 1)
		local sp = rec.k == "dragon" and Species.get(rec.sp)
		if sp and Rarity.rank(sp.rarity) >= Rarity.rank("Mythic") then
			Sync.notifyAll(string.format("🚨 %s stole a %s from %s!", player.DisplayName, name, victim.DisplayName), "steal")
		end
	else
		clear(player, c)
		BaseService.placeEgg(player, { b = c.b, r = c.r }, pad)
		data.stats.eggs += 1
		Sync.set(player, "stats", data.stats)
		Signals.progress(player, "egg", 1)
		Sync.notify(player, string.format("🥚 %s is incubating!", label(c)), "good")
	end
	delivered:Fire(player, c, pad)
end

---------------------------------------------------------------------------
-- Stealing from bases
---------------------------------------------------------------------------
local lastSteal = {}
local function tryStealPad(player: Player, slot: number, n: number)
	if type(slot) ~= "number" or type(n) ~= "number" then
		return
	end
	if carrying[player] then
		return
	end
	local victim = BaseService.ownerOf(slot)
	if not victim or victim == player then
		return
	end
	if lastSteal[player] and os.clock() - lastSteal[player] < 1 then
		return
	end
	lastSteal[player] = os.clock()
	if not BaseService.slot(player) then
		return
	end
	if BaseService.isLocked(slot) then
		Sync.notify(player, "🔒 That base is locked!", "bad")
		return
	end
	if BaseService.shielded(victim) then
		Sync.notify(player, "🛡️ That player just joined — their base is protected for a bit.", "bad")
		return
	end
	if BaseService.isStealing(slot, n) then
		return
	end
	if BaseService.freeCount(player) < 1 then
		Sync.notify(player, "🏰 Your base is full! Sell a dragon first.", "bad")
		return
	end
	local rec = BaseService.getPad(victim, n)
	if not rec then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - Layout.padCFrame(slot, n).Position).Magnitude > 16 then
		return
	end
	BaseService.collect(victim, n) -- the owner keeps cash earned so far
	BaseService.markStealing(slot, n, player)
	CarryService.start(player, { kind = rec.k, rec = rec, r = rec.r }, { type = "base", slot = slot, pad = n })
	local name = rec.k == "dragon" and Value.label(rec) or ((rec.r or "") .. " Egg")
	Sync.notify(victim, string.format("🚨 %s is stealing your %s! Slap them!", player.DisplayName, name), "steal")
	alarmEvent:FireClient(victim, player.UserId, slot, n)
end

function CarryService.init()
	Net.event("StealPad").OnServerEvent:Connect(tryStealPad)

	Players.PlayerRemoving:Connect(function(player)
		if carrying[player] then
			CarryService.drop(player, "left")
		end
		lastSteal[player] = nil
		-- anyone stealing from this player's base loses the item (victim keeps it)
		for thief, c in pairs(carrying) do
			if c.source.type == "base" and BaseService.ownerOf(c.source.slot) == player then
				CarryService.drop(thief, "ownerLeft")
				Sync.notify(thief, "💨 The owner left — the loot vanished!", "bad")
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			if carrying[player] then
				CarryService.drop(player, "died")
			end
			local hum = char:WaitForChild("Humanoid", 10)
			if hum then
				hum.Died:Connect(function()
					if carrying[player] then
						CarryService.drop(player, "died")
					end
				end)
			end
		end)
	end)

	-- Delivery check
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player, c in pairs(carrying) do
				local slot = BaseService.slot(player)
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then
					CarryService.drop(player, "died")
				elseif slot and Layout.inBase(slot, hrp.Position, 1) then
					CarryService.deliver(player)
				elseif c.model and not c.model.Parent then
					attachVisual(player, c)
				end
			end
		end
	end)
end

return CarryService
