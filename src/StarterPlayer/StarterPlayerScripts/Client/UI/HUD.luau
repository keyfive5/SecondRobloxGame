-- Always-on HUD: cash + income, speed, side menu, action bar (home / hatch all /
-- lock), event banner, and the carry banner with the guardian danger meter.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Layout = require(Shared.Layout)
local Biomes = require(Shared.Biomes)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local HUD = {}
local C = Theme.C
local new = Theme.new
local player = Players.LocalPlayer

local hatchFunc = Net.func("Hatch")
local lockFunc = Net.func("LockRemote")
local homeEvent = Net.event("Respawn")

local EVENT_INFO = {
	golden = { "🌟", "GOLDEN HOUR", Color3.fromRGB(255, 190, 40), "25% of hatches turn Golden!" },
	bloodmoon = { "🌑", "BLOOD MOON", Color3.fromRGB(200, 30, 50), "Rarer eggs • faster guardians" },
}

local badges = {}
HUD.badges = badges

local function sideButton(parent, order: number, icon: string, label: string, color: Color3, onClick)
	local b = Theme.button({
		Name = label,
		Text = "",
		Color = color,
		Size = UDim2.fromOffset(72, 72),
		LayoutOrder = order,
		Radius = 18,
		Parent = parent,
		onClick = function()
			Sounds.play("click")
			onClick()
		end,
	})
	Theme.text({ Text = icon, Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 6), stroke = false, maxSize = 34, Parent = b, ZIndex = 3 })
	Theme.text({ Text = label, Size = UDim2.new(1, -6, 0, 20), Position = UDim2.new(0, 3, 1, -24), maxSize = 16, Parent = b, ZIndex = 3 })
	local badge = Theme.card({
		Name = "Badge",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, 4, 0, -4),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.red,
		Radius = 13,
		StrokeThickness = 2,
		ZIndex = 4,
		Parent = b,
	})
	badge.Visible = false
	Theme.text({ Name = "N", Text = "!", Size = UDim2.fromScale(1, 1), maxSize = 16, ZIndex = 5, Parent = badge })
	badges[label] = badge
	return b
end

function HUD.setBadge(label: string, on: boolean, text: string?)
	local b = badges[label]
	if b then
		b.Visible = on
		b.N.Text = text or "!"
	end
end

---------------------------------------------------------------------------
local cashLabel, incomeLabel
local shownCash, targetCash = 0, 0

