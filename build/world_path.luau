-- Edit-time builder: the Dragon Path and its eight biomes (terrain, scenery,
-- gate arches, nests, guardian lairs, boundaries).
-- Run after world_hub.luau: node tools/run.mjs build/world_path.luau
--#include build/lib.luau

local world = workspace:FindFirstChild("World") or folder("World", workspace)
local path = folder("Path", world)
local M = Enum.Material

-- ground / road / hill materials and global material colors
local THEMES = {
	{ ground = M.Grass, road = M.Ground, hill = M.Grass, emoji = "🌼" },
	{ ground = M.Sand, road = M.Sandstone, hill = M.Sand, emoji = "🏜️" },
	{ ground = M.Snow, road = M.Glacier, hill = M.Snow, emoji = "❄️" },
	{ ground = M.Basalt, road = M.Mud, hill = M.Basalt, emoji = "🌋" },
	{ ground = M.Rock, road = M.Cobblestone, hill = M.Rock, emoji = "⚡" },
	{ ground = M.Limestone, road = M.Concrete, hill = M.Limestone, emoji = "💎" },
	{ ground = M.Slate, road = M.Brick, hill = M.Slate, emoji = "👻" },
	{ ground = M.Asphalt, road = M.Pavement, hill = M.Asphalt, emoji = "🌠" },
}
Terrain:SetMaterialColor(M.Ground, rgb(150, 120, 80))
Terrain:SetMaterialColor(M.Sand, rgb(240, 208, 146))
Terrain:SetMaterialColor(M.Sandstone, rgb(214, 170, 110))
Terrain:SetMaterialColor(M.Glacier, rgb(190, 225, 245))
Terrain:SetMaterialColor(M.Basalt, rgb(60, 48, 46))
Terrain:SetMaterialColor(M.Mud, rgb(90, 74, 66))
Terrain:SetMaterialColor(M.Rock, rgb(112, 116, 136))
Terrain:SetMaterialColor(M.Limestone, rgb(196, 176, 236))
Terrain:SetMaterialColor(M.Concrete, rgb(222, 212, 246))
Terrain:SetMaterialColor(M.Slate, rgb(58, 44, 80))
Terrain:SetMaterialColor(M.Brick, rgb(92, 66, 120))
Terrain:SetMaterialColor(M.Asphalt, rgb(36, 40, 86))
Terrain:SetMaterialColor(M.CrackedLava, rgb(255, 120, 40))

-- road from the gate to the first biome
Terrain:FillBlock(CFrame.new(0, -8, (Layout.PlazaRadius + Layout.Biomes[1].zStart) / 2 + 10), Vector3.new(44, 12, Layout.Biomes[1].zStart - Layout.PlazaRadius + 20), M.Pavement)

local function scatter(info, n: number, fn, rng: Random, minX: number?, maxX: number?)
	minX = minX or Layout.PathWidth / 2 + 6
	maxX = maxX or info.halfWidth - 6
	-- counts are tuned for a ~280-stud biome; longer biomes get proportionally more
	n = math.floor(n * math.max(1, (info.zEnd - info.zStart) / 280) + 0.5)
	for _ = 1, n do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local x = side * rng:NextNumber(minX, maxX)
		local z = rng:NextNumber(info.zStart + 30, info.zEnd - 20)
		-- keep the nest + lair area clear
		if math.abs(z - info.nestZ) > 24 or math.abs(x) > 30 then
			fn(Vector3.new(x, 0, z), side)
		end
	end
end

