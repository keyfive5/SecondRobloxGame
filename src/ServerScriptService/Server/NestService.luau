-- Nests, eggs and the giant guardian dragons.
--
-- Each biome's nest holds Config.EggsPerNest eggs. Grabbing one wakes the biome's
-- guardian, which chases the carrier until they leave the biome (through its gate
-- toward the hub) or get caught - then the egg flies back to the nest.
-- Guardians are unanchored, server-owned models pushed by AlignPosition so their
-- motion replicates smoothly; clients animate their wings.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Biomes = require(Shared.Biomes)
local Species = require(Shared.Species)
local Rarity = require(Shared.Rarity)
local Net = require(Shared.Net)
local Products = require(Shared.Products)
local DragonBuilder = require(Shared.Visuals.DragonBuilder)
local EggBuilder = require(Shared.Visuals.EggBuilder)

local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local Sync = require(script.Parent.Sync)
local WorldState = require(script.Parent.WorldState)

local NestService = {}

local rng = Random.new()
local nests = {} -- [biome] = { [slot] = { model, rarity, respawnAt } }
local secretEgg = nil -- { biome, model }
local groundEggs = {} -- [model] = { b, r, zone, expires, slot }
local guardians = {} -- [biome] = state

local buyRequested = Instance.new("BindableEvent")
NestService.BuyRequested = buyRequested.Event -- (player, egg = { b, r, zone, slot })

local roarEvent = Net.event("GuardianRoar")
local knockEvent = Net.event("Knockback")

local eggFolder = Instance.new("Folder")
eggFolder.Name = "NestEggs"
eggFolder.Parent = workspace
local guardFolder = Instance.new("Folder")
guardFolder.Name = "Guardians"
guardFolder.Parent = workspace

local SECRET_SLOT = 0

---------------------------------------------------------------------------
-- Eggs
---------------------------------------------------------------------------
local function rollRarity(biome: number): string
	local weights = Biomes.List[biome].eggs
	local luck = WorldState.serverLuck()
	if WorldState.eventId() == "bloodmoon" then
		luck *= 1.5
	end
	local total = 0
	local list = {}
	for r, w in pairs(weights) do
		local rank = Rarity.rank(r)
		local ww = rank >= 3 and w * luck or w
		table.insert(list, { r = r, w = ww, rank = rank })
		total += ww
	end
	table.sort(list, function(a, b)
		return a.rank < b.rank
	end)
	local pick = rng:NextNumber() * total
	for _, e in ipairs(list) do
		pick -= e.w
		if pick <= 0 then
			return e.r
		end
	end
	return list[1].r
end

local function billboard(model: Model, text: string, color: Color3, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(160, 40)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = Color3.fromRGB(25, 15, 35)
	s.Parent = t
	t.Parent = bb
	bb.Parent = model.PrimaryPart
	return bb
end

local function eggPrompts(model: Model, rarity: string, onGrab, onBuy)
	local shell = model.PrimaryPart
	local att = Instance.new("Attachment")
	att.Parent = shell
	local grab = Instance.new("ProximityPrompt")
	grab.Name = "Grab"
	grab.ActionText = "Steal Egg"
	grab.ObjectText = rarity .. " Egg"
	grab.KeyboardKeyCode = Enum.KeyCode.E
	grab.HoldDuration = 0.35
	grab.MaxActivationDistance = 11
	grab.RequiresLineOfSight = false
	grab.UIOffset = Vector2.new(0, 0)
	grab.Parent = att
	grab.Triggered:Connect(onGrab)
	local product = Products.eggProduct(rarity)
	if onBuy and product and product.id ~= 0 then
		local att2 = Instance.new("Attachment")
		att2.Position = Vector3.new(0, -1.2, 0)
		att2.Parent = shell
		local buy = Instance.new("ProximityPrompt")
		buy.Name = "Buy"
		buy.ActionText = "Buy Safely"
		buy.ObjectText = "R$ " .. product.price .. " • skip the chase"
		buy.KeyboardKeyCode = Enum.KeyCode.F
		buy.GamepadKeyCode = Enum.KeyCode.ButtonY
		buy.HoldDuration = 0
		buy.MaxActivationDistance = 11
		buy.RequiresLineOfSight = false
		buy.Parent = att2
		buy:SetAttribute("EggBuy", rarity)
		buy.Triggered:Connect(onBuy)
	end
end

local function canTake(player: Player): boolean
	if CarryService.get(player) then
		return false
	end
	if not BaseService.slot(player) then
		return false
	end
	if BaseService.freeCount(player) < 1 then
		Sync.notify(player, "🏰 Your base is full! Sell a dragon or buy more pads.", "bad")
		return false
	end
	return true
end

local spawnEgg

local function grabFromNest(player: Player, biome: number, slot: number)
	local nest = nests[biome]
	local e = slot == SECRET_SLOT and secretEgg or nest[slot]
	if not e or not e.model or not canTake(player) then
		return
	end
	e.model:Destroy()
	e.model = nil
	local rarity = e.rarity
	local item
	if slot == SECRET_SLOT then
		secretEgg = nil
		item = { kind = "egg", b = 0, r = "Secret" }
		Sync.notifyAll(string.format("❓ %s grabbed the SECRET EGG! Stop them!", player.DisplayName), "rare")
	else
		e.respawnAt = os.clock() + rng:NextNumber(Config.EggRespawn[1], Config.EggRespawn[2])
		item = { kind = "egg", b = biome, r = rarity }
	end
	CarryService.start(player, item, { type = "nest", biome = biome, slot = slot, zone = biome })
	player:SetAttribute("CarryZone", biome)
end

function spawnEgg(biome: number, slot: number, rarity: string?)
	local nest = nests[biome]
	rarity = rarity or rollRarity(biome)
	local cf = Layout.nestEggCFrame(biome, slot, Config.EggsPerNest) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12))
	local model = EggBuilder.build(biome, rarity, cf, { scale = 1.3 })
	model.Name = "Egg_" .. biome .. "_" .. slot
	model:SetAttribute("Biome", biome)
	model:SetAttribute("Rarity", rarity)
	billboard(model, rarity .. " Egg", Rarity.color(rarity), 3.2)
	eggPrompts(model, rarity, function(player)
		grabFromNest(player, biome, slot)
	end, function(player)
		local e = nest[slot]
		if e and e.model then
			buyRequested:Fire(player, { b = biome, r = rarity, zone = biome, slot = slot })
		end
	end)
	model.Parent = eggFolder
	nest[slot] = { model = model, rarity = rarity, respawnAt = nil }
