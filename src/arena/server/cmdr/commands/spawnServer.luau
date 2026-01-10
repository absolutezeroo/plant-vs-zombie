--!strict
--[[
	spawn Command (Server)
	
	Spawns a zombie in the specified lane.
	Usage: spawn basic 3
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = script.Parent.Parent.Parent
local Logger = require(ReplicatedStorage.Shared.utils.Logger)

return function(context, zombieType: string, lane: number)
	-- Validate lane
	if lane < 1 or lane > 5 then
		return "Lane must be between 1 and 5"
	end
	
	-- Get WaveSpawner
	local managers = Server:FindFirstChild("managers")
	if not managers then
		return "Managers folder not found"
	end
	
	local waveFolder = managers:FindFirstChild("wave")
	if not waveFolder then
		return "Wave manager not found"
	end
	
	local WaveSpawnerModule = waveFolder:FindFirstChild("WaveSpawner")
	if not WaveSpawnerModule then
		return "WaveSpawner module not found"
	end
	
	local WaveSpawner = require(WaveSpawnerModule)
	local spawner = WaveSpawner.GetInstance()
	
	if not spawner then
		return "WaveSpawner instance not initialized"
	end
	
	Logger.Info("Cmdr", `Spawning {zombieType} in lane {lane}`)
	
	task.spawn(function()
		spawner:SpawnZombie(zombieType, lane)
	end)
	
	return `Spawned {zombieType} zombie in lane {lane}`
end