local function buildTop()
	local top = new("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(600, 210),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = Root.gui,
	})
	Root.scaled(top)
	local pill = Theme.card({
		Name = "Cash",
		Size = UDim2.fromOffset(290, 56),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.new(1, 1, 1),
		Gradient = { Color3.fromRGB(140, 240, 120), Color3.fromRGB(40, 170, 70), 90 },
		StrokeColor = Color3.fromRGB(20, 80, 30),
		StrokeThickness = 4,
		Radius = 28,
		Parent = top,
	})
	local icon = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(120, 230, 110),
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0, 5, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = pill,
	}, { Theme.corner(23), Theme.stroke(Color3.fromRGB(20, 90, 30), 3) })
	Theme.text({ Text = "$", Font = Theme.TitleFont, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), strokeColor = Color3.fromRGB(20, 90, 30), Parent = icon })
	cashLabel = Theme.text({
		Text = "0",
		Font = Theme.TitleFont,
		Size = UDim2.new(1, -70, 0, 40),
		Position = UDim2.new(0, 58, 0.5, 2),
		AnchorPoint = Vector2.new(0, 0.5),
		strokeColor = Color3.fromRGB(20, 70, 25),
		strokeThickness = 3,
		maxSize = 34,
		Parent = pill,
	})
	local pillScale = new("UIScale", { Parent = pill })
	local income = Theme.card({
		Name = "Income",
		Size = UDim2.fromOffset(190, 30),
		Position = UDim2.new(0.5, 0, 0, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.fromRGB(30, 40, 80),
		Transparency = 0.15,
		Radius = 15,
		StrokeThickness = 2,
		Parent = top,
	})
	incomeLabel = Theme.text({ Text = "+$0/s", Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = Color3.fromRGB(150, 255, 150), maxSize = 20, Parent = income })

	-- event banner
	local banner = Theme.card({
		Name = "Event",
		Size = UDim2.fromOffset(470, 34),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.new(1, 1, 1),
		Gradient = { C.gold, Theme.darken(C.gold, 0.4), 0 },
		Radius = 17,
		Parent = top,
	})
	banner.Visible = false
	local bannerText = Theme.text({ Text = "", Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 19, Parent = banner })

	-- carry banner
	local carry = Theme.card({
		Name = "Carry",
		Size = UDim2.fromOffset(440, 64),
		Position = UDim2.new(0.5, 0, 0, 136),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.new(1, 1, 1),
		Gradient = { Color3.fromRGB(255, 160, 60), Color3.fromRGB(200, 70, 30), 90 },
		StrokeColor = Color3.fromRGB(90, 30, 10),
		Radius = 16,
		Parent = top,
	})
	carry.Visible = false
	local carryText = Theme.text({ Text = "", Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0.5, 0, 0, 5), AnchorPoint = Vector2.new(0.5, 0), maxSize = 22, Parent = carry })
	local dangerBack = Theme.card({ Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Color = Color3.fromRGB(40, 20, 20), Radius = 9, StrokeThickness = 2, Parent = carry })
	local dangerFill = Theme.card({ Size = UDim2.fromScale(0, 1), Color = C.red, Radius = 9, Stroke = false, Parent = dangerBack })
	local dangerText = Theme.text({ Text = "", Size = UDim2.fromScale(1, 1), maxSize = 14, ZIndex = 3, Parent = dangerBack })

	RunService.Heartbeat:Connect(function()
		-- cash count-up
		if shownCash ~= targetCash then
			local diff = targetCash - shownCash
			if math.abs(diff) < 1 then
				shownCash = targetCash
			else
				shownCash += diff * 0.2
			end
			local v = math.floor(shownCash + 0.5)
			cashLabel.Text = v < 1e6 and Format.commas(v) or Format.short(v)
		end
		incomeLabel.Text = "+" .. Format.rate(player:GetAttribute("Income") or 0)
		-- events
		local id = ReplicatedStorage:GetAttribute("EventId")
		local ends = ReplicatedStorage:GetAttribute("EventEnds") or 0
		local luckUntil = ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0
		local info = id and EVENT_INFO[id]
		local left = ends - os.time()
		if info and left > 0 then
			banner.Visible = true
			bannerText.Text = string.format("%s %s  %s  • %s", info[1], info[2], Format.clock(left), info[4])
			banner:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(info[3], Theme.darken(info[3], 0.45))
		elseif luckUntil > os.time() then
			banner.Visible = true
			bannerText.Text = "🌈 SERVER LUCK x2  " .. Format.clock(luckUntil - os.time())
			banner:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(C.purple, Theme.darken(C.purple, 0.45))
		else
			banner.Visible = false
		end
		-- carrying
		local carrying = player:GetAttribute("Carrying")
		carry.Visible = carrying ~= nil
		if carrying then
			local zone = player:GetAttribute("CarryZone")
			local g = zone and workspace:FindFirstChild("Guardians") and workspace.Guardians:FindFirstChild("Guardian_" .. zone)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local chasing = g and g:GetAttribute("State") == "chase" or (g and g:GetAttribute("State") == "wake")
			if chasing and hrp and g.PrimaryPart then
				local d = (g.PrimaryPart.Position - hrp.Position) * Vector3.new(1, 0, 1)
				local info2 = Layout.Biomes[zone]
				local toGate = math.max(0, hrp.Position.Z - info2.zStart)
				carryText.Text = string.format("🐉 %s IS CHASING YOU! RUN to the gate (%dm)", string.upper(Biomes.List[zone].guardian), math.floor(toGate))
				local danger = math.clamp(1 - (d.Magnitude - Layout.GuardCatch) / 80, 0, 1)
				dangerBack.Visible = true
				dangerFill.Size = UDim2.fromScale(danger, 1)
				dangerText.Text = string.format("%d studs away", math.floor(d.Magnitude))
			else
				carryText.Text = "🥚 Carrying " .. carrying .. " — run home! 🏠"
				dangerBack.Visible = false
			end
		end
	end)

	State.onChange("cash", function(v)
		local up = v > targetCash
		targetCash = v
		if up and State.loaded then
			pillScale.Scale = 1.1
			Theme.tween(pillScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	State.whenLoaded(function()
		targetCash = State.data.cash
		shownCash = targetCash
		cashLabel.Text = Format.commas(targetCash)
	end)
end

---------------------------------------------------------------------------
local function buildSide()
	local side = new("Frame", {
		Name = "Side",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(160, 340),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = Root.gui,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(72, 72),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirectionMaxCells = 2,
		}),
	})
	Root.scaled(side)
	sideButton(side, 1, "🛒", "Store", C.gold, function()
		Root.toggle("Store")
	end)
	sideButton(side, 2, "📖", "Index", C.green, function()
		Root.toggle("Index")
	end)
	sideButton(side, 3, "⚡", "Upgrades", C.orange, function()
		Root.toggle("Upgrades")
	end)
	sideButton(side, 4, "📜", "Quests", C.blue, function()
		Root.toggle("Quests")
	end)
	sideButton(side, 5, "🎁", "Rewards", C.pink, function()
		Root.toggle("Rewards")
	end)
	sideButton(side, 6, "⚙️", "Settings", C.grey, function()
		Root.toggle("Settings")
	end)
