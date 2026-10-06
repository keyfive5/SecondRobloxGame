-- Game passes + developer products. Receipts are idempotent: every PurchaseId is
-- recorded in the player's save before Roblox is told it was granted.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Products)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local BaseService = require(script.Parent.BaseService)
local NestService = require(script.Parent.NestService)
local EventService = require(script.Parent.EventService)
local ShopService = require(script.Parent.ShopService)
local PlayerService = require(script.Parent.PlayerService)
local WorldState = require(script.Parent.WorldState)
local Sync = require(script.Parent.Sync)

local MonetizationService = {}

local MAX_RECEIPTS = 100
local pending = {} -- [player] = { kind = "hatch", pad } | { kind = "egg", b, r, slot }

local function onPassChanged(player: Player, key: string)
	if key == "DoubleCash" or key == "VIP" then
		BaseService.rebase(player)
	elseif key == "MegaBase" then
		BaseService.replicateAll(player)
	elseif key == "SpeedBoost" then
		PlayerService.refreshSpeed(player)
	end
end

local function setPass(player: Player, key: string, owned: boolean)
	player:SetAttribute("Pass_" .. key, owned or nil)
	onPassChanged(player, key)
end
MonetizationService.setPass = setPass

local function loadPasses(player: Player)
	for _, pass in ipairs(Products.Passes) do
		if pass.id ~= 0 then
			local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owned then
				setPass(player, pass.key, true)
			end
		end
	end
	if RunService:IsStudio() and player:GetAttribute("StudioAllPasses") then
		for _, pass in ipairs(Products.Passes) do
			setPass(player, pass.key, true)
		end
	end
end

