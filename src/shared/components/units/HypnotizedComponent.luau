--!strict
--[[
	HypnotizedComponent.luau - Hypnotized zombie marker
	
	Applied to zombies that have eaten a Hypno-shroom.
	These zombies will:
	- Move in the opposite direction (toward zombie spawns)
	- Attack other zombies instead of plants
	- Be ignored by plants' targeting
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type HypnotizedComponent = {
	HypnotizedAt: number, -- When the zombie was hypnotized
	OriginalSpeed: number, -- Original movement speed before hypnotization
}

return Matter.component("HypnotizedComponent", {
	HypnotizedAt = 0,
	OriginalSpeed = 0,
})