end

-- Called by MonetizationService after a "Buy Safely" receipt.
function NestService.takeForPurchase(biome: number, slot: number)
	local nest = nests[biome]
	local e = nest and nest[slot]
	if e and e.model then
		e.model:Destroy()
		e.model = nil
		e.respawnAt = os.clock() + rng:NextNumber(Config.EggRespawn[1], Config.EggRespawn[2])
	end
end

function NestService.spawnSecret(biome: number?)
	if secretEgg and secretEgg.model then
		secretEgg.model:Destroy()
	end
	biome = biome or rng:NextInteger(1, #Layout.Biomes)
	local info = Layout.Biomes[biome]
	local cf = CFrame.new(0, Layout.Ground + 4.2, info.nestZ)
	local model = EggBuilder.build(0, "Secret", cf, { scale = 1.8 })
	model.Name = "SecretEgg"
	billboard(model, "❓ SECRET EGG ❓", Color3.fromRGB(255, 255, 255), 4.5)
	eggPrompts(model, "Secret", function(player)
		grabFromNest(player, biome, SECRET_SLOT)
	end, nil)
	model.Parent = eggFolder
	secretEgg = { model = model, rarity = "Secret", biome = biome }
	ReplicatedStorage:SetAttribute("SecretEggBiome", biome)
	Sync.notifyAll(string.format("❓ A SECRET EGG appeared at %s's nest in %s! (Speed %d+)", Biomes.List[biome].guardian, Biomes.List[biome].name, Biomes.List[biome].speed), "rare")
	return biome
end

local function groundEgg(b: number, r: string, zone: number, slot: number?, pos: Vector3, life: number?, title: string?)
	local ray = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), (function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = { eggFolder, guardFolder, workspace:FindFirstChild("Characters") or Instance.new("Folder") }
		return p
	end)())
	local y = ray and ray.Position.Y or pos.Y - 2.5
	local model = EggBuilder.build(b, r, CFrame.new(pos.X, y + 1.6, pos.Z), { scale = 1.2 })
	model.Name = "DroppedEgg"
	billboard(model, title or ("Dropped " .. (r == "Secret" and "SECRET" or r) .. " Egg!"), Rarity.color(r == "Secret" and "Legendary" or r), 3)
	local entry = { b = b, r = r, zone = zone, slot = slot, expires = os.clock() + (life or Config.DroppedEggLife) }
	groundEggs[model] = entry
	eggPrompts(model, r, function(player)
		if not groundEggs[model] or not canTake(player) then
			return
		end
		groundEggs[model] = nil
		model:Destroy()
		CarryService.start(player, { kind = "egg", b = b, r = r }, { type = "ground", biome = zone, slot = slot, zone = zone })
		player:SetAttribute("CarryZone", zone)
	end, nil)
	model.Parent = eggFolder
