--!strict
--[[
    LobbyService.luau - Orchestrates teleport pad functionality
    
    Single Responsibility: Coordinate managers for pad operations
    
    This is a thin orchestrator that delegates to:
    - PadManager: Read pad configuration from workspace
    - PadQueueManager: Track player queues
    - PlayerLockManager: Handle player movement locking
    - CountdownManager: Handle countdown timers
    - TeleportManager: Handle teleportation
    - PadBroadcaster: Handle network updates
    - PadTouchHandler: Handle touch detection
    - PadLogicHandler: Pure logic for validation and decisions
]]

local Players = game:GetService("Players")
local _RunService = game:GetService("RunService") -- Reserved for future use
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

-- Shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local _LobbyConfig = require(Shared.config.LobbyConfig) -- Reserved for future use

-- Shared handlers (pure logic)
local PadLogicHandler = require(Shared.handlers.lobby.PadLogicHandler)

-- Managers
local PadManager = require(script.Parent.Parent.modules.PadManager)
local PlayerLockManager = require(script.Parent.Parent.managers.PlayerLockManager)
local PadQueueManager = require(script.Parent.Parent.managers.PadQueueManager)
local CountdownManager = require(script.Parent.Parent.managers.CountdownManager)
local TeleportManager = require(script.Parent.Parent.managers.TeleportManager)
local PadBroadcaster = require(script.Parent.Parent.managers.PadBroadcaster)
local PadTouchHandler = require(script.Parent.Parent.managers.PadTouchHandler)

-- Types
export type PadConfig = PadManager.PadConfig

-- Module
local LobbyService = {}

-- State
local _initialized = false
local _padConfigs: { [string]: PadConfig } = {} -- padId -> config
local _lastBroadcastTime: { [string]: number } = {} -- padId -> last broadcast time

-- Trove for connection cleanup
local _trove = Trove.new()

-- Zap server reference
local ZapServer: any = nil

-- Manager instances
local _playerLockManager: PlayerLockManager.PlayerLockManager
local _queueManager: PadQueueManager.PadQueueManager
local _countdownManager: CountdownManager.CountdownManager
local _teleportManager: TeleportManager.TeleportManager
local _broadcaster: PadBroadcaster.PadBroadcaster
local _touchHandler: PadTouchHandler.PadTouchHandler

-- Forward declarations
local handlePlayerLeave: (player: Player) -> ()

--[[ ============================================
    PRIVATE: Core pad operations
============================================ ]]
--

-- Handle player joining a pad
local function handlePlayerJoin(player: Player, padModel: Model)
	local padId = PadManager.GetPadId(padModel)
	local config = _padConfigs[padId]

	if not config then
		Logger.Warn("LobbyService", `Unknown pad: {padId}`)
		return
	end

	-- Validate join via handler
	local currentPadId = _queueManager:GetPlayerPad(player)
	local playerCount = _queueManager:GetPlayerCount(padId)
	local validation = PadLogicHandler.ValidateJoin(config :: PadLogicHandler.PadConfig, playerCount, currentPadId)
	
	if not validation.CanJoin then
		if validation.Reason ~= "AlreadyOnPad" then
			Logger.Warn("LobbyService", `{player.Name} cannot join pad {padId}: {validation.Reason}`)
		end
		return
	end

	-- Leave current pad first if needed
	if PadLogicHandler.ShouldLeaveCurrentPad(currentPadId, padId) then
		handlePlayerLeave(player)
	end

	-- Try to join queue
	local joined = _queueManager:JoinPad(player, padId, config)
	if not joined then
		return
	end

	-- Lock player in the zone (SpawnPosition)
	local spawnPos = config.SpawnPosition
	_playerLockManager:LockPlayer(player, spawnPos)

	-- Notify client
	if ZapServer then
		ZapServer.PadJoined.Fire(player, {
			PadId = padId,
			WorldId = config.WorldId,
			Difficulty = config.Difficulty,
			Position = spawnPos,
		})
	end

	Logger.Info("LobbyService", `{player.Name} joined pad {padId}`)

	-- Start countdown if min players met
	updateCountdown(padId, config)

	-- Broadcast state
	_broadcaster:BroadcastPadState(padId, config)
end

-- Handle player leaving a pad
function handlePlayerLeave(player: Player)
	local padId = _queueManager:LeavePad(player)
	if not padId then
		return
	end

	local config = _padConfigs[padId]

	-- Unlock player
	_playerLockManager:UnlockPlayer(player)

	-- Teleport player to LeaveRoomPart
	local workspace = game:GetService("Workspace")
	local lobbyTeleports = workspace:FindFirstChild("LobbyTeleports")
	local leaveRoomPart = lobbyTeleports and lobbyTeleports:FindFirstChild("LeaveRoomPart", true)

	if leaveRoomPart and leaveRoomPart:IsA("BasePart") then
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				-- Use handler to calculate leave CFrame
				local leaveCFrame = PadLogicHandler.CalculateLeaveCFrame(leaveRoomPart.Position, 3)
				humanoidRootPart.CFrame = leaveCFrame
				Logger.Info("LobbyService", `Teleported {player.Name} to LeaveRoomPart`)
			end
		end
	end

	-- Notify client
	if ZapServer then
		ZapServer.PadLeft.Fire(player, {})
	end

	Logger.Info("LobbyService", `{player.Name} left pad {padId}`)

	-- Update countdown
	if config then
		updateCountdown(padId, config)
		_broadcaster:BroadcastPadState(padId, config)
	end
end

