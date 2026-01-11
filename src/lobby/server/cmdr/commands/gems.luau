--!strict
--[[
	gems Command Definition
	
	Gives gems to the player.
]]

return {
	Name = "gems",
	Aliases = { "givegems", "addgems" },
	Description = "Give gems to a player (default: yourself)",
	Group = "Debug",
	Args = {
		{
			Type = "integer",
			Name = "Amount",
			Description = "Amount of gems to add",
			Default = 100,
		},
		{
			Type = "player",
			Name = "Target",
			Description = "Player to give gems to (default: yourself)",
			Optional = true,
		},
	},
}
