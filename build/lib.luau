-- Shared helpers for the edit-time world builders (inlined via --#include).
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Terrain = workspace.Terrain

-- Fresh copies of the shared modules (edit-mode require caches stale modules).
local _fresh = RS:FindFirstChild("_SharedFresh")
if _fresh then
	_fresh:Destroy()
end
_fresh = RS.Shared:Clone()
_fresh.Name = "_SharedFresh"
_fresh.Parent = RS
local Shared = _fresh
local Layout = require(Shared.Layout)
local Biomes = require(Shared.Biomes)
local function cleanupFresh()
	_fresh:Destroy()
end

local ShapesFolder = RS.Assets.Shapes
local rgb = Color3.fromRGB
local rad = math.rad

local function folder(name: string, parent: Instance): Folder
	local f = parent:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- P(kind, size, cf, color, material?, parent, opts?) -> BasePart
-- kind: "Block" | "Ball" | "Cylinder" | "Wedge" | "CornerWedge" | a Shapes asset name
local function P(kind: string, size: Vector3, cf: CFrame, color: Color3, mat, parent: Instance, opts)
	opts = opts or {}
	local p: BasePart
	if kind == "Block" or kind == "Ball" or kind == "Cylinder" then
		p = Instance.new("Part")
		p.Shape = Enum.PartType[kind]
	elseif kind == "Wedge" then
		p = Instance.new("WedgePart")
	elseif kind == "CornerWedge" then
		p = Instance.new("CornerWedgePart")
	else
		p = ShapesFolder[kind]:Clone()
	end
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat and (typeof(mat) == "string" and Enum.Material[mat] or mat) or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = opts.collide ~= false
	p.CanQuery = opts.query ~= false and p.CanCollide
	p.CanTouch = opts.touch == true
	p.CastShadow = opts.shadow ~= false
	if opts.alpha then
		p.Transparency = opts.alpha
	end
	if opts.reflect then
		p.Reflectance = opts.reflect
	end
	p.Name = opts.name or kind
	p.Parent = parent
	return p
end

local function deco(kind, size, cf, color, mat, parent, opts)
	opts = opts or {}
	opts.collide = false
	return P(kind, size, cf, color, mat, parent, opts)
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3?, font, opts)
	opts = opts or {}
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = opts.ppu or 40
	g.LightInfluence = opts.light or 0
	g.Brightness = opts.brightness or 1.2
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.LuckiestGuy
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.RichText = true
	local s = Instance.new("UIStroke")
	s.Thickness = opts.stroke or 3
	s.Color = opts.strokeColor or rgb(30, 20, 40)
	s.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = t
	t.Parent = g
	return g, t
end

-- Flat terrain disc whose rendered surface sits at `top`. Built from FillBlock
-- strips: FillCylinder rounds whole voxels up and lands ~2 studs too high, while
-- a FillBlock ending at y renders its surface at y + 2.
local function fillDisc(cx: number, cz: number, r: number, top: number, mat: Enum.Material, depth: number?)
	depth = depth or 8
	for x = -r, r, 2 do
		local h = math.sqrt(math.max(0, r * r - x * x))
		if h > 0.5 then
			Terrain:FillBlock(CFrame.new(cx + x, top - 2 - depth / 2, cz), Vector3.new(2, depth, 2 * h), mat)
		end
	end
end

---------------------------------------------------------------------------
-- Props
---------------------------------------------------------------------------
local Props = {}

function Props.tree(pos: Vector3, h: number, parent: Instance, leaf: Color3?, rng: Random?)
	rng = rng or Random.new()
	local m = Instance.new("Model")
	m.Name = "Tree"
	local trunkH = h * 0.5
	P("Cylinder", Vector3.new(trunkH, h * 0.14, h * 0.14), CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(120, 82, 50), "Wood", m)
	leaf = leaf or rgb(90, 180, 70)
	local top = pos + Vector3.new(0, trunkH, 0)
	for i = 1, 4 do
		local s = h * rng:NextNumber(0.45, 0.62)
		local off = Vector3.new(rng:NextNumber(-0.25, 0.25) * h, rng:NextNumber(0.05, 0.35) * h, rng:NextNumber(-0.25, 0.25) * h)
		P("Ball", Vector3.new(s, s, s), CFrame.new(top + off), leaf:Lerp(rgb(255, 255, 200), rng:NextNumber(0, 0.15)), "Grass", m, { collide = false })
	end
	m.Parent = parent
	return m
