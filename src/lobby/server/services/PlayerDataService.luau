--!strict
--[[
    Lobby Services - Re-exports from server/services
    
    For the Lobby place, we need access to PlayerDataService
    but not the full Arena game logic.
]]

local _Server = game:GetService("ServerScriptService"):WaitForChild("LobbyServer") -- Reserved for future use

-- PlayerDataService is the same across both places
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
    CurrentStage = "1-1",
    CompletedStages = {} :: {[string]: number},
    UnlockedPlants = {
        Sunflower = true,
        Peashooter = true,
        WallNut = true,
    },
    PlantUpgrades = {},
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
local Profiles: { [Player]: typeof(Store:StartSessionAsync(nil :: any)) } = {}

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
end

function PlayerDataService.GetProfile(player: Player)
    return Profiles[player]
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

return PlayerDataService
