--!strict
--[[
	ZombieRenderSystem.luau - Client-side zombie visual rendering
	
	Priority: 410 (Render phase - after sun)
	
	Receives zombie spawn/position events from server via Zap.
	Creates and updates visual zombie representations.
	Uses real models from Assets/Zombies, falls back to colored cubes.
	
	LIFECYCLE:
	- Init(): Setup network listeners (CAN yield)
	- system(): Interpolate zombie positions (CANNOT yield)
	- Dispose(): Disconnect events, cleanup visuals
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Use FindFirstChild to avoid yielding (modules should exist from init.client.luau)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "ZombieRenderSystem: Shared folder not found")

local Packages = ReplicatedStorage:FindFirstChild("Packages")
assert(Packages, "ZombieRenderSystem: Packages folder not found")
local Trove = require(Packages:WaitForChild("Trove"))

local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local ZombieData = require(Shared.data.ZombieData)
local Logger = require(Shared.utils.Logger)
local GameSignals = require(Shared.signals.GameSignals)
local ChanceUtils = require(Shared.utils.ChanceUtils)

-- Client root (script.Parent.Parent.Parent since we're in systems/rendering/)
local Client = script.Parent.Parent.Parent
local Modules = Client:FindFirstChild("modules")
local Network = require(Shared.network.generated.client)
local VFXService = require(Modules.VFXService)

-- Assets folder (optional - fallback to cubes if missing)
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local ZombieAssets = Assets and Assets:FindFirstChild("Zombies")

if not ZombieAssets then
	Logger.Warn("ZombieRender", "Zombie assets not found - using fallback cubes")
end

-- Services (lazy loaded)
local _animService: any = nil

local function getAnimService()
	if not _animService and Modules then
		local success, result = pcall(function()
			return require(Modules.AnimationService)
		end)
		if success then
			_animService = result
		end
	end
	return _animService
end

-- Zombie visual cache: entityId -> visual data
type ZombieVisual = {
	Model: Model,
	ZombieType: string,
	Lane: number,
	TargetX: number,
	FeetOffset: number, -- Distance from root to feet for ground alignment
}
local _zombieVisuals: { [number]: ZombieVisual } = {}

-- Trove for cleanup
local _trove = Trove.new()

local INTERPOLATION_SPEED = 10 -- How fast to interpolate to target position

local function getLaneZ(lane: number): number
	-- Return default if not initialized (will be corrected when initialized)
	if not MapConfig.IsInitialized() then
		return lane * 4 -- Rough estimate
	end
	local laneCenter = MapConfig.GridToWorld(1, lane)
	return laneCenter.Z
end

-- Model fallback mapping (when specific model doesn't exist, use Basic)
local MODEL_FALLBACKS: { [string]: string } = {
	Flag = "Basic",
	Imp = "Basic",
	MiniGargantuar = "Gargantuar",
}

local function createZombieVisual(entityId: number, zombieType: string, lane: number, positionX: number): ZombieVisual
	local z = getLaneZ(lane)
	local groundY = if MapConfig.IsInitialized() then MapConfig.GetConfig().GridY else 0

	-- Try to get real model from Assets (with fallback)
	local modelName = zombieType
	local modelTemplate = ZombieAssets and ZombieAssets:FindFirstChild(modelName)

	-- Try specific fallback first, then default to Basic
	if not modelTemplate then
		modelName = MODEL_FALLBACKS[zombieType] or "Basic"
		modelTemplate = ZombieAssets and ZombieAssets:FindFirstChild(modelName)
	end

	if not modelTemplate or not modelTemplate:IsA("Model") then
		Logger.Error("ZombieRender", `No model found for zombie {zombieType} (tried {modelName})`)
		return nil :: any
	end

	-- Clone real model
	local model = modelTemplate:Clone()
	model.Name = `Zombie_{entityId}_{zombieType}`

	-- Ensure PrimaryPart is set (required for animations)
	if not model.PrimaryPart then
		local humanoidRoot = model:FindFirstChild("HumanoidRootPart")
		local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
		local firstPart = model:FindFirstChildWhichIsA("BasePart")
		model.PrimaryPart = humanoidRoot or torso or firstPart
	end

	-- Calculate spawn position with feet offset
	-- FeetOffset = distance from root to feet (so we add it to put feet at ground level)
	local feetOffset = model:GetAttribute("FeetOffset") or 0
	local spawnY = groundY + feetOffset
	local worldPos = Vector3.new(positionX, spawnY, z)

	-- Position and rotate to face toward the house
	local zombieDir = MapConfig.GetZombieDirection()
	local facingCFrame = CFrame.lookAt(worldPos, worldPos + zombieDir) * CFrame.fromEulerAnglesXYZ(0, math.pi / 2, 0)
	model:PivotTo(facingCFrame)

	model:SetAttribute("EntityId", entityId)
	model.Parent = Workspace

	-- Play spawn/idle animations
	local animService = getAnimService()
	if animService then
		animService.PlaySpawn(model)
		animService.StartIdle(model)
	end

	Logger.Debug("ZombieRender", `Zombie {entityId} ({zombieType}) spawned at Y={spawnY}`)

	return {
		Model = model,
		ZombieType = zombieType,
		Lane = lane,
		TargetX = positionX,
		FeetOffset = feetOffset, -- Store for movement updates
	}
end

local function destroyZombieVisual(entityId: number)
	local visual = _zombieVisuals[entityId]
	if visual then
		visual.Model:Destroy()
		_zombieVisuals[entityId] = nil
	end
end

--[[
	Setup network event listeners (called during Init phase)
]]
local function setupNetworkListeners()
	_trove:Add(Network.ZombieSpawned.On(function(data)
		local entityId = data.EntityId
		local zombieType = tostring(data.ZombieType) -- Convert enum to string
		local lane = data.Lane
		local positionX = data.PositionX

		if _zombieVisuals[entityId] then
			Logger.Warn("ZombieRender", `Zombie {entityId} already exists, updating`)
			_zombieVisuals[entityId].TargetX = positionX
		else
			_zombieVisuals[entityId] = createZombieVisual(entityId, zombieType, lane, positionX)
			Logger.Debug("ZombieRender", `Zombie {entityId} ({zombieType}) spawned in lane {lane}`)
		end
	end))

	_trove:Add(Network.ZombiePositionBatch.On(function(data)
		local entityIds = data.EntityIds
		local positionsX = data.PositionsX

		for i, entityId in entityIds do
			local visual = _zombieVisuals[entityId]
			if visual then
				visual.TargetX = positionsX[i]
			end
		end
	end))

	_trove:Add(Network.EntityDied.On(function(data)
		local entityId = data.EntityId
		local visual = _zombieVisuals[entityId]

		if visual then
			-- Remove from active tracking FIRST to prevent duplicate processing
			_zombieVisuals[entityId] = nil

			local pos = visual.Model:GetPivot().Position

			-- Fire signal for VFX/Audio (decoupled)
			GameSignals.OnZombieDeath:Fire({
				Position = pos,
				ZombieType = visual.ZombieType,
			})

			-- Play death animation then destroy
			local animService = getAnimService()
			if animService then
				animService.PlayDeath(visual.Model)
			end

			-- Fade out and destroy after delay
			task.delay(0.5, function()
				if visual.Model and visual.Model.Parent then
					visual.Model:Destroy()
				end
			end)

			Logger.Debug("ZombieRender", `Zombie {entityId} died`)
		end
	end))

	-- Show floating damage numbers
	_trove:Add(Network.EntityDamaged.On(function(data)
		local visual = _zombieVisuals[data.EntityId]
		if visual then
			local pos = visual.Model:GetPivot().Position

			-- Show floating damage number via signal
			if data.DamageAmount > 0 then
				local floatPos = pos
					+ Vector3.new(
						ChanceUtils.RandomOffset(1), -- Random X offset
						1, -- Above zombie
						0
					)

				-- Pass DamageType if available (convert enum to string)
				local damageType = if data.DamageType then tostring(data.DamageType) else "Normal"

				GameSignals.OnDamageDealt:Fire({
					Position = floatPos,
					Amount = data.DamageAmount,
					DamageType = damageType,
				})
			end
		end
	end))

	-- Status effect applied (show overlay on zombie model)
	_trove:Add(Network.StatusApplied.On(function(data)
		local entityId = data.EntityId
		local visual = _zombieVisuals[entityId]
		if visual then
			local statusType = tostring(data.StatusType)
			local duration = data.Duration

			-- Apply status overlay to zombie model
			VFXService.ApplyStatusOverlay(entityId, visual.Model, statusType, duration)
			Logger.Debug("ZombieRender", `Status {statusType} overlay applied to zombie {entityId}`)
		end
	end))

	-- Status effect removed (cleanup overlay)
	_trove:Add(Network.StatusRemoved.On(function(data)
		local entityId = data.EntityId
		local visual = _zombieVisuals[entityId]
		if visual then
			local statusType = tostring(data.StatusType)

			-- Remove status overlay from zombie model
			VFXService.RemoveStatusOverlay(entityId, visual.Model, statusType)
			Logger.Debug("ZombieRender", `Status {statusType} overlay removed from zombie {entityId}`)
		end
	end))
end

--[[
	Init - Setup network listeners (CAN yield)
]]
local function Init(_world)
	setupNetworkListeners()
	Logger.Debug("ZombieRender", "Initialized")
end

-- Movement config
local MovementConfig = {
	MIN_DT = 1 / 120, -- Minimum deltaTime
	MAX_DT = 1 / 15, -- Maximum deltaTime
}

--[[
	System - Interpolate zombie positions (CANNOT yield)
]]
local function ZombieRenderSystem(_world)
	-- Skip if MapConfig not initialized yet (Studio mode)
	if not MapConfig.IsInitialized() then
		return
	end

	-- CRITICAL: Use Matter's deltaTime for frame-rate independence
	local Matter = require(Packages:FindFirstChild("Matter"))
	local dt = Matter.useDeltaTime()
	dt = math.clamp(dt, MovementConfig.MIN_DT, MovementConfig.MAX_DT)
	local groundY = MapConfig.GetConfig().GridY
	local zombieDir = MapConfig.GetZombieDirection()

	-- Interpolate zombie positions
	for entityId, visual in _zombieVisuals do
		if not visual.Model.Parent then
			_zombieVisuals[entityId] = nil
			continue
		end

		local currentPos = visual.Model:GetPivot().Position
		local currentX = currentPos.X
		local targetX = visual.TargetX
		local newX = currentX + (targetX - currentX) * math.min(1, INTERPOLATION_SPEED * dt)

		local z = getLaneZ(visual.Lane)
		local spawnY = groundY + visual.FeetOffset -- Add feet offset for ground alignment
		local newPos = Vector3.new(newX, spawnY, z)

		-- Update position with 90° rotation
		local facingCFrame = CFrame.lookAt(newPos, newPos + zombieDir) * CFrame.Angles(0, math.pi / 2, 0)
		visual.Model:PivotTo(facingCFrame)
	end
end

--[[
	Dispose - Cleanup all visuals and connections
]]
local function Dispose()
	-- Disconnect all events
	_trove:Clean()

	-- Destroy all zombie visuals
	for entityId in _zombieVisuals do
		destroyZombieVisual(entityId)
	end

	Logger.Debug("ZombieRender", "Disposed")
end

return {
	_name = "ZombieRenderSystem",
	priority = 410,
	system = ZombieRenderSystem,
	Init = Init,
	Dispose = Dispose,
}
