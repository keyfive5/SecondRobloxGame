-- Server bootstrap. Order matters: everything hooks DataService.Loaded before
-- DataService starts loading players.
local Server = script.Parent:WaitForChild("Server")

local DataService = require(Server.DataService)

local function boot(name: string, method: string?)
	local ok, err = pcall(function()
		require(Server[name])[method or "start"]()
	end)
	if not ok then
		warn("[Main] failed to start " .. name .. ": " .. tostring(err))
	end
end

boot("BaseService")
boot("CarryService", "init")
boot("NestService")
boot("PlayerService")
boot("ToolService")
boot("ShopService")
boot("EventService")
boot("MonetizationService")
for _, name in ipairs({ "RewardsService", "QuestService", "LeaderboardService", "AdminService" }) do
	if Server:FindFirstChild(name) then
		boot(name)
	end
end
DataService.start()

-- Studio-only hook so test scripts can drive services: DevHook:Invoke("BaseService", "placeEgg", player, {...})
if game:GetService("RunService"):IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "DevHook"
	hook.OnInvoke = function(service: string, method: string, ...)
		local mod = require(Server[service])
		if method == "__tempProfile" then -- filming/testing: stop saving this player's data
			local profile = mod.get(...)
			if profile then
				profile.temporary = true
			end
			return profile ~= nil
		end
		if method == "__get" then
			local field = ...
			return mod[field]
		end
		return mod[method](...)
	end
	hook.Parent = game:GetService("ServerStorage")
end
print("[Steal a Dragon Egg] server ready")
