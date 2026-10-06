-- Robux store: game passes, cash packs, boosts and server events.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Products)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Ads = require(script.Parent.Parent.Ads)
local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local Sounds = require(script.Parent.Parent.Sounds)

local StorePanel = {}
local C = Theme.C
local new = Theme.new
local player = Players.LocalPlayer

local BOOST_DESC = {
	CashBoost = "Every dragon earns double for 15 minutes.",
	LuckBoost = "2x mutation luck + bigger dragons for 15 minutes.",
	ServerLuck = "Give EVERYONE in the server 2x luck for 15 minutes!",
	Speed10 = "+10 walk speed, forever. Outrun the guardians!",
	LockBase = "Lock your base for 5 minutes. No thieves allowed.",
}
local EVENT_DESC = {
	Event_golden = "Golden Hour for the whole server: 25% of hatches turn GOLDEN.",
	Event_meteor = "Meteors crash into the plaza, each leaving a free high-tier egg!",
	Event_bloodmoon = "Rarer eggs, faster guardians and Blood Moon dragons (x6)!",
	Event_secret = "Spawn a SECRET EGG in a random nest. Race everyone for it!",
}

local function card(parent, order: number, icon: string, title: string, desc: string, color: Color3)
	local c = Theme.card({
		Size = UDim2.fromOffset(226, 214),
		Color = Color3.new(1, 1, 1),
		Gradient = { Theme.darken(color, 0.15), Theme.darken(color, 0.6), 90 },
		StrokeColor = Theme.darken(color, 0.75),
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.text({ Text = icon, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 8), stroke = false, maxSize = 48, Parent = c })
	Theme.text({ Text = title, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 62), maxSize = 22, Parent = c })
	local descLabel = Theme.text({ Text = desc, Size = UDim2.new(1, -16, 0, 58), Position = UDim2.fromOffset(8, 92), TextColor3 = Color3.fromRGB(235, 235, 255), maxSize = 16, strokeThickness = 1.5, Parent = c })
	return c, descLabel
end

local function priceButton(parent, price: number, onClick)
	return Theme.button({
		Text = "R$ " .. price,
		Color = C.green,
		Size = UDim2.new(1, -24, 0, 42),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Theme.TitleFont,
		maxSize = 22,
		Parent = parent,
		onClick = function()
			Sounds.play("click")
			onClick()
		end,
	})
end

