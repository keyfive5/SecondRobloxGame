-- Renders every base's pads on this client from ReplicatedStorage.BaseData:
-- animated dragons, wobbling eggs with hatch countdowns, live stored-cash labels,
-- and prompts (your base: hatch / sell; other bases: steal).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Species = require(Shared.Species)
local Traits = require(Shared.Traits)
local Value = require(Shared.Value)
local Rarity = require(Shared.Rarity)
local Products = require(Shared.Products)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local DragonBuilder = require(Shared.Visuals.DragonBuilder)
local EggBuilder = require(Shared.Visuals.EggBuilder)
local Effects = require(Shared.Visuals.Effects)

local Sounds = require(script.Parent.Sounds)
local Notify = require(script.Parent.UI.Notify)

local BaseRenderer = {}

local player = Players.LocalPlayer
local renderFolder = Instance.new("Folder")
renderFolder.Name = "BaseRender"
renderFolder.Parent = workspace

local stealEvent = Net.event("StealPad")
local collectEvent = Net.event("Collect")
local hatchFunc = Net.func("Hatch")
local sellFunc = Net.func("SellPad")
local hatchNowFunc = Net.func("RequestHatchNow")

local pads = {} -- [slot] = { [n] = rec }
local HIDE_RANGE = 330
local ANIM_RANGE = 150

local hatchedEvent = Instance.new("BindableEvent")
BaseRenderer.Hatched = hatchedEvent.Event -- (slot, n, dragon)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function mySlot(): number?
	return player:GetAttribute("BaseSlot")
end

local function folderOf(slot: number): Folder
	return ReplicatedStorage:WaitForChild("BaseData"):WaitForChild("Base_" .. slot)
end

local function decode(s: string)
	if s == "" then
		return nil
	end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, s)
	return ok and v or nil
end

local function stored(d): number
	if not d or d.k ~= "dragon" then
		return 0
	end
	return (d.s or 0) + (d.c or 0) * math.max(0, now() - (d.t or now()))
end

---------------------------------------------------------------------------
-- Labels
---------------------------------------------------------------------------
local function makeBillboard(adornee: BasePart, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "PadLabel"
	bb.Adornee = adornee
	-- sized in studs so labels shrink with distance instead of piling up
	bb.Size = UDim2.fromScale(7.5, 2.9)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.AlwaysOnTop = false
	local function line(name: string, y: number, h: number, color: Color3, font)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, h)
		t.Position = UDim2.fromScale(0, y)
		t.Font = font or Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = color
		t.RichText = true
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.Color = Color3.fromRGB(20, 14, 30)
		s.Parent = t
		t.Parent = bb
		return t
	end
	line("Title", 0, 0.3, Color3.new(1, 1, 1))
	line("Rate", 0.3, 0.27, Color3.fromRGB(140, 255, 150))
	line("Stored", 0.57, 0.43, Color3.fromRGB(255, 225, 90), Enum.Font.LuckiestGuy)
	bb.Parent = adornee
	return bb
end

---------------------------------------------------------------------------
-- Prompts
---------------------------------------------------------------------------
local function prompt(parent: Instance, action: string, object: string, key: Enum.KeyCode, hold: number, offsetY: number?)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, offsetY or 0, 0)
	att.Parent = parent
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = key
	p.GamepadKeyCode = key == Enum.KeyCode.E and Enum.KeyCode.ButtonX or Enum.KeyCode.ButtonY
	p.HoldDuration = hold
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = att
	return p
end

local function rarityOf(d): string
	if d.k == "dragon" then
		local sp = Species.get(d.sp)
		return sp and sp.rarity or "Common"
	end
	return d.r or "Common"
end

local function titleOf(d): string
	local r = rarityOf(d)
	local hex = Rarity.hex(r)
	if d.k == "dragon" then
		return string.format('<font color="%s">%s</font>', hex, Value.label(d))
	end
	return string.format('<font color="%s">%s Egg</font>', hex, r)
