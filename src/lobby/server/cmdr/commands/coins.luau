--!strict
--[[
	coins Command Definition
	
	Gives coins to the player.
]]

return {
	Name = "coins",
	Aliases = { "givecoins", "addcoins" },
	Description = "Give coins to a player (default: yourself)",
	Group = "Debug",
	Args = {
		{
			Type = "integer",
			Name = "Amount",
			Description = "Amount of coins to add",
			Default = 1000,
		},
		{
			Type = "player",
			Name = "Target",
			Description = "Player to give coins to (default: yourself)",
			Optional = true,
		},
	},
}
