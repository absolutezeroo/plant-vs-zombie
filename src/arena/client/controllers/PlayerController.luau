--!strict
--[[
	PlayerController.luau - Player character setup for Arena
	
	Handles player-specific settings in the arena:
	- Disables jumping (tower defense gameplay)
	- Future: Camera constraints, movement limits, etc.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local PlayerController = {}

local _initialized = false

--[[
	Disable jumping for a character
]]
local function setupCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Disable jumping completely
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		
		Logger.Debug("PlayerController", "Jump disabled for character")
	end
end

--[[
	Initialize the controller
]]
function PlayerController.Init()
	if _initialized then
		return
	end
	_initialized = true
	
	local player = Players.LocalPlayer
	
	-- Setup current character if exists
	if player.Character then
		setupCharacter(player.Character)
	end
	
	-- Setup future characters (respawn)
	player.CharacterAdded:Connect(setupCharacter)
	
	Logger.Info("PlayerController", "Initialized - Jump disabled in Arena")
end

return PlayerController
