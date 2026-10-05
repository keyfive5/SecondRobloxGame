-- Builds a chibi dragon Model from a species `look` (see Species.luau) out of the
-- CSG shapes in ReplicatedStorage.Assets.Shapes.
--
-- Rig: an anchored invisible Root at the feet, and Motor6Ds Root->Body,
-- Body->Head, Body->WingL/WingR and Body->Tail so clients can animate idle bobbing
-- and wing flaps by setting Motor6D.Transform. Everything else is welded.
-- Model space: feet on y = 0, facing -Z, about 4 studs tall at scale 1.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent.Parent
local Traits = require(Shared.Traits)
local Effects = require(script.Parent.Effects)

local DragonBuilder = {}

-- Looked up per build so edit-time tools survive the shapes being rebuilt.
local function shapes(): Folder
	return ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Shapes")
end

local rgb = Color3.fromRGB
local rad = math.rad
local WHITE = Color3.new(1, 1, 1)
local BLACK = rgb(22, 20, 28)

DragonBuilder.RainbowTag = "RainbowPart"
DragonBuilder.PrismTag = "PrismPart"

local function quiet(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

local function scaled(cf: CFrame, s: number): CFrame
	return cf - cf.Position + cf.Position * s
end

local Builder = {}
Builder.__index = Builder

local function newBuilder(origin: CFrame, s: number)
	local self = setmetatable({}, Builder)
	self.origin = origin
	self.s = s
	self.model = Instance.new("Model")
	self.groups = {} -- name -> { main = BasePart, members = { BasePart } }
	return self
end

-- shape: "Ball" | "Block" | "Cylinder" | "Wedge" | asset name in Shapes
function Builder:add(group: string, shape: string, size: Vector3, cf: CFrame, color: Color3, opts)
	opts = opts or {}
	local p: BasePart
	if shape == "Ball" or shape == "Block" or shape == "Cylinder" then
		p = Instance.new("Part")
		p.Shape = Enum.PartType[shape]
	elseif shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		p = shapes()[shape]:Clone()
	end
	quiet(p)
	p.Size = size * self.s
	p.CFrame = self.origin * scaled(cf, self.s)
	p.Color = color
	p.Material = opts.material and Enum.Material[opts.material] or Enum.Material.SmoothPlastic
	p.Transparency = opts.alpha or 0
	p.Reflectance = opts.reflect or 0
	p.Name = opts.name or shape
	if opts.role then
		p:SetAttribute("Role", opts.role)
	end
	if opts.noShadow then
		p.CastShadow = false
	end
	p.Parent = self.model
	local g = self.groups[group]
	if not g then
		g = { members = {} }
		self.groups[group] = g
	end
	if opts.main then
		g.main = p
	else
		table.insert(g.members, p)
	end
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = a.CFrame:ToObjectSpace(b.CFrame)
	w.Parent = b
end

local function motor(name: string, a: BasePart, b: BasePart, joint: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = a
	m.Part1 = b
	m.C0 = a.CFrame:ToObjectSpace(joint)
	m.C1 = b.CFrame:ToObjectSpace(joint)
	m.Parent = a
	return m
end

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function eye(b, side: number, look, angry: boolean)
	local x = 0.47 * side
	local cf = CFrame.new(x, 2.9, -1.31) * CFrame.Angles(angry and rad(-6) or 0, rad(-17) * side, 0)
	local white = angry and rgb(255, 245, 200) or WHITE
	b:add("Head", "Ellipsoid", Vector3.new(0.62, angry and 0.6 or 0.8, 0.28), cf, white, { role = "eyeWhite" })
	local irisColor = look.eye or BLACK
	local glow = look.glowEyes or angry
	b:add("Head", "Ellipsoid", Vector3.new(0.46, angry and 0.46 or 0.62, 0.2), cf * CFrame.new(0, -0.03, -0.07), irisColor, {
		role = "iris", material = glow and "Neon" or nil,
	})
	if not glow then
		b:add("Head", "Ellipsoid", Vector3.new(0.28, 0.42, 0.18), cf * CFrame.new(0, -0.04, -0.12), BLACK, { role = "pupil" })
		b:add("Head", "Ball", Vector3.new(0.17, 0.17, 0.17), cf * CFrame.new(-0.08 * side, 0.13, -0.19), WHITE, { material = "Neon", role = "shine", noShadow = true })
		b:add("Head", "Ball", Vector3.new(0.08, 0.08, 0.08), cf * CFrame.new(0.08 * side, -0.14, -0.18), WHITE, { material = "Neon", role = "shine", noShadow = true })
	else
		b:add("Head", "Ellipsoid", Vector3.new(0.12, angry and 0.36 or 0.44, 0.16), cf * CFrame.new(0, -0.02, -0.12), BLACK, { role = "pupil" })
	end
	if angry then
		-- slanted brow
		b:add("Head", "Block", Vector3.new(0.75, 0.16, 0.2), cf * CFrame.new(0.02 * side, 0.4, -0.08) * CFrame.Angles(0, 0, rad(-24) * side), rgb(40, 30, 30), { role = "brow" })
	end
end

local function horn(b, kind: string, look)
	local c = look.accent
	if kind == "none" then
		return
	end
	for _, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(0.55 * side, 3.5, -0.25)
		if kind == "nub" then
			b:add("Head", "Cone", Vector3.new(0.32, 0.45, 0.32), base * CFrame.Angles(rad(20), 0, rad(-14) * side), c, { role = "accent" })
		elseif kind == "curved" then
			b:add("Head", "Cone", Vector3.new(0.34, 0.7, 0.34), base * CFrame.Angles(rad(25), 0, rad(-16) * side) * CFrame.new(0, 0.12, 0), c, { role = "accent" })
			b:add("Head", "Cone", Vector3.new(0.22, 0.5, 0.22), base * CFrame.Angles(rad(25), 0, rad(-16) * side) * CFrame.new(0, 0.5, 0.05) * CFrame.Angles(rad(40), 0, 0) * CFrame.new(0, 0.18, 0), c, { role = "accent" })
		elseif kind == "long" then
			b:add("Head", "Cone", Vector3.new(0.36, 1.25, 0.36), base * CFrame.Angles(rad(48), 0, rad(-12) * side) * CFrame.new(0, 0.42, 0), c, { role = "accent" })
		elseif kind == "bolt" then
			local o = base * CFrame.Angles(rad(15), 0, rad(-18) * side)
			b:add("Head", "Block", Vector3.new(0.16, 0.5, 0.16), o * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, rad(25) * side), c, { role = "accent", material = "Neon" })
			b:add("Head", "Block", Vector3.new(0.16, 0.5, 0.16), o * CFrame.new(0.12 * side, 0.55, 0) * CFrame.Angles(0, 0, rad(-25) * side), c, { role = "accent", material = "Neon" })
			b:add("Head", "Cone", Vector3.new(0.2, 0.4, 0.2), o * CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, rad(20) * side), c, { role = "accent", material = "Neon" })
		elseif kind == "crystal" then
			b:add("Head", "Cone", Vector3.new(0.34, 0.95, 0.34), base * CFrame.Angles(rad(22), 0, rad(-14) * side) * CFrame.new(0, 0.3, 0), c, { role = "accent", material = "Glass", alpha = 0.15 })
			b:add("Head", "Cone", Vector3.new(0.22, 0.55, 0.22), base * CFrame.new(0.22 * side, -0.05, 0.15) * CFrame.Angles(rad(35), 0, rad(-40) * side) * CFrame.new(0, 0.2, 0), c, { role = "accent", material = "Glass", alpha = 0.15 })
		end
	end
	if kind == "unihorn" then
		local cf = CFrame.new(0, 3.62, -0.95) * CFrame.Angles(rad(-22), 0, 0) * CFrame.new(0, 0.55, 0)
		b:add("Head", "Cone", Vector3.new(0.34, 1.3, 0.34), cf, c, { role = "accent", material = "Foil", reflect = 0.1 })
		for i = 1, 3 do
			b:add("Head", "Ring", Vector3.new(0.06, 0.34 - i * 0.07, 0.34 - i * 0.07), cf * CFrame.new(0, -0.55 + i * 0.28, 0) * CFrame.Angles(rad(8), 0, rad(90)), Color3.new(1, 0.95, 0.75), { role = "accent", material = "Neon" })
		end
	end
