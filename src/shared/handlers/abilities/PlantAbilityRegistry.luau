--!strict
--[[
	PlantAbilityRegistry.luau - Registry for complex plant abilities
	
	Provides a centralized registry for plant ability handlers.
	Allows adding new complex plant behaviors without modifying SpecialPlantSystem.
	
	ARCHITECTURE:
	- Each ability is a separate handler module in /handlers/abilities/
	- Handlers define lifecycle hooks (OnSpawn, OnTick, OnDeath)
	- SpecialPlantSystem delegates to this registry
	
	USAGE:
	local handler = PlantAbilityRegistry.GetHandler("Chomper")
	if handler and handler.OnTick then
		handler.OnTick(context)
	end
]]

-- ============================================
-- TYPE DEFINITIONS
-- ============================================

export type AbilityContext = {
	EntityId: number,
	World: any,
	PlantType: string,
	Position: { X: number, Y: number, Z: number },
	Lane: number,
	Column: number,
	CurrentTime: number,
	DeltaTime: number?,
	
	-- State passed between ticks (optional)
	State: { [string]: any }?,
}

export type AbilityResult = {
	Handled: boolean, -- True if ability consumed the action
	Despawn: boolean?, -- True if plant should be removed
	ClearGrid: boolean?, -- True if grid cell should be cleared
	Message: string?, -- Optional log message
}

export type PlantAbilityHandler = {
	-- Identifier
	Id: string,
	Name: string,
	Description: string,
	
	-- Which plant types use this ability
	AppliesTo: { string },
	
	-- Priority (lower = processed first)
	Priority: number?,
	
	-- Lifecycle hooks (all optional)
	OnSpawn: ((ctx: AbilityContext) -> AbilityResult?)?,
	OnTick: ((ctx: AbilityContext) -> AbilityResult?)?,
	OnDeath: ((ctx: AbilityContext) -> AbilityResult?)?,
	OnTargetFound: ((ctx: AbilityContext, targetId: number, targetPos: any) -> AbilityResult?)?,
	
	-- State management
	InitState: ((entityId: number) -> { [string]: any })?,
	CleanupState: ((entityId: number) -> ())?,
}

-- ============================================
-- REGISTRY
-- ============================================

local _handlers: { [string]: PlantAbilityHandler } = {}
local _plantToHandler: { [string]: string } = {} -- PlantType -> HandlerId
local _handlerStates: { [number]: { [string]: any } } = {} -- EntityId -> State

-- ============================================
-- PUBLIC API
-- ============================================

local PlantAbilityRegistry = {}

--[[
	Register a new ability handler
]]
function PlantAbilityRegistry.Register(handler: PlantAbilityHandler)
	if _handlers[handler.Id] then
		warn(`[PlantAbilityRegistry] Handler '{handler.Id}' already registered, overwriting`)
	end
	
	_handlers[handler.Id] = handler
	
	-- Map plant types to this handler
	for _, plantType in handler.AppliesTo do
		_plantToHandler[plantType] = handler.Id
	end
end

--[[
	Get handler for a specific plant type
]]
function PlantAbilityRegistry.GetHandler(plantType: string): PlantAbilityHandler?
	local handlerId = _plantToHandler[plantType]
	if handlerId then
		return _handlers[handlerId]
	end
	return nil
end

--[[
	Get handler by ID
]]
function PlantAbilityRegistry.GetHandlerById(handlerId: string): PlantAbilityHandler?
	return _handlers[handlerId]
end

--[[
	Check if a plant type has a registered ability handler
]]
function PlantAbilityRegistry.HasHandler(plantType: string): boolean
	return _plantToHandler[plantType] ~= nil
end

--[[
	Get all registered handlers
]]
function PlantAbilityRegistry.GetAllHandlers(): { PlantAbilityHandler }
	local result = {}
	for _, handler in _handlers do
		table.insert(result, handler)
	end
	
	-- Sort by priority
	table.sort(result, function(a, b)
		return (a.Priority or 100) < (b.Priority or 100)
	end)
	
	return result
end

--[[
	Initialize state for an entity
]]
function PlantAbilityRegistry.InitState(entityId: number, plantType: string): { [string]: any }?
	local handler = PlantAbilityRegistry.GetHandler(plantType)
	if handler and handler.InitState then
		local state = handler.InitState(entityId)
		_handlerStates[entityId] = state
		return state
	end
	return nil
end

--[[
	Get state for an entity
]]
function PlantAbilityRegistry.GetState(entityId: number): { [string]: any }?
	return _handlerStates[entityId]
end

--[[
	Set state for an entity
]]
function PlantAbilityRegistry.SetState(entityId: number, state: { [string]: any })
	_handlerStates[entityId] = state
end

--[[
	Cleanup state for an entity
	If plantType is nil, just clears the state without calling handler cleanup
]]
function PlantAbilityRegistry.CleanupState(entityId: number, plantType: string?)
	if plantType then
		local handler = PlantAbilityRegistry.GetHandler(plantType)
		if handler and handler.CleanupState then
			handler.CleanupState(entityId)
		end
	end
	_handlerStates[entityId] = nil
end

--[[
	Execute OnSpawn hook for a plant
]]
function PlantAbilityRegistry.ExecuteOnSpawn(ctx: AbilityContext): AbilityResult?
	local handler = PlantAbilityRegistry.GetHandler(ctx.PlantType)
	if handler and handler.OnSpawn then
		ctx.State = PlantAbilityRegistry.GetState(ctx.EntityId)
		return handler.OnSpawn(ctx)
	end
	return nil
end

--[[
	Execute OnTick hook for a plant
]]
function PlantAbilityRegistry.ExecuteOnTick(ctx: AbilityContext): AbilityResult?
	local handler = PlantAbilityRegistry.GetHandler(ctx.PlantType)
	if handler and handler.OnTick then
		ctx.State = PlantAbilityRegistry.GetState(ctx.EntityId)
		local result = handler.OnTick(ctx)
		if ctx.State then
			_handlerStates[ctx.EntityId] = ctx.State
		end
		return result
	end
	return nil
end

--[[
	Execute OnDeath hook for a plant
]]
function PlantAbilityRegistry.ExecuteOnDeath(ctx: AbilityContext): AbilityResult?
	local handler = PlantAbilityRegistry.GetHandler(ctx.PlantType)
	if handler and handler.OnDeath then
		ctx.State = PlantAbilityRegistry.GetState(ctx.EntityId)
		return handler.OnDeath(ctx)
	end
	return nil
end

--[[
	Execute OnTargetFound hook for a plant
]]
function PlantAbilityRegistry.ExecuteOnTargetFound(
	ctx: AbilityContext,
	targetId: number,
	targetPos: any
): AbilityResult?
	local handler = PlantAbilityRegistry.GetHandler(ctx.PlantType)
	if handler and handler.OnTargetFound then
		ctx.State = PlantAbilityRegistry.GetState(ctx.EntityId)
		local result = handler.OnTargetFound(ctx, targetId, targetPos)
		if ctx.State then
			_handlerStates[ctx.EntityId] = ctx.State
		end
		return result
	end
	return nil
end

--[[
	Clear all states (for cleanup on arena end)
]]
function PlantAbilityRegistry.ClearAllStates()
	table.clear(_handlerStates)
end

--[[
	Get list of plant types with handlers
]]
function PlantAbilityRegistry.GetRegisteredPlantTypes(): { string }
	local result = {}
	for plantType in _plantToHandler do
		table.insert(result, plantType)
	end
	return result
end

-- ============================================
-- EXPORT
-- ============================================

return PlantAbilityRegistry
