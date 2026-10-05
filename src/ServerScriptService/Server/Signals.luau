-- Decoupled game events for quests, stats and achievements.
local Signals = {}

local progress = Instance.new("BindableEvent")
Signals.Progress = progress.Event -- (player, kind, amount)

-- kind: "egg" | "hatch" | "steal" | "collect" | "speed" | "rare" | "sell"
function Signals.progress(player: Player, kind: string, amount: number?)
	progress:Fire(player, kind, amount or 1)
end

return Signals
