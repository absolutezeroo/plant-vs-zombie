--!strict
--[[
	ProjectileRenderSystem.luau - Client-side projectile rendering
	
	Priority: 420 (Render phase - after zombies)
	
	Receives projectile spawn events from server via Zap.
	Creates visual projectiles with movement, trails and VFX.
	
	ASSET-BASED APPROACH:
	Projectile visuals come from ReplicatedStorage/Assets/Projectiles/
	Each projectile type is a Model with:
	- Root (Part) - PrimaryPart, the actual projectile visual
	- Trail (Trail) - Optional trail effect
	- Particles (ParticleEmitter) - Optional particle effects
	
	MUZZLE FLASH:
	When projectile spawns, checks source plant's VFX/Shoot for muzzle flash.
	
	V3 Architecture: Matter Hooks pattern
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Use FindFirstChild to avoid yielding (modules should exist from init.client.luau)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "ProjectileRenderSystem: Shared folder not found")

local Packages = ReplicatedStorage:FindFirstChild("Packages")
assert(Packages, "ProjectileRenderSystem: Packages folder not found")
local Trove = require(Packages:WaitForChild("Trove"))
local Hooks = require(Packages.MatterHooks)
local Matter = require(Packages.Matter)

local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local AttachmentUtils = require(Shared.utils.grid.AttachmentUtils)
local Logger = require(Shared.utils.core.Logger)
local GameSignals = require(Shared.signals.GameSignals)
local VFXUtils = require(Shared.utils.vfx.VFXUtils)

-- Client root (script.Parent.Parent.Parent since we're in systems/rendering/)
local Client = script.Parent.Parent.Parent
local Modules = Client:FindFirstChild("modules")
local Network = require(Shared.network.generated.client)
local AudioService = require(Modules.AudioService)

-- Assets folder
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local ProjectileAssets = Assets and Assets:FindFirstChild("Projectiles")

if not ProjectileAssets then
	Logger.Warn("ProjectileRender", "Assets/Projectiles not found - will use fallback visuals")
end

-- Projectile visual cache
type ProjectileVisual = {
	Model: Model?, -- Cloned asset model (if available)
	Part: Part?, -- Fallback part (if no asset)
	Lane: number,
	Speed: number,
	Variant: string,
	IsFrozen: boolean,
	IsEnhanced: boolean,
	DirectionX: number, -- Direction vector X (-1 or 1)
	DirectionZ: number, -- Direction vector Z (usually 0)
}
local _projectileVisuals: { [number]: ProjectileVisual } = {}

-- Trove for cleanup
local _trove = Trove.new()

-- Fallback config (used when asset not found)
type FallbackConfig = {
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	Shape: Enum.PartType,
	Speed: number,
}

local FALLBACK_CONFIGS: { [string]: FallbackConfig } = {
	Pea = {
		Size = Vector3.new(1, 1, 1),
		Color = Color3.fromRGB(100, 200, 100),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Speed = 15,
	},
	FrozenPea = {
		Size = Vector3.new(1, 1, 1),
		Color = Color3.fromRGB(150, 220, 255),
		Material = Enum.Material.Ice,
		Shape = Enum.PartType.Ball,
		Speed = 15,
	},
	FirePea = {
		Size = Vector3.new(1.2, 1.2, 1.2),
		Color = Color3.fromRGB(255, 150, 50),
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		Speed = 18,
	},
	Spore = {
		Size = Vector3.new(0.6, 0.6, 0.6),
		Color = Color3.fromRGB(180, 150, 200),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Speed = 12,
	},
	Fume = {
		Size = Vector3.new(1.5, 1.5, 1.5),
		Color = Color3.fromRGB(150, 50, 180),
		Material = Enum.Material.ForceField,
		Shape = Enum.PartType.Ball,
		Speed = 20,
	},
	Cabbage = {
		Size = Vector3.new(1.5, 1.2, 1.5),
		Color = Color3.fromRGB(100, 180, 80),
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Ball,
		Speed = 10,
	},
	Kernel = {
		Size = Vector3.new(0.8, 1, 0.8),
		Color = Color3.fromRGB(255, 220, 100),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Speed = 10,
	},
	Butter = {
		Size = Vector3.new(1.2, 0.6, 1.2),
		Color = Color3.fromRGB(255, 230, 100),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Block,
		Speed = 10,
	},
	Melon = {
		Size = Vector3.new(2, 1.5, 2),
		Color = Color3.fromRGB(100, 200, 100),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Speed = 8,
	},
	Star = {
		Size = Vector3.new(0.8, 0.8, 0.2),
		Color = Color3.fromRGB(255, 255, 100),
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Block,
		Speed = 18,
	},
	Spike = {
		Size = Vector3.new(0.4, 0.4, 1.5),
		Color = Color3.fromRGB(80, 120, 80),
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Block,
		Speed = 25,
	},
	Seed = {
		Size = Vector3.new(0.5, 0.5, 0.5),
		Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.Wood,
		Shape = Enum.PartType.Ball,
		Speed = 12,
	},
}

local DEFAULT_FALLBACK: FallbackConfig = FALLBACK_CONFIGS.Pea

local function getLaneZ(lane: number): number
	local laneCenter = MapConfig.GridToWorld(1, lane)
	return laneCenter.Z
end

--[[
	Find source plant model to get Muzzle Attachment position + trigger muzzle flash VFX
	RULE: Never use hardcoded Vector3 offsets
]]
local function findPlantModelInLane(lane: number, nearX: number): Model?
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and child.Name:find("Plant_") then
			local root = child.PrimaryPart
			if root then
				local expectedZ = getLaneZ(lane)
				if math.abs(root.Position.Z - expectedZ) < 3 then
					if math.abs(root.Position.X - nearX) < 5 then
						return child
					end
				end
			end
		end
	end
	return nil
end

--[[
	Play muzzle flash VFX from plant's VFX/Shoot folder
]]
local function playMuzzleFlash(plantModel: Model, spawnPos: Vector3)
	local vfxFolder = plantModel:FindFirstChild("VFX")
	local shootVFX = vfxFolder and vfxFolder:FindFirstChild("Shoot")

	if shootVFX and shootVFX:IsA("ParticleEmitter") then
		-- Use VFXUtils to clone, emit, and cleanup
		VFXUtils.CloneAndEmit(shootVFX, spawnPos)
		Logger.Debug("ProjectileRender", "Played muzzle flash VFX")
	end

	-- Fire signal for audio (decoupled)
	GameSignals.OnPlantShoot:Fire({
		Position = spawnPos,
		PlantType = plantModel:GetAttribute("PlantType") or "Unknown",
	})
end

--[[
	Create projectile visual from asset or fallback
	Priority: 1) Assets/Projectiles/{Variant} 2) Fallback Part
]]
local function createProjectileVisual(
	entityId: number,
	lane: number,
	startX: number,
	variant: string?,
	isFrozen: boolean?,
	isEnhanced: boolean?,
	directionX: number?,
	directionZ: number?
): ProjectileVisual
	local actualVariant = variant or "Pea"
	local actualFrozen = isFrozen or false
	local actualEnhanced = isEnhanced or false

	-- Override variant if enhanced (Torchwood)
	if actualEnhanced and actualVariant == "Pea" then
		actualVariant = "FirePea"
	end

	-- Use provided direction or calculate forward direction (opposite of zombie direction)
	local forwardDirX: number
	local forwardDirZ: number
	if directionX ~= nil and directionZ ~= nil then
		forwardDirX = directionX
		forwardDirZ = directionZ
	else
		local zombieDir = MapConfig.GetZombieDirection()
		forwardDirX = -zombieDir.X
		forwardDirZ = -zombieDir.Z
	end

	-- Get spawn position
	local z = getLaneZ(lane)
	local spawnPos = Vector3.new(startX, 2.5, z)

	-- Try to find source plant for muzzle position + VFX
	local plantModel = findPlantModelInLane(lane, startX - 2)
	if plantModel then
		local muzzlePos = AttachmentUtils.GetWorldPosition(plantModel, AttachmentUtils.Names.Muzzle, false)
		spawnPos = muzzlePos

		-- Play muzzle flash from plant's VFX folder
		playMuzzleFlash(plantModel, spawnPos)
	end

	-- Try to clone asset from Assets/Projectiles/{Variant}
	local assetTemplate = ProjectileAssets and ProjectileAssets:FindFirstChild(actualVariant)

	if assetTemplate and assetTemplate:IsA("Model") then
		-- Clone asset model
		local model = assetTemplate:Clone()
		model.Name = `Projectile_{entityId}_{actualVariant}`

		if model.PrimaryPart then
			model:PivotTo(CFrame.new(spawnPos))
		end

		model:SetAttribute("EntityId", entityId)
		model.Parent = Workspace

		-- Get speed from asset attribute or fallback config
		local config = FALLBACK_CONFIGS[actualVariant] or DEFAULT_FALLBACK
		local speed = model:GetAttribute("Speed") or config.Speed

		Logger.Debug("ProjectileRender", `{actualVariant} {entityId} using asset model`)

		return {
			Model = model,
			Part = nil,
			Lane = lane,
			Speed = speed,
			Variant = actualVariant,
			IsFrozen = actualFrozen,
			IsEnhanced = actualEnhanced,
			DirectionX = forwardDirX,
			DirectionZ = forwardDirZ,
		}
	end

	-- Fallback: Create simple Part
	local config = FALLBACK_CONFIGS[actualVariant] or DEFAULT_FALLBACK

	local part = Instance.new("Part")
	part.Name = `Projectile_{entityId}_{actualVariant}`
	part.Shape = config.Shape
	part.Size = config.Size
	part.Color = config.Color
	part.Material = config.Material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Position = spawnPos
	part:SetAttribute("EntityId", entityId)
	part.Parent = Workspace

	Logger.Debug("ProjectileRender", `{actualVariant} {entityId} using fallback Part (no asset found)`)

	return {
		Model = nil,
		Part = part,
		Lane = lane,
		Speed = config.Speed,
		Variant = actualVariant,
		IsFrozen = actualFrozen,
		IsEnhanced = actualEnhanced,
		DirectionX = forwardDirX,
		DirectionZ = forwardDirZ,
	}