end

local function wing(b, side: number, look)
	local joint = CFrame.new(0.5 * side, 2.0, 0.62)
	local raise = rad(24)
	local sweep = rad(38)
	-- the Wing shape is 3 x 2 at size 1; it's used at 2.0 x 1.35, so asset point
	-- (x, y) lands at (x * SX, y * SY). Root edge sits at the shoulder joint.
	local SX, SY = 2.0 / 3, 1.35 / 2
	local cf = joint * CFrame.Angles(0, sweep * side, raise * side) * CFrame.new(1.0 * side, 0.15, 0)
	if side < 0 then
		cf *= CFrame.Angles(0, math.pi, 0)
	end
	local group = side > 0 and "WingR" or "WingL"
	local mat = look.wingNeon and "Neon" or nil
	local w = b:add(group, "Wing", Vector3.new(2.0, 1.35, 0.12), cf, look.wing, {
		main = true, role = look.rainbowWings and "rainbow" or "wing", material = mat, alpha = look.wingAlpha,
	})
	w.Name = group
	if look.rainbowWings then
		CollectionService:AddTag(w, DragonBuilder.RainbowTag)
	end
	-- bones: leading edge, plus two fingers from the wrist to the scallop cusps
	local function bone(a: Vector2, c: Vector2, thick: number)
		a = Vector2.new(a.X * SX, a.Y * SY)
		c = Vector2.new(c.X * SX, c.Y * SY)
		local d = c - a
		local mid = (a + c) / 2
		b:add(group, "Cylinder", Vector3.new(d.Magnitude, thick, thick), cf * CFrame.new(mid.X, mid.Y, 0) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), look.accent, { role = "accent" })
	end
	local wrist = Vector2.new(-0.45, 0.68)
	bone(Vector2.new(-1.5, 0.5), Vector2.new(1.5, 1.0), 0.15)
	bone(wrist, Vector2.new(-0.45, -0.3), 0.08)
	bone(wrist, Vector2.new(0.36, 0.24), 0.08)
	b:add(group, "Cone", Vector3.new(0.18, 0.32, 0.18), cf * CFrame.new(wrist.X * SX, wrist.Y * SY + 0.12, 0), look.accent, { role = "accent" })
	return joint
