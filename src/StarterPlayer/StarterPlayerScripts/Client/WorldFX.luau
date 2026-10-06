-- World effects on this client: guardian animation + roars, per-biome sky and fog
-- as you run down the Dragon Path, event lighting, meteors, idle shopkeepers.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Biomes = require(Shared.Biomes)
local Net = require(Shared.Net)
local Effects = require(Shared.Visuals.Effects)

local Sounds = require(script.Parent.Sounds)
local ToolController = require(script.Parent.ToolController)
local Notify = require(script.Parent.UI.Notify)

local WorldFX = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB

---------------------------------------------------------------------------
-- Guardians
---------------------------------------------------------------------------
local guardianRigs = {} -- [model] = { motors }

local function rigOf(model: Model)
	local rig = guardianRigs[model]
	if rig then
		return rig
	end
	rig = { motors = {}, phase = math.random() * 10 }
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") then
			rig.motors[m.Name] = m
		end
	end
	guardianRigs[model] = rig
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			guardianRigs[model] = nil
		end
	end)
	return rig
end

local function animateGuardians()
	local folder = workspace:FindFirstChild("Guardians")
	if not folder then
		return
	end
	local cam = workspace.CurrentCamera
	local t = os.clock()
	for _, model in ipairs(folder:GetChildren()) do
		local root = model.PrimaryPart
		if root and (root.Position - cam.CFrame.Position).Magnitude < 600 then
			local rig = rigOf(model)
			local state = model:GetAttribute("State") or "sleep"
			local m = rig.motors
			local ph = t + rig.phase
			if state == "sleep" then
				if m.Body then
					m.Body.Transform = CFrame.new(0, math.sin(ph * 0.8) * 0.25, 0) * CFrame.Angles(0.12, 0, 0)
				end
				if m.Head then
					m.Head.Transform = CFrame.Angles(0.35 + math.sin(ph * 0.8) * 0.04, 0, 0)
				end
				if m.WingR then
					m.WingR.Transform = CFrame.Angles(0, 0, -0.5)
				end
				if m.WingL then
					m.WingL.Transform = CFrame.Angles(0, 0, 0.5)
				end
				if m.Tail then
					m.Tail.Transform = CFrame.Angles(0, math.sin(ph * 0.5) * 0.15, 0)
				end
			else
				local fast = state == "chase" and 9 or 5
				local flap = math.sin(ph * fast) * 0.6
				if m.Body then
					m.Body.Transform = CFrame.new(0, math.sin(ph * fast) * 0.5, 0) * CFrame.Angles(-0.12, 0, 0)
				end
				if m.Head then
					m.Head.Transform = CFrame.Angles(-0.15 + math.sin(ph * 6) * 0.05, math.sin(ph * 2) * 0.1, 0)
				end
				if m.WingR then
					m.WingR.Transform = CFrame.Angles(0, 0, flap)
				end
				if m.WingL then
					m.WingL.Transform = CFrame.Angles(0, 0, -flap)
				end
				if m.Tail then
					m.Tail.Transform = CFrame.Angles(math.sin(ph * 4) * 0.2, math.sin(ph * 3) * 0.35, 0)
				end
			end
		end
	end
end

local function onRoar(biome: number, targetId: number?, kind: string?)
	local folder = workspace:FindFirstChild("Guardians")
	local g = folder and folder:FindFirstChild("Guardian_" .. biome)
	local root = g and g.PrimaryPart
	if root then
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://9113980319"
		s.Volume = 0.7
		s.PlaybackSpeed = 0.75 + biome * 0.03
		s.RollOffMaxDistance = 500
		s.RollOffMinDistance = 40
		s.Parent = root
		s:Play()
		task.delay(3, function()
			s:Destroy()
		end)
	end
	if targetId == player.UserId then
		if kind == "catch" then
			ToolController.shake(0.7, 1.6)
		else
			ToolController.shake(0.9, 0.8)
			Notify.big(string.upper(Biomes.List[biome].guardian) .. " WOKE UP!", "RUN back through the gate! 🏃", rgb(255, 90, 60))
		end
	end
end

