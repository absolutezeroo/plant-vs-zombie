--!strict
--[[
	PlacementSystem.luau - Server-side plant placement validation
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 200 (Core game logic)
	
	Validates placement requests from clients:
	- Cell in bounds
	- Cell not occupied
	- Player has enough sun
	- Plant not on cooldown (server cooldown tracking)
	
	Spawns plant entity on success, rejects on failure.
	
	LIFECYCLE:
	- Init(): Setup player listeners and network handlers (CAN yield)
	- OnStep(): Main loop (CANNOT yield) - stores world reference
	- Dispose(): Cleanup player connections and state
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local GridUtils = require(Shared.utils.GridUtils)
local PlantData = require(Shared.data.PlantData)
local WorldData = require(Shared.data.WorldData)
local Logger = require(Shared.utils.Logger)
local EntityPool = require(Shared.utils.EntityPool)

-- Network
local Network = require(Shared.network.generated.server)

-- Server services
local Server = script.Parent.Parent.Parent
local GridService = require(Server.services.GridService)
local SunService = require(Server.services.SunService)
local WaveService = require(Server.services.WaveService)
local MutationService = require(Server.services.MutationService)

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 200,
})

-- ============================================================
-- SECTION 3: STATE (all mutable data)
-- ============================================================
local State = {
	World = nil :: any?,
	Trove = Trove.new(),
	PlayerCooldowns = {} :: { [Player]: { [string]: number } },
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

-- Initialize new player
local function onPlayerAdded(player: Player)
	State.PlayerCooldowns[player] = {}
	Logger.Debug("PlacementSystem", `Player {player.Name} initialized`)
end

local function onPlayerRemoving(player: Player)
	State.PlayerCooldowns[player] = nil
end

-- Validate placement request
local function validatePlacement(player: Player, column: number, lane: number, plantType: string): (boolean, string?)
	local world = State.World
	if not world then
		return false, "World not ready"
	end

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

	if existingEntityId and world:contains(existingEntityId) then
		existingPlant = world:get(existingEntityId, Components.PlantTypeComponent)
		if existingPlant then
			existingStats = PlantData[existingPlant.PlantType]
		end
	end

	-- ==============================================
	-- Water/Platform validation (DATA-DRIVEN)
	-- ==============================================

	-- Get current world config from WaveService
	local worldConfig = WaveService.GetCurrentWorldConfig()
	local waterLanes: { number } = if worldConfig then worldConfig.WaterLanes or {} else {}
	local isWaterLane = table.find(waterLanes, lane) ~= nil

	-- Rule 1: Plants with RequiresWater can ONLY be placed on water lanes
	if stats.RequiresWater then
		if not isWaterLane then
			return false, "This plant requires a water lane"
		end
		-- RequiresWater plants go directly in water (no LilyPad needed)
	end

	-- Rule 2: Platform plants have lane restrictions
	if stats.IsPlatform and stats.AllowsPlantOnTop then
		-- DATA-DRIVEN: Use IsWaterPlatform and IsGroundPlatform flags
		if stats.IsWaterPlatform and not isWaterLane then
			return false, "Lily Pad can only be placed on water lanes"
		end
		if stats.IsGroundPlatform and isWaterLane then
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
			local SleepingComponent = Components.SleepingComponent
			local sleeping = world:get(existingEntityId, SleepingComponent)
			if not sleeping or not sleeping.IsSleeping then
				return false, "Mushroom is already awake"
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

	-- Check player has enough sun (via SunService)
	local sun = SunService.GetSun(player)
	if sun < stats.Cost then
		return false, "Not enough sun"
	end

	-- Check cooldown
	local cooldowns = State.PlayerCooldowns[player]
	if cooldowns then
		local cooldownEnd = cooldowns[plantType]
		if cooldownEnd and os.clock() < cooldownEnd then
			return false, "Plant on cooldown"
		end
	end

	return true, nil
end

-- Spawn plant entity
local function spawnPlant(player: Player, column: number, lane: number, plantType: string): number
	local world = State.World
	if not world then
		Logger.Error("PlacementSystem", "World not initialized")
		return -1
	end

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
			world:spawn(Components.PlantActionEvent({
				ActionType = "WakeMushroom",
				TargetEntity = existingEntityId,
				PositionX = worldPos.X,
				PositionY = worldPos.Y,
				PositionZ = worldPos.Z,
			}))

			-- Coffee Bean is consumed - don't spawn entity
			-- Deduct sun and start cooldown
			SunService.SpendSun(player, stats.Cost)
			local cooldowns = State.PlayerCooldowns[player]
			if cooldowns then
				cooldowns[plantType] = os.clock() + stats.Cooldown
			end

			Logger.Info("PlacementSystem", `Coffee Bean woke mushroom at ({column}, {lane}) for {player.Name}`)
			return -1 -- No entity spawned
		end
	end

	local entityId = EntityPool.Spawn(
		Components.PositionComponent({
			X = worldPos.X,
			Y = worldPos.Y + 2, -- Slightly above ground
			Z = worldPos.Z,
		}),
		Components.HealthComponent({
			Current = stats.Health,
			Max = stats.Health,
		}),
		Components.PlantTypeComponent({
			PlantType = plantType,
			Column = column,
			Lane = lane,
		}),
		Components.OwnerComponent({
			PlayerId = player.UserId,
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

	-- Deduct sun via SunService
	SunService.SpendSun(player, stats.Cost)

	-- Start cooldown
	local cooldowns = State.PlayerCooldowns[player]
	if cooldowns then
		cooldowns[plantType] = os.clock() + stats.Cooldown
	end

	-- Get equipped mutations for this plant (via MutationService)
	local mutations = MutationService.GetPlantMutations(player.UserId, plantType)
	local mutationInfo = ""
	if #mutations > 0 then
		mutationInfo = ` with {#mutations} mutation(s): {table.concat(mutations, ", ")}`
	end

	Logger.Info(
		"PlacementSystem",
		`Spawned {plantType} at ({column}, {lane}) for {player.Name} - Entity {entityId}{mutationInfo}`
	)

	-- Broadcast to all clients (with mutations as enum array)
	Network.PlantSpawned.FireAll({
		EntityId = entityId,
		PlantType = plantType :: any,
		Lane = lane :: any,
		Column = column :: any,
		OwnerId = player.UserId,
		Mutations = mutations :: any,
	})

	-- Spawn SpawnEvent for presentation systems (VFX, Audio)
	-- MushroomSystem and SpecialPlantSystem will also react to this event
	-- to initialize mushroom sleeping state or arm explosives
	world:spawn(Components.SpawnEvent({
		Target = entityId,
		EntityType = "Plant",
		PositionX = worldPos.X,
		PositionY = worldPos.Y + 2,
		PositionZ = worldPos.Z,
	}))

	return entityId
end

-- Handle placement request
local function handlePlacementRequest(
	player: Player,
	column: number,
	lane: number,
	plantType: string
): (boolean, string?)
	local success, reason = validatePlacement(player, column, lane, plantType)

	if not success then
		Logger.Warn("PlacementSystem", `Placement denied for {player.Name}: {reason}`)
		return false, reason
	end

	local entityId = spawnPlant(player, column, lane, plantType)
	if entityId < 0 and not PlantData[plantType].CanStackOnMushroom then
		-- entityId -1 is valid for Coffee Bean (consumed on use)
		return false, "Spawn failed"
	end

	return true, nil
end

-- Shovel (remove) a plant and refund partial sun
local function handleShovelRequest(player: Player, plantEntityId: number): (boolean, string?)
	local world = State.World
	if not world then
		return false, "World not ready"
	end

	-- Validate entity exists
	if not world:contains(plantEntityId) then
		return false, "Plant not found"
	end

	-- Get plant info
	local plantType = world:get(plantEntityId, Components.PlantTypeComponent)
	local owner = world:get(plantEntityId, Components.OwnerComponent)

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

	-- Refund sun to player via SunService
	SunService.AddSun(player, refundAmount)

	Logger.Info("PlacementSystem", `{player.Name} shoveled {plantType.PlantType} - refunded {refundAmount} sun`)

	-- Broadcast removal to all clients (use EntityDied event)
	Network.EntityDied.FireAll({
		EntityId = plantEntityId,
	})

	return true, nil
end

-- Set up network handlers
local function setupNetworkHandlers()
	-- Placement request handler
	Network.PlacePlantRequest.SetCallback(function(player: Player, data)
		if not State.World then
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

		local success, reason = handlePlacementRequest(player, column, lane, plantType)

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

	-- Shovel request handler
	Network.ShovelPlantRequest.SetCallback(function(player: Player, data)
		if not State.World then
			Logger.Warn("PlacementSystem", "World not initialized, rejecting shovel")
			Network.RequestResponse.Fire(player, {
				RequestId = data.RequestId,
				Success = false,
				ErrorCode = 4, -- 4 = World not ready
			})
			return
		end

		local success, reason = handleShovelRequest(player, data.PlantEntityId)

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
end

-- ============================================================
-- SECTION 5: ONSTEP (main ECS loop)
-- ============================================================
local function OnStep(world)
	State.World = world
	-- Cooldown processing handled by os.clock() comparisons
	-- No per-frame work needed
end

-- ============================================================
-- SECTION 6: INIT / DISPOSE
-- ============================================================
local function Init(_world)
	-- Setup player listeners
	State.Trove:Connect(Players.PlayerAdded, onPlayerAdded)
	State.Trove:Connect(Players.PlayerRemoving, onPlayerRemoving)

	-- Initialize existing players
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Setup network handlers
	setupNetworkHandlers()

	Logger.Debug("PlacementSystem", "Initialized")
end

local function Dispose()
	State.Trove:Destroy()
	State.Trove = Trove.new()
	table.clear(State.PlayerCooldowns)
	State.World = nil
	Logger.Debug("PlacementSystem", "Disposed")
end

-- ============================================================
-- SECTION 7: MODULE EXPORT
-- ============================================================
return {
	priority = CONFIG.PRIORITY,
	system = OnStep,
	Init = Init,
	Dispose = Dispose,
}
