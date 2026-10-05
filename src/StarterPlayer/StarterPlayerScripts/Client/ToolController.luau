-- Gear tools on the client: activation -> "UseTool" remote, swing animation,
-- knockback when you get slapped/caught, and slap/net/trap effects.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Effects = require(Shared.Visuals.Effects)

local Sounds = require(script.Parent.Sounds)

local ToolController = {}

local player = Players.LocalPlayer
local useEvent = Net.event("UseTool")
local shakeUntil, shakeMag = 0, 0

function ToolController.shake(seconds: number, magnitude: number)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
	shakeMag = math.max(shakeMag, magnitude)
end

local function hrpOf(p: Player): BasePart?
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function bindTool(tool: Tool)
	if tool:GetAttribute("Bound") then
		return
	end
	tool:SetAttribute("Bound", true)
	local id = tool:GetAttribute("Gear")
	local baseGrip = tool.Grip
	tool.Activated:Connect(function()
		local target
		if id == "net" then
			local mouse = player:GetMouse()
			target = mouse.Hit and mouse.Hit.Position
			if not target then
				local hrp = hrpOf(player)
				target = hrp and (hrp.Position + hrp.CFrame.LookVector * 50)
			end
		end
		useEvent:FireServer(id, target)
		if id == "slap" then
			-- quick swing
			tool.Grip = baseGrip * CFrame.Angles(math.rad(-70), 0, 0)
			task.delay(0.12, function()
				tool.Grip = baseGrip * CFrame.Angles(math.rad(40), 0, 0)
			end)
			task.delay(0.25, function()
				tool.Grip = baseGrip
			end)
			Sounds.play("whoosh", 1.3)
		end
	end)
end

local function watchCharacter(char: Model)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and c:GetAttribute("Gear") then
			bindTool(c)
		end
	end)
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute("Gear") then
			bindTool(c)
		end
	end
end

local function popText(pos: Vector3, text: string, color: Color3)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.CFrame = CFrame.new(pos)
	a.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 50)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Parent = t
	t.Parent = bb
	TweenService:Create(bb, TweenInfo.new(0.7), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(0.7), { TextTransparency = 1 }):Play()
	TweenService:Create(s, TweenInfo.new(0.7), { Transparency = 1 }):Play()
	task.delay(0.75, function()
		a:Destroy()
	end)
	return a
end

local function onToolFx(kind: string, fromId: number?, toId: number?, a: Vector3?, b: Vector3?)
	local from = fromId and Players:GetPlayerByUserId(fromId)
	local to = toId and Players:GetPlayerByUserId(toId)
	if kind == "slap" then
		local hrp = to and hrpOf(to)
		if hrp then
			popText(hrp.Position + Vector3.new(0, 3, 0), "SLAP!", Color3.fromRGB(255, 230, 80))
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://9114788747"
			s.Volume = 0.6
			s.RollOffMaxDistance = 120
			s.Parent = hrp
			s:Play()
			task.delay(2, function()
				s:Destroy()
			end)
		end
	elseif kind == "net" and a and b then
		local net = Instance.new("Part")
		net.Anchored = true
		net.CanCollide = false
		net.CanQuery = false
		net.Size = Vector3.new(4, 4, 0.2)
		net.Material = Enum.Material.Fabric
		net.Color = Color3.fromRGB(230, 230, 230)
		net.Transparency = 0.3
		net.CFrame = CFrame.lookAt(a, b)
		net.Parent = workspace
		local tw = TweenService:Create(net, TweenInfo.new(0.25, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(b, b + (b - a)) })
		tw:Play()
		tw.Completed:Wait()
		task.delay(to and 2.2 or 0.3, function()
			net:Destroy()
		end)
		if to then
			popText(b + Vector3.new(0, 3, 0), "NETTED!", Color3.fromRGB(200, 240, 255))
		end
	elseif kind == "trap" and a then
		popText(a + Vector3.new(0, 3, 0), "SNAP!", Color3.fromRGB(255, 120, 90))
		Sounds.play("slap", 0.7)
	elseif kind == "cloak" then
		Sounds.play("whoosh", 0.8)
	end
	local _ = from
end

local function onKnockback(vel: Vector3, kind: string?)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or typeof(vel) ~= "Vector3" then
		return
	end
	hum:ChangeState(Enum.HumanoidStateType.FallingDown)
	hrp.AssemblyLinearVelocity = vel
	ToolController.shake(kind == "guardian" and 0.6 or 0.3, kind == "guardian" and 1.4 or 0.6)
	task.delay(0.7, function()
		if hum.Parent and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function ToolController.start()
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
	Net.event("ToolFx").OnClientEvent:Connect(onToolFx)
	Net.event("Knockback").OnClientEvent:Connect(onKnockback)
	-- camera shake
	RunService:BindToRenderStep("DragonShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		if left <= 0 then
			shakeMag = 0
			return
		end
		local m = shakeMag * math.min(1, left * 2)
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(math.random(-10, 10) * 0.1 * m), math.rad(math.random(-10, 10) * 0.1 * m), 0)
	end)
end

return ToolController
