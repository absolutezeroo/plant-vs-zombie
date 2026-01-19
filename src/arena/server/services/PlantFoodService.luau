--!strict
--[[
	PlantFoodService.luau - Manages Plant Food charges
	
	Centralized service for Plant Food economy.
	Used by PlantFoodSystem and network handlers.
	
	API:
	- GetCharges(player) - Get current charge count
	- AddCharge(player, amount?) - Add charges (max 3)
	- UseCharge(player) - Use a charge, returns false if none
	- ResetWaveTracking() - Reset glowing zombie tracking for new wave
	- ShouldZombieBeGlowing() - Check if next zombie should glow
	
	LIFECYCLE:
	- Service is initialized when first required
	- Player tracking is automatic via PlayerAdded/Removing
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConstants = require(Shared.config.GameConstants)
local Logger = require(Shared.utils.core.Logger)
local ChanceUtils = require(Shared.utils.core.ChanceUtils)

-- Network
local Network = require(Shared.network.generated.server)

-- Configuration (from GameConstants.PlantFood)
local Config = GameConstants.PlantFood

-- ============================================================
-- SECTION 2: STATE (all mutable data)
-- ============================================================
local State = {
	PlayerCharges = {} :: { [number]: number }, -- UserId -> charge count
	GlowingSpawnedThisWave = 0,
	Trove = Trove.new(),
	Initialized = false,
}

-- ============================================================
-- SECTION 3: PRIVATE HELPERS
-- ============================================================

local function onPlayerAdded(player: Player)
	State.PlayerCharges[player.UserId] = 0

	Network.PlantFoodChargeUpdate.Fire(player, {
		ChargeCount = 0,
	})
end

local function onPlayerRemoving(player: Player)
	State.PlayerCharges[player.UserId] = nil
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
	Logger.Debug("PlantFoodService", "Initialized")
end

-- ============================================================
-- SECTION 4: PUBLIC API
-- ============================================================
local PlantFoodService = {}

--[[
	Get current charge count for a player
	@param player Player
	@return number - Current charges (0-3)
]]
function PlantFoodService.GetCharges(player: Player): number
	initialize()
	return State.PlayerCharges[player.UserId] or 0
end

--[[
	Add charges to a player (capped at MAX_CHARGES)
	@param player Player
	@param amount number? - Amount to add (default 1)
	@return number - New charge count
]]
function PlantFoodService.AddCharge(player: Player, amount: number?): number
	initialize()
	local userId = player.UserId
	local current = State.PlayerCharges[userId] or 0
	local newCount = math.min(current + (amount or 1), Config.MAX_CHARGES)
	State.PlayerCharges[userId] = newCount

	-- Notify client
	Network.PlantFoodChargeUpdate.Fire(player, {
		ChargeCount = newCount,
	})

	Logger.Info("PlantFoodService", `Player {player.Name} gained charge: {current} -> {newCount}`)
	return newCount
end

--[[
	Use a Plant Food charge
	@param player Player
	@return boolean - True if successful, false if no charges
]]
function PlantFoodService.UseCharge(player: Player): boolean
	initialize()
	local userId = player.UserId
	local current = State.PlayerCharges[userId] or 0

	if current <= 0 then
		return false
	end

	State.PlayerCharges[userId] = current - 1

	-- Notify client
	Network.PlantFoodChargeUpdate.Fire(player, {
		ChargeCount = current - 1,
	})

	Logger.Info("PlantFoodService", `Player {player.Name} used charge: {current} -> {current - 1}`)
	return true
end

--[[
	Check if the next zombie should be glowing (drops Plant Food)
	@return boolean
]]
function PlantFoodService.ShouldZombieBeGlowing(): boolean
	initialize()
	-- First zombie each wave is guaranteed to be glowing
	if State.GlowingSpawnedThisWave < Config.GUARANTEED_PER_WAVE then
		State.GlowingSpawnedThisWave += 1
		return true
	end

	-- Random chance for additional glowing zombies
	return ChanceUtils.Roll(Config.GLOWING_ZOMBIE_CHANCE)
end

--[[
	Reset glowing zombie tracking for new wave
]]
function PlantFoodService.ResetWaveTracking()
	State.GlowingSpawnedThisWave = 0
end

--[[
	Dispose of service resources
]]
function PlantFoodService.Dispose()
	State.Trove:Destroy()
	State.Trove = Trove.new()
	table.clear(State.PlayerCharges)
	State.GlowingSpawnedThisWave = 0
	State.Initialized = false
	Logger.Debug("PlantFoodService", "Disposed")
end

-- ============================================================
-- SECTION 5: MODULE EXPORT
-- ============================================================
return PlantFoodService
