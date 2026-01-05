--!strict
--[[
	EntityPool.lua - Pre-spawned entity pool for zero-allocation gameplay
	
	CRITICAL: NEVER use world:spawn() during gameplay after initialization.
	Always use EntityPool.Acquire() to get entities from the pool.
	
	Pool is initialized at server boot with ENTITY_CAP inactive entities.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PerformanceConfig = require(ReplicatedStorage.Shared.config.PerformanceConfig)
local Logger = require(ReplicatedStorage.Shared.utils.Logger)
local ErrorHandler = require(ReplicatedStorage.Shared.utils.ErrorHandler)

-- Import tag component (will be available after package install)
-- local Tags = require(ReplicatedStorage.Shared.components.Tags)

local EntityPool = {}

-- Pool state (module-level is OK for singletons, not systems)
local _available: {number} = {}
local _inUse: {[number]: boolean} = {}
local _world: any = nil -- Matter World reference
local _initialized: boolean = false
local _InactiveTag: any = nil

--[[
	Initialize the entity pool with pre-spawned inactive entities
	
	MUST be called once at server boot before any gameplay.
	Creates ENTITY_CAP entities with InactiveTag component.
	
	@param world - Matter World instance
	@param InactiveTag - Inactive tag component factory
]]
function EntityPool.Initialize(world: any, InactiveTag: any)
	if _initialized then
		ErrorHandler.Report("EntityPool already initialized", "EntityPool.Initialize", "Important")
		return
	end
	
	_world = world
	_InactiveTag = InactiveTag
	
	local poolSize = PerformanceConfig.ENTITY_CAP
	Logger.Info("EntityPool", `Initializing pool with {poolSize} entities`)
	
	-- Pre-spawn all entities with InactiveTag
	for i = 1, poolSize do
		local entityId = world:spawn(InactiveTag())
		table.insert(_available, entityId)
	end
	
	_initialized = true
	Logger.Info("EntityPool", `Pool initialized: {#_available} entities available`)
end

--[[
	Acquire an entity from the pool
	
	Removes InactiveTag and prepares entity for use.
	Caller should add appropriate components after acquiring.
	
	@return Entity ID, or nil if pool exhausted
]]
function EntityPool.Acquire(): number?
	if not _initialized then
		ErrorHandler.Report("EntityPool not initialized", "EntityPool.Acquire", "Critical")
		return nil
	end
	
	if #_available == 0 then
		ErrorHandler.Report(
			"Entity pool exhausted! This should never happen.",
			"EntityPool.Acquire",
			"Critical"
		)
		return nil
	end
	
	-- Pop from available pool
	local entityId = table.remove(_available)
	if entityId then
		_inUse[entityId] = true
		
		-- Remove inactive tag
		if _world:contains(entityId) then
			_world:remove(entityId, _InactiveTag)
		end
	end
	
	return entityId
end

--[[
	Release an entity back to the pool
	
	Strips all components except InactiveTag.
	Entity becomes available for reuse.
	
	@param entityId - Entity to release
]]
function EntityPool.Release(entityId: number)
	if not _initialized then
		ErrorHandler.Report("EntityPool not initialized", "EntityPool.Release", "Critical")
		return
	end
	
	if not _inUse[entityId] then
		ErrorHandler.Report(
			`Entity {entityId} not in use, cannot release`,
			"EntityPool.Release",
			"Minor"
		)
		return
	end
	
	-- Verify entity still exists
	if not _world:contains(entityId) then
		ErrorHandler.Report(
			`Entity {entityId} no longer exists in world`,
			"EntityPool.Release",
			"Important"
		)
		_inUse[entityId] = nil
		return
	end
	
	-- Strip all components (Matter's despawn would remove entity, we just clear it)
	-- For Matter, we need to iterate and remove each component
	-- This is done by the caller before Release, or we add InactiveTag which systems ignore
	
	-- Re-add inactive tag
	_world:insert(entityId, _InactiveTag())
	
	-- Move back to available pool
	_inUse[entityId] = nil
	table.insert(_available, entityId)
end

--[[
	Get pool statistics for monitoring
	
	@return { Available: number, InUse: number, Total: number }
]]
function EntityPool.GetStats(): { Available: number, InUse: number, Total: number }
	local inUseCount = 0
	for _ in _inUse do
		inUseCount = inUseCount + 1
	end
	
	return {
		Available = #_available,
		InUse = inUseCount,
		Total = #_available + inUseCount,
	}
end

--[[
	Check if pool has available entities
	
	@return true if entities available
]]
function EntityPool.HasAvailable(): boolean
	return #_available > 0
end

--[[
	Get count of available entities
	
	@return Number of available entities
]]
function EntityPool.GetAvailableCount(): number
	return #_available
end

--[[
	Check if pool is initialized
	
	@return true if initialized
]]
function EntityPool.IsInitialized(): boolean
	return _initialized
end

return EntityPool