end

function Props.pine(pos: Vector3, h: number, parent: Instance, color: Color3?, snow: boolean?)
	local m = Instance.new("Model")
	m.Name = "Pine"
	P("Cylinder", Vector3.new(h * 0.3, h * 0.1, h * 0.1), CFrame.new(pos + Vector3.new(0, h * 0.15, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(100, 70, 45), "Wood", m)
	color = color or rgb(50, 130, 80)
	for i = 0, 2 do
		local w = h * (0.55 - i * 0.13)
		local y = h * (0.3 + i * 0.22)
		P("Cone", Vector3.new(w, h * 0.38, w), CFrame.new(pos + Vector3.new(0, y + h * 0.19, 0)), color, "Grass", m, { collide = i == 0 })
		if snow then
			P("Cone", Vector3.new(w * 0.55, h * 0.18, w * 0.55), CFrame.new(pos + Vector3.new(0, y + h * 0.32, 0)), rgb(250, 252, 255), "Snow", m, { collide = false })
		end
	end
	m.Parent = parent
	return m
end

function Props.rock(pos: Vector3, s: number, parent: Instance, color: Color3?, mat, rng: Random?)
	rng = rng or Random.new()
	local m = Instance.new("Model")
	m.Name = "Rock"
	color = color or rgb(130, 130, 140)
	for i = 1, 3 do
		local sz = Vector3.new(rng:NextNumber(0.7, 1.2), rng:NextNumber(0.5, 0.9), rng:NextNumber(0.7, 1.2)) * s
		local off = Vector3.new(rng:NextNumber(-0.35, 0.35) * s, sz.Y * 0.2, rng:NextNumber(-0.35, 0.35) * s)
		P("Ellipsoid", sz, CFrame.new(pos + off) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)), color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.15)), mat or "Rock", m)
	end
	m.Parent = parent
	return m
end

function Props.cactus(pos: Vector3, h: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Cactus"
	local green = rgb(80, 165, 80)
	local w = h * 0.22
	P("Cylinder", Vector3.new(h, w, w), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, rad(90)), green, "Grass", m)
	P("Ball", Vector3.new(w, w, w), CFrame.new(pos + Vector3.new(0, h, 0)), green, "Grass", m)
	for _, side in ipairs({ -1, 1 }) do
		local ah = h * (side > 0 and 0.32 or 0.42)
		local base = pos + Vector3.new(side * w * 1.1, h * (side > 0 and 0.45 or 0.55), 0)
		P("Cylinder", Vector3.new(w * 1.2, w * 0.7, w * 0.7), CFrame.new(base - Vector3.new(side * w * 0.5, 0, 0)), green, "Grass", m)
		P("Cylinder", Vector3.new(ah, w * 0.7, w * 0.7), CFrame.new(base + Vector3.new(side * w * 0.15, ah / 2, 0)) * CFrame.Angles(0, 0, rad(90)), green, "Grass", m)
		P("Ball", Vector3.new(w * 0.7, w * 0.7, w * 0.7), CFrame.new(base + Vector3.new(side * w * 0.15, ah, 0)), green, "Grass", m)
	end
	P("Ball", Vector3.new(w * 0.6, w * 0.4, w * 0.6), CFrame.new(pos + Vector3.new(0, h + w * 0.45, 0)), rgb(255, 120, 180), nil, m, { collide = false })
	m.Parent = parent
	return m
end

function Props.crystal(pos: Vector3, h: number, parent: Instance, color: Color3, rng: Random?, neon: boolean?)
	rng = rng or Random.new()
	local m = Instance.new("Model")
	m.Name = "Crystal"
	for i = 1, 4 do
		local hh = h * (i == 1 and 1 or rng:NextNumber(0.4, 0.7))
		local w = hh * 0.32
		local tilt = i == 1 and 0 or rng:NextNumber(0.25, 0.6)
		local yaw = rng:NextNumber(0, 6.28)
		local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, tilt) * CFrame.new(0, hh / 2, 0)
		P("Cone", Vector3.new(w, hh, w), cf, color, neon and "Neon" or "Glass", m, { alpha = neon and 0 or 0.15, reflect = 0.1, collide = i == 1 })
	end
	m.Parent = parent
	return m
