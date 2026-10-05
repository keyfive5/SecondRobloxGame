-- Tunable numbers for the whole game.
local Config = {}

Config.DataStoreName = "DragonEgg_Live_1"
Config.DataVersion = 1
Config.AutosaveInterval = 90

-- Movement
Config.BaseSpeed = 20 -- walk speed with no upgrades
Config.MaxSpeedLevel = 160 -- speed upgrades cap (BaseSpeed + level)
Config.CarryEggMult = 0.85 -- walk speed while carrying an egg
Config.CarryDragonMult = 0.7 -- walk speed while carrying a stolen dragon
Config.JumpPower = 50

-- Base / pads
Config.StartPads = 8
Config.MaxPadUpgrades = 8 -- 8 + 8 = 16 pads from cash, +4 with the Mega Base pass
Config.PassPads = 4
Config.PadUpgradeCost = function(n: number): number -- n = upgrades already owned
	return math.floor(400 * 4.5 ^ n)
end
Config.LockSeconds = 60
Config.LockPassSeconds = 120

-- Speed upgrade price for going from `speed` to speed + 1. Anchored at each
-- biome's recommended speed (about 3 minutes of a full base of the previous
-- biome's dragons per biome) and interpolated exponentially between anchors.
local SPEED_ANCHORS = {
	{ 20, 120 }, { 30, 1200 }, { 42, 7000 }, { 56, 40000 }, { 72, 300000 },
	{ 90, 2e6 }, { 110, 13e6 }, { 135, 100e6 },
}
function Config.speedCost(speed: number): number
	speed = math.max(speed, SPEED_ANCHORS[1][1])
	for i = 1, #SPEED_ANCHORS - 1 do
		local a, b = SPEED_ANCHORS[i], SPEED_ANCHORS[i + 1]
		if speed < b[1] then
			local t = (speed - a[1]) / (b[1] - a[1])
			return math.floor(a[2] * (b[2] / a[2]) ^ t)
		end
	end
	local last = SPEED_ANCHORS[#SPEED_ANCHORS]
	return math.floor(last[2] * 1.085 ^ (speed - last[1]))
end

-- Hatch time (seconds) per rarity.
Config.HatchTime = { Common = 8, Uncommon = 15, Rare = 30, Epic = 60, Legendary = 120, Mythic = 240, Secret = 300 }

-- Selling a dragon pays this many seconds of its income.
Config.SellSeconds = 45

-- Offline income: fraction of normal rate, for up to this many seconds.
Config.OfflineRate = 0.5
Config.OfflineCap = 4 * 3600
Config.OfflineCapVIP = 8 * 3600

-- Rebirths
function Config.rebirthCost(n: number): number -- n = rebirths already done
	return math.floor(10e6 * 8 ^ n)
end
Config.RebirthIncome = 0.5 -- +50% income per rebirth (additive)
Config.RebirthSpeed = 2 -- +2 base walk speed per rebirth
Config.MaxRebirths = 25

-- Nests
Config.EggsPerNest = 5
Config.EggRespawn = { 6, 12 } -- seconds before a taken egg slot refills
Config.DroppedEggLife = 12 -- seconds a dropped egg waits on the ground

-- Stealing
Config.StealHold = 1.4 -- seconds to hold E on someone's dragon
Config.SlapCooldown = 1.1
Config.SlapRange = 9
Config.NewPlayerShield = 180 -- seconds after joining your base can't be robbed

-- Secret egg / server events
Config.EventEvery = { 420, 660 } -- seconds between natural server events

return Config