end

---------------------------------------------------------------------------
-- Build / clear
---------------------------------------------------------------------------
local function clearRec(rec)
	if rec.model then
		rec.model:Destroy()
	end
	rec.model = nil
	rec.bb = nil
	rec.prompts = {}
	rec.motors = nil
end

local function setupPrompts(slot: number, n: number, rec)
	local d = rec.data
	local root = rec.model and rec.model.PrimaryPart
	if not root then
		return
	end
	local own = slot == mySlot()
	if own then
		if d.k == "dragon" then
			local p = prompt(root, "Sell", "", Enum.KeyCode.F, 1.2, 1)
			p.Name = "Sell"
			p.MaxActivationDistance = 8
			p.Triggered:Connect(function()
				local price = sellFunc:InvokeServer(n)
				if price then
					Sounds.play("coins")
				end
			end)
			rec.prompts.sell = p
		else
			local hp = prompt(root, "Hatch!", "", Enum.KeyCode.E, 0, 0.5)
			hp.Name = "Hatch"
			hp.Triggered:Connect(function()
				hatchFunc:InvokeServer(n)
			end)
			rec.prompts.hatch = hp
			if Products.devId("HatchNow") ~= 0 then
				local np = prompt(root, "Hatch Now", "R$ " .. Products.DevByKey.HatchNow.price, Enum.KeyCode.F, 0, -0.8)
				np.Name = "HatchNow"
				np.Triggered:Connect(function()
					hatchNowFunc:InvokeServer(n)
				end)
				rec.prompts.hatchNow = np
			end
		end
	else
		local sp = prompt(root, "Steal", "", Enum.KeyCode.E, 1.4, 0.5)
		sp.Name = "Steal"
		sp.Triggered:Connect(function()
			stealEvent:FireServer(slot, n)
		end)
		rec.prompts.steal = sp
	end
end

local function build(slot: number, n: number, rec)
	clearRec(rec)
	local d = rec.data
	if not d then
		return
	end
	local cf = Layout.padCFrame(slot, n)
	local model
	if d.k == "dragon" then
		local sp = Species.get(d.sp)
		if not sp then
			return
		end
		local scale = Traits.size(d.sz).scale * 0.95
		model = DragonBuilder.build(sp.look, cf, { scale = scale, mutation = d.mut })
		rec.scale = scale
		rec.motors = {}
		for _, m in ipairs(model:GetDescendants()) do
			if m:IsA("Motor6D") then
				rec.motors[m.Name] = m
			end
		end
	else
		model = EggBuilder.build(d.b or 1, d.r or "Common", cf * CFrame.new(0, 1.35, 0), { scale = 1.0 })
		rec.scale = 1
	end
	model.Name = "Pad_" .. slot .. "_" .. n
	model:SetAttribute("Slot", slot)
	model:SetAttribute("Pad", n)
	model.Parent = renderFolder
	rec.model = model
	rec.phase = (slot * 7 + n * 3) % 10
	local height = d.k == "dragon" and (4.8 * rec.scale + 1.2) or 2.4
	rec.bb = makeBillboard(model.PrimaryPart, height)
	rec.bb.Title.Text = titleOf(d)
	setupPrompts(slot, n, rec)
end

local function identity(d): string
	if not d then
		return ""
	end
	if d.k == "dragon" then
		return "d|" .. d.sp .. "|" .. (d.sz or "") .. "|" .. (d.mut or "")
	end
	return "e|" .. tostring(d.b) .. "|" .. tostring(d.r)
end

local function refresh(slot: number, n: number)
	pads[slot] = pads[slot] or {}
	local rec = pads[slot][n]
	if not rec then
		rec = { prompts = {} }
		pads[slot][n] = rec
	end
	local value = folderOf(slot):FindFirstChild("P" .. n)
	local d = value and decode(value.Value)
	local changed = identity(d) ~= identity(rec.data) or rec.ownerAtBuild ~= (slot == mySlot())
	rec.data = d
	if changed then
		rec.ownerAtBuild = slot == mySlot()
		build(slot, n, rec)
	end
