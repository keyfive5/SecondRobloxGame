-- Dragon Index: every species by biome, with 3D previews (silhouettes until
-- discovered) and which mutations you've collected for each.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local Biomes = require(Shared.Biomes)
local Rarity = require(Shared.Rarity)
local Traits = require(Shared.Traits)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local Viewport = require(script.Parent.Viewport)
local State = require(script.Parent.Parent.State)

local IndexPanel = {}
local C = Theme.C

function IndexPanel.start()
	local cards = {}
	local built = false
	local counter
	local w
	local function refresh()
		if not built then
			return
		end
		local index = State.data.index or {}
		local found = 0
		for id, c in pairs(cards) do
			local has = index[id] == true
			if has then
				found += 1
			end
			if c.has ~= has then
				c.has = has
				if c.vp then
					c.vp:Destroy()
				end
				c.vp = Viewport.dragon(c.box, { sp = id }, UDim2.fromScale(1, 1), not has)
				c.name.Text = has and c.sp.name or "???"
				c.rate.Text = has and Format.rate(c.sp.cps) or ""
			end
			for mid, dot in pairs(c.dots) do
				dot.BackgroundTransparency = index[id .. ":" .. mid] and 0 or 0.8
			end
		end
		counter.Text = string.format("Discovered %d / %d", found, #Species.List)
	end

	local function build()
		built = true
		local scroll = Root.scroller(w.body, { gap = 6 })
		local groups = {}
		for i, b in ipairs(Biomes.List) do
			table.insert(groups, { title = b.name, color = b.color, biome = i })
		end
		table.insert(groups, { title = "❓ Secret Eggs", color = Color3.fromRGB(40, 40, 50), biome = 0 })
		local order = 0
		for _, g in ipairs(groups) do
			order += 1
			local header = Theme.card({ Size = UDim2.new(1, -12, 0, 32), Color = g.color:Lerp(Color3.new(0, 0, 0), 0.35), Radius = 10, LayoutOrder = order, Parent = scroll })
			Theme.text({ Text = g.title, Font = Theme.TitleFont, Size = UDim2.new(1, -20, 1, -6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 22, Parent = header })
			order += 1
			local grid = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = scroll }, {
				Theme.new("UIGridLayout", { CellSize = UDim2.fromOffset(136, 176), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			for _, sp in ipairs(Species.List) do
				if sp.biome == g.biome then
					local rc = Rarity.color(sp.rarity)
					local card = Theme.card({ Color = C.card, Radius = 14, LayoutOrder = sp.order, Parent = grid, StrokeColor = rc:Lerp(Color3.new(0, 0, 0), 0.3) })
					local box = Theme.new("Frame", { BackgroundColor3 = Color3.fromRGB(30, 36, 80), Size = UDim2.new(1, -12, 0, 96), Position = UDim2.fromOffset(6, 6), Parent = card }, { Theme.corner(10) })
					local name = Theme.text({ Text = "???", Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 104), maxSize = 16, Parent = card })
					Theme.text({ Text = sp.rarity, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 124), TextColor3 = rc, maxSize = 14, Parent = card })
					local rate = Theme.text({ Text = "", Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 140), TextColor3 = Color3.fromRGB(150, 255, 150), maxSize = 13, Parent = card })
					local dotRow = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 12), Position = UDim2.fromOffset(4, 158), Parent = card }, {
						Theme.list(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Center),
					})
					local dots = {}
					for k, m in ipairs(Traits.Mutations) do
						dots[m.id] = Theme.new("Frame", { BackgroundColor3 = m.color, BackgroundTransparency = 0.8, Size = UDim2.fromOffset(12, 12), LayoutOrder = k, Parent = dotRow }, { Theme.corner(6) })
					end
					cards[sp.id] = { sp = sp, box = box, name = name, rate = rate, dots = dots }
				end
			end
		end
		refresh()
	end

	w = Root.window({ name = "Index", title = "📖 DRAGON INDEX", accent = C.green, width = 800, height = 480, onOpen = function()
		if not built then
			build()
		end
	end })
	counter = w.subtitle
	State.onChange("index", refresh)
end

return IndexPanel
