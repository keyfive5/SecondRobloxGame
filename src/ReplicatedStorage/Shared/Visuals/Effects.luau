-- Particle and light effects for species auras, mutations and eggs.
-- Only uses Roblox's built-in particle textures, so nothing needs uploading.
local Effects = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local GLOW = "rbxasset://textures/particles/forcefield_glow_main.dds"

Effects.Textures = { SPARKLE = SPARKLE, FIRE = FIRE, SPARKS = SPARKS, SMOKE = SMOKE, GLOW = GLOW }

local function seq(a, b)
	if b == nil then
		return NumberSequence.new(a)
	end
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

function Effects.emitter(parent: Instance, p)
	local e = Instance.new("ParticleEmitter")
	e.Name = p.name or "Fx"
	e.Texture = p.texture or SPARKLE
	e.Rate = p.rate or 4
	e.Lifetime = p.lifetime or NumberRange.new(0.8, 1.4)
	e.Speed = p.speed or NumberRange.new(0.5, 1.5)
	e.SpreadAngle = p.spread or Vector2.new(180, 180)
	e.LightEmission = p.light or 1
	e.LightInfluence = p.lightInfluence or 0
	e.Color = typeof(p.color) == "ColorSequence" and p.color or ColorSequence.new(p.color or Color3.new(1, 1, 1))
	e.Size = p.size or seq(0.3, 0)
	e.Transparency = p.transparency or seq(0.1, 1)
	e.Acceleration = p.accel or Vector3.zero
	e.Drag = p.drag or 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = p.rotSpeed or NumberRange.new(-60, 60)
	e.EmissionDirection = p.dir or Enum.NormalId.Top
	e.Shape = p.shape or Enum.ParticleEmitterShape.Box
	e.ZOffset = p.zoffset or 0
	e.Parent = parent
	return e
end
local emitter = Effects.emitter

local function light(parent: Instance, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.2
	l.Shadows = false
	l.Parent = parent
	return l
end
Effects.light = light

local rgb = Color3.fromRGB

-- body: the dragon's body part (emitters fill its box); tip: the tail tip.
function Effects.speciesFx(body: BasePart, tip: BasePart, kind: string, s: number)
	if kind == "sparkle" then
		emitter(body, { rate = 3, size = seq(0.35 * s, 0), color = rgb(255, 250, 210) })
	elseif kind == "petals" then
		emitter(body, { texture = SPARKLE, rate = 3, size = seq(0.3 * s, 0.1 * s), color = rgb(255, 170, 210), accel = Vector3.new(0, -1, 0), light = 0.3 })
	elseif kind == "snow" then
		emitter(body, { rate = 4, size = seq(0.22 * s, 0.05 * s), color = rgb(230, 245, 255), accel = Vector3.new(0, -1.5, 0), light = 0.6 })
	elseif kind == "embers" then
		emitter(body, { texture = SPARKS, rate = 5, size = seq(0.25 * s, 0), color = rgb(255, 150, 50), accel = Vector3.new(0, 2, 0), speed = NumberRange.new(0.2, 0.8) })
	elseif kind == "fire" then
		emitter(tip, { texture = FIRE, rate = 14, size = seq(0.9 * s, 0.1 * s), color = ColorSequence.new(rgb(255, 220, 90), rgb(255, 70, 20)), lifetime = NumberRange.new(0.4, 0.7), speed = NumberRange.new(1, 2), accel = Vector3.new(0, 3, 0), spread = Vector2.new(15, 15), transparency = seq(0.2, 1) })
		emitter(body, { texture = SPARKS, rate = 4, size = seq(0.25 * s, 0), color = rgb(255, 170, 50), accel = Vector3.new(0, 3, 0) })
		light(body, rgb(255, 140, 50), 8 * s, 1.5)
	elseif kind == "sparks" then
		emitter(body, { texture = SPARKS, rate = 6, size = seq(0.3 * s, 0), color = rgb(150, 220, 255), speed = NumberRange.new(2, 4), lifetime = NumberRange.new(0.2, 0.4) })
		light(body, rgb(140, 200, 255), 7 * s, 1)
	elseif kind == "wisps" then
		emitter(body, { texture = GLOW, rate = 3, size = seq(0.6 * s, 0), color = rgb(200, 220, 255), accel = Vector3.new(0, 1, 0), transparency = seq(0.4, 1) })
	elseif kind == "smoke" then
		emitter(body, { texture = SMOKE, rate = 4, size = seq(1.0 * s, 2 * s), color = rgb(60, 30, 90), light = 0, lightInfluence = 0, accel = Vector3.new(0, 0.6, 0), transparency = seq(0.6, 1), speed = NumberRange.new(0.2, 0.6) })
	elseif kind == "stars" then
		emitter(body, { rate = 5, size = seq(0.35 * s, 0), color = rgb(255, 240, 170), speed = NumberRange.new(0.5, 1.5) })
		light(body, rgb(170, 190, 255), 7 * s, 0.8)
	elseif kind == "nebula" then
		emitter(body, { texture = GLOW, rate = 4, size = seq(1.2 * s, 0), color = ColorSequence.new(rgb(255, 120, 230), rgb(110, 170, 255)), transparency = seq(0.5, 1) })
	elseif kind == "disco" then
		emitter(body, { rate = 8, size = seq(0.3 * s, 0), color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 80, 200)), ColorSequenceKeypoint.new(0.5, rgb(80, 220, 255)), ColorSequenceKeypoint.new(1, rgb(255, 240, 80)) }), speed = NumberRange.new(2, 4) })
		light(body, rgb(255, 120, 230), 10 * s, 1.5)
	elseif kind == "void" then
		emitter(body, { texture = GLOW, rate = 6, size = seq(1.5 * s, 0), color = rgb(20, 0, 40), light = 0, transparency = seq(0.3, 1), speed = NumberRange.new(-1.5, -0.5) })
		emitter(body, { rate = 3, size = seq(0.3 * s, 0), color = rgb(255, 255, 255) })
	end
