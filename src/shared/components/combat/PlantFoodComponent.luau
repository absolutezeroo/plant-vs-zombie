--!strict
--[[
	PlantFoodComponent.luau - Tags a zombie as a Plant Food carrier
	
	Glowing zombies drop Plant Food when killed.
	Only one per wave is guaranteed (set by WaveManagerSystem).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type PlantFoodComponent = {
	IsGlowing: boolean,  -- Visual indicator for glowing effect
}

return Matter.component("PlantFoodComponent", {
	IsGlowing = true,
})
