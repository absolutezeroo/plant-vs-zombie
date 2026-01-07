--!strict
--[[
    TeleportManager.luau - Handles teleportation logic for arena
    
    Single Responsibility: Teleport players to arena with proper data
]]

local _Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local TeleportData = require(Shared.data.TeleportData)

-- Dependencies
local PlayerDataService = nil -- Lazy loaded
local PlayerLockManager = require(script.Parent.PlayerLockManager)

local DEFAULT_DECK = {"Sunflower", "Peashooter", "WallNut"}

export type TeleportResult = {
    Success: boolean,
    Error: string?,
    IsStudioMode: boolean,
}

export type TeleportManager = {
    TeleportPlayer: (self: TeleportManager, player: Player, stageId: number, onComplete: ((player: Player) -> ())?) -> TeleportResult,
    TeleportGroup: (self: TeleportManager, players: {Player}, stageId: number, onComplete: ((player: Player) -> ())?) -> {[Player]: TeleportResult},
    IsStudioMode: (self: TeleportManager) -> boolean,
}

local TeleportManager = {}
TeleportManager.__index = TeleportManager

-- State
local _isStudio = RunService:IsStudio()

function TeleportManager.new(): TeleportManager
    local self = setmetatable({}, TeleportManager)
    return self
end

-- Lazy load PlayerDataService to avoid circular dependency
local function getPlayerDataService()
    if not PlayerDataService then
        local success, result = pcall(function()
            return require(script.Parent.Parent.services.PlayerDataService)
        end)
        if success then
            PlayerDataService = result
        end
    end
    return PlayerDataService
end

-- Get player's deck from profile
local function getPlayerDeck(player: Player): {string}?
    local dataService = getPlayerDataService()
    if not dataService then return nil end
    
    -- Use GetDeck directly
    local deck = dataService.GetDeck(player)
    if deck and #deck > 0 then
        return deck
    end
    
    return nil
end

-- Move player to spawn (for Studio mode)
local function movePlayerToSpawn(player: Player)
    local character = player.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local spawnLocation = game.Workspace:FindFirstChild("SpawnLocation")
    if spawnLocation then
        (hrp :: BasePart).CFrame = (spawnLocation :: SpawnLocation).CFrame + Vector3.new(0, 3, 0)
    else
        -- Fallback: move away from current position
        (hrp :: BasePart).CFrame = (hrp :: BasePart).CFrame + Vector3.new(20, 0, 0)
    end
end

-- Check if running in Studio
function TeleportManager:IsStudioMode(): boolean
    return _isStudio
end

-- Teleport a single player to arena
function TeleportManager:TeleportPlayer(player: Player, stageId: number, onComplete: ((player: Player) -> ())?): TeleportResult
    local deck = getPlayerDeck(player) or DEFAULT_DECK
    
    if _isStudio then
        -- In Studio, simulate teleport
        Logger.Info("TeleportManager", `[STUDIO] Would teleport {player.Name} to Arena (stage {stageId})`)
        movePlayerToSpawn(player)
        
        -- Unlock player
        PlayerLockManager.GetInstance():UnlockPlayer(player)
        
        if onComplete then
            onComplete(player)
        end
        
        return {
            Success = true,
            IsStudioMode = true,
        }
    end
    
    -- Real teleport
    local teleportOptions = Instance.new("TeleportOptions")
    local arenaData = TeleportData.CreateArenaJoinData(tostring(stageId), deck)
    teleportOptions:SetTeleportData(arenaData)
    
    local success, err = pcall(function()
        TeleportService:TeleportAsync(
            TeleportData.PlaceIds.Arena,
            {player},
            teleportOptions
        )
    end)
    
    if not success then
        Logger.Error("TeleportManager", `Teleport failed for {player.Name}: {err}`)
        PlayerLockManager.GetInstance():UnlockPlayer(player)
        
        if onComplete then
            onComplete(player)
        end
        
        return {
            Success = false,
            Error = tostring(err),
            IsStudioMode = false,
        }
    end
    
    Logger.Info("TeleportManager", `{player.Name} teleported to Arena (stage {stageId})`)
    
    if onComplete then
        onComplete(player)
    end
    
    return {
        Success = true,
        IsStudioMode = false,
    }
end

-- Teleport a group of players
function TeleportManager:TeleportGroup(players: {Player}, stageId: number, onComplete: ((player: Player) -> ())?): {[Player]: TeleportResult}
    local results: {[Player]: TeleportResult} = {}
    
    for _, player in ipairs(players) do
        results[player] = self:TeleportPlayer(player, stageId, onComplete)
    end
    
    return results
end

-- Singleton instance
local _instance: TeleportManager? = nil

function TeleportManager.GetInstance(): TeleportManager
    if not _instance then
        _instance = TeleportManager.new()
    end
    return _instance
end

return TeleportManager
