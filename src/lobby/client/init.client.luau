--!strict
--[[
    Lobby Client Bootstrap
    
    Initializes the Lobby UI:
    - Mounts LobbyScreen with Fusion
    - Handles stage selection, deck building
    - Sends teleport requests to server
    
    Note: No ECS loop needed in Lobby - it's purely UI-driven
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

-- Fusion imports
local Children = Fusion.Children

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local TeleportData = require(Shared.TeleportData)

-- Import UI components - ui is a child of the init script's container
local LobbyScreen = require(script:WaitForChild("ui"):WaitForChild("LobbyScreen"))

-- Get local player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

Logger.Info("LobbyClient", `Initializing lobby for {LocalPlayer.Name}`)

-- Create a scope for Fusion cleanup (pass Fusion to get New, Value, etc.)
local scope = Fusion.scoped(Fusion)

-- Reactive state for lobby
local lobbyState = {
    SelectedStage = scope:Value(nil :: string?),
    SelectedDeck = scope:Value({} :: { string }),
    IsLoading = scope:Value(false),
    ReturnData = scope:Value(nil :: TeleportData.LobbyReturnData?),
}

-- Check if player returned from Arena with results
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
            lobbyState.ReturnData:set(data :: TeleportData.LobbyReturnData)
        end
    end
end

checkReturnData()

-- Mount the Lobby UI (using scoped New for Fusion 0.3)
local screenGui = scope:New "ScreenGui" {
    Name = "LobbyUI",
    Parent = PlayerGui,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    
    [Children] = {
        LobbyScreen({
            SelectedStage = lobbyState.SelectedStage,
            SelectedDeck = lobbyState.SelectedDeck,
            IsLoading = lobbyState.IsLoading,
            ReturnData = lobbyState.ReturnData,
            
            OnPlayClicked = function(stageId: string, deck: { string })
                Logger.Info("LobbyClient", `Play clicked: {stageId}`, { deckSize = #deck })
                lobbyState.IsLoading:set(true)
                
                -- TODO: Send request via Zap after adding to packets.zap
                -- ZapClient.TeleportToArenaRequest:Fire({
                --     StageId = stageId,
                --     Deck = deck,
                -- })
                
                -- For now, log the action
                Logger.Info("LobbyClient", "Would teleport to Arena", {
                    stage = stageId,
                    deck = deck,
                })
            end,
        }),
    },
}

Logger.Info("LobbyClient", "Lobby UI mounted")

-- Cleanup on player leaving (shouldn't happen in lobby, but safety)
LocalPlayer.AncestryChanged:Connect(function()
    if not LocalPlayer:IsDescendantOf(game) then
        screenGui:Destroy()
    end
end)