end

--[[
	Get the main Part from a projectile visual (for positioning/effects)
]]
local function getVisualPart(visual: ProjectileVisual): Part?
	if visual.Model and visual.Model.PrimaryPart then
		return visual.Model.PrimaryPart :: Part
	end
	return visual.Part
end

local function destroyProjectileVisual(entityId: number)
	local visual = _projectileVisuals[entityId]
	if visual then
		if visual.Model then
			visual.Model:Destroy()
		elseif visual.Part then
			visual.Part:Destroy()
		end
		_projectileVisuals[entityId] = nil
	end
end

--[[
	Setup network event listeners (called during Init phase)
]]
local function setupNetworkListeners()
	_trove:Add(Network.ProjectileSpawned.On(function(data)
		local entityId = data.EntityId
		local lane = data.Lane
		local startX = data.StartX
		local variant = if data.Variant then tostring(data.Variant) else "Pea"
		local isFrozen = data.IsFrozen or false
		local isEnhanced = data.IsEnhanced or false

		if not _projectileVisuals[entityId] then
			_projectileVisuals[entityId] = createProjectileVisual(
				entityId,
				lane,
				startX,
				variant,
				isFrozen,
				isEnhanced,
				data.DirectionX,
				data.DirectionZ
			)

			-- Play shoot sound based on variant
			local groundY = if MapConfig.IsInitialized() then MapConfig.GetConfig().GridY else 0
			local z = if MapConfig.IsInitialized() then MapConfig.GridToWorld(1, lane).Z else lane * 4
			local shootPos = Vector3.new(startX, groundY + 2, z)
			AudioService.PlayProjectileShoot(variant, shootPos)

			Logger.Debug("ProjectileRender", `{variant} {entityId} spawned in lane {lane}`)
		end
	end))

	-- Projectile hit a target - play impact VFX
	_trove:Add(Network.ProjectileHit.On(function(data)
		local visual = _projectileVisuals[data.EntityId]
		if visual then
			local part = getVisualPart(visual)

			-- CRITICAL: Teleport visual to impact position (sync with server)
			local impactPos = Vector3.new(data.PositionX, data.PositionY, data.PositionZ)
			if part then
				if visual.Model then
					visual.Model:PivotTo(CFrame.new(impactPos))
				else
					part.Position = impactPos
				end
			end

			local pos = impactPos

			-- Fire signal for VFX/Audio (decoupled)
			GameSignals.OnProjectileImpact:Fire({
				Position = pos,
				ProjectileType = visual.Variant,
				IsFrozen = visual.IsFrozen or data.IsFrozen,
				IsEnhanced = visual.IsEnhanced or data.IsEnhanced,
			})

			-- Hit animation (quick scale down) - immediate destroy to avoid traversal
			if part then
				local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Quad)
				local tween = TweenService:Create(part, tweenInfo, {
					Size = Vector3.new(0.1, 0.1, 0.1),
					Transparency = 1,
				})
				tween:Play()
				tween.Completed:Connect(function()
					destroyProjectileVisual(data.EntityId)
				end)
			else
				destroyProjectileVisual(data.EntityId)
			end
		end
		_projectileVisuals[data.EntityId] = nil
	end))

	-- Projectile despawned without hitting - just remove (no VFX)
	_trove:Add(Network.ProjectileDespawned.On(function(data)
		destroyProjectileVisual(data.EntityId)
	end))

	-- Projectile enhanced by Torchwood (pea -> fire pea)
	_trove:Add(Network.ProjectileEnhanced.On(function(data)
		local entityId = data.EntityId
		local visual = _projectileVisuals[entityId]
		if not visual then
			return
		end

		local enhancementType = data.EnhancementType

		if enhancementType == "fire" then
			-- Update visual state
			visual.IsEnhanced = true
			visual.Variant = "FirePea"

			-- Change visual appearance
			local part = getVisualPart(visual)
			if part then
				local pos = part.Position

				-- Get FirePea config
				local fireConfig = FALLBACK_CONFIGS.FirePea or DEFAULT_FALLBACK

				-- Apply fire appearance to fallback part
				if visual.Part then
					visual.Part.Color = fireConfig.Color
					visual.Part.Material = fireConfig.Material
					visual.Part.Size = fireConfig.Size
				end

				-- If using model, swap to FirePea model
				if visual.Model then
					local fireTemplate = ProjectileAssets and ProjectileAssets:FindFirstChild("FirePea")
					if fireTemplate and fireTemplate:IsA("Model") then
						-- Destroy old model
						local oldModel = visual.Model
						local oldCFrame = oldModel:GetPivot()

						-- Create new fire model
						local newModel = fireTemplate:Clone()
						newModel.Name = `Projectile_{entityId}_FirePea`
						newModel:PivotTo(oldCFrame)
						newModel:SetAttribute("EntityId", entityId)
						newModel.Parent = Workspace

						visual.Model = newModel
						oldModel:Destroy()
					end
				end

				-- Play fire ignition VFX at projectile position
				local vfxAssets = ReplicatedStorage:FindFirstChild("Assets")
				local vfxFolder = vfxAssets and vfxAssets:FindFirstChild("VFX")
				local fireVFX = vfxFolder and vfxFolder:FindFirstChild("FireIgnite")
				if fireVFX and fireVFX:IsA("ParticleEmitter") then
					VFXUtils.CloneAndEmit(fireVFX, pos)
				end

				Logger.Debug("ProjectileRender", `Projectile {entityId} enhanced to FirePea at {pos}`)
			end
		end
	end))
