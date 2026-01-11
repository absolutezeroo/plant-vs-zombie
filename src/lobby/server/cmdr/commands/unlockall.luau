--!strict
--[[
	unlockall Command Definition
	
	Unlocks all plants.
]]

return {
	Name = "unlockall",
	Aliases = { "unlockallplants" },
	Description = "Unlock all plants for a player (default: yourself)",
	Group = "Debug",
	Args = {
		{
			Type = "player",
			Name = "Target",
			Description = "Player to unlock all plants for (default: yourself)",
			Optional = true,
		},
	},
}
