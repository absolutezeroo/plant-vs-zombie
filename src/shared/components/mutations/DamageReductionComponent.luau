--!strict
--[[
	DamageReductionComponent.luau - Reinforced mutation effect
	
	Applied to plants with Reinforced/Fortified mutation.
	Reduces incoming damage by a percentage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type DamageReductionComponent = {
	Percent: number,  -- 0.0-1.0, how much damage is reduced (0.2 = 20% reduction)
}

return Matter.component("DamageReduction")