---------------------------------------------------------------------------
-- Biome atmosphere
---------------------------------------------------------------------------
local ATMOS = {
	[0] = { color = rgb(200, 220, 255), decay = rgb(120, 140, 190), density = 0.28, haze = 1.2, ambient = rgb(140, 140, 160), clock = 14.2, tint = rgb(255, 255, 255), sat = 0.12 },
	{ color = rgb(210, 235, 255), decay = rgb(140, 190, 140), density = 0.26, haze = 1, ambient = rgb(150, 160, 140), clock = 13.5, tint = rgb(255, 255, 245), sat = 0.18 },
	{ color = rgb(255, 225, 170), decay = rgb(220, 160, 90), density = 0.32, haze = 2.2, ambient = rgb(170, 150, 120), clock = 15.5, tint = rgb(255, 240, 215), sat = 0.12 },
	{ color = rgb(220, 240, 255), decay = rgb(150, 190, 230), density = 0.38, haze = 2.4, ambient = rgb(160, 175, 200), clock = 12.5, tint = rgb(235, 245, 255), sat = 0 },
	{ color = rgb(255, 150, 90), decay = rgb(120, 40, 20), density = 0.42, haze = 2.6, ambient = rgb(150, 90, 70), clock = 17.6, tint = rgb(255, 215, 190), sat = 0.15 },
	{ color = rgb(150, 160, 200), decay = rgb(60, 60, 100), density = 0.42, haze = 1.6, ambient = rgb(110, 115, 150), clock = 16.8, tint = rgb(220, 225, 255), sat = -0.05 },
	{ color = rgb(210, 170, 255), decay = rgb(120, 70, 200), density = 0.36, haze = 1.4, ambient = rgb(150, 120, 190), clock = 18.2, tint = rgb(240, 225, 255), sat = 0.25 },
	{ color = rgb(110, 70, 160), decay = rgb(40, 20, 70), density = 0.48, haze = 1.2, ambient = rgb(90, 70, 120), clock = 19.6, tint = rgb(215, 200, 255), sat = 0.1 },
	{ color = rgb(70, 80, 170), decay = rgb(20, 20, 60), density = 0.36, haze = 0.6, ambient = rgb(100, 100, 160), clock = 0.2, tint = rgb(210, 215, 255), sat = 0.2 },
}

local currentZone = -1
local function applyZone(zone: number)
	if zone == currentZone then
		return
	end
	currentZone = zone
	local a = ATMOS[zone] or ATMOS[0]
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine)
	if atm then
		TweenService:Create(atm, info, { Color = a.color, Decay = a.decay, Density = a.density, Haze = a.haze }):Play()
	end
	if cc then
		local ev = ReplicatedStorage:GetAttribute("EventId")
		local tint = a.tint
		if ev == "golden" then
			tint = tint:Lerp(rgb(255, 210, 120), 0.45)
		elseif ev == "bloodmoon" then
			tint = tint:Lerp(rgb(255, 110, 110), 0.5)
		end
		TweenService:Create(cc, info, { TintColor = tint, Saturation = a.sat }):Play()
	end
	TweenService:Create(Lighting, info, { OutdoorAmbient = a.ambient, ClockTime = a.clock }):Play()
	if zone > 0 and (zone > (WorldFX.lastBannerZone or 0) or os.clock() - (WorldFX.lastBannerAt or 0) > 25) then
		WorldFX.lastBannerZone = zone
		WorldFX.lastBannerAt = os.clock()
		local b = Biomes.List[zone]
		Notify.big(string.upper(b.name), "⚡ Speed " .. b.speed .. " to escape " .. b.guardian, b.color:Lerp(rgb(255, 255, 255), 0.3))
	elseif zone == 0 then
		WorldFX.lastBannerZone = 0
	end
end

---------------------------------------------------------------------------
-- Meteors
---------------------------------------------------------------------------
local function onMeteor(pos: Vector3, fall: number)
	local start = pos + Vector3.new(math.random(-120, 120), 260, math.random(-120, 120))
	local rock = Instance.new("Part")
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.new(6, 6, 6)
	rock.Material = Enum.Material.Neon
	rock.Color = rgb(255, 130, 40)
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CFrame = CFrame.new(start)
	rock.Parent = workspace
	Effects.emitter(rock, { texture = Effects.Textures.FIRE, rate = 80, size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 1) }), color = ColorSequence.new(rgb(255, 230, 120), rgb(255, 60, 20)), lifetime = NumberRange.new(0.5, 0.8), speed = NumberRange.new(2, 5), transparency = NumberSequence.new(0.2, 1) })
	Effects.light(rock, rgb(255, 150, 60), 40, 3)
	local tw = TweenService:Create(rock, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(pos) })
	tw:Play()
	task.delay(fall, function()
		rock.Transparency = 1
		for _, e in ipairs(rock:GetChildren()) do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		local boom = Effects.emitter(rock, { texture = Effects.Textures.SPARKS, rate = 0, size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) }), color = rgb(255, 170, 60), speed = NumberRange.new(30, 60), lifetime = NumberRange.new(0.5, 1) })
		boom:Emit(60)
		local s = Instance.new("Sound")
		s.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
		s.Volume = 0.35
		s.RollOffMaxDistance = 300
		s.Parent = rock
		s:Play()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - pos).Magnitude < 80 then
			ToolController.shake(0.4, 0.8)
		end
		task.delay(2, function()
			rock:Destroy()
		end)
	end)
