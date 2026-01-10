--!strict
--[[
	sun Command (Server)
	
	Adds sun to the player's current match balance.
	Usage: sun 500
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local Network = require(Shared.network.generated.server)

return function(context, amount: number)
	local player = context.Executor
	
	-- Get PlacementSystem API (which has AddSun)
	local Server = script.Parent.Parent.Parent
	local systems = Server:FindFirstChild("systems")
	if not systems then
		return "Systems folder not found"
	end
	
	local units = systems:FindFirstChild("units")
	if not units then
		return "Units folder not found"
	end
	
	local PlacementSystemModule = units:FindFirstChild("PlacementSystem")
	if not PlacementSystemModule then
		return "PlacementSystem not found"
	end
	
	local PlacementSystem = require(PlacementSystemModule)
	
	-- Add sun using PlacementAPI
	if PlacementSystem.API and PlacementSystem.API.AddSun then
		PlacementSystem.API.AddSun(player, amount)
		local newTotal = PlacementSystem.API.GetPlayerSun(player)
		
		-- Sync to client using SunCollected event
		Network.SunCollected.Fire(player, {
			SunEntityId = 0, -- No entity, just a sync
			CollectorId = player.UserId,
			NewTotal = newTotal,
		})
		
		Logger.Info("Cmdr", `Added {amount} sun to {player.Name}`)
		return `Added {amount} sun (total: {newTotal})`
	else
		return "PlacementSystem.API.AddSun not available"
	end
end
