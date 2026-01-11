--!strict
--[[
	mutation Command Definition
	
	Adds a mutation to a plant.
]]

return {
	Name = "mutation",
	Aliases = { "addmutation", "mut" },
	Description = "Add a mutation to a plant for a player (default: yourself)",
	Group = "Debug",
	Args = {
		{
			Type = "string",
			Name = "PlantMutation",
			Description = "Format: PlantType:MutationType (e.g., Peashooter:Fire)",
		},
		{
			Type = "player",
			Name = "Target",
			Description = "Player to add mutation for (default: yourself)",
			Optional = true,
		},
	},
}
