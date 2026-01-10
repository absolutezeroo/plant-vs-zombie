--!strict
--[[
	Cmdr Client Initialization
	
	Initializes Cmdr on the client.
	
	Controls:
	- F2 or ; to open/close console
	- Tab to autocomplete
	- Up/Down arrows for command history
	
	Type "help" to see all available commands.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for Cmdr to be set up by the server (it creates CmdrClient in ReplicatedStorage)
local CmdrClient = ReplicatedStorage:WaitForChild("CmdrClient", 10)
if not CmdrClient then
	warn("[Cmdr] CmdrClient not found - server may not have initialized Cmdr")
	return
end

local Cmdr = require(CmdrClient)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Set activation keys (F2 and semicolon)
Cmdr:SetActivationKeys({ Enum.KeyCode.F2, Enum.KeyCode.Semicolon })

-- Cmdr is now ready
Cmdr:SetEnabled(true)

Logger.Info("Cmdr", "Client initialized - Press F2 or ; to open console")
