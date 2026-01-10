--!strict
--[[
	skip Command (Server)
	
	Skips the preparation phase or advances to next wave.
	Usage: skip
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = script.Parent.Parent.Parent
local Logger = require(ReplicatedStorage.Shared.utils.Logger)

return function(context)
	-- Get WaveManager
	local managers = Server:FindFirstChild("managers")
	if not managers then
		return "Managers folder not found"
	end
	
	local waveFolder = managers:FindFirstChild("wave")
	if not waveFolder then
		return "Wave manager not found"
	end
	
	local WaveManagerModule = waveFolder:FindFirstChild("WaveManager")
	if not WaveManagerModule then
		return "WaveManager module not found"
	end
	
	local WaveManager = require(WaveManagerModule)
	local manager = WaveManager.GetInstance()
	
	if not manager then
		return "WaveManager instance not initialized"
	end
	
	Logger.Info("Cmdr", "Skipping preparation phase")
	
	task.spawn(function()
		manager:SkipPreparation()
	end)
	
	return "Skipped preparation phase"
end
