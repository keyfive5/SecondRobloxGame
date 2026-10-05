-- Gear Shop: slap upgrades + gadget tools, bought with cash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Gear = require(Shared.Gear)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local GearPanel = {}
local C = Theme.C

local buyGear = Net.func("BuyGear")

function GearPanel.start()
	local w = Root.window({ name = "Gear", title = "🛠️ GEAR SHOP", accent = C.blue, width = 780, height = 470 })
	local scroll = Root.scroller(w.body, { gap = 8 })
	local cards = {}

	local function card(order: number, icon: string, name: string, desc: string, color: Color3, onBuy)
		local c = Theme.card({ Size = UDim2.new(1, -12, 0, 74), Color = C.card, Radius = 14, LayoutOrder = order, Parent = scroll })
		local iconBox = Theme.card({ Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = color, Radius = 12, Parent = c })
		Theme.text({ Text = icon, Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), stroke = false, Parent = iconBox })
		Theme.text({ Text = name, Font = Theme.TitleFont, Size = UDim2.new(1, -260, 0, 28), Position = UDim2.fromOffset(76, 8), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 24, Parent = c })
		Theme.text({ Text = desc, Size = UDim2.new(1, -260, 0, 30), Position = UDim2.fromOffset(76, 38), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.textDim, maxSize = 16, Parent = c })
		local btn, label = Theme.button({ Text = "", Color = C.green, Size = UDim2.fromOffset(170, 48), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), maxSize = 22, Parent = c, onClick = onBuy })
		return { card = c, btn = btn, label = label }
	end

	for i, tier in ipairs(Gear.Slaps) do
		cards["slap_" .. tier.id] = card(i, tier.icon, tier.name, string.format("Slap power %d • range %d. Knocks thieves back and makes them drop loot.", tier.power, tier.range), tier.color, function()
			if buyGear:InvokeServer("slap", tier.id) then
				Sounds.play("coins")
			else
				Sounds.play("error")
			end
		end)
		cards["slap_" .. tier.id].tier = tier
	end
	for i, item in ipairs(Gear.Items) do
		cards["item_" .. item.id] = card(100 + i, item.icon, item.name, item.desc, C.purple, function()
			if buyGear:InvokeServer("item", item.id) then
				Sounds.play("coins")
			else
				Sounds.play("error")
			end
		end)
		cards["item_" .. item.id].item = item
	end

	local function refresh()
		local gear = State.data.gear or { slap = "slap", items = {} }
		local cash = State.data.cash or 0
		local cur = Gear.slap(gear.slap)
		for _, c in pairs(cards) do
			if c.tier then
				if c.tier.tier <= cur.tier then
					c.label.Text = c.tier.id == cur.id and "EQUIPPED" or "OWNED"
					Theme.setButtonColor(c.btn, C.grey)
				else
					c.label.Text = Format.cash(c.tier.price)
					Theme.setButtonColor(c.btn, cash >= c.tier.price and C.green or C.red)
				end
			else
				if gear.items and gear.items[c.item.id] then
					c.label.Text = "OWNED"
					Theme.setButtonColor(c.btn, C.grey)
				else
					c.label.Text = Format.cash(c.item.price)
					Theme.setButtonColor(c.btn, cash >= c.item.price and C.green or C.red)
				end
			end
		end
	end
	State.onChange("cash", refresh)
	State.onChange("gear", refresh)
	State.whenLoaded(refresh)
end

return GearPanel