local function nest(info, parent: Instance, rng: Random, logColor: Color3, strawColor: Color3)
	local m = Instance.new("Model")
	m.Name = "Nest"
	local c = Vector3.new(0, 0, info.nestZ)
	P("Cylinder", Vector3.new(1.2, 19, 19), CFrame.new(c + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, rad(90)), strawColor, "Fabric", m)
	for i = 1, 18 do
		local a = i / 18 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * 10, 1.6, math.sin(a) * 10)
		P("Cylinder", Vector3.new(7.5, 1.6, 1.6), CFrame.lookAt(pos, c + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, rad(90), 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.25, 0.25)), logColor:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.2)), "Wood", m, { collide = false })
		local pos2 = c + Vector3.new(math.cos(a + 0.17) * 10.6, 3, math.sin(a + 0.17) * 10.6)
		P("Cylinder", Vector3.new(6, 1.2, 1.2), CFrame.lookAt(pos2, c + Vector3.new(0, 3, 0)) * CFrame.Angles(0, rad(90), 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, 0), logColor:Lerp(rgb(255, 230, 180), rng:NextNumber(0, 0.15)), "Wood", m, { collide = false })
	end
	m.Parent = parent
	-- invisible floor so eggs + players stand on the straw
	return m
end

local function lair(info, parent: Instance, color: Color3, mat)
	local pos = Vector3.new(0, 0, info.restZ)
	fillDisc(pos.X, pos.Z, 22, 0.5, mat)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		Props.rock(pos + Vector3.new(math.cos(a) * 24, 0, math.sin(a) * 24 + 6), Random.new(i):NextNumber(5, 9), parent, color, nil, Random.new(i + 10))
	end
end

local biomeBuilders = {}

-- 1 Sunny Meadow
biomeBuilders[1] = function(info, f, rng)
	scatter(info, 34, function(p) Props.tree(p, rng:NextNumber(14, 24), f, nil, rng) end, rng)
	scatter(info, 26, function(p) Props.flowers(p, f, rng) end, rng, 26, info.halfWidth - 4)
	scatter(info, 10, function(p) Props.mushroom(p, rng:NextNumber(3, 6), f, rgb(230, 60, 60)) end, rng)
	scatter(info, 8, function(p) Props.rock(p, rng:NextNumber(3, 6), f, rgb(140, 140, 135), nil, rng) end, rng)
	-- pond
	fillDisc(-44, info.zStart + 90, 16, -0.6, M.Water, 5)
	nest(info, f, rng, rgb(130, 95, 60), rgb(235, 210, 120))
	lair(info, f, rgb(110, 140, 100), M.LeafyGrass)
end

-- 2 Sandy Dunes
biomeBuilders[2] = function(info, f, rng)
	scatter(info, 30, function(p) Props.cactus(p, rng:NextNumber(8, 14), f) end, rng)
	scatter(info, 14, function(p) Props.rock(p, rng:NextNumber(4, 8), f, rgb(200, 150, 90), "Sandstone", rng) end, rng)
	-- pyramids
	for _, side in ipairs({ -1, 1 }) do
		local base = Vector3.new(side * (info.halfWidth - 10), 0, info.zStart + 120 + (side > 0 and 60 or 0))
		local h = 0
		for k = 0, 6 do
			local w = 50 - k * 7
			P("Block", Vector3.new(w, 5, w), CFrame.new(base + Vector3.new(0, h + 2.5, 0)), rgb(226, 186, 116):Lerp(rgb(190, 140, 80), k / 8), "Sandstone", f)
			h += 5
		end
		P("Cone", Vector3.new(4, 4, 4), CFrame.new(base + Vector3.new(0, h + 1, 0)), rgb(255, 200, 50), "Foil", f, { collide = false })
	end
	nest(info, f, rng, rgb(170, 130, 80), rgb(240, 220, 160))
	lair(info, f, rgb(210, 160, 100), M.Sandstone)
end

