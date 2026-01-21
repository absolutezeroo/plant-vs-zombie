--!strict
--[[
	EntityPool.luau - Simple entity manager with count cap
	
	REPLACES world:spawn/despawn for gameplay entities.
	- EntityPool.Spawn(...) - Create entity with cap enforcement
	- EntityPool.Despawn(id) - Remove entity and decrement count
	
	For ephemeral events (1-frame), use world:spawn() directly.
	
	Matter already optimizes entity recycling internally - this module
	just enforces the ENTITY_CAP and provides stats.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PerformanceConfig = require(ReplicatedStorage.Shared.config.PerformanceConfig)
local Logger = require(ReplicatedStorage.Shared.utils.core.Logger)
local ErrorHandler = require(ReplicatedStorage.Shared.utils.core.ErrorHandler)

local EntityPool = {}

-- Simple state
local _world: any = nil
local _initialized: boolean = false
local _activeCount: number = 0
local _trackedEntities: { [number]: boolean } = {}

--[[
	Initialize the entity pool
	
	@param world - Matter World instance
	@param InactiveTag - UNUSED (kept for API compatibility)
	@param components - UNUSED (kept for API compatibility)
]]
function EntityPool.Initialize(world: any, _InactiveTag: any?, _components: { [string]: any }?)
	if _initialized then
		ErrorHandler.Report("EntityPool already initialized", "EntityPool.Initialize", "Important")
		return
	end

	_world = world
	_initialized = true
	_activeCount = 0
	table.clear(_trackedEntities)

	Logger.Info("EntityPool", `Initialized with cap of {PerformanceConfig.ENTITY_CAP} entities`)
end

--[[
	Spawn an entity with components (enforces entity cap)
	
	REPLACES world:spawn() for gameplay entities.
	
	@param ... - Component instances to add to the entity
	@return Entity ID, or nil if cap reached
]]
function EntityPool.Spawn(...: any): number?
	if not _initialized then
		ErrorHandler.Report("EntityPool not initialized", "EntityPool.Spawn", "Critical")
		return nil
	end

	-- Check cap
	if _activeCount >= PerformanceConfig.ENTITY_CAP then
		ErrorHandler.Report(
			`Entity cap reached ({PerformanceConfig.ENTITY_CAP}). Cannot spawn more entities.`,
			"EntityPool.Spawn",
			"Critical"
		)
		return nil
	end

	-- Spawn directly via Matter (already optimized internally)
	local entityId = _world:spawn(...)

	-- Track it
	_trackedEntities[entityId] = true
	_activeCount += 1

	return entityId
end

--[[
	Despawn an entity (decrements count)
	
	REPLACES world:despawn() for pooled entities.
	
	@param entityId - Entity to remove
]]
function EntityPool.Despawn(entityId: number)
	if not _initialized then
		ErrorHandler.Report("EntityPool not initialized", "EntityPool.Despawn", "Critical")
		return
	end

	-- Only track entities we spawned
	if not _trackedEntities[entityId] then
		return
	end

	-- Clean up tracking
	_trackedEntities[entityId] = nil
	_activeCount -= 1

	-- Despawn if still exists
	if _world:contains(entityId) then
		_world:despawn(entityId)
	end
end

--[[
	Check if an entity is tracked by the pool
	
	@param entityId - Entity to check
	@return true if entity was spawned via EntityPool
]]
function EntityPool.IsPooledEntity(entityId: number): boolean
	return _trackedEntities[entityId] == true
end

--[[
	Safe despawn - works for both pooled and non-pooled entities
	
	Consolidates the common pattern:
	  if EntityPool.IsPooledEntity(id) then EntityPool.Despawn(id) else world:despawn(id) end
	
	@param entityId - Entity to despawn
	@param world - Optional world instance (uses cached world if not provided)
]]
function EntityPool.SafeDespawn(entityId: number, world: any?)
	if not entityId then
		return
	end
	
	if _trackedEntities[entityId] then
		-- Pooled entity
		EntityPool.Despawn(entityId)
	else
		-- Non-pooled entity
		local w = world or _world
		if w and w:contains(entityId) then
			w:despawn(entityId)
		end
	end
end

--[[
	Legacy: Acquire (prefer Spawn)
]]
function EntityPool.Acquire(): number?
	return EntityPool.Spawn()
end

--[[
	Legacy: Release (prefer Despawn)
]]
function EntityPool.Release(entityId: number)
	EntityPool.Despawn(entityId)
end

--[[
	Get pool statistics for monitoring
	
	@return { Available: number, InUse: number, Total: number }
]]
function EntityPool.GetStats(): { Available: number, InUse: number, Total: number }
	local cap = PerformanceConfig.ENTITY_CAP
	return {
		Available = cap - _activeCount,
		InUse = _activeCount,
		Total = cap,
	}
end

--[[
	Check if more entities can be spawned
]]
function EntityPool.HasAvailable(): boolean
	return _activeCount < PerformanceConfig.ENTITY_CAP
end

--[[
	Get count of remaining entity slots
]]
function EntityPool.GetAvailableCount(): number
	return PerformanceConfig.ENTITY_CAP - _activeCount
end

--[[
	Check if pool is initialized
]]
function EntityPool.IsInitialized(): boolean
	return _initialized
end

--[[
	Get the Matter World instance
]]
function EntityPool.GetWorld(): any
	return _world
end

--[[
	Reset pool state (for testing/cleanup)
]]
function EntityPool.Reset()
	table.clear(_trackedEntities)
	_activeCount = 0
	_world = nil
	_initialized = false
	Logger.Debug("EntityPool", "Pool reset")
end

return EntityPool