end

--[[
	Init - Setup network listeners (via useMemo)
]]
-- setupNetworkListeners is called within system via useMemo

-- Movement config
local MovementConfig = {
	MIN_DT = 1 / 120, -- Minimum deltaTime
	MAX_DT = 1 / 15, -- Maximum deltaTime
}

--[[
	System - Initialize on first run and move projectiles each frame
]]
local function ProjectileRenderSystem(_world)
	-- One-time initialization via hooks
	Hooks.useMemo(function()
		setupNetworkListeners()
		Logger.Debug("ProjectileRender", "Initialized")
		return true
	end, {})

	-- CRITICAL: Use Matter's deltaTime for frame-rate independence
	local dt = Matter.useDeltaTime()
	dt = math.clamp(dt, MovementConfig.MIN_DT, MovementConfig.MAX_DT)

	-- Move projectiles and check client-side collision for responsive visuals
	for entityId, visual in _projectileVisuals do
		local part = getVisualPart(visual)
		if not part then
			destroyProjectileVisual(entityId)
			continue
		end

		local currentX = part.Position.X
		local currentZ = part.Position.Z
		local newX = currentX + visual.Speed * visual.DirectionX * dt
		local newZ = currentZ + visual.Speed * visual.DirectionZ * dt

		-- Check if off-screen (past grid bounds)
		local mapConfig = MapConfig.GetConfig()
		local minX = mapConfig.GridCornerA.X - 50
		local maxX = mapConfig.GridCornerB.X + 50
		if newX < minX or newX > maxX then
			destroyProjectileVisual(entityId)
			continue
		end

		-- CLIENT-SIDE COLLISION: Check if projectile visually hits any zombie
		-- This makes impacts feel instant without waiting for server
		local hitZombie = false
		local hitPosition = Vector3.new(newX, part.Position.Y, newZ)

		-- Look for zombie models in workspace (tagged with Zombie_ prefix)
		for _, child in Workspace:GetChildren() do
			if child:IsA("Model") and child.Name:find("Zombie_") then
				local zombieRoot = child.PrimaryPart
				if zombieRoot then
					-- Check if same lane (Z position) and close enough on X
					local zombieZ = zombieRoot.Position.Z
					local zombieX = zombieRoot.Position.X
					local laneMatch = math.abs(zombieZ - newZ) < 3 -- Same lane tolerance
					local xDistance = math.abs(newX - zombieX)

					if laneMatch and xDistance < 2.5 then
						hitZombie = true
						hitPosition = Vector3.new(zombieX, part.Position.Y, zombieZ)
						break
					end
				end
			end
		end

		if hitZombie then
			-- Fire impact signal for VFX/Audio immediately
			GameSignals.OnProjectileImpact:Fire({
				Position = hitPosition,
				ProjectileType = visual.Variant,
				IsFrozen = visual.IsFrozen,
				IsEnhanced = visual.IsEnhanced,
			})

			-- Destroy visual immediately (server will confirm damage)
			destroyProjectileVisual(entityId)
		else
			-- Move model or part
			if visual.Model then
				visual.Model:PivotTo(CFrame.new(newX, part.Position.Y, newZ))
			else
				part.Position = Vector3.new(newX, part.Position.Y, newZ)
			end
		end
	end
end

return {
	priority = 420,
	system = ProjectileRenderSystem,
}
