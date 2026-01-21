--!strict
--[[
	ZombieRenderSystem.luau - Client-side zombie visual rendering
	
	Priority: 410 (Render phase - after sun)
	
	Receives zombie spawn/position events from server via Zap.
	Creates and updates visual zombie representations.
	Uses real models from Assets/Zombies, falls back to colored cubes.
	
	V3 Architecture: Matter Hooks pattern
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Use FindFirstChild to avoid yielding (modules should exist from init.client.luau)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "ZombieRenderSystem: Shared folder not found")

local Packages = ReplicatedStorage:FindFirstChild("Packages")
assert(Packages, "ZombieRenderSystem: Packages folder not found")
local Trove = require(Packages:WaitForChild("Trove"))
local Hooks = require(Packages.MatterHooks)

local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local ZombieData = require(Shared.data.ZombieData)
local Logger = require(Shared.utils.core.Logger)
local GameSignals = require(Shared.signals.GameSignals)
local ChanceUtils = require(Shared.utils.core.ChanceUtils)

-- Client root (script.Parent.Parent.Parent since we're in systems/rendering/)
local Client = script.Parent.Parent.Parent
local Modules = Client:FindFirstChild("modules")
local Controllers = Client:FindFirstChild("controllers")
local Network = require(Shared.network.generated.client)
local VFXService = require(Modules.VFXService)
local AudioService = require(Modules.AudioService)
local FogController = require(Controllers.FogController)

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
	IsVaulting: boolean?, -- True while playing vault animation
	IsGlowing: boolean?, -- True for Plant Food zombies
	IsHypnotized: boolean?, -- True for hypnotized zombies (walk backwards)
	CachedParts: { BasePart }?, -- Cached BaseParts for fog visibility
	LastFogVisible: boolean?, -- Last fog visibility state (to avoid redundant updates)
}
local _zombieVisuals: { [number]: ZombieVisual } = {}

-- Vault animation config
local VAULT_CONFIG = {
	DURATION = 0.5, -- Seconds for the jump arc
	HEIGHT = 8, -- Peak height of the jump arc (studs)
}

-- Trove for cleanup
local _trove = Trove.new()

local INTERPOLATION_SPEED = 10 -- How fast to interpolate to target position

-- Cached MapConfig values (set in Init, rarely change)
local _cachedGroundY: number = 0
local _cachedZombieDir: Vector3 = Vector3.new(-1, 0, 0)
local _mapConfigCached: boolean = false

-- Groan system: random zombie groans for immersion
local GROAN_CONFIG = {
	MIN_INTERVAL = 2.0, -- Minimum seconds between groans
	MAX_INTERVAL = 6.0, -- Maximum seconds between groans
	CHANCE_PER_ZOMBIE = 0.7, -- 30% chance a zombie groans when timer triggers
}
local _nextGroanTime = 0

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
local DEFAULT_FALLBACK_MODEL = "Basic"

local function createZombieVisual(entityId: number, zombieType: string, lane: number, positionX: number, isGlowing: boolean?): ZombieVisual
	local z = getLaneZ(lane)
	local groundY = if MapConfig.IsInitialized() then MapConfig.GetConfig().GridY else 0

	-- Try to get real model from Assets (with fallback)
	local modelName = zombieType
	local modelTemplate = ZombieAssets and ZombieAssets:FindFirstChild(modelName)

	-- Try specific fallback first, then default fallback
	if not modelTemplate then
		modelName = MODEL_FALLBACKS[zombieType] or DEFAULT_FALLBACK_MODEL
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
	local finalY = groundY + feetOffset
	
	-- Emerge animation config
	local EMERGE_DEPTH = 4 -- How far below ground to start (fallback if no animation)
	local EMERGE_DURATION = 0.8 -- Fallback duration if no animation

	-- Position and rotate to face toward the house
	local zombieDir = MapConfig.GetZombieDirection()
	local finalPos = Vector3.new(positionX, finalY, z)
	local finalCFrame = CFrame.lookAt(finalPos, finalPos + zombieDir) * CFrame.fromEulerAnglesXYZ(0, math.pi / 2, 0)
	
	-- Check if we have an Emerge animation
	local animService = getAnimService()
	local hasEmergeAnim = false
	local emergeDuration = 0
	
	if animService then
		-- Try to get emerge animation duration (returns 0 if not available)
		-- We need to position model first to load animations
		model:PivotTo(finalCFrame)
		model:SetAttribute("EntityId", entityId)
		model:SetAttribute("IsEmerging", true)
		model.Parent = Workspace
		
		emergeDuration = animService.PlayEmerge(model)
		hasEmergeAnim = emergeDuration > 0
	end
	
	-- Play dirt burst VFX at ground level
	local groundPos = Vector3.new(positionX, groundY, z)
	local VFXUtils = require(Shared.utils.vfx.VFXUtils)
	VFXUtils.DirtBurst(groundPos)

	if hasEmergeAnim then
		-- USE ANIMATION: Model stays in place, animation handles the visual
		Logger.Debug("ZombieRender", `Zombie {entityId} playing Emerge animation ({emergeDuration}s)`)
		
		task.spawn(function()
			-- Wait for animation to complete
			task.wait(emergeDuration)
			
			if model and model.Parent then
				model:SetAttribute("IsEmerging", false)
				-- Start walk after emerge
				if animService then
					animService.StartIdle(model)
				end
			end
		end)
	else
		-- FALLBACK: Tween-based emerge (no animation available)
		local startY = finalY - EMERGE_DEPTH
		local startPos = Vector3.new(positionX, startY, z)
		local startCFrame = CFrame.lookAt(startPos, startPos + zombieDir) * CFrame.fromEulerAnglesXYZ(0, math.pi / 2, 0)
		model:PivotTo(startCFrame)
		
		task.spawn(function()
			-- Create a CFrameValue to tween
			local cframeValue = Instance.new("CFrameValue")
			cframeValue.Value = startCFrame
			cframeValue.Parent = model
			
			-- Connect to update model position when value changes
			local connection = cframeValue.Changed:Connect(function()
				if model and model.Parent then
					model:PivotTo(cframeValue.Value)
				end
			end)
			
			-- Create and play tween
			local tweenInfo = TweenInfo.new(
				EMERGE_DURATION,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
			local tween = TweenService:Create(cframeValue, tweenInfo, { Value = finalCFrame })
			tween:Play()
			
			-- Wait for tween to complete
			tween.Completed:Wait()
			
			-- Cleanup
			connection:Disconnect()
			cframeValue:Destroy()
			
			-- Ensure final position and clear flag
			if model and model.Parent then
				model:PivotTo(finalCFrame)
				model:SetAttribute("IsEmerging", false)
				
				-- Start walk after emerge
				if animService then
					animService.StartIdle(model)
				end
			end
		end)
	end

	Logger.Debug("ZombieRender", `Zombie {entityId} ({zombieType}) emerging from ground`)

	-- Apply Plant Food glow effect if this zombie is glowing
	if isGlowing then
		Logger.Debug("ZombieRender", `Zombie {entityId} is GLOWING (Plant Food)`)
		
		-- Find a main part for the PointLight
		local mainPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if mainPart then
			-- Green glow light
			local glowLight = Instance.new("PointLight")
			glowLight.Name = "PlantFoodGlow"
			glowLight.Color = Color3.fromRGB(100, 255, 100) -- Green
			glowLight.Brightness = 3
			glowLight.Range = 8
			glowLight.Shadows = false
			glowLight.Parent = mainPart
			
			-- Highlight effect for outline
			local highlight = Instance.new("Highlight")
			highlight.Name = "PlantFoodHighlight"
			highlight.FillColor = Color3.fromRGB(100, 255, 100)
			highlight.FillTransparency = 0.7
			highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
			highlight.OutlineTransparency = 0
			highlight.Adornee = model
			highlight.Parent = model
		end
	end

	return {
		Model = model,
		ZombieType = zombieType,
		Lane = lane,
		TargetX = positionX,
		FeetOffset = feetOffset, -- Store for movement updates
		IsGlowing = isGlowing,
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
		local isGlowing = data.IsGlowing

		if _zombieVisuals[entityId] then
			Logger.Warn("ZombieRender", `Zombie {entityId} already exists, updating`)
			_zombieVisuals[entityId].TargetX = positionX
		else
			_zombieVisuals[entityId] = createZombieVisual(entityId, zombieType, lane, positionX, isGlowing)
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

	-- Clear all visuals when map is unloading
	_trove:Add(Network.MapUnloading.On(function(data)
		Logger.Info("ZombieRender", `Map unloading: {data.MapId}, clearing {#_zombieVisuals} zombie visuals`)
		for entityId, visual in _zombieVisuals do
			if visual.Model then
				visual.Model:Destroy()
			end
		end
		table.clear(_zombieVisuals)
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

	-- Zombie vaulted over a plant (Pole Vaulter jump animation)
	_trove:Add(Network.ZombieVaulted.On(function(data)
		local entityId = data.EntityId
		local visual = _zombieVisuals[entityId]
		if not visual or not visual.Model.Parent then
			return
		end

		-- Mark as vaulting (disable normal interpolation)
		visual.IsVaulting = true

		-- Start and end positions
		local startPos = Vector3.new(data.StartX, data.StartY, data.StartZ)
		local endPos = Vector3.new(data.EndX, data.EndY, data.EndZ)
		local peakHeight = VAULT_CONFIG.HEIGHT
		local duration = VAULT_CONFIG.DURATION

		-- Get zombie facing direction
		local zombieDir = MapConfig.GetZombieDirection()
		local baseCFrame = CFrame.Angles(0, math.pi / 2, 0)

		-- Play vault animation in a separate thread
		task.spawn(function()
			local startTime = os.clock()

			while true do
				local elapsed = os.clock() - startTime
				local t = math.min(elapsed / duration, 1)

				-- Parabolic arc for Y position (peaks at t=0.5)
				local arcT = 4 * t * (1 - t) -- Parabola: 0 at t=0, 1 at t=0.5, 0 at t=1
				local currentY = startPos.Y + (peakHeight * arcT)

				-- Linear interpolation for X and Z
				local currentX = startPos.X + (endPos.X - startPos.X) * t
				local currentZ = startPos.Z + (endPos.Z - startPos.Z) * t

				local currentPos = Vector3.new(currentX, currentY, currentZ)
				local facingCFrame = CFrame.lookAt(currentPos, currentPos + zombieDir) * baseCFrame

				-- Update model position
				if visual.Model and visual.Model.Parent then
					visual.Model:PivotTo(facingCFrame)
				else
					break -- Model destroyed
				end

				if t >= 1 then
					break -- Animation complete
				end

				task.wait() -- Wait one frame
			end

			-- Update target position and end vaulting
			if visual then
				visual.TargetX = endPos.X
				visual.IsVaulting = false
			end

			Logger.Debug("ZombieRender", `Zombie {entityId} vault animation complete`)
		end)

		Logger.Debug("ZombieRender", `Zombie {entityId} vaulting from {startPos} to {endPos}`)
	end))

	-- Zombie was hypnotized (turn around and walk backwards)
	_trove:Add(Network.ZombieHypnotized.On(function(data)
		local entityId = data.ZombieId
		local visual = _zombieVisuals[entityId]
		if not visual or not visual.Model.Parent then
			Logger.Warn("ZombieRender", `Hypnotized zombie {entityId} not found`)
			return
		end

		-- Get current model position
		local currentCFrame = visual.Model:GetPivot()
		local currentPos = currentCFrame.Position

		-- Rotate 180 degrees (zombie now faces opposite direction)
		local zombieDir = MapConfig.GetZombieDirection()
		local reversedDir = -zombieDir
		local newCFrame = CFrame.lookAt(currentPos, currentPos + reversedDir) * CFrame.Angles(0, math.pi / 2, 0)

		-- Tween the rotation for smooth turn
		local turnTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		-- Find root part to tween
		local rootPart = visual.Model.PrimaryPart or visual.Model:FindFirstChildWhichIsA("BasePart")
		if rootPart then
			local tween = TweenService:Create(rootPart, turnTweenInfo, {
				CFrame = newCFrame,
			})
			tween:Play()
		else
			-- No tween possible, snap rotation
			visual.Model:PivotTo(newCFrame)
		end

		-- Mark as hypnotized for interpolation (reverses direction)
		visual.IsHypnotized = true

		Logger.Info("ZombieRender", `Zombie {entityId} hypnotized, turning around`)
	end))

	-- Zombie diverted to adjacent lane by Garlic
	_trove:Add(Network.ZombieDiverted.On(function(data)
		local entityId = data.EntityId
		local visual = _zombieVisuals[entityId]
		if not visual or not visual.Model.Parent then
			Logger.Warn("ZombieRender", `Diverted zombie {entityId} not found`)
			return
		end

		local newLane = data.NewLane
		local newZ = data.NewZ

		-- Update lane tracking
		local oldLane = visual.Lane
		visual.Lane = newLane

		-- Get current position
		local currentCFrame = visual.Model:GetPivot()
		local currentPos = currentCFrame.Position
		local targetPos = Vector3.new(currentPos.X, currentPos.Y, newZ)

		-- Smooth lane transition (tween Z position)
		local laneChangeTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		-- Use CFrameValue for smooth model pivot tween
		task.spawn(function()
			local cframeValue = Instance.new("CFrameValue")
			cframeValue.Value = currentCFrame
			cframeValue.Parent = visual.Model

			local connection = cframeValue.Changed:Connect(function()
				if visual.Model and visual.Model.Parent then
					visual.Model:PivotTo(cframeValue.Value)
				end
			end)

			local zombieDir = MapConfig.GetZombieDirection()
			local targetCFrame = CFrame.lookAt(targetPos, targetPos + zombieDir) * CFrame.Angles(0, math.pi / 2, 0)

			local tween = TweenService:Create(cframeValue, laneChangeTweenInfo, { Value = targetCFrame })
			tween:Play()
			tween.Completed:Wait()

			connection:Disconnect()
			cframeValue:Destroy()
		end)

		-- Play divert VFX (dust puff)
		local VFXUtils = require(Shared.utils.vfx.VFXUtils)
		VFXUtils.DirtBurst(currentPos)

		Logger.Debug("ZombieRender", `Zombie {entityId} diverted from lane {oldLane} to lane {newLane}`)
	end))
end

--[[
	Init - Setup network listeners (via useMemo in system)
]]
local function setupAndInitialize()
	setupNetworkListeners()

	-- Cache MapConfig values (they don't change during gameplay)
	if MapConfig.IsInitialized() then
		_cachedGroundY = MapConfig.GetConfig().GridY
		_cachedZombieDir = MapConfig.GetZombieDirection()
		_mapConfigCached = true
	end

	-- Listen for map config sync to update cache
	_trove:Add(Network.MapConfigSync.On(function(_data)
		task.defer(function()
			if MapConfig.IsInitialized() then
				_cachedGroundY = MapConfig.GetConfig().GridY
				_cachedZombieDir = MapConfig.GetZombieDirection()
				_mapConfigCached = true
				Logger.Debug("ZombieRender", "MapConfig cache updated")
			end
		end)
	end))
	
	Logger.Debug("ZombieRender", "Initialized")
end

-- Movement config
local MovementConfig = {
	MIN_DT = 1 / 120, -- Minimum deltaTime
	MAX_DT = 1 / 15, -- Maximum deltaTime
}

--[[
	System - Initialize on first run and interpolate zombie positions
]]
local function ZombieRenderSystem(_world)
	-- Initialize network listeners once via useMemo
	Hooks.useMemo(function()
		setupAndInitialize()
		return true
	end, {})

	-- Skip if MapConfig not initialized yet (Studio mode)
	if not MapConfig.IsInitialized() then
		return
	end

	-- Update cache if not yet cached (late initialization)
	if not _mapConfigCached then
		_cachedGroundY = MapConfig.GetConfig().GridY
		_cachedZombieDir = MapConfig.GetZombieDirection()
		_mapConfigCached = true
	end

	-- CRITICAL: Use Matter's deltaTime for frame-rate independence
	local Matter = require(Packages:FindFirstChild("Matter"))
	local dt = Matter.useDeltaTime()
	dt = math.clamp(dt, MovementConfig.MIN_DT, MovementConfig.MAX_DT)
	
	-- Use cached values (no function calls per frame)
	local groundY = _cachedGroundY
	local zombieDir = _cachedZombieDir

	-- Interpolate zombie positions
	for entityId, visual in _zombieVisuals do
		if not visual.Model.Parent then
			_zombieVisuals[entityId] = nil
			continue
		end

		-- Skip interpolation if zombie is vaulting (animation handles position)
		if visual.IsVaulting then
			continue
		end

		local currentPos = visual.Model:GetPivot().Position
		local currentX = currentPos.X
		local targetX = visual.TargetX
		local newX = currentX + (targetX - currentX) * math.min(1, INTERPOLATION_SPEED * dt)

		local z = getLaneZ(visual.Lane)
		local spawnY = groundY + visual.FeetOffset -- Add feet offset for ground alignment
		local newPos = Vector3.new(newX, spawnY, z)

		-- Update position with 90° rotation (reversed for hypnotized zombies)
		local facingDir = if visual.IsHypnotized then -zombieDir else zombieDir
		local facingCFrame = CFrame.lookAt(newPos, newPos + facingDir) * CFrame.Angles(0, math.pi / 2, 0)
		visual.Model:PivotTo(facingCFrame)
		
		-- FOG VISIBILITY: Hide zombies in fog zone unless illuminated
		local isVisible = true
		if FogController.IsFogActive() then
			local column, lane = MapConfig.WorldToGrid(newPos)
			if column and lane then
				isVisible = FogController.IsCellVisible(column, lane)
			end
		end
		
		-- Only update if visibility changed (optimization)
		if visual.LastFogVisible ~= isVisible then
			visual.LastFogVisible = isVisible
			
			-- Build part cache if not exists
			local cachedParts: { BasePart } = visual.CachedParts or {}
			if #cachedParts == 0 then
				for _, part in visual.Model:GetDescendants() do
					if part:IsA("BasePart") then
						table.insert(cachedParts, part)
					end
				end
				visual.CachedParts = cachedParts
			end
			
			-- Apply visibility using cached parts
			local modifier = if isVisible then 0 else 1
			for _, part in cachedParts do
				part.LocalTransparencyModifier = modifier
			end
		end
	end

	-- Random zombie groans for immersion
	local currentTime = os.clock()
	if currentTime >= _nextGroanTime then
		-- Schedule next groan check
		_nextGroanTime = currentTime + ChanceUtils.RandomFloat(GROAN_CONFIG.MIN_INTERVAL, GROAN_CONFIG.MAX_INTERVAL)

		-- Pick a random zombie to groan
		local zombieList = {}
		for entityId, visual in _zombieVisuals do
			if visual.Model.Parent then
				table.insert(zombieList, visual)
			end
		end

		if #zombieList > 0 and ChanceUtils.Roll(GROAN_CONFIG.CHANCE_PER_ZOMBIE) then
			local randomZombie = ChanceUtils.PickRandom(zombieList)
			if randomZombie then
				local pos = randomZombie.Model:GetPivot().Position
				AudioService.PlayZombieGroan(pos)
			end
		end
	end
end

return {
	priority = 410,
	system = ZombieRenderSystem,
}
