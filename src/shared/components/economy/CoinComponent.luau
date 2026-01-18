--!strict
--[[
	CoinComponent.luau - ECS component for coin pickups
	
	Coins spawn when zombies die and are auto-collected after a delay.
	Contains position and value data for rendering.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type CoinComponent = {
	Value: number, -- Coin value
	SpawnTime: number, -- When coin was spawned
	CollectDelay: number, -- Delay before auto-collect (for VFX)
	PositionX: number, -- World X position
	PositionZ: number, -- World Z position
	TargetPlayerId: number, -- Player who killed the zombie (gets the coins)
}

return Matter.component("Coin")