end

---------------------------------------------------------------------------
-- Shopkeepers + statue idle animation
---------------------------------------------------------------------------
local idleRigs = {}
local function collectIdle()
	local shops = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub") and workspace.World.Hub:FindFirstChild("Shops")
	if not shops then
		return
	end
	for _, shop in ipairs(shops:GetChildren()) do
		local keeper = shop:FindFirstChild("Keeper")
		if keeper and not idleRigs[keeper] then
			local motors = {}
			for _, m in ipairs(keeper:GetDescendants()) do
				if m:IsA("Motor6D") then
					motors[m.Name] = m
				end
			end
			idleRigs[keeper] = { motors = motors, phase = math.random() * 10 }
		end
	end
end

local function animateIdle()
	local t = os.clock()
	for keeper, rig in pairs(idleRigs) do
		if keeper.Parent then
			local m = rig.motors
			local ph = t + rig.phase
			if m.Body then
				m.Body.Transform = CFrame.new(0, math.abs(math.sin(ph * 2)) * 0.2, 0)
			end
			if m.Head then
				m.Head.Transform = CFrame.Angles(0, math.sin(ph * 0.7) * 0.3, math.sin(ph * 1.1) * 0.06)
			end
			if m.WingR then
				m.WingR.Transform = CFrame.Angles(0, 0, math.sin(ph * 4) * 0.3)
			end
			if m.WingL then
				m.WingL.Transform = CFrame.Angles(0, 0, -math.sin(ph * 4) * 0.3)
			end
			if m.Tail then
				m.Tail.Transform = CFrame.Angles(0, math.sin(ph * 2.5) * 0.3, 0)
			end
		else
			idleRigs[keeper] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Ambience: a box of particles that follows the camera, themed per zone,
-- plus lightning flashes over Thunder Cliffs.
---------------------------------------------------------------------------
local ambBox = Instance.new("Part")
ambBox.Name = "Ambience"
ambBox.Anchored = true
ambBox.CanCollide = false
ambBox.CanQuery = false
ambBox.CanTouch = false
ambBox.Transparency = 1
ambBox.Size = Vector3.new(120, 1, 120)
ambBox.Parent = workspace
local ambEmitters = {}
local SPARK = Effects.Textures.SPARKLE
local AMB = {
	[1] = { texture = SPARK, color = rgb(255, 250, 200), size = 0.25, rate = 6, speed = { 0.5, 1.5 }, accel = Vector3.new(0, 0.6, 0), life = { 4, 7 }, light = 1 }, -- fireflies
	[2] = { texture = Effects.Textures.SMOKE, color = rgb(240, 210, 150), size = 2.5, rate = 10, speed = { 6, 10 }, accel = Vector3.new(4, -0.5, 0), life = { 3, 5 }, light = 0, alpha = 0.75 }, -- blowing sand
	[3] = { texture = SPARK, color = rgb(255, 255, 255), size = 0.35, rate = 60, speed = { 2, 4 }, accel = Vector3.new(1, -5, 0), life = { 5, 8 }, light = 0.4 }, -- snow
	[4] = { texture = Effects.Textures.SPARKS, color = rgb(255, 130, 40), size = 0.3, rate = 30, speed = { 1, 3 }, accel = Vector3.new(0, 3, 0), life = { 3, 6 }, light = 1, up = true }, -- embers
	[5] = { texture = SPARK, color = rgb(190, 210, 255), size = 0.15, rate = 120, speed = { 50, 60 }, accel = Vector3.new(0, -30, 0), life = { 1, 1.4 }, light = 0.2, streak = true }, -- rain
	[6] = { texture = SPARK, color = rgb(230, 170, 255), size = 0.3, rate = 25, speed = { 0.5, 1.5 }, accel = Vector3.zero, life = { 3, 6 }, light = 1 }, -- crystal motes
	[7] = { texture = Effects.Textures.GLOW, color = rgb(150, 90, 230), size = 1.6, rate = 10, speed = { 0.5, 1.5 }, accel = Vector3.new(0, 0.5, 0), life = { 4, 7 }, light = 0.6, alpha = 0.6 }, -- wisps
	[8] = { texture = SPARK, color = rgb(255, 255, 220), size = 0.5, rate = 14, speed = { 40, 60 }, accel = Vector3.zero, life = { 0.8, 1.2 }, light = 1, streak = true, diag = true }, -- shooting stars
}
local function setAmbience(zone: number)
	for _, e in ipairs(ambEmitters) do
		e:Destroy()
	end
	ambEmitters = {}
	local a = AMB[zone]
	if not a then
		return
	end
	local e = Effects.emitter(ambBox, {
		texture = a.texture,
		rate = a.rate,
		color = a.color,
		size = NumberSequence.new(a.size),
		speed = NumberRange.new(a.speed[1], a.speed[2]),
		accel = a.accel,
		lifetime = NumberRange.new(a.life[1], a.life[2]),
		light = a.light,
		spread = a.streak and Vector2.new(5, 5) or Vector2.new(180, 180),
		transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, a.alpha or 0.15), NumberSequenceKeypoint.new(0.85, a.alpha or 0.15), NumberSequenceKeypoint.new(1, 1) }),
		dir = a.up and Enum.NormalId.Top or Enum.NormalId.Bottom,
	})
	if a.streak then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Size = NumberSequence.new(a.size * 3)
		e.Squash = NumberSequence.new(-2.5)
	end
	table.insert(ambEmitters, e)
