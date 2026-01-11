--!strict
--[[
	win Command Definition
	
	Forces a victory for testing the VictoryDefeatScreen.
]]

return {
	Name = "win",
	Aliases = { "victory" },
	Description = "Force a victory (test Victory screen)",
	Group = "Debug",
	Args = {
		{
			Type = "number",
			Name = "stars",
			Description = "Number of stars (1-3)",
			Optional = true,
		},
	},
}