-- 3 Frostpeak
biomeBuilders[3] = function(info, f, rng)
	scatter(info, 40, function(p) Props.pine(p, rng:NextNumber(16, 28), f, rgb(60, 120, 100), true) end, rng)
	scatter(info, 16, function(p) Props.crystal(p, rng:NextNumber(5, 10), f, rgb(170, 225, 255), rng) end, rng)
	-- frozen lake
	P("Cylinder", Vector3.new(0.4, 50, 50), CFrame.new(46, 0.1, info.zStart + 140) * CFrame.Angles(0, 0, rad(90)), rgb(180, 220, 245), "Ice", f, { reflect = 0.2 })
	-- snowmen
	for k = 1, 3 do
		local p = Vector3.new((k % 2 == 0 and -1 or 1) * rng:NextNumber(32, 48), 0, info.zStart + 60 + k * 70)
		P("Ball", Vector3.new(6, 6, 6), CFrame.new(p + Vector3.new(0, 2.6, 0)), rgb(250, 252, 255), "Snow", f)
		P("Ball", Vector3.new(4.4, 4.4, 4.4), CFrame.new(p + Vector3.new(0, 6.6, 0)), rgb(250, 252, 255), "Snow", f)
		P("Ball", Vector3.new(3.2, 3.2, 3.2), CFrame.new(p + Vector3.new(0, 9.6, 0)), rgb(250, 252, 255), "Snow", f)
		P("Cone", Vector3.new(0.6, 1.6, 0.6), CFrame.new(p + Vector3.new(0, 9.6, -1.9)) * CFrame.Angles(rad(-90), 0, 0), rgb(255, 140, 40), nil, f, { collide = false })
	end
	nest(info, f, rng, rgb(120, 110, 100), rgb(235, 240, 250))
	lair(info, f, rgb(180, 215, 240), M.Glacier)
end

-- 4 Magma Mountain
biomeBuilders[4] = function(info, f, rng)
	scatter(info, 26, function(p) Props.rock(p, rng:NextNumber(5, 11), f, rgb(55, 45, 45), "Basalt", rng) end, rng)
	-- lava pools with glowing surfaces (decorative, off the road)
	for k = 1, 8 do
		local side = k % 2 == 0 and -1 or 1
		local p = Vector3.new(side * rng:NextNumber(40, info.halfWidth - 18), 0, info.zStart + 40 + k * (info.reach + 60) / 8)
		fillDisc(p.X, p.Z, rng:NextNumber(9, 15), 0, M.CrackedLava)
		local glow = deco("Cylinder", Vector3.new(0.3, 16, 16), CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(255, 110, 30), "Neon", f, { alpha = 0.35, shadow = false })
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 120, 40)
		l.Range = 24
		l.Brightness = 2
		l.Parent = glow
	end
	-- volcano cones in the distance
	for _, side in ipairs({ -1, 1 }) do
		local base = Vector3.new(side * (info.halfWidth + 40), -10, info.zStart + 200)
		Terrain:FillBall(base, 60, M.Basalt)
		local crater = P("Cylinder", Vector3.new(1, 30, 30), CFrame.new(base + Vector3.new(0, 49, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(255, 100, 30), "Neon", f, { collide = false })
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(rgb(70, 60, 60))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 40) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(6, 9)
		smoke.Speed = NumberRange.new(8, 14)
		smoke.Rate = 4
		smoke.SpreadAngle = Vector2.new(15, 15)
		smoke.EmissionDirection = Enum.NormalId.Right
		smoke.LightInfluence = 0.3
		smoke.Parent = crater
	end
	-- spiky basalt shards
	scatter(info, 14, function(p)
		local h = rng:NextNumber(8, 18)
		P("Cone", Vector3.new(h * 0.35, h, h * 0.35), CFrame.new(p + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)), rgb(40, 32, 32), "Basalt", f)
	end, rng)
	-- glowing lava rivers running alongside the road
	for _, side in ipairs({ -1, 1 }) do
		local z = info.zStart + 30
		while z < info.zEnd - 60 do
			local len = rng:NextNumber(40, 80)
			local x = side * rng:NextNumber(36, 44)
			local seg = deco("Block", Vector3.new(rng:NextNumber(5, 8), 0.4, len), CFrame.new(x, 0.15, z + len / 2) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0), rgb(255, 100, 20), "Neon", f, { shadow = false })
			local l = Instance.new("PointLight")
			l.Color = rgb(255, 110, 40)
			l.Range = 18
			l.Brightness = 1.5
			l.Parent = seg
			z += len + rng:NextNumber(20, 60)
		end
	end
	nest(info, f, rng, rgb(50, 40, 38), rgb(140, 80, 50))
	lair(info, f, rgb(60, 48, 46), M.Basalt)
