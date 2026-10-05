-- Tiny declarative UI toolkit + the game's visual style.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.TitleFont = Enum.Font.LuckiestGuy

Theme.C = {
	panelTop = Color3.fromRGB(58, 70, 150),
	panelBottom = Color3.fromRGB(30, 34, 86),
	panelStroke = Color3.fromRGB(14, 14, 40),
	card = Color3.fromRGB(78, 94, 186),
	cardDark = Color3.fromRGB(44, 54, 120),
	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(205, 196, 240),
	stroke = Color3.fromRGB(26, 16, 48),
	gold = Color3.fromRGB(255, 202, 58),
	green = Color3.fromRGB(86, 214, 98),
	red = Color3.fromRGB(240, 74, 86),
	blue = Color3.fromRGB(72, 166, 255),
	purple = Color3.fromRGB(172, 104, 255),
	pink = Color3.fromRGB(255, 110, 180),
	grey = Color3.fromRGB(130, 128, 150),
	orange = Color3.fromRGB(255, 150, 50),
}

function Theme.new(class: string, props, children)
	local inst = Instance.new(class)
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = Theme.new

function Theme.corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

function Theme.stroke(color: Color3?, thickness: number?, mode)
	return new("UIStroke", {
		Color = color or Theme.C.stroke,
		Thickness = thickness or 3,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Theme.textStroke(thickness: number?, color: Color3?)
	return new("UIStroke", { Color = color or Theme.C.stroke, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

function Theme.gradient(a: Color3, b: Color3, rotation: number?)
	return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90 })
end

function Theme.pad(px: number, py: number?)
	py = py or px
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, py), PaddingBottom = UDim.new(0, py),
	})
end

function Theme.list(dir, padding: number?, hAlign, vAlign)
	return new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Theme.lighten(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), k)
end

function Theme.darken(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end

-- Text label with the cartoon outline.
function Theme.text(props)
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = props.Font or Theme.Font,
		TextColor3 = props.TextColor3 or Theme.C.text,
		TextScaled = props.TextScaled ~= false,
		TextSize = props.TextSize or 18,
		TextWrapped = true,
		RichText = props.RichText or false,
		Text = props.Text or "",
		Size = props.Size or UDim2.new(1, 0, 0, 24),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Name = props.Name or "Text",
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	if props.stroke ~= false then
		Theme.textStroke(props.strokeThickness or 2, props.strokeColor).Parent = t
	end
	if props.maxSize then
		new("UITextSizeConstraint", { MaxTextSize = props.maxSize, MinTextSize = props.minSize or 8, Parent = t })
	end
	return t
end

local function pressFx(button: GuiButton)
	local scale = new("UIScale", { Scale = 1, Parent = button })
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	button.MouseEnter:Connect(function()
		if not UserInputService.TouchEnabled then
			TweenService:Create(scale, info, { Scale = 1.05 }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, info, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, info, { Scale = 0.93 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, info, { Scale = 1 }):Play()
	end)
end
Theme.pressFx = pressFx

-- Chunky colored button. Returns the button and its label.
function Theme.button(props)
	local color = props.Color or Theme.C.green
	local b = new("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = props.Size or UDim2.fromOffset(140, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		LayoutOrder = props.LayoutOrder or 0,
		Text = "",
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, {
		Theme.corner(props.Radius or 12),
		Theme.stroke(Theme.darken(color, 0.55), props.StrokeThickness or 3),
		new("UIGradient", {
			Color = ColorSequence.new(Theme.lighten(color, 0.25), Theme.darken(color, 0.12)),
			Rotation = 90,
		}),
	})
	local label = Theme.text({
		Text = props.Text or "",
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = props.Font or Theme.Font,
		RichText = props.RichText,
		ZIndex = (props.ZIndex or 1) + 1,
		maxSize = props.maxSize or 26,
		Parent = b,
	})
	pressFx(b)
	if props.onClick then
		b.Activated:Connect(props.onClick)
	end
	return b, label
end

function Theme.setButtonColor(b: GuiButton, color: Color3)
	b.BackgroundColor3 = color
	local s = b:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = Theme.darken(color, 0.55)
	end
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(Theme.lighten(color, 0.25), Theme.darken(color, 0.12))
	end
end

-- Rounded card / panel background.
function Theme.card(props)
	local f = new("Frame", {
		Name = props.Name or "Card",
		BackgroundColor3 = props.Color or Theme.C.card,
		BackgroundTransparency = props.Transparency or 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		LayoutOrder = props.LayoutOrder or 0,
		ClipsDescendants = props.Clips or false,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, {
		Theme.corner(props.Radius or 14),
	})
	if props.Stroke ~= false then
		Theme.stroke(props.StrokeColor or Theme.C.stroke, props.StrokeThickness or 3).Parent = f
	end
	if props.Gradient then
		Theme.gradient(props.Gradient[1], props.Gradient[2], props.Gradient[3]).Parent = f
	end
	return f
end

-- A small diamond-shaped gem icon drawn with UI (cheap, no viewport).
function Theme.gemIcon(color: Color3, size: number, parent: Instance?)
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Name = "GemIcon", Parent = parent })
	local d = new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromScale(0.68, 0.68),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		Parent = holder,
	}, {
		Theme.corner(math.floor(size * 0.12)),
		Theme.stroke(Theme.darken(color, 0.55), 2),
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.lighten(color, 0.6)),
				ColorSequenceKeypoint.new(0.45, color),
				ColorSequenceKeypoint.new(1, Theme.darken(color, 0.3)),
			}),
			Rotation = -45,
		}),
	})
	new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(0.22, 0.22),
		Position = UDim2.fromScale(0.3, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = d,
	}, { Theme.corner(3) })
	return holder, d
end

function Theme.tween(inst: Instance, time: number, props, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

return Theme
