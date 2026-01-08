--!strict
--[[
    ShopHandler.luau - Handles shop purchase requests
    
    Listens for PurchasePlantRequest and validates/processes purchases.
    Uses PlayerDataService for data persistence and ProgressionData for costs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionData = require(Shared.data.ProgressionData)
local Logger = require(Shared.utils.Logger)

-- Network (generated from Zap)
local Server = script.Parent.Parent
local Network = require(Server.network.generated)

-- Services
local Services = Server.services
local PlayerDataService = require(Services.PlayerDataService)

local ShopHandler = {}

-- Convert PlantType enum to string (Zap generates numbers)
local function plantEnumToString(plantEnum: any): string?
    -- The network layer should handle this, but just in case
    if type(plantEnum) == "string" then
        return plantEnum
    end
    return nil
end

-- Send full player data sync to a player
function ShopHandler.SyncPlayerData(player: Player)
    local coins = PlayerDataService.GetCoins(player)
    local gems = PlayerDataService.GetGems(player)
    local level = PlayerDataService.GetLevel(player)
    local xp = PlayerDataService.GetXP(player)
    local xpForNext = PlayerDataService.GetXPForNextLevel(player)
    local stats = PlayerDataService.GetStats(player)
    local unlockedPlants = PlayerDataService.GetUnlockedPlants(player)
    local deck = PlayerDataService.GetDeck(player) or {"Sunflower", "Peashooter", "WallNut"}
    
    Network.FullPlayerDataSync.Fire(player, {
        Coins = coins,
        Gems = gems,
        Level = level,
        XP = xp,
        TotalXPForNextLevel = xpForNext,
        GamesPlayed = stats.GamesPlayed,
        GamesWon = stats.GamesWon,
        ZombiesKilled = stats.ZombiesKilled,
        PlantsPlaced = stats.PlantsPlaced,
        UnlockedPlants = unlockedPlants,
        Deck = deck,
    })
    
    Logger.Debug("ShopHandler", `Synced full player data to {player.Name}`)
end

-- Handle purchase request
local function onPurchasePlantRequest(player: Player, data: {PlantType: any})
    local plantType = data.PlantType
    
    -- Convert to string if needed
    if type(plantType) ~= "string" then
        plantType = tostring(plantType)
    end
    
    Logger.Info("ShopHandler", `{player.Name} wants to purchase {plantType}`)
    
    -- Get plant unlock info
    local unlockInfo = ProgressionData.PlantUnlocks[plantType]
    if not unlockInfo then
        Logger.Warn("ShopHandler", `Invalid plant type: {plantType}`)
        Network.PurchasePlantResponse.Fire(player, {
            Success = false,
            PlantType = plantType,
            ErrorCode = 3, -- InvalidPlant
            NewCoins = nil,
        })
        return
    end
    
    -- Check if already owned
    if PlayerDataService.HasPlant(player, plantType) then
        Network.PurchasePlantResponse.Fire(player, {
            Success = false,
            PlantType = plantType,
            ErrorCode = 1, -- AlreadyOwned
            NewCoins = nil,
        })
        return
    end
    
    -- Check coins
    local currentCoins = PlayerDataService.GetCoins(player)
    local cost = unlockInfo.Cost
    
    if currentCoins < cost then
        Network.PurchasePlantResponse.Fire(player, {
            Success = false,
            PlantType = plantType,
            ErrorCode = 2, -- NotEnoughCoins
            NewCoins = nil,
        })
        return
    end
    
    -- Process purchase
    local success, err = PlayerDataService.PurchasePlant(player, plantType, cost)
    
    if success then
        local newCoins = PlayerDataService.GetCoins(player)
        Network.PurchasePlantResponse.Fire(player, {
            Success = true,
            PlantType = plantType,
            ErrorCode = nil,
            NewCoins = newCoins,
        })
        
        -- Also sync unlocked plants
        local unlockedPlants = PlayerDataService.GetUnlockedPlants(player)
        Network.SyncUnlockedPlants.Fire(player, {
            UnlockedPlants = unlockedPlants,
        })
        
        Logger.Info("ShopHandler", `✅ {player.Name} purchased {plantType}!`)
    else
        Logger.Warn("ShopHandler", `Purchase failed for {player.Name}: {err or "unknown"}`)
        Network.PurchasePlantResponse.Fire(player, {
            Success = false,
            PlantType = plantType,
            ErrorCode = 2, -- Fallback to NotEnoughCoins
            NewCoins = nil,
        })
    end
end

-- Handle full data request
local function onRequestPlayerData(player: Player, _data: {})
    ShopHandler.SyncPlayerData(player)
end

function ShopHandler.Initialize()
    Logger.Info("ShopHandler", "Initializing Shop Handler...")
    
    -- Listen for purchase requests
    Network.PurchasePlantRequest.SetCallback(onPurchasePlantRequest)
    
    -- Listen for data sync requests
    Network.RequestPlayerData.SetCallback(onRequestPlayerData)
    
    Logger.Info("ShopHandler", "✅ Shop Handler ready")
end

return ShopHandler