end

local function cone(b, group, size, cf, color, opts)
	return b:add(group, "Cone", size, cf, color, opts)
end

---------------------------------------------------------------------------
-- Accessories
---------------------------------------------------------------------------
local Extras = {}

Extras.leaf = function(b, look)
	local stem = CFrame.new(0, 3.62, -0.5)
	b:add("Head", "Cylinder", Vector3.new(0.45, 0.1, 0.1), stem * CFrame.Angles(0, 0, rad(90)), rgb(90, 150, 60))
	b:add("Head", "Ellipsoid", Vector3.new(0.75, 0.08, 0.38), stem * CFrame.new(0.3, 0.25, 0) * CFrame.Angles(0, 0, rad(30)), rgb(110, 210, 80))
	b:add("Head", "Ellipsoid", Vector3.new(0.6, 0.08, 0.32), stem * CFrame.new(-0.25, 0.2, 0) * CFrame.Angles(0, 0, rad(-30)), rgb(130, 225, 90))
end

Extras.clover = function(b, look)
	local c = CFrame.new(0.55, 3.55, -0.6) * CFrame.Angles(rad(-15), 0, rad(-20))
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		b:add("Head", "Ellipsoid", Vector3.new(0.34, 0.06, 0.34), c * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.18), rgb(70, 190, 80))
	end
	b:add("Head", "Ball", Vector3.new(0.12, 0.12, 0.12), c * CFrame.new(0, 0.03, 0), rgb(255, 240, 120))
end

Extras.bee = function(b, look)
	for _, y in ipairs({ 0.75, 1.3 }) do
		b:add("Body", "Ellipsoid", Vector3.new(2.14, 0.24, 2.34), CFrame.new(0, y, 0.2), look.accent, { role = "accent" })
	end
	b:add("Tail", "Ellipsoid", Vector3.new(0.84, 0.2, 0.94), CFrame.new(0, 0.55, 1.35) * CFrame.Angles(rad(90), 0, 0), look.accent, { role = "accent" })
	for _, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(0.32 * side, 3.6, -0.6)
		b:add("Head", "Cylinder", Vector3.new(0.7, 0.07, 0.07), base * CFrame.Angles(0, 0, rad(70 * side + (side < 0 and 180 or 0))) * CFrame.new(0.3, 0, 0), look.accent)
		b:add("Head", "Ball", Vector3.new(0.22, 0.22, 0.22), base * CFrame.new(0.28 * side, 0.62, 0), look.accent)
	end
end

Extras.flower = function(b, look)
	local c = CFrame.new(-0.55, 3.55, -0.55) * CFrame.Angles(rad(-20), 0, rad(22))
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		b:add("Head", "Ellipsoid", Vector3.new(0.34, 0.08, 0.5), c * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.25), rgb(255, 255, 255))
	end
	b:add("Head", "Ball", Vector3.new(0.25, 0.25, 0.25), c * CFrame.new(0, 0.05, 0), rgb(255, 210, 60))
end

Extras.mane = function(b, look)
	local colors = { rgb(255, 150, 200), rgb(170, 150, 255), rgb(120, 220, 255), rgb(140, 240, 170), rgb(255, 230, 120) }
	for i, col in ipairs(colors) do
		local t = (i - 1) / (#colors - 1)
		b:add("Head", "Ellipsoid", Vector3.new(0.4, 0.5, 0.55), CFrame.new(0, 3.55 - t * 1.0, 0.1 + t * 0.55), col, { material = "SmoothPlastic" })
	end
end

Extras.cactus = function(b, look)
	local rng = Random.new(7)
	for _ = 1, 16 do
		local a = rng:NextNumber(-math.pi * 0.85, math.pi * 0.85)
		local y = rng:NextNumber(0.6, 1.9)
		local dir = Vector3.new(math.sin(a), (y - 1.2) * 0.6, math.cos(a)).Unit
		local pos = Vector3.new(0, 1.2, 0.2) + dir * Vector3.new(1.05, 1.0, 1.15)
		b:add("Body", "Cone", Vector3.new(0.1, 0.28, 0.1), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(rad(-90), 0, 0), look.accent, { role = "accent" })
	end
	-- flower on head
	local c = CFrame.new(0, 3.62, -0.45)
	for i = 0, 4 do
		b:add("Head", "Ellipsoid", Vector3.new(0.26, 0.08, 0.4), c * CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.new(0, 0, -0.2), rgb(255, 120, 190))
	end
	b:add("Head", "Ball", Vector3.new(0.2, 0.2, 0.2), c * CFrame.new(0, 0.05, 0), rgb(255, 230, 90))
end

Extras.gem = function(b, look)
	b:add("Head", "Cone", Vector3.new(0.34, 0.34, 0.2), CFrame.new(0, 3.35, -1.32) * CFrame.Angles(rad(-70), 0, 0), rgb(255, 60, 90), { material = "Glass", reflect = 0.2 })
end

Extras.bandage = function(b, look)
	local rng = Random.new(3)
	for i = 1, 5 do
		local y = 0.45 + i * 0.32
		b:add("Body", "Ellipsoid", Vector3.new(2.16, 0.12, 2.36), CFrame.new(0, y, 0.2) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.2, 0.2)), rgb(200, 190, 160), { role = "accent" })
	end
	for i = 1, 2 do
		b:add("Head", "Ellipsoid", Vector3.new(2.14, 0.14, 1.94), CFrame.new(0, 2.3 + i * 0.85, -0.55) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.25, 0.25)), rgb(200, 190, 160), { role = "accent" })
	end
