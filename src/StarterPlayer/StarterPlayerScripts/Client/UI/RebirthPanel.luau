-- Rebirth: trade everything for a permanent income + speed bonus.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local RebirthPanel = {}
local C = Theme.C

local rebirthFunc = Net.func("Rebirth")

function RebirthPanel.start()
	local w = Root.window({ name = "Rebirth", title = "🌀 REBIRTH", accent = C.purple, width = 620, height = 450 })
	local body = w.body
	local now = Theme.text({ Text = "", Font = Theme.TitleFont, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 4), TextColor3 = Color3.fromRGB(210, 170, 255), maxSize = 34, Parent = body })
	local gains = Theme.card({ Size = UDim2.new(1, -20, 0, 120), Position = UDim2.new(0.5, 0, 0, 52), AnchorPoint = Vector2.new(0.5, 0), Color = Color3.fromRGB(60, 120, 80), Radius = 14, Parent = body })
	local gainText = Theme.text({ Text = "", Size = UDim2.new(1, -24, 1, -16), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), RichText = true, maxSize = 20, Parent = gains })
	local loses = Theme.card({ Size = UDim2.new(1, -20, 0, 70), Position = UDim2.new(0.5, 0, 0, 180), AnchorPoint = Vector2.new(0.5, 0), Color = Color3.fromRGB(130, 50, 60), Radius = 14, Parent = body })
	Theme.text({ Text = "You lose: cash, speed upgrades, pad upgrades and every dragon & egg in your base.\nYou keep: gear, your Index and all passes.", Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 17, Parent = loses })
	local cost = Theme.text({ Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 258), maxSize = 22, Parent = body })
	local btn, label = Theme.button({ Text = "REBIRTH", Color = C.purple, Size = UDim2.fromOffset(260, 56), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), Font = Theme.TitleFont, Parent = body, onClick = function()
		if rebirthFunc:InvokeServer() then
			Sounds.play("stinger")
			Root.close()
		else
			Sounds.play("error")
		end
	end })

	local function refresh()
		local r = State.data.rebirths or 0
		now.Text = "Rebirth " .. r .. (r >= Config.MaxRebirths and " (MAX)" or "")
		local nextMult = 1 + (r + 1) * Config.RebirthIncome
		gainText.Text = string.format("You get:\n💰 <b>x%.1f</b> cash forever (now x%.1f)\n⚡ <b>+%d</b> base speed\n🥚 a free Rare Egg to restart", nextMult, 1 + r * Config.RebirthIncome, Config.RebirthSpeed)
		local c = Config.rebirthCost(r)
		local cash = State.data.cash or 0
		cost.Text = "Needs " .. Format.cash(c) .. " cash  (you have " .. Format.cash(cash) .. ")"
		local ok = cash >= c and r < Config.MaxRebirths
		Theme.setButtonColor(btn, ok and C.purple or C.grey)
		label.Text = ok and "🌀 REBIRTH NOW" or "NOT ENOUGH CASH"
	end
	State.onChange("cash", refresh)
	State.onChange("rebirths", refresh)
	State.whenLoaded(refresh)
end

return RebirthPanel
