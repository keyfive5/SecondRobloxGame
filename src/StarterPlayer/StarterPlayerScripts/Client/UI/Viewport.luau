-- 3D icons rendered in ViewportFrames: dragons and eggs, slowly turning.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local DragonBuilder = require(Shared.Visuals.DragonBuilder)
local EggBuilder = require(Shared.Visuals.EggBuilder)

local Theme = require(script.Parent.Theme)

local Viewport = {}

local spinning = {} -- [ViewportFrame] = { model, speed }

local function frameCamera(vp: ViewportFrame, size: Vector3, center: Vector3, zoom: number?)
	local cam = vp.CurrentCamera or Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = size.Magnitude / (2 * math.tan(math.rad(15))) * (zoom or 0.82)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(0, size.Magnitude * 0.18, -dist), center)
	cam.Parent = vp
	vp.CurrentCamera = cam
end

local function makeFrame(parent: Instance, size: UDim2): ViewportFrame
	return Theme.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = size,
		Ambient = Color3.fromRGB(200, 200, 215),
		LightColor = Color3.fromRGB(255, 255, 250),
		LightDirection = Vector3.new(0.4, -1, 0.6),
		Parent = parent,
	})
end

local function strip(model: Model)
	for _, c in ipairs(model:GetDescendants()) do
		if c:IsA("ParticleEmitter") or c:IsA("PointLight") then
			c:Destroy()
		elseif c:IsA("BasePart") then
			c.Anchored = true
		end
	end
end

-- dragon: { sp, sz?, mut? }. silhouette = undiscovered (all black).
function Viewport.dragon(parent: Instance, d, size: UDim2?, silhouette: boolean?)
	local vp = makeFrame(parent, size or UDim2.fromScale(1, 1))
	local sp = Species.get(d.sp)
	if not sp then
		return vp
	end
	local model = DragonBuilder.build(sp.look, CFrame.new(), { mutation = d.mut, fx = false })
	strip(model)
	if silhouette then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Color = Color3.fromRGB(20, 18, 34)
				p.Material = Enum.Material.SmoothPlastic
				p.Transparency = p.Name == "Root" and 1 or 0
			end
		end
	end
	model.Parent = vp
	local cf, ext = model:GetBoundingBox()
	frameCamera(vp, ext, cf.Position)
	spinning[vp] = { model = model, speed = 0.6, center = cf.Position }
	vp.Destroying:Connect(function()
		spinning[vp] = nil
	end)
	return vp
end

function Viewport.egg(parent: Instance, biome: number, rarity: string, size: UDim2?)
	local vp = makeFrame(parent, size or UDim2.fromScale(1, 1))
	local model = EggBuilder.build(biome, rarity, CFrame.new(), { fx = false })
	strip(model)
	model.Parent = vp
	local cf, ext = model:GetBoundingBox()
	frameCamera(vp, ext, cf.Position, 0.95)
	spinning[vp] = { model = model, speed = 0.8, center = cf.Position }
	vp.Destroying:Connect(function()
		spinning[vp] = nil
	end)
	return vp
end

local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	for vp, s in pairs(spinning) do
		if vp.Parent and vp.Visible then
			local win = vp:FindFirstAncestorWhichIsA("LayerCollector")
			if win and win.Enabled then
				s.model:PivotTo(CFrame.Angles(0, math.sin(t * s.speed) * 0.7, 0))
			end
		end
	end
end)

return Viewport
