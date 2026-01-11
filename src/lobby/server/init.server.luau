--!strict
--[[
    Lobby Server Bootstrap
    
    Initializes the Lobby place:
    - Loads player profiles via ProfileStore
    - Handles TeleportService requests to Arena
    - Manages lobby-specific state (no ECS needed here)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

-- Trove for server-level connection cleanup
local _serverTrove = Trove.new()

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local TeleportData = require(Shared.data.TeleportData)
local WorldData = require(Shared.data.WorldData)
local DifficultyData = require(Shared.data.DifficultyData)
local PlantData = require(Shared.data.PlantData)
local TeleportDataHandler = require(Shared.services.TeleportDataHandler)

-- Import services from this folder
local PlayerDataService = require(script.services.PlayerDataService)
local LobbyService = require(script.services.LobbyService)

-- Import managers
local TeleportManager = require(script.managers.TeleportManager)

-- Import modules
local ShopHandler = require(script.modules.ShopHandler)
local MutationHandler = require(script.modules.MutationHandler)

-- Network (unified Zap schema in shared/network)
local ZapServer = require(Shared.network.generated.server)

-- Initialize services
PlayerDataService.Initialize()
Logger.Info("Lobby", "PlayerDataService initialized")

-- Initialize ShopHandler EARLY (before client can request data)
-- This sets up RequestPlayerData.SetCallback before any client requests arrive
ShopHandler.Initialize()
Logger.Info("Lobby", "ShopHandler initialized")

-- Initialize MutationHandler EARLY (for mutation sync)
MutationHandler.Initialize()
Logger.Info("Lobby", "MutationHandler initialized")

-- Initialize LobbyService (teleport pads) - can be slow, do after network handlers
LobbyService.Initialize(ZapServer)
Logger.Info("Lobby", "LobbyService initialized")

-- Note: Dev commands are now handled by Cmdr (see cmdr/init.server.luau)

-- Initialize TeleportDataHandler for Lobby (handles return from Arena)
TeleportDataHandler.InitializeLobby({
    PlayerDataService = PlayerDataService,
})
Logger.Info("Lobby", "TeleportDataHandler initialized")

-- Subscribe to OnPlayerReturned to show results UI
_serverTrove:Connect(TeleportDataHandler.OnPlayerReturned, function(player: Player, returnData: TeleportData.LobbyReturnData)
    Logger.Info("Lobby", `{player.Name} returned from Arena: Victory={returnData.Victory}, Stars={returnData.Stars}`)
    
    -- Send results to client for display
    ZapServer.ShowResults.Fire(player, {
        WorldId = returnData.WorldId,
        Difficulty = returnData.Difficulty,
        Victory = returnData.Victory,
        Stars = returnData.Stars,
        CoinsEarned = returnData.CoinsEarned,
        XPEarned = returnData.XPEarned,
    })
end)

-- Track players in lobby
local playersInLobby: { [Player]: boolean } = {}

--[[
    Handle teleport request from client
    Validates deck and world/difficulty before teleporting
]]
local function handleTeleportToArena(player: Player, worldId: string, difficulty: string, deck: { string }): (boolean, number, string)
    Logger.Info("Lobby", `{player.Name} requesting teleport to World={worldId}, Difficulty={difficulty}`)
    
    -- Validate world exists (data-driven via WorldData)
    local world = WorldData.GetWorld(worldId)
    if not world then
        Logger.Warn("Lobby", `Invalid world: {worldId}`)
        return false, 1, "Invalid world"
    end
    
    -- Validate difficulty exists (data-driven via DifficultyData)
    local diffConfig = DifficultyData.GetDifficulty(difficulty)
    if not diffConfig then
        Logger.Warn("Lobby", `Invalid difficulty: {difficulty}`)
        return false, 1, "Invalid difficulty"
    end
    
    -- Validate deck
    if #deck < 1 or #deck > 6 then
        Logger.Warn("Lobby", `Invalid deck size: {#deck}`)
        return false, 2, "Deck must have 1-6 plants"
    end
    
    -- Validate player owns all plants in deck
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        Logger.Warn("Lobby", `No profile for {player.Name}`)
        return false, 2, "Profile not loaded"
    end
    
    local unlockedPlants = profile.Data.UnlockedPlants or {}
    for _, plantType in deck do
        if not PlantData[plantType] then
            Logger.Warn("Lobby", `Invalid plant type: {plantType}`)
            return false, 2, `Invalid plant: {plantType}`
        end
        
        -- Check if plant is unlocked
        if not unlockedPlants[plantType] then
            Logger.Warn("Lobby", `{player.Name} doesn't own {plantType}`)
            return false, 3, `Plant not unlocked: {plantType}`
        end
    end
    
    -- Use TeleportManager for reserved server teleportation
    -- This ensures players get their own private server
    TeleportManager.GetInstance():TeleportPlayerAsync(player, worldId, difficulty)
        :andThen(function(result)
            if result.Success then
                Logger.Info("Lobby", `{player.Name} teleported to private Arena`)
            else
                Logger.Error("Lobby", `Teleport failed for {player.Name}: {result.Error or "Unknown error"}`)
            end
        end)
        :catch(function(err)
            Logger.Error("Lobby", `Teleport promise failed for {player.Name}: {err}`)
        end)
    
    return true, 0, "Teleporting..."
end

--[[
    Handle player joining Lobby
    NOTE: TeleportDataHandler now handles return data processing (rewards, etc.)
    This function just tracks players in lobby
]]
local function onPlayerAdded(player: Player)
    Logger.Info("Lobby", `{player.Name} joined lobby`)
    playersInLobby[player] = true
end

local function onPlayerRemoving(player: Player)
	Logger.Info("Lobby", `{player.Name} leaving lobby`)
	playersInLobby[player] = nil
end

-- Connect player events
_serverTrove:Connect(Players.PlayerAdded, onPlayerAdded)
_serverTrove:Connect(Players.PlayerRemoving, onPlayerRemoving)

-- Handle players already in game (Studio testing)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end

-- Setup network event handlers (Zap generated)
ZapServer.TeleportToArenaRequest.SetCallback(function(player, data)
    -- Convert Zap enum array to string array
    local deckStrings: { string } = {}
    for i, plantType in data.Deck do
        deckStrings[i] = plantType
    end
    
    local success, errorCode, message = handleTeleportToArena(player, data.WorldId, data.Difficulty, deckStrings)
    
    -- Send response to client
    ZapServer.TeleportToArenaResponse.Fire(player, {
        Success = success,
        ErrorCode = if success then nil else errorCode,
        ErrorMessage = if success then nil else message,
    })
    
    if success then
        Logger.Info("Lobby", `{player.Name} teleport initiated: {message}`)
    end
end)

-- Handle SaveDeck request
ZapServer.SaveDeck.SetCallback(function(player, data)
	-- Convert Zap enum array to string array
	local deckStrings: { string } = {}
	for i, plantType in data.Deck do
		deckStrings[i] = plantType
	end
	
	-- Save to profile
	local success = PlayerDataService.SetDeck(player, deckStrings)
	
	if success then
		-- Confirm to client
		ZapServer.DeckChanged.Fire(player, {
			Deck = data.Deck,
		})
		Logger.Info("Lobby", `{player.Name} deck saved`, {deckSize = #deckStrings})
	else
		Logger.Warn("Lobby", `Failed to save deck for {player.Name}`)
	end
end)