-- Update countdown state for a pad
function updateCountdown(padId: string, config: PadConfig)
	local playerCount = _queueManager:GetPlayerCount(padId)
	local isActive = _countdownManager:IsCountdownActive(padId)

	-- Use handler to decide countdown action
	local decision = PadLogicHandler.DecideCountdownAction(playerCount, config.MinPlayers, isActive)

	if decision.ShouldStart then
		_countdownManager:StartCountdown(padId, config.CountdownDuration, {
			OnTick = function(id, remaining)
				-- Broadcast every tick
				_broadcaster:BroadcastPadState(id, config)
			end,
			OnComplete = function(id)
				-- Teleport group
				teleportPadGroup(id, config)
			end,
			OnCancel = function(id)
				_broadcaster:BroadcastPadState(id, config)
			end,
		})
		Logger.Info("LobbyService", `Countdown started for pad {padId} ({config.CountdownDuration}s)`)
	end

	if decision.ShouldCancel then
		_countdownManager:CancelCountdown(padId)
		Logger.Info("LobbyService", `Countdown cancelled for pad {padId}`)
	end
end

-- Teleport all players on a pad
function teleportPadGroup(padId: string, config: PadConfig)
	local players = _queueManager:GetPlayersOnPad(padId)
	
	-- Use handler to validate teleport
	local canTeleport, reason = PadLogicHandler.CanTeleportGroup(#players, config.MinPlayers)
	if not canTeleport then
		Logger.Warn("LobbyService", `Cannot teleport pad {padId}: {reason}`)
		return
	end

	Logger.Info("LobbyService", `Teleporting {#players} players from pad {padId} TOGETHER`)

	-- Set cooldowns for all players
	for _, player in ipairs(players) do
		_touchHandler:SetCooldown(player)
	end

	-- Teleport ALL players together to the SAME server
	_teleportManager:TeleportGroupAsync(players, config.WorldId, config.Difficulty):catch(function(err)
		Logger.Warn("LobbyService", `Group teleport failed: {err}`)
		-- Unlock all players on failure
		for _, player in ipairs(players) do
			if player.Parent == Players then
				_playerLockManager:UnlockPlayer(player)
			end
		end
	end)

	-- Clear the queue
	_queueManager:ClearPad(padId)

	-- Broadcast cleared state
	_broadcaster:BroadcastPadState(padId, config)
end

--[[ ============================================
    PRIVATE: Initialization helpers
============================================ ]]
--

-- Scan workspace for teleport pads (LobbyTeleports gates)
local function scanForPads()
	local workspace = game:GetService("Workspace")
	local lobbyTeleports = workspace:FindFirstChild("LobbyTeleports")
	local teleportPadsFolder = lobbyTeleports and lobbyTeleports:FindFirstChild("Workspace")

	if not teleportPadsFolder then
		Logger.Warn("LobbyService", "No 'LobbyTeleports/Workspace' folder found")
		return
	end

	for _, child in teleportPadsFolder:GetChildren() do
		if child:IsA("Model") then
			local config = PadManager.ReadPadConfig(child)
			if config and config.IsValid then
				local padId = PadManager.GetPadId(child)
				_padConfigs[padId] = config

				-- Setup touch detection on Gate trigger part
				_touchHandler:SetupPadTouch(child, config.TriggerPart, function(player, padModel)
					handlePlayerJoin(player, padModel)
				end)
			end
		end
	end

	local padCount = 0
	for _ in _padConfigs do
		padCount += 1
	end
	Logger.Info("LobbyService", `Loaded {padCount} teleport pads`)
end

-- Broadcast all pad states (for new players or initial sync)
local function broadcastAllPadStates()
	for padId, config in pairs(_padConfigs) do
		_broadcaster:BroadcastPadState(padId, config)
	end
end

--[[ ============================================
    PUBLIC: API
============================================ ]]
--

-- Initialize the lobby service
function LobbyService.Initialize(zapServer: any)
	if _initialized then
		Logger.Warn("LobbyService", "Already initialized")
		return
	end

	ZapServer = zapServer

	-- Get manager instances
	_playerLockManager = PlayerLockManager.GetInstance()
	_queueManager = PadQueueManager.GetInstance()
	_countdownManager = CountdownManager.GetInstance()
	_teleportManager = TeleportManager.GetInstance()
	_broadcaster = PadBroadcaster.GetInstance()
	_touchHandler = PadTouchHandler.GetInstance()

	-- Scan for pads in workspace
	scanForPads()

	-- Broadcast initial state for all pads
	task.defer(broadcastAllPadStates)

	-- Handle new players - send them all pad states
	_trove:Connect(Players.PlayerAdded, function(player)
		task.wait(1)
		broadcastAllPadStates()
	end)

	-- Handle player leaving game
	_trove:Connect(Players.PlayerRemoving, function(player)
		handlePlayerLeave(player)
		_playerLockManager:Cleanup(player)
		_touchHandler:Cleanup(player)
	end)

	-- Handle LeavePadRequest from clients
	ZapServer.LeavePadRequest.SetCallback(function(player)
		handlePlayerLeave(player)
	end)

	_initialized = true
	Logger.Info("LobbyService", "Lobby service initialized")
end

-- Get pad config (for debugging)
function LobbyService.GetPadConfig(padId: string): PadConfig?
	return _padConfigs[padId]
end

-- Manual player join (for testing)
function LobbyService.PlayerJoinedPad(player: Player, padModel: Model)
	handlePlayerJoin(player, padModel)
end

-- Manual player leave (for testing)
function LobbyService.PlayerLeftPad(player: Player)
	handlePlayerLeave(player)
end

return LobbyService
