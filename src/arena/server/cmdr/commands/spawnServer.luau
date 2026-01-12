--!strict
--[[
	spawn Command (Server)
	
	Spawns a zombie in the specified lane.
	Usage: spawn basic 3
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = script.Parent.Parent.Parent
local Logger = require(ReplicatedStorage.Shared.utils.Logger)

local WaveService = require(Server.services.WaveService)

return function(_context, zombieType: string, lane: number)
	-- Validate lane
	if lane < 1 or lane > 5 then
		return "Lane must be between 1 and 5"
	end

	-- Get spawner from WaveService
	local spawner = WaveService.GetSpawner()

	if not spawner then
		return "WaveSpawner not initialized. Start a game first with 'startgame'."
	end

	Logger.Info("Cmdr", `Spawning {zombieType} in lane {lane}`)

	task.spawn(function()
		spawner:SpawnZombie(zombieType, lane)
	end)

	return `Spawned {zombieType} zombie in lane {lane}`
end
