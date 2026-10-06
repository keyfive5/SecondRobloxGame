-- Opt-in rewarded video ads ("watch a short ad for a free Lucky Hatch boost").
-- Availability is checked right before showing the offer, as Roblox recommends.
local AdService = game:GetService("AdService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Products)

local Ads = {}

function Ads.enabled(): boolean
	local p = Products.DevByKey.AdLuck
	return p ~= nil and p.id ~= 0
end

-- Yields. True if a rewarded video is ready for this player right now.
function Ads.available(): boolean
	if not Ads.enabled() then
		return false
	end
	local ok, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	return ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
end

function Ads.watch()
	Net.event("WatchAd"):FireServer()
end

function Ads.start() end

return Ads
