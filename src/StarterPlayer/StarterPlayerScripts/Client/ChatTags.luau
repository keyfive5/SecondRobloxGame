-- Chat prefix for VIP pass owners.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTags = {}

function ChatTags.start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local plr = source and Players:GetPlayerByUserId(source.UserId)
		if plr and plr:GetAttribute("Pass_VIP") then
			props.PrefixText = '<font color="#FFD34D">[👑 VIP]</font> ' .. message.PrefixText
		end
		return props
	end
end

return ChatTags
