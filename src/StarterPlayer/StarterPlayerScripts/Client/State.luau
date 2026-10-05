-- Client-side mirror of the player's save (pushed by the server's Sync module).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local State = {
	data = {
		cash = 0, speedLv = 0, padUp = 0, rebirths = 0, index = {}, gear = { slap = "slap", items = {} },
		stats = { earned = 0 }, daily = {}, quests = { list = {} }, tutorial = 0, boosts = {}, settings = { music = 0, sfx = 0.7 }, codes = {},
	},
	loaded = false,
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event -- (key)
local loadedEvent = Instance.new("BindableEvent")
State.Loaded = loadedEvent.Event

local function fire(key: string)
	changed:Fire(key)
end

function State.get(key: string)
	return State.data[key]
end

function State.onChange(key: string, fn)
	return State.Changed:Connect(function(k)
		if k == key then
			fn(State.data[key])
		end
	end)
end

-- Run fn now if data already arrived, and again on every future full snapshot.
function State.whenLoaded(fn)
	if State.loaded then
		task.spawn(fn)
	end
	return State.Loaded:Connect(fn)
end

function State.waitLoaded()
	while not State.loaded do
		State.Loaded:Wait()
	end
end

function State.start()
	Net.event("State").OnClientEvent:Connect(function(kind, a, b)
		if kind == "full" then
			for k, v in pairs(a) do
				State.data[k] = v
			end
			State.loaded = true
			for k in pairs(a) do
				fire(k)
			end
			loadedEvent:Fire()
		elseif kind == "set" then
			State.data[a] = b
			fire(a)
		end
	end)
end

return State
