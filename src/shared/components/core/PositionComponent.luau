--!strict
--[[
	PositionComponent.luau - World position for entities
	
	Stores X, Y, Z world coordinates.
	Used for entities that need precise positioning (sun orbs, projectiles).
	Plants use GridPositionComponent instead (column, lane).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type PositionComponent = {
	X: number,
	Y: number,
	Z: number,
}

return Matter.component("Position")
