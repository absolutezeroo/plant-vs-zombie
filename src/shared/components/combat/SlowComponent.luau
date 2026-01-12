--!strict
--[[
	SlowComponent.luau - Slow/freeze effect on entities
	
	Applied to zombies when hit by SnowPea or frozen effects.
	Reduces movement speed by a percentage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type SlowComponent = {
	SlowPercent: number, -- 0.0-1.0, how much to slow (0.5 = 50% slower)
	Duration: number, -- Seconds remaining
	AppliedAt: number, -- os.clock() when applied
}

return Matter.component("Slow")
