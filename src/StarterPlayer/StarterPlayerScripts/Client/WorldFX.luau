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
	if zone > 0 then
		local b = Biomes.List[zone]
		Notify.big(string.upper(b.name), "⚡ Speed " .. b.speed .. " to escape " .. b.guardian, b.color:Lerp(rgb(255, 255, 255), 0.3))
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

function WorldFX.start()
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
