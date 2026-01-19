--!strict
--[[
	plantfood Command (Server)
	
	Adds Plant Food charges to the player.
	Usage: plantfood 1
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

-- Use PlantFoodService directly
local Server = script.Parent.Parent.Parent
local PlantFoodService = require(Server.services.PlantFoodService)

return function(context, amount: number)
	local player = context.Executor

	-- Add charges using PlantFoodService
	local newTotal = PlantFoodService.AddCharge(player, amount)

	Logger.Info("Cmdr", `Added {amount} Plant Food charge(s) to {player.Name}, total: {newTotal}`)
	return `Added {amount} Plant Food charge(s) (total: {newTotal}/3)`
end
