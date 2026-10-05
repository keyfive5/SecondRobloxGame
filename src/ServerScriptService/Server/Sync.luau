-- Pushes the parts of a player's save the client needs for UI.
-- Full snapshot on load, then small keyed updates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local Sync = {}

local stateEvent = Net.event("State")
local notifyEvent = Net.event("Notify")

local CLIENT_KEYS = { "cash", "speedLv", "padUp", "rebirths", "index", "gear", "stats", "daily", "quests", "tutorial", "boosts", "settings", "codes" }

function Sync.full(player: Player, data)
	local snap = {}
	for _, k in ipairs(CLIENT_KEYS) do
		snap[k] = data[k]
	end
	stateEvent:FireClient(player, "full", snap)
end

function Sync.set(player: Player, key: string, value)
	stateEvent:FireClient(player, "set", key, value)
end

-- kind: "info" | "good" | "bad" | "rare" | "steal"
function Sync.notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

function Sync.notifyAll(text: string, kind: string?)
	notifyEvent:FireAllClients(text, kind or "info")
end

return Sync
