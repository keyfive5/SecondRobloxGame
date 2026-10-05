-- World prompts that open UI (shop stalls).
local ProximityPromptService = game:GetService("ProximityPromptService")

local Root = require(script.Parent.UI.Root)
local Sounds = require(script.Parent.Sounds)

local Interactions = {}

local SHOP_WINDOWS = { Speed = "Upgrades", Gear = "Gear", Rebirth = "Rebirth", Index = "Index" }

function Interactions.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local shop = prompt:GetAttribute("Shop")
		if shop and SHOP_WINDOWS[shop] then
			Sounds.play("hello")
			Root.open(SHOP_WINDOWS[shop])
		end
	end)
end

return Interactions
