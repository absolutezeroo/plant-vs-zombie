--!strict
--[[
    DeckBuilderController.luau - Manages deck selection zone
    
    Responsibilities:
    - Listen for ProximityPrompt on DeckBuilderZone
    - Open DeckBuilder GUI
    - Send selected deck to server
    - Receive confirmation and update local state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PlantData = require(Shared.data.PlantData)

-- Network (unified Zap schema in shared/network)
local ZapClient = require(Shared.network.generated.client)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local DeckBuilderController = {}

-- Trove for connection cleanup
local _trove = Trove.new()

-- Current deck state (reactive)
local currentDeck = Fusion.Value({} :: {string})

-- Open deck builder GUI
local function openDeckBuilder()
    Logger.Info("DeckBuilder", "Opening deck builder")
    
    -- TODO: Create dedicated DeckBuilder GUI
    -- For now, just log
    Logger.Info("DeckBuilder", "Deck builder not yet implemented")
end

-- Save deck to server
local function saveDeck(deck: {string})
    Logger.Info("DeckBuilder", "Saving deck", {deckSize = #deck})
    
    -- Convert to Zap enum array
    local deckEnums = {}
    for i, plantType in deck do
        deckEnums[i] = plantType
    end
    
    ZapClient.SaveDeck.Fire({
        Deck = deckEnums :: any,
    })
end

-- Listen for deck changes from server
ZapClient.DeckChanged.On(function(data)
    local deck = {}
    for i, plantType in data.Deck do
        deck[i] = plantType
    end
    
    currentDeck:set(deck)
    Logger.Info("DeckBuilder", "Deck updated from server", {deckSize = #deck})
end)

-- Initialize (called from init.client.luau)
function DeckBuilderController.Initialize()
    Logger.Info("DeckBuilder", "DeckBuilderController initialized")
    
    -- Find DeckBuilderZone in workspace
    local workspace = game:GetService("Workspace")
    local deckZone = workspace:FindFirstChild("DeckBuilderZone", true)
    
    if deckZone then
        -- Find ProximityPrompt
        local prompt = deckZone:FindFirstChildOfClass("ProximityPrompt", true)
        if prompt then
            _trove:Connect(prompt.Triggered, function(player)
                if player == LocalPlayer then
                    openDeckBuilder()
                end
            end)
            Logger.Info("DeckBuilder", "ProximityPrompt connected")
        else
            Logger.Warn("DeckBuilder", "No ProximityPrompt found in DeckBuilderZone")
        end
    else
        Logger.Warn("DeckBuilder", "DeckBuilderZone not found in workspace")
    end
end

-- Get current deck (for other systems)
function DeckBuilderController.GetDeck(): {string}
    return Fusion.peek(currentDeck)
end

return DeckBuilderController
