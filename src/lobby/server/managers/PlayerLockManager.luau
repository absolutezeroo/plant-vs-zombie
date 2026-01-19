--!strict
--[[
    PlayerLockManager.luau - Handles locking/unlocking player movement on pads
    
    Single Responsibility: Manage player movement state (WalkSpeed, JumpPower)
]]

local _Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

-- Default movement values
local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50
local DEFAULT_JUMP_HEIGHT = 7.2

export type PlayerLockManager = {
	LockPlayer: (self: PlayerLockManager, player: Player, position: Vector3) -> boolean,
	UnlockPlayer: (self: PlayerLockManager, player: Player) -> boolean,
	IsLocked: (self: PlayerLockManager, player: Player) -> boolean,
	Cleanup: (self: PlayerLockManager, player: Player) -> (),
}

local PlayerLockManager = {}
PlayerLockManager.__index = PlayerLockManager

-- State
local _lockedPlayers: { [Player]: boolean } = {}

function PlayerLockManager.new(): PlayerLockManager
	local self = setmetatable({}, PlayerLockManager)
	return self
end

-- Lock a player at a specific position
function PlayerLockManager:LockPlayer(player: Player, position: Vector3): boolean
	if _lockedPlayers[player] then
		return false -- Already locked
	end

	local character = player.Character
	if not character then
		Logger.Warn("PlayerLockManager", `Cannot lock {player.Name}: no character`)
		return false
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoidRootPart or not humanoid then
		Logger.Warn("PlayerLockManager", `Cannot lock {player.Name}: missing HRP or Humanoid`)
		return false
	end

	-- Teleport to position
	(humanoidRootPart :: BasePart).CFrame = CFrame.new(position)

	-- Lock movement
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	_lockedPlayers[player] = true
	Logger.Debug("PlayerLockManager", `{player.Name} locked at position`)

	return true
end

-- Unlock a player's movement
function PlayerLockManager:UnlockPlayer(player: Player): boolean
	if not _lockedPlayers[player] then
		return false -- Not locked
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = DEFAULT_WALK_SPEED
			humanoid.JumpPower = DEFAULT_JUMP_POWER
			humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
		end
	end

	_lockedPlayers[player] = nil
	Logger.Debug("PlayerLockManager", `{player.Name} unlocked`)

	return true
end

-- Check if a player is locked
function PlayerLockManager:IsLocked(player: Player): boolean
	return _lockedPlayers[player] == true
end

-- Cleanup when player leaves
function PlayerLockManager:Cleanup(player: Player)
	_lockedPlayers[player] = nil
end

-- Singleton instance
local _instance: PlayerLockManager? = nil

function PlayerLockManager.GetInstance(): PlayerLockManager
	if not _instance then
		_instance = PlayerLockManager.new()
	end
	return _instance
end

return PlayerLockManager
