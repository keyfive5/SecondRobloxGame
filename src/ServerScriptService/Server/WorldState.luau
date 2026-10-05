-- Server-wide state other services read without requiring each other:
-- the current event and server-wide boosts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldState = {
	event = nil, -- { id = "golden" | "bloodmoon" | ..., endsAt = unix }
	serverLuckUntil = 0,
}

-- Mutation the current event can give at hatch, and its chance (percent).
local EVENT_MUTATIONS = {
	golden = { "gold", 25 },
	bloodmoon = { "blood", 8 },
	lava = { "lava", 10 },
	frost = { "frozen", 10 },
}

function WorldState.eventId(): string?
	local e = WorldState.event
	if e and e.endsAt > os.time() then
		return e.id
	end
	return nil
end

function WorldState.eventMutation(): (string?, number?)
	local id = WorldState.eventId()
	local m = id and EVENT_MUTATIONS[id]
	if m then
		return m[1], m[2]
	end
	return nil, nil
end

function WorldState.serverLuck(): number
	return WorldState.serverLuckUntil > os.time() and 2 or 1
end

-- Mirror for clients (HUD timers)
function WorldState.publish()
	local e = WorldState.event
	ReplicatedStorage:SetAttribute("EventId", e and e.endsAt > os.time() and e.id or nil)
	ReplicatedStorage:SetAttribute("EventEnds", e and e.endsAt or nil)
	ReplicatedStorage:SetAttribute("ServerLuckUntil", WorldState.serverLuckUntil > os.time() and WorldState.serverLuckUntil or nil)
end

return WorldState
