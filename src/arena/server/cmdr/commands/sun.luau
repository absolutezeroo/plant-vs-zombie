--!strict
--[[
	sun Command Definition
	
	Adds sun to the player.
]]

return {
	Name = "sun",
	Aliases = { "addsun", "givesun" },
	Description = "Add sun to your match balance (use negative to remove)",
	Group = "Debug",
	Args = {
		{
			Type = "integer",
			Name = "Amount",
			Description = "Amount of sun to add (can be negative)",
			Default = 500,
		},
	},
}
