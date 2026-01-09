--!strict
--[[
	ZombieRenderSystem.luau - Client-side zombie visual rendering
	
	Priority: 410 (Render phase - after sun)
	
	Receives zombie spawn/position events from server via Zap.
	Creates and updates visual zombie representations.
	Uses simple Part-based visuals for MVP (no Humanoid).
	
	LIFECYCLE:
	- Init(): Setup network listeners (CAN yield)
	- system(): Interpolate zombie positions (CANNOT yield)
	- Dispose(): Disconnect events, cleanup visuals
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

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

-- Client root (script.Parent.Parent.Parent since we're in systems/rendering/)
local Client = script.Parent.Parent.Parent
local Network = require(Shared.network.generated.client)

-- Zombie visual cache: entityId -> visual data
type ZombieVisual = {
	Part: Part,
	ZombieType: string,
	Lane: number,
	TargetX: number,
}
local _zombieVisuals: {[number]: ZombieVisual} = {}

-- Trove for cleanup
local _trove = Trove.new()

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
	-- Return default if not initialized (will be corrected when initialized)
	if not MapConfig.IsInitialized() then
		return lane * 4 -- Rough estimate
	end
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
	-- Use default Y if MapConfig not ready
	local groundY = if MapConfig.IsInitialized() then MapConfig.GetConfig().GridY else 0
	part.Position = Vector3.new(positionX, groundY + ZOMBIE_SIZE.Y / 2, z)
	
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
			
			-- Keep reference to part for animation
			local part = visual.Part
			
			-- Fire signal for VFX/Audio (decoupled)
			local pos = part.Position
			GameSignals.OnZombieDeath:Fire({
				Position = pos,
				ZombieType = visual.ZombieType,
			})
			
			-- Death animation
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(part, tweenInfo, {
				Size = Vector3.new(ZOMBIE_SIZE.X, 0.5, ZOMBIE_SIZE.Z),
				Position = part.Position - Vector3.new(0, ZOMBIE_SIZE.Y / 2 - 0.25, 0),
				Transparency = 1
			})
			
			tween:Play()
			tween.Completed:Connect(function()
				-- Destroy the part directly since it's no longer in _zombieVisuals
				if part and part.Parent then
					part:Destroy()
				end
			end)
			
			Logger.Debug("ZombieRender", `Zombie {entityId} died`)
		end
	end))
	
	-- Show floating damage numbers
	_trove:Add(Network.EntityDamaged.On(function(data)
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
			
			-- Show floating damage number via signal
			if data.DamageAmount > 0 then
				local pos = visual.Part.Position + Vector3.new(
					(math.random() - 0.5) * 2, -- Random X offset
					1, -- Above zombie
					0
				)
				GameSignals.OnDamageDealt:Fire({
					Position = pos,
					Amount = data.DamageAmount,
				})
			end
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

--[[
	System - Interpolate zombie positions (CANNOT yield)
]]
local function ZombieRenderSystem(_world)
	-- Skip if MapConfig not initialized yet (Studio mode)
	if not MapConfig.IsInitialized() then
		return
	end
	
	local dt = 1/60
	local groundY = MapConfig.GetConfig().GridY
	
	-- Interpolate zombie positions
	for entityId, visual in _zombieVisuals do
		-- Skip if part was destroyed
		if not visual.Part or not visual.Part.Parent then
			_zombieVisuals[entityId] = nil
			continue
		end
		
		local currentX = visual.Part.Position.X
		local targetX = visual.TargetX
		
		-- Smooth interpolation
		local newX = currentX + (targetX - currentX) * math.min(1, INTERPOLATION_SPEED * dt)
		
		local z = getLaneZ(visual.Lane)
		visual.Part.Position = Vector3.new(newX, groundY + ZOMBIE_SIZE.Y / 2, z)
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
