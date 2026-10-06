-- Edit-time builder: lighting, hub terrain, plaza, statue fountain, shops, gate and
-- the eight castle bases. Run with: node tools/run.mjs build/world_hub.luau
--#include build/lib.luau

local Lighting = game:GetService("Lighting")
local DragonBuilder = require(Shared.Visuals.DragonBuilder)
local Species = require(Shared.Species)

---------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------
Lighting.ClockTime = 14.2
Lighting.Brightness = 2.6
Lighting.Ambient = rgb(70, 70, 90)
Lighting.OutdoorAmbient = rgb(140, 140, 160)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true
Lighting.ExposureCompensation = 0.1
for _, c in ipairs(Lighting:GetChildren()) do
	if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
		c:Destroy()
	end
end
local atm = Instance.new("Atmosphere")
atm.Density = 0.28
atm.Offset = 0.15
atm.Color = rgb(200, 220, 255)
atm.Decay = rgb(120, 140, 190)
atm.Glare = 0.2
atm.Haze = 1.2
atm.Parent = Lighting
local sky = Instance.new("Sky")
sky.SunAngularSize = 14
sky.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.4
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.12
cc.Contrast = 0.06
cc.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.04
rays.Spread = 0.5
rays.Parent = Lighting

---------------------------------------------------------------------------
-- Streaming: the map is ~5,300 studs long, so only nearby parts load (default
-- radii; they aren't scriptable). Bases, eggs and guardians stream atomically.
workspace.StreamingEnabled = true

---------------------------------------------------------------------------
-- Clean slate
---------------------------------------------------------------------------
for _, name in ipairs({ "Baseplate", "SpawnLocation", "Preview", "Solo", "EggPreview", "WingTest" }) do
	local x = workspace:FindFirstChild(name)
	if x then
		x:Destroy()
	end
end
local world = folder("World", workspace)
local hub = folder("Hub", world)
local basesFolder = folder("Bases", workspace)
local rng = Random.new(42)

Terrain:Clear()
-- big grassy ground for the hub
-- (rendered terrain surfaces sit ~2 studs above a fill's top, so fills end at y = -2)
Terrain:FillBlock(CFrame.new(0, -10, 0), Vector3.new(760, 16, 760), Enum.Material.Grass)
-- rolling hills ringing the hub behind the bases
for i = 0, 40 do
	local a = math.rad(165 + i * (210 / 40))
	local r = rng:NextNumber(290, 340)
	local s = rng:NextNumber(60, 110)
	Terrain:FillBall(Vector3.new(math.cos(a) * r, -s * 0.35, math.sin(a) * r), s * 0.6, Enum.Material.Grass)
end
-- gentle hills either side of the gate approach
for _, side in ipairs({ -1, 1 }) do
	for i = 0, 5 do
		local a = math.rad(side > 0 and (15 - i * 9) or (165 + i * 9))
		Terrain:FillBall(Vector3.new(math.cos(a) * 300, -20, math.sin(a) * 300 + 40), 55, Enum.Material.Grass)
	end
end

---------------------------------------------------------------------------
-- Plaza
---------------------------------------------------------------------------
-- Plaza + walkways are terrain pavement (parts would be covered by grass blades).
fillDisc(0, 0, Layout.PlazaRadius, 0, Enum.Material.Pavement)
-- inner ring pattern as thin parts (a second terrain fill would raise the surface)
P("Cylinder", Vector3.new(0.12, (Layout.PlazaRadius - 16) * 2, (Layout.PlazaRadius - 16) * 2), CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, rad(90)), rgb(178, 166, 150), "Cobblestone", hub, { name = "PlazaInner" })
P("Cylinder", Vector3.new(0.14, 56, 56), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, rad(90)), rgb(150, 120, 170), "Cobblestone", hub, { name = "PlazaCenter" })
for i = 1, Layout.BaseCount do
	local cf = Layout.baseCFrame(i)
	local dir = cf.Position.Unit
	local len = Layout.BaseRing - Layout.BaseDepth / 2 - Layout.PlazaRadius + 10
	local mid = dir * (Layout.PlazaRadius - 4 + len / 2)
	Terrain:FillBlock(CFrame.lookAt(mid, mid + dir) * CFrame.new(0, -6, 0), Vector3.new(16, 8, len), Enum.Material.Pavement)
