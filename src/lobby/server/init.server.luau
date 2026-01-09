--!strict
--[[
    Lobby Server Bootstrap
    
    Initializes the Lobby place:
    - Loads player profiles via ProfileStore
    - Handles TeleportService requests to Arena
    - Manages lobby-specific state (no ECS needed here)
]]

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise = require(Packages:WaitForChild("Promise"))
local Trove = require(Packages:WaitForChild("Trove"))

-- Trove for server-level connection cleanup
local _serverTrove = Trove.new()

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ErrorHandler = require(Shared.utils.ErrorHandler)
local TeleportData = require(Shared.data.TeleportData)
local WorldData = require(Shared.data.WorldData)
local DifficultyData = require(Shared.data.DifficultyData)
local PlantData = require(Shared.data.PlantData)
local TeleportDataHandler = require(Shared.services.TeleportDataHandler)

-- Import services from this folder
local PlayerDataService = require(script.services.PlayerDataService)
local LobbyService = require(script.services.LobbyService)

-- Import modules
local ShopHandler = require(script.modules.ShopHandler)
local MutationHandler = require(script.modules.MutationHandler)
local DevCommands = require(script.modules.DevCommands)

-- Network (unified Zap schema in shared/network)
local ZapServer = require(Shared.network.generated.server)

-- Initialize services
PlayerDataService.Initialize()
Logger.Info("Lobby", "PlayerDataService initialized")

-- Initialize LobbyService (teleport pads)
LobbyService.Initialize(ZapServer)
Logger.Info("Lobby", "LobbyService initialized")

-- Initialize ShopHandler
ShopHandler.Initialize()
Logger.Info("Lobby", "ShopHandler initialized")

-- Initialize MutationHandler
MutationHandler.Initialize()
Logger.Info("Lobby", "MutationHandler initialized")

-- Initialize DevCommands
DevCommands.Initialize(PlayerDataService)
Logger.Info("Lobby", "DevCommands initialized")

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
    
    -- Check if PlaceIds are configured
    if TeleportData.PlaceIds.Arena == 0 then
        Logger.Warn("Lobby", "Arena PlaceId not configured - skipping teleport in Studio")
        -- In Studio without configured PlaceIds, just log success
        return true, 0, "Teleport simulated (Studio mode)"
    end
    
    -- Get equipped mutations for the deck plants
    local equippedMutations = PlayerDataService.GetAllEquippedMutations(player) or {}
    
    -- Create teleport data
    local teleportOptions = Instance.new("TeleportOptions")
    local arenaData = TeleportData.CreateArenaJoinData(worldId, difficulty, deck, equippedMutations)
    teleportOptions:SetTeleportData(arenaData)
    
    -- Teleport to Arena with Promise.retry (non-blocking)
    Promise.retry(function()
        return Promise.new(function(resolve, reject)
            if player.Parent ~= Players then
                reject("Player left the game")
                return
            end
            
            TeleportService:TeleportAsync(
                TeleportData.PlaceIds.Arena,
                { player },
                teleportOptions
            )
            resolve()
        end)
    end, 3, function(attempt)
        Logger.Warn("Lobby", `Teleport attempt {attempt} failed for {player.Name}, retrying...`)
        return 2 * attempt -- Exponential backoff
    end):andThen(function()
        Logger.Info("Lobby", `{player.Name} teleported to Arena`)
    end):catch(function(err)
        Logger.Error("Lobby", `Teleport failed for {player.Name} after 3 attempts: {err}`)
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

-- Handle DevCommand request
ZapServer.DevCommand.SetCallback(function(player, data)
	local command = data.Command
	local stringArg = data.StringArg
	local numberArg = data.NumberArg
	
	Logger.Info("Lobby", `DevCommand received: command={command}, type={typeof(command)}`)
	
	local success, message = DevCommands.HandleCommand(player, command, stringArg, numberArg)
	
	-- Send response
	ZapServer.DevCommandResponse.Fire(player, {
		Success = success,
		Message = message,
	})
	
	-- If successful, sync player data
	if success then
		-- Use ShopHandler to sync data properly (converts dict to array)
		ShopHandler.SyncPlayerData(player)
	end
end)