end

local function rebuildSlot(slot: number)
	for n = 1, Layout.MaxPads do
		local rec = pads[slot] and pads[slot][n]
		if rec then
			rec.ownerAtBuild = nil
		end
		refresh(slot, n)
	end
end

---------------------------------------------------------------------------
-- Per-frame: labels, prompts, animation, LOD
---------------------------------------------------------------------------
local function updateLabels()
	local t = now()
	local me = mySlot()
	local carrying = player:GetAttribute("Carrying") ~= nil
	for slot, list in pairs(pads) do
		local f = folderOf(slot)
		local locked = (f:GetAttribute("LockUntil") or 0) > t
		local shielded = (f:GetAttribute("ShieldUntil") or 0) > os.time()
		for n, rec in pairs(list) do
			local d = rec.data
			if d and rec.bb then
				local beingStolen = f:GetAttribute("S" .. n)
				if d.k == "dragon" then
					rec.bb.Rate.Text = Format.rate(d.c or 0)
					if slot == me then
						rec.bb.Stored.Text = beingStolen and ("🚨 STOLEN BY " .. string.upper(beingStolen)) or Format.cash(stored(d))
						if rec.prompts.sell then
							rec.prompts.sell.ObjectText = "for " .. Format.cash(math.floor((d.c or 0) * 45))
							rec.prompts.sell.Enabled = not beingStolen
						end
					else
						rec.bb.Stored.Text = beingStolen and "🚨 BEING STOLEN" or ""
					end
				else
					local left = (d.ready or 0) - t
					rec.bb.Rate.Text = left > 0 and ("🥚 Hatching in " .. Format.clock(left)) or "✨ Ready to hatch!"
					rec.bb.Stored.Text = beingStolen and "🚨 BEING STOLEN" or ""
					if rec.prompts.hatch then
						rec.prompts.hatch.Enabled = left <= 0.5 and not beingStolen
					end
					if rec.prompts.hatchNow then
						rec.prompts.hatchNow.Enabled = left > 0.5 and not beingStolen
					end
				end
				if rec.prompts.steal then
					rec.prompts.steal.Enabled = not locked and not shielded and not beingStolen and not carrying and f:GetAttribute("Owner") ~= nil
					rec.prompts.steal.ObjectText = d.k == "dragon" and Value.label(d) or ((d.r or "") .. " Egg")
				end
				if rec.model then
					local hide = beingStolen ~= nil
					if rec.hidden ~= hide then
						rec.hidden = hide
						for _, p in ipairs(rec.model:GetDescendants()) do
							if p:IsA("BasePart") and p.Name ~= "Root" then
								p.LocalTransparencyModifier = hide and 0.85 or 0
							end
						end
					end
				end
			end
		end
	end
end