end

Extras.nemes = function(b, look)
	local gold, blue = rgb(255, 200, 50), look.accent
	for i = 0, 6 do
		local col = i % 2 == 0 and blue or gold
		b:add("Head", "Ellipsoid", Vector3.new(2.25 - i * 0.02, 0.2, 2.0), CFrame.new(0, 3.45 - i * 0.2, -0.45) * CFrame.Angles(rad(-8), 0, 0), col, { role = "accent", material = i % 2 == 0 and "SmoothPlastic" or "Foil" })
	end
	-- lappets hanging behind the head
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 3 do
			local col = i % 2 == 0 and blue or gold
			b:add("Head", "Block", Vector3.new(0.4, 0.22, 0.5), CFrame.new(0.85 * side, 2.55 - i * 0.22, 0.1), col, { role = "accent" })
		end
	end
	b:add("Head", "Cone", Vector3.new(0.3, 0.45, 0.2), CFrame.new(0, 3.8, -1.25) * CFrame.Angles(rad(-15), 0, 0), gold, { material = "Foil" })
end

Extras.collar = function(b, look)
	b:add("Body", "Ellipsoid", Vector3.new(1.9, 0.3, 1.9), CFrame.new(0, 2.05, -0.15), rgb(255, 200, 50), { material = "Foil" })
	b:add("Body", "Ellipsoid", Vector3.new(1.7, 0.26, 1.7), CFrame.new(0, 1.85, -0.15), rgb(40, 80, 190))
end

Extras.earmuffs = function(b, look)
	b:add("Head", "Cylinder", Vector3.new(0.12, 0.14, 0.14), CFrame.new(0, 3.72, -0.55) * CFrame.Angles(0, 0, 0), rgb(255, 90, 110))
	local band = CFrame.new(0, 3.55, -0.5)
	b:add("Head", "Ellipsoid", Vector3.new(2.3, 0.6, 0.16), band, rgb(255, 90, 110))
	for _, side in ipairs({ -1, 1 }) do
		b:add("Head", "Ball", Vector3.new(0.65, 0.65, 0.65), CFrame.new(1.05 * side, 2.9, -0.5), rgb(255, 255, 255), { material = "Fabric" })
	end
end

Extras.scarf = function(b, look)
	b:add("Body", "Ellipsoid", Vector3.new(1.95, 0.42, 1.95), CFrame.new(0, 2.02, -0.2), rgb(230, 50, 60), { material = "Fabric" })
	b:add("Body", "Block", Vector3.new(0.4, 0.8, 0.12), CFrame.new(0.55, 1.6, -1.15) * CFrame.Angles(rad(-10), 0, rad(-12)), rgb(230, 50, 60), { material = "Fabric" })
	b:add("Body", "Block", Vector3.new(0.42, 0.1, 0.13), CFrame.new(0.6, 1.25, -1.2) * CFrame.Angles(rad(-10), 0, rad(-12)), rgb(255, 240, 240), { material = "Fabric" })
end

Extras.icecrystals = function(b, look)
	local spots = { { 0.4, 2.0, 0.6, 20 }, { -0.45, 1.9, 0.75, -25 }, { 0, 2.15, 0.4, 0 }, { 0.15, 1.6, 1.2, 10 } }
	for _, s in ipairs(spots) do
		b:add("Body", "Cone", Vector3.new(0.3, 0.75, 0.3), CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(rad(30), 0, rad(-s[4])), rgb(200, 240, 255), { material = "Glass", alpha = 0.2, reflect = 0.15 })
	end
end

