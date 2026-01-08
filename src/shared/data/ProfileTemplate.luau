--!strict
--[[
    ProfileTemplate.luau - Single source of truth for player profile structure
    
    Used by both Lobby and Arena PlayerDataService.
    Any changes here will affect both places.
]]

export type ProfileData = {
    -- Currency
    Coins: number,
    TotalCoinsEarned: number,
    Gems: number,
    TotalGemsEarned: number,
    
    -- XP and Level system
    XP: number,
    Level: number,
    
    -- Unlocked plants (starter plants are unlocked by default)
    UnlockedPlants: {[string]: boolean},
    
    -- Owned mutations (purchased, per plant)
    PlantOwnedMutations: {[string]: {string}}, -- [PlantType] = {"Fire", "Swift", ...}
    
    -- Equipped mutations (active on plant)
    PlantEquippedMutations: {[string]: {string}}, -- [PlantType] = {"Fire", "Swift", ...}
    
    -- Plant mastery system (cosmetic XP tracking)
    PlantMastery: {[string]: { Rank: number, XP: number }},
    
    -- Statistics
    Stats: {
        GamesPlayed: number,
        GamesWon: number,
        ZombiesKilled: number,
        PlantsPlaced: number,
    },
    
    -- Settings
    Settings: {
        MusicVolume: number,
        SFXVolume: number,
    },
    
    -- Deck loadout (up to 6 plant slots)
    Deck: {string},
}

local ProfileTemplate = {
    -- Default starter plants (unlocked for all new players)
    STARTER_PLANTS = {
        "Sunflower",
        "Peashooter",
        "WallNut",
    },
    
    -- Maximum deck size
    MAX_DECK_SIZE = 6,
    
    -- Maximum mutations per plant
    MAX_MUTATIONS_PER_PLANT = 4,
}

-- Default profile for new players
ProfileTemplate.PROFILE_TEMPLATE = {
    Coins = 0,
    TotalCoinsEarned = 0,
    Gems = 0,
    TotalGemsEarned = 0,

    -- XP and Level system
    XP = 0,
    Level = 1,

    -- Unlocked plants (starter plants are unlocked by default)
    UnlockedPlants = {
        Sunflower = true,
        Peashooter = true,
        WallNut = true,
    },
    
    -- Owned mutations (purchased, per plant)
    PlantOwnedMutations = {} :: {[string]: {string}},

    -- Equipped mutations (active on plant)
    PlantEquippedMutations = {} :: {[string]: {string}},

    -- Plant mastery system (cosmetic XP tracking)
    PlantMastery = {} :: {[string]: { Rank: number, XP: number }},

    -- Statistics
    Stats = {
        GamesPlayed = 0,
        GamesWon = 0,
        ZombiesKilled = 0,
        PlantsPlaced = 0,
    },
    
    -- Settings
    Settings = {
        MusicVolume = 1.0,
        SFXVolume = 1.0,
    },

    -- Deck loadout (6 plant slots)
    Deck = {
        "Sunflower",
        "Peashooter",
        "WallNut",
        -- Slots 4-6 empty by default
    },
} :: ProfileData

return ProfileTemplate
