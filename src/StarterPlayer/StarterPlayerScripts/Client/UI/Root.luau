-- Owns the ScreenGui, global UI scale (so it fits phones through 4K), and the
-- "one big panel at a time" window manager.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Theme = require(script.Parent.Theme)

local Root = {}

local player = Players.LocalPlayer
local gui = Theme.new("ScreenGui", {
	Name = "DragonEggUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	Parent = player:WaitForChild("PlayerGui"),
})
Root.gui = gui

-- Separate full-screen layer for overlays that should ignore safe insets.
Root.overlay = Theme.new("ScreenGui", {
	Name = "DragonEggOverlay",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player.PlayerGui,
})

local scales = {}
Root.scale = 1
Root.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function computeScale()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.min(v.X / 1180, v.Y / 660)
	if Root.isMobile then
		s *= 1.12
	end
	return math.clamp(s, 0.48, 1.6)
end

local function applyScale()
	Root.scale = computeScale()
	for s in pairs(scales) do
		if s.Parent then
			s.Scale = Root.scale * (s:GetAttribute("Mult") or 1)
		else
			scales[s] = nil
		end
	end
end

-- Attach an auto-updating UIScale to a top-level element.
function Root.scaled(frame: GuiObject, mult: number?)
	local s = Theme.new("UIScale", { Scale = Root.scale * (mult or 1), Parent = frame })
	if mult then
		s:SetAttribute("Mult", mult)
	end
	scales[s] = true
	return s
end

task.defer(function()
	applyScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
end)
applyScale()

---------------------------------------------------------------------------
-- Window manager
---------------------------------------------------------------------------
local windows = {}
local current = nil
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = Lighting

local openedEvent = Instance.new("BindableEvent")
Root.WindowChanged = openedEvent.Event -- (name or nil)

function Root.register(name: string, frame: GuiObject, onOpen, onClose)
	windows[name] = { frame = frame, onOpen = onOpen, onClose = onClose }
	frame.Visible = false
end

function Root.isOpen(name: string): boolean
	return current == name
end

function Root.current()
	return current
end

function Root.close()
	if not current then
		return
	end
	local w = windows[current]
	local name = current
	current = nil
	if w then
		local sc = w.frame:FindFirstChild("PopScale")
		if sc then
			Theme.tween(sc, 0.12, { Scale = 0.85 })
		end
		task.delay(0.1, function()
			if current ~= name then
				w.frame.Visible = false
			end
		end)
		if w.onClose then
			w.onClose()
		end
	end
	Theme.tween(blur, 0.2, { Size = 0 })
	openedEvent:Fire(nil)
end

function Root.open(name: string, ...)
	if current == name then
		return
	end
	if current then
		local w = windows[current]
		if w then
			w.frame.Visible = false
			if w.onClose then
				w.onClose()
			end
		end
	end
	local w = windows[name]
	if not w then
		return
	end
	current = name
	w.frame.Visible = true
	local sc = w.frame:FindFirstChild("PopScale")
	if not sc then
		sc = Theme.new("UIScale", { Name = "PopScale", Parent = w.frame })
	end
	sc.Scale = 0.85
	Theme.tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	Theme.tween(blur, 0.2, { Size = 10 })
	if w.onOpen then
		w.onOpen(...)
	end
	openedEvent:Fire(name)
end

function Root.toggle(name: string, ...)
	if current == name then
		Root.close()
	else
		Root.open(name, ...)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if current then
			Root.close()
		end
	end
	local _ = processed
end)

-- Standard window shell: gradient panel + title bar + close button + body frame.
function Root.window(props)
	local holder = Theme.new("Frame", {
		Name = props.name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(props.width or 760, math.min(props.height or 500, 480)),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 10,
		Parent = gui,
	})
	Root.scaled(holder)
	local panel = Theme.card({
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		Color = Color3.new(1, 1, 1),
		Gradient = { Theme.C.panelTop, Theme.C.panelBottom, 90 },
		StrokeColor = Theme.C.panelStroke,
		StrokeThickness = 5,
		Radius = 22,
		ZIndex = 10,
		Parent = holder,
	})
	local accent = props.accent or Theme.C.purple
	local header = Theme.card({
		Name = "Header",
		Size = UDim2.new(1, -20, 0, 58),
		Position = UDim2.fromOffset(10, 10),
		Color = Color3.new(1, 1, 1),
		Gradient = { Theme.lighten(accent, 0.15), Theme.darken(accent, 0.15), 90 },
		StrokeColor = Theme.darken(accent, 0.6),
		Radius = 16,
		ZIndex = 11,
		Parent = panel,
	})
	local title = Theme.text({
		Text = props.title or "",
		Font = Theme.TitleFont,
		Size = UDim2.new(1, -140, 0, 40),
		Position = UDim2.new(0, 18, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		strokeThickness = 3,
		maxSize = 34,
		ZIndex = 12,
		Parent = header,
	})
	local subtitle = Theme.text({
		Name = "Subtitle",
		Text = "",
		Size = UDim2.new(0.5, -70, 0, 26),
		Position = UDim2.new(1, -70, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 244, 200),
		maxSize = 22,
		ZIndex = 12,
		Parent = header,
	})
	local close = Theme.button({
		Name = "Close",
		Text = "X",
		Color = Theme.C.red,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Radius = 12,
		Font = Theme.TitleFont,
		ZIndex = 13,
		Parent = header,
		onClick = function()
			Root.close()
		end,
	})
	local body = Theme.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 1, -94),
		Position = UDim2.fromOffset(14, 80),
		ZIndex = 11,
		Parent = panel,
	})
	Root.register(props.name, holder, props.onOpen, props.onClose)
	return { holder = holder, panel = panel, header = header, title = title, subtitle = subtitle, body = body, close = close }
end

-- Scrolling list that auto-sizes its canvas.
function Root.scroller(parent: Instance, props)
	props = props or {}
	local s = Theme.new("ScrollingFrame", {
		Name = props.name or "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(220, 210, 255),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = props.zindex or 11,
		Parent = parent,
	})
	Theme.pad(6, 6).Parent = s
	if props.grid then
		Theme.new("UIGridLayout", {
			CellSize = props.grid,
			CellPadding = UDim2.fromOffset(props.gap or 10, props.gap or 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = s,
		})
	else
		Theme.list(Enum.FillDirection.Vertical, props.gap or 8).Parent = s
	end
	return s
end

return Root
