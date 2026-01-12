--!strict
--[[
	GhostComponent.lua - Client-side prediction marker
	
	Ghost entities exist only on client during server validation.
	Used by Hybrid Prediction pattern for optimistic placement.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("GhostComponent", {
	RequestId = "", -- GUID matching server response
	TimeCreated = 0, -- tick() timestamp for timeout detection
	PlantType = "", -- Plant type being placed
	Cost = 0, -- Sun cost for refund on rollback
})