end
Terrain:FillBlock(CFrame.new(0, -6, Layout.PlazaRadius + 25), Vector3.new(36, 8, 60), Enum.Material.Pavement)
-- flower beds around the fountain
for i = 0, 7 do
	local a = i / 8 * math.pi * 2 + math.pi / 8
	local pos = Vector3.new(math.cos(a) * 46, 0, math.sin(a) * 46)
	P("Cylinder", Vector3.new(1.2, 12, 12), CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(200, 190, 175), "Brick", hub)
	deco("Cylinder", Vector3.new(0.3, 10.6, 10.6), CFrame.new(pos + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, 0, rad(90)), rgb(110, 80, 55), "Ground", hub)
	Props.flowers(pos + Vector3.new(0, 0.9, 0), hub, rng)
	Props.flowers(pos + Vector3.new(0, 0.9, 0), hub, rng)
end

-- Fountain with a golden dragon statue
local fountain = Instance.new("Model")
fountain.Name = "Fountain"
fountain.Parent = hub
P("Cylinder", Vector3.new(2.4, 40, 40), CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, rad(90)), rgb(220, 214, 204), "Marble", fountain)
P("Cylinder", Vector3.new(0.4, 36, 36), CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, rad(90)), rgb(90, 180, 255), "Glass", fountain, { alpha = 0.25, reflect = 0.2, collide = false, name = "Water" })
P("Cylinder", Vector3.new(7, 10, 10), CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, rad(90)), rgb(230, 224, 214), "Marble", fountain)
local statueLook = table.clone(Species.get("blaze").look)
local statue = DragonBuilder.build(statueLook, CFrame.new(0, 7, 0) * CFrame.Angles(0, math.rad(180), 0), { scale = 3.2, mutation = "gold", fx = false })
statue.Name = "Statue"
for _, p in ipairs(statue:GetDescendants()) do
	if p:IsA("BasePart") then
		p.Anchored = true
		p.CanCollide = p.Name ~= "Root"
	end
	if p:IsA("ParticleEmitter") or p:IsA("PointLight") then
		p:Destroy()
	end
