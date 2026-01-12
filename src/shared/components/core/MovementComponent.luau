--!strict
--[[
	MovementComponent.lua - Entity movement state
	
	Used for zombies walking toward the house.
	Speed in studs per second, direction typically -X.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("MovementComponent", {
	Speed = 0.5, -- Movement speed (studs/second)
	DirectionX = -1, -- X direction (-1 = toward house)
	DirectionZ = 0, -- Z direction (usually 0)
	IsMoving = true, -- False when attacking
})
