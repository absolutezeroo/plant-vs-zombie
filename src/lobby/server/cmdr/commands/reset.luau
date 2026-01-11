--!strict
--[[
	reset Command Definition
	
	Resets all player data to defaults.
]]

return {
	Name = "reset",
	Aliases = { "resetdata", "wipe" },
	Description = "Reset all data to defaults for a player (default: yourself)",
	Group = "Debug",
	Args = {
		{
			Type = "player",
			Name = "Target",
			Description = "Player to reset data for (default: yourself)",
			Optional = true,
		},
	},
}