end
statue.Parent = fountain
for i = 0, 5 do
	local a = i / 6 * math.pi * 2
	local nozzle = deco("Ball", Vector3.new(1.2, 1.2, 1.2), CFrame.new(math.cos(a) * 14, 2.4, math.sin(a) * 14), rgb(230, 224, 214), "Marble", fountain)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(200, 235, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Speed = NumberRange.new(14, 16)
	e.SpreadAngle = Vector2.new(4, 4)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Lifetime = NumberRange.new(0.9, 1.1)
	e.Rate = 40
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = nozzle
	local att = Instance.new("Attachment")
	att.Parent = nozzle
end

-- Lamps around the plaza edge
for i = 0, 15 do
	local a = i / 16 * math.pi * 2 + 0.1
	Props.lamp(Vector3.new(math.cos(a) * (Layout.PlazaRadius - 3), 0, math.sin(a) * (Layout.PlazaRadius - 3)), hub)
end

-- Spawn
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Size = Vector3.new(12, 1, 12)
spawn.CFrame = Layout.Spawn - Vector3.new(0, 2.6, 0)
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Duration = 0
spawn.Neutral = true
spawn.Parent = hub
local decal = spawn:FindFirstChildOfClass("Decal")
if decal then
	decal:Destroy()
end

---------------------------------------------------------------------------
-- Shops: a striped-awning stall with a dragon shopkeeper and a prompt.
---------------------------------------------------------------------------
local shopDefs = {
	{ key = "Speed", title = "⚡ SPEED SHOP", color = rgb(255, 200, 40), keeper = "thunder", prompt = "Buy Speed" },
	{ key = "Gear", title = "🛠️ GEAR SHOP", color = rgb(90, 170, 255), keeper = "scarab", prompt = "Buy Gear" },
	{ key = "Rebirth", title = "🌀 REBIRTH", color = rgb(190, 110, 255), keeper = "amethyst", prompt = "Rebirth" },
	{ key = "Index", title = "📖 DRAGON INDEX", color = rgb(110, 220, 140), keeper = "clover", prompt = "Open Index" },
}
local shops = folder("Shops", hub)
for _, def in ipairs(shopDefs) do
	local cf = Layout.Shops[def.key]
	local m = Instance.new("Model")
	m.Name = def.key
	-- floor
	P("Block", Vector3.new(22, 1, 16), cf * CFrame.new(0, 0.3, 0), rgb(160, 120, 80), "WoodPlanks", m)
	-- counter (faces the plaza: local -Z)
	local counter = P("Block", Vector3.new(16, 4, 3), cf * CFrame.new(0, 2.8, -4), def.color:Lerp(rgb(255, 255, 255), 0.35), "WoodPlanks", m, { name = "Counter" })
	P("Block", Vector3.new(17, 0.6, 4), cf * CFrame.new(0, 5, -4), rgb(120, 85, 55), "Wood", m)
	-- posts
	for _, x in ipairs({ -10, 10 }) do
		for _, z in ipairs({ -7, 7 }) do
			P("Cylinder", Vector3.new(12, 1, 1), cf * CFrame.new(x, 6.5, z) * CFrame.Angles(0, 0, rad(90)), rgb(130, 95, 60), "Wood", m)
		end
	end
	-- striped awning
	for i = 0, 7 do
		local col = i % 2 == 0 and def.color or rgb(255, 255, 255)
		P("Wedge", Vector3.new(2.75, 3, 9), cf * CFrame.new(-9.625 + i * 2.75, 14, -3.5) * CFrame.Angles(0, math.pi, 0), col, "Fabric", m)
		P("Wedge", Vector3.new(2.75, 3, 9), cf * CFrame.new(-9.625 + i * 2.75, 14, 4.5), col, "Fabric", m)
	end
	local sign = P("Block", Vector3.new(18, 4.5, 0.6), cf * CFrame.new(0, 17.5, -0.5), rgb(50, 36, 60), nil, m)
	surfaceText(sign, Enum.NormalId.Front, def.title, def.color:Lerp(Color3.new(1, 1, 1), 0.4), nil, { ppu = 14 })
	surfaceText(sign, Enum.NormalId.Back, def.title, def.color:Lerp(Color3.new(1, 1, 1), 0.4), nil, { ppu = 14 })
	-- shopkeeper dragon behind the counter
	local keeper = DragonBuilder.build(Species.get(def.keeper).look, cf * CFrame.new(0, 0.8, 1.5), { scale = 1.6, fx = false })
	keeper.Name = "Keeper"
	keeper:SetAttribute("Idle", true)
	keeper.Parent = m
	-- prompt
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 1, -2)
	att.Parent = counter
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = def.prompt
	prompt.ObjectText = def.title:gsub("^[^%s]+%s", "")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt:SetAttribute("Shop", def.key)
	prompt.Parent = att
	m.Parent = shops
end

-- Leaderboard stands (server fills the SurfaceGuis)
local boards = folder("Leaderboards", hub)
local boardDefs = { { key = "Income", title = "💰 TOP INCOME" }, { key = "Steals", title = "🦹 TOP THIEVES" } }
for i, cf in ipairs(Layout.Leaderboards) do
	local def = boardDefs[i]
	local m = Instance.new("Model")
	m.Name = def.key
	for _, x in ipairs({ -8, 8 }) do
		P("Block", Vector3.new(1.5, 18, 1.5), cf * CFrame.new(x, 9, 0), rgb(90, 70, 110), "Wood", m)
	end
	local board = P("Block", Vector3.new(15, 14, 1), cf * CFrame.new(0, 11, 0), rgb(40, 30, 60), nil, m, { name = "Board" })
	board:SetAttribute("Board", def.key)
	board:SetAttribute("Title", def.title)
	m.Parent = boards
end

