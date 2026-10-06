-- "Buy Safely" on a nest egg opens this first: the exact odds of what the egg
-- can hatch into (dragon, size, mutation) before any Robux prompt. Hidden for
-- players whose region restricts paid random items.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local Biomes = require(Shared.Biomes)
local Rarity = require(Shared.Rarity)
local Traits = require(Shared.Traits)
local Products = require(Shared.Products)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local Viewport = require(script.Parent.Viewport)
local Notify = require(script.Parent.Notify)
local Sounds = require(script.Parent.Parent.Sounds)

local EggOddsPanel = {}
local C = Theme.C
local new = Theme.new
local player = Players.LocalPlayer

local restricted = nil
local function isRestricted(): boolean
	if restricted == nil then
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		restricted = ok and info and info.ArePaidRandomItemsRestricted or false
	end
	return restricted
end

local function pct(x: number): string
	if x >= 10 then
		return string.format("%d%%", math.floor(x + 0.5))
	elseif x >= 1 then
		return string.format("%.1f%%", x)
	end
	return string.format("%.2f%%", x)
end

-- Odds for an egg of this biome + rarity (base odds, before luck boosts).
function EggOddsPanel.odds(biome: number, rarity: string)
	local dragons = {}
	if rarity == "Secret" or biome == 0 then
		local total = 0
		for _, w in pairs(Species.SecretWeights) do
			total += w
		end
		for _, sp in ipairs(Species.Secrets) do
			table.insert(dragons, { sp = sp, chance = (Species.SecretWeights[sp.id] or 0) / total * 100 })
		end
	else
		local pool = Species.pool(biome, rarity)
		for _, sp in ipairs(pool) do
			table.insert(dragons, { sp = sp, chance = 100 / #pool })
		end
	end
	local sizes = {}
	local total = 0
	for _, s in ipairs(Traits.Sizes) do
		total += s.weight
	end
	for _, s in ipairs(Traits.Sizes) do
		table.insert(sizes, { name = s.name ~= "" and s.name or "Normal", chance = s.weight / total * 100, mult = s.mult })
	end
	local muts = {}
	local none = 100
	for _, m in ipairs(Traits.Mutations) do
		if m.chance > 0 then
			table.insert(muts, { name = m.name, chance = m.chance, mult = m.mult, color = m.color })
			none -= m.chance
		end
	end
	table.insert(muts, 1, { name = "No mutation", chance = none, mult = 1 })
	return dragons, sizes, muts
end

function EggOddsPanel.start()
	local current
	local win = Root.window({ name = "EggOdds", title = "🥚 BUY EGG SAFELY", accent = C.gold, width = 760, height = 470 })
	local body = win.body
	local left = Theme.card({ Size = UDim2.new(0, 220, 1, 0), Color = C.cardDark, Radius = 16, Parent = body })
	local eggBox = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 190), Position = UDim2.fromOffset(10, 6), Parent = left })
	local eggTitle = Theme.text({ Text = "", Font = Theme.TitleFont, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 198), maxSize = 24, Parent = left })
	local eggSub = Theme.text({ Text = "", Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 228), TextColor3 = C.textDim, maxSize = 16, Parent = left })
	local buyBtn, buyLabel = Theme.button({ Text = "", Color = C.green, Size = UDim2.new(1, -20, 0, 54), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), Font = Theme.TitleFont, maxSize = 24, Parent = left })
	local scroll = Root.scroller(body, { size = UDim2.new(1, -232, 1, 0), position = UDim2.fromOffset(232, 0), gap = 6 })

	local function row(order: number, text: string, right: string, color: Color3?)
		local r = Theme.card({ Size = UDim2.new(1, -12, 0, 30), Color = C.card, Radius = 8, StrokeThickness = 2, LayoutOrder = order, Parent = scroll })
		Theme.text({ Text = text, RichText = true, Size = UDim2.new(0.7, -10, 1, -6), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or C.text, maxSize = 16, Parent = r })
		Theme.text({ Text = right, Size = UDim2.new(0.3, -10, 1, -6), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.gold, maxSize = 16, Parent = r })
	end
	local function header(order: number, text: string)
		Theme.text({ Text = text, Font = Theme.TitleFont, Size = UDim2.new(1, -12, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, maxSize = 20, Parent = scroll })
	end

	local function show(biome: number, slot: number, rarity: string)
		current = { biome = biome, slot = slot, rarity = rarity }
		for _, c in ipairs(eggBox:GetChildren()) do
			c:Destroy()
		end
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		Viewport.egg(eggBox, biome, rarity)
		eggTitle.Text = rarity .. " Egg"
		eggTitle.TextColor3 = Rarity.color(rarity == "Secret" and "Legendary" or rarity)
		eggSub.Text = (Biomes.List[biome] and Biomes.List[biome].name or "Secret") .. "\nSkip the chase — it goes straight to your base."
		local product = Products.eggProduct(rarity)
		buyLabel.Text = "BUY  R$ " .. (product and product.price or "?")
		local dragons, sizes, muts = EggOddsPanel.odds(biome, rarity)
		local o = 0
		header(o, "🐉 Dragon it hatches into")
		for _, d in ipairs(dragons) do
			o += 1
			row(o, string.format('%s  <font color="#9CFF9C">%s</font>', d.sp.name, Format.rate(d.sp.cps)), pct(d.chance), Rarity.color(d.sp.rarity):Lerp(Color3.new(1, 1, 1), 0.35))
		end
		o += 1
		header(o, "📏 Size")
		for _, s in ipairs(sizes) do
			o += 1
			row(o, string.format("%s  (x%s income)", s.name, tostring(s.mult)), pct(s.chance))
		end
		o += 1
		header(o, "✨ Mutation")
		for _, m in ipairs(muts) do
			o += 1
			row(o, string.format("%s%s", m.name, m.mult > 1 and ("  (x" .. m.mult .. " income)") or ""), pct(m.chance), m.color)
		end
		o += 1
		Theme.text({ Text = "Base odds. Luck boosts, the Lucky Hatcher pass and events raise size & mutation chances.", Size = UDim2.new(1, -12, 0, 36), TextColor3 = C.textDim, LayoutOrder = o, maxSize = 14, Parent = scroll })
		Root.open("EggOdds")
	end

	buyBtn.Activated:Connect(function()
		if not current then
			return
		end
		Sounds.play("click")
		local ok = Net.func("BuyEgg"):InvokeServer(current.biome, current.slot)
		if ok then
			Root.close()
		else
			Notify.toast("That egg is gone — try another one!", "info")
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local rarity = prompt:GetAttribute("EggBuy")
		if not rarity then
			return
		end
		if isRestricted() then
			Notify.toast("Buying eggs isn't available in your region.", "info")
			return
		end
		show(prompt:GetAttribute("EggBiome") or 1, prompt:GetAttribute("EggSlot") or 1, rarity)
	end)
	-- hide the buy prompts entirely where paid random items are restricted
	task.spawn(function()
		if isRestricted() then
			ProximityPromptService.PromptShown:Connect(function(prompt)
				if prompt:GetAttribute("EggBuy") then
					prompt.Enabled = false
				end
			end)
		end
	end)
end

return EggOddsPanel
