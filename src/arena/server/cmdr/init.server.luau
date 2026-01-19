--!strict
--[[
	Cmdr Server Initialization
	
	Initializes Cmdr on the server with custom commands.
	Commands are registered from the commands/ folder.
	
	Usage:
	- Press F2 or ; to open console (client)
	- Type "help" to see available commands
	- Commands: loadmap, spawn, skip, entities, sun, etc.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Cmdr = require(Packages:WaitForChild("Cmdr"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

local WHITELISTED_USERS: { number } = {
	353813522,
	-- Add your Roblox UserId here for production testing
	-- Example: 12345678,
}

-- Register Cmdr (creates RemoteFunction in ReplicatedStorage)
Cmdr:RegisterDefaultCommands()

-- Register custom commands from commands folder
local commandsFolder = script:WaitForChild("commands")
Cmdr:RegisterCommandsIn(commandsFolder)

-- Register custom types from types folder (if exists)
local typesFolder = script:FindFirstChild("types")
if typesFolder then
	Cmdr:RegisterTypesIn(typesFolder)
end

-- Hook for permission checking
Cmdr.Registry:RegisterHook("BeforeRun", function(context)
	-- In Studio: allow all commands
	if RunService:IsStudio() then
		return nil -- Allow
	end

	-- In production: check if player is developer/admin
	local player = context.Executor
	for _, userId in WHITELISTED_USERS do
		if player.UserId == userId then
			return nil -- Allow
		end
	end

	-- Block unauthorized users in production
	return "Permission denied - dev commands are restricted"
end)

Logger.Info("Cmdr", "Server initialized with custom commands")
