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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Cmdr = require(Packages:WaitForChild("Cmdr"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

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
	-- For now, allow all commands (you can add permission logic here)
	-- Example: if context.Executor.UserId ~= YOUR_USER_ID then return "Permission denied" end
	
	return nil -- Allow
end)

Logger.Info("Cmdr", "Server initialized with custom commands")
