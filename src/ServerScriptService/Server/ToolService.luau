-- Slap + gear tools. Tools are built on the server and handed out on spawn;
-- clients report activation through the "UseTool" remote and the server does
-- every check (range, cooldown, ownership).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Gear = require(Shared.Gear)
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local PlayerService = require(script.Parent.PlayerService)
local Sync = require(script.Parent.Sync)

local ToolService = {}

local knockEvent = Net.event("Knockback")
local fxEvent = Net.event("ToolFx")
local cooldowns = {} -- [player] = { [toolId] = clockReadyAt }
local traps = {} -- [player] = { model... }

local rgb = Color3.fromRGB

local function dataOf(player: Player)
	local p = DataService.get(player)
	return p and p.data
end

local function hrpOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function ready(player: Player, id: string, cd: number): boolean
	cooldowns[player] = cooldowns[player] or {}
	local t = cooldowns[player][id] or 0
	if os.clock() < t then
		return false
	end
	cooldowns[player][id] = os.clock() + cd
	return true
end

---------------------------------------------------------------------------
-- Tool models
---------------------------------------------------------------------------
local function handle(size: Vector3, color: Color3, material, shape)
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = size
	h.Color = color
	h.Material = material or Enum.Material.SmoothPlastic
	if shape then
		h.Shape = shape
	end
	h.CanCollide = false
	h.Massless = true
	return h
end

local function weldTo(h: BasePart, p: BasePart, cf: CFrame)
	p.CFrame = h.CFrame * cf
	p.CanCollide = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = h
	w.Part1 = p
	w.Parent = p
	p.Parent = h.Parent
end

local function makeTool(id: string, name: string)
	local t = Instance.new("Tool")
	t.Name = name
	t.CanBeDropped = false
	t.RequiresHandle = true
	t:SetAttribute("Gear", id)
	return t
end

local function buildSlap(tier)
	local t = makeTool("slap", tier.name)
	t.ToolTip = "Slap thieves to make them drop their loot!"
	local h = handle(Vector3.new(1.4, 1.6, 0.7), tier.color, tier.id == "golden" and Enum.Material.Foil or (tier.id == "diamond" and Enum.Material.Glass or (tier.id == "galaxy" and Enum.Material.Neon or Enum.Material.SmoothPlastic)))
	h.Parent = t
	-- fingers
	for i = -1, 1 do
		local f = Instance.new("Part")
		f.Size = Vector3.new(0.38, 0.9, 0.5)
		f.Color = tier.color
		f.Material = h.Material
		weldTo(h, f, CFrame.new(i * 0.42, 1.15, 0))
	end
	local thumb = Instance.new("Part")
	thumb.Size = Vector3.new(0.38, 0.75, 0.45)
	thumb.Color = tier.color
	thumb.Material = h.Material
	weldTo(h, thumb, CFrame.new(0.85, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-40)))
	t.Grip = CFrame.new(0, -0.6, 0)
	return t
end