Extras.fluffy = function(b, look)
	local rng = Random.new(11)
	for _ = 1, 12 do
		local a = rng:NextNumber(-math.pi, math.pi)
		local y = rng:NextNumber(0.5, 1.9)
		local pos = Vector3.new(math.sin(a) * 1.0, y, 0.2 + math.cos(a) * 1.08)
		b:add("Body", "Ball", Vector3.new(0.55, 0.55, 0.55), CFrame.new(pos), look.body, { role = "skin", material = "Fabric" })
	end
	for _ = 1, 5 do
		local a = rng:NextNumber(-math.pi * 0.6, math.pi * 0.6)
		b:add("Head", "Ball", Vector3.new(0.5, 0.5, 0.5), CFrame.new(math.sin(a) * 0.85, 3.45, -0.45 + math.cos(a) * 0.5), look.body, { role = "skin", material = "Fabric" })
	end
end

Extras.auroraTrail = function(b, look)
	local cols = { rgb(110, 255, 200), rgb(110, 200, 255), rgb(190, 130, 255) }
	for i, col in ipairs(cols) do
		b:add("Tail", "Ellipsoid", Vector3.new(0.1, 0.5, 1.2), CFrame.new(-0.3 + i * 0.15, 1.3 + i * 0.12, 2.9) * CFrame.Angles(rad(-30), 0, 0), col, { material = "Neon", alpha = 0.25, noShadow = true })
	end
end

Extras.lavaspots = function(b, look)
	local rng = Random.new(5)
	for _ = 1, 9 do
		local a = rng:NextNumber(-math.pi * 0.9, math.pi * 0.9)
		local y = rng:NextNumber(0.6, 1.9)
		local pos = Vector3.new(math.sin(a) * 1.0, y, 0.2 + math.cos(a) * 1.1)
		b:add("Body", "Ellipsoid", Vector3.new(0.38, 0.3, 0.38), CFrame.lookAt(pos, pos * 2 - Vector3.new(0, pos.Y, 0)), rgb(255, 120, 30), { material = "Neon", role = "glow" })
	end
end

Extras.crystals = function(b, look)
	local spots = { { 0, 2.15, 0.45, 0, 0.9 }, { 0.5, 1.95, 0.75, 25, 0.6 }, { -0.5, 1.95, 0.75, -25, 0.6 }, { 0, 1.75, 1.15, 0, 0.7 } }
	for _, s in ipairs(spots) do
		b:add("Body", "Cone", Vector3.new(0.34, s[5], 0.34), CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(rad(28), 0, rad(-s[4])) * CFrame.new(0, s[5] * 0.3, 0), look.accent, { material = "Glass", alpha = 0.15, role = "accent" })
	end
end

Extras.crest = function(b, look)
	local cols = { rgb(255, 60, 30), rgb(255, 140, 30), rgb(255, 220, 60) }
	for i, col in ipairs(cols) do
		b:add("Head", "Ellipsoid", Vector3.new(0.2, 1.0 - i * 0.12, 0.45), CFrame.new((i - 2) * 0.22, 3.75, -0.35 + i * 0.1) * CFrame.Angles(rad(-35 + i * 5), 0, rad((i - 2) * -18)), col, { material = "Neon" })
	end
end

Extras.crown = function(b, look)
	local base = CFrame.new(0, 3.7, -0.55)
	b:add("Head", "Cylinder", Vector3.new(0.32, 1.15, 1.15), base * CFrame.Angles(0, 0, rad(90)), rgb(255, 200, 40), { material = "Foil", reflect = 0.15 })
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		b:add("Head", "Cone", Vector3.new(0.28, 0.42, 0.28), base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.32, -0.46), rgb(255, 200, 40), { material = "Foil" })
		b:add("Head", "Ball", Vector3.new(0.14, 0.14, 0.14), base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.0, -0.58), i % 2 == 0 and rgb(255, 50, 80) or rgb(60, 160, 255), { material = "Neon" })
	end
end

Extras.cloudpuffs = function(b, look)
	local spots = { { -1.0, 0.45, 0.3, 0.9 }, { 1.0, 0.45, 0.4, 0.85 }, { 0, 0.35, 1.2, 1.0 }, { -0.6, 0.3, -0.7, 0.7 }, { 0.65, 0.3, -0.75, 0.7 } }
	for _, s in ipairs(spots) do
		b:add("Body", "Ball", Vector3.new(s[4], s[4], s[4]), CFrame.new(s[1], s[2], s[3]), rgb(255, 255, 255), { material = "SmoothPlastic", alpha = 0.05 })
	end
end

Extras.stormcloud = function(b, look)
	local base = CFrame.new(0, 4.45, -0.5)
	for _, s in ipairs({ { -0.45, 0, 0.6 }, { 0.1, 0.12, 0.75 }, { 0.55, -0.02, 0.55 }, { 0, -0.08, 0.6 } }) do
		b:add("Head", "Ball", Vector3.new(s[3], s[3], s[3]), base * CFrame.new(s[1], s[2], 0), rgb(90, 90, 120))
	end
	b:add("Head", "Block", Vector3.new(0.1, 0.45, 0.1), base * CFrame.new(0.1, -0.45, 0) * CFrame.Angles(0, 0, rad(25)), rgb(255, 245, 120), { material = "Neon" })
end