local function animate(dt: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	for slot, list in pairs(pads) do
		local basePos = Layout.baseCFrame(slot).Position
		local far = (basePos - camPos).Magnitude > HIDE_RANGE
		for n, rec in pairs(list) do
			local model = rec.model
			if model then
				local wantParent = far and nil or renderFolder
				if model.Parent ~= wantParent then
					model.Parent = wantParent
				end
				if not far and rec.data and (model.PrimaryPart.Position - camPos).Magnitude < ANIM_RANGE then
					local ph = t + rec.phase
					if rec.motors then
						local m = rec.motors
						local s = rec.scale or 1
						if m.Body then
							m.Body.Transform = CFrame.new(0, math.abs(math.sin(ph * 2.2)) * 0.12 * s, 0)
						end
						if m.Head then
							m.Head.Transform = CFrame.Angles(math.sin(ph * 1.4) * 0.05, math.sin(ph * 0.6) * 0.18, math.sin(ph * 0.9) * 0.05)
						end
						local flap = math.sin(ph * 5) * 0.32
						if m.WingR then
							m.WingR.Transform = CFrame.Angles(0, 0, flap)
						end
						if m.WingL then
							m.WingL.Transform = CFrame.Angles(0, 0, -flap)
						end
						if m.Tail then
							m.Tail.Transform = CFrame.Angles(0, math.sin(ph * 2.4) * 0.3, 0)
						end
					elseif rec.data.k == "egg" then
						local left = (rec.data.ready or 0) - now()
						local wob = left <= 0 and 0.16 or (left < 10 and 0.08 or 0.025)
						local base = Layout.padCFrame(slot, n) * CFrame.new(0, 1.35, 0)
						model.PrimaryPart.CFrame = base * CFrame.Angles(math.sin(ph * 9) * wob, 0, math.cos(ph * 7) * wob)
					end
				end
			end
		end
	end
end

-- Rainbow / prism parts cycle their hue.
local function rainbow()
	local t = os.clock()
	for _, p in ipairs(CollectionService:GetTagged(DragonBuilder.RainbowTag)) do
		if p:IsA("BasePart") and p:IsDescendantOf(workspace) then
			local h = (t * 0.25 + (p.Position.X + p.Position.Z) * 0.01) % 1
			p.Color = Color3.fromHSV(h, 0.75, 1)
		end
	end
	for _, p in ipairs(CollectionService:GetTagged(DragonBuilder.PrismTag)) do
		if p:IsA("BasePart") and p:IsDescendantOf(workspace) then
			local h = (t * 0.15 + p.Position.Y * 0.05) % 1
			p.Color = Color3.fromHSV(h, 0.35, 1)
		end
	end
end

---------------------------------------------------------------------------
-- FX from the server
---------------------------------------------------------------------------
local function burst(pos: Vector3, color: Color3, count: number, size: number)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.new(1, 1, 1)
	a.CFrame = CFrame.new(pos)
	a.Parent = renderFolder
	local e = Effects.emitter(a, {
		rate = 0, color = color, size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) }),
		speed = NumberRange.new(8, 18), lifetime = NumberRange.new(0.5, 0.9), accel = Vector3.new(0, -20, 0),
	})
	e:Emit(count)
	task.delay(1.5, function()
		a:Destroy()
	end)
end

local function onFx(slot: number, n: number, kind: string, extra)
	if kind == "hatch" then
		local cf = Layout.padCFrame(slot, n)
		local d = extra
		local sp = d and Species.get(d.sp)
		local color = sp and Rarity.color(sp.rarity) or Color3.new(1, 1, 1)
		burst(cf.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 250, 230), 30, 0.6)
		burst(cf.Position + Vector3.new(0, 2, 0), color, 24, 0.8)
		if slot == mySlot() then
			Sounds.play("crack")
			Sounds.play("stinger")
			task.defer(function()
				hatchedEvent:Fire(slot, n, d)
			end)
		end
		-- pop-in animation
		task.defer(function()
			local rec = pads[slot] and pads[slot][n]
			local model = rec and rec.model
			if model and model.Parent then
				local ok = pcall(function()
					model:ScaleTo(0.25)
				end)
				if ok then
					local start = os.clock()
					local conn
					conn = RunService.RenderStepped:Connect(function()
						local a = math.clamp((os.clock() - start) / 0.45, 0, 1)
						local e = 1 + 2.2 * (a - 1) ^ 3 + 1.2 * (a - 1) ^ 2 -- back-out
						if not model.Parent then
							conn:Disconnect()
							return
						end
						model:ScaleTo(math.max(0.25, 0.25 + 0.75 * e))
						if a >= 1 then
							model:ScaleTo(1)
							conn:Disconnect()
						end
					end)
				end
			end
		end)
	elseif kind == "collect" and slot == mySlot() then
		Sounds.play("coins", 1 + math.random() * 0.15)
		local cam = workspace.CurrentCamera
		local pos = Layout.plateCFrame(slot, n).Position + Vector3.new(0, 3, 0)
		local sp, onScreen = cam:WorldToViewportPoint(pos)
		if onScreen then
			Notify.float("+" .. Format.cash(extra or 0), Color3.fromRGB(255, 225, 80), Vector2.new(sp.X, sp.Y))
		end
	elseif kind == "sell" then
		burst(Layout.padCFrame(slot, n).Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 220, 90), 20, 0.5)
	elseif kind == "place" and slot == mySlot() then
		Sounds.play("pop")
	elseif kind == "lock" or kind == "unlock" then
		if slot == mySlot() then
			Sounds.play(kind == "lock" and "lock" or "click")
		end
	end
