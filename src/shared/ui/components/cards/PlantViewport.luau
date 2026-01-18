--!strict
--[[
	PlantViewport.luau - Reusable 3D plant viewport component
	
	SHARED atom component for displaying a 3D plant model in a ViewportFrame.
	Used across Lobby and Arena UI components.
	
	Features:
	- Automatic camera framing based on model bounds
	- Consistent lighting setup
	- Proper cleanup on scope destruction
	- Optional idle animation (rotation)
	
	Usage:
		local PlantViewport = require(Shared.ui.components.cards.PlantViewport)
		
		-- With Fusion scope (auto-cleanup)
		local viewport = PlantViewport.CreateWithScope(scope, {
			PlantType = "Peashooter",
			Size = UDim2.fromOffset(100, 100),
		})
		
		-- Manual management
		local viewport, cleanup = PlantViewport.New({
			PlantType = "Sunflower",
			EnableRotation = true,
		})
		-- Later: cleanup()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Assets
local Assets = ReplicatedStorage:WaitForChild("Assets")
local PlantModels = Assets:WaitForChild("Plants")

-- Types
export type PlantViewportProps = {
	PlantType: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	-- Camera settings
	CameraFOV: number?, -- Default: 35 (narrower = larger plant)
	CameraDistance: number?, -- Multiplier for distance (default: 1.5)
	CameraHeight: number?, -- Vertical offset multiplier (default: 0.2)
	-- Optional idle animation
	EnableRotation: boolean?, -- Slowly rotate the plant
	RotationSpeed: number?, -- Degrees per second (default: 15)
}

--[[
	Creates a ViewportFrame with a 3D plant model
	
	@param props PlantViewportProps
	@return ViewportFrame - The configured viewport frame (must be parented by caller)
	@return () -> () - Cleanup function to call when destroying
]]
local function PlantViewport(props: PlantViewportProps): (ViewportFrame, () -> ())
	local plantType = props.PlantType

	-- Create viewport frame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "PlantViewport"
	viewport.Size = props.Size or UDim2.fromScale(1, 1)
	viewport.Position = props.Position or UDim2.fromScale(0.5, 0.5)
	viewport.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	viewport.LayoutOrder = props.LayoutOrder or 0
	viewport.ZIndex = props.ZIndex or 1
	viewport.BackgroundTransparency = 1

	-- Lighting setup
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1, -1)

	-- Camera settings
	local fov = props.CameraFOV or 35
	local distanceMultiplier = props.CameraDistance or 1.5
	local heightMultiplier = props.CameraHeight or 0.2

	-- Rotation animation state
	local rotationConnection: RBXScriptConnection? = nil
	local worldModel: WorldModel? = nil
	local model: Model? = nil
	local baseCFrame: CFrame? = nil

	-- Setup viewport with plant model
	local function setup()
		-- Clear previous content
		for _, child in viewport:GetChildren() do
			if child:IsA("Model") or child:IsA("Camera") or child:IsA("WorldModel") then
				child:Destroy()
			end
		end

		-- Get plant model template
		local modelTemplate = PlantModels:FindFirstChild(plantType)
		if not modelTemplate then
			warn("[PlantViewport] Plant model not found:", plantType)
			return
		end

		-- Create WorldModel for proper rendering
		worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewport

		-- Clone and add model
		model = modelTemplate:Clone() :: Model
		model.Parent = worldModel

		-- Position model at origin, rotate 90° to face camera
		baseCFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		if model.PrimaryPart then
			model:PivotTo(baseCFrame)
		end

		-- Create camera
		local camera = Instance.new("Camera")
		camera.FieldOfView = fov
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		-- Calculate framing based on model bounds
		local cframe, size = model:GetBoundingBox()
		local maxSize = math.max(size.X, size.Y, size.Z)
		local distance = maxSize * distanceMultiplier

		-- Position camera in front of the plant
		local modelCenter = cframe.Position
		camera.CFrame = CFrame.new(modelCenter + Vector3.new(0, distance * heightMultiplier, distance), modelCenter)

		-- Setup idle rotation if enabled
		if props.EnableRotation then
			local rotationSpeed = props.RotationSpeed or 15 -- degrees per second
			local currentAngle = 90 -- Start at 90 since we already rotated

			rotationConnection = RunService.Heartbeat:Connect(function(dt)
				if model and model.PrimaryPart and baseCFrame then
					currentAngle = currentAngle + (rotationSpeed * dt)
					model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(currentAngle), 0))
				end
			end)
		end
	end

	-- Cleanup function
	local function cleanup()
		if rotationConnection then
			rotationConnection:Disconnect()
			rotationConnection = nil
		end
		viewport:Destroy()
	end

	-- Defer setup to ensure proper initialization
	task.defer(setup)

	return viewport, cleanup
end

--[[
	Helper to create PlantViewport and add to Fusion scope for auto-cleanup
	
	@param scope Fusion.Scope<any>
	@param props PlantViewportProps
	@return ViewportFrame
]]
local function CreateWithScope(scope: any, props: PlantViewportProps): ViewportFrame
	local viewport, cleanup = PlantViewport(props)

	-- Add cleanup to scope
	table.insert(scope, {
		Destroy = cleanup,
	})

	return viewport
end

return {
	New = PlantViewport,
	CreateWithScope = CreateWithScope,
}