Extras.spikesRed = function(b, look)
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			b:add("Body", "Cone", Vector3.new(0.22, 0.45, 0.22), CFrame.new(0.95 * side, 1.5 - i * 0.3, 0.1 + i * 0.3) * CFrame.Angles(0, 0, rad(-80) * side), look.accent, { material = "Neon", role = "glow" })
		end
	end
end

Extras.starTip = function(b, look)
	b:add("Tail", "Ball", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 1.45, 2.78), rgb(255, 230, 90), { material = "Neon" })
end

Extras.orbit = function(b, look)
	b:add("Body", "Ring", Vector3.new(0.08, 3.4, 3.4), CFrame.new(0, 1.6, 0.2) * CFrame.Angles(rad(15), 0, rad(90)), look.accent, { material = "Neon", noShadow = true, alpha = 0.1 })
	b:add("Body", "Ball", Vector3.new(0.3, 0.3, 0.3), CFrame.new(1.65, 1.75, 0.0), rgb(255, 240, 160), { material = "Neon" })
end

Extras.pepperoni = function(b, look)
	local rng = Random.new(9)
	for _ = 1, 8 do
		local a = rng:NextNumber(-math.pi * 0.9, math.pi * 0.9)
		local y = rng:NextNumber(0.7, 1.9)
		local pos = Vector3.new(math.sin(a) * 1.02, y, 0.2 + math.cos(a) * 1.12)
		b:add("Body", "Cylinder", Vector3.new(0.06, 0.45, 0.45), CFrame.lookAt(pos, pos * 2 - Vector3.new(0, pos.Y, 0)) * CFrame.Angles(0, rad(90), 0), rgb(190, 40, 30))
	end
	-- crust ridge along the back
	b:add("Body", "Ellipsoid", Vector3.new(0.5, 0.45, 2.1), CFrame.new(0, 2.05, 0.45) * CFrame.Angles(rad(-25), 0, 0), rgb(200, 130, 50))
end

Extras.chefhat = function(b, look)
	b:add("Head", "Cylinder", Vector3.new(0.5, 1.15, 1.15), CFrame.new(0, 3.75, -0.55) * CFrame.Angles(0, 0, rad(90)), rgb(250, 250, 250))
	for _, s in ipairs({ { 0, 4.3, -0.55, 1.1 }, { -0.35, 4.2, -0.4, 0.8 }, { 0.35, 4.2, -0.4, 0.8 } }) do
		b:add("Head", "Ball", Vector3.new(s[4], s[4], s[4]), CFrame.new(s[1], s[2], s[3]), rgb(255, 255, 255))
	end
end

Extras.sunglasses = function(b, look)
	local cf = CFrame.new(0, 2.95, -1.47)
	b:add("Head", "Block", Vector3.new(1.55, 0.12, 0.1), cf * CFrame.new(0, 0.18, 0), BLACK)
	for _, side in ipairs({ -1, 1 }) do
		b:add("Head", "Block", Vector3.new(0.62, 0.42, 0.1), cf * CFrame.new(0.42 * side, 0, 0.02) * CFrame.Angles(0, rad(-12) * side, 0), BLACK, { reflect = 0.3 })
	end
end

Extras.discoball = function(b, look)
	b:add("Body", "Ball", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 1.55, -1.15), rgb(220, 220, 230), { material = "Foil", reflect = 0.5 })
	b:add("Body", "Ellipsoid", Vector3.new(1.85, 0.18, 1.85), CFrame.new(0, 2.0, -0.2), rgb(255, 215, 60), { material = "Foil" })
end

Extras.voidhalo = function(b, look)
	b:add("Head", "Ring", Vector3.new(0.12, 1.5, 1.5), CFrame.new(0, 4.25, -0.4) * CFrame.Angles(rad(80), 0, 0) * CFrame.Angles(0, 0, rad(90)), rgb(255, 255, 255), { material = "Neon", noShadow = true })
	b:add("Head", "Ball", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 4.25, -0.4), rgb(5, 5, 8), { material = "Neon" })
end

Extras.cape = function(b, look)
	b:add("Body", "Wedge", Vector3.new(2.0, 2.0, 0.12), CFrame.new(0, 1.15, 1.45) * CFrame.Angles(rad(-12), 0, 0) * CFrame.Angles(0, math.pi, 0), rgb(200, 30, 50), { material = "Fabric" })
	b:add("Body", "Ellipsoid", Vector3.new(2.0, 0.3, 1.6), CFrame.new(0, 2.05, 0.1), rgb(250, 250, 250), { material = "Fabric" })
end

