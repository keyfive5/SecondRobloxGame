-- Client bootstrap.
local Client = script.Parent:WaitForChild("Client")
local UI = Client:WaitForChild("UI")

local State = require(Client.State)
State.start()

local modules = {
	Client.Sounds,
	UI.Notify,
	UI.HUD,
	UI.UpgradesPanel,
	UI.GearPanel,
	UI.RebirthPanel,
	UI.IndexPanel,
	Client.BaseRenderer,
	Client.ToolController,
	Client.WorldFX,
	Client.Interactions,
}
for _, name in ipairs({ "StorePanel", "MiscPanels", "QuestPanel", "HatchReveal" }) do
	if UI:FindFirstChild(name) then
		table.insert(modules, UI[name])
	end
end
for _, name in ipairs({ "Tutorial", "ChatTags", "Ads" }) do
	if Client:FindFirstChild(name) then
		table.insert(modules, Client[name])
	end
end
for _, m in ipairs(modules) do
	task.spawn(function()
		local ok, err = pcall(function()
			require(m).start()
		end)
		if not ok then
			warn("[Client] " .. m.Name .. " failed: " .. tostring(err))
		end
	end)
end
