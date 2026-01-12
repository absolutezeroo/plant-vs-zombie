--!strict
--[[
	PlantTypeComponent.luau - Identifies plant type and holds base data
	
	Each plant entity has this component to identify what kind of plant it is.
	Actual stats come from PlantData lookup table.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("PlantTypeComponent", {
	PlantType = "Peashooter", -- String identifier (matches PlantData keys)
	OwnerId = 0, -- Player UserId who placed this plant
})
