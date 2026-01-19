--!strict
--[[
    ArenaService.luau - Manages Arena battle lifecycle
    
    Handles:
    - Starting battles from TeleportData (Lobby → Arena)
    - Loading the correct map for each world
    - Setting up world + difficulty and deck
    - Returning to Lobby with results
    
    Configuration:
    - World determines map, mechanics, zombie pool (see WorldData)
    - Difficulty determines wave count, budget, multipliers (see DifficultyData)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)
local MapConfig = require(Shared.config.MapConfig)

-- NEW: Data-driven world and difficulty
local WorldData = require(Shared.data.WorldData)
local DifficultyData = require(Shared.data.DifficultyData)

-- Check if running in Studio (skip preload to avoid yield issues)
local IS_STUDIO = RunService:IsStudio()

-- Services
local MapLoader = require(script.Parent.MapLoader)

local ArenaService = {}

-- Track which players have started battles
export type BattleData = {
	WorldId: string,
	Difficulty: string,
	Deck: { string },
}

local _activeBattles: { [Player]: BattleData } = {}

-- Get battle data for a player
function ArenaService.GetBattleData(player: Player): BattleData?
	return _activeBattles[player]
end

-- Start a battle for a player (NEW API: WorldId + Difficulty)
function ArenaService.StartBattle(player: Player, worldId: string, difficulty: string, deck: { string }): boolean
	Logger.Info(
		"ArenaService",
		`Starting battle for {player.Name}: world={worldId}, difficulty={difficulty}, deck={#deck}`
	)

	-- Validate world (data-driven)
	local worldConfig = WorldData.GetWorld(worldId)
	if not worldConfig then
		Logger.Error("ArenaService", `Invalid world: {worldId}`)
		return false
	end

	-- Validate difficulty (data-driven)
	local difficultyConfig = DifficultyData.GetDifficulty(difficulty)
	if not difficultyConfig then
		Logger.Error("ArenaService", `Invalid difficulty: {difficulty}`)
		return false
	end

	-- Check world unlock requirement
	-- TODO: Get player level from PlayerDataService if needed
	-- For now, all worlds are accessible

	-- Load the map for this world
	local mapId = worldConfig.MapId
	if mapId then
		local mapLoaded: boolean
		if IS_STUDIO then
			Logger.Info("ArenaService", `[Studio] Loading map without preload: {mapId}`)
			mapLoaded = MapLoader.LoadMap(mapId)
		else
			Logger.Info("ArenaService", `Loading map with preload: {mapId}`)
			mapLoaded = MapLoader.LoadMapWithPreload(mapId, player)
		end

		if not mapLoaded then
			-- Try to use existing ArenaMap in workspace
			Logger.Warn("ArenaService", `Map {mapId} not found, using existing ArenaMap`)
			MapConfig.Reload()
		end
	else
		-- No MapId specified, use existing map or reload config
		Logger.Info("ArenaService", "No MapId specified, using default map")
		MapConfig.Reload()
	end

	-- Track active battle
	_activeBattles[player] = {
		WorldId = worldId,
		Difficulty = difficulty,
		Deck = deck,
	}

	-- Load WaveService
	local WaveService = require(script.Parent.WaveService)

	-- Reset game state before starting new battle
	WaveService.ResetGameState()

	-- Start the game with world + difficulty
	local success = WaveService.StartGame(worldId, difficulty)

	if not success then
		Logger.Error("ArenaService", `Failed to start game: {worldId}/{difficulty}`)
		_activeBattles[player] = nil
		return false
	end

	Logger.Info("ArenaService", `Battle started: {worldConfig.Name} ({difficultyConfig.Name})`)
	return true
end

-- End battle and prepare return data (updated for new system)
function ArenaService.EndBattle(player: Player, victory: boolean, wavesSurvived: number, coins: number, xp: number)
	local battleData = _activeBattles[player]
	if not battleData then
		Logger.Warn("ArenaService", `No active battle for {player.Name}`)
		return
	end

	Logger.Info("ArenaService", `Battle ended for {player.Name}: victory={victory}, waves={wavesSurvived}`)

	-- Use the global function set by init.server.luau
	local sendToLobby = _G.ArenaSendPlayerToLobby
	if sendToLobby then
		sendToLobby(player, victory, wavesSurvived, coins, xp)
	else
		Logger.Error("ArenaService", "ArenaSendPlayerToLobby not available")
	end

	_activeBattles[player] = nil
end

-- Clean up when player leaves
function ArenaService.OnPlayerRemoving(player: Player)
	_activeBattles[player] = nil
end

-- Get current world config for a player's active battle
function ArenaService.GetWorldConfig(player: Player): WorldData.WorldConfig?
	local battleData = _activeBattles[player]
	if not battleData then
		return nil
	end
	return WorldData.GetWorld(battleData.WorldId)
end

-- Get current difficulty config for a player's active battle
function ArenaService.GetDifficultyConfig(player: Player): DifficultyData.DifficultyConfig?
	local battleData = _activeBattles[player]
	if not battleData then
		return nil
	end
	return DifficultyData.GetDifficulty(battleData.Difficulty)
end

return ArenaService