end

local lastFlash = 0
local function lightningFlash()
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		return
	end
	local b = cc.Brightness
	cc.Brightness = b + 0.45
	TweenService:Create(cc, TweenInfo.new(0.35), { Brightness = b }):Play()
	task.delay(0.6, function()
		local s = Instance.new("Sound")
		s.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
		s.Volume = 0.18
		s.PlaybackSpeed = 0.5
		s.Parent = workspace.CurrentCamera
		s:Play()
		task.delay(3, function()
			s:Destroy()
		end)
	end)
end

-- Someone is carrying loot out of your base: red pulses + banner.
local function onAlarm(thiefId: number)
	local thief = Players:GetPlayerByUserId(thiefId)
	Notify.big("🚨 THIEF IN YOUR BASE!", (thief and thief.DisplayName or "Someone") .. " is stealing — slap them!", rgb(255, 70, 60))
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		return
	end
	task.spawn(function()
		for _ = 1, 3 do
			local base = cc.TintColor
			cc.TintColor = base:Lerp(rgb(255, 90, 90), 0.6)
			TweenService:Create(cc, TweenInfo.new(0.45), { TintColor = base }):Play()
			task.wait(0.55)
		end
	end)
end

function WorldFX.start()
	Net.event("Alarm").OnClientEvent:Connect(onAlarm)
	local ambZone = -1
	RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		local p = cam.CFrame.Position
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local zone = hrp and Layout.biomeAt(hrp.Position) or 0
		if zone ~= ambZone then
			ambZone = zone
			setAmbience(zone)
		end
		local a = AMB[zone]
		local height = (a and a.up) and -8 or 40
		if a and a.diag then
			ambBox.CFrame = CFrame.new(p + Vector3.new(-40, 70, 0)) * CFrame.Angles(0, 0, math.rad(-60))
		else
			ambBox.CFrame = CFrame.new(p + Vector3.new(0, height, 0))
		end
		if zone == 5 and os.clock() - lastFlash > 7 and math.random() < 0.004 then
			lastFlash = os.clock()
			lightningFlash()
		end
	end)
	Net.event("GuardianRoar").OnClientEvent:Connect(onRoar)
	Net.event("Meteor").OnClientEvent:Connect(onMeteor)
	RunService.RenderStepped:Connect(function()
		animateGuardians()
		animateIdle()
	end)
	task.spawn(function()
		while true do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				applyZone(Layout.biomeAt(hrp.Position))
			end
			collectIdle()
			task.wait(0.5)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("EventId"):Connect(function()
		local z = currentZone
		currentZone = -1
		applyZone(z)
	end)
end

return WorldFX
