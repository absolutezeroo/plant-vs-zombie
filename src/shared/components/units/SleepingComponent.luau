--!strict
--[[
	SleepingComponent - Applied to mushrooms sleeping during day
	
	Sleeping plants cannot shoot or produce anything.
	Coffee Bean removes this component.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("SleepingComponent", {
	IsSleeping = true,      -- Currently sleeping?
	WokeAt = nil :: number?,-- os.clock() when woken (nil if still sleeping)
})
