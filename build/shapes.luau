-- Edit-time builder for the reusable CSG shapes every dragon, egg and prop is made
-- from. Stored in ReplicatedStorage.Assets.Shapes; unions scale non-uniformly and
-- keep real materials, unlike SpecialMesh spheres.
-- Run with: node tools/run.mjs build/shapes.luau
local RS = game:GetService("ReplicatedStorage")
local assets = RS:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = RS
local old = assets:FindFirstChild("Shapes")
if old then
	old:Destroy()
end
local shapes = Instance.new("Folder")
shapes.Name = "Shapes"

local work = Instance.new("Folder")
work.Name = "_ShapeWork"
work.Parent = workspace

local function part(shape, size: Vector3, cf: CFrame, class: string?)
	local p = Instance.new(class or "Part")
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Parent = work
	return p
end

local function finish(u: BasePart, name: string, smoothing: number?)
	u.Name = name
	u.UsePartColor = true
	u.Anchored = true
	u.CanCollide = false
	u.CanTouch = false
	u.CanQuery = false
	u.CastShadow = true
	u.Material = Enum.Material.SmoothPlastic
	if u:IsA("UnionOperation") then
		u.SmoothingAngle = smoothing or 60
	end
	u.Parent = shapes
	return u
end

local function union(a: BasePart, others: { BasePart }, smoothing: number?)
	local u = a:UnionAsync(others, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	a:Destroy()
	for _, o in ipairs(others) do
		o:Destroy()
	end
	u.Parent = work
	u.SmoothingAngle = smoothing or 60
	return u
end

local function subtract(a: BasePart, others: { BasePart }, smoothing: number?)
	local u = a:SubtractAsync(others, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	a:Destroy()
	for _, o in ipairs(others) do
		o:Destroy()
	end
	u.Parent = work
	u.SmoothingAngle = smoothing or 60
	return u
end

-- Ellipsoid: a sphere as a union so it can be resized to any proportions. 2x2x2.
local function sphereUnion()
	local ball = part(Enum.PartType.Ball, Vector3.new(2, 2, 2), CFrame.new())
	local core = part(Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), CFrame.new())
	return union(ball, { core }, 89)
end
finish(sphereUnion(), "Ellipsoid", 89)

-- Dome: top half of a sphere, 2 x 1 x 2.
do
	local s = sphereUnion()
	local cut = part(nil, Vector3.new(4, 2, 4), CFrame.new(0, -1, 0))
	finish(subtract(s, { cut }, 89), "Dome", 89)
end

-- Cone: 24 thin wedge slices around the Y axis, base radius 1, height 2 (2x2x2),
-- tip at +Y. Used for horns, back spikes, claws, hats and crystals.
do
	local n = 24
	local slices = {}
	local w = 2 * math.tan(math.pi / n) * 1.02
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		-- A WedgePart's tall edge is at local +Z and its slope falls toward -Z, so
		-- shifting it by -0.5 puts the tall edge on the axis and the slope outward.
		table.insert(slices, part(nil, Vector3.new(w, 2, 1), CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.5), "WedgePart"))
	end
	local first = table.remove(slices, 1)
	finish(union(first, slices, 40), "Cone", 40)
end

-- Wing: flat bat wing, 3 x 2 x 0.16, lying in the XY plane (thin in Z).
-- Root edge at x = -1.5 (y from -1 to 0.5); the leading edge rises to a point at
-- (1.5, 1); the trailing edge runs from (-1.5, -1) to the tip with three scallops.
do
	local plate = part(nil, Vector3.new(3, 2, 0.16), CFrame.new())
	local function lineCut(a: Vector2, b: Vector2, above: boolean)
		local d = (b - a)
		local ang = math.atan2(d.Y, d.X)
		local normal = Vector2.new(-math.sin(ang), math.cos(ang)) * (above and 1 or -1)
		local mid = (a + b) / 2 + normal * 1.5
		return part(nil, Vector3.new(8, 3, 1), CFrame.new(mid.X, mid.Y, 0) * CFrame.Angles(0, 0, ang))
	end
	local lead0, tip, trail0 = Vector2.new(-1.5, 0.5), Vector2.new(1.5, 1), Vector2.new(-1.5, -1)
	local cuts = { lineCut(lead0, tip, true), lineCut(trail0, tip, false) }
	-- scallops: discs centred just outside the trailing edge
	local d = (tip - trail0)
	local ang = math.atan2(d.Y, d.X)
	local outward = Vector2.new(math.sin(ang), -math.cos(ang))
	for _, s in ipairs({ { 0.2, 0.62 }, { 0.48, 0.52 }, { 0.74, 0.4 } }) do
		local c = trail0 + d * s[1] + outward * s[2] * 0.55
		table.insert(cuts, part(Enum.PartType.Cylinder, Vector3.new(1, s[2] * 2, s[2] * 2), CFrame.new(c.X, c.Y, 0) * CFrame.Angles(0, math.pi / 2, 0)))
	end
	finish(subtract(plate, cuts, 30), "Wing", 30)
end

-- Egg: round bottom, taller top. 2 wide, 2.6 tall, origin at its center.
do
	local top = sphereUnion()
	top.Size = Vector3.new(2, 3.2, 2)
	local cutTop = part(nil, Vector3.new(4, 4, 4), CFrame.new(0, -2, 0))
	top = subtract(top, { cutTop }, 89)
	local bottom = sphereUnion()
	local cutBottom = part(nil, Vector3.new(4, 4, 4), CFrame.new(0, 2, 0))
	bottom = subtract(bottom, { cutBottom }, 89)
	local egg = union(top, { bottom }, 89)
	finish(egg, "Egg", 89)
end

-- Ring: flat annulus, 2 x 0.12 x 2 (pad markers, halos).
do
	local outer = part(Enum.PartType.Cylinder, Vector3.new(0.12, 2, 2), CFrame.Angles(0, 0, math.pi / 2))
	local inner = part(Enum.PartType.Cylinder, Vector3.new(0.5, 1.8, 1.8), CFrame.Angles(0, 0, math.pi / 2))
	finish(subtract(outer, { inner }, 60), "Ring", 60)
end

shapes.Parent = assets
work:Destroy()
local out = {}
for _, s in ipairs(shapes:GetChildren()) do
	table.insert(out, s.Name .. " " .. tostring(s.Size))
end
return table.concat(out, "\n")
