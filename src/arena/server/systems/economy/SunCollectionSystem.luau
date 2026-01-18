--!strict
--[[
	SunCollectionSystem.luau - Server-side sun collection processing
	
	SYSTEM V2 ARCHITECTURE (see docs/SYSTEM-STANDARD.md)
	
	Priority: 310 (After sun spawning)
	
	Handles sun collection requests from clients via Zap.
	Validates the sun entity exists and is collectible.
	Awards sun to player via SunService and despawns entity.
	
	LIFECYCLE:
	- Init(): Setup network listener (CAN yield)
	- OnStep(): Main loop (CANNOT yield) - processes collection queue
	- Dispose(): Clear collection queue
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)
local EntityPool = require(Shared.utils.EntityPool)

-- Network
local Network = require(Shared.network.generated.server)

-- Server services
local Server = script.Parent.Parent.Parent
local SunService = require(Server.services.SunService)

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 310,
})

-- ============================================================
-- SECTION 3: STATE (all mutable data)
-- ============================================================
local State = {
	World = nil :: any?,
	CollectionQueue = {} :: { { Player: Player, EntityId: number, RequestId: number } },
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

-- Queue a collection request (called by network handler)
local function queueCollection(player: Player, entityId: number, requestId: number)
	table.insert(State.CollectionQueue, {
		Player = player,
		EntityId = entityId,
		RequestId = requestId,
	})
end

-- Validate collection and return sun value if valid
local function processCollection(world: any, player: Player, entityId: number): number?
	-- Check entity exists
	if not world:contains(entityId) then
		Logger.Warn("SunCollection", `Entity {entityId} does not exist`)
		return nil
	end

	-- Check entity has SunComponent
	local sun = world:get(entityId, Components.SunComponent)
	if not sun then
		Logger.Warn("SunCollection", `Entity {entityId} is not a sun`)
		return nil
	end

	-- Check ownership: if sun has an owner, only that player can collect it
	if sun.OwnerId and sun.OwnerId ~= player.UserId then
		Logger.Debug("SunCollection", `{player.Name} cannot collect sun {entityId} - belongs to another player`)
		return nil
	end

	local value = sun.Value

	-- Release sun back to pool
	EntityPool.SafeDespawn(entityId, world)

	Logger.Debug("SunCollection", `{player.Name} collected sun {entityId} worth {value}`)

	return value
end

-- ============================================================
-- SECTION 5: ONSTEP (main ECS loop)
-- ============================================================
local function OnStep(world)
	State.World = world

	-- Process collection queue
	for _, request in State.CollectionQueue do
		local value = processCollection(world, request.Player, request.EntityId)

		if value then
			-- Add sun via SunService
			SunService.AddSun(request.Player, value)
			local newTotal = SunService.GetSun(request.Player)

			-- Broadcast SunCollected to all clients
			Network.SunCollected.FireAll({
				SunEntityId = request.EntityId,
				CollectorId = request.Player.UserId,
				NewTotal = newTotal,
			})

			-- Send success response
			Network.RequestResponse.Fire(request.Player, {
				RequestId = request.RequestId,
				Success = true,
				ErrorCode = nil,
			})
		else
			-- Send failure response
			Network.RequestResponse.Fire(request.Player, {
				RequestId = request.RequestId,
				Success = false,
				ErrorCode = 0, -- Generic error
			})
		end
	end

	-- Clear queue
	table.clear(State.CollectionQueue)
end

-- ============================================================
-- SECTION 6: INIT / DISPOSE
-- ============================================================
local function Init(_world)
	-- Set up network handler
	Network.CollectSunRequest.SetCallback(function(player: Player, data)
		queueCollection(player, data.SunEntityId, data.RequestId)
	end)

	Logger.Debug("SunCollectionSystem", "Initialized")
end

local function Dispose()
	table.clear(State.CollectionQueue)
	State.World = nil
	Logger.Debug("SunCollectionSystem", "Disposed")
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
