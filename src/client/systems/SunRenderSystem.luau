--!strict
--[[
	SunRenderSystem.luau - Client-side sun visual rendering
	
	Priority: 400 (Render phase)
	
	Receives sun spawn/despawn events from server via Zap.
	Creates visual sun orbs with falling animation.
	Handles collection input (click/tap on sun).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Client = script.Parent.Parent
local Modules = Client:WaitForChild("modules")
local SelectionState = require(Modules.SelectionState)
local Network = require(Client.network.generated)

-- VFX/Audio services (lazy loaded to avoid circular deps)
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

-- Sun data cache: entityId -> sun data
type SunData = {
	Part: Part,
	TargetY: number,
	Falling: boolean,
	Value: number,
}
local _sunData: {[number]: SunData} = {}

-- Sun visual config
local SUN_SIZE = Vector3.new(2.5, 2.5, 2.5)
local SUN_COLOR = Color3.fromRGB(255, 220, 50)
local SUN_MATERIAL = Enum.Material.Neon
local FALL_SPEED = 4 -- Studs per second (match server)

local function createSunVisual(entityId: number, position: Vector3, targetY: number, value: number): SunData
	local part = Instance.new("Part")
	part.Name = `Sun_{entityId}`
	part.Shape = Enum.PartType.Ball
	part.Size = SUN_SIZE
	part.Color = SUN_COLOR
	part.Material = SUN_MATERIAL
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true -- Raycast needs to hit it
	part.CastShadow = false
	part.Position = position
	
	-- Add highlight for visibility
	local highlight = Instance.new("Highlight")
	highlight.FillColor = SUN_COLOR
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0.5
	highlight.Parent = part
	
	-- Add attribute for entity tracking
	part:SetAttribute("EntityId", entityId)
	
	part.Parent = Workspace
	
	return {
		Part = part,
		TargetY = targetY,
		Falling = true,
		Value = value,
	}
end

local function collectSun(entityId: number, sunData: SunData)
	local part = sunData.Part
	
	-- Play collection effects
	local vfx = getVFXService()
	local audio = getAudioService()
	if vfx then vfx.PlaySunCollect(part.Position) end
	if audio then audio.PlaySunCollect() end
	
	-- Animate collection (tween up and fade)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local targetPos = part.Position + Vector3.new(0, 5, 0)
	
	local tween = TweenService:Create(part, tweenInfo, {
		Position = targetPos,
		Size = Vector3.new(0.5, 0.5, 0.5),
		Transparency = 1
	})
	
	tween:Play()
	tween.Completed:Connect(function()
		part:Destroy()
	end)
	
	-- Remove from cache
	_sunData[entityId] = nil
	
	-- Optimistic update: add sun locally
	SelectionState.AddSun(sunData.Value)
	
	-- Send CollectSun request to server
	Network.CollectSunRequest.Fire({
		RequestId = entityId % 65535, -- Use entityId as request ID
		SunEntityId = entityId,
	})
	
	Logger.Debug("SunRender", `Collected sun {entityId} (+{sunData.Value})`)
end

local function handleInput(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	
	-- Raycast to find sun
	local camera = Workspace.CurrentCamera
	if not camera then return end
	
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	
	-- Build filter list of sun visuals
	local sunParts = {}
	for _, data in _sunData do
		table.insert(sunParts, data.Part)
	end
	rayParams.FilterDescendantsInstances = sunParts
	
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 100, rayParams)
	
	if result and result.Instance then
		local entityId = result.Instance:GetAttribute("EntityId")
		if entityId and _sunData[entityId] then
			collectSun(entityId, _sunData[entityId])
		end
	end
end

UserInputService.InputBegan:Connect(handleInput)

-- Network event handlers
Network.SunSpawned.On(function(data)
	local entityId = data.EntityId
	local position = Vector3.new(data.PositionX, data.PositionY, data.PositionZ)
	
	if _sunData[entityId] then
		-- Already exists, update position
		_sunData[entityId].Part.Position = position
	else
		-- Create new sun visual
		_sunData[entityId] = createSunVisual(entityId, position, data.TargetY, data.Value)
		Logger.Debug("SunRender", `Sun {entityId} spawned at ({math.floor(data.PositionX)}, {math.floor(data.PositionY)}, {math.floor(data.PositionZ)})`)
	end
end)

Network.SunDespawned.On(function(data)
	local entityId = data.EntityId
	local sunData = _sunData[entityId]
	
	if sunData then
		sunData.Part:Destroy()
		_sunData[entityId] = nil
		Logger.Debug("SunRender", `Sun {entityId} despawned`)
	end
end)

Network.SunPositionUpdate.On(function(data)
	local sunData = _sunData[data.EntityId]
	if sunData then
		sunData.Falling = data.Falling
		if not data.Falling then
			sunData.Part.Position = Vector3.new(
				sunData.Part.Position.X,
				data.PositionY,
				sunData.Part.Position.Z
			)
		end
	end
end)

Network.SunCollected.On(function(data)
	-- Another player collected the sun, remove visual
	local sunData = _sunData[data.SunEntityId]
	if sunData then
		sunData.Part:Destroy()
		_sunData[data.SunEntityId] = nil
	end
	
	-- Update our sun count if we were the collector
	local localPlayer = Players.LocalPlayer
	if localPlayer and data.CollectorId == localPlayer.UserId then
		SelectionState.SetSun(data.NewTotal)
	end
end)

local function SunRenderSystem(world)
	-- Client-side falling animation (interpolation)
	local dt = 1/60 -- Approximate delta time
	
	for entityId, sunData in _sunData do
		if sunData.Falling then
			local currentY = sunData.Part.Position.Y
			local newY = currentY - FALL_SPEED * dt
			
			if newY <= sunData.TargetY then
				newY = sunData.TargetY
				sunData.Falling = false
			end
			
			sunData.Part.Position = Vector3.new(
				sunData.Part.Position.X,
				newY,
				sunData.Part.Position.Z
			)
		end
	end
end

return {
	system = SunRenderSystem,
	priority = 400, -- Render phase
}
