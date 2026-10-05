-- Where everything is. Shared so the server and every client agree on base, pad,
-- nest and biome positions without needing streamed-in parts.
--
-- Hub: a round plaza at the origin. Eight bases sit on a ring behind it (z < 0),
-- entrances facing the plaza. The Dragon Path leaves the plaza through a gate at
-- +Z and runs straight through the eight biomes, nearest (easiest) first.
local Shared = script.Parent
local Biomes = require(Shared.Biomes)
local Config = require(Shared.Config)

local Layout = {}

Layout.PlazaRadius = 82
Layout.BaseRing = 192
Layout.BaseCount = 8
Layout.BaseWidth = 60 -- along the ring
Layout.BaseDepth = 66 -- toward the plaza
Layout.FloorTop = 1 -- base floor surface height
Layout.PadTop = 1.4 -- pad surface height (dragons stand here)
Layout.GateZ = 118
Layout.PathWidth = 56
Layout.Ground = 0

-- Pads: 4 columns x 5 rows, filled front row first.
Layout.PadColumns = { -16.5, -5.5, 5.5, 16.5 }
Layout.PadRows = { -17, -6, 5, 16, 27 }
Layout.MaxPads = #Layout.PadColumns * #Layout.PadRows
Layout.PadSize = 8

-- Base i's frame: origin at the base center on the ground, LookVector (-Z) pointing
-- at the plaza, so the entrance is on the local -Z side.
function Layout.baseCFrame(i: number): CFrame
	local a = math.rad(180 + (i - 0.5) * 180 / Layout.BaseCount)
	local pos = Vector3.new(math.cos(a) * Layout.BaseRing, Layout.Ground, math.sin(a) * Layout.BaseRing)
	return CFrame.lookAt(pos, Vector3.new(0, Layout.Ground, 0))
end

-- Local offset of pad n (1-based) inside a base.
function Layout.padOffset(n: number): Vector3
	local cols = #Layout.PadColumns
	local row = math.floor((n - 1) / cols) + 1
	local col = (n - 1) % cols + 1
	return Vector3.new(Layout.PadColumns[col], Layout.PadTop, Layout.PadRows[row])
end

-- World frame a dragon on pad n stands at (facing the entrance).
function Layout.padCFrame(base: number, n: number): CFrame
	return Layout.baseCFrame(base) * CFrame.new(Layout.padOffset(n))
end

-- Collect plate in front of pad n.
function Layout.plateCFrame(base: number, n: number): CFrame
	local o = Layout.padOffset(n)
	return Layout.baseCFrame(base) * CFrame.new(o.X, Layout.FloorTop + 0.1, o.Z - 5.4)
end

-- Doorway (local): 16 wide, centered on the front wall.
Layout.DoorWidth = 16
function Layout.doorCFrame(base: number): CFrame
	return Layout.baseCFrame(base) * CFrame.new(0, Layout.FloorTop, -Layout.BaseDepth / 2)
end
function Layout.lockButtonCFrame(base: number): CFrame
	return Layout.baseCFrame(base) * CFrame.new(13, Layout.FloorTop, -Layout.BaseDepth / 2 + 5)
end

-- Is a world position inside base i (floor area, any height up to 30)?
function Layout.inBase(base: number, pos: Vector3, margin: number?): boolean
	local lp = Layout.baseCFrame(base):PointToObjectSpace(pos)
	local m = margin or 0
	return math.abs(lp.X) <= Layout.BaseWidth / 2 + m and math.abs(lp.Z) <= Layout.BaseDepth / 2 + m and lp.Y > -5 and lp.Y < 40
end

---------------------------------------------------------------------------
-- Biomes along the path. The chase is tuned so a player at exactly the biome's
-- recommended speed just escapes its guardian:
--   carrier speed P = speed * CarryEggMult; the guardian rests `rest` studs behind
--   the nest, wakes after WAKE seconds and gives up at the biome gate, `reach`
--   studs from the nest. Solving for the speed G that catches the carrier right
--   at the gate gives G = P * (rest - CATCH + reach) / (reach - P * WAKE).
---------------------------------------------------------------------------
Layout.GuardWake = 1.0
Layout.GuardCatch = 14 -- horizontal distance from the guardian's root
Layout.GuardLeeway = 0.93

Layout.Biomes = {}
local z = Layout.GateZ + 20
for i, b in ipairs(Biomes.List) do
	local S = b.speed
	local P = S * Config.CarryEggMult
	local reach = math.floor(6.5 * S + 40)
	local rest = math.floor(30 + 0.8 * S)
	local G = P * (rest - Layout.GuardCatch + reach) / (reach - P * Layout.GuardWake) * Layout.GuardLeeway
	local length = reach + rest + 70
	local info = {
		index = i,
		def = b,
		zStart = z, -- the biome's gate
		zEnd = z + length,
		nestZ = z + reach,
		restZ = z + reach + rest,
		reach = reach,
		guardSpeed = G,
		halfWidth = 60 + i * 4, -- playable half width (x) inside the biome
	}
	Layout.Biomes[i] = info
	z += length
end
Layout.PathEnd = z

-- Egg slot positions in a nest (ring around the nest center).
Layout.NestRadius = 6
function Layout.nestEggCFrame(biome: number, slot: number, count: number): CFrame
	local info = Layout.Biomes[biome]
	local a = (slot - 1) / count * math.pi * 2
	return CFrame.new(math.cos(a) * Layout.NestRadius, Layout.Ground + 3.1, info.nestZ + math.sin(a) * Layout.NestRadius)
end
function Layout.nestCFrame(biome: number): CFrame
	return CFrame.new(0, Layout.Ground, Layout.Biomes[biome].nestZ)
end
function Layout.guardianRest(biome: number): CFrame
	local info = Layout.Biomes[biome]
	return CFrame.new(0, Layout.Ground, info.restZ) -- faces -Z (toward the hub)
end

-- Which biome a world position is in (0 = hub / before the first gate).
function Layout.biomeAt(pos: Vector3): number
	if pos.Z < Layout.Biomes[1].zStart then
		return 0
	end
	for i = #Layout.Biomes, 1, -1 do
		if pos.Z >= Layout.Biomes[i].zStart then
			return i
		end
	end
	return 0
end

-- Hub landmarks
Layout.Spawn = CFrame.new(0, Layout.Ground + 3, 30)
local function ring(angleDeg: number, r: number): CFrame
	local a = math.rad(angleDeg)
	local pos = Vector3.new(math.cos(a) * r, Layout.Ground, math.sin(a) * r)
	return CFrame.lookAt(pos, Vector3.new(0, Layout.Ground, 0))
end
Layout.Shops = {
	Speed = ring(140, 104),
	Gear = ring(40, 104),
	Rebirth = ring(115, 116),
	Index = ring(65, 116),
}
Layout.Leaderboards = { ring(160, 100), ring(20, 100) }

return Layout
