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
	
	LIFECYCLE:
	- Init(): Setup player listeners (CAN yield)
	- system(): Main loop (CANNOT yield) - stores world reference
	- Dispose(): Cleanup player connections and state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local GridUtils = require(Shared.utils.GridUtils)
local PlantData = require(Shared.data.PlantData)
local WorldData = require(Shared.data.WorldData)
local Logger = require(Shared.utils.Logger)
local EntityPool = require(Shared.utils.EntityPool)

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local PlantTypeComponent = Components.PlantTypeComponent
local OwnerComponent = Components.OwnerComponent
local SpawnEvent = Components.SpawnEvent
local PlantActionEvent = Components.PlantActionEvent

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent
local GridService = require(Server.services.GridService)

-- Import MutationApplySystem for mutation queries
local MutationApplySystemModule = require(Server.systems.mutations.MutationApplySystem)

-- Player sun tracking (temporary until ProfileStore integration)
local playerSun: {[Player]: number} = {}
local playerCooldowns: {[Player]: {[string]: number}} = {}

local STARTING_SUN = 50

-- Trove for cleanup (connections)
local Trove = require(Packages.Trove)
local _trove = Trove.new()

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

local function setupListeners()
	_trove:Connect(Players.PlayerAdded, onPlayerAdded)
	_trove:Connect(Players.PlayerRemoving, onPlayerRemoving)
end

