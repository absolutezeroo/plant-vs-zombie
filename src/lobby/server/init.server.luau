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

-- Import shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ErrorHandler = require(Shared.utils.ErrorHandler)
local TeleportData = require(Shared.data.TeleportData)
local WorldData = require(Shared.data.WorldData)
local DifficultyData = require(Shared.data.DifficultyData)
local PlantData = require(Shared.data.PlantData)

-- Import services from this folder
local PlayerDataService = require(script.services.PlayerDataService)
local LobbyService = require(script.services.LobbyService)

-- Import Zap generated network module
local ZapServer = require(script.network.generated)

-- Initialize services
PlayerDataService.Initialize()
Logger.Info("Lobby", "PlayerDataService initialized")

-- Initialize LobbyService (teleport pads)
LobbyService.Initialize(ZapServer)
Logger.Info("Lobby", "LobbyService initialized")

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
    
    -- Create teleport data
    local teleportOptions = Instance.new("TeleportOptions")
    local arenaData = TeleportData.CreateArenaJoinData(worldId, difficulty, deck)
    teleportOptions:SetTeleportData(arenaData)
    
    -- Teleport to Arena
    local success, err = pcall(function()
        TeleportService:TeleportAsync(
            TeleportData.PlaceIds.Arena,
            { player },
            teleportOptions
        )
    end)
    
    if not success then
        Logger.Error("Lobby", `Teleport failed: {err}`)
        return false, 4, `Teleport failed: {err}`
    end
    
    return true, 0, "Teleporting..."
end

--[[
    Handle player joining Lobby
    Could be fresh join or return from Arena
]]
local function onPlayerAdded(player: Player)
    Logger.Info("Lobby", `{player.Name} joined lobby`)
    playersInLobby[player] = true
    
    -- Check if returning from Arena with results
    local teleportData = player:GetJoinData().TeleportData
    if teleportData then
        local isValid, err = TeleportData.ValidateLobbyReturnData(teleportData)
        if isValid then
			local returnData = teleportData :: TeleportData.LobbyReturnData
			Logger.Info("Lobby", `{player.Name} returned from Arena`, {
				worldId = returnData.WorldId,
				difficulty = returnData.Difficulty,
				victory = returnData.Victory,
				stars = returnData.Stars,
			})
			
			-- Process rewards on server side
			task.spawn(function()
				-- Wait for profile to load (up to 10 seconds)
				local attempts = 0
				while attempts < 100 do
					local profile = PlayerDataService.GetProfile(player)
					if profile then
						-- Apply rewards (no stage completion tracking in new system)
						PlayerDataService.AddCoins(player, returnData.CoinsEarned)
						PlayerDataService.AddXP(player, returnData.XPEarned)
						
						Logger.Info("Lobby", `Rewards applied: +{returnData.CoinsEarned} coins, +{returnData.XPEarned} XP`)
						
						-- Send results to client for display
						ZapServer.ShowResults.Fire(player, {
							WorldId = returnData.WorldId,
							Difficulty = returnData.Difficulty,
							Victory = returnData.Victory,
							Stars = returnData.Stars,
							CoinsEarned = returnData.CoinsEarned,
							XPEarned = returnData.XPEarned,
						})
						
						break
					end
					task.wait(0.1)
					attempts += 1
				end
				
				if attempts >= 100 then
					Logger.Error("Lobby", `Profile load timeout for {player.Name} - rewards not applied!`)
				end
			end)
		else
			Logger.Warn("Lobby", `Invalid return data: {err}`)
		end
	end
end

local function onPlayerRemoving(player: Player)
	Logger.Info("Lobby", `{player.Name} leaving lobby`)
	playersInLobby[player] = nil
end

-- Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

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

