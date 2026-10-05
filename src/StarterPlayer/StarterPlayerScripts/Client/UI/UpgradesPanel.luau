-- Upgrades: walk speed (with a checklist of which guardians you can outrun) and
-- extra dragon pads.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Biomes = require(Shared.Biomes)
local Products = require(Shared.Products)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local UpgradesPanel = {}
local C = Theme.C
local player = Players.LocalPlayer

local buySpeed = Net.func("BuySpeed")
local buyPad = Net.func("BuyPad")

local EMOJI = { "🌼", "🏜️", "❄️", "🌋", "⚡", "💎", "👻", "🌠" }

function UpgradesPanel.start()
	local w = Root.window({ name = "Upgrades", title = "⚡ UPGRADES", accent = C.orange, width = 780, height = 470 })
	local body = w.body

	-- left: speed
	local left = Theme.card({ Size = UDim2.new(0.5, -6, 1, 0), Color = C.cardDark, Radius = 16, Parent = body })
	Theme.text({ Text = "⚡ WALK SPEED", Font = Theme.TitleFont, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 8), maxSize = 26, Parent = left })
	local speedBig = Theme.text({ Text = "20", Font = Theme.TitleFont, Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 38), TextColor3 = Color3.fromRGB(130, 210, 255), maxSize = 46, Parent = left })
	local costText = Theme.text({ Text = "", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0.5, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0), maxSize = 20, Parent = left })
	local row = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), Parent = left }, {
		Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center),
	})
	local function buy(count)
		local n = buySpeed:InvokeServer(count)
		if n and n > 0 then
			Sounds.play("coins")
		else
			Sounds.play("error")
		end
	end
	local buttons = {}
	for i, c in ipairs({ { "+1", 1 }, { "+5", 5 }, { "+10", 10 }, { "MAX", "max" } }) do
		buttons[i] = Theme.button({ Text = c[1], Color = i == 4 and C.gold or C.green, Size = UDim2.fromOffset(78, 44), LayoutOrder = i, Font = Theme.TitleFont, Parent = row, onClick = function()
			buy(c[2])
		end })
	end
	local list = Root.scroller(left, { size = UDim2.new(1, -16, 1, -184), position = UDim2.fromOffset(8, 176), gap = 4 })
	local rows = {}
	for i, b in ipairs(Biomes.List) do
		local r = Theme.card({ Size = UDim2.new(1, -8, 0, 30), Color = C.card, Radius = 10, StrokeThickness = 2, LayoutOrder = i, Parent = list })
		local t = Theme.text({ Text = "", Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Left, RichText = true, maxSize = 17, Parent = r })
		rows[i] = { card = r, text = t, biome = b }
	end

	-- right: pads
	local right = Theme.card({ Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(0.5, 6, 0, 0), Color = C.cardDark, Radius = 16, Parent = body })
	Theme.text({ Text = "🏰 DRAGON PADS", Font = Theme.TitleFont, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 8), maxSize = 26, Parent = right })
	local padsBig = Theme.text({ Text = "8 / 16", Font = Theme.TitleFont, Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 38), TextColor3 = Color3.fromRGB(255, 210, 120), maxSize = 46, Parent = right })
	local padCost = Theme.text({ Text = "", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0.5, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0), maxSize = 20, Parent = right })
	local padBtn = Theme.button({ Text = "Unlock Pad", Color = C.green, Size = UDim2.fromOffset(220, 46), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.TitleFont, Parent = right, onClick = function()
		if buyPad:InvokeServer() then
			Sounds.play("coins")
		else
			Sounds.play("error")
		end
	end })
	Theme.text({ Text = "More pads = more dragons = more cash every second. Fill every pad, then replace weak dragons with better ones!", Size = UDim2.new(1, -24, 0, 66), Position = UDim2.new(0.5, 0, 0, 178), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = C.textDim, maxSize = 18, Parent = right })
	local mega = Theme.button({ Text = "🏰 Mega Base: +4 pads", Color = C.purple, Size = UDim2.new(1, -40, 0, 46), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), Parent = right, onClick = function()
		Root.open("Store", "MegaBase")
	end })

	local function refresh()
		local data = State.data
		local speedLv = data.speedLv or 0
		local cur = Config.BaseSpeed + speedLv
		local shown = player:GetAttribute("Speed") or cur
		speedBig.Text = "⚡ " .. shown
		if speedLv >= Config.MaxSpeedLevel then
			costText.Text = "MAX SPEED!"
		else
			costText.Text = "Next +1: " .. Format.cash(Config.speedCost(cur))
		end
		local cash = data.cash or 0
		for i, b in ipairs(buttons) do
			Theme.setButtonColor(b, (cash >= Config.speedCost(cur)) and (i == 4 and C.gold or C.green) or C.grey)
		end
		for i, r in ipairs(rows) do
			local need = r.biome.speed
			local ok = shown >= need
			r.text.Text = string.format("%s %s  <font color=\"%s\">⚡%d</font>  %s", EMOJI[i], r.biome.name, ok and "#8CFF8C" or "#FFB060", need, ok and "✅" or ("(+" .. (need - shown) .. ")"))
			r.card.BackgroundColor3 = ok and Color3.fromRGB(56, 120, 80) or C.card
		end
		local pads = Config.StartPads + math.min(data.padUp or 0, Config.MaxPadUpgrades) + (player:GetAttribute("Pass_MegaBase") and Config.PassPads or 0)
		padsBig.Text = pads .. " / " .. (Config.StartPads + Config.MaxPadUpgrades + Config.PassPads)
		if (data.padUp or 0) >= Config.MaxPadUpgrades then
			padCost.Text = "All cash pads unlocked!"
			padBtn.Visible = false
		else
			local c = Config.PadUpgradeCost(data.padUp or 0)
			padCost.Text = "Next pad: " .. Format.cash(c)
			padBtn.Visible = true
			Theme.setButtonColor(padBtn, cash >= c and C.green or C.grey)
		end
		mega.Visible = not player:GetAttribute("Pass_MegaBase") and Products.passId("MegaBase") ~= 0
	end
	for _, k in ipairs({ "cash", "speedLv", "padUp", "rebirths" }) do
		State.onChange(k, refresh)
	end
	player:GetAttributeChangedSignal("Speed"):Connect(refresh)
	State.whenLoaded(refresh)
	refresh()
end

return UpgradesPanel