end

-- 5 Thunder Cliffs
biomeBuilders[5] = function(info, f, rng)
	scatter(info, 20, function(p)
		local h = rng:NextNumber(20, 45)
		P("Cylinder", Vector3.new(h, rng:NextNumber(7, 12), rng:NextNumber(7, 12)), CFrame.new(p + Vector3.new(0, h / 2 - 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), rad(90)), rgb(110, 115, 135), "Rock", f)
	end, rng)
	-- lightning rods
	scatter(info, 12, function(p)
		P("Cylinder", Vector3.new(18, 0.8, 0.8), CFrame.new(p + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(150, 150, 160), "Metal", f)
		local orb = deco("Ball", Vector3.new(2.4, 2.4, 2.4), CFrame.new(p + Vector3.new(0, 19, 0)), rgb(150, 220, 255), "Neon", f)
		local l = Instance.new("PointLight")
		l.Color = rgb(150, 210, 255)
		l.Range = 16
		l.Parent = orb
	end, rng)
	scatter(info, 18, function(p) Props.rock(p, rng:NextNumber(4, 9), f, rgb(100, 105, 125), nil, rng) end, rng)
	-- storm clouds hanging over the cliffs
	for k = 1, math.floor((info.zEnd - info.zStart) / 70) do
		local c = Vector3.new(rng:NextNumber(-info.halfWidth, info.halfWidth), rng:NextNumber(55, 80), info.zStart + k * 70)
		for _ = 1, 5 do
			local r = rng:NextNumber(14, 26)
			deco("Ellipsoid", Vector3.new(r * 1.7, r * 0.55, r * 1.2), CFrame.new(c + Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-2, 2), rng:NextNumber(-12, 12))), rgb(150, 155, 175), "SmoothPlastic", f, { shadow = false, alpha = 0.1 })
		end
	end
	nest(info, f, rng, rgb(80, 80, 95), rgb(200, 200, 215))
	lair(info, f, rgb(100, 104, 124), M.Rock)
end

