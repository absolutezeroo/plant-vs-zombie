--!strict
--[[
	OwnerComponent.luau - Tracks entity ownership
	
	Links entities to the player who spawned them.
	Used for:
	- Crediting kills/sun collection
	- Permission checks on entity actions
	- Cleanup on player disconnect
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type OwnerComponent = {
	PlayerId: number, -- Player.UserId who owns this entity
}

return Matter.component("Owner")
