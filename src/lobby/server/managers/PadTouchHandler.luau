--!strict
--[[
    PadTouchHandler.luau - Handles touch detection and cooldowns for pads
    
    Single Responsibility: Detect player touching pads and manage cooldowns
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages.Trove)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Dependencies
local PlayerLockManager = require(script.Parent.PlayerLockManager)

-- Constants
local TELEPORT_COOLDOWN = 3.0 -- Seconds before player can rejoin after teleport

export type TouchCallback = (player: Player, padModel: Model) -> ()

export type PadTouchHandler = {
    SetupPadTouch: (self: PadTouchHandler, padModel: Model, platform: BasePart, onTouch: TouchCallback) -> (),
    SetCooldown: (self: PadTouchHandler, player: Player, duration: number?) -> (),
    IsOnCooldown: (self: PadTouchHandler, player: Player) -> boolean,
    Cleanup: (self: PadTouchHandler, player: Player) -> (),
}

local PadTouchHandler = {}
PadTouchHandler.__index = PadTouchHandler

-- State
local _playerCooldown: {[Player]: number} = {} -- player -> cooldown end time
local _trove = Trove.new()

function PadTouchHandler.new(): PadTouchHandler
    local self = setmetatable({}, PadTouchHandler)
    return self
end

-- Setup touch detection for a pad platform
function PadTouchHandler:SetupPadTouch(padModel: Model, platform: BasePart, onTouch: TouchCallback)
    local connection = platform.Touched:Connect(function(hit: BasePart)
        -- Check if it's a character
        local character = hit.Parent
        if not character then return end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end
        
        -- Check cooldown
        if self:IsOnCooldown(player) then
            return
        end
        
        -- Check if already locked on a pad
        if PlayerLockManager.GetInstance():IsLocked(player) then
            return
        end
        
        -- Trigger callback
        onTouch(player, padModel)
    end)
    
    _trove:Add(connection)
    Logger.Debug("PadTouchHandler", `Setup touch for pad {padModel.Name}`)
end

-- Set cooldown for a player
function PadTouchHandler:SetCooldown(player: Player, duration: number?)
    local cooldownTime = duration or TELEPORT_COOLDOWN
    _playerCooldown[player] = os.clock() + cooldownTime
    Logger.Debug("PadTouchHandler", `{player.Name} on cooldown for {cooldownTime}s`)
end

-- Check if player is on cooldown
function PadTouchHandler:IsOnCooldown(player: Player): boolean
    local cooldownEnd = _playerCooldown[player]
    if cooldownEnd and os.clock() < cooldownEnd then
        return true
    end
    return false
end

-- Cleanup player state
function PadTouchHandler:Cleanup(player: Player)
    _playerCooldown[player] = nil
end

-- Cleanup all connections
function PadTouchHandler:CleanupAll()
    _trove:Destroy()
    _trove = Trove.new()
    table.clear(_playerCooldown)
end

-- Singleton instance
local _instance: PadTouchHandler? = nil

function PadTouchHandler.GetInstance(): PadTouchHandler
    if not _instance then
        _instance = PadTouchHandler.new()
    end
    return _instance
end

return PadTouchHandler