---------------------------------------------------------------------------
-- Mutations recolor the dragon's skin after it's built.
---------------------------------------------------------------------------
local function applyMutation(model: Model, mut: string?)
	if not mut then
		return
	end
	local m = Traits.mutation(mut)
	if not m then
		return
	end
	for _, p in ipairs(model:GetDescendants()) do
		if not p:IsA("BasePart") then
			continue
		end
		local role = p:GetAttribute("Role")
		local skin = role == "skin" or role == "belly" or role == "wing" or role == "rainbow"
		if mut == "gold" then
			if skin or role == "accent" then
				p.Color = role == "belly" and rgb(255, 230, 120) or (role == "accent" and rgb(255, 245, 200) or rgb(255, 196, 40))
				p.Material = Enum.Material.Foil
				p.Reflectance = 0.08
				p.Transparency = 0
			end
		elseif mut == "diamond" then
			if skin then
				p.Color = role == "belly" and rgb(230, 250, 255) or rgb(160, 225, 255)
				p.Material = Enum.Material.Glass
				p.Reflectance = 0.25
				p.Transparency = role == "wing" and 0.3 or 0.05
			elseif role == "accent" then
				p.Color = rgb(255, 255, 255)
				p.Material = Enum.Material.Glass
			end
		elseif mut == "rainbow" then
			if skin then
				CollectionService:AddTag(p, DragonBuilder.RainbowTag)
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = 0
			end
		elseif mut == "lava" then
			if role == "skin" or role == "wing" then
				p.Color = rgb(45, 30, 30)
				p.Material = Enum.Material.Basalt
				p.Transparency = 0
			elseif role == "belly" or role == "accent" then
				p.Color = rgb(255, 110, 20)
				p.Material = Enum.Material.Neon
			end
		elseif mut == "frozen" then
			if skin then
				p.Color = role == "belly" and rgb(240, 250, 255) or rgb(175, 225, 255)
				p.Material = Enum.Material.Ice
				p.Transparency = 0
			end
		elseif mut == "blood" then
			if skin then
				p.Color = role == "belly" and rgb(120, 10, 20) or rgb(70, 8, 14)
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = 0
			elseif role == "accent" then
				p.Color = rgb(255, 30, 50)
				p.Material = Enum.Material.Neon
			elseif role == "iris" then
				p.Color = rgb(255, 30, 40)
				p.Material = Enum.Material.Neon
			end
		elseif mut == "galaxy" then
			if skin then
				p.Color = role == "belly" and rgb(120, 80, 230) or rgb(40, 20, 90)
				p.Material = Enum.Material.Neon
				p.Transparency = role == "wing" and 0.15 or 0
			elseif role == "accent" then
				p.Color = rgb(140, 230, 255)
				p.Material = Enum.Material.Neon
			end
		end
	end
	local body = model:FindFirstChild("Body")
	if body then
		Effects.mutationFx(body, mut, model:GetAttribute("Scale") or 1)
	end
end
DragonBuilder.applyMutation = applyMutation

