-- Popup card when one of your eggs hatches: 3D dragon, name, rarity, income.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local Rarity = require(Shared.Rarity)
local Traits = require(Shared.Traits)
local Value = require(Shared.Value)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local Viewport = require(script.Parent.Viewport)
local Notify = require(script.Parent.Notify)
local BaseRenderer = require(script.Parent.Parent.BaseRenderer)

local HatchReveal = {}
local C = Theme.C

local queue = {}
local showing = false

local function show(d)
	showing = true
	local sp = Species.get(d.sp)
	if not sp then
		showing = false
		return
	end
	local rc = Rarity.color(sp.rarity)
	local holder = Theme.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 330),
		Position = UDim2.new(1, -20, 1, -150),
		AnchorPoint = Vector2.new(1, 1),
		Parent = Root.gui,
	})
	Root.scaled(holder)
	local card = Theme.card({
		Size = UDim2.fromScale(1, 1),
		Color = Color3.new(1, 1, 1),
		Gradient = { rc:Lerp(Color3.new(1, 1, 1), 0.15), rc:Lerp(Color3.new(0, 0, 0), 0.55), 90 },
		StrokeColor = rc:Lerp(Color3.new(0, 0, 0), 0.7),
		StrokeThickness = 4,
		Radius = 20,
		Parent = holder,
	})
	Theme.text({ Text = "🐣 HATCHED!", Font = Theme.TitleFont, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), maxSize = 30, Parent = card })
	local box = Theme.new("Frame", { BackgroundColor3 = Color3.fromRGB(20, 24, 50), BackgroundTransparency = 0.35, Size = UDim2.new(1, -24, 0, 170), Position = UDim2.fromOffset(12, 46), Parent = card }, { Theme.corner(14) })
	Viewport.dragon(box, d, UDim2.fromScale(1, 1))
	Theme.text({ Text = Value.label(d), Font = Theme.TitleFont, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 220), maxSize = 24, Parent = card })
	Theme.text({ Text = sp.rarity .. (d.mut and ("  •  " .. Traits.mutation(d.mut).name .. " x" .. Traits.mutation(d.mut).mult) or ""), Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 250), TextColor3 = rc:Lerp(Color3.new(1, 1, 1), 0.4), maxSize = 18, Parent = card })
	Theme.text({ Text = "+" .. Format.rate(Value.cps(d, nil)) .. " (before boosts)", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 276), TextColor3 = Color3.fromRGB(150, 255, 150), maxSize = 18, Parent = card })
	local sc = Theme.new("UIScale", { Scale = 0.2, Parent = card })
	Theme.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	if Rarity.rank(sp.rarity) >= Rarity.rank("Legendary") or (d.mut and Traits.mutation(d.mut).mult >= 5) then
		Notify.big(string.upper(Value.label(d)) .. "!", sp.rarity .. " dragon hatched", rc)
	end
	task.delay(3.4, function()
		Theme.tween(sc, 0.2, { Scale = 0 })
		task.wait(0.25)
		holder:Destroy()
		showing = false
		local nextD = table.remove(queue, 1)
		if nextD then
			show(nextD)
		end
	end)
end

function HatchReveal.start()
	BaseRenderer.Hatched:Connect(function(_, _, d)
		if not d then
			return
		end
		if showing then
			if #queue < 4 then
				table.insert(queue, d)
			end
		else
			show(d)
		end
	end)
end

return HatchReveal
