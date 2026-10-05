-- Server-wide events, every few minutes (or bought with Robux):
--   secret    a Secret Egg appears in a random nest (guardian enraged)
--   golden    Golden Hour: 25% of hatches turn Golden
--   bloodmoon guardians are faster, eggs rarer, Blood Moon mutation can appear
--   meteor    meteors crash into the plaza, each leaving a free high-tier egg
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)

local NestService = require(script.Parent.NestService)
local Sync = require(script.Parent.Sync)
local WorldState = require(script.Parent.WorldState)

local EventService = {}

local rng = Random.new()
local meteorEvent = Net.event("Meteor")

EventService.Defs = {
	secret = { name = "Secret Egg", weight = 30 },
	golden = { name = "Golden Hour", weight = 25, seconds = 240, msg = "🌟 GOLDEN HOUR! 25% of eggs that hatch now turn GOLDEN!" },
	bloodmoon = { name = "Blood Moon", weight = 18, seconds = 240, msg = "🌑 BLOOD MOON! Guardians are faster, but eggs are rarer — and Blood Moon dragons can hatch!" },
	meteor = { name = "Meteor Shower", weight = 27 },
}

local function setEvent(id: string, seconds: number)
	WorldState.event = { id = id, endsAt = os.time() + seconds }
	WorldState.publish()
	task.delay(seconds + 0.5, function()
		if WorldState.event and WorldState.event.id == id and WorldState.event.endsAt <= os.time() then
			WorldState.event = nil
			WorldState.publish()
			Sync.notifyAll("The " .. EventService.Defs[id].name .. " has ended.", "info")
		end
	end)
end

local function meteorShower()
	Sync.notifyAll("☄️ METEOR SHOWER! Meteors are crashing into the plaza — grab the eggs they leave!", "rare")
	ReplicatedStorage:SetAttribute("MeteorUntil", os.time() + 40)
	local count = rng:NextInteger(7, 11)
	for i = 1, count do
		task.delay(i * rng:NextNumber(2, 3.5), function()
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(14, Layout.PlazaRadius - 8)
			local pos = Vector3.new(math.cos(a) * r, Layout.Ground + 1.5, math.sin(a) * r)
			if pos.Magnitude < 24 then
				pos = pos.Unit * 26 + Vector3.new(0, Layout.Ground + 1.5, 0)
			end
			local fall = 2.2
			meteorEvent:FireAllClients(pos, fall)
			task.delay(fall, function()
				local biome = rng:NextInteger(3, #Layout.Biomes)
				local rarity = NestService.rollRarity(biome)
				NestService.dropEgg(biome, rarity, pos, 25, "☄️ Meteor " .. rarity .. " Egg")
			end)
		end)
	end
end

function EventService.trigger(id: string, byName: string?)
	local def = EventService.Defs[id]
	if not def then
		return false
	end
	if byName then
		Sync.notifyAll(string.format("🎁 %s started a %s for the whole server!", byName, def.name), "rare")
	end
	if id == "secret" then
		NestService.spawnSecret()
	elseif id == "meteor" then
		meteorShower()
	else
		setEvent(id, def.seconds)
		Sync.notifyAll(def.msg, "rare")
	end
	return true
end

local function pickNatural(): string
	local total = 0
	for _, d in pairs(EventService.Defs) do
		total += d.weight
	end
	local pick = rng:NextNumber() * total
	for id, d in pairs(EventService.Defs) do
		pick -= d.weight
		if pick <= 0 then
			return id
		end
	end
	return "secret"
end

function EventService.start()
	task.spawn(function()
		task.wait(150)
		while true do
			EventService.trigger(pickNatural())
			task.wait(rng:NextNumber(Config.EventEvery[1], Config.EventEvery[2]))
		end
	end)
end

return EventService
