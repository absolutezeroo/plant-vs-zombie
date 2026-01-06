--!strict
--[[
	ChewingComponent - Applied to Chomper while digesting zombie
	
	Chomper is disabled while chewing and cannot attack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("ChewingComponent", {
	ChewDuration = 42,    -- Seconds to chew (data-driven from PlantData)
	ChewStartTime = 0,    -- os.clock() when started chewing
})