end

function Props.lamp(pos: Vector3, parent: Instance, color: Color3?)
	local m = Instance.new("Model")
	m.Name = "Lamp"
	P("Cylinder", Vector3.new(10, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(60, 50, 70), "Metal", m)
	local bulb = P("Ball", Vector3.new(1.8, 1.8, 1.8), CFrame.new(pos + Vector3.new(0, 10.6, 0)), color or rgb(255, 230, 160), "Neon", m, { collide = false })
	P("Cone", Vector3.new(2.4, 1, 2.4), CFrame.new(pos + Vector3.new(0, 11.8, 0)), rgb(60, 50, 70), "Metal", m, { collide = false })
	local l = Instance.new("PointLight")
	l.Color = color or rgb(255, 220, 150)
	l.Range = 18
	l.Brightness = 1.2
	l.Parent = bulb
	m.Parent = parent
	return m
end

function Props.flowers(pos: Vector3, parent: Instance, rng: Random)
	local colors = { rgb(255, 120, 160), rgb(255, 230, 90), rgb(170, 130, 255), rgb(255, 255, 255), rgb(255, 150, 70) }
	for _ = 1, 5 do
		local p = pos + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		deco("Cylinder", Vector3.new(1.2, 0.15, 0.15), CFrame.new(p + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(80, 160, 60), "Grass", parent)
		deco("Ball", Vector3.new(0.7, 0.4, 0.7), CFrame.new(p + Vector3.new(0, 1.25, 0)), colors[rng:NextInteger(1, #colors)], nil, parent)
	end
end

function Props.mushroom(pos: Vector3, h: number, parent: Instance, cap: Color3, neon: boolean?)
	local m = Instance.new("Model")
	m.Name = "Mushroom"
	P("Cylinder", Vector3.new(h * 0.7, h * 0.25, h * 0.25), CFrame.new(pos + Vector3.new(0, h * 0.35, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(240, 230, 210), nil, m)
	P("Dome", Vector3.new(h * 0.9, h * 0.45, h * 0.9), CFrame.new(pos + Vector3.new(0, h * 0.7 + h * 0.22, 0)), cap, neon and "Neon" or nil, m)
	m.Parent = parent
	return m
end

-- Arch gate with a sign across the top.
function Props.arch(cf: CFrame, width: number, height: number, color: Color3, parent: Instance, title: string, subtitle: string?, mat)
	local m = Instance.new("Model")
	m.Name = "Arch"
	local pillar = Vector3.new(5, height, 5)
	for _, side in ipairs({ -1, 1 }) do
		P("Block", pillar, cf * CFrame.new(side * (width / 2 + 2.5), height / 2, 0), color, mat or "Cobblestone", m)
		P("Cone", Vector3.new(6.5, 5, 6.5), cf * CFrame.new(side * (width / 2 + 2.5), height + 2.5, 0), color:Lerp(Color3.new(0, 0, 0), 0.25), mat or "Slate", m)
	end
	local beam = P("Block", Vector3.new(width + 10, 7, 3), cf * CFrame.new(0, height - 1, 0), color:Lerp(Color3.new(0, 0, 0), 0.15), mat or "Cobblestone", m)
	local sign = P("Block", Vector3.new(width - 2, 6, 0.6), cf * CFrame.new(0, height - 1, -1.8), rgb(40, 30, 50), "SmoothPlastic", m, { collide = false })
	local text = title
	if subtitle then
		text = title .. '\n<font size="14">' .. subtitle .. "</font>"
	end
	surfaceText(sign, Enum.NormalId.Front, text, Color3.new(1, 1, 1), nil, { ppu = 12 })
	local back = P("Block", Vector3.new(width - 2, 6, 0.6), cf * CFrame.new(0, height - 1, 1.8), rgb(40, 30, 50), "SmoothPlastic", m, { collide = false })
	surfaceText(back, Enum.NormalId.Back, title, Color3.new(1, 1, 1), nil, { ppu = 12 })
	m.Parent = parent
	return m
end

-- Invisible collision wall.
local function wall(size: Vector3, cf: CFrame, parent: Instance)
	local p = P("Block", size, cf, Color3.new(1, 1, 1), nil, parent, { alpha = 1, shadow = false })
	p.Name = "Boundary"
	return p
end
