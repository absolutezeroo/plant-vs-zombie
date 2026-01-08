--!strict
--[[
    Lobby Services - Re-exports from server/services
    
    For the Lobby place, we need access to PlayerDataService
    but not the full Arena game logic.
]]

local _Server = game:GetService("ServerScriptService"):WaitForChild("LobbyServer") -- Reserved for future use

-- FaiDataService is the same across both places
-- In production, this would be in a shared location
-- For now, we duplicate the essential functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local _RunService = game:GetService("RunService") -- Reserved for future use

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ProfileStore = require(Packages:WaitForChild("ProfileStore"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Profile template (same as Arena)
local PROFILE_TEMPLATE = {
    Coins = 0,
    TotalCoinsEarned = 0,
    Gems = 0,
    TotalGemsEarned = 0,
    XP = 0,
    Level = 1,
    UnlockedPlants = {
        Sunflower = true,
        Peashooter = true,
        WallNut = true,
    },
    PlantMutations = {} :: {[string]: {string}}, -- [PlantType] = {"Fire", "Swift", ...}
    PlantMastery = {} :: {[string]: { Rank: number, XP: number }},
    Deck = {"Sunflower", "Peashooter", "WallNut"} :: {string}, -- Default starter deck
    Stats = {
        GamesPlayed = 0,
        GamesWon = 0,
        ZombiesKilled = 0,
        PlantsPlaced = 0,
    },
    Settings = {
        MusicVolume = 1.0,
        SFXVolume = 1.0,
    },
}

local PlayerDataService = {}

local Store = ProfileStore.New("PlayerData_v1", PROFILE_TEMPLATE)
local Profiles: { [Player]: any } = {}
local ProfileLoadedCallbacks: { [Player]: {(any) -> ()} } = {}

function PlayerDataService.Initialize()
    Logger.Info("LobbyPlayerData", "Initializing PlayerDataService for Lobby")
    
    Players.PlayerAdded:Connect(function(player)
        PlayerDataService.LoadProfile(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        PlayerDataService.ReleaseProfile(player)
    end)
    
    -- Handle existing players
    for _, player in Players:GetPlayers() do
        task.spawn(PlayerDataService.LoadProfile, player)
    end
end

function PlayerDataService.LoadProfile(player: Player)
    Logger.Info("LobbyPlayerData", `Loading profile for {player.Name}`)
    
    local profile = Store:StartSessionAsync(`Player_{player.UserId}`, {
        Cancel = function()
            return player.Parent ~= Players
        end,
    })
    
    if profile then
        profile:AddUserId(player.UserId)
        profile:Reconcile()
        
        profile.OnSessionEnd:Connect(function()
            Profiles[player] = nil
            if player.Parent == Players then
                player:Kick("Profile session ended")
            end
        end)
        
        if player.Parent == Players then
            Profiles[player] = profile
            Logger.Info("LobbyPlayerData", `Profile loaded for {player.Name}`)
            
            -- Fire any waiting callbacks
            local callbacks = ProfileLoadedCallbacks[player]
            if callbacks then
                for _, callback in callbacks do
                    task.spawn(callback, profile)
                end
                ProfileLoadedCallbacks[player] = nil
            end
        else
            profile:EndSession()
        end
    else
        player:Kick("Failed to load profile")
    end
end

function PlayerDataService.ReleaseProfile(player: Player)
    local profile = Profiles[player]
    if profile then
        profile:EndSession()
        Profiles[player] = nil
    end
    
    -- Clean up any pending callbacks
    ProfileLoadedCallbacks[player] = nil
end

function PlayerDataService.GetProfile(player: Player)
    return Profiles[player]
end

--[[
    Wait for a player's profile to be loaded.
    Returns the profile once loaded, or nil if timeout/player left.
]]
function PlayerDataService.WaitForProfile(player: Player, timeout: number?): any
    -- Already loaded?
    local profile = Profiles[player]
    if profile then
        return profile
    end
    
    -- Player already left?
    if player.Parent ~= Players then
        return nil
    end
    
    local maxWait = timeout or 10
    local loaded = false
    local resultProfile = nil
    
    -- Register callback
    if not ProfileLoadedCallbacks[player] then
        ProfileLoadedCallbacks[player] = {}
    end
    table.insert(ProfileLoadedCallbacks[player], function(p)
        resultProfile = p
        loaded = true
    end)
    
    -- Wait with timeout
    local elapsed = 0
    while not loaded and elapsed < maxWait and player.Parent == Players do
        task.wait(0.1)
        elapsed += 0.1
    end
    
    return resultProfile
end

function PlayerDataService.GetData(player: Player)
    local profile = Profiles[player]
    return if profile then profile.Data else nil
end

-- Set player's current deck (saved for reuse)
function PlayerDataService.SetDeck(player: Player, deck: {string}): boolean
    local profile = Profiles[player]
    if not profile then return false end
    
    profile.Data.Deck = deck
    Logger.Info("LobbyPlayerData", `Deck updated for {player.Name}`, {deckSize = #deck})
    return true
end

-- Get player's current deck
function PlayerDataService.GetDeck(player: Player): {string}?
    local profile = Profiles[player]
    if not profile then return nil end
    return profile.Data.Deck
end

-- ============================================
-- COINS SYSTEM
-- ============================================

-- Get coins for a player
function PlayerDataService.GetCoins(player: Player): number
    local profile = Profiles[player]
    return if profile then profile.Data.Coins else 0
end

-- Add coins to a player
function PlayerDataService.AddCoins(player: Player, amount: number): boolean
    local profile = Profiles[player]
    if not profile then
        return false
    end
    
    profile.Data.Coins += amount
    profile.Data.TotalCoinsEarned += amount
    
    Logger.Info("LobbyPlayerData", `{player.Name} +{amount} coins (Total: {profile.Data.Coins})`)
    return true
end

-- ============================================
-- XP / LEVEL SYSTEM
-- ============================================

-- Add XP to a player (simplified version - full progression is in Arena)
function PlayerDataService.AddXP(player: Player, amount: number): number
    local profile = Profiles[player]
    if not profile then
        return 0
    end
    
    local oldLevel = profile.Data.Level
    profile.Data.XP += amount
    
    -- Simple level up check (100 XP per level for now)
    local XP_PER_LEVEL = 100
    local newLevel = math.floor(profile.Data.XP / XP_PER_LEVEL) + 1
    local levelsGained = newLevel - oldLevel
    
    if levelsGained > 0 then
        profile.Data.Level = newLevel
        Logger.Info("LobbyPlayerData", `🎉 {player.Name} leveled up! {oldLevel} -> {newLevel}`)
    end
    
    Logger.Info("LobbyPlayerData", `{player.Name} +{amount} XP (Level {profile.Data.Level}, Total: {profile.Data.XP})`)
    return levelsGained
end

-- Get current level
function PlayerDataService.GetLevel(player: Player): number
    local profile = Profiles[player]
    return if profile then profile.Data.Level else 1
end

-- Get current XP
function PlayerDataService.GetXP(player: Player): number
    local profile = Profiles[player]
    return if profile then profile.Data.XP else 0
end

-- ============================================
-- PLANT UNLOCK SYSTEM
-- ============================================

-- Check if player has unlocked a specific plant
function PlayerDataService.HasPlant(player: Player, plantType: string): boolean
    local profile = Profiles[player]
    if not profile then return false end
    return profile.Data.UnlockedPlants[plantType] == true
end

-- Get all unlocked plants for a player
function PlayerDataService.GetUnlockedPlants(player: Player): {string}
    local profile = Profiles[player]
    if not profile then return {"Sunflower", "Peashooter", "WallNut"} end
    
    local plants = {}
    for plantType, isUnlocked in pairs(profile.Data.UnlockedPlants) do
        if isUnlocked then
            table.insert(plants, plantType)
        end
    end
    return plants
end

-- Unlock a plant for a player (free unlock, e.g., from level reward)
function PlayerDataService.UnlockPlant(player: Player, plantType: string): boolean
    local profile = Profiles[player]
    if not profile then return false end
    
    if profile.Data.UnlockedPlants[plantType] then
        Logger.Warn("LobbyPlayerData", `{player.Name} already has {plantType}`)
        return false
    end
    
    profile.Data.UnlockedPlants[plantType] = true
    Logger.Info("LobbyPlayerData", `🌱 {player.Name} unlocked {plantType}!`)
    return true
end

-- Purchase a plant with coins
function PlayerDataService.PurchasePlant(player: Player, plantType: string, cost: number): (boolean, string?)
    local profile = Profiles[player]
    if not profile then 
        return false, "ProfileNotLoaded"
    end
    
    -- Check if already owned
    if profile.Data.UnlockedPlants[plantType] then
        return false, "AlreadyOwned"
    end
    
    -- Check if enough coins
    if profile.Data.Coins < cost then
        return false, "NotEnoughCoins"
    end
    
    -- Deduct coins and unlock
    profile.Data.Coins -= cost
    profile.Data.UnlockedPlants[plantType] = true
    
    Logger.Info("LobbyPlayerData", `💰 {player.Name} purchased {plantType} for {cost} coins (Remaining: {profile.Data.Coins})`)
    return true, nil
end

-- ============================================
-- STATS SYSTEM
-- ============================================

-- Get player stats
function PlayerDataService.GetStats(player: Player): {GamesPlayed: number, GamesWon: number, ZombiesKilled: number, PlantsPlaced: number}
    local profile = Profiles[player]
    if not profile then 
        return {GamesPlayed = 0, GamesWon = 0, ZombiesKilled = 0, PlantsPlaced = 0}
    end
    return profile.Data.Stats
end

-- Get gems
function PlayerDataService.GetGems(player: Player): number
    local profile = Profiles[player]
    return if profile then profile.Data.Gems else 0
end

-- Get total XP needed for next level
function PlayerDataService.GetXPForNextLevel(player: Player): number
    local profile = Profiles[player]
    if not profile then return 100 end
    local level = profile.Data.Level
    -- Simple formula: 100 XP per level
    return level * 100
end

-- ============================================
-- MUTATION SYSTEM
-- ============================================

local MutationData = require(Shared.data.MutationData)
local PlantData = require(Shared.data.PlantData)

-- Get mutations for a specific plant
function PlayerDataService.GetPlantMutations(player: Player, plantType: string): {string}
    local profile = Profiles[player]
    if not profile then return {} end
    return profile.Data.PlantMutations[plantType] or {}
end

-- Get all plant mutations for a player
function PlayerDataService.GetAllPlantMutations(player: Player): {[string]: {string}}
    local profile = Profiles[player]
    if not profile then return {} end
    return profile.Data.PlantMutations or {}
end

-- Check if a plant has a specific mutation
function PlayerDataService.HasMutation(player: Player, plantType: string, mutationType: string): boolean
    local mutations = PlayerDataService.GetPlantMutations(player, plantType)
    for _, mutation in mutations do
        if mutation == mutationType then
            return true
        end
    end
    return false
end

-- Purchase a mutation for a plant
function PlayerDataService.PurchaseMutation(player: Player, plantType: string, mutationType: string): (boolean, string?, number?)
    local profile = Profiles[player]
    if not profile then 
        return false, "ProfileNotLoaded", nil
    end
    
    -- Check if plant is unlocked
    if not profile.Data.UnlockedPlants[plantType] then
        return false, "PlantNotUnlocked", nil
    end
    
    -- Get mutation info
    local mutationInfo = MutationData.Get(mutationType)
    if not mutationInfo then
        return false, "InvalidMutation", nil
    end
    
    -- Check player level requirement
    if profile.Data.Level < mutationInfo.RequiredLevel then
        return false, "LevelTooLow", nil
    end
    
    -- Check if already has this mutation
    if PlayerDataService.HasMutation(player, plantType, mutationType) then
        return false, "AlreadyHas", nil
    end
    
    -- Check plant category compatibility
    local plantStats = PlantData.Get(plantType)
    if plantStats then
        local category = plantStats.Category
        if not MutationData.IsCompatibleWith(mutationType, category) then
            return false, "Incompatible", nil
        end
    end
    
    -- Check incompatibility with existing mutations
    local existingMutations = PlayerDataService.GetPlantMutations(player, plantType)
    for _, existingMutation in existingMutations do
        if not MutationData.AreCompatible(mutationType, existingMutation) then
            return false, "Incompatible", nil
        end
    end
    
    -- Check if enough coins
    if profile.Data.Coins < mutationInfo.Cost then
        return false, "NotEnoughCoins", nil
    end
    
    -- Deduct coins
    profile.Data.Coins -= mutationInfo.Cost
    
    -- Add mutation
    if not profile.Data.PlantMutations[plantType] then
        profile.Data.PlantMutations[plantType] = {}
    end
    table.insert(profile.Data.PlantMutations[plantType], mutationType)
    
    Logger.Info("LobbyPlayerData", `🧬 {player.Name} purchased {mutationType} mutation for {plantType} (Cost: {mutationInfo.Cost}, Remaining: {profile.Data.Coins})`)
    return true, nil, profile.Data.Coins
end

-- Remove a mutation from a plant
function PlayerDataService.RemoveMutation(player: Player, plantType: string, mutationType: string): boolean
    local profile = Profiles[player]
    if not profile then return false end
    
    local mutations = profile.Data.PlantMutations[plantType]
    if not mutations then return false end
    
    for i, mutation in mutations do
        if mutation == mutationType then
            table.remove(mutations, i)
            Logger.Info("LobbyPlayerData", `🧬 {player.Name} removed {mutationType} mutation from {plantType}`)
            return true
        end
    end
    
    return false
end

return PlayerDataService
