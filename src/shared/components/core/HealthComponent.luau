--!strict
--[[
	HealthComponent.lua - Entity health state
	
	Server-authoritative health. Client reads for health bar display.
	When Current reaches 0, DeathEvent should be spawned.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("HealthComponent", {
	Current = 100, -- Current health points
	Max = 100, -- Maximum health points
})