-- 6 Crystal Caverns
biomeBuilders[6] = function(info, f, rng)
	local cols = { rgb(200, 120, 255), rgb(120, 200, 255), rgb(255, 130, 210), rgb(140, 255, 220) }
	scatter(info, 46, function(p) Props.crystal(p, rng:NextNumber(8, 22), f, cols[rng:NextInteger(1, #cols)], rng, rng:NextNumber() < 0.35) end, rng)
	scatter(info, 12, function(p) Props.rock(p, rng:NextNumber(4, 8), f, rgb(170, 150, 210), "Slate", rng) end, rng)
	-- glowing archway crystals over the road
	for k = 1, 5 do
		local z = info.zStart + k * info.reach / 5
		for _, side in ipairs({ -1, 1 }) do
			local cf = CFrame.new(side * 30, 0, z) * CFrame.Angles(0, 0, side * rad(28))
			local c = deco("Cone", Vector3.new(6, 34, 6), cf * CFrame.new(0, 17, 0), cols[k % #cols + 1], "Neon", f, { alpha = 0.2 })
			local l = Instance.new("PointLight")
			l.Color = c.Color
			l.Range = 20
			l.Parent = c
		end
	end
	scatter(info, 10, function(p, side)
		Props.crystal(Vector3.new(side * rng:NextNumber(30, 36), 0, p.Z), rng:NextNumber(14, 26), f, cols[rng:NextInteger(1, #cols)], rng, true)
	end, rng)
	nest(info, f, rng, rgb(140, 110, 190), rgb(230, 210, 255))
	lair(info, f, rgb(170, 140, 220), M.Salt)
end

-- 7 Shadow Realm
biomeBuilders[7] = function(info, f, rng)
	-- dead trees
	scatter(info, 34, function(p)
		local h = rng:NextNumber(14, 26)
		P("Cylinder", Vector3.new(h, 1.6, 1.6), CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(30, 22, 36), "Wood", f)
		for b = 1, 3 do
			local y = h * (0.5 + b * 0.13)
			local a = rng:NextNumber(0, 6.28)
			deco("Cylinder", Vector3.new(h * 0.35, 0.8, 0.8), CFrame.new(p + Vector3.new(0, y, 0)) * CFrame.Angles(0, a, rad(35)) * CFrame.new(h * 0.15, 0, 0), rgb(30, 22, 36), "Wood", f)
		end
	end, rng)
	scatter(info, 20, function(p) Props.mushroom(p, rng:NextNumber(3, 7), f, rgb(170, 80, 255), true) end, rng)
	-- floating wisps
	scatter(info, 16, function(p)
		local w = deco("Ball", Vector3.new(1.6, 1.6, 1.6), CFrame.new(p + Vector3.new(0, rng:NextNumber(6, 16), 0)), rgb(190, 140, 255), "Neon", f, { alpha = 0.2 })
		local l = Instance.new("PointLight")
		l.Color = rgb(170, 110, 255)
		l.Range = 14
		l.Parent = w
	end, rng)
	scatter(info, 22, function(p)
		local h = rng:NextNumber(3, 5)
		P("Block", Vector3.new(h * 0.7, h, 0.8), CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.12, 0.12)), rgb(90, 85, 105), "Slate", f)
		P("Cylinder", Vector3.new(0.8, h * 0.7, h * 0.7), CFrame.new(p + Vector3.new(0, h, 0)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0) * CFrame.Angles(0, rad(90), 0), rgb(90, 85, 105), "Slate", f)
	end, rng, 26, 60)
	for k = 1, math.floor((info.zEnd - info.zStart) / 60) do
		for _, side in ipairs({ -1, 1 }) do
			Props.lamp(Vector3.new(side * 31, 0, info.zStart + k * 60), f, rgb(190, 120, 255))
		end
	end
	nest(info, f, rng, rgb(35, 28, 45), rgb(90, 60, 120))
	lair(info, f, rgb(50, 38, 70), M.Slate)
end

-- 8 Starfall Summit
biomeBuilders[8] = function(info, f, rng)
	scatter(info, 30, function(p) Props.crystal(p, rng:NextNumber(6, 14), f, rgb(255, 235, 140), rng, true) end, rng)
	-- floating islands
	scatter(info, 12, function(p)
		local s = rng:NextNumber(10, 18)
		local y = rng:NextNumber(25, 55)
		P("Cone", Vector3.new(s, s * 0.9, s), CFrame.new(p + Vector3.new(0, y - s * 0.45, 0)) * CFrame.Angles(math.pi, 0, 0), rgb(60, 60, 110), "Slate", f, { collide = false })
		P("Cylinder", Vector3.new(1.5, s, s), CFrame.new(p + Vector3.new(0, y + 0.7, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(90, 110, 200), "Grass", f, { collide = false })
	end, rng)
	-- planets
	for k = 1, 3 do
		local side = k % 2 == 0 and -1 or 1
		local pl = deco("Ball", Vector3.new(60, 60, 60), CFrame.new(side * (info.halfWidth + 90), 90 + k * 20, info.zStart + k * 300), ({ rgb(255, 150, 90), rgb(120, 200, 255), rgb(200, 140, 255) })[k], "SmoothPlastic", f)
		deco("Ring", Vector3.new(1, 100, 100), pl.CFrame * CFrame.Angles(0.3, 0, rad(90) + 0.4), rgb(255, 240, 200), "SmoothPlastic", f, { alpha = 0.3 })
	end
	scatter(info, 8, function(p)
		local r = rng:NextNumber(8, 14)
		P("Ring", Vector3.new(1.4, r * 2, r * 2), CFrame.new(p + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(60, 60, 110), "Slate", f, { collide = false })
		local rock = P("Ball", Vector3.new(r * 0.5, r * 0.5, r * 0.5), CFrame.new(p + Vector3.new(0, r * 0.12, 0)), rgb(255, 150, 70), "Neon", f)
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 160, 80)
		l.Range = 16
		l.Parent = rock
	end, rng)
	for k = 1, math.floor((info.zEnd - info.zStart) / 70) do
		for _, side in ipairs({ -1, 1 }) do
			Props.lamp(Vector3.new(side * 31, 0, info.zStart + k * 70), f, rgb(255, 235, 150))
		end
	end
	nest(info, f, rng, rgb(70, 70, 130), rgb(140, 160, 255))
	lair(info, f, rgb(50, 55, 110), M.Asphalt)
end

for i, info in ipairs(Layout.Biomes) do
	local th = THEMES[i]
	local def = info.def
	local f = Instance.new("Folder")
	f.Name = "Biome_" .. i
	f.Parent = path
	local rng = Random.new(1000 + i)
	local len = info.zEnd - info.zStart
	local zc = (info.zStart + info.zEnd) / 2
	-- ground + road
	Terrain:FillBlock(CFrame.new(0, -10, zc), Vector3.new(info.halfWidth * 2 + 200, 16, len + 2), th.ground)
	Terrain:FillBlock(CFrame.new(0, -8, zc), Vector3.new(Layout.PathWidth - 10, 12, len + 2), th.road)
	-- hills along both sides (natural walls)
	for _, side in ipairs({ -1, 1 }) do
		local z = info.zStart
		while z < info.zEnd do
			local r = rng:NextNumber(26, 44)
			Terrain:FillBall(Vector3.new(side * (info.halfWidth + r * 0.55), -r * 0.25, z), r, th.hill)
			z += r * rng:NextNumber(0.9, 1.3)
		end
		wall(Vector3.new(4, 120, len), CFrame.new(side * (info.halfWidth + 2), 50, zc), f)
	end
	-- gate arch
	local gateColor = def.color:Lerp(rgb(140, 130, 120), 0.45)
	Props.arch(CFrame.new(0, 0, info.zStart), 42, 24, gateColor, f, th.emoji .. " " .. string.upper(def.name), "⚡ Speed " .. def.speed .. " to escape " .. def.guardian)
	biomeBuilders[i](info, f, rng)
	-- signpost at the nest
	local post = P("Block", Vector3.new(1, 8, 1), CFrame.new(16, 4, info.nestZ - 22), rgb(120, 90, 60), "Wood", f)
	local board = P("Block", Vector3.new(10, 4, 0.5), CFrame.new(16, 8.5, info.nestZ - 22), rgb(150, 115, 80), "WoodPlanks", f)
	surfaceText(board, Enum.NormalId.Front, "⚠️ " .. def.guardian .. "'s Nest", rgb(255, 240, 200), nil, { ppu = 20 })
end

-- end of the path
local last = Layout.Biomes[#Layout.Biomes]
wall(Vector3.new(last.halfWidth * 2 + 20, 120, 4), CFrame.new(0, 50, Layout.PathEnd + 2), path)
Terrain:FillBlock(CFrame.new(0, 10, Layout.PathEnd + 40), Vector3.new(last.halfWidth * 2 + 200, 60, 80), M.Asphalt)
local endSign = P("Block", Vector3.new(40, 10, 1), CFrame.new(0, 14, Layout.PathEnd - 2), rgb(30, 30, 60), nil, path)
surfaceText(endSign, Enum.NormalId.Front, "🚧 NEW BIOMES COMING SOON 🚧", rgb(255, 230, 120), nil, { ppu = 12 })
-- hub boundary walls beside the gate road
wall(Vector3.new(4, 120, Layout.Biomes[1].zStart - Layout.GateZ + 20), CFrame.new(-Layout.Biomes[1].halfWidth - 2, 50, (Layout.GateZ + Layout.Biomes[1].zStart) / 2), path)
wall(Vector3.new(4, 120, Layout.Biomes[1].zStart - Layout.GateZ + 20), CFrame.new(Layout.Biomes[1].halfWidth + 2, 50, (Layout.GateZ + Layout.Biomes[1].zStart) / 2), path)

cleanupFresh()
return "path built to z=" .. Layout.PathEnd
