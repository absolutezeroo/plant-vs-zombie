--!strict
--[[
	PlantRenderSystem.luau - Client-side plant visual rendering
	
	Priority: 405 (Render phase - before zombies)
	
	Receives plant spawn/death events from server via Zap.
	Creates visual plant representations.
	Uses simple Part-based visuals for MVP (no Humanoid).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)
local PlantData = require(Shared.data.PlantData)
local GridUtils = require(Shared.utils.GridUtils)
local Logger = require(Shared.utils.Logger)

local Client = script.Parent.Parent
local Network = require(Client.network.generated)

-- Plant visual cache: entityId -> visual data
type PlantVisual = {
	Part: Part,
	PlantType: string,
	Column: number,
	Lane: number,
}
local _plantVisuals: {[number]: PlantVisual} = {}

-- Visual config
local PLANT_SIZE = Vector3.new(4, 4, 4)
local PLANT_COLORS = {
	Sunflower = Color3.fromRGB(255, 220, 50),    -- Yellow
	Peashooter = Color3.fromRGB(100, 200, 100),  -- Green
	WallNut = Color3.fromRGB(180, 130, 80),      -- Brown
	SnowPea = Color3.fromRGB(150, 200, 255),     -- Light blue
	CherryBomb = Color3.fromRGB(255, 50, 50),    -- Red
	PotatoMine = Color3.fromRGB(150, 100, 50),   -- Brown-ish
}

local function createPlantVisual(entityId: number, plantType: string, column: number, lane: number): PlantVisual
	local part = Instance.new("Part")
	part.Name = `Plant_{entityId}_{plantType}`
	part.Size = PLANT_SIZE
	part.Color = PLANT_COLORS[plantType] or Color3.fromRGB(100, 200, 100)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
	
	-- Position at grid cell center
	local worldPos = GridUtils.GridToWorld(column, lane)
	part.Position = worldPos + Vector3.new(0, PLANT_SIZE.Y / 2, 0)
	
	-- Add attribute for entity tracking
	part:SetAttribute("EntityId", entityId)
	part:SetAttribute("PlantType", plantType)
	
	-- Spawn animation
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(part, tweenInfo, {
		Size = PLANT_SIZE
	})
	
	part.Parent = Workspace
	tween:Play()
	
	return {
		Part = part,
		PlantType = plantType,
		Column = column,
		Lane = lane,
	}
end

local function destroyPlantVisual(entityId: number)
	local visual = _plantVisuals[entityId]
	if visual then
		visual.Part:Destroy()
		_plantVisuals[entityId] = nil
	end
end

-- Network event handlers
Network.PlantSpawned.On(function(data)
	local entityId = data.EntityId
	local plantType = tostring(data.PlantType)
	local column = data.Column
	local lane = data.Lane
	
	if _plantVisuals[entityId] then
		Logger.Warn("PlantRender", `Plant {entityId} already exists`)
		return
	end
	
	_plantVisuals[entityId] = createPlantVisual(entityId, plantType, column, lane)
	Logger.Debug("PlantRender", `Plant {entityId} ({plantType}) spawned at ({column}, {lane})`)
end)

Network.EntityDied.On(function(data)
	local entityId = data.EntityId
	local visual = _plantVisuals[entityId]
	
	if visual then
		-- Death animation
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		local tween = TweenService:Create(visual.Part, tweenInfo, {
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1
		})
		
		tween:Play()
		tween.Completed:Connect(function()
			destroyPlantVisual(entityId)
		end)
		
		-- Remove from tracking immediately
		_plantVisuals[entityId] = nil
		
		Logger.Debug("PlantRender", `Plant {entityId} died`)
	end
end)

-- Damage flash effect
Network.EntityDamaged.On(function(data)
	local visual = _plantVisuals[data.EntityId]
	if visual then
		-- Flash red briefly
		local originalColor = visual.Part.Color
		visual.Part.Color = Color3.fromRGB(255, 100, 100)
		
		task.delay(0.1, function()
			if visual.Part and visual.Part.Parent then
				visual.Part.Color = originalColor
			end
		end)
	end
end)

local function PlantRenderSystem(world)
	-- Plants are static, no per-frame updates needed
	-- All updates come via network events
end

return {
	system = PlantRenderSystem,
	priority = 405,
}
