--!strict
--[[
	StunComponent - Applied to stunned entities (butter from KernelPult)
	
	Stun prevents all movement and attacking for Duration seconds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("StunComponent", {
	Duration = 4, -- Total stun duration
	AppliedAt = 0, -- os.clock() when applied
})
