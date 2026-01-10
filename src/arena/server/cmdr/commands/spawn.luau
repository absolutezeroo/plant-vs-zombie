--!strict
--[[
	spawn Command Definition
	
	Spawns a zombie in a lane.
]]

return {
	Name = "spawn",
	Aliases = { "z", "zombie" },
	Description = "Spawn a zombie in a specific lane",
	Group = "Debug",
	Args = {
		{
			Type = "string",
			Name = "ZombieType",
			Description = "Type of zombie (Basic, Cone, Bucket, Flag, Gargantuar)",
			Default = "Basic",
		},
		{
			Type = "integer",
			Name = "Lane",
			Description = "Lane number (1-5)",
			Default = 3,
		},
	},
}