---------------------------------------------------------------------------
-- Main entry
---------------------------------------------------------------------------
-- opts: { scale, mutation, angry (guardian face), anchored (default true), fx (default true) }
function DragonBuilder.build(look, origin: CFrame, opts)
	opts = opts or {}
	local s = opts.scale or 1
	local b = newBuilder(origin, s)
	local model = b.model
	model.Name = "Dragon"
	model:SetAttribute("Scale", s)
	local angry = opts.angry

	local skinMat = look.bodyMat
	local skinAlpha = look.ghost and 0.45 or 0
	local skinOpts = function(main, name)
		return { main = main, name = name, role = "skin", material = skinMat or (look.ghost and "Glass" or nil), alpha = skinAlpha, reflect = skinMat == "Glass" and 0.1 or 0 }
	end

	-- Root
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1) * s
	root.CFrame = origin
	root.Transparency = 1
	root.Anchored = opts.anchored ~= false
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root

	-- Body
	local body = b:add("Body", "Ellipsoid", Vector3.new(2.1, 2.0, 2.3), CFrame.new(0, 1.2, 0.2), look.body, skinOpts(true, "Body"))
	b:add("Body", "Ellipsoid", Vector3.new(1.55, 1.5, 0.7), CFrame.new(0, 1.08, -0.72) * CFrame.Angles(rad(8), 0, 0), look.belly, {
		role = "belly", material = look.glowBelly and "Neon" or nil,
	})
	-- belly scale lines
	for i = 1, 3 do
		b:add("Body", "Ellipsoid", Vector3.new(1.2 - i * 0.12, 0.05, 0.2), CFrame.new(0, 0.62 + i * 0.3, -1.04 + i * 0.015), look.belly:Lerp(BLACK, 0.18), { role = "detail" })
	end
	-- feet
	for _, side in ipairs({ -1, 1 }) do
		local foot = CFrame.new(0.62 * side, 0.24, 0.05)
		b:add("Body", "Ellipsoid", Vector3.new(0.72, 0.48, 0.98), foot, look.body, skinOpts(false))
		for t = -1, 1 do
			b:add("Body", "Ball", Vector3.new(0.18, 0.18, 0.18), foot * CFrame.new(t * 0.2, -0.05, -0.47), angry and BLACK or WHITE, { role = "claw" })
		end
		-- arms
		b:add("Body", "Ellipsoid", Vector3.new(0.48, 0.72, 0.5), CFrame.new(0.72 * side, 0.92, -0.72) * CFrame.Angles(rad(-30), 0, rad(18) * side), look.body, skinOpts(false))
	end
	-- back spikes
	if not (look.extras and table.find(look.extras, "cactus")) then
		local spikes = { { 2.18, 0.5, 0.34, 0.44 }, { 1.95, 1.0, 0.3, 0.38 }, { 1.55, 1.35, 0.26, 0.32 } }
		for _, sp in ipairs(spikes) do
			cone(b, "Body", Vector3.new(sp[3], sp[4], sp[3]), CFrame.new(0, sp[1], sp[2]) * CFrame.Angles(rad(40), 0, 0), look.accent, { role = "accent" })
		end
	end

	-- Head
	local neck = CFrame.new(0, 2.05, -0.35)
	local head = b:add("Head", "Ellipsoid", Vector3.new(2.1, 1.9, 1.9), CFrame.new(0, 2.75, -0.55), look.body, skinOpts(true, "Head"))
	b:add("Head", "Ellipsoid", Vector3.new(1.25, 0.8, 1.0), CFrame.new(0, 2.36, -1.42), look.body, skinOpts(false))
	-- muzzle highlight + nostrils + smile
	b:add("Head", "Ellipsoid", Vector3.new(0.95, 0.42, 0.6), CFrame.new(0, 2.22, -1.62), look.belly, { role = "belly" })
	for _, side in ipairs({ -1, 1 }) do
		b:add("Head", "Ball", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0.2 * side, 2.55, -1.88), BLACK, { role = "detail" })
	end
	if angry then
		-- fangs
		for _, side in ipairs({ -1, 1 }) do
			cone(b, "Head", Vector3.new(0.14, 0.26, 0.14), CFrame.new(0.28 * side, 2.04, -1.78) * CFrame.Angles(rad(180), 0, 0), WHITE, { role = "claw" })
		end
	else
		-- blush
		for _, side in ipairs({ -1, 1 }) do
			b:add("Head", "Ellipsoid", Vector3.new(0.42, 0.2, 0.1), CFrame.new(0.78 * side, 2.52, -1.18) * CFrame.Angles(0, rad(-42) * side, 0), rgb(255, 130, 160), { alpha = 0.35, role = "blush", noShadow = true })
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		eye(b, side, look, angry)
		-- ear frills
		b:add("Head", "Wing", Vector3.new(0.9, 0.62, 0.08), CFrame.new(1.0 * side, 3.05, -0.15) * CFrame.Angles(0, rad(65) * side, rad(-25) * side) * CFrame.new(0.3 * side, 0, 0) * (side < 0 and CFrame.Angles(0, math.pi, 0) or CFrame.identity), look.wing, { role = "wing", alpha = look.wingAlpha, material = look.wingNeon and "Neon" or nil })
	end
	horn(b, look.horn or "nub", look)

	-- Wings
	local jointR = wing(b, 1, look)
	local jointL = wing(b, -1, look)

	-- Tail
	local tailBase = CFrame.new(0, 0.62, 1.1)
	local tail = b:add("Tail", "Ellipsoid", Vector3.new(0.82, 0.8, 0.95), CFrame.new(0, 0.55, 1.38) * CFrame.Angles(rad(-10), 0, 0), look.body, skinOpts(true, "Tail"))
	b:add("Tail", "Ellipsoid", Vector3.new(0.62, 0.62, 0.78), CFrame.new(0, 0.66, 1.98) * CFrame.Angles(rad(-25), 0, 0), look.body, skinOpts(false))
	b:add("Tail", "Ellipsoid", Vector3.new(0.46, 0.46, 0.62), CFrame.new(0, 0.92, 2.42) * CFrame.Angles(rad(-45), 0, 0), look.body, skinOpts(false))
	local tip = cone(b, "Tail", Vector3.new(0.62, 0.7, 0.16), CFrame.new(0, 1.3, 2.62) * CFrame.Angles(rad(-35), 0, 0), look.accent, { role = "accent", name = "TailTip" })

	for _, name in ipairs(look.extras or {}) do
		local fn = Extras[name]
		if fn then
			fn(b, look)
		end
	end

	-- Weld every group member to its group's main part, then rig the groups.
	for name, g in pairs(b.groups) do
		local main = g.main
		if not main then
			main = body
		end
		for _, p in ipairs(g.members) do
			weld(main, p)
		end
	end
	motor("Body", root, body, origin * scaled(CFrame.new(0, 0.2, 0.2), s))
	motor("Head", body, head, origin * scaled(neck, s))
	motor("Tail", body, tail, origin * scaled(tailBase, s))
	local wr, wl = b.groups.WingR.main, b.groups.WingL.main
	motor("WingR", body, wr, origin * scaled(jointR, s))
	motor("WingL", body, wl, origin * scaled(jointL, s))

	if look.prism then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and (p:GetAttribute("Role") == "skin" or p:GetAttribute("Role") == "belly" or p:GetAttribute("Role") == "wing") then
				CollectionService:AddTag(p, DragonBuilder.PrismTag)
			end
		end
	end
	if opts.fx ~= false and look.fx then
		Effects.speciesFx(body, tip, look.fx, s)
	end
	applyMutation(model, opts.mutation)
	return model
end

return DragonBuilder
