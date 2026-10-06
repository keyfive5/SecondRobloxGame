-- Global leaderboards on the hub boards, backed by OrderedDataStores.
-- Values are stored log-compressed so they fit in an integer at any size.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local BOARDS = {
	{ id = "Income", store = "LB_Income_1", get = function(d) return d.stats.bestCps or 0 end, fmt = function(v) return Format.rate(v) end },
	{ id = "Steals", store = "LB_Steals_1", get = function(d) return d.stats.steals or 0 end, fmt = function(v) return "🦹 " .. Format.commas(math.floor(v + 0.5)) end },
}

local function encode(v: number): number
	return math.floor(math.log10(math.max(v, 0) + 1) * 1e9)
end

local function decode(v: number): number
	return 10 ^ (v / 1e9) - 1
end

local names = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and n or "Dragon Thief"
	return names[userId]
end

-- Build the SurfaceGui skeleton (front and back) on a board part once.
local function listsOf(boardId: string)
	local hub = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub")
	local model = hub and hub:FindFirstChild("Leaderboards") and hub.Leaderboards:FindFirstChild(boardId)
	local board = model and model:FindFirstChild("Board")
	if not board then
		return {}
	end
	if not board:FindFirstChild("LB_Front") then
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local gui = Instance.new("SurfaceGui")
			gui.Name = "LB_" .. face.Name
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 30
			gui.LightInfluence = 0
			gui.Parent = board
			local title = Instance.new("TextLabel")
			title.BackgroundTransparency = 1
			title.Size = UDim2.fromScale(1, 0.13)
			title.Font = Enum.Font.LuckiestGuy
			title.TextScaled = true
			title.TextColor3 = Color3.fromRGB(255, 220, 90)
			title.Text = board:GetAttribute("Title") or boardId
			local s = Instance.new("UIStroke")
			s.Thickness = 3
			s.Parent = title
			title.Parent = gui
			local list = Instance.new("Frame")
			list.Name = "List"
			list.BackgroundTransparency = 1
			list.Position = UDim2.fromScale(0.04, 0.15)
			list.Size = UDim2.fromScale(0.92, 0.83)
			local l = Instance.new("UIListLayout")
			l.Padding = UDim.new(0.008, 0)
			l.SortOrder = Enum.SortOrder.LayoutOrder
			l.Parent = list
			list.Parent = gui
		end
	end
	return { board.LB_Front.List, board.LB_Back.List }
end

local MEDALS = { Color3.fromRGB(255, 215, 70), Color3.fromRGB(220, 225, 235), Color3.fromRGB(230, 150, 90) }

local function render(boardId: string, rows)
	for _, list in ipairs(listsOf(boardId)) do
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for i, row in ipairs(rows) do
			local f = Instance.new("Frame")
			f.BackgroundTransparency = (i % 2 == 0) and 0.85 or 0.75
			f.BackgroundColor3 = Color3.new(1, 1, 1)
			f.Size = UDim2.new(1, 0, 0.092, 0)
			f.LayoutOrder = i
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.2, 0)
			corner.Parent = f
			local function txt(text, x, w, align, color)
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Position = UDim2.fromScale(x, 0.08)
				t.Size = UDim2.fromScale(w, 0.84)
				t.Font = Enum.Font.FredokaOne
				t.TextScaled = true
				t.TextXAlignment = align
				t.TextColor3 = color or Color3.new(1, 1, 1)
				t.TextStrokeTransparency = 0.4
				t.Text = text
				t.Parent = f
			end
			txt("#" .. i, 0.02, 0.12, Enum.TextXAlignment.Left, MEDALS[i])
			txt(row.name, 0.15, 0.48, Enum.TextXAlignment.Left, MEDALS[i])
			txt(row.text, 0.6, 0.38, Enum.TextXAlignment.Right)
			f.Parent = list
		end
	end
end

local function refresh()
	for _, b in ipairs(BOARDS) do
		local rows = {}
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, b.store)
		if ok then
			for player, profile in pairs(DataService.Profiles) do
				if not profile.temporary then
					local v = b.get(profile.data, player)
					if v and v > 0 then
						pcall(store.SetAsync, store, tostring(player.UserId), encode(v))
					end
				end
			end
			local ok2, pages = pcall(store.GetSortedAsync, store, false, 10)
			if ok2 then
				for _, entry in ipairs(pages:GetCurrentPage()) do
					local uid = tonumber(entry.key)
					if uid then
						table.insert(rows, { name = nameOf(uid), text = b.fmt(decode(entry.value)) })
					end
				end
			end
		end
		render(b.id, rows)
	end
end

function LeaderboardService.start()
	task.spawn(function()
		task.wait(8)
		while true do
			pcall(refresh)
			task.wait(150)
		end
	end)
end

return LeaderboardService
