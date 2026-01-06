--!strict
--[[
	Types.luau - Shared type definitions for the project
	
	Centralizes type aliases used across server and client.
	Import via: local Types = require(Shared.Types)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

--[[
	MatterWorld - Type alias for Matter's World object
	
	Use this instead of `any` for the `world` parameter in systems.
	Provides type safety for world:query(), world:spawn(), etc.
]]
export type MatterWorld = typeof(Matter.World.new())

--[[
	EntityId - Numeric entity identifier
	
	All entity IDs in Matter are numbers.
]]
export type EntityId = number

--[[
	SystemFn - Type for system loop functions
	
	Systems receive the world as parameter.
]]
export type SystemFn = (world: MatterWorld) -> ()

--[[
	SystemModule - Type for system module exports
	
	Systems export a table with system function and priority.
]]
export type SystemModule = {
	system: SystemFn,
	priority: number,
}

return {
	-- Re-export for convenience (optional usage pattern)
}