end

function Effects.mutationFx(body: BasePart, mut: string, s: number)
	if mut == "gold" then
		emitter(body, { rate = 3, size = seq(0.4 * s, 0), color = rgb(255, 225, 120), name = "MutFx" })
	elseif mut == "diamond" then
		emitter(body, { rate = 5, size = seq(0.45 * s, 0), color = rgb(220, 245, 255), name = "MutFx" })
		light(body, rgb(170, 230, 255), 6 * s, 0.8)
	elseif mut == "rainbow" then
		emitter(body, { rate = 6, size = seq(0.4 * s, 0), color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 80, 80)), ColorSequenceKeypoint.new(0.33, rgb(255, 230, 80)),
			ColorSequenceKeypoint.new(0.66, rgb(80, 220, 255)), ColorSequenceKeypoint.new(1, rgb(200, 90, 255)),
		}), name = "MutFx" })
	elseif mut == "lava" then
		emitter(body, { texture = SPARKS, rate = 6, size = seq(0.3 * s, 0), color = rgb(255, 130, 40), accel = Vector3.new(0, 3, 0), name = "MutFx" })
		light(body, rgb(255, 120, 40), 7 * s, 1.2)
	elseif mut == "frozen" then
		emitter(body, { rate = 4, size = seq(0.25 * s, 0.05 * s), color = rgb(230, 245, 255), accel = Vector3.new(0, -1.5, 0), name = "MutFx" })
	elseif mut == "blood" then
		emitter(body, { texture = GLOW, rate = 4, size = seq(0.8 * s, 0), color = rgb(255, 30, 40), transparency = seq(0.5, 1), name = "MutFx" })
		light(body, rgb(255, 40, 50), 7 * s, 1.2)
	elseif mut == "galaxy" then
		emitter(body, { rate = 8, size = seq(0.35 * s, 0), color = rgb(255, 255, 255), name = "MutFx" })
		emitter(body, { texture = GLOW, rate = 3, size = seq(1.2 * s, 0), color = ColorSequence.new(rgb(140, 80, 255), rgb(60, 160, 255)), transparency = seq(0.6, 1), name = "MutFx" })
		light(body, rgb(150, 110, 255), 8 * s, 1.2)
	end
end

-- Toggle every emitter/light under a model (distance LOD on clients).
function Effects.setEnabled(root: Instance, on: boolean)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = on
		end
	end
end

return Effects