end

---------------------------------------------------------------------------
-- Own laser: walk through your own locked door
---------------------------------------------------------------------------
local function watchLasers()
	local bases = workspace:WaitForChild("Bases", 30)
	if not bases then
		return
	end
	local function hook(slot: number)
		local base = bases:WaitForChild("Base_" .. slot, 30)
		local laser = base and base:WaitForChild("Laser", 30)
		if not laser then
			return
		end
		local function apply()
			if mySlot() == slot and laser.CanCollide then
				laser.CanCollide = false
			end
		end
		laser:GetPropertyChangedSignal("CanCollide"):Connect(apply)
		player:GetAttributeChangedSignal("BaseSlot"):Connect(apply)
		apply()
	end
	for slot = 1, Layout.BaseCount do
		task.spawn(hook, slot)
	end
end

-- Locked pads beyond the owner's count look dim; the first one advertises upgrades.
local function updatePadRings()
	local bases = workspace:FindFirstChild("Bases")
	if not bases then
		return
	end
	for slot = 1, Layout.BaseCount do
		local base = bases:FindFirstChild("Base_" .. slot)
		if base then
			local count = folderOf(slot):GetAttribute("Pads") or 0
			for n = 1, Layout.MaxPads do
				local ring = base:FindFirstChild("PadRing_" .. n)
				if ring then
					local open = n <= count
					ring.Transparency = open and 0 or 0.75
					ring.Material = open and Enum.Material.Neon or Enum.Material.SmoothPlastic
				end
				local plate = base:FindFirstChild("Plate_" .. n)
				if plate then
					plate.Transparency = (n <= count) and 0 or 0.7
				end
			end
		end
	end
end

function BaseRenderer.start()
	local root = ReplicatedStorage:WaitForChild("BaseData")
	for slot = 1, Layout.BaseCount do
		local f = root:WaitForChild("Base_" .. slot)
		for n = 1, Layout.MaxPads do
			local v = f:WaitForChild("P" .. n)
			v.Changed:Connect(function()
				refresh(slot, n)
			end)
			refresh(slot, n)
		end
		f:GetAttributeChangedSignal("Pads"):Connect(updatePadRings)
		f:GetAttributeChangedSignal("Owner"):Connect(updatePadRings)
	end
	player:GetAttributeChangedSignal("BaseSlot"):Connect(function()
		for slot = 1, Layout.BaseCount do
			rebuildSlot(slot)
		end
		updatePadRings()
	end)
	Net.event("BaseFx").OnClientEvent:Connect(onFx)
	task.spawn(watchLasers)
	task.spawn(function()
		while true do
			updateLabels()
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			updatePadRings()
			task.wait(3)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		animate(dt)
		rainbow()
	end)
end

-- Stored cash on one of my pads (HUD "collect" hints).
function BaseRenderer.myStored(): number
	local slot = mySlot()
	local total = 0
	if slot and pads[slot] then
		for _, rec in pairs(pads[slot]) do
			total += stored(rec.data)
		end
	end
	return total
end

function BaseRenderer.records(slot: number)
	return pads[slot] or {}
end

return BaseRenderer
