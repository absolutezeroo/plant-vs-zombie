--!strict
--[[
	lose Command Definition
	
	Forces a defeat for testing the VictoryDefeatScreen.
]]

return {
	Name = "lose",
	Aliases = { "defeat", "die" },
	Description = "Force a defeat (test Defeat screen)",
	Group = "Debug",
	Args = {
		{
			Type = "number",
			Name = "wave",
			Description = "Wave reached before losing",
			Optional = true,
		},
	},
}