function StorePanel.start()
	local pages, tabButtons, passCards = {}, {}, {}
	local show
	local win = Root.window({ name = "Store", title = "🛒 DRAGON STORE", accent = C.gold, width = 800, height = 540, onOpen = function(focusPass)
		if focusPass and passCards[focusPass] then
			show("passes")
			local c = passCards[focusPass]
			local s = c:FindFirstChild("Pulse") or new("UIScale", { Name = "Pulse", Parent = c })
			s.Scale = 1.12
			Theme.tween(s, 0.5, { Scale = 1 }, Enum.EasingStyle.Elastic)
		end
	end })
	local body = win.body

	local tabsBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = body }, { Theme.list(Enum.FillDirection.Horizontal, 8) })
	local function page(name: string)
		local s = Root.scroller(body, { size = UDim2.new(1, 0, 1, -54), position = UDim2.fromOffset(0, 54), grid = UDim2.fromOffset(226, 214), gap = 12 })
		s.Visible = false
		pages[name] = s
		return s
	end
	function show(name: string)
		for n, p in pairs(pages) do
			p.Visible = n == name
		end
		for n, b in pairs(tabButtons) do
			Theme.setButtonColor(b, n == name and C.gold or C.cardDark)
		end
	end
	for i, t in ipairs({ { "passes", "⭐ Passes" }, { "cash", "💰 Cash" }, { "boosts", "⚡ Boosts" }, { "events", "🎉 Events" } }) do
		tabButtons[t[1]] = Theme.button({ Text = t[2], Color = C.cardDark, Size = UDim2.fromOffset(170, 42), LayoutOrder = i, maxSize = 20, Parent = tabsBar, onClick = function()
			Sounds.play("click")
			show(t[1])
		end })
	end

	-- Passes
	local passes = page("passes")
	local passButtons = {}
	for i, p in ipairs(Products.Passes) do
		if p.id ~= 0 then
			local c = card(passes, i, p.icon, p.name, p.desc, C.purple)
			passCards[p.key] = c
			local b, label = priceButton(c, p.price, function()
				MarketplaceService:PromptGamePassPurchase(player, p.id)
			end)
			passButtons[p.key] = { button = b, label = label }
		end
	end
	local function refreshPasses()
		for key, pb in pairs(passButtons) do
			if player:GetAttribute("Pass_" .. key) then
				pb.label.Text = "OWNED"
				Theme.setButtonColor(pb.button, C.grey)
				pb.button.Active = false
			end
		end
	end
	player.AttributeChanged:Connect(function(attr)
		if attr:sub(1, 5) == "Pass_" then
			refreshPasses()
		end
	end)

	-- Cash packs (amounts scale with income)
	local cash = page("cash")
	local cashLabels = {}
	for i, p in ipairs(Products.Dev) do
		if p.kind == "cash" and p.id ~= 0 then
			local c, descLabel = card(cash, i, p.icon, p.name, "", C.green)
			cashLabels[p.key] = descLabel
			priceButton(c, p.price, function()
				MarketplaceService:PromptProductPurchase(player, p.id)
			end)
		end
	end

	-- Boosts (+ optional rewarded ad)
	local boosts = page("boosts")
	local adCard = card(boosts, 0, "📺", "Free Lucky Hatch", "Watch a short ad for 2x hatch luck for 10 minutes. Totally optional!", C.green)
	adCard.Visible = false
	Theme.button({ Text = "WATCH AD", Color = C.green, Size = UDim2.new(1, -24, 0, 42), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), Font = Theme.TitleFont, maxSize = 22, Parent = adCard, onClick = function()
		adCard.Visible = false
		Ads.watch()
	end })
	for i, key in ipairs({ "ServerLuck", "CashBoost", "LuckBoost", "Speed10", "LockBase" }) do
		local p = Products.DevByKey[key]
		if p and p.id ~= 0 then
			local c = card(boosts, i, p.icon, p.name, BOOST_DESC[key] or "", C.blue)
			priceButton(c, p.price, function()
				MarketplaceService:PromptProductPurchase(player, p.id)
			end)
		end
	end

	-- Server events
	local events = page("events")
	for i, key in ipairs({ "Event_golden", "Event_meteor", "Event_bloodmoon", "Event_secret" }) do
		local p = Products.DevByKey[key]
		if p and p.id ~= 0 then
			local c = card(events, i, p.icon, p.name, EVENT_DESC[key] or "", C.orange)
			priceButton(c, p.price, function()
				MarketplaceService:PromptProductPurchase(player, p.id)
			end)
		end
	end

	local anything = false
	for _, pg in pairs(pages) do
		for _, ch in ipairs(pg:GetChildren()) do
			if ch:IsA("Frame") and ch ~= adCard then
				anything = true
			end
		end
	end
	if not anything then
		Theme.text({ Text = "✨ The Dragon Store opens very soon! ✨", Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 30, Parent = body })
		tabsBar.Visible = false
	end

	Root.WindowChanged:Connect(function(name)
		if name ~= "Store" then
			return
		end
		refreshPasses()
		task.spawn(function()
			adCard.Visible = Ads.available()
		end)
		task.spawn(function()
			local amounts = Net.func("CashPackAmounts"):InvokeServer()
			for key, lbl in pairs(cashLabels) do
				if lbl and amounts and amounts[key] then
					lbl.Text = "+" .. Format.cash(amounts[key]) .. " cash"
					lbl.TextColor3 = C.gold
				end
			end
		end)
	end)
	show("passes")
end

return StorePanel
