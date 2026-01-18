--!strict
--[[
	plantfood Command Definition
	
	Adds Plant Food charges to the player.
]]

return {
	Name = "plantfood",
	Aliases = { "pf", "giveplantfood", "addplantfood" },
	Description = "Add Plant Food charges to your inventory (max 3)",
	Group = "Debug",
	Args = {
		{
			Type = "integer",
			Name = "Amount",
			Description = "Amount of charges to add (default 1, max will cap at 3)",
			Default = 1,
		},
	},
}