end

---------------------------------------------------------------------------
local function buildActions()
	local bar = new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(620, 54),
		Position = UDim2.new(0.5, 0, 1, -82),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = Root.gui,
	}, { Theme.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	Root.scaled(bar)
	local speed = Theme.card({
		Name = "Speed",
		Size = UDim2.fromOffset(130, 44),
		LayoutOrder = 1,
		Color = Color3.new(1, 1, 1),
		Gradient = { Color3.fromRGB(110, 190, 255), Color3.fromRGB(40, 100, 220), 90 },
		StrokeColor = Color3.fromRGB(10, 30, 80),
		Radius = 14,
		Parent = bar,
	})
	local speedText = Theme.text({ Text = "⚡ 20", Font = Theme.TitleFont, Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 24, Parent = speed })
	Theme.button({
		Name = "Home",
		Text = "🏠 Home",
		Color = C.orange,
		Size = UDim2.fromOffset(130, 44),
		LayoutOrder = 2,
		maxSize = 22,
		Parent = bar,
		onClick = function()
			Sounds.play("whoosh")
			homeEvent:FireServer()
		end,
	})
	local hatchBtn, hatchLabel = Theme.button({
		Name = "HatchAll",
		Text = "🐣 Hatch All",
		Color = C.pink,
		Size = UDim2.fromOffset(160, 44),
		LayoutOrder = 3,
		maxSize = 22,
		Parent = bar,
		onClick = function()
			hatchFunc:InvokeServer("all")
		end,
	})
	hatchBtn.Visible = false
	local lockBtn, lockLabel = Theme.button({
		Name = "Lock",
		Text = "🔒 Lock",
		Color = C.red,
		Size = UDim2.fromOffset(130, 44),
		LayoutOrder = 4,
		maxSize = 22,
		Parent = bar,
		onClick = function()
			if player:GetAttribute("Pass_SuperLock") then
				lockFunc:InvokeServer()
			else
				Root.open("Store", "SuperLock")
			end
		end,
	})
	HUD.hatchButton = hatchBtn
	task.spawn(function()
		while true do
			speedText.Text = "⚡ " .. (player:GetAttribute("Speed") or 20)
			-- ready eggs in my base
			local slot = player:GetAttribute("BaseSlot")
			local ready = 0
			local lockLeft = 0
			if slot then
				local f = ReplicatedStorage.BaseData:FindFirstChild("Base_" .. slot)
				if f then
					local t = workspace:GetServerTimeNow()
					for n = 1, Layout.MaxPads do
						local v = f:FindFirstChild("P" .. n)
						if v and v.Value ~= "" and v.Value:find('"k":"egg"') then
							local ok, d = pcall(game.HttpService.JSONDecode, game.HttpService, v.Value)
							if ok and d.ready and d.ready <= t + 0.5 then
								ready += 1
							end
						end
					end
					lockLeft = (f:GetAttribute("LockUntil") or 0) - t
				end
			end
			hatchBtn.Visible = ready > 0
			hatchLabel.Text = ready > 1 and ("🐣 Hatch All (" .. ready .. ")") or "🐣 Hatch!"
			lockLabel.Text = lockLeft > 0 and ("🔒 " .. math.ceil(lockLeft) .. "s") or "🔒 Lock"
			task.wait(0.25)
		end
	end)
end

function HUD.start()
	buildTop()
	buildSide()
	buildActions()
end

return HUD
