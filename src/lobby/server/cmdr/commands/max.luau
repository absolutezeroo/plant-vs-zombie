--!strict
--[[
	max Command Definition
	
	Maxes out all resources.
]]

return {
	Name = "max",
	Aliases = { "maxresources", "rich" },
	Description = "Max out coins, gems, and level for a player (default: yourself)",
	Group = "Debug",
	Args = {
		{
			Type = "player",
			Name = "Target",
			Description = "Player to max resources for (default: yourself)",
			Optional = true,
		},
	},
}
