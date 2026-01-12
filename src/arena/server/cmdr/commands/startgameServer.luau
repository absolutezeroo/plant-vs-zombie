--!strict
--[[
	startgame Command (Server)
	
	Starts the game in Studio Debug mode.
	Usage: startgame         -> Start with day/normal
	Usage: startgame night   -> Start with night/normal
	Usage: startgame day hard -> Start with day/hard
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Server = script.Parent.Parent.Parent
local WaveService = require(Server.services.WaveService)

return function(_context, worldId: string?, difficulty: string?)
	local world = worldId or "day"
	local diff = difficulty or "normal"

	-- Check if game already running
	local currentState = WaveService.GetGameState()
	if currentState ~= "Waiting" and currentState ~= nil then
		return `Game already running! State: {currentState}. Use 'reset' command first.`
	end

	-- Start the game using WaveService
	local success = WaveService.StartGame(world, diff)

	if success then
		Logger.Info("Cmdr", `Game started: {world}/{diff}`)
		return `🎮 Game started! World: {world}, Difficulty: {diff}`
	else
		return `Failed to start game with world={world}, difficulty={diff}`
	end
end
