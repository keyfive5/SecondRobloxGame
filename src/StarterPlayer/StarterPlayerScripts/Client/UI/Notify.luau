-- Toast notifications (right side), floating "+coins" text, and the big
-- celebratory popup for rare hatches.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local Sounds = require(script.Parent.Parent.Sounds)

local Notify = {}

local C = Theme.C
local KIND_COLORS = {
	info = C.blue,
	good = C.green,
	bad = C.red,
	rare = C.purple,
	steal = C.orange,
}

local stack = Theme.new("Frame", {
	Name = "Toasts",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(340, 400),
	Position = UDim2.new(1, -16, 0.34, 0),
	AnchorPoint = Vector2.new(1, 0),
	Parent = Root.gui,
}, {
	Theme.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right),
})
Root.scaled(stack)

local order = 0
function Notify.toast(text: string, kind: string?)
	kind = kind or "info"
	order += 1
	local color = KIND_COLORS[kind] or C.blue
	local card = Theme.card({
		Size = UDim2.fromOffset(330, 0),
		Color = Color3.new(1, 1, 1),
		Gradient = { Theme.darken(color, 0.15), Theme.darken(color, 0.45), 0 },
		StrokeColor = Theme.darken(color, 0.65),
		Radius = 12,
		LayoutOrder = -order,
		Parent = stack,
	})
	card.AutomaticSize = Enum.AutomaticSize.Y
	Theme.pad(10, 8).Parent = card
	local t = Theme.text({
		Text = text,
		TextScaled = false,
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	t.AutomaticSize = Enum.AutomaticSize.Y
	local sc = Theme.new("UIScale", { Scale = 0.6, Parent = card })
	Theme.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(kind == "rare" and 7 or 4.5, function()
		Theme.tween(sc, 0.2, { Scale = 0 })
		task.wait(0.22)
		card:Destroy()
	end)
	-- keep at most 5 visible
	local cards = {}
	for _, c in ipairs(stack:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(cards, c)
		end
	end
	if #cards > 5 then
		table.sort(cards, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		cards[1]:Destroy()
	end
	if kind == "rare" then
		Sounds.play("stinger")
		pcall(function()
			local channel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
			if channel then
				channel:DisplaySystemMessage('<font color="#FFD34D">' .. text .. "</font>")
			end
		end)
	elseif kind == "bad" then
		Sounds.play("error")
	elseif kind == "steal" then
		Sounds.play("alarm")
	else
		Sounds.play("notify")
	end
end

-- Big centered banner (e.g. "GOLDEN HUGE PHOENIX DRAGON!").
function Notify.big(title: string, subtitle: string?, color: Color3?)
	color = color or C.gold
	local holder = Theme.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(700, 140),
		Position = UDim2.fromScale(0.5, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = Root.gui,
	})
	Root.scaled(holder)
	local t = Theme.text({
		Text = title,
		Font = Theme.TitleFont,
		Size = UDim2.new(1, 0, 0, 74),
		TextColor3 = color,
		strokeThickness = 4,
		Parent = holder,
	})
	Theme.new("UIGradient", { Color = ColorSequence.new(Theme.lighten(color, 0.5), color), Rotation = 90, Parent = t })
	if subtitle then
		Theme.text({ Text = subtitle, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 78), strokeThickness = 3, Parent = holder })
	end
	local sc = Theme.new("UIScale", { Scale = 0.3, Parent = holder })
	Theme.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		Theme.tween(sc, 0.25, { Scale = 0 })
		task.wait(0.3)
		holder:Destroy()
	end)
end

-- Floating text that drifts up from a screen position.
function Notify.float(text: string, color: Color3?, screenPos: Vector2?)
	local cam = workspace.CurrentCamera
	local pos = screenPos or Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y * 0.55)
	local label = Theme.text({
		Text = text,
		Font = Theme.TitleFont,
		Size = UDim2.fromOffset(260, 40),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = color or C.gold,
		strokeThickness = 3,
		ZIndex = 50,
		Parent = Root.overlay,
	})
	Theme.new("UIScale", { Scale = Root.scale, Parent = label })
	Theme.tween(label, 1.1, { Position = UDim2.fromOffset(pos.X + math.random(-30, 30), pos.Y - 90), TextTransparency = 1 })
	local s = label:FindFirstChildOfClass("UIStroke")
	if s then
		Theme.tween(s, 1.1, { Transparency = 1 })
	end
	task.delay(1.15, function()
		label:Destroy()
	end)
end

function Notify.start()
	Net.event("Notify").OnClientEvent:Connect(function(text, kind)
		Notify.toast(text, kind)
	end)
end

return Notify