end

-- An egg went back to its nest (guardian catch, expiry, carrier left).
local function returnEgg(b: number, r: string, zone: number, slot: number?)
	if r == "Secret" then
		NestService.spawnSecret(zone)
		return
	end
	local nest = nests[zone]
	if nest and slot and slot ~= SECRET_SLOT and nest[slot] and not nest[slot].model then
		spawnEgg(zone, slot, r)
	end
end

---------------------------------------------------------------------------
-- Guardians
---------------------------------------------------------------------------
local GUARD_LOOKS = {
	{ base = "sprout", body = Color3.fromRGB(70, 150, 60), horn = "long" },
	{ base = "sandy", body = Color3.fromRGB(214, 160, 80), horn = "long", extras = { "collar" } },
	{ base = "icicle", horn = "crystal" },
	{ base = "magma", horn = "long", extras = { "lavaspots", "crown" } },
	{ base = "storm", horn = "bolt" },
	{ base = "amethyst", horn = "crystal" },
	{ base = "shadow", horn = "long" },
	{ base = "cosmic", horn = "long" },
}

local function guardianLook(biome: number)
	local g = GUARD_LOOKS[biome]
	local look = table.clone(Species.get(g.base).look)
	if g.body then
		look.body = g.body
	end
	look.horn = g.horn or look.horn
	if g.extras then
		look.extras = g.extras
	end
	look.glowEyes = true
	return look
end

local function guardScale(biome: number): number
	return 6 + (biome - 1) * 0.35
end

local function setGuardLabel(g, text: string)
	local label = g.label
	if label then
		label.Text = text
	end
end

local function buildGuardian(biome: number)
	local rest = Layout.guardianRest(biome)
	local s = guardScale(biome)
	local model = DragonBuilder.build(guardianLook(biome), rest, { scale = s, angry = true, anchored = false })
	model.Name = "Guardian_" .. biome
	model:SetAttribute("Biome", biome)
	model:SetAttribute("Guardian", Biomes.List[biome].guardian)
	local root = model.PrimaryPart
	root.Massless = false
	root.Size = Vector3.new(4, 4, 4)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			if p ~= root then
				p.Massless = true
			end
		end
	end
	local att = Instance.new("Attachment")
	att.Name = "Drive"
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e9
	ap.Responsiveness = 120
	ap.MaxVelocity = Layout.Biomes[biome].guardSpeed
	ap.Position = rest.Position
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e9
	ao.Responsiveness = 30
	ao.CFrame = rest
	ao.Parent = root
	-- name tag
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 50)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4.6 * s, 0)
	bb.MaxDistance = 260
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 235, 200)
	t.Text = Biomes.List[biome].guardian .. " 💤"
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(30, 15, 20)
	st.Parent = t
	t.Parent = bb
	bb.Parent = root
	model:SetAttribute("State", "sleep")
	model.Parent = guardFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return {
		biome = biome, model = model, root = root, ap = ap, ao = ao, label = t,
		rest = rest, state = "sleep", target = nil, scale = s, wakeAt = 0,
	}
end

local function guardSpeed(g): number
	local sp = Layout.Biomes[g.biome].guardSpeed
	if WorldState.eventId() == "bloodmoon" then
		sp *= 1.12
	end
	if secretEgg == nil and g.chasingSecret then
		sp *= 1.1
	end
	return sp
end

local function inZone(biome: number, pos: Vector3): boolean
	local info = Layout.Biomes[biome]
	return pos.Z >= info.zStart - 2 and pos.Z <= info.zEnd + 30 and math.abs(pos.X) < info.halfWidth + 10
end

local function findTarget(g): (Player?, BasePart?)
	local best, bestHrp, bestD = nil, nil, math.huge
	for player, c in pairs(CarryService.all()) do
		if c.source.zone == g.biome and not player:GetAttribute("Invisible") then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and inZone(g.biome, hrp.Position) then
				local d = (hrp.Position - g.root.Position).Magnitude
				if d < bestD then
					best, bestHrp, bestD = player, hrp, d
				end
			end
		end
	end
	return best, bestHrp
end

local function flatLook(from: Vector3, to: Vector3): CFrame
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if dir.Magnitude < 0.01 then
		return CFrame.new(from)
	end
	return CFrame.lookAt(from, from + dir)
end

local function setState(g, state: string)
	g.state = state
	g.model:SetAttribute("State", state)
end

