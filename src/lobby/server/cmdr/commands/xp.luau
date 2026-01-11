--!strict
--[[
	xp Command Definition
	
	Gives XP to the player.
]]

return {
	Name = "xp",
	Aliases = { "givexp", "addxp" },
	Description = "Give XP to a player (default: yourself)",
	Group = "Debug",
	Args = {
		{
			Type = "integer",
			Name = "Amount",
			Description = "Amount of XP to add",
			Default = 500,
		},
		{
			Type = "player",
			Name = "Target",
			Description = "Player to give XP to (default: yourself)",
			Optional = true,
		},
	},
}