local function grant(player: Player, product): boolean
	local data = DataService.get(player).data
	local kind = product.kind
	if kind == "cash" then
		local amount = Products.cashAmount(product, BaseService.income(player))
		Economy.addCash(player, amount, false)
		Sync.notify(player, string.format("💰 +%s cash! Thank you!", Format.cash(amount)), "good")
	elseif kind == "hatch" then
		local p = pending[player]
		local done = false
		if p and p.kind == "hatch" then
			done = BaseService.hatch(player, p.pad, true)
		end
		if not done then
			-- egg was stolen/sold in the meantime: hatch the first unhatched egg instead
			for n = 1, 20 do
				local rec = BaseService.getPad(player, n)
				if rec and rec.k == "egg" and BaseService.hatch(player, n, true) then
					done = true
					break
				end
			end
		end
		if not done then
			Economy.addCash(player, Products.cashAmount(Products.DevByKey.Cash1, BaseService.income(player)), false)
			Sync.notify(player, "No eggs to hatch — here's some cash instead!", "info")
		end
	elseif kind == "lock" then
		BaseService.lock(player, product.seconds)
		Sync.notify(player, "🔒 Base locked for 5 minutes!", "good")
	elseif kind == "boost" then
		local t = os.time()
		data.boosts[product.boost] = math.max(data.boosts[product.boost] or 0, t) + product.seconds
		Sync.set(player, "boosts", data.boosts)
		if product.boost == "cash" then
			BaseService.rebase(player)
			Sync.notify(player, "💸 2x cash is active!", "good")
		else
			Sync.notify(player, "🔮 2x hatch luck is active!", "good")
		end
	elseif kind == "serverluck" then
		WorldState.serverLuckUntil = math.max(WorldState.serverLuckUntil, os.time()) + product.seconds
		WorldState.publish()
		Sync.notifyAll(string.format("🌈 %s gave the whole server 2x LUCK for 15 minutes!", player.DisplayName), "rare")
	elseif kind == "speed" then
		ShopService.addSpeedLevels(player, product.amount)
		Sync.notify(player, string.format("⚡ +%d speed!", product.amount), "good")
	elseif kind == "event" then
		EventService.trigger(product.event, player.DisplayName)
	elseif kind == "egg" then
		local p = pending[player]
		local b, slot = 1, nil
		if p and p.kind == "egg" and p.r == product.rarity then
			b, slot = p.b, p.slot
		end
		if slot then
			NestService.takeForPurchase(b, slot)
		end
		if not BaseService.placeEgg(player, { b = b, r = product.rarity }) then
			-- base full: refund as cash so nothing is lost
			Economy.addCash(player, Products.cashAmount(Products.DevByKey.Cash2, BaseService.income(player)), false)
			Sync.notify(player, "Your base was full — you got cash instead.", "info")
		else
			data.stats.eggs += 1
			Sync.notify(player, string.format("🥚 A %s Egg is safe in your base!", product.rarity), "good")
		end
	else
		return false
	end
	pending[player] = nil
	return true
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipts = profile.data.receipts
	if table.find(receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = Products.DevById[info.ProductId]
	if not product then
		warn("[Monetization] unknown product", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(grant, player, product)
	if not ok then
		warn("[Monetization] grant failed", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(receipts, info.PurchaseId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
	profile.data.stats.robux = (profile.data.stats.robux or 0) + (info.CurrencySpent or 0)
	if not DataService.save(player, false) and not profile.temporary then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function prompt(player: Player, key: string): boolean
	local id = Products.devId(key)
	if id == 0 then
		Sync.notify(player, "That's not on sale yet!", "info")
		return false
	end
	MarketplaceService:PromptProductPurchase(player, id)
	return true
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = Products.PassById[passId]
		if pass then
			setPass(player, pass.key, true)
			Sync.notify(player, string.format("%s %s unlocked! Thank you for supporting the game!", pass.icon, pass.name), "rare")
		end
	end)
	DataService.Loaded:Connect(function(player)
		loadPasses(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)

	-- "Buy Safely" on a nest egg: the client has already shown the odds.
	-- Paid random items are hidden where local policy restricts them.
	local PolicyService = game:GetService("PolicyService")
	Net.func("BuyEgg").OnServerInvoke = function(player, biome, slot)
		if type(biome) ~= "number" or type(slot) ~= "number" then
			return false
		end
		local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and policy and policy.ArePaidRandomItemsRestricted then
			Sync.notify(player, "Buying eggs isn't available in your region.", "info")
			return false
		end
		local rarity, pos = NestService.eggAt(biome, slot)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not rarity or not hrp or (hrp.Position - pos).Magnitude > 30 then
			return false
		end
		local product = Products.eggProduct(rarity)
		if not product or product.id == 0 then
			return false
		end
		pending[player] = { kind = "egg", b = biome, r = rarity, slot = slot }
		MarketplaceService:PromptProductPurchase(player, product.id)
		return true
	end

	Net.func("RequestHatchNow").OnServerInvoke = function(player, n)
		if type(n) ~= "number" then
			return false
		end
		local rec = BaseService.getPad(player, n)
		if not rec or rec.k ~= "egg" then
			return false
		end
		pending[player] = { kind = "hatch", pad = n }
		return prompt(player, "HatchNow")
	end
	Net.func("CashPackAmounts").OnServerInvoke = function(player)
		local out = {}
		for _, p in ipairs(Products.Dev) do
			if p.kind == "cash" then
				out[p.key] = Products.cashAmount(p, BaseService.income(player))
			end
		end
		return out
	end

	-- Rewarded video ads: opt-in, Roblox grants the AdLuck product via ProcessReceipt.
	local AdService = game:GetService("AdService")
	local lastAd = {}
	Net.event("WatchAd").OnServerEvent:Connect(function(player)
		local product = Products.DevByKey.AdLuck
		if not product or product.id == 0 then
			return
		end
		if lastAd[player] and os.clock() - lastAd[player] < 30 then
			return
		end
		lastAd[player] = os.clock()
		task.spawn(function()
			local ok, err = pcall(function()
				local reward = AdService:CreateAdRewardFromDevProductId(product.id)
				AdService:ShowRewardedVideoAdAsync(player, reward)
			end)
			if not ok then
				warn("[Ads]", err)
			end
		end)
	end)
end

return MonetizationService
