-- Edit-time "photo studio" for marketing renders: puts one dragon/egg on a flat
-- magenta backdrop high above the map so tools/photo.mjs can capture it and
-- tools/key.py can cut it out. Usage (placeholders filled in by photo.mjs):
--   KIND = "dragon" | "egg" | "clear";  ARGS = { ... }
--#include build/lib.luau
local KIND = "%KIND%"
local ARGS = game:GetService("HttpService"):JSONDecode([[%ARGS%]])
local Lighting = game:GetService("Lighting")
local DragonBuilder = require(Shared.Visuals.DragonBuilder)
local EggBuilder = require(Shared.Visuals.EggBuilder)
local Species = require(Shared.Species)

local STAGE = Vector3.new(0, 3000, 0)

local stage = workspace:FindFirstChild("PhotoStage")
if stage then
	stage:Destroy()
end
if KIND == "clear" then
	local b = Lighting:FindFirstChild("BloomEffect")
	if b then
		b.Enabled = true
	end
	cleanupFresh()
	return "cleared"
end
stage = Instance.new("Folder")
stage.Name = "PhotoStage"
stage.Parent = workspace
local b = Lighting:FindFirstChild("BloomEffect")
if b then
	b.Enabled = false
end

-- backdrop: a big magenta shell around the subject
local back = Instance.new("Part")
back.Name = "Backdrop"
back.Anchored = true
back.CanCollide = false
back.Material = Enum.Material.Neon
back.Color = Color3.fromRGB(255, 0, 255)
back.Size = Vector3.new(400, 400, 1)
back.CastShadow = false
back.Parent = stage

local model
if KIND == "dragon" then
	local sp = Species.get(ARGS.sp)
	local look = table.clone(sp.look)
	if ARGS.horn then
		look.horn = ARGS.horn
	end
	model = DragonBuilder.build(look, CFrame.new(STAGE) * CFrame.Angles(0, math.rad(ARGS.yaw or -12), 0), { scale = ARGS.scale or 1, mutation = ARGS.mut, angry = ARGS.angry, fx = false })
	-- a nice wing pose
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") then
			if m.Name == "WingR" then
				m.Transform = CFrame.Angles(0, 0, 0.25)
			elseif m.Name == "WingL" then
				m.Transform = CFrame.Angles(0, 0, -0.25)
			elseif m.Name == "Head" then
				m.Transform = CFrame.Angles(ARGS.headTilt or 0, 0, 0.08)
			end
		end
	end
else
	model = EggBuilder.build(ARGS.b or 1, ARGS.r or "Common", CFrame.new(STAGE + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, math.rad(ARGS.yaw or -12), math.rad(ARGS.tilt or -8)), { scale = ARGS.scale or 1, fx = false })
end
for _, p in ipairs(model:GetDescendants()) do
	if p:IsA("BasePart") then
		p.Anchored = true
	elseif p:IsA("ParticleEmitter") or p:IsA("PointLight") then
		p:Destroy()
	end
end
model.Parent = stage
local cf, size = model:GetBoundingBox()
local center = cf.Position
local radius = size.Magnitude * 0.5
-- camera in front (-Z) and a little above; backdrop far behind
local camDir = Vector3.new(ARGS.camX or 0.5, ARGS.camY or 0.3, -1).Unit
local dist = radius / math.tan(math.rad(35)) * (ARGS.zoom or 0.92)
local camPos = center + camDir * dist
back.CFrame = CFrame.lookAt(center - camDir * (radius + 40), center)
cleanupFresh()
return string.format("%.2f %.2f %.2f %.2f %.2f %.2f", camPos.X, camPos.Y, camPos.Z, center.X, center.Y, center.Z)
