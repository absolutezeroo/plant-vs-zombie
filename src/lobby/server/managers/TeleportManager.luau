--!strict
--[[
    TeleportManager.luau - Handles teleportation logic for arena
    
    Single Responsibility: Teleport players to arena with proper data
    Uses Promise.retry for reliable teleportation with automatic retries.
]]

local _Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise = require(Packages:WaitForChild("Promise"))

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
    TeleportPlayerAsync: (self: TeleportManager, player: Player, worldId: string, difficulty: string) -> any, -- Promise<TeleportResult>
    TeleportGroupAsync: (self: TeleportManager, players: {Player}, worldId: string, difficulty: string) -> any, -- Promise<{TeleportResult}>
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

-- Get player's equipped mutations
local function getPlayerEquippedMutations(player: Player): {[string]: {string}}
    local dataService = getPlayerDataService()
    if not dataService then return {} end
    
    -- Use GetAllEquippedMutations to get all equipped mutations
    return dataService.GetAllEquippedMutations(player) or {}
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

-- Teleport configuration
local TELEPORT_MAX_RETRIES = 3
local TELEPORT_RETRY_DELAY = 2  -- seconds between retries

-- Teleport a single player to arena (returns Promise)
function TeleportManager:TeleportPlayerAsync(player: Player, worldId: string, difficulty: string): any
    local deck = getPlayerDeck(player) or DEFAULT_DECK
    local equippedMutations = getPlayerEquippedMutations(player)
    
    -- Log deck and mutations for debugging
    Logger.Info("TeleportManager", `Teleporting {player.Name}: Deck={table.concat(deck, ", ")}`)
    local mutationCount = 0
    for plantType, mutations in pairs(equippedMutations) do
        if #mutations > 0 then
            mutationCount = mutationCount + 1
            Logger.Info("TeleportManager", `  {plantType}: {table.concat(mutations, ", ")}`)
        end
    end
    if mutationCount == 0 then
        Logger.Info("TeleportManager", "  No mutations equipped")
    end
    
    if _isStudio then
        -- In Studio, simulate teleport
        return Promise.resolve():andThen(function()
            Logger.Info("TeleportManager", `[STUDIO] Would teleport {player.Name} to Arena (World={worldId}, Difficulty={difficulty})`)
            movePlayerToSpawn(player)
            PlayerLockManager.GetInstance():UnlockPlayer(player)
            
            return {
                Success = true,
                IsStudioMode = true,
            }
        end)
    end
    
    -- Real teleport with retry
    local teleportOptions = Instance.new("TeleportOptions")
    local arenaData = TeleportData.CreateArenaJoinData(worldId, difficulty, deck, equippedMutations)
    teleportOptions:SetTeleportData(arenaData)
    
    return Promise.retry(function()
        return Promise.new(function(resolve, reject)
            -- Check if player is still in game
            if player.Parent ~= _Players then
                reject("Player left the game")
                return
            end
            
            TeleportService:TeleportAsync(
                TeleportData.PlaceIds.Arena,
                {player},
                teleportOptions
            )
            
            resolve()
        end)
    end, TELEPORT_MAX_RETRIES, function(attempt)
        -- Exponential backoff between retries
        Logger.Warn("TeleportManager", `Teleport attempt {attempt} failed for {player.Name}, retrying in {TELEPORT_RETRY_DELAY}s...`)
        return TELEPORT_RETRY_DELAY * attempt
    end):andThen(function()
        Logger.Info("TeleportManager", `{player.Name} teleported to Arena (World={worldId}, Difficulty={difficulty})`)
        return {
            Success = true,
            IsStudioMode = false,
        }
    end):catch(function(err)
        Logger.Error("TeleportManager", `Teleport failed for {player.Name} after {TELEPORT_MAX_RETRIES} attempts: {err}`)
        PlayerLockManager.GetInstance():UnlockPlayer(player)
        return {
            Success = false,
            Error = tostring(err),
            IsStudioMode = false,
        }
    end)
end

-- Teleport a group of players (returns Promise.all)
function TeleportManager:TeleportGroupAsync(players: {Player}, worldId: string, difficulty: string): any
    local promises = {}
    
    for _, player in ipairs(players) do
        table.insert(promises, self:TeleportPlayerAsync(player, worldId, difficulty))
    end
    
    return Promise.all(promises)
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
