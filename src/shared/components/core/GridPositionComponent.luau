--!strict
--[[
	GridPositionComponent.lua - Entity position on the 9×5 grid
	
	Used for both plants (fixed position) and zombies (moving position).
	Server-authoritative position, client reads for visual placement.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("GridPositionComponent", {
	Row = 1,        -- Lane (1-5)
	Column = 1,     -- Grid column (1-9)
	X = 0,          -- World X position (studs)
	Z = 0,          -- World Z position (studs)  
	Y = 0,          -- World Y position (height)
})
