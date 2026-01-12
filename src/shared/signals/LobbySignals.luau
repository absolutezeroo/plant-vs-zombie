--!strict
--[[
    LobbySignals.luau - Centralized event signals for Lobby client
    
    PURPOSE:
    Decouples Network listeners from UI Controllers using the Observer pattern.
    Network listeners FIRE signals, Controllers LISTEN via Trove:Connect().
    
    USAGE:
    -- Emitter (Network listener in init.client.luau):
    LobbySignals.OnPlayerDataSync:Fire({ Data = profileData })
    
    -- Consumer (ZoneInteractionController):
    _trove:Connect(LobbySignals.OnPlayerDataSync, function(data)
        self:SetPlayerData(data.Data)
    end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages:WaitForChild("Signal"))

local LobbySignals = {}

--------------------------------------------------------------------------------
-- PLAYER DATA SIGNALS
--------------------------------------------------------------------------------

--[[
    Fired when full player data is synced from server.
    Payload: { Data: ProfileData }
]]
LobbySignals.OnPlayerDataSync = Signal.new()

--[[
    Fired when deck is updated.
    Payload: { Deck: {string} }
]]
LobbySignals.OnDeckUpdated = Signal.new()

--[[
    Fired when mutations are synced.
    Payload: { Owned: {[string]: {string}}, Equipped: {[string]: {string}} }
]]
LobbySignals.OnMutationsSync = Signal.new()

--------------------------------------------------------------------------------
-- TELEPORT PAD SIGNALS
--------------------------------------------------------------------------------

--[[
    Fired when player joins a teleport pad.
    Payload: { PadId: string, WorldId: string, Difficulty: string }
]]
LobbySignals.OnPadJoined = Signal.new()

--[[
    Fired when player leaves a teleport pad.
    Payload: {}
]]
LobbySignals.OnPadLeft = Signal.new()

--[[
    Fired when pad countdown updates.
    Payload: { TimeRemaining: number }
]]
LobbySignals.OnPadCountdown = Signal.new()

--------------------------------------------------------------------------------
-- SHOP/ECONOMY SIGNALS
--------------------------------------------------------------------------------

--[[
    Fired when a plant purchase completes.
    Payload: { Success: boolean, PlantType: string, NewCoins: number? }
]]
LobbySignals.OnPurchasePlantResponse = Signal.new()

--[[
    Fired when a mutation purchase completes.
    Payload: { Success: boolean, PlantType: string, MutationType: string }
]]
LobbySignals.OnPurchaseMutationResponse = Signal.new()

--[[
    Fired when arena results should be displayed.
    Payload: { WorldId: string, Difficulty: string, Victory: boolean, Stars: number, CoinsEarned: number, XPEarned: number }
]]
LobbySignals.OnBattleResultsSync = Signal.new()

return table.freeze(LobbySignals)
