--!strict
--[[
	ShellComponent.luau - Pumpkin shell protection tracking
	
	Applied to Pumpkin when placed on a plant.
	Contains reference to the protected plant.
	Zombies attack the shell first; when destroyed, the inner plant is exposed.
	
	Also applied to the protected plant (ProtectedByShell) to reverse-lookup.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type ShellComponent = {
	ProtectsPlant: number?, -- Entity ID of plant being protected (on Pumpkin)
	ProtectedByShell: number?, -- Entity ID of Pumpkin protecting this plant (on inner plant)
}

return Matter.component("ShellComponent", {
	ProtectsPlant = nil,
	ProtectedByShell = nil,
})
