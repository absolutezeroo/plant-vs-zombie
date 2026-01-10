--!strict
--[[
	loadmap Command Definition
	
	Loads a specific map for testing.
]]

return {
	Name = "loadmap",
	Aliases = { "map" },
	Description = "Load a specific map",
	Group = "Debug",
	Args = {
		{
			Type = "string",
			Name = "MapId",
			Description = "Map ID to load (e.g., World1_Day, World1_Night)",
			Default = "World1_Day",
		},
	},
}
