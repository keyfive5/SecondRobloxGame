-- Rewards (daily streak + playtime gifts + invite friends), Quests and Settings
-- (music is OFF until the player turns it on; codes live here too).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage.Shared
local Rewards = require(Shared.Rewards)
local Quests = require(Shared.Quests)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local HUD = require(script.Parent.HUD)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local MiscPanels = {}
local C = Theme.C
local new = Theme.new
local player = Players.LocalPlayer

local function describe(spec): string
	local lines = {}
	local cash = Rewards.cash(spec, player:GetAttribute("Income") or 0)
	if cash > 0 then
		table.insert(lines, "💰 " .. Format.cash(cash))
	end
	for _, r in ipairs(spec.eggs or {}) do
		table.insert(lines, "🥚 " .. r .. " Egg")
	end
	for k, s in pairs(spec.boost or {}) do
		table.insert(lines, (k == "luck" and "🔮 2x Luck " or "💸 2x Cash ") .. Format.duration(s))
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Rewards: daily + gifts + invite
---------------------------------------------------------------------------
local function buildRewards()
	local win = Root.window({ name = "Rewards", title = "🎁 REWARDS", accent = C.pink, width = 820, height = 480 })
	local body = win.body
	Theme.text({ Text = "📅 DAILY STREAK", Font = Theme.TitleFont, Size = UDim2.new(0.5, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 22, Parent = body })
	local dailyRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 130), Position = UDim2.fromOffset(0, 30), Parent = body }, { Theme.list(Enum.FillDirection.Horizontal, 6) })
	local tiles = {}
	for day = 1, Rewards.DailyCycle do
		local tile = Theme.card({ Size = UDim2.fromOffset(104, 128), Color = Color3.new(1, 1, 1), Gradient = { C.card, C.cardDark, 90 }, LayoutOrder = day, Parent = dailyRow })
		Theme.text({ Text = "DAY " .. day, Font = Theme.TitleFont, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 4), maxSize = 20, Parent = tile })
		local desc = Theme.text({ Text = "", Size = UDim2.new(1, -8, 0, 90), Position = UDim2.fromOffset(4, 32), maxSize = 14, strokeThickness = 1.5, TextYAlignment = Enum.TextYAlignment.Top, Parent = tile })
		tiles[day] = { tile = tile, desc = desc }
	end
	local claim, claimLabel = Theme.button({ Text = "CLAIM", Color = C.green, Size = UDim2.fromOffset(240, 44), Position = UDim2.new(1, 0, 0, -2), AnchorPoint = Vector2.new(1, 0), Font = Theme.TitleFont, maxSize = 20, Parent = body })
	claim.Size = UDim2.fromOffset(240, 30)

	Theme.text({ Text = "⏰ PLAYTIME GIFTS", Font = Theme.TitleFont, Size = UDim2.new(0.5, 0, 0, 26), Position = UDim2.fromOffset(0, 170), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 22, Parent = body })
	local giftRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), Position = UDim2.fromOffset(0, 200), Parent = body }, { Theme.list(Enum.FillDirection.Horizontal, 8) })
	local gifts = {}
	for i, need in ipairs(Rewards.GiftTimes) do
		local tile = Theme.card({ Size = UDim2.fromOffset(150, 148), Color = Color3.new(1, 1, 1), Gradient = { C.card, C.cardDark, 90 }, LayoutOrder = i, Parent = giftRow })
		Theme.text({ Text = "🎁", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 4), stroke = false, maxSize = 30, Parent = tile })
		local desc = Theme.text({ Text = "", Size = UDim2.new(1, -10, 0, 50), Position = UDim2.fromOffset(5, 40), maxSize = 14, strokeThickness = 1.5, TextYAlignment = Enum.TextYAlignment.Top, Parent = tile })
		local btn, label = Theme.button({ Text = Format.duration(need), Color = C.grey, Size = UDim2.new(1, -16, 0, 38), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), maxSize = 18, Parent = tile })
		btn.Activated:Connect(function()
			local ok, msg = Net.func("ClaimGift"):InvokeServer(i)
			if ok then
				Sounds.play("stinger")
			elseif msg then
				Notify.toast(msg, "info")
			end
		end)
		gifts[i] = { desc = desc, btn = btn, label = label, need = need }
	end
	-- invite friends
	local invite = Theme.card({ Size = UDim2.fromOffset(150, 148), Color = Color3.new(1, 1, 1), Gradient = { C.blue, Theme.darken(C.blue, 0.5), 90 }, LayoutOrder = 10, Parent = giftRow })
	Theme.text({ Text = "👥", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 4), stroke = false, maxSize = 30, Parent = invite })
	Theme.text({ Text = "Invite a friend: you both get a free egg!", Size = UDim2.new(1, -10, 0, 50), Position = UDim2.fromOffset(5, 40), maxSize = 14, strokeThickness = 1.5, Parent = invite })
	Theme.button({ Text = "INVITE", Color = C.green, Size = UDim2.new(1, -16, 0, 38), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Font = Theme.TitleFont, maxSize = 18, Parent = invite, onClick = function()
		pcall(function()
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage = "Help me steal dragon eggs!"
			SocialService:PromptGameInvite(player, options)
		end)
	end })

	local info
	local function refreshDaily()
		info = Net.func("DailyStatus"):InvokeServer()
		if not info then
			return
		end
		for day, t in ipairs(tiles) do
			t.desc.Text = describe(Rewards.Daily[day])
			local g = t.tile:FindFirstChildOfClass("UIGradient")
			if day == info.nextDay and info.canClaim then
				g.Color = ColorSequence.new(Theme.lighten(C.green, 0.1), Theme.darken(C.green, 0.4))
			elseif day < info.nextDay then
				g.Color = ColorSequence.new(C.grey, Theme.darken(C.grey, 0.4))
			else
				g.Color = ColorSequence.new(C.card, C.cardDark)
			end
		end
		if info.canClaim then
			claimLabel.Text = "🎁 CLAIM DAY " .. info.nextDay
			Theme.setButtonColor(claim, C.green)
		else
			claimLabel.Text = "Next in " .. Format.duration(info.resetsIn)
			Theme.setButtonColor(claim, C.grey)
		end
	end
	claim.Activated:Connect(function()
		if info and info.canClaim then
			if Net.func("ClaimDaily"):InvokeServer() then
				Sounds.play("stinger")
			end
			refreshDaily()
		end
	end)
	Root.WindowChanged:Connect(function(name)
		if name == "Rewards" then
			task.spawn(refreshDaily)
		end
	end)

	-- gifts + badge ticker
	task.spawn(function()
		State.waitLoaded()
		refreshDaily()
		local claimed = {}
		local status = Net.func("GiftStatus"):InvokeServer()
		claimed = status and status.claimed or {}
		local start = os.clock() - (status and status.elapsed or 0)
		local lastPoll = os.clock()
		while true do
			if os.clock() - lastPoll > 20 or (Root.isOpen("Rewards") and os.clock() - lastPoll > 2) then
				local s = Net.func("GiftStatus"):InvokeServer()
				claimed = s and s.claimed or claimed
				lastPoll = os.clock()
			end
			local elapsed = os.clock() - start
			local ready = 0
			for i, t in ipairs(gifts) do
				t.desc.Text = describe(Rewards.Gifts[i])
				if claimed[i] or claimed[tostring(i)] then
					t.label.Text = "CLAIMED"
					Theme.setButtonColor(t.btn, C.grey)
				elseif elapsed >= t.need then
					t.label.Text = "CLAIM!"
					Theme.setButtonColor(t.btn, C.green)
					ready += 1
				else
					t.label.Text = Format.clock(t.need - elapsed)
					Theme.setButtonColor(t.btn, C.cardDark)
				end
			end
			if info and info.canClaim then
				ready += 1
			end
			HUD.setBadge("Rewards", ready > 0, tostring(ready))
			task.wait(1)
		end
	end)
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
local function buildQuests()
	local win = Root.window({ name = "Quests", title = "📜 DAILY QUESTS", accent = C.blue, width = 700, height = 470 })
	local body = win.body
	local rows = {}
	for i = 1, 3 do
		local row = Theme.card({ Size = UDim2.new(1, 0, 0, 92), Position = UDim2.fromOffset(0, (i - 1) * 100), Color = C.card, Radius = 14, Parent = body })
		local title = Theme.text({ Text = "", Font = Theme.TitleFont, Size = UDim2.new(1, -200, 0, 28), Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 22, Parent = row })
		local reward = Theme.text({ Text = "", Size = UDim2.new(1, -200, 0, 20), Position = UDim2.fromOffset(12, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold, maxSize = 16, Parent = row })
		local barBg = Theme.card({ Size = UDim2.new(1, -210, 0, 18), Position = UDim2.fromOffset(12, 62), Color = Color3.fromRGB(20, 24, 60), Radius = 9, StrokeThickness = 2, Parent = row })
		local fill = Theme.card({ Size = UDim2.fromScale(0, 1), Color = C.green, Radius = 9, Stroke = false, Parent = barBg })
		local count = Theme.text({ Text = "", Size = UDim2.fromScale(1, 1), maxSize = 14, ZIndex = 3, Parent = barBg })
		local btn, label = Theme.button({ Text = "", Color = C.grey, Size = UDim2.fromOffset(170, 50), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Font = Theme.TitleFont, maxSize = 20, Parent = row, onClick = function()
			if Net.func("ClaimQuest"):InvokeServer(i) then
				Sounds.play("stinger")
			end
		end })
		rows[i] = { row = row, title = title, reward = reward, fill = fill, count = count, btn = btn, label = label }
	end
	local bonus, bonusLabel = Theme.button({ Text = "", Color = C.grey, Size = UDim2.new(1, 0, 0, 54), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Font = Theme.TitleFont, maxSize = 20, Parent = body, onClick = function()
		if Net.func("ClaimQuest"):InvokeServer("bonus") then
			Sounds.play("stinger")
		end
	end })

	local function refresh()
		local q = State.data.quests or {}
		local list = q.list or {}
		local ready, allDone = 0, #list > 0
		for i, r in ipairs(rows) do
			local e = list[i]
			r.row.Visible = e ~= nil
			if e then
				local def = Quests.ById[e.id]
				local needText = def.cashGoal and Format.cash(e.need) or tostring(e.need)
				r.title.Text = string.format(def.text, def.cashGoal and needText or e.need)
				r.reward.Text = "Reward: " .. describe(def.reward):gsub("\n", " + ")
				r.fill.Size = UDim2.fromScale(math.clamp(e.have / math.max(e.need, 1), 0, 1), 1)
				r.count.Text = def.cashGoal and (Format.cash(e.have) .. " / " .. needText) or (e.have .. " / " .. e.need)
				if e.claimed then
					r.label.Text = "✅ DONE"
					Theme.setButtonColor(r.btn, C.grey)
				elseif e.have >= e.need then
					r.label.Text = "CLAIM!"
					Theme.setButtonColor(r.btn, C.green)
					ready += 1
				else
					r.label.Text = "In progress"
					Theme.setButtonColor(r.btn, C.cardDark)
				end
				if not e.claimed then
					allDone = false
				end
			end
		end
		if q.bonus then
			bonusLabel.Text = "🏆 Bonus claimed — new quests tomorrow!"
			Theme.setButtonColor(bonus, C.grey)
		elseif allDone then
			bonusLabel.Text = "🏆 CLAIM BONUS: " .. describe(Quests.Bonus):gsub("\n", " + ")
			Theme.setButtonColor(bonus, C.gold)
			ready += 1
		else
			bonusLabel.Text = "🏆 Finish all 3 for: " .. describe(Quests.Bonus):gsub("\n", " + ")
			Theme.setButtonColor(bonus, C.cardDark)
		end
		HUD.setBadge("Quests", ready > 0, tostring(ready))
	end
	State.onChange("quests", refresh)
	State.whenLoaded(refresh)
end

---------------------------------------------------------------------------
-- Settings + codes
---------------------------------------------------------------------------
local function buildSettings()
	local win = Root.window({ name = "Settings", title = "⚙️ SETTINGS", accent = C.grey, width = 580, height = 430 })
	local body = win.body
	local levels = { { "Off", 0 }, { "Low", 0.25 }, { "Med", 0.5 }, { "High", 1 } }
	local function selector(y: number, label: string, key: string, default: number)
		Theme.text({ Text = label, Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(4, y), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 24, Parent = body })
		local buttons = {}
		local function paint()
			local v = State.data.settings and State.data.settings[key] or default
			local best, bi = 99, 1
			for i, lv in ipairs(levels) do
				if math.abs(lv[2] - v) < best then
					best, bi = math.abs(lv[2] - v), i
				end
			end
			for j, b in ipairs(buttons) do
				Theme.setButtonColor(b, j == bi and C.green or C.cardDark)
			end
		end
		for i, lv in ipairs(levels) do
			buttons[i] = Theme.button({ Text = lv[1], Color = C.cardDark, Size = UDim2.fromOffset(84, 40), Position = UDim2.fromOffset(160 + (i - 1) * 92, y), maxSize = 20, Parent = body, onClick = function()
				State.data.settings[key] = lv[2]
				Sounds.setVolumes(State.data.settings.music or 0, State.data.settings.sfx or 0.7)
				Net.func("SaveSettings"):InvokeServer(State.data.settings)
				Sounds.play("click")
				paint()
			end })
		end
		State.whenLoaded(paint)
		paint()
	end
	selector(4, "🎵 Music", "music", 0)
	Theme.text({ Text = "Music is off by default — turn it on if you like!", Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(4, 48), TextColor3 = C.textDim, maxSize = 15, Parent = body })
	selector(76, "🔊 Sounds", "sfx", 0.7)

	Theme.text({ Text = "🎟️ Codes", Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(4, 140), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 24, Parent = body })
	local boxBg = Theme.card({ Size = UDim2.fromOffset(250, 44), Position = UDim2.fromOffset(160, 138), Color = Color3.fromRGB(24, 26, 60), Parent = body })
	local box = new("TextBox", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Font = Theme.Font, TextScaled = true,
		PlaceholderText = "Enter code...", PlaceholderColor3 = Color3.fromRGB(150, 150, 200), Text = "", TextColor3 = Color3.new(1, 1, 1),
		ClearTextOnFocus = false, Parent = boxBg,
	})
	Theme.button({ Text = "Redeem", Color = C.green, Size = UDim2.fromOffset(120, 44), Position = UDim2.fromOffset(420, 138), maxSize = 20, Parent = body, onClick = function()
		local ok, msg = Net.func("Redeem"):InvokeServer(box.Text)
		if not ok then
			Notify.toast(msg or "Invalid code", "bad")
		else
			box.Text = ""
			Sounds.play("stinger")
		end
	end })
	Theme.text({ Text = "New codes drop with every update! Try: RELEASE", Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(4, 192), TextColor3 = C.textDim, maxSize = 17, Parent = body })
	Theme.text({ Text = "🐉 Steal a Dragon Egg\nGrab eggs from the guardians' nests, outrun them, hatch dragons, get rich.\nLock your base — and slap anyone who tries to steal from you!", Size = UDim2.new(1, -10, 0, 80), Position = UDim2.new(0, 4, 1, -84), TextColor3 = C.textDim, maxSize = 16, strokeThickness = 1.5, Parent = body })
end

function MiscPanels.start()
	buildRewards()
	buildQuests()
	buildSettings()
	State.whenLoaded(function()
		local s = State.data.settings or {}
		Sounds.setVolumes(s.music or 0, s.sfx or 0.7)
	end)
end

return MiscPanels
