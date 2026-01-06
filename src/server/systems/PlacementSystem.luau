--!strict
--[[
	PlacementSystem.luau - Server-side plant placement validation
	
	Priority: 200 (Core game logic)
	
	Validates placement requests from clients:
	- Cell in bounds
	- Cell not occupied
	- Player has enough sun
	- Plant not on cooldown (server cooldown tracking)
	
	Spawns plant entity on success, rejects on failure.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = Shared.components
local GridConfig = require(Shared.config.GridConfig)
local GridUtils = require(Shared.utils.GridUtils)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

-- Components
local PositionComponent = require(Components.PositionComponent)
local HealthComponent = require(Components.HealthComponent)
local PlantTypeComponent = require(Components.PlantTypeComponent)
local OwnerComponent = require(Components.OwnerComponent)

local Server = script.Parent.Parent
local GridState = require(Server.modules.GridState)
local Network = require(Server.network.generated)

-- Player sun tracking (temporary until ProfileStore integration)
local playerSun: {[Player]: number} = {}
local playerCooldowns: {[Player]: {[string]: number}} = {}

local STARTING_SUN = 50

-- Initialize new player
local function onPlayerAdded(player: Player)
	playerSun[player] = STARTING_SUN
	playerCooldowns[player] = {}
	Logger.Info("PlacementSystem", `Player {player.Name} initialized with {STARTING_SUN} sun`)
end

local function onPlayerRemoving(player: Player)
	playerSun[player] = nil
	playerCooldowns[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Initialize existing players
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- Validate placement request
local function validatePlacement(player: Player, column: number, lane: number, plantType: string): (boolean, string?)
	-- Check plant type exists
	local stats = PlantData[plantType]
	if not stats then
		return false, "Invalid plant type"
	end
	
	-- Check bounds
	if not GridUtils.IsValidCell(column, lane) then
		return false, "Cell out of bounds"
	end
	
	-- Check cell not occupied
	if GridState.IsOccupied(column, lane) then
		return false, "Cell already occupied"
	end
	
	-- Check player has enough sun
	local sun = playerSun[player] or 0
	if sun < stats.Cost then
		return false, "Not enough sun"
	end
	
	-- Check cooldown
	local cooldowns = playerCooldowns[player]
	if cooldowns then
		local cooldownEnd = cooldowns[plantType]
		if cooldownEnd and os.clock() < cooldownEnd then
			return false, "Plant on cooldown"
		end
	end
	
	return true, nil
end

-- Spawn plant entity
local function spawnPlant(world: any, player: Player, column: number, lane: number, plantType: string): number
	local stats = PlantData[plantType]
	if not stats then
		Logger.Error("PlacementSystem", `Invalid plant type: {plantType}`)
		return -1
	end
	
	local worldPos = GridUtils.GridToWorld(column, lane)
	
	local entityId = world:spawn(
		PositionComponent({
			X = worldPos.X,
			Y = worldPos.Y + 2, -- Slightly above ground
			Z = worldPos.Z
		}),
		HealthComponent({
			Current = stats.Health,
			Max = stats.Health
		}),
		PlantTypeComponent({
			PlantType = plantType,
			Column = column,
			Lane = lane
		}),
		OwnerComponent({
			PlayerId = player.UserId
		})
	)
	
	-- Mark cell as occupied
	GridState.Occupy(column, lane, entityId)
	
	-- Deduct sun
	playerSun[player] = (playerSun[player] or 0) - stats.Cost
	
	-- Start cooldown
	local cooldowns = playerCooldowns[player]
	if cooldowns then
		cooldowns[plantType] = os.clock() + stats.Cooldown
	end
	
	Logger.Info("PlacementSystem", `Spawned {plantType} at ({column}, {lane}) for {player.Name} - Entity {entityId}`)
	
	-- Broadcast to all clients
	local plantTypeEnum = ({
		Peashooter = "Peashooter",
		Sunflower = "Sunflower",
		WallNut = "WallNut",
		SnowPea = "SnowPea",
		CherryBomb = "CherryBomb",
		PotatoMine = "PotatoMine"
	})[plantType] or "Peashooter"
	
	Network.PlantSpawned.FireAll({
		EntityId = entityId,
		PlantType = plantTypeEnum :: any,
		Lane = lane :: any,
		Column = column :: any,
		OwnerId = player.UserId,
	})
	
	return entityId
end

-- API for handling placement requests (will be called by Zap handler)
local PlacementAPI = {}

function PlacementAPI.RequestPlacement(world: any, player: Player, column: number, lane: number, plantType: string): (boolean, string?)
	local success, reason = validatePlacement(player, column, lane, plantType)
	
	if not success then
		Logger.Warn("PlacementSystem", `Placement denied for {player.Name}: {reason}`)
		return false, reason
	end
	
	local entityId = spawnPlant(world, player, column, lane, plantType)
	if entityId < 0 then
		return false, "Spawn failed"
	end
	
	return true, nil
end

function PlacementAPI.GetPlayerSun(player: Player): number
	return playerSun[player] or 0
end

function PlacementAPI.AddSun(player: Player, amount: number)
	playerSun[player] = (playerSun[player] or 0) + amount
	Logger.Debug("PlacementSystem", `{player.Name} now has {playerSun[player]} sun`)
end

-- World reference for Zap handler
local _world: any = nil

-- Set up network handler for placement requests
Network.PlacePlantRequest.SetCallback(function(player: Player, data)
	if not _world then
		Logger.Warn("PlacementSystem", "World not initialized, rejecting placement")
		Network.RequestResponse.Fire(player, {
			RequestId = data.RequestId,
			Success = false,
			ErrorCode = 0,
		})
		return
	end
	
	local plantType = tostring(data.PlantType)
	local column = data.Column
	local lane = data.Lane
	
	local success, reason = PlacementAPI.RequestPlacement(_world, player, column, lane, plantType)
	
	-- Map reason to error code
	local errorCode = 0
	if reason == "Not enough sun" then
		errorCode = 1
	elseif reason == "Cell already occupied" then
		errorCode = 2
	elseif reason == "Cell out of bounds" then
		errorCode = 3
	end
	
	Network.RequestResponse.Fire(player, {
		RequestId = data.RequestId,
		Success = success,
		ErrorCode = if success then nil else errorCode,
	})
end)

-- System that processes cooldowns each frame (optional, for syncing)
local function PlacementSystem(world)
	_world = world -- Store world reference for Zap handler
	-- Cooldown processing handled by os.clock() comparisons
	-- No per-frame work needed
end

return {
	system = PlacementSystem,
	priority = 200,
	API = PlacementAPI,
}