local function stepGuardian(g, dt: number)
	local info = Layout.Biomes[g.biome]
	local pos = g.root.Position
	if g.state == "sleep" or g.state == "return" then
		local player, hrp = findTarget(g)
		if player then
			-- already awake on its way home: turns around almost instantly
			g.wakeAt = os.clock() + (g.state == "return" and 0.3 or Layout.GuardWake)
			setState(g, "wake")
			g.target = player
			g.chasingSecret = CarryService.get(player) and CarryService.get(player).r == "Secret"
			setGuardLabel(g, Biomes.List[g.biome].guardian .. " 😡")
			roarEvent:FireAllClients(g.biome, player.UserId)
			g.ap.Position = pos + Vector3.new(0, 6, 0)
			g.ao.CFrame = flatLook(pos, hrp.Position)
			return
		end
		if g.state == "return" then
			g.ap.MaxVelocity = guardSpeed(g) * 0.8
			g.ap.Position = g.rest.Position
			g.ao.CFrame = flatLook(pos, g.rest.Position)
			if (pos - g.rest.Position).Magnitude < 4 then
				setState(g, "sleep")
				g.ao.CFrame = g.rest
				setGuardLabel(g, Biomes.List[g.biome].guardian .. " 💤")
			end
		end
		return
	end
	if g.state == "wake" then
		if os.clock() >= g.wakeAt then
			setState(g, "chase")
		end
		return
	end
	-- chase
	local player, hrp = findTarget(g)
	if not player then
		setState(g, "return")
		g.target = nil
		setGuardLabel(g, Biomes.List[g.biome].guardian)
		return
	end
	g.target = player
	local speed = guardSpeed(g)
	g.ap.MaxVelocity = speed
	local tp = hrp.Position
	local goal = Vector3.new(tp.X, Layout.Ground + 2.5, math.max(tp.Z, info.zStart - 2))
	g.ap.Position = goal
	g.ao.CFrame = flatLook(pos, tp)
	-- catch: horizontal distance from the guardian's root (its head is already
	-- over you at this range)
	local flat = Vector3.new(tp.X - pos.X, 0, tp.Z - pos.Z)
	if flat.Magnitude < Layout.GuardCatch and math.abs(tp.Y - pos.Y) < 10 * g.scale then
		local away = flat.Magnitude > 0.1 and flat.Unit or g.root.CFrame.LookVector
		CarryService.drop(player, "guardian", tp)
		knockEvent:FireClient(player, away * 95 + Vector3.new(0, 55, 0), "guardian")
		roarEvent:FireAllClients(g.biome, player.UserId, "catch")
		setState(g, "return")
		g.target = nil
		setGuardLabel(g, Biomes.List[g.biome].guardian)
	end
end

---------------------------------------------------------------------------
function NestService.start()
	for b = 1, #Layout.Biomes do
		nests[b] = {}
		for slot = 1, Config.EggsPerNest do
			spawnEgg(b, slot)
		end
		guardians[b] = buildGuardian(b)
	end

	CarryService.Dropped:Connect(function(player, c, reason, pos)
		if c.source.type == "base" or c.kind ~= "egg" then
			return
		end
		local zone = c.source.zone or c.b
		if (reason == "slap" or reason == "trap" or reason == "net") and pos then
			groundEgg(c.b, c.r, zone, c.source.slot, pos)
		else
			returnEgg(c.b, c.r, zone, c.source.slot)
		end
		player:SetAttribute("CarryZone", nil)
	end)
	CarryService.Delivered:Connect(function(player)
		player:SetAttribute("CarryZone", nil)
	end)

	-- refill nests + expire ground eggs
	task.spawn(function()
		while true do
			task.wait(0.5)
			local t = os.clock()
			for b, nest in pairs(nests) do
				for slot, e in pairs(nest) do
					if not e.model and e.respawnAt and t >= e.respawnAt then
						spawnEgg(b, slot)
					end
				end
			end
			for model, e in pairs(groundEggs) do
				if t >= e.expires then
					groundEggs[model] = nil
					model:Destroy()
					returnEgg(e.b, e.r, e.zone, e.slot)
				end
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, g in pairs(guardians) do
			if g.model.Parent then
				stepGuardian(g, dt)
			end
		end
	end)
end

-- Loose egg on the ground (meteor showers, events). zone 0 = no guardian cares.
function NestService.dropEgg(b: number, r: string, pos: Vector3, life: number?, title: string?)
	groundEgg(b, r, 0, nil, pos, life, title)
end

function NestService.rollRarity(biome: number): string
	return rollRarity(biome)
end

function NestService.guardians()
	return guardians
end

return NestService
