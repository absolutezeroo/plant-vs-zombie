--!strict
--[[
	FrozenComponent.luau - Complete freeze status on zombie
	
	Applied to zombies that have been frozen by ice mutation.
	Completely stops movement and attacking until duration expires.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type FrozenComponent = {
	RemainingDuration: number, -- Seconds left frozen
	AppliedAt: number, -- os.clock() when frozen
}

return Matter.component("Frozen")
