--!strict
--[[
	ProjectileRenderSystem.luau - Client-side projectile rendering
	
	Priority: 420 (Render phase - after zombies)
	
	Receives projectile spawn events from server via Zap.
	Creates visual pea projectiles with movement.
	
	Attachment-based positioning:
	- If a source plant visual exists, spawns projectile at "Muzzle" Attachment
	- This respects the "spatial contract" between Artists and Code
	- Fallback to server-provided StartX if no model/attachment found
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GridConfig = require(Shared.config.GridConfig)
local AttachmentUtils = require(Shared.utils.AttachmentUtils)
local Logger = require(Shared.utils.Logger)

-- Client root (script.Parent.Parent.Parent since we're in systems/rendering/)
local Client = script.Parent.Parent.Parent
local Modules = Client:WaitForChild("modules")
local Network = require(Client.network.generated)

-- VFX/Audio services (lazy loaded)
local _vfxService: any = nil
local _audioService: any = nil

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

-- Projectile visual cache
type ProjectileVisual = {
	Part: Part,
	Lane: number,
	Speed: number,
}
local _projectileVisuals: {[number]: ProjectileVisual} = {}

-- Visual config
local PEA_SIZE = Vector3.new(1, 1, 1)
local PEA_COLOR = Color3.fromRGB(100, 200, 100) -- Green pea
local PEA_SPEED = 15 -- Match server

local function getLaneZ(lane: number): number
	return (lane - 1) * GridConfig.CELL_SIZE + GridConfig.CELL_SIZE / 2 + GridConfig.GRID_ORIGIN_Z
end

--[[
	Find source plant model to get Muzzle Attachment position
	RULE: Never use hardcoded Vector3 offsets
]]
local function findPlantModelInLane(lane: number, nearX: number): Model?
	-- Look for plant visuals in workspace
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and child.Name:find("Plant_") then
			local root = child.PrimaryPart
			if root then
				-- Check if in same lane (approximately same Z)
				local expectedZ = getLaneZ(lane)
				if math.abs(root.Position.Z - expectedZ) < 3 then
					-- Check if close to startX
					if math.abs(root.Position.X - nearX) < 5 then
						return child
					end
				end
			end
		end
	end
	return nil
end

local function createProjectileVisual(entityId: number, lane: number, startX: number): ProjectileVisual
	local part = Instance.new("Part")
	part.Name = `Pea_{entityId}`
	part.Shape = Enum.PartType.Ball
	part.Size = PEA_SIZE
	part.Color = PEA_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	
	-- Try to find source plant and use its Muzzle Attachment
	local z = getLaneZ(lane)
	local spawnPos = Vector3.new(startX, 2.5, z) -- Default fallback
	
	local plantModel = findPlantModelInLane(lane, startX - 2) -- startX is already offset
	if plantModel then
		-- Use Muzzle Attachment position (the spatial contract!)
		local muzzlePos = AttachmentUtils.GetWorldPosition(plantModel, AttachmentUtils.Names.Muzzle, false)
		spawnPos = muzzlePos
		Logger.Debug("ProjectileRender", `Pea {entityId} spawning from Muzzle attachment`)
	end
	
	part.Position = spawnPos
	part:SetAttribute("EntityId", entityId)
	part.Parent = Workspace
	
	return {
		Part = part,
		Lane = lane,
		Speed = PEA_SPEED,
	}
end

local function destroyProjectileVisual(entityId: number)
	local visual = _projectileVisuals[entityId]
	if visual then
		visual.Part:Destroy()
		_projectileVisuals[entityId] = nil
	end
end

-- Network event handlers
Network.ProjectileSpawned.On(function(data)
	local entityId = data.EntityId
	local lane = data.Lane
	local startX = data.StartX
	
	if not _projectileVisuals[entityId] then
		_projectileVisuals[entityId] = createProjectileVisual(entityId, lane, startX)
		Logger.Debug("ProjectileRender", `Pea {entityId} spawned in lane {lane}`)
	end
end)

-- Also handle projectile despawn via EntityDied (reuse the event)
-- Projectiles don't have health so they won't trigger EntityDied normally
-- We'll clean up when they go off-screen

local function ProjectileRenderSystem(world)
	local dt = 1/60
	
	-- Move projectiles
	for entityId, visual in _projectileVisuals do
		local currentX = visual.Part.Position.X
		local newX = currentX + visual.Speed * dt
		
		-- Check if off-screen (past grid)
		if newX > GridConfig.GRID_WIDTH + 50 then
			destroyProjectileVisual(entityId)
		else
			local z = getLaneZ(visual.Lane)
			visual.Part.Position = Vector3.new(newX, 2.5, z)
		end
	end
end

-- Clean up on EntityDied (for any entity)
Network.EntityDied.On(function(data)
	-- Check if this was a projectile we're tracking
	if _projectileVisuals[data.EntityId] then
		local visual = _projectileVisuals[data.EntityId]
		local pos = visual.Part.Position
		
		-- Play impact VFX and audio
		local vfx = getVFXService()
		local audio = getAudioService()
		if vfx then vfx.PlayPeaImpact(pos, false) end
		if audio then audio.PlayPeaImpact(pos) end
		
		-- Hit animation (quick scale down)
		local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad)
		local tween = TweenService:Create(visual.Part, tweenInfo, {
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1
		})
		tween:Play()
		tween.Completed:Connect(function()
			destroyProjectileVisual(data.EntityId)
		end)
		_projectileVisuals[data.EntityId] = nil
	end
end)

return {
	system = ProjectileRenderSystem,
	priority = 420,
}
