--!strict
--[[
	loadmap Command (Server)
	
	Loads a specific map for testing.
	Usage: loadmap World1_Day
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = script.Parent.Parent.Parent
local Logger = require(ReplicatedStorage.Shared.utils.Logger)

return function(context, mapId: string)
	-- Get MapLoader service
	local services = Server:FindFirstChild("services")
	if not services then
		return "MapLoader service not found"
	end
	
	local MapLoaderModule = services:FindFirstChild("MapLoader")
	if not MapLoaderModule then
		return "MapLoader module not found"
	end
	
	local MapLoader = require(MapLoaderModule)
	
	Logger.Info("Cmdr", `Loading map: {mapId}`)
	
	-- Load map (may yield)
	task.spawn(function()
		local success, err = pcall(function()
			MapLoader.LoadMap(mapId)
		end)
		
		if not success then
			Logger.Error("Cmdr", `Failed to load map: {err}`)
		end
	end)
	
	return `Loading map: {mapId}`
end