local function buildItem(item)
	local t = makeTool(item.id, item.name)
	t.ToolTip = item.desc
	local h
	if item.id == "speedcoil" or item.id == "gravity" then
		h = handle(Vector3.new(0.6, 1.6, 0.6), item.id == "speedcoil" and rgb(60, 160, 255) or rgb(160, 90, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
		h.Size = Vector3.new(1.6, 0.6, 0.6)
	elseif item.id == "trap" then
		h = handle(Vector3.new(1.6, 0.4, 1.6), rgb(140, 140, 150), Enum.Material.Metal)
	elseif item.id == "net" then
		h = handle(Vector3.new(0.6, 0.6, 2.2), rgb(90, 80, 70), Enum.Material.Wood)
	else
		h = handle(Vector3.new(1.4, 1.8, 0.2), rgb(120, 200, 255), Enum.Material.Glass)
		h.Transparency = 0.4
	end
	h.Parent = t
	return t
end

local function giveTools(player: Player)
	local data = dataOf(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	for _, t in ipairs(backpack:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("Gear") then
			t:Destroy()
		end
	end
	local char = player.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("Gear") then
				t:Destroy()
			end
		end
	end
	buildSlap(Gear.slap(data.gear.slap)).Parent = backpack
	for _, item in ipairs(Gear.Items) do
		if data.gear.items[item.id] then
			local tool = buildItem(item)
			tool.Parent = backpack
			if item.id == "speedcoil" then
				tool.Equipped:Connect(function()
					PlayerService.setSpeedExtra(player, "coil", 12)
				end)
				tool.Unequipped:Connect(function()
					PlayerService.setSpeedExtra(player, "coil", nil)
				end)
			elseif item.id == "gravity" then
				local force
				tool.Equipped:Connect(function()
					local hrp = hrpOf(player)
					if not hrp then
						return
					end
					local att = hrp:FindFirstChild("RootAttachment") or Instance.new("Attachment", hrp)
					force = Instance.new("VectorForce")
					force.Name = "GravityCoil"
					force.Attachment0 = att
					force.RelativeTo = Enum.ActuatorRelativeTo.World
					local mass = 0
					for _, p in ipairs(player.Character:GetDescendants()) do
						if p:IsA("BasePart") then
							mass += p:GetMass()
						end
					end
					force.Force = Vector3.new(0, mass * workspace.Gravity * 0.72, 0)
					force.Parent = hrp
				end)
				tool.Unequipped:Connect(function()
					if force then
						force:Destroy()
						force = nil
					end
				end)
			end
		end
	end
end
ToolService.giveTools = giveTools

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function knock(victim: Player, vel: Vector3, kind: string)
	knockEvent:FireClient(victim, vel, kind)
end

local function hitPlayer(victim: Player, reason: string)
	if CarryService.get(victim) then
		CarryService.drop(victim, reason)
	end
end

local function doSlap(player: Player)
	local data = dataOf(player)
	local hrp = hrpOf(player)
	if not data or not hrp then
		return
	end
	if not ready(player, "slap", Config.SlapCooldown) then
		return
	end
	local tier = Gear.slap(data.gear.slap)
	local best, bestD
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local ohrp = hrpOf(other)
			if ohrp then
				local off = ohrp.Position - hrp.Position
				local d = off.Magnitude
				if d <= tier.range and (d < 3 or hrp.CFrame.LookVector:Dot(off.Unit) > 0.1) then
					if not bestD or d < bestD then
						best, bestD = other, d
					end
				end
			end
		end
	end
	fxEvent:FireAllClients("slap", player.UserId, best and best.UserId or nil)
	if best then
		local ohrp = hrpOf(best)
		local dir = (ohrp.Position - hrp.Position) * Vector3.new(1, 0, 1)
		dir = dir.Magnitude > 0.1 and dir.Unit or hrp.CFrame.LookVector
		knock(best, dir * tier.power + Vector3.new(0, tier.power * 0.45, 0), "slap")
		hitPlayer(best, "slap")
	end
end

local function placeTrap(player: Player)
	local hrp = hrpOf(player)
	local slot = BaseService.slot(player)
	if not hrp or not slot then
		return
	end
	if not Layout.inBase(slot, hrp.Position) then
		Sync.notify(player, "🪤 Traps can only be placed inside your base.", "bad")
		return
	end
	if not ready(player, "trap", Gear.item("trap").cooldown) then
		return
	end
	traps[player] = traps[player] or {}
	if #traps[player] >= 3 then
		local old = table.remove(traps[player], 1)
		old:Destroy()
	end
	local trap = Instance.new("Part")
	trap.Name = "BearTrap"
	trap.Size = Vector3.new(3.4, 0.5, 3.4)
	trap.Shape = Enum.PartType.Cylinder
	trap.Size = Vector3.new(0.5, 3.4, 3.4)
	trap.CFrame = CFrame.new(hrp.Position.X, Layout.FloorTop + 0.25, hrp.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	trap.Anchored = true
	trap.CanCollide = false
	trap.Color = rgb(120, 120, 130)
	trap.Material = Enum.Material.Metal
	trap.Parent = workspace
	for i = 0, 7 do
		local tooth = Instance.new("Part")
		tooth.Size = Vector3.new(0.3, 0.7, 0.3)
		tooth.Anchored = true
		tooth.CanCollide = false
		tooth.CanTouch = false
		tooth.Color = rgb(220, 220, 230)
		tooth.Material = Enum.Material.Metal
		local a = i / 8 * math.pi * 2
		tooth.CFrame = CFrame.new(hrp.Position.X + math.cos(a) * 1.4, Layout.FloorTop + 0.7, hrp.Position.Z + math.sin(a) * 1.4)
		tooth.Parent = trap
	end
	table.insert(traps[player], trap)
	local sprung = false
	trap.Touched:Connect(function(hit)
		local victim = Players:GetPlayerFromCharacter(hit.Parent)
		if sprung or not victim or victim == player then
			return
		end
		sprung = true
		PlayerService.stun(victim, 3)
		hitPlayer(victim, "trap")
		fxEvent:FireAllClients("trap", victim.UserId, nil, trap.Position)
		Sync.notify(victim, "🪤 You stepped in a bear trap!", "bad")
		Sync.notify(player, "🪤 Your trap caught " .. victim.DisplayName .. "!", "good")
		local list = traps[player]
		if list then
			local i = table.find(list, trap)
			if i then
				table.remove(list, i)
			end
		end
		Debris:AddItem(trap, 0.5)
	end)
	Sync.notify(player, "🪤 Trap set!", "good")
end

local function fireNet(player: Player, target: Vector3?)
	local hrp = hrpOf(player)
	if not hrp or typeof(target) ~= "Vector3" then
		return
	end
	if not ready(player, "net", Gear.item("net").cooldown) then
		return
	end
	local dir = (target - hrp.Position)
	if dir.Magnitude < 1 then
		return
	end
	dir = dir.Unit
	local range = 70
	-- find the first player near the line
	local best, bestT
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local ohrp = hrpOf(other)
			if ohrp then
				local rel = ohrp.Position - hrp.Position
				local t = rel:Dot(dir)
				if t > 0 and t < range and (rel - dir * t).Magnitude < 5 then
					if not bestT or t < bestT then
						best, bestT = other, t
					end
				end
			end
		end
	end
	local hitPos = best and hrpOf(best).Position or (hrp.Position + dir * range)
	fxEvent:FireAllClients("net", player.UserId, best and best.UserId or nil, hrp.Position, hitPos)
	if best then
		PlayerService.stun(best, 2.5)
		hitPlayer(best, "net")
	end
end

local function cloak(player: Player)
	local char = player.Character
	if not char then
		return
	end
	if not ready(player, "cloak", Gear.item("cloak").cooldown) then
		return
	end
	player:SetAttribute("Invisible", true)
	local saved = {}
	for _, p in ipairs(char:GetDescendants()) do
		if (p:IsA("BasePart") and p.Name ~= "HumanoidRootPart") or p:IsA("Decal") then
			saved[p] = p.Transparency
			p.Transparency = 0.92
		end
	end
	fxEvent:FireAllClients("cloak", player.UserId)
	task.delay(8, function()
		for p, t in pairs(saved) do
			if p.Parent then
				p.Transparency = t
			end
		end
		if player.Parent then
			player:SetAttribute("Invisible", nil)
		end
	end)
end

function ToolService.start()
	Net.event("UseTool").OnServerEvent:Connect(function(player, id, target)
		local char = player.Character
		if not char then
			return
		end
		-- must actually be holding that tool
		local tool = char:FindFirstChildOfClass("Tool")
		if not tool or tool:GetAttribute("Gear") ~= id then
			return
		end
		if id == "slap" then
			doSlap(player)
		elseif id == "trap" then
			placeTrap(player)
		elseif id == "net" then
			fireNet(player, target)
		elseif id == "cloak" then
			cloak(player)
		end
	end)
	DataService.Loaded:Connect(function(player)
		if player.Character then
			task.defer(giveTools, player)
		end
		player.CharacterAdded:Connect(function()
			task.defer(giveTools, player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		for _, t in ipairs(traps[player] or {}) do
			t:Destroy()
		end
		traps[player] = nil
	end)
end

return ToolService
