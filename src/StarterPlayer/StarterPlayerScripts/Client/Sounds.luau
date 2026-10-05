-- Sound effects (Roblox UI pack + ProSoundEffects library) and optional background
-- music (APM library, licensed for Roblox). Music is OFF by default and every
-- volume follows the player's settings.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Sounds = {}

local SFX = {
	click = { "rbxassetid://15675059323", 0.5 },
	pop = { "rbxassetid://15675055424", 0.6 },
	whoosh = { "rbxassetid://9120704978", 0.35 },
	stinger = { "rbxassetid://15675043410", 0.5 },
	notify = { "rbxassetid://15675085146", 0.35 },
	hello = { "rbxassetid://15675016548", 0.45 },
	coins = { "rbxassetid://9113849492", 0.35 },
	error = { "rbxassetid://15675081158", 0.3 },
	crack = { "rbxassetid://9113959343", 0.6 },
	roar = { "rbxassetid://9113980319", 0.45 },
	slap = { "rbxassetid://9114788747", 0.45 },
	alarm = { "rbxassetid://9125557781", 0.12 },
	lock = { "rbxassetid://15675059323", 0.6 },
	boom = { "rbxasset://sounds/impact_explosion_03.mp3", 0.3 },
}

local MUSIC = {
	"rbxassetid://9046598930", -- Watching the Garden Grow
	"rbxassetid://1839578771", -- Charming View Ukulele
	"rbxassetid://1839580320", -- Happy Forever Ukulele
}
local MUSIC_BASE = 0.22

local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "SFX"
sfxGroup.Volume = 0.6
sfxGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Volume = 0
musicGroup.Parent = SoundService

local cache = {}
for name, def in pairs(SFX) do
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def[1]
	s.Volume = def[2]
	s.SoundGroup = sfxGroup
	s.Parent = SoundService
	cache[name] = s
end

-- Long effects (alarm, roar) are cut short so they never drone on.
local MAX_LEN = { alarm = 1.4, roar = 2.6, coins = 0.9 }

function Sounds.play(name: string, pitch: number?)
	local s = cache[name]
	if not s then
		return
	end
	if MAX_LEN[name] then
		local c = s:Clone()
		c.PlaybackSpeed = pitch or 1
		c.Parent = SoundService
		c:Play()
		task.delay(MAX_LEN[name], function()
			c:Destroy()
		end)
		return
	end
	if pitch then
		local c = s:Clone()
		c.PlaybackSpeed = pitch
		c.Parent = SoundService
		c:Play()
		c.Ended:Once(function()
			c:Destroy()
		end)
	else
		s:Play()
	end
end

function Sounds.setVolumes(music: number, sfx: number)
	musicGroup.Volume = math.clamp(music, 0, 1)
	sfxGroup.Volume = math.clamp(sfx, 0, 1)
end

function Sounds.start()
	task.spawn(function()
		local list = {}
		for _, s in pairs(cache) do
			table.insert(list, s)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
	task.spawn(function()
		local track = Instance.new("Sound")
		track.Name = "BackgroundMusic"
		track.Volume = MUSIC_BASE
		track.SoundGroup = musicGroup
		track.Parent = SoundService
		local i = math.random(1, #MUSIC)
		while true do
			track.SoundId = MUSIC[i]
			track:Play()
			local t = os.clock()
			track.Ended:Wait()
			if os.clock() - t < 5 then
				task.wait(20) -- failed to load; don't spin
			end
			task.wait(4)
			i = i % #MUSIC + 1
		end
	end)
end

return Sounds
