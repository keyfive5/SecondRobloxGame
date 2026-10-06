-- Chat commands for the game owner (and anyone while testing in Studio).
--   /cash 1000         /speed 10           /egg 3 Legendary [n]
--   /dragon phoenix [size] [mutation]       /event golden|bloodmoon|meteor|secret
--   /secret [biome]    /hatchall           /lock [seconds]   /announce text...
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)

local Economy = require(script.Parent.Economy)
local Sync = require(script.Parent.Sync)
local BaseService = require(script.Parent.BaseService)
local NestService = require(script.Parent.NestService)
local EventService = require(script.Parent.EventService)
local ShopService = require(script.Parent.ShopService)

local AdminService = {}

function AdminService.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= 254
end

local commands = {}
commands.cash = function(p, n)
	Economy.addCash(p, tonumber(n) or 1000, false)
end
commands.speed = function(p, n)
	ShopService.addSpeedLevels(p, tonumber(n) or 10)
end
commands.egg = function(p, b, r, n)
	for _ = 1, math.clamp(tonumber(n) or 1, 1, 20) do
		BaseService.placeEgg(p, { b = tonumber(b) or 1, r = r or "Rare" })
	end
end
commands.dragon = function(p, id, size, mut)
	if Species.get(id or "") then
		BaseService.placeDragon(p, { sp = id, sz = size or "normal", mut = mut })
	end
end
commands.event = function(p, id)
	EventService.trigger(id or "golden", p.DisplayName)
end
commands.secret = function(_, b)
	NestService.spawnSecret(tonumber(b))
end
commands.hatchall = function(p)
	for n = 1, 24 do
		BaseService.hatch(p, n, true)
	end
end
commands.lock = function(p, s)
	BaseService.lock(p, tonumber(s) or 60)
end
commands.announce = function(_, ...)
	Sync.notifyAll("📣 " .. table.concat({ ... }, " "), "rare")
end

local function handle(player: Player, msg: string)
	if msg:sub(1, 1) ~= "/" or not AdminService.isAdmin(player) then
		return
	end
	local parts = string.split(msg:sub(2), " ")
	local cmd = table.remove(parts, 1)
	local fn = commands[string.lower(cmd or "")]
	if fn then
		local ok, err = pcall(fn, player, table.unpack(parts))
		if not ok then
			warn("[Admin]", err)
		end
	end
end

function AdminService.start()
	local function hook(player: Player)
		player.Chatted:Connect(function(msg)
			handle(player, msg)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
end

return AdminService
