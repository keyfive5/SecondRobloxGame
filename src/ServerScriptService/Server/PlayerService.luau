-- Leaderstats, spawning at your base, walk speed, stuns and playtime.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local Sync = require(script.Parent.Sync)

local PlayerService = {}

local stunnedUntil = {} :: { [Player]: number }
local speedExtra = {} :: { [Player]: { [string]: number } } -- tool bonuses

local function dataOf(player: Player)
	local p = DataService.get(player)
	return p and p.data
end

-- Walk speed without carrying/stun/tools (what the HUD shows as "Speed").
function PlayerService.baseSpeed(player: Player): number
	local data = dataOf(player)
	if not data then
		return Config.BaseSpeed
	end
	local s = Config.BaseSpeed + data.speedLv + data.rebirths * Config.RebirthSpeed
	if player:GetAttribute("Pass_SpeedBoost") then
		s *= 1.25
	end
	return math.floor(s + 0.5)
end

function PlayerService.refreshSpeed(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local base = PlayerService.baseSpeed(player)
	player:SetAttribute("Speed", base)
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Speed") then
		ls.Speed.Value = base
	end
	if not hum then
		return
	end
	if (stunnedUntil[player] or 0) > os.clock() then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		return
	end
	local s = base
	for _, v in pairs(speedExtra[player] or {}) do
		s += v
	end
	local c = CarryService.get(player)
	if c then
		s *= (c.kind == "dragon" or c.source.type == "base") and Config.CarryDragonMult or Config.CarryEggMult
	end
	hum.WalkSpeed = s
	hum.JumpPower = Config.JumpPower
	hum.UseJumpPower = true
end

function PlayerService.setSpeedExtra(player: Player, key: string, value: number?)
	speedExtra[player] = speedExtra[player] or {}
	speedExtra[player][key] = value
	PlayerService.refreshSpeed(player)
end

function PlayerService.stun(player: Player, seconds: number)
	stunnedUntil[player] = os.clock() + seconds
	player:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + seconds)
	PlayerService.refreshSpeed(player)
	task.delay(seconds + 0.05, function()
		if player.Parent and (stunnedUntil[player] or 0) <= os.clock() then
			player:SetAttribute("StunnedUntil", nil)
			PlayerService.refreshSpeed(player)
		end
	end)
end

local function makeLeaderstats(player: Player, data)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = data.cash
	cash.Parent = ls
	local speed = Instance.new("IntValue")
	speed.Name = "Speed"
	speed.Value = PlayerService.baseSpeed(player)
	speed.Parent = ls
	local reb = Instance.new("IntValue")
	reb.Name = "Rebirths"
	reb.Value = data.rebirths
	reb.Parent = ls
	ls.Parent = player
end

-- Spawn just inside your base's door, facing out toward the plaza.
local function placeAtBase(player: Player, char: Model)
	local slot = BaseService.slot(player)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not slot or not hrp then
		return
	end
	local cf = Layout.baseCFrame(slot) * CFrame.new(0, Layout.FloorTop + 3.5, -Layout.BaseDepth / 2 + 7)
	char:PivotTo(cf)
end

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	stunnedUntil[player] = nil
	speedExtra[player] = {}
	PlayerService.refreshSpeed(player)
	task.defer(placeAtBase, player, char)
end

function PlayerService.start()
	DataService.Loaded:Connect(function(player, profile)
		makeLeaderstats(player, profile.data)
		-- full snapshot once every Loaded handler has had its synchronous turn
		task.defer(function()
			if player.Parent then
				Sync.full(player, profile.data)
			end
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
	end)
	BaseService.Assigned:Connect(function(player)
		if player.Character then
			task.defer(placeAtBase, player, player.Character)
		end
	end)
	CarryService.Changed:Connect(function(player)
		PlayerService.refreshSpeed(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		stunnedUntil[player] = nil
		speedExtra[player] = nil
	end)
	-- playtime
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = dataOf(player)
				if data then
					data.stats.playtime += 60
				end
			end
		end
	end)
	Net.event("Respawn").OnServerEvent:Connect(function(player)
		local char = player.Character
		if char then
			if CarryService.get(player) then
				CarryService.drop(player, "died")
			end
			placeAtBase(player, char)
		end
	end)
end

return PlayerService
