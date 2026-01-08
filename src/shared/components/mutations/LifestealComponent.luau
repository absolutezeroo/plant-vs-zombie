--!strict
--[[
	LifestealComponent.luau - Shadow mutation effect
	
	Applied to plants with Shadow/Void mutation.
	When dealing damage, heals the plant for a percentage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type LifestealComponent = {
	Percent: number,  -- 0.0-1.0, how much of damage heals (0.15 = 15%)
}

return Matter.component("Lifesteal")
