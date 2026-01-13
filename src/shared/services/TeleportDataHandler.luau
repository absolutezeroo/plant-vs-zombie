--!strict
--[[
    TeleportDataHandler.luau - Unified teleport data handling for Lobby and Arena
    
    This module provides a clean abstraction for handling teleport data flow:
    - Arena: Processes incoming players from Lobby
    - Lobby: Processes returning players from Arena
    
    Key features:
    - Signal-based coordination (using Signal library, not BindableEvents)
    - Waits for profile before processing teleport data
    - Atomic deck/mutation application
    - Single point of synchronization
    - Proper cleanup via Trove
    
    Usage in Arena:
    ```lua
    local TeleportDataHandler = require(Shared.services.TeleportDataHandler)
    
    -- Initialize with dependencies
    TeleportDataHandler.InitializeArena({
        PlayerDataService = PlayerDataService,
        MutationApplySystem = MutationApplySystem,
        ArenaService = ArenaService,
    })
    
    -- Listen to ready signal
    TeleportDataHandler.OnPlayerReady:Connect(function(player, teleportData)
        NetworkSyncHandler.SyncPlayerData(player)
        NetworkSyncHandler.SyncDeck(player)
    end)
    ```
    
    Usage in Lobby:
    ```lua
    TeleportDataHandler.InitializeLobby({
        PlayerDataService = PlayerDataService,
    })
    
    TeleportDataHandler.OnPlayerReturned:Connect(function(player, returnData)
        -- Apply rewards, show results UI
    end)
    ```
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages:WaitForChild("Signal"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TeleportData = require(Shared.data.TeleportData)
local PlayerDataCore = require(Shared.services.PlayerDataCore)
local Logger = require(Shared.utils.Logger)

local TeleportDataHandler = {}

-- Trove for cleanup
local _trove = Trove.new()

-- Signals (using Signal library for proper lifecycle management)
local _onPlayerReadySignal = Signal.new()
local _onPlayerReturnedSignal = Signal.new()
_trove:Add(_onPlayerReadySignal)
_trove:Add(_onPlayerReturnedSignal)

-- Public signals (expose the Signal directly - same API as RBXScriptSignal)
TeleportDataHandler.OnPlayerReady = _onPlayerReadySignal -- (player, teleportData: ArenaJoinData)
TeleportDataHandler.OnPlayerReturned = _onPlayerReturnedSignal -- (player, returnData: LobbyReturnData)

-- Cache for teleport data (by userId for persistence across quick reconnects)
local _playerTeleportData: { [number]: TeleportData.ArenaJoinData } = {}
local _playerReturnData: { [number]: TeleportData.LobbyReturnData } = {}

-- Track which players have already had OnPlayerReady fired (to avoid duplicates)
local _playerReadyFired: { [number]: boolean } = {}

-- Dependencies (set during initialization)
local _dependencies: {
	PlayerDataService: any?,
	MutationService: any?,
	ArenaService: any?,
	NetworkSyncHandler: any?,
} =
	{}

-- Profile waiter instance
local _profileWaiter = PlayerDataCore.CreateProfileWaiter()

--------------------------------------------------------------------------------
-- Public API: Get Teleport Data
--------------------------------------------------------------------------------

-- Get the teleport data for a player (Arena)
function TeleportDataHandler.GetTeleportData(player: Player): TeleportData.ArenaJoinData?
	return _playerTeleportData[player.UserId]
end

-- Get the return data for a player (Lobby)
function TeleportDataHandler.GetReturnData(player: Player): TeleportData.LobbyReturnData?
	return _playerReturnData[player.UserId]
end

--------------------------------------------------------------------------------
-- Arena Initialization
--------------------------------------------------------------------------------

export type ArenaDependencies = {
	PlayerDataService: any,
	MutationService: any?,
	ArenaService: any?,
	NetworkSyncHandler: any?,
}

--[[
    Initialize the handler for Arena place.
    Call this once in init.server.luau.
    
    IMPORTANT: Call this BEFORE PlayerDataService.Initialize() so that
    PlayerAdded callbacks are registered in the correct order.
    PlayerDataService will call NotifyProfileLoaded which triggers our callbacks.
]]
function TeleportDataHandler.InitializeArena(deps: ArenaDependencies)
	Logger.Info("TeleportDataHandler", "Initializing for Arena")

	_dependencies.PlayerDataService = deps.PlayerDataService
	_dependencies.MutationService = deps.MutationService
	_dependencies.ArenaService = deps.ArenaService
	_dependencies.NetworkSyncHandler = deps.NetworkSyncHandler

	-- Connect to PlayerAdded (single handler for all teleport logic)
	-- This MUST be connected BEFORE PlayerDataService.Initialize() is called
	_trove:Connect(Players.PlayerAdded, function(player)
		task.spawn(function()
			TeleportDataHandler._handleArenaPlayerJoin(player)
		end)
	end)

	-- NOTE: We do NOT handle existing players here!
	-- PlayerDataService.Initialize() will handle them and call NotifyProfileLoaded,
	-- which triggers our WaitForProfile callbacks.
	-- Handling them here would cause a race condition.

	-- Cleanup on player leave
	_trove:Connect(Players.PlayerRemoving, function(player)
		_profileWaiter.Cleanup(player)
		_playerTeleportData[player.UserId] = nil
		_playerReadyFired[player.UserId] = nil
	end)
end

-- Internal: Handle a player joining Arena
function TeleportDataHandler._handleArenaPlayerJoin(player: Player)
	local PlayerDataService = _dependencies.PlayerDataService
	if not PlayerDataService then
		Logger.Warn("TeleportDataHandler", "PlayerDataService not set")
		return
	end

	-- Step 1: Extract teleport data immediately (before it expires)
	local joinData = player:GetJoinData()
	local rawTeleportData = joinData.TeleportData :: any
	local teleportData: TeleportData.ArenaJoinData? = nil

	if rawTeleportData then
		if rawTeleportData.PlayerDecks and not rawTeleportData.Deck then
			-- Convert group format to solo format for this player
			local userId = player.UserId
			local playerDeck = rawTeleportData.PlayerDecks[userId] or rawTeleportData.PlayerDecks[tostring(userId)]
			local playerMutations = rawTeleportData.PlayerMutations
					and (rawTeleportData.PlayerMutations[userId] or rawTeleportData.PlayerMutations[tostring(userId)])
				or {}

			if playerDeck then
				rawTeleportData = {
					WorldId = rawTeleportData.WorldId,
					Difficulty = rawTeleportData.Difficulty,
					Deck = playerDeck,
					EquippedMutations = playerMutations,
					Timestamp = rawTeleportData.Timestamp,
				}
				Logger.Info("TeleportDataHandler", `Converted group teleport data for {player.Name}`)
			else
				Logger.Warn("TeleportDataHandler", `No deck found for {player.Name} (UserId={userId}) in group data`)
			end
		end

		local isValid, errorMsg = TeleportData.ValidateArenaJoinData(rawTeleportData)
		if isValid then
			teleportData = rawTeleportData
			_playerTeleportData[player.UserId] = rawTeleportData
			Logger.Info(
				"TeleportDataHandler",
				`Valid teleport data for {player.Name}: World={rawTeleportData.WorldId}, Difficulty={rawTeleportData.Difficulty}, Deck={#rawTeleportData.Deck} plants`
			)
		else
			Logger.Warn("TeleportDataHandler", `Invalid teleport data for {player.Name}: {errorMsg}`)
		end
	else
		Logger.Info("TeleportDataHandler", `No teleport data for {player.Name} (direct join or Studio test)`)
	end

	-- Step 2: Wait for profile to load (using signal-based waiter, not polling)
	Logger.Debug("TeleportDataHandler", `Waiting for profile: {player.Name}`)

	local profileData = _profileWaiter.WaitForProfile(
		player,
		PlayerDataService.GetProfile,
		15 -- 15 second timeout
	)

	if not profileData then
		Logger.Error("TeleportDataHandler", `Profile load timeout for {player.Name}`)
		-- Could kick player here or use default data
		return
	end

	Logger.Info("TeleportDataHandler", `Profile loaded for {player.Name}`)

	-- Step 3: Apply teleport data if present
	if teleportData then
		TeleportDataHandler._applyTeleportData(player, teleportData, profileData)
	end

	-- Step 4: Fire OnPlayerReady signal (other systems can react)
	-- Only fire once per player
	if not _playerReadyFired[player.UserId] then
		_playerReadyFired[player.UserId] = true
		_onPlayerReadySignal:Fire(player, teleportData)
	end
end

-- Internal: Apply teleport data to player profile
function TeleportDataHandler._applyTeleportData(
	player: Player,
	teleportData: TeleportData.ArenaJoinData,
	profileData: PlayerDataCore.ProfileData
)
	local PlayerDataService = _dependencies.PlayerDataService
	local MutationService = _dependencies.MutationService

	-- Auto-unlock any plants in the teleported deck that aren't unlocked
	local needsUnlock = false
	for _, plantType in teleportData.Deck do
		if not profileData.UnlockedPlants[plantType] then
			Logger.Info("TeleportDataHandler", `Auto-unlocking plant {plantType} for {player.Name}`)
			PlayerDataService.UnlockPlant(player, plantType)
			needsUnlock = true
		end
	end

	-- Save the teleported deck to profile (atomic operation)
	local deckValid, cleanedDeck, deckError = PlayerDataCore.ValidateDeck(teleportData.Deck, profileData.UnlockedPlants)

	if deckValid then
		local success, saveError = PlayerDataService.SaveDeck(player, cleanedDeck)
		if success then
			Logger.Info("TeleportDataHandler", `Deck saved for {player.Name}: {#cleanedDeck} plants`)
		else
			Logger.Warn("TeleportDataHandler", `Failed to save deck for {player.Name}: {saveError}`)
		end
	else
		Logger.Warn("TeleportDataHandler", `Invalid deck for {player.Name}: {deckError}`)
	end

	-- Load mutations into the MutationService cache
	if MutationService and teleportData.EquippedMutations then
		local mutationCount = 0
		for plantType, mutations in teleportData.EquippedMutations do
			mutationCount += #mutations
		end

		if mutationCount > 0 then
			MutationService.LoadPlayerMutations(player.UserId, teleportData.EquippedMutations)
			Logger.Info("TeleportDataHandler", `Loaded {mutationCount} mutations for {player.Name}`)
		end
	end
end

--------------------------------------------------------------------------------
-- Lobby Initialization
--------------------------------------------------------------------------------

export type LobbyDependencies = {
	PlayerDataService: any,
}

--[[
    Initialize the handler for Lobby place.
    Call this once in init.server.luau.
]]
function TeleportDataHandler.InitializeLobby(deps: LobbyDependencies)
	Logger.Info("TeleportDataHandler", "Initializing for Lobby")

	_dependencies.PlayerDataService = deps.PlayerDataService

	-- Connect to PlayerAdded
	_trove:Connect(Players.PlayerAdded, function(player)
		task.spawn(function()
			TeleportDataHandler._handleLobbyPlayerJoin(player)
		end)
	end)

	-- Handle players already in game
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			TeleportDataHandler._handleLobbyPlayerJoin(player)
		end)
	end

	-- Cleanup on player leave
	_trove:Connect(Players.PlayerRemoving, function(player)
		_profileWaiter.Cleanup(player)
		_playerReturnData[player.UserId] = nil
	end)
end

-- Internal: Handle a player joining Lobby
function TeleportDataHandler._handleLobbyPlayerJoin(player: Player)
	local PlayerDataService = _dependencies.PlayerDataService
	if not PlayerDataService then
		Logger.Warn("TeleportDataHandler", "PlayerDataService not set")
		return
	end

	-- Step 1: Extract return data if coming from Arena
	local joinData = player:GetJoinData()
	local rawReturnData = joinData.TeleportData :: any
	local returnData: TeleportData.LobbyReturnData? = nil

	if rawReturnData then
		local isValid, errorMsg = TeleportData.ValidateLobbyReturnData(rawReturnData)
		if isValid then
			returnData = rawReturnData
			_playerReturnData[player.UserId] = rawReturnData
			Logger.Info(
				"TeleportDataHandler",
				`Player {player.Name} returned from Arena: Victory={rawReturnData.Victory}, Stars={rawReturnData.Stars}`
			)
		else
			Logger.Debug(
				"TeleportDataHandler",
				`Return data invalid for {player.Name}: {errorMsg} (normal for fresh join)`
			)
		end
	end

	-- Step 2: Wait for profile
	local profileData = _profileWaiter.WaitForProfile(player, PlayerDataService.GetProfile, 15)

	if not profileData then
		Logger.Error("TeleportDataHandler", `Profile load timeout for {player.Name}`)
		return
	end

	-- Step 3: Apply rewards if returning from Arena
	if returnData then
		TeleportDataHandler._applyReturnRewards(player, returnData)
	end

	-- Step 4: Fire OnPlayerReturned signal
	if returnData then
		_onPlayerReturnedSignal:Fire(player, returnData)
	end
end

-- Internal: Apply rewards from Arena return
function TeleportDataHandler._applyReturnRewards(player: Player, returnData: TeleportData.LobbyReturnData)
	local PlayerDataService = _dependencies.PlayerDataService

	-- Add coins earned
	if returnData.CoinsEarned and returnData.CoinsEarned > 0 then
		PlayerDataService.AddCoins(player, returnData.CoinsEarned)
		Logger.Info("TeleportDataHandler", `Added {returnData.CoinsEarned} coins to {player.Name}`)
	end

	-- Add XP earned
	if returnData.XPEarned and returnData.XPEarned > 0 then
		PlayerDataService.AddXP(player, returnData.XPEarned)
		Logger.Info("TeleportDataHandler", `Added {returnData.XPEarned} XP to {player.Name}`)
	end

	-- Increment games played stat
	if PlayerDataService.IncrementStat then
		PlayerDataService.IncrementStat(player, "GamesPlayed", 1)
		if returnData.Victory then
			PlayerDataService.IncrementStat(player, "GamesWon", 1)
		end
	end
end

--------------------------------------------------------------------------------
-- Profile Waiter Integration
--------------------------------------------------------------------------------

-- Call this when a profile loads (from PlayerDataService.LoadProfile)
-- This handles BOTH new players (who are waiting via WaitForProfile)
-- AND existing players (who missed the PlayerAdded event)
function TeleportDataHandler.NotifyProfileLoaded(player: Player, profileData: PlayerDataCore.ProfileData)
	-- Fire callbacks for players who are waiting via WaitForProfile
	_profileWaiter.FireCallbacks(player, profileData)

	-- For existing players who missed PlayerAdded, we need to process them now
	-- Check if we already processed this player (teleport data would be extracted)
	-- If not, this is an existing player that needs full processing
	if _playerTeleportData[player.UserId] == nil then
		-- Check if there's teleport data we haven't processed yet
		local joinData = player:GetJoinData()
		local rawTeleportData = joinData.TeleportData :: any

		if rawTeleportData then
			local isValid, errorMsg = TeleportData.ValidateArenaJoinData(rawTeleportData)
			if isValid then
				_playerTeleportData[player.UserId] = rawTeleportData
				Logger.Info("TeleportDataHandler", `[Late] Valid teleport data for {player.Name}`)
				TeleportDataHandler._applyTeleportData(player, rawTeleportData, profileData)
			else
				Logger.Warn("TeleportDataHandler", `[Late] Invalid teleport data for {player.Name}: {errorMsg}`)
			end
		else
			Logger.Debug("TeleportDataHandler", `[Late] No teleport data for existing player {player.Name}`)
		end

		-- Fire OnPlayerReady for existing players who missed the normal flow
		-- Only fire if we haven't already fired for this player
		if not _playerReadyFired[player.UserId] then
			_playerReadyFired[player.UserId] = true
			task.defer(function()
				_onPlayerReadySignal:Fire(player, _playerTeleportData[player.UserId])
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- Lifecycle: Dispose
--------------------------------------------------------------------------------

--[[
    Clean up all connections and signals.
    Call this when the place is shutting down (optional, as Roblox handles cleanup on close).
]]
function TeleportDataHandler.Dispose()
	Logger.Info("TeleportDataHandler", "Disposing...")
	_trove:Clean()
	table.clear(_playerTeleportData)
	table.clear(_playerReturnData)
	table.clear(_playerReadyFired)
	table.clear(_dependencies)
end

return TeleportDataHandler
