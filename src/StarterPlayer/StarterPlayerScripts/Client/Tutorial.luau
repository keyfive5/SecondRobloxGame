-- First-time guide: a glowing beam from you to the next goal plus a hint card.
--   0 hatch your starter egg -> 1 grab an egg from Mossback's nest -> 2 outrun him
--   and bring it home -> 3 collect cash from the plates -> 4 buy speed -> 99 done
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)

local Theme = require(script.Parent.UI.Theme)
local Root = require(script.Parent.UI.Root)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Tutorial = {}

local player = Players.LocalPlayer
local setStep = Net.func("SetTutorial")

local STEPS = {
	[0] = "🐣 Your first egg is hatching! Walk to it and press <b>E</b> to hatch it.",
	[1] = "🥚 Run down the <b>Dragon Path</b> and steal an egg from <b>Mossback's nest</b>!",
	[2] = "🏃 RUN! Get back through the gate before Mossback catches you — then bring the egg home.",
	[3] = "💰 Walk over the <b>green plates</b> in front of your dragons to collect cash.",
	[4] = "⚡ Visit the <b>Speed Shop</b> to get faster and reach better biomes!",
}

local target = Instance.new("Part")
target.Name = "TutorialTarget"
target.Anchored = true
target.CanCollide = false
target.CanQuery = false
target.CanTouch = false
target.Transparency = 1
target.Size = Vector3.new(1, 1, 1)
target.Parent = workspace
local targetAtt = Instance.new("Attachment")
targetAtt.Parent = target

local beam = Instance.new("Beam")
beam.Attachment1 = targetAtt
beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 140, 60))
beam.Width0 = 1.4
beam.Width1 = 1.4
beam.FaceCamera = true
beam.LightEmission = 1
beam.Texture = "rbxassetid://446111271"
beam.TextureMode = Enum.TextureMode.Static
beam.TextureLength = 4
beam.TextureSpeed = 2
beam.Transparency = NumberSequence.new(0.15)
beam.Segments = 20
beam.Parent = target

local card, label
local function buildCard()
	card = Theme.card({
		Name = "Tutorial",
		Size = UDim2.fromOffset(520, 64),
		Position = UDim2.new(0.5, 0, 0, 210),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.new(1, 1, 1),
		Gradient = { Color3.fromRGB(255, 210, 90), Color3.fromRGB(230, 130, 40), 90 },
		StrokeColor = Color3.fromRGB(90, 40, 10),
		Radius = 16,
		Parent = Root.gui,
	})
	Root.scaled(card)
	label = Theme.text({ Text = "", RichText = true, Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 22, Parent = card })
end

local function step(): number
	return State.data.tutorial or 0
end

local function advance(to: number)
	if to > step() then
		State.data.tutorial = to
		Sounds.play("stinger")
		task.spawn(function()
			setStep:InvokeServer(to)
		end)
	end
end

local function myEggPad(): Vector3?
	local slot = player:GetAttribute("BaseSlot")
	if not slot then
		return nil
	end
	local f = ReplicatedStorage.BaseData:FindFirstChild("Base_" .. slot)
	for n = 1, Layout.MaxPads do
		local v = f and f:FindFirstChild("P" .. n)
		if v and v.Value:find('"k":"egg"') then
			return Layout.padCFrame(slot, n).Position
		end
	end
	return nil
end

local function hasDragon(): boolean
	local slot = player:GetAttribute("BaseSlot")
	local f = slot and ReplicatedStorage.BaseData:FindFirstChild("Base_" .. slot)
	if not f then
		return false
	end
	for n = 1, Layout.MaxPads do
		local v = f:FindFirstChild("P" .. n)
		if v and v.Value:find('"k":"dragon"') then
			return true, n
		end
	end
	return false
end

function Tutorial.start()
	State.waitLoaded()
	if step() >= 99 then
		target:Destroy()
		return
	end
	buildCard()
	local lastEggs = (State.data.stats and State.data.stats.eggs) or 0
	while step() < 99 do
		local s = step()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local att = hrp and hrp:FindFirstChild("RootAttachment")
		beam.Attachment0 = att
		local slot = player:GetAttribute("BaseSlot")
		local goal
		if s == 0 then
			local has = hasDragon()
			if has then
				advance(1)
			else
				goal = myEggPad()
			end
		elseif s == 1 then
			if player:GetAttribute("Carrying") then
				advance(2)
			else
				goal = Layout.nestCFrame(1).Position + Vector3.new(0, 3, 0)
			end
		elseif s == 2 then
			local eggs = (State.data.stats and State.data.stats.eggs) or 0
			if not player:GetAttribute("Carrying") and eggs > lastEggs then
				advance(3)
			elseif not player:GetAttribute("Carrying") then
				advance(1)
				State.data.tutorial = 1
			elseif slot then
				goal = Layout.baseCFrame(slot).Position + Vector3.new(0, 3, 0)
			end
		elseif s == 3 then
			if (State.data.cash or 0) > 0 then
				advance(4)
			else
				local _, n = hasDragon()
				goal = slot and n and Layout.plateCFrame(slot, n).Position + Vector3.new(0, 1, 0)
			end
		elseif s == 4 then
			if (State.data.speedLv or 0) > 0 then
				advance(99)
				break
			end
			goal = Layout.Shops.Speed.Position + Vector3.new(0, 3, 0)
		end
		label.Text = STEPS[step()] or ""
		card.Visible = STEPS[step()] ~= nil and not Root.current()
		if goal then
			target.Position = goal
			beam.Enabled = att ~= nil
		else
			beam.Enabled = false
		end
		task.wait(0.4)
	end
	if card then
		card:Destroy()
	end
	target:Destroy()
	local done = Theme.text({ Text = "🎉 You're a dragon thief now! Go get rich!", Font = Theme.TitleFont, Size = UDim2.fromOffset(600, 50), Position = UDim2.new(0.5, 0, 0, 220), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = Color3.fromRGB(255, 220, 90), Parent = Root.gui })
	Root.scaled(done)
	task.delay(4, function()
		done:Destroy()
	end)
end

return Tutorial
