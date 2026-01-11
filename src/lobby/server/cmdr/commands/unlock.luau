--!strict
--[[
	unlock Command Definition
	
	Unlocks a specific plant.
]]

return {
	Name = "unlock",
	Aliases = { "unlockplant" },
	Description = "Unlock a specific plant for a player (default: yourself)",
	Group = "Debug",
	Args = {
		{
			Type = "string",
			Name = "PlantType",
			Description = "Plant to unlock (e.g., Repeater, SnowPea)",
		},
		{
			Type = "player",
			Name = "Target",
			Description = "Player to unlock plant for (default: yourself)",
			Optional = true,
		},
	},
}
