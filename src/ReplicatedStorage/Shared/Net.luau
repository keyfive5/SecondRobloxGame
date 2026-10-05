-- Single place that owns every RemoteEvent / RemoteFunction.
-- Server creates them on first access; clients wait for them.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local function get(name: string, class: string)
	if RunService:IsServer() then
		local r = folder:FindFirstChild(name)
		if not r then
			r = Instance.new(class)
			r.Name = name
			r.Parent = folder
		end
		return r
	end
	return folder:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	return get(name, "RemoteEvent")
end

function Net.func(name: string): RemoteFunction
	return get(name, "RemoteFunction")
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return get(name, "UnreliableRemoteEvent")
end

return Net
