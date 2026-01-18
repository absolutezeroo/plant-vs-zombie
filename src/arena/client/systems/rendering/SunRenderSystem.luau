--!strict
--[[
	SunRenderSystem.luau - Client-side sun visual rendering
	
	Priority: 400 (Render phase)
	
	Receives sun spawn/despawn events from server via Zap.
	Creates visual sun orbs with falling animation.
	Handles collection input (click/tap on sun).
	
	LIFECYCLE:
	- Init(): Setup network listeners & input handlers (CAN yield)
	- system(): Animate falling suns (CANNOT yield)
	- Dispose(): Disconnect events, cleanup visuals
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Use FindFirstChild to avoid yielding (modules should exist from init.client.luau)
local Packages = ReplicatedStorage:FindFirstChild("Packages")
assert(Packages, "SunRenderSystem: Packages folder not found")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "SunRenderSystem: Shared folder not found")
local Logger = require(Shared.utils.Logger)

-- Client root (script.Parent.Parent.Parent since we're in systems/rendering/)
local Client = script.Parent.Parent.Parent
local Modules = Client:FindFirstChild("modules")
assert(Modules, "SunRenderSystem: modules folder not found")
local SelectionState = require(Modules.SelectionState)
local Network = require(Shared.network.generated.client)
local GameSignals = require(Shared.signals.GameSignals)

-- Sun data cache: entityId -> sun data
type SunData = {
	Part: Part,
	TargetY: number,
	Falling: boolean,
	Value: number,
	OwnerId: number?,
}
local _sunData: { [number]: SunData } = {}

-- Trove for cleanup
local _trove = Trove.new()

-- Sun visual config
local SUN_SIZE = Vector3.new(2.5, 2.5, 2.5)
local SUN_COLOR = Color3.fromRGB(255, 220, 50)
local SUN_COLOR_GREYED = Color3.fromRGB(128, 128, 128) -- For other players' suns
local SUN_MATERIAL = Enum.Material.Neon
local FALL_SPEED = 4 -- Studs per second (match server)

local function createSunVisual(
	entityId: number,
	position: Vector3,
	targetY: number,
	value: number,
	ownerId: number?
): SunData
	local part = Instance.new("Part")
	part.Name = `Sun_{entityId}`
	part.Shape = Enum.PartType.Ball
	part.Size = SUN_SIZE
	part.Material = SUN_MATERIAL
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true -- Raycast needs to hit it
	part.CastShadow = false
	part.Position = position

	-- Determine if this sun belongs to the local player
	local localPlayer = Players.LocalPlayer
	local isOwnSun = (ownerId == nil) or (localPlayer and ownerId == localPlayer.UserId)
	local sunColor = if isOwnSun then SUN_COLOR else SUN_COLOR_GREYED

	part.Color = sunColor
	part.Transparency = if isOwnSun then 0 else 0.3 -- Slightly transparent for others' suns

	-- Add highlight for visibility
	local highlight = Instance.new("Highlight")
	highlight.FillColor = sunColor
	highlight.FillTransparency = if isOwnSun then 0.5 else 0.7
	highlight.OutlineColor = if isOwnSun then Color3.new(1, 1, 1) else Color3.fromRGB(100, 100, 100)
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
		OwnerId = ownerId,
	}
end

local function collectSun(entityId: number, sunData: SunData)
	-- Check ownership: cannot collect other players' suns
	local localPlayer = Players.LocalPlayer
	if sunData.OwnerId and localPlayer and sunData.OwnerId ~= localPlayer.UserId then
		Logger.Debug("SunRender", `Cannot collect sun {entityId} - belongs to player {sunData.OwnerId}`)
		return
	end

	local part = sunData.Part

	-- Play collection effects
	-- Fire signal for VFX/Audio (position + amount)
	GameSignals.OnSunCollected:Fire({
		Position = part.Position,
		Amount = sunData.Value,
	})

	-- Animate collection (tween up and fade)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local targetPos = part.Position + Vector3.new(0, 5, 0)

	local tween = TweenService:Create(part, tweenInfo, {
		Position = targetPos,
		Size = Vector3.new(0.5, 0.5, 0.5),
		Transparency = 1,
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
	if gameProcessed then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	-- Raycast to find sun
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include

	-- Build filter list of sun visuals
	local sunParts: { Instance } = {}
	for _, data in _sunData do
		table.insert(sunParts, data.Part :: Instance)
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

--[[
	Setup network event listeners & input handlers (called during Init phase)
]]
local function setupListeners()
	_trove:Connect(UserInputService.InputBegan, handleInput)

	_trove:Add(Network.SunSpawned.On(function(data)
		local entityId = data.EntityId
		local position = Vector3.new(data.PositionX, data.PositionY, data.PositionZ)
		local ownerId = data.OwnerId -- May be nil for shared suns

		if _sunData[entityId] then
			-- Already exists, update position
			_sunData[entityId].Part.Position = position
		else
			-- Create new sun visual (with ownership info for greying)
			_sunData[entityId] = createSunVisual(entityId, position, data.TargetY, data.Value, ownerId)
			Logger.Debug(
				"SunRender",
				`Sun {entityId} spawned at ({math.floor(data.PositionX)}, {math.floor(data.PositionY)}, {math.floor(
					data.PositionZ
				)}) owner={ownerId or "shared"}`
			)
		end
	end))

	_trove:Add(Network.SunDespawned.On(function(data)
		local entityId = data.EntityId
		local sunData = _sunData[entityId]

		if sunData then
			sunData.Part:Destroy()
			_sunData[entityId] = nil
			Logger.Debug("SunRender", `Sun {entityId} despawned`)
		end
	end))

	_trove:Add(Network.SunPositionUpdate.On(function(data)
		local sunData = _sunData[data.EntityId]
		if sunData then
			sunData.Falling = data.Falling
			if not data.Falling then
				sunData.Part.Position = Vector3.new(sunData.Part.Position.X, data.PositionY, sunData.Part.Position.Z)
			end
		end
	end))

	_trove:Add(Network.SunCollected.On(function(data)
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
	end))

	-- Clear all sun visuals when map is unloading
	_trove:Add(Network.MapUnloading.On(function(_data)
		for entityId, sunData in _sunData do
			if sunData.Part then
				sunData.Part:Destroy()
			end
		end
		table.clear(_sunData)
		Logger.Debug("SunRender", "Cleared all sun visuals for map unload")
	end))
end

--[[
	Destroy sun visual
]]
local function destroySunVisual(entityId: number)
	local sunData = _sunData[entityId]
	if sunData then
		sunData.Part:Destroy()
		_sunData[entityId] = nil
	end
end

--[[
	Init - Setup listeners (CAN yield)
]]
local function Init(_world)
	setupListeners()
	Logger.Debug("SunRender", "Initialized")
end

-- Movement config
local MovementConfig = {
	MIN_DT = 1 / 120, -- Minimum deltaTime
	MAX_DT = 1 / 15, -- Maximum deltaTime
}

--[[
	System - Animate falling suns (CANNOT yield)
]]
local function SunRenderSystem(_world)
	-- CRITICAL: Use Matter's deltaTime for frame-rate independence
	local Matter = require(Packages:FindFirstChild("Matter"))
	local dt = Matter.useDeltaTime()
	dt = math.clamp(dt, MovementConfig.MIN_DT, MovementConfig.MAX_DT)

	for entityId, sunData in _sunData do
		if sunData.Falling then
			local currentY = sunData.Part.Position.Y
			local newY = currentY - FALL_SPEED * dt

			if newY <= sunData.TargetY then
				newY = sunData.TargetY
				sunData.Falling = false
			end

			sunData.Part.Position = Vector3.new(sunData.Part.Position.X, newY, sunData.Part.Position.Z)
		end
	end
end

--[[
	Dispose - Cleanup all visuals and connections
]]
local function Dispose()
	-- Disconnect all events
	_trove:Clean()

	-- Destroy all sun visuals
	for entityId in _sunData do
		destroySunVisual(entityId)
	end

	Logger.Debug("SunRender", "Disposed")
end

return {
	_name = "SunRenderSystem",
	priority = 400,
	system = SunRenderSystem,
	Init = Init,
	Dispose = Dispose,
}
