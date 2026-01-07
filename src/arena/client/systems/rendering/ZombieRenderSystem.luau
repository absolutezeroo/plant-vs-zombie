--!strict
--[[
	ZombieRenderSystem.luau - Client-side zombie visual rendering
	
	Priority: 410 (Render phase - after sun)
	
	Receives zombie spawn/position events from server via Zap.
	Creates and updates visual zombie representations.
	Uses simple Part-based visuals for MVP (no Humanoid).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local ZombieData = require(Shared.data.ZombieData)
local Logger = require(Shared.utils.Logger)

-- Client root (script.Parent.Parent.Parent since we're in systems/rendering/)
local Client = script.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local UI = Client:WaitForChild("ui")
local Network = require(Client.network.generated)

-- VFX/Audio services (lazy loaded)
local _vfxService: any = nil
local _audioService: any = nil
local _floatingTextUI: any = nil

local function getVFXService()
	if not _vfxService then
		local success, result = pcall(function()
			return require(Modules.VFXService)
		end)
		if success then
			_vfxService = result
		end
	end
	return _vfxService
end

local function getAudioService()
	if not _audioService then
		local success, result = pcall(function()
			return require(Modules.AudioService)
		end)
		if success then
			_audioService = result
		end
	end
	return _audioService
end

local function getFloatingTextUI()
	if not _floatingTextUI then
		local success, result = pcall(function()
			return require(UI.FloatingTextUI)
		end)
		if success then
			_floatingTextUI = result
		end
	end
	return _floatingTextUI
end

-- Zombie visual cache: entityId -> visual data
type ZombieVisual = {
	Part: Part,
	ZombieType: string,
	Lane: number,
	TargetX: number,
}
local _zombieVisuals: {[number]: ZombieVisual} = {}

-- Visual config
local ZOMBIE_SIZE = Vector3.new(3, 5, 3)
local ZOMBIE_COLORS = {
	Basic = Color3.fromRGB(100, 150, 100),    -- Green-ish
	Cone = Color3.fromRGB(255, 150, 50),      -- Orange cone
	Bucket = Color3.fromRGB(150, 150, 150),   -- Gray bucket
	Pole = Color3.fromRGB(100, 100, 200),     -- Blue-ish
	Newspaper = Color3.fromRGB(200, 200, 150),-- Tan
	Football = Color3.fromRGB(50, 50, 50),    -- Dark
}
local INTERPOLATION_SPEED = 10 -- How fast to interpolate to target position

local function getLaneZ(lane: number): number
	local laneCenter = MapConfig.GridToWorld(1, lane)
	return laneCenter.Z
end

local function createZombieVisual(entityId: number, zombieType: string, lane: number, positionX: number): ZombieVisual
	local part = Instance.new("Part")
	part.Name = `Zombie_{entityId}`
	part.Size = ZOMBIE_SIZE
	part.Color = ZOMBIE_COLORS[zombieType] or ZOMBIE_COLORS.Basic
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
	
	local z = getLaneZ(lane)
	part.Position = Vector3.new(positionX, ZOMBIE_SIZE.Y / 2, z)
	
	-- Add attribute for entity tracking
	part:SetAttribute("EntityId", entityId)
	part:SetAttribute("ZombieType", zombieType)
	
	-- Add face decal (simple eyes)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Left -- Facing left towards house
	face.Color3 = Color3.new(1, 1, 1)
	face.Transparency = 0.5
	face.Parent = part
	
	part.Parent = Workspace
	
	return {
		Part = part,
		ZombieType = zombieType,
		Lane = lane,
		TargetX = positionX,
	}
end

local function destroyZombieVisual(entityId: number)
	local visual = _zombieVisuals[entityId]
	if visual then
		visual.Part:Destroy()
		_zombieVisuals[entityId] = nil
	end
end

-- Network event handlers
Network.ZombieSpawned.On(function(data)
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
end)

Network.ZombiePositionBatch.On(function(data)
	local entityIds = data.EntityIds
	local positionsX = data.PositionsX
	
	for i, entityId in entityIds do
		local visual = _zombieVisuals[entityId]
		if visual then
			visual.TargetX = positionsX[i]
		end
	end
end)

Network.EntityDied.On(function(data)
	local entityId = data.EntityId
	local visual = _zombieVisuals[entityId]
	
	if visual then
		-- Play death VFX and audio
		local pos = visual.Part.Position
		local vfx = getVFXService()
		local audio = getAudioService()
		if vfx then vfx.PlayZombieDeath(pos) end
		if audio then audio.PlayZombieDeath(pos) end
		
		-- Death animation
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(visual.Part, tweenInfo, {
			Size = Vector3.new(ZOMBIE_SIZE.X, 0.5, ZOMBIE_SIZE.Z),
			Position = visual.Part.Position - Vector3.new(0, ZOMBIE_SIZE.Y / 2 - 0.25, 0),
			Transparency = 1
		})
		
		tween:Play()
		tween.Completed:Connect(function()
			destroyZombieVisual(entityId)
		end)
		
		-- Remove from active tracking immediately
		_zombieVisuals[entityId] = nil
		
		Logger.Debug("ZombieRender", `Zombie {entityId} died`)
	end
end)

-- Show floating damage numbers
Network.EntityDamaged.On(function(data)
	local visual = _zombieVisuals[data.EntityId]
	if visual then
		-- Flash red
		local originalColor = visual.Part.Color
		visual.Part.Color = Color3.fromRGB(255, 100, 100)
		task.delay(0.1, function()
			if visual.Part and visual.Part.Parent then
				visual.Part.Color = originalColor
			end
		end)
		
		-- Show floating damage number
		local floatingText = getFloatingTextUI()
		if floatingText and data.DamageAmount > 0 then
			local pos = visual.Part.Position + Vector3.new(
				(math.random() - 0.5) * 2, -- Random X offset
				1, -- Above zombie
				0
			)
			floatingText.ShowDamage(pos, data.DamageAmount)
		end
	end
end)

local function ZombieRenderSystem(world)
	local dt = 1/60
	
	-- Interpolate zombie positions
	for entityId, visual in _zombieVisuals do
		local currentX = visual.Part.Position.X
		local targetX = visual.TargetX
		
		-- Smooth interpolation
		local newX = currentX + (targetX - currentX) * math.min(1, INTERPOLATION_SPEED * dt)
		
		local z = getLaneZ(visual.Lane)
		visual.Part.Position = Vector3.new(newX, ZOMBIE_SIZE.Y / 2, z)
	end
end

return {
	system = ZombieRenderSystem,
	priority = 410, -- Render phase, after sun
}
