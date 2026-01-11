--!strict
--[[
	level Command Definition
	
	Sets the player's level.
]]

return {
	Name = "level",
	Aliases = { "setlevel" },
	Description = "Set a player's level (default: yourself)",
	Group = "Debug",
	Args = {
		{
			Type = "integer",
			Name = "Level",
			Description = "Level to set (1-100)",
			Default = 10,
		},
		{
			Type = "player",
			Name = "Target",
			Description = "Player to set level for (default: yourself)",
			Optional = true,
		},
	},
}
