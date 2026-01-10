--!strict
--[[
	PlantRenderSystem.luau - Client-side plant visual rendering
	
	Priority: 405 (Render phase - before zombies)
	
	Receives plant spawn/death events from server via Zap.
	Creates visual plant representations using real models from Assets.
	Uses AnimationService for idle/spawn/death animations (no Humanoid).
	Falls back to colored cube if model not found.
	
	LIFECYCLE:
	- Init(): Setup network listeners (CAN yield)
	- system(): Static plants, no per-frame updates (CANNOT yield)
	- Dispose(): Disconnect events, cleanup visuals
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Packages
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages.Trove)

-- Use FindFirstChild to avoid yielding (modules should exist from init.client.luau)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "PlantRenderSystem: Shared folder not found")
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local PlantData = require(Shared.data.PlantData)
local GridUtils = require(Shared.utils.GridUtils)
local Logger = require(Shared.utils.Logger)
local GameSignals = require(Shared.signals.GameSignals)
local AttachmentUtils = require(Shared.utils.AttachmentUtils)

-- Client root (script.Parent.Parent.Parent since we're in systems/rendering/)
local Client = script.Parent.Parent.Parent
local Modules = Client:FindFirstChild("modules")
local Network = require(Shared.network.generated.client)

-- Assets folder (optional - fallback to cubes if missing)
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local PlantAssets = Assets and Assets:FindFirstChild("Plants")

if not PlantAssets then
	Logger.Warn("PlantRender", "Plant assets not found - using fallback cubes")
end

-- Services (lazy loaded - AnimService and VFXService needed for model-based operations)
local _animService: any = nil
local _vfxService: any = nil

local function getAnimService()
	if not _animService and Modules then
		local success, result = pcall(function()
			return require(Modules.AnimationService)
		end)
		if success then _animService = result end
	end
	return _animService
end

-- VFXService needed for AttachIdleVFX/DetachIdleVFX (requires Model reference)
local function getVFXService()
	if not _vfxService and Modules then
		local success, result = pcall(function()
			return require(Modules.VFXService)
		end)
		if success then _vfxService = result end
	end
	return _vfxService
end

-- Plant visual cache: entityId -> visual data
type PlantVisual = {
	Model: Model?,       -- Real model (if available)
	Part: Part?,         -- Fallback cube (if no model)
	PlantType: string,
	Column: number,
	Lane: number,
}
local _plantVisuals: {[number]: PlantVisual} = {}

-- Trove for cleanup (connections)
local _trove = Trove.new()

-- Fallback visual config (when model not found)
local FALLBACK_SIZE = Vector3.new(4, 4, 4)
local FALLBACK_COLORS = {
	Sunflower = Color3.fromRGB(255, 220, 50),
	Peashooter = Color3.fromRGB(100, 200, 100),
	WallNut = Color3.fromRGB(180, 130, 80),
	SnowPea = Color3.fromRGB(150, 200, 255),
	CherryBomb = Color3.fromRGB(255, 50, 50),
	PotatoMine = Color3.fromRGB(150, 100, 50),
	Repeater = Color3.fromRGB(60, 180, 60),
}

--[[
	Create plant visual from real model or fallback to cube
]]
local function createPlantVisual(entityId: number, plantType: string, column: number, lane: number): PlantVisual
	local worldPos = GridUtils.GridToWorld(column, lane)
	
	-- Try to get real model from Assets
	local modelTemplate = PlantAssets and PlantAssets:FindFirstChild(plantType)
	
	if modelTemplate and modelTemplate:IsA("Model") then
		-- Clone real model
		local model = modelTemplate:Clone()
		model.Name = `Plant_{entityId}_{plantType}`
		
		-- Position using PrimaryPart (Root)
		-- Model front = +Z, but lookAt points -Z toward target
		-- Add 180° rotation to flip so +Z faces the intended direction
		if model.PrimaryPart then
			local zombieDir = MapConfig.GetZombieDirection()
			-- Plants face toward zombie spawns (-zombieDir)
			local facingCFrame = CFrame.lookAt(worldPos, worldPos - zombieDir) * CFrame.fromEulerAnglesXYZ(0, -math.pi / 2, 0)
			model:PivotTo(facingCFrame)
		else
			Logger.Warn("PlantRender", `Model {plantType} has no PrimaryPart`)
		end
		
		-- Add entity tracking attributes
		model:SetAttribute("EntityId", entityId)
		
		model.Parent = Workspace
		
		-- Play spawn animation via AnimationService
		local animService = getAnimService()
		if animService then
			animService.PlaySpawn(model)
			-- Start idle animation
			animService.StartIdle(model)
		end
		
		-- Attach idle VFX if available
		local vfx = getVFXService()
		if vfx then vfx.AttachIdleVFX(model) end
		
		Logger.Debug("PlantRender", `Plant {entityId} ({plantType}) using real model`)
		
		return {
			Model = model,
			Part = nil,
			PlantType = plantType,
			Column = column,
			Lane = lane,
		}
	else
		-- Fallback: Create colored cube
		local part = Instance.new("Part")
		part.Name = `Plant_{entityId}_{plantType}`
		part.Size = FALLBACK_SIZE
		part.Color = FALLBACK_COLORS[plantType] or Color3.fromRGB(100, 200, 100)
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = true
		part.CastShadow = true
		
		part.Position = worldPos + Vector3.new(0, FALLBACK_SIZE.Y / 2, 0)
		part:SetAttribute("EntityId", entityId)
		part:SetAttribute("PlantType", plantType)
		
		-- Spawn animation (scale up)
		part.Size = Vector3.new(0.1, 0.1, 0.1)
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local tween = TweenService:Create(part, tweenInfo, { Size = FALLBACK_SIZE })
		
		part.Parent = Workspace
		tween:Play()
		
		Logger.Warn("PlantRender", `Plant {entityId} ({plantType}) using fallback cube - model not found`)
		
		return {
			Model = nil,
			Part = part,
			PlantType = plantType,
			Column = column,
			Lane = lane,
		}
	end
end

--[[
	Destroy plant visual and cleanup animations/VFX
]]
local function destroyPlantVisual(entityId: number)
	local visual = _plantVisuals[entityId]
	if visual then
		if visual.Model then
			visual.Model:Destroy()
		end
		if visual.Part then
			visual.Part:Destroy()
		end
		_plantVisuals[entityId] = nil
	end
end

--[[
	Setup network event listeners (called during Init phase)
]]
local function setupNetworkListeners()
	_trove:Add(Network.PlantSpawned.On(function(data)
		local entityId = data.EntityId
		local plantType = tostring(data.PlantType)
		local column = data.Column
		local lane = data.Lane
		
		if _plantVisuals[entityId] then
			Logger.Warn("PlantRender", `Plant {entityId} already exists`)
			return
		end
		
		_plantVisuals[entityId] = createPlantVisual(entityId, plantType, column, lane)
		
		-- Play placement VFX
		-- Use Center Attachment if model available, otherwise fallback to grid position
		local visual = _plantVisuals[entityId]
		local vfx = getVFXService()
		if vfx then
			if visual.Model then
				-- Model-aware: use Center Attachment (spatial contract)
				local vfxPos = AttachmentUtils.GetWorldPosition(visual.Model, AttachmentUtils.Names.Center, false)
				vfx.PlayPlantPlaced(vfxPos)
			else
				-- Fallback for cube: use grid center
				local worldPos = GridUtils.GridToWorld(column, lane)
				vfx.PlayPlantPlaced(worldPos)
			end
		end
		
		Logger.Debug("PlantRender", `Plant {entityId} ({plantType}) spawned at ({column}, {lane})`)
	end))

	_trove:Add(Network.EntityDied.On(function(data)
		local entityId = data.EntityId
		local visual = _plantVisuals[entityId]
		
		if visual then
			local animService = getAnimService()
			local vfx = getVFXService()
			
			-- Remove from tracking immediately to prevent double-processing
			_plantVisuals[entityId] = nil
			
			if visual.Model then
				-- Stop idle animation and VFX
				if animService then animService.StopIdle(visual.Model) end
				if vfx then vfx.DetachIdleVFX(visual.Model) end
				
				-- Get position for death VFX
				local pos = visual.Model.PrimaryPart and visual.Model.PrimaryPart.Position 
					or GridUtils.GridToWorld(visual.Column, visual.Lane)
				
				-- Play death VFX (model-aware)
				if vfx then vfx.PlayPlantDeath(visual.Model, pos) end
				
				-- Play death animation then destroy
				if animService then
					task.spawn(function()
						animService.PlayDeath(visual.Model)
						-- Destroy the model directly (visual already removed from tracking)
						if visual.Model then
							visual.Model:Destroy()
						end
					end)
				else
					-- No animation service, destroy immediately
					visual.Model:Destroy()
				end
			elseif visual.Part then
				-- Fallback cube death animation
				local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				local tween = TweenService:Create(visual.Part, tweenInfo, {
					Size = Vector3.new(0.1, 0.1, 0.1),
					Transparency = 1
				})
				
				tween:Play()
				tween.Completed:Connect(function()
					if visual.Part then
						visual.Part:Destroy()
					end
				end)
			end
			
			Logger.Debug("PlantRender", `Plant {entityId} died`)
		end
	end))

	-- Damage flash effect
	_trove:Add(Network.EntityDamaged.On(function(data)
		local visual = _plantVisuals[data.EntityId]
		if not visual then return end
		
		local vfx = getVFXService()
		
		if visual.Model then
			-- Flash all parts in the model
			local partsToFlash: {BasePart} = {}
			local originalColors: {Color3} = {}
			
			for _, part in visual.Model:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					table.insert(partsToFlash, part)
					table.insert(originalColors, part.Color)
					part.Color = Color3.fromRGB(255, 100, 100)
				end
			end
			
			task.delay(0.1, function()
				for i, part in partsToFlash do
					if part and part.Parent then
						part.Color = originalColors[i]
					end
				end
			end)
		elseif visual.Part then
			-- Flash fallback cube
			if vfx then
				vfx.FlashDamage(visual.Part)
			else
				local originalColor = visual.Part.Color
				visual.Part.Color = Color3.fromRGB(255, 100, 100)
				task.delay(0.1, function()
					if visual.Part and visual.Part.Parent then
						visual.Part.Color = originalColor
					end
				end)
			end
		end
	end))
end

--[[
	Get the visual Model/Part for an entity (used by other systems for VFX)
]]
local function getPlantVisual(entityId: number): (Model?, Part?)
	local visual = _plantVisuals[entityId]
	if visual then
		return visual.Model, visual.Part
	end
	return nil, nil
end

--[[
	Init - Setup network listeners (CAN yield)
]]
local function Init(_world)
	setupNetworkListeners()
	Logger.Debug("PlantRender", "Initialized")
end

--[[
	System - Static plants, no per-frame updates needed
]]
local function PlantRenderSystem(_world)
	-- All updates come via network events
end

--[[
	Dispose - Cleanup all visuals and connections
]]
local function Dispose()
	-- Trove handles all connection cleanup
	_trove:Destroy()
	_trove = Trove.new() -- Reset for potential reuse
	
	-- Destroy all plant visuals
	for entityId in _plantVisuals do
		destroyPlantVisual(entityId)
	end
	
	Logger.Debug("PlantRender", "Disposed")
end

return {
	_name = "PlantRenderSystem",
	priority = 405,
	system = PlantRenderSystem,
	Init = Init,
	Dispose = Dispose,
	getPlantVisual = getPlantVisual,
}
