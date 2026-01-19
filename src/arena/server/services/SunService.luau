--!strict
--[[
	SunService.luau - Manages player sun currency
	
	Centralized service for sun economy management.
	Used by PlacementSystem, SunCollectionSystem, and commands.
	
	API:
	- GetSun(player) - Get current sun amount
	- AddSun(player, amount) - Add sun to player
	- SpendSun(player, amount) - Deduct sun (returns false if insufficient)
	- SetSun(player, amount) - Set exact sun amount
	- ResetPlayer(player) - Reset to starting sun
	
	LIFECYCLE:
	- Service is initialized when first required
	- Player tracking is automatic via PlayerAdded/Removing
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)
local ValidationMiddleware = require(Shared.utils.combat.ValidationMiddleware)

-- Network for broadcasting sun updates
local Network = require(Shared.network.generated.server)

-- Lazy-loaded (to avoid circular dependency)
local ServerEventBus = nil :: any?
local function getServerEventBus()
	if not ServerEventBus then
		ServerEventBus = require(script.Parent.ServerEventBus)
	end
	return ServerEventBus
end

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	STARTING_SUN = 50,
})

-- ============================================================
-- SECTION 3: STATE (all mutable data)
-- ============================================================
local State = {
	PlayerSun = {} :: { [Player]: number },
	Trove = Trove.new(),
	Initialized = false,
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

local function onPlayerAdded(player: Player)
	State.PlayerSun[player] = CONFIG.STARTING_SUN
	Logger.Info("SunService", `Player {player.Name} initialized with {CONFIG.STARTING_SUN} sun`)
end

local function onPlayerRemoving(player: Player)
	State.PlayerSun[player] = nil
end

local function initialize()
	if State.Initialized then
		return
	end

	State.Trove:Connect(Players.PlayerAdded, onPlayerAdded)
	State.Trove:Connect(Players.PlayerRemoving, onPlayerRemoving)

	-- Initialize existing players
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	State.Initialized = true
	Logger.Debug("SunService", "Initialized")
end

-- ============================================================
-- SECTION 5: PUBLIC API
-- ============================================================
local SunService = {}

--[[
	Get current sun amount for a player
	@param player Player
	@return number - Current sun amount (0 if not tracked)
]]
function SunService.GetSun(player: Player): number
	initialize() -- Ensure initialized
	return State.PlayerSun[player] or 0
end

--[[
	Add sun to a player
	@param player Player
	@param amount number - Amount to add (can be negative but prefer SpendSun)
]]
function SunService.AddSun(player: Player, amount: number)
	initialize() -- Ensure initialized
	local current = State.PlayerSun[player] or 0
	State.PlayerSun[player] = math.max(0, current + amount)
	Logger.Debug("SunService", `{player.Name} now has {State.PlayerSun[player]} sun (+{amount})`)
end

--[[
	Spend sun from a player
	@param player Player
	@param amount number - Amount to spend
	@param reason string? - Optional reason for spending (for middleware context)
	@return boolean - True if successful, false if insufficient
]]
function SunService.SpendSun(player: Player, amount: number, reason: string?): boolean
	initialize() -- Ensure initialized

	-- Run middleware validation hooks (God Mode integration)
	local allowed, middlewareReason = ValidationMiddleware.Validate("SpendSun", {
		Player = player,
		Amount = amount,
		Reason = reason or "Unknown",
		CurrentSun = State.PlayerSun[player] or 0,
	})
	if not allowed then
		Logger.Debug("SunService", `SpendSun blocked by middleware for {player.Name}: {middlewareReason}`)
		return false
	end

	local current = State.PlayerSun[player] or 0
	if current < amount then
		return false
	end
	State.PlayerSun[player] = current - amount
	Logger.Debug("SunService", `{player.Name} spent {amount} sun, now has {State.PlayerSun[player]}`)
	
	-- Fire ServerEventBus event for analytics/achievements
	getServerEventBus().FireSunSpent({
		Player = player,
		Amount = amount,
		Reason = reason or "Unknown",
		Remaining = State.PlayerSun[player],
	})
	
	return true
end

--[[
	Set exact sun amount for a player
	@param player Player
	@param amount number - New sun amount
]]
function SunService.SetSun(player: Player, amount: number)
	initialize() -- Ensure initialized
	State.PlayerSun[player] = math.max(0, amount)
	Logger.Debug("SunService", `{player.Name} sun set to {State.PlayerSun[player]}`)
end

--[[
	Reset player to starting sun
	@param player Player
]]
function SunService.ResetPlayer(player: Player)
	initialize() -- Ensure initialized
	State.PlayerSun[player] = CONFIG.STARTING_SUN
	Logger.Debug("SunService", `{player.Name} sun reset to {CONFIG.STARTING_SUN}`)
end

--[[
	Broadcast current sun total to a player
	Used after collection/spending to sync client UI
	@param player Player
]]
function SunService.BroadcastSunUpdate(player: Player, sunEntityId: number?)
	local total = SunService.GetSun(player)
	Network.SunCollected.Fire(player, {
		SunEntityId = sunEntityId or 0,
		CollectorId = player.UserId,
		NewTotal = total,
	})
end

--[[
	Dispose of service resources
	Called when arena match ends
]]
function SunService.Dispose()
	State.Trove:Destroy()
	State.Trove = Trove.new()
	table.clear(State.PlayerSun)
	State.Initialized = false
	Logger.Debug("SunService", "Disposed")
end

-- ============================================================
-- SECTION 6: MODULE EXPORT
-- ============================================================
return SunService
