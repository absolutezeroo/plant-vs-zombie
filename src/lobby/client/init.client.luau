--!strict
--[[
    Lobby Client Bootstrap
    
    Initializes the interactive 3D Lobby:
    - HUD minimal (coins, level, deck)
    - PadUIController for teleport pads (BillboardGui + leave button)
    - ZoneInteractionController for Shop/DeckBuilder/Profile zones
    - Network event handling
    
    The lobby is a 3D interactive world, NOT a full-screen menu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

-- Disable default Roblox UI elements
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local TeleportData = require(Shared.data.TeleportData)

-- Import Zap generated network module
local ZapClient = require(script:WaitForChild("network"):WaitForChild("generated"))

-- Import UI components
local LobbyHUD = require(script:WaitForChild("ui"):WaitForChild("LobbyHUD"))

-- Import controllers
local PadUIController = require(script:WaitForChild("controllers"):WaitForChild("PadUIController"))
local ZoneInteractionController = require(script:WaitForChild("controllers"):WaitForChild("ZoneInteractionController"))
local UIStateManager = require(script:WaitForChild("controllers"):WaitForChild("UIStateManager"))

-- Get local player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

Logger.Info("LobbyClient", `Initializing 3D lobby for {LocalPlayer.Name}`)

-- Create a scope for Fusion cleanup
local scope = Fusion.scoped(Fusion)

-- ============================================
-- REACTIVE STATE
-- ============================================

type PlayerData = {
    Coins: number,
    Gems: number,
    Level: number,
    XP: number,
    TotalXPForNextLevel: number,
    GamesPlayed: number,
    GamesWon: number,
    ZombiesKilled: number,
    PlantsPlaced: number,
    UnlockedPlants: {string},
    Deck: {string},
}

local playerData = scope:Value(nil :: PlayerData?)
local currentDeck = scope:Value({} :: {string})

-- ============================================
-- NETWORK FUNCTIONS
-- ============================================

local function requestPlayerData()
    Logger.Info("LobbyClient", "Requesting player data from server...")
    ZapClient.RequestPlayerData.Fire({})
end

local function purchasePlant(plantType: string)
    Logger.Info("LobbyClient", `Purchasing plant: {plantType}`)
    ZapClient.PurchasePlantRequest.Fire({
        PlantType = plantType,
    })
end

local function saveDeck(deck: {string})
    Logger.Info("LobbyClient", `Saving deck with {#deck} plants`)
    ZapClient.SaveDeck.Fire({
        Deck = deck,
    })
    currentDeck:set(deck)
end

-- ============================================
-- CHECK RETURN DATA FROM ARENA
-- ============================================

local function checkReturnData()
    local joinData = LocalPlayer:GetJoinData()
    if joinData.TeleportData then
        local data = joinData.TeleportData
        local isValid = TeleportData.ValidateLobbyReturnData(data)
        if isValid then
            Logger.Info("LobbyClient", "Returned from Arena with results", {
                victory = data.Victory,
                stars = data.Stars,
            })
            -- Could show a results popup here
        end
    end
end

-- ============================================
-- INITIALIZE CONTROLLERS
-- ============================================

-- Initialize Pad UI Controller (BillboardGui on pads + leave button)
PadUIController.Initialize()
Logger.Info("LobbyClient", "✅ PadUIController initialized")

-- Initialize Zone Interaction Controller (Shop, DeckBuilder, Profile)
ZoneInteractionController.Initialize()
ZoneInteractionController.SetOnPurchasePlant(purchasePlant)
ZoneInteractionController.SetOnSaveDeck(saveDeck)
Logger.Info("LobbyClient", "✅ ZoneInteractionController initialized")

-- ============================================
-- MOUNT HUD
-- ============================================

local hudGui = LobbyHUD(scope, {
    PlayerData = playerData,
    CurrentDeck = currentDeck,
})
hudGui.Parent = PlayerGui

-- Register HUD with UIStateManager (will be hidden when in queue)
UIStateManager.Register("LobbyHUD", hudGui)

Logger.Info("LobbyClient", "✅ LobbyHUD mounted")

-- ============================================
-- NETWORK EVENT LISTENERS
-- ============================================

-- Listen for teleport response
ZapClient.TeleportToArenaResponse.On(function(response)
    if response.Success then
        Logger.Info("LobbyClient", "Teleport initiated successfully!")
    else
        Logger.Warn("LobbyClient", `Teleport failed: {response.ErrorMessage or "Unknown error"}`)
    end
end)

-- Listen for full player data sync
ZapClient.FullPlayerDataSync.On(function(data)
    Logger.Info("LobbyClient", `Received player data: Level={data.Level}, Coins={data.Coins}`)
    
    local newData: PlayerData = {
        Coins = data.Coins,
        Gems = data.Gems,
        Level = data.Level,
        XP = data.XP,
        TotalXPForNextLevel = data.TotalXPForNextLevel,
        GamesPlayed = data.GamesPlayed,
        GamesWon = data.GamesWon,
        ZombiesKilled = data.ZombiesKilled,
        PlantsPlaced = data.PlantsPlaced,
        UnlockedPlants = data.UnlockedPlants,
        Deck = data.Deck,
    }
    
    playerData:set(newData)
    currentDeck:set(data.Deck or {})
    
    -- Update ZoneInteractionController
    ZoneInteractionController.SetPlayerData(newData)
end)

-- Listen for purchase response
ZapClient.PurchasePlantResponse.On(function(response)
    if response.Success then
        Logger.Info("LobbyClient", `✅ Purchased {response.PlantType}! New balance: {response.NewCoins}`)
        -- Request updated player data
        requestPlayerData()
    else
        local errorMsg = response.ErrorCode == 1 and "Already owned"
            or response.ErrorCode == 2 and "Not enough coins"
            or response.ErrorCode == 3 and "Invalid plant"
            or "Unknown error"
        Logger.Warn("LobbyClient", `❌ Purchase failed: {errorMsg}`)
    end
end)

-- Listen for unlocked plants sync
ZapClient.SyncUnlockedPlants.On(function(data)
    Logger.Info("LobbyClient", `Synced {#data.UnlockedPlants} unlocked plants`)
    
    -- Update player data
    local current = Fusion.peek(playerData)
    if current then
        current.UnlockedPlants = data.UnlockedPlants
        playerData:set(current)
    end
    
    -- Update ZoneInteractionController
    ZoneInteractionController.UpdateUnlockedPlants(data.UnlockedPlants)
end)

-- Listen for deck changes
ZapClient.DeckChanged.On(function(data)
    Logger.Info("LobbyClient", `Deck updated: {#data.Deck} plants`)
    currentDeck:set(data.Deck)
    ZoneInteractionController.UpdateDeck(data.Deck)
end)

-- Listen for battle results
ZapClient.ShowResults.On(function(results)
    Logger.Info("LobbyClient", "Battle results received", {
        victory = results.Victory,
        stars = results.Stars,
        coins = results.CoinsEarned,
        xp = results.XPEarned,
    })
    
    -- Refresh player data after battle
    requestPlayerData()
end)

-- ============================================
-- STARTUP
-- ============================================

-- Check for return data from arena
checkReturnData()

-- Request initial player data
task.defer(requestPlayerData)

Logger.Info("LobbyClient", "✅ 3D Lobby client fully initialized")