-- Validate placement request
local function validatePlacement(player: Player, column: number, lane: number, plantType: string, world: any?): (boolean, string?)
	-- Check plant type exists
	local stats = PlantData[plantType]
	if not stats then
		return false, "Invalid plant type"
	end
	
	-- Check bounds
	if not GridUtils.IsValidCell(column, lane) then
		return false, "Cell out of bounds"
	end
	
	-- Get what's currently in the cell
	local existingEntityId = GridService.GetEntity(column, lane)
	local existingPlant = nil
	local existingStats = nil
	
	if existingEntityId and world and world:contains(existingEntityId) then
		existingPlant = world:get(existingEntityId, PlantTypeComponent)
		if existingPlant then
			existingStats = PlantData[existingPlant.PlantType]
		end
	end
	
	-- ==============================================
	-- Water/Platform validation (DATA-DRIVEN)
	-- ==============================================
	
	-- Get current world config from WaveManager (lazy require with safety check)
	local WaveManagerModule = require(script.Parent.Parent.wave.WaveManagerSystem) :: any
	local WaveManager = WaveManagerModule and WaveManagerModule.WaveManager
	local worldConfig = WaveManager and WaveManager.GetCurrentWorldConfig and WaveManager.GetCurrentWorldConfig()
	local waterLanes: {number} = if worldConfig then worldConfig.WaterLanes or {} else {}
	local isWaterLane = table.find(waterLanes, lane) ~= nil
	
	-- Rule 1: Plants with RequiresWater can ONLY be placed on water lanes
	if stats.RequiresWater then
		if not isWaterLane then
			return false, "This plant requires a water lane"
		end
		-- RequiresWater plants go directly in water (no LilyPad needed)
	end
	
	-- Rule 2: LilyPad (IsPlatform with water context) can ONLY be placed on water lanes
	if stats.IsPlatform and stats.AllowsPlantOnTop then
		-- Check if this is a water platform (LilyPad) or ground platform (FlowerPot)
		-- LilyPad can only go on water, FlowerPot can go anywhere except water
		local isLilyPad = plantType == "LilyPad"
		local isFlowerPot = plantType == "FlowerPot"
		
		if isLilyPad and not isWaterLane then
			return false, "Lily Pad can only be placed on water lanes"
		end
		if isFlowerPot and isWaterLane then
			return false, "Flower Pot cannot be placed on water"
		end
	end
	
	-- Rule 3: RequiresLilyPad plants need a LilyPad underneath
	if stats.RequiresLilyPad then
		if not existingEntityId or not existingStats or not existingStats.IsPlatform then
			return false, "This plant requires a Lily Pad"
		end
	end
	
	-- Rule 4: Normal plants on water lanes MUST have a LilyPad
	if isWaterLane and not stats.RequiresWater and not stats.IsPlatform then
		if not existingEntityId or not existingStats or not existingStats.IsPlatform then
			return false, "Plants on water lanes require a Lily Pad"
		end
	end
	
	-- ==============================================
	-- Check stacking rules
	if stats.CanStackOnPlant then
		-- Pumpkin can be placed on top of another plant
		if existingEntityId then
			if existingStats and existingStats.IsShell then
				return false, "Cannot stack shells"
			end
			-- Allow stacking on non-shell plants
		else
			return false, "Pumpkin requires a plant to protect"
		end
	elseif stats.CanStackOnMushroom then
		-- Coffee Bean can only be placed on sleeping mushrooms
		if existingEntityId and existingStats and existingStats.IsMushroom then
			-- Check if mushroom is sleeping
			local Systems = script.Parent.Parent
			local MushroomSystem = require(Systems.units.MushroomSystem)
			if world then
				local SleepingComponent = Components.SleepingComponent
				local sleeping = world:get(existingEntityId, SleepingComponent)
				if not sleeping or not sleeping.IsSleeping then
					return false, "Mushroom is already awake"
				end
			end
			-- Allow placing Coffee Bean on sleeping mushroom
		else
			return false, "Coffee Bean requires a sleeping mushroom"
		end
	elseif stats.IsPlatform then
		-- Platforms (LilyPad, FlowerPot) can be placed on empty cells only
		if existingEntityId then
			return false, "Platform cannot stack"
		end
	else
		-- Normal plant - cell must be empty OR have a platform
		if existingEntityId then
			if existingStats and existingStats.IsPlatform and existingStats.AllowsPlantOnTop then
				-- Can place on platform - this is valid
			else
				return false, "Cell already occupied"
			end
		end
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
	
	-- Check for special stacking cases
	local existingEntityId = GridService.GetEntity(column, lane)

	-- Handle Coffee Bean - wakes mushroom and disappears
	if stats.CanStackOnMushroom and stats.WakesMushrooms then
		if existingEntityId and world:contains(existingEntityId) then
			-- Fire PlantActionEvent instead of direct API call
			-- MushroomSystem will react to this event
			world:spawn(PlantActionEvent({
				ActionType = "WakeMushroom",
				TargetEntity = existingEntityId,
				PositionX = worldPos.X,
				PositionY = worldPos.Y,
				PositionZ = worldPos.Z,
			}))
			
			-- Coffee Bean is consumed - don't spawn entity
			-- Deduct sun and start cooldown
			playerSun[player] = (playerSun[player] or 0) - stats.Cost
			local cooldowns = playerCooldowns[player]
			if cooldowns then
				cooldowns[plantType] = os.clock() + stats.Cooldown
			end
			
			Logger.Info("PlacementSystem", `Coffee Bean woke mushroom at ({column}, {lane}) for {player.Name}`)
			return -1 -- No entity spawned
		end
	end
	
	local entityId = EntityPool.Spawn(
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
	
	if not entityId then
		Logger.Error("PlacementSystem", "EntityPool exhausted! Cannot spawn plant")
		return nil :: any
	end
	
	-- Mark cell as occupied (only if not stacking)
	if not stats.CanStackOnPlant and not existingEntityId then
		GridService.Occupy(column, lane, entityId)
	end
	
	-- Deduct sun
	playerSun[player] = (playerSun[player] or 0) - stats.Cost
	
	-- Start cooldown
	local cooldowns = playerCooldowns[player]
	if cooldowns then
		cooldowns[plantType] = os.clock() + stats.Cooldown
	end
	
	-- Get equipped mutations for this plant
	local mutations = MutationApplySystemModule.API.GetPlantMutations(player.UserId, plantType)
	local mutationInfo = ""
	if #mutations > 0 then
		mutationInfo = ` with {#mutations} mutation(s): {table.concat(mutations, ", ")}`
	end
	
	Logger.Info("PlacementSystem", `Spawned {plantType} at ({column}, {lane}) for {player.Name} - Entity {entityId}{mutationInfo}`)
	
	-- Broadcast to all clients
	Network.PlantSpawned.FireAll({
		EntityId = entityId,
		PlantType = plantType :: any,
		Lane = lane :: any,
		Column = column :: any,
		OwnerId = player.UserId,
	})
	
	-- Spawn SpawnEvent for presentation systems (VFX, Audio)
	-- MushroomSystem and SpecialPlantSystem will also react to this event
	-- to initialize mushroom sleeping state or arm explosives
	world:spawn(SpawnEvent({
		Target = entityId,
		EntityType = "Plant",
		PositionX = worldPos.X,
		PositionY = worldPos.Y + 2,
		PositionZ = worldPos.Z,
	}))
	
	return entityId
end

-- API for handling placement requests (will be called by Zap handler)
local PlacementAPI = {}

function PlacementAPI.RequestPlacement(world: any, player: Player, column: number, lane: number, plantType: string): (boolean, string?)
	local success, reason = validatePlacement(player, column, lane, plantType, world)
	
	if not success then
		Logger.Warn("PlacementSystem", `Placement denied for {player.Name}: {reason}`)
		return false, reason
	end
	
	local entityId = spawnPlant(world, player, column, lane, plantType)
	if entityId < 0 and not PlantData[plantType].CanStackOnMushroom then
		-- entityId -1 is valid for Coffee Bean (consumed on use)
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

--[[
	Shovel (remove) a plant and refund partial sun
	@param world any - Matter world
	@param player Player - Player requesting removal
	@param plantEntityId number - Entity ID of plant to remove
	@return boolean, string? - Success and optional error reason
]]
function PlacementAPI.ShovelPlant(world: any, player: Player, plantEntityId: number): (boolean, string?)
	-- Validate entity exists
	if not world:contains(plantEntityId) then
		return false, "Plant not found"
	end
	
	-- Get plant info
	local plantType = world:get(plantEntityId, PlantTypeComponent)
	local owner = world:get(plantEntityId, OwnerComponent)
	
	if not plantType then
		return false, "Not a plant"
	end
	
	-- Check ownership
	if not owner or owner.PlayerId ~= player.UserId then
		return false, "Not your plant"
	end
	
	-- Get plant stats for refund calculation
	local stats = PlantData[plantType.PlantType]
	if not stats then
		return false, "Invalid plant type"
	end
	
	-- Calculate refund (50% of cost)
	local refundAmount = math.floor(stats.Cost * 0.5)
	
	-- Clear grid cell
	GridService.ClearByEntity(plantEntityId)
	
	-- Release plant back to pool
	if EntityPool.IsPooledEntity(plantEntityId) then
		EntityPool.Despawn(plantEntityId)
	else
		world:despawn(plantEntityId)
	end
	
	-- Refund sun to player
	PlacementAPI.AddSun(player, refundAmount)
	
	Logger.Info("PlacementSystem", `{player.Name} shoveled {plantType.PlantType} - refunded {refundAmount} sun`)
	
	-- Broadcast removal to all clients (use EntityDied event)
	Network.EntityDied.FireAll({
		EntityId = plantEntityId,
	})
	
	return true, nil
end

-- Set up network handler for shovel requests
Network.ShovelPlantRequest.SetCallback(function(player: Player, data)
	if not _world then
		Logger.Warn("PlacementSystem", "World not initialized, rejecting shovel")
		Network.RequestResponse.Fire(player, {
			RequestId = data.RequestId,
			Success = false,
			ErrorCode = 4, -- 4 = World not ready
		})
		return
	end
	
	local success, reason = PlacementAPI.ShovelPlant(_world, player, data.PlantEntityId)
	
	-- Map reason to error code
	local errorCode = 0
	if reason == "Plant not found" then
		errorCode = 5
	elseif reason == "Not your plant" then
		errorCode = 6
	elseif reason == "Not a plant" then
		errorCode = 7
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

local function Init(_world)
	setupListeners()
	-- Initialize existing players
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Logger.Debug("PlacementSystem", "Initialized")
end

local function Dispose()
	_trove:Destroy()
	_trove = Trove.new() -- Reset for potential reuse
	table.clear(playerSun)
	table.clear(playerCooldowns)
	_world = nil
	Logger.Debug("PlacementSystem", "Disposed")
end

return {
	_name = "PlacementSystem",
	priority = 200,
	system = PlacementSystem,
	Init = Init,
	Dispose = Dispose,
	API = PlacementAPI,
}
