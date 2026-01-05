--!strict
--[[
	TargetComponent.lua - Entity targeting state
	
	Stores the entity ID of the current target.
	Systems should verify target exists with world:contains() before use.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("TargetComponent", {
	EntityId = 0,   -- Target entity's numeric ID
	Distance = 0,   -- Cached distance to target (studs)
})
