--!strict
--[[
	startgame Command Definition
	
	Starts the game with specified world and difficulty (for Studio testing).
]]

return {
	Name = "startgame",
	Aliases = { "sg", "start" },
	Description = "Start the game (world, difficulty)",
	Group = "Debug",
	Args = {
		{
			Type = "string",
			Name = "WorldId",
			Description = "World ID (day, night, roof, pool)",
			Optional = true,
			Default = "day",
		},
		{
			Type = "string",
			Name = "Difficulty",
			Description = "Difficulty (easy, normal, hard, nightmare)",
			Optional = true,
			Default = "normal",
		},
	},
}