---------------------------------------------------------------------------
-- Gate to the Dragon Path
---------------------------------------------------------------------------
Props.arch(CFrame.new(0, 0, Layout.GateZ), 34, 22, rgb(150, 140, 130), hub, "🐉 DRAGON PATH 🐉", "Grab an egg — then RUN!")
for _, side in ipairs({ -1, 1 }) do
	-- dragon head statues flanking the gate
	local g = DragonBuilder.build(Species.get("magma").look, CFrame.new(side * 30, 2, Layout.GateZ - 6) * CFrame.Angles(0, math.pi + side * 0.4, 0), { scale = 2.2, fx = false, angry = true })
	for _, p in ipairs(g:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.Color = p.Color:Lerp(rgb(150, 145, 140), 0.85)
			if p.Material == Enum.Material.Neon then
				p.Color = rgb(255, 120, 40)
			else
				p.Material = Enum.Material.Slate
			end
		end
	end
	g.Parent = hub
	P("Block", Vector3.new(10, 2, 10), CFrame.new(side * 30, 1, Layout.GateZ - 6), rgb(140, 135, 130), "Slate", hub)
end

-- Trees scattered between the bases and on the edges
local trees = folder("Trees", hub)
for i = 1, Layout.BaseCount + 1 do
	local a = math.rad(180 + (i - 1) * 180 / Layout.BaseCount)
	for _, r in ipairs({ 150, 236, 262 }) do
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if r > 200 or (i > 1 and i <= Layout.BaseCount) then
			Props.tree(pos, rng:NextNumber(14, 20), trees, nil, rng)
		end
	end
end
for i = 0, 26 do
	local a = math.rad(-8 + i * 7.3)
	if math.abs(math.deg(a) - 90) > 16 then
		local r = rng:NextNumber(130, 250)
		Props.tree(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(14, 24), trees, rgb(80, 175, 75), rng)
		Props.flowers(Vector3.new(math.cos(a) * (r - 12), 0, math.sin(a) * (r - 12)), trees, rng)
	end
end

---------------------------------------------------------------------------
-- Bases
---------------------------------------------------------------------------
local SLOT_COLORS = {
	rgb(235, 70, 70), rgb(255, 150, 40), rgb(250, 210, 50), rgb(90, 200, 90),
	rgb(60, 200, 210), rgb(70, 130, 240), rgb(160, 90, 230), rgb(240, 110, 190),
}
local W, D = Layout.BaseWidth, Layout.BaseDepth
local wallH = 10
for i = 1, Layout.BaseCount do
	local cf = Layout.baseCFrame(i)
	local color = SLOT_COLORS[i]
	-- no grass blades poking through the floor
	Terrain:FillBlock(cf * CFrame.new(0, -6, 0), Vector3.new(W + 6, 8, D + 6), Enum.Material.Ground)
	local m = Instance.new("Model")
	m.Name = "Base_" .. i
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("Slot", i)
	m:SetAttribute("Color", color)
	-- floor
	P("Block", Vector3.new(W, 1, D), cf * CFrame.new(0, 0.5, 0), rgb(196, 150, 105), "WoodPlanks", m, { name = "Floor" })
	-- carpet runner from the door
	deco("Block", Vector3.new(10, 0.1, D - 6), cf * CFrame.new(0, 1.05, 1), color:Lerp(rgb(80, 20, 30), 0.3), "Fabric", m)
	-- walls
	local stone = rgb(180, 172, 165)
	local function wallSeg(cx, cz, sx, sz)
		P("Block", Vector3.new(sx, wallH, sz), cf * CFrame.new(cx, 1 + wallH / 2, cz), stone, "Cobblestone", m, { name = "Wall" })
		-- crenellations
		local len = math.max(sx, sz)
		local n = math.floor(len / 4)
		for k = 0, n - 1 do
			if k % 2 == 0 then
				local t = -len / 2 + (k + 0.5) * (len / n)
				local ox, oz = (sx > sz) and t or 0, (sx > sz) and 0 or t
				P("Block", Vector3.new(sx > sz and len / n or sx, 2, sx > sz and sz or len / n), cf * CFrame.new(cx + ox, 1 + wallH + 1, cz + oz), stone, "Cobblestone", m, { name = "Wall" })
			end
		end
	end
	wallSeg(-W / 2 + 1, 0, 2, D)
	wallSeg(W / 2 - 1, 0, 2, D)
	wallSeg(0, D / 2 - 1, W, 2)
	local frontLen = (W - Layout.DoorWidth) / 2
	wallSeg(-W / 2 + frontLen / 2, -D / 2 + 1, frontLen, 2)
	wallSeg(W / 2 - frontLen / 2, -D / 2 + 1, frontLen, 2)
	-- corner towers
	for _, x in ipairs({ -W / 2 + 1, W / 2 - 1 }) do
		for _, z in ipairs({ -D / 2 + 1, D / 2 - 1 }) do
			P("Cylinder", Vector3.new(15, 8, 8), cf * CFrame.new(x, 1 + 7.5, z) * CFrame.Angles(0, 0, rad(90)), stone, "Cobblestone", m, { name = "Tower" })
			P("Cone", Vector3.new(10, 8, 10), cf * CFrame.new(x, 1 + 15 + 4, z), color, "Slate", m, { name = "Roof" })
			-- flag
			deco("Cylinder", Vector3.new(5, 0.3, 0.3), cf * CFrame.new(x, 1 + 23 + 2.5, z) * CFrame.Angles(0, 0, rad(90)), rgb(90, 70, 50), "Wood", m)
			deco("Wedge", Vector3.new(0.2, 2, 3), cf * CFrame.new(x, 1 + 26, z + 1.5) * CFrame.Angles(0, 0, 0), color, "Fabric", m)
		end
	end
	-- door frame + sign
	for _, side in ipairs({ -1, 1 }) do
		P("Block", Vector3.new(3, wallH + 4, 3), cf * CFrame.new(side * (Layout.DoorWidth / 2 + 1.5), 1 + (wallH + 4) / 2, -D / 2 + 1), stone:Lerp(Color3.new(0, 0, 0), 0.1), "Cobblestone", m)
	end
	P("Block", Vector3.new(Layout.DoorWidth + 6, 3, 3), cf * CFrame.new(0, 1 + wallH + 3.5, -D / 2 + 1), stone:Lerp(Color3.new(0, 0, 0), 0.1), "Cobblestone", m)
	local sign = P("Block", Vector3.new(Layout.DoorWidth + 10, 5, 0.6), cf * CFrame.new(0, 1 + wallH + 8, -D / 2 + 0.2), rgb(40, 30, 55), nil, m, { name = "Sign" })
	local _, label = surfaceText(sign, Enum.NormalId.Front, "EMPTY BASE", color:Lerp(Color3.new(1, 1, 1), 0.5), nil, { ppu = 14 })
	label.Name = "OwnerLabel"
	-- laser door (server toggles)
	local laser = P("Block", Vector3.new(Layout.DoorWidth, wallH + 2, 0.6), cf * CFrame.new(0, 1 + (wallH + 2) / 2, -D / 2 + 1), rgb(255, 40, 60), "Neon", m, { name = "Laser", alpha = 1, collide = false, shadow = false })
	laser.CanQuery = false
	-- lock button pedestal
	local lcf = Layout.lockButtonCFrame(i)
	P("Cylinder", Vector3.new(3, 3, 3), lcf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, rad(90)), rgb(70, 60, 80), "Metal", m)
	local btn = P("Cylinder", Vector3.new(0.8, 2.4, 2.4), lcf * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, rad(90)), rgb(255, 60, 70), "Neon", m, { name = "LockButton" })
	local latt = Instance.new("Attachment")
	latt.Parent = btn
	local lp = Instance.new("ProximityPrompt")
	lp.Name = "LockPrompt"
	lp.ActionText = "Lock Base"
	lp.ObjectText = "60s"
	lp.KeyboardKeyCode = Enum.KeyCode.E
	lp.HoldDuration = 0
	lp.MaxActivationDistance = 10
	lp.RequiresLineOfSight = false
	lp.Parent = latt
	-- pads + collect plates
	for n = 1, Layout.MaxPads do
		local o = Layout.padOffset(n)
		local pcf = cf * CFrame.new(o.X, Layout.FloorTop, o.Z)
		P("Cylinder", Vector3.new(0.4, Layout.PadSize, Layout.PadSize), pcf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, rad(90)), rgb(150, 145, 160), "Slate", m, { name = "Pad_" .. n })
		local ring = deco("Ring", Vector3.new(0.12, Layout.PadSize - 0.4, Layout.PadSize - 0.4), pcf * CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, rad(90)), color, "Neon", m, { name = "PadRing_" .. n })
		ring.CastShadow = false
		local plate = P("Block", Vector3.new(4.2, 0.3, 2.2), Layout.plateCFrame(i, n), rgb(90, 220, 110), "Neon", m, { name = "Plate_" .. n, touch = true })
		plate:SetAttribute("Pad", n)
	end
	m.Parent = basesFolder
end

cleanupFresh()
return "hub built"
