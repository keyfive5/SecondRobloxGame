-- Builds dragon eggs: a biome-colored shell with spots, plus decoration that gets
-- fancier with rarity (bands, crowns of spikes, gold, neon, rainbow).
-- Model space: egg centered at its origin, 2 wide x 2.6 tall at scale 1.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent.Parent
local Biomes = require(Shared.Biomes)
local Rarity = require(Shared.Rarity)
local Effects = require(script.Parent.Effects)

local EggBuilder = {}

EggBuilder.RainbowTag = "RainbowPart"

local rgb = Color3.fromRGB

local function shapes(): Folder
	return ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Shapes")
end

local function quiet(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- Radius of the shell at height y (egg space, scale 1). The shell is a bottom
-- hemisphere of radius 1 joined at y = -0.3 to a top half-ellipsoid 1.6 tall.
local function radiusAt(y: number): number
	local yy = y + 0.3
	if yy >= 0 then
		return math.sqrt(math.max(0, 1 - (yy / 1.6) ^ 2))
	end
	return math.sqrt(math.max(0, 1 - yy * yy))
end
EggBuilder.radiusAt = radiusAt

-- Point + outward normal on the shell for azimuth a and height y.
local function surface(a: number, y: number): (Vector3, Vector3)
	local r = radiusAt(y)
	local yy = y + 0.3
	local p = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	local ny = yy >= 0 and yy / (1.6 * 1.6) or yy
	local n = Vector3.new(p.X, ny, p.Z)
	return p, (n.Magnitude > 0 and n.Unit or Vector3.yAxis)
end

-- biome: index (0 = secret egg). opts: { scale, anchored, fx }
function EggBuilder.build(biome: number, rarity: string, origin: CFrame, opts)
	opts = opts or {}
	local s = opts.scale or 1
	local model = Instance.new("Model")
	model.Name = "Egg"
	model:SetAttribute("Scale", s)

	local secret = rarity == "Secret" or biome == 0
	local b = Biomes.List[biome]
	local pal = b and b.egg or { base = rgb(25, 22, 30), spot = rgb(255, 255, 255), spotNeon = true }
	local rcol = Rarity.color(rarity)
	local rank = Rarity.rank(rarity)

	local shell = shapes().Egg:Clone()
	quiet(shell)
	shell.Name = "Shell"
	shell.Size = shell.Size * s
	shell.CFrame = origin
	shell.Color = secret and rgb(18, 16, 24) or pal.base
	shell.Material = pal.mat and Enum.Material[pal.mat] or Enum.Material.SmoothPlastic
	shell.Reflectance = pal.mat == "Glass" and 0.15 or 0.05
	shell.Anchored = opts.anchored ~= false
	shell.Parent = model
	model.PrimaryPart = shell

	local function add(shape: string, size: Vector3, cf: CFrame, color: Color3, mat: string?, alpha: number?)
		local p: BasePart
		if shape == "Ball" then
			p = Instance.new("Part")
			p.Shape = Enum.PartType.Ball
		elseif shape == "Block" then
			p = Instance.new("Part")
		else
			p = shapes()[shape]:Clone()
		end
		quiet(p)
		p.Size = size * s
		p.CFrame = origin * (cf - cf.Position + cf.Position * s)
		p.Color = color
		p.Material = mat and Enum.Material[mat] or Enum.Material.SmoothPlastic
		p.Transparency = alpha or 0
		p.CastShadow = false
		local w = Instance.new("Weld")
		w.Part0 = shell
		w.Part1 = p
		w.C0 = shell.CFrame:ToObjectSpace(p.CFrame)
		w.Parent = p
		p.Parent = model
		return p
	end

	local function band(y: number, color: Color3, mat: string?, height: number?)
		local r = radiusAt(y) * 2 + 0.06
		return add("Ring", Vector3.new(height or 0.18, r, r), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), color, mat)
	end

	-- spots
	local rng = Random.new(biome * 31 + rank * 7)
	local spotColor = pal.spot
	local spotMat = pal.spotNeon and "Neon" or nil
	local nSpots = 9
	for i = 1, nSpots do
		local a = (i / nSpots) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local y = rng:NextNumber(-0.9, 0.95)
		local pos, n = surface(a, y)
		local size = rng:NextNumber(0.28, 0.48)
		add("Ellipsoid", Vector3.new(size, size * 0.85, 0.08), CFrame.lookAt(pos, pos + n), spotColor, spotMat)
	end

	-- rarity decoration
	if rarity == "Uncommon" then
		band(-0.05, rcol)
	elseif rarity == "Rare" then
		band(0.2, rcol)
		band(-0.35, rcol)
	elseif rarity == "Epic" then
		band(-0.1, rcol, nil, 0.24)
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			local pos, n = surface(a, 0.12)
			add("Cone", Vector3.new(0.28, 0.4, 0.12), CFrame.lookAt(pos, pos + n:Cross(Vector3.yAxis)) * CFrame.new(0, 0.1, 0), rcol)
		end
	elseif rarity == "Legendary" then
		band(0.3, rcol, "Foil", 0.2)
		band(-0.1, rcol, "Foil", 0.26)
		band(-0.5, rcol, "Foil", 0.2)
		add("Ball", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 1.32, 0), rgb(255, 80, 110), "Glass")
	elseif rarity == "Mythic" then
		band(0.45, rcol, "Neon", 0.16)
		band(-0.1, rcol, "Neon", 0.24)
		band(-0.65, rcol, "Neon", 0.16)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local pos, n = surface(a, -0.1)
			add("Cone", Vector3.new(0.22, 0.5, 0.22), CFrame.lookAt(pos, pos + n) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, 0.15, 0), rgb(255, 230, 240), "Glass")
		end
	end
	if secret then
		for i, y in ipairs({ 0.6, 0.15, -0.3, -0.75 }) do
			local p = band(y, Color3.fromHSV(i / 4, 1, 1), "Neon", 0.2)
			CollectionService:AddTag(p, EggBuilder.RainbowTag)
		end
		add("Ball", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.35, 0), rgb(255, 255, 255), "Neon")
	end

	-- glow + particles for the good stuff
	if opts.fx ~= false then
		if rank >= 4 or secret then
			Effects.emitter(shell, {
				rate = secret and 10 or (rank * 1.5), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * s), NumberSequenceKeypoint.new(1, 0) }),
				color = secret and ColorSequence.new({
					ColorSequenceKeypoint.new(0, rgb(255, 80, 80)), ColorSequenceKeypoint.new(0.5, rgb(80, 255, 200)), ColorSequenceKeypoint.new(1, rgb(200, 90, 255)),
				}) or rcol:Lerp(Color3.new(1, 1, 1), 0.4),
				speed = NumberRange.new(0.5, 1.5),
			})
		end
		if rank >= 3 or secret then
			Effects.light(shell, secret and rgb(255, 255, 255) or rcol, (secret and 12 or 3 + rank) * s, secret and 1.2 or 0.25 + rank * 0.08)
		end
	end
	return model
end

return EggBuilder
