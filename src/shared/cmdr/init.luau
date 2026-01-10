--!strict
--[[
	Cmdr Shared Types & Configuration
	
	This module provides shared configuration for Cmdr.
	Commands are organized in server/client folders.
]]

local CmdrConfig = {
	-- Permission levels
	Permissions = {
		Admin = 255,
		Developer = 100,
		Player = 0,
	},
	
	-- Activation key (default: F2, since ; is sometimes annoying)
	ActivationKeys = { Enum.KeyCode.F2, Enum.KeyCode.Semicolon },
	
	-- Hide default commands not relevant to our game
	HiddenCommands = {
		"announce",  -- We don't use this
	},
}

return table.freeze(CmdrConfig)
