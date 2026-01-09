--!strict
--[[
	PlantActionEvent.luau - Ephemeral event for special plant actions
	
	Fired when: A plant needs to trigger a special action
	Consumed by: MushroomSystem, SpecialPlantSystem, etc.
	Lifetime: One frame (cleaned by EventCleanupSystem)
	
	ActionType values:
	- "WakeMushroom": Coffee Bean waking a sleeping mushroom
	- "Arm": Potato Mine arming
	- "Explode": Explosive plant detonating
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type PlantActionEvent = {
	ActionType: string,      -- "WakeMushroom" | "Arm" | "Explode"
	TargetEntity: number,    -- Entity receiving the action
	SourceEntity: number?,   -- Entity triggering the action (e.g., Coffee Bean)
	PositionX: number?,
	PositionY: number?,
	PositionZ: number?,
}

return Matter.component("PlantActionEvent")
